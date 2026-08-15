--[[
 LivingBase / whistle.lua — BOAR WHISTLE SUMMONS CREW (anchor method)

 WHAT THE WHISTLE ACTUALLY IS (settled 2026-07-09, the hard way):
   There is NO UR5PetSummonParams in this game — FindAllOf returned nothing, repeatedly. The whistle
   spawns BP_Mob_Boar_Friend directly. Confirmed independently by the PlagueWitchPet Nexus mod,
   whose pak replaces exactly BP_Mob_Boar_Friend.uasset and touches no summon params at all.
   Our earlier PetSummon patch could never have worked.

 THE ANCHOR METHOD (RedFalcon's call):
   Overwriting the pet asset needs a cooked pak. From Lua we instead let the game summon its boar,
   then immediately turn that boar into an invisible, collision-free, damage-immune ANCHOR and spawn
   crew beside it. The anchor keeps holding everything the game owns — the pet timer
   (GE_Mob_Boar_Friend_KillTimer), the item cooldown, the dismiss/re-summon bookkeeping. We never
   fight that logic. When the anchor dies or is dismissed, we remove the crew with it.

 Detection is FREE: NotifyOnNewObject(classPath, cb) fires the instant the boar is constructed.
 No polling. The only cost is the crew spawns themselves.

 The escort is TRANSIENT (never persisted; a reload must not resurrect a finished summon) and
 COMBATANT (killable — otherwise it's two immortal crewmen). It is labelled WHISTLE_CREW.
]]

local Config = require("config")
local Spawner = require("spawner")

local Whistle = {}
Whistle.anchors = {}       -- [anchorKey] = { anchor = <boar>, crew = { <actor>, ... } }
Whistle._installed = false

local function out(msg) print(string.format("[LivingBase:Whistle] %s\n", tostring(msg))) end

local function keyOf(o)
    local k = "?"
    pcall(function() k = o:GetFullName() end)
    return k
end

--------------------------------------------------------------------
-- Turn the game's summoned boar into an invisible anchor.
--------------------------------------------------------------------
local function makeAnchor(boar)
    -- Invisible.
    pcall(function() boar:SetActorHiddenInGame(true) end)
    -- Collision OFF (RedFalcon): nothing should bump into, block, or target a boar that isn't there.
    pcall(function() boar:SetActorEnableCollision(false) end)

    -- ⚠ DO NOT MAKE THE ANCHOR IMMUNE. v2.22 applied GE_Mob_Mob_ImmuneToDamage here, and
    -- GE_Mob_Boar_Friend_KillTimer ends the pet by DEALING DAMAGE — so the timer could never fire,
    -- the anchor never died, and RedFalcon was left with a permanent invisible Truffles plus an escort
    -- that was never dismissed. The whole point of the anchor is that the game's timer still works.

    -- Nameplate + health bar follow the marker component, not the mesh, so hiding the actor is not
    -- enough — RedFalcon could still see "Truffles" and a health bar by walking close.
    pcall(function() Spawner.HideNameplate(boar) end)

    -- Disarm it, and take away its senses so nothing bothers targeting a boar that isn't there.
    pcall(function() Spawner.MakePassive(boar) end)
    for _, comp in ipairs({ "MemoryComponent", "R5AgentComponent", "TargetLock_TargetComponent" }) do
        pcall(function() Spawner.StripComponent(boar, comp) end)
    end
end


--------------------------------------------------------------------
-- Spawn the crew escort beside the anchor.
--------------------------------------------------------------------
local function escortSpots(loc, n)
    local spots, spread = {}, Config.WHISTLE_CREW_SPREAD_UU or 120
    for i = 1, n do
        -- Fan them out either side of the anchor rather than stacking them.
        local off = (i - (n + 1) / 2) * spread
        spots[i] = { X = loc.X + off, Y = loc.Y, Z = loc.Z }
    end
    return spots
end

--- Who does a pet follow? Its OWNER. The game sets that on the summoned boar; our crew are spawned
--- ownerless, so the pet controller would have nobody to trail. Inherit the boar's owner, and fall
--- back to the player pawn if the boar carries none.
local function ownerOf(boar)
    local owner = nil
    pcall(function() owner = boar:GetOwner() end)
    if owner and owner:IsValid() then return owner end
    pcall(function()
        local UEHelpers = require("UEHelpers")
        local pc = UEHelpers.GetPlayerController()
        owner = pc and pc:IsValid() and pc.Pawn or nil
    end)
    if owner and owner:IsValid() then return owner end
    return nil
end

local function adoptAsPet(actor, owner)
    if not (owner and owner:IsValid()) then return false end
    local ok = pcall(function() actor.Owner = owner end)
    -- Ownership drives faction inheritance too; without it a "pet" can read as neutral.
    pcall(function()
        local oc = actor.OwnershipComponent
        if oc and oc:IsValid() then oc.bShouldUseOwnerFaction = true end
    end)
    return ok
end

local function spawnEscort(boar, anchorKey)
    local loc = nil
    pcall(function() loc = boar:K2_GetActorLocation() end)
    if not loc then out("Anchor had no location; escort skipped.") return end
    local owner = ownerOf(boar)

    local n = Config.WHISTLE_CREW_COUNT or 2
    local spots = escortSpots(loc, n)
    local i = 0

    local function step()
        i = i + 1
        if i > n then return end
        ExecuteInGameThread(function()
            local rec = Whistle.anchors[anchorKey]
            -- The anchor can die (timer, dismiss) between staggered spawns.
            if not (rec and rec.anchor and rec.anchor:IsValid()) then
                out("Anchor gone mid-spawn; escort aborted.")
                return
            end
            Spawner.transient = true     -- never persisted
            Spawner.combatant = true     -- killable, not set-dressing
            -- The crew keep their OWN brain by default, which is why they stand and fight rather
            -- than follow. WHISTLE_PET_AI hands them the boar's pet controller so they trail the
            -- player like Truffles did. A mismatched brain has frozen pawns before (the crew brain
            -- froze goats), so it is opt-in.
            local ai = Config.WHISTLE_PET_AI and Config.WHISTLE_PET_AI_CLASS or nil
            local ok, actor = pcall(function()
                return Spawner.Spawn(Config.WHISTLE_CREW_CLASS, "WHISTLE_CREW",
                    spots[i], nil, ai, nil, true, nil)   -- makeFriendly = true: they fight for you
            end)
            Spawner.transient = false
            Spawner.combatant = false
            if ok and actor and actor:IsValid() then
                -- Make them the player's pet, so the pet brain has someone to follow.
                if Config.WHISTLE_PET_AI then
                    local adopted = adoptAsPet(actor, owner)
                    if i == 1 then
                        out(adopted and "Escort adopted as pets (following)."
                                     or "Escort has no owner — they will stand and fight, not follow.")
                    end
                end
                rec.crew[#rec.crew + 1] = actor
            else
                out("Escort crewman " .. i .. " failed to spawn.")
            end
        end)
        -- STAGGER. Two composite builds in one frame is a native crash (this is why
        -- SPAWN_DEBOUNCE_MS exists). Set WHISTLE_CREW_STAGGER_MS = 0 to force same-frame.
        local gap = Config.WHISTLE_CREW_STAGGER_MS or 250
        if i < n and gap > 0 and ExecuteWithDelay then
            ExecuteWithDelay(gap, step)
        elseif i < n then
            step()
        end
    end
    step()
end

--------------------------------------------------------------------
-- FOLLOW. The crew keep their OWN controller (swapping in the boar's pet brain froze them solid,
-- exactly as our goat notes warned). Instead we hand that controller a destination on a slow tick:
-- SimpleMoveToActor(controller, player). They still fight, because their own brain is intact.
--
-- The PlagueWitchPet mod never solved this either — its pet follows only because its pak replaces
-- BP_Mob_Boar_Friend in place, keeping the pet's own AI. Its one movement call is an emergency warp
-- at 80m, which is what WHISTLE_WARP_UU reproduces.
--------------------------------------------------------------------
local function dist2(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return dx * dx + dy * dy + dz * dz
end

--- Every step below can fail silently. "They didn't follow and didn't warp" told us nothing, and the
--- warp is pure arithmetic — no AI, no engine call — so if it never fired, this function never ran
--- or rec.crew was empty. WHISTLE_FOLLOW_DEBUG makes each tick report exactly where it stops.
local function followTick(rec)
    local dbg = Config.WHISTLE_FOLLOW_DEBUG
    if not Config.WHISTLE_FOLLOW then
        if dbg then out("followTick: WHISTLE_FOLLOW is off") end
        return
    end
    local player = nil
    pcall(function()
        local UEHelpers = require("UEHelpers")
        local pc = UEHelpers.GetPlayerController()
        player = pc and pc:IsValid() and pc.Pawn or nil
    end)
    if not (player and player:IsValid()) then
        if dbg then out("followTick: no player pawn") end
        return
    end

    local ploc = nil
    pcall(function() ploc = player:K2_GetActorLocation() end)
    if not ploc then
        if dbg then out("followTick: no player location") end
        return
    end

    local n = #rec.crew
    if n == 0 then
        if dbg then out("followTick: rec.crew is EMPTY — escort was never recorded") end
        return
    end

    local start = (Config.WHISTLE_FOLLOW_START_UU or 700)
    local warp  = (Config.WHISTLE_WARP_UU or 8000)

    -- Match the player's PACE: compute a target speed from his current velocity once per tick, so the
    -- crew walk when he walks and sprint when he sprints (their ~110 walk cap is why they lagged).
    local paceSpeed = nil
    if Config.FOLLOW_MATCH_PACE then
        local ps = 0.0
        pcall(function()
            local v = player:GetVelocity()
            ps = math.sqrt((v.X or 0.0) ^ 2 + (v.Y or 0.0) ^ 2)
        end)
        paceSpeed = math.max(Config.FOLLOW_SPEED_MIN or 250.0,
                       math.min(Config.FOLLOW_SPEED_MAX or 900.0,
                                ps + (Config.FOLLOW_PACE_MARGIN or 150.0)))
    end

    for i, c in ipairs(rec.crew) do
        if c and c:IsValid() then
            local cloc = nil
            pcall(function() cloc = c:K2_GetActorLocation() end)
            if not cloc then
                if dbg then out(string.format("followTick: crew %d has no location", i)) end
            else
                -- One follow-state table per crew member: plain data, owned by us. Spawner.Follow
                -- uses it to remember TrackActor is already running for this pawn, because
                -- re-issuing a move order every tick restarts pathfinding and they never step.
                rec.follow = rec.follow or {}
                rec.follow[i] = rec.follow[i] or {}
                local st = rec.follow[i]

                local d = math.sqrt(dist2(cloc, ploc))
                if d > warp then
                    Spawner.WarpNear(c, player, Config.WHISTLE_WARP_RING_UU or 500, i, n)
                    st.tracking = false     -- the teleport invalidates the path; re-issue next tick
                    out(string.format("Escort %d fell %.0fm behind — warped to you.", i, d / 100))
                elseif Spawner.IsFighting(c, player) then
                    -- THIS crew member is engaging an enemy (any hostile, per-pawn target read): yield.
                    -- Stop forcing the follow so its combat AI runs; it rejoins once the enemy is down.
                    st.tracking = false
                    Spawner.SetSpeedMultiplier(c, 1.0)     -- normal combat speed; don't compound it
                    if st.logicStopped then Spawner.SetAILogic(c, true); st.logicStopped = false end
                    if dbg then
                        out(string.format("followTick: crew %d at %.1fm -> holding for combat", i, d / 100))
                    end
                elseif d > start then
                    -- Raise their movement cap so they can actually travel at the player's pace —
                    -- Mercuna can't exceed CharacterMovement.MaxWalkSpeed, their ~110 walk gait.
                    if paceSpeed then Spawner.SetMaxWalkSpeed(c, paceSpeed) end
                    -- ...but out of combat they keep the WALK gait, whose desired speed still caps them
                    -- low. Multiply their speed so the walk becomes a keep-up jog (reset to 1.0 when
                    -- they arrive or fight). Tunable: FOLLOW_SPEED_MULT.
                    Spawner.SetSpeedMultiplier(c, Config.FOLLOW_SPEED_MULT or 3.0)
                    -- Their own StateTree may re-issue its own destination each tick and stomp ours.
                    -- Silencing it makes the order stick, at the cost of them not fighting while
                    -- they walk. Opt-in; Spawner.Follow also escalates to this on its own if it
                    -- sees a live path with zero speed (Config.FOLLOW_AUTOSTOP_LOGIC).
                    if Config.WHISTLE_FOLLOW_STOP_LOGIC then Spawner.SetAILogic(c, false) end
                    local ok, why = Spawner.Follow(c, player, st)
                    if dbg then
                        out(string.format("followTick: crew %d at %.1fm -> %s", i, d / 100, tostring(why)))
                    end
                else
                    -- Back at your heel. Stop tracking so Mercuna stops fighting the pawn's own idle
                    -- behaviour, then hand its brain back so it fights again.
                    if st.tracking then
                        local nav = nil
                        pcall(function() nav = c.MercunaGroundNavigationComponent end)
                        if nav and nav:IsValid() then pcall(function() nav:Stop() end) end
                        st.tracking = false
                    end
                    if st.logicStopped or Config.WHISTLE_FOLLOW_STOP_LOGIC then
                        Spawner.SetAILogic(c, true)
                        st.logicStopped = false
                    end
                    Spawner.SetSpeedMultiplier(c, 1.0)     -- back to normal speed at your heel
                    if dbg then
                        out(string.format("followTick: crew %d at %.1fm (within %.1fm, holding)",
                            i, d / 100, start / 100))
                    end
                end
            end
        elseif dbg then
            out(string.format("followTick: crew %d is invalid/dead", i))
        end
    end
end

--------------------------------------------------------------------
-- Retire the escort when the anchor is gone (pet timer expired, or dismissed).
--------------------------------------------------------------------
local function watchAnchor(anchorKey)
    local function tick()
        ExecuteInGameThread(function() pcall(function()
            local rec = Whistle.anchors[anchorKey]
            if not rec then return end
            local alive = rec.anchor and rec.anchor:IsValid()
            if alive then followTick(rec) return end   -- still summoned: keep them at your heel
            local n = 0
            for _, c in ipairs(rec.crew) do
                if c and c:IsValid() then
                    pcall(function() c:K2_DestroyActor() end)
                    n = n + 1
                end
            end
            Whistle.anchors[anchorKey] = nil
            out(string.format("Pet expired — escort dismissed (%d crew).", n))
        end) end)
        if Whistle.anchors[anchorKey] and ExecuteWithDelay then
            ExecuteWithDelay(Config.WHISTLE_ANCHOR_CHECK_MS or 1000, tick)
        end
    end
    if ExecuteWithDelay then ExecuteWithDelay(Config.WHISTLE_ANCHOR_CHECK_MS or 1000, tick) end
end

--------------------------------------------------------------------
-- Hooks. NotifyOnNewObject fires the moment the object is constructed — no polling.
--------------------------------------------------------------------
local function onPetSpawned(boar)
    if not (boar and boar:IsValid()) then return end
    local k = keyOf(boar)
    if Whistle.anchors[k] then return end
    Whistle.anchors[k] = { anchor = boar, crew = {} }
    out("Whistle pet summoned — anchoring it and calling up the crew.")
    makeAnchor(boar)
    spawnEscort(boar, k)
    watchAnchor(k)
end

local function onTotemSpawned(totem)
    if not (totem and totem:IsValid()) then return end
    -- The Caster's witch totems attack the player: they are separate actors and never inherit her
    -- friendly faction. Our earlier attempt stripped abilities by GUESSED name and removed nothing
    -- ("removed ability" appears 0 times in the log). With the real class path we simply destroy
    -- them on spawn. Her close-range AoE is untouched.
    pcall(function() totem:K2_DestroyActor() end)
    out("Caster totem destroyed on spawn.")
end

--- Register the object hooks. Safe to call more than once.
function Whistle.Install()
    if Whistle._installed then return end
    Whistle._installed = true

    if Config.WHISTLE_CREW then
        local ok = pcall(function()
            NotifyOnNewObject(Config.WHISTLE_PET_CLASS_PATH, function(o)
                -- Hide IMMEDIATELY, in the notify callback, not one frame later on the game thread.
                -- Deferring it is why RedFalcon saw the boar for a frame.
                pcall(function() o:SetActorHiddenInGame(true) end)
                ExecuteInGameThread(function() pcall(onPetSpawned, o) end)
            end)
        end)
        out(ok and "Watching for the whistle's pet (anchor + crew escort)."
                or "NotifyOnNewObject unavailable — whistle feature inactive.")
    end

    if Config.CASTER_KILL_TOTEMS then
        local ok = pcall(function()
            NotifyOnNewObject(Config.CASTER_TOTEM_CLASS_PATH, function(o)
                ExecuteInGameThread(function() pcall(onTotemSpawned, o) end)
            end)
        end)
        if not ok then out("NotifyOnNewObject unavailable — totem killer inactive.") end
    end
end

--- Kept for main.lua's world-load call site: hooks are global, so there is nothing to re-apply.
function Whistle.ApplyOnLoad() Whistle.Install() end

return Whistle
