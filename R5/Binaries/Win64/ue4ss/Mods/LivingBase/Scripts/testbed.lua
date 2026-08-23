--[[
 LivingBase / testbed.lua — the placement handlers behind the keys.
 Numpad: SpawnCrew, SpawnWalker (townsman), the statue cyclers (standing/seated/chair/interactive),
 SpawnNextPlague (Senkamati), SpawnNextLivestock (boar/goat/dodo/wolf/crocodile), DespawnInFront
 (undo), Cleanup (DEL).
 Decor: SpawnActiveDecorCategory places from the active category, CycleDecorCategory changes which
 one is active (Config.DECOR_ORDER / Config.DECOR_CATEGORIES) — see fkeys.lua.
 Every placement goes through Spawner.Spawn, which records it to persist.txt for restore on reload.
]]

local Config = require("config")
local Spawner = require("spawner")
local UEHelpers = require("UEHelpers")


local Testbed = {}

-- Delayed callbacks (de-corrupt retries, hair re-applies) can fire long after a spawn.
-- If DEL despawned everything in the meantime, touching those actors crashes the game.
-- Capture Spawner.generation at spawn time and bail when it changes.
-- Spawner.generation is a WIPE marker: only DespawnAll (DEL) bumps it. A single F9 despawn drops
-- that actor from Spawner.spawned instead, so its own callbacks bail via IsTracked while everyone
-- else's keep running. Before this split, any F9 within ~13.5s of spawning a Warrior silently
-- cancelled his shield and hair fix.
local function stillAlive(actor, gen)
    if Spawner.generation ~= gen then return false end
    if not (actor and actor:IsValid()) then return false end
    return Spawner.IsTracked(actor)
end

-- MakePassive, but re-applied over ~3s. A pawn's ability system (its attacks) attaches
-- late in BeginPlay and can rebuild AFTER a one-shot strip — which is why crew kept
-- fighting goats. Strip now, then a few more times, guarded against DEL (generation).
local function disarmRepeated(actor)
    if not (actor and actor:IsValid()) then return end
    pcall(function() Spawner.MakePassive(actor) end)
    if not ExecuteWithDelay then return end
    local gen = Spawner.generation
    local n = 0
    local function again()
        ExecuteInGameThread(function() pcall(function()
            if stillAlive(actor, gen) then Spawner.MakePassive(actor) end
        end) end)
        n = n + 1
        if n < 4 and ExecuteWithDelay then ExecuteWithDelay(750, again) end
    end
    ExecuteWithDelay(750, again)
end

-- Make a spawned animal peaceful: copy the crew (friendly) faction, and for goats strip the
-- battle/target components so they don't initiate. Re-applied a few times over ~3s because
-- the pawn's AI/faction can rebuild late in BeginPlay. `disable` = component names to strip.
local function pacifyCreature(actor, label, disable)
    if not (actor and actor:IsValid()) then return end
    local fp = Spawner.GetFriendlyFactionParams()
    local function apply()
        if Config.CREW_PASSIVE then pcall(function() Spawner.MakePassive(actor) end) end
        if fp then pcall(function() Spawner.MakeFriendly(actor, fp) end) end
        if disable then
            for _, name in ipairs(disable) do Spawner.StripComponent(actor, name) end
        end
        -- makeSetDressing() already cleared bCanBeDamaged, but damage here flows through GAS, not
        -- UE's damage path -- which is why boars and goats still died in raids. Apply the game's
        -- own mob immunity effect instead.
        if Config.CREATURE_INVINCIBLE then
            local ge = Spawner.ResolveGEClass(Config.IMMUNE_GE_CANDIDATES, Config.IMMUNE_GE_NAME)
            if ge then pcall(function() Spawner.ApplyGE(actor, ge) end) end
        end
    end
    apply()
    if not ExecuteWithDelay then return end
    local gen = Spawner.generation
    local n = 0
    local function again()
        ExecuteInGameThread(function() pcall(function()
            if stillAlive(actor, gen) then apply() end
        end) end)
        n = n + 1
        if n < 4 and ExecuteWithDelay then ExecuteWithDelay(750, again) end
    end
    ExecuteWithDelay(750, again)
end

local MOD_NAME = "[LivingBase:Testbed]"

local function log(msg)
    if Config.VERBOSE then print(string.format("%s %s\n", MOD_NAME, tostring(msg))) end
end

------------------------------------------------------------
-- Num1: crew pawn, cycling forward one look per press through Config.FACTION_VISITOR_LOOKS (same
-- rotation style as SpawnWalker below) -- index 1 is plain default crew (params=nil), the other 12
-- are faction re-skins (Buccaneers/Smugglers/Tortuga/Brethren, confirmed working 2026-08-07). Was
-- its own separate key (Num+) at first, merged in the same day once nothing else needed that key --
-- see Config.FACTION_VISITOR_LOOKS's own comment for the full re-skin mechanism/history (why
-- `params` not `archetype`, and why colorParams is deliberately NOT wired in here).
------------------------------------------------------------
local lastCrewIdx = 0

-- Spawn one specific Config.FACTION_VISITOR_LOOKS entry -- shared by the rotation-driven Num1 key
-- (Testbed.SpawnCrew, picks the next entry itself) and the by-name console lookup
-- (Testbed.SpawnCrewByName, 2026-08-13, for lbspawn/lblook validation -- see main.lua).
local function spawnCrewEntry(entry)
    local ai = Config.HANDYMAN_FOR_CREW and Config.HANDYMAN_AI_CLASS or nil
    -- Prefer spawn_menu.ini's curated label (Spawner.FriendlyLabels, built in main.lua) over the
    -- mechanical "CREW_<name>" fallback -- see that table's own comment for the full mechanism.
    local spawnLabel = (Spawner.FriendlyLabels and Spawner.FriendlyLabels[entry.name]) or ("CREW_" .. entry.name)
    local actor = Spawner.Spawn(Config.CREW_CLASS, spawnLabel, nil, nil, ai, nil, false,
        { params = entry.params, sex = entry.sex, bodyTypes = entry.bodyTypes })
    -- Set-dressing: disarm only if CREW_PASSIVE (off by default so crew still defend).
    if Config.CREW_PASSIVE and actor and actor:IsValid() then disarmRepeated(actor) end
    return actor
end

