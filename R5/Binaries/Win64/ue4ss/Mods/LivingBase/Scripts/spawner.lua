--[[
 LivingBase / spawner.lua
 Actor spawning via GameplayStatics deferred spawn. Tracks everything
 it spawns so cleanup is one call. Phase 2: used by the testbed only.
]]

local UEHelpers = require("UEHelpers")
local Config = require("config")

local Spawner = {}
local MOD_NAME = "[LivingBase:Spawner]"

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
function Spawner.LetFurniturePass(actor)
    if not (actor and actor:IsValid()) then return false end
    local cls = StaticFindObject("/Script/Engine.PrimitiveComponent")
    if not (cls and cls:IsValid()) then return false end
    local n = 0
    pcall(function()
        local comps = actor:K2_GetComponentsByClass(cls)
        pcall(function() n = comps:GetArrayNum() end)
        if n == 0 then pcall(function() n = #comps end) end
        for i = 1, n do
            local c = comps[i]; if not c then pcall(function() c = comps:Get(i) end) end
            if c and c:IsValid() then
                pcall(function() c:SetCollisionResponseToAllChannels(0) end)   -- Ignore all
                pcall(function() c:SetCollisionResponseToChannel(2, 2) end)    -- Block Pawn
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
function Spawner.Spawn(classPath, label, atLocation, preFinish, aiControllerClassPath, yaw, makeFriendly, compositeLook, presetInstanceLabel)
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
    table.insert(Spawner.spawned, { actor = actor, label = finalLabel, class = classPath,
        home = { X = loc.X, Y = loc.Y, Z = loc.Z }, yaw = yawUsed })
    ledgerAppend(actor)
    persistAppend(classPath, loc, aiControllerClassPath, yawUsed, makeFriendly, compositeLook, finalLabel)
    log(string.format("SPAWNED [%s] -> %s at (%.0f, %.0f, %.0f)",
        tostring(finalLabel), classPath, loc.X, loc.Y, loc.Z))
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
-- Spawner.ProbeNearestActor() / Spawner.ProbeDumpProperties() — dev-tool diagnostics (HOME / PAUSE),
-- not a real feature, not gated by modGate (same treatment the toast investigation's
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
-- set, HOME probes THAT actor directly instead of re-running the cone/range sweep — same reason
-- the lock already bypasses findNearestSpawnInFront's own pick: lets you back away, circle
-- around, or stand at an awkward angle to line up HOME/PAUSE on the same actor repeatedly without
-- re-aiming precisely each press. Only ever helps for something the lock could target in the
-- first place (an actor tracked in Spawner.spawned, e.g. one of our own placed statues) — a wild
-- world NPC/undiscovered decoration was never lockable, so probing one still falls through to the
-- normal full-world sweep exactly as before.
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
            if a and a:IsValid() and not isController and not exclude[actorInstancePath(a)] then
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
    print(string.format("[LivingBase] [probe] TARGET @ %.0fuu: %s\n", bestD, cls))
    if discoveryAppend("CLASS: " .. cls) then
        print("[LivingBase] [probe] logged to discovery_dump.txt\n")
    else
        print("[LivingBase] [probe] could not open discovery_dump.txt for writing.\n")
    end
    Spawner._lastProbedActor = best
    print("[LivingBase] [probe] press PAUSE to dump this target's properties.\n")
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
local function dumpMaterialParameters(actor)
    if not (actor and actor:IsValid()) then return end
    local mesh = nil
    pcall(function() mesh = actor.Mesh end)
    if not (mesh and mesh:IsValid()) then
        print("[LivingBase] [probe-mat] no actor.Mesh to read a material from.\n")
        return
    end
    local nMats = 0
    pcall(function() nMats = mesh:GetNumMaterials() end)
    if nMats == 0 then
        print("[LivingBase] [probe-mat] GetNumMaterials() returned 0.\n")
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
        print("[LivingBase] [probe-props] no valid probed target -- press HOME on something first.\n")
        return
    end
    pcall(function() dumpObjectProperties(target, "TARGET") end)
    pcall(function() dumpMeshComponentNames(target) end)
    pcall(function() dumpColorControllers(target) end)
    pcall(function() dumpMaterialParameters(target) end)
    pcall(function() dumpArchetypeInfo(target) end)
    pcall(function() dumpCustomizability(target) end)
    pcall(function() dumpAvailableBodyTypes(target) end)
    pcall(function() dumpAnimInfo(target) end)
    print("[LivingBase] [probe-props] done.\n")
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
                    table.insert(Spawner.spawned,
                        { actor = a, label = label, class = cls, home = home })
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
    -- split: class|x|y|z|ai|yaw|friendly|lookParams|lookArchetype|sex|bodyTypes|reskinTarget|instanceLabel|pitch|roll
    -- (reskinTarget is a 2026-08-11 addition/field 12, instanceLabel a 2026-08-16 one/field 13,
    -- pitch/roll a 2026-08-18 one/fields 14-15 -- any of these can be absent/nil on an older line,
    -- same graceful-degradation contract as parsePersistLine above.)
    local parts = {}
    for f in (line .. "|"):gmatch("([^|]*)|") do parts[#parts + 1] = f end
    local cls, x, y, z, ai, yw, fr = parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]
    local lp, la, ls, lb, lr, storedLabel = parts[8], parts[9], parts[10], parts[11], parts[12], parts[13]
    local pitch, roll = tonumber(parts[14]) or 0.0, tonumber(parts[15]) or 0.0
    if not (cls and x and y and z) then return end
    local loc = { X = tonumber(x), Y = tonumber(y), Z = tonumber(z) }
    local aiPath = (ai and ai ~= "") and ai or nil
    local yaw = tonumber(yw) or 0.0
    local friendly = (fr == "1")
    local look = nil
    if (lp and lp ~= "") or (la and la ~= "") or (lb and lb ~= "") or (lr and lr ~= "") then
        look = { params    = (lp and lp ~= "" and lp) or nil,
                 archetype = (la and la ~= "" and la) or nil,
                 sex       = (ls and ls ~= "" and tonumber(ls)) or nil,
                 bodyTypes = (lb and lb ~= "" and lb) or nil,
                 reskinTarget = (lr and lr ~= "" and lr) or nil }
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

    local ok, a = pcall(function()
        return Spawner.Spawn(cls, resolvedLabel, loc, nil, aiPath, yaw, friendly, look, resolvedLabel)
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

-- Spawner.ToggleTargetLock() — Num+ toggle (see Spawner.lockedTarget's own comment inside
-- findNearestSpawnInFront for what a lock DOES). This function only decides ON vs OFF and picks
-- what to lock onto; the actual "make every other action use it" behavior lives entirely in that one
-- shared picker, so nothing else needed to change to support this.
--------------------------------------------------------------------
-- ON: does the exact same cone/range pick despawn/edit/cycle already use (LIVE_EDIT_MAX_DIST, same
-- camera-based cone) — locking targets whatever those keys would already have hit, so there's no
-- separate/different "what counts as in front of me" rule to learn. OFF: just clears the pin; every
-- action goes back to picking fresh each press, same as before this feature existed.
function Spawner.ToggleTargetLock()
    print("[LivingBase] target-lock key received.\n")
    local maxDist = Config.LIVE_EDIT_MAX_DIST or 200.0
    if Spawner.lockedTarget then
        -- Already locked: RedFalcon asked (2026-08-16) for pressing + on a DIFFERENT object to just
        -- retarget in one press, instead of needing unlock-then-relock (two presses). ignoreLock=true
        -- bypasses findNearestSpawnInFront's own lock short-circuit, so this is a genuinely fresh
        -- cone/range pick, not just the same locked actor being handed back again.
        local bestI, e = findNearestSpawnInFront(maxDist, true)
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
    local bestI, e = findNearestSpawnInFront(maxDist)
    if not bestI then
        print(string.format("[LivingBase] Target lock: nothing within %.0fuu ahead — walk closer / face it.\n", maxDist))
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
    -- Also any StaticMeshComponents that aren't the root (the visible mesh is often a child, and a
    -- Static child ignores the parent's runtime move on the render thread too). Try both UE4SS method
    -- spellings for the class lookup.
    pcall(function()
        local smcClass = StaticFindObject("/Script/Engine.StaticMeshComponent")
        if not smcClass then return end
        local comps
        pcall(function() comps = actor:GetComponentsByClass(smcClass) end)
        if not comps then pcall(function() comps = actor:K2_GetComponentsByClass(smcClass) end) end
        if not comps then return end
        for i = 1, #comps do
            local c = comps[i]
            if c and c:IsValid() then pcall(function() c:SetMobility(2) end) end
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
    -- fx/fy here (the SLIDE frame for arrow-key movement) come from the PAWN'S OWN body rotation, not
    -- the camera — mixing camera-facing with pawn-position made MOVEMENT worse (camera can look a fair
    -- bit away from where the body actually is, offset/lag), so findNearestSpawnInFront always returns
    -- pawn-based fx/fy regardless of how it internally picked the target. (Movement direction for
    -- STATUES is separately overridden below to the statue's own facing anyway, so this only affects
    -- non-statue decorations.) The TARGET PICK itself (which object counts as "in front") is a separate
    -- concern handled inside findNearestSpawnInFront and now uses the camera's look direction (see its
    -- comment) — picking and moving are allowed to use different facings; they answer different
    -- questions ("what am I looking at" vs "which way should this slide").
    local bestI, e, bestD, px, py, pz, fx, fy = findNearestSpawnInFront(maxDist)
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
    -- is set to); DECORATIONS move in the player's frame. Statues are AnimatedActor/QuestStatic classes.
    local statueFrame = (e.class and (string.find(e.class, "AnimatedActor", 1, true)
        or string.find(e.class, "QuestStatic", 1, true))) and true or false
    local newX, newY, newZ, newYaw, newPitch, newRoll
    pcall(function()
        local l = e.actor:K2_GetActorLocation()
        local r = e.actor:K2_GetActorRotation()
        -- Horizontal nudge: forward = frame facing; right = (-fwdY, fwdX). Player frame by default,
        -- the statue's own facing when editing a statue.
        local afx, afy = fx, fy
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