--[[
 LivingBase / bbraid.lua — BLACKBEARD FLAG RAID  (Config.BBRAID_ENABLED, F8)

 Drop the flag with F7 (the Composition_70 prop, its own dedicated key), then press F8: at EACH placed
 flag a wave of hostile Blackbeard pirates spawns and charges the nearest bonfire to attack the camp.

 Reuses the night-raid pattern (raid.lua): spawns are TRANSIENT (never persisted, so a reload can't
 resurrect a finished raid) and COMBATANT (skips set-dressing, so they stay killable AND keep their own
 hostile Blackbeard faction + AI — hostility is free, we just don't apply the friendly crew faction).

 The "mixed group" is automatic: BP_Mob_Crew_Regular_Blackbeard randomizes its archetype on spawn
 (musketeer / sailor / ...), and the officer is the sergeant-tier. So a batch of regulars + an officer
 already reads as a varied pirate band without any per-unit class list.

 v1 scope: level scaling (enemy = player level - 2) is STUBBED — no plain character-level field exists
 in the headers, so raiders spawn at their default level for now (RedFalcon OK'd this). applyLevel() is the
 single hook to fill in once the scaling attribute is found.
]]

local Config = require("config")
local Spawner = require("spawner")
local UEHelpers = require("UEHelpers")

local BBRaid = {}
BBRaid.active = {}      -- live raiders across all flags, so Clear()/pruning can reach them
BBRaid.gen = 0         -- bumped on world load; per-raider despawn timers from a prior session bail (their
                       -- captured actor pointer dangles once the old world is torn down / GC'd)

local function log(msg) print(string.format("[LivingBase:BBRaid] %s\n", tostring(msg))) end

local function actorLoc(a)
    local loc = nil
    pcall(function() loc = a:K2_GetActorLocation() end)
    return loc
end

-- Every player-placed flag we can still see (tracked spawn whose class is the flag decoration).
local function findFlags()
    -- A Ctrl+R hot-reload wipes Spawner.spawned, so a flag placed before the reload is still IN the world
    -- but no longer tracked. Recover it from the ledger first (same trick as the live-edit/despawn keys).
    if #(Spawner.spawned or {}) == 0 then pcall(Spawner.RetrackOrphans) end
    local flags = {}
    local flagClass = Config.BBRAID_FLAG_CLASS
    for _, e in ipairs(Spawner.spawned or {}) do
        if e and e.actor and e.actor:IsValid() and e.class == flagClass then
            flags[#flags + 1] = e.actor
        end
    end
    return flags
end

-- Bonfires (building centers). FindAllOf scans EVERY UObject, so calling it each charge tick (every 3s)
-- was a periodic hitch — the stutter. Bonfires don't move and a base under raid won't gain new ones, so
-- scan ONCE per raid and cache; thereafter only PRUNE invalidated entries — never re-scan, even when the
-- cache empties (re-scanning an empty result every tick would reintroduce the per-tick full scan). The
-- short class name is derived from Config.BBRAID_BONFIRE_CLASS so the version string lives only in config.
-- bonfireCache is reset (to nil) at each raid Trigger so the next raid scans fresh.
local BONFIRE_SHORT = (Config.BBRAID_BONFIRE_CLASS or ""):match("([^.]+)$")
    or "BP_BuildingBlock_BuildingCenterT01_C"
local bonfireCache = nil
local function getBonfires()
    if bonfireCache then
        local live = {}
        for _, b in ipairs(bonfireCache) do if b and b:IsValid() then live[#live + 1] = b end end
        bonfireCache = live
        return bonfireCache
    end
    local list = nil
    pcall(function() list = FindAllOf(BONFIRE_SHORT) end)
    bonfireCache = list or {}
    return bonfireCache
end

-- Nearest bonfire in `list` to a location.
local function nearestFrom(loc, list)
    if not loc then return nil end
    local best, bestD
    for _, b in ipairs(list) do
        if b and b:IsValid() then
            local bl = actorLoc(b)
            if bl then
                local dx, dy = bl.X - loc.X, bl.Y - loc.Y
                local d = dx * dx + dy * dy
                if not bestD or d < bestD then best, bestD = b, d end
            end
        end
    end
    return best
end

-- STUB: set a raider's level to player level + BBRAID_LEVEL_OFFSET. No character-level field was found
-- in the headers, so this is a no-op placeholder for v1 (raiders keep their default level). Fill in here
-- once the scaling attribute is located; everything else already passes the actor through.
local function applyLevel(actor)
    -- intentionally empty for v1 (RedFalcon approved default-level pirates)
end

-- Scatter point around the flag so a wave doesn't stack on one pixel.
local function spawnSpot(center, i)
    local spread = Config.BBRAID_SPREAD_UU or 350
    local ang = math.random() * math.pi * 2
    local r = math.random() * spread
    return { X = center.X + math.cos(ang) * r, Y = center.Y + math.sin(ang) * r, Z = center.Z }
end

-- The charge order is NOT issued here — a freshly spawned pawn has no initialized Mercuna nav yet, so a
-- one-shot order at spawn fails (or beelines via stock nav). The repeating chargeTick() below handles it
-- once nav is up, and keeps re-issuing so they don't stall.
local function spawnOne(path, name, spot)
    Spawner.transient = true       -- never written to persist.txt
    Spawner.combatant = true       -- killable + keeps its hostile faction/AI
    local ok, actor = pcall(function()
        return Spawner.Spawn(path, "BBRAID_" .. name, spot, nil, nil, nil, false, nil)
    end)
    Spawner.transient = false
    Spawner.combatant = false
    if not (ok and actor and actor:IsValid()) then
        log("Failed to spawn " .. tostring(name) .. " — check the class path.")
        return
    end
    BBRaid.active[#BBRaid.active + 1] = actor
    pcall(function() applyLevel(actor) end)
    -- Start them fast right away (the ticker keeps re-asserting it after).
    pcall(function() Spawner.SetMaxWalkSpeed(actor, Config.BBRAID_RUN_SPEED or 450) end)
    pcall(function() Spawner.SetSpeedMultiplier(actor, Config.BBRAID_SPEED_MULT or 1.5) end)
    -- Self-despawn if the player never kills it (transient, so a reload wouldn't clean it otherwise).
    if ExecuteWithDelay then
        local myGen = BBRaid.gen
        ExecuteWithDelay(Config.BBRAID_DESPAWN_MS or 300000, function()
            if myGen ~= BBRaid.gen then return end   -- a world load happened; this actor is from a torn-down session
            ExecuteInGameThread(function() pcall(function()
                if actor and actor:IsValid() then actor:K2_DestroyActor() end
            end) end)
        end)
    end
end

-- CHARGE TICKER. Every BBRAID_CHARGE_MS, re-issue "move to the nearest bonfire" to each live raider that
-- ISN'T currently fighting — Mercuna (which pathfinds around rocks, unlike the stock-nav fallback) is
-- ready by now, and a repeating order stops them stalling. Fighting raiders are left to their combat AI
-- so we don't yank them off a defender. Self-stops when no raiders remain.
local charging = false
local function chargeTick()
    local live = {}
    for _, a in ipairs(BBRaid.active) do if a and a:IsValid() then live[#live + 1] = a end end
    BBRaid.active = live
    if #live == 0 then charging = false; return end     -- nothing left to steer
    ExecuteInGameThread(function() pcall(function()
        local pc = UEHelpers.GetPlayerController()
        local player = pc and pc:IsValid() and pc.Pawn or nil
        local bonfires = getBonfires()
        if #bonfires == 0 then log("charge: no bonfire found in the world."); return end
        -- Tally which navigator each raider got so we can SEE from the log whether they're pathfinding
        -- (Mercuna) or beelining (stock fallback) — the whole question RedFalcon raised.
        local merc, stock, fighting = 0, 0, 0
        for _, a in ipairs(live) do
            if a and a:IsValid() then
                -- Keep them RUNNING (raid urgency). Re-assert every tick because the gait system re-clamps
                -- the speed; applies to fighters too so a charge doesn't drop to a walk mid-swing.
                pcall(function() Spawner.SetMaxWalkSpeed(a, Config.BBRAID_RUN_SPEED or 450) end)
                pcall(function() Spawner.SetSpeedMultiplier(a, Config.BBRAID_SPEED_MULT or 1.5) end)
                if Spawner.IsFighting(a, player) then
                    fighting = fighting + 1
                else
                    local bf = nearestFrom(actorLoc(a), bonfires)
                    if bf then
                        local _, status = Spawner.MoveTowards(a, bf)
                        if tostring(status):find("mercuna", 1, true) then merc = merc + 1 else stock = stock + 1 end
                    end
                end
            end
        end
        log(string.format("charge: %d via Mercuna (pathfinds), %d via stock nav (beelines), %d fighting.",
            merc, stock, fighting))
    end) end)
    if ExecuteWithDelay then ExecuteWithDelay(Config.BBRAID_CHARGE_MS or 3000, chargeTick) end
end
local function startCharging()
    if charging then return end
    charging = true
    if ExecuteWithDelay then ExecuteWithDelay(Config.BBRAID_CHARGE_MS or 3000, chargeTick) end
end

-- Spawn a full wave at one flag, staggered (a burst of AI pawns in one frame crashes natively).
local function waveAt(flag)
    local center = actorLoc(flag)
    if not center then return end
    -- Build the wave list (regulars then the officer), then drip it out one per stagger tick.
    local wave = {}
    for _ = 1, (Config.BBRAID_REGULARS or 5) do wave[#wave + 1] = { p = Config.BBRAID_REGULAR_CLASS, n = "Regular" } end
    for _ = 1, (Config.BBRAID_OFFICERS or 1) do wave[#wave + 1] = { p = Config.BBRAID_OFFICER_CLASS, n = "Officer" } end
    local i = 0
    local function step()
        i = i + 1
        if i > #wave then return end
        ExecuteInGameThread(function()
            spawnOne(wave[i].p, wave[i].n, spawnSpot(center, i))
        end)
        if ExecuteWithDelay then ExecuteWithDelay(Config.BBRAID_STAGGER_MS or 400, step) end
    end
    if ExecuteWithDelay then ExecuteWithDelay(Config.BBRAID_STAGGER_MS or 400, step) else step() end
end

-- F8: spawn a wave at every placed flag.
function BBRaid.Trigger()
    if not Config.BBRAID_ENABLED then log("Blackbeard raid disabled (Config.BBRAID_ENABLED)."); return end
    local flags = findFlags()
    if #flags == 0 then
        log("No placed Blackbeard flag found. Drop the raid flag with F7 first, then press F8.")
        return
    end
    -- Drop dead raiders from the roster before adding a new wave, so Count stays honest.
    local live = {}
    for _, a in ipairs(BBRaid.active) do if a and a:IsValid() then live[#live + 1] = a end end
    BBRaid.active = live
    bonfireCache = nil   -- rescan bonfires once for this raid (base may have changed since last time)
    log(string.format("Blackbeard raid! %d wave(s) inbound — %d regulars + %d officer each.",
        #flags, Config.BBRAID_REGULARS or 5, Config.BBRAID_OFFICERS or 1))
    -- Shield the base NOW so the first swings can't chip a wall before the periodic sweep comes around.
    pcall(function() local n = Spawner.ShieldAllStructures(); if n and n > 0 then log(string.format("Shielded %d structures against the raid.", n)) end end)
    for _, flag in ipairs(flags) do waveAt(flag) end
    startCharging()   -- repeating order that steers non-fighting raiders to the nearest bonfire
end

-- Panic button / cleanup: remove every raider still standing.
function BBRaid.Clear()
    local n = 0
    for _, a in ipairs(BBRaid.active) do
        if a and a:IsValid() then pcall(function() a:K2_DestroyActor() end); n = n + 1 end
    end
    BBRaid.active = {}
    log(string.format("Blackbeard raid cleared — %d removed.", n))
end

-- Called from main.lua on WORLD LOAD. A reload tears down the old world, so any raiders from a raid that
-- was still running are freed — but our module state (BBRaid.active, the charge ticker, and each raider's
-- 5-min despawn timer) still holds their now-dangling pointers, and IsValid() doesn't reliably catch a
-- freed-across-GC UObject (the mod's known AV class). Bumping gen makes the stale despawn timers bail and
-- clearing active makes the ticker self-stop, so nothing native is called on a torn-down actor. A fresh
-- raid after load starts clean.
function BBRaid.Reset()
    BBRaid.gen = BBRaid.gen + 1
    BBRaid.active = {}
    bonfireCache = nil
    charging = false
end

return BBRaid