function Testbed.SpawnCrew()
    local list = Config.FACTION_VISITOR_LOOKS or {}
    if #list == 0 then log("No crew looks configured."); return end
    local idx = (lastCrewIdx % #list) + 1
    lastCrewIdx = idx
    local entry = list[idx]
    local ai = Config.HANDYMAN_FOR_CREW and Config.HANDYMAN_AI_CLASS or nil
    log(string.format("Placing CREW %d/%d: %s%s", idx, #list, entry.name, ai and " (+sit AI)" or ""))
    spawnCrewEntry(entry)
end

-- By-name lookup (console validation, 2026-08-13) -- case-insensitive match against
-- Config.FACTION_VISITOR_LOOKS' own `name` field ("Buccaneers Musketeer", "Player Crew", etc.).
-- Returns the spawned actor, or nil + a reason string on no match.
function Testbed.SpawnCrewByName(name)
    for _, entry in ipairs(Config.FACTION_VISITOR_LOOKS or {}) do
        if entry.name:lower() == tostring(name):lower() then
            return spawnCrewEntry(entry)
        end
    end
    return nil, "no crew look named '" .. tostring(name) .. "'"
end

------------------------------------------------------------
-- Townsman key: place ONE townsman, picked at RANDOM from Config.TOWNSFOLK_CLASSES
-- (never the same class twice in a row), so outfits vary instead of alternating.
-- Each Citizen class has ~one outfit, so variety comes from the wider roster (the
-- Handyman professions each dress differently). Handyman NPCs keep their OWN AI
-- (they're the pawns it was built for); Citizens get the Handyman AI override so
-- they wander + sit. Females aren't available as walkers (class is male-locked).
------------------------------------------------------------
local lastTownIdx = 0

-- Spawn one specific Config.TOWNSFOLK_CLASSES entry -- shared by the rotation-driven Num2 key
-- (Testbed.SpawnWalker, picks the next entry itself) and the by-name console lookup
-- (Testbed.SpawnWalkerByName, 2026-08-13, for lbspawn/lblook validation -- see main.lua).
local function spawnTownsmanEntry(cls)
    -- Only the plain Citizens need the Handyman brain bolted on.
    local ai = (cls.handymanAI and Config.HANDYMAN_FOR_TOWNSFOLK)
        and Config.HANDYMAN_AI_CLASS or nil
    -- Each profession has ONE archetype (= identical clones). Assign a RANDOM
    -- archetype pre-build for real face/body/sex variety, plus the hero body-type
    -- list so female archetypes can resolve a female body on any pawn.
    local look, archName = nil, ""
    if Config.TOWNSFOLK_VARY_ARCHETYPE and Config.TOWNSFOLK_ARCHETYPES
        and #Config.TOWNSFOLK_ARCHETYPES > 0 then
        local a = Config.TOWNSFOLK_ARCHETYPES[math.random(#Config.TOWNSFOLK_ARCHETYPES)]
        look = { archetype = a, bodyTypes = Config.HERO_BODY_TYPES }
        archName = " / " .. (a:match("Archetype(%w+)$") or "?") ..
            (a:find("_Female_") and " (F)" or "")
    end
    log(string.format("Placing townsman: %s%s%s", cls.name, archName, ai and " (+sit AI)" or ""))
    -- Prefer spawn_menu.ini's curated label over the mechanical "TOWN_<name>" fallback -- see
    -- Spawner.FriendlyLabels' own comment (main.lua) for the full mechanism.
    local spawnLabel = (Spawner.FriendlyLabels and Spawner.FriendlyLabels[cls.name]) or ("TOWN_" .. cls.name)
    local actor = Spawner.Spawn(cls.path, spawnLabel, nil, nil, ai, nil, false, look)
    if not (actor and actor:IsValid()) then
        -- Path miss (e.g. a Handyman variant) — fall back to the plain Walker.
        log("Townsman '" .. cls.name .. "' failed; falling back to Walker.")
        return Spawner.Spawn(Config.TOWNSFOLK_WALKER_CLASS, "TOWN_Walker", nil, nil,
            Config.HANDYMAN_FOR_TOWNSFOLK and Config.HANDYMAN_AI_CLASS or nil)
    end
    -- Townsfolk spawn exactly as the game ships them (no re-skin, no hair colour).
    return actor
end

function Testbed.SpawnWalker()
    local list = Config.TOWNSFOLK_CLASSES or {}
    if #list == 0 then log("No townsfolk classes configured."); return end
    -- Set rotation (RedFalcon 2026-07-08): cycle the professions in order, one per press, so
    -- N presses hit all N once — instead of random picks that clump/repeat.
    local idx = (lastTownIdx % #list) + 1
    lastTownIdx = idx
    spawnTownsmanEntry(list[idx])
end

-- By-name lookup (console validation, 2026-08-13) -- case-insensitive match against
-- Config.TOWNSFOLK_CLASSES' own `name` field ("Walker", "Farmer", "Gatherer", etc.).
-- Returns the spawned actor, or nil + a reason string on no match.
function Testbed.SpawnWalkerByName(name)
    for _, cls in ipairs(Config.TOWNSFOLK_CLASSES or {}) do
        if cls.name:lower() == tostring(name):lower() then
            return spawnTownsmanEntry(cls)
        end
    end
    return nil, "no townsfolk class named '" .. tostring(name) .. "'"
end

------------------------------------------------------------
-- Shared placement helpers. Posed statues have varying pivots (some at the
-- head), so we DON'T guess a fixed vertical offset — we spawn, then measure
-- the actor's bounds and drop it so its bottom rests on the floor.
------------------------------------------------------------
-- Horizontal direction is CAMERA yaw, not pawn body yaw (see spotInFrontOfPlayer in spawner.lua for
-- the full reasoning) — matches where you're actually looking left/right. Pitch deliberately excluded;
-- Z still comes from the player's own height / STATUE_GROUND_OFFSET, then snapToFloor below corrects it.
local function frontSpot(dist)
    local pc = UEHelpers.GetPlayerController()
    local pawn = pc and pc:IsValid() and pc.Pawn or nil
    if not pawn or not pawn:IsValid() then return nil end
    local loc = pawn:K2_GetActorLocation()
    local yawDeg = pawn:K2_GetActorRotation().Yaw
    pcall(function()
        local camRot = pc:GetControlRotation()
        if camRot then yawDeg = camRot.Yaw end
    end)
    local yaw = math.rad(yawDeg)
    return {
        X = loc.X + math.cos(yaw) * (dist or 300),
        Y = loc.Y + math.sin(yaw) * (dist or 300),
        Z = loc.Z - (Config.STATUE_GROUND_OFFSET or 0),
    }
end

-- Floor Z under the player (their bounding-box bottom = where they stand).
local function playerFloorZ()
    local pc = UEHelpers.GetPlayerController()
    local pawn = pc and pc:IsValid() and pc.Pawn or nil
    if not pawn or not pawn:IsValid() then return nil end
    local z = nil
    pcall(function()
        local origin, extent = pawn:GetActorBounds(false)
        if origin and extent then z = origin.Z - extent.Z end
    end)
    if z then return z end
    local ok, loc = pcall(function() return pawn:K2_GetActorLocation() end)
    return ok and loc and (loc.Z - 90) or nil
end

-- Drop `actor` so its bounding-box bottom rests at floorZ (per-actor, handles
-- any pivot). Fail-safe: if bounds are unreadable, leaves the actor as-is.
local function snapToFloor(actor, floorZ)
    if not (actor and actor:IsValid() and floorZ) then return end
    pcall(function()
        local origin, extent = actor:GetActorBounds(false)
        if not (origin and extent) then return end
        local bottom = origin.Z - extent.Z
        local loc = actor:K2_GetActorLocation()
        local dz = floorZ - bottom
        if math.abs(dz) <= 1000 then
            actor:K2_SetActorLocation({ X = loc.X, Y = loc.Y, Z = loc.Z + dz }, false, {}, true)
        end
    end)
end

-- Place a posed statue, optionally with the FURNITURE it's posed to sit on. Both go at
-- the same spot + facing and are each snapped to the floor, so a "SitterOnStool" lands
-- on its stool. Both are tracked/persisted, so DEL removes the pair (F9 undoes one at a
-- time). Statues posed "SitterOnGround" need no furniture at all.
local function spawnPosed(path, label, furniture, yaw)
    local spot   = frontSpot(300)
    local floorZ = playerFloorZ()
    if furniture then
        local f = Spawner.Spawn(furniture, label .. "_Seat", spot, nil, nil, yaw)
        if f and f:IsValid() then snapToFloor(f, floorZ) end
    end
    local actor = Spawner.Spawn(path, label, spot, nil, nil, yaw)
    if actor and actor:IsValid() then snapToFloor(actor, floorZ) end
    return actor
end

-- The player's current facing yaw (for statues that should face the same way you do).
local function playerYaw()
    local y = 0.0
    pcall(function()
        local pc = UEHelpers.GetPlayerController()
        local pawn = pc and pc:IsValid() and pc.Pawn
        if pawn and pawn:IsValid() then y = pawn:K2_GetActorRotation().Yaw end
    end)
    return y
end

------------------------------------------------------------
-- Boar: place a friendly boar (farm vibe). Tries each candidate path until
-- one resolves; the working one is what gets persisted.
------------------------------------------------------------
-- Spawn the first resolving candidate from a list, friendly if configured. `aiPath`
-- optionally overrides the pawn's AI controller (e.g. the friendly-boar brain for goats).
-- Say ONCE per session which class each creature actually resolved to. The boar bug hid for weeks
-- because the fallback was silent: BP_Mob_Boar_Friend is the whistle summon and is the only class
-- in the game carrying GE_Mob_Boar_Friend_KillTimer, so those boars quietly died on a timer.
-- Always prints (not VERBOSE-gated) — a silent fallback is what let this go unnoticed.
local announcedClass = {}
local function announceCreatureClass(label, path)
    if announcedClass[label] then return end
    announcedClass[label] = true
    local leaf = tostring(path):match("([^/%.]+)$") or tostring(path)
    if path:find("Boar_Friend") then
        print(string.format(
            "[LivingBase] %s -> %s  *** WHISTLE SUMMON: carries GE_Mob_Boar_Friend_KillTimer " ..
            "and WILL die on a timer. The plain BP_Mob_Boar path did not resolve. ***\n",
            tostring(label), leaf))
    else
        print(string.format("[LivingBase] %s -> %s\n", tostring(label), leaf))
    end
end

local function spawnCreature(candidates, label, aiPath, disable)
    local friendly = Config.MAKE_CREATURES_FRIENDLY == true
    if friendly and not Spawner.GetFriendlyFactionParams() then
        log("No crew found to copy a friendly faction from — spawn a crew (F2) " ..
            "first, or " .. label .. " will be hostile.")
    end
    for _, path in ipairs(candidates or {}) do
        local a = Spawner.Spawn(path, label, frontSpot(300), nil, aiPath, nil, friendly)
        if a and a:IsValid() then
            snapToFloor(a, playerFloorZ())
            -- Copy the friendly faction; goats also get their battle/target components
            -- stripped so they don't initiate.
            pacifyCreature(a, label, disable)
            announceCreatureClass(label, path)
            return true
        end
    end
    return false
end

-- LIVESTOCK (NUM_8): all "tame like pets" creatures on one key. Cycles boar family -> goats ->
-- dodos -> wolves -> crocodile. Expanded 2026-08-07 (per user request) to fold in the wider wildlife
-- roster, all pacified the same way as the original boar/goat/dodo set (friendly-faction copy +
-- invincibility via pacifyCreature) -- see Config.BOARS/WOLVES/CROCODILES' own comments for which
-- ones are proven-passive (Boar, via Config.BOAR_AI) vs never-live-tested (everything new).
local livestock, liveIdx = nil, 0
-- Lazily builds (and caches in the `livestock` upvalue) the flattened BOARS+GOATS+DODOS+WOLVES+
-- CROCODILES roster with each entry's AI-override/disable-list already resolved. Shared by the
-- rotation-driven Num8 key (Testbed.SpawnNextLivestock) and the by-name console lookup
-- (Testbed.SpawnLivestockByName, 2026-08-13 -- see main.lua). Pulled out of SpawnNextLivestock
-- unchanged; behavior for the real key is identical to before this refactor.
local function buildLivestockList()
    if livestock then return livestock end
    livestock = {}
    -- Boar family: only the base Boar has a known-passive AI override (Config.BOAR_AI, found by
    -- testing); Sow/Charger/Mega carry whatever `ai` Config.BOARS gives them (nil for now).
    for _, b in ipairs(Config.BOARS or {}) do
        livestock[#livestock + 1] = { name = b.name, candidates = b.candidates, ai = b.ai }
    end
    -- Aggressive MALE goat gets the FEMALE prey brain; all goats (incl. GoatMega) get the
    -- perception strip. GoatMega has no dedicated ai override yet (falls through to nil).
    for _, g in ipairs(Config.GOATS or {}) do
        local ai = (g.name == "GoatM") and Config.GOATF_AI or nil
        livestock[#livestock + 1] = { name = g.name, candidates = g.candidates,
                                      ai = ai, disable = Config.GOAT_DISABLE }
    end
    -- Dodos: calm with just the friendly faction, own brain kept (DODO_AI defaults false -> nil).
    for _, d in ipairs(Config.DODOS or {}) do
        livestock[#livestock + 1] = { name = d.name, candidates = d.candidates,
                                      ai = Config.DODO_AI or nil }
    end
    for _, w in ipairs(Config.WOLVES or {}) do
        livestock[#livestock + 1] = { name = w.name, candidates = w.candidates }
    end
    for _, c in ipairs(Config.CROCODILES or {}) do
        livestock[#livestock + 1] = { name = c.name, candidates = c.candidates }
    end
    return livestock
end

-- Prefer spawn_menu.ini's curated label over the mechanical "LIVESTOCK_<name>" fallback -- see
-- Spawner.FriendlyLabels' own comment (main.lua) for the full mechanism. Shared by both call sites
-- below so the lookup can't drift between the rotation-driven key and the by-name console lookup.
local function livestockLabel(a)
    return (Spawner.FriendlyLabels and Spawner.FriendlyLabels[a.name]) or ("LIVESTOCK_" .. a.name)
end

function Testbed.SpawnNextLivestock()
    local list = buildLivestockList()
    if #list == 0 then log("No livestock configured."); return end
    liveIdx = liveIdx % #list + 1
    local a = list[liveIdx]
    log(string.format("Livestock %d/%d: %s", liveIdx, #list, a.name))
    if not spawnCreature(a.candidates, livestockLabel(a), a.ai, a.disable) then
        log("Livestock " .. a.name .. " failed — no candidate path resolved.")
    end
end

-- By-name lookup (console validation, 2026-08-13) -- case-insensitive match against the roster's
-- own short name ("Boar", "GoatM", "CrocodilePlague", etc, same names CONSOLE_SPAWN_REFERENCE.md
-- lists). Goes through the SAME spawnCreature() the real Num8 key uses, so it gets the SAME
-- pacification (friendly faction + AI override + component-disable) -- unlike a raw `lbspawn` of
-- the class, which stays hostile since it deliberately skips all mod-specific treatment. Returns
-- true/false (matching Testbed.SpawnNextLivestock's own via spawnCreature's contract) or nil +
-- a reason string on no match.
function Testbed.SpawnLivestockByName(name)
    local list = buildLivestockList()
    for _, a in ipairs(list) do
        if a.name:lower() == tostring(name):lower() then
            return spawnCreature(a.candidates, livestockLabel(a), a.ai, a.disable)
        end
    end
    return nil, "no livestock entry named '" .. tostring(name) .. "'"
end

-- END (EXPERIMENT): place a harvestable dodo-egg nest. Spawned COMBATANT so set-dressing doesn't lock
-- it invulnerable (a nest must be harvestable), and persisted so it survives reloads. Whether it
-- REFILLS after harvest depends on the raw-spawned actor registering its own respawn logic -- untested,
-- so watch it after harvesting. Cycles the two nest variants.
-- F-ROW: cycle through a DECORATION CATEGORY (Config.DECOR_CATEGORIES[cat]) and place one. Pure scenery:
-- spawned as set-dressing (invulnerable), ground-snapped, persisted. Each category has its own cycle
-- index so F1..F6 advance independently. END no longer cycles everything.
local decorIdx = {}   -- per-category cursor
-- Place ONE decoration entry {name, path, zoffset} ~3m in front: spawn, solidify, and pin its Z so it
-- rests at floor + zoffset (live-edit nudges from there; the pose persists). Shared by the F-row category
-- cyclers (SpawnDecorCategory).
-- Spawn label: `d.label` (2026-08-17, a "Proper Name" some entries now carry, e.g. "Bezoar") if
-- present, else the raw `d.name` -- was unconditionally "DECOR_" .. d.name before; dropped the
-- prefix since it made every toast/persisted label read like "DECOR_Loot_T02_Bezoar_01 1" instead
-- of something a player would want to see. Safe to drop: Spawner.SolidifyDecor's "is this tracked
-- entry decor" fallback check (e.label:sub(1,6)=="DECOR_") is an OR alongside
-- Spawner.IsDecorClass(e.class), which independently and reliably catches every entry here anyway
-- (decorPathSet is built straight from these same categories' own `path` fields) -- confirmed by
-- reading that function, not assumed.
local function placeDecorEntry(d)
    local floorZ = playerFloorZ()
    -- spawn_menu.ini's curated label (Spawner.FriendlyLabels, main.lua) wins over config.lua's own
    -- `d.label`, since the ini tree is what RedFalcon actively renames -- falls back to d.label,
    -- then d.name, same as before this existed.
    local spawnLabel = (Spawner.FriendlyLabels and Spawner.FriendlyLabels[d.name]) or d.label or d.name
    local spot = frontSpot(300)
    local a = Spawner.Spawn(d.path, spawnLabel, spot)
    if not (a and a:IsValid()) then
        log("Decoration " .. d.name .. " failed — path may be wrong; probe a wild one for its class.")
        return
    end
    -- Item-drop decor entries (fkeys.lua's inventoryDrops category) carry a `mesh` field: a real
    -- static-mesh asset path, not a class path. Their shared class (R5LootActor) normally gets its
    -- mesh from a real drop event (LootView), which a generic spawn never gets — confirmed dead
    -- silent/invisible without this (see Spawner.SetLootMesh's own comment for why the business-
    -- rule route is unusable). Force the mesh, then immediately convert it to inert decor (no pickup
    -- prompt, no toss physics, no sparkle) the same way lbdecorloot handles an already-dropped item —
    -- these are meant to be pure set-dressing like every other decor category, not real pickups.
    if d.mesh then
        Spawner.SetLootMesh(a, d.mesh)
        Spawner.MakeLootDecor(a)
        -- Backfill persist.txt's field 16 (2026-08-19 fix, RedFalcon's bug report -- see
        -- spawner.lua's restoreOne, right where look.lootMesh gets reapplied, for the full root-
        -- cause writeup, including why that fix had to live there and not in a RESTORE_RULES entry).
        -- Spawner.Spawn already wrote the persist line for this actor by the time we get here, with
        -- no mesh recorded (it can't know about d.mesh, a testbed.lua-only concept) -- this call
        -- finds that SAME just-written line (by class+nearest-location, same as PersistUpdatePose)
        -- and adds the one field it was missing.
        pcall(function() Spawner.PersistUpdateLootMesh(d.path, spot, d.mesh) end)
    end
    -- These props float because their MESH sits offset above the actor's ROOT (placing the root on the
    -- ground leaves the mesh at chest height), and their bounds are unreliable so snapToFloor can't fix
    -- it. So place the root at floorZ + a per-entry `zoffset` (a starting guess; 0 = root on ground) and
    -- let the live-edit keys nudge it to sit right in the base — that edit persists. Record z0 (the
    -- placed Z) on the tracked entry so the live-edit log can report how far it was moved.
    -- Collision: DECOR_COLLISION on (default) makes the prop SOLID (SetDecorSolid enables collision +
    -- freezes physics, so it can't eject now that zoffset=0 keeps the root out of the terrain). Off =
    -- pass-through (the old behavior, when burying the root made physics shove the prop upward).
    if Config.DECOR_COLLISION == false then
        pcall(function() a:SetActorEnableCollision(false) end)
    else
        Spawner.SetDecorSolid(a)
    end
    -- CRITICAL: world props spawn as Static meshes, whose render transform is baked at registration —
    -- so the pin() below (and the live-edit keys) would update the actor's logical Z but NEVER move the
    -- mesh on screen, leaving it floating at the spawn height. Flip it Movable first so the pin lands.
    Spawner.MakeMovable(a)
    local z0 = floorZ and (floorZ + (d.zoffset or 0.0)) or nil
    local function pin()
        if not (a and a:IsValid() and z0) then return end
        pcall(function()
            local l = a:K2_GetActorLocation()
            a:K2_SetActorLocation({ X = l.X, Y = l.Y, Z = z0 }, false, {}, true)
        end)
    end
    pin()
    if ExecuteWithDelay then
        ExecuteWithDelay(600, function() ExecuteInGameThread(function() pcall(pin) end) end)
    end
    -- Tag the just-created tracked entry with its baseline Z (for the live-edit height read-out).
    local last = Spawner.spawned[#Spawner.spawned]
    if last and last.actor == a then last.z0 = z0 end
    return a
end

function Testbed.SpawnDecorCategory(cat)
    local cats = Config.DECOR_CATEGORIES or {}
    local list = cats[cat] or {}
    if #list == 0 then log("No decorations in category '" .. tostring(cat) .. "'."); return end
    decorIdx[cat] = (decorIdx[cat] or 0) % #list + 1
    local d = list[decorIdx[cat]]
    log(string.format("Decor[%s] %d/%d: %s", cat, decorIdx[cat], #list, d.name))
    placeDecorEntry(d)
end

-- ACTIVE DECOR CATEGORY (';'/''' -- see fkeys.lua): ''' advances which category is "active"
-- (wraps through Config.DECOR_ORDER, announced via toast/log so you know what ';' will place next)
-- without spawning anything; ';' places one entry from whichever category is currently active,
-- via the same Testbed.SpawnDecorCategory/decorIdx cursor a fixed per-category key would have used.
-- Resets to the first category (Config.DECOR_ORDER[1]) every load -- in-memory only, same as
-- decorIdx itself, not written to persist.txt.
local activeDecorIdx = 1
local function activeDecorCategoryName()
    local order = Config.DECOR_ORDER or {}
    if #order == 0 then return nil end
    return order[((activeDecorIdx - 1) % #order) + 1]
end

function Testbed.CycleDecorCategory()
    local order = Config.DECOR_ORDER or {}
    if #order == 0 then log("No decor categories configured (Config.DECOR_ORDER empty)."); return end
    activeDecorIdx = (activeDecorIdx % #order) + 1
    local name = order[activeDecorIdx]
    log("Decor category: " .. name)
    pcall(function() Spawner.Toast("Decor category: " .. name, 2.0) end)
end

function Testbed.SpawnActiveDecorCategory()
    local name = activeDecorCategoryName()
    if not name then log("No decor categories configured (Config.DECOR_ORDER empty)."); return end
    Testbed.SpawnDecorCategory(name)
end

-- By-name lookup (console validation, 2026-08-13) -- case-insensitive match against ANY decor
-- entry's `name` field, searched across every category in Config.DECOR_ORDER (first match wins;
-- names are unique per-category by construction but not checked across categories). Reuses
-- placeDecorEntry directly, so it's the exact same floor-placement/zoffset/collision recipe the
-- ';' key uses, not a raw spawn. Returns the spawned actor, or nil + a reason string on no match.
function Testbed.SpawnDecorByName(name)
    local cats = Config.DECOR_CATEGORIES or {}
    for _, catKey in ipairs(Config.DECOR_ORDER or {}) do
        for _, d in ipairs(cats[catKey] or {}) do
            if d.name:lower() == tostring(name):lower() then
                return placeDecorEntry(d)
            end
        end
    end
    return nil, "no decoration named '" .. tostring(name) .. "'"
end

-- (Fixed per-category wrapper functions removed 2026-08-13, replaced by the active-category
-- design above -- see Testbed.SpawnActiveDecorCategory / Testbed.CycleDecorCategory.)

-- rulesWithHelmet(baseRules, showHelmet) -- 2026-08-10: the "full armor" comparison entries in
-- Config.SENKAMATI_LOOKS need the SAME ruleset as the "no helmet" ones, minus whatever
-- hides/replaces the headdress/helmet -- rather than hand-duplicating every DECORRUPT_* table
-- into helmet/no-helmet pairs, filter out any hides/replaces entry whose match pattern targets
-- "_Head" at use time. Covers both treatments already in this file: Warrior/Hunter HIDE their
-- helmet piece outright; Caster/Healer REPLACE their Head (which IS their hair) with dreadlocks
-- (hiding it left them bald) -- both patterns contain "_Head", so one filter catches both.
-- BUG FIX (2026-08-11, RedFalcon's report: masked Senkamati "don't load properly" after the
-- persisted-row fix started restoring more of them, and more concurrently, than before).
-- showHelmet=false used to return baseRules COMPLETELY UNCHANGED -- the literal
-- Config.DECORRUPT_CREW_* / DECORRUPT_HUNTER / etc. table, shared by EVERY actor of that
-- character, helmet-on or off. Spawner.DeCorrupt caches resolved-asset and "already
-- replaced" state directly ON the rule objects (rp._targetNames, rp._meshes, sw._mat --
-- see its own comment) -- when a helmet=true actor and a helmet=false actor of the SAME
-- character get processed with overlapping timing (routine once restore can place several
-- Senkamati concurrently), they were mutating the SAME shared rule objects underneath each
-- other, exactly the class of cross-actor collision already found and fixed for the female
-- walkers' overlays this same day. Now ALWAYS deep-copies every swap/replace entry (hides
-- are plain strings -- immutable, safe to share) regardless of showHelmet, so no two calls
-- -- same character or not, same helmet flag or not -- ever share a mutable rule object.
local function deepCopyRuleList(list)
    local out = {}
    for i, item in ipairs(list or {}) do
        if type(item) == "table" then
            local copy = {}
            for k, v in pairs(item) do copy[k] = v end
            out[i] = copy
        else
            out[i] = item
        end
    end
    return out
end
local function rulesWithHelmet(baseRules, showHelmet)
    if not baseRules then return baseRules end
    local hides = deepCopyRuleList(baseRules.hides)
    local replaces = deepCopyRuleList(baseRules.replaces)
    if showHelmet then
        local filteredHides = {}
        for _, h in ipairs(hides) do
            if not tostring(h):find("_Head") then filteredHides[#filteredHides + 1] = h end
        end
        local filteredReplaces = {}
        for _, r in ipairs(replaces) do
            if not (r.match and r.match:find("_Head")) then filteredReplaces[#filteredReplaces + 1] = r end
        end
        hides, replaces = filteredHides, filteredReplaces
    end
    return { swaps = deepCopyRuleList(baseRules.swaps), hides = hides, replaces = replaces }
end

-- Senkamati MOB (Hunter/Caster) post-spawn: make passive + de-corrupt, retried while the
-- feather armor attaches late. Shared by the Num7 handler AND world-restore (restore only
-- re-runs Spawner.Spawn, so without this a reloaded Caster comes back corrupted + hostile).
-- showHelmet: keep the headdress/helmet visible (see rulesWithHelmet above). skipDecorrupt: for
-- the roster's final "as original" comparison row -- pacify/friendly-copy still runs (so it's
-- safe to stand next to), but the DeCorrupt pass is skipped entirely, leaving the mob's actual
-- corrupted look untouched ("full armor and corruption", the pre-de-corrupt appearance).
-- onDone (2026-08-11, optional): called exactly once, when the de-corrupt retry loop genuinely
-- concludes (converged or gave up) -- or immediately if there's no retry loop to wait for (no
-- actor, decorrupt skipped/disabled). Callers route this through Spawner.RunSerialized so no two
-- actors' composites are ever touched concurrently (see that function's own comment for why).
local function senkaMobFix(actor, name, shortName, showHelmet, skipDecorrupt, onDone)
    -- Idempotent (2026-08-16): the ExecuteWithDelay/ExecuteInGameThread nesting fix below can
    -- occasionally fire one redundant final retry tick (see that fix's own comment for why --
    -- the retry-continuation state it checks is a tick stale by design), which could otherwise
    -- call finish() a second time -- this codebase's own contract elsewhere promises onDone
    -- "called exactly once", so guard it here rather than trust every caller's onDone to already
    -- be safe to invoke twice.
    local finished = false
    local function finish()
        if finished then return end
        finished = true
        if onDone then pcall(onDone) end
    end
    if not (actor and actor:IsValid()) then finish(); return end
    -- Passivity comes from the FRIENDLY FACTION (a humanoid Senkamati treats crew/player as
    -- allies), plus MakePassive as backup. The faction copy needs a live crew to source
    -- from — on world restore it can miss at spawn time (crew not spawned yet), so re-apply
    -- it HERE too, not just MakePassive. Otherwise a reloaded Caster/Hunter stays hostile.
    local fp = Spawner.GetFriendlyFactionParams()
    -- The Caster summons witch totems that attack the player. The totems are separate actors and
    -- don't inherit her friendly faction, so they stay hostile. Remove ONLY the summon ability —
    -- her close-range AoE is fine and stays. Abilities can be granted late in BeginPlay, so this
    -- rides the same retry cadence as the faction/passive work below.
    local killAbilities = (name == "Caster-F") and Config.CASTER_DISABLE_ABILITIES or nil
    local function pacify()
        if Config.SENKAMATI_PASSIVE then pcall(function() Spawner.MakePassive(actor) end) end
        if Config.MAKE_CREATURES_FRIENDLY and fp then
            pcall(function() Spawner.MakeFriendly(actor, fp) end)
        end
        if killAbilities then
            pcall(function() Spawner.StripAbilities(actor, killAbilities, "Caster") end)
        end
    end
    pacify()
    if ExecuteWithDelay then
        local gen = Spawner.generation
        ExecuteWithDelay(2000, function()
            ExecuteInGameThread(function() pcall(function()
                if stillAlive(actor, gen) then pacify() end
            end) end)
        end)
    end
    if Config.DECORRUPT and ExecuteWithDelay and not skipDecorrupt then
        local rules = rulesWithHelmet((name == "Hunter") and Config.DECORRUPT_HUNTER or Config.DECORRUPT_MOB, showHelmet)
        local gen = Spawner.generation
        local tries, quiet = 0, 0
        -- Reflects the PREVIOUS completed attempt, not the one in flight -- doFixWork's own
        -- ExecuteInGameThread callback is async, so this is necessarily one tick stale by the
        -- time tryFix reads it (worst case: one extra retry beyond the ideal stopping point).
        local shouldContinue = true
        local function doFixWork()
            ExecuteInGameThread(function()
                if Spawner.generation ~= gen then
                    shouldContinue = false
                    finish()
                    return
                end
                local changed, comps = 0, 0
                pcall(function() changed, comps = Spawner.DeCorruptByClass(shortName, rules, actor) end)
                quiet = (changed == 0) and (quiet + 1) or 0
                tries = tries + 1
                local converged = ((comps or 0) >= 4) and quiet >= 2
                if not converged and tries < 12 then
                    shouldContinue = true
                else
                    shouldContinue = false
                    finish()
                end
            end)
        end
        -- CONFIRMED (2026-08-16): calling ExecuteWithDelay NESTED inside an ExecuteInGameThread
        -- callback throws "No overload found for function 'ExecuteWithDelay'" in this UE4SS build
        -- -- found investigating a launch crash in an unrelated feature (UnlockBuild's own retry
        -- timer, see main.lua's unlockTick/doWork fix), then audited across the whole codebase and
        -- found here too. doFixWork's ExecuteInGameThread call and tryFix's own ExecuteWithDelay
        -- call are siblings now, never nested.
        local function tryFix()
            doFixWork()
            if shouldContinue then
                ExecuteWithDelay(800, tryFix)
            end
        end
        -- Wait for the mob's composite to FINISH building before touching its meshes. At
        -- 1.2s the de-corrupt hit a still-building Caster/Hunter composite and crashed
        -- natively (same as the Warrior did until v1.81 pushed it to 4s).
        ExecuteWithDelay(Config.MOB_DECORRUPT_DELAY_MS or 4000, tryFix)
    else
        finish()
    end
end

-- Senkamati re-skin post-spawn (2026-08-10: now covers Warrior/Hunter/Caster/Healer, not just
-- the Warrior -- all four are re-skins of a human-skeleton base now, see
-- Config.SENKAMATI_LOOKS). Per-actor de-corrupt (weapon + hair + helmet), retried as the
-- composite attaches. `name` picks which ruleset matches this pawn's base (crew skin naming
-- for Warrior/Hunter, generic-human-female naming for Caster-F/Healer -- see each
-- Config.DECORRUPT_CREW_* table's own comment). Shared by handler + restore. showHelmet: see
-- rulesWithHelmet's own comment above senkaMobFix.
-- onDone (2026-08-11, optional): see senkaMobFix's own comment -- same contract, called exactly
-- once when this actor's de-corrupt + post-fix (leg-nudge, Warrior's shield) work is genuinely
-- done. Callers route this through Spawner.RunSerialized.
local function senkaCrewFix(actor, name, showHelmet, onDone)
    -- Idempotent (2026-08-16): the ExecuteWithDelay/ExecuteInGameThread nesting fix below can
    -- occasionally fire one redundant final retry tick (see that fix's own comment for why --
    -- the retry-continuation state it checks is a tick stale by design), which could otherwise
    -- call finish() a second time -- this codebase's own contract elsewhere promises onDone
    -- "called exactly once", so guard it here rather than trust every caller's onDone to already
    -- be safe to invoke twice.
    local finished = false
    local function finish()
        if finished then return end
        finished = true
        if onDone then pcall(onDone) end
    end
    if not (actor and actor:IsValid()) then finish(); return end
    if Config.CREW_PASSIVE then disarmRepeated(actor) end
    local rulesName = "DECORRUPT_CREW"
    local rules = Config.DECORRUPT_CREW
    local legPattern = "Warrior_Feather_%d+_Legs"
    if name == "Hunter" then
        rulesName, rules, legPattern = "DECORRUPT_CREW_HUNTER", Config.DECORRUPT_CREW_HUNTER, "Hunter_Feather_%d+_Legs"
    elseif name == "Caster-F" or name == "Healer" then
        rulesName, rules, legPattern = "DECORRUPT_CREW_FEMALE", Config.DECORRUPT_CREW_FEMALE, "Witch_Feather_%d+_Legs"
        -- Config.SENKA_FEMALE_BASE_CLASS (Handyman Gatherer) has her own idle/bark voice lines --
        -- silence them so a Caster/Healer doesn't talk like a townsfolk gatherer. No-op on
        -- Warrior/Hunter's crew base (StripVoice targets a component this Handyman-only pawn has).
        pcall(function() Spawner.StripVoice(actor) end)
    end
    rules = rulesWithHelmet(rules, showHelmet)
    -- Unconditional (2026-08-10 debugging): the only way to tell "picked the wrong/nil ruleset"
    -- apart from "picked correctly but it matched nothing" apart from "never even got called".
    print(string.format("[LivingBase] senkaCrewFix: name=%s rules=%s (%s)\n",
        tostring(name), rulesName, rules and "present" or "NIL"))
    if Config.DECORRUPT and ExecuteWithDelay then
        local gen = Spawner.generation
        local tries, quiet = 0, 0
        -- Outcome of the LAST completed iteration -- "continue" (keep retrying), "warrior_postfix"
        -- (converged, needs the shield-attach step scheduled), or "done" (finished, nothing left).
        -- One tick stale relative to the iteration in flight, same reasoning as every other fix in
        -- this pass -- see main.lua's unlockTick/doWork for the fuller explanation.
        local outcome = "continue"
        local function doFixWork()
            ExecuteInGameThread(function()
                local changed = 0
                pcall(function()
                    if stillAlive(actor, gen) then changed = Spawner.DeCorrupt(actor, rules) or 0 end
                end)
                print(string.format("[LivingBase] senkaCrewFix tryFix: name=%s try=%d changed=%d\n",
                    tostring(name), tries + 1, changed))
                quiet = (changed == 0) and (quiet + 1) or 0
                tries = tries + 1
                if quiet < 2 and tries < 10 then
                    outcome = "continue"
                    return
                end
                -- Settled. The de-corrupt already replaced hair (dreadlocks/mohawk) and swapped
                -- MI_Hair -> black. We no longer read the colour back and hide the hair when it
                -- didn't take (RedFalcon: "don't try to force baldness, it doesn't work"). A spawn
                -- who rolls light hair just gets respawned.
                --
                -- PELVIS GAP experiment (2026-08-10): see Spawner.NudgeComponentTransform's own
                -- comment. Runs once settled, on all four (not just the one currently being
                -- tested), so a config change applies uniformly next time any of them spawn.
                pcall(function()
                    Spawner.NudgeComponentTransform(actor, legPattern,
                        Config.SENKA_LEGS_NUDGE_SCALE, Config.SENKA_LEGS_NUDGE_OFFSET_Z)
                end)
                -- SHIELD: Warrior only -- Hunter/Caster/Healer never carried one to attach.
                if name == "Warrior" then
                    outcome = "warrior_postfix"
                else
                    outcome = "done"
                    finish()
                end
            end)
        end
        local function doWarriorPostFix()
            ExecuteInGameThread(function()
                if not stillAlive(actor, gen) then
                    print("[LivingBase] Warrior post-fix skipped: actor gone or untracked.\n")
                    finish()
                    return
                end
                local okShield, errShield = pcall(Spawner.AttachShield, actor)
                if not okShield then
                    print("[LivingBase] AttachShield failed: " .. tostring(errShield) .. "\n")
                end
                finish()
            end)
        end
        -- CONFIRMED (2026-08-16): calling ExecuteWithDelay NESTED inside an ExecuteInGameThread
        -- callback throws "No overload found for function 'ExecuteWithDelay'" in this UE4SS build
        -- (found investigating a launch crash in an unrelated feature, then audited across the
        -- whole codebase -- see main.lua's own unlockTick/doWork fix for the fuller writeup). This
        -- function used to nest TWO such violations (the retry itself, and the Warrior post-fix's
        -- own ExecuteWithDelay) -- doFixWork/doWarriorPostFix's ExecuteInGameThread calls and
        -- tryFix's own ExecuteWithDelay calls are all siblings now, never nested.
        local function tryFix()
            doFixWork()
            if outcome == "continue" then
                ExecuteWithDelay(800, tryFix)
            elseif outcome == "warrior_postfix" then
                ExecuteWithDelay(Config.WARRIOR_POSTFIX_MS or 1500, doWarriorPostFix)
            end
            -- outcome == "done": finish() already ran inside doFixWork's own callback.
        end
        -- Wait for the composite to FINISH building before touching its meshes. De-corrupting
        -- at 1.2s hit a half-built composite and crashed natively (~1.2s after spawn, no
        -- de-corrupt line logged). Give it longer to attach.
        ExecuteWithDelay(Config.WARRIOR_DECORRUPT_DELAY_MS or 4000, tryFix)
    else
        finish()
    end
end

-- senkaRowKey/parseSenkaRowKey (2026-08-11) -- same fix as the female walkers'
-- reskinTarget field, applied to Config.SENKAMATI_LOOKS: persist.txt previously had no way
-- to recall which of the 14 comparison rows a Senkamati actor was, so restore fell back to
-- a fixed default (de-corrupted, helmet hidden) regardless of the actual row -- see this
-- file's own RESTORE_RULES comment, and CLAUDE.md's "persist.txt format" section. name+kind
-- (+helmet, where it applies) uniquely identifies a row; encoded as a plain "|"-joined
-- string and threaded through the SAME persistAppend `reskinTarget` field the female
-- walkers use (Spawner.Spawn's compositeLook table doesn't care which feature put a value
-- there). Deliberately does NOT retry on missing pieces the way the female walkers do --
-- no toplessness has ever been observed on this group, so that risk/complexity isn't
-- justified here (RedFalcon's call).
-- BUG FIX (2026-08-11, RedFalcon's report: "on reload none of them end up with masks"). This
-- originally joined with "|" -- but persist.txt's own field parser (parsePersistLine,
-- spawner.lua) ALSO splits strictly on "|" between its 12 top-level fields, with no
-- escaping. A reskinTarget value of "Hunter|mob|true" doesn't survive as one field 12 --
-- it gets sliced into three, corrupting the split, so parts[12] comes back as just
-- "Hunter" and parseSenkaRowKey's pattern (expecting all three segments) never matches,
-- unconditionally returning nil after every reload. That's why EVERY masked row lost its
-- mask, not just ones colliding via DeCorruptByClass (see item 38) -- this predates and is
-- independent of that bug; both needed fixing. Switched the internal separator to "::",
-- which cannot collide with the outer "|" split and doesn't appear in any Senkamati
-- name/kind/boolean value.
-- `idle` field added (2026-08-15, RedFalcon's request) -- new frozen comparison rows needed a way
-- to tell themselves apart from the existing walking crew/mob rows of the SAME name+kind+helmet on
-- restore, same collision class this function's own history already warns about (baseLabel was
-- deliberately kept OUT of this key for exactly that reason -- but idle genuinely changes restore
-- behavior, unlike baseLabel, so it has to be threaded through here). Appended as a 4th segment
-- rather than inserted in the middle, so a pre-existing 3-segment key from before this field
-- existed simply fails to match parseSenkaRowKey's pattern and falls through to the already-
-- established "can't recover this row exactly" default -- no crash, no silent misparse.
local function senkaRowKey(s)
    return tostring(s.name) .. "::" .. tostring(s.kind) .. "::" .. tostring(s.helmet) .. "::" .. tostring(s.idle == true)
end
local function parseSenkaRowKey(key)
    if type(key) ~= "string" then return nil end
    local name, kind, helmetStr, idleStr = key:match("^(.+)::(.+)::(.+)::(.+)$")
    if not name then return nil end
    return { name = name, kind = kind, helmet = (helmetStr == "true"), idle = (idleStr == "true") }
end

-- senkaStatueRowKey/parseSenkaStatueRowKey/Config.SENKAMATI_STATUES REMOVED (2026-08-15) -- the
-- whole Senkamati Statues feature ('='/'-' keys) was purged: the "posed" kind's archetype-reroll
-- flashed through other body types on the way to a good one, which can expose bare skin/nipples
-- repeatedly -- an NSFW risk RedFalcon decided wasn't worth keeping once Num7's own frozen "idle"
-- rows (item 66) already cover the same "see a static look" need safely. See CLAUDE.md for the
-- full writeup. `freezeSenkaStatue` (below) is KEPT -- Num7's idle rows still depend on it.

-- Short, typeable key for one SENKAMATI_LOOKS entry -- e.g. "Warrior_crew_Mask",
-- "Hunter_mob", "Caster-F_corrupted". Distinct from senkaRowKey (the persist.txt identity,
-- "::"-separated, above) and rowLabel (the in-toast label, "SENKA_"-prefixed, below) -- this
-- one is specifically for the by-name console lookup (Testbed.SpawnSenkaByKey, 2026-08-13).
-- `baseLabel` (2026-08-14, optional field on a SENKAMATI_LOOKS row) is appended when present, so a
-- row using a non-default baseClass (e.g. the Herbalist-base Caster-F crew pair) gets a DISTINCT key
-- instead of colliding with name+kind+helmet-identical rows -- same class of bug already found and
-- fixed for the walking-woman "Herbalist" name (see FEMALE_RESKIN_TARGETS' own history in this file).
-- Every existing row has no baseLabel, so this is a no-op for all of them.
-- `_Idle` suffix (2026-08-15) -- same collision-avoidance reasoning as baseLabel above: the new
-- frozen comparison rows share name+kind+helmet with an existing walking row, so without this
-- they'd be indistinguishable in logs/toasts/lblook lookups.
local function senkaShortKey(s)
    return s.name .. "_" .. s.kind .. (s.baseLabel and ("_" .. s.baseLabel) or "") ..
        (s.helmet and "_Mask" or "") .. (s.idle and "_Idle" or "")
end
-- Exposed (2026-08-14) so main.lua's "lblook list senka" can build the SAME key instead of a
-- hand-duplicated format string that could silently drift from this one (exactly the kind of gap
-- that let the walking-woman "Herbalist" collision go unnoticed until live testing).
Testbed.SenkaShortKey = senkaShortKey

-- Forward-declared (2026-08-15): spawnSenkaEntry below needs freezeSenkaStatue for its new
-- `idle` rows, but that function isn't actually DEFINED until later in this file (it was written
-- for the statue roster, further down). A plain `local function freezeSenkaStatue(...)` down there
-- would create a NEW local from that point on -- spawnSenkaEntry, being defined earlier, would
-- resolve the name as an undeclared GLOBAL instead (nil, since nothing ever assigns one), and
-- crash the first time an `idle` row actually spawns. Standard Lua forward-reference fix:
-- pre-declare the local here (nil for now), then drop the `local` keyword at the real
-- definition site so it ASSIGNS to this same variable instead of shadowing it.
local freezeSenkaStatue

-- Spawn one specific Config.SENKAMATI_LOOKS entry -- shared by the rotation-driven Num7 key
-- (spawnCleanSenkamati, picks the next entry itself) and the by-name console lookup
-- (Testbed.SpawnSenkaByKey, 2026-08-13 -- see main.lua). Returns true/false, matching the
-- original function's own return contract (used as a success flag, not the actor itself).
local function spawnSenkaEntry(s)
    local helmetLabel = (s.kind ~= "corrupted") and (s.helmet and "full armor" or "no helmet") or "corrupted"
    log(string.format("Clean Senkamati: %s (%s, %s)", s.name, s.kind, helmetLabel))
    -- Spawn LABEL differentiated by kind + mask (2026-08-11, RedFalcon's request) -- "SENKA_Hunter"
    -- was identical across all 4+ Hunter rows regardless of kind/helmet, making them
    -- impossible to tell apart in logs/toasts/despawn prompts. Distinct from senkaRowKey
    -- (the persist.txt identity, above) -- this is purely for human-readable output.
    -- "SENKA_" .. senkaShortKey(s) (2026-08-14) -- was a second hand-written copy of the same
    -- name+kind+helmet format; reused senkaShortKey directly so baseLabel differentiation (see its
    -- own comment) can't drift between the lookup key and the display label the way it easily could
    -- if this stayed a separate inline format string.
    -- Prefer spawn_menu.ini's curated label (Spawner.FriendlyLabels, main.lua) over the mechanical
    -- "SENKA_<shortkey>" fallback -- see that table's own comment for the full mechanism.
    local rowLabel = (Spawner.FriendlyLabels and Spawner.FriendlyLabels[senkaShortKey(s)]) or ("SENKA_" .. senkaShortKey(s))

    if s.kind == "crew" then
        -- forceArchetype: Warrior/Hunter need the male Senkamati archetype pinned (their crew
        -- base otherwise rolls a random ethnicity). Caster-F/Healer's Handyman base is already
        -- female natively -- forcing the male-authored Config.SENKAMATI_ARCHETYPE onto her would
        -- rebuild her as male (see the RESULT note above), so those entries set
        -- forceArchetype=false and keep her own ArchetypePreset/BodyTypeParams untouched.
        local arche = s.forceArchetype and (s.archetype or Config.SENKAMATI_ARCHETYPE) or nil
        -- Pass the look as compositeLook: Spawner sets it PRE-BUILD (deferred window) so
        -- BeginPlay constructs the Senkamati armor from these params, AND records it to
        -- persist.txt so it comes back re-skinned on reload. makeFriendly=false: the crew base
        -- is already your faction, and the Handyman base isn't hostile to begin with.
        local look = { params = s.params, archetype = arche, sex = s.sex, reskinTarget = senkaRowKey(s) }
        local baseClass = s.baseClass or Config.WARRIOR_BASE_CLASS or Config.CREW_CLASS
        local ai = Config.SENKAMATI_HANDYMAN and Config.HANDYMAN_AI_CLASS or nil
        local actor = Spawner.Spawn(baseClass, rowLabel, frontSpot(300), nil, ai, nil, false, look)
        if not (actor and actor:IsValid()) then return false end
        -- `idle` (2026-08-15, RedFalcon's request) -- frozen counterpart to the normal walking
        -- crew row, added specifically as an NSFW-safer comparison option: the "posed" statue rows
        -- (the now-REMOVED Senkamati Statues feature) could flash bare skin/nipples repeatedly
        -- during their archetype reroll (item 60/61), and even a walking crew row is briefly nude
        -- while her composite
        -- layers build before de-corrupt catches up. Freezing doesn't eliminate that initial
        -- build-up flash (a rendering/composite-construction timing issue, unrelated to AI state),
        -- but it DOES stop her from walking around the base still exposed for the whole ~4.5s
        -- de-corrupt window -- same "freeze FIRST, unserialized, THEN de-corrupt" ordering already
        -- proven for the statue roster (freezeSenkaStatue's own comment explains why that order
        -- matters -- de-corrupting first let her "walk before stopping"). snapToFloor added to
        -- match the statue roster's own crew-kind handling, since a frozen pawn never gets the
        -- floor correction her own AI navigation would otherwise have applied.
        if s.idle then
            snapToFloor(actor, playerFloorZ())
            freezeSenkaStatue(actor)
        end
        -- Disarm + de-corrupt (weapon/hair/helmet). Same routine restore uses so a reloaded spawn
        -- comes back re-skinned, not as a plain crewman/gatherer. Routed through
        -- Spawner.RunSerialized (2026-08-11) so this actor's composite surgery never overlaps
        -- with another Senkamati/female-walker's own de-corrupt/reskin work -- see that
        -- function's own comment for the crash this fixes.
        Spawner.RunSerialized(function(done) senkaCrewFix(actor, s.name, s.helmet, done) end)
        return true
    elseif s.kind == "mob" or s.kind == "corrupted" then
        -- Both spawn the raw mob class (native Senkamati skeleton); "mob" still de-corrupts
        -- (clean skin/hair, original zombie-gait stance), "corrupted" skips that entirely (see
        -- senkaMobFix's own comment) to show the untouched, pre-de-corrupt appearance.
        local friendly = Config.MAKE_CREATURES_FRIENDLY == true
        local actor = Spawner.Spawn(s.mob, rowLabel, frontSpot(300), nil, nil, nil, friendly,
            { reskinTarget = senkaRowKey(s) })
        if not (actor and actor:IsValid()) then
            log("mob spawn FAILED (class unresolved?)")
            return false
        end
        snapToFloor(actor, playerFloorZ())
        -- `idle` (2026-08-15) -- see the crew branch's own comment above for why. The mob body is
        -- a single pre-baked skeletal mesh (already fully clothed in her corrupted look, not
        -- composite-built), so she was never at NSFW risk the way a crew-kind row can be -- this
        -- is offered mainly for parity/comparison with the new idle crew rows, and so a frozen mob
        -- look is available here too instead of only in the statue roster.
        if s.idle then freezeSenkaStatue(actor) end
        local shortName = s.mob:match("%.([%w_]+)$") or s.mob
        -- Spawner.RunSerialized (2026-08-11): see the crew branch's own comment above.
        Spawner.RunSerialized(function(done)
            senkaMobFix(actor, s.name, shortName, s.helmet, s.kind == "corrupted", done)
        end)
        return true
    end
    log("Unknown Senkamati kind: " .. tostring(s.kind))
    return false
end

local senkaIdx = 0
local function spawnCleanSenkamati()
    local list = Config.SENKAMATI_LOOKS or {}
    if #list == 0 then log("No Senkamati looks configured."); return false end
    senkaIdx = senkaIdx % #list + 1
    return spawnSenkaEntry(list[senkaIdx])
end

-- freezeSenkaStatue -- originally built for the now-REMOVED Senkamati Statues feature, kept
-- because Num7's frozen "idle" rows (item 66) depend on it too: Spawner.SetAILogic(actor, false)
-- stops the pawn's AIController logic (StopLogic), same proven mechanism this file already uses
-- to stall a following crew member's StateTree without freezing their MESH/animation, just their
-- movement/decision-making.
-- Called FIRST, immediately on spawn -- BEFORE senkaMobFix's/senkaCrewFix's de-corrupt pass, not
-- after (RedFalcon's report: "decorrupted idle walks for a bit before changing and stopping" --
-- the original order froze her only once de-corrupt's own retry loop fully converged, which can
-- take several seconds, so she visibly wandered the whole time; SetAILogic only touches the
-- AIController, nothing about it depends on or is depended on by the mesh/composite work de-corrupt
-- does, so there's no reason to wait). `tries`: the AIController may not have possessed the pawn in
-- the very same tick it was spawned, so a failed SetAILogic call retries a few times at a short
-- interval rather than giving up after one attempt -- same "poll with a bounded retry budget"
-- shape senkaMobFix/senkaCrewFix's own de-corrupt loops already use, just much shorter (this only
-- needs to catch a possession race, not wait out a multi-second composite build). onDone: called
-- exactly once, optional.
-- NOTE: no `local` here -- forward-declared above (near spawnSenkaEntry) so both share the SAME
-- variable instead of spawnSenkaEntry silently resolving an undeclared global.
function freezeSenkaStatue(actor, onDone, tries)
    -- Idempotent (2026-08-16): the ExecuteWithDelay/ExecuteInGameThread nesting fix below can
    -- occasionally fire one redundant final retry tick (see that fix's own comment for why --
    -- the retry-continuation state it checks is a tick stale by design), which could otherwise
    -- call finish() a second time -- this codebase's own contract elsewhere promises onDone
    -- "called exactly once", so guard it here rather than trust every caller's onDone to already
    -- be safe to invoke twice.
    local finished = false
    local function finish()
        if finished then return end
        finished = true
        if onDone then pcall(onDone) end
    end
    if not (actor and actor:IsValid()) then finish(); return end
    tries = tries or 0
    local gen = Spawner.generation
    -- Reflects the PREVIOUS completed attempt, not the one in flight -- see main.lua's
    -- unlockTick/doWork for why this is split this way (ExecuteWithDelay nested inside
    -- ExecuteInGameThread throws "No overload found" in this UE4SS build, confirmed 2026-08-16).
    local shouldRetry = true
    local function attempt()
        ExecuteInGameThread(function()
            if not stillAlive(actor, gen) then
                shouldRetry = false
                finish()
                return
            end
            local ok = false
            pcall(function() ok = Spawner.SetAILogic(actor, false) end)
            if ok then
                shouldRetry = false
                finish()
            elseif tries < 6 then
                shouldRetry = true
                tries = tries + 1
            else
                shouldRetry = false
                print("[LivingBase] freezeSenkaStatue: SetAILogic call failed after retries -- no AIController on this class? -- statue may still wander.\n")
                finish()
            end
        end)
    end
    local function tick()
        attempt()
        if shouldRetry and ExecuteWithDelay then
            ExecuteWithDelay(300, tick)
        end
    end
    tick()
end

-- applyStatueBodySwapTest/currentBodyMeshName/statueArchetypeTally/tallyAndLogArchetype/
-- shortArchetypeLabel/rerollStatueArchetype/spawnSenkaStatueEntry/SpawnNextSenkamatiStatue/
-- SpawnSenkaStatueStanding ALL REMOVED (2026-08-15) -- the entire Senkamati Statues feature
-- ('='/'-' keys, Config.SENKAMATI_STATUES) was purged. See the earlier removal note (above
-- freezeSenkaStatue) and CLAUDE.md for the full writeup -- the archetype-reroll mechanism this
-- machinery existed for could flash through other body types (bare skin/nipples) on the way to a
-- good one, an NSFW risk not worth keeping once Num7's own frozen "idle" rows cover the same need
-- safely. Spawner.CurrentBodyMeshName/Spawner.ShortArchetypeLabel (spawner.lua) are untouched --
-- still used by the plain Spawner.Spawn toast's body-type readout on every spawn, not statue-only.

-- By-key lookup (console validation, 2026-08-13) -- case-insensitive match against
-- senkaShortKey's format ("Warrior_crew_Mask", "Hunter_mob", "Caster-F_corrupted"); a leading
-- "SENKA_" (the in-toast label's own prefix) is accepted and stripped if present, so either
-- form works. Returns true/false (matching spawnSenkaEntry's own contract) or nil + a reason.
function Testbed.SpawnSenkaByKey(key)
    local wanted = tostring(key):gsub("^SENKA_", ""):lower()
    for _, s in ipairs(Config.SENKAMATI_LOOKS or {}) do
        if senkaShortKey(s):lower() == wanted then
            return spawnSenkaEntry(s)
        end
    end
    return nil, "no Senkamati look keyed '" .. tostring(key) .. "'"
end

-- freezeIdleOnRestore (2026-08-23, RedFalcon's report: "all the idle senkamati are walking
-- when restored again... they do eventually freeze, but they need to freeze immediately --
-- they are supposed to be frozen like statues"). ROOT CAUSE FOUND AND FIXED AT THE SOURCE:
-- this function only ever runs via RestoreHook, which doesn't fire until
-- Config.RESTORE_POSTPROCESS_MS (8s default) after every restored mover has already spawned
-- (see spawner.lua's scheduleRestorePostProcess comment -- that whole pipeline is gated that
-- late for de-corrupt/MakePassive/goat-strip's crash-prone component surgery). Every idle
-- Senkamati visibly walked for that entire 8+ second wait before this ever got called. The
-- REAL fix is now inline in spawner.lua's restoreOne -- SetAILogic(actor, false) fires
-- immediately, same frame as the spawn, same as decor's own physics/collision restoration
-- right next to it. This function (and its call sites in RESTORE_RULES below) are KEPT as a
-- secondary safety net / re-assertion -- harmless no-op once the immediate freeze has already
-- taken, in case that one somehow doesn't for a given actor. Logs success/failure of every
-- attempt (previously totally silent) so a re-occurrence shows real evidence in ue4ss.log
-- instead of guessing blind again.
local function freezeIdleOnRestore(actor)
    local gen = Spawner.generation
    local function pass(label)
        if not stillAlive(actor, gen) then return end
        local ok = false
        pcall(function() ok = Spawner.SetAILogic(actor, false) end)
        print(string.format("[LivingBase] freezeIdleOnRestore[%s]: SetAILogic(false) -> %s\n",
            label, tostring(ok)))
    end
    freezeSenkaStatue(actor, function() pass("initial") end)
    if ExecuteWithDelay then
        for _, delay in ipairs({ 3000, 8000, 15000 }) do
            ExecuteWithDelay(delay, function() pass(tostring(delay) .. "ms") end)
        end
    end
end

-- Called by Spawner.RestoreFromPersist for each re-created actor on WORLD LOAD. Restore
-- only re-runs Spawner.Spawn (which re-applies the pre-build look/faction/AI), so the
-- POST-spawn fixes — Senkamati de-corrupt/passivity, goat perception-strip — must be
-- re-applied here or reloaded spawns come back wrong (e.g. the corrupted, hostile Caster).
-- Restore dispatch. FIRST MATCHING RULE WINS, so order matters: the Warrior is a crew pawn
-- identified by its composite LOOK (not its class path), so it must be tested before the
-- generic /Mob/ rules would ever see it. Adding a creature = adding one row here.
local RESTORE_RULES = {
    -- Senkamati STATUE restore rule REMOVED (2026-08-15) -- the whole feature was purged, see
    -- freezeSenkaStatue's own removal note above.
    -- Row identity RECOVERED (2026-08-11) via the persisted reskinTarget field (see
    -- senkaRowKey/parseSenkaRowKey above) when present. Falls back to the OLD fixed-default
    -- behavior (de-corrupted, helmet hidden) only for a pre-1.3.x line that never recorded
    -- one -- (a) pre-2026-08-10 saves, back when Hunter/Caster/Healer ONLY spawned via the
    -- crew rule below, and (b) any Config.SENKAMATI_LOOKS row placed before this field
    -- existed. Re-place fresh via Num7 if an old save's row can't be exactly recovered.
    { name  = "Senkamati mob (original skeleton)",
      when  = function(cls) return cls:find("SenkamatiCorrupted") ~= nil end,
      -- Spawner.RunSerialized + Begin/EndAsyncPostProcess (2026-08-11): the crash fix (see
      -- Spawner.RunSerialized's own comment) AND closes a real gap this rule never had --
      -- unlike the female-walker rule below, this one never told scheduleRestorePostProcess it
      -- had async work outstanding, so "base restored" could already have fired before a
      -- restored Senkamati mob's de-corrupt retry loop actually finished.
      apply = function(actor, cls, look, short)
          -- idle (2026-08-15): freeze FIRST, unserialized, same ordering the live-spawn path uses
          -- (spawnSenkaEntry) and the same reason (SetAILogic doesn't touch composite/mesh state,
          -- no reason to make it wait behind de-corrupt). Parsed once here, ahead of the
          -- RunSerialized block below, purely so this one read isn't duplicated inside it.
          local preRow = parseSenkaRowKey(look and look.reskinTarget)
          if preRow and preRow.idle then freezeIdleOnRestore(actor) end
          Spawner.BeginAsyncPostProcess()
          local onDone = function() Spawner.EndAsyncPostProcess() end
          Spawner.RunSerialized(function(done)
              local row = parseSenkaRowKey(look and look.reskinTarget)
              local function bothDone() onDone(); done() end
              if row then
                  senkaMobFix(actor, row.name, short, row.helmet, row.kind == "corrupted", bothDone)
              else
                  senkaMobFix(actor, cls:find("Hunter") and "Hunter" or "Caster-F", short, false, false, bothDone)
              end
          end)
      end },
    { name  = "Senkamati re-skin (Warrior/Hunter/Caster/Healer)",
      when  = function(_, look)
          return look ~= nil and type(look.params) == "string"
             and look.params:find("Senkamati") ~= nil
      end,
      -- Spawner.RunSerialized + Begin/EndAsyncPostProcess (2026-08-11): see the mob rule's own
      -- comment above -- same crash fix, same restore-completion gap closed.
      apply = function(actor, cls, look)
          local p = look.params
          local nm = "Warrior"
          if p:find("Regular_Hunter") then nm = "Hunter"
          elseif p:find("Shaman_Caster") then nm = "Caster-F"
          elseif p:find("Shaman_Healer") then nm = "Healer" end
          -- Name is already correctly recovered from `params` above regardless of
          -- reskinTarget (that matching predates this field and stays as the primary
          -- source) -- the row key only fills in the ONE thing params can't tell us: the
          -- helmet flag. Falls back to hidden (the old fixed default) for a pre-1.3.x line.
          local row = parseSenkaRowKey(look.reskinTarget)
          -- idle (2026-08-15): see the mob rule's own comment above -- same freeze-first ordering.
          if row and row.idle then freezeIdleOnRestore(actor) end
          Spawner.BeginAsyncPostProcess()
          local onDone = function() Spawner.EndAsyncPostProcess() end
          Spawner.RunSerialized(function(done)
              senkaCrewFix(actor, nm, row and row.helmet or false, function() onDone(); done() end)
          end)
      end },
    -- Item-drop decor's own RESTORE_RULES entry REMOVED (2026-08-19, same session it was added):
    -- confirmed live it was unreachable dead code -- isStaticLine() (spawner.lua) routes every
    -- decor-class actor, R5LootActor drops included, into the restore loop's `statics` list, which
    -- gets spawned with collect=false specifically so a statics-heavy base skips a no-op post-
    -- process pass -- RestoreHook/this whole rules table never sees a decor actor at all, by
    -- design. The actual fix now lives inline in spawner.lua's restoreOne, right where pitch/roll
    -- and SetDecorSolid/MakeMovable already get the same immediate (not deferred) treatment for
    -- every decor actor -- see that block's own comment for the full root-cause writeup.
    -- Goats keep the perception-strip on restore — confirmed in-game that they DON'T flee
    -- with it. The strip is component-destruction, but running it after the world settles
    -- (deferred ~8s post-load) has not crashed.
    { name  = "goat",
      when  = function(cls) return cls:find("/Mob/Goat") ~= nil end,
      apply = function(actor) pacifyCreature(actor, "GOAT", Config.GOAT_DISABLE) end },
    { name  = "boar",
      when  = function(cls) return cls:find("/Mob/Boar") ~= nil end,
      apply = function(actor) pacifyCreature(actor, "BOAR", nil) end },
    -- Female walker re-skins (Numpad Decimal / Testbed.TestFemaleWalkerReskin) -- LAST in
    -- this list on purpose: the Senkamati Caster-F/Healer rule above also spawns this same
    -- class, and it already `return`s on its own match, so ordering alone keeps the two
    -- from colliding without needing an explicit exclusion here. Uses the persisted
    -- reskinTarget field (2026-08-11) to restore the SAME character/category if present;
    -- falls back to a random pick only for a pre-1.3.5 line that never recorded one.
    -- Begin/EndAsyncPostProcess (2026-08-11, RedFalcon's request): pairs so "base restored and
    -- ready" genuinely waits for this actor's full processing -- including any topless
    -- despawn/respawn retry chain and any time spent queued behind another actor of the
    -- same target -- see Spawner.BeginAsyncPostProcess's own comment.
    -- Spawner.RunSerialized (2026-08-11): see its own comment for the crash this fixes -- wraps
    -- the existing Begin/EndAsyncPostProcess pair rather than replacing it; they answer related
    -- but different questions (is restore still waiting on this actor? vs. is it safe to start
    -- touching the NEXT actor's composite yet?) and both release from the same onSettled point.
    { name  = "female walker re-skin",
      -- Broadened (2026-08-14) to also recognize Config.SENKA_FEMALE_BASE_CLASS_HERBALIST
      -- (Testbed.SpawnHerbalistWomanByName) -- without this, a restored Herbalist-based walker would
      -- come back as her plain default look, silently losing the randomized skin/hair reskin, since
      -- this was the ONLY thing deciding whether ANY female-walker post-process runs at all.
      when  = function(cls) return cls == Config.SENKA_FEMALE_BASE_CLASS
          or cls == Config.SENKA_FEMALE_BASE_CLASS_HERBALIST end,
      apply = function(actor, cls, look)
          -- BUG FIX (2026-08-19, RedFalcon: "vanilla herbalist/gatherer turns into the merchant
          -- on reload"). SENKA_FEMALE_BASE_CLASS/_HERBALIST are the SAME class paths whether an
          -- actor came from the reskin system or was spawned vanilla (lbspawn/lblook) directly --
          -- a vanilla spawn never threads a reskinTarget through persistAppend in the first
          -- place, so it looks IDENTICAL to a genuine pre-1.3.5 save missing the field (that
          -- field has existed since 2026-08-11, so that legacy case is essentially dead by now).
          -- The old fallback (Testbed.ApplyRandomFemaleLook, removed) couldn't tell the two
          -- apart and forced a RANDOM character reskin onto every vanilla spawn on every reload.
          -- Nothing persisted can disambiguate them, so the only safe default is to leave a
          -- reskinTarget-less actor as its own plain look -- a genuine ancient legacy save
          -- (increasingly unlikely) just shows as vanilla now instead of getting a random
          -- identity, which is a far better trade than corrupting every vanilla spawn.
          if not (look and look.reskinTarget) then return end
          Spawner.BeginAsyncPostProcess()
          Spawner.RunSerialized(function(done)
              local onSettled = function() Spawner.EndAsyncPostProcess(); done() end
              Testbed.ApplyFemaleReskinTarget(actor, look.reskinTarget, nil, onSettled)
          end)
      end },
}

function Testbed.RestoreHook(actor, classPath, look)
    if not (actor and actor:IsValid()) or type(classPath) ~= "string" then return end
    local short = classPath:match("([%w_]+)$")
    for _, rule in ipairs(RESTORE_RULES) do
        if rule.when(classPath, look) then
            local ok, err = pcall(rule.apply, actor, classPath, look, short)
            if not ok then
                log(string.format("RestoreHook [%s] failed: %s", rule.name, tostring(err)))
            end
            return
        end
    end
end

local plagueIdx = 0
function Testbed.SpawnNextPlague()
    if Config.PLAGUE_USE_CLEAN then
        spawnCleanSenkamati()
        return
    end
    local list = Config.PLAGUE_CREATURES or {}
    if #list == 0 then log("No plague creatures configured."); return end
    plagueIdx = plagueIdx % #list + 1
    local p = list[plagueIdx]
    log(string.format("Plague %d/%d: %s", plagueIdx, #list, p.name))
    if not spawnCreature(p.candidates, "PLAGUE_" .. p.name) then
        log("Plague " .. p.name .. " failed — F11 a real one to confirm its class.")
    end
end

------------------------------------------------------------
-- Villager key (own key while we iterate on it). Base = a random Handyman
-- townsman/woman: they walk, use furniture, and include real female bodies (crew
-- can't). Human body, so the Native skin swap + hair replace work. Garments are
-- re-skinned to a light tribal look (bare chest / bra, pants, barefoot).
------------------------------------------------------------
-- (Villager feature removed 2026-07-08: Hunter/Warrior/Caster cover the Senkamati,
-- and hair colour proved uncontrollable on AI pawns.)

-- Cycle a simple {faction, path} statue list, one per press (floor-snapped, no furniture).
local statueCyclers = {}
-- A statue faces TOWARD you by default (Spawner's nil-yaw default is playerYaw + 180); a rifler faces
-- the SAME way you do (playerYaw), showing you its back. Per-entry yaw corrections are baked in config.
-- The '\' key toggles a global 180-flip: statues turn their back to you, riflers turn to face you.
local facingFlipped = false

local function statueYaw(yaw)
    local base = yaw
    if base == nil then base = playerYaw() + 180.0 end
    if facingFlipped then base = base + 180.0 end
    return base % 360.0
end

function Testbed.ToggleStatueFacing()
    facingFlipped = not facingFlipped
    local msg = facingFlipped
        and "Statue facing: FLIPPED (statues face away, riflers face you)"
        or  "Statue facing: NORMAL (statues face you, riflers face away)"
    log(msg)
    Spawner.Toast(msg, 3.0)
end

-- Short class name a statue entry is identified by, everywhere (log lines, lblook by-name
-- matching): "/Game/.../BP_AnimatedActor_BotC_Merchant_01.BP_AnimatedActor_BotC_Merchant_01_C"
-- -> "BP_AnimatedActor_BotC_Merchant_01". Falls back to the faction string on a malformed path.
local function statueEntryName(w)
    return tostring(w.path):match("([%w_]+)%.[%w_]+$") or tostring(w.faction)
end

-- Place ONE statue-list entry -- shared by the rotation-driven cyclers (cycleStatues, index-
-- picked) and the by-name console lookups (Testbed.SpawnStandingByName/etc., 2026-08-13, for
-- lbspawn/lblook validation -- see main.lua). `label` is only used for the log line prefix here;
-- callers still track their OWN rotation cursor via cycleStatues, not this function.
local function placeStatueEntry(w, label, yaw)
    local nm = statueEntryName(w)
    -- Per-entry yaw correction. Posed AnimatedActors bake their facing into the animation, and about
    -- half of the sitters were authored facing the opposite way — so at one placement yaw they split
    -- ~50/50. `w.yaw` (usually 180) rotates just that entry so every sitter ends up facing the same
    -- direction. The name is logged on every spawn so the backwards ones can be identified and fixed.
    local placeYaw = statueYaw(yaw)
    if w.yaw then placeYaw = (placeYaw + w.yaw) % 360.0 end
    log(string.format("%s [%s]%s %s", label, tostring(w.faction),
        facingFlipped and " (flipped)" or "", nm))
    -- Prefer spawn_menu.ini's curated label (Spawner.FriendlyLabels, main.lua) over the mechanical
    -- "STANDING_<faction>"-style fallback -- see that table's own comment for the full mechanism.
    -- Statues have no human name field in Config at all, so this is the one roster where the
    -- fallback was never anything but a category+faction string, not a real name.
    local spawnLabel = (Spawner.FriendlyLabels and Spawner.FriendlyLabels[nm]) or (label:upper() .. "_" .. tostring(w.faction))
    return spawnPosed(w.path, spawnLabel, nil, placeYaw)
end

local function cycleStatues(list, label, yaw)
    list = list or {}
    if #list == 0 then log("No " .. label .. " statues configured."); return end
    local i = (statueCyclers[label] or 0) % #list + 1
    statueCyclers[label] = i
    log(string.format("%s %d/%d", label, i, #list))
    placeStatueEntry(list[i], label, yaw)
end

-- By-name lookup shared by the four public ByName functions below -- case-insensitive match
-- against the entry's short class name (statueEntryName, the same identifier logged/toasted on
-- every rotation-driven placement, so what you see in-game or in DISPLAY_NAMES.md IS what you type).
local function statueByName(list, label, name, yaw)
    for _, w in ipairs(list or {}) do
        if statueEntryName(w):lower() == tostring(name):lower() then
            return placeStatueEntry(w, label, yaw)
        end
    end
    return nil, "no " .. label .. " statue named '" .. tostring(name) .. "'"
end

-- Statue keys (numpad): Num3 standing / Num4 floor-sitter / Num5 chair-sitter / Num6 interactive.
-- Women + quest folk (QuestStatic NPCs) are folded into the STANDING roster.
function Testbed.SpawnNextStanding()    cycleStatues(Config.STANDING_STATUES,    "standing")    end
function Testbed.SpawnNextSeated()      cycleStatues(Config.SEATED_STATUES,      "seated")      end
-- NUM_FIVE: chair/stool sitters, split out of the floor sitters. Same cycler, its own list; no
-- furniture spawned (place your own stool — STATUE_IGNORE_FURNITURE lets it tuck underneath).
function Testbed.SpawnNextChairSeated() cycleStatues(Config.CHAIR_STATUES,       "chairseat")   end
-- Riflers face the SAME way you do (they rummage away from you, showing their back),
-- i.e. 180 deg from the toward-you default the other statues use.
function Testbed.SpawnNextInteractive() cycleStatues(Config.INTERACTIVE_STATUES, "interactive", playerYaw()) end

-- By-name console lookups (2026-08-13) -- one per statue list, matching cycleStatues' own label
-- and yaw handling for each. Returns the spawned actor, or nil + a reason string on no match.
function Testbed.SpawnStandingByName(name)    return statueByName(Config.STANDING_STATUES,    "standing",    name) end
function Testbed.SpawnSeatedByName(name)      return statueByName(Config.SEATED_STATUES,      "seated",      name) end
function Testbed.SpawnChairByName(name)       return statueByName(Config.CHAIR_STATUES,       "chairseat",   name) end
function Testbed.SpawnInteractiveByName(name) return statueByName(Config.INTERACTIVE_STATUES, "interactive", name, playerYaw()) end

-- TEMP DEV/TEST TOOL (2026-08-10, replacing TestFemaleStatueAI): giving the Handyman AI directly
-- to the posed FACTION_STATUES women (BotC_Female_Standing_01 / Female_Sitting_01-03) was tried
-- and CONFIRMED NOT TO WORK live in-game (no reason logged from this side — the game simply never
-- animated them; consistent with Config.HANDYMAN_FOR_CREW's own "crew given this brain just stand
-- there" precedent generalizing to a third pawn family, as that comment warned it might).
-- Trying the OTHER direction instead: reuse the ALREADY-PROVEN-WALKING female base
-- (Config.SENKA_FEMALE_BASE_CLASS, the Handyman Gatherer — confirmed walking/wandering/sitting for
-- Caster-F/Healer, see that config entry's own history) and dress HER in the same composite-mesh
-- reskin technique already proven for the Senkamati crew re-skins (spawnCleanSenkamati's "crew"
-- kind, the `params` field of compositeLook) — but pointed at Config.FACTION_VISITOR_LOOKS' own
-- "Brethren Woman" entry instead of a Senkamati armor composite, since that's the one female
-- FactionActor look already confirmed to resolve and render (it only ever failed on CREW_CLASS's
-- own male-locked body — see that entry's 2026-08-07 RESULT comment — a failure mode that doesn't
-- apply here: the Handyman Gatherer is natively female already, same reasoning as Caster-F's
-- forceArchetype=false). No AI override passed (Config.SENKAMATI_HANDYMAN is false, and doesn't
-- need to be true here anyway) — she keeps her own native Handyman brain, the thing that actually
-- walks. colorParams is deliberately NOT passed: FACTION_VISITOR_LOOKS' own comment confirms
-- setting it in this same pre-build window crashed the game outright; params-only, same as
-- Testbed.SpawnCrew. No snapToFloor call, matching the "crew" kind's own precedent in
-- spawnCleanSenkamati (a Handyman-family pawn spawns already grounded, unlike a posed statue).
-- Bound to the same Num-decimal test slot.
--
-- REAL PER-CHARACTER OVERLAYS (2026-08-10, same day): "I want Letty to look like Letty but
-- walking" — a live HOME+PAUSE probe on the walker plus Letty/Marita/the merchant/two statues
-- (see Config.FEMALE_WALKER_OVERLAYS' own comment for the full mesh-piece mapping) confirmed
-- they're all built from the same shared modular armor/hair library, so each target's real look
-- CAN be transplanted onto the walker — not just approximated with the one generic Brethren Woman
-- composite. After the base Brethren Woman spawn settles, this looks up
-- Config.FEMALE_WALKER_OVERLAYS by name and applies it via Spawner.DeCorrupt, retried on the same
-- settle-delay/quiet-convergence cadence senkaCrewFix already uses (a composite mesh takes a few
-- seconds to finish attaching; touching it too early is a proven native-crash risk elsewhere in
-- this file). "Brethren Merchant_04" was the original guess for "the merchant" —
-- corrected to "Buccaneers Merchant_01" after RedFalcon rescanned every candidate live and confirmed
-- she's the genuinely female-bodied one (Merchant_04 has a male body under women's clothing, a
-- baked-in game quirk noted in STANDING_STATUES' own comment).
-- Female_Sitting_02/03 dropped from the cycle (2026-08-10, RedFalcon's call) -- redundant next to
-- Sitting_01 (same plain Brethren Woman look, no overlay for any of the three sitting poses).
-- "Stripped" added (2026-08-10) as a 6th, diagnostic-only entry -- see its own comment on
-- Config.FEMALE_WALKER_OVERLAYS for what it's checking (the pelvis-gap question).
-- "TattooTest" REMOVED (2026-08-10) -- CONFIRMED LIVE to crash the game, reproduced twice in a
-- row. Applying Config.TATTOO_TEST_PARAMS (a PLAYER-only "Hero" CompositeMeshComponentParams
-- DataAsset) as an NPC's compositeLook.params is NOT safe -- whatever this DataAsset expects
-- (likely something only present on the player's own pawn/component setup, given the "Hero"
-- naming) isn't there on an NPC, and the native composite-build code doesn't fail gracefully.
-- DO NOT re-add this or try another Hero-prefixed CompositeMeshParams asset the same way without
-- a real theory for why it would behave differently -- treat "Hero_" composite params as
-- off-limits for NPC pawns via this mechanism. Config.TATTOO_TEST_PARAMS left in config.lua,
-- commented as unsafe, purely as a record of what was tried.
-- "Stripped" diagnostic entry REMOVED (2026-08-11, debug-tool cleanup) -- it existed only to
-- test whether the Senkamati pelvis-gap issue also affected this body. CONCLUDED 2026-08-10:
-- no gap on this body (see Config.FEMALE_WALKER_OVERLAYS' own former comment, kept in
-- archive/ if the write-up is wanted again) -- issue is specific to the Senkamati Feather_Legs
-- piece, not this skeleton. Nothing left to check for.
-- Renamed + reordered (2026-08-11, RedFalcon's request): "Female_Standing_01"/"Female_Sitting_01"
-- read as internal class-path leftovers in logs/toasts -- "Woman With Hat"/"Woman With Hair"
-- actually describe what the two generic slots look like. These strings ARE the persisted
-- reskinTarget value too (see persistAppend's own comment), not just a display label.
-- EVERY entry given Base 1/Base 2 variants (2026-08-14, RedFalcon's request -- "I want ALL the walking
-- women to have base 1 and base 2", after an initial cut only split the generic "Woman With Hair"
-- slot). Base 1 = the original Gatherer body (Config.SENKA_FEMALE_BASE_CLASS), Base 2 = the Herbalist
-- (Config.SENKA_FEMALE_BASE_CLASS_HERBALIST) -- see femaleBaseClassFor below for how the suffix picks
-- the body, and femaleCharacterKey (above releaseAndDrainTarget) for how "Letty Base 1"/"Letty Base 2"
-- both still dispatch to the SAME "Letty" overlay recipe (Config.FEMALE_WALKER_OVERLAYS) despite the
-- different names -- only WHICH BODY gets spawned differs; her outfit/hair-style rules are untouched
-- and unverified-but-expected to work on the Herbalist too (same broad Hat/Headband/Bandana content-
-- matching the generic slot already confirmed works on her, not per-character-hardcoded names).
-- Motivation: direct color/palette control on a pawn is a confirmed dead end in this game (see
-- CLAUDE.md's color-investigation writeup) -- different BASE CLASSES is the only way this mod can
-- give ANY of these looks genuine figure/hair-color/palette variety, since each class comes with its
-- own fixed default archetype baked in at construction. Room for a "Base 3" etc. later if another
-- suitable walking-female NPC class turns up -- femaleBaseClassFor would need a 3rd branch then.
-- MOVED to Config.FEMALE_RESKIN_TARGETS (2026-08-16) so spawnmenu_manifest.lua can enumerate it
-- into the LivingBaseSpawnMenu tree without a circular require -- see that Config entry's own
-- comment (config.lua, right after Config.FEMALE_WALKER_OVERLAYS) for the full story.
local FEMALE_RESKIN_TARGETS = Config.FEMALE_RESKIN_TARGETS
-- Exposed (2026-08-13) so main.lua's "lblook list" can read the real roster instead of a
-- hand-copied duplicate that could drift if this list ever changes.
Testbed.FEMALE_RESKIN_TARGETS = FEMALE_RESKIN_TARGETS
-- Which base pawn class a target name spawns, by its "Base N" suffix -- a plain suffix RULE now
-- (2026-08-14) rather than a per-name lookup table, since every entry follows the exact same pattern
-- (any name ending "Base 2" is the Herbalist, everything else -- "Base 1" or no suffix at all, e.g. a
-- pre-1.3.9 persisted reskinTarget -- is the Gatherer) rather than a one-off needing its own table row.
local function femaleBaseClassFor(targetName)
    if tostring(targetName):match("Base%s+2$") then return Config.SENKA_FEMALE_BASE_CLASS_HERBALIST end
    return Config.SENKA_FEMALE_BASE_CLASS
end
local femaleReskinIdx = 0

-- BUSY GUARD, PER TARGET NAME (2026-08-10, RedFalcon's theory, refined 2026-08-11 to cover
-- restore too). Spawner.DeCorrupt caches asset lookups and "already replaced" target
-- names ON THE RULE TABLE ITSELF (rp._mesh, rp._targetNames -- see its own comment), not
-- per-actor. If a SECOND walker using the SAME target's rules gets processed while the
-- FIRST one's retry loop (~4-8s) is still running, both loops read/write the SAME shared
-- rule-table cache -- the second actor's "has this been replaced yet" check could see
-- state left behind by the first actor and wrongly skip a swap it actually still needs.
-- Originally a single global flag (blocked ANY new placement while ANY one was
-- processing); now keyed per targetName instead, since a collision only actually happens
-- when the SAME named entry's shared `replaces`/`hides`/`forceHat` tables are touched
-- twice at once -- two DIFFERENT targets (or two generic rolls, which always build fresh
-- tables) can safely run concurrently. Needed a real key now that restore can process
-- several female walkers in the same load, not just the live key guarding against its own
-- rapid re-press.
local reskinTargetBusy = {}
-- QUEUE, not just a skip (2026-08-11, RedFalcon's report: "only the first entry of each type is
-- processed [on restore], the rest remain untouched"). Restore stages several actors close
-- together (Config.RESTORE_POSTPROCESS_SPACING_MS, ~400ms apart) while a single target's own
-- retry loop takes up to ~12s -- with a bare skip-and-return, every actor of the SAME target
-- that arrived while the first was still processing was simply abandoned forever, never
-- reprocessed. Queued actors are drained one at a time as each target's busy flag clears
-- (releaseAndDrainTarget below), so nothing gets silently dropped -- it just waits its turn.
-- NOTE (2026-08-11): since every call site now routes through Spawner.RunSerialized (see its
-- own comment -- the global one-composite-at-a-time crash fix), a second ApplyFemaleReskinTarget
-- call for the SAME targetName can no longer actually start while the first is still mid-flight
-- -- the global queue won't even begin the second one until the first calls its `done`, which
-- always happens AFTER this per-target busy flag has already cleared (see releaseAndDrainTarget's
-- call site inside ApplyFemaleReskinTarget). So in practice this queue should stay empty and
-- releaseAndDrainTarget's direct (non-RunSerialized) dequeue call below should never fire anymore
-- -- left in place as a harmless safety net rather than deleted, since removing it would silently
-- reintroduce the original "abandoned actor" bug if some future caller ever calls
-- ApplyFemaleReskinTarget directly, bypassing RunSerialized.
local reskinTargetQueue = {}

-- Strip a trailing " Base N" (any N) from a female-walker target name, recovering which
-- CHARACTER/overlay recipe it maps to independent of which base BODY it's using (2026-08-14, once
-- Letty/Marita/Merchant/"Woman With Hat" all gained Base 1/Base 2 variants too, not just "Woman With
-- Hair"). "Letty Base 1" and "Letty Base 2" both dispatch to the exact same "Letty" overlay
-- (Config.FEMALE_WALKER_OVERLAYS, or the "Woman With Hat"/generic-hair fallback) via THIS key --
-- only WHICH PAWN CLASS gets spawned differs, decided separately by femaleBaseClassFor below. The
-- parens truncate string.gsub's 2nd return (replacement count), which no caller here wants.
local function femaleCharacterKey(targetName)
    return (tostring(targetName):gsub("%s+Base%s+%d+$", ""))
end

-- Busy-guard/queue keys are the CHARACTER (femaleCharacterKey), not the full target name (2026-08-14).
-- The guard above exists because Spawner.DeCorrupt's shared rule-table cache collides when the SAME
-- named entry's `replaces`/`hides`/`forceHat` tables are touched twice at once -- "Letty Base 1" and
-- "Letty Base 2" read that IDENTICAL shared "Letty" table (namedOverlay is looked up from
-- Config.FEMALE_WALKER_OVERLAYS, never copied per-base), so they need to be serialized against EACH
-- OTHER too, exactly the collision this guard was built to prevent -- keying by the full name would
-- have let them run concurrently and silently reintroduced it.
-- Each queued item now carries its OWN targetName (2026-08-14) -- previously unnecessary, since the
-- queue itself was keyed by targetName so every item in one bucket was implicitly for the same target;
-- now that one bucket (one character) can hold a mix of "X Base 1"/"X Base 2" items, each needs its
-- own name preserved so releaseAndDrainTarget redispatches the RIGHT one, not whichever happened to be
-- the key.
local function releaseAndDrainTarget(characterKey)
    reskinTargetBusy[characterKey] = nil
    local q = reskinTargetQueue[characterKey]
    if not (q and #q > 0) then return end
    local nextItem = table.remove(q, 1)
    if nextItem.actor and nextItem.actor:IsValid() then
        Testbed.ApplyFemaleReskinTarget(nextItem.actor, nextItem.targetName, nextItem.retriesLeft, nextItem.onSettled)
    else
        if nextItem.onSettled then pcall(nextItem.onSettled) end
        releaseAndDrainTarget(characterKey)  -- actor died while queued -- skip to the next one
    end
end

-- Testbed.ApplyFemaleReskinTarget(actor, targetName, retriesLeft, onSettled) -- build and
-- apply the overlay for ONE of the 5 FEMALE_RESKIN_TARGETS entries, given its name. Shared
-- by the live TestFemaleWalkerReskin key AND the restore-on-reload path (RESTORE_RULES
-- below, reading the reskinTarget field persistAppend now writes) so a restored actor gets
-- the SAME category of look the live key would have given it. Skin tone (and, for the two
-- generic slots, hair style/hat) still re-rolls fresh every call -- matching how repeated
-- live presses already behave; only the CATEGORY (which character, or hat-vs-hair for the
-- generic slots) is what actually gets restored, since that's all persist.txt records.
-- onSettled (optional, 2026-08-11): called EXACTLY ONCE when this actor's full lifecycle --
-- across any queue wait, any topless despawn/respawn retry -- has genuinely concluded (not
-- when this one call returns, which can be long before the real end). Threaded through every
-- continuation (queue drain, retry respawn) rather than called per-invocation. RestoreHook
-- uses this to pair Spawner.BeginAsyncPostProcess()/EndAsyncPostProcess() correctly; the live
-- key passes nothing and doesn't need to.
function Testbed.ApplyFemaleReskinTarget(actor, targetName, retriesLeft, onSettled)
    retriesLeft = retriesLeft or 3
    if not (actor and actor:IsValid()) then
        if onSettled then pcall(onSettled) end
        return
    end
    -- characterKey (2026-08-14): what actually decides WHICH OVERLAY RECIPE applies and what the
    -- busy-guard/queue key on -- see femaleCharacterKey's own comment. targetName (full, with any
    -- " Base N" suffix) stays the one used for the Spawn label/persisted reskinTarget/every print
    -- below, so logs/toasts/persist.txt still say "Letty Base 2", not the collapsed "Letty".
    local characterKey = femaleCharacterKey(targetName)
    -- Config.FEMALE_CHARACTER_PARAMS fast path (2026-08-19) -- Letty/Marita/Merchant now spawn
    -- with their OWN real composite params (spawnFemaleWalkerTarget already did this), so the
    -- outfit is correct from the moment the actor is built -- no piece-replace/hide/forceHat
    -- overlay needed at all. That also means NO shared-rule-table collision risk (the whole
    -- reason the busy-guard/queue below exists), so this returns BEFORE touching either --
    -- fully independent of the namedOverlay/generic-hat/generic-hair system past this point.
    -- Just (1) preload Hairs/Eyebrows to this character's own real value -- the controller
    -- range belongs to the NEW outfit, not the walker's own base body, so her carried-over
    -- index would otherwise land in the wrong pool (confirmed live this session: a stale
    -- index rendered a visibly wrong hairstyle until corrected) -- and (2) layer randomized
    -- skin tone on top via the same swap-only Spawner.DeCorrupt call the overlay branches
    -- below use, proven fast/reliable on its own (see that branch's own comment: the retry
    -- loop exists for LATE-attaching hat/headwear timing, not for skin tone).
    local charParams = Config.FEMALE_CHARACTER_PARAMS and Config.FEMALE_CHARACTER_PARAMS[characterKey]
    if charParams then
        local skinFamily = Config.SKIN_FAMILIES[math.random(#Config.SKIN_FAMILIES)]
        local gen = Spawner.generation
        if not ExecuteWithDelay then
            if onSettled then pcall(onSettled) end
            return
        end
        -- Short settle delay (2026-08-19): the composite is built synchronously in the
        -- deferred pre-build window, so this is cheap insurance against a first-frame timing
        -- edge case, not a real wait for late-attaching components the way the old system's
        -- 4000ms initial delay was.
        ExecuteWithDelay(250, function()
            ExecuteInGameThread(function()
                pcall(function()
                    if not stillAlive(actor, gen) then return end
                    Spawner.StripVoice(actor)
                    -- charParams.hairs = a fixed preload (Letty/Marita/Merchant, whose OWN dedicated
                    -- outfit's controller pool doesn't match their carried-over index).
                    -- charParams.hairsRandomMax = a fresh random pick each spawn (Woman) -- the
                    -- shared composite's own build-time randomization covers Armor.*/skin but NOT
                    -- Hairs on this walking host (confirmed live), so it needs an explicit nudge;
                    -- confirmed live the controller write still picks a hat-compatible variant
                    -- correctly even when a hat rolled that spawn, no coordination risk.
                    if charParams.hairs then
                        Spawner.SetCustomizationController(actor, "hairs", charParams.hairs)
                    elseif charParams.hairsRandomMax then
                        Spawner.SetCustomizationController(actor, "hairs", math.random(0, charParams.hairsRandomMax))
                    end
                    if charParams.eyebrows then
                        Spawner.SetCustomizationController(actor, "eyebrows", charParams.eyebrows)
                    end
                    -- meshFixes (2026-08-19): per-BodyPart mesh overrides for a real body-shape
                    -- mismatch baked into this character's own params (see Config.
                    -- FEMALE_CHARACTER_PARAMS' own comment, Merchant's Legs piece specifically).
                    for _, fix in ipairs(charParams.meshFixes or {}) do
                        Spawner.SetBodyPartMesh(actor, fix.bodyPart, fix.mesh)
                    end
                    Spawner.DeCorrupt(actor, { swaps = Config.SkinFamilySwapRules(skinFamily) })
                end)
            end)
            if onSettled then pcall(onSettled) end
        end)
        return
    end
    if reskinTargetBusy[characterKey] then
        reskinTargetQueue[characterKey] = reskinTargetQueue[characterKey] or {}
        table.insert(reskinTargetQueue[characterKey],
            { actor = actor, targetName = targetName, retriesLeft = retriesLeft, onSettled = onSettled })
        -- Unconditional, not VERBOSE-gated -- troubleshooting output for a skip/retry path
        -- must not be silent (project convention; a log()-gated version of this exact retry
        -- logging gave zero signal on a real "still topless" report before this fix).
        print("[LivingBase] ApplyFemaleReskinTarget: '" .. tostring(targetName) ..
            "' already being processed for another '" .. characterKey .. "' actor -- queued (" ..
            tostring(#reskinTargetQueue[characterKey]) .. " waiting) to avoid " ..
            "Spawner.DeCorrupt's shared-rule-table cache colliding (see the busy-guard comment above).\n")
        return
    end
    local namedOverlay = nil
    for _, o in ipairs(Config.FEMALE_WALKER_OVERLAYS or {}) do
        if o.name == characterKey then namedOverlay = o; break end
    end
    local skinFamily = Config.SKIN_FAMILIES[math.random(#Config.SKIN_FAMILIES)]
    local overlay
    if namedOverlay then
        -- EXPERIMENT (2026-08-11, RedFalcon's request): randomized SKIN TONE layered on top of
        -- the named character's existing garment/hair rules via a shallow copy -- never
        -- mutate Config.FEMALE_WALKER_OVERLAYS itself (shared across every future spawn/
        -- restore of the same character; writing into it directly would leak whatever
        -- family THIS call happened to roll into every later one too). Hair STYLE stays
        -- fixed per character on purpose -- Letty keeps her ponytail, etc.
        overlay = {
            replaces = namedOverlay.replaces,
            hides = namedOverlay.hides,
            forceHat = namedOverlay.forceHat,
            swaps = Config.SkinFamilySwapRules(skinFamily),
        }
    elseif characterKey == "Woman With Hat" then
        -- Standing = ALWAYS a hat + a hairSTYLE from FEMALE_HAIR_STYLES_HAT -- the
        -- SuspendHat variant of that family, built by the game to sit correctly under a
        -- hat (the same mechanism Marita's Wig / the Merchant's ShortBob rely on).
        -- BUG FIX (2026-08-11, RedFalcon's report -- "spawn before processing is NOT topless"):
        -- Spawner.ForceHeadwear's positional grab was overwriting the TORSO when a spawn
        -- rolled with no natural headwear component at all (see its own comment). Content-
        -- matched `replaces` is the PRIMARY mechanism now -- safe, can only ever touch a
        -- component whose mesh name actually contains Hat/Headband/Bandana, same as every
        -- other DeCorrupt rule in this file. ForceHeadwear (now hardened to exclude every
        -- known non-headwear piece by name, see its own comment) only runs as a backup, for
        -- the rarer case where NOTHING matching those three patterns rolled at all.
        local chosenHat = Config.GENERIC_FEMALE_HATS[math.random(#Config.GENERIC_FEMALE_HATS)]
        local hairStyle = Config.FEMALE_HAIR_STYLES_HAT[math.random(#Config.FEMALE_HAIR_STYLES_HAT)]
        overlay = {
            swaps = Config.SkinFamilySwapRules(skinFamily),
            -- BUG FIX (2026-08-11, RedFalcon's report: "hair appears, then a hat, but then the
            -- hair is removed"). A same-pass ordering fix (Hair_ checked last) wasn't
            -- enough -- Spawner.DeCorrupt's retry loop re-evaluates every component's
            -- CURRENT mesh name on every pass, and several hairstyles' own names contain
            -- "Hat" (e.g. "SK_Hair_ShortBob_SuspendHat_Female"): pass 1 correctly sets the
            -- hair, but pass 2 reads that SAME name back, sees "Hat" in it, and the Hat rule
            -- fires AGAIN -- overwriting the just-placed hair with an actual hat mesh. Fixed
            -- properly this time by ANCHORING every pattern to "^SK_Armor_" -- every real
            -- headwear mesh in this game starts with that prefix, no hair mesh ever does
            -- (they all start "SK_Hair_"), so these rules can now never match a hair
            -- component on ANY pass, regardless of what "Hat"-like substring its name has.
            replaces = {
                { match = "Hair_", to = hairStyle.path },
                { match = "^SK_Armor_.*Hat", to = chosenHat },
                { match = "^SK_Armor_.*Headband", to = chosenHat },
                { match = "^SK_Armor_.*Bandana", to = chosenHat },
            },
            forceHat = chosenHat,
        }
    else
        -- "Woman With Hair" (or anything unrecognized) = NEVER a rigid hat/bandana, but a naturally-
        -- rolled HEADBAND is left alone -- RedFalcon's call: headbands are thin enough to be
        -- designed to coexist with regular hair (no clipping), unlike a full hat (needs the
        -- dedicated SuspendHat variant Standing uses) or the tight "Bandana" skullcap piece
        -- (confirmed clipping bug, see below) -- so only Hat/Bandana get hidden here now,
        -- Headband dropped from this list on purpose.
        -- BUG FIX (2026-08-11, confirmed via live HOME+PAUSE probes, two rounds): first
        -- round found "Female_Hat" never matches "..._Female_BandanaHat" (no "Female_Hat"
        -- substring in "Female_Banana"+"Hat" run together) -- broadened to plain "Hat".
        -- Second round found a THIRD naming convention slipping past even that: a plain
        -- "..._Female_Bandana" piece with neither "Hat" nor "Headband" in its name at all
        -- (reads as a tight skullcap under the hair). Added "Bandana". Both anchored to
        -- "^SK_Armor_" (same fix as Standing's replaces above) so neither can ever match a
        -- hair mesh's own name.
        local hairStyle = Config.FEMALE_HAIR_STYLES[math.random(#Config.FEMALE_HAIR_STYLES)]
        overlay = {
            swaps = Config.SkinFamilySwapRules(skinFamily),
            replaces = { { match = "Hair_", to = hairStyle.path } },
            hides = { "^SK_Armor_.*Hat", "^SK_Armor_.*Bandana" },
        }
    end
    pcall(function() Spawner.StripVoice(actor) end)
    if not ExecuteWithDelay then return end
    reskinTargetBusy[characterKey] = true
    local gen = Spawner.generation
    local tries = 0
    -- Reflects the PREVIOUS completed pass, not the one in flight -- see main.lua's
    -- unlockTick/doWork for why this whole function is split this way (ExecuteWithDelay nested
    -- inside ExecuteInGameThread throws "No overload found" in this UE4SS build, confirmed
    -- 2026-08-16). Three possible outcomes each pass: "continue" (keep looping the overlay
    -- pass), "done" (settled, onSettled already fired inside doWork), or "respawn" (the
    -- settle-check below wants a despawn+respawn retry -- the new actor/remaining retry count
    -- land in pendingRetryActor/pendingRetryRetries, and the recursive
    -- Testbed.ApplyFemaleReskinTarget call that owns firing onSettled happens from tick() below,
    -- OUTSIDE ExecuteInGameThread, not from inside doWork's own callback the way the original
    -- code called it directly).
    local outcome = "continue"
    local pendingRetryActor, pendingRetryRetries = nil, nil
    local function doWork()
        ExecuteInGameThread(function()
            pcall(function()
                if stillAlive(actor, gen) then Spawner.DeCorrupt(actor, overlay) end
            end)
            -- Positional guarantee (see Spawner.ForceHeadwear's own comment): re-applied
            -- every pass alongside the normal content-matched rules above, not instead of
            -- them -- idempotent (setting the same mesh twice is a no-op), so it's safe to
            -- just always run it for entries that opted in.
            if overlay.forceHat then
                pcall(function()
                    if stillAlive(actor, gen) then Spawner.ForceHeadwear(actor, overlay.forceHat) end
                end)
            end
            tries = tries + 1
            -- FIX (2026-08-11): no "stop after 2 quiet passes" early exit. The skin-tone
            -- swap succeeds fast and reliably, which made the loop think it had converged
            -- and quit BEFORE a late-attaching hat/headband had even shown up to be hidden
            -- -- the same class of late-attachment timing issue already documented for
            -- Senkamati armor elsewhere in this codebase. Always run the full budget.
            if tries < 10 then
                outcome = "continue"
                return
            end
            outcome = "done" -- overwritten below if a respawn retry gets queued instead
            releaseAndDrainTarget(characterKey)
            -- SETTLE-CHECK RETRY (2026-08-11, RedFalcon's requests): covers TWO ways a
            -- composite's random build can leave a spawn looking wrong, neither of
            -- which Spawner.DeCorrupt can ever fix directly (it can only replace/hide
            -- EXISTING components, never create one): (1) the Torso slot is entirely
            -- absent -- topless; (2) an overlay wanted a hat (`forceHat` set) but no
            -- headwear-ish component ever showed up to content-match OR for the
            -- (now-hardened) Spawner.ForceHeadwear to safely grab -- the hair is still
            -- styled FOR a hat but nothing's covering it, reading as bald. Once settled,
            -- check for both; if either is wrong, despawn and respawn the SAME target at
            -- the SAME spot, up to a few attempts, hoping the next roll fixes it.
            pcall(function()
                -- DIAGNOSTIC (2026-08-11): unconditional, not VERBOSE-gated -- a log()-
                -- gated version of this exact check gave zero signal on a real "still
                -- topless" report (VERBOSE defaults off), so there was no way to tell
                -- whether the check ever even ran. This line fires every time, torso
                -- found or not.
                local hasTorso = false
                pcall(function() hasTorso = Spawner.HasMeshMatching(actor, "Female_Torso") end)
                -- "HAT HAIR BUT NO HAT" (2026-08-11, RedFalcon's report: baldness spreading
                -- after the ForceHeadwear hardening). Any overlay with `forceHat` set
                -- pairs a hat-STYLED hair (SuspendHat/SuspendedHat/SuspendedBandana --
                -- geometry built assuming a hat covers the top) with an intended hat --
                -- if the content-matched replace found nothing to convert AND the now-
                -- hardened Spawner.ForceHeadwear had no safe fallback component either
                -- (see its own comment), the hat silently never lands, but the hair is
                -- STILL the hat-styled variant -- reads as bald/thin on top with nothing
                -- covering it. Only checked for overlays that actually wanted a hat.
                local needsHat = overlay.forceHat ~= nil
                local hasHat = false
                if needsHat then
                    pcall(function()
                        hasHat = Spawner.HasMeshMatching(actor, "^SK_Armor_.*Hat")
                            or Spawner.HasMeshMatching(actor, "^SK_Armor_.*Headband")
                            or Spawner.HasMeshMatching(actor, "^SK_Armor_.*Bandana")
                    end)
                end
                print(string.format(
                    "[LivingBase] ApplyFemaleReskinTarget: '%s' settle check -> hasTorso=%s needsHat=%s hasHat=%s retriesLeft=%d stillAlive=%s\n",
                    tostring(targetName), tostring(hasTorso), tostring(needsHat), tostring(hasHat),
                    retriesLeft, tostring(stillAlive(actor, gen))))
                -- settled: tracks whether THIS call resolved things itself (success, or
                -- gave up, or the actor died) vs. handed off to a recursive retry call
                -- that owns firing onSettled instead. Exactly one of the branches below
                -- ends up calling onSettled -- never zero, never twice.
                local settled = true
                local problem = (not hasTorso) or (needsHat and not hasHat)
                if stillAlive(actor, gen) and problem then
                    if retriesLeft > 1 then
                        print(string.format(
                            "[LivingBase] ApplyFemaleReskinTarget: '%s' rolled %s -- despawning and retrying (%d attempt(s) left).\n",
                            targetName,
                            (not hasTorso) and "without a Torso" or "hat-styled hair with no hat",
                            retriesLeft - 1))
                        local info = Spawner.DespawnActor(actor)
                        print("[LivingBase] ApplyFemaleReskinTarget: DespawnActor -> " ..
                            (info and "ok" or "FAILED (actor not tracked?)") .. "\n")
                        if info then
                            local entry = nil
                            for _, e in ipairs(Config.FACTION_VISITOR_LOOKS or {}) do
                                if e.name == "Brethren Woman" then entry = e; break end
                            end
                            if entry then
                                local newActor = Spawner.Spawn(info.class, targetName,
                                    info.home, nil, nil, info.yaw, false,
                                    { params = entry.params, reskinTarget = targetName })
                                if newActor and newActor:IsValid() then
                                    settled = false  -- the recursive call now owns onSettled
                                    pendingRetryActor, pendingRetryRetries = newActor, retriesLeft - 1
                                    outcome = "respawn"
                                else
                                    print("[LivingBase] ApplyFemaleReskinTarget: retry respawn FAILED.\n")
                                end
                            else
                                print("[LivingBase] ApplyFemaleReskinTarget: retry aborted -- no 'Brethren Woman' entry found.\n")
                            end
                        end
                    else
                        print(string.format(
                            "[LivingBase] ApplyFemaleReskinTarget: '%s' still %s after retries -- giving up, leaving as-is.\n",
                            targetName, (not hasTorso) and "topless" or "hat-styled hair with no hat"))
                    end
                end
                if settled and onSettled then pcall(onSettled) end
            end)
        end)
    end
    local function tick()
        doWork()
        if outcome == "continue" then
            ExecuteWithDelay(800, tick)
        elseif outcome == "respawn" then
            -- Recurses through this same function so a re-rolled actor gets the full overlay +
            -- its own settle-check too, not just a bare respawn. Dispatched via a short
            -- ExecuteWithDelay (never 0 -- see this fix's own header comment) rather than a
            -- direct call, since we're still dynamically inside doWork's ExecuteInGameThread
            -- callback at this point in a naive implementation; a real delay guarantees this
            -- fires from a genuinely separate, safe context.
            ExecuteWithDelay(10, function()
                Testbed.ApplyFemaleReskinTarget(pendingRetryActor, targetName, pendingRetryRetries, onSettled)
            end)
        end
        -- outcome == "done": onSettled already fired inside doWork's own callback.
    end
    ExecuteWithDelay(Config.MOB_DECORRUPT_DELAY_MS or 4000, tick)
end

-- Spawn a walking-woman reskin for a SPECIFIC target name -- shared by the rotation-driven
-- Numpad-decimal key (Testbed.TestFemaleWalkerReskin, picks the next target itself) and the
-- by-name console lookup (Testbed.SpawnFemaleWalkerByName, 2026-08-13 -- see main.lua). Not
-- restricted to FEMALE_RESKIN_TARGETS' own entries: Testbed.ApplyFemaleReskinTarget already
-- handles any unrecognized name via its own "Woman With Hair"-style fallback (see its own
-- comment), so an arbitrary name is safe to pass through here too.
local function spawnFemaleWalkerTarget(targetName)
    local entry = nil
    for _, e in ipairs(Config.FACTION_VISITOR_LOOKS or {}) do
        if e.name == "Brethren Woman" then entry = e; break end
    end
    if not entry then
        log("spawnFemaleWalkerTarget: no 'Brethren Woman' entry in Config.FACTION_VISITOR_LOOKS.")
        return nil
    end
    -- Which BODY to spawn -- see femaleBaseClassFor's own comment above.
    local baseClass = femaleBaseClassFor(targetName)
    -- reskinTarget (2026-08-11): threaded through Spawner.Spawn's compositeLook -> persistAppend
    -- -> parsePersistLine/restoreOne, so a reload can call Testbed.ApplyFemaleReskinTarget with
    -- the SAME targetName instead of guessing. See persistAppend's own comment on the new field.
    -- LABEL (2026-08-11, RedFalcon's request): use the roster name itself ("Letty", "Woman With Hat",
    -- etc.) instead of the old internal "TESTWALKRESKIN_<n>" placeholder -- this is also what the
    -- "Spawned: %s" toast (Spawner.Spawn's own comment) shows verbatim, so the toast now reads
    -- the character name instead of a meaningless index.
    -- Prefer spawn_menu.ini's curated label over targetName itself -- see Spawner.FriendlyLabels'
    -- own comment (main.lua) for the full mechanism. targetName is already human-readable, so this
    -- only matters if RedFalcon has since renamed the tree entry to something else.
    local spawnLabel = (Spawner.FriendlyLabels and Spawner.FriendlyLabels[targetName]) or targetName
    -- Config.FEMALE_CHARACTER_PARAMS (2026-08-19): Letty/Marita/Merchant spawn with their OWN real
    -- composite params instead of the shared Brethren Woman outfit -- see that table's own comment
    -- for why. Woman With Hat/Woman With Hair have an entry too (so Testbed.ApplyFemaleReskinTarget
    -- can take its fast path and skip the old overlay/retry system) but no `.params` of their own --
    -- they still default to entry.params (Brethren Woman) below, same outfit source as always,
    -- since that shared composite's own build-time randomization already covers their whole look.
    local charParams = Config.FEMALE_CHARACTER_PARAMS and Config.FEMALE_CHARACTER_PARAMS[femaleCharacterKey(targetName)]
    local outfitParams = (charParams and charParams.params) or entry.params
    local actor = Spawner.Spawn(baseClass, spawnLabel,
        frontSpot(300), nil, nil, nil, false, { params = outfitParams, reskinTarget = targetName })
    if not (actor and actor:IsValid()) then
        log("spawnFemaleWalkerTarget: spawn FAILED for " .. tostring(targetName))
        return nil
    end
    -- Spawner.RunSerialized (2026-08-11): see its own comment -- keeps a live placement from
    -- overlapping composite work with any Senkamati/other female-walker still mid-processing
    -- (e.g. a Num7 press moments earlier whose retry loop hasn't settled yet).
    Spawner.RunSerialized(function(done)
        Testbed.ApplyFemaleReskinTarget(actor, targetName, nil, done)
    end)
    return actor
end

function Testbed.TestFemaleWalkerReskin()
    femaleReskinIdx = femaleReskinIdx % #FEMALE_RESKIN_TARGETS + 1
    local targetName = FEMALE_RESKIN_TARGETS[femaleReskinIdx]
    log(string.format("TestFemaleWalkerReskin %d/%d: standing in for %s",
        femaleReskinIdx, #FEMALE_RESKIN_TARGETS, targetName))
    spawnFemaleWalkerTarget(targetName)
end

-- Testbed.TestApplyBodySex REMOVED (2026-08-15) -- was scaffolding for confirming Spawner.
-- ApplyBodySex's post-build comp:SetCharacterSex() call actually renders (it does -- see CLAUDE.md
-- item 64). That capability lives on as the `lbsexchange` console command (Spawner.
-- ApplySexChangeToNearest) instead of a dev key now that it's a confirmed, real feature.

-- Testbed.TestApplyBodyType() -- CONFIRMED LIVE (2026-08-15) TO CRASH THE GAME, reproduced twice
-- in a row -- see Spawner.ApplyBodyType's own comment for the full finding. No longer registered
-- to any key (see main.lua's removal note at the old register("testApplyBodyType", ...) call
-- site); kept here purely as a documented record, not for reuse.
function Testbed.TestApplyBodyType()
    local actor = Spawner._lastProbedActor
    if not (actor and actor:IsValid()) then
        log("TestApplyBodyType: no valid probed target -- press HOME on something first.")
        return
    end
    log("TestApplyBodyType: forcing Customization.Morph.BodyType.Albion")
    Spawner.ApplyBodyType(actor, "Customization.Morph.BodyType.Albion", 2, true)
end

-- Testbed.TestApplyPose REMOVED (2026-08-15) -- was scaffolding for the pose-porting investigation,
-- now CLOSED (CLAUDE.md item 63/65). Spawner.ApplyPose/ApplyBlueprintPose/MakePreBuildPoseSetter
-- are kept, undeployed, as documented reference.

-- By-name lookup (console validation, 2026-08-13) -- case-insensitive match against
-- FEMALE_RESKIN_TARGETS' full 10-entry roster (every character/look x Base 1/Base 2, 2026-08-14 --
-- see that array's own comment for the Base 1/Base 2 split and femaleBaseClassFor for how the suffix
-- picks the body). Returns the spawned actor, or nil + a reason string on no match.
-- A SHORT-LIVED "Herbalist Woman"/Testbed.SpawnHerbalistWomanByName lblook-only entry existed here
-- for a few minutes this same day, spawning the Herbalist base with no roster integration -- removed
-- immediately once "Woman With Hair Base 2" (this same function, no special-casing needed) made it
-- fully redundant. Kept only as a historical note in CLAUDE.md, not as dead code here.
function Testbed.SpawnFemaleWalkerByName(name)
    for _, targetName in ipairs(FEMALE_RESKIN_TARGETS) do
        if targetName:lower() == tostring(name):lower() then
            return spawnFemaleWalkerTarget(targetName)
        end
    end
    return nil, "no walking-woman target named '" .. tostring(name) .. "'"
end

-- Testbed.SpawnBarbieByName(name) -- named lblook-only look (2026-08-13, "Female_Barbie").
-- Spawns the same walking-woman base (SENKA_FEMALE_BASE_CLASS + the "Brethren Woman" params)
-- spawnFemaleWalkerTarget uses, but instead of calling Testbed.ApplyFemaleReskinTarget to dress
-- her, runs its own retry loop HIDING every armor piece as it attaches (broad "^SK_Armor_"
-- pattern -- every real armor mesh in this game uses that prefix, confirmed by the ANCHORING fix
-- noted in ApplyFemaleReskinTarget's own comment -- this also covers hats, which are named
-- SK_Armor_*Hat) so only her base body + hair stays visible; hair meshes are SK_Hair_-prefixed,
-- untouched by this pattern, so she always keeps her hair and never a hat.
-- Deliberately lblook-only -- no numpad key of its own, not part of the Numpad-. walking-women
-- rotation, reachable only via `lblook Female_Barbie` (see LBLOOK_CATEGORIES in main.lua).
-- Spawner.DeCorrupt refuses to ever touch the player pawn (its own NEVER-de-corrupt-player
-- guard), so this can't affect anyone but this one spawned actor.
function Testbed.SpawnBarbieByName(name)
    if tostring(name):lower() ~= "female_barbie" then
        return nil, "no lblook-only look named '" .. tostring(name) .. "'"
    end
    local entry = nil
    for _, e in ipairs(Config.FACTION_VISITOR_LOOKS or {}) do
        if e.name == "Brethren Woman" then entry = e; break end
    end
    if not entry then
        log("SpawnBarbieByName: no 'Brethren Woman' entry in Config.FACTION_VISITOR_LOOKS.")
        return nil, "internal: missing Brethren Woman params"
    end
    local actor = Spawner.Spawn(Config.SENKA_FEMALE_BASE_CLASS, "Female_Barbie",
        frontSpot(300), nil, nil, nil, false, { params = entry.params })
    if not (actor and actor:IsValid()) then
        log("SpawnBarbieByName: spawn FAILED.")
        return nil, "spawn failed"
    end
    local gen = Spawner.generation
    local tries = 0
    -- Split into doWork()/tick() -- see main.lua's unlockTick for why: ExecuteWithDelay called
    -- from directly inside an ExecuteInGameThread callback throws "No overload found" in this
    -- UE4SS build (confirmed 2026-08-16). tick() is only ever invoked from outside that callback
    -- (the initial call below, or ExecuteWithDelay's own timer callback), never nested within it.
    local shouldContinue = true
    local function doWork()
        ExecuteInGameThread(function()
            pcall(function()
                if stillAlive(actor, gen) then
                    local changed = Spawner.DeCorrupt(actor, { hides = { "^SK_Armor_" } })
                    log(string.format("Female_Barbie strip pass %d: %d change(s).", tries + 1, changed or 0))
                end
            end)
            tries = tries + 1
            shouldContinue = tries < 10
        end)
    end
    local function tick()
        doWork()
        if shouldContinue and ExecuteWithDelay then
            ExecuteWithDelay(800, tick)
        end
    end
    tick()
    return actor
end

-- Testbed.TestColorRandomization REMOVED (2026-08-11, debug-tool cleanup). It was a
-- standalone test spawn (not a real look) built to answer three feasibility questions:
-- can hair/outfit color, skin tone, and hair style be changed on these walkers? Findings,
-- kept here since the tool itself is gone:
--   - hair/outfit COLOR tint (Spawner.SetColorControllerValue) and garment PALETTE swap
--     (comp.ColorParams) are both DEAD for post-spawn use -- confirmed to set + read back
--     correctly but never visibly render (a build-time-only input).
--   - ColorParams set PRE-build reproduces a CONFIRMED FATAL native crash (already known
--     from 2026-08-07 on CREW_CLASS, now also confirmed on this class) -- do not retry on
--     ANY class without a genuinely new theory.
--   - skin TONE (material swap between the game's 7 ethnicity families) and hair STYLE
--     (mesh swap) both work fine via Spawner.DeCorrupt's existing swaps/replaces paths --
--     the roster tables that drove this tool (Config.SKIN_FAMILIES/SkinFamilySwapRules/
--     FEMALE_HAIR_STYLES) were removed with it, but the technique is proven and cheap to
--     redo if a real feature ever wants skin/hair variety on these walkers.

-- F9 (2026-07-08): remove the single spawn you're standing in front of, so you can walk
-- around cleaning up specific placements instead of undo-ing the whole list in order.
function Testbed.DespawnInFront()
    Spawner.DespawnNearestInFront(Config.DESPAWN_FRONT_UU or 700.0)
end

function Testbed.Cleanup()
    Spawner.DespawnAll()
end

return Testbed
