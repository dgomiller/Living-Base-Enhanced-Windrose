--[[
 LivingBase / spawner.lua
 Actor spawning via GameplayStatics deferred spawn. Tracks everything
 it spawns so cleanup is one call. Phase 2: used by the testbed only.
]]

local UEHelpers = require("UEHelpers")
local Config = require("config")

local Spawner = {}
local MOD_NAME = "[LivingBase:Spawner]"

-- TEMP DIAGNOSTIC (2026-08-19, remove after use): lbghosttest2 has reported 0 dynamic instances
-- with NO error message on every attempt since the error-logging fix was deployed, which shouldn't
-- be possible unless this file isn't actually being re-read on lbreload -- Lua's require() caches
-- modules in package.loaded and main.lua loads this file via a plain require("spawner"), which does
-- NOT re-read from disk on a second call unless something clears that cache first. This print runs
-- once at module load/require time -- if it does NOT reappear in ue4ss.log after an lbreload, that
-- confirms RestartMod("LivingBase") is reusing a stale cached copy of this file instead of the
-- redeployed one, which would mean several of tonight's spawner.lua fixes were never actually live.
print("[LivingBase:Spawner] MODULE LOAD MARKER v2026-08-19-2235\n")

local function log(msg)
    if Config.VERBOSE then print(string.format("%s %s\n", MOD_NAME, tostring(msg))) end
end
-- Unconditional — for troubleshooting output that must survive Config.VERBOSE=false (the project
-- default). A silent Spawn() failure (bad class path, no world, etc.) with zero log trace is exactly
-- the kind of thing this rule exists for — confirmed live 2026-08-07 when a failed test spawn logged
-- nothing beyond "FAILED -- nil", because every SPAWN FAILED branch below used the gated log().
local function always(msg)
    print(string.format("%s %s\n", MOD_NAME, tostring(msg)))
end

-- Everything we spawn, for DEL clean-house: { {actor=..., label=...}, ... }
Spawner.spawned = {}

-- Target lock (Num+ toggle, Spawner.ToggleTargetLock): nil when off, else { actor=<UObject>,
-- label=<string>, class=<string> } for the one tracked actor every non-spawning action (despawn,
-- cycle, live-edit) pins to. Session-only, same as Spawner.editPrecisionScale — resets on
-- reload/restart rather than persisting. See findNearestSpawnInFront's own comment for how it's
-- honored.
Spawner.lockedTarget = nil

-- Set true while the LivingBaseSpawnMenu companion mod's Coords window is open (2026-08-16) --
-- suspends ONLY the distance-based half of Spawner.TargetLockDistanceCheck below, not the
-- existence check. Typing a coordinate is a real typo risk (an extra digit sends the object far
-- enough that the normal "walked too far, release the lock" rule would fire and silently kick you
-- out of the very edit you're mid-typo-recovering from); the Coords window explicitly sets this
-- around its own open/close lifetime so that can't happen while you're actively editing. See
-- main.lua's ACTION:COORDS_OPEN/COORDS_CLOSE handling.
Spawner.suspendTargetLockDistanceCheck = false

-- Set true while restoring persisted spawns so we don't re-record them.
Spawner.restoring = false

-- Set true around a Spawner.Spawn call whose caller already shows its OWN toast (Undo, pose-cycle) —
-- prevents a redundant generic "Spawned: X" on top of "Undo: restored X" / "Cycle: ...".
Spawner._suppressSpawnToast = false

-- Outstanding ASYNC post-process work counter (2026-08-11). scheduleRestorePostProcess's own
-- restore loop only tracks whether every restoreHook has been CALLED, not whether the
-- background work each call kicks off (Testbed.ApplyFemaleReskinTarget's multi-second retry/
-- despawn-respawn chains, for instance) has actually FINISHED — those run on their own
-- ExecuteWithDelay chains well past the point restoreHook itself returns. A restoreHook
-- implementation that wants "base restored and ready" to genuinely wait for it should call
-- Spawner.BeginAsyncPostProcess() when it kicks off async work and Spawner.EndAsyncPostProcess()
-- exactly once when that work (including any retry/respawn chain) truly concludes.
-- Deliberately opt-in, not automatic for every restoreHook rule — see scheduleRestorePostProcess's
-- own comment for the safety timeout that keeps a miscounted rule from locking the player out of
-- every mod key forever.
Spawner.postProcessPending = 0
function Spawner.BeginAsyncPostProcess()
    Spawner.postProcessPending = (Spawner.postProcessPending or 0) + 1
end
function Spawner.EndAsyncPostProcess()
    Spawner.postProcessPending = math.max(0, (Spawner.postProcessPending or 0) - 1)
end

-- Spawner.RunSerialized(fn) (2026-08-11) — GLOBAL bounded-concurrency queue for any post-spawn
-- work that touches a pawn's composite mesh/components (Senkamati de-corrupt/reskin, female-
-- walker reskin). Root-caused from a real crash: ue4ss.log stopped dead mid-restore (no Lua
-- error, no shutdown line — the exact signature of every other confirmed native crash already
-- documented in this file) while a restored Warrior's de-corrupt retry loop was mid-pass AND a
-- Letty and a Merchant were ALSO concurrently mid-processing in the background. Touching ONE
-- actor's composite while ITS OWN build is still settling was already a known, confirmed crash
-- trigger (see the Warrior/Caster delay comments elsewhere in this file) — what hadn't been
-- tested until this session's own concurrency work (the per-target female-walker queue, the
-- Senkamati restore-row fixes) is that touching TWO DIFFERENT actors' composites at the same
-- time appears to be able to crash it too, since restore can now genuinely have several actors'
-- retry loops running in overlapping windows.
-- CONCURRENCY LIMIT (2026-08-11, RedFalcon's follow-up): strict one-at-a-time made a big restore take
-- noticeably longer, so this caps at Config.POSTPROCESS_MAX_CONCURRENT (default 3) actors' worth
-- of composite work running at once instead of exactly 1 — a middle ground between "never
-- crashed before this session, when concurrency was much lower" and "provably safe at 1". Not
-- proven safe at 3 specifically; if crashes resume, drop the config value back toward 1 rather
-- than reverting this whole mechanism.
-- fn(done) is called once a slot is free. fn MUST call done() itself, exactly once, when ALL of
-- its own composite/component work — including any retry/respawn chain — has genuinely
-- finished, not just when fn() itself returns (virtually all of these are async). A caller that
-- also uses Spawner.BeginAsyncPostProcess/EndAsyncPostProcess should call done() from the SAME
-- completion point as EndAsyncPostProcess() — they're answering related but different questions
-- (is restore still waiting? vs. is a slot free for the next one?) and should always agree on
-- when "this actor is truly finished" is.
Spawner._postProcessActive = 0
Spawner._postProcessQueue = {}
local function startSerialized(fn)
    Spawner._postProcessActive = Spawner._postProcessActive + 1
    local calledDone = false
    local function done()
        if calledDone then return end
        calledDone = true
        Spawner._postProcessActive = math.max(0, Spawner._postProcessActive - 1)
        local nextFn = table.remove(Spawner._postProcessQueue, 1)
        if nextFn then startSerialized(nextFn) end
    end
    local ok, err = pcall(fn, done)
    if not ok then
        print("[LivingBase] RunSerialized: fn errored (releasing the slot so the queue doesn't stall): "
            .. tostring(err) .. "\n")
        done()
    end
end
function Spawner.RunSerialized(fn)
    if type(fn) ~= "function" then return end
    local maxConcurrent = (Config and Config.POSTPROCESS_MAX_CONCURRENT) or 3
    if Spawner._postProcessActive >= maxConcurrent then
        table.insert(Spawner._postProcessQueue, fn)
        return
    end
    startSerialized(fn)
end

-- Forward declarations: these file-io helpers are DEFINED further down but
-- CALLED inside Spawner.Spawn (above their definitions). Declaring them here
-- as locals puts them in scope at the call sites. (Fixes a bug where every
-- spawn errored on a nil 'ledgerAppend'.)
local actorInstancePath, ledgerAppend, ledgerReadAndClear
local persistAppend

-- Per-world persistence (2026-08-13): Windrose has multiple named-save "worlds", each with its own
-- islandId, but persist.txt/spawn_ledger.txt used to be ONE flat filename shared by every world --
-- loading a different world restored the wrong crew and clobbered the other world's save on next
-- write. Confirmed live: World.GameState.islandId.ID (an R5BLRecordId's FString field) matches
-- EXACTLY the ID Windrose's own world-select screen shows in its tooltip for that save, and only
-- reads back non-empty once the world is genuinely live (ReplicatedWorldTimeSecondsDouble ticking,
-- i.e. by the time RestoreFromPersist actually runs -- see main.lua's scheduleRestore/fire()).
-- Falls back to nil/"" when probed too early or with no world loaded (menu), in which case callers
-- below fall back to the OLD flat filenames -- same behavior as before this change, so nothing ever
-- silently fails to save just because the id isn't available yet.
local function getIslandId()
    local ok, id = pcall(function()
        local world = UEHelpers.GetWorld()
        if not (world and world:IsValid()) then return nil end
        local gs = world.GameState
        if not (gs and gs:IsValid()) then return nil end
        local iid = gs.islandId
        if iid == nil then return nil end
        local rawId = iid.ID
        if rawId == nil then return nil end
        if type(rawId) == "userdata" then
            local okt, s = pcall(function() return rawId:ToString() end)
            return okt and s or nil
        end
        return tostring(rawId)
    end)
    if not ok or not id then return nil end
    -- Filesystem-safe: every confirmed ID so far is plain hex, but don't trust that blindly.
    id = id:gsub("[^%w]", "")
    if id == "" then return nil end
    return id
end

-- Old flat filenames (pre-multi-world). Kept as the migration SOURCE and as the fallback when no
-- island id is available yet -- never used as a live save target once an id is known.
local OLD_LEDGER_PATHS = {
    "ue4ss/Mods/LivingBase/spawn_ledger.txt",
    "Mods/LivingBase/spawn_ledger.txt",
    "spawn_ledger.txt",
}
local OLD_PERSIST_PATHS = {
    "ue4ss/Mods/LivingBase/persist.txt",
    "Mods/LivingBase/persist.txt",
    "persist.txt",
}
-- Path candidates for baseName ("spawn_ledger.txt"/"persist.txt"), suffixed with the current
-- island id once one is known. Recomputed on every call (not cached) since the SAME running game
-- process can load a different world later without restarting.
local function worldPaths(baseName, oldPaths)
    local id = getIslandId()
    if not id then return oldPaths end
    local named = baseName:gsub("%.txt$", "_" .. id .. ".txt")
    return {
        "ue4ss/Mods/LivingBase/" .. named,
        "Mods/LivingBase/" .. named,
        named,
    }
end
-- Clone the old shared file into a newly-seen world's own file, once per (world, file) per
-- session -- then rename the old file to .bak so it can only ever be claimed ONCE. Confirmed live
-- 2026-08-13: renaming used to happen never (old file left in place "in case a different world
-- needs it too"), which meant a SECOND world's first load found the same old file still sitting
-- there and cloned the FIRST world's crew into itself as well. The old shared file only ever
-- really belonged to one specific world (whichever was last played pre-update); once that world
-- claims it, no other world should treat it as theirs too. .bak (not deleted) so nothing is lost
-- if the wrong world claims it first.
local migratedFlags = {}
local function migrateIfNeeded(baseName, oldPaths)
    local id = getIslandId()
    if not id then return end
    local key = id .. "|" .. baseName
    if migratedFlags[key] then return end
    migratedFlags[key] = true
    local newPaths = worldPaths(baseName, oldPaths)
    for _, p in ipairs(newPaths) do
        local f = io.open(p, "r")
        if f then f:close(); return end -- this world already has its own file; nothing to migrate.
    end
    local oldContent, foundOld = nil, nil
    for _, p in ipairs(oldPaths) do
        local f = io.open(p, "r")
        if f then oldContent = f:read("*a"); f:close(); foundOld = p; break end
    end
    if not oldContent then return end
    for _, p in ipairs(newPaths) do
        local f = io.open(p, "w")
        if f then
            f:write(oldContent)
            f:close()
            print(string.format("[LivingBase] Migrated %s -> %s (world %s) from old shared save.\n", foundOld, p, id))
            local bakPath = foundOld:gsub("%.txt$", ".bak")
            local okRename = pcall(function() os.rename(foundOld, bakPath) end)
            if okRename then
                print(string.format("[LivingBase] Renamed %s -> %s so no other world re-claims it.\n", foundOld, bakPath))
            else
                print(string.format("[LivingBase] WARNING: could not rename %s to .bak -- a later world may re-claim it too.\n", foundOld))
            end
            return
        end
    end
end
local function LEDGER_PATHS() return worldPaths("spawn_ledger.txt", OLD_LEDGER_PATHS) end
local function PERSIST_PATHS() return worldPaths("persist.txt", OLD_PERSIST_PATHS) end
local function getGameplayStatics()
    local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    if gs and gs:IsValid() then return gs end
    return nil
end

-- Resolve a BP class by full path; try StaticFindObject first, then
-- LoadAsset for classes not yet in memory (e.g. faction actors far
-- from town).
local function resolveClass(path)
    local cls = StaticFindObject(path)
    if cls and cls:IsValid() then return cls end
    log("Class not in memory, attempting LoadAsset: " .. path)
    local okLoad = pcall(function() LoadAsset(path) end)
    if okLoad then
        cls = StaticFindObject(path)
        if cls and cls:IsValid() then return cls end
    end
    return nil
end

-- Spawn location: ~3m in front of the player, at player height.
-- Toast auto-removal: a SINGLE self-rescheduling ticker (same proven pattern as Spawner.LeashTick),
-- not one ExecuteWithDelay per toast. First version scheduled its own removal timer per call --
-- user-confirmed 2026-08-06 that EVERY toast shown all session stayed on screen forever, none ever
-- auto-removed, once several fired in quick succession (statue pose-cycling alone fires 4+ in under a
-- second). This UE4SS build apparently doesn't reliably run many independent overlapping
-- ExecuteWithDelay callbacks; one ticker checking a short list every 500ms sidesteps that.
Spawner._activeToasts = Spawner._activeToasts or {}
local toastTickerStarted = false
local function toastTick()
    local now = os.time()
    local lastContainer
    for i = #Spawner._activeToasts, 1, -1 do
        local t = Spawner._activeToasts[i]
        if now >= t.expiresAt then
            pcall(function() t.box:RemoveChild(t.widget) end)
            lastContainer = t.container
            table.remove(Spawner._activeToasts, i)
        end
    end
    -- Forcing the container visible (see trySpliceToast) made it absorb mouse clicks over its screen
    -- area even once EMPTY -- user-reported 2026-08-06: it sat on top of the build menu and other UI,
    -- blocking clicks underneath. Re-collapse it once the last active toast expires so it's fully out
    -- of the way again, same as its own default (bHidden=true) state before we ever touched it.
    if #Spawner._activeToasts == 0 and lastContainer then
        pcall(function()
            lastContainer.bHidden = true
            lastContainer:CheckVisibility()
            lastContainer:SetVisibility(ESlateVisibility and ESlateVisibility.Collapsed or 1)
        end)
    end
    if ExecuteWithDelay then ExecuteWithDelay(500, toastTick) end
end
local function ensureToastTicker()
    if toastTickerStarted then return end
    toastTickerStarted = true
    if ExecuteWithDelay then ExecuteWithDelay(500, toastTick) end
end

-- Splices ONE TextBlock into the live side-notification container's VerticalBox. Returns true if it
-- actually attached (false if the container isn't found yet, e.g. too early during world load before
-- the HUD widget tree exists). See Spawner.Toast's own comment for the full "why a TextBlock spliced
-- into AddChild instead of PrintString/ClientMessage/SpawnNotification" history.
local function trySpliceToast(text, seconds)
    local shown = false
    pcall(function()
        local container, box
        local list
        pcall(function() list = FindAllOf("WBP_SideNotificationsContainer_C") end)
        if list then
            local n = 0
            pcall(function() n = list:GetArrayNum() end)
            if n == 0 then pcall(function() n = #list end) end
            for i = 1, n do
                local w = list[i]
                if not w then pcall(function() w = list:Get(i) end) end
                if w and w:IsValid() then
                    local b
                    pcall(function() b = w.vbox_Notifications end)
                    if b and b:IsValid() then
                        container, box = w, b
                        break
                    end
                end
            end
        end
        if not (container and box) then return end

        local okClass, TextBlockClass = pcall(function() return StaticFindObject("/Script/UMG.TextBlock") end)
        local okOuter, GameInstance = pcall(function() return UEHelpers.GetGameInstance() end)
        if not (okClass and TextBlockClass and TextBlockClass:IsValid()
            and okOuter and GameInstance and GameInstance:IsValid()) then return end
        local okNew, newWidget = pcall(function() return StaticConstructObject(TextBlockClass, GameInstance) end)
        if not (okNew and newWidget and newWidget:IsValid()) then return end
        pcall(function()
            local ktl = UEHelpers.GetKismetTextLibrary()
            newWidget:SetText(ktl:Conv_StringToText(text))
        end)
        -- A bare TextBlock has no width constraint from the notification widget's own styling (that
        -- lives on WBP_SideNotification_C, which we're deliberately not using), so long messages ran
        -- off past the edge of the screen at the default (large) font size. Wrap at a fixed pixel width
        -- and shrink the default font down to something toast-sized.
        pcall(function() newWidget:SetAutoWrapText(true) end)
        pcall(function() newWidget:SetWrapTextWidth(360) end)
        pcall(function()
            local font = newWidget.Font
            if font then
                font.Size = 14
                newWidget.Font = font
            end
        end)

        local okAdd = pcall(function() box:AddChild(newWidget) end)
        if not okAdd then return end
        pcall(function() container.bHidden = false end)
        pcall(function() container:CheckVisibility() end)
        pcall(function() container:SetVisibility(ESlateVisibility and ESlateVisibility.Visible or 0) end)
        shown = true

        ensureToastTicker()
        Spawner._activeToasts[#Spawner._activeToasts + 1] =
            { box = box, widget = newWidget, container = container, expiresAt = os.time() + math.ceil(seconds or 4.0) }
    end)
    return shown
end

-- Spawner.Toast(msg, seconds) — on-screen message, reusing the game's own native side-notification
-- widget tree (WBP_SideNotificationsContainer_C / vbox_Notifications) rather than any engine
-- debug-output API. History: KismetSystemLibrary::PrintString and PlayerController::ClientMessage
-- were both tried first and confirmed DEAD ENDS for real gameplay HUD feedback in this game --
-- PrintString's on-screen path never rendered (GAreScreenMessagesEnabled likely false, and this
-- build doesn't even recognize the "EnableAllScreenMessages" exec command to flip it), and
-- ClientMessage routes to UE4SS's own separate debug console window, not the game's HUD. Confirmed
-- working approach instead: construct a native /Script/UMG.TextBlock via StaticConstructObject, set
-- its text via KismetTextLibrary:Conv_StringToText + SetText, and splice it directly into a LIVE
-- container's VerticalBox via AddChild (a standard UPanelWidget function) -- bypassing the
-- Blueprint-only SpawnNotification/RemoveNotification pair entirely, since those expect a pre-built
-- widget of a class we have no reference to (see CLAUDE.md for the full investigation). The
-- container itself defaults to bHidden=true and only reveals itself through its own
-- CheckVisibility/SetIsMetaUIMode logic (normally driven by SpawnNotification), so after AddChild
-- this also forces the container visible directly -- user-confirmed on-screen 2026-08-06.
-- Retries repeatedly, spaced out, if the container isn't found on the first try -- confirmed
-- 2026-08-06 that the earliest restore-status toast (fired the moment the player pawn is detected,
-- which can be WHILE the loading screen is still up, potentially many seconds before the HUD widget
-- tree actually mounts) silently found no container and fell through to log-only even with a 4-try/
-- 2.4s budget -- the later "base restored" toast for the SAME load only succeeds because it fires
-- after RESTORE_SETTLE_MS + staggered spawn delays, several more seconds on. Bumped way up (20
-- tries/1s = ~20s) since this only ever actually loops in that one early-load window -- the common
-- case (HUD already mounted) still succeeds on the very first attempt, zero added cost.
function Spawner.Toast(msg, seconds)
    local text = tostring(msg)
    local function attempt(triesLeft)
        if trySpliceToast(text, seconds) then return end
        if triesLeft > 0 and ExecuteWithDelay then
            ExecuteWithDelay(1000, function() attempt(triesLeft - 1) end)
        else
            print(string.format("[LivingBase] %s\n", text))
        end
    end
    attempt(20)
    return true
end

-- Horizontal direction is the CAMERA'S yaw (control rotation), not pawn body yaw — so a new spawn
-- lands where you're actually looking left/right, even if your body hasn't turned to match (third
-- person camera can free-look independent of body facing). Deliberately YAW ONLY, no pitch: unlike
-- the targeting cone (findNearestSpawnInFront), this isn't measuring an angle to an EXISTING object's
-- position, it's picking a brand-new point at a fixed distance from the player — so there's no
-- origin/direction mismatch to worry about (that bug class is specific to angle-to-existing-position
-- tests). Pitch is intentionally NOT used for placement: that would put spawns higher/lower or
-- floating in midair depending on where you're looking up/down, and floor-snapping (snapToFloor in
-- testbed.lua) already handles height correctly on its own. Falls back to pawn yaw if control
-- rotation isn't available for some reason.
local function spotInFrontOfPlayer(distanceUU)
    distanceUU = distanceUU or 300.0
    local pc = UEHelpers.GetPlayerController()
    if not pc or not pc:IsValid() then return nil end
    local pawn = pc.Pawn
    if not pawn or not pawn:IsValid() then return nil end
    local loc = pawn:K2_GetActorLocation()
    local yawDeg = pawn:K2_GetActorRotation().Yaw
    pcall(function()
        local camRot = pc:GetControlRotation()
        if camRot then yawDeg = camRot.Yaw end
    end)
    local yawRad = math.rad(yawDeg)
    return {
        X = loc.X + math.cos(yawRad) * distanceUU,
        Y = loc.Y + math.sin(yawRad) * distanceUU,
        Z = loc.Z,
    }, yawDeg
end

-- Best-effort "set dressing" hardening: no damage. Collision is left
-- ON so interaction traces still hit the actor (trade window needs it).
local function makeSetDressing(actor)
    pcall(function() actor:SetCanBeDamaged(false) end)
    pcall(function() actor.bCanBeDamaged = false end)
end

-- Spawner.LetFurniturePass(actor) — a posed statue should let PLACED FURNITURE overlap it (so a
-- stool tucks under a sitter) while still BLOCKING walking characters.
--
-- The trick that avoids guessing the furniture's collision channel: on every primitive component,
-- ignore ALL channels, then block Pawn only. Collision between two components needs BOTH to block,
-- so ignoring everything-but-Pawn drops furniture (whatever channel it uses — WorldStatic,
-- WorldDynamic, a game trace channel) through the statue. Pawn stays Block, so the player and
-- walking NPCs are still stopped — that collision reads the statue's response to Pawn, which we
-- keep. These are placed props with no physics/AI, so ignoring world geometry costs nothing (they
-- don't fall), and F9 despawn iterates the tracked list rather than tracing, so it's unaffected.
--
-- ECollisionResponse: Ignore=0, Overlap=1, Block=2.   ECollisionChannel: Pawn=2.
--
-- ECC_Visibility (raw channel 3) ALSO kept blocking (2026-08-21) -- CONFIRMED LIVE this "ignore
-- everything but Pawn" design (see above) had a real side effect: RedFalcon could no longer target a
-- confirmed-placed statue at all (Num+/hover-highlight both use LineTraceSingle -- see
-- Spawner.UpdateHoverHighlight's own comment -- with a trace-channel arg of 0, which this function
-- had been silently turning off for every statue since it predates the raycast-targeting feature).
-- Two wrong guesses before landing here, both CONFIRMED LIVE wrong: (1) switched the TRACE itself to
-- channel 2 assuming that's "Pawn" -- broke targeting for decor too, which had always worked fine on
-- channel 0; (2) blocked raw ECollisionChannel 0 here (ECC_WorldStatic) on the same wrong assumption
-- that LineTraceSingle's channel PARAMETER and SetCollisionResponseToChannel's channel parameter
-- share one numbering -- they don't. LineTraceSingle's channel arg is `ETraceTypeQuery` (a
-- Blueprint-only enum built from Project Settings > Collision > Trace Channels), NOT the raw
-- `ECollisionChannel` SetCollisionResponseToChannel takes. By Unreal's own default project settings
-- (unless Windrose customized this), TraceTypeQuery index 0 is "Visibility", which in the raw
-- ECollisionChannel enum is index 3, not 0 -- consistent with decor (default "block everything"
-- collision, Visibility included) always having worked on trace-channel 0. Blocking raw channel 3
-- here is the standards-based fix, not another blind index guess. Residual risk unchanged from
-- before: this function's whole POINT was avoiding a guess at furniture's own channel by blocking
-- NOTHING but Pawn -- if furniture placement also happens to use Visibility, this re-introduces the
-- "furniture won't slide under a seated statue" bug. Not yet re-tested live either way.
function Spawner.LetFurniturePass(actor)
    if not (actor and actor:IsValid()) then return false end
    local cls = StaticFindObject("/Script/Engine.PrimitiveComponent")
    if not (cls and cls:IsValid()) then return false end
    local n = 0
    local touched = 0
    pcall(function()
        local comps = actor:K2_GetComponentsByClass(cls)
        pcall(function() n = comps:GetArrayNum() end)
        if n == 0 then pcall(function() n = #comps end) end
        for i = 1, n do
            local c = comps[i]; if not c then pcall(function() c = comps:Get(i) end) end
            -- UNWRAP (2026-08-21) -- CONFIRMED SUSPECT: K2_GetComponentsByClass's returned array can
            -- hand back a RemoteUnrealParam wrapper, not the component directly -- a documented,
            -- recurring pitfall in THIS file (Spawner.MakeMovable, ApplyGhostMaterial,
            -- dumpMeshComponentNames all already unwrap it) that this function -- older, predates the
            -- raycast-targeting feature entirely per its own header comment -- never did. If c was a
            -- wrapper, every collision-response call below could have been silently no-op'ing this
            -- WHOLE TIME, on every channel guess tried tonight (0, then 3/Visibility, then a 0-12
            -- sweep) -- which would explain why NONE of them ever changed the statue's actual
            -- behavior even once.
            pcall(function() if c ~= nil and type(c) == "userdata" and c.get then c = c:get() end end)
            if c and c:IsValid() then
                touched = touched + 1
                pcall(function() c:SetCollisionResponseToAllChannels(0) end)   -- Ignore all
                pcall(function() c:SetCollisionResponseToChannel(2, 2) end)    -- Block Pawn
                -- BROAD SWEEP (2026-08-21) -- covers every default engine channel plus the usual
                -- custom GameTraceChannel range, so whichever one targeting's raycast actually uses
                -- gets blocked regardless of the exact index -- see this function's own history above
                -- for the two narrower guesses that came before this.
                for ch = 0, 12 do
                    pcall(function() c:SetCollisionResponseToChannel(ch, 2) end)
                end
            end
        end
    end)
    print(string.format("[LivingBase] [furniturepass] found=%d touched=%d\n", n, touched))
    return n > 0
end

-- Spawner.EnsureRaytraceChannel(actor) -- (2026-08-22, RedFalcon: "the walking actors, the idle
-- senkamati, and the drops decor need to be added to raytrace targeting because i cant target them
-- currently") -- confirmed live via the [hover-diag] probe: aiming at a walking NPC/idle Senkamati,
-- the raycast passed straight through and hit an R5BuildingBlock behind it instead -- same root cause
-- as the original statue-targeting bug (their collision doesn't respond on the trace channel), but
-- these are NOT stationary display statues, so LetFurniturePass's "ignore everything but Pawn" design
-- would be the wrong fix here -- it'd make walking NPCs/decor non-solid to everything but the player,
-- when they should keep their normal collision. This ONLY sets the one channel our own raycast
-- actually uses (raw ECollisionChannel 3 / Visibility, confirmed by LetFurniturePass's own comment:
-- LineTraceSingle's channel arg is TraceTypeQuery index 0, which maps to raw channel 3 by Unreal's
-- default project settings) to Block, WITHOUT touching any other channel's existing response --
-- additive, not a wipe-and-rebuild like LetFurniturePass.
-- TEMPORARILY DISABLED (2026-08-24, diagnostic) -- RedFalcon reported wild NPCs' legs bending/
-- lifting near a mod-spawned NPC (including mod-spawned vs. mod-spawned -- "they behave the same
-- to each other"), confirmed live to reproduce on FRESH spawns never touched by F7/placement, so
-- unrelated to today's placement-preview work. Leading theory: this function's own
-- SetCollisionResponseToChannel(3, 2) below -- forcing raw Visibility to Block on every primitive
-- component of every mod spawn, added 2026-08-22 so raycast-targeting (Num+/hover-highlight/
-- lbprobe, which also traces on that same channel) could hit walking NPCs/idle Senkamati/drops --
-- is ALSO exactly the kind of channel a character's own foot-IK/ground-detection trace commonly
-- uses, so any OTHER pawn now blocking it registers as solid ground under its feet. The actual
-- SetCollisionResponseToChannel call is commented out below so RedFalcon can confirm this live
-- before a permanent (more surgical) fix goes in -- raycast-targeting on walkers/idle Senkamati/
-- drops will regress back to pass-through while this is disabled, same as before 2026-08-22.
function Spawner.EnsureRaytraceChannel(actor)
    if not (actor and actor:IsValid()) then return false end
    local cls = StaticFindObject("/Script/Engine.PrimitiveComponent")
    if not (cls and cls:IsValid()) then return false end
    local n, touched = 0, 0
    pcall(function()
        local comps = actor:K2_GetComponentsByClass(cls)
        pcall(function() n = comps:GetArrayNum() end)
        if n == 0 then pcall(function() n = #comps end) end
        for i = 1, n do
            local c = comps[i]; if not c then pcall(function() c = comps:Get(i) end) end
            pcall(function() if c ~= nil and type(c) == "userdata" and c.get then c = c:get() end end)
            if c and c:IsValid() then
                touched = touched + 1
                -- pcall(function() c:SetCollisionResponseToChannel(3, 2) end)  -- Block Visibility (raw ECC 3) -- DIAGNOSTIC DISABLE, see above
            end
        end
    end)
    return n > 0
end

-- Raw-spawned pawns have no AI controller, so their behavior tree
-- never starts (frozen NPCs). Attach the class's default controller,
-- then call the game's own R5AICharacter::ActivateCharacter — the
-- native "bring this NPC to life" initializer discovered via F11.
local function ensureController(actor)
    pcall(function() actor:SpawnDefaultController() end)

    local activated = false
    local okAct, errAct = pcall(function()
        actor:ActivateCharacter()
        activated = true
    end)
    if activated then
        log("ActivateCharacter succeeded on " .. tostring(actor:GetFName() and actor:GetFName():ToString() or "?"))
    elseif errAct then
        log("ActivateCharacter failed (non-fatal): " .. tostring(errAct))
    end
end

--------------------------------------------------------------------
-- Engine spawn with SIGNATURE AUTO-DETECTION.
-- Windrose's UE 5.6 build reported "expected 7 parameters, received 5"
-- for BeginDeferredActorSpawnFromClass — the signature grew in UE5
-- (TransformScaleMethod) and this UE4SS build counts the return slot.
-- We try known variants once, then lock in whichever the engine takes.
--------------------------------------------------------------------
-- Enum notes: CollisionHandling 1 = AlwaysSpawn
--             ScaleMethod      1 = MultiplyWithRoot
local beginVariants = {
    { name = "UE5.6 (6 args: +ScaleMethod)",
      call = function(gs, w, c, t) return gs:BeginDeferredActorSpawnFromClass(w, c, t, 1, nil, 1) end },
    { name = "UE5.6 (7 args: +ScaleMethod +ret slot)",
      call = function(gs, w, c, t) return gs:BeginDeferredActorSpawnFromClass(w, c, t, 1, nil, 1, nil) end },
    { name = "UE4 classic (5 args)",
      call = function(gs, w, c, t) return gs:BeginDeferredActorSpawnFromClass(w, c, t, 1, nil) end },
}
local finishVariants = {
    { name = "UE5 (3 args: +ScaleMethod)",
      call = function(gs, a, t) return gs:FinishSpawningActor(a, t, 1) end },
    { name = "UE4 classic (2 args)",
      call = function(gs, a, t) return gs:FinishSpawningActor(a, t) end },
    { name = "UE5 (4 args: +ScaleMethod +ret slot)",
      call = function(gs, a, t) return gs:FinishSpawningActor(a, t, 1, nil) end },
}
local lockedBegin, lockedFinish = nil, nil

-- preFinish(actor): optional callback run in the deferred-spawn window —
-- AFTER the actor is constructed but BEFORE FinishSpawningActor triggers
-- BeginPlay/visual build. This is the only place to set "expose-on-spawn"
-- style params (e.g. body sex) so the game builds the intended look.
-- aiClass: optional resolved AIController UClass — set as the pawn's
-- AIControllerClass here (pre-possess) so it uses that brain (e.g. Handyman
-- so a stationary/quest NPC wanders + can idle-sit).
function Spawner._DoEngineSpawn(gs, world, cls, transform, label, preFinish, aiClass)
    -- Phase A: begin deferred spawn
    local deferred = nil
    if lockedBegin then
        local ok, res = pcall(lockedBegin.call, gs, world, cls, transform)
        if ok then deferred = res
        else log("Locked begin-variant failed (" .. tostring(res) .. "); re-detecting."); lockedBegin = nil end
    end
    if not deferred then
        for _, v in ipairs(beginVariants) do
            local ok, res = pcall(v.call, gs, world, cls, transform)
            if ok and res and res:IsValid() then
                deferred = res
                lockedBegin = v
                log("Begin-spawn signature locked: " .. v.name)
                break
            elseif not ok then
                log("Begin variant '" .. v.name .. "' rejected: " .. tostring(res))
            end
        end
    end
    if not deferred or not deferred:IsValid() then
        always("SPAWN FAILED (all begin-spawn signatures rejected): " .. tostring(label))
        return nil
    end

    -- Override the AI brain before self-possession, if requested.
    -- Unconditional (was gated behind Config.VERBOSE) -- actively being used to debug why the
    -- Hunter/Caster/Healer walk-AI experiment had no visible effect (2026-08-09); silent under
    -- VERBOSE=false was exactly the wrong tradeoff while that's still an open question.
    if aiClass then
        local ok = pcall(function() deferred.AIControllerClass = aiClass end)
        always("AIControllerClass override " .. (ok and "set" or "FAILED") .. " for " .. tostring(label))
    end

    -- Pre-finish hook: set spawn params before the visual builds.
    if preFinish then
        local ok, err = pcall(preFinish, deferred)
        if not ok then log("preFinish hook error (non-fatal): " .. tostring(err)) end
    end

    -- Phase B: finish spawning
    local finished = false
    if lockedFinish then
        local ok, err = pcall(lockedFinish.call, gs, deferred, transform)
        if ok then finished = true
        else log("Locked finish-variant failed (" .. tostring(err) .. "); re-detecting."); lockedFinish = nil end
    end
    if not finished then
        for _, v in ipairs(finishVariants) do
            local ok, err = pcall(v.call, gs, deferred, transform)
            if ok then
                finished = true
                lockedFinish = v
                log("Finish-spawn signature locked: " .. v.name)
                break
            else
                log("Finish variant '" .. v.name .. "' rejected: " .. tostring(err))
            end
        end
    end
    if not finished then
        always("SPAWN FAILED (all finish-spawn signatures rejected): " .. tostring(label))
        pcall(function() deferred:K2_DestroyActor() end)
        return nil
    end

    return deferred
end

-- Spawner.CurrentBodyMeshName(actor) -- reads actor.Mesh's current skeletal mesh short name
-- (e.g. "SK_Albion_Female_01"). Pure read, no side effects. Shared with testbed.lua (originally a
-- statue-only local there; promoted here 2026-08-14 so the plain spawn toast can also report body
-- type -- RedFalcon wants to spot, on ANY spawn, which archetype rolled so they can find more armor-safe
-- ones beyond the two already confirmed).
function Spawner.CurrentBodyMeshName(actor)
    local name = nil
    pcall(function()
        local mesh = actor.Mesh
        if not (mesh and mesh:IsValid()) then return end
        local sk = mesh.SkeletalMesh
        if not (sk and sk:IsValid()) and mesh.GetSkeletalMeshAsset then sk = mesh:GetSkeletalMeshAsset() end
        if sk and sk:IsValid() then name = sk:GetFName():ToString() end
    end)
    return name
end

-- Spawner.ShortArchetypeLabel(meshName) -- "SK_Albion_Female_01" -> "Albion", for a readable toast.
-- Falls back to the raw mesh name if it doesn't match the expected "SK_<Family>_Female_*" shape.
function Spawner.ShortArchetypeLabel(meshName)
    if not meshName then return nil end
    return meshName:match("^SK_(%a+)_Female") or meshName
end

-- Per-instance display naming (2026-08-16, RedFalcon's request): every spawn used to be labeled by
-- its LOOK CATEGORY alone ("Brethren Woman", "SENKA_Warrior_crew", ...), so target-locking two of the
-- same look showed the identical name -- and every restored entity showed the single generic
-- "RESTORED" placeholder, since persist.txt never recorded what it actually was. Spawner.Spawn now
-- resolves every spawn's caller-supplied `label` into a unique "<label> N" instance label via
-- NextInstanceLabel below (unless the caller/restore already knows the exact label to reuse -- see
-- Spawn's own presetInstanceLabel parameter), and persists the RESOLVED label as persist.txt's new
-- field 13 so it survives a reload instead of being reassigned. See restoreOne for the read-back +
-- old-format migration side of this.
Spawner.instanceLabelCounts = Spawner.instanceLabelCounts or {}
-- Returns a fresh, session-unique "<baseLabel> N" string, incrementing a per-base-label counter.
function Spawner.NextInstanceLabel(baseLabel)
    baseLabel = tostring(baseLabel or "Object")
    local n = (Spawner.instanceLabelCounts[baseLabel] or 0) + 1
    Spawner.instanceLabelCounts[baseLabel] = n
    return baseLabel .. " " .. n
end
-- Given an ALREADY-RESOLVED "<base> N" label (e.g. read back from persist.txt on restore), bumps
-- the SAME counter table so a LATER NextInstanceLabel() call for that base can never reissue a
-- number already in use. No-op if `resolvedLabel` doesn't match the "<base> N" shape.
function Spawner.NoteInstanceLabelUsed(resolvedLabel)
    local base, numStr = tostring(resolvedLabel or ""):match("^(.*) (%d+)$")
    if not base then return end
    local n = tonumber(numStr)
    if n and (not Spawner.instanceLabelCounts[base] or Spawner.instanceLabelCounts[base] < n) then
        Spawner.instanceLabelCounts[base] = n
    end
end

--------------------------------------------------------------------
-- Spawner.Spawn(classPath, label [, atLocation])
-- Returns the actor or nil. Logs every step so failures are visible.
--------------------------------------------------------------------
-- yaw (degrees): facing to spawn with. nil = face TOWARD the player.
-- makeFriendly: copy a live crew's faction onto the spawn (friendly to you+crew);
-- recorded so it re-applies on restore. Both passed explicitly on restore.
-- presetInstanceLabel: when given, used VERBATIM as the final display/persisted label instead of
-- auto-numbering `label` -- restoreOne is the only caller that passes this (the label it read back
-- from, or just migrated into, persist.txt). Every existing call site leaves this nil and gets a
-- freshly auto-numbered label as before, no changes needed at those call sites.
-- markIdle (2026-08-24, RedFalcon's request): threads config.lua's own `s.idle` flag (Senkamati
-- frozen-look rows, see testbed.lua's spawnSenkaEntry) through onto the generic Spawner.spawned
-- entry, so the placement-preview system (ConfirmPlacement/CancelPlacement -- see their own
-- comments) can tell "this is meant to stay frozen" apart from "this is a normal walking actor"
-- without guessing from class name. nil/false for every OTHER call site in this file (crew/
-- townsfolk/decor/livestock/statues never pass this) -- they're walking by default, which is the
-- correct default for ConfirmPlacement's own idle check below.
function Spawner.Spawn(classPath, label, atLocation, preFinish, aiControllerClassPath, yaw, makeFriendly, compositeLook, presetInstanceLabel, markIdle)
    local cls = resolveClass(classPath)
    if not cls then
        always("SPAWN FAILED (class unresolved): " .. classPath)
        return nil
    end

    -- Optional AI brain override (e.g. Handyman so an NPC wanders/idle-sits).
    local aiClass = nil
    if aiControllerClassPath then
        aiClass = resolveClass(aiControllerClassPath)
        if not aiClass then log("AI override class unresolved: " .. aiControllerClassPath) end
    end

    local loc, facingYaw
    if atLocation then
        loc, facingYaw = atLocation, 0.0
    else
        loc, facingYaw = spotInFrontOfPlayer()
    end
    if not loc then
        always("SPAWN FAILED (no player location): " .. tostring(label))
        return nil
    end

    local gs = getGameplayStatics()
    if not gs then
        always("SPAWN FAILED: GameplayStatics not found")
        return nil
    end

    local world = UEHelpers.GetWorld()
    if not world or not world:IsValid() then
        always("SPAWN FAILED: no world")
        return nil
    end

    -- Facing: use the given yaw (restore) or camera yaw + 180 so a fresh placement faces TOWARD you
    -- (you see its front). Camera yaw to match spotInFrontOfPlayer's placement direction above — if the
    -- position comes from where you're looking, the "face me" default should turn to match that same
    -- point, not your body's separate facing. Falls back to pawn yaw if control rotation is unavailable.
    local yawUsed = yaw
    if yawUsed == nil then
        pcall(function()
            local pc = UEHelpers.GetPlayerController()
            local pawn = pc and pc:IsValid() and pc.Pawn
            if pawn and pawn:IsValid() then
                local yawDeg = pawn:K2_GetActorRotation().Yaw
                pcall(function()
                    local camRot = pc:GetControlRotation()
                    if camRot then yawDeg = camRot.Yaw end
                end)
                yawUsed = yawDeg + 180.0
            end
        end)
    end
    yawUsed = yawUsed or 0.0
    local halfRad = math.rad(yawUsed) * 0.5
    local transform = {
        Rotation = { W = math.cos(halfRad), X = 0.0, Y = 0.0, Z = math.sin(halfRad) },
        Translation = { X = loc.X, Y = loc.Y, Z = loc.Z },
        Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 },
    }

    -- Friendly-faction: fetch a reference now, apply pre-BeginPlay (composed
    -- with any caller preFinish) and again post-spawn.
    local fp = nil
    if makeFriendly then fp = Spawner.GetFriendlyFactionParams() end
    local effPreFinish = preFinish
    local hasLook = compositeLook and (compositeLook.params or compositeLook.archetype
        or compositeLook.bodyTypes or compositeLook.colorParams)
    if fp or hasLook then
        local base = preFinish
        effPreFinish = function(a)
            if base then pcall(base, a) end
            -- Pre-build: set the composite look so the pawn constructs it from
            -- these params at BeginPlay (post-build rebuild won't take on AI pawns).
            if hasLook then
                pcall(function()
                    Spawner.SetCompositeParams(a, compositeLook.params,
                        compositeLook.archetype, compositeLook.sex, compositeLook.bodyTypes,
                        compositeLook.colorParams)
                end)
            end
            if fp then Spawner.MakeFriendly(a, fp) end
        end
    end

    -- Resolve the FINAL, unique, persisted display label -- see the comment above this function.
    local finalLabel = presetInstanceLabel or Spawner.NextInstanceLabel(label)

    local actor = Spawner._DoEngineSpawn(gs, world, cls, transform, finalLabel, effPreFinish, aiClass)
    if not actor or not actor:IsValid() then
        return nil
    end
    if fp then Spawner.MakeFriendly(actor, fp) end

    -- Set-dressing makes a spawn INVULNERABLE. A raider must be killable, or the whole
    -- feature is a group of immortal zombies standing in your camp.
    if not Spawner.combatant then makeSetDressing(actor) end
    ensureController(actor)
    if Config.HIDE_NAMEPLATES then Spawner.HideNameplate(actor) end
    if Config.STRIP_INTERACTION then Spawner.StripInteraction(actor) end
    if Config.STRIP_QUEST_SCENARIO then Spawner.StripQuestScenario(actor) end
    -- Posed statues (AnimatedActors) let placed furniture pass through them, so RedFalcon can slide a
    -- stool under a sitter, while still blocking walking characters. Keyed off the class name so it
    -- applies on RESTORE too (restore re-enters Spawn; statues never hit the mover restoreHook).
    if Config.STATUE_IGNORE_FURNITURE and classPath and classPath:find("AnimatedActor") then
        Spawner.LetFurniturePass(actor)
    end
    -- Unconditional, EVERY spawn (2026-08-22, RedFalcon: walking actors/idle Senkamati couldn't be
    -- raytrace-targeted) -- LetFurniturePass above already covers this for statues as a side effect
    -- of its own broad channel sweep, but only statues go through that branch. Calling this
    -- unconditionally here is a harmless no-op re-set for statues (same value, idempotent) and the
    -- actual fix for everything else that spawns through this function -- crew/townsman/Senkamati/
    -- livestock/etc. -- without touching their other collision responses at all.
    Spawner.EnsureRaytraceChannel(actor)
    -- hasLook tracked on the entry itself (2026-08-19) so anything reading Spawner.spawned later --
    -- e.g. Spawner.ScanNearbyCustomization telling a recipe-reskinned spawn apart from a raw/vanilla
    -- one of the SAME underlying class -- doesn't have to guess from the label string, which varies
    -- by caller (lbspawn passes the raw typed input, lblook passes the recipe's own display name)
    -- and was never a reliable "was a look actually applied" signal on its own.
    table.insert(Spawner.spawned, { actor = actor, label = finalLabel, class = classPath,
        hasLook = hasLook and true or false, home = { X = loc.X, Y = loc.Y, Z = loc.Z }, yaw = yawUsed,
        idle = markIdle and true or false })
    ledgerAppend(actor)
    persistAppend(classPath, loc, aiControllerClassPath, yawUsed, makeFriendly, compositeLook, finalLabel)
    log(string.format("SPAWNED [%s] -> %s at (%.0f, %.0f, %.0f)",
        tostring(finalLabel), classPath, loc.X, loc.Y, loc.Z))
    -- Auto-target the probe (2026-08-18, RedFalcon's request): every LIVE placement becomes the
    -- lbprobe/lbprobedump target immediately, no separate aim-and-lbprobe step needed -- run
    -- lbprobedump right after spawning something to inspect exactly what you just placed. Gated on
    -- Spawner.restoring alone (not _suppressSpawnToast too) -- unlike the toast below, a cycle/undo
    -- replacement swapping in a new actor is still something worth being able to probe right away,
    -- even when it suppresses its own toast. Excludes RestoreFromPersist's own dozens of calls on
    -- world load, same reasoning as the toast: not something you just deliberately placed.
    if not Spawner.restoring then
        Spawner._lastProbedActor = actor
    end
    -- Auto-LOCK on spawn (2026-08-19, RedFalcon's correction: the earlier request above was meant
    -- for the actual live-edit target lock -- Spawner.lockedTarget, Num+ -- not the passive
    -- lbprobe/lbcustomnpc target; those are two separate things this file tracks). Every live
    -- placement becomes the locked target immediately, exactly as if Num+ had just been pressed on
    -- it -- same wrapper shape/StartTargetLockTick call Spawner.ToggleTargetLock's own "ON" branch
    -- uses. Same restoring-only gate as the probe target above.
    if not Spawner.restoring then
        Spawner.lockedTarget = { actor = actor, label = finalLabel, class = classPath }
        Spawner.StartTargetLockTick()
    end
    -- Only for live placements, not the dozens of Spawn calls RestoreFromPersist fires on world load,
    -- and not when the caller (Undo, pose-cycle) already shows its own more specific toast.
    if not Spawner.restoring and not Spawner._suppressSpawnToast then
        -- Composite-look spawns (crew/walkers/statues) build their body mesh asynchronously --
        -- senkaCrewFix waits ~4s before even touching it (see its own comment: reading/de-corrupting
        -- earlier hit a half-built composite). Reading CurrentBodyMeshName synchronously right here
        -- would just report the pre-build placeholder. Delay the body-type read for those; plain
        -- (non-composite) spawns have a fixed mesh already, so show immediately as before.
        if hasLook and ExecuteWithDelay then
            local gen = Spawner.generation
            ExecuteWithDelay(Config.SPAWN_TOAST_BODY_DELAY_MS or 4500, function()
                pcall(function()
                    if Spawner.generation ~= gen or not (actor and actor:IsValid()) then return end
                    local bodyLabel = Spawner.ShortArchetypeLabel(Spawner.CurrentBodyMeshName(actor))
                    if bodyLabel then
                        Spawner.Toast(string.format("Spawned: %s (%s)", tostring(finalLabel), bodyLabel), 2.0)
                    else
                        Spawner.Toast(string.format("Spawned: %s", tostring(finalLabel)), 2.0)
                    end
                end)
            end)
        else
            pcall(function()
                local bodyLabel = Spawner.ShortArchetypeLabel(Spawner.CurrentBodyMeshName(actor))
                if bodyLabel then
                    Spawner.Toast(string.format("Spawned: %s (%s)", tostring(finalLabel), bodyLabel), 2.0)
                else
                    Spawner.Toast(string.format("Spawned: %s", tostring(finalLabel)), 2.0)
                end
            end)
        end
    end
    return actor
end

--------------------------------------------------------------------
-- stripComponentsOfClass(actor, classPath) — destroy every component of a class on an actor.
-- Used by StripInteraction (removes the interaction-target components on set-dressing). All pcall'd.
--
-- LOGS UNCONDITIONALLY (not gated behind Config.VERBOSE) -- per project convention, troubleshooting
-- output for a strip that might silently be doing nothing must not be hidden behind an off-by-
-- default flag. Added 2026-08-07 after StripQuestScenario appeared to have no effect (Letty kept
-- talking) and StripInteraction's own component was ALREADY observed still present in a live probe
-- dump despite supposedly being destroyed -- this function previously failed completely silently on
-- every path (class not found, zero components matched, or the destroy call itself erroring inside
-- its own pcall), so there was no way to tell which. Now every path prints.
--
-- REAL BUG FOUND (2026-08-07, same day): even with the logging above, the "N matching component(s)
-- found" line printed fine but NOTHING after it ever printed -- not the destroy line, not the
-- "not valid" line, for ANY component, on ANY actor, across a full log capture. Root cause: the
-- original `local c = comps[i]` bracket-index access (present since before this session touched this
-- file) was NOT wrapped in pcall. If that array type doesn't support bracket indexing and raises a
-- real Lua error instead of returning nil, that error is uncaught locally -- it propagates straight
-- out of the `for` loop to the OUTER pcall wrapping the whole function, which silently swallows it.
-- That would explain both this session's mystery (missing destroy logs) AND the much earlier one
-- (R5CommonInteractionTargetComponent still showing up in a property dump despite StripInteraction
-- supposedly already destroying it) -- the destroy call was likely never reached in EITHER case. Now
-- both `comps[i]` and `comps:Get(i)` are pcall'd, and a total failure to access the index logs
-- explicitly instead of silently killing the rest of the function.
--------------------------------------------------------------------
local function stripComponentsOfClass(actor, classPath)
    pcall(function()
        local cls = StaticFindObject(classPath)
        if not (cls and cls:IsValid()) then
            print(string.format("[LivingBase] [strip] class not found: %s\n", classPath))
            return
        end
        local comps = actor:K2_GetComponentsByClass(cls)
        local n = 0
        pcall(function() n = comps:GetArrayNum() end)
        if n == 0 then pcall(function() n = #comps end) end
        print(string.format("[LivingBase] [strip] %s -> %s matching component(s) found (n type=%s).\n",
            classPath, tostring(n), type(n)))
        -- Loop wrapped in its OWN pcall, separate from the outer one, so a for-loop-level error (e.g.
        -- "'for' limit must be a number" if n isn't a true Lua number despite printing fine above) is
        -- caught and reported here instead of silently escaping to the outer pcall with zero trace.
        -- Prints as the FIRST thing in every iteration, before touching comps[i] at all, so even a
        -- crash/hang inside indexing shows exactly how far execution got.
        local okLoop, loopErr = pcall(function()
            for i = 1, n do
                local raw
                local okIdx, viaIdx = pcall(function() return comps[i] end)
                if okIdx then raw = viaIdx end
                if not raw then
                    local okGet, viaGet = pcall(function() return comps:Get(i) end)
                    if okGet then raw = viaGet end
                end
                -- Bracket-indexing this TArray type returns a RemoteUnrealParam WRAPPER, not a plain
                -- component reference -- confirmed live 2026-08-07 ("attempt to call a
                -- RemoteUnrealParam value (method 'IsValid')"). UE4SS's own dump_object.lua unwraps
                -- array elements the same way (`Elem:get():GetFullName()`), so try that here too.
                local c = raw
                if raw then
                    local okUnwrap, unwrapped = pcall(function() return raw:get() end)
                    if okUnwrap and unwrapped then c = unwrapped end
                end
                if c and c:IsValid() then
                    local okDestroy, err = pcall(function() c:K2_DestroyComponent(actor) end)
                    -- NOTE: do NOT trust c:IsValid() here as a success signal -- K2_DestroyComponent
                    -- marks the UObject as garbage but doesn't free the memory synchronously, so a
                    -- stale Lua handle's :IsValid() keeps reporting true until the next GC sweep even
                    -- when the destroy fully succeeded. Confirmed live 2026-08-07 (every single destroy
                    -- this session logged "still valid after=true" with zero errors). The real proof is
                    -- the post-loop recount below, not this per-call check.
                    print(string.format("[LivingBase] [strip]   destroy #%d: call %s%s\n",
                        i, okDestroy and "OK" or "ERRORED",
                        okDestroy and "" or (" (" .. tostring(err) .. ")")))
                else
                    print(string.format("[LivingBase] [strip]   #%d: could not access index (bracket ok=%s) -- skipped.\n",
                        i, tostring(okIdx)))
                end
            end
        end)
        if not okLoop then
            print(string.format("[LivingBase] [strip]   LOOP ERRORED: %s\n", tostring(loopErr)))
        end
        -- Post-loop recount: a fresh K2_GetComponentsByClass call reflects the actor's REAL current
        -- component list, unlike a stale per-instance :IsValid() check -- this is the actual proof
        -- destroy took effect.
        if n > 0 then
            local okRecount, remaining = pcall(function()
                local comps2 = actor:K2_GetComponentsByClass(cls)
                local n2 = 0
                pcall(function() n2 = comps2:GetArrayNum() end)
                if n2 == 0 then pcall(function() n2 = #comps2 end) end
                return n2
            end)
            print(string.format("[LivingBase] [strip]   recount after destroy: %s remaining (started with %d).\n",
                okRecount and tostring(remaining) or "ERROR", n))
        end
    end)
end

--------------------------------------------------------------------
-- Spawner.HideNameplate(actor) — remove the floating nameplate by DESTROYING
-- the R5 marker component(s). This is the version that WORKED (RedFalcon: hidden
-- before v0.38). It never broke persistence — the game just doesn't save our
-- spawns (fixed mod-side), so destroying the marker is safe. SetVisibility
-- did NOT hide it (the marker manager ignores component visibility).
--------------------------------------------------------------------
function Spawner.HideNameplate(actor)
    if not actor or not actor:IsValid() then return end
    pcall(function()
        local marker = actor.R5Marker
        if marker and marker:IsValid() then
            pcall(function() marker:DestroyMarkerComponent() end)
        end
    end)
    pcall(function()
        local cls = StaticFindObject("/Script/R5.R5MarkerComponent")
        if not (cls and cls:IsValid()) then return end
        local comps = actor:K2_GetComponentsByClass(cls)
        local n = 0
        pcall(function() n = comps:GetArrayNum() end)
        if n == 0 then pcall(function() n = #comps end) end
        for i = 1, n do
            local c = comps[i]; if not c then pcall(function() c = comps:Get(i) end) end
            if c and c:IsValid() then pcall(function() c:DestroyMarkerComponent() end) end
        end
    end)
end

--------------------------------------------------------------------
-- Spawner.ApplyComposite(actor, paramsPath, archetypePath) — re-skin a built
-- humanoid (e.g. a crew pawn) by swapping its composite-mesh DefaultParams
-- and/or ArchetypePreset, then rebuilding the visual. Used to give a crew the
-- REGULAR (non-corrupted) Senkamati tribal look. Same appearance system that
-- resisted override on the procedural Citizen_Walker (it re-randomizes in
-- BeginPlay) — crew may hold the override where citizens didn't. All pcall'd;
-- logs each step so an in-game test can tell us how far it got. EXPERIMENTAL.
--------------------------------------------------------------------
local function resolveAsset(path)
    if not path then return nil end
    local o = StaticFindObject(path)
    if o and o:IsValid() then return o end
    pcall(function() LoadAsset(path) end)
    o = StaticFindObject(path)
    if o and o:IsValid() then return o end
    return nil
end

-- Spawner.DeCorrupt(actor) — swap corrupted materials to clean ones per
-- Config.DECORRUPT_SWAPS. Runs post-build (materials must exist). For each mesh
-- slot whose current material name contains a rule's `match`, SetMaterial to the
-- rule's replacement. All pcall'd; prints a summary.
function Spawner.DeCorrupt(actor, rules)
    -- Gated: this runs ~12x per spawn per actor, so unconditional printing floods the
    -- log (and was a likely contributor to a crash during heavy scenes).
    local function say(m)
        if Config.VERBOSE then print("[LivingBase:DeCorrupt] " .. tostring(m) .. "\n") end
    end
    if not (actor and actor:IsValid()) then return end
    -- NEVER de-corrupt the PLAYER. If a stored ref or search ever resolves to the player
    -- pawn, painting our materials on the hero body crashes (confirmed 2026-07-09: a skin
    -- swap on SK_Fable_Male_01 crashed mid-movement). Cheap insurance.
    do
        local ok, ppawn = pcall(function()
            local pc = UEHelpers.GetPlayerController()
            return pc and pc:IsValid() and pc.Pawn or nil
        end)
        if ok and ppawn and ppawn:IsValid() and actor == ppawn then return 0, 0, 0 end
    end
    -- Rules are per spawn-type (mob vs crew re-skin): a crew body is a HUMAN mesh
    -- and takes a human skin material; a mob body is a Senkamati mesh whose skin
    -- gets re-assigned by its own composite build.
    rules = rules or Config.DECORRUPT_MOB or {}
    local swaps    = rules.swaps or {}
    local hides    = rules.hides or {}
    local replaces = rules.replaces or {}
    if #swaps == 0 and #hides == 0 and #replaces == 0 then return 0, 0, 0 end
    -- STALE-POINTER GUARD (2026-07-09). These rule tables live at MODULE scope, so the old
    -- one-shot `_tried` flag cached raw UObject pointers that outlived world loads and
    -- garbage collection. Handing a dangling UObject to SetMaterial/SetSkeletalMesh is a
    -- native crash — exactly what we caught: the dump lands INSIDE SetSkeletalMesh, in the
    -- same frame as the ">>> REPLACE" breadcrumb, and only after a session has been loading
    -- and despawning for a while. So validate on EVERY use and re-resolve when dead.
    -- `_miss` caps retries on an asset that genuinely doesn't exist, so we never reintroduce
    -- the ~20s LoadAsset hitch that `_tried` was originally added to cure.
    local function liveAsset(store, key, path)
        local o = store[key]
        if o and o:IsValid() then return o end
        if (store._miss or 0) >= 3 then return nil end
        o = resolveAsset(path)
        store[key] = o
        if o then
            store._miss = nil
        else
            store._miss = (store._miss or 0) + 1
            say("asset UNRESOLVED: " .. tostring(path))
        end
        return o
    end
    for _, sw in ipairs(swaps) do
        local mat = liveAsset(sw, "_mat", sw.to)
        -- Target's own name, so we skip re-swapping a material to itself (a rule
        -- like "MI_%a+_Male_Small" matches its own target once applied).
        if mat and not sw._matName then
            pcall(function() sw._matName = mat:GetFName():ToString() end)
        end
    end
    for _, rp in ipairs(replaces) do
        -- `toList` = pick one at random per actor (hair variety). `to` = fixed mesh.
        -- Either way we remember the target NAMES (strings — these never go stale) so a
        -- pattern can't re-replace its own result on the next retry pass.
        rp._targetNames = rp._targetNames or {}
        local function remember(o)
            local nm = ""
            pcall(function() nm = o:GetFName():ToString() end)
            if nm ~= "" then rp._targetNames[nm] = true end
        end
        if rp.toList then
            local stale = (not rp._meshes) or (#rp._meshes ~= #rp.toList)
            if not stale then
                for _, mo in ipairs(rp._meshes) do
                    if not (mo and mo:IsValid()) then stale = true; break end
                end
            end
            if stale then
                rp._meshes = {}
                for i, p in ipairs(rp.toList) do
                    local mo = liveAsset(rp, "_pool" .. i, p)
                    if mo then table.insert(rp._meshes, mo); remember(mo) end
                end
            end
        elseif rp.to then
            local mo = liveAsset(rp, "_mesh", rp.to)
            if mo then remember(mo) end
        end
    end
    local swapped, hidden, replaced = 0, 0, 0
    local function doComp(c)
        if not (c and c:IsValid()) then return end
        local compName = "?"
        if Config.VERBOSE then pcall(function() compName = c:GetFName():ToString() end) end
        -- Read this component's skeletal-mesh name once (drives hide + replace).
        local meshName = ""
        if #hides > 0 or #replaces > 0 then
            pcall(function()
                local sk = c.SkeletalMesh
                if not (sk and sk:IsValid()) and c.GetSkeletalMeshAsset then sk = c:GetSkeletalMeshAsset() end
                if sk and sk:IsValid() then meshName = sk:GetFName():ToString() end
            end)
        end
        if meshName ~= "" then
            -- REPLACE takes priority (e.g. witch headdress -> clean dreadlocks).
            local didReplace = false
            for _, rp in ipairs(replaces) do
                -- Already one of this rule's targets? Then this actor is done — don't
                -- re-roll its hair on every retry pass.
                local alreadyTarget = rp._targetNames and rp._targetNames[meshName]
                if not alreadyTarget and meshName:find(rp.match) then
                    -- toList => pick a random style for THIS actor; otherwise fixed mesh.
                    local target = rp._mesh
                    if rp._meshes and #rp._meshes > 0 then
                        target = rp._meshes[math.random(#rp._meshes)]
                    end
                    -- Re-check validity at the MOMENT of use. liveAsset() refreshed it above,
                    -- but a GC between then and here would still hand SetSkeletalMesh a
                    -- dangling pointer — which is a native crash we cannot pcall our way out of.
                    if target and target:IsValid() then
                        say(string.format(">>> REPLACE mesh on comp[%s]: %s -> (rule %s)",
                            compName, meshName, tostring(rp.name or "")))
                        -- Hide before mutating: swapping the mesh on a visible, actively
                        -- animating composite component is the riskiest thing we do.
                        pcall(function() c:SetVisibility(false, false) end)
                        local ok = pcall(function() c:SetSkeletalMeshAsset(target) end)
                        if not ok then ok = pcall(function() c:SetSkeletalMesh(target, false) end) end
                        if ok then
                            -- Composite hair follows the body via leader-pose; reassigning the
                            -- mesh can leave that binding stale. Re-bind before showing it.
                            pcall(function()
                                local body = actor.Mesh
                                if body and body:IsValid() then
                                    c:SetLeaderPoseComponent(body, false, false)
                                end
                            end)
                            pcall(function() c:SetVisibility(true, false) end)
                            local tn = "?"
                            pcall(function() tn = target:GetFName():ToString() end)
                            replaced = replaced + 1
                            didReplace = true
                            say(string.format("replaced mesh: %s -> %s (%s)", meshName,
                                tn, tostring(rp.name or "")))
                        else
                            -- Swap rejected: un-hide so we don't leave a bald invisible head.
                            pcall(function() c:SetVisibility(true, false) end)
                            say("replace FAILED on " .. meshName)
                        end
                    end
                end
            end
            -- HIDE whole corrupted pieces (skip anything we just replaced).
            if not didReplace then
                for _, h in ipairs(hides) do
                    if meshName:find(h) then   -- Lua pattern (variant-number %d+)
                        -- IDEMPOTENT: if this piece is already hidden, do NOT re-hide or
                        -- re-count it. Re-counting already-hidden armor as a "change" kept
                        -- `changed > 0` forever, so the retry loop never converged — it
                        -- ground all 12 passes on every mob. Three Senkamati doing that at
                        -- once on a loaded world is the load spike behind the late-spawn
                        -- crash. Skipping already-hidden pieces lets it converge in ~3.
                        local alreadyHidden = false
                        pcall(function() alreadyHidden = c.bHiddenInGame == true end)
                        if not alreadyHidden then
                            say(string.format(">>> HIDE mesh on comp[%s]: %s", compName, meshName))
                            pcall(function() c:SetVisibility(false, false) end)
                            pcall(function() c:SetHiddenInGame(true, false) end)
                            hidden = hidden + 1
                            say("hid mesh: " .. meshName)
                        end
                    end
                end
            end
        end
        local nm = 0
        pcall(function() nm = c:GetNumMaterials() end)
        for m = 0, (nm - 1) do
            local curName = ""
            pcall(function()
                local cur = c:GetMaterial(m)
                if cur and cur:IsValid() then curName = cur:GetFName():ToString() end
            end)
            for _, sw in ipairs(swaps) do
                -- Lua PATTERN match (so "MI_%a+_Male_Small" catches any ethnicity).
                -- Skip if it's already the target (rules can match their own result).
                -- NOTE: "Fable" is just another ETHNICITY in the ShipCrew archetype pool
                -- (Scum/Orient/African/Native/Fable/...), NOT a special hero body — the
                -- v1.97 guard that skipped it was wrong and left those Warriors unskinned.
                -- Scum->Native and Orient->Native both swap cleanly; Fable is the same op.
                -- The player pawn (the one thing we must never touch) is guarded at the
                -- top of DeCorrupt instead.
                -- Same stale-pointer hazard as the mesh replace: `_mat` is cached at module
                -- scope and can be GC'd out from under us between world loads.
                if sw._mat and sw._mat:IsValid() and curName ~= "" and curName ~= sw._matName
                    and curName:find(sw.match) then
                    say(string.format(">>> SWAP material slot %d on comp[%s]: %s", m, compName, curName))
                    local ok = pcall(function() c:SetMaterial(m, sw._mat) end)
                    if ok then
                        -- READ BACK: SetMaterial "succeeds" even when the composite
                        -- re-assigns right after. Only shout if it did NOT take.
                        local after = "?"
                        pcall(function()
                            local a = c:GetMaterial(m)
                            if a and a:IsValid() then after = a:GetFName():ToString() end
                        end)
                        swapped = swapped + 1
                        if after == curName then
                            say(string.format("swap DID NOT TAKE on slot %d: %s", m, curName))
                        else
                            say(string.format("swapped %s -> %s", curName, after))
                        end
                    end
                end
            end
        end
    end
    pcall(function() local mm = actor.Mesh; if mm and mm:IsValid() then doComp(mm) end end)
    local n = 0
    local cls = StaticFindObject("/Script/Engine.SkeletalMeshComponent")
    if cls and cls:IsValid() then
        local comps = actor:K2_GetComponentsByClass(cls)
        pcall(function() n = comps:GetArrayNum() end)
        if n == 0 then pcall(function() n = #comps end) end   -- GetArrayNum returns 0 here; #comps works
        for i = 1, n do
            local c = nil
            pcall(function() c = comps[i] end)
            if c == nil then pcall(function() c = comps:Get(i) end) end
            pcall(function() if c ~= nil and type(c) == "userdata" and c.get then c = c:get() end end)
            doComp(c)
        end
    end
    -- Only report when something actually changed — this runs ~12x per spawn and the
    -- "0 swapped, 0 hidden" spam was drowning the log (and hurting perf in busy scenes).
    -- Unconditional (was say(), gated behind Config.VERBOSE) -- actively debugging why the
    -- Hunter/Caster/Healer crew re-skin's hide/replace rules show no effect (2026-08-10); with
    -- VERBOSE off this summary line was the ONLY way to tell "ran and matched nothing" apart
    -- from "never ran at all", and it was silent.
    if (swapped + hidden + replaced) > 0 then
        always(string.format("de-corrupt: %d swapped, %d hidden, %d replaced (%d components) rules=%s",
            swapped, hidden, replaced, n, tostring(rules)))
    end
    -- Return TOTAL changes so callers can stop retrying once the look has converged
    -- (nothing left to change), instead of grinding a fixed number of passes.
    return (swapped + hidden + replaced), swapped, n
end

-- Spawner.ForceHeadwear(actor, targetPath) -- 2026-08-10: a narrow, POSITIONAL escape hatch for
-- the female-walker headwear slot specifically (Config.FEMALE_WALKER_OVERLAYS). Content-based
-- matching (DeCorrupt's normal "Female_Headband"/"Female_Hat" patterns) kept missing SOME random
-- roll of that slot -- Marita and the Merchant both intermittently ended up bald or wearing the
-- wrong item even with both patterns in place; root cause (a third unseen naming variant? a
-- retry-timing gap where that slot settles later than the others?) was never fully pinned down.
-- Rather than keep guessing at more name patterns, this sidesteps content-matching entirely:
-- confirmed via many repeated live probes that on THIS WALKER SPECIFICALLY the headwear component
-- is ALWAYS the first "real" (non-body, non-empty-weapon) SkeletalMeshComponent in the
-- K2_GetComponentsByClass sweep, regardless of which random variant it currently shows -- every
-- probe this session (original baseline, post-overlay Letty/Marita/Merchant re-checks) agreed on
-- this order without exception.
-- BUG FIX (2026-08-11, RedFalcon's report + live probe): that "always first" claim was only ever
-- validated against Marita/Merchant, whose composites reliably roll WITH a headwear piece. The
-- generic Standing slot (added later, see Testbed.ApplyFemaleReskinTarget) can roll with NO
-- headwear component at all -- confirmed directly by probe. When that happens, "first real
-- component after the body" is the TORSO instead, and this function was overwriting it with a
-- hat mesh unconditionally -- RedFalcon: "the spawn before the processing is NOT topless" pinned this
-- down exactly (fine pre-process, topless right after ForceHeadwear runs). Now EXCLUDES every
-- known non-headwear piece by name pattern (Torso/Legs/Feet/Hand/Belt/Frog/Sling/Eyebrows/Hair_)
-- rather than trusting positional order alone -- if nothing SAFE is left to grab, this returns
-- false (no hat forced this spawn) instead of clobbering a real garment piece. Callers that need
-- a guaranteed hat should try a content-matched `replaces` rule (Hat/Headband/Bandana) FIRST, the
-- same safe mechanism DeCorrupt already uses everywhere else, and treat this as a last resort.
local FORCEHEADWEAR_EXCLUDE = {
    "Torso", "Legs", "Feet", "Hand", "Belt", "Frog", "Sling", "Eyebrows", "Hair_",
}
function Spawner.ForceHeadwear(actor, targetPath)
    if not (actor and actor:IsValid() and targetPath) then return false end
    local target = resolveAsset(targetPath)
    if not (target and target:IsValid()) then return false end
    local cls = StaticFindObject("/Script/Engine.SkeletalMeshComponent")
    if not (cls and cls:IsValid()) then return false end
    local comps
    pcall(function() comps = actor:K2_GetComponentsByClass(cls) end)
    if not comps then return false end
    local n = 0
    pcall(function() n = comps:GetArrayNum() end)
    if n == 0 then pcall(function() n = #comps end) end
    local bodyMeshName = ""
    pcall(function()
        local mm = actor.Mesh
        if mm and mm:IsValid() then
            local sk = mm.SkeletalMesh
            if not (sk and sk:IsValid()) and mm.GetSkeletalMeshAsset then sk = mm:GetSkeletalMeshAsset() end
            if sk and sk:IsValid() then bodyMeshName = sk:GetFName():ToString() end
        end
    end)
    for i = 1, n do
        local c = nil
        pcall(function() c = comps[i] end)
        if c == nil then pcall(function() c = comps:Get(i) end) end
        pcall(function() if c ~= nil and type(c) == "userdata" and c.get then c = c:get() end end)
        if c and c:IsValid() then
            local meshName = ""
            pcall(function()
                local sk = c.SkeletalMesh
                if not (sk and sk:IsValid()) and c.GetSkeletalMeshAsset then sk = c:GetSkeletalMeshAsset() end
                if sk and sk:IsValid() then meshName = sk:GetFName():ToString() end
            end)
            -- Skip the body itself, empty weapon slots (meshName == ""), and every KNOWN
            -- non-headwear garment piece -- only an unrecognized name (the presumed headwear
            -- slot) is safe to grab positionally.
            local excluded = false
            if meshName ~= "" then
                for _, pat in ipairs(FORCEHEADWEAR_EXCLUDE) do
                    if meshName:find(pat) then excluded = true; break end
                end
            end
            if meshName ~= "" and meshName ~= bodyMeshName and not excluded then
                local ok = pcall(function() c:SetSkeletalMeshAsset(target) end)
                if not ok then ok = pcall(function() c:SetSkeletalMesh(target, false) end) end
                return ok
            end
        end
    end
    return false
end

-- Spawner.SetColorControllers/ApplyHairColor/RandomizeGarmentColors REMOVED (2026-08-11,
-- debug-tool cleanup). CONCLUDED DEAD: SetColorControllerValue sets + reads back correctly
-- but never visibly renders on an already-built pawn -- confirmed via a live read-back
-- test, a retry after a hair-mesh swap (in case only the original mesh's material was
-- untintable), and a forced render-state refresh (the SetActorHiddenInGame toggle that
-- fixed the analogous transform-desync bug elsewhere in this file did NOT fix this one).
-- It's a build-time-only input, same class of limitation as SetCompositeParams/ColorParams
-- below. Don't re-add without a genuinely new theory for forcing a composite rebuild.

-- Spawner.HasMeshMatching(actor, pattern) — does any skeletal-mesh component's mesh
-- name match this Lua pattern? Used to tell a BALD pawn (no SK_Hair_* component) from
-- one that already has hair — we can only REPLACE meshes, never create components, so
-- a bald pawn needs its hat/head piece turned into hair instead.
function Spawner.HasMeshMatching(actor, pattern)
    if not (actor and actor:IsValid() and pattern) then return false end
    local found = false
    local cls = StaticFindObject("/Script/Engine.SkeletalMeshComponent")
    if not (cls and cls:IsValid()) then return false end
    local comps = actor:K2_GetComponentsByClass(cls)
    local n = 0
    pcall(function() n = comps:GetArrayNum() end)
    if n == 0 then pcall(function() n = #comps end) end
    for i = 1, n do
        local c = nil
        pcall(function() c = comps[i] end)
        if c == nil then pcall(function() c = comps:Get(i) end) end
        pcall(function() if c ~= nil and type(c) == "userdata" and c.get then c = c:get() end end)
        if c and c:IsValid() then
            pcall(function()
                local sk = c.SkeletalMesh
                if not (sk and sk:IsValid()) and c.GetSkeletalMeshAsset then sk = c:GetSkeletalMeshAsset() end
                if sk and sk:IsValid() and sk:GetFName():ToString():find(pattern) then found = true end
            end)
        end
        if found then break end
    end
    return found
end

-- Spawner.DeCorruptByClass(shortClassName, rules, targetActor) — de-corrupt a live actor
-- of that class using a FRESH reference (K2_GetComponentsByClass returns 0 on captured
-- spawn refs, but works on FindAllOf refs). Returns total meshes hidden.
-- BUG FIX (2026-08-11, RedFalcon's report: "the script that removes the mask, removes it from
-- the masked version too"). This used to apply `rules` to EVERY live actor of
-- shortClassName, not just the one that owns this particular retry loop — fine when only
-- one instance of a mob class existed, but the Num7 roster (and restore) can have a
-- helmet-ON and a helmet-OFF Hunter/Caster mob alive AT THE SAME TIME, sharing the same
-- underlying class. Each row's own tryFix() retries were stomping every OTHER row's actor
-- of that class with its own rules, so whichever row's retry fired last would silently
-- decide the head-hide state for ALL of them, including ones that should have kept their
-- headdress. `targetActor` (the specific actor this call is responsible for, passed by
-- senkaMobFix) narrows the FRESH FindAllOf list down to the one entry whose GetFName()
-- matches it — GetFName is a plain UObject-level call and (unlike the component-array
-- reflection this workaround exists for) works fine on the stale captured ref, so it's
-- safe to read straight off `targetActor` for the comparison. Backward compatible: if no
-- targetActor is passed, falls back to the old "every live actor of this class" behavior.
function Spawner.DeCorruptByClass(shortClassName, rules, targetActor)
    if not shortClassName then return 0, 0 end
    local list = FindAllOf(shortClassName)
    if not list then return 0, 0 end
    local targetName = nil
    if targetActor and targetActor:IsValid() then
        pcall(function() targetName = targetActor:GetFName():ToString() end)
    end
    local totalHidden, count, maxComps = 0, 0, 0
    for _, a in ipairs(list) do
        if a and a:IsValid() then
            local matches = true
            if targetName then
                local aName = nil
                pcall(function() aName = a:GetFName():ToString() end)
                matches = (aName == targetName)
            end
            if matches then
                count = count + 1
                -- NB: don't assign to `_` here — it's the (const in Lua 5.4+) loop variable
                -- of the enclosing `for _, a`. Capture into fresh locals instead.
                local h, n = 0, 0
                local ok, rh, _sw, rn = pcall(Spawner.DeCorrupt, a, rules)
                if ok then h, n = rh or 0, rn or 0 end
                totalHidden = totalHidden + (h or 0)
                if (n or 0) > maxComps then maxComps = n end
            end
        end
    end
    if count == 0 then
        print("[LivingBase:DeCorrupt] DeCorruptByClass: none live for " .. tostring(shortClassName)
            .. (targetName and (" (target=" .. targetName .. ")") or "") .. "\n")
    end
    -- maxComps lets the caller know whether the (late-attaching) armor is present.
    return totalHidden, maxComps
end



-- Spawner.SetCompositeParams(actor, paramsPath, archetypePath) — set the
-- composite DefaultParams/ArchetypePreset ONLY (no rebuild). Meant to run in the
-- deferred spawn window (preFinish) so the pawn BUILDS its look from these at
-- BeginPlay, instead of re-skinning after the fact (which the rebuild API won't
-- do on a live AI pawn). All pcall'd; prints what it set.
function Spawner.SetCompositeParams(actor, paramsPath, archetypePath, sex, bodyTypesPath, colorPath)
    -- Unconditional -- was gated behind Config.VERBOSE until 2026-08-07, which meant a compositeLook
    -- that silently failed to resolve (e.g. a typo'd archetype path) gave zero trace, same class of
    -- bug already fixed once this session for Spawner.Spawn's own SPAWN FAILED branches.
    local function say(m) print("[LivingBase:Composite] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then return false end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say("preFinish: no CompositeMeshComponent yet")
        return false
    end
    local params = resolveAsset(paramsPath)
    local arch   = resolveAsset(archetypePath)
    -- BodyTypeParams = the list the body mesh is RESOLVED FROM (by the archetype's
    -- CharacterSex + AllowedBodyTypes). AI pawns lack female entries, so without
    -- this a female archetype builds its clothes onto a male body.
    local bodies = resolveAsset(bodyTypesPath)
    -- ColorParams (R5CompositeMeshColorCustomizationParams) -- found live 2026-08-07 via the
    -- CompositeMeshComponent property dump (dump_object): CREW_CLASS defaults this to a generic
    -- /R5BusinessRules/.../NPC/Common/DA_NPC_Common_CompositeMeshColorCustomizationParams (the
    -- blue-top/red-white-bottom look every faction-visitor reskin was stuck with). Each faction/role
    -- ships its own "..._PresetColor" asset of this same type -- that's the fix.
    local color  = resolveAsset(colorPath)
    if bodies then pcall(function() comp.BodyTypeParams = bodies end) end
    if params then pcall(function() comp.DefaultParams = params end) end
    if arch   then pcall(function() comp.ArchetypePreset = arch end) end
    if color  then pcall(function() comp.ColorParams = color end) end
    -- Optional sex override: 1=Male, 2=Female. The archetype's own sex usually wins.
    if sex and sex ~= 0 then pcall(function() comp:SetCharacterSex(sex) end) end
    say(string.format("preFinish set bodies=%s params=%s archetype=%s color=%s sex=%s (pre-build)",
        bodies and "ok" or (bodyTypesPath and "MISS" or "-"),
        params and "ok" or (paramsPath and "MISS" or "-"),
        arch and "ok" or (archetypePath and "MISS" or "-"),
        color and "ok" or (colorPath and "MISS" or "-"), tostring(sex or "-")))
    return true
end

-- Spawner.SetAIPawnParams(actor, path) -- EXPERIMENTAL (2026-08-09). Overriding just the
-- pawn's AIControllerClass (see aiClass in _DoEngineSpawn above) turned out to have NO
-- visible effect on Hunter/Caster/Healer's walk behavior -- confirmed live: no freeze, no
-- crash, but no wandering either. Working theory: in this R5 framework the AIController is a
-- thin dispatcher and the actual per-archetype behavior comes from a Data Asset referenced by
-- the PAWN itself (`AIPawnParams`, confirmed present on both the Warrior and the Hunter via
-- live probe dumps) -- so swapping only the controller class leaves the mob still running its
-- own combat-oriented params regardless of which brain possesses it. This sets AIPawnParams
-- (the plain property) AND OverriddenAIPawnParams (a second property found on the same probe
-- dump, shaped exactly like a runtime override slot -- FWeakObjectPtr, paired with an
-- equivalent OverriddenAbilitySystemParams) to the SAME data asset the Warrior itself already
-- walks with, confirmed via probe: DA_Mob_Crew_Regular_AIPawnParams. Must run in the deferred
-- spawn window (preFinish), same reasoning as SetCompositeParams above -- post-build changes
-- don't take on a live AI pawn. All pcall'd; prints unconditionally so an in-game test tells
-- us which property (if either) actually took.
function Spawner.SetAIPawnParams(actor, path)
    local function say(m) print("[LivingBase:AIPawnParams] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then return false end
    if not path then return false end
    local asset = resolveAsset(path)
    if not asset then
        say("UNRESOLVED: " .. tostring(path))
        return false
    end
    local okPlain = pcall(function() actor.AIPawnParams = asset end)
    local okOverr = pcall(function() actor.OverriddenAIPawnParams = asset end)
    say(string.format("set AIPawnParams=%s OverriddenAIPawnParams=%s -> %s",
        okPlain and "ok" or "FAILED", okOverr and "ok" or "FAILED", path))
    return okPlain or okOverr
end

function Spawner.ApplyComposite(actor, paramsPath, archetypePath)
    -- Always prints (experimental diagnostic — user must see it even if VERBOSE off).
    local function say(m) print("[LivingBase:Composite] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then return false end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say("no CompositeMeshComponent on actor")
        return false
    end
    local params = resolveAsset(paramsPath)
    local arch   = resolveAsset(archetypePath)
    if not params and not arch then
        say("neither params nor archetype resolved:\n    params=" ..
            tostring(paramsPath) .. "\n    arch=" .. tostring(archetypePath))
        return false
    end
    if not params then say("WARN params unresolved: " .. tostring(paramsPath)) end
    if not arch   then say("WARN archetype unresolved: " .. tostring(archetypePath)) end
    -- Readback helper: does a property write actually land on this component?
    local function nameOf(get)
        local s = "<nil>"
        pcall(function() local o = get(); if o and o:IsValid() then s = o:GetFullName() end end)
        return s
    end
    say("BEFORE DefaultParams=" .. nameOf(function() return comp.DefaultParams end))
    say("BEFORE Archetype  =" .. nameOf(function() return comp.ArchetypePreset end))
    if params then pcall(function() comp.DefaultParams = params end) end
    if arch   then pcall(function() comp.ArchetypePreset = arch end) end
    say("AFTER  DefaultParams=" .. nameOf(function() return comp.DefaultParams end))
    say("AFTER  Archetype  =" .. nameOf(function() return comp.ArchetypePreset end))
    -- Rebuild the visual. Try the documented triggers in order; all pcall'd.
    -- ConstructVisualFromParams rebuilds from the (new) params/archetype;
    -- the edit-transaction is a second lever in case the first is a no-op.
    pcall(function() comp:ConstructVisualFromParams(0) end)
    pcall(function() comp:StartCharacterEdit() end)
    pcall(function() comp:EndCharacterEdit(true) end)
    local built, sex = "?", "?"
    pcall(function() built = comp.BuildedCompositeMeshes:GetArrayNum() end)
    pcall(function() sex = comp:GetBodySex() end)
    say(string.format("applied %s%s -> BuildedCompositeMeshes=%s BodySex=%s",
        params and "params " or "", arch and "archetype" or "(no arch)",
        tostring(built), tostring(sex)))
    return true
end
-- CONCLUDED DEAD for `archetypePath` specifically (2026-08-14, live-tested against the Senkamati
-- statue's random-archetype problem): calling this with an `archetypePath` reads back a genuine
-- success at every step (comp.ArchetypePreset visibly changes from BEFORE to AFTER, the rebuild
-- reports "applied... BuildedCompositeMeshes=N"), but the actual rendered body mesh never
-- changes — same "build-time-only consumed input" wall already concluded for `ColorParams` just
-- above this function. `paramsPath` (outfit/DefaultParams) is unaffected by this and remains the
-- proven, working half of this function — this dead end is scoped to the archetype argument
-- only. Don't retry forcing archetype through this function (or invent a new post-build variant
-- of the same idea) without a genuinely new theory; two independent build-time-only-input walls
-- (color, now archetype) is a real pattern in this game's composite system, not a coincidence.
--
-- ADDENDUM (2026-08-19): the "paramsPath remains proven working" claim above needs a caveat.
-- Live-tested giving the Gatherer (5 BuildedCompositeMeshes entries, no Headgear at all) the
-- Buccaneers Merchant 01's DefaultParams (11 entries, includes a hat) via THIS function, on an
-- actor that had been alive/walking for a while (not freshly spawned): comp.DefaultParams read
-- back correctly changed, but `BuildedCompositeMeshes` stayed at 5 -- the rebuild never actually
-- re-ran the composite construction from the new params AT ALL, a different failure mode than
-- archetypePath's own (which DID show the rebuild "succeed" per its own reporting, just not
-- render). Suspect cause: this function's call order is ConstructVisualFromParams ->
-- StartCharacterEdit -> EndCharacterEdit -- the rebuild fires BEFORE the edit session opens, then
-- the session opens/closes around nothing. See Spawner.ApplyCompositeOrdered below for the
-- corrected-order variant this addendum motivated -- test THAT before concluding paramsPath is
-- dead post-build too; don't treat the original "proven working" note as still fully accurate
-- until it's confirmed one way or the other.

-- Spawner.ApplyCompositeOrdered(actor, paramsPath, say) -- TEMP DEV/TEST TOOL (2026-08-19),
-- companion to Spawner.ApplyComposite's own addendum just above. Same property write, same three
-- rebuild-trigger calls, but wraps the write+rebuild INSIDE the edit session instead of firing the
-- rebuild before the session opens: StartCharacterEdit() -> comp.DefaultParams = params ->
-- ConstructVisualFromParams(0) -> EndCharacterEdit(true). All three calls are already proven not
-- to crash (ApplyBodySex/ApplyComposite have called this exact trio many times) -- only the ORDER
-- is new, not any new engine surface, so this carries no additional crash risk per §3h's own
-- standard. Reports BuildedCompositeMeshes before/after so a real rebuild (array count actually
-- changing, e.g. 5 -> 11) is unambiguous from a no-op (count staying put, what ApplyComposite's
-- own unordered call just produced).
function Spawner.ApplyCompositeOrdered(actor, paramsPath, say)
    say = say or function(m) print("[LivingBase:CompositeOrdered] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then say("no actor"); return false end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say("no CompositeMeshComponent on actor")
        return false
    end
    local params = resolveAsset(paramsPath)
    if not params then
        say("params unresolved: " .. tostring(paramsPath))
        return false
    end
    local function builtCount()
        local n = "?"
        pcall(function() n = comp.BuildedCompositeMeshes:GetArrayNum() end)
        return n
    end
    local before = builtCount()
    local okEdit = pcall(function() comp:StartCharacterEdit() end)
    pcall(function() comp.DefaultParams = params end)
    local okBuild = pcall(function() comp:ConstructVisualFromParams(0) end)
    local okEnd = pcall(function() comp:EndCharacterEdit(true) end)
    local after = builtCount()
    say(string.format("StartCharacterEdit=%s ConstructVisualFromParams=%s EndCharacterEdit=%s -- BuildedCompositeMeshes before=%s after=%s (requested %s)",
        tostring(okEdit), tostring(okBuild), tostring(okEnd), tostring(before), tostring(after), paramsPath))
    return true
end
-- CONCLUDED DEAD (2026-08-19), live-tested via lbtestparamswap2 giving the long-alive Gatherer the
-- Buccaneers Merchant 01's DefaultParams (5 -> 11 entries expected, including a Headgear piece she
-- has none of): StartCharacterEdit/ConstructVisualFromParams/EndCharacterEdit all reported success
-- (no pcall failures), yet BuildedCompositeMeshes stayed at 5 -> 5 -- the mesh-piece list itself
-- never gets reconstructed post-build, regardless of whether the rebuild trigger fires before or
-- inside the edit session (Spawner.ApplyComposite's own unordered call showed the identical 5 -> 5
-- symptom first). This is a HARDER wall than archetypePath/ColorParams above -- those at least
-- showed the array "rebuild" per its own reporting, just not render; here the array count itself
-- never moves. Retracts this file's earlier "paramsPath remains the proven, working half" claim as
-- not holding for an actor that's been alive/walking a while (the original claim may have been
-- observed on a much-more-recently-spawned actor, or by a different verification standard than
-- comparing real array counts) -- don't trust that older note without re-verifying on a fresh
-- spawn first. Bottom line for "can an empty composite slot be filled on an already-spawned
-- actor": NO, not via anything in dumpCompositeFunctions' own list, tried two different call
-- orders. The only proven lever for composite pieces remains pre-build (compositeLook/
-- SetCompositeParams in the deferred spawn window) -- respawning is still required. Don't retry
-- ConstructVisualFromParams-based rebuilds a third way without a genuinely new theory.

-- Spawner.ApplyBodySex(actor, newSex) -- TEMP DEV/TEST TOOL (2026-08-14). RedFalcon probed a wild male
-- Standing NPC via HOME+PAUSE and noticed IsBodySexChangeAvailable=true (dumpCustomizability) --
-- distinct from the ColorParams/ArchetypePreset walls above, since THOSE are plain property writes
-- through the generic ApplyComposite rebuild recipe, while sex has its own dedicated setter,
-- comp:SetCharacterSex(newSex) (already used PRE-build in Spawner.SetCompositeParams, 1=Male/
-- 2=Female -- "the archetype's own sex usually wins" there). Worth testing POST-build specifically
-- because it's a genuinely different code path from the two already-confirmed-dead ones, not a
-- retry of either. Same BEFORE/AFTER readback pattern as ApplyComposite so a live test tells us
-- immediately whether this is a third build-time-only wall or an actual working lever.
function Spawner.ApplyBodySex(actor, newSex)
    local function say(m) print("[LivingBase:BodySex] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then say("no actor"); return false end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say("no CompositeMeshComponent on actor")
        return false
    end
    local before = "?"
    pcall(function() before = comp:GetBodySex() end)
    local okSet = pcall(function() comp:SetCharacterSex(newSex) end)
    say(string.format("SetCharacterSex(%s) call %s", tostring(newSex), okSet and "ok" or "FAILED"))
    pcall(function() comp:ConstructVisualFromParams(0) end)
    pcall(function() comp:StartCharacterEdit() end)
    pcall(function() comp:EndCharacterEdit(true) end)
    local after, built = "?", "?"
    pcall(function() after = comp:GetBodySex() end)
    pcall(function() built = comp.BuildedCompositeMeshes:GetArrayNum() end)
    say(string.format("BEFORE BodySex=%s -> AFTER BodySex=%s (requested %s) BuildedCompositeMeshes=%s",
        tostring(before), tostring(after), tostring(newSex), tostring(built)))
    return true
end

-- Spawner.ApplySexChangeToNearest(say) moved further down this file, right after
-- findNearestSpawnInFront's own definition -- see that spot for why (2026-08-17 lbsexchange fix).

-- Spawner.ApplyBodyType(actor, tagName, bodySex, forceLoad) -- TEMP DEV/TEST TOOL (2026-08-15).
-- RedFalcon's follow-up to ApplyBodySex's success: "something like the sexchange or pose change
-- [for] the mesh in use, something we missed?" -- checked UE4SS_ObjectDump.txt for every function
-- R5CompositeMeshComponent declares (the actual source SetCharacterSex/IsBodySexChangeAvailable
-- were found in originally) and found `SetBody(InBodyType: FGameplayTag, InBodySex: EBodySex,
-- bForceLoad: bool)` sitting right next to SetCharacterSex -- a GENUINELY DIFFERENT mechanism from
-- the confirmed-dead ArchetypePreset DataAsset property (item 59): body type here is a GAMEPLAY
-- TAG ("Customization.Morph.BodyType.<Family>", confirmed live via dumpAvailableBodyTypes, not
-- guessed), not an asset reference. FGameplayTag is a one-field struct (TagName, an FName) --
-- written here as a plain `{ TagName = tagName }` Lua table, same convention Spawner.WarpNear
-- already uses for FVector. Same BEFORE/AFTER readback pattern as ApplyBodySex/ApplyComposite so a
-- live test is unambiguous about whether this is a working lever or a third instance of the
-- "reports success, never renders" wall.
--
-- CONFIRMED LIVE (2026-08-15) TO CRASH THE GAME, reproduced twice in a row (F4 test key, since
-- removed -- see main.lua's own removal note at the old register() call site, and CLAUDE.md item
-- 64). `comp:SetBody(...)` itself triggers a native crash -- pcall does not and cannot catch it,
-- same class of crash as Config.TATTOO_TEST_PARAMS. UE4SS.log showed ZERO output from this
-- function's own `say()` calls either time (the FIRST print happens right after the pcall-wrapped
-- SetBody call returns -- never printing means execution never returned to Lua at all). Kept below
-- purely as a documented record of what was tried and found dangerous; DO NOT wire this into any
-- live key/spawn path or call it again without a genuinely new theory about the crash.
function Spawner.ApplyBodyType(actor, tagName, bodySex, forceLoad)
    local function say(m) print("[LivingBase:BodyType] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then say("no actor"); return false end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say("no CompositeMeshComponent on actor")
        return false
    end
    local function currentTag()
        local n = "?"
        pcall(function()
            local t = comp:GetBodyType()
            local nm = t["TagName"]
            if nm then n = nm:ToString() end
        end)
        return n
    end
    local before = currentTag()
    local okSet = pcall(function()
        comp:SetBody({ TagName = tagName }, bodySex, forceLoad)
    end)
    say(string.format("SetBody(%s, sex=%s, forceLoad=%s) call %s",
        tostring(tagName), tostring(bodySex), tostring(forceLoad), okSet and "ok" or "FAILED"))
    local after = currentTag()
    local built = "?"
    pcall(function() built = comp.BuildedCompositeMeshes:GetArrayNum() end)
    say(string.format("BEFORE BodyType=%s -> AFTER BodyType=%s (requested %s) BuildedCompositeMeshes=%s",
        before, after, tostring(tagName), tostring(built)))
    return true
end

-- SUPERSEDED same day by Spawner.ApplyBlueprintPose, below -- the live AnimInstance probe (item 62
-- follow-up) proved both Standing_01 and Sitting_01 run in BlueprintMode, not SingleNode, so there
-- is no static AnimSequence to hand SetAnimationMode/SetAnimation here; kept for reference/any
-- future genuinely-SingleNode target, not called by the current F5 test key.
-- Spawner.ApplyPose(actor, animSequencePath) -- TEMP DEV/TEST TOOL (2026-08-14). RedFalcon asked,
-- after ApplyBodySex confirmed a genuine post-build setter CAN visibly re-render a pawn (unlike
-- the ColorParams/ArchetypePreset walls), whether a pose can be assigned the same way. This is
-- DELIBERATELY NOT a retry of the AnimClass swap that T-posed (item 54/55 in CLAUDE.md) -- that
-- replaced the whole animation BLUEPRINT class, which has to match the pawn's movement component/
-- event-graph wiring, not just its skeleton. This instead drives the mesh component directly into
-- SINGLE-NODE playback of ONE specific AnimSequence -- SetAnimationMode(0) (0 =
-- EAnimationMode::AnimationSingleNode), SetAnimation(seq), then Play(false)+SetPosition(0,false)
-- to hold the very first frame frozen rather than looping -- a much more primitive lever (same
-- category as SetCharacterSex: a real engine function, not a struct field the rebuild silently
-- ignores) that only needs the SKELETON to match, not the whole AnimBP graph. animSequencePath
-- should come from a live probe (dumpAnimInfo's new AnimationData.AnimToPlay read) off the REAL
-- posed statue class, not a guess -- guessing a wrong asset path has cost a full test cycle
-- before (WINDROSE_MODDING_NOTES.md #9/#10's own lesson).
function Spawner.ApplyPose(actor, animSequencePath)
    local function say(m) print("[LivingBase:Pose] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then say("no actor"); return false end
    local mesh = nil
    pcall(function() mesh = actor.Mesh end)
    if not (mesh and mesh:IsValid()) then
        say("no actor.Mesh on this actor")
        return false
    end
    local seq = resolveAsset(animSequencePath)
    if not seq then
        say("UNRESOLVED animSequencePath: " .. tostring(animSequencePath))
        return false
    end
    local beforeMode = "?"
    pcall(function() beforeMode = tostring(mesh.AnimationMode) end)
    local okMode = pcall(function() mesh:SetAnimationMode(0) end) -- 0 = AnimationSingleNode
    local okAnim = pcall(function() mesh:SetAnimation(seq) end)
    local okPlay = pcall(function() mesh:Play(false) end)
    local okPos  = pcall(function() mesh:SetPosition(0.0, false) end)
    local afterMode = "?"
    pcall(function() afterMode = tostring(mesh.AnimationMode) end)
    say(string.format(
        "SetAnimationMode call %s, SetAnimation call %s (%s), Play call %s, SetPosition call %s; AnimationMode %s -> %s",
        okMode and "ok" or "FAILED", okAnim and "ok" or "FAILED", tostring(animSequencePath),
        okPlay and "ok" or "FAILED", okPos and "ok" or "FAILED", beforeMode, afterMode))
    return true
end

-- Spawner.ApplyBlueprintPose(actor, animClassPath, animSequencePath) -- TEMP DEV/TEST TOOL
-- (2026-08-14). The REAL mechanism behind ApplyPose's dead end: a live AnimInstance property dump
-- (item 62 follow-up, dumpAnimInfo -> dumpObjectProperties(animInstance, "ANIMINSTANCE")) found
-- BOTH Standing_01 and Sitting_01 share the SAME AnimClass (ABP_StandingNPC_Regular_AI_C, exactly
-- Config.SENKA_STATUE_STANDING_ANIM_CLASS -- confirmed live, not a guess), but each has a
-- DIFFERENT `Animation` property value on the AnimInstance itself: Standing_01 reads
-- A_AnimatedActor_Regular_Female_Idle_Standing_05, Sitting_01 reads
-- A_AnimatedActor_Regular_Female_Idle_SittingOnChair_01. That `Animation` variable (fed into the
-- AnimBP's own AnimGraphNode_SequencePlayer) is almost certainly what the item 54/55 AnimClass
-- swap was missing -- swapping the class alone builds a FRESH AnimInstance whose `Animation` is
-- empty/default, hence the T-pose; the real statues only get the right pose because their OWN
-- Blueprint construction script sets this variable, which a bare class swap never runs.
-- Two-step: (1) Spawner.SetAnimClass (existing, unchanged) to install the AnimBP and get a fresh
-- AnimInstance built, (2) grab that NEW instance via mesh:GetAnimInstance() and set its
-- `Animation` property directly -- a plain top-level UObject-reference property set, same class of
-- operation as any other property write in this file, not a struct field.
-- FIRST LIVE TEST (2026-08-14): Animation set/read back cleanly (BEFORE=(none) AFTER=<requested
-- sequence>), yet she STILL T-posed. Re-probing her afterward (HOME+PAUSE again, same actor)
-- explained why: a bare SetAnimClass builds the fresh AnimInstance off pure CLASS DEFAULTS, and
-- two more of THIS class's own variables came back wrong compared to the real statue --
-- `IsFemale?` read false (real statue: true) and `ArmorThicknessMorph` read 0.0 (real statue:
-- 0.35) -- neither ever gets set by a bare class swap, only by the real statue's own construction
-- script. A Control Rig built for a female skeleton running with IsFemale=false is a very
-- plausible T-pose cause on its own. Now sets both, hardcoded to the real statue's own probed
-- values, BEFORE setting Animation (in case anything downstream reads them during that assignment).
function Spawner.ApplyBlueprintPose(actor, animClassPath, animSequencePath)
    local function say(m) print("[LivingBase:BPPose] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then say("no actor"); return false end
    local mesh = nil
    pcall(function() mesh = actor.Mesh end)
    if not (mesh and mesh:IsValid()) then say("no actor.Mesh on this actor"); return false end
    local seq = resolveAsset(animSequencePath)
    if not seq then
        say("UNRESOLVED animSequencePath: " .. tostring(animSequencePath))
        return false
    end
    if not Spawner.SetAnimClass(actor, animClassPath) then
        say("SetAnimClass failed, aborting")
        return false
    end
    local inst = nil
    pcall(function() inst = mesh:GetAnimInstance() end)
    if not (inst and inst:IsValid()) then
        say("no AnimInstance after SetAnimClass -- can't set Animation property")
        return false
    end
    -- IsFemale?/ArmorThicknessMorph: real property names confirmed live via the ANIMINSTANCE probe
    -- dump (the literal FName includes the "?" -- valid in this codebase's Blueprint variable
    -- naming, and bracket-indexing handles it fine even though it's not a legal Lua identifier for
    -- dot-access). Hardcoded to the real Female_Standing_01's own probed values, not guessed.
    local beforeFemale, beforeMorph = "?", "?"
    pcall(function() beforeFemale = tostring(inst["IsFemale?"]) end)
    pcall(function() beforeMorph = tostring(inst.ArmorThicknessMorph) end)
    local okFemale = pcall(function() inst["IsFemale?"] = true end)
    local okMorph = pcall(function() inst.ArmorThicknessMorph = 0.34999999403954 end)
    local afterFemale, afterMorph = "?", "?"
    pcall(function() afterFemale = tostring(inst["IsFemale?"]) end)
    pcall(function() afterMorph = tostring(inst.ArmorThicknessMorph) end)
    say(string.format("IsFemale? set %s -- BEFORE=%s AFTER=%s; ArmorThicknessMorph set %s -- BEFORE=%s AFTER=%s",
        okFemale and "ok" or "FAILED", beforeFemale, afterFemale,
        okMorph and "ok" or "FAILED", beforeMorph, afterMorph))
    -- BodyMorph (2026-08-15, RedFalcon's follow-up) -- the ONE struct-valued property in this same
    -- list that was never actually compared (dumpObjectProperties only ever showed its TYPE, not
    -- its X/Y/Z -- see dumpAnimInfo's own comment). Live-probed BOTH actors afterward: real
    -- Standing_01 reads X=0.0 Y=0.84752953052521 Z=0.093581974506378; this class's own default
    -- (what a bare SetAnimClass leaves it at) reads X=0.0 Y=0.0 Z=1.0 -- genuinely different, Z
    -- pushed to a full 1.0 vs the real statue's 0.093, plausibly an untested extreme for whatever
    -- blend this feeds. Plain Lua table assignment, same pattern Spawner.WarpNear already uses for
    -- K2_SetActorLocation's Vector argument -- no struct-drilling needed to WRITE it, only to READ
    -- it safely (which dumpAnimInfo's BodyMorph probe already solved).
    local okMorphVec = pcall(function()
        inst.BodyMorph = { X = 0.0, Y = 0.84752953052521, Z = 0.093581974506378 }
    end)
    say("BodyMorph vector set " .. (okMorphVec and "ok" or "FAILED"))
    local function animName()
        local n = "(none)"
        pcall(function()
            local a = inst.Animation
            if a and a:IsValid() then n = a:GetFName():ToString() end
        end)
        return n
    end
    local before = animName()
    local okSet = pcall(function() inst.Animation = seq end)
    local after = animName()
    say(string.format("Animation property set %s -- BEFORE=%s AFTER=%s (requested %s)",
        okSet and "ok" or "FAILED", before, after, tostring(animSequencePath)))
    return true
end

-- Spawner.MakePreBuildPoseSetter(animClassPath, animSequencePath) -- TEMP DEV/TEST TOOL
-- (2026-08-14). ApplyBlueprintPose (above) set AnimClass + IsFemale?/ArmorThicknessMorph/
-- Animation POST-build on an already-spawned pawn -- every write reported success and read back
-- correctly, and she STILL T-posed. That's the same "reported success, never rendered" wall
-- already confirmed twice this project for post-build ColorParams/ArchetypePreset writes (items
-- 35, 59) -- likely a third instance of it: the compiled anim graph's runtime node data
-- (AnimNode_SequencePlayer, AnimNode_ControlRig) is probably initialized ONCE from these variables
-- at construction and never re-reads them afterward, same as DefaultParams/ArchetypePreset only
-- ever getting consumed once during the pawn's actual build. This is the genuinely new angle:
-- Spawner.SetCompositeParams already proved pre-build composite writes DO stick where post-build
-- ones don't (that's the entire reason it exists) -- untested whether the SAME timing distinction
-- applies to anim state. Returns a preFinish-compatible closure (same signature Spawner.Spawn's
-- own `preFinish` param expects) that runs INSIDE the deferred spawn window, before BeginPlay --
-- unknown until tried live whether `mesh:GetAnimInstance()` even resolves to anything at this
-- point (components generally exist pre-registration, but AnimInstance creation might not happen
-- until component registration, which could still be ahead of this call) -- logs plainly either
-- way so a live test is unambiguous about which case it hit.
function Spawner.MakePreBuildPoseSetter(animClassPath, animSequencePath)
    return function(actor)
        local function say(m) print("[LivingBase:BPPosePreBuild] " .. tostring(m) .. "\n") end
        if not (actor and actor:IsValid()) then return end
        local mesh = nil
        pcall(function() mesh = actor.Mesh end)
        if not (mesh and mesh:IsValid()) then say("no actor.Mesh in preFinish"); return end
        local cls = resolveClass(animClassPath)
        if not (cls and cls:IsValid()) then
            say("UNRESOLVED animClassPath: " .. tostring(animClassPath))
            return
        end
        local seq = resolveAsset(animSequencePath)
        if not seq then
            say("UNRESOLVED animSequencePath: " .. tostring(animSequencePath))
            return
        end
        local okSet = pcall(function() mesh:SetAnimInstanceClass(cls) end)
        if not okSet then okSet = pcall(function() mesh.AnimClass = cls end) end
        say("SetAnimInstanceClass in preFinish: " .. (okSet and "ok" or "FAILED"))
        local inst = nil
        pcall(function() inst = mesh:GetAnimInstance() end)
        if not (inst and inst:IsValid()) then
            say("no AnimInstance available yet at preFinish time -- can't set IsFemale?/ArmorThicknessMorph/Animation pre-build.")
            return
        end
        say("AnimInstance IS available at preFinish time -- setting IsFemale?/ArmorThicknessMorph/BodyMorph/Animation now.")
        local okFemale = pcall(function() inst["IsFemale?"] = true end)
        local okMorph = pcall(function() inst.ArmorThicknessMorph = 0.34999999403954 end)
        -- BodyMorph (2026-08-15) -- see ApplyBlueprintPose's own comment for the real probed
        -- values (X=0.0 Y=0.84752953052521 Z=0.093581974506378) vs. this class's own default
        -- (X=0.0 Y=0.0 Z=1.0).
        local okMorphVec = pcall(function()
            inst.BodyMorph = { X = 0.0, Y = 0.84752953052521, Z = 0.093581974506378 }
        end)
        local okAnim = pcall(function() inst.Animation = seq end)
        say(string.format("preFinish sets -- IsFemale? %s, ArmorThicknessMorph %s, BodyMorph %s, Animation %s",
            okFemale and "ok" or "FAILED", okMorph and "ok" or "FAILED",
            okMorphVec and "ok" or "FAILED", okAnim and "ok" or "FAILED"))
    end
end

-- Spawner.ApplyColorParams REMOVED (2026-08-11, debug-tool cleanup). It applied a
-- different garment color PALETTE (R5CompositeMeshColorCustomizationParams) to an
-- already-built pawn, POST-build, re-triggering a rebuild via the same recipe
-- Spawner.ApplyComposite (above) uses for DefaultParams/ArchetypePreset. CONCLUDED DEAD:
-- live-tested across 5 different palettes -- resolved, set comp.ColorParams, and the
-- rebuild calls all reported success, but NONE visibly changed the outfit. Same wall as
-- the color-controller tint above: color looks like a build-time-only input that's
-- consumed once, during the pawn's actual initial construction, not something
-- ConstructVisualFromParams re-runs. Setting ColorParams PRE-build instead (the only
-- remaining lever) was ALSO tried, with the user's sign-off, and reproduced a confirmed
-- FATAL native crash (matching an earlier 2026-08-07 crash on a different actor class) --
-- see Config.FACTION_VISITOR_LOOKS' own header comment. Outfit color/palette is a closed
-- question for this mod: don't wire comp.ColorParams into either the pre- or post-build
-- path again on any class without a genuinely new theory.
--
-- ADDENDUM (2026-08-13): the "maybe this class is just edit-locked" theory is also dead. Live
-- probe (Spawner.ProbeDumpProperties' dumpCustomizability) read IsCharacterCustomizable /
-- IsBodyTypeChangeAvailable / IsBodySexChangeAvailable as TRUE on three different classes --
-- BP_NPC_Handyman_Gatherer_C (our female-walker base) AND BP_AnimatedActor_BotC_Female_Standing_01_C,
-- a genuinely, visibly, distinctly-colored ORIGINAL NPC (25 color controllers vs. the Gatherer's
-- 19, including Mask/Cape entries the Gatherer doesn't even have) used as a positive control. If a
-- per-class lock were the reason live recolor fails, the control would read differently from the
-- Gatherer -- it didn't. Combined with attempting to recolor that same control NPC and seeing no
-- visible change either, this confirms color is build-time-consumed for EVERY pawn, not gated by
-- class, and these Is*Available flags govern something else (most likely whether the player-facing
-- character-creator UI may open on this actor at all) -- not whether a runtime
-- SetColorControllerValue/ColorParams write will visibly render. Don't re-chase this flag cluster
-- as an explanation for the color wall either.

--------------------------------------------------------------------
-- Spawner.MakePassive(actor) — stop a friendly mob from attacking. The Caster's
-- spells were damaging the player even with a friendly faction (her AoE doesn't
-- care). Destroying the ability-system component removes her attacks entirely; she
-- still walks around. EXPERIMENTAL — pcall'd, and toggleable via Config.
--------------------------------------------------------------------
-- Stop a pawn from fighting WITHOUT freezing it. Reach components by PROPERTY (class-path
-- lookup returns -1 — Diag proved it). Destroying the AbilitySystemComponent stops combat
-- but also kills locomotion (the goats went inert — their movement runs on the ASC), so we
-- strip only what Config.PASSIVE_STRIP lists — default just the CombatComponent.
-- Named component getters (StaticFindObject can't resolve these R5 component classes, so we
-- reach them as actor properties, the way MakeFriendly reaches FactionComponent).
local COMP_GETTERS = {
    CombatComponent           = function(a) return a.CombatComponent end,
    AbilitySystemComponent    = function(a) return a.AbilitySystemComponent end,
    TargetLock_TargetComponent= function(a) return a.TargetLock_TargetComponent end,
    BattleManagerComponent    = function(a) return a.BattleManagerComponent end,
    MemoryComponent           = function(a) return a.MemoryComponent end,
    R5AgentComponent          = function(a) return a.R5AgentComponent end,
}
-- Destroy a named component if present. Returns true if it was there to destroy.
function Spawner.StripComponent(actor, name)
    if not (actor and actor:IsValid()) then return false end
    local getter = COMP_GETTERS[name]
    if not getter then return false end
    local hit = false
    pcall(function()
        local c = getter(actor)
        if c and c:IsValid() then c:K2_DestroyComponent(actor); hit = true end
    end)
    return hit
end

function Spawner.MakePassive(actor)
    if not (actor and actor:IsValid()) then return end
    for _, name in ipairs(Config.PASSIVE_STRIP or { "CombatComponent" }) do
        Spawner.StripComponent(actor, name)
    end
end


--------------------------------------------------------------------
-- Spawner.StripInteraction(actor) — destroy the interaction-target components
-- so the actor can't be interacted with and shows no mouseover/look-at name or
-- prompt. This removes the name on QuestStatic NPCs (e.g. Marita) that the
-- marker-destroy can't (that name comes from the interaction title, not the
-- floating marker). No-op on actors without these components. All pcall'd.
--------------------------------------------------------------------
-- Spawner.StripAbilities(actor, patterns, label) — remove SPECIFIC granted abilities by class-name
-- pattern, leaving the rest intact. Used to take the Caster's totem summon away without touching
-- her close-range AoE (stripping the whole AbilitySystemComponent freezes a pawn — movement runs
-- on it; see the goat saga).
--
-- ASC.ActivatableAbilities is an FGameplayAbilitySpecContainer { TArray<FGameplayAbilitySpec> Items },
-- and each spec carries { FGameplayAbilitySpecHandle Handle; UGameplayAbility* Ability; ... }.
-- ClearAbility(Handle) removes one. Collect handles FIRST, then clear — clearing mutates Items.
--
-- If nothing matches, dump every ability name (always) so we learn the real one instead of guessing.
function Spawner.StripAbilities(actor, patterns, label)
    if not (actor and actor:IsValid()) or not patterns or #patterns == 0 then return 0 end
    local asc = nil
    pcall(function() asc = actor.AbilitySystemComponent end)
    if not (asc and asc:IsValid()) then return 0 end

    local doomed, seen = {}, {}
    pcall(function()
        local items = asc.ActivatableAbilities.Items
        local n = 0
        pcall(function() n = items:GetArrayNum() end)
        if n == 0 then pcall(function() n = #items end) end
        for i = 1, n do
            local spec = nil
            pcall(function() spec = items[i] end)
            if spec == nil then pcall(function() spec = items:Get(i) end) end
            if spec then
                local aname = ""
                pcall(function()
                    local ab = spec.Ability
                    if ab and ab:IsValid() then aname = ab:GetClass():GetFName():ToString() end
                end)
                if aname ~= "" then
                    seen[#seen + 1] = aname
                    for _, pat in ipairs(patterns) do
                        if aname:find(pat) then
                            doomed[#doomed + 1] = { handle = spec.Handle, name = aname }
                            break
                        end
                    end
                end
            end
        end
    end)

    local removed = 0
    for _, d in ipairs(doomed) do
        local ok = pcall(function() asc:ClearAbility(d.handle) end)
        if ok then
            removed = removed + 1
            print(string.format("[LivingBase] %s: removed ability %s\n", tostring(label), d.name))
        else
            print(string.format("[LivingBase] %s: ClearAbility FAILED on %s\n", tostring(label), d.name))
        end
    end
    if removed == 0 and #seen > 0 and not Spawner._abilityDumped then
        Spawner._abilityDumped = true
        print(string.format("[LivingBase] %s: no ability matched %s. Granted abilities are:\n",
            tostring(label), table.concat(patterns, "/")))
        for _, a in ipairs(seen) do print("[LivingBase]    " .. a .. "\n") end
    end
    return removed
end

-- Spawner.ResolveGEClass(candidates, shortName) — GameplayEffect BP classes have no path recorded
-- in any dump, so try the configured guesses, then fall back to a by-name object search. Logs the
-- resolved full path ONCE so it can be hardcoded next time instead of guessed forever.
function Spawner.ResolveGEClass(candidates, shortName)
    Spawner._geCache = Spawner._geCache or {}
    local hit = Spawner._geCache[shortName]
    if hit and hit:IsValid() then return hit end

    for _, p in ipairs(candidates or {}) do
        local o = resolveAsset(p)
        if o and o:IsValid() then
            Spawner._geCache[shortName] = o
            print(string.format("[LivingBase] GE resolved: %s\n", p))
            return o
        end
    end
    -- Last resort: it may already be loaded under a path we didn't guess.
    local found = nil
    pcall(function() found = FindObject("BlueprintGeneratedClass", shortName) end)
    if found and found:IsValid() then
        Spawner._geCache[shortName] = found
        local full = "?"
        pcall(function() full = found:GetFullName() end)
        print(string.format("[LivingBase] GE resolved by name: %s -> %s\n", shortName, full))
        return found
    end
    if not Spawner._geWarned then
        Spawner._geWarned = {}
    end
    if not Spawner._geWarned[shortName] then
        Spawner._geWarned[shortName] = true
        print(string.format("[LivingBase] GE NOT FOUND: %s (tried %d path(s) + name search)\n",
            shortName, #(candidates or {})))
    end
    return nil
end

-- Spawner.ApplyGE(actor, geClass) — apply a GameplayEffect to a pawn via its own ASC.
-- ASC:MakeEffectContext() then BP_ApplyGameplayEffectToSelf(Class, Level, Context).
function Spawner.ApplyGE(actor, geClass, level)
    if not (actor and actor:IsValid() and geClass and geClass:IsValid()) then return false end
    local asc = nil
    pcall(function() asc = actor.AbilitySystemComponent end)
    if not (asc and asc:IsValid()) then return false end
    local ok = pcall(function()
        local ctx = asc:MakeEffectContext()
        asc:BP_ApplyGameplayEffectToSelf(geClass, level or 1.0, ctx)
    end)
    return ok
end

-- Spawner.AttachShield(actor) — bolt the plague warrior's shield onto our crew Warrior.
-- Harvested live from BP_Mob_SenkamatiCorrupted_Regular_Warrior (2026-07-09):
--   mesh   = SK_Weapon_Dendromorph_ShieldMedium
--   socket = ik_weapon_lSocket   (the LEFT/offhand socket — the macuahuitl is in the right hand)
--   parent = CharacterMesh0, identity relative transform
-- We ADD a component rather than replace an existing mesh: the armour meshes are skinned to the
-- body, and a shield swapped onto one would deform into garbage.
function Spawner.AttachShield(actor)
    if not (actor and actor:IsValid()) then return false end
    if not Config.WARRIOR_SHIELD then return false end
    -- Once per pawn.
    local already = false
    pcall(function() already = actor.LivingBase_ShieldDone == true end)
    if already then return false end

    local mesh = resolveAsset(Config.WARRIOR_SHIELD_MESH)
    if not (mesh and mesh:IsValid()) then
        print("[LivingBase] Shield mesh did not resolve: " .. tostring(Config.WARRIOR_SHIELD_MESH) .. "\n")
        return false
    end
    local compCls = StaticFindObject("/Script/Engine.SkeletalMeshComponent")
    if not (compCls and compCls:IsValid()) then return false end

    local comp = nil
    pcall(function()
        -- bManualAttachment = true: we attach to the socket ourselves below.
        comp = actor:AddComponentByClass(compCls, true, {
            Rotation = { W = 1.0, X = 0.0, Y = 0.0, Z = 0.0 },
            Translation = { X = 0.0, Y = 0.0, Z = 0.0 },
            Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 },
        }, false)
    end)
    if not (comp and comp:IsValid()) then
        print("[LivingBase] AddComponentByClass failed for the shield.\n")
        return false
    end

    local okMesh = pcall(function() comp:SetSkeletalMeshAsset(mesh) end)
    if not okMesh then pcall(function() comp:SetSkeletalMesh(mesh, false) end) end

    local body = nil
    pcall(function() body = actor.Mesh end)
    if not (body and body:IsValid()) then
        print("[LivingBase] Shield: no CharacterMesh0 to attach to.\n")
        return false
    end

    -- The socket name was harvested from the Senkamati MOB, whose skeleton is a CREATURE rig. Our
    -- Warrior is a crew HUMAN rig, so that socket may simply not exist here. K2_AttachToComponent
    -- does NOT fail on a missing socket — it silently attaches at the component origin, which is
    -- why the shield floated. pcall reported "socket ok" and told us nothing. Verify first.
    local function socketExists(name)
        local ok, exists = pcall(function() return body:DoesSocketExist(FName(name)) end)
        return ok and exists == true
    end

    local socket = nil
    for _, cand in ipairs(Config.WARRIOR_SHIELD_SOCKETS or { Config.WARRIOR_SHIELD_SOCKET }) do
        if socketExists(cand) then socket = cand break end
    end

    if not socket then
        -- Say exactly what this skeleton DOES offer, once, so we can pick the real one instead of
        -- guessing a third time.
        print("[LivingBase] Shield: none of the candidate sockets exist on this skeleton.\n")
        if not Spawner._socketsDumped then
            Spawner._socketsDumped = true
            pcall(function()
                local names = body:GetAllSocketNames()
                local n = 0
                pcall(function() n = names:GetArrayNum() end)
                if n == 0 then pcall(function() n = #names end) end
                print(string.format("[LivingBase] Shield: %d sockets on CharacterMesh0:\n", n))
                for i = 1, n do
                    local s = nil
                    pcall(function() s = names[i] end)
                    if s == nil then pcall(function() s = names:Get(i) end) end
                    if s then print("[LivingBase]    " .. tostring(s:ToString()) .. "\n") end
                end
            end)
        end
        pcall(function() comp:K2_DestroyComponent(actor) end)   -- don't leave a floating shield
        return false
    end

    -- EAttachmentRule: 0=KeepRelative 1=KeepWorld 2=SnapToTarget.
    local attached = pcall(function()
        comp:K2_AttachToComponent(body, FName(socket), 2, 2, 2, false)
    end)

    -- Fine-tuning: the harvested transform was identity on the MOB's socket. A different skeleton's
    -- socket can be oriented differently, so allow a nudge without another harvest round-trip.
    local off = Config.WARRIOR_SHIELD_OFFSET
    if off then
        pcall(function() comp:K2_SetRelativeLocation({ X = off.X or 0.0, Y = off.Y or 0.0, Z = off.Z or 0.0 },
            false, {}, false) end)
    end
    local rot = Config.WARRIOR_SHIELD_ROTATION
    if rot then
        pcall(function() comp:K2_SetRelativeRotation({ Pitch = rot.Pitch or 0.0, Yaw = rot.Yaw or 0.0,
            Roll = rot.Roll or 0.0 }, false, {}, false) end)
    end

    pcall(function() comp:SetVisibility(true, false) end)
    pcall(function() actor.LivingBase_ShieldDone = true end)

    -- Remember it (with its owner + socket) so the live tuner can rotate it AND so we can re-assert
    -- the attachment after combat, which is what leaves it crooked (see Spawner.ReassertShields).
    Spawner.shieldComps = Spawner.shieldComps or {}
    Spawner.shieldComps[#Spawner.shieldComps + 1] =
        { comp = comp, owner = actor, socket = socket, wasFighting = false }

    print(string.format("[LivingBase] Warrior shield attached to socket '%s' (%s)\n",
        socket, attached and "attach ok" or "ATTACH CALL FAILED"))
    -- Start the re-assert watcher only NOW (a warrior with a shield exists). It stops itself when the
    -- last shielded warrior is gone, so there's no perpetual tick when none are out.
    pcall(function() Spawner.StartShieldWatcher() end)
    return true
end

--- Spawner.ReassertShields() — re-apply the tuned shield attachment when a warrior LEAVES combat.
--- RedFalcon: the shield is aligned until the warrior enters combat, then sits wrong afterward. Combat
--- montages (and the equipment re-init combat can trigger) disturb our added component — either its
--- relative rotation or its socket attachment. So on the fight->no-fight transition we re-attach it
--- to the socket and re-apply the tuned rotation/offset. Only fires on that edge, so it never fights
--- a live combat animation. Cheap: a handful of shields, checked on a slow tick.
function Spawner.ReassertShields()
    local list = Spawner.shieldComps
    if not list or #list == 0 then return end
    local rot = Config.WARRIOR_SHIELD_ROTATION
    local off = Config.WARRIOR_SHIELD_OFFSET
    local live = {}
    for _, e in ipairs(list) do
        if e and e.comp and e.comp:IsValid() and e.owner and e.owner:IsValid() then
            live[#live + 1] = e
            local fighting = Spawner.IsFighting(e.owner)
            if e.wasFighting and not fighting then
                -- Just left combat: put the shield back exactly where the tuner left it.
                pcall(function()
                    local body = e.owner.Mesh
                    if body and body:IsValid() and e.socket then
                        e.comp:K2_AttachToComponent(body, FName(e.socket), 2, 2, 2, false)
                    end
                    if off then
                        e.comp:K2_SetRelativeLocation({ X = off.X or 0.0, Y = off.Y or 0.0,
                            Z = off.Z or 0.0 }, false, {}, false)
                    end
                    if rot then
                        e.comp:K2_SetRelativeRotation({ Pitch = rot.Pitch or 0.0, Yaw = rot.Yaw or 0.0,
                            Roll = rot.Roll or 0.0 }, false, {}, false)
                    end
                end)
            end
            e.wasFighting = fighting
        end
    end
    Spawner.shieldComps = live   -- prune destroyed warriors/components
end

-- Spawner.StartShieldWatcher() — run the shield re-assert poll ONLY while a shielded warrior is alive.
-- Started by AttachShield; it re-schedules itself while shieldComps is non-empty and STOPS the moment
-- the last warrior is gone (ReassertShields prunes the list). So no perpetual tick when none are out;
-- the poll is just how "left combat" is detected (there's no combat-exit event to hook). AttachShield
-- restarts it whenever a new warrior spawns.
--------------------------------------------------------------------
Spawner.shieldWatcherRunning = false
function Spawner.StartShieldWatcher()
    if Spawner.shieldWatcherRunning then return end
    if not (Spawner.shieldComps and #Spawner.shieldComps > 0) then return end
    if not ExecuteWithDelay then pcall(Spawner.ReassertShields); return end   -- no timer: one-shot
    Spawner.shieldWatcherRunning = true
    -- shouldContinue reflects the PREVIOUS completed check, not the one in flight -- doWork's own
    -- ExecuteInGameThread callback is async (queued for a later game tick), so this is
    -- necessarily one tick stale by the time tick() reads it. Fine here: worst case is one extra
    -- poll after the last warrior is already gone.
    local shouldContinue = true
    local function doWork()
        ExecuteInGameThread(function()
            pcall(Spawner.ReassertShields)   -- re-attaches on combat-exit AND prunes shieldComps
            if Spawner.shieldComps and #Spawner.shieldComps > 0 then
                shouldContinue = true
            else
                shouldContinue = false
                Spawner.shieldWatcherRunning = false   -- last warrior gone -> stop entirely
            end
        end)
    end
    -- CONFIRMED (2026-08-16): calling ExecuteWithDelay NESTED inside an ExecuteInGameThread
    -- callback throws "No overload found for function 'ExecuteWithDelay'" in this UE4SS build --
    -- found investigating a launch crash in an unrelated feature (UnlockBuild's own retry timer,
    -- see main.lua's unlockTick/doWork fix), then audited across the whole codebase and found
    -- here too. doWork's ExecuteInGameThread call and tick's own ExecuteWithDelay call are
    -- siblings now, never nested.
    local function tick()
        doWork()
        if shouldContinue then
            ExecuteWithDelay(Config.SHIELD_REASSERT_MS or 2000, tick)
        end
    end
    ExecuteWithDelay(Config.SHIELD_REASSERT_MS or 2000, tick)
end

-- Spawner.MoveTowards(pawn, goalActor) — issue a navmesh move order to a pawn's OWN controller.
--
-- WHY NOT SWAP THE BRAIN: giving crew the boar's pet controller froze them solid (2026-07-10),
-- exactly as our goat notes warned. And the PlagueWitchPet mod never solved this — its pet follows
-- because its pak REPLACES BP_Mob_Boar_Friend in place, so the pawn keeps the pet's own AI. We
-- can't cook a pak, so instead we leave the crew's brain alone (they still fight) and simply give
-- it a destination every tick. UAIBlueprintHelperLibrary::SimpleMoveToActor(controller, goal).
--- Returns ok, reason. The reason string exists because "it didn't follow" is useless feedback.
---
--- WINDROSE USES MERCUNA, NOT THE UE NAVMESH. Every AI pawn carries a
--- MercunaGroundNavigationComponent. UAIBlueprintHelperLibrary::SimpleMoveToActor posts a request
--- into the stock navigation system, which these pawns never read: it neither throws nor fails, it
--- simply goes nowhere. That is why the log read "move order issued" once a second while the escort
--- wandered 65m away. Drive Mercuna directly:
---     void MoveToActor(AActor* Actor, float EndDistance, float Speed, bool UsePartialPath)
--- Stock nav stays as a fallback for any pawn without the component.
function Spawner.MoveTowards(pawn, goal)
    if not (pawn and pawn:IsValid()) then return false, "pawn invalid" end
    if not (goal and goal:IsValid()) then return false, "goal invalid" end

    local nav = nil
    pcall(function() nav = pawn.MercunaGroundNavigationComponent end)
    if nav and nav:IsValid() then
        local ok, err = pcall(function()
            nav:MoveToActor(goal,
                Config.FOLLOW_END_UU or 300.0,      -- stop this far short of the goal
                Config.FOLLOW_SPEED or 0.0,         -- 0 = the pawn's own default speed
                Config.FOLLOW_PARTIAL ~= false)     -- accept a partial path rather than refuse
        end)
        if ok then return true, "mercuna move issued" end
        return false, "Mercuna MoveToActor threw: " .. tostring(err)
    end

    -- Fallback: stock UE navigation.
    local ctrl = nil
    pcall(function() ctrl = pawn.Controller end)
    if not (ctrl and ctrl:IsValid()) then pcall(function() ctrl = pawn:GetController() end) end
    if not (ctrl and ctrl:IsValid()) then pcall(function() ctrl = pawn:GetR5AIController() end) end
    if not (ctrl and ctrl:IsValid()) then return false, "no Mercuna nav and no controller" end

    local lib = Spawner._aiLib
    if not (lib and lib:IsValid()) then
        lib = StaticFindObject("/Script/AIModule.Default__AIBlueprintHelperLibrary")
        Spawner._aiLib = lib
    end
    if not (lib and lib:IsValid()) then return false, "no Mercuna nav; AIBlueprintHelperLibrary missing" end

    local ok, err = pcall(function() lib:SimpleMoveToActor(ctrl, goal) end)
    if not ok then return false, "SimpleMoveToActor threw: " .. tostring(err) end
    return true, "stock nav move issued (no Mercuna component!)"
end

--- The pawn's Mercuna ground-nav component, or nil. Deliberately NOT cached: a UObject held
--- across a world load or GC becomes a dangling pointer, and the next native call through it is
--- a crash pcall cannot catch. See [[decorrupt-stale-asset-pointers]].
local function mercunaNav(pawn)
    local nav = nil
    pcall(function() nav = pawn.MercunaGroundNavigationComponent end)
    if nav and nav:IsValid() then return nav end
    return nil
end

--- Spawner.SetMaxWalkSpeed(pawn, speed) — raise the pawn's movement cap so it can actually MOVE at
--- the speed we want. Mercuna cannot push a character past its CharacterMovement.MaxWalkSpeed, so a
--- crew stuck at their ~110 uu/s walk gait ignores any higher Mercuna Speed arg. AR5AICharacter is a
--- plain ACharacter, so CharacterMovement is the standard component. Set every tick — a gait system
--- may reset it. MaxAcceleration is bumped alongside so they actually reach the new speed promptly.
function Spawner.SetMaxWalkSpeed(pawn, speed)
    if not (pawn and pawn:IsValid()) then return false end
    return pcall(function()
        local mv = pawn.CharacterMovement
        if mv and mv:IsValid() then mv.MaxWalkSpeed = speed end
        -- NOTE: do NOT crank MaxAcceleration — a huge accel makes them lurch to top speed instantly,
        -- which read as constant screen stutter with several crew moving near the camera. Default
        -- accel ramps smoothly.
    end)
end

--- Spawner.SetSpeedMultiplier(pawn, mult) — the crew keep their WALK gait while following out of
--- combat, so raising MaxWalkSpeed alone doesn't help: the AI's desired (walk) speed still caps them
--- at ~110, which is why they matched pace only in combat (run gait). UR5MovementComponent carries
--- CheatMovementSpeedModifer, a raw velocity MULTIPLIER the gait system doesn't reset. Multiply it up
--- while following so the walk becomes a jog that keeps pace, and back to 1.0 when they hold/fight so
--- their normal (and combat) speeds are untouched. Reached via CharacterMovement (an R5 component).
function Spawner.SetSpeedMultiplier(pawn, mult)
    if not (pawn and pawn:IsValid()) then return false end
    pcall(function()
        local mv = pawn.CharacterMovement
        if mv and mv:IsValid() then
            mv.CheatMovementSpeedModifer = mult
            -- One-time diagnostic: v2.46's CheatMovementSpeedModifer didn't change their pace, and we
            -- don't know why — is CharacterMovement even the right component, does MaxWalkSpeed stick?
            -- Log the actual component class + a MaxWalkSpeed read-back once per pawn so the next test
            -- says which lever (if any) the crew actually respond to.
            if Config.WHISTLE_FOLLOW_DEBUG then
                local flagged = false
                pcall(function() flagged = pawn.LivingBase_SpeedDbg == true end)
                if not flagged then
                    pcall(function() pawn.LivingBase_SpeedDbg = true end)
                    local cls, mws = "?", "?"
                    pcall(function() cls = mv:GetClass():GetFName():ToString() end)
                    pcall(function() mws = tostring(mv.MaxWalkSpeed) end)
                    print(string.format(
                        "[LivingBase] crew move comp = %s | MaxWalkSpeed = %s | set mult %.1f\n",
                        cls, mws, mult))
                end
            end
        end
    end)
    -- Mercuna-side multiplier: a DIFFERENT lever than the movement component's. If the gait system
    -- stomps the component field each frame, this scales Mercuna's own commanded speed instead.
    local nav = mercunaNav(pawn)
    if nav then pcall(function() nav:OverrideSpeedMultiplier(mult) end) end
    return true
end

--- Spawner.IsFighting(pawn) — is this pawn actively engaging an enemy RIGHT NOW? Cheap, per-pawn,
--- and covers ANY hostile (not a hard-coded class list): we read the combat target the pawn is
--- already tracking. Two independent signals, either one counts:
---   * UR5PawnAnimInstance.CurrentTarget — the actor the aim/combat animation is locked onto.
---   * the AI controller's focus actor (AController::GetFocusActor) — set while chasing/fighting.
--- A target that is the player himself doesn't count (they focus you to receive orders, not fight).
--- Replaces the old FindAllOf-per-class scan, which was the likely source of the follow stutter and
--- only ever noticed Drowned. Fails to `false` (keep following) on any trouble.
function Spawner.IsFighting(pawn, player)
    if not (pawn and pawn:IsValid()) then return false end
    local function realEnemy(t)
        if not (t and t:IsValid()) then return false end
        if player and player:IsValid() and t == player then return false end
        return true
    end

    local tgt = nil
    pcall(function()
        local mesh = pawn.Mesh
        local anim = mesh and mesh:IsValid() and mesh:GetAnimInstance() or nil
        if anim and anim:IsValid() then tgt = anim.CurrentTarget end
    end)
    if realEnemy(tgt) then return true end

    local focus = nil
    pcall(function()
        local ctrl = pawn.Controller
        if ctrl and ctrl:IsValid() then focus = ctrl:GetFocusActor() end
    end)
    return realEnemy(focus)
end

--- CONTINUOUS follow, the way Mercuna intends it.
---
--- Two separate bugs are fixed here, and it's worth keeping them apart:
---
--- 1. WRONG NAV SYSTEM. MoveTowards() posted to UE's stock navmesh, which these pawns never read.
---
--- 2. WRONG VERB. Even against Mercuna, re-issuing a one-shot MoveToActor once per second can
---    restart pathfinding before the pawn ever takes a step. Mercuna ships TrackActor() for
---    exactly "keep following this actor": issue it ONCE and let it run. So we issue on the first
---    call and re-issue only when the path is genuinely dead (which also covers being warped).
---
--- `state` is a plain Lua table the caller owns, one per pawn. Plain data only — never stash the
--- pawn or the component in it, for the dangling-pointer reason above.
---
--- Returns (ok, reason). The reason now carries real telemetry — current speed and remaining path
--- length — because "move order issued" was true and useless for two whole sessions. Those two
--- numbers separate the remaining failure modes on sight:
---     path > 0, speed > 0  → working
---     path > 0, speed ~ 0  → a path exists but something cancels it each frame (its StateTree)
---     path <= 0 forever    → no route at all: no nav grid, nav paused, or goal off-grid
function Spawner.Follow(pawn, goal, state)
    if not (pawn and pawn:IsValid()) then return false, "pawn invalid" end
    if not (goal and goal:IsValid()) then return false, "goal invalid" end
    state = state or {}

    local nav = mercunaNav(pawn)
    if not nav then return Spawner.MoveTowards(pawn, goal) end   -- fallback, loudly labelled

    -- Horizontal speed only, so a falling or settling pawn doesn't read as "moving".
    local spd = 0.0
    pcall(function()
        local v = pawn:GetVelocity()
        spd = math.sqrt((v.X or 0.0) ^ 2 + (v.Y or 0.0) ^ 2)
    end)

    local remaining = -1.0
    pcall(function() remaining = nav:GetRemainingPathLength() end)

    -- A freshly issued path takes a moment to compute, so don't call it dead on the first tick.
    if (remaining or -1.0) <= 0.0 then
        state.dead = (state.dead or 0) + 1
    else
        state.dead = 0
    end

    -- ASSERTIVE: if the pawn is MOVING but heading AWAY from the goal, its StateTree grabbed the wheel
    -- (a wander/investigate/idle-walk) — re-assert the follow instead of waiting for the path to die.
    -- Require TWO consecutive "away" ticks: a single one fires on normal path curvature (rounding an
    -- obstacle), and re-issuing then causes a needless re-path = a stutter. Two in a row means they're
    -- genuinely walking off, not just curving.
    if Config.FOLLOW_ASSERTIVE and state.tracking and spd > 30.0 then
        local away = false
        pcall(function()
            local pl = pawn:K2_GetActorLocation()
            local gl = goal:K2_GetActorLocation()
            local tx, ty = gl.X - pl.X, gl.Y - pl.Y
            local v = pawn:GetVelocity()
            if (v.X or 0.0) * tx + (v.Y or 0.0) * ty < 0.0 then away = true end   -- velocity·toGoal < 0
        end)
        state.away = away and (state.away or 0) + 1 or 0
        if (state.away or 0) >= 2 then state.tracking = false; state.away = 0 end   -- force re-issue
    end

    if (not state.tracking) or (state.dead or 0) >= 3 then
        if not state.navReady then
            -- A component with no nav grid, or with navigation paused, silently discards every
            -- order. Both are cheap to rule out and neither surfaces as an error.
            pcall(function() nav:SetNavGridToBest() end)
            pcall(function() nav:ResumeNavigation() end)
            state.navReady = true
        end
        local ok, err = pcall(function()
            nav:TrackActor(goal,
                Config.FOLLOW_END_UU or 300.0,      -- trail this far back, don't crowd him
                Config.FOLLOW_SPEED or 0.0,         -- 0 = the pawn's own default speed
                { X = 0.0, Y = 0.0, Z = 0.0 },      -- no formation offset
                Config.FOLLOW_PARTIAL ~= false)     -- a partial path beats standing still
        end)
        if not ok then
            state.tracking = false
            return false, "TrackActor threw: " .. tostring(err)
        end
        state.tracking, state.dead = true, 0
        return true, string.format("TrackActor issued (speed %.0f, path %.0fuu)", spd, remaining)
    end

    -- Tracking but standing still => something cancels our order every frame. Confirmed in-game:
    -- the path length flickers 1150 -> 0 -> 1150 once a second while speed stays ~0 and the pawn
    -- only TURNS to face the goal. That is the pawn's own StateTree issuing a competing order (or
    -- an outright CancelMovement) on the same Mercuna component every tick.
    --
    -- Detect the stall by SPEED, not by path length. The path is exactly what's being wiped, so
    -- gating on `path > 0` reset the counter on every flicker and the escalation never fired.
    -- Speed, by contrast, is steadily near zero the whole time — the honest signal that they're
    -- not actually walking. (Follow is only ever called when they're out of range, so a low speed
    -- here always means "should be moving and isn't".)
    if Config.FOLLOW_AUTOSTOP_LOGIC and spd < 10.0 then
        state.stall = (state.stall or 0) + 1
        if state.stall == (Config.FOLLOW_STALL_TICKS or 3) and not state.logicStopped then
            state.logicStopped = true
            Spawner.SetAILogic(pawn, false)
            -- The StateTree just wiped our last path on its way out. Re-issue into the now-quiet
            -- component next tick instead of waiting three more "dead" ticks to notice.
            state.tracking = false
            return true, string.format(
                "stalled %d ticks (speed ~0) — stopped its StateTree so Mercuna can drive", state.stall)
        end
    else
        state.stall = 0
    end

    return true, string.format("tracking (speed %.0f, path %.0fuu)", spd, remaining)
end

-- Spawner.SetAILogic(pawn, on) — AR5AIController exposes StartLogic()/StopLogic().
--
-- If the crew's own StateTree re-issues its own destination every tick, it will stomp our move order
-- and they'll wander instead of following. Stopping their logic silences that — but it also stops
-- them fighting, so we only do it while they're far away, and restart it once they're at your heel.
function Spawner.SetAILogic(pawn, on)
    if not (pawn and pawn:IsValid()) then return false end
    local ctrl = nil
    pcall(function() ctrl = pawn.Controller end)
    if not (ctrl and ctrl:IsValid()) then pcall(function() ctrl = pawn:GetR5AIController() end) end
    if not (ctrl and ctrl:IsValid()) then return false end
    return pcall(function()
        if on then ctrl:StartLogic() else ctrl:StopLogic() end
    end)
end

-- Spawner.SetAnimClass(actor, animClassPath) -- 2026-08-14, built for the Senkamati statue's
-- pose-matching problem: the crew Caster's frozen "standing" statue locks into a generic neutral
-- rest pose (her own ABP_Human_NPC_C AnimBP), not the distinctive stance the REAL
-- Female_Standing_01 statue has (ABP_StandingNPC_Regular_AI_C -- confirmed via HOME+PAUSE's
-- dumpAnimInfo, notably living in a folder literally named "Share_HumanAI", suggesting it's a
-- generic, reusable AnimBP rather than something hardcoded to her specific skeleton). This swaps
-- which AnimBlueprint drives an actor's main body mesh (actor.Mesh) WITHOUT touching the mesh or
-- skeleton at all -- fundamentally different from the SetSkeletalMeshAsset trick that T-posed 3-4
-- of 5 statues (items 49-51): the skeleton binding never changes here, only which "brain"
-- computes the pose each frame. Tries the proper runtime UFUNCTION
-- (SetAnimInstanceClass, which reconstructs the live AnimInstance) first; falls back to a plain
-- AnimClass property assignment if that call isn't exposed in this UE4SS build -- both classes
-- probed so far already use AnimationMode=BlueprintMode, so a plain property set should still
-- take effect for them even without the UFUNCTION rebuilding anything.
function Spawner.SetAnimClass(actor, animClassPath)
    if not (actor and actor:IsValid()) then return false end
    local mesh = nil
    pcall(function() mesh = actor.Mesh end)
    if not (mesh and mesh:IsValid()) then return false end
    local cls = resolveClass(animClassPath)
    if not (cls and cls:IsValid()) then
        print("[LivingBase] SetAnimClass: could not resolve " .. tostring(animClassPath) .. "\n")
        return false
    end
    local ok = pcall(function() mesh:SetAnimInstanceClass(cls) end)
    if not ok then
        ok = pcall(function() mesh.AnimClass = cls end)
    end
    print(string.format("[LivingBase] SetAnimClass: %s -> %s\n", ok and "ok" or "FAILED", tostring(animClassPath)))
    return ok
end

-- Spawner.WarpNear(pawn, anchorActor, radius, index, total) — emergency teleport when a follower
-- falls hopelessly behind (through geometry, off a cliff, stuck on nav). The PlagueWitchPet mod
-- does exactly this for its own pets at 80m, which is a good sign it's the pragmatic answer.
function Spawner.WarpNear(pawn, target, radius, index, total)
    if not (pawn and pawn:IsValid() and target and target:IsValid()) then return false end
    local ok = pcall(function()
        local p = target:K2_GetActorLocation()
        local ang = (2 * math.pi) * ((index or 1) - 1) / math.max(total or 1, 1)
        pawn:K2_SetActorLocation({
            X = p.X + math.cos(ang) * (radius or 500.0),
            Y = p.Y + math.sin(ang) * (radius or 500.0),
            Z = p.Z,
        }, false, {}, false)
    end)
    return ok
end

function Spawner.StripInteraction(actor)
    if not actor or not actor:IsValid() then return end
    stripComponentsOfClass(actor, "/Script/R5.R5CommonInteractionTargetComponent")
    stripComponentsOfClass(actor, "/Script/R5.R5PrimitiveInteractionTargetComponent")
end

-- Spawner.SetLootMesh(actor, meshPath) — forces a R5LootActor's MeshComponent to show a specific
-- static mesh, bypassing the whole business-rule/LootView system that normally sets it (that path is
-- CONFIRMED DEAD: Spawner.ProbeStoneItemMesh found the Stone item's ItemMesh property is an opaque
-- TSoftObjectPtrUserdata in this UE4SS build — LoadSynchronous/IsValid/IsNull/ToString/GetPath/Get all
-- throw "attempt to call a TSoftObjectPtrUserdata value", and even field access like .AssetPathName
-- just silently returns the same userdata back, not a real value — there is no way to resolve it from
-- Lua). meshPath is a real STATIC MESH asset path, not a class path (e.g.
-- "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT01_Stone_01.SM_ResourcesT01_Stone_01"
-- — confirmed live via Spawner.ProbeNearestLootMesh reading 4 REAL dropped items' MeshComponents
-- directly, 2026-08-17: Stone, Wood, Leather, Pickaxe T03). resolveClass's LoadAsset fallback works
-- fine here since it's a generic StaticFindObject+LoadAsset resolve, not class-specific.
function Spawner.SetLootMesh(actor, meshPath)
    if not (actor and actor:IsValid() and meshPath) then return false end
    local mesh = resolveClass(meshPath)
    if not (mesh and mesh:IsValid()) then
        print("[LivingBase] SetLootMesh: could not resolve " .. tostring(meshPath) .. "\n")
        return false
    end
    local mc = nil
    pcall(function() mc = actor.MeshComponent end)
    if not (mc and mc:IsValid()) then
        print("[LivingBase] SetLootMesh: actor has no MeshComponent.\n")
        return false
    end
    local ok = pcall(function() mc:SetStaticMesh(mesh) end)
    print(string.format("[LivingBase] SetLootMesh: %s -> %s\n", ok and "ok" or "FAILED", tostring(meshPath)))
    return ok
end

-- Spawner.MakeLootDecor(actor) — converts a dropped-item actor (R5LootActor, the single native class
-- every world-dropped item uses, confirmed via HOME+PAUSE live probe 2026-08-17) into inert decoration:
-- no longer pickable, no longer physically tossable, no longer glowing as lootable. Leaves
-- CollisionComponent (root) and MeshComponent alone — the whole point is it KEEPS its 3D mesh and stays
-- solid, it just stops behaving like a pickup from here on.
--
-- The probe's property dump named three components relevant here:
--   InteractTargetComponent = R5PrimitiveInteractionTargetComponent -- the SAME class
--     Spawner.StripInteraction already strips for statues, so that proven call is reused as-is.
--   ProjectileMovement = R5LootMovementComponent -- the toss/bounce/settle physics. Stripped too, same
--     stripComponentsOfClass() pattern, so a leftover decor item can't be knocked around by collisions.
--   NiagaraComponent -- the sparkle marking it as lootable. Deactivated (not destroyed — no proven-safe
--     precedent yet for destroying a Niagara component specifically, and Deactivate() is the standard,
--     low-risk way to stop an effect without touching the component graph).
-- InitialLifeSpan read as 0.0 on the probed instance (no engine auto-despawn timer on the actor itself),
-- so there's no timer here to race.
function Spawner.MakeLootDecor(actor)
    if not (actor and actor:IsValid()) then return false end
    Spawner.StripInteraction(actor)
    stripComponentsOfClass(actor, "/Script/R5.R5LootMovementComponent")
    pcall(function()
        local niag = actor.NiagaraComponent
        if niag and niag:IsValid() then niag:Deactivate() end
    end)
    -- Raytrace targeting (2026-08-22, RedFalcon: "drops decor need to be added to raytrace targeting
    -- because i cant target them") -- same collision-channel fix as walking actors/Senkamati (see
    -- Spawner.EnsureRaytraceChannel's own comment). NOT yet added to Spawner.spawned -- that's the
    -- SEPARATE open question of whether this should become a fully tracked spawn (despawnable,
    -- persisted across reloads) -- pending RedFalcon's answer, since it's not a normal spawnable
    -- class and restore-on-reload behavior for it is unverified.
    Spawner.EnsureRaytraceChannel(actor)
    return true
end

-- Spawner.MakeLootDecorNearest(say) — console-command entry point (lbdecorloot). A dropped item is a
-- WILD world actor, never tracked in Spawner.spawned, so findNearestSpawnInFront (which only walks
-- tracked spawns — see its own comment) can't see it. Uses a direct FindAllOf("R5LootActor") sweep
-- instead, filtered by the same cone/range test Spawner.ProbeNearestActor uses (camera forward, dot
-- >= Config.TARGET_MIN_VIEW_DOT, Config.PROBE_MIN_DIST..PROBE_MAX_DIST), since class-filtering at the
-- FindAllOf call (confirmed working for a native, non-Blueprint class — see the "R5BuildingBlock" sweep
-- elsewhere in this file) is far cheaper than the probe's full FindAllOf("Actor") world sweep.
-- findNearestLootActor(maxDist) -- shared by Spawner.MakeLootDecorNearest and
-- Spawner.ProbeNearestLootMesh. Extracted 2026-08-17 (was duplicated inline in
-- MakeLootDecorNearest) once a second caller needed the exact same
-- FindAllOf("R5LootActor") + camera-cone sweep. Returns (actor, dist) or nil on no match/no
-- camera.
local function findNearestLootActor(maxDist)
    maxDist = maxDist or Config.PROBE_MAX_DIST or 800.0
    local minViewDot = Config.TARGET_MIN_VIEW_DOT or 0.90
    local minDist = Config.PROBE_MIN_DIST or 50.0
    local camX, camY, camZ, cfx, cfy, cfz
    pcall(function()
        local pc = UEHelpers.GetPlayerController()
        if not (pc and pc:IsValid()) then return end
        local pawn = pc.Pawn
        local cam = pc.PlayerCameraManager
        local camRot
        if cam and cam:IsValid() then
            pcall(function() local l = cam:GetCameraLocation(); camX, camY, camZ = l.X, l.Y, l.Z end)
            pcall(function() camRot = cam:GetCameraRotation() end)
        end
        if not camRot then pcall(function() camRot = pc:GetControlRotation() end) end
        if not camX and pawn and pawn:IsValid() then
            local l = pawn:K2_GetActorLocation(); camX, camY, camZ = l.X, l.Y, l.Z
        end
        if camRot then
            local yaw, pitch = math.rad(camRot.Yaw), math.rad(camRot.Pitch)
            local cp = math.cos(pitch)
            cfx, cfy, cfz = cp * math.cos(yaw), cp * math.sin(yaw), math.sin(pitch)
        end
    end)
    if not (camX and cfx) then return nil, "no player/camera available." end
    local list
    local ok = pcall(function() list = FindAllOf("R5LootActor") end)
    if not (ok and list) then return nil, "no dropped items found in the world." end
    local n = 0
    pcall(function() n = list:GetArrayNum() end)
    if n == 0 then pcall(function() n = #list end) end
    local best, bestD
    for i = 1, n do
        local a = list[i]
        if not a then pcall(function() a = list:Get(i) end) end
        if a and a:IsValid() then
            local dist, cosAngle
            pcall(function()
                local l = a:K2_GetActorLocation()
                local dx, dy, dz = l.X - camX, l.Y - camY, l.Z - camZ
                dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                cosAngle = dist > 0 and ((dx * cfx + dy * cfy + dz * cfz) / dist) or 1.0
            end)
            if dist and cosAngle and dist >= minDist and cosAngle >= minViewDot and dist <= maxDist
               and (not bestD or dist < bestD) then
                best, bestD = a, dist
            end
        end
    end
    if not best then
        return nil, string.format("no dropped item within %.0fuu ahead -- walk closer / face it.", maxDist)
    end
    return best, bestD
end

function Spawner.MakeLootDecorNearest(say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    local best, bestD = findNearestLootActor()
    if not best then
        say(bestD) -- second return is the failure reason when best is nil
        return
    end
    if Spawner.MakeLootDecor(best) then
        say(string.format("dropped item @ %.0fuu converted to decor -- no longer pickable.", bestD))
    else
        say("failed to convert -- see log.")
    end
end

-- Spawner.FixAllRaytraceChannels(say) -- (2026-08-22) EnsureRaytraceChannel only runs at SPAWN time,
-- so it doesn't retroactively fix anything already placed BEFORE this fix shipped -- this walks
-- every tracked spawn (walking actors, idle Senkamati, statues, decor -- everything in
-- Spawner.spawned) and applies it now, without needing a reload/respawn. Loot-drop decor isn't
-- tracked in Spawner.spawned (a separate, still-open question -- see MakeLootDecor's own comment),
-- so re-run lbdecorloot on those instead -- MakeLootDecor itself now includes the same fix.
function Spawner.FixAllRaytraceChannels(say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    local n = 0
    for _, e in ipairs(Spawner.spawned or {}) do
        if e.actor and e.actor:IsValid() then
            if Spawner.EnsureRaytraceChannel(e.actor) then n = n + 1 end
        end
    end
    say(string.format("raytrace channel re-applied to %d tracked spawns.", n))
end

-- Spawner.ProbeNearestLootMesh(say) -- TEMP DEV TOOL (2026-08-17). Reads the ACTUAL mesh off a
-- REAL, already-dropped item's MeshComponent (a plain StaticMeshComponent -- a normal, already-
-- resolved hard object reference once something is really dropped, NOT the opaque
-- TSoftObjectPtrUserdata that dead-ended Spawner.ProbeStoneItemMesh on the DataAsset side). Drop
-- any real item, face it, run this. Console-only diagnostic, read-only, no actor mutated.
function Spawner.ProbeNearestLootMesh(say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    local best, bestD = findNearestLootActor()
    if not best then
        say(bestD)
        return
    end
    say(string.format("probing dropped item @ %.0fuu...", bestD))
    pcall(function()
        local mc = best.MeshComponent
        if not (mc and mc:IsValid()) then
            say("MeshComponent missing/invalid.")
            return
        end
        local mesh
        pcall(function() mesh = mc:GetStaticMesh() end)
        if not (mesh and mesh:IsValid()) then pcall(function() mesh = mc.StaticMesh end) end
        if not (mesh and mesh:IsValid()) then
            say("no static mesh assigned (MeshComponent has no mesh).")
            return
        end
        local full = "?"
        pcall(function() full = mesh:GetFullName() end)
        say("static mesh: " .. full)
        local n = 0
        pcall(function() n = mc:GetNumMaterials() end)
        for m = 0, (n - 1) do
            pcall(function()
                local mat = mc:GetMaterial(m)
                if mat and mat:IsValid() then say(string.format("  material[%d]: %s", m, mat:GetFullName())) end
            end)
        end
    end)
end

-- Spawner.ProbeLootSparkle(say) -- TEMP DEV TOOL (2026-08-21). RedFalcon: "can we make an effect
-- appear by them instead" -- looking for a real, already-confirmed-working effect to reuse instead
-- of the material-swap ghost highlight (root cause of the whole statue skin/eye white-restore saga).
-- The interaction-params DataAsset RedFalcon found dead-ended (Spawner.ProbeInteractionTargetParams
-- -- just interact distance/options/requirements, no FX reference at all). R5LootActor's own
-- NiagaraComponent (the lootable sparkle, already handled elsewhere -- Deactivate()'d in
-- Spawner.MakeLootDecor) IS a real, confirmed-working native effect. Reads its Asset (the actual
-- NiagaraSystem) plus world transform, so we know exactly what to spawn/attach onto a targeted
-- statue/decor object instead of ever touching materials.
function Spawner.ProbeLootSparkle(say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    local best, bestD = findNearestLootActor()
    if not best then
        say(bestD)
        return
    end
    say(string.format("probing dropped item @ %.0fuu for its sparkle...", bestD))
    pcall(function()
        local niag = best.NiagaraComponent
        if not (niag and niag:IsValid()) then
            say("NiagaraComponent missing/invalid.")
            return
        end
        local asset
        pcall(function() asset = niag.Asset end)
        if asset and type(asset) == "userdata" and asset.IsValid and asset:IsValid() then
            local full = "?"
            pcall(function() full = asset:GetFullName() end)
            say("NiagaraComponent.Asset: " .. full)
        else
            say("NiagaraComponent.Asset: nil/invalid (tried .Asset).")
        end
        local relLoc, relScale
        pcall(function() relLoc = niag:K2_GetComponentLocation() end)
        pcall(function() relScale = niag:K2_GetComponentScale() end)
        if relLoc then say(string.format("world loc: (%.1f,%.1f,%.1f)", relLoc.X, relLoc.Y, relLoc.Z)) end
        if relScale then say(string.format("world scale: (%.2f,%.2f,%.2f)", relScale.X, relScale.Y, relScale.Z)) end
        local isActive
        pcall(function() isActive = niag:IsActive() end)
        say("IsActive: " .. tostring(isActive))
    end)
end

-- Spawner.ProbeStoneItemMesh() -- TEMP DEV TOOL (2026-08-17). Follow-up to the inventoryDrops decor
-- experiment (confirmed live: a bare-spawned R5LootActor has no visible mesh, because MeshComponent
-- is only populated at a REAL drop event via LootView/ItemsStack -- see fkeys.lua's own comment).
-- UE4SS_ObjectDump.txt showed the Stone item DataAsset (DA_DID_Resource_Stone_T01, class
-- R5BLInventoryItem) carries a nested struct property InventoryItemGppData
-- (R5BLInventoryItemGPP) with its own SoftObjectProperty field ItemMesh -- exactly the kind of
-- field that should hold the world-drop static mesh asset. This is READ-ONLY: it doesn't touch any
-- actor, just resolves the DataAsset and prints whatever ItemMesh actually is, in several shapes
-- (SoftObjectProperty's exact Lua representation in this UE4SS build is unconfirmed -- could
-- resolve to a live UObject already, or to a struct with AssetPathName/SubPathString fields, or to
-- nil if unloaded), so the log output decides which path forward is real rather than guessing.
-- Console-only, remove once the mesh path is confirmed and wired into a real feature (or ruled out).
function Spawner.ProbeStoneItemMesh()
    local path = "/R5BusinessRules/InventoryItems/DefaultItems/Resource/DA_DID_Resource_Stone_T01.DA_DID_Resource_Stone_T01"
    local obj = resolveClass(path)
    if not (obj and obj:IsValid()) then
        print("[LivingBase] [probe-item] could not resolve " .. path .. "\n")
        return
    end
    print("[LivingBase] [probe-item] resolved DataAsset OK.\n")
    pcall(function()
        local gpp = obj.InventoryItemGppData
        if not gpp then
            print("[LivingBase] [probe-item] InventoryItemGppData is nil.\n")
            return
        end
        local mesh = gpp.ItemMesh
        print(string.format("[LivingBase] [probe-item] ItemMesh raw: type=%s tostring=%s\n", type(mesh), tostring(mesh)))
        if mesh == nil then return end
        -- Each candidate tried in its OWN pcall with an explicit before/after print (see
        -- WINDROSE_MODDING_NOTES.md 3b -- log before the call, and here also log the pcall's error
        -- string on failure) so a wrong method name shows up as a visible "FAILED: <reason>" line
        -- instead of silently vanishing, unlike the first version of this probe.
        local function tryCall(label, fn)
            print("[LivingBase] [probe-item] trying " .. label .. "...\n")
            local ok, result = pcall(fn)
            if ok then
                print(string.format("[LivingBase] [probe-item] %s -> OK: type=%s tostring=%s\n", label, type(result), tostring(result)))
            else
                print(string.format("[LivingBase] [probe-item] %s -> FAILED: %s\n", label, tostring(result)))
            end
            return ok, result
        end
        local okLoad, loaded = tryCall("LoadSynchronous()", function() return mesh:LoadSynchronous() end)
        if okLoad and loaded and type(loaded) == "userdata" then
            pcall(function()
                local valid = loaded:IsValid()
                print("[LivingBase] [probe-item] LoadSynchronous() result :IsValid()=" .. tostring(valid) .. "\n")
                if valid then print("[LivingBase] [probe-item] LoadSynchronous() result :GetFullName()=" .. tostring(loaded:GetFullName()) .. "\n") end
            end)
        end
        tryCall("IsValid()", function() return mesh:IsValid() end)
        tryCall("IsNull()", function() return mesh:IsNull() end)
        tryCall("ToString()", function() return mesh:ToString() end)
        tryCall("GetPath()", function() return mesh:GetPath() end)
        tryCall("Get()", function() return mesh:Get() end)
        tryCall(".AssetPathName (field)", function() return mesh.AssetPathName end)
        tryCall(".SubPathString (field)", function() return mesh.SubPathString end)
    end)
end

-- Spawner.StripQuestScenario(actor) — destroys R5ScenarioComponent_ForIslandActor, the component
-- that ties a QuestStatic NPC (Letty, Francois Arno) to their live dialogue graph. See
-- Config.STRIP_QUEST_SCENARIO's own comment for how this was found (live probe + dump_object,
-- 2026-08-07) and why it's a separate flag from StripInteraction. No-op on actors without the
-- component (every non-QuestStatic spawn).
function Spawner.StripQuestScenario(actor)
    if not actor or not actor:IsValid() then return end
    stripComponentsOfClass(actor, "/Script/R5.R5ScenarioComponent_ForIslandActor")
end

-- Spawner.StripVoice(actor) — destroys the plain engine AudioComponent (the "AudioVoice" property
-- on Handyman-family NPCs, confirmed via a live probe of Config.SENKA_FEMALE_BASE_CLASS) so a
-- Caster/Healer re-skin doesn't play her Handyman-role idle/bark voice lines. Targets ONLY
-- `/Script/Engine.AudioComponent` specifically, NOT the R5-custom sound components on the same
-- pawn (R5CosmeticSoundComponent, R5InterruptibleSoundComponent, R5FootstepComponent, per the
-- same probe) -- those are different classes entirely, so footsteps/cosmetic sounds are
-- unaffected. Same stripComponentsOfClass() used by StripInteraction/StripQuestScenario. No-op
-- on actors without a plain AudioComponent (e.g. the Warrior/Hunter's crew base).
function Spawner.StripVoice(actor)
    if not actor or not actor:IsValid() then return end
    stripComponentsOfClass(actor, "/Script/Engine.AudioComponent")
end

--------------------------------------------------------------------
-- Spawner.ProbeNearestActor() / Spawner.ProbeDumpProperties() — dev-tool diagnostics, triggered by
-- the "lbprobe" / "lbprobedump" console commands (main.lua) as of 2026-08-18 -- originally bound to
-- HOME/PAUSE keys, moved to console commands on RedFalcon's request; the functions themselves are
-- unchanged. Not a real feature, not gated by modGate (same treatment the toast investigation's
-- DumpActiveWidgets/DumpNotificationFunctions got before they were removed once their job was done
-- — see CLAUDE.md item 28). Aim at ANY actor in the world — ours, a wild NPC like the real Letty, or
-- an undiscovered decoration.
--
-- SPLIT INTO TWO KEYS, DELIBERATELY, after a live crash (2026-08-07): the first version did the
-- class-path log AND a full component sweep (GetComponentsByClass on the ActorComponent base class)
-- in one press. Aimed at Letty, it logged her AI controller's class fine
-- (BP_NPC_AIController_QuestStatic) — then crashed the game outright partway into the component
-- sweep. pcall does NOT protect against a native crash (established repeatedly in this codebase —
-- see CLAUDE.md's RegisterKeyBind/goat-component-destroy precedents), so the fix isn't a pcall, it's
-- removing the risky call:
--   * HOME (ProbeNearestActor) now ONLY logs the class path — the half that's fired clean twice in a
--     row (once correctly excluding PlayerCameraManager, once against the QuestStatic controller
--     right up until the crash). Caches the target as Spawner._lastProbedActor.
--   * PAUSE (ProbeDumpProperties) is a SEPARATE, deliberate second press that walks the cached
--     target's DECLARED properties via Class:ForEachProperty — the exact pattern
--     DumpNotificationFunctions already used successfully in the toast investigation to dump a live
--     widget's property values, never GetComponentsByClass. A property walk is safer AND more useful
--     here: whatever drives Letty's quest dialogue may be a plain bool/struct field, not necessarily
--     a discrete component object.
--
-- Targeting excludes Controllers (AIController/PlayerController) as well as the pawn/camera-manager
-- — probing the invisible controller instead of the visible character was itself a bug (that's how
-- HOME landed on BP_NPC_AIController_QuestStatic instead of Letty's own pawn class last time), and
-- controllers are also where AI-specific components (Blackboard/Perception/PathFollowing) that may
-- be behind the crash tend to live.
--
-- Deliberately a full FindAllOf("Actor") sweep, not restricted to Spawner.spawned — wild NPCs and
-- undiscovered world decor were never spawned by us. Same cost tradeoff already accepted by
-- RetrackOrphans and the old widget-dump probes: fine for a manual, rarely-pressed diagnostic key,
-- never something to do on a gameplay hot path.
--
-- Targeting: camera POSITION and camera DIRECTION together, for BOTH the cone test and the range
-- check — unlike findNearestSpawnInFront (which deliberately keeps range on the pawn so "how far
-- can I reach" tracks how close you're standing), this is a look-and-press probe with no "reach"
-- concept, so there's no reason to split the two and every reason not to: mixing one transform's
-- position with another's direction is the exact bug class item 15 in CLAUDE.md already burned
-- time on twice. Keep both from PlayerCameraManager, full stop.
--
-- TARGET LOCK SHORTCUT (v1.3.10+): if Spawner.lockedTarget (Numpad +, see ToggleTargetLock) is
-- set, lbprobe probes THAT actor directly instead of re-running the cone/range sweep — same reason
-- the lock already bypasses findNearestSpawnInFront's own pick: lets you back away, circle
-- around, or stand at an awkward angle without re-aiming precisely each time. Only ever helps for
-- something the lock could target in the first place (an actor tracked in Spawner.spawned, e.g.
-- one of our own placed statues) — a wild world NPC/undiscovered decoration was never lockable, so
-- probing one still falls through to the normal full-world sweep exactly as before.
--
-- AUTO-TARGET ON SPAWN (2026-08-18): Spawner.Spawn itself also sets Spawner._lastProbedActor on
-- every live placement (see its own comment, right after the SPAWNED log line) — so lbprobedump
-- works immediately after placing something, with no lbprobe step needed first, unless you
-- deliberately want to re-aim at something else.
--------------------------------------------------------------------
local DISCOVERY_PATHS = {
    "ue4ss/Mods/LivingBase/discovery_dump.txt",
    "Mods/LivingBase/discovery_dump.txt",
    "discovery_dump.txt",
}
local function discoveryAppend(line)
    for _, p in ipairs(DISCOVERY_PATHS) do
        local f = io.open(p, "a")
        if f then f:write(line .. "\n"); f:close(); return true end
    end
    return false
end

function Spawner.ProbeNearestActor(maxDist)
    print("[LivingBase] [probe] key received.\n")
    maxDist = maxDist or Config.PROBE_MAX_DIST or 800.0
    local minViewDot = Config.TARGET_MIN_VIEW_DOT or 0.90
    -- PROBE_MIN_DIST: candidates closer than this to the CAMERA are skipped outright, not just
    -- exempted from the angle test like MIN_STABLE_DIST elsewhere. Root cause of the first version
    -- of this probe always returning PlayerCameraManager: that actor's own location IS the camera's
    -- location (dist ~= 0), so the old `dist > 0 and (...) or 1.0` fallback handed it a perfect
    -- cosAngle=1.0 and its near-zero distance made it un-beatable as "nearest" on every single press
    -- -- confirmed live (2026-08-07): five presses, five identical PlayerCameraManager hits in
    -- discovery_dump.txt. Excluding the pawn/controller/camera-manager BY INSTANCE PATH (below) fixes
    -- the three known offenders; this distance floor is the general-case guard against any other
    -- per-player manager actor (HUD, PlayerState, etc.) that might also sit at/near the camera.
    local minDist = Config.PROBE_MIN_DIST or 50.0
    local pawn, pc, cam
    local camX, camY, camZ, cfx, cfy, cfz
    pcall(function()
        pc = UEHelpers.GetPlayerController()
        pawn = pc and pc:IsValid() and pc.Pawn
        if not (pc and pc:IsValid()) then return end
        cam = pc.PlayerCameraManager
        local camRot
        if cam and cam:IsValid() then
            pcall(function() local l = cam:GetCameraLocation(); camX, camY, camZ = l.X, l.Y, l.Z end)
            pcall(function() camRot = cam:GetCameraRotation() end)
        end
        if not camRot then pcall(function() camRot = pc:GetControlRotation() end) end
        if not camX and pawn and pawn:IsValid() then
            local l = pawn:K2_GetActorLocation(); camX, camY, camZ = l.X, l.Y, l.Z
        end
        if camRot then
            local yaw, pitch = math.rad(camRot.Yaw), math.rad(camRot.Pitch)
            local cp = math.cos(pitch)
            cfx, cfy, cfz = cp * math.cos(yaw), cp * math.sin(yaw), math.sin(pitch)
        end
    end)
    if not (camX and cfx) then
        print("[LivingBase] [probe] no player/camera available -- aborting.\n")
        return
    end
    local best, bestD
    if Spawner.lockedTarget and Spawner.lockedTarget.actor and Spawner.lockedTarget.actor:IsValid() then
        -- Spawner.lockedTarget is a WRAPPER TABLE ({ actor, label, class } -- see
        -- Spawner.ToggleTargetLock/CycleNearestInFront), not the raw actor itself. An earlier version
        -- of this block called :IsValid() directly on the wrapper, which has no such method on a
        -- plain Lua table -- "attempt to call a nil value" aborted the function immediately after the
        -- "key received" print, with nothing left to catch/log it usefully. Confirmed live 2026-08-14.
        best = Spawner.lockedTarget.actor
        pcall(function()
            local l = best:K2_GetActorLocation()
            local dx, dy, dz = l.X - camX, l.Y - camY, l.Z - camZ
            bestD = math.sqrt(dx * dx + dy * dy + dz * dz)
        end)
        print("[LivingBase] [probe] using locked target (Numpad +) -- skipping the normal sweep.\n")
    end

    if not best then
        -- Exclude the pawn, the controller, and the camera manager itself -- all three are real
        -- Actor instances FindAllOf("Actor") returns, and all three sit at/near the camera's own
        -- transform.
        local exclude = {}
        for _, a in ipairs({ pawn, pc, cam }) do
            if a and a:IsValid() then
                local p = actorInstancePath(a)
                if p then exclude[p] = true end
            end
        end
        -- Also exclude EVERY Controller (AIController/PlayerController), not just the player's own —
        -- probing a wild NPC's invisible controller instead of its visible pawn is what happened to
        -- Letty (landed on BP_NPC_AIController_QuestStatic). IsA() against the base Controller class
        -- catches every subclass without needing to know its name in advance.
        local controllerClass
        pcall(function() controllerClass = StaticFindObject("/Script/Engine.Controller") end)
        -- Volume + bare-Actor exclusion (2026-08-21, RedFalcon: lbprobe kept latching onto invisible
        -- helper actors instead of a real chest POI -- confirmed live via the instance-name
        -- diagnostic: a MercunaNavExclusionVolume (a 3rd-party AI-pathing exclusion zone, base class
        -- AVolume) and a genuinely bare, subclass-less AActor (an anchor/marker with no Blueprint at
        -- all, hence GetClass() legitimately resolving to plain "/Script/Engine.Actor") were both
        -- winning "nearest in cone" over the chest -- these dev/test-map (GYM/Genlandia) volumes and
        -- markers apparently sprawl wide enough to out-compete a real, closer POI. Same IsA()
        -- exclusion pattern already used for Controller above: AVolume covers NavExclusionVolume/
        -- TriggerVolume/BlockingVolume/etc. generically, and a direct class-identity check catches
        -- the bare-Actor case (comparing against ONE canonical StaticFindObject fetch, not a
        -- cross-fetch comparison -- see this file's own documented wrapper-identity pitfall).
        local volumeClass
        pcall(function() volumeClass = StaticFindObject("/Script/Engine.Volume") end)

        local list
        local ok = pcall(function() list = FindAllOf("Actor") end)
        if not (ok and list) then
            print("[LivingBase] [probe] FindAllOf('Actor') returned nothing.\n")
            return
        end
        local n = 0
        pcall(function() n = list:GetArrayNum() end)
        if n == 0 then pcall(function() n = #list end) end

        for i = 1, n do
            local a = list[i]
            if not a then pcall(function() a = list:Get(i) end) end
            local isController = false
            if a and controllerClass then pcall(function() isController = a:IsA(controllerClass) end) end
            local isVolumeOrBare = false
            if a and volumeClass then pcall(function() isVolumeOrBare = a:IsA(volumeClass) end) end
            -- BUG FIX (2026-08-21): `a:GetClass() == bareActorClass` never actually matched --
            -- confirmed live, bare Actor still won every probe after this shipped. `a:GetClass()` is
            -- fetched fresh per candidate here, a DIFFERENT wrapper handle each time than the ONE
            -- `bareActorClass` fetched outside the loop -- exactly this file's own documented
            -- cross-fetch wrapper-identity pitfall (raw `==` between independently-fetched handles to
            -- the same underlying UObject can silently read as unequal). String-compare the resolved
            -- class's own FullName instead, same low-risk pattern already used everywhere else in
            -- this file for class/asset-path matching.
            if a and not isVolumeOrBare then
                pcall(function()
                    local cf = a:GetClass():GetFullName()
                    if cf == "Class /Script/Engine.Actor" then isVolumeOrBare = true end
                end)
            end
            if a and a:IsValid() and not isController and not isVolumeOrBare and not exclude[actorInstancePath(a)] then
                local dist, cosAngle
                pcall(function()
                    local l = a:K2_GetActorLocation()
                    local dx, dy, dz = l.X - camX, l.Y - camY, l.Z - camZ
                    dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                    cosAngle = dist > 0 and ((dx * cfx + dy * cfy + dz * cfz) / dist) or 1.0
                end)
                if dist and cosAngle and dist >= minDist and cosAngle >= minViewDot and dist <= maxDist
                   and (not bestD or dist < bestD) then
                    best, bestD = a, dist
                end
            end
        end
        if not best then
            print(string.format("[LivingBase] [probe] nothing within %.0fuu ahead.\n", maxDist))
            return
        end
    end

    local cls = "?"
    pcall(function()
        local full = best:GetClass():GetFullName()
        cls = full:match("(/Game/[%w_/%.]+)$") or full
    end)
    -- TEMP DIAGNOSTIC (2026-08-21, RedFalcon: "lbprobe is only grabbing /script/engine.actor" while
    -- reportedly aiming at the same chest as before, same session) -- printing the actor's own
    -- instance name/path too (not just the resolved class) tells us whether `best` is genuinely a
    -- DIFFERENT object each press (e.g. an invisible trigger/interaction volume overlapping the
    -- chest, now winning "nearest" by a hair) or the SAME chest instance with GetClass() itself
    -- somehow degrading to the base Actor class post-restart.
    local instName = "?"
    pcall(function() instName = best:GetFullName() end)
    print(string.format("[LivingBase] [probe] TARGET @ %.0fuu: %s (instance: %s)\n", bestD, cls, instName))
    if discoveryAppend("CLASS: " .. cls) then
        print("[LivingBase] [probe] logged to discovery_dump.txt\n")
    else
        print("[LivingBase] [probe] could not open discovery_dump.txt for writing.\n")
    end
    Spawner._lastProbedActor = best
    print("[LivingBase] [probe] run lbprobedump to dump this target's properties.\n")
end

-- Spawner.ProbeDumpProperties() — the deliberate SECOND step, PAUSE. Walks Spawner._lastProbedActor's
-- DECLARED properties via Class:ForEachProperty and prints name=value for each, the same reflection
-- pattern DumpNotificationFunctions already used safely on a live widget (never
-- GetComponentsByClass, which is what crashed here — see this section's own comment above).
--
-- Walks UP THE FULL CLASS HIERARCHY (leaf class, then GetSuperStruct() repeatedly), not just the
-- leaf class alone — ForEachProperty only enumerates members DECLARED on that specific UStruct, the
-- same limitation DumpNotificationFunctions already hit and solved for functions. First live run
-- against Letty (2026-08-07) proved this the hard way: her leaf class (BP_NPC_QuestStatic_Letty_C)
-- only declares 2 properties (Audio, ActiveQuestMarker — the latter is the SAME R5MarkerComponent
-- HideNameplate already strips, not new) — whatever actually drives her quest dialogue is almost
-- certainly declared on a parent QuestStatic/NPC base class further up, invisible without this walk.
--
-- NO AUTO-DRILL into nested objects (removed 2026-08-07, same day it was added). A first version
-- auto-drilled one level into any property whose value's class name contained "interaction"/"quest"
-- -- against Letty that meant walking R5CommonInteractionTargetComponent's own ForEachProperty list,
-- which crashed the game outright (right after printing its `Params`/`bHasDefaultTitle` fields
-- clean). So this exact technique is safe on a Pawn/Character/Actor hierarchy (proven twice, 197
-- properties, no issue) but NOT safe on at least this one live gameplay component -- and there's no
-- way to know which components are safe ahead of time without risking another crash. Use UE4SS's own
-- bundled `dump_object` CONSOLE command (Tilde) instead for anything found via a `= ClassName ...`
-- value in this dump that's worth going deeper on -- it's the same reflection walk, so it isn't
-- inherently safer against a crash-prone live component either, but it doesn't cost editing/
-- redeploying this file to try, and it's the community-standard tool for exactly this job.
local function dumpObjectProperties(obj, tag)
    local cls
    pcall(function() cls = obj:GetClass() end)
    while cls and cls:IsValid() do
        local className = "?"
        pcall(function() className = cls:GetFName():ToString() end)
        print(string.format("[LivingBase] [probe-props] -- %s: from %s --\n", tag, className))
        pcall(function()
            cls:ForEachProperty(function(prop)
                local pname = "?"
                pcall(function() pname = prop:GetFName():ToString() end)
                local valStr = "<unreadable>"
                local okv, val = pcall(function() return obj[pname] end)
                if okv then
                    if val == nil then
                        valStr = "nil"
                    elseif type(val) == "userdata" then
                        local okc, full = pcall(function() return val:GetFullName() end)
                        valStr = okc and full or tostring(val)
                    else
                        valStr = tostring(val)
                    end
                end
                print(string.format("[LivingBase] [probe-props]   %s = %s\n", pname, valStr))
            end)
        end)
        local nextCls
        pcall(function() nextCls = cls:GetSuperStruct() end)
        cls = nextCls
    end
end

-- Spawner.ProbeChestFX() -- TEMP DEV TOOL (2026-08-21). RedFalcon probed a real chest POI
-- (BP_ChestVisual_Clay_02_C) and its full property dump turned up TWO promising leads no other probe
-- this session has found: `ChestFXParams` (a DataAsset LITERALLY named DA_ChestFXParams, class
-- R5ChestFXParams) and `SpawnedChestVFX` (a LIVE, already-spawned NiagaraComponent reference sitting
-- right on the actor). Much better candidates than the interaction-params dead end
-- (Spawner.ProbeInteractionTargetParams) or the loot sparkle (Spawner.ProbeLootSparkle) -- this is
-- the exact system driving a real, persistent POI's sparkle/highlight, not a generic interact-prompt
-- system or a transient dropped-item effect. Operates on Spawner._lastProbedActor (run lbprobe on a
-- chest first) -- read-only, no auto-drill (same safe pattern as dumpObjectProperties everywhere else).
function Spawner.ProbeChestFX()
    local target = Spawner._lastProbedActor
    if not (target and target:IsValid()) then
        print("[LivingBase] [probe-chestfx] no valid probed target -- run lbprobe on a chest first.\n")
        return
    end
    pcall(function()
        local params = target.ChestFXParams
        if params and params:IsValid() then
            local full = "?"
            pcall(function() full = params:GetFullName() end)
            print("[LivingBase] [probe-chestfx] ChestFXParams: " .. full .. "\n")
            dumpObjectProperties(params, "CHESTFX")
        else
            print("[LivingBase] [probe-chestfx] ChestFXParams missing/invalid on this actor.\n")
        end
    end)
    pcall(function()
        local niag = target.SpawnedChestVFX
        if not (niag and niag:IsValid()) then
            print("[LivingBase] [probe-chestfx] SpawnedChestVFX missing/invalid on this actor.\n")
            return
        end
        local asset
        pcall(function() asset = niag.Asset end)
        if asset and type(asset) == "userdata" and asset.IsValid and asset:IsValid() then
            local full = "?"
            pcall(function() full = asset:GetFullName() end)
            print("[LivingBase] [probe-chestfx] SpawnedChestVFX.Asset: " .. full .. "\n")
        else
            print("[LivingBase] [probe-chestfx] SpawnedChestVFX.Asset: nil/invalid.\n")
        end
        local isActive
        pcall(function() isActive = niag:IsActive() end)
        print("[LivingBase] [probe-chestfx] SpawnedChestVFX.IsActive: " .. tostring(isActive) .. "\n")
    end)
end

-- Spawner.ProbeKSLTraceFunctions() -- TEMP DEV TOOL (2026-08-24). LineTraceSingleByObjectType
-- (guessed by analogy with the already-proven-working LineTraceSingle -- see UpdateHoverHighlight's
-- own comment for why an object-type trace was worth trying at all: it lets pawn-targeting work off
-- their ALREADY-existing native Pawn-channel collision instead of EnsureRaytraceChannel's own
-- Visibility-block, which turned out to make every mod spawn register as "ground" to another pawn's
-- foot-IK) CONFIRMED LIVE to fail at the method-resolution stage itself ("Tried calling a member
-- function but the UObject instance is nullptr" -- i.e. the name/binding doesn't exist as guessed),
-- not a bad-argument or a miss. Same "read reflection FIRST rather than guess another call" lesson
-- ProbeNiagaraFunctions' own comment already documents -- should have started here. Lists every
-- UFunction on KismetSystemLibrary whose name contains "Trace" or "Object" (case-insensitive), so
-- the real name (and, from its own signature/param count if the Lua binding exposes that) can be
-- read directly instead of guessed again.
function Spawner.ProbeKSLTraceFunctions()
    local cdo
    pcall(function() cdo = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end)
    if not (cdo and cdo:IsValid()) then
        print("[LivingBase] [probe-kslfuncs] could not resolve KismetSystemLibrary CDO.\n")
        return
    end
    local cls
    pcall(function() cls = cdo:GetClass() end)
    if not (cls and cls:IsValid()) then
        print("[LivingBase] [probe-kslfuncs] could not resolve KismetSystemLibrary class.\n")
        return
    end
    local names = {}
    pcall(function()
        cls:ForEachFunction(function(fn)
            local n = "?"
            pcall(function() n = fn:GetFName():ToString() end)
            local lower = n:lower()
            if lower:find("trace") or lower:find("object") then
                names[#names + 1] = n
            end
        end)
    end)
    table.sort(names)
    print(string.format("[LivingBase] [probe-kslfuncs] %d matching function(s):\n", #names))
    for _, n in ipairs(names) do
        print("[LivingBase] [probe-kslfuncs]   " .. n .. "\n")
    end
end

-- Spawner.ProbeNiagaraFunctions() -- TEMP DEV TOOL (2026-08-21). Next step after confirming a real,
-- reusable NiagaraSystem (FX_PickUP_Chest_01, off a live chest's SpawnedChestVFX component) --
-- RedFalcon wants to try spawning/attaching this ourselves onto a targeted statue/decor object
-- instead of swapping materials (the root cause of the whole skin/eye white-restore saga). Spawning a
-- Niagara system from Lua needs UNiagaraFunctionLibrary's static SpawnSystemAttached (or similar) --
-- never called from this codebase before, and UE versions vary on the exact function name/signature,
-- so read-only reflection FIRST (same ForEachFunction walk dumpCompositeFunctions already uses
-- safely) rather than guessing a call and risking a crash from wrong arg count/types.
function Spawner.ProbeNiagaraFunctions()
    local cdo
    pcall(function() cdo = StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary") end)
    if not (cdo and cdo:IsValid()) then
        print("[LivingBase] [probe-niagarafuncs] could not resolve NiagaraFunctionLibrary CDO.\n")
        return
    end
    local cls
    pcall(function() cls = cdo:GetClass() end)
    local total = 0
    while cls and cls:IsValid() do
        local className = "?"
        pcall(function() className = cls:GetFName():ToString() end)
        local names = {}
        pcall(function()
            cls:ForEachFunction(function(fn)
                local n = "?"
                pcall(function() n = fn:GetFName():ToString() end)
                names[#names + 1] = n
            end)
        end)
        table.sort(names)
        total = total + #names
        print(string.format("[LivingBase] [probe-niagarafuncs] -- %s (%d functions) --\n", className, #names))
        print("[LivingBase] [probe-niagarafuncs]   " .. table.concat(names, ", ") .. "\n")
        local nextCls
        pcall(function() nextCls = cls:GetSuperStruct() end)
        cls = nextCls
    end
    print(string.format("[LivingBase] [probe-niagarafuncs] done, %d total.\n", total))
end

-- Spawner.ProbeCustomPrimitiveData() -- TEMP DEV TOOL (2026-08-21). RedFalcon's redirect after the
-- Niagara crash: "is there a technique for changing tint of a mesh?" -- Custom Primitive Data is a
-- per-COMPONENT numeric slot a material can read directly (if authored to), completely separate from
-- material instances -- no swap, no restore problem, no duplicate actor needed if Windrose's own
-- materials use it. Checks whether PrimitiveComponent actually exposes the Set*CustomPrimitiveData*
-- functions in this build (pure reflection, no risk) and, if the last probed target has a mesh
-- component, reads its CURRENT CustomPrimitiveData array (if any) so we can see whether it's already
-- being fed something non-default (a sign the material actually consumes it).
function Spawner.ProbeCustomPrimitiveData()
    local pcCls
    pcall(function() pcCls = StaticFindObject("/Script/Engine.PrimitiveComponent") end)
    if not (pcCls and pcCls:IsValid()) then
        print("[LivingBase] [probe-cpd] could not resolve PrimitiveComponent class.\n")
        return
    end
    local names = {}
    pcall(function()
        pcCls:ForEachFunction(function(fn)
            local n = "?"
            pcall(function() n = fn:GetFName():ToString() end)
            if n:lower():find("customprimitivedata", 1, true) then names[#names + 1] = n end
        end)
    end)
    table.sort(names)
    print("[LivingBase] [probe-cpd] PrimitiveComponent CustomPrimitiveData functions: " ..
        (#names > 0 and table.concat(names, ", ") or "(none found)") .. "\n")

    local target = Spawner._lastProbedActor
    if not (target and target:IsValid()) then
        print("[LivingBase] [probe-cpd] no probed target -- run lbprobe on something to also inspect its current data.\n")
        return
    end
    local comp
    pcall(function() comp = target.Mesh end)
    if not (comp and comp:IsValid()) then
        pcall(function()
            local staticCls = StaticFindObject("/Script/Engine.StaticMeshComponent")
            local comps = target:K2_GetComponentsByClass(staticCls)
            local n = 0
            pcall(function() n = comps:GetArrayNum() end)
            if n == 0 then pcall(function() n = #comps end) end
            if n > 0 then
                comp = comps[1]
                if not comp then comp = comps:Get(1) end
                pcall(function() if comp ~= nil and type(comp) == "userdata" and comp.get then comp = comp:get() end end)
            end
        end)
    end
    if not (comp and comp:IsValid()) then
        print("[LivingBase] [probe-cpd] target has no readable mesh component.\n")
        return
    end
    pcall(function()
        local cpd = comp.CustomPrimitiveData
        if cpd == nil then
            print("[LivingBase] [probe-cpd] target's CustomPrimitiveData: nil/not accessible this way.\n")
            return
        end
        local dataArr
        pcall(function() dataArr = cpd.Data end)
        if not dataArr then
            print("[LivingBase] [probe-cpd] CustomPrimitiveData.Data not accessible.\n")
            return
        end
        local n = 0
        pcall(function() n = dataArr:GetArrayNum() end)
        if n == 0 then pcall(function() n = #dataArr end) end
        print(string.format("[LivingBase] [probe-cpd] target's CustomPrimitiveData.Data: %d entries.\n", n))
        for i = 1, n do
            local v = nil
            pcall(function() v = dataArr[i] end)
            if v == nil then pcall(function() v = dataArr:Get(i) end) end
            print(string.format("[LivingBase] [probe-cpd]   [%d] = %s\n", i - 1, tostring(v)))
        end
    end)
end

-- Spawner.ProbeNiagaraSpawnAttachedSignature() -- TEMP DEV TOOL (2026-08-21). Follow-up to
-- ProbeNiagaraFunctions: confirmed "SpawnSystemAttached" exists in this build, but knowing the NAME
-- isn't enough to call it safely -- wrong arg count/order/type on a native UFunction call is a real
-- crash risk in this codebase (documented elsewhere in this file). A UFunction IS itself a UStruct,
-- so its parameters are readable via the SAME ForEachProperty reflection already used safely on
-- classes everywhere else -- this just points it at the FUNCTION object instead of a class, and for
-- each param also tries to resolve what type of property it is (ObjectProperty/BoolProperty/etc.)
-- and, for object params, which CLASS it expects (PropertyClass) -- e.g. confirming the first param
-- really does want a NiagaraSystem and not something else. Still just reflection, nothing invoked.
function Spawner.ProbeNiagaraSpawnAttachedSignature()
    local cdo
    pcall(function() cdo = StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary") end)
    if not (cdo and cdo:IsValid()) then
        print("[LivingBase] [probe-niagarasig] could not resolve NiagaraFunctionLibrary CDO.\n")
        return
    end
    local cls
    pcall(function() cls = cdo:GetClass() end)
    if not (cls and cls:IsValid()) then
        print("[LivingBase] [probe-niagarasig] could not resolve NiagaraFunctionLibrary class.\n")
        return
    end
    local targetFn
    pcall(function()
        cls:ForEachFunction(function(fn)
            if targetFn then return end
            local n = "?"
            pcall(function() n = fn:GetFName():ToString() end)
            if n == "SpawnSystemAttached" then targetFn = fn end
        end)
    end)
    if not (targetFn and targetFn:IsValid()) then
        print("[LivingBase] [probe-niagarasig] SpawnSystemAttached not found on this class.\n")
        return
    end
    print("[LivingBase] [probe-niagarasig] -- SpawnSystemAttached params --\n")
    pcall(function()
        targetFn:ForEachProperty(function(prop)
            local pname = "?"
            pcall(function() pname = prop:GetFName():ToString() end)
            local ptype = "?"
            pcall(function() ptype = prop:GetClass():GetFName():ToString() end)
            local extra = ""
            pcall(function()
                local pc = prop.PropertyClass
                if pc and pc:IsValid() then extra = " -> " .. pc:GetFName():ToString() end
            end)
            pcall(function()
                if extra == "" then
                    local st = prop.Struct
                    if st and st:IsValid() then extra = " -> " .. st:GetFName():ToString() end
                end
            end)
            pcall(function()
                if extra == "" then
                    local en = prop.Enum
                    if en and en:IsValid() then extra = " -> " .. en:GetFName():ToString() end
                end
            end)
            local flags = "?"
            pcall(function() flags = tostring(prop.PropertyFlags) end)
            print(string.format("[LivingBase] [probe-niagarasig]   %s : %s%s  (flags=%s)\n", pname, ptype, extra, flags))
        end)
    end)
end

-- Spawner.ProbeCPDIndexSignature() -- TEMP DEV TOOL (2026-08-21). Follow-up to ProbeCustomPrimitiveData
-- -- GetCustomPrimitiveDataIndexForVectorParameter/ForScalarParameter can tell us, BY PARAMETER NAME,
-- whether a specific material actually reads Custom Primitive Data at all (returns a real index) or
-- doesn't (-1/INDEX_NONE), instead of guessing blind whether Windrose's materials support tinting this
-- way. Much simpler function than SpawnSystemAttached (no structs/enums, just an object + a name), but
-- still reflecting the signature first before calling anything, same caution as before the crash.
function Spawner.ProbeCPDIndexSignature()
    local pcCls
    pcall(function() pcCls = StaticFindObject("/Script/Engine.PrimitiveComponent") end)
    if not (pcCls and pcCls:IsValid()) then
        print("[LivingBase] [probe-cpdsig] could not resolve PrimitiveComponent class.\n")
        return
    end
    for _, fname in ipairs({ "GetCustomPrimitiveDataIndexForVectorParameter", "GetCustomPrimitiveDataIndexForScalarParameter" }) do
        local targetFn
        pcall(function()
            pcCls:ForEachFunction(function(fn)
                if targetFn then return end
                local n = "?"
                pcall(function() n = fn:GetFName():ToString() end)
                if n == fname then targetFn = fn end
            end)
        end)
        if not (targetFn and targetFn:IsValid()) then
            print("[LivingBase] [probe-cpdsig] " .. fname .. " not found.\n")
        else
            print("[LivingBase] [probe-cpdsig] -- " .. fname .. " params --\n")
            pcall(function()
                targetFn:ForEachProperty(function(prop)
                    local pname = "?"
                    pcall(function() pname = prop:GetFName():ToString() end)
                    local ptype = "?"
                    pcall(function() ptype = prop:GetClass():GetFName():ToString() end)
                    print(string.format("[LivingBase] [probe-cpdsig]   %s : %s\n", pname, ptype))
                end)
            end)
        end
    end
end

-- Spawner.ProbeCPDNames() -- TEMP DEV TOOL (2026-08-21). GetCustomPrimitiveDataIndexForVectorParameter
-- only takes a ParameterName (FName) -> index -- it's a method ON the component itself (looks up
-- against whatever material that component currently has assigned), and it's a pure read-only query
-- (returns -1/INDEX_NONE for a name the material doesn't use, no risk either way) -- much lower risk
-- than the crashed Niagara call: one simple string arg, no structs/enums/attach semantics. Tries a
-- batch of plausible tint/highlight parameter names against Spawner._lastProbedActor's mesh component
-- in one pass, including "Edge Color" (a real, CONFIRMED-existing VectorParameterValues name on the
-- chest materials probed earlier this session -- worth trying since materials sometimes expose the
-- same conceptual name both as a static per-instance override AND a runtime CPD hook).
function Spawner.ProbeCPDNames()
    -- DISABLED (2026-08-21): confirmed live to hard-crash the game (crash_2026_08_21_21_30_01),
    -- faulting on the very first candidate name with ZERO output printed first -- meaning
    -- GetCustomPrimitiveDataIndexForVectorParameter/ForScalarParameter themselves crash natively in
    -- this build, not just SpawnSystemAttached. pcall did not (cannot) catch it. Two different native
    -- UFunction CALLS have now hard-crashed this session despite looking simple beforehand -- treat
    -- ANY unproven native call as high-risk here, not just structurally complex ones. Left in place,
    -- disabled, for reference -- see the commented-out body below.
    print("[LivingBase] [probe-cpdnames] DISABLED -- this call hard-crashed the game once already. See spawner.lua's own comment.\n")
end
--[[ Reference only, removed from the live function above (2026-08-21):

local target = Spawner._lastProbedActor
local comp = target.Mesh
local candidates = {
    "Edge Color", "AO Color", "Bottom Color", "Top Color",
    "Tint", "TintColor", "Tint Color",
    "Highlight", "Highlight Color", "HighlightColor",
    "Selection", "Selection Color", "SelectionColor",
    "Focus", "Focus Color", "InteractHighlight",
}
for _, name in ipairs(candidates) do
    local idxV = comp:GetCustomPrimitiveDataIndexForVectorParameter(name)
    local idxS = comp:GetCustomPrimitiveDataIndexForScalarParameter(name)
end
]]

-- Spawner.TestSpawnNiagara() / TestSpawnNiagaraClear() -- TEMP DEV TOOL (2026-08-21). First-ever call
-- into UNiagaraFunctionLibrary from this codebase, confirmed via ProbeNiagaraSpawnAttachedSignature's
-- reflection dump to take (SystemTemplate, AttachToComponent, AttachPointName, Location, Rotation,
-- LocationType, bAutoDestroy, PoolingMethod, bPreCullCheck) -> UNiagaraComponent. Isolated, manual
-- on/off test on whatever lbprobe last cached -- NOT wired into the real hover-highlight flow yet.
-- bAutoDestroy=false (manual control, matches TestSpawnNiagaraClear) since FX_PickUP_Chest_01 is a
-- looping sparkle, not a one-shot burst. LocationType=0 (EAttachLocation::KeepRelativeOffset) with a
-- zero Location offset -- functionally the same end result as a "snap to target" mode without needing
-- to guess that enum's exact ordinal in this UE version. PoolingMethod=0 (None) -- simplest, no
-- pooling. Genuinely first native call of its kind here, so pcall'd throughout and reported plainly if
-- it fails -- pcall can't catch a hard native crash, only a Lua-level error.
local NIAGARA_FX_CHEST_PICKUP = "/Game/FX/Particles/Environment/PickUP/FX_PickUP_Chest_01.FX_PickUP_Chest_01"
function Spawner.TestSpawnNiagara()
    -- DISABLED (2026-08-21): confirmed live to hard-crash the game (crash_2026_08_21_20_39_20) on
    -- the 3rd attempt, once the arg COUNT was finally right (10 args, matching UE4SS's own
    -- expected-params-minus-return-value math in LuaUObject.cpp) -- the crash happened inside the
    -- native call itself, before any Lua-catchable error, meaning something about the actual
    -- VALUES/types (not the count) faulted at the engine level. RedFalcon chose to abandon this
    -- approach entirely rather than keep guessing at a call that's already proven it can hard-crash
    -- (see project_build_ghost_preview.md memory) -- pursuing the duplicate-ghost-mesh overlay
    -- instead. Left in place, disabled, rather than deleted, in case revisiting this is ever worth it
    -- with a fresh angle (e.g. a UE-version-matched Niagara sample project to confirm exact expected
    -- struct/enum marshalling instead of guessing).
    print("[LivingBase] [test-niagara] DISABLED -- this call hard-crashed the game once already. See spawner.lua's own comment.\n")
end
--[[ Reference only, unreachable/removed from the live function above (2026-08-21) -- kept as a
comment in case this approach is ever worth revisiting with a fresh angle. Last attempt (10 args,
correct count per UE4SS's own expected-params-minus-return-value math) still hard-crashed natively
inside the call itself, so whatever's wrong is in the VALUES/types, not the count:

local target = Spawner._lastProbedActor
local sys = resolveAsset(NIAGARA_FX_CHEST_PICKUP)
local root = target.RootComponent
local nfl = StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
local comp = nfl:SpawnSystemAttached(
    sys, root, "",
    { X = 0.0, Y = 0.0, Z = 0.0 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },
    0,      -- LocationType: EAttachLocation::KeepRelativeOffset
    false,  -- bAutoDestroy
    true,   -- bAutoActivate
    0,      -- PoolingMethod: ENCPoolMethod::None
    true    -- bPreCullCheck
)
]]

function Spawner.TestSpawnNiagaraClear()
    local comp = Spawner._testNiagaraComp
    if not (comp and comp:IsValid()) then
        print("[LivingBase] [test-niagara] nothing to clear.\n")
        return
    end
    pcall(function() comp:Deactivate() end)
    pcall(function() comp:DestroyComponent(false) end)
    Spawner._testNiagaraComp = nil
    print("[LivingBase] [test-niagara] cleared.\n")
end

-- Spawner.TestSpawnNiagaraActor() / TestSpawnNiagaraActorClear() -- TEMP DEV TOOL (2026-08-21). After
-- BOTH SpawnSystemAttached (crash_2026_08_21_20_39_20) and GetCustomPrimitiveDataIndexForVectorParameter
-- (crash_2026_08_21_21_30_01) hard-crashed the game, RedFalcon asked to search the pak listing
-- (Other\pakcontents.xlsx) for something spawnable instead -- no reusable generic FX Blueprint actor
-- turned up (BP_Niagara_Bleeding is the only actor in the one "generic" FX folder, everything else is
-- scenario-specific). Falls back to a stock, native UE class instead: NiagaraActor
-- (/Script/Niagara.NiagaraActor) is a bare actor whose only job is holding one NiagaraComponent, with
-- a plain settable `Asset` property -- this avoids calling EITHER crashed function entirely. Uses ONLY
-- mechanisms already proven safe elsewhere in this exact file: Spawner._DoEngineSpawn (the same
-- spawn helper Spawner.Spawn itself uses, with its own signature auto-detection), a preFinish hook
-- (same pattern used for AIControllerClass overrides -- see its own comment), a plain property READ
-- (actor.NiagaraComponent, the same pattern ProbeLootSparkle already used without issue) and a plain
-- property WRITE (niag.Asset = sys, the SAME pattern _DoEngineSpawn's own aiClass override already
-- uses: `deferred.AIControllerClass = aiClass`) -- no new UFunction CALL anywhere in this path.
function Spawner.TestSpawnNiagaraActor(assetPath)
    local target = Spawner._lastProbedActor
    if not (target and target:IsValid()) then
        print("[LivingBase] [test-niagaraactor] no valid probed target -- run lbprobe on something first.\n")
        return
    end
    assetPath = assetPath or NIAGARA_FX_CHEST_PICKUP
    local sys = resolveAsset(assetPath)
    if not (sys and sys:IsValid()) then
        print("[LivingBase] [test-niagaraactor] could not resolve " .. assetPath .. "\n")
        return
    end
    local cls
    pcall(function() cls = StaticFindObject("/Script/Niagara.NiagaraActor") end)
    if not (cls and cls:IsValid()) then
        print("[LivingBase] [test-niagaraactor] could not resolve NiagaraActor class.\n")
        return
    end
    local gs = getGameplayStatics()
    local world = UEHelpers.GetWorld()
    if not (gs and world and world:IsValid()) then
        print("[LivingBase] [test-niagaraactor] no GameplayStatics/World available.\n")
        return
    end
    -- Scale + placement from the target's own bounds (2026-08-21, RedFalcon: "is it possible to
    -- resize it to match the hitbox of the object?" then "it always spawns halfway up the actors")
    -- -- GetActorBounds' 4-arg form (Origin/BoxExtent as pre-allocated Out-param tables) is already
    -- proven safe elsewhere in this file (actorBoundsBottomZ/computeActorCenterOffset) -- reused
    -- directly here rather than calling either of those (both declared much later in the file, so
    -- calling them here would hit this file's own documented Lua forward-declaration scoping
    -- gotcha). ONE bounds read now drives both: scale from horizontal extent only (tall, narrow
    -- objects like statues/lampposts have Z as their LARGEST extent, which was driving the scale up
    -- even though the effect should track the FOOTPRINT, not the height), and placement at the
    -- bounding box's BOTTOM-CENTER (origin.X/Y, origin.Z - extent.Z) instead of the raw actor pivot
    -- -- same root cause as the earlier decor "sits low"/statue anchor-offset bugs this session:
    -- these actors' pivots sit mid-body, not at their visual base, so K2_GetActorLocation() alone put
    -- the effect halfway up instead of grounded under the object. Falls back to
    -- K2_GetActorLocation() only if bounds can't be read at all.
    -- BUG FIX (2026-08-21, RedFalcon: "it still pops up halfway up a statue... It isnt changing
    -- width though") -- NOT actually statue-specific: `local ok = target:GetActorBounds(...)`
    -- captured GetActorBounds' own Lua return value as "ok" -- but GetActorBounds is a void
    -- UFunction that only writes through its Origin/BoxExtent OUT-PARAMS, it has no real return
    -- value, so `ok` was always nil/falsy and this whole branch silently never ran for ANYONE,
    -- decor included -- see actorBoundsBottomZ's own proven pattern just above in this file, which
    -- wraps the call in pcall() and uses PCALL's own success boolean as "ok", not the function's.
    -- Decor only looked "fine" by coincidence: static prop pivots are usually already near their
    -- base, so the fallback K2_GetActorLocation() happened to land close to the ground anyway;
    -- statues' pivots sit mid-body, so the exact same silent failure looked completely different.
    local scaleMul = 1.0
    local loc
    pcall(function()
        local origin, extent = {}, {}
        local ok = pcall(function() target:GetActorBounds(false, origin, extent, false) end)
        if ok and origin.X and origin.Y and origin.Z and extent.X and extent.Y and extent.Z then
            loc = { X = origin.X, Y = origin.Y, Z = origin.Z - extent.Z }
            local radius = math.max(extent.X, extent.Y)
            local base = Config.NIAGARA_HIGHLIGHT_BASE_RADIUS_UU or 50.0
            if radius > 0 and base > 0 then
                scaleMul = radius / base
                local minS, maxS = Config.NIAGARA_HIGHLIGHT_MIN_SCALE or 0.3, Config.NIAGARA_HIGHLIGHT_MAX_SCALE or 4.0
                if scaleMul < minS then scaleMul = minS end
                if scaleMul > maxS then scaleMul = maxS end
            end
        end
    end)
    if not loc then pcall(function() loc = target:K2_GetActorLocation() end) end
    if not loc then
        print("[LivingBase] [test-niagaraactor] could not read target location/bounds.\n")
        return
    end
    local transform = {
        Rotation = { W = 1.0, X = 0.0, Y = 0.0, Z = 0.0 },
        Translation = { X = loc.X, Y = loc.Y, Z = loc.Z },
        Scale3D = { X = scaleMul, Y = scaleMul, Z = scaleMul },
    }
    print(string.format("[LivingBase] [test-niagaraactor] scaleMul=%.2f loc=(%.1f,%.1f,%.1f)\n",
        scaleMul, loc.X, loc.Y, loc.Z))
    local preFinish = function(actor)
        pcall(function()
            local niag = actor.NiagaraComponent
            if niag and niag:IsValid() then
                niag.Asset = sys
            end
        end)
    end
    local actor = Spawner._DoEngineSpawn(gs, world, cls, transform, "TestNiagaraActor", preFinish, nil)
    if not (actor and actor:IsValid()) then
        print("[LivingBase] [test-niagaraactor] spawn failed.\n")
        return
    end
    Spawner._testNiagaraActor = actor
    print("[LivingBase] [test-niagaraactor] spawned OK at target's location. Run lbtestniagaraactorclear to remove it.\n")
end

function Spawner.TestSpawnNiagaraActorClear()
    local actor = Spawner._testNiagaraActor
    if not (actor and actor:IsValid()) then
        print("[LivingBase] [test-niagaraactor] nothing to clear.\n")
        return
    end
    pcall(function() actor:K2_DestroyActor() end)
    Spawner._testNiagaraActor = nil
    print("[LivingBase] [test-niagaraactor] cleared.\n")
end

-- Spawner.SpawnHoverEffect(actor) / ClearHoverEffect() -- PRODUCTION hover-highlight for CHARACTER
-- targets (statues, walkers, idle Senkamati -- anything with a SkeletalMeshComponent), replacing the
-- material-swap ghost highlight for these specifically (2026-08-22, RedFalcon: "instead of the
-- texture change, use the effect thing we were trying but us this effect halfway up their body
-- (where the sparkle was originally appearing earlier). It loops, is small and is visible through
-- objects"). Decor keeps the existing material-swap (applyHoverHighlight/restoreHoverMaterials) --
-- it's static-mesh only and never had the skin/eye restore problem this whole detour was chasing.
-- Reuses the exact proven-safe pattern from Spawner.TestSpawnNiagaraActor (NiagaraActor spawn via
-- _DoEngineSpawn + a plain .Asset property write -- no risky function calls, same building blocks
-- that already worked live with zero crashes). Placed at the RAW actor pivot
-- (K2_GetActorLocation), NOT the bounds-bottom TestSpawnNiagaraActor uses for its own different
-- ground-ring use case -- "halfway up their body" is RedFalcon's deliberate choice here, and matches
-- where these actors' pivots naturally sit (mid-body, the same offset that was originally a bug for
-- the ground-ring idea).
local HOVER_EFFECT_FX_PATH = "/Game/FX/Particles/Mobs/Actions/Unblockable/FX_Unblockable_Attack_PreActionState.FX_Unblockable_Attack_PreActionState"
-- Spawner.ComputeHoverEffectLoc(actor) -- pose-based height drop (2026-08-22, RedFalcon: "any of the
-- ground sitting and squatting people, their pivot point is the same as the standing statues. they
-- will need their position dropped 50%. Sleeping people would need it dropped 75%") -- floor/ground
-- poses (SitterOnGround, LayOnGround -- confirmed real classPath substrings, see the statue
-- manifest's own comment: "*_SitterOnGround / *_LayOnGround -- floor poses") share the SAME
-- root-bone pivot height as a standing statue even though the actual pose sits much lower to the
-- ground, so using the raw pivot puts the effect way too high on their now-much-shorter silhouette.
-- Reduces the pivot's height ABOVE THE FLOOR by the given fraction (0% standing/unchanged, 50%
-- ground-sitting/squatting, 75% sleeping) rather than an absolute Z offset, so it scales correctly
-- regardless of how tall any given statue's pivot-to-floor gap actually is. Floor Z via the SAME
-- proven GetActorBounds 4-arg pcall pattern used elsewhere in this file (actorBoundsBottomZ/
-- computeActorCenterOffset). Shared by BOTH SpawnHoverEffect (initial placement) and
-- UpdateHoverHighlight's per-tick reposition (same target, still hovering) -- the drop must be
-- computed identically in both places, or the effect would visibly snap to the wrong height on the
-- very next tick after spawning correctly.
function Spawner.ComputeHoverEffectLoc(actor)
    if not (actor and actor:IsValid()) then return nil end
    local loc
    pcall(function() loc = actor:K2_GetActorLocation() end)
    if not loc then return nil end
    local class
    for _, e in ipairs(Spawner.spawned) do
        if e.actor == actor then class = e.class; break end
    end
    local dropFraction = 0.0
    if class then
        if class:find("LayOnGround") then dropFraction = 0.75
        elseif class:find("SitterOnGround") then dropFraction = 0.5 end
    end
    if dropFraction > 0 then
        pcall(function()
            local origin, extent = {}, {}
            local ok = pcall(function() actor:GetActorBounds(false, origin, extent, false) end)
            if ok and origin.Z and extent.Z then
                local floorZ = origin.Z - extent.Z
                loc.Z = floorZ + (loc.Z - floorZ) * (1.0 - dropFraction)
            end
        end)
    end
    return loc
end

function Spawner.SpawnHoverEffect(actor)
    if not (actor and actor:IsValid()) then return false end
    local sys = resolveAsset(HOVER_EFFECT_FX_PATH)
    if not (sys and sys:IsValid()) then return false end
    local loc = Spawner.ComputeHoverEffectLoc(actor)
    if not loc then return false end
    local cls
    pcall(function() cls = StaticFindObject("/Script/Niagara.NiagaraActor") end)
    if not (cls and cls:IsValid()) then return false end
    local gs = getGameplayStatics()
    local world = UEHelpers.GetWorld()
    if not (gs and world and world:IsValid()) then return false end
    local scaleMul = Config.HOVER_EFFECT_SCALE or 0.6
    local transform = {
        Rotation = { W = 1.0, X = 0.0, Y = 0.0, Z = 0.0 },
        Translation = { X = loc.X, Y = loc.Y, Z = loc.Z },
        Scale3D = { X = scaleMul, Y = scaleMul, Z = scaleMul },
    }
    local preFinish = function(a)
        pcall(function()
            local niag = a.NiagaraComponent
            if niag and niag:IsValid() then niag.Asset = sys end
        end)
    end
    local effectActor = Spawner._DoEngineSpawn(gs, world, cls, transform, "HoverEffect", preFinish, nil)
    if not (effectActor and effectActor:IsValid()) then return false end
    Spawner._hoverEffectActor = effectActor
    Spawner._hoverActor = actor
    return true
end

-- Destroys the spawned effect actor if one exists. Deliberately does NOT touch Spawner._hoverActor
-- itself -- UpdateHoverHighlight's own transition logic manages that centrally (both this and
-- restoreHoverMaterials get called defensively on every transition/loss regardless of which path was
-- actually active, so ordering there -- not here -- is what has to stay correct).
function Spawner.ClearHoverEffect()
    local e = Spawner._hoverEffectActor
    Spawner._hoverEffectActor = nil
    if e and e:IsValid() then
        pcall(function() e:K2_DestroyActor() end)
    end
end

-- Spawner.CycleTestNiagaraEffect() -- TEMP DEV TOOL (2026-08-21, RedFalcon: "i'm not sold on the
-- sparkles" -- "just want to see other options"). Candidates pulled from Other\pakcontents.xlsx --
-- other entries in the same Pickup family, plus FX_Boatswain_Visualization_Circle (a ground-projected
-- ring/circle used for a boss-fight telegraph zone, which reads much more like a "this is targeted"
-- selection indicator than a sparkle burst). Swaps the Asset on the ALREADY-spawned test actor
-- (spawning one via TestSpawnNiagaraActor first if none exists yet) rather than respawning each time
-- -- one more plain property write (niag.Asset = sys, the same proven-safe pattern used to set it the
-- first time), no new native calls. Run repeatedly to step through the list.
local NIAGARA_HIGHLIGHT_CANDIDATES = {
    "/Game/FX/Particles/Environment/Pickup/FX_PickUP_Chest_01.FX_PickUP_Chest_01",
    "/Game/FX/Particles/Environment/Pickup/FX_PickUP_Sparkles_01.FX_PickUP_Sparkles_01",
    "/Game/FX/Particles/Environment/Pickup/FX_PickUP_Object_01.FX_PickUP_Object_01",
    "/Game/FX/Particles/Bosses/CoastJungle/Boatswain/FX_Boatswain_Visualization_Circle.FX_Boatswain_Visualization_Circle",
    "/Game/FX/Particles/Environment/InteractiveObjects/Pickup/FX_LootBox_Small.FX_LootBox_Small",
    "/Game/FX/Particles/Environment/InteractiveObjects/Pickup/FX_LootBox_Medium.FX_LootBox_Medium",
}
-- NOT using a live .Asset swap + re-activate on the EXISTING actor -- that would need an extra
-- method call (something like ActivateSystem) that's never been tried in this build, and today's two
-- crashes both came from assuming an unfamiliar call was safe. Destroy + respawn instead, reusing
-- Spawner.TestSpawnNiagaraActor's own fully-proven flow (spawn helper + K2_DestroyActor, both used
-- constantly elsewhere in this file) with a different candidate asset each time -- slightly heavier
-- than an in-place swap, but zero new native-call surface.
Spawner._testNiagaraCandidateIdx = Spawner._testNiagaraCandidateIdx or 0
function Spawner.CycleTestNiagaraEffect()
    Spawner._testNiagaraCandidateIdx = (Spawner._testNiagaraCandidateIdx % #NIAGARA_HIGHLIGHT_CANDIDATES) + 1
    local path = NIAGARA_HIGHLIGHT_CANDIDATES[Spawner._testNiagaraCandidateIdx]
    print(string.format("[LivingBase] [test-niagaraactor] cycling to [%d/%d]: %s\n",
        Spawner._testNiagaraCandidateIdx, #NIAGARA_HIGHLIGHT_CANDIDATES, path))
    Spawner.TestSpawnNiagaraActorClear()
    Spawner.TestSpawnNiagaraActor(path)
end

-- Spawner.TestSpawnNiagaraByPath(pathArg) -- TEMP DEV TOOL (2026-08-21, RedFalcon: "is there a way to
-- make a function where i can enter an effect name or path and i can kinda work through some") --
-- takes any /Game/... asset path pasted straight out of Other\pakcontents.xlsx, WITH or WITHOUT the
-- trailing ".AssetName" (auto-derived from the last path segment if missing, the same
-- Package.AssetName convention used everywhere else in this file), and spawns it the same
-- proven-safe way as CycleTestNiagaraEffect (destroy old test actor if any, respawn fresh with the
-- given asset) -- no name->path index built (that's a bigger, separate task, not needed for "let me
-- paste a path and try it"); just paste the full path from the spreadsheet.
function Spawner.TestSpawnNiagaraByPath(pathArg)
    if not pathArg or pathArg == "" then
        print("[LivingBase] [test-niagarapath] usage: lbtestniagarapath <full /Game/... asset path, dotted suffix optional>\n")
        return
    end
    local path = pathArg
    if not path:match("%.[%w_]+$") then
        local last = path:match("([^/]+)$")
        if last then path = path .. "." .. last end
    end
    Spawner.TestSpawnNiagaraActorClear()
    Spawner.TestSpawnNiagaraActor(path)
end

-- Spawner.ProbeInteractionTargetParams() -- TEMP DEV TOOL (2026-08-21). RedFalcon found two native
-- DataAssets that likely drive the game's OWN interaction-highlight system (the sparkle/prompt shown
-- when looking at a lootable item or harvestable crop) -- an alternative to our hand-rolled
-- material-swap ghost highlight, which is what's been causing the statue skin/eye white-restore
-- saga (see this file's memory notes) in the first place:
--   R5/Content/Gameplay/Interaction/Params/DA_InteractionTarget_Loot.uasset
--   R5/Content/Gameplay/Interaction/Params/Farming/DA_InteractionTarget_Crop.uasset
-- If these reference a reusable Niagara/decal/outline effect (rather than a material), we could
-- spawn/attach THAT instead of ever touching the target's own materials -- sidesteps the whole
-- restore problem structurally instead of skip-listing more slots. Read-only: resolves each
-- DataAsset (same /Game/... .AssetName convention as DA_DID_Resource_Stone_T01 elsewhere in this
-- file) and dumps its declared properties via dumpObjectProperties -- the same safe, non-drilling
-- reflection walk Spawner.ProbeDumpProperties already uses on live actors, just pointed at a static
-- DataAsset instead (no live component graph, so the one documented crash from THAT tool -- reflectively
-- auto-drilling into a live R5CommonInteractionTargetComponent -- doesn't apply here).
local INTERACTION_PARAMS_PATHS = {
    "/Game/Gameplay/Interaction/Params/DA_InteractionTarget_Loot.DA_InteractionTarget_Loot",
    "/Game/Gameplay/Interaction/Params/Farming/DA_InteractionTarget_Crop.DA_InteractionTarget_Crop",
}
function Spawner.ProbeInteractionTargetParams()
    for _, path in ipairs(INTERACTION_PARAMS_PATHS) do
        local obj = resolveClass(path)
        if obj and obj:IsValid() then
            print("[LivingBase] [probe-interact] resolved " .. path .. "\n")
            dumpObjectProperties(obj, path)
        else
            print("[LivingBase] [probe-interact] could NOT resolve " .. path .. "\n")
        end
    end
end

-- Spawner.DumpMeshComponentNames(actor) -- TEMP DEV TOOL (2026-08-09): list every
-- SkeletalMeshComponent on the probed actor (component name + its currently assigned
-- mesh). dumpObjectProperties above only shows top-level UPROPERTYs, not the mesh
-- assigned to each composite sub-component -- exactly what's needed to find the real
-- component name for a Senkamati Warrior/Hunter's head/helmet piece before writing a
-- Config.DECORRUPT_* hide rule for it (guessing the name risks a rule that silently
-- matches nothing, same failure mode already hit once on the Warrior/Hunter skin
-- swaps). Mirrors the doComp() component sweep in Spawner.DeCorrupt, read-only.
-- Remove once the real component names are confirmed and the hide rule is written.
local function dumpMeshComponentNames(actor)
    -- fullPath added 2026-08-10: the short name alone (e.g. "SK_Armor_Underwear_02_Female_Legs")
    -- isn't resolvable by Spawner.DeCorrupt's `replaces.to` -- that needs the full /Game/ asset
    -- path. Printing it here means a `replaces` target can be copied straight from the log
    -- instead of guessed (guessing the wrong folder has already cost a full test cycle once).
    local function meshOf(c)
        local sk = nil
        pcall(function()
            sk = c.SkeletalMesh
            if not (sk and sk:IsValid()) and c.GetSkeletalMeshAsset then sk = c:GetSkeletalMeshAsset() end
        end)
        return sk
    end
    -- materialsOf added 2026-08-10: needed to find the exact material name on the underwear-Legs
    -- piece so Config.DECORRUPT_CREW_FEMALE/DECORRUPT_CREW/DECORRUPT_CREW_HUNTER can add a
    -- `swaps` rule recoloring it to the wearer's own skin tone (see Config.SENKA_UNDERWEAR_LEGS_*
    -- 's own comment) -- can't write that rule without knowing what material it's actually using.
    -- full paths added 2026-08-10 (second pass): the short material name alone isn't resolvable
    -- by Spawner.DeCorrupt's `swaps.to` either, same reason fullPath was added for meshes above.
    local function materialsOf(c)
        local names = {}
        local n = 0
        pcall(function() n = c:GetNumMaterials() end)
        for m = 0, (n - 1) do
            local nm = "?"
            pcall(function()
                local cur = c:GetMaterial(m)
                if cur and cur:IsValid() then
                    nm = cur:GetFName():ToString()
                    local full = ""
                    pcall(function() full = cur:GetFullName() end)
                    if full ~= "" then nm = nm .. "[" .. full .. "]" end
                end
            end)
            names[#names + 1] = nm
        end
        return names
    end
    local function say(c)
        if not (c and c:IsValid()) then return end
        local compName = "?"
        pcall(function() compName = c:GetFName():ToString() end)
        local sk = meshOf(c)
        local nm, full = "", ""
        if sk and sk:IsValid() then
            pcall(function() nm = sk:GetFName():ToString() end)
            pcall(function() full = sk:GetFullName() end)
        end
        print(string.format("[LivingBase] [probe-mesh] comp[%s] mesh=%s full=%s mats=%s\n",
            compName, nm ~= "" and nm or "(none)", full ~= "" and full or "-",
            table.concat(materialsOf(c), ",")))
    end
    pcall(function() local mm = actor.Mesh; if mm and mm:IsValid() then say(mm) end end)
    local n = 0
    local cls = StaticFindObject("/Script/Engine.SkeletalMeshComponent")
    if cls and cls:IsValid() then
        local comps
        pcall(function() comps = actor:K2_GetComponentsByClass(cls) end)
        if comps then
            pcall(function() n = comps:GetArrayNum() end)
            if n == 0 then pcall(function() n = #comps end) end
            for i = 1, n do
                local c = nil
                pcall(function() c = comps[i] end)
                if c == nil then pcall(function() c = comps:Get(i) end) end
                pcall(function() if c ~= nil and type(c) == "userdata" and c.get then c = c:get() end end)
                say(c)
            end
        end
    end
    print(string.format("[LivingBase] [probe-mesh] %d skeletal mesh components total.\n", n))
end

-- dumpAnimInfo(actor) -- TEMP DEV/PROBE TOOL (2026-08-14): what actually drives a pawn's CURRENT
-- pose/animation on its main body mesh (`actor.Mesh`, same property dumpMeshComponentNames
-- already reads first). Built to answer a specific question: the Senkamati statue's "standing"
-- look (the crew/Handyman base, frozen via SetAILogic) locks into a generic neutral rest pose
-- once frozen, not the distinctive stance the REAL Female_Standing_01 statue bodies have baked
-- into their own AnimBP -- RedFalcon asked whether that specific pose could be ported onto the
-- (better-fitted) crew body instead of a mesh swap. Reads two things, pure property/getter reads,
-- no side effects: `AnimationMode` (BlueprintMode vs SingleNodeMode) and `AnimClass` (the
-- AnimInstance Blueprint driving BlueprintMode), plus the actual runtime `GetAnimInstance()`
-- class as a cross-check.
-- REMOVED (same day, confirmed live): a third read, `AnimationData.AnimToPlay` (the single
-- AnimSequence driving SingleNodeMode) -- `AnimationData` is a native engine STRUCT, not an
-- object reference, and plain dot-access into a struct field is exactly the class of read this
-- project has already been burned by once (the per-world save-ID work needed real struct-drilling
-- via StaticFindObject+ForEachProperty instead of plain `x.y` -- see WINDROSE_MODDING_NOTES.md
-- #10). Confirmed here too: adding this line made PAUSE go completely silent (not even its own
-- first unconditional print) on the very next press -- a native crash, not a caught Lua error
-- (pcall cannot catch those, established repeatedly elsewhere in this file). If AnimToPlay is
-- ever genuinely needed, drill into the struct properly (resolve its UScriptStruct, ForEachProperty
-- over that, bracket-index the struct instance) rather than retrying plain dot-access.
local function dumpAnimInfo(actor)
    if not (actor and actor:IsValid()) then return end
    local mesh = nil
    pcall(function() mesh = actor.Mesh end)
    if not (mesh and mesh:IsValid()) then
        print("[LivingBase] [probe-anim] no actor.Mesh on this actor.\n")
        return
    end
    local mode = "?"
    pcall(function() mode = tostring(mesh.AnimationMode) end)
    local animClass, animClassFull = "(none)", ""
    pcall(function()
        local ac = mesh.AnimClass
        if ac and ac:IsValid() then
            animClass = ac:GetFName():ToString()
            pcall(function() animClassFull = ac:GetFullName() end)
        end
    end)
    local runtimeInstClass = "(none)"
    local animInstance = nil
    pcall(function()
        local inst = mesh:GetAnimInstance()
        if inst and inst:IsValid() then
            animInstance = inst
            runtimeInstClass = inst:GetClass():GetFName():ToString()
        end
    end)
    print(string.format(
        "[LivingBase] [probe-anim] AnimationMode=%s AnimClass=%s (%s) RuntimeAnimInstanceClass=%s\n",
        mode, animClass, animClassFull ~= "" and animClassFull or "-", runtimeInstClass))
    -- AnimInstance's OWN properties (2026-08-14, RedFalcon's follow-up) -- both Standing_01 and
    -- Sitting_01 came back BlueprintMode on the SAME AnimClass (ABP_StandingNPC_Regular_AI_C), no
    -- static AnimSequence involved -- so whatever actually picks standing-vs-sitting has to be a
    -- variable ON THIS INSTANCE (almost certainly set by the statue's own Blueprint construction
    -- script), not anything on the mesh component itself. That's exactly why the item 54/55
    -- AnimClass swap T-posed: assigning the class alone never supplied whatever this variable
    -- needs. Reuses `dumpObjectProperties` UNCHANGED -- it already walks any object's declared
    -- properties across its full class hierarchy via the same proven-safe reflection pattern (has
    -- run clean on Actor/Pawn hierarchies all session); this is just pointing it at the
    -- AnimInstance object instead of the actor.
    if animInstance then
        pcall(function() dumpObjectProperties(animInstance, "ANIMINSTANCE") end)
    end
    -- BodyMorph actual X/Y/Z -- RedFalcon's follow-up (2026-08-15) after 5 straight pose-porting
    -- dead ends: "what if we set every anim setting the same as the standing pose, in case
    -- something important was missed". Fair challenge -- dumpObjectProperties' generic reader only
    -- ever prints a STRUCT-typed property as its TYPE name ("ScriptStruct /Script/CoreUObject.
    -- Vector"), never the actual X/Y/Z values, so BodyMorph (sitting right next to
    -- ArmorThicknessMorph in the same property list -- clearly a per-archetype body-shape input,
    -- not runtime graph state) was NEVER actually compared between the real statue and any test
    -- actor, unlike IsFemale?/ArmorThicknessMorph/Animation which all were. Same safe struct-
    -- drilling recipe as AnimationData.AnimToPlay (GetFullName for the type path, StaticFindObject,
    -- ForEachProperty, bracket-index the instance) -- deliberately NOT extended to every other
    -- struct property here (AnimGraphNode_Root/Slot/ControlRig/SequencePlayer, UberGraphFrame): those
    -- are internal anim-runtime state/raw execution pointers, rebuilt by the compiled graph itself
    -- every frame, not configuration -- reading (let alone writing) them is a different, much
    -- riskier question than a plain FVector.
    if animInstance then
        pcall(function()
            local bm = animInstance.BodyMorph
            if bm == nil then
                print("[LivingBase] [probe-anim] BodyMorph: nil/not accessible.\n")
                return
            end
            local typeFull = "?"
            pcall(function() typeFull = bm:GetFullName() end)
            local structPath = typeFull:match("ScriptStruct%s+(%S+)")
            if not structPath then
                print("[LivingBase] [probe-anim] BodyMorph: could not parse struct path from " .. tostring(typeFull) .. "\n")
                return
            end
            local structDef = StaticFindObject(structPath)
            if not (structDef and structDef:IsValid()) then
                print("[LivingBase] [probe-anim] BodyMorph: StaticFindObject(" .. structPath .. ") failed.\n")
                return
            end
            local x, y, z = "?", "?", "?"
            pcall(function() x = tostring(bm["X"]) end)
            pcall(function() y = tostring(bm["Y"]) end)
            pcall(function() z = tostring(bm["Z"]) end)
            print(string.format("[LivingBase] [probe-anim] BodyMorph = X=%s Y=%s Z=%s\n", x, y, z))
        end)
    end
    -- AnimationData.AnimToPlay -- SAFE VERSION (2026-08-14), reusing the exact struct-drilling
    -- recipe the per-world save-ID work established (WINDROSE_MODDING_NOTES.md #10): a top-level
    -- struct-VALUED property read (`mesh.AnimationData`) is safe on its own -- the crash earlier
    -- today was PLAIN DOT-ACCESS one level further into that wrapper (`.AnimToPlay`), not the
    -- struct read itself. Instead: read the wrapper's OWN `:GetFullName()` (which normally just
    -- reports the struct's TYPE, e.g. "ScriptStruct /Script/Engine.SingleAnimationPlayData" --
    -- USEFUL here, since it hands back the exact path to feed StaticFindObject without guessing),
    -- resolve that as a UScriptStruct, `:ForEachProperty()` over THAT to enumerate its declared
    -- field names, then read each field back via BRACKET-indexing the wrapper instance
    -- (`animData[fieldName]`) -- never `animData.AnimToPlay` directly. RedFalcon wants to port the
    -- real Female_Standing_01 statue's baked pose onto the crew body (a genuinely new mechanism,
    -- SetAnimationMode(SingleNode)+SetAnimation+Play, distinct from the AnimClass swap that
    -- T-posed) -- this is step one: find out what AnimSequence asset the REAL statue is actually
    -- playing, probed safely instead of guessed.
    pcall(function()
        local animData = mesh.AnimationData
        if animData == nil then
            print("[LivingBase] [probe-anim] AnimationData: nil/not accessible.\n")
            return
        end
        local typeFull = "?"
        pcall(function() typeFull = animData:GetFullName() end)
        print(string.format("[LivingBase] [probe-anim] AnimationData struct type: %s\n", typeFull))
        local structPath = typeFull:match("ScriptStruct%s+(%S+)")
        if not structPath then
            print("[LivingBase] [probe-anim] AnimationData: could not parse struct path from type name.\n")
            return
        end
        local structDef = StaticFindObject(structPath)
        if not (structDef and structDef:IsValid()) then
            print("[LivingBase] [probe-anim] AnimationData: StaticFindObject(" .. structPath .. ") failed.\n")
            return
        end
        pcall(function()
            structDef:ForEachProperty(function(prop)
                local pname = "?"
                pcall(function() pname = prop:GetFName():ToString() end)
                local valStr = "<unreadable>"
                local okv, val = pcall(function() return animData[pname] end)
                if okv then
                    if val == nil then
                        valStr = "nil"
                    elseif type(val) == "userdata" then
                        local okFull, full = pcall(function() return val:GetFullName() end)
                        if okFull and full then
                            valStr = full
                        else
                            local okStr, s = pcall(function() return val:ToString() end)
                            valStr = (okStr and s) and s or tostring(val)
                        end
                    else
                        valStr = tostring(val)
                    end
                end
                print(string.format("[LivingBase] [probe-anim]   AnimationData.%s = %s\n", pname, valStr))
            end)
        end)
    end)
end

-- Spawner.DumpColorControllers(actor) -- TEMP DEV/PROBE TOOL (2026-08-10): list EVERY
-- ColorController on the target's CompositeMeshComponent (name + AllowedRange). Looking for a
-- tattoo/body-art/marking selector -- if this game exposes tattoos through the SAME controller
-- system as hair/garment color (a "master material tinted by a selector+range" mechanism,
-- confirmed 2026-08-10/11 to only take effect at BUILD time, not live -- see the removed
-- Spawner.SetColorControllers' own note just above Spawner.HasMeshMatching), this will show
-- its SelectorName so a real
-- Spawner.ApplyTattoo can be written against a confirmed name instead of a guess. Unconditional
-- print (not VERBOSE-gated) -- this is a one-shot discovery print, meant to be seen. Remove once
-- tattoos are confirmed working or confirmed not to exist on this controller system at all.
local function dumpColorControllers(actor)
    if not (actor and actor:IsValid()) then return end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        print("[LivingBase] [probe-color] no CompositeMeshComponent on this actor.\n")
        return
    end
    local list = nil
    pcall(function() list = comp:GetColorControllers() end)
    if not list then
        print("[LivingBase] [probe-color] GetColorControllers() returned nothing.\n")
        return
    end
    local n = 0
    pcall(function() n = list:GetArrayNum() end)
    if n == 0 then pcall(function() n = #list end) end
    for i = 1, n do
        local ctrl = nil
        pcall(function() ctrl = list[i] end)
        if ctrl == nil then pcall(function() ctrl = list:Get(i) end) end
        pcall(function() if ctrl ~= nil and type(ctrl) == "userdata" and ctrl.get then ctrl = ctrl:get() end end)
        if ctrl then
            local name, lo, hi, cur = "", 0, 0, "?"
            pcall(function() name = ctrl.SelectorName:ToString() end)
            pcall(function() lo = ctrl.AllowedRange.Min; hi = ctrl.AllowedRange.Max end)
            pcall(function() cur = tostring(comp:GetColorControllerValue(ctrl)) end)
            print(string.format("[LivingBase] [probe-color] controller[%d] name='%s' range=%s..%s current=%s\n",
                i, tostring(name), tostring(lo), tostring(hi), cur))
        end
    end
    print(string.format("[LivingBase] [probe-color] %d color controller(s) total.\n", n))
end

-- dumpUnknownStruct(val, tag) -- shared helper (2026-08-19), extracted from the
-- dumpCustomizationMeshControllers investigation once it became clear the same "figure out an
-- unknown struct's shape" dance would be needed twice (the controller itself, then its nested
-- GroupCategoryId field). Two dead ends already found and folded in here: val:GetClass() on a
-- struct instance returns a useless generic "ScriptStruct" placeholder with 0 properties, not the
-- specific type; and the "extract the path out of tostring()" trick that worked for
-- CustomizationRecordID (raw form "ScriptStruct /Script/Module.Type") does NOT apply to this
-- "UScriptStruct: <hex>" shape -- for THIS shape, val:GetFName() and val:ForEachProperty() work
-- DIRECTLY on the value itself, no separate StaticFindObject(path) resolution needed.
-- Deliberately NOT auto-recursive into further nested structs it finds -- that's the same class of
-- blind auto-drill that crashed the game once already (see dumpObjectProperties' own header
-- comment) -- callers must explicitly ask for one more level, same discipline as everywhere else.
local function dumpUnknownStruct(val, tag)
    if val == nil then
        print("[LivingBase] [probe-struct] " .. tag .. " is nil.\n")
        return
    end
    local rawStr = tostring(val)
    print("[LivingBase] [probe-struct] " .. tag .. ": " .. rawStr .. "\n")
    if not rawStr:match("^UScriptStruct:") then
        print("[LivingBase] [probe-struct]   not a recognized struct shape -- nothing more to do.\n")
        return
    end
    local okName, name = pcall(function() return val:GetFName():ToString() end)
    if okName and name then print("[LivingBase] [probe-struct]   type name=" .. name .. "\n") end
    local propCount = 0
    local okWalk, errWalk = pcall(function()
        val:ForEachProperty(function(prop)
            propCount = propCount + 1
            local pname = "?"
            pcall(function() pname = prop:GetFName():ToString() end)
            local valStr = "<unreadable>"
            local okv, fv = pcall(function() return val[pname] end)
            if okv then
                local okStr, asStr = pcall(function() return fv:ToString() end)
                valStr = (okStr and asStr) and asStr or tostring(fv)
            end
            print(string.format("[LivingBase] [probe-struct]   %s = %s\n", pname, valStr))
        end)
    end)
    if not okWalk then
        print("[LivingBase] [probe-struct]   ForEachProperty FAILED: " .. tostring(errWalk) .. "\n")
    elseif propCount == 0 then
        print("[LivingBase] [probe-struct]   0 declared properties.\n")
    end
end

-- dumpNamedStruct(val, tag) -- the OTHER struct shape (§10/2b's original recipe, distinct from
-- dumpUnknownStruct's "UScriptStruct: <hex>" shape above): val:GetFullName() reports a real
-- resolvable type path ("ScriptStruct /Script/Module.Type", e.g. R5EquippedSlotData), unlike the
-- generic placeholder GetClass() returns for the other shape. Recipe proven on AnimationData/
-- BodyMorph (probe-anim, this file): extract the path, StaticFindObject it as the struct
-- DEFINITION, :ForEachProperty over THAT to enumerate declared field names, then read each field
-- back by bracket-indexing the actual VALUE (val[fieldName]) -- never dot-access past the wrapper,
-- confirmed elsewhere in this file to be what actually crashed once, not the struct read itself.
local function dumpNamedStruct(val, structPath, tag)
    local structDef = StaticFindObject(structPath)
    if not (structDef and structDef:IsValid()) then
        print("[LivingBase] [probe-struct] " .. tag .. ": StaticFindObject(" .. structPath .. ") failed.\n")
        return
    end
    pcall(function()
        structDef:ForEachProperty(function(prop)
            local pname = "?"
            pcall(function() pname = prop:GetFName():ToString() end)
            local valStr = "<unreadable>"
            local okv, fv = pcall(function() return val[pname] end)
            if okv then
                if fv == nil then
                    valStr = "nil"
                elseif type(fv) == "userdata" then
                    local okFull, full = pcall(function() return fv:GetFullName() end)
                    if okFull and full then
                        valStr = full
                    else
                        local okStr, s = pcall(function() return fv:ToString() end)
                        valStr = (okStr and s) and s or tostring(fv)
                    end
                else
                    valStr = tostring(fv)
                end
            end
            print(string.format("[LivingBase] [probe-struct]   %s.%s = %s\n", tag, pname, valStr))
        end)
    end)
end

-- dumpCustomizationMeshControllers(actor) -- TEMP DEV/PROBE TOOL (2026-08-19): RedFalcon asked
-- whether per-slot mesh controllers (GetCustomizationMeshControllers/
-- SetCustomizationMeshControllerValue, found via dumpCompositeFunctions) offer more granular
-- control than swapping a whole `params` DataAsset -- CONFIRMED YES, live: each controller is an
-- R5SelectableCompositeMeshController with MeshGroupIndex/CurValue/MaxValue/bSelectionAllowed/
-- GroupCategoryId. Also dumps GroupCategoryId (itself a struct) since it almost certainly
-- identifies WHICH body part a given MeshGroupIndex actually is -- one explicit extra level via
-- dumpUnknownStruct, not a general auto-drill.
local function dumpCustomizationMeshControllers(actor)
    if not (actor and actor:IsValid()) then return end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        print("[LivingBase] [probe-meshctrl] no CompositeMeshComponent on this actor.\n")
        return
    end
    local list = nil
    pcall(function() list = comp:GetCustomizationMeshControllers() end)
    if not list then
        print("[LivingBase] [probe-meshctrl] GetCustomizationMeshControllers() returned nothing.\n")
        return
    end
    local n = 0
    pcall(function() n = list:GetArrayNum() end)
    if n == 0 then pcall(function() n = #list end) end
    for i = 1, n do
        local ctrl = nil
        pcall(function() ctrl = list[i] end)
        if ctrl == nil then pcall(function() ctrl = list:Get(i) end) end
        pcall(function() if ctrl ~= nil and type(ctrl) == "userdata" and ctrl.get then ctrl = ctrl:get() end end)
        if ctrl then
            dumpUnknownStruct(ctrl, string.format("controller[%d]", i))
            local okCat, catId = pcall(function() return ctrl.GroupCategoryId end)
            if okCat and catId ~= nil then
                dumpUnknownStruct(catId, string.format("controller[%d].GroupCategoryId", i))
            end
        end
    end
    print(string.format("[LivingBase] [probe-meshctrl] %d customization mesh controller(s) total.\n", n))
end

-- dumpBuildedCompositeMeshes(actor) -- TEMP DEV/PROBE TOOL (2026-08-19): RedFalcon asked how the
-- Gatherer/Herbalist render visible clothes at all when Spawner.ScanNearbyCustomization proved
-- they have ZERO Armor.* controllers -- GetCustomizationMeshControllers only lists slots with
-- MULTIPLE author-provided options to pick between, so a piece with just one authored look would
-- never show up there even though it's still attached via the composite BUILD system (the same
-- params-DataAsset mechanism this mod's whole reskinning approach already drives). This file
-- already reads comp.BuildedCompositeMeshes in a few places (Spawner.ApplyBodySex/ApplyComposite/
-- ApplyBodyType) but ONLY ever as a count (:GetArrayNum()) -- never dumped element-by-element.
-- Element type CONFIRMED LIVE (2026-08-19, first real run on the Gatherer): each entry's
-- :GetFullName() returns "ScriptStruct /Script/R5.R5EquippedSlotData" -- the dumpNamedStruct shape
-- (a resolvable type path), NOT a plain UObject reference and NOT the "UScriptStruct: <hex>"
-- shape dumpUnknownStruct handles. First cut of this function treated a successful GetFullName()
-- as "good enough" and stopped there without drilling in -- that's exactly backwards for this
-- shape, where GetFullName only ever reports the TYPE, never the per-instance field values (same
-- trap probe-anim's own comment already documents for AnimationData). Fixed to detect the
-- "ScriptStruct %S+" pattern specifically and route it through dumpNamedStruct; a real object
-- path (GetFullName not matching that pattern) still prints directly, and dumpUnknownStruct
-- remains the final fallback for the other struct shape, in case a different actor's composite
-- ever holds something else in this array.
local function dumpBuildedCompositeMeshes(actor)
    if not (actor and actor:IsValid()) then return end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        print("[LivingBase] [probe-built] no CompositeMeshComponent on this actor.\n")
        return
    end
    local list = nil
    pcall(function() list = comp.BuildedCompositeMeshes end)
    if not list then
        print("[LivingBase] [probe-built] BuildedCompositeMeshes not readable on this actor.\n")
        return
    end
    local n = 0
    pcall(function() n = list:GetArrayNum() end)
    if n == 0 then pcall(function() n = #list end) end
    for i = 1, n do
        local el = nil
        pcall(function() el = list[i] end)
        if el == nil then pcall(function() el = list:Get(i) end) end
        pcall(function() if el ~= nil and type(el) == "userdata" and el.get then el = el:get() end end)
        if el then
            local tag = string.format("built[%d]", i)
            local okFull, full = pcall(function() return el:GetFullName() end)
            local structPath = okFull and full and full:match("^ScriptStruct%s+(%S+)")
            if structPath then
                print(string.format("[LivingBase] [probe-built] %s type: %s\n", tag, full))
                dumpNamedStruct(el, structPath, tag)
            elseif okFull then
                local okPath, path = pcall(function() return el:GetPathName() end)
                print(string.format("[LivingBase] [probe-built] %s: FullName=%s PathName=%s\n",
                    tag, full, okPath and path or "?"))
            else
                dumpUnknownStruct(el, tag)
            end
        end
    end
    print(string.format("[LivingBase] [probe-built] %d BuildedCompositeMeshes entr%s total.\n",
        n, n == 1 and "y" or "ies"))
end

-- dumpCustomizability(actor) -- TEMP DEV/PROBE TOOL (2026-08-13): the color-controller/ColorParams
-- routes are confirmed dead (see Spawner.SetColorControllers/ApplyColorParams's own removal
-- comments), but every attempt so far assumed the composite was EDITABLE and just wasn't
-- rendering. Never actually checked. R5CompositeMeshComponent exposes IsCharacterCustomizable(),
-- IsCustomizationEditActive(), IsBodyTypeChangeAvailable(), IsBodySexChangeAvailable() -- found via
-- the 2026-08-13 UE4SS_ObjectDump.txt refresh. If IsCharacterCustomizable() comes back false on an
-- AI-spawned pawn (the Gatherer being the live test case -- never seen to vary its look across
-- spawns), that's the actual reason color/tattoo never took: the composite is edit-locked for this
-- class entirely, independent of sequencing or which property gets set. Pure reads, no side
-- effects -- safe regardless of what they return.
local function dumpCustomizability(actor)
    if not (actor and actor:IsValid()) then return end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        print("[LivingBase] [probe-customizable] no CompositeMeshComponent on this actor.\n")
        return
    end
    local function callBool(name)
        local ok, val = pcall(function() return comp[name](comp) end)
        return ok and tostring(val) or "call FAILED"
    end
    print(string.format("[LivingBase] [probe-customizable] IsCharacterCustomizable=%s IsCustomizationEditActive=%s IsBodyTypeChangeAvailable=%s IsBodySexChangeAvailable=%s\n",
        callBool("IsCharacterCustomizable"), callBool("IsCustomizationEditActive"),
        callBool("IsBodyTypeChangeAvailable"), callBool("IsBodySexChangeAvailable")))
end

-- dumpAvailableBodyTypes(actor) -- TEMP DEV/PROBE TOOL (2026-08-15). RedFalcon asked whether a
-- SetCharacterSex-style dedicated FUNCTION might exist for body type too, the way it did for sex --
-- checked the actual UE4SS_ObjectDump.txt (the source SetCharacterSex/IsBodySexChangeAvailable
-- themselves were originally found in) for every function R5CompositeMeshComponent declares.
-- Real find: `SetBody(InBodyType: FGameplayTag, InBodySex: EBodySex, bForceLoad: bool)` -- a
-- COMPLETELY different mechanism from the confirmed-dead `ArchetypePreset` DataAsset property
-- (item 59): body type here is a GAMEPLAY TAG, not an asset reference, alongside matching getters
-- `GetBodyType()`/`GetAvailableBodyTypes(BodySexFilter)`. FGameplayTag is a one-field struct
-- (`TagName`, an FName) per the object dump -- safe to read via a single bracket index (no
-- multi-level struct-drilling needed, unlike AnimationData) and safe to WRITE as a plain
-- `{ TagName = "..." }` Lua table (same plain-table-for-simple-struct convention Spawner.WarpNear
-- already uses for FVector). This probe reads GetBodyType() (current) and GetAvailableBodyTypes()
-- (the full valid roster) so a real tag name can be used with Spawner.ApplyBodyType instead of
-- guessing one.
local function dumpAvailableBodyTypes(actor)
    if not (actor and actor:IsValid()) then return end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        print("[LivingBase] [probe-bodytype] no CompositeMeshComponent on this actor.\n")
        return
    end
    local function tagName(tag)
        local n = "?"
        pcall(function()
            local nm = tag["TagName"]
            if nm then n = nm:ToString() end
        end)
        return n
    end
    pcall(function()
        local cur = comp:GetBodyType()
        print("[LivingBase] [probe-bodytype] GetBodyType() = " .. tagName(cur) .. "\n")
    end)
    -- BodySexFilter: same EBodySex encoding as CharacterSex elsewhere in this file (1=Male,
    -- 2=Female) -- tries 0 too in case that means "no filter/any".
    for _, filterVal in ipairs({ 0, 1, 2 }) do
        pcall(function()
            local list = comp:GetAvailableBodyTypes(filterVal)
            local n = 0
            pcall(function() n = list:GetArrayNum() end)
            if n == 0 then pcall(function() n = #list end) end
            local names = {}
            for i = 1, n do
                local t = nil
                pcall(function() t = list[i] end)
                if t == nil then pcall(function() t = list:Get(i) end) end
                -- Bracket/Get-indexing a TArray in this build returns a RemoteUnrealParam WRAPPER,
                -- not the struct directly -- confirmed elsewhere in this file (see the strip
                -- component-array loop's own comment). Unwrap via :get() before reading TagName.
                if t then
                    local okUnwrap, unwrapped = pcall(function() return t:get() end)
                    if okUnwrap and unwrapped then t = unwrapped end
                end
                if t then names[#names + 1] = tagName(t) end
            end
            print(string.format("[LivingBase] [probe-bodytype] GetAvailableBodyTypes filter=%d: %d entries: %s\n",
                filterVal, n, table.concat(names, ", ")))
        end)
    end
end

-- dumpCompositeFunctions(actor) -- TEMP DEV/PROBE TOOL (2026-08-18): list EVERY function
-- R5CompositeMeshComponent declares (walking up GetSuperStruct(), same technique the now-removed
-- DumpNotificationFunctions used on a UMG widget class -- see CLAUDE.md item 22 -- just ForEachFunction
-- instead of dumpObjectProperties' ForEachProperty). Built to answer a specific open question:
-- IsBodySexChangeAvailable() has always read TRUE on every actor probed so far (2026-08-13/14), so
-- whether it's a computed/gated result or something with a matching SETTER (the way SetCharacterSex/
-- SetBody sit right next to their own getters) has never actually been checked -- this is that check,
-- live, on whatever's targeted, instead of manually grepping a fresh UE4SS_ObjectDump.txt by hand.
-- Read-only (calling ForEachFunction does not invoke anything), so no crash risk beyond what every
-- other reflective class walk in this file already carries (none observed so far).
local function dumpCompositeFunctions(actor)
    if not (actor and actor:IsValid()) then return end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        print("[LivingBase] [probe-funcs] no CompositeMeshComponent on this actor.\n")
        return
    end
    local cls
    pcall(function() cls = comp:GetClass() end)
    local total = 0
    while cls and cls:IsValid() do
        local className = "?"
        pcall(function() className = cls:GetFName():ToString() end)
        local names = {}
        pcall(function()
            cls:ForEachFunction(function(fn)
                local fname = "?"
                pcall(function() fname = fn:GetFName():ToString() end)
                names[#names + 1] = fname
            end)
        end)
        table.sort(names)
        total = total + #names
        print(string.format("[LivingBase] [probe-funcs] -- %s (%d functions) --\n", className, #names))
        print("[LivingBase] [probe-funcs]   " .. table.concat(names, ", ") .. "\n")
        local nextCls
        pcall(function() nextCls = cls:GetSuperStruct() end)
        cls = nextCls
    end
    print(string.format("[LivingBase] [probe-funcs] %d functions total across the class hierarchy.\n", total))
end

-- dumpArchetypeInfo(actor) -- TEMP DEV/PROBE TOOL (2026-08-10): pursuing the NPC-side tattoo
-- system instead of the PLAYER-only composite-params route (CONFIRMED to crash the game, see
-- Config.TATTOO_TEST_PARAMS' own comment -- do not revisit that path). The game's own manifest
-- shows a separate NPC PresetGroup system (DA_NPC_Common_PresetGroup_Tattoo<Region>, one option
-- of which is explicitly "TattooNONE") and per-archetype SubPresets (e.g. Blackbeard crew,
-- ShipCrew Officer/Sailor each have their own SubPreset_Tattoo<Region> assets) -- strongly
-- suggesting tattoos are just PART of which ArchetypePreset an NPC happens to roll, not a
-- separate toggle. First step: read which ArchetypePreset our walker is CURRENTLY using (a
-- single direct property read, not a reflective class walk -- same safe pattern as
-- dumpColorControllers, no crash risk) -- across a few spawns this should reveal whether her
-- pool has any variety at all, and give a real name to go look up rather than guessing blind.
-- Also speculatively tries a few plausible property names for a DIRECT tattoo-preset reference on
-- the composite component itself, in case one exists separately from ArchetypePreset -- each is
-- just a pcall'd property read (fails silently and safely if the name doesn't exist, unlike
-- calling an unknown FUNCTION with side effects).
-- readObjProp(holder, propName, tag) -- single direct property read (NOT a reflective class
-- walk), pcall'd, safe against a nonexistent property (fails quietly) the same way every other
-- probe this session does. Returns the resolved UObject (or nil) so a caller can drill one level
-- further with it, same pattern used to go from the actor -> CompositeMeshComponent ->
-- ArchetypePreset below.
local function readObjProp(holder, propName, tag)
    if not (holder and holder:IsValid()) then return nil end
    local ok, val = pcall(function() return holder[propName] end)
    if not ok or val == nil then
        print(string.format("[LivingBase] [probe-arch] %s.%s: nil/not accessible.\n", tag, propName))
        return nil
    end
    local okValid, isValid = pcall(function() return val:IsValid() end)
    if not (okValid and isValid) then
        print(string.format("[LivingBase] [probe-arch] %s.%s: (invalid/none)\n", tag, propName))
        return nil
    end
    local full = "?"
    pcall(function() full = val:GetFullName() end)
    print(string.format("[LivingBase] [probe-arch] %s.%s: %s\n", tag, propName, full))
    return val
end

local function dumpArchetypeInfo(actor)
    if not (actor and actor:IsValid()) then return end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        print("[LivingBase] [probe-arch] no CompositeMeshComponent on this actor.\n")
        return
    end
    local archetype = readObjProp(comp, "ArchetypePreset", "comp")
    readObjProp(comp, "DefaultParams", "comp")
    -- Speculative -- no confirmed evidence these exist, purely guessed from the manifest's own
    -- naming (PresetGroup_Tattoo<Region>, SubPreset_Tattoo<Region>). Safe to try regardless.
    readObjProp(comp, "TattooPreset", "comp")
    readObjProp(comp, "SkinDecorPreset", "comp")
    readObjProp(comp, "TattooChest", "comp")
    readObjProp(comp, "TattooPresetGroup", "comp")
    -- ArchetypePreset came back FIXED (always PresetArchetype1, no variety) across every probe
    -- this session -- so if she ever gets a tattoo, it's not from her archetype re-rolling. Still
    -- worth checking whether HER SPECIFIC archetype references a tattoo sub-preset directly (drill
    -- one level into the DataAsset itself, same guessed-name/safe-read approach).
    if archetype then
        readObjProp(archetype, "TattooChest", "archetype")
        readObjProp(archetype, "TattooPreset", "archetype")
        readObjProp(archetype, "SkinDecor", "archetype")
        readObjProp(archetype, "Tattoos", "archetype")
    end
end

-- dumpMaterialParameters(actor) -- TEMP DEV/PROBE TOOL (2026-08-10): DumpColorControllers came
-- back clean across 6 probes (both our own composite walker and a genuine original static NPC,
-- Letty) -- 19 controllers, all garment/hair color palettes, nothing tattoo-related. Next place to
-- look: the body's own material (the MaterialInstanceConstant on comp[CharacterMesh0]/actor.Mesh,
-- e.g. MI_Adventurer_Female_Medium) might carry a "TattooMask"/"BodyArt"-style scalar or texture
-- parameter. DELIBERATELY does NOT walk the material's class via ForEachProperty/ForEachFunction
-- -- Spawner.ProbeDumpProperties' own comment documents a REAL crash from reflectively walking a
-- DIFFERENT nested component's property list (R5CommonInteractionTargetComponent, 2026-08-07) --
-- so this only ever does DIRECT, single, pcall'd property reads (mat.ScalarParameterValues /
-- mat.TextureParameterValues), the same lower-risk pattern already used safely all session for
-- SkeletalMesh/GetMaterial, never a reflective class-level walk on the material itself.
-- BUG FIX (2026-08-10): hardcoded GetMaterial(0) grabbed MI_Eye, not the skin material -- every
-- probe-mesh dump this session shows material slot order Eye(0), Pirate_Mouth(1),
-- Adventurer_Female_*(2, the actual skin), Hair(3) on this body. Rather than hardcode a "correct"
-- index that might not hold on every pawn, this now walks EVERY material slot via GetNumMaterials
-- and dumps each one's parameters, so the skin material (whatever its index) is never missed.
-- EXTENDED (2026-08-21, RedFalcon: chasing the native "crop turns blue" / "chest brightens when
-- faced" highlight effect) -- this only ever read actor.Mesh (a SkeletalMeshComponent-specific
-- property name), so it silently no-op'd ("no actor.Mesh") on any STATIC-mesh-based actor -- which
-- a crop plant or a treasure chest almost certainly is. Now walks StaticMeshComponent AND
-- SkeletalMeshComponent generically too, same K2_GetComponentsByClass sweep pattern
-- applyHoverHighlight already uses safely, so this works on either kind of actor.
local function dumpMatsOnMeshComponent(mesh, tag)
    if not (mesh and mesh:IsValid()) then return end
    local nMats = 0
    pcall(function() nMats = mesh:GetNumMaterials() end)
    if nMats == 0 then
        print(string.format("[LivingBase] [probe-mat] %s: GetNumMaterials() returned 0.\n", tag))
        return
    end
    for slot = 0, (nMats - 1) do
        local mat = nil
        pcall(function() mat = mesh:GetMaterial(slot) end)
        if mat and mat:IsValid() then
            local matName = "?"
            pcall(function() matName = mat:GetFName():ToString() end)
            print(string.format("[LivingBase] [probe-mat] slot[%d] material: %s\n", slot, matName))
            local function dumpArray(propName)
                local ok, arr = pcall(function() return mat[propName] end)
                if not (ok and arr) then
                    print(string.format("[LivingBase] [probe-mat]   %s: not accessible this way.\n", propName))
                    return
                end
                local n = 0
                pcall(function() n = arr:GetArrayNum() end)
                if n == 0 then pcall(function() n = #arr end) end
                print(string.format("[LivingBase] [probe-mat]   %s: %d entries.\n", propName, n))
                for i = 1, n do
                    local item = nil
                    pcall(function() item = arr[i] end)
                    if item == nil then pcall(function() item = arr:Get(i) end) end
                    if item then
                        local pname, pval = "?", "?"
                        pcall(function() pname = item.ParameterInfo.Name:ToString() end)
                        -- BUG FIX (2026-08-10): tostring() on a texture/object value just printed a
                        -- raw pointer address, useless for identifying WHICH texture is assigned.
                        -- Resolve it properly: if it's a UObject, get its actual asset name/full
                        -- path (same pattern used everywhere else this session for mesh/material
                        -- names); only fall back to tostring for a genuinely plain scalar value.
                        local okv, rawVal = pcall(function() return item.ParameterValue end)
                        if okv and rawVal ~= nil and type(rawVal) == "userdata" then
                            local okIsValid, isValid = pcall(function() return rawVal:IsValid() end)
                            if okIsValid and isValid then
                                local full = "?"
                                pcall(function() full = rawVal:GetFullName() end)
                                pval = full
                            else
                                pval = "(invalid/none)"
                            end
                        elseif okv then
                            pval = tostring(rawVal)
                        end
                        print(string.format("[LivingBase] [probe-mat]     [%d] name='%s' value=%s\n", i, pname, pval))
                    end
                end
            end
            dumpArray("ScalarParameterValues")
            dumpArray("TextureParameterValues")
            dumpArray("VectorParameterValues")
            -- STATIC SWITCH PARAMETERS (2026-08-10): a compile-time bool baked into the material
            -- permutation -- a genuinely different property shape than the three arrays above
            -- (FStaticSwitchParameter has a `Value` field, not `ParameterValue`, and it lives
            -- nested inside a StaticParameters STRUCT, not as a top-level array on the material).
            -- Tried after two clean negative results on BodyDecor/mesh-components: a confirmed-
            -- tattooed statue showed byte-identical texture params and component lists to a
            -- non-tattooed one, so whatever toggles the tattoo isn't either of those -- a static
            -- switch is the next most plausible mechanism for an on/off visual change with no
            -- texture/mesh difference. Still just direct pcall'd property reads, no reflective
            -- class walk, so still safe even if the property path turns out wrong.
            local okSP, staticParams = pcall(function() return mat.StaticParameters end)
            if okSP and staticParams then
                local okSW, switches = pcall(function() return staticParams.StaticSwitchParameters end)
                if okSW and switches then
                    local n = 0
                    pcall(function() n = switches:GetArrayNum() end)
                    if n == 0 then pcall(function() n = #switches end) end
                    print(string.format("[LivingBase] [probe-mat]   StaticSwitchParameters: %d entries.\n", n))
                    for i = 1, n do
                        local item = nil
                        pcall(function() item = switches[i] end)
                        if item == nil then pcall(function() item = switches:Get(i) end) end
                        if item then
                            local pname, pval = "?", "?"
                            pcall(function() pname = item.ParameterInfo.Name:ToString() end)
                            pcall(function() pval = tostring(item.Value) end)
                            print(string.format("[LivingBase] [probe-mat]     [%d] name='%s' value=%s\n", i, pname, pval))
                        end
                    end
                else
                    print("[LivingBase] [probe-mat]   StaticSwitchParameters: not accessible this way.\n")
                end
            else
                print("[LivingBase] [probe-mat]   StaticParameters: not accessible this way.\n")
            end
        end
    end
end

local function dumpMaterialParameters(actor)
    if not (actor and actor:IsValid()) then return end
    local found = 0
    local mesh = nil
    pcall(function() mesh = actor.Mesh end)
    if mesh and mesh:IsValid() then
        found = found + 1
        dumpMatsOnMeshComponent(mesh, "actor.Mesh")
    end
    for _, className in ipairs({ "StaticMeshComponent", "SkeletalMeshComponent" }) do
        local cls = StaticFindObject("/Script/Engine." .. className)
        if cls and cls:IsValid() then
            local comps
            local ok = pcall(function() comps = actor:K2_GetComponentsByClass(cls) end)
            if ok and comps then
                local n = 0
                pcall(function() n = comps:GetArrayNum() end)
                if n == 0 then pcall(function() n = #comps end) end
                for i = 1, n do
                    local comp
                    pcall(function() comp = comps[i] end)
                    if not comp then pcall(function() comp = comps:Get(i) end) end
                    pcall(function() if comp ~= nil and type(comp) == "userdata" and comp.get then comp = comp:get() end end)
                    -- actor.Mesh, if it exists, is ALSO one of the SkeletalMeshComponents this sweep
                    -- would return -- skip re-dumping the same physical component twice.
                    if comp and comp:IsValid() and comp ~= mesh then
                        found = found + 1
                        local compName = "?"
                        pcall(function() compName = comp:GetFName():ToString() end)
                        dumpMatsOnMeshComponent(comp, className .. ":" .. compName)
                    end
                end
            end
        end
    end
    if found == 0 then
        print("[LivingBase] [probe-mat] no StaticMeshComponent/SkeletalMeshComponent/actor.Mesh found on this actor.\n")
    end
end

-- Spawner.NudgeComponentTransform(actor, pattern, scaleMul, offsetZ) -- EXPERIMENTAL
-- (2026-08-10): the Senkamati Legs armor piece attaches fine (confirmed via probe) but leaves
-- a real, persistent see-through gap at the pelvis on the human re-skin bases -- proven NOT a
-- settle-timing issue (waited it out, still there) and NOT fixable by swapping which mesh
-- occupies that slot alone (a proper human garment there closes it, but looks visually
-- out-of-place next to the tribal armor -- see Config.DECORRUPT_CREW's own note). Working
-- theory: this piece was originally skinned/fitted for the SenkamatiCorrupted mob's own
-- proportions, not this human skeleton, so it may be undersized/offset relative to where the
-- human body actually needs coverage. This scales and/or nudges the WHOLE component (its own
-- transform, not per-bone) to see if that closes the visual gap without changing which mesh is
-- used. UNCERTAIN whether this works at all: a leader-pose-bound skinned mesh's vertices follow
-- the LEADER's animated bone transforms, not just this component's own transform, so a uniform
-- scale/offset might close the gap cleanly, or might look stretched/detached instead -- this is
-- a live visual judgment call the user has to make, not something provable from a log line.
-- Runs AFTER the composite settles (called from senkaCrewFix's own retry loop, same timing as
-- the hide/replace pass), matching `pattern` against each component's current mesh name.
function Spawner.NudgeComponentTransform(actor, pattern, scaleMul, offsetZ)
    if not (actor and actor:IsValid()) or not pattern then return 0 end
    scaleMul = scaleMul or 1.0
    offsetZ = offsetZ or 0.0
    if scaleMul == 1.0 and offsetZ == 0.0 then return 0 end   -- no-op, don't touch anything
    local touched = 0
    local cls = StaticFindObject("/Script/Engine.SkeletalMeshComponent")
    if not (cls and cls:IsValid()) then return 0 end
    local comps
    pcall(function() comps = actor:K2_GetComponentsByClass(cls) end)
    if not comps then return 0 end
    local n = 0
    pcall(function() n = comps:GetArrayNum() end)
    if n == 0 then pcall(function() n = #comps end) end
    for i = 1, n do
        local c = nil
        pcall(function() c = comps[i] end)
        if c == nil then pcall(function() c = comps:Get(i) end) end
        pcall(function() if c ~= nil and type(c) == "userdata" and c.get then c = c:get() end end)
        if c and c:IsValid() then
            local meshName = ""
            pcall(function()
                local sk = c.SkeletalMesh
                if not (sk and sk:IsValid()) and c.GetSkeletalMeshAsset then sk = c:GetSkeletalMeshAsset() end
                if sk and sk:IsValid() then meshName = sk:GetFName():ToString() end
            end)
            if meshName ~= "" and meshName:find(pattern) then
                local okS = pcall(function()
                    c:SetRelativeScale3D({ X = scaleMul, Y = scaleMul, Z = scaleMul })
                end)
                local okO = true
                if offsetZ ~= 0.0 then
                    okO = pcall(function()
                        local loc = c:K2_GetRelativeLocation()
                        c:K2_SetRelativeLocation({ X = loc.X, Y = loc.Y, Z = loc.Z + offsetZ }, false, nil, false)
                    end)
                end
                touched = touched + 1
                print(string.format(
                    "[LivingBase] [nudge] comp mesh=%s scale=%s(%s) offsetZ=%s(%s)\n",
                    meshName, tostring(scaleMul), okS and "ok" or "FAILED",
                    tostring(offsetZ), okO and "ok" or "FAILED"))
            end
        end
    end
    return touched
end

function Spawner.ProbeDumpProperties()
    print("[LivingBase] [probe-props] key received.\n")
    local target = Spawner._lastProbedActor
    if not (target and target:IsValid()) then
        print("[LivingBase] [probe-props] no valid probed target -- run lbprobe on something first.\n")
        return
    end
    pcall(function() dumpObjectProperties(target, "TARGET") end)
    -- COMPOSITE (2026-08-19): dumpObjectProperties is generic (any object + a tag) but every prior
    -- call here only ever pointed it at the ACTOR -- CompositeMeshComponent's OWN declared
    -- properties (e.g. CustomizationRecordID, the backing field OnRep_CustomizationRecordID reacts
    -- to -- see dumpCompositeFunctions's LoadCharacterDataFromDB lead) were never actually dumped.
    -- Reuses the same function, just pointed at comp instead of target.
    pcall(function()
        local comp = nil
        pcall(function() comp = target.CompositeMeshComponent end)
        if comp and comp:IsValid() then
            dumpObjectProperties(comp, "COMPOSITE")
            -- CustomizationRecordID (2026-08-19) is a ScriptStruct (R5BLRecordId), so
            -- dumpObjectProperties above only shows its TYPE, not its actual field values --
            -- plain dot-access into an unknown struct field is a real crash risk in this codebase
            -- (see WINDROSE_MODDING_NOTES.md #10), so drill it the SAME safe way that finding
            -- required: resolve the struct's own UScriptStruct type, ForEachProperty over THAT to
            -- discover its real field names, then bracket-index the struct VALUE for each. This is
            -- narrowly scoped to this one known struct -- NOT the same as the auto-drill-into-nested-
            -- OBJECTS technique removed 2026-08-07 for crashing on a live component; a plain data
            -- struct is a different, lower-risk case this file already reads safely elsewhere
            -- (Vector .X/.Y/.Z). Still pcall'd throughout since pcall cannot catch a native crash.
            pcall(function()
                local recId = comp.CustomizationRecordID
                if recId == nil then
                    print("[LivingBase] [probe-props] CustomizationRecordID is nil.\n")
                    return
                end
                local structType = nil
                pcall(function() structType = StaticFindObject("/Script/R5BLCommon.R5BLRecordId") end)
                if not (structType and structType:IsValid()) then
                    print("[LivingBase] [probe-props] could not resolve R5BLRecordId struct type.\n")
                    return
                end
                pcall(function()
                    structType:ForEachProperty(function(prop)
                        local fname = "?"
                        pcall(function() fname = prop:GetFName():ToString() end)
                        local valStr = "<unreadable>"
                        local okv, val = pcall(function() return recId[fname] end)
                        if okv then
                            -- FString: 2026-08-19, plain tostring() on the userdata only shows the
                            -- wrapper's identity, not its text -- needs :ToString() called explicitly,
                            -- same as FName elsewhere in this file (prop:GetFName():ToString()).
                            local okStr, asStr = pcall(function() return val:ToString() end)
                            valStr = (okStr and asStr) and asStr or tostring(val)
                        end
                        print(string.format("[LivingBase] [probe-props] CustomizationRecordID.%s = %s\n", fname, valStr))
                    end)
                end)
            end)
        end
    end)
    pcall(function() dumpMeshComponentNames(target) end)
    pcall(function() dumpColorControllers(target) end)
    pcall(function() dumpCustomizationMeshControllers(target) end)
    pcall(function() dumpBuildedCompositeMeshes(target) end)
    pcall(function() dumpMaterialParameters(target) end)
    pcall(function() dumpArchetypeInfo(target) end)
    pcall(function() dumpCustomizability(target) end)
    pcall(function() dumpAvailableBodyTypes(target) end)
    pcall(function() dumpCompositeFunctions(target) end)
    pcall(function() dumpAnimInfo(target) end)
    print("[LivingBase] [probe-props] done.\n")
end

-- Spawner.ProbeCameraRig(say) -- TEMP DEV TOOL (2026-08-20, RedFalcon: native build mode raises/
-- pulls back the camera for a better view; screenshots confirmed it -- wants to reproduce that while
-- placing/relocating). Deliberately does NOT go anywhere near ConstructionContext/R5BuildingBrush --
-- see Spawner.ProbeBuildAbility's own comment for why a reflective walk of THOSE specific objects
-- crashed the game twice already. This targets a completely different, standard-engine object
-- instead: the player pawn's own SpringArmComponent (every UE third-person camera rig has one), via
-- the SAME typed GetComponentsByClass(KNOWN class) pattern Spawner.MakeMovable/ApplyGhostMaterial
-- already use safely -- a targeted lookup for ONE specific engine class, not the generic
-- ActorComponent-base sweep that's the actual documented crash (see dumpMeshComponentNames' own
-- comment, a few hundred lines up, for that one). Reads only SocketOffset/TargetArmLength by name
-- (known SpringArmComponent fields), not a reflective property walk. Run once normally, then again
-- while actually holding the hammer in real build mode, and diff the two -- gives the EXACT native
-- offset instead of guessing one from screenshots.
function Spawner.ProbeCameraRig(say)
    say = say or print
    local pc, pawn, cam
    pcall(function()
        pc = UEHelpers.GetPlayerController()
        pawn = pc and pc:IsValid() and pc.Pawn
        cam = pc and pc:IsValid() and pc.PlayerCameraManager
    end)
    if not (pawn and pawn:IsValid()) then
        say("[LivingBase] [probecam] no player pawn.\n")
        return
    end
    -- CONFIRMED LIVE (2026-08-20): the spring arm's own SocketOffset/TargetArmLength read IDENTICAL
    -- in and out of real build mode -- whatever raises/pulls back the camera isn't touching the arm's
    -- own config at all, so it must be happening downstream (a camera modifier, FOV change, or a
    -- separate view-target blend). Reading the ACTUAL computed camera pose here too (what
    -- PlayerCameraManager reports, same GetCameraLocation/GetCameraRotation calls the follow loop
    -- already uses elsewhere in this file) -- also pawn-relative deltas, so the numbers are usable
    -- directly as a follow-loop offset regardless of where you're standing when you probe.
    local pawnLoc
    pcall(function() pawnLoc = pawn:K2_GetActorLocation() end)
    if pawnLoc then
        say(string.format("[LivingBase] [probecam] PawnLocation=(%.1f, %.1f, %.1f)\n", pawnLoc.X, pawnLoc.Y, pawnLoc.Z))
    end
    if cam and cam:IsValid() then
        local camLoc, camRot, fov
        pcall(function() camLoc = cam:GetCameraLocation() end)
        pcall(function() camRot = cam:GetCameraRotation() end)
        pcall(function() fov = cam:GetFOVAngle() end)
        if not fov then pcall(function() fov = cam.FOVAngle end) end
        if camLoc then
            say(string.format("[LivingBase] [probecam] CameraLocation=(%.1f, %.1f, %.1f)\n", camLoc.X, camLoc.Y, camLoc.Z))
            if pawnLoc then
                say(string.format("[LivingBase] [probecam] CameraMinusPawn=(dX=%.1f, dY=%.1f, dZ=%.1f)\n",
                    camLoc.X - pawnLoc.X, camLoc.Y - pawnLoc.Y, camLoc.Z - pawnLoc.Z))
            end
        end
        if camRot then say(string.format("[LivingBase] [probecam] CameraRotation=(Pitch=%.1f, Yaw=%.1f, Roll=%.1f)\n", camRot.Pitch, camRot.Yaw, camRot.Roll)) end
        if fov then say(string.format("[LivingBase] [probecam] FOV=%.2f\n", fov)) end
    else
        say("[LivingBase] [probecam] no PlayerCameraManager.\n")
    end
    local springArmClass = StaticFindObject("/Script/Engine.SpringArmComponent")
    if not (springArmClass and springArmClass:IsValid()) then
        say("[LivingBase] [probecam] SpringArmComponent class not found via StaticFindObject.\n")
        return
    end
    local comps
    pcall(function() comps = pawn:GetComponentsByClass(springArmClass) end)
    if not comps then pcall(function() comps = pawn:K2_GetComponentsByClass(springArmClass) end) end
    local n = 0
    pcall(function() n = comps and (comps.GetArrayNum and comps:GetArrayNum() or #comps) or 0 end)
    if n == 0 then
        say("[LivingBase] [probecam] no SpringArmComponent found on the pawn.\n")
        return
    end
    say(string.format("[LivingBase] [probecam] %d SpringArmComponent(s) found:\n", n))
    for i = 1, n do
        local c = comps[i]
        pcall(function() if c ~= nil and type(c) == "userdata" and c.get then c = c:get() end end)
        if c and c:IsValid() then
            local cls = "?"
            pcall(function() cls = c:GetClass():GetFullName() end)
            local so, tal
            pcall(function() so = c.SocketOffset end)
            pcall(function() tal = c.TargetArmLength end)
            say(string.format("[LivingBase] [probecam] #%d class=%s TargetArmLength=%s SocketOffset=(%s, %s, %s)\n",
                i, tostring(cls), tostring(tal),
                so and tostring(so.X) or "?", so and tostring(so.Y) or "?", so and tostring(so.Z) or "?"))
            local wloc, wrot
            pcall(function() wloc = c:K2_GetComponentLocation() end)
            pcall(function() wrot = c:K2_GetComponentRotation() end)
            if wloc then say(string.format("[LivingBase] [probecam]    WorldLocation=(%.1f, %.1f, %.1f)\n", wloc.X, wloc.Y, wloc.Z)) end
            if wrot then say(string.format("[LivingBase] [probecam]    WorldRotation=(Pitch=%.1f, Yaw=%.1f, Roll=%.1f)\n", wrot.Pitch, wrot.Yaw, wrot.Roll)) end
        end
    end
end

-- Spawner.ProbeBuildAbility() -- TEMP DEV TOOL (2026-08-19, build-ghost-preview feasibility spike):
-- lbprobe/lbprobedump aim via the camera+cone sweep over FindAllOf("Actor"), which -- CONFIRMED
-- LIVE -- lands on GCA_BuildingCreate_C (a GameplayCueNotify_Actor, the one-shot "place" VFX/SFX
-- cue), not the actual translucent ghost mesh that follows the reticle while still choosing a
-- spot. That dump DID surface the real object graph though: BP_R5PlayerState_C holds an
-- R5Ability_Building_MakeConstructCommand ability, which holds a ConstructionContext
-- (R5BuildingConstructionContext) -- almost certainly where the live ghost actor/component and its
-- valid/invalid materials actually live. Go straight at the ability by CLASS via FindAllOf instead
-- of camera-sweeping for it (it's not necessarily a camera-visible Actor at all), then walk both it
-- and its ConstructionContext with the same generic dumpObjectProperties this file already uses.
-- Only meaningful while actively in build mode with a piece selected -- the ability instance may
-- not exist (or its ConstructionContext may be empty) otherwise. Remove once the real ghost
-- actor/material is identified -- same throwaway status as lbtickspike in main.lua.
function Spawner.ProbeBuildAbility()
    print("[LivingBase] [probe-buildctx] key received.\n")
    local list
    local ok = pcall(function() list = FindAllOf("R5Ability_Building_MakeConstructCommand") end)
    if not ok or not list or #list == 0 then
        print("[LivingBase] [probe-buildctx] no R5Ability_Building_MakeConstructCommand instance found -- are you actively in build mode with a piece selected?\n")
        return
    end
    local ability = list[1]
    if not (ability and ability:IsValid()) then
        print("[LivingBase] [probe-buildctx] found an entry but it's not valid.\n")
        return
    end
    pcall(function() dumpObjectProperties(ability, "BUILD_ABILITY") end)
    local context
    pcall(function() context = ability.ConstructionContext end)
    if not (context and context:IsValid()) then
        print("[LivingBase] [probe-buildctx] ConstructionContext is nil/invalid on this ability instance.\n")
        print("[LivingBase] [probe-buildctx] done.\n")
        return
    end
    pcall(function() dumpObjectProperties(context, "CONSTRUCTION_CONTEXT") end)

    -- STOP HERE. context.Brush (an R5BuildingBrush) is named in the CONSTRUCTION_CONTEXT dump
    -- above -- CONFIRMED LIVE (2026-08-19) that calling dumpObjectProperties(brush, ...) to walk
    -- ITS OWN properties crashes the game (pcall does NOT catch it -- native crash, not a Lua
    -- error): the log's last line both times was dumpObjectProperties' own "-- BRUSH: from
    -- R5BuildingBrush --" header, immediately followed by a crash dump ~1ms later, i.e. it died on
    -- the very first property read inside R5BuildingBrush's own ForEachProperty walk (not the
    -- inherited base-class properties -- those are walked AFTER the leaf class, never reached).
    -- Matches the crash class ProbeDumpProperties' own comment already documents ("a REAL crash
    -- from reflectively walking a live component") -- R5BuildingBrush is apparently another one.
    -- Do NOT re-add a generic dumpObjectProperties(brush, ...) or any method call on brush (e.g.
    -- K2_GetComponentsByClass) without a safer, one-property-at-a-time approach first (see this
    -- function's TEMP DEV TOOL header comment for the plan).
    print("[LivingBase] [probe-buildctx] done.\n")
end

-- Spawner.ApplyGhostMaterial() -- TEMP DEV TOOL (2026-08-19, build-ghost-preview spike, 3rd pass):
-- RedFalcon's design call -- the real feature doesn't need collision/stability logic, just a clear
-- "where is it" look while placing, and Windrose's own build-ghost material has a handy glow-in-
-- the-dark on top of that, so worth reusing it as-is rather than hunting down its parameters.
-- MI_Building_SimplifiedPreview (R5/Content/Environment/Gameplay/GDKit/Meshes/Building/, found via
-- the exported pak content list -- ue4ss.log's live probe never actually reached it, that path
-- crashed on R5BuildingBrush's own property walk before getting this far) is the candidate.
-- Deliberately does NOT touch R5Ability_Building_MakeConstructCommand/ConstructionContext/Brush at
-- all -- that reflective walk crashed the game twice already today. This only touches an actor WE
-- spawned (via lbspawn/lblook, then lbprobe to select it), using the exact same resolveAsset() +
-- SetMaterial() pattern Spawner.DeCorrupt's swaps already use safely on live actors.
function Spawner.ApplyGhostMaterial()
    print("[LivingBase] [probe-ghostmat] key received.\n")
    local actor = Spawner._lastProbedActor
    if not (actor and actor:IsValid()) then
        print("[LivingBase] [probe-ghostmat] no valid probed target -- run lbprobe on something first.\n")
        return
    end
    local GHOST_MAT_PATH = "/Game/Environment/Gameplay/GDKit/Meshes/Building/MI_Building_SimplifiedPreview.MI_Building_SimplifiedPreview"
    local mat = resolveAsset(GHOST_MAT_PATH)
    if not (mat and mat:IsValid()) then
        print("[LivingBase] [probe-ghostmat] could not resolve " .. GHOST_MAT_PATH .. " -- wrong path, or this piece isn't in a loaded pak.\n")
        return
    end
    local touched = 0
    local function applyTo(comp)
        -- K2_GetComponentsByClass's array can hand back a RemoteUnrealParam wrapper rather than
        -- the component directly -- CONFIRMED LIVE (2026-08-19): every call here failed with
        -- "attempt to call a RemoteUnrealParam value (method 'IsValid')" until unwrapped, same fix
        -- dumpMeshComponentNames already uses a few hundred lines up in this file.
        pcall(function() if comp ~= nil and type(comp) == "userdata" and comp.get then comp = comp:get() end end)
        if not (comp and comp:IsValid()) then return end
        local n = 0
        pcall(function() n = comp:GetNumMaterials() end)
        for slot = 0, (n - 1) do
            local ok = pcall(function() comp:SetMaterial(slot, mat) end)
            if ok then touched = touched + 1 end
        end
    end
    pcall(function() applyTo(actor.Mesh) end)
    for _, className in ipairs({ "StaticMeshComponent", "SkeletalMeshComponent" }) do
        local cls = StaticFindObject("/Script/Engine." .. className)
        if cls and cls:IsValid() then
            local comps
            local ok = pcall(function() comps = actor:K2_GetComponentsByClass(cls) end)
            if ok and comps then
                local n = 0
                pcall(function() n = comps:GetArrayNum() end)
                if n == 0 then pcall(function() n = #comps end) end
                for i = 1, n do
                    local comp
                    pcall(function() comp = comps[i] end)
                    if not comp then pcall(function() comp = comps:Get(i) end) end
                    applyTo(comp)
                end
            end
        end
    end
    print(string.format("[LivingBase] [probe-ghostmat] applied to %d material slot(s).\n", touched))
end

-- Spawner.ApplyGhostMaterialSolid() -- TEMP DEV TOOL (2026-08-19, build-ghost-preview spike, 4th
-- pass): Spawner.ApplyGhostMaterial (above) applies MI_Building_SimplifiedPreview AS-IS, which
-- FModel's own property export shows has 4 color params (AltColor/MaxStabilityColor/
-- MinStabilityColor/InstabilityColor) blended by some hidden per-instance "stability" value this
-- codebase never feeds it -- CONFIRMED LIVE that produces inconsistent colors per object (glowing
-- white skin, yellow/orange decor) since whatever drives the blend is uninitialized garbage on
-- objects the real building system never touches. Fix: don't fight the hidden driver -- make it
-- irrelevant. Create a per-slot MaterialInstanceDynamic and force ALL FOUR color params to the
-- SAME value; whatever the blend factor is, interpolating/selecting among four identical colors
-- always yields that color. Keeps the real asset (glow-in-the-dark, fresnel/rim shape definition
-- RedFalcon confirmed from an actual in-game screenshot -- "velvety", not flat, even though the
-- material is Unlit) without needing to know or reverse-engineer what feeds the stability blend.
-- CreateDynamicMaterialInstance/SetVectorParameterValue are UNPROVEN in this codebase (nothing
-- here has called them before) -- pcall'd throughout like everything else, but treat a FAILED
-- result as genuinely uninformative about the FLinearColor table shape, not just "retry it."
function Spawner.ApplyGhostMaterialSolid()
    print("[LivingBase] [probe-ghostmat2] key received.\n")
    -- DISABLED (2026-08-19) -- CONFIRMED LIVE: comp:CreateDynamicMaterialInstance(slot, mat, "")
    -- crashes the game natively (pcall does NOT catch it) on the very first call, every time --
    -- two crashes total from this function tonight (the first from a missing 3rd argument, a clean
    -- Lua error; this one from passing "" as that argument, no longer a clean error at all). Do NOT
    -- re-enable by just deleting this early return without trying a genuinely different argument
    -- form first (e.g. nil instead of "", or omitting the 3rd arg entirely if a differently-typed
    -- overload exists) -- two crashes is enough blind live iteration on one native call for one
    -- night. lbghosttest (Spawner.ApplyGhostMaterial, plain SetMaterial, no dynamic instance) is
    -- still the proven-safe fallback.
    print("[LivingBase] [probe-ghostmat2] DISABLED -- CreateDynamicMaterialInstance crashed twice tonight. Use lbghosttest instead.\n")
    return
    --[[ DISABLED BELOW -- kept as reference for whoever re-attempts this, not live code.
    local actor = Spawner._lastProbedActor
    if not (actor and actor:IsValid()) then
        print("[LivingBase] [probe-ghostmat2] no valid probed target -- run lbprobe on something first.\n")
        return
    end
    local GHOST_MAT_PATH = "/Game/Environment/Gameplay/GDKit/Meshes/Building/MI_Building_SimplifiedPreview.MI_Building_SimplifiedPreview"
    local mat = resolveAsset(GHOST_MAT_PATH)
    if not (mat and mat:IsValid()) then
        print("[LivingBase] [probe-ghostmat2] could not resolve " .. GHOST_MAT_PATH .. " -- wrong path, or this piece isn't in a loaded pak.\n")
        return
    end
    -- Bright cyan/blue, roughly matching the ~3.0-magnitude overbright scale FModel showed on
    -- InstabilityColor/MaxStabilityColor -- deliberately NOT red/green/orange so it reads as "our
    -- tool," not a native valid/invalid/stability state.
    local GHOST_COLOR = { R = 0.3, G = 1.5, B = 3.0, A = 1.0 }
    local PARAM_NAMES = { "AltColor", "MaxStabilityColor", "MinStabilityColor", "InstabilityColor" }
    local touched, paramsSet = 0, 0
    local function applyTo(comp)
        pcall(function() if comp ~= nil and type(comp) == "userdata" and comp.get then comp = comp:get() end end)
        if not (comp and comp:IsValid()) then return end
        local n = 0
        pcall(function() n = comp:GetNumMaterials() end)
        for slot = 0, (n - 1) do
            local dyn
            -- CONFIRMED LIVE (2026-08-19): UE4SS's Lua binding does NOT apply this UFUNCTION's C++
            -- default for OptionalName (NAME_None) -- "UFunction expected 4 parameters, received 2"
            -- until passed explicitly. An empty string constructs to NAME_None same as the default.
            local ok, err = pcall(function() dyn = comp:CreateDynamicMaterialInstance(slot, mat, "") end)
            if not ok then
                print("[LivingBase] [probe-ghostmat2] CreateDynamicMaterialInstance FAILED: " .. tostring(err) .. "\n")
            elseif not (dyn and dyn:IsValid()) then
                print("[LivingBase] [probe-ghostmat2] CreateDynamicMaterialInstance returned nil/invalid (no Lua error, just no result).\n")
            end
            if ok and dyn and dyn:IsValid() then
                touched = touched + 1
                for _, pname in ipairs(PARAM_NAMES) do
                    local pok, perr = pcall(function() dyn:SetVectorParameterValue(pname, GHOST_COLOR) end)
                    if pok then
                        paramsSet = paramsSet + 1
                    else
                        print("[LivingBase] [probe-ghostmat2] SetVectorParameterValue(" .. pname .. ") FAILED: " .. tostring(perr) .. "\n")
                    end
                end
            end
        end
    end
    pcall(function() applyTo(actor.Mesh) end)
    for _, className in ipairs({ "StaticMeshComponent", "SkeletalMeshComponent" }) do
        local cls = StaticFindObject("/Script/Engine." .. className)
        if cls and cls:IsValid() then
            local comps
            local ok = pcall(function() comps = actor:K2_GetComponentsByClass(cls) end)
            if ok and comps then
                local n = 0
                pcall(function() n = comps:GetArrayNum() end)
                if n == 0 then pcall(function() n = #comps end) end
                for i = 1, n do
                    local comp
                    pcall(function() comp = comps[i] end)
                    if not comp then pcall(function() comp = comps:Get(i) end) end
                    applyTo(comp)
                end
            end
        end
    end
    print(string.format("[LivingBase] [probe-ghostmat2] %d dynamic instance(s) created, %d/%d parameter set(s) succeeded.\n",
        touched, paramsSet, touched * #PARAM_NAMES))
    ]]
end

-- Spawner.ToggleCustomDepthOutline() -- TEMP DEV TOOL (2026-08-19, build-ghost-preview spike, 5th
-- pass): RedFalcon's actual ask -- keep the real mesh (full texture/depth/lighting), layer a shader
-- effect ON TOP, rather than replacing the material at all (which is what MI_Building_
-- SimplifiedPreview always was, flat-Masked-Unlit limitations and all). Unreal's standard mechanism
-- for exactly this is bRenderCustomDepth + a post-process outline material reading the CustomDepth
-- buffer -- doesn't touch the object's own material/blend-mode/shading-model at all, so none of
-- tonight's Masked/Unlit/BasePropertyOverrides limitations apply. Untested whether Windrose's
-- rendering pipeline actually HAS an active outline post-process pass reading this buffer -- if it
-- doesn't, this is a harmless no-op (nothing to see), which is why it's worth just trying live
-- rather than more pak-archaeology first. SetRenderCustomDepth/SetCustomDepthStencilValue take a
-- plain bool/int, not a struct -- much lower marshaling risk than CreateDynamicMaterialInstance.
function Spawner.ToggleCustomDepthOutline()
    print("[LivingBase] [probe-outline] key received.\n")
    local actor = Spawner._lastProbedActor
    if not (actor and actor:IsValid()) then
        print("[LivingBase] [probe-outline] no valid probed target -- run lbprobe on something first.\n")
        return
    end
    local touched = 0
    local function applyTo(comp)
        pcall(function() if comp ~= nil and type(comp) == "userdata" and comp.get then comp = comp:get() end end)
        if not (comp and comp:IsValid()) then return end
        local ok1 = pcall(function() comp:SetRenderCustomDepth(true) end)
        local ok2 = pcall(function() comp:SetCustomDepthStencilValue(1) end)
        if ok1 then touched = touched + 1 end
        if not (ok1 and ok2) then
            print(string.format("[LivingBase] [probe-outline] component call failed (SetRenderCustomDepth=%s, SetCustomDepthStencilValue=%s).\n", tostring(ok1), tostring(ok2)))
        end
    end
    pcall(function() applyTo(actor.Mesh) end)
    for _, className in ipairs({ "StaticMeshComponent", "SkeletalMeshComponent" }) do
        local cls = StaticFindObject("/Script/Engine." .. className)
        if cls and cls:IsValid() then
            local comps
            local ok = pcall(function() comps = actor:K2_GetComponentsByClass(cls) end)
            if ok and comps then
                local n = 0
                pcall(function() n = comps:GetArrayNum() end)
                if n == 0 then pcall(function() n = #comps end) end
                for i = 1, n do
                    local comp
                    pcall(function() comp = comps[i] end)
                    if not comp then pcall(function() comp = comps:Get(i) end) end
                    applyTo(comp)
                end
            end
        end
    end
    print(string.format("[LivingBase] [probe-outline] SetRenderCustomDepth(true) on %d component(s) -- LOOK at the object now.\n", touched))
end

-- Spawner.StartFollowTest/StopFollowTest -- TEMP DEV TOOL (2026-08-19, build-ghost-preview spike,
-- 6th pass): tests the ACTUAL risky operation (repeated K2_SetActorLocation), not just timing --
-- lbtickspike only ever measured os.clock() gaps, never actually moved anything. There's a
-- documented, UNRESOLVED crash already in this file from sustained rotation during
-- LivingBaseSpawnMenu's move-panel repeat-hold (see Spawner.EditNearestInFront's own "OPEN ISSUE"
-- comment, 2026-08-16) -- but that path ALSO does two full persist.txt reads plus one rewrite on
-- EVERY call, so the crash may be disk I/O under rapid repeat, not SetActorLocation itself
-- (RedFalcon's hypothesis). This moves the probed actor to follow the camera every tick with ZERO
-- file I/O -- pure in-memory K2_SetActorLocation only -- to isolate that. Reuses the exact camera
-- location/rotation math Spawner.ProbeNearestActor already uses safely. Calls Spawner.MakeMovable
-- first -- otherwise a Static-mobility prop (most world decor) won't visibly move even though the
-- calls succeed (see MakeMovable's own comment). lbfollowteststop sets a flag the loop checks each
-- tick -- doesn't try to cancel a pending ExecuteWithDelay directly (no known API for that), just
-- makes the next tick a no-op instead of rescheduling again.
function Spawner.StartFollowTest(intervalMs, totalTicks, distance)
    intervalMs = intervalMs or 33
    totalTicks = totalTicks or 300
    distance = distance or 300.0
    print("[LivingBase] [followtest] key received.\n")
    local actor = Spawner._lastProbedActor
    if not (actor and actor:IsValid()) then
        print("[LivingBase] [followtest] no valid probed target -- run lbprobe on something first.\n")
        return
    end
    pcall(function() Spawner.MakeMovable(actor) end)
    -- CONFIRMED LIVE (2026-08-19): RedFalcon reported the decor creeping toward the camera instead
    -- of holding a static distance, UNLESS looking straight up (open air, nothing to collide with).
    -- Physics simulation still active on the object -- K2_SetActorLocation correctly teleports the
    -- logical transform, but if bSimulatePhysics is true the physics engine keeps resolving it back
    -- out of whatever world geometry the target point now overlaps, fighting our teleport every
    -- physics tick. Spawner.SetDecorSolid already exists in this file for exactly this reason ("a
    -- physics-simulating prop got shoved... can never eject or drop") but ALSO force-enables
    -- collision, which a live-following preview does NOT want (would shove the player / block
    -- movement) -- so disable physics directly here instead of calling that.
    pcall(function()
        local root = actor:K2_GetRootComponent()
        if root and root:IsValid() then pcall(function() root:SetSimulatePhysics(false) end) end
    end)
    pcall(function() forEachStaticMesh(actor, function(c) c:SetSimulatePhysics(false) end) end)
    print(string.format("[LivingBase] [followtest] starting: nominal %dms x %d ticks (~%.1fs), %.0fuu in front of camera -- NO file I/O this whole time. Look around to see if it tracks.\n",
        intervalMs, totalTicks, intervalMs * totalTicks / 1000.0, distance))
    Spawner._followTestActive = true
    local count, moved = 0, 0
    local function tick()
        if not Spawner._followTestActive then
            print(string.format("[LivingBase] [followtest] stopped early by lbfollowteststop after %d/%d ticks (%d moved OK).\n", count, totalTicks, moved))
            return
        end
        if not (actor and actor:IsValid()) then
            print(string.format("[LivingBase] [followtest] target no longer valid after %d ticks -- stopping.\n", count))
            Spawner._followTestActive = false
            return
        end
        count = count + 1
        local ok = pcall(function()
            local pc = UEHelpers.GetPlayerController()
            if not (pc and pc:IsValid()) then return end
            local cam = pc.PlayerCameraManager
            if not (cam and cam:IsValid()) then return end
            -- FIXED (2026-08-19, RedFalcon's diagnosis): origin was the CAMERA's own position, which
            -- this game's third-person spring-arm camera pulls in/out to avoid clipping through
            -- nearby geometry -- including our own placed object once it got close to the character.
            -- That created a feedback loop: object near character -> camera zooms in -> camera moves
            -- -> our "300uu from camera" target moves with it -> still near character -> repeat. The
            -- per-tick read-back proved the math was hitting exactly 300uu from wherever the camera
            -- WAS each instant -- it was the camera itself oscillating, not our placement. Fix: anchor
            -- the ORIGIN to the player PAWN's position (not moved by camera collision-avoidance),
            -- keep the camera's ROTATION for direction so it still points wherever you're looking.
            local pawn = pc.Pawn
            if not (pawn and pawn:IsValid()) then return end
            local loc = pawn:K2_GetActorLocation()
            local rot = cam:GetCameraRotation()
            local yaw, pitch = math.rad(rot.Yaw), math.rad(rot.Pitch)
            local cp = math.cos(pitch)
            local fx, fy, fz = cp * math.cos(yaw), cp * math.sin(yaw), math.sin(pitch)
            local target = { X = loc.X + fx * distance, Y = loc.Y + fy * distance, Z = loc.Z + fz * distance }
            actor:K2_SetActorLocation(target, false, {}, true)
            moved = moved + 1
            if count <= 3 or count % 30 == 0 then
                local actual = actor:K2_GetActorLocation()
                local dx, dy, dz = actual.X - loc.X, actual.Y - loc.Y, actual.Z - loc.Z
                local actualDist = math.sqrt(dx * dx + dy * dy + dz * dz)
                print(string.format("[LivingBase] [followtest]   tick %d: pawn=(%.0f,%.0f,%.0f) target=(%.0f,%.0f,%.0f) actual=(%.0f,%.0f,%.0f) actualDistFromPawn=%.0fuu\n",
                    count, loc.X, loc.Y, loc.Z, target.X, target.Y, target.Z, actual.X, actual.Y, actual.Z, actualDist))
            end
        end)
        if not ok then
            print(string.format("[LivingBase] [followtest] tick FAILED at count=%d -- stopping (pcall caught it, not a crash).\n", count))
            Spawner._followTestActive = false
            return
        end
        if count < totalTicks then
            ExecuteWithDelay(intervalMs, tick)
        else
            print(string.format("[LivingBase] [followtest] done: %d/%d ticks moved the actor successfully, no crash, zero file I/O.\n", moved, count))
        end
    end
    ExecuteWithDelay(intervalMs, tick)
end

function Spawner.StopFollowTest()
    Spawner._followTestActive = false
    print("[LivingBase] [followtest] stop flag set -- will halt on its next tick instead of rescheduling.\n")
end

--------------------------------------------------------------------
-- Spawn ledger: record each spawn's EXACT instance path to a file so
-- DespawnAll can clean them even after a Ctrl+R wiped the in-memory table.
-- Exact instance paths mean cleanup NEVER touches your real crew/NPCs (they
-- aren't in the ledger). Stale paths (after a world reload, actors gone)
-- resolve to nil and are harmless.
--------------------------------------------------------------------
function actorInstancePath(actor)
    local full = nil
    pcall(function() full = actor:GetFullName() end)
    if not full then return nil end
    local sp = string.find(full, " ", 1, true) -- strip leading "ClassName "
    return sp and string.sub(full, sp + 1) or full
end

-- While a restore is running, `Spawner._ledgerBuffer` collects paths instead of opening the
-- ledger file once PER SPAWN. A 20-mover restore was doing 20 synchronous open/write/close
-- calls on the game thread, inside the very loop we're trying to keep light. One write now.
function ledgerAppend(actor)
    local path = actorInstancePath(actor)
    if not path then return end
    migrateIfNeeded("spawn_ledger.txt", OLD_LEDGER_PATHS)
    -- Only buffer while a restore is genuinely in flight. If a restore ever dies before its
    -- flush, a stale buffer must not silently swallow later keypress spawns.
    local buf = Spawner.restoring and Spawner._ledgerBuffer
    if buf then buf[#buf + 1] = path; return end
    for _, p in ipairs(LEDGER_PATHS()) do
        local f = io.open(p, "a")
        if f then f:write(path .. "\n"); f:close(); return end
    end
end

-- Flush whatever ledgerAppend buffered, in one file write. Safe to call with no buffer.
function Spawner.LedgerFlush()
    local buf = Spawner._ledgerBuffer
    Spawner._ledgerBuffer = nil
    if not buf or #buf == 0 then return end
    migrateIfNeeded("spawn_ledger.txt", OLD_LEDGER_PATHS)
    for _, p in ipairs(LEDGER_PATHS()) do
        local f = io.open(p, "a")
        if f then f:write(table.concat(buf, "\n") .. "\n"); f:close(); return end
    end
end

function ledgerReadAndClear()
    migrateIfNeeded("spawn_ledger.txt", OLD_LEDGER_PATHS)
    local lines, opened = {}, nil
    for _, p in ipairs(LEDGER_PATHS()) do
        local f = io.open(p, "r")
        if f then
            for line in f:lines() do
                if line and #line > 0 then table.insert(lines, line) end
            end
            f:close(); opened = p; break
        end
    end
    if opened then local w = io.open(opened, "w"); if w then w:close() end end
    return lines
end

-- Read the ledger WITHOUT clearing it (for re-tracking orphans after a Ctrl+R).
local function ledgerRead()
    migrateIfNeeded("spawn_ledger.txt", OLD_LEDGER_PATHS)
    for _, p in ipairs(LEDGER_PATHS()) do
        local f = io.open(p, "r")
        if f then
            local lines = {}
            for line in f:lines() do if line and #line > 0 then table.insert(lines, line) end end
            f:close()
            return lines
        end
    end
    return {}
end

--------------------------------------------------------------------
-- Save/restore: record class+position+AI per spawn so we can re-create the
-- crowd on world load (the game doesn't persist our runtime-spawned actors).
--------------------------------------------------------------------
function persistAppend(classPath, loc, aiPath, yaw, makeFriendly, look, instanceLabel)
    if Spawner.restoring then return end
    -- TRANSIENT spawns (night raiders) are never saved. The game doesn't persist our actors
    -- anyway, so writing them here would resurrect a finished raid into the base on reload.
    if Spawner.transient then return end
    -- Fields 8/9/10/11 = composite look (params|archetype|sex|bodyTypes) for re-skinned
    -- spawns (e.g. the clean Senkamati crew). Empty for normal spawns. Paths
    -- never contain "|", so the field split stays safe.
    local lp = (look and look.params) or ""
    local la = (look and look.archetype) or ""
    local ls = (look and look.sex and tostring(look.sex)) or ""
    local lb = (look and look.bodyTypes) or ""
    -- Field 12 = reskinTarget (2026-08-11) — which FEMALE_RESKIN_TARGETS entry a female-
    -- walker spawn was standing in for (e.g. "Letty", "Female_Standing_01"), so a reload
    -- can restore the SAME character/hat-vs-hair category instead of a fresh random roll
    -- every time. Empty for every other spawn type. APPENDED AT THE END, not inserted —
    -- a pre-1.3.5 persist.txt line simply won't have this field at all; every reader below
    -- treats a missing/empty field 12 as "unknown" and falls back to the old fully-random
    -- behavior rather than erroring. Nothing needs converting: an old line never recorded
    -- which target it was in the first place, so there's no lost data to recover — this
    -- only changes what gets written for NEW spawns from here on.
    local lr = (look and look.reskinTarget) or ""
    -- Field 13 = the resolved per-instance display label (2026-08-16, e.g. "Brethren Woman 3") --
    -- see Spawner.NextInstanceLabel's own comment. Same "append at the end, old lines just won't
    -- have it" contract as field 12 above -- restoreOne treats a missing field 13 as an old-format
    -- line to migrate, not an error.
    local ll = tostring(instanceLabel or "")
    -- Fields 14/15 = pitch/roll (2026-08-18) -- always "0.0" here: a FRESH spawn is always upright
    -- at spawn time (Spawner.Spawn's own transform quaternion is yaw-only), same as `yaw` itself
    -- being the only non-zero rotation a fresh placement ever has. Only Spawner.PersistUpdatePose
    -- (live-edit rotate) or Spawner.SetLockedTargetTransform (Coords) ever write a non-zero value
    -- into these fields, after the fact.
    migrateIfNeeded("persist.txt", OLD_PERSIST_PATHS)
    for _, p in ipairs(PERSIST_PATHS()) do
        local f = io.open(p, "a")
        if f then
            f:write(string.format("%s|%.1f|%.1f|%.1f|%s|%.1f|%s|%s|%s|%s|%s|%s|%s|%.1f|%.1f\n",
                classPath, loc.X, loc.Y, loc.Z, aiPath or "", yaw or 0.0,
                makeFriendly and "1" or "0", lp, la, ls, lb, lr, ll, 0.0, 0.0))
            f:close(); return
        end
    end
end

local function persistReadLines()
    migrateIfNeeded("persist.txt", OLD_PERSIST_PATHS)
    for _, p in ipairs(PERSIST_PATHS()) do
        local f = io.open(p, "r")
        if f then
            local lines = {}
            for line in f:lines() do if line and #line > 0 then table.insert(lines, line) end end
            f:close()
            return lines, p
        end
    end
    return {}, nil
end

local function persistWriteLines(lines)
    for _, p in ipairs(PERSIST_PATHS()) do
        local f = io.open(p, "w")
        if f then
            for _, l in ipairs(lines) do f:write(l .. "\n") end
            f:close(); return
        end
    end
end

-- Parse one persist.txt line into its fields. Field order is fixed by persistAppend() above:
-- classPath|X|Y|Z|aiPath|yaw|makeFriendly|look.params|look.archetype|look.sex|look.bodyTypes|look.reskinTarget|instanceLabel|pitch|roll
-- Field 12 (reskinTarget) is a 2026-08-11 addition, field 13 (instanceLabel) a 2026-08-16 one,
-- fields 14/15 (pitch/roll) a 2026-08-18 one -- on an older line, gmatch simply never produces
-- that part, so it comes out nil here. Callers must treat that as "unknown", not an error.
local function parsePersistLine(line)
    local parts = {}
    for f in (line .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = f end
    local x, y, z = tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
    if not (parts[1] and parts[1] ~= "" and x) then return nil end
    local look = nil
    if (parts[8] and parts[8] ~= "") or (parts[9] and parts[9] ~= "") or (parts[12] and parts[12] ~= "") then
        look = { params = parts[8], archetype = parts[9], sex = parts[10], bodyTypes = parts[11],
                 reskinTarget = (parts[12] and parts[12] ~= "" and parts[12]) or nil }
    end
    return {
        classPath = parts[1], X = x, Y = y, Z = z,
        aiPath = (parts[5] ~= "" and parts[5]) or nil,
        yaw = tonumber(parts[6]) or 0.0,
        makeFriendly = (parts[7] == "1"),
        look = look,
        instanceLabel = (parts[13] and parts[13] ~= "" and parts[13]) or nil,
        -- Fields 14/15 (2026-08-18) -- pitch/roll, absent on any pre-2.0.1 line, same "missing =
        -- 0.0, not an error" contract as every other field added to this format so far.
        pitch = tonumber(parts[14]) or 0.0,
        roll = tonumber(parts[15]) or 0.0,
    }
end

-- Find (without removing) the saved record nearest a class + position. Returns the parsed line
-- (see parsePersistLine) and its line index, or nil if nothing matches. Shared by
-- PersistRemoveMatching (which also deletes it) and by the despawn functions, which use this
-- BEFORE destroying an actor to (a) log an explicit "this is the persisted record being removed"
-- confirmation, and (b) recover the AI-controller/composite-look fields for a full-fidelity undo —
-- data the live actor's transform alone doesn't carry.
function Spawner.PersistFindMatching(classPath, loc)
    if not (classPath and loc) then return nil end
    local lines = persistReadLines()
    local bestI, bestD, bestParsed
    for i, line in ipairs(lines) do
        local parsed = parsePersistLine(line)
        if parsed and parsed.classPath == classPath then
            local d = (parsed.X - loc.X) ^ 2 + (parsed.Y - loc.Y) ^ 2 + (parsed.Z - loc.Z) ^ 2
            if not bestD or d < bestD then bestI, bestD, bestParsed = i, d, parsed end
        end
    end
    return bestParsed, bestI
end

-- Wipe the save file (DEL clean-house: nothing comes back on next load).
function Spawner.PersistClear()
    persistWriteLines({})
end

-- Drop the last saved record (F9 undo).
function Spawner.PersistRemoveLast()
    local lines = persistReadLines()
    if #lines > 0 then table.remove(lines); persistWriteLines(lines) end
end

-- Drop the saved record matching a class + spawn position (the closest one). Order-
-- independent, so it works even after the in-memory list was rebuilt from disk (Ctrl+R)
-- and no longer lines up with persist by index. `loc` is the spawn/home position.
function Spawner.PersistRemoveMatching(classPath, loc)
    if not (classPath and loc) then return false end
    local lines = persistReadLines()
    local _, bestI = Spawner.PersistFindMatching(classPath, loc)
    if bestI then table.remove(lines, bestI); persistWriteLines(lines); return true end
    return false
end

-- After a Ctrl+R hot-reload the in-memory list is gone but the spawned actors are still
-- live orphans and the ledger still lists their EXACT instance paths. Re-associate them by
-- matching those paths — the same guarantee DespawnAll uses so we only ever touch OUR
-- spawns, never the player's real crew/NPCs (matching by class+position could grab a real
-- crewman of the same class). Lets "despawn in front"/"undo" work again after Ctrl+R.
function Spawner.RetrackOrphans()
    if #Spawner.spawned > 0 then return 0 end
    local wanted = {}
    for _, path in ipairs(ledgerRead()) do wanted[path] = true end
    if not next(wanted) then return 0 end
    local n = 0
    pcall(function()
        local actors = FindAllOf("Actor")
        if not actors then return end
        for _, a in ipairs(actors) do
            if a and a:IsValid() then
                local path = actorInstancePath(a)
                if path and wanted[path] then
                    wanted[path] = nil
                    local cls, home
                    pcall(function()
                        cls = a:GetClass():GetFullName():match("(/Game/[%w_/%.]+)$")
                    end)
                    pcall(function()
                        local l = a:K2_GetActorLocation(); home = { X = l.X, Y = l.Y, Z = l.Z }
                    end)
                    -- Readable label from the class path (same short-name idiom used everywhere else
                    -- in this file, e.g. EditNearestInFront's `short`) instead of the generic
                    -- "RETRACKED" placeholder this had before (2026-08-13) -- a plain "RETRACKED"
                    -- toast/log line told you NOTHING about which object it actually was, which only
                    -- became visible once Target Lock started surfacing `label` directly in its own
                    -- toast right after an lbreload (RetrackOrphans is what re-populates Spawner.spawned
                    -- after a hot-reload wipes it -- see findNearestSpawnInFront's own call site above).
                    local label = (cls and tostring(cls):match("([%w_]+)%.[%w_]+$")) or "unknown"
                    -- idle (2026-08-24 fix, same regression/reasoning as restoreOne's own markIdle
                    -- comment above -- RedFalcon: "idles lose the ai lock after moving") -- an
                    -- orphan re-tracked after an lbreload/Ctrl+R has no `look`/reskinTarget of its
                    -- own to read (this function only scans live actors + the ledger, neither
                    -- carries it), so cross-reference persist.txt by class+position -- the SAME
                    -- record restoreOne itself would read on a real world-load restore -- purely to
                    -- recover its reskinTarget for the same "::true$" check.
                    local idle = false
                    if cls and home then
                        local persisted = Spawner.PersistFindMatching(cls, home)
                        idle = (persisted and persisted.look and persisted.look.reskinTarget
                            and tostring(persisted.look.reskinTarget):match("::true$")) and true or false
                    end
                    table.insert(Spawner.spawned,
                        { actor = a, label = label, class = cls, home = home, idle = idle })
                    n = n + 1
                end
            end
        end
    end)
    if n > 0 then log(string.format("Re-tracked %d orphaned spawns after reload.", n)) end
    return n
end

-- Re-spawn one persisted line. Returns (actor, classPath, look) or nil. Does NOT run the
-- restore hook — post-processing is deferred until the world is stable (see below).
local function restoreOne(line)
    -- split: class|x|y|z|ai|yaw|friendly|lookParams|lookArchetype|sex|bodyTypes|reskinTarget|instanceLabel|pitch|roll|lootMesh
    -- (reskinTarget is a 2026-08-11 addition/field 12, instanceLabel a 2026-08-16 one/field 13,
    -- pitch/roll a 2026-08-18 one/fields 14-15, lootMesh a 2026-08-19 one/field 16 -- any of these
    -- can be absent/nil on an older line, same graceful-degradation contract as parsePersistLine
    -- above.)
    local parts = {}
    for f in (line .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = f end
    local cls, x, y, z, ai, yw, fr = parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]
    local lp, la, ls, lb, lr, storedLabel = parts[8], parts[9], parts[10], parts[11], parts[12], parts[13]
    local pitch, roll = tonumber(parts[14]) or 0.0, tonumber(parts[15]) or 0.0
    local lootMesh = parts[16]
    if not (cls and x and y and z) then return end
    local loc = { X = tonumber(x), Y = tonumber(y), Z = tonumber(z) }
    local aiPath = (ai and ai ~= "") and ai or nil
    local yaw = tonumber(yw) or 0.0
    local friendly = (fr == "1")
    local look = nil
    if (lp and lp ~= "") or (la and la ~= "") or (lb and lb ~= "") or (lr and lr ~= "")
        or (lootMesh and lootMesh ~= "") then
        look = { params    = (lp and lp ~= "" and lp) or nil,
                 archetype = (la and la ~= "" and la) or nil,
                 sex       = (ls and ls ~= "" and tonumber(ls)) or nil,
                 bodyTypes = (lb and lb ~= "" and lb) or nil,
                 reskinTarget = (lr and lr ~= "" and lr) or nil,
                 lootMesh  = (lootMesh and lootMesh ~= "" and lootMesh) or nil }
        -- AUTO-UPGRADE old-style walking-women lines (2026-08-19): a Letty/Marita/Merchant
        -- persisted BEFORE they got their own real Config.FEMALE_CHARACTER_PARAMS outfit is still
        -- carrying the OLD shared-composite params in this saved line -- and since composite pieces
        -- are confirmed build-time-only this session (no live post-build lever exists, see
        -- Spawner.ApplyCompositeOrdered's own dead-end note), the ONLY place that can fix her is
        -- HERE, before Spawner.Spawn ever builds her, not afterward. Reuses the exact same
        -- femaleCharacterKey suffix-strip rule testbed.lua's own copy uses (kept as a plain inline
        -- pattern rather than a cross-module call -- spawner.lua doesn't require testbed.lua, and
        -- never should, to avoid a circular require). A character with no dedicated params entry
        -- (Woman, or anything not yet migrated) is untouched -- charParams.params is nil for those,
        -- so the `and` short-circuits and look.params passes through exactly as persisted.
        if look.reskinTarget then
            local characterKey = look.reskinTarget:gsub("%s+Base%s+%d+$", "")
            local charParams = Config.FEMALE_CHARACTER_PARAMS and Config.FEMALE_CHARACTER_PARAMS[characterKey]
            if charParams and charParams.params and look.params ~= charParams.params then
                log(string.format("restore: upgrading '%s' to her real outfit (was using the old shared composite).", look.reskinTarget))
                look.params = charParams.params
            end
        end
    end

    -- Instance label (2026-08-16): reuse the stored one verbatim if this line has it (stable across
    -- reloads), bumping the in-memory counter so a FRESH placement later this session can't reissue
    -- the same number. An older line (no field 13) gets migrated here: derive the best available
    -- base name (the reskinTarget if this was a female-walker reskin, else a short class name, else
    -- plain "Restored"), mint a fresh number for it via the SAME counter every live spawn uses, and
    -- mark it to be written back below so the NEXT restore reads this SAME resolved label instead of
    -- silently re-migrating (and potentially re-numbering) it every single reload.
    local resolvedLabel, needsMigration
    if storedLabel and storedLabel ~= "" then
        resolvedLabel = storedLabel
        Spawner.NoteInstanceLabelUsed(storedLabel)
    else
        local baseName = lr
        if not baseName or baseName == "" then
            baseName = tostring(cls):match("([%w_]+)%.[%w_]+$") or tostring(cls):match("([%w_]+)$") or "Restored"
        end
        resolvedLabel = Spawner.NextInstanceLabel(baseName)
        needsMigration = true
    end

    -- markIdle (2026-08-24 fix, RedFalcon: "idles lose the ai lock after moving" -- a RESTORED idle
    -- Senkamati's entry.idle came back false, since this call never threaded it through, so
    -- ConfirmPlacement/CancelPlacement's releasePlacementMobility -- see their own comments -- wrongly
    -- restored its AI after a relocate). Same "::true$" detection the idle-freeze fix a few lines
    -- below already uses on this exact reskinTarget string -- reused here instead of duplicated, so
    -- the two can never drift out of sync with each other.
    local markIdle = look and look.reskinTarget and tostring(look.reskinTarget):match("::true$") and true or false
    local ok, a = pcall(function()
        return Spawner.Spawn(cls, resolvedLabel, loc, nil, aiPath, yaw, friendly, look, resolvedLabel, markIdle)
    end)
    if ok and a and a:IsValid() then
        if needsMigration then
            pcall(function() Spawner.PersistUpdateLabel(cls, loc, resolvedLabel) end)
        end
        -- DECORATIONS restore as scenery: freeze physics + enable collision RIGHT NOW (same frame as the
        -- spawn, before the first physics tick). Otherwise a prop whose mesh grazes the terrain gets
        -- shoved upward by depenetration during the ~14s before the delayed SolidifyDecor pass runs, and
        -- ends up frozen HIGHER than it was placed (the "ground pushes them back up on reload" bug). Also
        -- make it Movable (so live-edit still works on restored props) and re-assert the exact saved Z in
        -- case a tick nudged it before we froze it.
        if Config.DECOR_COLLISION ~= false and Spawner.IsDecorClass(cls) then
            pcall(function() Spawner.SetDecorSolid(a) end)
            pcall(function() Spawner.MakeMovable(a) end)
            pcall(function() a:K2_SetActorLocation({ X = loc.X, Y = loc.Y, Z = loc.Z }, false, {}, true) end)
        end
        -- Pitch/roll (2026-08-18): Spawner.Spawn's own placement transform is yaw-only (matches
        -- every OTHER spawn path, upright by default), so a saved non-zero pitch/roll from a prior
        -- live-edit/Coords session needs a direct post-spawn correction here, same K2_SetActorRotation
        -- call EditNearestInFront/SetLockedTargetTransform already use. Skipped entirely when both
        -- are 0 (the overwhelming common case) to avoid a pointless extra native call on every restore.
        if pitch ~= 0.0 or roll ~= 0.0 then
            pcall(function() a:K2_SetActorRotation({ Pitch = pitch, Yaw = yaw, Roll = roll }, false) end)
        end
        -- Item-drop decor mesh (2026-08-19 fix, RedFalcon's bug report). MUST be applied HERE,
        -- inline/synchronous, not through a RESTORE_RULES/RestoreHook entry -- confirmed live that
        -- an entry there is unreachable dead code for ANY decor-class actor: isStaticLine() routes
        -- decor into the `statics` list, which spawnList() calls with collect=false ("Only MOVERS
        -- get post-processing... so only collect them", right above this file's own restore-loop
        -- comment) specifically so a statics-heavy base skips a no-op post-process pass -- postList
        -- (and therefore Spawner.restoreHook/RestoreHook) never sees a decor actor at all. Same
        -- immediate-not-deferred treatment the DECORATIONS block just above already gives every
        -- decor actor (SetDecorSolid/MakeMovable) -- this is a plain SetSkeletalMeshAsset swap, not
        -- crash-prone component surgery, so there's no reason it needs the deferred/staggered
        -- pipeline movers require.
        if look and look.lootMesh then
            pcall(function() Spawner.SetLootMesh(a, look.lootMesh) end)
            pcall(function() Spawner.MakeLootDecor(a) end)
        end
        -- Idle Senkamati (2026-08-23 fix, RedFalcon: "they do eventually freeze, but they need
        -- to freeze immediately... they are supposed to be frozen like statues"). testbed.lua's
        -- RESTORE_RULES already calls freezeSenkaStatue for an idle row, correctly ordered
        -- BEFORE its own de-corrupt work -- but RestoreHook (which is what actually invokes
        -- RESTORE_RULES) never runs until Config.RESTORE_POSTPROCESS_MS (8s default) after
        -- EVERY mover in this restore has already spawned, since that whole deferred pipeline
        -- exists for de-corrupt/MakePassive/goat-strip's crash-prone COMPONENT SURGERY (see
        -- scheduleRestorePostProcess's own comment) -- confirmed live, every idle Senkamati
        -- visibly walked for the full 8+ second wait before that first freeze call ever landed.
        -- SetAILogic is a plain function call, not component surgery, so it doesn't need that
        -- gate at all -- same reasoning already applied to decor's own physics/collision and
        -- loot-mesh restoration immediately above. reskinTarget's format is
        -- "name::kind::helmet::idle" (see testbed.lua's senkaRowKey/parseSenkaRowKey) --
        -- checking the trailing "::true" inline here, rather than requiring testbed.lua (which
        -- spawner.lua never does, to avoid a circular require -- same precedent as
        -- spawnmenu_manifest.lua's own short_class_name duplicate). RestoreHook's own later
        -- freeze call is UNCHANGED and still runs too -- harmless no-op re-assertion once this
        -- one has already taken, and a safety net if this one somehow doesn't.
        if look and look.reskinTarget and tostring(look.reskinTarget):match("::true$") then
            pcall(function() Spawner.SetAILogic(a, false) end)
        end
        return a, cls, look
    end
end

-- Post-processing (de-corrupt, MakePassive, goat perception-strip) does COMPONENT SURGERY.
-- Doing it mid-world-load crashed natively (destroying a goat's Memory/Agent components
-- while its AI was still initializing). So run it ONLY after the world is fully stable,
-- one actor per ~300ms — the same conditions under which a manual F-key spawn does it safely.
--
-- onFinished(staticsCount, moversCount), if given, is called EXACTLY ONCE, on every exit path —
-- whether post-processing actually ran (the normal path, after the last actor) or was skipped
-- entirely (RESTORE_POSTPROCESS=false, or restoreHook/ExecuteWithDelay unavailable). This is now
-- the one true "the restore is completely done" signal (see Spawner.RestoreFromPersist's own
-- comment on why the old "base restored" toast/onComplete used to fire here — before post-
-- processing — too early: the base wasn't actually done yet). Must fire on every path or a caller
-- relying on it (main.lua's restoreLockActive) would stay stuck forever.
-- WAIT-FOR-ASYNC (2026-08-11, RedFalcon's request): once every restoreHook has been CALLED, this used
-- to fire immediately — but a restoreHook implementation (Testbed.ApplyFemaleReskinTarget) can
-- kick off several more SECONDS of background work per actor after returning, so "base restored
-- and ready" could appear well before female walkers actually finished their skin/hair/hat
-- processing. Now polls Spawner.postProcessPending (opt-in counter, see its own comment) every
-- 500ms and holds the final callback until it reaches zero. SAFETY TIMEOUT: never waits past
-- Config.POSTPROCESS_WAIT_TIMEOUT_MS (default 30s) regardless — main.lua's restoreLockActive
-- key-gate depends on onFinished eventually firing; a bug that left the counter above zero
-- forever must not lock the player out of every mod key permanently.
local function scheduleRestorePostProcess(restored, staticsCount, moversCount, onFinished)
    local function finish()
        local waited = 0
        local function waitForPending()
            local pending = Spawner.postProcessPending or 0
            if pending <= 0 or waited >= (Config.POSTPROCESS_WAIT_TIMEOUT_MS or 30000) then
                if pending > 0 then
                    print(string.format(
                        "[LivingBase] Restore post-processing: gave up waiting for %d outstanding async job(s) after %dms.\n",
                        pending, waited))
                end
                if onFinished then pcall(onFinished, staticsCount, moversCount) end
                return
            end
            waited = waited + 500
            if ExecuteWithDelay then
                ExecuteWithDelay(500, waitForPending)
            else
                if onFinished then pcall(onFinished, staticsCount, moversCount) end
            end
        end
        waitForPending()
    end
    if Config.RESTORE_POSTPROCESS == false or not (Spawner.restoreHook and ExecuteWithDelay) then
        finish()
        return
    end
    local j = 0
    local function step()
        j = j + 1
        if j > #restored then
            log("Restore post-processing done.")
            finish()
            return
        end
        ExecuteInGameThread(function()
            local e = restored[j]
            if e and e.actor and e.actor:IsValid() then
                pcall(Spawner.restoreHook, e.actor, e.class, e.look)
            end
        end)
        ExecuteWithDelay(Config.RESTORE_POSTPROCESS_SPACING_MS or 400, step)
    end
    ExecuteWithDelay(Config.RESTORE_POSTPROCESS_MS or 8000, step)
end

-- STATUES (posed AnimatedActors + stationary QuestStatic NPCs) and DECORATIONS (inert set-dressing
-- props, Config.DECOR_CATEGORIES) have no wandering AI, so they can restore FAST. Only MOVERS
-- (crew/townsfolk/animals/mobs) each wake an AI and must be paced. Classify a persist line by its
-- class path.
-- BUG FIXED 2026-08-13: decorations were never checked here at all -- their class paths don't
-- contain "AnimatedActor"/"QuestStatic", so every decoration silently fell into the movers bucket
-- and got needlessly AI-staggered (RESTORE_STAGGER_MS per item) on every restore since decorations
-- were introduced, despite being just as static as a posed statue. Spawner.IsDecorClass already
-- has an exact-path lookup built from the same Config.DECOR_CATEGORIES data -- reuse it here.
local function isStaticLine(line)
    local cls = line:match("^([^|]*)")
    if not cls then return false end
    if cls:find("AnimatedActor") ~= nil or cls:find("QuestStatic") ~= nil then return true end
    return Spawner.IsDecorClass(cls)
end

-- Re-spawn everything in the save file (called on world load). Statues spawn quickly; movers
-- are staggered (a synchronous AI-pawn burst crashed in ActivateCharacter). Then DEFERRED,
-- spaced post-processing once the world is stable.
-- onComplete (optional): called once this restore genuinely concludes -- whether it actually restored
-- something, found nothing to restore, or hit the debounce/re-entrancy guards. Lets main.lua's
-- keybind lock release the instant it's actually safe, instead of guessing a fixed delay (see the
-- restoreLockActive comment in main.lua for why this exists at all).
function Spawner.RestoreFromPersist(onComplete)
    if Spawner.restoring then return 0 end                 -- re-entrancy guard (another restore owns completion)
    local now = os.time()
    if Spawner._lastRestore and (now - Spawner._lastRestore) < 8 then
        return 0                                            -- debounce double-fire (ditto)
    end
    local lines = persistReadLines()
    if #lines == 0 then
        if onComplete then pcall(onComplete) end
        return 0
    end
    Spawner._lastRestore = now
    Spawner.restoring = true
    Spawner._ledgerBuffer = {}      -- batch ledger writes; flushed when the restore finishes
    -- Always log: marks that the restore actually BEGAN. If a crash log shows this line,
    -- the crash is ours; if it shows only "player pawn ready", the crash is before us.
    print("[LivingBase] Restore: starting, " .. tostring(#lines) .. " saved entries.\n")
    -- STAND STILL warning: spawning + the post-processing "component surgery" (de-corrupt,
    -- MakePassive, goat perception-strip) both do delicate, crash-prone work over several seconds
    -- (see scheduleRestorePostProcess's own comment on why post-processing crashed natively when
    -- disturbed). Moving around / acting heavily during that window adds memory pressure on top of
    -- an already fragile sequence and has been observed to crash the game. Longer duration (8s, up
    -- from the usual 3s toast) so it stays visible through most of the window; the player's real
    -- cue to stop watching for it is the "base restored and ready" toast at the true end (see
    -- scheduleRestorePostProcess's onFinished below), not this toast's own timeout.
    pcall(function()
        Spawner.Toast(string.format(
            "LivingBase: restoring your base (%d saved entries)... please stand still until you see 'base restored and ready'.",
            #lines), 8.0)
    end)

    -- No delay primitive? Fall back to a synchronous burst with no post-processing.
    if not ExecuteWithDelay then
        local n = 0
        for _, line in ipairs(lines) do if restoreOne(line) then n = n + 1 end end
        Spawner.restoring = false
        Spawner.LedgerFlush()
        log(string.format("Restored %d persisted spawns (unstaggered, no post-process).", n))
        pcall(function() Spawner.Toast(string.format("LivingBase: base restored (%d objects).", n), 3.0) end)
        if onComplete then pcall(onComplete) end
        return n
    end

    -- Statics first (fast, no AI: statues + decorations), then movers (slow, AI-paced).
    local statics, movers = {}, {}
    for _, line in ipairs(lines) do
        if isStaticLine(line) then statics[#statics + 1] = line else movers[#movers + 1] = line end
    end
    -- Only MOVERS get post-processing (statues/decorations match no restoreHook branch), so only
    -- collect them — a statics-heavy base skips a no-op post-process pass over every one.
    local postList = {}
    local function spawnList(list, interval, collect, onDone)
        local i = 0
        local function step()
            i = i + 1
            if i > #list then onDone(); return end
            ExecuteInGameThread(function()
                -- Always log BEFORE the spawn: a native crash inside the engine leaves no
                -- trace otherwise, and "which entry died" is the whole question.
                local raw = list[i]:match("^([^|]*)") or "?"
                log(string.format("Restore %d/%d -> %s", i, #list, raw:match("([^/%.]+)$") or raw))
                local a, cls, look = restoreOne(list[i])
                if a and collect then postList[#postList + 1] = { actor = a, class = cls, look = look } end
            end)
            ExecuteWithDelay(interval, step)
        end
        -- LEAD-IN before the FIRST item, not just between items. step() used to spawn item 1
        -- in the same frame as "Restore: starting". That was harmless when statues led the
        -- list (cheap AnimatedActors, and movers didn't begin for ~2s), but a base of pure
        -- movers put an AI pawn spawn in that frame — which hung the load once and crashed
        -- it once (2026-07-09, both with 0 statues). Empty lists cost one extra tick; fine.
        if ExecuteWithDelay then
            ExecuteWithDelay(Config.RESTORE_LEAD_IN_MS or 2000, step)
        else
            step()
        end
    end

    spawnList(statics, Config.RESTORE_STATIC_STAGGER_MS or 40, false, function()
        spawnList(movers, Config.RESTORE_STAGGER_MS or 250, true, function()
            Spawner.restoring = false
            Spawner.LedgerFlush()   -- one write for the whole restore, not one per spawn
            -- Progress info only, NOT "done" -- post-processing (component surgery on every
            -- restored mover) still has to run, and disturbing that is the crash risk this whole
            -- stand-still warning exists for. The genuine completion signal (toast + onComplete,
            -- which releases main.lua's restoreLockActive key-gate) now fires from
            -- scheduleRestorePostProcess's onFinished callback below, once post-processing is
            -- ACTUALLY done -- not here, where it used to fire prematurely.
            print(string.format("[LivingBase] Restored %d statues + %d movers; post-processing in %ds.\n",
                #statics, #movers, math.floor((Config.RESTORE_POSTPROCESS_MS or 8000) / 1000)))
            -- Toast, not just a log line (2026-08-11, RedFalcon's request) -- marks the start of the
            -- (now genuinely tracked, see scheduleRestorePostProcess's wait-for-async comment)
            -- post-processing phase, so "base restored and ready" isn't the first visible sign
            -- anything is happening after the initial "restoring your base" toast.
            pcall(function()
                Spawner.Toast(string.format(
                    "LivingBase: post-processing %d mover(s)...", #movers), 4.0)
            end)
            scheduleRestorePostProcess(postList, #statics, #movers, function(staticsCount, moversCount)
                print(string.format("[LivingBase] Base restored and ready (%d statues, %d movers).\n",
                    staticsCount, moversCount))
                pcall(function()
                    Spawner.Toast(string.format(
                        "LivingBase: base restored and ready (%d statues, %d movers). You can move freely now.",
                        staticsCount, moversCount), 4.0)
                end)
                if onComplete then pcall(onComplete) end
            end)
        end)
    end)
    return 0    -- reported asynchronously
end

--------------------------------------------------------------------
-- Spawner.LeashTick() — keep wanderers near where they were placed WITHOUT the
-- old teleport jerk. Two tiers:
--   * Past LEASH_RADIUS_UU: tell the AI to WALK home (MoveToLocation). Natural
--     stroll; re-issued each tick while it's outside. If the pawn has no usable
--     controller, we fall back to a soft teleport so it never escapes entirely.
--   * Past HARD_LEASH_UU: teleport home (far backstop for a truly-stuck NPC).
-- Called on a timer from main.lua. Stationary spawns never trip it. Must run on
-- the game thread (moves actors / drives AI). All pcall'd.
--------------------------------------------------------------------
local function teleportHome(actor, home, jitter)
    pcall(function()
        local x, y = home.X, home.Y
        if jitter and jitter > 0 then
            local ang, rad = math.random() * 6.2832, math.random() * jitter
            x, y = x + math.cos(ang) * rad, y + math.sin(ang) * rad
        end
        actor:K2_SetActorLocation({ X = x, Y = y, Z = home.Z }, false, {}, true)
    end)
end

-- Ask the pawn's AI controller to walk to `dest`. Returns true if the command
-- was issued. AAIController:MoveToLocation (UE5 8-arg signature).
local function walkTo(actor, dest)
    local issued = false
    pcall(function()
        local ctrl = actor:GetController()
        if ctrl and ctrl:IsValid() and ctrl.MoveToLocation then
            -- (Dest, AcceptanceRadius, bStopOnOverlap, bUsePathfinding,
            --  bProjectDestinationToNavigation, bCanStrafe, FilterClass, bAllowPartialPath)
            ctrl:MoveToLocation({ X = dest.X, Y = dest.Y, Z = dest.Z },
                80.0, true, true, true, true, nil, true)
            issued = true
        end
    end)
    return issued
end

function Spawner.LeashTick()
    local soft = Config.LEASH_RADIUS_UU or 600
    local hard = Config.HARD_LEASH_UU or 6000
    local soft2, hard2 = soft * soft, hard * hard
    local jitter = soft * 0.4
    for _, e in ipairs(Spawner.spawned) do
        if e.actor and e.actor:IsValid() and e.home then
            local ok, loc = pcall(function() return e.actor:K2_GetActorLocation() end)
            if ok and loc then
                local dx, dy = loc.X - e.home.X, loc.Y - e.home.Y
                local d2 = dx * dx + dy * dy
                if d2 > hard2 then
                    teleportHome(e.actor, e.home, jitter)          -- far backstop
                elseif d2 > soft2 then
                    if not walkTo(e.actor, e.home) then            -- gentle walk home
                        teleportHome(e.actor, e.home, jitter)      -- fallback if no AI
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------
-- Friendly faction (EXPERIMENTAL): copy a live crew's FactionsParams onto an
-- actor so the relationship system treats it as your faction (friendly to you
-- AND your crew). Faction may be baked at BeginPlay, so callers set it both in
-- the pre-finish window and post-spawn. Needs at least one crew in the world.
--------------------------------------------------------------------
function Spawner.GetFriendlyFactionParams()
    if Spawner._friendlyFactionParams and Spawner._friendlyFactionParams:IsValid() then
        return Spawner._friendlyFactionParams
    end
    local found = nil
    -- Preferred: copy from a live player crew if one exists.
    pcall(function()
        local list = FindAllOf("BP_Mob_Crew_Regular_Player_C")
        if list then
            for _, c in ipairs(list) do
                if c and c:IsValid() then
                    local ok, fp = pcall(function() return c.FactionComponent.FactionsParams end)
                    if ok and fp and fp:IsValid() then found = fp; break end
                end
            end
        end
    end)
    -- Fallback: load the faction DATA ASSET directly (the params a crew points at). This
    -- removes the "need a live crew" dependency — without it, animals/Senkamati restored or
    -- spawned with no crew present stayed HOSTILE (confirmed: peace only when a crew existed).
    if not found then
        pcall(function()
            local path = Config.FRIENDLY_FACTION_ASSET
            if path then
                local fp = StaticFindObject(path) or LoadAsset(path)
                if fp and fp:IsValid() then found = fp end
            end
        end)
    end
    Spawner._friendlyFactionParams = found
    return found
end

function Spawner.MakeFriendly(actor, fp)
    fp = fp or Spawner.GetFriendlyFactionParams()
    if not (actor and actor:IsValid() and fp) then return false end
    local ok = false
    pcall(function()
        local fc = actor.FactionComponent
        if fc and fc:IsValid() then fc.FactionsParams = fp; ok = true end
    end)
    return ok
end


--------------------------------------------------------------------
-- Spawner.DespawnNearestInFront(maxDist) — destroy the single tracked spawn nearest to
-- the player AND in front of them (facing hemisphere). Lets you walk up to one bad
-- statue and remove just it, instead of undo-ing the whole list. Only ever touches OUR
-- tracked actors (Spawner.spawned) — never a FindAllOf('Actor') sweep.
--------------------------------------------------------------------
-- Shared "what's the object right in front of me" finder — despawn, live-edit, and the pose-cycle
-- key all need exactly this same pick, and it was written three separate times before being pulled
-- out here (risk: they'd quietly drift apart). Returns (index, entry, dist) into Spawner.spawned, or
-- nil if nothing qualifies. Below MIN_STABLE_DIST, the cosine "is it in front" test is skipped — at
-- point-blank range that vector is tiny and its angle is noise-sensitive (gets WORSE, not better, the
-- tighter the cone, since a small position wobble swings the angle wildly when dist is near zero).
--
-- Cone width is Config.TARGET_MIN_VIEW_DOT (cosine threshold): was an unconditional `dot > 0`, i.e. a
-- full 90-degree hemisphere, so "nearest anything vaguely in front" could out-compete "the one you're
-- actually looking at" when two spawns sat near each other. Narrowed after comparing against
-- WindroseTextSigns (separate UE4SS mod, targets native signs) — its shipped config uses a ~23-degree
-- cone at long range and reportedly targets more reliably. See Config.TARGET_MIN_VIEW_DOT's comment
-- in config.lua for the exact number.
--
-- The cone direction is now the CAMERA'S look vector (pitch included), not pawn body yaw — user
-- reported the other mod's targeting tracks the reticle and includes vertical look (picking between
-- two signs stacked on top of each other), and asked to try the same here. This is a DIFFERENT
-- combination from the one already tried and rejected in `EditNearestInFront` (see its comment): that
-- was camera direction driving both WHERE the search originates/moves things AND which object gets
-- picked, at the OLD wide 90-degree cone, and mixing camera-offset position with pawn position made
-- movement worse. Here, camera direction feeds ONLY the target-pick cone below (cfx/cfy/cfz, local,
-- not returned) — the returned px/py/pz/fx/fy stay 100% pawn-based, unchanged, because
-- EditNearestInFront still needs pawn facing for its slide-frame math.
--
-- FIRST ATTEMPT AT THIS BROKE EVERYTHING (2026-08-06): used the camera's DIRECTION but the PAWN'S
-- POSITION as the ray origin. Every single live-edit press failed ("nothing within 200uu ahead") even
-- while visibly aimed at something on screen. Root cause: in third person the camera sits well behind/
-- above the pawn's root, and at our short ranges (200-250uu) that offset is comparable to or bigger
-- than the target distance itself — nowhere near negligible the way it is at WTS's 1000uu range. A ray
-- "from the pawn, pointed where the camera looks" just doesn't line up with what's under the reticle at
-- close range. Fix: the angle test now uses BOTH camera position and camera direction (camX/camY/camZ +
-- cfx/cfy/cfz), a self-consistent pair from PlayerCameraManager — while the RANGE/reach check (`dist`,
-- compared against maxDist and used for "nearest") stays pawn-based on purpose, so "how far can I
-- reach" still tracks how close you're standing, not how far the camera boom is pulled out. If
-- camera-based picking still feels off after this, the next lever is Config.TARGET_MIN_VIEW_DOT, not
-- reverting to pawn yaw for the cone, and NOT reverting to pawn-origin for the angle test.
-- ignoreLock (2026-08-16, added for Spawner.ToggleTargetLock's "retarget in one press" feature):
-- when true, skips the target-lock short-circuit below entirely and always does the normal fresh
-- cone/range pick, even while a lock is active. Every existing caller passes nothing (nil =
-- false), so this is purely additive -- the lock still transparently wins for despawn/cycle/
-- live-edit exactly as before.
local function findNearestSpawnInFront(maxDist, ignoreLock)
    if #Spawner.spawned == 0 then pcall(Spawner.RetrackOrphans) end   -- Ctrl+R recovery
    local MIN_STABLE_DIST = 40.0
    local minViewDot = Config.TARGET_MIN_VIEW_DOT or 0.90
    local px, py, pz, fx, fy       -- pawn position + pawn-yaw facing: returned as-is, used by callers
    local camX, camY, camZ         -- camera position: used ONLY for the cone test below (angle origin)
    local cfx, cfy, cfz            -- camera look direction (yaw+pitch): used ONLY for the cone test below
    pcall(function()
        local pc = UEHelpers.GetPlayerController()
        local pawn = pc and pc:IsValid() and pc.Pawn
        if not (pawn and pawn:IsValid()) then return end
        local loc = pawn:K2_GetActorLocation()
        local rot = pawn:K2_GetActorRotation()
        px, py, pz = loc.X, loc.Y, loc.Z
        local a = math.rad(rot.Yaw)
        fx, fy = math.cos(a), math.sin(a)          -- UE forward = +X rotated by yaw

        -- Origin AND direction must both come from the camera, or the cone points where the camera
        -- looks but starts from where the pawn's ROOT is — in third person the camera sits well behind/
        -- above that root, and at our short ranges (200-250uu) that offset is comparable to the target
        -- distance itself, not negligible like it is at WTS's 1000uu. Mixing them made every press miss
        -- (confirmed 2026-08-06: every single live-edit press failed, "nothing within 200uu ahead", even
        -- while visibly aimed at something in-game). PlayerCameraManager is the one source that gives a
        -- genuinely self-consistent location+rotation pair for "where the reticle ray actually starts".
        local cam = pc.PlayerCameraManager
        local camRot
        if cam and cam:IsValid() then
            pcall(function() local l = cam:GetCameraLocation(); camX, camY, camZ = l.X, l.Y, l.Z end)
            pcall(function() camRot = cam:GetCameraRotation() end)
        end
        if not camX then camX, camY, camZ = px, py, pz end   -- camera manager unavailable: fall back to pawn root
        if not camRot then pcall(function() camRot = pc:GetControlRotation() end) end
        if camRot then
            -- Matches UE's own FRotator::Vector(): X=cos(pitch)*cos(yaw), Y=cos(pitch)*sin(yaw),
            -- Z=sin(pitch) (positive pitch = looking up).
            local yaw, pitch = math.rad(camRot.Yaw), math.rad(camRot.Pitch)
            local cp = math.cos(pitch)
            cfx, cfy, cfz = cp * math.cos(yaw), cp * math.sin(yaw), math.sin(pitch)
        else
            cfx, cfy, cfz = fx, fy, 0.0   -- no camera/control rotation at all: fall back to flat pawn facing
        end
    end)
    if not px then return nil, nil, nil, nil, nil, nil, nil, nil end

    -- TARGET LOCK (Spawner.lockedTarget, toggled by Num+ -- see Spawner.ToggleTargetLock): a DELIBERATE,
    -- user-held pin on one specific tracked actor, checked here so despawn/live-edit/cycle -- every
    -- caller of this shared picker -- all honor it for free, with no changes needed at any call site.
    -- Bypasses the cone/range search entirely while locked, UP TO Config.TARGET_LOCK_MAX_DIST (2026-08-13
    -- addition -- see that config's own comment for the uu-to-meters conversion this project uses): the
    -- whole point of a lock is to keep hitting the same object while walking around it or looking away,
    -- which an automatic re-pick can't do, but an UNBOUNDED lock would mean wandering off to a different
    -- part of the base and still silently editing/despawning something back where you left it -- RedFalcon
    -- asked for a leash after using it live, same reasoning the wanderer LEASH_RADIUS_UU already applies
    -- to a different feature. This is NOT the same thing as the automatic per-press target-lock CACHING
    -- tried and abandoned early in this project (see EditNearestInFront's own comment) -- that was a
    -- transparent cache meant to smooth out picking on its own and never helped; this is an explicit,
    -- visible, user-toggled pin with its own toast feedback, kept alive across a Cycle swap (the new actor
    -- inherits the lock) and auto-released (with a toast, and a specific REASON: gone vs. too far) the
    -- moment the locked actor stops existing or you walk out of range, so a stale lock can never silently
    -- eat future keypresses.
    -- The actual distance/existence rule lives in Spawner.TargetLockDistanceCheck (shared with the
    -- periodic tick Spawner.StartTargetLockTick runs while a lock is active -- see that function's own
    -- comment for why a lazy check ALONE isn't enough: it only ever fires on the NEXT keypress, so
    -- walking away and never pressing another mod key left a stale lock sitting there indefinitely).
    -- px/py/pz are passed through since this call already has them, sparing the checker its own
    -- (otherwise-needed) player-pawn lookup.
    if Spawner.lockedTarget and not ignoreLock then
        if Spawner.TargetLockDistanceCheck(px, py, pz) then
            local lt = Spawner.lockedTarget
            for i, entry in ipairs(Spawner.spawned) do
                if entry.actor == lt.actor then
                    local dist = 0.0
                    pcall(function()
                        local l = entry.actor:K2_GetActorLocation()
                        local dx, dy, ddz = l.X - px, l.Y - py, l.Z - pz
                        dist = math.sqrt(dx * dx + dy * dy + ddz * ddz)
                    end)
                    return i, entry, dist, px, py, pz, fx, fy
                end
            end
            -- Passed the distance/existence check but isn't in Spawner.spawned (shouldn't normally
            -- happen -- would mean something removed it from tracking without clearing the lock).
            -- Release here rather than silently falling through with a dangling lock still in place.
            Spawner.lockedTarget = nil
            print("[LivingBase] Target lock: released -- target no longer tracked.\n")
            pcall(function() Spawner.Toast("Target lock released (target no longer exists).", 2.5) end)
        end
        -- else: TargetLockDistanceCheck already released + toasted (gone, or out of range) -- fall
        -- through to the normal unlocked search below.
    end

    local zBand = Config.DESPAWN_FRONT_Z_UU or 250.0   -- same-floor only; don't reach through floors
    local bestI, bestD
    for i = 1, #Spawner.spawned do
        local entry = Spawner.spawned[i]
        if entry.actor and entry.actor:IsValid() then
            local dist, cosAngle, dz
            pcall(function()
                local l = entry.actor:K2_GetActorLocation()
                -- Angle test: FROM THE CAMERA, so it matches what's actually under the reticle.
                local cdx, cdy, cddz = l.X - camX, l.Y - camY, l.Z - camZ
                local cDist = math.sqrt(cdx * cdx + cdy * cdy + cddz * cddz)
                cosAngle = cDist > 0 and ((cdx * cfx + cdy * cfy + cddz * cfz) / cDist) or 1.0
                -- Range/reach test: FROM THE PLAYER'S BODY, so "how far can I reach" still tracks how
                -- close you're standing to the thing, not how far the camera boom happens to be pulled out.
                local dx, dy, ddz = l.X - px, l.Y - py, l.Z - pz
                dist = math.sqrt(dx * dx + dy * dy + ddz * ddz)
                dz   = math.abs(ddz)
            end)
            local inFront = dist and cosAngle and (cosAngle >= minViewDot or dist <= MIN_STABLE_DIST)
            if dist and inFront and dz and dist <= maxDist and dz <= zBand
               and (not bestD or dist < bestD) then bestI, bestD = i, dist end
        end
    end
    if not bestI then return nil, nil, nil, px, py, pz, fx, fy end
    return bestI, Spawner.spawned[bestI], bestD, px, py, pz, fx, fy
end

-- Spawner.ApplySexChangeToNearest(say) -- backing function for the `lbsexchange` console command
-- (main.lua). RedFalcon: "it only has to work on spawned ones" -- reuses the SAME "nearest
-- spawned actor in front, respecting target lock" picker despawn/cycle/live-edit already share
-- (findNearestSpawnInFront, just above -- MUST stay below that function in this file: it's a
-- `local function`, only visible to code that comes lexically AFTER its declaration, regardless of
-- when either function actually gets CALLED at runtime. This function originally lived up near
-- Spawner.ApplyBodySex, textually BEFORE findNearestSpawnInFront's declaration -- which silently
-- resolved the bare name to a nonexistent GLOBAL instead of the local, so every call failed with
-- "attempt to call a nil value (global 'findNearestSpawnInFront')". Confirmed via live UE4SS.log
-- error 2026-08-17. Moved here, the one place in the file guaranteed to be after the declaration.),
-- not the dev-only HOME probe ApplyBodySex's own test key used. Checks `IsBodySexChangeAvailable()`
-- FIRST (RedFalcon's explicit ask -- report clearly rather than just attempting the swap and seeing
-- what happens), reuses the confirmed-working Spawner.ApplyBodySex for the actual swap, then
-- independently re-reads GetBodySex() afterward to confirm it actually took before reporting
-- success -- matches the "confirmed genuinely stuck, not just an immediate post-write echo"
-- standard the rest of this session's live tests used. `say(msg)` is the caller's own output
-- function, so this has no dependency on UE4SS's console Ar/output-device machinery -- passed in
-- from main.lua's command handler.
function Spawner.ApplySexChangeToNearest(say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    local maxDist = Config.DESPAWN_FRONT_UU or 250.0
    local bestI, e = findNearestSpawnInFront(maxDist)
    if not bestI then
        say(string.format("Nothing within %.0fuu ahead -- walk closer / face it.", maxDist))
        return
    end
    local actor = e.actor
    local name = tostring(e.label or "actor")
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say(name .. " does not support changing sex.")
        return
    end
    local available = false
    pcall(function() available = comp:IsBodySexChangeAvailable() end)
    if not available then
        say(name .. " does not support changing sex.")
        return
    end
    local current = nil
    pcall(function() current = comp:GetBodySex() end)
    local newSex = (current == 1) and 2 or 1
    Spawner.ApplyBodySex(actor, newSex)
    local after = nil
    pcall(function() after = comp:GetBodySex() end)
    if after == newSex then
        say(string.format("%s has been switched to %s.", name, (after == 2) and "female" or "male"))
    else
        say(name .. " does not support changing sex.")
    end
end

-- Spawner.TestSwapBodySex(say) -- THROWAWAY DEV TEST (2026-08-19): does SwapBodySex bypass the
-- IsBodySexChangeAvailable() gate that blocks lbsexchange? Never called before -- found only by
-- listing R5CompositeMeshComponent's full function list (lbprobedump's dumpCompositeFunctions,
-- added this session specifically to answer this: no Set*Available/Enable* setter exists, but
-- this function was sitting right there, untested). Deliberately SKIPS the availability check --
-- that's the whole point of the test -- and targets the same nearest-in-front actor lbsexchange
-- uses. Signature unknown: tries a bare call first ("Swap" reads as a toggle, not "set to X"), and
-- if that raises a Lua error, retries with a sex-code argument matching SetCharacterSex's own
-- convention (1=Male, 2=Female) in case it actually needs a target. Reports GetBodySex() before/
-- after either way, so a silent no-op is visible even if the call itself "succeeds".
function Spawner.TestSwapBodySex(say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    local maxDist = Config.DESPAWN_FRONT_UU or 250.0
    local bestI, e = findNearestSpawnInFront(maxDist)
    if not bestI then
        say(string.format("Nothing within %.0fuu ahead -- walk closer / face it.", maxDist))
        return
    end
    local actor = e.actor
    local name = tostring(e.label or "actor")
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say(name .. " has no CompositeMeshComponent.")
        return
    end
    local available = false
    pcall(function() available = comp:IsBodySexChangeAvailable() end)
    local before = nil
    pcall(function() before = comp:GetBodySex() end)
    say(string.format("%s: IsBodySexChangeAvailable=%s, GetBodySex before=%s", name, tostring(available), tostring(before)))

    local okBare, errBare = pcall(function() comp:SwapBodySex() end)
    if not okBare then
        say("SwapBodySex() bare call FAILED: " .. tostring(errBare) .. " -- retrying with a sex-code argument.")
        local target = (before == 1) and 2 or 1
        local okArg, errArg = pcall(function() comp:SwapBodySex(target) end)
        if not okArg then
            say("SwapBodySex(" .. tostring(target) .. ") ALSO FAILED: " .. tostring(errArg))
            return
        end
    end

    local after = nil
    pcall(function() after = comp:GetBodySex() end)
    say(string.format("%s: GetBodySex after=%s (%s)", name, tostring(after),
        (after == before) and "NO CHANGE" or "CHANGED"))
end

-- listCustomizationControllers(comp) -- shared helper (2026-08-19): the unwrap-and-walk dance
-- dumpCustomizationMeshControllers uses, factored out so both Spawner.ListCustomizationControllers
-- and findMeshController (below) share one implementation instead of three near-copies. Returns a
-- plain array of {ctrl=, idx=, cur=, max=, allowed=, tag=} tables (tag may be nil for a controller
-- with no GroupCategoryId, e.g. the placeholder seen on some actor types).
local function listCustomizationControllers(comp)
    local out = {}
    local list = nil
    pcall(function() list = comp:GetCustomizationMeshControllers() end)
    if not list then return out end
    local n = 0
    pcall(function() n = list:GetArrayNum() end)
    if n == 0 then pcall(function() n = #list end) end
    for i = 1, n do
        local ctrl = nil
        pcall(function() ctrl = list[i] end)
        if ctrl == nil then pcall(function() ctrl = list:Get(i) end) end
        pcall(function() if ctrl ~= nil and type(ctrl) == "userdata" and ctrl.get then ctrl = ctrl:get() end end)
        if ctrl then
            local row = { ctrl = ctrl }
            pcall(function() row.idx = ctrl.MeshGroupIndex end)
            pcall(function() row.cur = ctrl.CurValue end)
            pcall(function() row.max = ctrl.MaxValue end)
            pcall(function() row.allowed = ctrl.bSelectionAllowed end)
            pcall(function() row.tag = ctrl.GroupCategoryId.TagName:ToString() end)
            out[#out + 1] = row
        end
    end
    return out
end

-- findMeshController(comp, which) -- matches `which` against either a plain MeshGroupIndex number
-- (so controllers with no usable tag, e.g. tag=None, are still reachable) or a category tag,
-- exact OR as a case-insensitive suffix after "Customization.UID." (so "hairs" and
-- "facial.eyebrows" both work, not just the full "Customization.UID.Hairs"). Returns the matching
-- row (see listCustomizationControllers) or nil.
local function findMeshController(comp, which)
    local wantIdx = tonumber(which)
    local wantLower = tostring(which):lower()
    for _, row in ipairs(listCustomizationControllers(comp)) do
        if wantIdx and row.idx == wantIdx then return row end
        if row.tag then
            local tagLower = row.tag:lower()
            local suffix = tagLower:match("^customization%.uid%.(.+)$") or tagLower
            if tagLower == wantLower or suffix == wantLower then return row end
        end
    end
    return nil
end

-- Spawner.ListCustomizationControllers(say) -- backing function for "lbcustomnpc get". Lists every
-- controller on the currently probed actor (run lbprobe first) -- category, current pick, how many
-- options exist, and whether it's actually editable right now. RedFalcon's own tool for exploring
-- what's available before deciding what to change, per-actor -- confirmed this session that both
-- the SET of categories and whether any given one is selectable varies a lot by actor type/state
-- (see WINDROSE_MODDING_NOTES.md §2c), so there's no substitute for checking the specific actor.
function Spawner.ListCustomizationControllers(say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    local actor = Spawner._lastProbedActor
    if not (actor and actor:IsValid()) then
        say("No valid probed target -- run lbprobe on something first.")
        return
    end
    local name = "actor"
    pcall(function() name = actor:GetClass():GetFName():ToString() end)
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say(name .. " has no CompositeMeshComponent.")
        return
    end
    local rows = listCustomizationControllers(comp)
    if #rows == 0 then
        say(name .. ": no customization controllers.")
        return
    end
    say(string.format("%s: %d controller(s):", name, #rows))
    for _, row in ipairs(rows) do
        say(string.format("  %-38s index=%s current=%s options=0..%s selectable=%s",
            row.tag or "(no category)", tostring(row.idx), tostring(row.cur), tostring(row.max), tostring(row.allowed)))
    end
end

-- Spawner.SetCustomizationController(which, newValue, say) -- backing function for "lbcustomnpc
-- set <which> <value>". `which` is matched by findMeshController (category name or plain index,
-- see its own comment). Range-checks against MaxValue and bSelectionAllowed before attempting --
-- confirmed this session those vary per actor, so this can't assume anything the actor's own
-- controller list doesn't say. Signature of SetCustomizationMeshControllerValue is (ctrl,
-- newValue) -- CONFIRMED working live 2026-08-19 (was previously a guess, tried with a
-- (MeshGroupIndex, value) fallback in case it errored; the primary guess has worked every time
-- since, so the fallback was dropped here). Re-reads the controller list from scratch afterward
-- (not the same ctrl reference) to confirm it actually stuck, same "confirmed genuinely stuck"
-- standard Spawner.ApplySexChangeToNearest already uses.
-- `actor` is an explicit parameter (2026-08-19, was Spawner._lastProbedActor internally) so
-- non-console callers (e.g. the walking-women hair preload) can target a specific just-spawned
-- actor without needing it to also be the current lbprobe target. The lbcustomnpc console command
-- (main.lua) passes Spawner._lastProbedActor itself now -- same behavior as before for that
-- caller, just the lookup moved to the call site.
function Spawner.SetCustomizationController(actor, which, newValue, say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then
        say("No valid target actor.")
        return
    end
    local name = "actor"
    pcall(function() name = actor:GetClass():GetFName():ToString() end)
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say(name .. " has no CompositeMeshComponent.")
        return
    end

    local row = findMeshController(comp, which)
    if not row then
        say(string.format("%s: no controller matching '%s'. Run 'lbcustomnpc get' to see what's available.", name, tostring(which)))
        return
    end
    if not row.allowed then
        say(string.format("%s: %s found but not currently selectable (bSelectionAllowed=false).", name, row.tag or tostring(row.idx)))
        return
    end
    local target = tonumber(newValue)
    if not target then
        say("'" .. tostring(newValue) .. "' isn't a number.")
        return
    end
    if row.max and (target < 0 or target > row.max) then
        say(string.format("%s: %s value %d out of range (0..%s).", name, row.tag or tostring(row.idx), target, tostring(row.max)))
        return
    end

    local okSet, errSet = pcall(function() comp:SetCustomizationMeshControllerValue(row.ctrl, target) end)
    if not okSet then
        say("SetCustomizationMeshControllerValue FAILED: " .. tostring(errSet))
        return
    end

    local afterRow = findMeshController(comp, which)
    local after = afterRow and afterRow.cur or nil
    say(string.format("%s: %s before=%s -> after=%s (%s)", name, row.tag or tostring(row.idx),
        tostring(row.cur), tostring(after),
        (after == target) and "CHANGED as requested" or ((after == row.cur) and "NO CHANGE" or "changed to something else")))
end

-- Spawner.SetBodyPartMesh(actor, bodyPart, meshPath, say) -- swaps the SkeletalMesh asset on
-- whichever BuildedCompositeMeshes entry matches the given BodyPart enum value (see
-- ER5BLCompositeMeshBodyPartType_V0_8_0, decoded this session from UE4SS_ObjectDump.txt -- 13 =
-- Legs, etc). Built (2026-08-19) for the "Merchant" walking-woman fix: her REAL DefaultParams
-- bakes in a body-shape-mismatched Legs piece -- confirmed by config.lua's own
-- Config.FEMALE_WALKER_OVERLAYS "Merchant" entry, which root-caused the identical symptom the
-- same day for the OLD per-piece-replace system ("a real body-shape mismatch between the
-- Walker's own skeleton and a mesh built to fit the Standing statue's body", fixed there by
-- swapping in SK_Armor_Conquistador_02_Female_Legs). This is the direct per-slot equivalent for
-- the NEW pre-build-params system, which bypasses that content-name-matched `replaces` rule
-- entirely -- addressed by BodyPart enum instead of guessing a live component's current mesh
-- name. Reuses the EXACT hide -> SetSkeletalMeshAsset/SetSkeletalMesh-fallback ->
-- SetLeaderPoseComponent rebind -> show sequence Spawner.DeCorrupt's own `replaces` rule already
-- proved safe (see its own comment, right above where didReplace is set) -- same risk profile,
-- not a new one.
function Spawner.SetBodyPartMesh(actor, bodyPart, meshPath, say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    if not (actor and actor:IsValid()) then say("no actor"); return false end
    local comp = nil
    pcall(function() comp = actor.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say("no CompositeMeshComponent on actor")
        return false
    end
    local list = nil
    pcall(function() list = comp.BuildedCompositeMeshes end)
    if not list then
        say("BuildedCompositeMeshes not readable")
        return false
    end
    local n = 0
    pcall(function() n = list:GetArrayNum() end)
    if n == 0 then pcall(function() n = #list end) end
    local wantBodyPart = tonumber(bodyPart)
    local target = nil
    for i = 1, n do
        local el = nil
        pcall(function() el = list[i] end)
        if el == nil then pcall(function() el = list:Get(i) end) end
        pcall(function() if el ~= nil and type(el) == "userdata" and el.get then el = el:get() end end)
        if el then
            local bp = nil
            pcall(function() bp = el.BodyPart end)
            if tonumber(bp) == wantBodyPart then
                pcall(function() target = el.EquippedMesh end)
                break
            end
        end
    end
    if not (target and target:IsValid()) then
        say(string.format("no BuildedCompositeMeshes entry found for BodyPart=%s", tostring(bodyPart)))
        return false
    end
    local mesh = resolveAsset(meshPath)
    if not mesh then
        say("mesh unresolved: " .. tostring(meshPath))
        return false
    end
    pcall(function() target:SetVisibility(false, false) end)
    local ok = pcall(function() target:SetSkeletalMeshAsset(mesh) end)
    if not ok then ok = pcall(function() target:SetSkeletalMesh(mesh, false) end) end
    if ok then
        pcall(function()
            local body = actor.Mesh
            if body and body:IsValid() then
                target:SetLeaderPoseComponent(body, false, false)
            end
        end)
    end
    pcall(function() target:SetVisibility(true, false) end)
    say(string.format("BodyPart=%s mesh swap %s (%s)", tostring(bodyPart), ok and "OK" or "FAILED", meshPath))
    return ok
end

-- Spawner.ProbeClassCustomization(classPath, say) -- backing function for "lbprobeclass". RedFalcon
-- asked whether the Armor.* controller breakdown could be surveyed across the class roster WITHOUT
-- spawning every actor into the world first. §7 (WINDROSE_MODDING_NOTES.md) already confirmed a
-- buildable-trader's Class Default Object owns a real, populated R5CompositeMeshComponent -- same
-- "Default__<ClassName>" object-naming trick this file already uses at getGameplayStatics()
-- (StaticFindObject("/Script/Engine.Default__GameplayStatics")). Untested territory: whether that
-- generalizes to actual PAWN classes, whose composite look this mod otherwise only ever builds via
-- an explicit runtime SetCompositeParams/build call (see WINDROSE_MODDING_NOTES.md §9) rather than
-- static class-default component setup. This function is the one cheap test for that -- resolves
-- classPath's own CDO and reads its controllers directly, no SpawnActor call anywhere. An empty/
-- zeroed result on a class that's known (via a live spawn) to have real controllers would prove the
-- CDO route doesn't generalize past the buildable-trader case; a populated result would open up
-- surveying the whole roster with zero world-load cost.
function Spawner.ProbeClassCustomization(classPath, say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    if not (classPath and classPath ~= "") then
        say("Usage: lbprobeclass <ShortName|ClassPath>")
        return
    end
    local packagePath, className = classPath:match("^(.+)%.([^%.]+)$")
    if not (packagePath and className) then
        say("'" .. tostring(classPath) .. "' doesn't look like a full /Game/... object path (need Package.ClassName_C).")
        return
    end
    -- Force the package into memory first (StaticFindObject alone misses anything not already
    -- loaded, same reason resolveClass falls back to LoadAsset) -- the CDO can't resolve if the
    -- class itself was never loaded.
    resolveClass(classPath)
    local cdoPath = packagePath .. ".Default__" .. className
    local cdo = StaticFindObject(cdoPath)
    if not (cdo and cdo:IsValid()) then
        say("Could not resolve CDO at '" .. cdoPath .. "' -- class may not exist or isn't loadable this way.")
        return
    end
    local comp = nil
    pcall(function() comp = cdo.CompositeMeshComponent end)
    if not (comp and comp:IsValid()) then
        say(className .. "'s CDO has no (valid) CompositeMeshComponent.")
        return
    end
    local rows = listCustomizationControllers(comp)
    if #rows == 0 then
        say(className .. " CDO: 0 customization controllers -- either genuinely none, or this class builds its composite at spawn-time rather than on the CDO; cross-check against a live lbprobe on an actual spawned instance before concluding either way.")
        return
    end
    say(string.format("%s CDO: %d controller(s):", className, #rows))
    for _, row in ipairs(rows) do
        say(string.format("  %-38s index=%s current=%s options=0..%s selectable=%s",
            row.tag or "(no category)", tostring(row.idx), tostring(row.cur), tostring(row.max), tostring(row.allowed)))
    end
end

-- customization_survey.jsonl -- accumulated output of Spawner.ScanNearbyCustomization, ONE JSON
-- object per line (JSON Lines, not a single JSON array) so a new scan can just APPEND -- no need to
-- re-parse and rewrite the whole file to add records, same reasoning discoveryAppend/ledgerAppend
-- already use `io.open(p, "a")` for their own accumulating logs. Same multi-candidate relative-path
-- list every other file in this section uses (UE4SS's Lua CWD isn't consistent across contexts).
local CUSTOM_SURVEY_PATHS = {
    "ue4ss/Mods/LivingBase/customization_survey.jsonl",
    "Mods/LivingBase/customization_survey.jsonl",
    "customization_survey.jsonl",
}
local function customSurveyAppend(line)
    for _, p in ipairs(CUSTOM_SURVEY_PATHS) do
        local f = io.open(p, "a")
        if f then f:write(line .. "\n"); f:close(); return true end
    end
    return false
end
-- Dedup key is CLASS+VARIANT, not the class alone (2026-08-19, RedFalcon's own catch: the first
-- Gatherer scan turned out to be a Senkamati Caster reskin WEARING the Gatherer's base class, not a
-- vanilla Gatherer -- same class, genuinely different composite state, and the class-only key would
-- have silently thrown the vanilla one away as "already known" forever). "variant" is "vanilla" for
-- anything not spawned through a recipe (wild NPCs, or a raw lbspawn of the class) or the recipe's
-- own display label (e.g. "Herbalist Woman") when Spawner.spawned's hasLook flag says one was
-- applied -- see the lookup in Spawner.ScanNearbyCustomization. Doesn't need a real JSON parser:
-- this file is ONLY ever written by customSurveyAppend below in this exact shape, so a plain pattern
-- match for the `"class"`/`"variant"` fields each line carries is enough to recover every key
-- already on file. Old lines written before "variant" existed have no such field -- they default to
-- "vanilla" here, matching what they actually were (this tool didn't distinguish recipes yet).
local function readSurveyedClasses()
    local seen = {}
    for _, p in ipairs(CUSTOM_SURVEY_PATHS) do
        local f = io.open(p, "r")
        if f then
            for line in f:lines() do
                local cls = line:match('"class"%s*:%s*"([^"]+)"')
                local variant = line:match('"variant"%s*:%s*"([^"]+)"') or "vanilla"
                local bodySex = line:match('"bodySex"%s*:%s*"([^"]+)"') or "Unknown"
                if cls then seen[cls .. "\1" .. variant .. "\1" .. bodySex] = true end
            end
            f:close()
            break
        end
    end
    return seen
end
-- comp:GetBodySex() -- same EBodySex encoding SetCharacterSex/SetCompositeParams already use
-- elsewhere in this file (1=Male/2=Female, see Spawner.ApplyBodySex's own comment). RedFalcon asked
-- to track this per record too (2026-08-19): a male- vs female-presenting spawn of the exact same
-- class+variant can carry a genuinely different controller set -- WINDROSE_MODDING_NOTES.md §2c
-- already confirmed SetCharacterSex rebuilds the whole list, not just the current picks -- so this
-- folds into the dedup key alongside class/variant, not just a label on the same record.
local function bodySexLabel(comp)
    local ok, v = pcall(function() return comp:GetBodySex() end)
    if not ok then return "Unknown" end
    local n = tonumber(v)
    if n == 1 then return "Male" end
    if n == 2 then return "Female" end
    return "Unknown(" .. tostring(v) .. ")"
end
-- Minimal escaper for the two string fields this file ever writes (class name, gameplay tag) --
-- neither can contain control characters, only backslash/quote are realistically possible (a tag
-- with a literal backslash has never been seen, guarded anyway since it's one line of code).
local function jsonEscape(s)
    return tostring(s):gsub('[\\"]', "\\%0")
end

-- Spawner.ScanNearbyCustomization(radius, say) -- backing function for "lbcustomscan". RedFalcon's
-- follow-up to Spawner.ProbeClassCustomization's CDO dead-end: since a pawn's controller list only
-- exists once something is actually spawned, survey whatever's ALREADY standing nearby (placed via
-- lbspawn/lblook, or just wandering wild NPCs) in one pass instead of probing one at a time via
-- lbprobe+lbcustomnpc. Deliberately a plain RADIUS sweep around the player pawn, not the camera-cone
-- targeting findNearestSpawnInFront/ProbeNearestActor use -- this wants everything nearby, not just
-- what's currently in view. Reuses the same FindAllOf("Actor")+exclude-Controllers sweep
-- ProbeNearestActor already does (see that function's own comment for why Controllers must be
-- excluded by IsA(), not by name). Records, per NEW class only (skips anything already in
-- customization_survey.jsonl from a prior scan): every controller row (same shape as "lbcustomnpc
-- get") PLUS the four IsX...Available() flags (dumpCustomizability's own set) -- folding sex-change
-- availability into the same record since RedFalcon asked for it alongside the controller data,
-- and it's a free read off the same component.
function Spawner.ScanNearbyCustomization(radius, say)
    say = say or function(m) print("[LivingBase] " .. tostring(m) .. "\n") end
    radius = tonumber(radius) or 5000.0

    local pawn
    local px, py, pz
    pcall(function()
        local pc = UEHelpers.GetPlayerController()
        pawn = pc and pc:IsValid() and pc.Pawn
        if pawn and pawn:IsValid() then
            local l = pawn:K2_GetActorLocation()
            px, py, pz = l.X, l.Y, l.Z
        end
    end)
    if not px then
        say("No player pawn available -- aborting.")
        return
    end

    local controllerClass
    pcall(function() controllerClass = StaticFindObject("/Script/Engine.Controller") end)

    local list
    local ok = pcall(function() list = FindAllOf("Actor") end)
    if not (ok and list) then
        say("FindAllOf('Actor') returned nothing.")
        return
    end
    local n = 0
    pcall(function() n = list:GetArrayNum() end)
    if n == 0 then pcall(function() n = #list end) end

    local alreadySeen = readSurveyedClasses()
    local seenThisRun = {}
    local scanned, recorded, skippedDupe, skippedNoComp = 0, 0, 0, 0

    for i = 1, n do
        local a = list[i]
        if not a then pcall(function() a = list:Get(i) end) end
        local isController = false
        if a and controllerClass then pcall(function() isController = a:IsA(controllerClass) end) end
        if a and a:IsValid() and not isController then
            local dist
            pcall(function()
                local l = a:K2_GetActorLocation()
                local dx, dy, dz = l.X - px, l.Y - py, l.Z - pz
                dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            end)
            if dist and dist <= radius then
                local comp
                pcall(function() comp = a.CompositeMeshComponent end)
                if comp and comp:IsValid() then
                    scanned = scanned + 1
                    local className = "?"
                    pcall(function() className = a:GetClass():GetFName():ToString() end)
                    -- Was this actor spawned through one of this mod's own recipes, or is it vanilla
                    -- (a wild NPC, or a raw lbspawn)? Spawner.spawned's hasLook flag (set at spawn
                    -- time in Spawner.Spawn) is the precise signal -- not the label string, which
                    -- exists for every tracked spawn regardless of whether a recipe was applied.
                    local variant = "vanilla"
                    for _, entry in ipairs(Spawner.spawned) do
                        if entry.actor == a then
                            if entry.hasLook and entry.label then variant = entry.label end
                            break
                        end
                    end
                    local bodySex = bodySexLabel(comp)
                    local key = className .. "\1" .. variant .. "\1" .. bodySex
                    if alreadySeen[key] or seenThisRun[key] then
                        skippedDupe = skippedDupe + 1
                    else
                        seenThisRun[key] = true
                        local rows = listCustomizationControllers(comp)
                        local function callBool(name)
                            local okc, v = pcall(function() return comp[name](comp) end)
                            if not okc then return "null" end
                            return v and "true" or "false"
                        end
                        local parts = {}
                        for _, row in ipairs(rows) do
                            parts[#parts + 1] = string.format(
                                '{"tag":%s,"index":%s,"current":%s,"max":%s,"selectable":%s}',
                                row.tag and ('"' .. jsonEscape(row.tag) .. '"') or "null",
                                row.idx ~= nil and tostring(row.idx) or "null",
                                row.cur ~= nil and tostring(row.cur) or "null",
                                row.max ~= nil and tostring(row.max) or "null",
                                row.allowed ~= nil and tostring(row.allowed) or "null")
                        end
                        local record = string.format(
                            '{"class":"%s","variant":"%s","bodySex":"%s","scannedAt":"%s","distance":%d,'
                            .. '"characterCustomizable":%s,"customizationEditActive":%s,'
                            .. '"bodyTypeChangeAvailable":%s,"bodySexChangeAvailable":%s,"controllers":[%s]}',
                            jsonEscape(className), jsonEscape(variant), jsonEscape(bodySex),
                            os.date("%Y-%m-%d %H:%M:%S"), math.floor(dist),
                            callBool("IsCharacterCustomizable"),
                            callBool("IsCustomizationEditActive"),
                            callBool("IsBodyTypeChangeAvailable"),
                            callBool("IsBodySexChangeAvailable"),
                            table.concat(parts, ","))
                        if customSurveyAppend(record) then
                            recorded = recorded + 1
                            say(string.format("  + %s [%s/%s] (%d controller(s), %.0fuu)", className, variant, bodySex, #rows, dist))
                        else
                            say("  FAILED to write record for " .. className .. " -- could not open customization_survey.jsonl")
                        end
                    end
                else
                    skippedNoComp = skippedNoComp + 1
                end
            end
        end
    end

    say(string.format("Scan done: %d actor(s) with a composite mesh within %.0fuu, %d new class(es) recorded, %d already-known class(es) skipped.",
        scanned, radius, recorded, skippedDupe))
end

-- Spawner.ToggleTargetLock() — Num+ toggle (see Spawner.lockedTarget's own comment inside
-- findNearestSpawnInFront for what a lock DOES). This function only decides ON vs OFF and picks
-- what to lock onto; the actual "make every other action use it" behavior lives entirely in that one
-- shared picker, so nothing else needed to change to support this.
--------------------------------------------------------------------
-- ON: does the exact same cone/range pick despawn/edit/cycle already use (LIVE_EDIT_MAX_DIST, same
-- camera-based cone) — locking targets whatever those keys would already have hit, so there's no
-- separate/different "what counts as in front of me" rule to learn. OFF: just clears the pin; every
-- action goes back to picking fresh each press, same as before this feature existed.
-- Raycast is now the ONLY source for acquiring a target lock (2026-08-20, RedFalcon: "with raytrace
-- we dont need the cone. we're locking live edit to targets only" / "we should use ray trace as the
-- visual truth now its faster and more accurate"). Previously fell back to findNearestSpawnInFront's
-- cone/radius sweep whenever nothing was hovered -- a SECOND, independently-sourced pick with its own
-- origin/range, which is exactly what made target-lock's effective reach diverge from hover-highlight's
-- even with matching Config.LIVE_EDIT_MAX_DIST numbers (RedFalcon: "target and highlight should be
-- synced both by source and by distance... it doesnt make sense otherwise"). With the raycast as the
-- only source, that divergence can't happen: whatever's currently lit up (Spawner._hoverActor) IS the
-- only thing + can lock onto. No fallback -- if nothing's hovered, there's nothing to lock onto, full
-- stop. This only ever runs with the SpawnMenu window open anyway (targetLock is windowGatedAction'd),
-- same gate hover-highlight itself runs under, so the raycast is always live by the time this is
-- called. Deliberately NOT a change to findNearestSpawnInFront itself -- despawn/cycle still use it
-- directly and are untouched by this. Returns the same (bestI, e) shape findNearestSpawnInFront does
-- (bestI just a truthy marker here, not a real index -- nothing reads it as one).
local function pickTargetPreferringHover()
    local hovered = Spawner._hoverActor
    if hovered and hovered:IsValid() then
        local hoverPath = actorInstancePath(hovered)
        if hoverPath then
            for _, e in ipairs(Spawner.spawned) do
                if e.actor and e.actor:IsValid() and actorInstancePath(e.actor) == hoverPath then
                    return true, e
                end
            end
        end
    end
    return false, nil
end

function Spawner.ToggleTargetLock()
    print("[LivingBase] target-lock key received.\n")
    if Spawner.lockedTarget then
        -- Already locked: RedFalcon asked (2026-08-16) for pressing + on a DIFFERENT object to just
        -- retarget in one press, instead of needing unlock-then-relock (two presses). Raycast-only pick
        -- (see pickTargetPreferringHover's own comment), so this is whatever's hovered right now, not
        -- the same locked actor being handed back again.
        local bestI, e = pickTargetPreferringHover()
        if bestI and e.actor ~= Spawner.lockedTarget.actor then
            local oldLabel = Spawner.lockedTarget.label
            Spawner.lockedTarget = { actor = e.actor, label = e.label, class = e.class }
            print("[LivingBase] Target lock moved: " .. tostring(oldLabel) .. " -> " .. tostring(e.label) .. ".\n")
            pcall(function() Spawner.Toast("Target lock moved to: " .. tostring(e.label), 2.5) end)
            -- _targetLockTickRunning is already true from the original lock (never released here) --
            -- no need to call Spawner.StartTargetLockTick() again, its next tick reads
            -- Spawner.lockedTarget fresh and will already see the new actor.
            return
        end
        -- Aiming at the SAME object still, or nothing new to switch to: falls through to the
        -- original "any press while locked just unlocks" behavior.
        local label = Spawner.lockedTarget.label
        Spawner.lockedTarget = nil
        print("[LivingBase] Target lock OFF (was: " .. tostring(label) .. ").\n")
        pcall(function() Spawner.Toast("Target lock OFF: " .. tostring(label), 2.5) end)
        return
    end
    local bestI, e = pickTargetPreferringHover()
    if not bestI then
        print("[LivingBase] Target lock: nothing hovered to lock onto.\n")
        pcall(function() Spawner.Toast("Target lock: nothing in front to lock onto.", 2.5) end)
        return
    end
    Spawner.lockedTarget = { actor = e.actor, label = e.label, class = e.class }
    print("[LivingBase] Target lock ON: " .. tostring(e.label) .. ".\n")
    pcall(function() Spawner.Toast("Target lock ON: " .. tostring(e.label) .. " — despawn/cycle/live-edit now act on it.", 3.0) end)
    Spawner.StartTargetLockTick()
end

-- Spawner.TargetLockDistanceCheck(px, py, pz) — the actual "still good?" rule for a lock: shared by
-- BOTH the lazy check inside findNearestSpawnInFront (every despawn/cycle/live-edit press re-validates
-- the lock too, so a target going bad the instant before a press is still caught right then) AND the
-- periodic tick below (so walking away and pressing nothing else STILL releases it -- see that tick's
-- own comment for why the lazy check alone wasn't enough). px/py/pz are OPTIONAL: findNearestSpawnInFront
-- already has the player's position and passes it through to skip a redundant lookup; the tick has
-- nothing to reuse, so it's looked up here when omitted. Returns true if the lock is still fine (or
-- there simply isn't one -- nothing to do), false if it JUST got released -- in which case this
-- function has already printed/toasted the reason itself, so no caller needs to.
function Spawner.TargetLockDistanceCheck(px, py, pz)
    local lt = Spawner.lockedTarget
    if not lt then return true end
    local releaseReason = nil
    if lt.actor and lt.actor:IsValid() then
        if not px then
            pcall(function()
                local pc = UEHelpers.GetPlayerController()
                local pawn = pc and pc:IsValid() and pc.Pawn
                if pawn and pawn:IsValid() then
                    local l = pawn:K2_GetActorLocation()
                    px, py, pz = l.X, l.Y, l.Z
                end
            end)
        end
        if not px then return true end   -- no pawn right now (loading/menu) -- don't release on a transient miss
        if Spawner.suspendTargetLockDistanceCheck then return true end   -- Coords window open -- see its own flag comment above
        local dist = 0.0
        pcall(function()
            local l = lt.actor:K2_GetActorLocation()
            local dx, dy, dz = l.X - px, l.Y - py, l.Z - pz
            dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        end)
        local maxLockDist = Config.TARGET_LOCK_MAX_DIST or 1500.0
        if dist <= maxLockDist then return true end
        releaseReason = string.format("walked %.0fm away (lock range %.0fm)", dist / 100.0, maxLockDist / 100.0)
    else
        releaseReason = "target no longer exists"
    end
    Spawner.lockedTarget = nil
    print("[LivingBase] Target lock: released -- " .. releaseReason .. ".\n")
    pcall(function() Spawner.Toast("Target lock released (" .. releaseReason .. ").", 2.5) end)
    return false
end

-- Spawner.SetLockedTargetTransform(x, y, z, pitch, yaw, roll) -- writes an ABSOLUTE transform to
-- the currently locked target, for the LivingBaseSpawnMenu Coords window's Preview/Apply/Reset/
-- Cancel (2026-08-16, extended to full pitch/yaw/roll 2026-08-18; all four buttons end up calling
-- this, just with different values -- Preview/Apply send whatever's typed, Reset/Cancel send the
-- opening snapshot back). Deliberately separate from Spawner.EditNearestInFront -- that one
-- applies a RELATIVE delta to whatever's targeted/in-front (keyboard/move-panel nudging); this one
-- sets an absolute position on the LOCKED target specifically (Coords editing only makes sense
-- against an explicit lock, never an ad-hoc "nearest in front" pick that could silently change
-- between typing and pressing Apply).
-- No SetActorHiddenInGame visibility-toggle here -- CONFIRMED (2026-08-16, see that function's own
-- comment) that toggle was the actual cause of a real crash under sustained rapid calls, and
-- Spawner.MakeMovable alone is sufficient for the mesh to visually update.
function Spawner.SetLockedTargetTransform(x, y, z, pitch, yaw, roll)
    local lt = Spawner.lockedTarget
    if not (lt and lt.actor and lt.actor:IsValid()) then
        return false, "no locked target"
    end
    pitch, roll = pitch or 0.0, roll or 0.0
    pcall(function() Spawner.MakeMovable(lt.actor) end)
    local ok = pcall(function()
        lt.actor:K2_SetActorLocation({ X = x, Y = y, Z = z }, false, {}, true)
        lt.actor:K2_SetActorRotation({ Pitch = pitch, Yaw = yaw, Roll = roll }, false)
    end)
    if not ok then
        return false, "transform write failed"
    end
    -- Persist sync, same pattern as Spawner.EditNearestInFront: find this actor's own tracked
    -- entry, correct persist.txt's record of it, then update our own copy of its home/yaw so the
    -- NEXT edit (Cycle/Replace/Edit/another Coords apply) starts from the right place.
    for _, entry in ipairs(Spawner.spawned) do
        if entry.actor == lt.actor then
            pcall(function() Spawner.PersistUpdatePose(entry.class, entry.home, { X = x, Y = y, Z = z }, yaw, pitch, roll) end)
            entry.home = { X = x, Y = y, Z = z }
            entry.yaw = yaw
            break
        end
    end
    return true
end

-- Periodic distance check while a lock is active (2026-08-13, added after RedFalcon found the LAZY check
-- alone wasn't enough in practice: it only ever runs on the NEXT despawn/cycle/live-edit press, so
-- walking far away and not touching any other mod key left the lock sitting there indefinitely --
-- confirmed in ue4ss.log: locked on, walked off, nothing fired until RedFalcon manually pressed Num+ again
-- a minute later). Self-terminating rather than an always-on background loop: each tick only
-- reschedules ANOTHER tick if the lock is STILL set afterward, so this runs only while a lock is
-- actually active and stops itself the moment it isn't -- deliberately NOT the same shape as
-- Spawner.LeashTick's own always-on loop (registered once, unconditionally, forever, cheap-no-op while
-- idle) elsewhere in this mod; that pattern was rejected here specifically to avoid a forever-running
-- timer for a feature that's off far more than it's on. Same self-rescheduling-only-while-there's-
-- live-work shape as Spawner._activeToasts' own ticker (see CLAUDE.md item 24).
Spawner._targetLockTickRunning = false
local function targetLockTick()
    if not Spawner.lockedTarget then
        Spawner._targetLockTickRunning = false
        return   -- lock is gone (released by ANY path) -- stop rescheduling, zero further background cost
    end
    Spawner.TargetLockDistanceCheck()
    if Spawner.lockedTarget and ExecuteWithDelay then
        ExecuteWithDelay(Config.TARGET_LOCK_CHECK_MS or 2000, targetLockTick)
    else
        Spawner._targetLockTickRunning = false
    end
end

-- Spawner.StartTargetLockTick() — called once, by Spawner.ToggleTargetLock, the moment a lock is newly
-- established. `_targetLockTickRunning` guards against a duplicate overlapping loop (not expected in
-- normal play -- turning ON while already locked goes through ToggleTargetLock's "already locked ->
-- release" branch instead -- but cheap to guard explicitly rather than relying on that invariant alone).
function Spawner.StartTargetLockTick()
    if Spawner._targetLockTickRunning or not ExecuteWithDelay then return end
    Spawner._targetLockTickRunning = true
    ExecuteWithDelay(Config.TARGET_LOCK_CHECK_MS or 2000, targetLockTick)
end

-- Spawner.ReleaseTargetLockIfDestroyed(actor) — call right after destroying ANY actor that might be
-- the current target lock (despawn, DEL clean-house, undo destroying a cycle's replacement) so the
-- lock is released IMMEDIATELY and visibly, not just lazily the next time a live-edit/despawn/cycle
-- key happens to be pressed. findNearestSpawnInFront's own lazy fallback (see its comment) still
-- exists as a backstop for anything that destroys a locked actor without going through this helper —
-- this just makes the common cases (you despawn what you locked) give immediate feedback instead of
-- a delayed one on your NEXT keypress. No-op (returns false) if `actor` isn't the locked target, so
-- every call site can call this unconditionally without checking first.
function Spawner.ReleaseTargetLockIfDestroyed(actor)
    if not (Spawner.lockedTarget and actor and Spawner.lockedTarget.actor == actor) then return false end
    local label = Spawner.lockedTarget.label
    Spawner.lockedTarget = nil
    print("[LivingBase] Target lock released (target despawned): " .. tostring(label) .. ".\n")
    pcall(function() Spawner.Toast("Target lock released (target despawned).", 2.5) end)
    return true
end

function Spawner.DespawnNearestInFront(maxDist)
    maxDist = maxDist or 700.0
    -- Fires FIRST, unconditionally (not gated behind Config.VERBOSE like the log() calls below) — so
    -- ue4ss.log proves every Num9 press that actually reached this function, even with VERBOSE off. If a
    -- physical press doesn't produce this line at all, it never got this far: either the engine dropped
    -- the keydown, or the shared spawnBusy debounce in main.lua's bind() (300ms, shared across every
    -- spawn/despawn key) swallowed it.
    print("[LivingBase] despawn-in-front key received.\n")
    local bestI, entry, bestD = findNearestSpawnInFront(maxDist)
    if not bestI then

        -- Log only (unconditional, per project convention) -- no on-screen toast for "nothing to despawn",
        -- since it's the common case when just casually pressing Num9 while not actually facing anything.
        print(string.format("[LivingBase] Despawn-in-front: nothing within %.0fuu ahead.\n", maxDist))
        return
    end
    -- No generation bump: this despawns ONE actor. Bumping the wipe marker here silently cancelled
    -- pending post-spawn work (shield, dark hair, de-corrupt) on every other live spawn. The
    -- despawned actor drops out of Spawner.spawned, so its own callbacks bail via IsTracked().
    local undoPos, undoYaw
    pcall(function()
        local l = entry.actor:K2_GetActorLocation()
        local r = entry.actor:K2_GetActorRotation()
        undoPos = { X = l.X, Y = l.Y, Z = l.Z }
        undoYaw = r.Yaw
    end)
    -- VALIDATE against persist.txt before removing anything: find the saved record for this exact
    -- class + spawn position and log it explicitly, so there's a concrete, checkable record of what's
    -- about to be deleted (not just "trust the in-memory pick"). Its extra fields (AI controller,
    -- composite look/preset) also aren't captured by the live actor's transform alone, so pull them in
    -- for a full-fidelity undo — otherwise a re-skinned crew member would come back with a fresh random
    -- look instead of the one it actually had.
    local persisted = Spawner.PersistFindMatching(entry.class, entry.home)
    if persisted then
        print(string.format("[LivingBase] Persist match: %s at (%.1f,%.1f,%.1f) yaw=%.1f — confirmed, removing.\n",
            persisted.classPath, persisted.X, persisted.Y, persisted.Z, persisted.yaw))
    else
        print("[LivingBase] Persist match: none found (spawn may not have been saved yet, or was TRANSIENT) — removing live actor only.\n")
    end
    if undoPos then
        Spawner.PushUndo({ {
            class = entry.class, label = entry.label, pos = undoPos, yaw = undoYaw,
            aiPath = persisted and persisted.aiPath, makeFriendly = persisted and persisted.makeFriendly,
            look = persisted and persisted.look,
        } })
    end
    local wasLocked = entry.actor
    pcall(function() entry.actor:K2_DestroyActor() end)
    table.remove(Spawner.spawned, bestI)
    Spawner.PersistRemoveMatching(entry.class, entry.home)
    print(string.format("[LivingBase] Despawned in front (%.0fuu): %s\n", bestD, tostring(entry.label)))
    pcall(function() Spawner.Toast(string.format("Despawned: %s", tostring(entry.label)), 2.0) end)
    Spawner.ReleaseTargetLockIfDestroyed(wasLocked)
end

-- Spawner.DespawnActor(actor) -- destroy ONE specific actor by REFERENCE (not by
-- proximity to the player, unlike DespawnNearestInFront above) and remove its tracking/
-- persist.txt entry the same way. For automated callers that need to despawn a specific
-- actor they already hold a reference to (e.g. Testbed.ApplyFemaleReskinTarget's topless
-- retry, 2026-08-11) rather than "whatever's nearest". No undo push, no toast -- an
-- automated respawn isn't a user action to offer undo on. Returns {class, home={X,Y,Z},
-- yaw} (what's needed to respawn at the same spot) or nil if the actor wasn't tracked.
function Spawner.DespawnActor(actor)
    if not (actor and actor:IsValid()) then return nil end
    local idx, entry = nil, nil
    for i, e in ipairs(Spawner.spawned) do
        if e.actor == actor then idx, entry = i, e; break end
    end
    if not entry then return nil end
    pcall(function() actor:K2_DestroyActor() end)
    table.remove(Spawner.spawned, idx)
    pcall(function() Spawner.PersistRemoveMatching(entry.class, entry.home) end)
    Spawner.ReleaseTargetLockIfDestroyed(actor)
    return { class = entry.class, home = entry.home, yaw = entry.yaw }
end

--- Spawner.PersistUpdatePose(classPath, loc, newLoc, newYaw) — rewrite the position + yaw of the
--- persisted line nearest `loc`, keeping every other field (ai, friendly, composite look) intact, so a
--- live-edited pose survives a reload without losing appearance. `newLoc` may be a table {X,Y,Z} (moves
--- the prop) or a plain number (Z only, keeps X/Y). Lossless in-place edit.
-- newPitch/newRoll (2026-08-18, optional): fields 14/15, full 3-axis rotation for props that can
-- rest at any angle -- see Spawner.EditNearestInFront's own comment. Omitted callers (nil) leave
-- those fields untouched on an existing line, so any caller that only ever cared about yaw (there
-- aren't any left after this session's edits, but keeping the params optional costs nothing) can't
-- accidentally zero out a pitch/roll some OTHER caller had already set.
function Spawner.PersistUpdatePose(classPath, loc, newLoc, newYaw, newPitch, newRoll)
    if not (classPath and loc) then return false end
    local lines = persistReadLines()
    local bestI, bestD, bestParts
    for i, line in ipairs(lines) do
        local parts = {}
        for f in (line .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = f end
        if parts[1] == classPath and tonumber(parts[2]) then
            local x, y, z = tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
            local d = (x - loc.X) ^ 2 + (y - loc.Y) ^ 2 + (z - loc.Z) ^ 2
            if not bestD or d < bestD then bestI, bestD, bestParts = i, d, parts end
        end
    end
    if not bestI then return false end
    if type(newLoc) == "table" then
        bestParts[2] = string.format("%.1f", newLoc.X)  -- X
        bestParts[3] = string.format("%.1f", newLoc.Y)  -- Y
        bestParts[4] = string.format("%.1f", newLoc.Z)  -- Z
    else
        bestParts[4] = string.format("%.1f", newLoc)    -- Z only (keeps X/Y)
    end
    bestParts[6] = string.format("%.1f", newYaw)   -- yaw
    if newPitch or newRoll then
        -- Pad any gap up through field 13 first (same defensive reasoning as
        -- Spawner.PersistUpdateLabel's own field 8-12 padding) so setting 14/15 directly after
        -- never leaves a hole table.concat can't handle.
        for f = 7, 13 do
            if bestParts[f] == nil then bestParts[f] = "" end
        end
        if newPitch then bestParts[14] = string.format("%.1f", newPitch) end
        if newRoll then bestParts[15] = string.format("%.1f", newRoll) end
    end
    lines[bestI] = table.concat(bestParts, "|")
    persistWriteLines(lines)
    return true
end

--- Spawner.PersistUpdateLabel(classPath, loc, newLabel) — rewrite (or add) field 13 of the persisted
--- line nearest `loc` to newLabel, keeping every other field intact. Used ONLY by restoreOne to
--- migrate a pre-1.3.11 persist.txt line that never recorded an instance label (see
--- Spawner.NextInstanceLabel's own comment) -- once migrated, the SAME resolved label sticks on the
--- next reload instead of being re-derived (and potentially re-numbered) every time.
function Spawner.PersistUpdateLabel(classPath, loc, newLabel)
    if not (classPath and loc and newLabel) then return false end
    local lines = persistReadLines()
    local bestI, bestD, bestParts
    for i, line in ipairs(lines) do
        local parts = {}
        for f in (line .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = f end
        if parts[1] == classPath and tonumber(parts[2]) then
            local x, y, z = tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
            local d = (x - loc.X) ^ 2 + (y - loc.Y) ^ 2 + (z - loc.Z) ^ 2
            if not bestD or d < bestD then bestI, bestD, bestParts = i, d, parts end
        end
    end
    if not bestI then return false end
    -- Fields 8-12 (composite look) may not exist at all on a very old line -- pad with empty
    -- strings first so setting field 13 directly after never leaves a gap table.concat can't handle.
    for f = 8, 12 do
        if bestParts[f] == nil then bestParts[f] = "" end
    end
    bestParts[13] = newLabel
    lines[bestI] = table.concat(bestParts, "|")
    persistWriteLines(lines)
    return true
end

-- Spawner.PersistUpdateLootMesh(classPath, loc, meshPath) — writes field 16 (2026-08-19, RedFalcon's
-- bug report: "Drops decor is in persist.txt but doesn't load"). ROOT CAUSE: Testbed.placeDecorEntry
-- calls Spawner.SetLootMesh AFTER Spawner.Spawn already returns and already wrote the persist line --
-- persistAppend (called from inside Spawner.Spawn itself) has no way to know the mesh path at that
-- point, so it was never recorded at all, and restoreOne/RestoreHook had nothing to reapply it from
-- -- a restored drop-decor actor spawned as a bare, unresolved R5LootActor with NO mesh assigned,
-- genuinely invisible (see Spawner.SetLootMesh's own comment: this class's mesh is normally only
-- populated by a real drop event, never baked into the class itself). Same "match by classPath +
-- nearest location, then rewrite one field" pattern as Spawner.PersistUpdatePose/PersistUpdateLabel
-- above -- called separately, right after the live SetLootMesh call succeeds, to backfill the ALREADY-
-- written persist line with the one piece of data it was missing.
function Spawner.PersistUpdateLootMesh(classPath, loc, meshPath)
    if not (classPath and loc and meshPath and meshPath ~= "") then return false end
    local lines = persistReadLines()
    local bestI, bestD, bestParts
    for i, line in ipairs(lines) do
        local parts = {}
        for f in (line .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = f end
        if parts[1] == classPath and tonumber(parts[2]) then
            local x, y, z = tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
            local d = (x - loc.X) ^ 2 + (y - loc.Y) ^ 2 + (z - loc.Z) ^ 2
            if not bestD or d < bestD then bestI, bestD, bestParts = i, d, parts end
        end
    end
    if not bestI then return false end
    -- Fields 8-15 may not exist at all on an older line -- pad with empty strings first so setting
    -- field 16 directly after never leaves a gap table.concat can't handle.
    for f = 8, 15 do
        if bestParts[f] == nil then bestParts[f] = "" end
    end
    bestParts[16] = meshPath
    lines[bestI] = table.concat(bestParts, "|")
    persistWriteLines(lines)
    return true
end

--------------------------------------------------------------------
-- Spawner.MakeMovable(actor) — flip an actor's scene components from Static to Movable so runtime
-- SetActorLocation/Rotation actually moves the RENDERED mesh. World props (nests, mushrooms, wrecks)
-- are placed as Static primitives: at runtime SetActorLocation updates the actor's logical transform
-- (GetActorLocation reads back the new value) but a Static component's render transform is baked at
-- registration, so the mesh never visibly moves. THIS is why live-edit "did nothing on screen" while
-- the log showed the Z climbing. EComponentMobility::Movable = 2.
--------------------------------------------------------------------
function Spawner.MakeMovable(actor)
    if not (actor and actor:IsValid()) then return end
    pcall(function()
        local root = actor:K2_GetRootComponent()
        if root and root:IsValid() then root:SetMobility(2) end
    end)
    -- Also any StaticMeshComponents/SkeletalMeshComponents that aren't the root (the visible mesh is
    -- often a child, and a Static child ignores the parent's runtime move on the render thread too).
    -- SkeletalMeshComponent added 2026-08-21, extending the build-ghost-preview follow to statues
    -- (AnimatedActor/QuestStatic classes -- see EditNearestInFront's own comment) -- their visible
    -- mesh is a skeletal mesh, not a static one, so the original StaticMeshComponent-only sweep would
    -- have silently missed it, same class of "mesh doesn't pick up the move" bug this function exists
    -- to prevent, just for a different component type. Same dual-class pattern ApplyGhostMaterial
    -- already uses for exactly this reason. Try both UE4SS method spellings for the class lookup.
    pcall(function()
        for _, className in ipairs({ "StaticMeshComponent", "SkeletalMeshComponent" }) do
            local mcClass = StaticFindObject("/Script/Engine." .. className)
            if mcClass and mcClass:IsValid() then
                local comps
                pcall(function() comps = actor:GetComponentsByClass(mcClass) end)
                if not comps then pcall(function() comps = actor:K2_GetComponentsByClass(mcClass) end) end
                if comps then
                    for i = 1, #comps do
                        local c = comps[i]
                        pcall(function() if c ~= nil and type(c) == "userdata" and c.get then c = c:get() end end)
                        if c and c:IsValid() then pcall(function() c:SetMobility(2) end) end
                    end
                end
            end
        end
    end)
end

-- Run fn on every StaticMeshComponent of an actor (root handled separately by callers).
local function forEachStaticMesh(actor, fn)
    pcall(function()
        local smcClass = StaticFindObject("/Script/Engine.StaticMeshComponent")
        if not smcClass then return end
        local comps
        pcall(function() comps = actor:GetComponentsByClass(smcClass) end)
        if not comps then pcall(function() comps = actor:K2_GetComponentsByClass(smcClass) end) end
        if not comps then return end
        for i = 1, #comps do
            local c = comps[i]
            if c and c:IsValid() then pcall(function() fn(c) end) end
        end
    end)
end

-- Spawner.SetDecorSolid(actor) — turn a decoration into a SOLID prop the player collides with, while
-- FREEZING physics so it can never eject or drop. Collision was originally disabled because a buried,
-- physics-simulating prop got shoved upward by depenetration; with zoffset=0 (root on the floor) and
-- simulation off, that can't happen — so we can safely leave collision on.
--------------------------------------------------------------------
function Spawner.SetDecorSolid(actor)
    if not (actor and actor:IsValid()) then return end
    pcall(function() actor:SetActorEnableCollision(true) end)
    pcall(function()
        local root = actor:K2_GetRootComponent()
        if root and root:IsValid() then pcall(function() root:SetSimulatePhysics(false) end) end
    end)
    forEachStaticMesh(actor, function(c) c:SetSimulatePhysics(false) end)
end

-- setPlacementPhysics(actor, on) / PLACEMENT_MIN_PHYSICS_DIST -- shared by beginFollowLoop's tick
-- and Spawner.TogglePlacementPhysics below -- declared here, ABOVE beginFollowLoop, so tick() can
-- see it (Lua locals are only visible to code declared AFTER them in the file -- see this file's own
-- "Lua scoping gotcha" precedent).
-- REVERTED collision-toggles-with-physics (2026-08-20) -- briefly tried re-enabling collision
-- alongside physics + a swept move so the object could actually react to the floor, CONFIRMED LIVE
-- to make it "freak out, vibrate, and then stop moving" (see beginFollowLoop's own tick() comment for
-- the full diagnosis: the physics engine and the per-tick forced move became two fighting authorities
-- over the same transform). The swept move is reverted to a plain teleport; collision here is
-- reverted right back to NOT toggling at all, staying off for the whole follow like it always did --
-- an UNTESTED "collision-on but teleport-only" combination isn't worth risking live right after an
-- actual instability, when the properly safe fix is a real redesign (see that same comment), not
-- another quick toggle. This makes physics ON functionally inert again while still being
-- followed -- confirmed stable, matches RedFalcon's very first test of this feature.
local PLACEMENT_MIN_PHYSICS_DIST = 500.0
local function setPlacementPhysics(actor, on)
    Spawner._placementPhysicsOn = on
    pcall(function()
        local root = actor:K2_GetRootComponent()
        if root and root:IsValid() then root:SetSimulatePhysics(on) end
    end)
    pcall(function() forEachStaticMesh(actor, function(c) c:SetSimulatePhysics(on) end) end)
end

-- Fixed GetActorBounds call (2026-08-21) -- CONFIRMED LIVE: the single-arg form
-- (actor:GetActorBounds(false)) throws "UFunction expected 4 parameters, received 1" in this UE4SS
-- build. Origin/BoxExtent are Out params (2nd/3rd of 4) that need pre-allocated tables passed in --
-- same class of fix as the spring-arm SweepHitResult issue found earlier this session
-- (Spawner.ApplyPlacementCameraOffset), just not yet worked out for THIS function. testbed.lua's
-- playerFloorZ()/snapToFloor call the broken single-arg form too and have ALWAYS silently fallen
-- through to a rough approximation instead (pawn Z minus ~90) -- which is why one statue floor-
-- locked fine with that flat guess and another ("he's above the surface... none of the others have
-- that issue") didn't: different statue poses bake in different pivot-to-feet offsets, so no single
-- flat constant works for all of them. This does the real bounds read instead. Returns the actor's
-- own bounding-box-bottom Z, or nil on failure.
-- DECLARED HERE, above beginFollowLoop (2026-08-21) -- an earlier version of this and the three
-- helpers below it were declared AFTER beginFollowLoop, which itself calls them from inside tick() --
-- confirmed live to throw "attempt to call a nil value (global 'findFloorBelow')", the exact same
-- "Lua scoping gotcha" this file's own history already documents elsewhere (a local is only visible
-- to code declared AFTER it, textually, regardless of call order at runtime).
local function actorBoundsBottomZ(actor)
    if not (actor and actor:IsValid()) then return nil end
    local origin, extent = {}, {}
    local ok = pcall(function() actor:GetActorBounds(false, origin, extent, false) end)
    if ok and origin.Z and extent.Z then return origin.Z - extent.Z end
    return nil
end

-- How far the actor's VISUAL BOUNDS CENTER sits from its own pivot, in world-aligned axes (2026-08-21,
-- RedFalcon: "the anchor that the object... is kind of off. Like i grab the chest... its a lot lower
-- than the target point"). Decor placement/grab was setting the raw PIVOT to the aim point with zero
-- compensation -- if an asset's pivot isn't at its visual center (common: pivot at the base, or
-- wherever the original modeler put it), the aim point and the visible object drift apart by exactly
-- that offset. RedFalcon's choice (asked directly): CENTER, not bottom like statues -- decor floats
-- freely rather than floor-locking, so "the aim point is the middle of the object" is the more
-- intuitive default here. Measured ONCE at grab/spawn time (same reasoning as
-- computeStatueBottomOffset below) -- a fixed property of the mesh/pose at its current rotation, not
-- the current position, and rotation doesn't change during a follow session.
local function computeActorCenterOffset(actor)
    local origin, extent = {}, {}
    local ok = pcall(function() actor:GetActorBounds(false, origin, extent, false) end)
    if not (ok and origin.X and origin.Y and origin.Z) then return nil end
    local curLoc
    pcall(function() curLoc = actor:K2_GetActorLocation() end)
    if not curLoc then return nil end
    return { X = origin.X - curLoc.X, Y = origin.Y - curLoc.Y, Z = origin.Z - curLoc.Z }
end

-- findFloorBelow (a separate downward-search-from-a-fixed-point raycast) was tried here and REMOVED
-- (2026-08-21) -- superseded by beginFollowLoop's own forward raycast (see that tick()'s comment),
-- which finds the actual surface in one step instead of computing a fixed-distance point and then
-- searching down from it. Having TWO different position sources (forward-ray hit vs. this fallback)
-- was itself the bug behind RedFalcon's "there seems to be a point at about 800uu where it jumps
-- straight to the 1000uu" -- right at the edge of what the forward ray could reach, it would flicker
-- between the two disagreeing sources. Don't reintroduce a second fallback source without also
-- solving that discontinuity (the fix that shipped instead: hold the last successfully-landed
-- position on a momentary miss, not fall back to a different calculation).

-- Same statue-class check EditNearestInFront's own statueFrame already uses (AnimatedActor/
-- QuestStatic) -- shared here (2026-08-21) so the follow loop's floor-lock (see its own comment)
-- can tell statues apart from decor the same way live-edit already does.
local function isStatueClass(class)
    return (class and (string.find(class, "AnimatedActor", 1, true)
        or string.find(class, "QuestStatic", 1, true))) and true or false
end

-- How far BELOW this actor's own pivot its visual bottom (bounding-box bottom) sits -- measured
-- ONCE at grab/spawn time (not every tick, since it's a fixed property of the mesh/pose, not the
-- current position) via the fixed actorBoundsBottomZ. The follow loop's floor-lock then does
-- target.Z = floorSurfaceZ - thisOffset to rest the actor's bottom exactly on whatever surface
-- findFloorBelow found, regardless of this statue's own pivot-to-feet quirk.
local function computeStatueBottomOffset(actor)
    local bottomZ = actorBoundsBottomZ(actor)
    if not bottomZ then return nil end
    local curZ
    pcall(function() curZ = actor:K2_GetActorLocation().Z end)
    if not curZ then return nil end
    return bottomZ - curZ
end

-- Build-mode camera raise (2026-08-20, RedFalcon: native build mode raises/pulls back the camera for
-- a better view -- wants the same while placing/relocating). CONFIRMED LIVE via lbprobecam (probe
-- in and out of real build mode, same spot, same look direction): camera height +35uu relative to
-- the pawn, and FOV 70 -> 76 (+6).
-- HEIGHT RAISE + FOV, both now (2026-08-22, RedFalcon after confirming FOV works: "i did want the
-- height we set, just not the backwards 100 of the sprintarm we tried") -- the height raise
-- (spring-arm RelativeLocation, +35uu) is back; only the separate TargetArmLength "pullback"
-- experiment (100uu, never worked, already removed) stays gone. Both the arm and the camera are now
-- reached via plain NAMED properties -- `pawn.CameraBoom` / `pawn.FollowCamera` -- confirmed live by
-- a reference UE4SS camera mod (Other\Camera Toggle System (UE4SS)-32-4-1-1778381431\...\main.lua),
-- replacing the old class-search findPawnSpringArm()/findPawnCamera() lookups.
--
-- ROOT CAUSE of every earlier FOV failure, found by reading that mod: Windrose's FollowCamera has a
-- settings-driven camera system (`CameraParams`) that keeps re-asserting its own FOV value UNLESS
-- you explicitly detach from it first -- that mod's own `DetachCameraSystem` helper:
--   cam.bUseSettingsFov = false
--   cam.CameraParams = nil
-- We never did either, which is almost certainly why both prior FieldOfView writes (
-- PlayerCameraManager.FOVAngle, then CameraComponent.FieldOfView) got silently overridden/blended
-- back. Both original values are saved here and restored exactly, since CameraParams likely drives
-- other camera behavior outside placement mode (native zoom-avoid-clipping, camera lag, etc.) --
-- permanently detaching without restoring would risk breaking that.
local PLACEMENT_CAMERA_RAISE_UU = Config.PLACEMENT_CAMERA_RAISE_UU or 35.0
local PLACEMENT_CAMERA_FOV_DELTA = Config.PLACEMENT_CAMERA_FOV_DELTA or 6.0
function Spawner.ApplyPlacementCameraOffset()
    local armOk, armErr = pcall(function()
        local pc = UEHelpers.GetPlayerController()
        local pawn = pc and pc:IsValid() and pc.Pawn
        local arm = pawn and pawn:IsValid() and pawn.CameraBoom
        if not (arm and arm:IsValid()) then error("no pawn.CameraBoom") end
        local rel = arm.RelativeLocation
        if not rel then error("RelativeLocation read failed") end
        Spawner._placementCamOrigArmZ = rel.Z
        arm:K2_SetRelativeLocation({ X = rel.X, Y = rel.Y, Z = rel.Z + PLACEMENT_CAMERA_RAISE_UU }, false, {}, true)
    end)
    local fovOk, fovErr = pcall(function()
        local pc = UEHelpers.GetPlayerController()
        local pawn = pc and pc:IsValid() and pc.Pawn
        local cam = pawn and pawn:IsValid() and pawn.FollowCamera
        if not (cam and cam:IsValid()) then error("no pawn.FollowCamera") end
        pcall(function() Spawner._placementCamOrigUseSettingsFov = cam.bUseSettingsFov end)
        pcall(function() Spawner._placementCamOrigParams = cam.CameraParams end)
        local curFov = cam.FieldOfView
        if not curFov then error("FieldOfView read failed") end
        Spawner._placementCamOrigFov = curFov
        cam.bUseSettingsFov = false
        cam.CameraParams = nil
        cam.FieldOfView = curFov + PLACEMENT_CAMERA_FOV_DELTA
    end)
    print(string.format("[LivingBase] [placecam] apply: arm=%s (%s) fov=%s (%s)\n",
        tostring(armOk), armOk and "ok" or tostring(armErr),
        tostring(fovOk), fovOk and "ok" or tostring(fovErr)))
end

function Spawner.RestorePlacementCameraOffset()
    if Spawner._placementCamOrigArmZ then
        local ok, err = pcall(function()
            local pc = UEHelpers.GetPlayerController()
            local pawn = pc and pc:IsValid() and pc.Pawn
            local arm = pawn and pawn:IsValid() and pawn.CameraBoom
            if not (arm and arm:IsValid()) then error("no pawn.CameraBoom") end
            local rel = arm.RelativeLocation
            if not rel then error("RelativeLocation read failed") end
            arm:K2_SetRelativeLocation({ X = rel.X, Y = rel.Y, Z = Spawner._placementCamOrigArmZ }, false, {}, true)
        end)
        if not ok then print("[LivingBase] [placecam] restore: arm restore FAILED (" .. tostring(err) .. ") -- camera may stay raised until next reload.\n") end
        Spawner._placementCamOrigArmZ = nil
    end
    if Spawner._placementCamOrigFov then
        local ok, err = pcall(function()
            local pc = UEHelpers.GetPlayerController()
            local pawn = pc and pc:IsValid() and pc.Pawn
            local cam = pawn and pawn:IsValid() and pawn.FollowCamera
            if not (cam and cam:IsValid()) then error("no pawn.FollowCamera") end
            cam.FieldOfView = Spawner._placementCamOrigFov
            if Spawner._placementCamOrigParams ~= nil then cam.CameraParams = Spawner._placementCamOrigParams end
            if Spawner._placementCamOrigUseSettingsFov ~= nil then cam.bUseSettingsFov = Spawner._placementCamOrigUseSettingsFov end
        end)
        if not ok then print("[LivingBase] [placecam] restore: FOV restore FAILED (" .. tostring(err) .. ") -- camera system may stay detached until next reload.\n") end
        Spawner._placementCamOrigFov = nil
        Spawner._placementCamOrigParams = nil
        Spawner._placementCamOrigUseSettingsFov = nil
    end
end

-- Spawner.StartPlacementPreview/ConfirmPlacement/CancelPlacement -- REAL FEATURE (2026-08-20): a
-- just-spawned decor object follows the camera/reticle until confirmed (F5) or cancelled (F6),
-- instead of landing wherever it happened to spawn. Built on the camera-follow mechanic proven safe
-- 2026-08-19 (see memory/project_build_ghost_preview.md for the full crash-and-fix writeup this is
-- based on): pawn-anchored origin (NOT the camera's own position -- this game's third-person
-- spring-arm camera zooms to avoid clipping through nearby objects, including the one being placed,
-- which created a feedback loop when the camera itself was used as the origin), zero file I/O per
-- tick, physics disabled so it doesn't fight the teleport.
--
-- The object arrives here ALREADY solid/collision-on/ledger-written -- Testbed.placeDecorEntry (see
-- testbed.lua) already ran Spawner.Spawn (which persists it) and Spawner.SetDecorSolid (collision +
-- frozen physics) before pollSpawnMenuRequest ever sees it. This re-opens exactly what's needed for
-- live movement (collision off so it doesn't shove the player while being dragged around; physics
-- was already off) rather than redoing the whole spawn treatment.
-- Shared by StartPlacementPreview (new spawn) and StartRelocatePreview (grab existing) -- same
-- camera-follow tick loop either way, only how the actor GOT into follow-state differs.
local function beginFollowLoop(distance)
    -- Spawner._placementDistance (2026-08-20, RedFalcon: "be able to zoom it in and out... so we
    -- aren't limited to either a set distance nor its starting distance") -- lives on Spawner, not as
    -- a plain closure-captured local, specifically so Spawner.AdjustPlacementDistance (below) can
    -- change it live from a completely different keypress while this loop keeps running. tick() reads
    -- it fresh every iteration rather than closing over a fixed value.
    -- Default bumped 300 -> Config.PLACEMENT_START_DIST_UU (2026-08-21, RedFalcon: matching native
    -- build mode's ~1000uu placement range, now that floor-lock makes long-range statue placement
    -- actually useful) -- applies to decor too (RedFalcon's explicit call, not statue-only), since
    -- StartPlacementPreview never passed its own `distance` anyway (this fallback was always what
    -- every fresh spawn from the menu actually used). StartRelocatePreview is unaffected -- it always
    -- computes its own grabDistance from the actual camera-to-object distance, this fallback only
    -- matters when that lookup fails.
    Spawner._placementDistance = distance or Config.PLACEMENT_START_DIST_UU or 300.0
    -- Camera raise/restore (2026-08-21): moved OFF this per-session lifecycle onto the SpawnMenu
    -- window's own open/close transition -- see Spawner.ApplyPlacementCameraOffset's own comment.
    -- By the time this runs, the window is already guaranteed open (StartPlacementPreview/
    -- StartRelocatePreview are only ever reached via windowGatedAction), so the camera should already
    -- be raised.
    -- CONFIRMED LIVE (2026-08-20): the old version's pcall wrapped the WHOLE camera lookup + move,
    -- and swallowed any failure completely silently -- no log, no state change -- while still
    -- rescheduling the next tick regardless. If the pawn/camera lookup (or the move itself) started
    -- failing for ANY reason -- even something as ordinary as a menu briefly stealing pawn
    -- possession -- the loop would spin forever doing nothing, never moving the object again and
    -- never clearing _placementActive, while looking completely healthy from the outside (no crash,
    -- no error, nothing in the log). RedFalcon hit exactly this: an object stopped moving mid-
    -- placement but F7/F5 kept saying "already placing" for 44 seconds. Fix: log the FIRST failure
    -- (so a repeat is actually diagnosable) and count consecutive failures -- after too many in a
    -- row, stop for real (clear _placementActive) instead of spinning inert forever. A few
    -- transient failures are still tolerated (matches the same "don't overreact to one bad tick"
    -- reasoning as the hover-highlight miss debounce), just not an unbounded silent hang.
    local FOLLOW_FAIL_TOLERANCE = 30 -- ~1s at 33ms before giving up for real
    local consecutiveFails = 0
    local function tick()
        if not Spawner._placementActive then return end
        if not (Spawner._placementActor and Spawner._placementActor:IsValid()) then
            Spawner._placementActive = false
            return
        end
        local ok, err = pcall(function()
            local pc = UEHelpers.GetPlayerController()
            if not (pc and pc:IsValid()) then error("no PlayerController") end
            local pawn = pc.Pawn
            local cam = pc.PlayerCameraManager
            if not (pawn and pawn:IsValid() and cam and cam:IsValid()) then error("no Pawn/PlayerCameraManager") end
            -- CAMERA-anchored, not pawn-anchored (2026-08-21, RedFalcon: chest "a lot lower than the
            -- target point" -- tried a 32uu pivot-to-center fix first, CONFIRMED LIVE it made zero
            -- visible difference, meaning the real gap was much bigger). Root cause: this was pawn-
            -- position + camera-direction -- the exact origin/direction MISMATCH this file's own
            -- anti-pattern comment already documents as broken for anything directional (see
            -- findNearestSpawnInFront's own comment, and the hover-highlight/statue-raycast history
            -- earlier this session). Using the camera's ANGLE from the PAWN's LOWER starting point
            -- traces a path that ends up below where the camera is actually looking, and that gap
            -- grows with distance -- which lines up with today's much longer follow distances
            -- (750-1800uu) making the old "close enough" pawn-anchored approximation clearly wrong.
            -- Origin was pawn-anchored ON PURPOSE originally (2026-08-19) specifically to dodge a
            -- DIFFERENT bug: third-person spring-arm collision-avoidance zooms the camera when the
            -- FOLLOWED OBJECT gets close to it, and camera-anchoring fed that zoom back into the next
            -- tick's own origin, creating a visible feedback loop ("object creeps toward the
            -- camera"). That trigger needs the object to be close to the camera specifically -- at
            -- today's much longer default distances this may no longer be reachable in normal use,
            -- but hasn't been proven safe at CLOSE range (zoom all the way in with HOME) -- watch for
            -- that old symptom specifically there if this regresses.
            local loc = cam:GetCameraLocation()
            local rot = cam:GetCameraRotation()
            local yaw, pitch = math.rad(rot.Yaw), math.rad(rot.Pitch)
            local cp = math.cos(pitch)
            local fx, fy, fz = cp * math.cos(yaw), cp * math.sin(yaw), math.sin(pitch)
            local dist = Spawner._placementDistance or 300.0
            local target = { X = loc.X + fx * dist, Y = loc.Y + fy * dist, Z = loc.Z + fz * dist }
            -- Statues stay floor-locked while being dragged (2026-08-21, RedFalcon: "i'd be ok if the
            -- statues stayed attached to the floor surface when moving. they are different from
            -- decor") -- decor can go on shelves/tables/mid-air, but a statue floating at whatever
            -- height the camera happens to be pitched at looks wrong; X/Y still follow the camera
            -- normally, only Z gets overridden to the player's own floor height. Same "assume same
            -- floor as the player" convention already used elsewhere in this file (the zBand/
            -- DESPAWN_FRONT_Z_UU same-floor-only check in findNearestSpawnInFront) rather than a new
            -- per-tick downward raycast -- cheaper, and consistent with how this codebase already
            -- treats "which floor" everywhere else.
            -- UPGRADED to a native-build-mode-style FORWARD raycast (2026-08-21, RedFalcon: "he
            -- doesnt slide closer he just goes through the floor/ground. we need to figure out how
            -- to let the distance be flexible so it doesnt drop through the floor"). The downward-
            -- raycast-from-a-fixed-distance-point version (previous approach, still used as the
            -- fallback below) had a real gap: X/Y always used the FULL configured distance along the
            -- camera ray, even when the actual floor doesn't extend that far -- so aiming past the
            -- edge of a platform put the search point over open air/a lower level entirely. Native
            -- build mode instead effectively SHORTENS its reach to stay on solid ground -- replicated
            -- here with ONE forward raycast along the camera's own view (origin AND direction both
            -- from the camera -- this is a directional raycast, see this file's own documented
            -- anti-pattern for why mixing pawn-position with camera-direction breaks this), capped at
            -- the current Spawner._placementDistance. Wherever that ray actually hits solid geometry
            -- IS the target -- X, Y, AND Z all come from the hit point directly, so it naturally
            -- lands on a nearer table/ledge/floor edge instead of overshooting past it.
            -- TRYING floor-lock on decor too (2026-08-21, RedFalcon: "real build mode is built on
            -- camera too. Can we try floor snapping on the decor too to see how it behaves") --
            -- experimental, gated purely on whether a bottom-offset was measured at grab/spawn time
            -- (Spawner._placementStatueBottomOffset), no longer restricted to Spawner._placementIsStatue.
            -- usedFloorLock tracked below so the separate center-anchor adjustment (further down, for
            -- decor's own pivot-to-center fix) doesn't ALSO apply on top of this and double-adjust --
            -- floor-lock already fully determines the pivot position itself when it engages.
            local usedFloorLock = false
            if Spawner._placementStatueBottomOffset then
                -- Snapshot into a local (2026-08-24 fix, RedFalcon's crash-on-exit investigation):
                -- CONFIRMED LIVE in ue4ss.log -- "attempt to perform arithmetic on a nil value
                -- (field '_placementStatueBottomOffset')" -- the SAME reentrancy this block's own
                -- later mid-tick re-check already documents (a Confirm/Cancel keypress landing
                -- WHILE a native call here, e.g. GetCameraLocation/LineTraceSingle, is still on the
                -- stack) can clear this field between this `if` passing and its OWN later use
                -- further down in this same block. That re-check only guards
                -- Spawner._placementActive/_placementActor, not this field, so re-reading the live
                -- global below was still exposed. A plain Lua error here is pcall-caught by tick()'s
                -- own wrapper (harmless -- one skipped move, not a crash), but closing it removes
                -- one candidate contributor while the actual native crash-on-exit is still being
                -- isolated.
                local bottomOffset = Spawner._placementStatueBottomOffset
                local camLoc
                pcall(function() camLoc = cam:GetCameraLocation() end)
                if camLoc then
                    local farPt = { X = camLoc.X + fx * dist, Y = camLoc.Y + fy * dist, Z = camLoc.Z + fz * dist }
                    local KSL = UEHelpers.GetKismetSystemLibrary()
                    local landed = false
                    if KSL and KSL:IsValid() then
                        local hitResult = {}
                        local zero = { R = 0, G = 0, B = 0, A = 0 }
                        local wasHit
                        -- bTraceComplex=false (2026-08-21), unlike hover-highlight's own true --
                        -- large floor/terrain/building geometry commonly only has SIMPLE collision
                        -- defined (complex per-triangle collision on big level geometry is usually
                        -- skipped for performance) -- a complex-only trace against that finds nothing.
                        pcall(function()
                            -- REVERTED to channel 0 (2026-08-21) -- channel 2 was tried on the theory
                            -- it meant "Pawn" (matching LetFurniturePass's own comment), but CONFIRMED
                            -- LIVE that broke targeting entirely, even for decor which worked fine on
                            -- channel 0 -- that comment's channel numbering doesn't match this trace
                            -- API's actual channel indices. Real fix went into LetFurniturePass itself
                            -- instead (see its own comment) -- it now also blocks channel 0, the
                            -- channel this trace has always actually used and confirmed working on.
                            wasHit = KSL:LineTraceSingle(pawn, camLoc, farPt, 0, false, {}, 0, hitResult, true, zero, zero, 0.0)
                        end)
                        if wasHit then
                            local hitLoc
                            pcall(function() hitLoc = hitResult.Location end)
                            if hitLoc then
                                target.X, target.Y, target.Z = hitLoc.X, hitLoc.Y, hitLoc.Z - bottomOffset
                                landed = true
                            end
                        end
                    end
                    -- Miss fallback (2026-08-21, RedFalcon: "if the ray trace is at or past the 1800
                    -- limit it stays at 1800. That way if i'm placing near the edge... it will still
                    -- move around that 1800 diameter instead of sticking, since we cant really tell
                    -- what that diameter is while placing") -- rather than holding a stale position
                    -- (tried and reported "sticky"/discontinuous earlier), just use the raw camera-ray
                    -- endpoint at the current max distance, recomputed fresh every tick. Nothing to
                    -- hit within reach in this direction just means it sits at the edge of that
                    -- reach instead of on a real surface -- and since farPt tracks the camera live,
                    -- it keeps sliding smoothly around that boundary as you look around, rather than
                    -- freezing the instant nothing's hit.
                    if not landed then
                        target.X, target.Y, target.Z = farPt.X, farPt.Y, farPt.Z - bottomOffset
                    end
                    usedFloorLock = true
                end
            end
            -- CONFIRMED LIVE (2026-08-20): the outer check a few lines up isn't enough on its own --
            -- everything between it and here (GetPlayerController, camera reads, math) takes real
            -- time, and a Confirm/Cancel keypress landing in that exact window can clear
            -- _placementActor to nil before this line runs, throwing "attempt to index a nil value"
            -- (caught by this pcall, logged, harmless, but worth closing). Re-check immediately
            -- before use rather than trusting the earlier snapshot.
            if not (Spawner._placementActive and Spawner._placementActor and Spawner._placementActor:IsValid()) then
                error("state changed mid-tick (confirmed/cancelled concurrently) -- skipping this move")
            end
            local actor = Spawner._placementActor
            -- REVERTED (2026-08-20) -- the swept move (bSweep=true, bTeleport=false) tried here for
            -- physics-on was CONFIRMED LIVE to fight the physics simulation itself: with
            -- SetSimulatePhysics(true) on, the physics engine has its own idea of where the object
            -- should be every substep, and the sweep-teleport was ALSO forcing it somewhere else every
            -- 33ms -- two independent authorities over the same transform, resolving a fresh collision
            -- conflict every tick. RedFalcon's live result: "it freaked out, vibrated, and then stopped
            -- moving" -- the follow loop's own tick log showed a "no PlayerController" failure moments
            -- later, consistent with the object's physics reaction actually disrupting player control
            -- state, not just a visual glitch. Back to a PLAIN TELEPORT always (bSweep=false,
            -- bTeleport=true) regardless of physics state -- teleport skips collision/physics
            -- resolution entirely, so it can't fight a simulating body this way. This makes
            -- Spawner._placementPhysicsOn effectively cosmetic again while still being followed (matches
            -- RedFalcon's FIRST test, physics-on-but-inert, which was stable) -- a real "drag with
            -- physics reacting" would need the follow loop to stop forcing position altogether while
            -- physics is on (hand full authority to the physics engine, no longer camera-tracking) --
            -- a bigger, deliberate redesign, not a tweak to this move call. Don't re-add sweep here
            -- without that redesign.
            -- Center-anchor for decor (2026-08-21, see computeActorCenterOffset's own comment) --
            -- `target` up to here represents where the PIVOT would go; shift it by the negative of
            -- the measured pivot-to-center offset so the object's VISUAL CENTER (not its raw pivot)
            -- ends up at the aim point instead. Skipped whenever floor-lock just ran (usedFloorLock)
            -- -- floor-lock already fully determined the pivot position itself (bottom-anchored, via
            -- its own hit-point-minus-bottomOffset math above), so applying a SEPARATE center-anchor
            -- correction on top would double-adjust and fight it.
            local moveTarget = target
            if Spawner._placementCenterOffset and not usedFloorLock then
                moveTarget = {
                    X = target.X - Spawner._placementCenterOffset.X,
                    Y = target.Y - Spawner._placementCenterOffset.Y,
                    Z = target.Z - Spawner._placementCenterOffset.Z,
                }
            end
            actor:K2_SetActorLocation(moveTarget, false, {}, true)
        end)
        if ok then
            consecutiveFails = 0
        else
            consecutiveFails = consecutiveFails + 1
            if consecutiveFails == 1 then
                print("[LivingBase] [followloop] tick failed: " .. tostring(err) .. " (will retry, giving up after "
                    .. FOLLOW_FAIL_TOLERANCE .. " in a row)\n")
            end
            if consecutiveFails >= FOLLOW_FAIL_TOLERANCE then
                print(string.format("[LivingBase] [followloop] %d consecutive failures -- stopping instead of hanging silently.\n", consecutiveFails))
                local strandedActor = Spawner._placementActor
                Spawner._placementActive = false
                -- Camera restore call REMOVED here (2026-08-21) -- the raise is no longer tied to
                -- this per-session lifecycle at all (see Spawner.ApplyPlacementCameraOffset's own
                -- comment), so there's nothing to restore on this path anymore either -- the window's
                -- own close transition owns that now, independent of how any given follow session ends.
                -- Re-solidify the stranded object too (2026-08-20, RedFalcon: "it got stuck and now
                -- its sitting there like a ghost with no physics and is unselectable") -- this giveup
                -- path used to leave the actor exactly as prepForFollow left it: collision OFF (so
                -- dragging never shoves the player), never restored, since only Confirm/Cancel used to
                -- call SetDecorSolid. With _placementActive already false, F5/F6 hit their own
                -- "nothing currently being placed" guard, so neither could ever reach it either --
                -- collision stayed off forever with no way back except a reload. Calling it directly
                -- here means giving up still leaves a normal, solid, selectable object -- collision
                -- back on and raycast-selectable again -- exactly like a completed placement, just at
                -- wherever it last successfully moved to instead of wherever the player was aiming.
                if strandedActor and strandedActor:IsValid() then
                    pcall(function() Spawner.SetDecorSolid(strandedActor) end)
                end
                return
            end
        end
        if Spawner._placementActive then
            ExecuteWithDelay(33, tick)
        end
    end
    ExecuteWithDelay(33, tick)
end

-- Spawner.AdjustPlacementDistance(delta) -- zoom the followed object closer/farther (2026-08-20,
-- RedFalcon: "be able to zoom it in and out instead... so we aren't limited to either a set distance
-- nor its starting distance"). Just adjusts Spawner._placementDistance -- beginFollowLoop's tick
-- reads it fresh every iteration, so this takes effect on the very next tick with no restart needed.
-- Clamped to a sane range (Config.PLACEMENT_ZOOM_MIN/MAX_UU) so it can't be zoomed to ~0 (right on
-- top of the camera) or out to some absurd distance where confirming it is impractical.
function Spawner.AdjustPlacementDistance(delta)
    if not Spawner._placementActive then
        print("[LivingBase] Zoom: nothing currently being placed.\n")
        return
    end
    local minD = Config.PLACEMENT_ZOOM_MIN_UU or 100.0
    local maxD = Config.PLACEMENT_ZOOM_MAX_UU or 2000.0
    local newD = (Spawner._placementDistance or 300.0) + delta
    if newD < minD then newD = minD end
    if newD > maxD then newD = maxD end
    Spawner._placementDistance = newD
    print(string.format("[LivingBase] Placement distance: %.0fuu.\n", newD))
    pcall(function() Spawner.Toast(string.format("Distance: %.0fuu", newD), 1.0) end)
end

-- Common "free it up for live movement" prep -- collision off (don't shove the player while being
-- dragged around), Movable (Static mobility ignores runtime SetActorLocation on the render thread),
-- physics off (fights the teleport otherwise, see this feature's own memory writeup for the full
-- crash-and-fix history from 2026-08-19).
local function prepForFollow(actor)
    pcall(function() actor:SetActorEnableCollision(false) end)
    pcall(function() Spawner.MakeMovable(actor) end)
    pcall(function()
        local root = actor:K2_GetRootComponent()
        if root and root:IsValid() then pcall(function() root:SetSimulatePhysics(false) end) end
    end)
    pcall(function() forEachStaticMesh(actor, function(c) c:SetSimulatePhysics(false) end) end)
    -- AI logic stop (2026-08-22, RedFalcon: "the senkamati, when i use the menu buttons they are
    -- bumping into objects instead of clipping. the statues and the decor do not do that") --
    -- SetActorEnableCollision(false) above stops the ACTOR's own collision from blocking anything,
    -- but an AI-driven pawn's own StateTree/controller can still be actively trying to navigate
    -- every tick regardless of that flag -- fighting our forced K2_SetActorLocation teleport looks
    -- exactly like "bumping into things". Statues/decor have no AI controller at all, so nothing
    -- fights them, which is why only AI pawns showed this. Reuses Spawner.SetAILogic (already
    -- proven elsewhere -- StartLogic/StopLogic on the AR5AIController, used to stop crew fighting a
    -- follow order) -- a no-op, harmless pcall for anything without a controller (statues/decor).
    pcall(function() Spawner.SetAILogic(actor, false) end)
    -- Stop falling when placed in the air (2026-08-22, RedFalcon: "putting them in the air makes
    -- them drop... i want them to behave like statues when idle") -- SetSimulatePhysics(false) above
    -- only stops the rigid-body physics engine; a Pawn/Character's own CharacterMovementComponent
    -- applies gravity independently of that through its MovementMode logic (Walking/Falling), same
    -- reason a real player falls even with ragdoll physics off. Zeroing GravityScale as a plain
    -- property write is the SAME proven pattern Spawner.SetMaxWalkSpeed already uses successfully on
    -- pawn.CharacterMovement -- no risky function call, just a value. Saves the original so
    -- ConfirmPlacement/CancelPlacement can put it back. No-op for statues/decor (no
    -- CharacterMovement component at all).
    pcall(function()
        local mv = actor.CharacterMovement
        if mv and mv:IsValid() then
            if Spawner._placementOrigGravityScale == nil then
                pcall(function() Spawner._placementOrigGravityScale = mv.GravityScale end)
            end
            mv.GravityScale = 0.0
        end
    end)
end

function Spawner.StartPlacementPreview(actor, distance)
    if not (actor and actor:IsValid()) then return end
    if Spawner._placementActive then
        print("[LivingBase] StartPlacementPreview: already placing/relocating something -- ignored.\n")
        return
    end
    -- FIXED (2026-08-21): RedFalcon reported statues weren't floor-locking during follow, AND
    -- couldn't be re-targeted after confirming -- both traced back to this. actor:GetClass():
    -- GetFullName() returns a totally different string shape ("BlueprintGeneratedClass /Script/...")
    -- than e.class elsewhere in this file (the literal spawn-time asset path, e.g.
    -- "/Game/.../BP_XYZ_AnimatedActor.BP_XYZ_AnimatedActor_C" -- see Spawner.Spawn's own `classPath`
    -- param, EditNearestInFront's statueFrame check, RetrackOrphans) -- isStatueClass's substring
    -- search against the WRONG string silently always returned false, so floor-lock never engaged
    -- and the statue ended up wherever the full 3D camera-direction math put it (potentially
    -- floating well above/below normal statue height) -- which also explains the "can't re-target
    -- it" report: aiming where a properly floor-placed statue would be simply wasn't aiming at it.
    -- Fixed by reading class off the Spawner.spawned entry Spawner.Spawn already created for this
    -- exact actor (same handle, so plain == is safe here -- not the cross-fetch wrapper-identity
    -- pitfall documented elsewhere in this file) instead of re-deriving it a different way.
    local class
    for _, e in ipairs(Spawner.spawned) do
        if e.actor == actor then class = e.class; break end
    end
    prepForFollow(actor)
    Spawner._placementActor = actor
    Spawner._placementActive = true
    Spawner._placementMode = "NEW"
    Spawner._placementPhysicsOn = false
    Spawner._placementIsStatue = isStatueClass(class)
    -- Floor-lock trial on decor too (2026-08-21, RedFalcon: "real build mode is built on camera too.
    -- Can we try floor snapping on the decor too to see how it behaves") -- gated behind
    -- Config.PLACEMENT_FLOOR_LOCK_DECOR so it's a one-line flip back to center-anchor-only if it
    -- doesn't feel right, no code changes needed. Statues always get it regardless of this flag,
    -- UNLESS free-build mode is on (F8, Spawner.ToggleFreeBuild) -- that overrides everything back to
    -- the old center-anchored/static-distance behavior for both statues and decor.
    local wantFloorLock = (not Spawner._placementFreeBuild) and (Spawner._placementIsStatue or (Config.PLACEMENT_FLOOR_LOCK_DECOR ~= false))
    Spawner._placementStatueBottomOffset = wantFloorLock and computeStatueBottomOffset(actor) or nil
    Spawner._placementCenterOffset = (not wantFloorLock) and computeActorCenterOffset(actor) or nil
    local co = Spawner._placementCenterOffset
    print(string.format("[LivingBase] StartPlacementPreview: class=%s isStatue=%s freeBuild=%s bottomOffset=%s centerOffset=%s\n",
        tostring(class), tostring(Spawner._placementIsStatue), tostring(Spawner._placementFreeBuild), tostring(Spawner._placementStatueBottomOffset),
        co and string.format("(%.1f,%.1f,%.1f)", co.X, co.Y, co.Z) or "nil"))
    -- Free-build spawns start at their own, much shorter distance (RedFalcon: "set the distance at
    -- 350uu, that will be about one platform distance from the player") -- separate from the
    -- non-free-build 1800uu default (Config.PLACEMENT_START_DIST_UU). Only applies when the caller
    -- didn't already pass an explicit distance (main.lua's call site never does today).
    local startDist = distance
    if not startDist then
        startDist = Spawner._placementFreeBuild and Config.PLACEMENT_FREEBUILD_START_DIST_UU or Config.PLACEMENT_START_DIST_UU
    end
    beginFollowLoop(startDist)
    pcall(function() Spawner.Toast("Placing... F5 to confirm, F6 to cancel.", 2.5) end)
end

-- Spawner.StartRelocatePreview() -- REAL FEATURE (2026-08-20, RedFalcon's request): grab whatever's
-- currently target-locked (Num+) and carry it with the camera the same way a fresh spawn follows,
-- instead of only being able to nudge it with the live-edit keys. Unlike a fresh placement, CANCEL
-- here means "put it back where it was," never destroy -- this is an EXISTING object, possibly one
-- RedFalcon spent real effort placing/decorating already. Records the pre-grab transform up front so
-- CancelPlacement has something to revert to.
function Spawner.StartRelocatePreview()
    local lt = Spawner.lockedTarget
    local actor = lt and lt.actor
    if not (actor and actor:IsValid()) then
        print("[LivingBase] Grab target: nothing target-locked -- Num+ it first.\n")
        pcall(function() Spawner.Toast("Target-lock something first (Num +).", 2.5) end)
        return
    end
    if Spawner._placementActive then
        print("[LivingBase] Grab target: already placing/relocating something -- ignored.\n")
        return
    end
    local loc, rot
    pcall(function() loc = actor:K2_GetActorLocation() end)
    pcall(function() rot = actor:K2_GetActorRotation() end)
    if not loc then
        print("[LivingBase] Grab target: could not read its current position.\n")
        return
    end
    Spawner._placementOriginalLoc = { X = loc.X, Y = loc.Y, Z = loc.Z }
    Spawner._placementOriginalRot = rot and { Pitch = rot.Pitch, Yaw = rot.Yaw, Roll = rot.Roll } or nil
    -- Follow at the SAME distance it was already sitting at when grabbed (2026-08-20, RedFalcon:
    -- "can we keep the item the same distance away from the camera as when it started?") --
    -- beginFollowLoop's own 300uu default would otherwise SNAP the object to a fixed distance the
    -- instant F7 is pressed, regardless of how far away it actually was (closer, or much farther for
    -- something viewed across the room). Measuring once, here, at grab time, means the very first
    -- follow tick reproduces its current on-screen position exactly -- no pop -- and only then does
    -- it start tracking the camera at that distance.
    -- REVERTED back to camera-measured (2026-08-21) -- briefly changed to pawn-measured to fix a
    -- confirmed ~2-meter pop (grabDistance was camera-measured while the follow loop's own target
    -- math was pawn-anchored, a real mismatch). Since then, beginFollowLoop's tick() itself switched
    -- to CAMERA-anchored origin (see that function's own comment -- pawn-anchoring turned out to be
    -- the real cause of a MUCH bigger "object sits a lot lower than where you're aiming" gap).
    -- Measurement here must match whatever the follow loop actually anchors to, or the exact same
    -- pop bug reappears with the origins swapped -- so this goes back to camera-measured to stay
    -- consistent with tick()'s new camera-anchored math.
    local grabDistance
    pcall(function()
        local pc = UEHelpers.GetPlayerController()
        local cam = pc and pc:IsValid() and pc.PlayerCameraManager
        if cam and cam:IsValid() then
            local cl = cam:GetCameraLocation()
            local dx, dy, dz = loc.X - cl.X, loc.Y - cl.Y, loc.Z - cl.Z
            grabDistance = math.sqrt(dx * dx + dy * dy + dz * dz)
        end
    end)
    -- Free-build grab floor (2026-08-21, RedFalcon: "keep the original distance unless it reaches or
    -- is less than 125uu from the camera -- that should be about when a camera zoom in will freak
    -- out") -- ONLY applies in free-build mode. Non-free-build grabs stay untouched (RedFalcon: "for
    -- non free build spawning and grabbing, keep it exactly as it is") -- no clamp at all there.
    if Spawner._placementFreeBuild and grabDistance and grabDistance < (Config.PLACEMENT_FREEBUILD_MIN_GRAB_UU or 125.0) then
        grabDistance = Config.PLACEMENT_FREEBUILD_MIN_GRAB_UU or 125.0
    end
    -- Grab-point-at-raycast-intersection (2026-08-24) -- TRIED AND REVERTED SAME DAY, RedFalcon:
    -- "moving a multipart decor item risks meshes separating during moving while still grabbing it
    -- from the bottom." A decor actor built from several separate mesh components apparently
    -- doesn't tolerate being dragged by an off-center/off-pivot offset the way a single-mesh object
    -- does -- back to the plain bottom/center-anchor behavior below for RELOCATE too, unconditionally.
    -- If this gets revisited, it needs to be SCOPED to single-mesh actors only, not blanket-applied.
    prepForFollow(actor)
    Spawner._placementActor = actor
    Spawner._placementActive = true
    Spawner._placementMode = "RELOCATE"
    Spawner._placementPhysicsOn = false
    Spawner._placementIsStatue = isStatueClass(lt.class)
    local wantFloorLock = (not Spawner._placementFreeBuild) and (Spawner._placementIsStatue or (Config.PLACEMENT_FLOOR_LOCK_DECOR ~= false))
    Spawner._placementStatueBottomOffset = wantFloorLock and computeStatueBottomOffset(actor) or nil
    Spawner._placementCenterOffset = (not wantFloorLock) and computeActorCenterOffset(actor) or nil
    local co = Spawner._placementCenterOffset
    print(string.format("[LivingBase] StartRelocatePreview: class=%s isStatue=%s freeBuild=%s bottomOffset=%s centerOffset=%s\n",
        tostring(lt.class), tostring(Spawner._placementIsStatue), tostring(Spawner._placementFreeBuild), tostring(Spawner._placementStatueBottomOffset),
        co and string.format("(%.1f,%.1f,%.1f)", co.X, co.Y, co.Z) or "nil"))
    beginFollowLoop(grabDistance)   -- nil falls back to beginFollowLoop's own 300uu default if the lookup failed
    pcall(function() Spawner.Toast("Relocating... F5 to confirm, F6 to cancel (returns to original spot).", 2.5) end)
end

-- releasePlacementMobility(actor, entry) -- shared by ConfirmPlacement/CancelPlacement's RELOCATE
-- branch (2026-08-24, RedFalcon: "moving a mobile object removes its AI when placing... should be
-- reenabled on placement"). prepForFollow (see its own comment) always stops AI logic and zeroes
-- gravity for the duration of a follow/drag -- this undoes that, but ONLY for entries NOT marked
-- idle (Spawner.Spawn's markIdle param -- see its own comment -- set from config.lua's Senkamati
-- `idle` rows). Gated this way specifically because blindly restoring for EVERYTHING already
-- regressed once (2026-08-22): an idle Senkamati started walking again the instant StartLogic()
-- ran (see the history this replaced, below). entry.idle stays false/nil for every other roster
-- (crew/townsfolk/animals/statues/decor), so this is exactly "walking actors" -- the category
-- prepForFollow's own AI-logic comment already names as the one meant to keep wandering.
-- Always clears _placementOrigGravityScale, restored or not -- it's a one-shot capture from
-- prepForFollow for THIS actor; leaving it set would feed a stale value into the NEXT placement
-- session's own restore.
local function releasePlacementMobility(actor, entry)
    local orig = Spawner._placementOrigGravityScale
    Spawner._placementOrigGravityScale = nil
    if not (entry and not entry.idle) then return end
    pcall(function() Spawner.SetAILogic(actor, true) end)
    pcall(function()
        local mv = actor.CharacterMovement
        if mv and mv:IsValid() and orig ~= nil then
            mv.GravityScale = orig
        end
    end)
end

-- Confirm: stop following, re-solidify (matches how a normal decor spawn ends up), and rewrite the
-- ALREADY-EXISTING persist.txt line (written back at spawn time for NEW, or wherever it was before
-- for RELOCATE) to the FINAL followed-to position -- otherwise a reload would restore it back to the
-- old spot, not where the player actually placed it. Same confirm behavior for both modes -- only
-- CancelPlacement's two modes differ.
function Spawner.ConfirmPlacement()
    if not (Spawner._placementActive and Spawner._placementActor and Spawner._placementActor:IsValid()) then
        print("[LivingBase] Confirm placement: nothing currently being placed.\n")
        return
    end
    local actor = Spawner._placementActor
    Spawner._placementActive = false
    Spawner._placementActor = nil
    Spawner._placementMode = nil
    Spawner._placementOriginalLoc = nil
    Spawner._placementOriginalRot = nil
    Spawner._placementPhysicsOn = nil
    Spawner._placementIsStatue = nil
    Spawner._placementStatueBottomOffset = nil
    Spawner._placementCenterOffset = nil
    pcall(function() Spawner.SetDecorSolid(actor) end)
    local entry
    for _, e in ipairs(Spawner.spawned) do
        if e.actor == actor then entry = e; break end
    end
    -- RESTORED (2026-08-24) -- was previously never restored at all (see git history / the
    -- modding notes for the 2026-08-22 regression this now works around via entry.idle instead of
    -- an all-or-nothing switch). Deliberately AFTER the entry lookup above, and before the
    -- persist-rewrite below, so ordering matches prepForFollow -> drag -> release -> persist.
    releasePlacementMobility(actor, entry)
    if entry then
        pcall(function()
            local loc = actor:K2_GetActorLocation()
            local rot = actor:K2_GetActorRotation()
            local newLoc = { X = loc.X, Y = loc.Y, Z = loc.Z }
            Spawner.PersistUpdatePose(entry.class, entry.home, newLoc, rot.Yaw, rot.Pitch, rot.Roll)
            entry.home = newLoc
            entry.yaw = rot.Yaw
        end)
    end
    print("[LivingBase] Placement confirmed.\n")
    pcall(function() Spawner.Toast("Placed.", 1.5) end)
end

-- Cancel: stop following. NEW mode -- fully remove it (Spawner.DespawnActor destroys the actor AND
-- removes the persist.txt line Spawner.Spawn already wrote at spawn time, so nothing is left
-- behind). RELOCATE mode -- put it back exactly where it was grabbed from, never destroy.
function Spawner.CancelPlacement()
    if not (Spawner._placementActive and Spawner._placementActor and Spawner._placementActor:IsValid()) then
        print("[LivingBase] Cancel placement: nothing currently being placed.\n")
        return
    end
    local actor = Spawner._placementActor
    local mode = Spawner._placementMode
    local origLoc, origRot = Spawner._placementOriginalLoc, Spawner._placementOriginalRot
    Spawner._placementActive = false
    Spawner._placementActor = nil
    Spawner._placementMode = nil
    Spawner._placementOriginalLoc = nil
    Spawner._placementOriginalRot = nil
    Spawner._placementPhysicsOn = nil
    Spawner._placementIsStatue = nil
    Spawner._placementStatueBottomOffset = nil
    Spawner._placementCenterOffset = nil
    if mode == "RELOCATE" then
        pcall(function()
            if origLoc then actor:K2_SetActorLocation(origLoc, false, {}, true) end
            if origRot then actor:K2_SetActorRotation(origRot, false) end
        end)
        pcall(function() Spawner.SetDecorSolid(actor) end)
        -- RESTORED (2026-08-24) -- see releasePlacementMobility's own comment (ConfirmPlacement,
        -- above). A cancelled RELOCATE puts a walking actor back at its original spot but it's
        -- still a live, ongoing object afterward -- same reasoning as confirm, just a different
        -- final position. NEW-mode cancel (the `else` branch below) skips this entirely: the actor
        -- is destroyed outright, nothing left to restore mobility on.
        local entry
        for _, e in ipairs(Spawner.spawned) do
            if e.actor == actor then entry = e; break end
        end
        releasePlacementMobility(actor, entry)
        print("[LivingBase] Relocation cancelled -- returned to original spot.\n")
        pcall(function() Spawner.Toast("Returned to original spot.", 1.5) end)
    else
        Spawner._placementOrigGravityScale = nil
        pcall(function() Spawner.DespawnActor(actor) end)
        print("[LivingBase] Placement cancelled.\n")
        pcall(function() Spawner.Toast("Placement cancelled.", 1.5) end)
    end
end

-- Spawner.TogglePlacementPhysics() -- EXPERIMENTAL (2026-08-20, RedFalcon: "I'd like to try turning
-- [physics] back on with a key press... I want to see if it will behave like build mode and slide
-- across the floor if I look down"). Re-enabling physics on a followed object bit this project once
-- already -- an object simulating physics while overlapping the player's own collision capsule got
-- violently shoved, "flying into the camera." Guard: refuse to turn physics ON unless the object is
-- currently at least PLACEMENT_MIN_PHYSICS_DIST away from the CAMERA (matches how the flying-into-
-- camera issue actually happened) -- turning it back OFF is always allowed regardless of distance,
-- as an escape hatch if it does something unwanted. The follow loop's own per-tick safety check (see
-- beginFollowLoop's tick()) keeps re-checking this same distance every tick while physics stays on,
-- not just at the moment of this keypress -- see that check's own comment for why a one-time gate
-- here wasn't enough on its own. Actual physics/collision toggling lives in setPlacementPhysics
-- (declared above beginFollowLoop, shared with that per-tick auto-disable) -- this function is just
-- the guard + user-facing feedback around calling it.
function Spawner.TogglePlacementPhysics()
    if not (Spawner._placementActive and Spawner._placementActor and Spawner._placementActor:IsValid()) then
        print("[LivingBase] Toggle physics: nothing currently being placed.\n")
        return
    end
    local actor = Spawner._placementActor
    local turningOn = not Spawner._placementPhysicsOn
    if turningOn then
        local dist
        pcall(function()
            local pc = UEHelpers.GetPlayerController()
            local cam = pc and pc:IsValid() and pc.PlayerCameraManager
            if cam and cam:IsValid() then
                local cl = cam:GetCameraLocation()
                local al = actor:K2_GetActorLocation()
                local dx, dy, dz = al.X - cl.X, al.Y - cl.Y, al.Z - cl.Z
                dist = math.sqrt(dx * dx + dy * dy + dz * dz)
            end
        end)
        if not dist or dist < PLACEMENT_MIN_PHYSICS_DIST then
            print(string.format("[LivingBase] Toggle physics: too close (%.0fuu) -- back up past %.0fuu first.\n", dist or 0.0, PLACEMENT_MIN_PHYSICS_DIST))
            pcall(function() Spawner.Toast(string.format("Too close to enable physics -- back up past %.0fuu.", PLACEMENT_MIN_PHYSICS_DIST), 2.5) end)
            return
        end
    end
    setPlacementPhysics(actor, turningOn)
    print("[LivingBase] Placement physics: " .. (turningOn and "ON" or "OFF") .. ".\n")
    pcall(function() Spawner.Toast(turningOn and "Physics ON (experimental) -- collision back on too, try looking down." or "Physics OFF.", 2.5) end)
end

-- Free-build toggle (2026-08-21, RedFalcon: "a floor collision toggle so that items can also behave
-- as they did before with the same static limit. That way if they want to free build they can.") --
-- a GLOBAL mode flag, not per-placement: unlike _placementPhysicsOn this is deliberately NOT reset by
-- ConfirmPlacement/CancelPlacement, so it persists across placements until toggled again. Read by
-- StartPlacementPreview/StartRelocatePreview (kills floor-lock + swaps in the 350uu free-build start
-- distance / 125uu grab floor) -- doesn't require an active placement to flip, unlike
-- TogglePlacementPhysics above.
function Spawner.ToggleFreeBuild()
    -- Blocked mid-placement (2026-08-21, RedFalcon: "While in the middle of placing F8 should not be
    -- allowed because it gets confusing as the current placing doesnt change") -- flipping the flag
    -- only affects the NEXT StartPlacementPreview/StartRelocatePreview call (offsets are computed once
    -- at grab/spawn time), so toggling mid-follow silently does nothing to what's currently being
    -- placed -- confusing, since the toast still says it changed. F6/F5 out of the current placement
    -- first, then F8.
    if Spawner._placementActive then
        print("[LivingBase] Free build toggle: finish or cancel the current placement first (F5/F6).\n")
        pcall(function() Spawner.Toast("Confirm or cancel the current placement first.", 2.5) end)
        return
    end
    Spawner._placementFreeBuild = not Spawner._placementFreeBuild
    print("[LivingBase] Free build mode: " .. (Spawner._placementFreeBuild and "ON (no floor lock)" or "OFF (floor lock)") .. ".\n")
    pcall(function() Spawner.Toast(Spawner._placementFreeBuild and "Free Build ON -- floor lock off." or "Free Build OFF -- floor lock on.", 2.5) end)
end

-- Spawner.UpdateHoverHighlight/ClearHoverHighlight -- REAL FEATURE (2026-08-20, RedFalcon's
-- request): while nothing is target-locked and nothing is being placed/relocated, ghost-highlight
-- whatever's under the reticle right now, so it's visually clear what WOULD get picked before
-- committing to Num+/F7. Driven by a persistent poll loop in main.lua (gated on modEnabled there,
-- since that flag is a main.lua-local this file can't see directly) -- this file only does the
-- per-tick work: a proper line trace (GetKismetSystemLibrary():LineTraceSingle, confirmed working
-- in this exact game via the bundled LineTraceMod/Scripts/main.lua reference implementation) rather
-- than a FindAllOf("Actor") world sweep -- RedFalcon's own concern about continuous load was right
-- to raise; a raycast against the physics engine's spatial structures is the cheap way to do this
-- repeatedly, a full actor-list scan every tick would not have been.
--
-- Applies the same MI_Building_SimplifiedPreview material Spawner.ApplyGhostMaterial (2026-08-19
-- spike) used, via the same proven-safe SetMaterial path -- but additionally records each touched
-- component+slot's ORIGINAL material first, so the previous hover target can be restored exactly
-- when the reticle moves to something else (or nothing).
-- Consecutive-miss debounce (2026-08-20, RedFalcon's flicker report) -- see the check site's own
-- comment below for why. hoverMissStreak resets to 0 both on a real hit and here on actual clear.
-- Raised from 2 to 6 (2026-08-20) -- 2 (~300ms grace) wasn't enough, still flickered live.
local HOVER_MISS_TOLERANCE = 6
local hoverMissStreak = 0
local function restoreHoverMaterials()
    if Spawner._hoverOriginalMats then
        for _, e in ipairs(Spawner._hoverOriginalMats) do
            local ok, err = pcall(function()
                if not (e.comp and e.comp:IsValid()) then error("comp invalid at restore time") end
                if not (e.mat and e.mat:IsValid()) then error("saved mat invalid at restore time") end
                e.comp:SetMaterial(e.slot, e.mat)
                -- Render refresh attempt (2026-08-21, RedFalcon: "skin texture still stays white") --
                -- both apply and restore diagnostics confirmed clean (every slot saved, every restore
                -- call succeeds with a valid comp+mat, no thrown errors) -- so SetMaterial IS
                -- correctly reassigning the exact original object back to the slot, yet it still
                -- renders wrong. Trying the cheap, safe theory first: a skeletal mesh with a dynamic
                -- material instance may just not be refreshing its render state on a runtime
                -- SetMaterial the way a static mesh does. MarkRenderStateDirty is a standard, safe UE
                -- call (unlike CreateDynamicMaterialInstance, which is confirmed to crash this game
                -- natively and stays disabled elsewhere in this file) -- if this alone fixes it, no
                -- need for the riskier "capture+reapply material parameters by hand" approach.
                pcall(function() e.comp:MarkRenderStateDirty() end)
            end)
            -- TEMP DIAGNOSTIC (2026-08-21, remove once "skin doesn't turn back" is resolved) --
            -- applyHoverHighlight's own diagnostic showed every slot saved fine, so if restore is
            -- still failing, it has to be happening HERE -- either the component or the saved
            -- material reference went stale between apply and restore (e.g. an animated statue's
            -- render state refreshing), or SetMaterial itself threw. Nothing printed before now on
            -- this specific failure path, so this is the missing half of the picture.
            if not ok then
                local compClass = "?"
                pcall(function() compClass = e.comp:GetClass():GetFullName() end)
                print(string.format("[LivingBase] [hover-mat] RESTORE FAILED comp=%s slot=%s: %s\n",
                    compClass, tostring(e.slot), tostring(err)))
            end
        end
    end
    Spawner._hoverOriginalMats = nil
    Spawner._hoverActor = nil
    hoverMissStreak = 0
end

-- BUG FIX (2026-08-22, RedFalcon: "After targeting a person, the effect doesnt disable") -- this is
-- the fallback the poll loop (main.lua's hoverHighlightLoop) calls INSTEAD of UpdateHoverHighlight
-- once something becomes target-locked/the window closes/placement starts (see its own `eligible`
-- check) -- only ever knew about the material-swap path, so a spawned hover-effect actor was never
-- destroyed on that transition, left orphaned in the world. Now tears down both, same as
-- UpdateHoverHighlight's own transition/loss branches already do.
function Spawner.ClearHoverHighlight()
    restoreHoverMaterials()
    Spawner.ClearHoverEffect()
end

local HOVER_GHOST_MAT_PATH = "/Game/Environment/Gameplay/GDKit/Meshes/Building/MI_Building_SimplifiedPreview.MI_Building_SimplifiedPreview"
local function applyHoverHighlight(actor)
    local mat = resolveAsset(HOVER_GHOST_MAT_PATH)
    if not (mat and mat:IsValid()) then return end
    -- TEMP ISOLATION TEST (2026-08-21, RedFalcon: "let's disable the other slot and see if it
    -- doesn't change. if not then we know they're tied together") -- the log proved we only ever
    -- touch 2 slots per statue (eye + skin), both already skipped, so there's no mystery "other
    -- slot" left to disable individually. This flag disables ALL slots instead -- a full no-op
    -- highlight -- so the statue never gets ANY material swapped during hover. If the white area
    -- around the eyes still appears with this on, it's proven completely unrelated to our
    -- highlight/restore code (nothing left for us to even be doing wrong). Flip back to false to
    -- restore normal ghost-highlighting once the test is done.
    local disableAllForTest = Config.HOVER_HIGHLIGHT_DISABLE_ALL_TEST
    local saved = {}
    local function applyTo(comp)
        pcall(function() if comp ~= nil and type(comp) == "userdata" and comp.get then comp = comp:get() end end)
        if not (comp and comp:IsValid()) then return end
        local n = 0
        pcall(function() n = comp:GetNumMaterials() end)
        local compClass = "?"
        pcall(function() compClass = comp:GetClass():GetFullName() end)
        for slot = 0, (n - 1) do
            local orig
            local getOk = pcall(function() orig = comp:GetMaterial(slot) end)
            -- Skip skin slots entirely (2026-08-21, RedFalcon: "maybe highlighting everything but
            -- skin?") -- restoring a skin material back to its slot always succeeds (no error, valid
            -- comp+mat) but renders white afterward anyway, meaning the material INSTANCE's own
            -- parameters are what's wrong, not the slot assignment -- reapplying dynamic material
            -- parameters is a real rabbit hole (this codebase's one attempt at creating/writing a
            -- dynamic material instance, Spawner.ApplyGhostMaterialSolid, is disabled because
            -- CreateDynamicMaterialInstance crashes the game natively). Simplest fix: never touch a
            -- skin slot in the first place, so there's nothing to restore incorrectly.
            -- CONFIRMED LIVE (2026-08-21) -- the word "skin" NEVER appears in the material's own
            -- name; skin is named after the character archetype/body variant instead, e.g.
            -- "MI_Albion_Male_Medium" (matches this codebase's own naming convention elsewhere --
            -- config.lua builds skin material paths as "MI_" .. skinName .. "_" .. sex .. "_" ..
            -- build). What DOES reliably distinguish it from armor/hair/weapons/eyes (all under
            -- their own named subfolders) is the asset PATH: skin lives under
            -- ".../Skeletal_Meshes/Human/..." specifically.
            -- Eyes stay white after restore too (2026-08-21, RedFalcon: "the eyes stay white like
            -- the skin") -- same root cause as skin (dynamic material instance parameters, not slot
            -- assignment), same fix: never touch that slot. Per the memory doc, eyes live under their
            -- own named subfolder alongside Human/Armor/Hairs/Weapons under Skeletal_Meshes, so match
            -- "/eyes/" the same way as "/human/". TEMP: log origName whenever skipped so the actual
            -- path can be confirmed/corrected if this guess is wrong.
            local isSkin = disableAllForTest
            local origName
            if orig then
                pcall(function() origName = orig:GetFullName() end)
                if origName then
                    local lower = origName:lower()
                    if lower:find("/human/", 1, true) or lower:find("/eyes/", 1, true) or lower:find("/eye/", 1, true) then
                        isSkin = true
                    end
                end
            end
            if isSkin then
                print(string.format("[LivingBase] [hover-mat] SKIP %sslot comp=%s slot=%d path=%s\n",
                    disableAllForTest and "(ALL-DISABLED TEST) " or "skin/eye ", compClass, slot, tostring(origName)))
            end
            if not isSkin then
                local setOk = pcall(function() comp:SetMaterial(slot, mat) end)
                if setOk and orig and orig:IsValid() then
                    saved[#saved + 1] = { comp = comp, slot = slot, mat = orig }
                    -- TEMP DIAGNOSTIC (2026-08-21, RedFalcon: "the skin around the eyes is also
                    -- sticking white" -- reported AFTER the skin+eye skip above, with the log
                    -- confirming both slots 0/2 were correctly skipped and zero restore failures
                    -- anywhere -- so whatever's white isn't explained by the skip list yet. Logging
                    -- every APPLIED (non-skipped) slot's path too, alongside the existing SKIP/NOT
                    -- SAVED prints, gives full slot-by-slot visibility on the next test to find
                    -- whichever slot actually corresponds to the area around the eyes.
                    print(string.format("[LivingBase] [hover-mat] APPLY slot comp=%s slot=%d path=%s\n",
                        compClass, slot, origName or "?"))
                else
                    -- TEMP DIAGNOSTIC (2026-08-21, remove once material-restore is confirmed clean
                    -- for everything else) -- this slot got swapped to the ghost material (if setOk)
                    -- but ISN'T going to be restored, since nothing valid was saved for it.
                    print(string.format("[LivingBase] [hover-mat] NOT SAVED comp=%s slot=%d getOk=%s origIsValid=%s setOk=%s\n",
                        compClass, slot, tostring(getOk), tostring(orig and orig:IsValid()), tostring(setOk)))
                end
            end
        end
    end
    pcall(function() applyTo(actor.Mesh) end)
    for _, className in ipairs({ "StaticMeshComponent", "SkeletalMeshComponent" }) do
        local cls = StaticFindObject("/Script/Engine." .. className)
        if cls and cls:IsValid() then
            local comps
            local ok = pcall(function() comps = actor:K2_GetComponentsByClass(cls) end)
            if ok and comps then
                local n = 0
                pcall(function() n = comps:GetArrayNum() end)
                if n == 0 then pcall(function() n = #comps end) end
                for i = 1, n do
                    local comp
                    pcall(function() comp = comps[i] end)
                    if not comp then pcall(function() comp = comps:Get(i) end) end
                    applyTo(comp)
                end
            end
        end
    end
    Spawner._hoverActor = actor
    Spawner._hoverOriginalMats = saved
end

-- Called on a poll loop from main.lua (only while gated conditions hold there). Traces from the
-- camera out to Config.LIVE_EDIT_MAX_DIST -- excludes the player's own pawn/controller (same
-- reasoning Spawner.ProbeNearestActor's own camera-manager exclusion uses: those sit at/near the
-- camera transform and would otherwise "win" trivially). No-ops (and clears any stale highlight)
-- if the caller's own gating already lapsed by the time this runs.
-- Reads Config.LIVE_EDIT_MAX_DIST fresh on every call rather than caching it once (2026-08-20,
-- RedFalcon: "make sure the light up matches the target distance") -- that's also
-- pickTargetPreferringHover's own fallback range, so what lights up and what Num+ can actually
-- reach now can't drift apart even if that config value changes again later.
function Spawner.UpdateHoverHighlight()
    -- CONFIRMED LIVE (2026-08-20): after any lbreload, Spawner.spawned starts EMPTY (a plain
    -- in-memory table, wiped by the reload) even though the actual actors are still live in the
    -- world -- confirmed via spawnedCount=0 on every diagnostic line despite genuinely hovering a
    -- real placed prop. RetrackOrphans already exists for exactly this (re-associates live orphans
    -- against the ledger) but isn't called automatically anywhere on reload -- only certain other
    -- actions happen to trigger it. Calling it here is safe to do on every tick: it early-returns
    -- immediately (a single length check) once Spawner.spawned is non-empty, so the real cost (a
    -- full FindAllOf("Actor") world sweep) only happens once, right after a reload, not repeatedly.
    pcall(Spawner.RetrackOrphans)
    local ok, err = pcall(function()
        local pc = UEHelpers.GetPlayerController()
        if not (pc and pc:IsValid()) then
            restoreHoverMaterials(); return
        end
        local pawn = pc.Pawn
        local cam = pc.PlayerCameraManager
        if not (cam and cam:IsValid()) then
            restoreHoverMaterials(); return
        end
        local KSL = UEHelpers.GetKismetSystemLibrary()
        if not (KSL and KSL:IsValid()) then
            restoreHoverMaterials(); return
        end
        -- REVERTED (2026-08-20) -- tried pawn-origin/camera-direction to match findNearestSpawnInFront's
        -- reach, but that function's OWN comment already documents exactly why this specific mix is
        -- broken for anything DIRECTIONAL: "Origin AND direction must both come from the camera, or
        -- the cone points where the camera looks but starts from where the pawn's ROOT is... Mixing
        -- them made every press miss (confirmed 2026-08-06: every single live-edit press failed...
        -- even while visibly aimed at something)." findNearestSpawnInFront itself never actually
        -- combines pawn-position with camera-direction into one ray -- it runs TWO separate,
        -- non-directional checks (a plain distance-from-pawn radius, and an independent camera-cone
        -- angle test). A raycast is directional, so mixing sources breaks it the same way -- CONFIRMED
        -- LIVE: RedFalcon saw "look at it, doesn't highlight; look again, highlights briefly, stops"
        -- after this change, exactly the "works sometimes, not where it should" signature that
        -- comment describes. Camera origin + camera direction only, like before and like LineTraceMod's
        -- own reference implementation -- the range mismatch this was trying to fix needs a different
        -- solution that doesn't touch the ray's own math.
        local loc = cam:GetCameraLocation()
        local rot = cam:GetCameraRotation()
        local yaw, pitch = math.rad(rot.Yaw), math.rad(rot.Pitch)
        local cp = math.cos(pitch)
        local fx, fy, fz = cp * math.cos(yaw), cp * math.sin(yaw), math.sin(pitch)
        local traceDist = Config.LIVE_EDIT_MAX_DIST or 200.0
        local endPoint = { X = loc.X + fx * traceDist, Y = loc.Y + fy * traceDist, Z = loc.Z + fz * traceDist }
        local hitResult = {}
        local zero = { R = 0, G = 0, B = 0, A = 0 }
        -- bTraceComplex=true (2026-08-20, was false matching LineTraceMod's example) -- RedFalcon's
        -- flicker report. Decor props' SIMPLE collision (a rough box/capsule approximation) rarely
        -- matches their actual visual silhouette closely -- a ray that looks like it's squarely on
        -- the object can miss the simplified hull around curves/edges constantly, not just as rare
        -- jitter. Complex (per-triangle, against the real render mesh) matches what you actually see
        -- instead. Slightly more expensive per-trace, negligible at one trace per 150ms tick.
        -- REVERTED to channel 0 (2026-08-21) -- channel 2 was tried on the theory it meant "Pawn"
        -- (matching LetFurniturePass's own "Block Pawn" comment), CONFIRMED LIVE to break targeting
        -- entirely, even for decor which had always worked fine on channel 0 -- that comment's
        -- channel numbering doesn't match this trace API's actual indices. The real reason statues
        -- couldn't be targeted (LetFurniturePass, Config.STATUE_IGNORE_FURNITURE, sets every
        -- collision channel to Ignore at spawn time except its own "channel 2") is still valid --
        -- just fixed at the SOURCE instead: LetFurniturePass now also blocks channel 0, the channel
        -- THIS trace has always actually used and is confirmed working on, rather than changing the
        -- trace to chase an unverified channel number.
        -- Pawn-native targeting (2026-08-24, RedFalcon's request) -- FIRST ATTEMPT, UNTESTED LIVE
        -- YET. Replaces the channel-based LineTraceSingle(..., 0, ...) above (TraceTypeQuery 0 =
        -- Visibility) with LineTraceSingleByObjectType, which queries by OBJECT TYPE instead of
        -- trace channel. Why: EnsureRaytraceChannel's own Visibility-block (added 2026-08-22 so
        -- THIS trace could hit walking NPCs/idle Senkamati/drops at all) turned out to also make
        -- every mod-spawned actor register as solid "ground" to any OTHER pawn's own foot-IK trace
        -- -- confirmed live, both wild-vs-mod and mod-vs-mod -- causing a visible leg-lift glitch.
        -- An object-type query can hit a pawn via its ALREADY-existing native Pawn-channel collision
        -- (every Character blocks Pawn by default -- no per-actor setup needed) and hit decor/
        -- statues via their existing WorldStatic/WorldDynamic collision, without ever touching
        -- Visibility or requiring EnsureRaytraceChannel's per-component modification at all -- so
        -- that function can stay permanently disabled once this is confirmed working, no tradeoff
        -- needed. Same call shape as LineTraceSingle otherwise (this file's own confirmed-working
        -- params), just the single channel enum swapped for an ObjectTypes array. Values assumed at
        -- Unreal's own default project-settings numbering (1=WorldStatic, 2=WorldDynamic, 3=Pawn) --
        -- same "assume defaults, confirm live" approach already proven right for TraceTypeQuery
        -- elsewhere in this file (LetFurniturePass's own comment). NOT YET LIVE-CONFIRMED -- if this
        -- misses everything, errors, or only hits some of {pawns, decor, statues}, the fallback is
        -- reverting this one line back to `KSL:LineTraceSingle(pawn, loc, endPoint, 0, true, {}, 0,
        -- hitResult, true, zero, zero, 0.0)` and re-enabling EnsureRaytraceChannel's commented-out
        -- SetCollisionResponseToChannel call (accepting the IK glitch back) rather than guessing
        -- blind at more object-type numbers.
        -- CORRECTED (2026-08-24) -- `LineTraceSingleByObjectType` doesn't exist in this UE4SS build
        -- (CONFIRMED LIVE: nullptr on the method call itself). `lbprobeksl` (Spawner.
        -- ProbeKSLTraceFunctions, see its own comment) dumped KismetSystemLibrary's real function
        -- list -- the actual name is `LineTraceSingleForObjects` (older UE4-style naming), same
        -- argument shape otherwise.
        local wasHit = KSL:LineTraceSingleForObjects(pawn, loc, endPoint, {1, 2, 3}, true, {}, 0, hitResult, true, zero, zero, 0.0)
        local hitActor
        if wasHit then
            -- Field name/depth for the hit actor moved across UE versions -- LineTraceMod's own
            -- reference implementation documents the split; Windrose is confirmed 5.6 (>= 5.4).
            pcall(function() hitActor = hitResult.HitObjectHandle.ReferenceObject:Get() end)
            -- CONFIRMED LIVE (2026-08-20): in THIS build, ReferenceObject resolves to the hit
            -- PRIMITIVE COMPONENT (e.g. "StaticMeshComponent ...StaticMesh"), not the owning Actor
            -- -- contradicts what LineTraceMod's own reference implementation assumes for >=5.4,
            -- but that's what the log showed every time. applyHoverHighlight/etc. all expect an
            -- Actor (K2_GetComponentsByClass, .Mesh are Actor-level). Walk up via GetOwner() if
            -- what we got back isn't already an Actor -- try it unconditionally rather than
            -- branching on a class check, since components have GetOwner() and Actors don't, so
            -- this is naturally a no-op (owner stays nil, pcall'd) when hitActor is already correct.
            if hitActor and hitActor:IsValid() then
                pcall(function()
                    local owner = hitActor:GetOwner()
                    if owner and owner:IsValid() then hitActor = owner end
                end)
            end
        end
        -- SCOPED to our own tracked spawns only (2026-08-20, RedFalcon: "we definitely only want to
        -- target spawns as otherwise its confusing") -- the raw raycast hits ANY actor, native
        -- Windrose building pieces included, which is why those were lighting up too. A hit on
        -- something we didn't spawn is treated exactly like a miss (same debounce path below).
        -- Compare by INSTANCE PATH, not raw actor reference (2026-08-20) -- `==` on two separately-
        -- fetched UE4SS Lua actor handles isn't reliable even when they represent the exact same
        -- underlying engine object (a known wrapper-identity pitfall this codebase already works
        -- around elsewhere, e.g. the spawn ledger / Spawner.DespawnActor's own matching). Confirmed
        -- live: a genuinely-spawned-this-session object still read isOurs=false under raw `==`.
        -- trackedActor (2026-08-20): the STABLE reference from Spawner.spawned itself, not the raw
        -- hitActor the raycast/GetOwner() freshly resolves every single tick. Same wrapper-identity
        -- pitfall as the isOurs fix above bit the "is this still the same thing I'm already
        -- highlighting" check too -- comparing hitActor ~= Spawner._hoverActor with TWO
        -- independently-fetched handles was true on basically every tick even while steadily
        -- aiming at one object, restoring-then-reapplying the material every 150ms -- CONFIRMED
        -- LIVE as the actual cause of the flicker RedFalcon kept seeing even after the
        -- bTraceComplex fix and the miss-tolerance debounce, neither of which touched this. Always
        -- storing/comparing the SAME Spawner.spawned entry's own actor reference sidesteps the
        -- wrapper-identity problem entirely, the same way actorInstancePath() does for isOurs.
        local isOurs = false
        local trackedActor = nil
        if hitActor and hitActor:IsValid() then
            local hitPath = actorInstancePath(hitActor)
            if hitPath then
                for _, e in ipairs(Spawner.spawned) do
                    if e.actor and e.actor:IsValid() and actorInstancePath(e.actor) == hitPath then
                        isOurs = true
                        trackedActor = e.actor
                        break
                    end
                end
            end
        end
        -- (2026-08-21) Statue targeting confirmed fixed (RemoteUnrealParam unwrap in
        -- Spawner.LetFurniturePass) -- removed the throttled per-tick wasHit/hitClass/isOurs
        -- diagnostic that lived here during that hunt, since it printed continuously forever
        -- otherwise. Reintroduce the same pattern if targeting regresses again.
        -- REINTRODUCED, throttled (2026-08-22, RedFalcon: "walking actors, the idle senkamati, and
        -- the drops decor need to be added to raytrace targeting because i cant target them
        -- currently") -- the existing "RESTORE after N misses" print below only ever fires as a
        -- TRANSITION away from an already-successful hover, so it says nothing for something that
        -- never highlights in the first place. This fires at most once/second, only on a hit that
        -- ISN'T tracked as ours, showing the raw hit actor's class/instance -- tells us whether the
        -- raycast is even connecting at all (collision-channel issue, same root cause as the
        -- original statue saga) vs. connecting but failing the Spawner.spawned lookup (an
        -- untracked/orphaned-reference issue instead).
        if wasHit and not isOurs and hitActor and hitActor:IsValid() then
            local nowT = os.time()
            if not Spawner._hoverMissLogAt or nowT ~= Spawner._hoverMissLogAt then
                Spawner._hoverMissLogAt = nowT
                local cls = "?"
                pcall(function() cls = hitActor:GetClass():GetFullName() end)
                print(string.format("[LivingBase] [hover-diag] hit NOT-OURS actor class=%s\n", cls))
            end
        end
        if isOurs and trackedActor ~= pawn and trackedActor ~= pc then
            hoverMissStreak = 0
            if trackedActor ~= Spawner._hoverActor then
                -- TEMP DIAGNOSTIC (2026-08-20, remove once flicker is confirmed fixed): RedFalcon
                -- reports SPORADIC flicker even after bTraceComplex + the miss-tolerance debounce +
                -- the wrapper-identity fix above -- log every actual apply/restore transition (not
                -- every tick) so we can see the real timeline instead of guessing further blind.
                print(string.format("[LivingBase] [hover-transition] APPLY (was %s)\n",
                    Spawner._hoverActor and "something else" or "nothing"))
                -- Dispatch by target TYPE (2026-08-22, RedFalcon: use the spawned effect instead of
                -- the material swap for CHARACTER targets -- statues/walkers/Senkamati) -- tear down
                -- BOTH possible previous states unconditionally (each is a safe no-op if it wasn't
                -- the one actually active), then apply whichever path fits the NEW target. A
                -- SkeletalMeshComponent (actor.Mesh) is what every one of the named categories has
                -- in common and decor never does -- same distinguishing test this whole session's
                -- skin/eye investigation kept coming back to.
                restoreHoverMaterials()
                Spawner.ClearHoverEffect()
                local isCharacter = false
                pcall(function()
                    local m = trackedActor.Mesh
                    isCharacter = (m ~= nil) and m:IsValid()
                end)
                if isCharacter then
                    Spawner.SpawnHoverEffect(trackedActor)
                else
                    applyHoverHighlight(trackedActor)
                end
            elseif Spawner._hoverEffectActor and Spawner._hoverEffectActor:IsValid() then
                -- Same target as last tick, effect-mode active -- keep it following (idle animation
                -- drift, or a genuinely walking actor still moving while hovered). Plain
                -- K2_SetActorLocation, the same proven-safe call used everywhere else in this file.
                -- Reuses Spawner.ComputeHoverEffectLoc (2026-08-22) so the pose-based height drop
                -- stays identical to whatever SpawnHoverEffect used at spawn time -- otherwise a
                -- sitting/sleeping statue's effect would snap back up to the raw (too-high) pivot on
                -- the very first reposition tick after spawning correctly.
                pcall(function()
                    local loc = Spawner.ComputeHoverEffectLoc(trackedActor)
                    if loc then Spawner._hoverEffectActor:K2_SetActorLocation(loc, false, {}, true) end
                end)
            end
        elseif Spawner._hoverActor then
            -- CONFIRMED LIVE (2026-08-20): RedFalcon saw the highlight flicker -- briefly going back
            -- to the real texture then reappearing -- while steadily aiming at one object. A raycast
            -- misses for an isolated tick now and then (aim micro-jitter, or a small gap between the
            -- visual mesh and its actual collision), and clearing on the FIRST miss made that one
            -- dropped tick instantly visible. Require a couple consecutive misses before actually
            -- restoring, so one bad tick doesn't flicker but genuinely looking away still clears
            -- promptly (worst case ~2 extra ticks of latency, well under half a second at 150ms).
            hoverMissStreak = hoverMissStreak + 1
            if hoverMissStreak >= HOVER_MISS_TOLERANCE then
                print(string.format("[LivingBase] [hover-transition] RESTORE after %d consecutive misses (isOurs=%s wasHit=%s)\n",
                    hoverMissStreak, tostring(isOurs), tostring(wasHit)))
                restoreHoverMaterials()
                Spawner.ClearHoverEffect()
            end
        end
    end)
    if not ok then
        print("[LivingBase] [hover] UpdateHoverHighlight FAILED: " .. tostring(err) .. "\n")
        restoreHoverMaterials()
    end
end

-- Is this class one of our decoration props? (used to solidify restored decorations, which don't carry
-- the DECOR_ label.) Builds a lookup once from Config.DECOR_CATEGORIES.
local decorPathSet
function Spawner.IsDecorClass(path)
    if not decorPathSet then
        decorPathSet = {}
        for _, list in pairs(Config.DECOR_CATEGORIES or {}) do
            for _, e in ipairs(list) do if e.path then decorPathSet[e.path] = true end end
        end
    end
    return decorPathSet[path] == true
end

-- Spawner.SolidifyDecor() — enable collision on every tracked decoration (fresh OR restored). Runs on a
-- delay after load so restored props become solid without the player respawning them.
function Spawner.SolidifyDecor()
    if Config.DECOR_COLLISION == false then return 0 end
    local n = 0
    for _, e in ipairs(Spawner.spawned or {}) do
        local isD = (type(e.label) == "string" and e.label:sub(1, 6) == "DECOR_") or Spawner.IsDecorClass(e.class)
        if isD and e.actor and e.actor:IsValid() then Spawner.SetDecorSolid(e.actor); n = n + 1 end
    end
    if n > 0 then print(string.format("[LivingBase] Decor collision ON for %d placed prop(s).\n", n)) end
    return n
end

-- Spawner.FixLastProbedGhost() -- TEMP DEV TOOL / recovery command (2026-08-20, RedFalcon: a follow
-- session got stuck mid-drag and left an object "sitting there like a ghost with no physics and is
-- unselectable" -- survived THREE separate SolidifyDecor sweeps across multiple reloads without ever
-- getting fixed. Root cause: SolidifyDecor only re-solidifies actors it classifies AS DECOR (label
-- prefix "DECOR_" or Spawner.IsDecorClass(e.class)) -- if this particular actor's class/label doesn't
-- match either check, the sweep silently skips it every single time, reload after reload, no matter
-- how many times it runs. This bypasses that classification entirely: run "lbprobe" (console command,
-- pure distance/angle math, NOT a raycast -- works even with the ghost's collision disabled, unlike
-- Num+/hover-highlight which need collision to detect anything) aimed at the ghost first, THEN this,
-- and it force-solidifies whatever lbprobe cached as Spawner._lastProbedActor directly -- no
-- classification check at all, same SetDecorSolid call SolidifyDecor itself uses per-object.
function Spawner.FixLastProbedGhost()
    local target = Spawner._lastProbedActor
    if not (target and target:IsValid()) then
        print("[LivingBase] [fixghost] no valid probed target -- run lbprobe aimed at it first.\n")
        return
    end
    local label = "?"
    pcall(function() label = target:GetFullName() end)
    pcall(function() Spawner.SetDecorSolid(target) end)
    print("[LivingBase] [fixghost] solidified: " .. tostring(label) .. "\n")
end

-- Spawner.ProbeRadius(radius, say) -- TEMP DEV TOOL (2026-08-20): "do we still have that command that
-- lets me probe in a radius around me?" -- lbcustomscan exists but is scoped to actors with a
-- composite mesh (character-type actors) for a totally different purpose, would miss a decor ghost
-- entirely. This is the general-purpose version: lists EVERY actor within radius of the pawn, no type
-- filter, sorted nearest-first, flagging whether each is currently TRACKED (present in
-- Spawner.spawned, by the same actorInstancePath comparison used throughout this file) and whether
-- its collision is currently enabled -- exactly the two questions this session's stuck-ghost hunt
-- needs answered: is it still a real actor at all, and if so, is it one we've lost track of. Same
-- FindAllOf("Actor") + ipairs sweep pattern as Spawner.RetrackOrphans (already proven safe), plain
-- distance math only -- no reflection, no collision dependency, so a collision-less ghost still shows
-- up like anything else.
function Spawner.ProbeRadius(radius, say)
    say = say or print
    radius = tonumber(radius) or 500.0
    local pc, pawn
    pcall(function()
        pc = UEHelpers.GetPlayerController()
        pawn = pc and pc:IsValid() and pc.Pawn
    end)
    if not (pawn and pawn:IsValid()) then
        say("[LivingBase] [proberadius] no player pawn.\n")
        return
    end
    local origin
    pcall(function() origin = pawn:K2_GetActorLocation() end)
    if not origin then
        say("[LivingBase] [proberadius] could not read pawn location.\n")
        return
    end
    local trackedPaths = {}
    for _, e in ipairs(Spawner.spawned or {}) do
        if e.actor and e.actor:IsValid() then
            local p = actorInstancePath(e.actor)
            if p then trackedPaths[p] = true end
        end
    end
    local actors
    local ok = pcall(function() actors = FindAllOf("Actor") end)
    if not (ok and actors) then
        say("[LivingBase] [proberadius] FindAllOf('Actor') returned nothing.\n")
        return
    end
    local hits = {}
    for _, a in ipairs(actors) do
        if a and a:IsValid() then
            local l
            pcall(function() l = a:K2_GetActorLocation() end)
            if l then
                local dx, dy, dz = l.X - origin.X, l.Y - origin.Y, l.Z - origin.Z
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                if d <= radius then
                    local cls = "?"
                    pcall(function() cls = a:GetClass():GetFullName() end)
                    local path = actorInstancePath(a)
                    local collision
                    pcall(function() collision = a:GetActorEnableCollision() end)
                    table.insert(hits, { dist = d, cls = cls, tracked = (path and trackedPaths[path]) or false, collision = collision })
                end
            end
        end
    end
    table.sort(hits, function(x, y) return x.dist < y.dist end)
    say(string.format("[LivingBase] [proberadius] %d actor(s) within %.0fuu:", #hits, radius))
    local MAX_RESULTS = 60
    for i = 1, math.min(#hits, MAX_RESULTS) do
        local h = hits[i]
        say(string.format("[LivingBase] [proberadius] #%d %.0fuu tracked=%s collision=%s class=%s",
            i, h.dist, tostring(h.tracked), tostring(h.collision), tostring(h.cls)))
    end
    if #hits > MAX_RESULTS then
        say(string.format("[LivingBase] [proberadius] ... %d more not shown (capped at %d).", #hits - MAX_RESULTS, MAX_RESULTS))
    end
end

-- Spawner.EditNearestInFront(dZ, dYaw) — LIVE FINE-TUNE the placed object in front of you: raise/lower
-- it by dZ and rotate it by dYaw, in place, and PERSIST the new pose so it survives a reload. Works on
-- any tracked spawn (statue, decoration, ...). Because chair-sitter facings are baked into the anim and
-- decoration meshes sit offset above their root, spawn placement can't always be perfect; this lets you
-- nudge each to sit and face right in the base. Logs the running offsets so a good value can be baked
-- into config (yaw offset vs placement, height offset vs placement).
--------------------------------------------------------------------
-- dZ = raise/lower · dYaw = rotate · dFwd = move along the player's facing (+away/-toward you) ·
-- dRight = move across it (+player-right/-player-left). All optional; a key passes just the one it drives.
--
-- Re-picks "nearest thing in front" fresh on every keypress UNLESS Spawner.lockedTarget is set (Num+
-- toggle, see Spawner.ToggleTargetLock) — an automatic PER-PRESS caching version of this was tried
-- early in this project and didn't help (it was chasing a different bug — see the "target-lock caching"
-- line in this file's own history — and was quietly transparent, no toast, no way to tell it was active).
-- This is a different, deliberate mechanism: an explicit, user-toggled pin with its own toast feedback,
-- shared (via findNearestSpawnInFront itself) with despawn and cycle too. Two things ARE kept tighter
-- than the original version to reduce mis-picks when UNLOCKED: a much smaller search radius
-- (LIVE_EDIT_MAX_DIST, 200uu, vs. the 700uu shared with the despawn-in-front key) so it's less likely to
-- grab something other than what you're standing next to, and a close-range floor (in the shared
-- findNearestSpawnInFront helper above) for stability right up close.

-- ⚠ OPEN ISSUE (2026-08-16): holding ROTATE for an extended period via the LivingBaseSpawnMenu
-- move panel crashed the game AFTER the SetActorHiddenInGame fix below was deployed and had
-- separately held up under heavy slide/height nudging -- so whatever this is, it's specific to
-- sustained dYaw (rotation), not this whole function. Not yet investigated. Next step: reproduce
-- with JUST rotate held (isolated from slide/height), check whether the log stops mid-stream with
-- zero trapped error (same "uncatchable crash" signature as the toggle bug was), and look at
-- whether K2_SetActorRotation behaves differently under sustained rapid calls than
-- K2_SetActorLocation does. See memory/project_livingbase_spawn_menu.md for the full history.
-- dPitch/dRoll (2026-08-18): full 3-axis rotation, for props that can rest at any angle (a coin,
-- an ingot, a dropped weapon) unlike a statue/NPC, which only ever needed dYaw. Same delta/mod-360
-- treatment as dYaw below, just on the other two Euler components; optional, so every EXISTING
-- caller (keyboard live-edit, which only ever drove dZ/dYaw/dFwd/dRight) keeps working unchanged.
function Spawner.EditNearestInFront(dZ, dYaw, dFwd, dRight, dPitch, dRoll)
    -- Fires FIRST, before any lookup — so the log proves the keypress reached us even when there's
    -- nothing in front to edit. If you press a live-edit key and DON'T see this line, that key is
    -- being consumed by the game before UE4SS sees it (like '[' and numpad-0 were).
    -- print() directly, NOT log() — log() is gated behind Config.VERBOSE and was silently hiding all of
    -- this tool's output, which made the keys look dead when they were firing fine.
    print(string.format("[LivingBase] live-edit key: dZ=%.0f dYaw=%.0f dFwd=%.0f dRight=%.0f dPitch=%.0f dRoll=%.0f\n",
        dZ or 0.0, dYaw or 0.0, dFwd or 0.0, dRight or 0.0, dPitch or 0.0, dRoll or 0.0))
    local maxDist = Config.LIVE_EDIT_MAX_DIST or 200.0
    -- Live-edit is now LOCK-ONLY (2026-08-20, RedFalcon: "we're locking live edit to targets only" --
    -- raytrace replaces the cone as the visual truth for what's targetable, so there's no more
    -- automatic "nearest thing in front" fallback here). No lock, no edit -- walk up and press Num+
    -- (hover-highlight shows what that would grab) before nudging anything. findNearestSpawnInFront is
    -- still called below, not reimplemented, since it already owns the lock-validity/leash-distance
    -- check (Spawner.TargetLockDistanceCheck) shared with the periodic lock tick -- this just refuses
    -- to let it fall through to ITS OWN cone/radius sweep by never calling it when unlocked.
    if not Spawner.lockedTarget then
        print("[LivingBase] Edit: no target locked.\n")
        pcall(function() Spawner.Toast("Live-edit: no target locked -- press Num+ on something first.", 2.5) end)
        return
    end
    -- findNearestSpawnInFront also returns a pawn-facing fx/fy pair (its own target-pick logic uses
    -- the camera's look direction instead -- picking and moving were always allowed to use different
    -- facings) -- no longer bound here since decor's own slide frame moved off the player's facing
    -- entirely, onto a fixed world axis (2026-08-19, see the slide-frame comment below).
    local bestI, e, bestD, px, py, pz = findNearestSpawnInFront(maxDist)
    if not px then
        print("[LivingBase] Edit: no player pawn.\n")
        pcall(function() Spawner.Toast("Live-edit: no player pawn found.", 2.5) end)
        return
    end
    if not bestI then
        -- Log only, no toast (same reasoning as the per-nudge "Editing: ..." toast removed above --
        -- live-edit keys are pressed/held rapidly, so even the miss case got spammy).
        print(string.format("[LivingBase] Edit: nothing within %.0fuu ahead — walk closer / face it.\n", maxDist))
        return
    end

    -- Static props ignore runtime moves on the render thread — make it Movable first, or the mesh
    -- stays put on screen even though SetActorLocation succeeds (the bug RedFalcon kept hitting).
    Spawner.MakeMovable(e.actor)
    -- Slide frame: STATUES move along their OWN facing (so fwd/back/left/right track the pose the statue
    -- is set to); DECORATIONS move along a FIXED WORLD axis (2026-08-19, RedFalcon's request -- was the
    -- player's own facing, which meant forward/right for an object silently changed direction depending
    -- on which way you happened to be standing when you nudged it, making repeated edits inconsistent).
    -- Statues are AnimatedActor/QuestStatic classes.
    local statueFrame = (e.class and (string.find(e.class, "AnimatedActor", 1, true)
        or string.find(e.class, "QuestStatic", 1, true))) and true or false
    local newX, newY, newZ, newYaw, newPitch, newRoll
    pcall(function()
        local l = e.actor:K2_GetActorLocation()
        local r = e.actor:K2_GetActorRotation()
        -- Horizontal nudge: forward = frame facing; right = (-fwdY, fwdX). Fixed world +X/+Y by
        -- default (forward = world +X, right = world +Y), the statue's own facing when editing a
        -- statue.
        local afx, afy = 1.0, 0.0
        if statueFrame then local a = math.rad(r.Yaw); afx, afy = math.cos(a), math.sin(a) end
        local f, rt = (dFwd or 0.0), (dRight or 0.0)
        newX   = l.X + f * afx + rt * (-afy)
        newY   = l.Y + f * afy + rt * (afx)
        newZ   = l.Z + (dZ or 0.0)
        newYaw   = (r.Yaw   + (dYaw   or 0.0)) % 360.0
        newPitch = (r.Pitch + (dPitch or 0.0)) % 360.0
        newRoll  = (r.Roll  + (dRoll  or 0.0)) % 360.0
        e.actor:K2_SetActorLocation({ X = newX, Y = newY, Z = newZ }, false, {}, true)
        e.actor:K2_SetActorRotation({ Pitch = newPitch, Yaw = newYaw, Roll = newRoll }, false)
        -- SetActorHiddenInGame(true)/(false) toggle DISABLED (2026-08-16, RedFalcon) -- originally
        -- added because the rendered mesh apparently only picked up a moved actor's new transform
        -- when it streamed out/in (walking away and back "refreshed" it), so this forced the same
        -- effect by briefly toggling visibility to make the engine re-register render state. Turned
        -- out unnecessary -- Spawner.MakeMovable (above) is sufficient on its own for a Movable
        -- component to pick up transform changes on the render thread every frame; this toggle was a
        -- leftover from before that was understood, not a real requirement.
        -- CONFIRMED root cause of a crash reproduced by the LivingBaseSpawnMenu move panel
        -- (2026-08-16): holding a nudge button fires this repeatedly in quick succession -- a volume
        -- of render-state toggling keyboard-driven edits never came close to (this UE4SS build drops
        -- most keydown repeats, so the effective keyboard rate was always far lower). The crash log
        -- showed no trapped error either time (same "uncatchable native crash" signature as other
        -- component-surgery-class crashes in this codebase, see WINDROSE_MODDING_NOTES.md §3).
        -- Isolated by controlled test: throttling the CALL RATE alone (down to 2/sec) did NOT stop
        -- the crash; disabling just this toggle (at 4/sec, unthrottled relative to that test) DID --
        -- confirms this toggle itself was the cause, not raw call frequency. Live-tested afterward:
        -- the mesh still visually updates on every nudge with this off, so it stays off for good.
        -- pcall(function() e.actor:SetActorHiddenInGame(true) end)
        -- pcall(function() e.actor:SetActorHiddenInGame(false) end)
    end)
    if not newZ then return end
    -- Persist the FULL new pose (X/Y/Z/yaw) matching the OLD home, then update our record so the next
    -- edit matches and a reload restores the moved position.
    local persisted = Spawner.PersistFindMatching(e.class, e.home)
    if persisted then
        print(string.format("[LivingBase] Persist match: %s at (%.1f,%.1f,%.1f) yaw=%.1f — editing this record.\n",
            persisted.classPath, persisted.X, persisted.Y, persisted.Z, persisted.yaw))
    else
        print("[LivingBase] Persist match: none found (not yet saved, or TRANSIENT) — editing live actor only.\n")
    end
    pcall(function() Spawner.PersistUpdatePose(e.class, e.home, { X = newX, Y = newY, Z = newZ }, newYaw, newPitch, newRoll) end)
    e.home = { X = newX, Y = newY, Z = newZ }

    local short = tostring(e.class or ""):match("([%w_]+)%.[%w_]+$") or tostring(e.class)
    local yawOff = e.yaw and string.format("yaw off %.0f", (newYaw - e.yaw) % 360.0) or "yaw ?"
    local zOff = e.z0 and string.format("z off %.0f", newZ - e.z0) or ""
    -- Log only, no toast: live-edit fires on every arrow/PageUp/comma/Num-rotate press, often held or
    -- repeated rapidly -- a toast per nudge was too spammy (user feedback, 2026-08-06).
    print(string.format("[LivingBase] EDIT %s  ->  %s  %s  (z=%.0f)\n", short, yawOff, zOff, newZ))
end

--------------------------------------------------------------------
-- Spawner.DespawnAll() — destroy everything this mod spawned.
--------------------------------------------------------------------
-- Bumped by every despawn. Delayed callbacks (de-corrupt retries, hair re-applies —
-- some fire up to 25s after a spawn) capture the value and bail if it changed, so they
-- never touch an actor that DEL just destroyed. That was crashing the game on DEL.
Spawner.generation = Spawner.generation or 0

-- Is this actor still one of ours? A despawned actor is removed from Spawner.spawned, so its own
-- pending callbacks bail here -- without cancelling everyone else's, the way a generation bump did.
function Spawner.IsTracked(actor)
    if not (actor and actor:IsValid()) then return false end
    for _, e in ipairs(Spawner.spawned or {}) do
        if e and e.actor == actor then return true end
    end
    return false
end

function Spawner.DespawnAll()
    Spawner.generation = Spawner.generation + 1
    local n = 0
    -- 1) in-memory tracked actors (this script session)
    local undoBatch = {}
    for _, entry in ipairs(Spawner.spawned) do
        if entry.actor and entry.actor:IsValid() then
            local undoPos, undoYaw
            pcall(function()
                local l = entry.actor:K2_GetActorLocation()
                local r = entry.actor:K2_GetActorRotation()
                undoPos = { X = l.X, Y = l.Y, Z = l.Z }
                undoYaw = r.Yaw
            end)
            local persisted = Spawner.PersistFindMatching(entry.class, entry.home)
            if undoPos then
                undoBatch[#undoBatch + 1] = {
                    class = entry.class, label = entry.label, pos = undoPos, yaw = undoYaw,
                    aiPath = persisted and persisted.aiPath, makeFriendly = persisted and persisted.makeFriendly,
                    look = persisted and persisted.look,
                }
            end
            if pcall(function() entry.actor:K2_DestroyActor() end) then n = n + 1 end
            Spawner.ReleaseTargetLockIfDestroyed(entry.actor)
        end
    end
    Spawner.PushUndo(undoBatch)
    Spawner.spawned = {}
    -- 2) ledger: catches spawns from before a Ctrl+R (in-memory table lost).
    --    StaticFindObject can't resolve level-instance paths, so scan LIVE
    --    actors and match by exact instance path. Only OUR spawns match
    --    (never your real crew/NPCs). Stale paths (post world-reload) match
    --    nothing and are harmless.
    --    NOTE: these are NOT added to the undo batch above — we only have their instance path here, not
    --    a clean class path to respawn from, so this rare (post-hot-reload) case isn't undo-able.
    local ledger = ledgerReadAndClear()
    if #ledger > 0 then
        local wanted = {}
        for _, p in ipairs(ledger) do wanted[p] = true end
        local actors = FindAllOf("Actor")
        if actors then
            for _, a in ipairs(actors) do
                if a and a:IsValid() then
                    local path = actorInstancePath(a)
                    if path and wanted[path] then
                        if pcall(function() a:K2_DestroyActor() end) then n = n + 1 end
                    end
                end
            end
        end
    end
    -- 3) clear the save file so nothing re-spawns on next world load.
    Spawner.PersistClear()
    log(string.format("Despawned %d actors + cleared save file.", n))
end

-- Spawner.UndoDespawn() — restore the most recently despawned object(s).
--------------------------------------------------------------------
-- A destroyed UE actor can't literally be un-destroyed, so "undo" means: capture the class + exact
-- position/rotation of each object right before it's removed, then respawn a fresh copy of the same
-- class at the same transform. Visually and functionally identical for statues/decorations (the vast
-- majority of what gets despawned) — the one thing NOT restored is per-actor runtime customization that
-- isn't baked into class/transform (e.g. a crew member's randomized composite look), since that data
-- doesn't survive the original despawn either.
-- Each despawn (single or DEL's clean-house) pushes one BATCH (a list, so DEL's undo restores everything
-- at once). Capped so a very long session doesn't grow this unbounded.
Spawner.undoStack = Spawner.undoStack or {}
local UNDO_STACK_MAX = 20

function Spawner.PushUndo(batch)
    if not batch or #batch == 0 then return end
    Spawner.undoStack[#Spawner.undoStack + 1] = batch
    while #Spawner.undoStack > UNDO_STACK_MAX do table.remove(Spawner.undoStack, 1) end
end

function Spawner.UndoDespawn()
    print("[LivingBase] undo key received.\n")
    local batch = table.remove(Spawner.undoStack)
    if not batch or #batch == 0 then
        print("[LivingBase] Undo: nothing to restore.\n")
        pcall(function() Spawner.Toast("Undo: nothing to restore.", 2.5) end)
        return
    end
    local restored = 0
    local restoredLabels = {}
    Spawner._suppressSpawnToast = true
    for _, item in ipairs(batch) do
        -- Cycle-pose undo: the roster swap didn't despawn its replacement -- it's still live at this
        -- spot -- so remove IT first, or restoring the old pose on top just stacks duplicates (and
        -- cycling again before undoing would pile up a third).
        if item.replaceActor then
            pcall(function()
                if item.replaceActor:IsValid() then item.replaceActor:K2_DestroyActor() end
            end)
            for si, s in ipairs(Spawner.spawned) do
                if s.actor == item.replaceActor then table.remove(Spawner.spawned, si); break end
            end
            Spawner.PersistRemoveMatching(item.replaceClass, item.replacePos or item.pos)
            -- If this cycle's replacement had inherited the target lock (CycleNearestInFront re-points
            -- the lock onto whatever it creates -- see that function's own comment), undoing the cycle
            -- just destroyed the locked actor. Release immediately rather than leaving a dangling lock.
            Spawner.ReleaseTargetLockIfDestroyed(item.replaceActor)
        end
        local ok = pcall(function()
            local actor = Spawner.Spawn(item.class, item.label, item.pos, nil, item.aiPath, item.yaw, item.makeFriendly, item.look)
            if actor and actor:IsValid() then
                restored = restored + 1
                restoredLabels[#restoredLabels + 1] = tostring(item.label)
            end
        end)
        if not ok then print("[LivingBase] Undo: failed to restore one item (class " .. tostring(item.class) .. ").\n") end
    end
    Spawner._suppressSpawnToast = false
    print(string.format("[LivingBase] Undo: restored %d/%d.\n", restored, #batch))
    pcall(function()
        local what
        if #restoredLabels == 0 then
            what = "nothing"
        elseif #restoredLabels <= 5 then
            what = table.concat(restoredLabels, ", ")
        else
            local shown = {}
            for i = 1, 5 do shown[i] = restoredLabels[i] end
            what = table.concat(shown, ", ") .. string.format(" (+%d more)", #restoredLabels - 5)
        end
        Spawner.Toast(string.format("Undo: restored %s", what), 3.0)
    end)
end


-- Spawner.CycleNearestInFront() -- swap the placed statue OR decoration in front of you for the NEXT
-- entry in its own roster (STANDING/SEATED/CHAIR/INTERACTIVE_STATUES, or a Config.DECOR_CATEGORIES
-- entry), in place: same spot, one shared PAIR of keys (']' forward / '[' backward -- briefly moved
-- to 'O'/'U' when ']'/'[' turned out to collide with the game's own "Change Target" bind, then moved
-- back the same day: more intuitive, and low-risk since Insert can disable every mod key outright
-- and cycling isn't happening mid-combat anyway; previously a single Num+ forward-only key until
-- 2026-08-07) auto-detecting which kind of roster the targeted
-- actor's class belongs to -- user asked for one key rather than a separate one per type (2026-08-06),
-- since the target is already uniquely identified by class either way. Undo-able: the replaced
-- actor is pushed onto the same undo stack Num9/DEL use, so Num0 reverts one cycle step if the new
-- pick isn't actually better than the old one.
-- Statues get a baked per-entry yaw correction (so a "faces backwards" quirk on one pose doesn't carry
-- onto another) and bounds-based re-leveling to the old floor height (poses can have different
-- root-to-ground offsets). Decorations get neither: no per-entry yaw field exists for them, and
-- placeDecorEntry's own comment in testbed.lua explains decoration bounds are unreliable for
-- floor-snapping (mesh often sits offset above the root) -- fresh placement uses playerFloorZ()+
-- zoffset instead of bounds for exactly that reason, so reusing bounds math here would reintroduce the
-- same problem. Decorations instead keep the EXACT old X/Y/Z; live-edit height fixes it if the new
-- entry's natural resting height differs, same as a fresh placement would need anyway.
local STATUE_ROSTERS = {
    { list = Config.STANDING_STATUES,    label = "standing" },
    { list = Config.SEATED_STATUES,      label = "seated" },
    { list = Config.CHAIR_STATUES,       label = "chairseat" },
    { list = Config.INTERACTIVE_STATUES, label = "interactive" },
}
-- One roster per Config.DECOR_CATEGORIES entry -- a targeted decoration cycles within its own
-- category (nature/boats/wrecks/tents/storage/furniture), regardless of which key spawned it.
local DECOR_ROSTERS
local function decorRosters()
    if not DECOR_ROSTERS then
        DECOR_ROSTERS = {}
        for cat, list in pairs(Config.DECOR_CATEGORIES or {}) do
            DECOR_ROSTERS[#DECOR_ROSTERS + 1] = { list = list, label = cat }
        end
    end
    return DECOR_ROSTERS
end

function Spawner.CycleNearestInFront(direction)
    direction = direction or 1
    print(string.format("[LivingBase] cycle key received (direction=%d).\n", direction))
    local maxDist = Config.LIVE_EDIT_MAX_DIST or 200.0
    local bestI, e = findNearestSpawnInFront(maxDist)
    if not bestI then
        print(string.format("[LivingBase] Cycle: nothing within %.0fuu ahead -- walk closer / face it.\n", maxDist))
        return
    end

    -- Which roster (if any) does this actor's class belong to, and at what index? Check statues first,
    -- then decorations -- the two roster sets never share a class path, so order doesn't matter for
    -- correctness, only for which error message a truly uncycleable actor gets (irrelevant either way).
    local kind, roster, curIdx, label
    for _, r in ipairs(STATUE_ROSTERS) do
        local list = r.list or {}
        for i, w in ipairs(list) do
            if w.path == e.class then kind, roster, curIdx, label = "statue", list, i, r.label; break end
        end
        if roster then break end
    end
    if not roster then
        for _, r in ipairs(decorRosters()) do
            local list = r.list or {}
            for i, d in ipairs(list) do
                if d.path == e.class then kind, roster, curIdx, label = "decor", list, i, r.label; break end
            end
            if roster then break end
        end
    end
    if not roster then
        print("[LivingBase] Cycle: " .. tostring(e.label) .. " isn't from a cycleable roster (Num3-6 statues or a decor list).\n")
        pcall(function() Spawner.Toast("Cycle: not a cycleable object.", 2.5) end)
        return
    end

    -- Lua's % is floored (result always in [0, #roster) even for a negative dividend), so this
    -- wraps correctly in BOTH directions: direction=1 steps forward, direction=-1 steps backward.
    local nextIdx = ((curIdx - 1 + direction) % #roster) + 1
    local curEntry, nextEntry = roster[curIdx], roster[nextIdx]
    local nextName = kind == "statue" and tostring(nextEntry.faction) or nextEntry.name

    -- Capture the CURRENT floor level (bottom of bounds, statues only) + live X/Y/yaw before destroying
    -- anything, so the replacement lands exactly where the old one was resting regardless of where the
    -- player is now.
    local oldX, oldY, oldZ, oldYaw, floorZ
    pcall(function()
        local l = e.actor:K2_GetActorLocation()
        local r = e.actor:K2_GetActorRotation()
        oldX, oldY, oldZ, oldYaw = l.X, l.Y, l.Z, r.Yaw
        if kind == "statue" then
            local origin, extent = e.actor:GetActorBounds(false)
            if origin and extent then floorZ = origin.Z - extent.Z end
        end
    end)
    if not oldX then
        print("[LivingBase] Cycle: couldn't read the current actor's transform.\n")
        return
    end
    -- Statues: preserve the conceptual facing across the swap by undoing the OLD entry's own baked yaw
    -- correction (if any), then applying the NEW entry's. Decorations have no such field -- keep yaw as-is.
    local newYaw = kind == "statue"
        and ((oldYaw - (curEntry.yaw or 0) + (nextEntry.yaw or 0)) % 360.0)
        or oldYaw

    local persisted = Spawner.PersistFindMatching(e.class, e.home)
    local oldShort = tostring(e.class):match("([%w_]+)%.[%w_]+$") or tostring(e.class)
    local newShort = tostring(nextEntry.path):match("([%w_]+)%.[%w_]+$") or tostring(nextEntry.path)
    print(string.format("[LivingBase] Cycle %s %d/%d: %s -> %s\n", label, nextIdx, #roster, oldShort, newShort))

    -- Same undo shape as a despawn: capture class/pos/yaw + persisted AI/look BEFORE removing, so Num0
    -- can bring the old one back if the new pick turns out to be worse. `replaceActor`/`replaceClass`
    -- get filled in below once the new actor exists -- Num0 needs to destroy THAT before respawning
    -- the old one, or the two end up stacked on top of each other at the same spot.
    local undoItem = {
        class = e.class, label = e.label, pos = { X = oldX, Y = oldY, Z = oldZ }, yaw = oldYaw,
        aiPath = persisted and persisted.aiPath, makeFriendly = persisted and persisted.makeFriendly,
        look = persisted and persisted.look,
    }
    Spawner.PushUndo({ undoItem })

    pcall(function() e.actor:K2_DestroyActor() end)
    table.remove(Spawner.spawned, bestI)
    Spawner.PersistRemoveMatching(e.class, e.home)

    local newLabel = kind == "statue" and (label:upper() .. "_" .. tostring(nextEntry.faction))
        or (nextEntry.label or nextEntry.name) -- see placeDecorEntry's own comment for why no "DECOR_" prefix
    Spawner._suppressSpawnToast = true
    local ok, newActor = pcall(function()
        return Spawner.Spawn(nextEntry.path, newLabel, { X = oldX, Y = oldY, Z = oldZ }, nil, nil, newYaw)
    end)
    Spawner._suppressSpawnToast = false
    if not (ok and newActor and newActor:IsValid()) then
        print("[LivingBase] Cycle: replacement spawn failed -- the old one is gone; Num0 can restore it.\n")
        pcall(function() Spawner.Toast("Cycle failed to spawn replacement -- Num0 to restore.", 3.0) end)
        return
    end
    undoItem.replaceActor = newActor
    undoItem.replaceClass = nextEntry.path
    undoItem.replacePos = { X = oldX, Y = oldY, Z = oldZ }

    -- Carry a target lock forward onto the replacement: e.actor (just destroyed) is exactly what
    -- Spawner.lockedTarget would be pointing at if this spot was locked, so re-point the lock at
    -- newActor rather than letting it fall through to "locked target no longer exists". Lets you lock
    -- once, cycle through several looks in place, and keep nudging with live-edit the whole time without
    -- re-locking after every cycle press. label reads back from Spawner.spawned (its just-inserted
    -- LAST entry) rather than the raw `newLabel` passed to Spawn above -- Spawn resolves that into a
    -- unique numbered instance label internally (2026-08-16), so the raw value here is stale/wrong,
    -- same fix ReplaceNearestInFront already applies below via its own `newEntry.label` read.
    if Spawner.lockedTarget and Spawner.lockedTarget.actor == e.actor then
        local resolvedLabel = Spawner.spawned[#Spawner.spawned] and Spawner.spawned[#Spawner.spawned].label or newLabel
        Spawner.lockedTarget = { actor = newActor, label = resolvedLabel, class = nextEntry.path }
    end

    if kind == "statue" then
        -- Re-level to the OLD floor position (same trick as spawnPosed's snapToFloor in testbed.lua) --
        -- different poses can have slightly different root-to-ground offsets.
        if floorZ then
            pcall(function()
                local origin, extent = newActor:GetActorBounds(false)
                if origin and extent then
                    local bottom = origin.Z - extent.Z
                    local loc = newActor:K2_GetActorLocation()
                    local dz = floorZ - bottom
                    if math.abs(dz) <= 1000 then
                        newActor:K2_SetActorLocation({ X = loc.X, Y = loc.Y, Z = loc.Z + dz }, false, {}, true)
                    end
                end
            end)
        end
    else
        if Config.DECOR_COLLISION == false then
            pcall(function() newActor:SetActorEnableCollision(false) end)
        else
            pcall(function() Spawner.SetDecorSolid(newActor) end)
        end
        pcall(function() Spawner.MakeMovable(newActor) end)
    end

    print(string.format("[LivingBase] Cycle: now showing %s (%d/%d in %s).\n", nextName, nextIdx, #roster, label))
    pcall(function() Spawner.Toast(string.format("%s: %d/%d (%s)", label, nextIdx, #roster, nextName), 2.5) end)
end

-- Spawner.ReplaceNearestInFront(spawnFn, newLabelHint) -- generalizes CycleNearestInFront above to
-- ANY roster kind, not just statues/decor. Cycle can get away with spawning the replacement
-- directly via a raw Spawner.Spawn(path, label, {X,Y,Z}, ..., yaw) call because statue/decor
-- entries need nothing beyond a class + position. Crew/Senkamati/townsfolk/livestock entries need
-- their FULL recipe (composite look, AI overrides, faction, post-build de-corrupt fixes) which
-- only the existing Testbed.SpawnXByName functions know how to build -- and none of those accept a
-- caller-supplied position (they always spawn in front of the player). So instead of threading a
-- position parameter through every one of those functions, this spawns normally via the caller's
-- `spawnFn` (any zero-arg function matching the SpawnXByName true/false contract, e.g. one of
-- main.lua's SPAWN_MENU_HANDLERS entries) and then RELOCATES the fresh actor to the old target's
-- exact transform afterward -- the same "spawn now, correct the position after" idea Cycle already
-- uses for a statue's floor-relevel, just generalized to the full transform. Built 2026-08-16 for
-- LivingBaseSpawnMenu's tree "Replace" button (see that mod's SpawnMenu.cpp).
function Spawner.ReplaceNearestInFront(spawnFn, newLabelHint)
    print("[LivingBase] replace key received.\n")
    local maxDist = Config.LIVE_EDIT_MAX_DIST or 200.0
    local bestI, e = findNearestSpawnInFront(maxDist)
    if not bestI then
        print(string.format("[LivingBase] Replace: nothing within %.0fuu ahead — walk closer / face it.\n", maxDist))
        pcall(function() Spawner.Toast("Replace: nothing in front to replace.", 2.5) end)
        return false, "nothing in front"
    end

    local oldX, oldY, oldZ, oldYaw
    pcall(function()
        local l = e.actor:K2_GetActorLocation()
        local r = e.actor:K2_GetActorRotation()
        oldX, oldY, oldZ, oldYaw = l.X, l.Y, l.Z, r.Yaw
    end)
    if not oldX then
        print("[LivingBase] Replace: couldn't read the current actor's transform.\n")
        return false, "transform read failed"
    end

    -- Same undo shape as Cycle/despawn: capture the OLD actor's info BEFORE removing it, so Num0
    -- can bring it back if the replacement turns out wrong. replaceActor/replaceClass/replacePos
    -- get filled in below once the new actor exists (Num0 needs to destroy THAT first).
    local persisted = Spawner.PersistFindMatching(e.class, e.home)
    local undoItem = {
        class = e.class, label = e.label, pos = { X = oldX, Y = oldY, Z = oldZ }, yaw = oldYaw,
        aiPath = persisted and persisted.aiPath, makeFriendly = persisted and persisted.makeFriendly,
        look = persisted and persisted.look,
    }
    Spawner.PushUndo({ undoItem })

    local oldActor, oldClass = e.actor, e.class
    pcall(function() oldActor:K2_DestroyActor() end)
    table.remove(Spawner.spawned, bestI)
    Spawner.PersistRemoveMatching(oldClass, e.home)

    -- Carry a target lock forward, same as Cycle -- do this BEFORE spawning the replacement so a
    -- lock pointing at the just-destroyed actor doesn't release itself in the gap.
    local wasLocked = Spawner.lockedTarget and Spawner.lockedTarget.actor == oldActor

    local countBefore = #Spawner.spawned
    Spawner._suppressSpawnToast = true
    local spawnOk = pcall(spawnFn)
    Spawner._suppressSpawnToast = false
    if not (spawnOk and #Spawner.spawned > countBefore) then
        print("[LivingBase] Replace: replacement spawn failed -- the old one is gone; Num0 can restore it.\n")
        pcall(function() Spawner.Toast("Replace failed to spawn -- Num0 to restore.", 3.0) end)
        return false, "spawn failed"
    end

    local newEntry = Spawner.spawned[#Spawner.spawned]
    local newActor = newEntry.actor
    -- newEntry.home right now is the FRESH frontSpot(player) location Spawner.Spawn just recorded --
    -- correct persist.txt's record of it to the OLD position before overwriting our own copy of
    -- newEntry.home, or PersistUpdatePose's own class+position lookup won't find the row it just wrote.
    pcall(function()
        Spawner.PersistUpdatePose(newEntry.class, newEntry.home, { X = oldX, Y = oldY, Z = oldZ }, oldYaw)
    end)
    pcall(function()
        newActor:K2_SetActorLocation({ X = oldX, Y = oldY, Z = oldZ }, false, {}, true)
        newActor:K2_SetActorRotation({ Pitch = 0.0, Yaw = oldYaw, Roll = 0.0 }, false)
    end)
    newEntry.home = { X = oldX, Y = oldY, Z = oldZ }
    newEntry.yaw = oldYaw

    undoItem.replaceActor = newActor
    undoItem.replaceClass = newEntry.class
    undoItem.replacePos = { X = oldX, Y = oldY, Z = oldZ }

    if wasLocked then
        Spawner.lockedTarget = { actor = newActor, label = newEntry.label, class = newEntry.class }
    end

    local shownLabel = newLabelHint or newEntry.label
    print(string.format("[LivingBase] Replace: %s -> %s.\n", tostring(oldClass), tostring(newEntry.class)))
    pcall(function() Spawner.Toast("Replaced with: " .. tostring(shownLabel), 2.5) end)
    return true
end

return Spawner