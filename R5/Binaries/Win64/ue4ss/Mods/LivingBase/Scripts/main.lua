--[[
============================================================
 LivingBase — Base Building & Population Mod for Windrose
============================================================
 Spawning is GUI-only now (the LivingBaseSpawnMenu companion window's categorized tree + Spawn/
 Replace buttons) -- 2026-08-24 numpad-only keybind rebuild. Every in-game key that remains is on
 the numpad, and every one of them (except NUM_SUBTRACT itself, which opens the window) only works
 while that window is open:
   Numpad 7/8/9/4/6/5 move (Up/Forward/Down/Left/Right/Backward) by default, or rotate per-axis
   once Numpad 2 (Change Mode) switches to Rotate mode -- entering an active placement/relocate
   session auto-switches to Rotate, confirming/cancelling switches back to Move.
   Numpad 1 release cursor (steal OS focus for the window) · Numpad 3 despawn-in-front ·
   Numpad + target lock · Numpad / cancel placement · Numpad * grab target to relocate ·
   Numpad - open/close the window · Numpad 0 confirm placement · Numpad . floor-clipping toggle.
 Placed crowd + decorations persist across reloads.
 Config: config.txt (plain-text toggles) + Scripts/config.lua (defaults/keymap). If the optional
 R5ModSettings mod is installed, every key here is ALSO remappable from Settings > Mods in-game
 (LivingBase-ModMenuPatch overlay) — keybind changes need a game restart to take effect; see the
 "KEY REGISTRATION" section below for why.
============================================================
]]

local Testbed = require("testbed")
local Spawner = require("spawner")
local Config = require("config")
local ModSettingsOk, ModSettings = pcall(require, "modsettings")
if not ModSettingsOk then
    ModSettings = nil
    print("[LivingBase] modsettings.lua failed to load — live keybind rebinding disabled (keys still work off config.lua/config.txt).\n")
end

-- On world load, restore re-creates actors via Spawner.Spawn only; this hook re-applies
-- the post-spawn fixes (Senkamati de-corrupt/passive, goat perception-strip). Without it a
-- reloaded Caster returns corrupted + hostile.
Spawner.restoreHook = Testbed.RestoreHook

-- One entry per SPATIAL action MoveMenu.cpp (and, as of the numpad rebuild, the in-game numpad
-- move/rotate keys too) can send -- UNIT (dZ, dYaw, dFwd, dRight, dPitch, dRoll) deltas. Multiplied
-- by the real step sizes + precision scale at the point of use, never baked in here. HOISTED
-- (2026-08-24, numpad rebuild) from its original spot in the MOVE MENU BRIDGE section further down
-- to here, above the KEY REGISTRATION section -- Lua locals are only visible from their declaration
-- point onward (this file's own established rule), and the new numpad key handlers below need to
-- reference this table. Pure static data with no dependencies, so the move is mechanical.
-- ROTX/ROTY/ROTZ (2026-08-18): full 3-axis rotation. Z is yaw; X/Y are UE's Roll/Pitch respectively
-- (Unreal's own FRotator convention: X axis = Roll, Y axis = Pitch, Z axis = Yaw).
local MOVE_MENU_ACTIONS = {
    UP     = {1, 0, 0, 0, 0, 0},
    DOWN   = {-1, 0, 0, 0, 0, 0},
    FWD    = {0, 0, 1, 0, 0, 0},
    BACK   = {0, 0, -1, 0, 0, 0},
    LEFT   = {0, 0, 0, -1, 0, 0},
    RIGHT  = {0, 0, 0, 1, 0, 0},
    ROTZ_L = {0, -1, 0, 0, 0, 0},
    ROTZ_R = {0, 1, 0, 0, 0, 0},
    ROTX_L = {0, 0, 0, 0, 0, -1},
    ROTX_R = {0, 0, 0, 0, 0, 1},
    ROTY_L = {0, 0, 0, 0, -1, 0},
    ROTY_R = {0, 0, 0, 0, 1, 0},
}

------------------------------------------------------------
-- SPAWN MENU TOAST HISTORY: wraps Spawner.Toast once here at load so every toast message this
-- session (spawns, despawns, undo, restore progress, target-lock, etc.) gets appended to a small
-- log file the LivingBaseSpawnMenu window's History tab can read -- built 2026-08-16. Wrapping the
-- ONE function every toast already funnels through is far simpler than touching every call site
-- individually (there are dozens across this file/spawner.lua/testbed.lua). Truncated fresh here
-- at mod load, so "this session" means exactly that -- a stale history from a previous session (or
-- before an lbreload) never lingers.
------------------------------------------------------------
local SPAWN_MENU_HISTORY_PATH = "ue4ss/Mods/LivingBase/spawn_menu_history.txt"
do
    local f = io.open(SPAWN_MENU_HISTORY_PATH, "w")
    if f then f:close() end
end
do
    local originalToast = Spawner.Toast
    Spawner.Toast = function(msg, seconds)
        pcall(function()
            local hf = io.open(SPAWN_MENU_HISTORY_PATH, "a")
            if hf then
                hf:write(tostring(msg), "\n")
                hf:close()
            end
        end)
        return originalToast(msg, seconds)
    end
end

local MOD_NAME = "[LivingBase]"
local function log(msg)
    if Config.VERBOSE then print(string.format("%s %s\n", MOD_NAME, tostring(msg))) end
end
-- The restore chain must speak even with VERBOSE off. Its lines are few, and each one answers
-- "did it run, and how far did it get?" — gating them behind VERBOSE is what let the v2.03
-- total-restore failure hide in silence.
--
-- v2.19 replaced the call sites but never inserted this definition, so every always(...) raised
-- "attempt to call a nil value" and killed the restore chain at its first log line. lupa compiles
-- a nil global without complaint (it's a RUNTIME error), which is why the undefined-call lint now
-- runs alongside the compile check.
local function always(msg)
    print(string.format("%s %s\n", MOD_NAME, tostring(msg)))
end

pcall(function() math.randomseed(os.time()) end)  -- for leash landing variety

-- One-time load confirmation (always shown).
print("[LivingBase] loaded — Numpad-only controls; see the LivingBaseSpawnMenu window for spawning. Numpad - opens/closes the window; every other key needs it open.\n")

-- modEnabled/keyStatusText/Config.KEYS_ENABLED_ONSTART/toggleMod REMOVED (2026-08-24, numpad-only
-- keybind rebuild) -- see config.lua's own removal note. Key availability is purely "is the
-- LivingBaseSpawnMenu window open" now (windowGate/windowGatedAction below), no separate concept.

-- Bumped by the numpad '-' key (see Config.KEYS.toggleWindow) each time the LivingBaseSpawnMenu
-- window should open/close -- published in the SPAWN MENU STATUS block further down as
-- WINDOW_TOGGLE=<seq>. A monotonic counter rather than an explicit open/closed flag since C++ owns
-- the actual visibility state outright (this side has no way to query it back) -- see MenuStatus::
-- WindowToggleSeq()'s own comment on the C++ side for why "something changed" is all that needs to
-- cross the bridge.
local windowToggleSeq = 0

-- Bumped by the numpad '1' key (see Config.KEYS.releaseCursor) every press -- published as
-- FOCUS_STEAL=<seq>, same bridge shape as windowToggleSeq above. Tells the C++ window to
-- SetForegroundWindow() on itself.
local focusStealSeq = 0

-- Locked from the moment a world load is detected until Spawner.RestoreFromPersist actually finishes
-- (or determines there's nothing to restore) -- placing something manually in that window got written
-- to persist.txt immediately, and restore (which reads persist.txt fresh, several seconds later once
-- RESTORE_SETTLE_MS/player-movement conditions are met) then re-spawned that SAME entry again, since
-- it was already in the file by the time restore's own read happened -- a real duplicate, not a
-- cosmetic one (user-reported 2026-08-06). Deliberately its own separate flag rather than folded
-- into any other gate, so it can keep denying real game-state actions on its own terms regardless
-- of what else changes around it (see restoreGate's own comment just below).
local restoreLockActive = false
-- restoreGate: the world-load restore lock alone, no window-open check -- this is the ONE gate
-- NOTHING touching real game state is exempt from (RedFalcon, 2026-08-16: "ALL things should
-- still be unavailable until the base is loaded"). Used directly by the GUI window's own action
-- handlers (spawn menu bridge, move menu bridge below) and by target lock's keyboard
-- registration -- all of these are meant to keep working even with the LivingBaseSpawnMenu
-- window closed, but none of them are exempt from THIS.
local function restoreGate(name)
    if restoreLockActive then
        print("[LivingBase] '" .. tostring(name) .. "' ignored — still loading/restoring your base.\n")
        return false
    end
    return true
end
-- modGate REMOVED (2026-08-24, numpad-only keybind rebuild) -- see config.lua's own removal note
-- on the In-Game Keys concept it used to check.

-- WINDOW STATE (2026-08-20): the first C++ -> Lua leg of this bridge (see MenuStatus::
-- PublishWindowVisible's own comment on the C++ side) -- StandaloneWindow writes "1"/"0" here every
-- frame the real IsWindowVisible(hwnd) state changes. Same multi-candidate path convention as every
-- other cross-process file in this bridge -- see SPAWN_REQUEST_PATH_CANDIDATES's own comment
-- (further down) for why a bare relative path is wrong here. Declared up here (not down by the
-- hover-highlight loop that also uses it) so windowGate below -- and any KEY registered against it
-- -- can see it too; RegisterKeyBind calls all happen in one synchronous pass and can only
-- reference locals already declared by that point.
local WINDOW_STATE_PATH_CANDIDATES = {
    "ue4ss/Mods/LivingBase/spawn_menu_window_state.txt",
    "Mods/LivingBase/spawn_menu_window_state.txt",
    "spawn_menu_window_state.txt",
}
local function isSpawnMenuWindowOpen()
    for _, p in ipairs(WINDOW_STATE_PATH_CANDIDATES) do
        local f = io.open(p, "r")
        if f then
            local content = f:read("*all")
            f:close()
            return content and content:match("1") ~= nil
        end
    end
    return false -- file not written yet (C++ side not loaded, or hasn't polled once) -- assume closed
end
-- windowGate: restoreGate PLUS the SpawnMenu window's own open/closed state, mirroring modGate's
-- shape exactly but checking window visibility instead of the In-Game-Keys toggle. RedFalcon's
-- long-term direction (2026-08-20): "tie everything to that window... window visibility will
-- become a mod active/inactive type toggle" -- this is the first action migrated onto it
-- (targetLock, previously restoreGatedAction-only/"available as soon as the world is loaded").
-- Expect more actions to move onto this gate over time as that direction plays out; this isn't a
-- one-off special case for target-lock specifically.
local function windowGate(name)
    -- Silent when denied (2026-08-20, RedFalcon: "I'd rather it say nothing. It'll be a given.") --
    -- unlike modGate's own per-press "ignored" message, the window being closed is meant to become
    -- the ordinary/expected inactive state once more actions migrate onto this gate, not a surprise
    -- worth explaining every single time. The one moment worth telling the player about is the
    -- window ITSELF opening/closing -- see the toast in the hover-highlight loop below.
    if not restoreGate(name) then return false end
    return isSpawnMenuWindowOpen()
end
local function windowGatedAction(fn, name)
    return function()
        if not windowGate(name) then return end
        ExecuteInGameThread(function()
            local ok, err = pcall(fn)
            if not ok then log(name .. " FAILED: " .. tostring(err)) end
        end)
    end
end

------------------------------------------------------------
-- KEY REGISTRATION
-- Every key binds EXACTLY ONCE, synchronously, during this startup pass — off Config.KEYS, which
-- config.lua's ModSettings.ApplyOnce may already have overridden once from R5ModSettings' saved
-- values before main.lua even ran. A keybind changed in Settings > Mods AFTER this point is saved
-- and takes effect on the NEXT game restart, not live.
--
-- An earlier version of this file called RegisterKeyBind again LATER, during gameplay, from a
-- ~1.5s poll, whenever it noticed a keybind had changed in Settings > Mods — the goal being to
-- apply a remap live, no restart. In testing this reliably crashed the game itself
-- (EXCEPTION_ACCESS_VIOLATION inside Windrose-Win64-Shipping.exe, confirmed via the crash dump —
-- not a Lua error, not something pcall could have caught) within seconds of picking a new key in
-- the menu. The same remap worked fine (just didn't apply without a restart) before that change
-- existed. RegisterKeyBind in this UE4SS build is evidently NOT safe to call outside the initial
-- mod-load pass — every call in this file now happens only here, synchronously, at load. Do not
-- reintroduce a runtime/deferred RegisterKeyBind call without re-verifying this in-game first.
------------------------------------------------------------

-- Raw Windows virtual-key codes for keys this UE4SS build's Key[] table doesn't expose (arrows
-- returned nil -> RegisterKeyBind(nil) crashed the mod). RegisterKeyBind accepts the numeric code
-- directly.
--
-- UP/DOWN/LEFT/RIGHT/numpad-operators are CONFIRMED gaps in this build's Key[] table (found by
-- testing). Everything else added below (BACKSPACE onward) is a safety-net, not a confirmed gap --
-- we don't know whether Key[] already has an entry for most of these; resolveKeyValue only falls
-- back to VK_FALLBACK if Key[] returns nil, so providing it here is harmless either way. Covers the
-- full standard keyboard + mouse buttons so ANY key a player picks via Settings > Mods resolves to
-- SOME correct numeric code, matching modsettings.lua's LB_TO_UE/UE_TO_LB translation table (see
-- its own comment for why -- same LB names used on both sides deliberately). Mouse-button support
-- is unverified: RegisterKeyBind is a keyboard-input API in every confirmed use in this codebase,
-- so a mouse-button pick may simply never fire regardless of the code passed.
local VK_FALLBACK = {
  UP = 0x26, DOWN = 0x28, LEFT = 0x25, RIGHT = 0x27,
  NUM_DIVIDE = 0x6F, NUM_MULTIPLY = 0x6A, NUM_ZERO = 0x60, NUM_SUBTRACT = 0x6D, NUM_ADD = 0x6B,
  NUM_DECIMAL = 0x6E,
  BACKSPACE = 0x08, TAB = 0x09, ENTER = 0x0D, ESCAPE = 0x1B, SPACE = 0x20,
  CAPS_LOCK = 0x14, NUM_LOCK = 0x90, SCROLL_LOCK = 0x91, PRINT_SCREEN = 0x2C, PAUSE = 0x13,
  LEFT_SHIFT = 0xA0, RIGHT_SHIFT = 0xA1, LEFT_CONTROL = 0xA2, RIGHT_CONTROL = 0xA3,
  LEFT_ALT = 0xA4, RIGHT_ALT = 0xA5,
  OEM_SEMICOLON = 0xBA, OEM_EQUALS = 0xBB, OEM_MINUS = 0xBD, OEM_SLASH = 0xBF, OEM_TILDE = 0xC0,
  OEM_LEFT_BRACKET = 0xDB, OEM_RIGHT_BRACKET = 0xDD, OEM_QUOTE = 0xDE,
  MOUSE_LEFT = 0x01, MOUSE_RIGHT = 0x02, MOUSE_MIDDLE = 0x04, MOUSE_THUMB1 = 0x05, MOUSE_THUMB2 = 0x06,
  F9 = 0x78, F10 = 0x79, F11 = 0x7A, F12 = 0x7B,
}
-- Letters (A-Z) and top-row digits (DIGIT_0..DIGIT_9): Windows VK codes equal their ASCII values
-- for these ranges, so generated rather than hand-typed to avoid transcription errors. "A".."Z" is
-- ALSO the LivingBase-side name for a letter key (see modsettings.lua: no translation entry needed,
-- Epic's FKey name for a letter key already IS the bare capital letter).
for c = string.byte("A"), string.byte("Z") do VK_FALLBACK[string.char(c)] = c end
for d = 0, 9 do VK_FALLBACK["DIGIT_" .. d] = string.byte(tostring(d)) end
local function resolveKeyValue(lbName)
    if lbName == nil then return nil end
    local kv = Key[lbName]
    if kv == nil then kv = VK_FALLBACK[lbName] end
    return kv
end

-- Debounce: ignore a keypress if another fired within SPAWN_DEBOUNCE_MS. Two spawns in the
-- same instant crash natively (overlapping composite builds), so this prevents an accidental
-- rapid double-press from doing that. Shared across all "gated" actions.
local spawnBusy = false

local failedActions = {}

-- Registers actionFn under Config.KEYS[actionKey]'s key, once. See the "KEY REGISTRATION" comment
-- above for why this never runs again after startup.
local function register(actionKey, actionFn)
    local keyValue = resolveKeyValue(Config.KEYS[actionKey])
    if keyValue == nil then
        print(string.format("[LivingBase] '%s' -> key '%s' not recognized; skipping bind.\n", actionKey, tostring(Config.KEYS[actionKey])))
        failedActions[actionKey] = true
        return
    end
    local okReg = pcall(function() RegisterKeyBind(keyValue, actionFn) end)
    if not okReg then
        print(string.format("[LivingBase] '%s' bind failed to register — key skipped.\n", actionKey))
        failedActions[actionKey] = true
    end
end

-- gatedAction/directAction/restoreGatedAction REMOVED (2026-08-24, numpad-only keybind rebuild) --
-- every action left is windowGatedAction (or the two exceptions below).
local function alwaysAction(fn, name)
    -- Bypasses BOTH gates entirely (not even restoreGate) -- for the ONE key that has to work
    -- regardless of window/restore state: toggleWindow (numpad '-'). If the window isn't open yet,
    -- nothing else can be reached at all, so this can't wait on anything either.
    return function()
        ExecuteInGameThread(function()
            local ok, err = pcall(fn)
            if not ok then log(name .. " FAILED: " .. tostring(err)) end
        end)
    end
end
local function windowGatedDebouncedAction(fn, name)
    -- Like windowGatedAction, but also shares the spawn debounce -- for despawn (numpad 3): a
    -- despawn immediately followed by a respawn is exactly the "two composite builds in one frame"
    -- risk a raw spawn already guards against, so this shouldn't drop that protection.
    return function()
        if not windowGate(name) then return end
        if spawnBusy then
            print("[LivingBase] '" .. tostring(name) .. "' ignored — shared spawn-debounce still active (" .. (Config.SPAWN_DEBOUNCE_MS or 300) .. "ms).\n")
            return
        end
        spawnBusy = true
        ExecuteInGameThread(function()
            local ok, err = pcall(fn)
            if not ok then log(name .. " FAILED: " .. tostring(err)) end
        end)
        if ExecuteWithDelay then
            ExecuteWithDelay(Config.SPAWN_DEBOUNCE_MS or 300, function() spawnBusy = false end)
        else
            spawnBusy = false
        end
    end
end

-- numpadMoveOrRotate(moveName, rotateName, label) -- shared builder for the six dual-purpose
-- numpad direction keys (7/8/9/4/6/5). In Move mode (default), sends the MOVE_MENU_ACTIONS delta
-- through Spawner.EditNearestInFront -- same target-lock/nearest-in-front pick, same step-size/
-- precision-scale math, every OTHER key here already used. In Rotate mode (Spawner.placementMode
-- == "ROTATE", toggled by Numpad 2), sends the paired rotate delta instead. During an ACTIVE
-- placement/relocate follow (Spawner._placementActive), movement is a no-op -- the follow loop
-- already owns that actor's position every tick from camera aim, see spawner.lua's own comment --
-- and rotation goes straight to Spawner.RotatePlacementActor (the exact, unambiguous actor being
-- placed) instead of through the target-lock pick, which may not even resolve to the same actor.
local function numpadMoveOrRotate(moveName, rotateName, label)
    return windowGatedAction(function()
        local rs = Config.LIVE_EDIT_ROTATE_STEP or 15.0
        if Spawner._placementActive then
            if Spawner.placementMode == "ROTATE" then
                local d = MOVE_MENU_ACTIONS[rotateName]
                if d then Spawner.RotatePlacementActor(d[2] * rs, d[5] * rs, d[6] * rs) end
            end
            return
        end
        local d = MOVE_MENU_ACTIONS[(Spawner.placementMode == "ROTATE") and rotateName or moveName]
        if not d then return end
        local hs, ms = Config.LIVE_EDIT_HEIGHT_STEP or 10.0, Config.LIVE_EDIT_MOVE_STEP or 10.0
        local scale = Spawner.editPrecisionScale or 1.0
        local rotScale = scale / 0.25
        Spawner.EditNearestInFront(d[1] * hs * scale, d[2] * rs * rotScale, d[3] * ms * scale,
            d[4] * ms * scale, d[5] * rs * rotScale, d[6] * rs * rotScale)
    end, label)
end
register("numpadUp",    numpadMoveOrRotate("UP",    "ROTX_L", "numpadUp"))
register("numpadFwd",   numpadMoveOrRotate("FWD",   "ROTY_L", "numpadFwd"))
register("numpadDown",  numpadMoveOrRotate("DOWN",  "ROTX_R", "numpadDown"))
register("numpadLeft",  numpadMoveOrRotate("LEFT",  "ROTZ_L", "numpadLeft"))
register("numpadRight", numpadMoveOrRotate("RIGHT", "ROTZ_R", "numpadRight"))
register("numpadBack",  numpadMoveOrRotate("BACK",  "ROTY_R", "numpadBack"))
-- Default precision baseline (was set inside the now-removed editPrecisionToggle cycle) -- the
-- LivingBaseSpawnMenu window's own precision slider (handleMoveMenuPrecision) is the only way to
-- change this now; this is just its starting value.
Spawner.editPrecisionScale = 0.25

-- Numpad 2: toggle Move <-> Rotate mode. See Spawner.placementMode/TogglePlacementMode's own
-- comment (spawner.lua) -- also auto-forced by StartPlacementPreview/StartRelocatePreview/
-- ConfirmPlacement/CancelPlacement. Was Numpad 5 until RedFalcon's 2026-08-24 WASD-feel swap (see
-- config.lua's own comment on Config.KEYS.changeMode) -- moved off the key in the middle of the
-- movement cross onto a corner key, so it's no longer easy to mispress while moving.
register("changeMode", windowGatedAction(Spawner.TogglePlacementMode, "changeMode"))

-- Numpad 1: steal OS focus for the LivingBaseSpawnMenu window -- was OEM_EQUALS ('=') before the
-- numpad rebuild. Only bumps a counter; the actual SetForegroundWindow() happens on the C++ side
-- (StandaloneWindow.cpp) once it notices FOCUS_STEAL changed in spawn_menu_status.txt.
register("releaseCursor", windowGatedAction(function()
    focusStealSeq = focusStealSeq + 1
end, "releaseCursor"))

-- Numpad 3: despawn whatever's in front of you -- was NUM_NINE/"undo" before the numpad rebuild.
register("despawn", windowGatedDebouncedAction(Testbed.DespawnInFront, "despawn"))

-- Numpad +: target lock (2026-08-13) -- pins despawn/live-edit to ONE tracked actor instead of
-- re-picking "nearest in front" on every press. UNCHANGED by the numpad rebuild.
register("targetLock", windowGatedAction(function() Spawner.ToggleTargetLock() end, "targetLock"))

-- BUILD-GHOST-PREVIEW (2026-08-20): confirm/cancel a live-following placement started from the
-- LivingBaseSpawnMenu Spawn button. Moved off F5/F6/F7/F8 onto the numpad (2026-08-24).
register("confirmPlacement", windowGatedAction(Spawner.ConfirmPlacement, "confirm placement")) -- Numpad 0
register("cancelPlacement",  windowGatedAction(Spawner.CancelPlacement,  "cancel placement"))   -- Numpad /
-- Grab-and-relocate (2026-08-20): pick up whatever's currently target-locked and carry it like a
-- fresh placement.
register("grabTarget", windowGatedAction(function() Spawner.StartRelocatePreview() end, "grab target for relocation")) -- Numpad *
-- Free-build/floor-clipping toggle (2026-08-21) -- flips floor-lock off/on globally.
register("toggleFreeBuild", windowGatedAction(Spawner.ToggleFreeBuild, "toggle free build mode")) -- Numpad .

-- Numpad -: open/close the LivingBaseSpawnMenu window -- the ONE key that stays reachable even
-- while the window is closed (alwaysAction, bypasses every gate). Only bumps a counter; the actual
-- show/hide happens on the C++ side (StandaloneWindow.cpp) once it notices WINDOW_TOGGLE changed
-- in spawn_menu_status.txt.
register("toggleWindow", alwaysAction(function()
    windowToggleSeq = windowToggleSeq + 1
    print("[LivingBase] Spawn menu window: toggle requested (seq " .. windowToggleSeq .. ").\n")
end, "toggleWindow"))

-- Without a console, a silently-skipped bind just looks like "the key does nothing" with no clue
-- why. Say so on screen once at load, listing exactly which actions didn't take.
do
    local names = {}
    for k in pairs(failedActions) do names[#names + 1] = k end
    if #names > 0 then
        table.sort(names)
        pcall(function() Spawner.Toast("LivingBase keys FAILED to bind: " .. table.concat(names, ", "), 6.0) end)
    end
end

-- TOGGLE POLL ONLY — no keybind polling (see the "KEY REGISTRATION" comment above: a live keybind
-- poll used to live here too, and reliably crashed the game by calling RegisterKeyBind after
-- startup; keybind changes now require a restart, same as config.txt always did). This poll is
-- safe because it NEVER calls RegisterKeyBind — it only touches the M.TOGGLE_DEFS entries marked
-- `live = true` (RESTORE_ON_LOAD, DECOR_COLLISION, LEASH_ENABLED, WHISTLE_FOLLOW_DEBUG as of this
-- writing; see modsettings.lua for the full list and why the rest stay restart-only). Most of these
-- just need Config[key] updated in place, since the code that reads them (scheduleRestore's own
-- live check above, the leash loop's own live check above, Spawner's own per-spawn/per-tick Config
-- reads) already re-checks Config live rather than caching a startup snapshot. DECOR_COLLISION gets
-- one extra step: turning it ON also re-solidifies whatever's already placed
-- (Spawner.SolidifyDecor(), the same insurance sweep main.lua already runs once after restore) —
-- turning it OFF can't undo collision already applied to existing decor, called out in that
-- setting's own description.
if ModSettings and ModSettings.IsInstalled() and ExecuteWithDelay then
    local function pollToggles()
        local live = ModSettings.ReadLiveToggles()
        for toggleKey, newValue in pairs(live) do
            if newValue ~= Config[toggleKey] then
                local old = Config[toggleKey]
                Config[toggleKey] = newValue
                local msg = string.format("LivingBase: '%s' %s -> %s (live)", toggleKey, tostring(old), tostring(newValue))
                print("[LivingBase] " .. msg .. "\n")
                pcall(function() Spawner.Toast(msg, 3.0) end)
                if toggleKey == "DECOR_COLLISION" and newValue == true then
                    pcall(function() Spawner.SolidifyDecor() end)
                end
            end
        end
    end
    local function pollLoop()
        ExecuteWithDelay(1500, function()
            ExecuteInGameThread(function() pcall(pollToggles) end)
            pollLoop()
        end)
    end
    pollLoop()
    print("[LivingBase] R5ModSettings detected — a handful of toggles apply live (see Settings > Mods); keybind changes need a game restart to take effect.\n")
end

------------------------------------------------------------
-- SPAWN MENU BRIDGE: the LivingBaseSpawnMenu companion C++ mod (a separate compiled UE4SS mod,
-- its own standalone ImGui window) writes "SPAWN:ROSTER:INDEX\n" or "REPLACE:ROSTER:INDEX\n" to
-- spawn_request.txt. Clicking a tree leaf only SELECTS it (2026-08-16 rework -- clicking used to
-- spawn immediately); the window's own "Spawn"/"Replace" buttons send the verb once the user
-- actually acts on the selection. Poll for that file here and turn it into a REAL spawn through
-- the exact same by-name entry point the keyboard/console already use (Testbed.SpawnSenkaByKey,
-- etc., via SPAWN_MENU_HANDLERS below) -- never a separate spawn path that could drift from what
-- pressing the key does. SPAWN places a new one; REPLACE swaps whatever's currently targeted/
-- locked for the selected entry IN PLACE via Spawner.ReplaceNearestInFront (spawner.lua) -- a
-- generalization of Spawner.CycleNearestInFront to jump to an arbitrary tree pick across ANY
-- roster, not just step forward/backward through a statue/decor list, which is why the tree's
-- own `]`/`[`-equivalent buttons were dropped in favor of this. Same "add a candidate path, never
-- trust a bare relative filename" lesson spawnmenu_manifest.lua already learned the hard way (its
-- own header comment has the story); same "process and delete" shape a request-queue file always
-- needs, so a stale leftover from a previous session (or the mod not loaded that tick) can't get
-- replayed later.
------------------------------------------------------------
local SPAWN_REQUEST_PATH_CANDIDATES = {
    "ue4ss/Mods/LivingBase/spawn_request.txt",
    "Mods/LivingBase/spawn_request.txt",
    "spawn_request.txt",
}
local function findSpawnRequestPath()
    for _, p in ipairs(SPAWN_REQUEST_PATH_CANDIDATES) do
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end
    return nil
end

-- One entry per `roster =` value spawnmenu_manifest.lua can emit. Add a new entry here each
-- time that generator's roster_descriptors() grows to cover another roster (statues, decor,
-- etc.) -- see that file's own comment.
local SPAWN_MENU_HANDLERS = {
    SENKAMATI_LOOKS = function(index)
        local row = Config.SENKAMATI_LOOKS and Config.SENKAMATI_LOOKS[index]
        if not row then return false, "index " .. tostring(index) .. " out of range" end
        return Testbed.SpawnSenkaByKey(Testbed.SenkaShortKey(row))
    end,
    TOWNSFOLK_CLASSES = function(index)
        local row = Config.TOWNSFOLK_CLASSES and Config.TOWNSFOLK_CLASSES[index]
        if not row then return false, "index " .. tostring(index) .. " out of range" end
        return Testbed.SpawnWalkerByName(row.name)
    end,
    FACTION_VISITOR_LOOKS = function(index)
        local row = Config.FACTION_VISITOR_LOOKS and Config.FACTION_VISITOR_LOOKS[index]
        if not row then return false, "index " .. tostring(index) .. " out of range" end
        return Testbed.SpawnCrewByName(row.name)
    end,
    -- Walking women: Config.FEMALE_RESKIN_TARGETS is a flat list of plain name strings (not rows
    -- with their own sub-fields), so the index points directly at the name to look up.
    FEMALE_RESKIN_TARGETS = function(index)
        local name = Config.FEMALE_RESKIN_TARGETS and Config.FEMALE_RESKIN_TARGETS[index]
        if not name then return false, "index " .. tostring(index) .. " out of range" end
        return Testbed.SpawnFemaleWalkerByName(name)
    end,
    -- Custom > Poses (2026-08-27) -- NOT a spawn. Applies Config.CUSTOM_POSES[index]'s animation to
    -- whatever's currently targeted/nearest-in-front, via the exact same Spawner.TestApplyPoseByPath
    -- the `lbtestpose <path>` console command already uses (every row's own `path` field IS that
    -- command's argument half, recorded verbatim from Other\Poses.xlsx). Deliberately returns
    -- `false` on every path, success included -- this roster never produces a new actor, so there's
    -- nothing for the SPAWN-verb's own build-ghost-preview check (a few lines below, in
    -- pollSpawnMenuRequest) to follow; returning `false` (falsy) short-circuits that check safely,
    -- same as every other handler's own failure path already does, rather than returning `true` and
    -- risking `result.IsValid` indexing a bare boolean. No tracking/persist.txt entry either --
    -- consistent with RedFalcon's own framing of this as not needing persistence yet, since the
    -- pose only ever modifies an actor that already exists.
    CUSTOM_POSES = function(index)
        local row = Config.CUSTOM_POSES and Config.CUSTOM_POSES[index]
        if not row then return false, "index " .. tostring(index) .. " out of range" end
        local ok, err = pcall(function() Spawner.TestApplyPoseByPath(row.path) end)
        if not ok then return false, tostring(err) end
        return false
    end,
    -- Custom > Skin Tones (2026-08-28) -- same non-spawn shape as CUSTOM_POSES above:
    -- Config.CUSTOM_SKIN_TONES is a flat name list (matching FEMALE_RESKIN_TARGETS' own plain-
    -- string-list shape, not rows with sub-fields), applied via Spawner.TestApplySkinFamily to
    -- whatever's targeted. Always returns `false` -- no actor is created, so the build-ghost-
    -- preview check must never fire for this roster either.
    SKIN_TONES = function(index)
        local name = Config.CUSTOM_SKIN_TONES and Config.CUSTOM_SKIN_TONES[index]
        if not name then return false, "index " .. tostring(index) .. " out of range" end
        local ok, err = pcall(function() Spawner.TestApplySkinFamily(name) end)
        if not ok then return false, tostring(err) end
        return false
    end,
    -- Custom > Hair (2026-08-28) -- same non-spawn shape as SKIN_TONES above. Config.CUSTOM_HAIR
    -- rows carry their own `name`, so the index maps straight to Spawner.TestApplyHairStyle(name)
    -- -- style-name matching (and sex auto-detection) happens inside that function, same as it
    -- does inside TestApplySkinFamily for family names.
    HAIR = function(index)
        local row = Config.CUSTOM_HAIR and Config.CUSTOM_HAIR[index]
        if not row then return false, "index " .. tostring(index) .. " out of range" end
        local ok, err = pcall(function() Spawner.TestApplyHairStyle(row.name, row.variant) end)
        if not ok then return false, tostring(err) end
        return false
    end,
    -- Custom > Clothes (2026-08-28) -- same non-spawn shape as HAIR/SKIN_TONES above.
    -- Config.CUSTOM_CLOTHES rows carry family/slot/name -- Spawner.TestApplyClothingPiece needs
    -- all three to disambiguate (the same bare `name`, e.g. "Default"/"Set 1", is reused across
    -- many different family/slot combinations).
    CLOTHES = function(index)
        local row = Config.CUSTOM_CLOTHES and Config.CUSTOM_CLOTHES[index]
        if not row then return false, "index " .. tostring(index) .. " out of range" end
        local ok, err = pcall(function() Spawner.TestApplyClothingPiece(row.family, row.slot, row.name) end)
        if not ok then return false, tostring(err) end
        return false
    end,
    -- Custom > Clothes > Remove (2026-08-28) -- Config.CLOTHES_REMOVE rows carry just `slot`
    -- ("Torso", "Legs", ..., or "All"); Spawner.TestRemoveClothingPiece hides rather than swaps.
    CLOTHES_REMOVE = function(index)
        local row = Config.CLOTHES_REMOVE and Config.CLOTHES_REMOVE[index]
        if not row then return false, "index " .. tostring(index) .. " out of range" end
        local ok, err = pcall(function() Spawner.TestRemoveClothingPiece(row.slot) end)
        if not ok then return false, tostring(err) end
        return false
    end,
    -- Custom > Face (2026-08-28) -- same non-spawn shape as CLOTHES above.
    FACIAL = function(index)
        local row = Config.CUSTOM_FACIAL and Config.CUSTOM_FACIAL[index]
        if not row then return false, "index " .. tostring(index) .. " out of range" end
        local ok, err = pcall(function() Spawner.TestApplyFacialPiece(row.family, row.slot, row.name) end)
        if not ok then return false, tostring(err) end
        return false
    end,
}

-- Rosters whose handler modifies an EXISTING target rather than spawning a new one -- see the
-- REPLACE-safety guard in pollSpawnMenuRequest below for why this list exists.
local NON_SPAWNING_ROSTERS = { CUSTOM_POSES = true, SKIN_TONES = true, HAIR = true, CLOTHES = true, CLOTHES_REMOVE = true, FACIAL = true }

-- Statue rosters (STANDING/SEATED/CHAIR/INTERACTIVE): each row is {faction, path}, and the
-- by-name entry points (Testbed.SpawnStandingByName/etc.) match on the SHORT CLASS NAME parsed
-- out of `path` -- the exact same pattern this file's own "lblook" section already computes
-- independently as `statueShortName` (see below), duplicated here in miniature rather than
-- depending on that later definition's position in the file (Lua locals are only visible from
-- their declaration point onward).
local function spawnMenuStatueShortName(path)
    return tostring(path):match("([%w_]+)%.[%w_]+$") or tostring(path)
end
local SPAWN_MENU_STATUE_ROSTERS = {
    STANDING_STATUES    = { list = Config.STANDING_STATUES,    fn = Testbed.SpawnStandingByName },
    SEATED_STATUES      = { list = Config.SEATED_STATUES,      fn = Testbed.SpawnSeatedByName },
    CHAIR_STATUES        = { list = Config.CHAIR_STATUES,       fn = Testbed.SpawnChairByName },
    INTERACTIVE_STATUES = { list = Config.INTERACTIVE_STATUES, fn = Testbed.SpawnInteractiveByName },
}
for roster, def in pairs(SPAWN_MENU_STATUE_ROSTERS) do
    SPAWN_MENU_HANDLERS[roster] = function(index)
        local row = def.list and def.list[index]
        if not row then return false, "index " .. tostring(index) .. " out of range" end
        return def.fn(spawnMenuStatueShortName(row.path))
    end
end

-- DECOR / LIVESTOCK: spawnmenu_manifest.lua flattens these (decor: DECOR_ORDER then each
-- category's own item order; livestock: BOARS/GOATS/DODOS/WOLVES/CROCODILES concatenated in that
-- order) into one array, since both are spread across several separate Config tables rather than
-- living in one flat roster like everything else here. Rebuild the IDENTICAL flattening here so
-- an index written into spawn_menu.ini means the same entry on both sides -- keep these two
-- functions in sync with that file's own decorRows/livestockRows if either ordering ever changes.
local function flattenSpawnMenuDecor()
    local rows = {}
    for _, catKey in ipairs(Config.DECOR_ORDER or {}) do
        for _, d in ipairs((Config.DECOR_CATEGORIES or {})[catKey] or {}) do
            rows[#rows + 1] = d
        end
    end
    return rows
end
local SPAWN_MENU_DECOR_ROWS = flattenSpawnMenuDecor()
SPAWN_MENU_HANDLERS.DECOR = function(index)
    local row = SPAWN_MENU_DECOR_ROWS[index]
    if not row then return false, "index " .. tostring(index) .. " out of range" end
    return Testbed.SpawnDecorByName(row.name)
end

local function flattenSpawnMenuLivestock()
    local rows = {}
    for _, t in ipairs({ Config.BOARS, Config.GOATS, Config.DODOS, Config.WOLVES, Config.CROCODILES }) do
        for _, e in ipairs(t or {}) do rows[#rows + 1] = e end
    end
    return rows
end
local SPAWN_MENU_LIVESTOCK_ROWS = flattenSpawnMenuLivestock()
SPAWN_MENU_HANDLERS.LIVESTOCK = function(index)
    local row = SPAWN_MENU_LIVESTOCK_ROWS[index]
    if not row then return false, "index " .. tostring(index) .. " out of range" end
    return Testbed.SpawnLivestockByName(row.name)
end

------------------------------------------------------------
-- FRIENDLY SPAWN LABELS (2026-08-19, RedFalcon's request): spawn_menu.ini's hand-curated
-- `label = ...` per roster/index entry -- the tree reorganization from v2.1.5 -- becomes the
-- ACTUAL toast/target-name/persist.txt label for that entry everywhere it's placed (keyboard
-- cycling, lblook/lbspawn, the GUI tree itself), not just something the ImGui window displays
-- while Lua goes on using its own mechanical "STANDING_People of Tortuga 1"-style label. Built
-- ONCE here from spawnmenu_manifest.lua's M.ReadLabels() (spawn_menu.ini only changes via a hand-
-- edit + restart, same one-time-INI-read pattern modsettings.lua's own EnsureSavedDefaults uses),
-- reusing every roster/index/row resolution this section already built above rather than
-- duplicating it a third time. Keyed by each roster's own IDENTITY string -- the exact same one
-- its by-name lookup already uses (short class name for statues via spawnMenuStatueShortName,
-- `.name` for crew/townsfolk/decor/livestock, Testbed.SenkaShortKey for Senkamati, the plain
-- string itself for walking women) -- so testbed.lua's placement functions can look themselves up
-- with zero roster/index plumbing threaded through at call time. Stored on Spawner (not a local
-- here) since testbed.lua already requires that module and is where every placement function
-- actually lives.
------------------------------------------------------------
Spawner.FriendlyLabels = {}
do
    local ok, SpawnMenuManifest = pcall(require, "spawnmenu_manifest")
    local byRoster = ok and SpawnMenuManifest.ReadLabels() or {}

    for index, label in pairs(byRoster.FACTION_VISITOR_LOOKS or {}) do
        local row = Config.FACTION_VISITOR_LOOKS and Config.FACTION_VISITOR_LOOKS[index]
        if row then Spawner.FriendlyLabels[row.name] = label end
    end
    for index, label in pairs(byRoster.TOWNSFOLK_CLASSES or {}) do
        local row = Config.TOWNSFOLK_CLASSES and Config.TOWNSFOLK_CLASSES[index]
        if row then Spawner.FriendlyLabels[row.name] = label end
    end
    for index, label in pairs(byRoster.SENKAMATI_LOOKS or {}) do
        local row = Config.SENKAMATI_LOOKS and Config.SENKAMATI_LOOKS[index]
        if row then Spawner.FriendlyLabels[Testbed.SenkaShortKey(row)] = label end
    end
    for index, label in pairs(byRoster.FEMALE_RESKIN_TARGETS or {}) do
        local name = Config.FEMALE_RESKIN_TARGETS and Config.FEMALE_RESKIN_TARGETS[index]
        if name then Spawner.FriendlyLabels[name] = label end
    end
    for index, label in pairs(byRoster.DECOR or {}) do
        local row = SPAWN_MENU_DECOR_ROWS[index]
        if row then Spawner.FriendlyLabels[row.name] = label end
    end
    for index, label in pairs(byRoster.LIVESTOCK or {}) do
        local row = SPAWN_MENU_LIVESTOCK_ROWS[index]
        if row then Spawner.FriendlyLabels[row.name] = label end
    end
    for roster, def in pairs(SPAWN_MENU_STATUE_ROSTERS) do
        for index, label in pairs(byRoster[roster] or {}) do
            local row = def.list and def.list[index]
            if row then Spawner.FriendlyLabels[spawnMenuStatueShortName(row.path)] = label end
        end
    end
end

local function pollSpawnMenuRequest()
    local path = findSpawnRequestPath()
    if not path then return end
    local f = io.open(path, "r")
    if not f then return end
    local content = f:read("*all")
    f:close()
    os.remove(path)

    local verb, roster, indexStr = content:match("(%u+)%s*:%s*(%u[%u_]*)%s*:%s*(%d+)")
    local index = indexStr and tonumber(indexStr)
    if not verb or not roster or not index then
        print("[LivingBase] spawn menu: malformed spawn_request.txt (" .. tostring(content) .. ")\n")
        return
    end
    if verb ~= "SPAWN" and verb ~= "REPLACE" then
        print("[LivingBase] spawn menu: unknown verb '" .. verb .. "' (expected SPAWN or REPLACE).\n")
        return
    end
    local handler = SPAWN_MENU_HANDLERS[roster]
    if not handler then
        print("[LivingBase] spawn menu: no handler for roster '" .. roster .. "' yet.\n")
        return
    end
    -- restoreGate only, NOT modGate (2026-08-16 split) -- GUI window actions stay reachable with
    -- In-Game Keys off (see restoreGate's own comment), still blocked during world-load restore.
    if not restoreGate("spawn menu: " .. verb .. " " .. roster) then return end
    if spawnBusy then
        print("[LivingBase] spawn menu: '" .. roster .. "' ignored — shared spawn-debounce still active.\n")
        return
    end
    spawnBusy = true
    ExecuteInGameThread(function()
        local ok, result = pcall(function()
            -- NON_SPAWNING_ROSTERS' handlers never spawn a new actor -- Spawner.ReplaceNearestInFront
            -- (spawner.lua) unconditionally DESTROYS the current target BEFORE calling the spawn
            -- callback, then checks Spawner.spawned actually grew afterward; since these rosters'
            -- own handlers never add an entry, REPLACE would delete whatever's targeted and then
            -- report "replacement spawn failed" -- undoable via Num0, but a genuinely bad surprise
            -- for a button that's supposed to just apply a pose/skin tone in place. Treat REPLACE
            -- identically to SPAWN for these (both buttons do the same safe thing) rather than
            -- routing them through a destroy-then-recreate flow only ever designed for rosters that
            -- actually spawn.
            if verb == "REPLACE" and not NON_SPAWNING_ROSTERS[roster] then
                return Spawner.ReplaceNearestInFront(function() return handler(index) end)
            end
            return handler(index)
        end)
        if not ok then
            log("spawn menu " .. verb .. " " .. roster .. " FAILED: " .. tostring(result))
        elseif verb == "SPAWN" and result and result.IsValid and result:IsValid()
               and (roster == "DECOR" or roster == "TOWNSFOLK_CLASSES" or roster == "FACTION_VISITOR_LOOKS"
                    or roster == "LIVESTOCK" or roster == "FEMALE_RESKIN_TARGETS" or roster == "SENKAMATI_LOOKS"
                    or SPAWN_MENU_STATUE_ROSTERS[roster]) then
            -- BUILD-GHOST-PREVIEW (2026-08-20, extended 2026-08-21 to statues, 2026-08-24 to
            -- townsfolk/crew/livestock/female-walkers/Senkamati). Briefly pulled the four humanoid
            -- rosters back out same day chasing a leg-bend/lift IK glitch, suspecting this
            -- live-preview path itself -- WRONG LEAD: confirmed live the glitch reproduced on FRESH
            -- spawns that had never been through this path at all, on EVERY roster including
            -- livestock (which stayed enabled the whole time) and even wild/vanilla NPCs standing
            -- near a mod spawn. Real root cause: Spawner.EnsureRaytraceChannel (2026-08-22) forcing
            -- every mod spawn to Block the Visibility collision channel so THIS panel's own
            -- targeting raycast could hit them -- which also made every mod spawn register as solid
            -- "ground" to any OTHER pawn's own foot-IK trace. Fixed at the source (see
            -- EnsureRaytraceChannel's own "TEMPORARILY DISABLED" comment and UpdateHoverHighlight's
            -- own comment on switching to LineTraceSingleForObjects) -- targeting now hits pawns via
            -- their native Pawn-channel collision instead, so EnsureRaytraceChannel's Visibility-
            -- block is unnecessary and stays permanently disabled. All five rosters restored here
            -- once that fix was confirmed live -- nothing about spawn-time live-placement itself was
            -- ever the problem.
            pcall(function() Spawner.StartPlacementPreview(result) end)
        end
    end)
    if ExecuteWithDelay then
        ExecuteWithDelay(Config.SPAWN_DEBOUNCE_MS or 300, function() spawnBusy = false end)
    else
        spawnBusy = false
    end
end

if ExecuteWithDelay then
    local function spawnMenuPollLoop()
        ExecuteWithDelay(400, function()
            pollSpawnMenuRequest()
            spawnMenuPollLoop()
        end)
    end
    spawnMenuPollLoop()
    print("[LivingBase] Spawn menu bridge armed — watching for spawn_request.txt from LivingBaseSpawnMenu.\n")
end

------------------------------------------------------------
-- HOVER HIGHLIGHT (2026-08-20, RedFalcon's request): ghost-highlight whatever's under the reticle
-- while the LivingBaseSpawnMenu window is open and nothing is target-locked/being placed, so it's
-- clear what Num+/F7 would grab before committing. Deliberately gated on the WINDOW being open, not
-- the unrelated In-Game-Keys toggle (modEnabled) -- RedFalcon's own point: only pay for the raycast
-- when the feature driving it is actually up. isSpawnMenuWindowOpen() reads the file
-- MenuStatus::PublishWindowVisible writes on the C++ side (the first C++ -> Lua leg of this bridge
-- -- see that function's own comment) -- needs the LivingBaseSpawnMenu.dll rebuild from the same
-- session this comment was added in; a Lua-only reload does NOT pick up a stale DLL that predates
-- this. Spawner.UpdateHoverHighlight does the actual per-tick raycast/material work. 150ms, not the
-- 33ms the active placement-follow loop uses -- a hover highlight doesn't need frame-perfect
-- tracking the way carrying an object does, and this one runs continuously whenever the window's
-- open (not just during a brief placement window), so a gentler cadence is the more conservative
-- choice for an always-on loop.
-- nil (not false) on purpose -- the FIRST poll after mod load shouldn't toast (that's just
-- discovering the window's already-existing state, not a transition RedFalcon's Insert/'-' caused).
local lastWindowOpenState = nil
if ExecuteWithDelay then
    local function hoverHighlightLoop()
        ExecuteWithDelay(150, function()
            local hasLock = Spawner.lockedTarget and Spawner.lockedTarget.actor and Spawner.lockedTarget.actor:IsValid()
            local windowOpen = isSpawnMenuWindowOpen()
            -- "Living Base Controls Active/Inactive" toast on the window's own open/close transition
            -- (2026-08-20, RedFalcon: since windowGate now denies silently, the window toggling
            -- itself is the one moment worth telling the player about, not every gated action after).
            -- Camera raise/restore now rides the SAME transition (2026-08-21, RedFalcon: "when
            -- building the camera changes and stays elevated as long as you are in building mode...
            -- let's link the change to opening and closing the menu, similar to the highlights") --
            -- see Spawner.ApplyPlacementCameraOffset's own comment. Deliberately only fires on a REAL
            -- detected transition (lastWindowOpenState ~= nil), not on the first poll after a
            -- load/lbreload, even if the window happens to already be open then -- this module's own
            -- Spawner._placementCamOrigArmZ baseline is fresh/nil at that point, so applying blind
            -- would ADD the raise on top of whatever the live camera already is (possibly already
            -- raised from before the reload), doubling it. The narrower cost of NOT applying here --
            -- if the window was already open across an lbreload, the raise could go unrestored on the
            -- next close until a full restart -- is a smaller, quieter bug than a visibly doubled
            -- camera height, so that's the tradeoff being made on purpose.
            if lastWindowOpenState ~= nil and windowOpen ~= lastWindowOpenState then
                pcall(function() Spawner.Toast(windowOpen and "Living Base Controls Active" or "Living Base Controls Inactive", 2.5) end)
                if windowOpen then
                    pcall(Spawner.ApplyPlacementCameraOffset)
                else
                    pcall(Spawner.RestorePlacementCameraOffset)
                    -- Release the target lock on window close too (2026-08-31, RedFalcon's request)
                    -- -- with the GUI gone there's no "Selected Target" display left showing what's
                    -- locked, and every Custom-category lever (Poses/Skin Tones/Hair/Clothes) only
                    -- works through this window, so a stale lock surviving a close just risks the
                    -- NEXT keyboard-only despawn/cycle/live-edit press silently acting on something
                    -- the player can no longer see was targeted. Spawner.ReleaseTargetLock is a
                    -- no-op if nothing's currently locked.
                    pcall(function() Spawner.ReleaseTargetLock("window closed") end)
                    -- Cancel an in-progress (unfinalized) placement on window close (2026-08-23,
                    -- RedFalcon's request) -- F5/F6 both go through windowGatedAction, so once the
                    -- window is closed the player has no way left to confirm OR cancel a placement
                    -- that's still following the camera; it would otherwise sit stuck forever.
                    -- Spawner.CancelPlacement (F6's own handler, called directly here rather than via
                    -- the gated wrapper since the window being closed is exactly the point) already
                    -- does the right thing for both modes -- despawns a fresh NEW-mode spawn with no
                    -- trace, or teleports a RELOCATE-mode grab back to its original transform -- see
                    -- its own comment in spawner.lua.
                    if Spawner._placementActive then
                        pcall(Spawner.CancelPlacement)
                    end
                end
            end
            lastWindowOpenState = windowOpen
            -- REMOVED the per-tick MaintainPlacementFov call (2026-08-22) -- was added when the FOV
            -- write appeared to have zero effect at all (wrong property target: PlayerCameraManager
            -- instead of the pawn's CameraComponent, since fixed). Once the CORRECT property was
            -- found, re-applying it every 150ms tick instead FOUGHT the game's own continuous
            -- FOV/zoom adjustment -- RedFalcon: "the FOV is constantly changing now" -- visible as a
            -- pulse against whatever dynamic system the game runs every frame. The one-time apply on
            -- the open/close transition below is enough now, same as the height raise (also a
            -- one-time set that sticks fine, never needed per-tick maintenance).
            local eligible = windowOpen and not restoreLockActive and not hasLock and not Spawner._placementActive
            if eligible then
                pcall(Spawner.UpdateHoverHighlight)
            elseif Spawner._hoverActor then
                pcall(Spawner.ClearHoverHighlight)
            end
            hoverHighlightLoop()
        end)
    end
    hoverHighlightLoop()
    print("[LivingBase] Hover highlight armed — ghosts whatever's under the reticle when nothing's targeted.\n")
end

------------------------------------------------------------
-- MOVE MENU BRIDGE: LivingBaseSpawnMenu's held-repeat buttons (MoveMenu.cpp, a side panel next
-- to the spawn tree) APPEND one "MOVE:<ACTION>\n" line to move_request.txt per repeat-tick while
-- a button is held -- appended, not overwritten, so ticks that land between two of our reads
-- never get lost to a last-write-wins overwrite. Uses the SAME step sizes and precision scale the
-- keyboard live-edit keys already use (Config.LIVE_EDIT_*_STEP / Spawner.editPrecisionScale) so
-- the window's buttons and the numpad keys stay in perfect sync -- this file is the only place
-- either one's step size is defined.
--
-- DRAIN vs FLUSH are deliberately two separate loops at two separate rates, not one:
-- Spawner.EditNearestInFront (spawner.lua) does TWO full persist.txt reads (PersistFindMatching,
-- then PersistUpdatePose's own internal read) plus one full persist.txt REWRITE, every single
-- call. That's fine at the rate a real held key produces -- this codebase's own comments elsewhere
-- note many keydown events are silently dropped by this UE4SS build, so the EFFECTIVE call rate
-- from a held keyboard key has always been much lower than its nominal repeat rate. A window
-- button has no such drop rate: draining+applying on every 100ms poll delivered a full,
-- undropped ~10 calls/sec for as long as the button was held -- confirmed live (2026-08-16):
-- holding one for an extended period crashed/hung the game with nothing trapped in the log,
-- consistent with persist.txt thrashing under sustained synchronous file I/O on the game thread,
-- a load this path had never actually been tested against before. Fix: drain the queue file
-- often (cheap, just file read + delete) but only ever CALL EditNearestInFront on the much slower
-- flush timer below, applying one ACCUMULATED delta instead of one call per tick.
------------------------------------------------------------
local MOVE_REQUEST_PATH_CANDIDATES = {
    "ue4ss/Mods/LivingBase/move_request.txt",
    "Mods/LivingBase/move_request.txt",
    "move_request.txt",
}
local function findMoveRequestPath()
    for _, p in ipairs(MOVE_REQUEST_PATH_CANDIDATES) do
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end
    return nil
end

-- ACTION:<NAME> one-shot commands (distinct from MOVE:<ACTION> spatial nudges above) -- these
-- come from single clicks (toggle/clear/lock buttons, or the in-window +/NUM_ADD keyboard
-- shortcut), never held-repeat, so they're handled IMMEDIATELY at drain time rather than queued
-- into the flush accumulator -- no reason to wait out the flush timer for a one-shot click, and
-- nothing here calls the expensive EditNearestInFront path the flush throttle exists to protect.
-- ACTION:MODE_TOGGLE/CANCEL_PLACEMENT/GRAB_TARGET/CONFIRM_PLACEMENT/TOGGLE_FREEBUILD (2026-08-24,
-- numpad rebuild) -- mirror the in-game numpad keys exactly, calling the SAME Spawner functions,
-- so the keyboard and the GUI window can never disagree. restoreGate only, NOT windowGate -- these
-- can only be reached from WITHIN the window anyway (its own keyboard focus), so there's no
-- "window closed" case to gate against here the way the in-game keys need to.
local function handleMoveMenuModeToggle()
    if not restoreGate("move menu: mode toggle") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(Spawner.TogglePlacementMode)
        if not ok then log("move menu mode-toggle FAILED: " .. tostring(err)) end
    end)
end
local function handleMoveMenuCancelPlacement()
    if not restoreGate("move menu: cancel placement") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(Spawner.CancelPlacement)
        if not ok then log("move menu cancel-placement FAILED: " .. tostring(err)) end
    end)
end
local function handleMoveMenuGrabTarget()
    if not restoreGate("move menu: grab target") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(function() Spawner.StartRelocatePreview() end)
        if not ok then log("move menu grab-target FAILED: " .. tostring(err)) end
    end)
end
local function handleMoveMenuConfirmPlacement()
    if not restoreGate("move menu: confirm placement") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(Spawner.ConfirmPlacement)
        if not ok then log("move menu confirm-placement FAILED: " .. tostring(err)) end
    end)
end
local function handleMoveMenuToggleFreeBuild()
    if not restoreGate("move menu: toggle free build") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(Spawner.ToggleFreeBuild)
        if not ok then log("move menu toggle-free-build FAILED: " .. tostring(err)) end
    end)
end
local function handleMoveMenuClearAll()
    -- The window's own confirmation popup (SpawnMenu.cpp side) is what gates sending this at all --
    -- unlike the keyboard DEL key, this file doesn't re-implement its own arm/confirm dance, the
    -- window already did that before this line ever got written. restoreGate only, NOT modGate
    -- (2026-08-16 split) -- see restoreGate's own comment.
    if not restoreGate("move menu: clear all") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(function() Testbed.Cleanup() end)
        if not ok then log("move menu clear-all FAILED: " .. tostring(err)) end
    end)
end
local function handleMoveMenuTargetLock()
    -- restoreGate only, NOT modGate -- matches the keyboard Num+ registration's own exemption (see
    -- its comment) since this is the SAME action reached via the '+' shortcut while this window has
    -- focus instead of the game.
    if not restoreGate("move menu: target lock") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(function() Spawner.ToggleTargetLock() end)
        if not ok then log("move menu target-lock FAILED: " .. tostring(err)) end
    end)
end
-- handleMoveMenuRotateAxisCycle REMOVED (2026-08-24, numpad rebuild) -- the old single-axis-cycle
-- concept it drove (rotateAxis/ROTATE_AXIS_CYCLE) is superseded by Spawner.placementMode/
-- TogglePlacementMode (handleMoveMenuModeToggle, above) -- Rotate mode now drives all three axes
-- at once via the numpad's own direction keys, nothing left to cycle between.
-- Despawn (matches Num9/Testbed.DespawnInFront): gated + shares the spawn debounce, same as
-- register("undo", gatedAction(...)) above -- despawn-in-front has always shared that debounce
-- with placement, not the "fast repeated tap" class undo/cycle get. restoreGate only, NOT modGate
-- (2026-08-16 split) -- see restoreGate's own comment.
local function handleMoveMenuDespawn()
    if not restoreGate("move menu: despawn") then return end
    if spawnBusy then
        print("[LivingBase] move menu: despawn ignored — shared spawn-debounce still active.\n")
        return
    end
    spawnBusy = true
    ExecuteInGameThread(function()
        local ok, err = pcall(function() Testbed.DespawnInFront() end)
        if not ok then log("move menu despawn FAILED: " .. tostring(err)) end
    end)
    if ExecuteWithDelay then
        ExecuteWithDelay(Config.SPAWN_DEBOUNCE_MS or 300, function() spawnBusy = false end)
    else
        spawnBusy = false
    end
end
-- Undo (matches Num0/Spawner.UndoDespawn): no shared debounce, same "fast repeated tap" class
-- directAction gives the keyboard key. restoreGate only, NOT modGate (2026-08-16 split) -- see
-- restoreGate's own comment.
local function handleMoveMenuUndo()
    if not restoreGate("move menu: undo") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(function() Spawner.UndoDespawn() end)
        if not ok then log("move menu undo FAILED: " .. tostring(err)) end
    end)
end
-- Coords window (2026-08-16) open/close: suspends/resumes the target-lock distance check for as
-- long as the window is open -- see Spawner.suspendTargetLockDistanceCheck's own comment in
-- spawner.lua for why. Deliberately NOT gated by modGate/spawnBusy -- this only flips a flag, it
-- never touches game state, so there's nothing for those gates to protect against.
local function handleMoveMenuCoordsOpen()
    Spawner.suspendTargetLockDistanceCheck = true
end
local function handleMoveMenuCoordsClose()
    Spawner.suspendTargetLockDistanceCheck = false
end
-- COORDS_MOVE:x:y:z:pitch:yaw:roll (2026-08-18, was x:y:z:yaw before full 3-axis rotation) --
-- Preview/Apply/Reset/Cancel in the Coords window all funnel through this SAME line shape, just
-- with different values (Preview/Apply send whatever's typed; Reset/Cancel send the window's own
-- remembered opening snapshot back) -- see Spawner.SetLockedTargetTransform's own comment for why
-- this writes an ABSOLUTE transform rather than reusing the relative-delta EditNearestInFront path
-- every other nudge control here uses.
local function handleMoveMenuCoordsMove(x, y, z, pitch, yaw, roll)
    -- restoreGate only, NOT modGate (2026-08-16 split) -- see restoreGate's own comment.
    if not restoreGate("move menu: coords") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(function() return Spawner.SetLockedTargetTransform(x, y, z, pitch, yaw, roll) end)
        if not ok then log("move menu coords FAILED: " .. tostring(err)) end
    end)
end
local function handleMoveMenuPrecision(scale)
    if type(scale) ~= "number" or scale <= 0 then return end
    -- Sets Spawner.editPrecisionScale directly -- the companion window's own slider
    -- (MoveMenu.cpp's g_precision_idx) is the ONLY way to change this now (2026-08-24, numpad-only
    -- keybind rebuild -- the old in-game Num- precision cycle is gone, Num- is the window Open/
    -- Close key now; see the default baseline's own comment above for where this used to be set).
    Spawner.editPrecisionScale = scale
end

-- Hard ceiling on how many queued actions ONE drain will ever fold into the pending accumulator,
-- regardless of how many are actually sitting in the file. MoveMenu.cpp appends and this file
-- deletes the SAME file from two different threads with no shared lock between them (C++'s
-- std::ofstream and Lua's os.remove); if a delete ever loses that race (Windows denies removing a
-- file another handle briefly has open), the file survives un-cleared and the NEXT drain re-reads
-- its old content on top of everything newly appended since. This cap bounds that worst case to a
-- sane number of steps regardless of how large the file grew, instead of chasing down the exact
-- Windows file-locking behavior that would let it happen.
local MOVE_MENU_MAX_ACTIONS_PER_DRAIN = 20

-- Pending accumulator: drainMoveMenuQueue() (fast, 100ms) adds to this; flushMoveMenuQueue()
-- (slow, 330ms as of 2026-08-19 -- see its own loop's comment) is the ONLY thing that ever reads
-- it and calls Spawner.EditNearestInFront, then resets it to zero.
local movePendingZ, movePendingYaw, movePendingFwd, movePendingRight = 0.0, 0.0, 0.0, 0.0
local movePendingPitch, movePendingRoll = 0.0, 0.0
local movePendingCount = 0

local function drainMoveMenuQueue()
    local path = findMoveRequestPath()
    if not path then return end
    local f = io.open(path, "r")
    if not f then return end
    local content = f:read("*all")
    f:close()
    local removedOk = os.remove(path)
    if not removedOk then
        -- Delete lost the race with a concurrent C++ append (see MOVE_MENU_MAX_ACTIONS_PER_DRAIN's
        -- comment) -- force-truncate as a fallback so this content can't also be re-read next
        -- drain. Whatever landed in the file in the gap between the read above and this truncate
        -- is lost, which is fine (a dropped tick or two), unlike the alternative (silently
        -- reprocessing old content forever).
        local tf = io.open(path, "w")
        if tf then tf:close() end
        print("[LivingBase] move menu: move_request.txt delete lost a race with a concurrent write -- truncated instead.\n")
    end

    local hs = Config.LIVE_EDIT_HEIGHT_STEP or 10.0
    local rs = Config.LIVE_EDIT_ROTATE_STEP or 15.0
    local ms = Config.LIVE_EDIT_MOVE_STEP or 10.0
    local scale = Spawner.editPrecisionScale or 1.0
    -- Rotation precision scaling (2026-08-19) -- same fix/reasoning as editRotAction's own comment
    -- (main.lua, the keyboard ','/'.' path): normalized against "1x (normal)" (0.25) rather than
    -- multiplying `scale` directly, so the CURRENT unscaled rs (15 deg) still comes out unchanged
    -- at normal precision, matching what RedFalcon confirmed already feels right. Keep in sync with
    -- editRotAction's own copy of this same 0.25 baseline if PRECISION_LEVELS is ever rebased again.
    local rotScale = scale / 0.25
    local count, skipped = 0, 0
    -- Line-by-line, not one gmatch over the whole file: MoveMenu.cpp can now send THREE distinct
    -- line shapes in the same file (spatial "MOVE:<ACTION>", one-shot "ACTION:<NAME>", and
    -- "PRECISION:<value>") -- see this block's own header comment for why one-shot commands are
    -- handled immediately here rather than queued into the spatial accumulator below.
    for line in content:gmatch("[^\r\n]+") do
        -- %u_ alone does NOT match digits in Lua patterns -- confirmed live 2026-08-16 with the
        -- now-removed "ROT_180" action, which silently failed to match here until this was widened
        -- to %u%d_.
        local spatialAction = line:match("^MOVE:([%u%d_]+)$")
        if spatialAction then
            if count >= MOVE_MENU_MAX_ACTIONS_PER_DRAIN then
                skipped = skipped + 1
            else
                local d = MOVE_MENU_ACTIONS[spatialAction]
                if d then
                    movePendingZ     = movePendingZ     + d[1] * hs * scale
                    movePendingYaw   = movePendingYaw   + d[2] * rs * rotScale
                    movePendingFwd   = movePendingFwd   + d[3] * ms * scale
                    movePendingRight = movePendingRight + d[4] * ms * scale
                    movePendingPitch = movePendingPitch + d[5] * rs * rotScale
                    movePendingRoll  = movePendingRoll  + d[6] * rs * rotScale
                    movePendingCount = movePendingCount + 1
                    count = count + 1
                end
            end
        else
            local precisionStr = line:match("^PRECISION:([%d%.]+)$")
            if precisionStr then
                handleMoveMenuPrecision(tonumber(precisionStr))
            elseif line == "ACTION:CLEAR_ALL" then
                handleMoveMenuClearAll()
            elseif line == "ACTION:TARGET_LOCK" then
                handleMoveMenuTargetLock()
            elseif line == "ACTION:MODE_TOGGLE" then
                handleMoveMenuModeToggle()
            elseif line == "ACTION:CANCEL_PLACEMENT" then
                handleMoveMenuCancelPlacement()
            elseif line == "ACTION:GRAB_TARGET" then
                handleMoveMenuGrabTarget()
            elseif line == "ACTION:CONFIRM_PLACEMENT" then
                handleMoveMenuConfirmPlacement()
            elseif line == "ACTION:TOGGLE_FREEBUILD" then
                handleMoveMenuToggleFreeBuild()
            elseif line == "ACTION:DESPAWN" then
                handleMoveMenuDespawn()
            elseif line == "ACTION:UNDO" then
                handleMoveMenuUndo()
            elseif line == "ACTION:COORDS_OPEN" then
                handleMoveMenuCoordsOpen()
            elseif line == "ACTION:COORDS_CLOSE" then
                handleMoveMenuCoordsClose()
            else
                -- COORDS_MOVE:x:y:z:pitch:yaw:roll (2026-08-18, was x:y:z:yaw before full 3-axis
                -- rotation) -- see handleMoveMenuCoordsMove's own comment.
                local cx, cy, cz, cp, cyaw, cr = line:match(
                    "^COORDS_MOVE:(-?[%d%.]+):(-?[%d%.]+):(-?[%d%.]+):(-?[%d%.]+):(-?[%d%.]+):(-?[%d%.]+)$")
                if cx then
                    handleMoveMenuCoordsMove(tonumber(cx), tonumber(cy), tonumber(cz),
                        tonumber(cp), tonumber(cyaw), tonumber(cr))
                end
            end
        end
    end
    if skipped > 0 then
        print(string.format("[LivingBase] move menu: capped at %d actions this drain, dropped %d queued -- move_request.txt is growing faster than expected (see the cap's own comment).\n",
            MOVE_MENU_MAX_ACTIONS_PER_DRAIN, skipped))
    end
end

local function flushMoveMenuQueue()
    if movePendingCount == 0 then return end
    local z, yaw, fwd, right = movePendingZ, movePendingYaw, movePendingFwd, movePendingRight
    local pitch, roll = movePendingPitch, movePendingRoll
    movePendingZ, movePendingYaw, movePendingFwd, movePendingRight, movePendingCount = 0.0, 0.0, 0.0, 0.0, 0
    movePendingPitch, movePendingRoll = 0.0, 0.0
    -- No shared spawnBusy debounce -- these are "fast repeated taps," not spawn-heavy. The
    -- throttle here is the flush RATE (250ms), not a busy-flag. restoreGate only -- unconditional
    -- now (Config.LIVE_EDIT gate removed 2026-08-24, numpad rebuild).
    if not restoreGate("move menu") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(function() Spawner.EditNearestInFront(z, yaw, fwd, right, pitch, roll) end)
        if not ok then log("move menu FAILED: " .. tostring(err)) end
    end)
end

if ExecuteWithDelay then
    local function moveMenuDrainLoop()
        ExecuteWithDelay(100, function()
            drainMoveMenuQueue()
            moveMenuDrainLoop()
        end)
    end
    moveMenuDrainLoop()
    -- FLUSH RATE (2026-08-19, RedFalcon: "movement causing crashing is a bit persnickety") --
    -- SLOWED, down from the actual 100ms this was running. History: the 2026-08-16 crash
    -- investigation traced the real cause to EditNearestInFront's per-edit SetActorHiddenInGame
    -- toggle (spawner.lua, since disabled) and confirmed a controlled test held up fine at 250ms
    -- with just that toggle fix -- the comment here used to conclude call rate alone was never the
    -- real problem and kept 100ms purely as cheap insurance, not because it was re-tested and
    -- confirmed safe at that speed. It wasn't -- RedFalcon is seeing renewed instability at 100ms.
    -- First tried 1000ms (a full second, deliberately well below the known-good 250ms rather than
    -- guessing a small reduction); RedFalcon then asked to try 330ms instead -- roughly a third of
    -- a second, still meaningfully slower than 100ms and close to the previously-validated 250ms,
    -- to see if a lighter slowdown is enough before committing to the choppier 1000ms feel. If
    -- 330ms doesn't fully resolve it, the toggle-disable fix itself (or something new since
    -- 2026-08-16) needs re-examining, not just another rate reduction.
    local function moveMenuFlushLoop()
        ExecuteWithDelay(330, function()
            flushMoveMenuQueue()
            moveMenuFlushLoop()
        end)
    end
    moveMenuFlushLoop()
    print("[LivingBase] Move menu bridge armed — watching for move_request.txt from LivingBaseSpawnMenu.\n")
end

------------------------------------------------------------
-- SPAWN MENU STATUS: the mirror of the two request channels above -- those only ever go
-- C++ -> Lua (a click/button becomes a real spawn/edit); this one goes Lua -> C++, so the window
-- can show live state it has no other way to know: whether Floor Clipping is on
-- (`Spawner._placementFreeBuild`), whether the world-load restore lock is active
-- (`restoreLockActive` -- see the "Restore: ..." block above; every keyboard key is gated on this
-- exact flag today, and RedFalcon asked for the window's buttons to be gated the same way),
-- which numpad mode is active (`Spawner.placementMode`, "MOVE"/"ROTATE" -- 2026-08-24 numpad
-- rebuild), and what's currently target-locked (Spawner.lockedTarget, Num+). Overwrites one small
-- file each time any of these actually changes -- POLLED AND DIFFED here rather than published
-- eagerly at each mutation site, since those sites are scattered across two files
-- (Spawner._placementFreeBuild/restoreLockActive/Spawner.placementMode's several set points here
-- and in spawner.lua) and this state only ever changes on an explicit user action or a restore
-- starting/ending, never on a held-repeat -- a short poll is simple, correct, and imperceptible.
------------------------------------------------------------
local SPAWN_MENU_STATUS_PATH = "ue4ss/Mods/LivingBase/spawn_menu_status.txt"
local lastPublishedFreeBuild, lastPublishedRestoring, lastPublishedTarget, lastPublishedId = nil, nil, nil, nil
local lastPublishedX, lastPublishedY, lastPublishedZ, lastPublishedYaw = nil, nil, nil, nil
local lastPublishedPitch, lastPublishedRoll = nil, nil
-- Also reads the locked target's live transform (2026-08-16, for the Coords window's "populate
-- from wherever the target currently is" snapshot-on-open) -- empty label/zeroed transform when
-- nothing's locked, same as before.
--
-- id (2026-08-16): the DISPLAY label alone isn't a reliable identity check -- two different actors
-- can share the exact same label (two identically-dressed Senkamati, two identical decor props),
-- so retargeting from one to the other via the "+ on a different thing" feature could leave
-- `target` looking unchanged even though the underlying actor is a completely different one.
-- CONFIRMED live (2026-08-16): this let the Coords window fail to notice a retarget onto a
-- same-labeled object -- it neither closed nor refreshed. GetFullName() (already used elsewhere in
-- this codebase for exactly this "need a real per-instance identity" reason) includes UE's own
-- auto-assigned per-instance discriminator, so it stays unique even when the label collides.
local function currentLockedTargetInfo()
    local lt = Spawner.lockedTarget
    if not (lt and lt.actor and lt.actor:IsValid()) then
        return "", "", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    end
    local id = ""
    pcall(function() id = lt.actor:GetFullName() end)
    local x, y, z, yaw, pitch, roll = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    pcall(function()
        local l = lt.actor:K2_GetActorLocation()
        local r = lt.actor:K2_GetActorRotation()
        x, y, z, yaw, pitch, roll = l.X, l.Y, l.Z, r.Yaw, r.Pitch, r.Roll
    end)
    return tostring(lt.label), tostring(id), x, y, z, yaw, pitch, roll
end
local lastPublishedWindowToggle = nil
local lastPublishedFocusSteal = nil
local lastPublishedPlacementMode = nil
local function publishSpawnMenuStatusIfChanged()
    local freebuild, restoring = Spawner._placementFreeBuild, restoreLockActive
    local placementMode = Spawner.placementMode or "MOVE"
    local target, id, x, y, z, yaw, pitch, roll = currentLockedTargetInfo()
    if freebuild == lastPublishedFreeBuild and restoring == lastPublishedRestoring and target == lastPublishedTarget
        and id == lastPublishedId
        and x == lastPublishedX and y == lastPublishedY and z == lastPublishedZ and yaw == lastPublishedYaw
        and pitch == lastPublishedPitch and roll == lastPublishedRoll
        and windowToggleSeq == lastPublishedWindowToggle
        and focusStealSeq == lastPublishedFocusSteal
        and placementMode == lastPublishedPlacementMode then
        return
    end
    lastPublishedFreeBuild, lastPublishedRestoring, lastPublishedTarget, lastPublishedId = freebuild, restoring, target, id
    lastPublishedX, lastPublishedY, lastPublishedZ, lastPublishedYaw = x, y, z, yaw
    lastPublishedPitch, lastPublishedRoll = pitch, roll
    lastPublishedWindowToggle = windowToggleSeq
    lastPublishedFocusSteal = focusStealSeq
    lastPublishedPlacementMode = placementMode
    local f = io.open(SPAWN_MENU_STATUS_PATH, "w")
    if not f then return end
    f:write("FREEBUILD=", freebuild and "1" or "0", "\n")
    f:write("RESTORING=", restoring and "1" or "0", "\n")
    f:write("TARGET=", target, "\n")
    f:write("TARGET_ID=", id, "\n")
    f:write("TARGET_X=", string.format("%.2f", x), "\n")
    f:write("TARGET_Y=", string.format("%.2f", y), "\n")
    f:write("TARGET_Z=", string.format("%.2f", z), "\n")
    f:write("TARGET_YAW=", string.format("%.2f", yaw), "\n")
    f:write("TARGET_PITCH=", string.format("%.2f", pitch), "\n")
    f:write("TARGET_ROLL=", string.format("%.2f", roll), "\n")
    f:write("WINDOW_TOGGLE=", tostring(windowToggleSeq), "\n")
    f:write("FOCUS_STEAL=", tostring(focusStealSeq), "\n")
    f:write("PLACEMENT_MODE=", placementMode, "\n")
    f:close()
end
if ExecuteWithDelay then
    local function statusPublishLoop()
        ExecuteWithDelay(300, function()
            pcall(publishSpawnMenuStatusIfChanged)
            statusPublishLoop()
        end)
    end
    statusPublishLoop()
end

-- Whistle -> crew escort (anchor method) and the Caster's totem killer. Both use
-- NotifyOnNewObject, which fires the instant the object is constructed -- no polling.
-- Installed at mod load; the hooks are global, so there is nothing to re-apply per world.
local Whistle = nil
if Config.WHISTLE_CREW or Config.CASTER_KILL_TOTEMS then
    Whistle = require("whistle")
    pcall(function() Whistle.Install() end)
end



-- Unlock hidden build-menu pieces (leaves standard progression intact). The build catalog isn't loaded
-- until the player opens the build menu / is near a building center, so retry a few times until it
-- appears, then run once more later to catch anything that streamed in. First run lists what it found.
if Config.UNLOCK_HIDDEN_BUILDING and ExecuteWithDelay then
    local UnlockBuild = require("unlockbuild")
    local tries = 0
    -- shouldContinue reflects the PREVIOUS completed attempt's result, not the one currently in
    -- flight -- doWork()'s own ExecuteInGameThread callback is async (queued for a later game
    -- tick, doesn't block), so by the time unlockTick checks this it's necessarily one tick
    -- stale. That's fine for a "retry up to ~10 times" heuristic (worst case: one extra retry
    -- beyond the ideal stopping point) and it's the price of the actual fix below.
    local shouldContinue = true
    local function doWork()
        ExecuteInGameThread(function()
            local n = 0
            pcall(function() n = UnlockBuild.Run(tries == 0) or 0 end)
            tries = tries + 1
            -- keep retrying while the catalog is empty (max ~10 tries), then a couple of top-ups
            shouldContinue = (n == 0 and tries < 10) or tries < 3
        end)
    end
    -- CONFIRMED live (2026-08-16): calling ExecuteWithDelay NESTED inside an ExecuteInGameThread
    -- callback throws "No overload found for function 'ExecuteWithDelay'" in this UE4SS build --
    -- this was happening on every single launch (Config.UNLOCK_HIDDEN_BUILDING's first retry
    -- fires ~15s after mod load, right on schedule with the observed crash timing), well before
    -- the player had any chance to interact with anything. Fix: doWork()'s ExecuteInGameThread
    -- call and unlockTick's own ExecuteWithDelay call are siblings now, never nested -- every
    -- other ExecuteWithDelay-recursion in this codebase (e.g. this file's own move-menu poll
    -- loops) already follows exactly this "call it from the SAME level as its own callback, never
    -- from inside a nested ExecuteInGameThread" shape, which is presumably why none of those ever
    -- hit this.
    local function unlockTick()
        doWork()
        if shouldContinue then
            ExecuteWithDelay(15000, unlockTick)
        end
    end
    ExecuteWithDelay(15000, unlockTick)
end

-- Solidify decorations after restore: restoreOne already freezes + collides each restored prop inline
-- (same frame as its spawn), and fresh placements solidify at placement — so this is just ONE insurance
-- sweep after the world settles, in case a prop restored on a slow stream slipped through. No repeat.
if Config.DECOR_COLLISION ~= false and ExecuteWithDelay then
    ExecuteWithDelay((Config.RESTORE_SETTLE_MS or 6000) + 8000, function()
        ExecuteInGameThread(function() pcall(function() Spawner.SolidifyDecor() end) end)
    end)
end

-- Restore persisted spawns on WORLD LOAD (not on Ctrl+R). InitGameState fires
-- when a map/game-state loads; Ctrl+R does not re-init it, so we don't double-
-- spawn. After it fires, wait for the player pawn to exist, then re-spawn.
local UEHelpers = require("UEHelpers")
-- InitGameState fires SEVERAL times (menu, then ~3x per world load). We must run exactly one
-- chain — but NOT by locking out later fires. v2.03 did that and broke restore entirely: the
-- MENU's chain held the lock, the real world-load fire was swallowed, then the menu chain
-- timed out silently. Nobody ever restored, and nothing was logged.
-- Correct pattern: LATEST FIRE WINS. Each call bumps a generation; older chains see a newer
-- generation on their next tick and retire themselves.
local restoreGen = 0
local function scheduleRestore()
    -- Checked LIVE (not cached at hook-registration time) so RESTORE_ON_LOAD, unlike LIVE_EDIT/
    -- KEYS_ENABLED_ONSTART/the four require()-gated feature flags above, can be flipped from
    -- Settings > Mods and take effect on the very next world load with no restart — see
    -- modsettings.lua's TOGGLE_DEFS comment for why this one specifically was safe to make live
    -- (no hook-install/teardown asymmetry: skipping this function is a complete, reversible no-op).
    if Config.RESTORE_ON_LOAD == false then
        log("Restore: skipped (RESTORE_ON_LOAD is off).")
        return
    end
    restoreGen = restoreGen + 1
    local myGen = restoreGen
    -- Lock every mod key for THIS chain until it concludes one way or another (restored, nothing to
    -- restore, or gave up) -- released below at every exit path, guarded by myGen so a stale older
    -- chain's completion can't unlock a newer one that's still in progress.
    restoreLockActive = true
    -- Only restore once the REAL player character exists — not a menu/loading pawn.
    local function isPlayerPawn(pawn)
        local ok, name = pcall(function() return pawn:GetClass():GetFName():ToString() end)
        return ok and type(name) == "string" and name:find("R5Character") ~= nil
    end
    local function pawnLoc(pawn)
        local ok, l = pcall(function() return pawn:K2_GetActorLocation() end)
        if ok and l then return l end
        return nil
    end
    local tries, waits, startLoc, sawPawn = 0, 0, nil, false
    local function unlockIfCurrent()
        if myGen == restoreGen then
            restoreLockActive = false
        end
    end
    local function fire(why)
        local delay = Config.RESTORE_SETTLE_MS or 4000
        always(string.format("Restore: %s; settling %dms.", why, delay))
        if ExecuteWithDelay then
            ExecuteWithDelay(delay, function()
                ExecuteInGameThread(function()
                    if Whistle then pcall(function() Whistle.ApplyOnLoad() end) end
                    pcall(function() Spawner.RestoreFromPersist(unlockIfCurrent) end)
                end)
            end)
        else
            ExecuteInGameThread(function()
                if Whistle then pcall(function() Whistle.ApplyOnLoad() end) end
                pcall(function() Spawner.RestoreFromPersist(unlockIfCurrent) end)
            end)
        end
    end
    local function tick()
        if myGen ~= restoreGen then return end   -- a newer world load superseded this chain
        local ok, pawn = pcall(function()
            local pc = UEHelpers.GetPlayerController()
            return pc and pc:IsValid() and pc.Pawn or nil
        end)
        if not (ok and pawn and pawn:IsValid() and isPlayerPawn(pawn)) then
            if tries < 120 and ExecuteWithDelay then
                tries = tries + 1
                ExecuteWithDelay(1000, tick)
            else
                -- Never give up silently: that is exactly how the v2.03 bug hid.
                always("Restore: gave up — no player pawn after 120s. Nothing restored.")
                unlockIfCurrent()
            end
            return
        end
        if not sawPawn then
            sawPawn = true
            always("Restore: player pawn ready — waiting for you to move before spawning.")
            -- This ONE move is required (it's how restore tells "still loading" from "world is
            -- live" — see the comment just below), but once it fires, stop: Spawner.RestoreFromPersist
            -- shows its own "please stand still" toast for the actual restore window that follows.
            pcall(function() Spawner.Toast("LivingBase: move once to confirm the world has loaded, then stand still — restoring your base is about to begin.", 3.0) end)
        end
        -- The pawn EXISTS during the loading screen, so its presence is not proof the world
        -- is live. Spawning 20 AI movers mid-stream hung the game (2026-07-09: "Restore:
        -- starting, 20 saved entries" then frozen, not one SPAWNED line). Wait until the
        -- player actually MOVES horizontally — that can only happen once the loading screen
        -- is gone. Z is ignored because the pawn settles/falls onto the ground during load.
        local loc = pawnLoc(pawn)
        if not startLoc then startLoc = loc end
        if startLoc and loc then
            local dx, dy = loc.X - startLoc.X, loc.Y - startLoc.Y
            local eps = Config.RESTORE_MOVE_EPSILON or 100
            if (dx * dx + dy * dy) > (eps * eps) then
                fire(string.format("player moved after %ds — world is live", waits))
                return
            end
        end
        waits = waits + 1
        if waits >= (Config.RESTORE_MOVE_TIMEOUT_S or 120) then
            fire("player never moved; proceeding after timeout")
            return
        end
        if ExecuteWithDelay then ExecuteWithDelay(1000, tick) else fire("no delay API") end
    end
    tick()
end
-- Registered UNCONDITIONALLY (not gated on Config.RESTORE_ON_LOAD) so a later live toggle-on takes
-- effect on the next world load — scheduleRestore() itself checks the live flag at entry and no-ops
-- cleanly if it's off, so registering the hook when the flag starts false costs nothing.
if RegisterInitGameStatePostHook then
    pcall(function()
        RegisterInitGameStatePostHook(function() scheduleRestore() end)
    end)
    log("Save/restore hook installed (RESTORE_ON_LOAD=" .. tostring(Config.RESTORE_ON_LOAD ~= false) .. "; live via Settings > Mods).")
else
    log("Auto-restore unavailable — RegisterInitGameStatePostHook missing. Place by keystroke.")
end

-- LB_COMMANDS / registerCmdInfo -- a lightweight metadata registry for "lbhelp" (2026-08-27).
-- Deliberately separate from RegisterConsoleCommandHandler itself, not a wrapper around it -- every
-- actual registration call below is completely untouched, so adding this can't affect whether any
-- existing command still registers correctly. Each command's own registration block gets ONE extra
-- line, right next to its existing `log("Console command registered: ...")` line, recording its
-- name/usage/one-line description here. Declared this early (before the first real command below)
-- so every later `registerCmdInfo(...)` call has it in scope.
local LB_COMMANDS = {}
local function registerCmdInfo(name, usage, desc)
    LB_COMMANDS[#LB_COMMANDS + 1] = { name = name, usage = usage or name, desc = desc or "" }
end

-- Console command "lbspawn <ShortName|ClassPath>" (2026-08-13) -- spawn any class for quick
-- validation, WITHOUT needing to add it to a config.lua roster and wire up a key first. Goes through
-- the exact same Spawner.Spawn every placement key already uses, so it gets identical treatment:
-- set-dressing invulnerability, nameplate/interaction/quest-scenario stripping, tracked in
-- Spawner.spawned (Num9 despawn / DEL clean-house / Num0 undo all work on it), recorded to
-- persist.txt (survives reload), and the normal "Spawned: X" toast. makeFriendly is deliberately
-- left off (false) -- this is a raw validation spawn of a possibly-unknown class, not a placement
-- through a roster that already decided whether that class should be friendly.
-- RegisterConsoleCommandHandler confirmed available in this UE4SS build via the separately
-- installed ConsoleCommandsMod (its "set"/"summon"/"dump_object" commands) -- "lbspawn" is a new,
-- distinct command name so it can't collide with those or the engine's own native "summon".
-- Ar (3rd handler arg) is an FOutputDevice -- Ar:Log(msg) prints directly into whichever console
-- window is open (the same mechanism ConsoleCommandsMod's own Log() helper uses), independent of
-- ue4ss.log and the in-game toast, so usage/failure feedback is visible right where it was typed.
-- SHORT NAME LOOKUP: class_index.lua (generated from the game's own asset manifest -- see its own
-- header comment) maps short Blueprint names ("BP_Mob_Wolf") to their full /Game/... path, so you
-- don't have to type the whole thing. Checked against the manifest 2026-08-13: only ONE short-name
-- collision exists across all 2,573 BP_ classes in the whole game (an irrelevant boss-arena prop),
-- so this is safe in practice, not just convenient. A path starting with "/" is used AS-IS (skips
-- the lookup entirely), so a full path always still works even for something not in the index.
local ClassIndexOk, ClassIndex = pcall(require, "class_index")
if not ClassIndexOk then
    ClassIndex = {}
    print("[LivingBase] class_index.lua failed to load -- lbspawn will only accept full /Game/... paths.\n")
end
local ClassIndexLower = {}
for shortName, path in pairs(ClassIndex) do
    ClassIndexLower[shortName:lower()] = path
end

-- Short class name (matching class_index.lua's own key format) from a full /Game/... object
-- path -- "/Game/.../BP_Mob_Wolf.BP_Mob_Wolf_C" -> "BP_Mob_Wolf". Used to build the `lbspawn
-- list` category tables below from the SAME live Config/FKeys data every placement key reads,
-- so the list can never drift from what's actually spawnable.
local function shortClassFromPath(path)
    local leaf = tostring(path):match("([^/]+)$") or tostring(path)
    return leaf:match("^([^%.]+)") or leaf
end

-- Category tables for "lbspawn list <category>" -- built ONCE at mod load from the live
-- Config.STANDING_STATUES/etc and Config.DECOR_CATEGORIES tables (2026-08-13). Statues only
-- carry `faction`+`path` at runtime (their human-readable "-- comment" is source-only, not
-- data), so the list shows [faction] short-class-name -- the short class name is what you'd
-- actually type, the faction is just enough context to tell entries apart at a glance.
local function buildStatueListing(list)
    local out = {}
    for _, e in ipairs(list or {}) do
        out[#out + 1] = string.format("[%s] %s", tostring(e.faction), shortClassFromPath(e.path))
    end
    return out
end
local function buildDecorListing(list)
    local out = {}
    for _, e in ipairs(list or {}) do
        out[#out + 1] = string.format("[%s]", tostring(e.name))
    end
    return out
end
local LBSPAWN_CATEGORIES = {
    { key = "standing",    label = "Standing statues (Num3)",        entries = buildStatueListing(Config.STANDING_STATUES) },
    { key = "seated",      label = "Seated statues (Num4)",          entries = buildStatueListing(Config.SEATED_STATUES) },
    { key = "chair",       label = "Chair/stool statues (Num5)",     entries = buildStatueListing(Config.CHAIR_STATUES) },
    { key = "interactive", label = "Interactive statues (Num6)",     entries = buildStatueListing(Config.INTERACTIVE_STATUES) },
    { key = "nature",      label = "Decor: Nature",                 entries = buildDecorListing(Config.DECOR_CATEGORIES and Config.DECOR_CATEGORIES.nature) },
    { key = "boats",       label = "Decor: Boats",                  entries = buildDecorListing(Config.DECOR_CATEGORIES and Config.DECOR_CATEGORIES.boats) },
    { key = "wrecks",      label = "Decor: Wrecks",                 entries = buildDecorListing(Config.DECOR_CATEGORIES and Config.DECOR_CATEGORIES.wrecks) },
    { key = "tents",       label = "Decor: Tents/Bedrolls",          entries = buildDecorListing(Config.DECOR_CATEGORIES and Config.DECOR_CATEGORIES.tents) },
    { key = "storage",     label = "Decor: Storage Clutter",         entries = buildDecorListing(Config.DECOR_CATEGORIES and Config.DECOR_CATEGORIES.storage) },
    { key = "furniture",   label = "Decor: Furniture",               entries = buildDecorListing(Config.DECOR_CATEGORIES and Config.DECOR_CATEGORIES.furniture) },
}

if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbspawn", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbspawn] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local function usage()
                say("Usage: lbspawn <ShortName|ClassPath>  e.g. lbspawn BP_Mob_Wolf  OR  lbspawn /Game/Gameplay/Character/AI/Mob/Wolf/BP_Mob_Wolf.BP_Mob_Wolf_C")
                say("       lbspawn list            -- show categories + counts")
                say("       lbspawn list <category>  -- e.g. lbspawn list standing / nature / furniture")
                say("       lbspawn list all         -- dump every category (long)")
                say("For named looks (crew/townsman/statues/Senkamati/livestock/walking women/decor) use lblook instead, not lbspawn.")
            end
            local arg1 = Parameters and Parameters[1]
            if not arg1 or arg1 == "?" then
                usage()
                return true
            end
            if arg1:lower() == "list" then
                local which = Parameters[2] and Parameters[2]:lower()
                if not which then
                    say("lbspawn categories:")
                    for _, cat in ipairs(LBSPAWN_CATEGORIES) do
                        say(string.format("  %-12s %s (%d)", cat.key, cat.label, #cat.entries))
                    end
                    say("Run 'lbspawn list <category>' for the full names in one, or 'lbspawn list all' for everything.")
                    return true
                end
                local shown = 0
                for _, cat in ipairs(LBSPAWN_CATEGORIES) do
                    if which == "all" or which == cat.key then
                        say(cat.label .. " (" .. #cat.entries .. "):")
                        for _, line in ipairs(cat.entries) do say("  " .. line) end
                        shown = shown + 1
                    end
                end
                if shown == 0 then
                    say("Unknown category '" .. Parameters[2] .. "'. Run 'lbspawn list' to see valid categories.")
                end
                return true
            end
            local input = arg1
            local classPath = input
            if not input:match("^/") then
                classPath = ClassIndex[input] or ClassIndexLower[input:lower()]
                if not classPath then
                    say("Unknown short name: " .. input .. " (not in the index of 2,562 known BP_ classes"
                        .. " -- check spelling, run 'lbspawn list' to browse LivingBase's own roster,"
                        .. " or pass the full /Game/... path instead)")
                    return true
                end
            end
            local ok, actor = pcall(function()
                return Spawner.Spawn(classPath, input, nil, nil, nil, nil, false, nil)
            end)
            if ok and actor and actor:IsValid() then
                say("Spawned: " .. input .. (classPath ~= input and (" (" .. classPath .. ")") or ""))
            else
                say("FAILED to spawn: " .. classPath .. " (see ue4ss.log for the [LivingBase] SPAWN FAILED line -- usually an unresolved class path)")
            end
            return true
        end)
    end)
    log("Console command registered: lbspawn <ClassPath>")
    registerCmdInfo("lbspawn", "lbspawn <ShortName|ClassPath>", "Spawn any class for quick validation, tracked/despawnable/undoable like a normal placement, without adding it to a config roster first.")
else
    log("lbspawn unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

------------------------------------------------------------
-- SPIKE (2026-08-19, RedFalcon's build-ghost-preview feasibility check): "lbtickspike
-- [intervalMs] [ticks]" -- throwaway diagnostic, NOT part of the real feature. Every
-- self-rescheduling ExecuteWithDelay loop already in this file (spawnMenuPollLoop,
-- moveMenuFlushLoop, etc.) runs at 300-400ms; nothing has ever asked it to hold a ~60fps
-- (16ms) cadence, which is what a camera-following ghost actor would need to look smooth.
-- This just fires N reschedules at the requested nominal interval and reports the REAL
-- elapsed gap between callbacks (min/max/avg), so we know whether ExecuteWithDelay drifts
-- badly at that speed before building anything on top of it. Delete once the ghost-preview
-- feature either lands or gets shelved -- this has no purpose beyond that one decision.
------------------------------------------------------------
if RegisterConsoleCommandHandler and ExecuteWithDelay then
    pcall(function()
        RegisterConsoleCommandHandler("lbtickspike", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [tickspike] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local intervalMs = tonumber(Parameters and Parameters[1]) or 16
            local totalTicks = tonumber(Parameters and Parameters[2]) or 120
            say(string.format("starting: nominal %dms x %d ticks (~%.1fs) -- watch for the 'done' line", intervalMs, totalTicks, intervalMs * totalTicks / 1000.0))
            local samples = {}
            local lastClock = os.clock()
            local count = 0
            local function tick()
                local now = os.clock()
                local dt = (now - lastClock) * 1000.0
                lastClock = now
                count = count + 1
                -- First callback's "dt" is time-since-command-issued, not a tick-to-tick gap -- not
                -- a real sample, would skew min/avg low if kept.
                if count > 1 then
                    table.insert(samples, dt)
                end
                if count < totalTicks then
                    ExecuteWithDelay(intervalMs, tick)
                else
                    local sum, lo, hi = 0.0, math.huge, 0.0
                    for _, v in ipairs(samples) do
                        sum = sum + v
                        if v < lo then lo = v end
                        if v > hi then hi = v end
                    end
                    local avg = #samples > 0 and (sum / #samples) or 0.0
                    -- CONFIRMED LIVE (2026-08-19): NOT a plain print() -- say() touches Ar (the
                    -- console command's FOutputDevice), which is only valid for the SYNCHRONOUS
                    -- duration of the command handler that received it. Calling say() from in here
                    -- (an ExecuteWithDelay callback firing seconds later, well after the handler
                    -- already returned) crashed on the exact instant this line ran, three times in a
                    -- row across two different test structures -- a stale-Ar use-after-free, not a
                    -- scheduling problem. Plain print() only, same as every other tick() call above.
                    print(string.format("[LivingBase] [tickspike] done: %d samples, avg=%.2fms min=%.2fms max=%.2fms (nominal %dms) -- os.clock() is CPU time, treat as an approximation\n", #samples, avg, lo, hi, intervalMs))
                end
            end
            ExecuteWithDelay(intervalMs, tick)
            return true
        end)
    end)
    log("Console command registered: lbtickspike [intervalMs=16] [ticks=120] -- diagnostic, see comment above")
    registerCmdInfo("lbtickspike", "lbtickspike [intervalMs=16] [ticks=120]", "Diagnostic: hammers ExecuteWithDelay at a fixed interval and reports min/max/avg drift, to sanity-check the timer before building on it.")
else
    log("lbtickspike unavailable -- RegisterConsoleCommandHandler or ExecuteWithDelay missing in this UE4SS build.")
end

------------------------------------------------------------
-- "lbtickspike2 [intervalMs] [ticks]" -- lbtickspike (above) crashed TWICE tonight, both times at
-- the exact same instant as its own "done" line (crash dump timestamp within 0.15ms of it) -- once
-- at tick 120/16ms (~2s total), once at tick 500/50ms (~25s total). Different tick counts, different
-- total durations, same result: crash lands on the ONE callback that breaks the chain (stops calling
-- ExecuteWithDelay and does something else instead), never on any of the hundreds of callbacks that
-- keep rescheduling. That rules out both "too fast" and "too many iterations" as the cause -- points
-- specifically at whatever happens when a self-rescheduling ExecuteWithDelay chain stops
-- rescheduling. Testing the fix: NEVER take that branch -- always call ExecuteWithDelay again,
-- unconditionally, forever; use a flag to make it a no-op past totalTicks instead of actually
-- stopping. If this survives past its own totalTicks without crashing, that confirms the theory AND
-- gives the real feature's camera-follow loop a concrete pattern to use (never let it stop
-- rescheduling itself while armed -- only flip a flag that makes each tick a no-op).
-- WARNING: unlike lbtickspike, this does NOT stop on its own -- it keeps ticking silently forever
-- once its sample window is done. Fine for a one-off live test right before a relaunch; do not leave
-- running.
------------------------------------------------------------
if RegisterConsoleCommandHandler and ExecuteWithDelay then
    pcall(function()
        RegisterConsoleCommandHandler("lbtickspike2", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [tickspike2] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local intervalMs = tonumber(Parameters and Parameters[1]) or 16
            local totalTicks = tonumber(Parameters and Parameters[2]) or 120
            say(string.format("starting: nominal %dms x %d ticks (~%.1fs) -- NEVER stops rescheduling, watch for 'done'", intervalMs, totalTicks, intervalMs * totalTicks / 1000.0))
            local samples = {}
            local lastClock = os.clock()
            local count = 0
            local reported = false
            local function tick()
                if count < totalTicks then
                    local now = os.clock()
                    local dt = (now - lastClock) * 1000.0
                    lastClock = now
                    count = count + 1
                    if count > 1 then
                        table.insert(samples, dt)
                    end
                end
                if count >= totalTicks and not reported then
                    reported = true
                    local sum, lo, hi = 0.0, math.huge, 0.0
                    for _, v in ipairs(samples) do
                        sum = sum + v
                        if v < lo then lo = v end
                        if v > hi then hi = v end
                    end
                    local avg = #samples > 0 and (sum / #samples) or 0.0
                    -- Same stale-Ar fix as lbtickspike -- see that one's own comment. This test's
                    -- 3rd crash (identical timing signature despite NEVER breaking the reschedule
                    -- chain) is what proved it's Ar, not scheduling structure.
                    print(string.format("[LivingBase] [tickspike2] done: %d samples, avg=%.2fms min=%.2fms max=%.2fms (nominal %dms) -- still ticking silently, chain never stops -- restart the game when finished testing\n", #samples, avg, lo, hi, intervalMs))
                end
                -- ALWAYS reschedules, even past totalTicks -- this is the actual thing under test.
                ExecuteWithDelay(intervalMs, tick)
            end
            ExecuteWithDelay(intervalMs, tick)
            return true
        end)
    end)
    log("Console command registered: lbtickspike2 [intervalMs=16] [ticks=120] -- diagnostic, see comment above")
    registerCmdInfo("lbtickspike2", "lbtickspike2 [intervalMs=16] [ticks=120]", "Variant of lbtickspike -- WARNING: does not stop on its own once its sample window ends; do not leave it running.")
else
    log("lbtickspike2 unavailable -- RegisterConsoleCommandHandler or ExecuteWithDelay missing in this UE4SS build.")
end

-- Console command "lblook <name>" (2026-08-13) -- spawn one of LivingBase's own NAMED composite
-- looks (a base engine class PLUS the specific reskin/de-corrupt/pacify recipe that makes it
-- "walking Letty", a masked Warrior, a Buccaneers Musketeer, a tamed Boar, etc.), not a raw
-- engine class -- that's what lbspawn is for. A plain lbspawn of the walker/crew/animal BASE
-- class gets you the default look/behavior with NONE of that recipe applied (confirmed live
-- 2026-08-13: lbspawn-ing the Boar class stayed aggressive, since raw lbspawn deliberately skips
-- the friendly-faction+AI-override treatment). lblook runs the exact same by-name spawn path
-- each category's own placement key already uses (Testbed.SpawnCrewByName / SpawnWalkerByName /
-- SpawnStandingByName / SpawnSeatedByName / SpawnChairByName / SpawnInteractiveByName /
-- SpawnSenkaByKey / SpawnLivestockByName / SpawnFemaleWalkerByName / SpawnDecorByName -- every
-- one added alongside this command by refactoring the rotation-driven Num1-Num8/Numpad-decimal/
-- ';' handlers to share their spawn logic with these by-name lookups), so it's validation of the
-- SAME thing you'd get by pressing that key enough times, not a separate path that could quietly
-- drift from what the real keys do. Full coverage pass 2026-08-13: every named recipe LivingBase
-- can produce is now reachable through lblook, not just crew/senka/women/livestock. One exception:
-- SpawnBarbieByName ("Female_Barbie") is lblook-ONLY, deliberately -- no numpad key/rotation of
-- its own, see its own comment in testbed.lua.
-- Tried in LBLOOK_CATEGORIES' own order (first match wins) -- see each Testbed function's own
-- comment for its exact matching rules (case-insensitive throughout; Senkamati also accepts an
-- optional leading "SENKA_" to match the in-toast label verbatim).
-- Short class name shown/matched for a {faction, path} statue entry -- same identifier
-- statueEntryName() computes in testbed.lua, so what's listed here IS what you type.
local function statueShortName(path)
    return tostring(path):match("([%w_]+)%.[%w_]+$") or tostring(path)
end
local LBLOOK_CATEGORIES = {
    { key = "crew", label = "Crew (Num1)", entries = (function()
        local out = {}
        for _, e in ipairs(Config.FACTION_VISITOR_LOOKS or {}) do out[#out + 1] = e.name end
        return out
    end)() },
    { key = "townsman", label = "Townsfolk (Num2)", entries = (function()
        local out = {}
        for _, c in ipairs(Config.TOWNSFOLK_CLASSES or {}) do out[#out + 1] = c.name end
        return out
    end)() },
    { key = "standing", label = "Standing statues (Num3)", entries = (function()
        local out = {}
        for _, w in ipairs(Config.STANDING_STATUES or {}) do out[#out + 1] = statueShortName(w.path) end
        return out
    end)() },
    { key = "seated", label = "Floor sitters (Num4)", entries = (function()
        local out = {}
        for _, w in ipairs(Config.SEATED_STATUES or {}) do out[#out + 1] = statueShortName(w.path) end
        return out
    end)() },
    { key = "chair", label = "Chair/stool sitters (Num5)", entries = (function()
        local out = {}
        for _, w in ipairs(Config.CHAIR_STATUES or {}) do out[#out + 1] = statueShortName(w.path) end
        return out
    end)() },
    { key = "interactive", label = "Interactive statues (Num6)", entries = (function()
        local out = {}
        for _, w in ipairs(Config.INTERACTIVE_STATUES or {}) do out[#out + 1] = statueShortName(w.path) end
        return out
    end)() },
    { key = "senka", label = "Senkamati (Num7)", entries = (function()
        -- Reuses Testbed.SenkaShortKey (2026-08-14) instead of a hand-duplicated format string --
        -- this list previously built the same "name_kind_Mask" shape independently, which would have
        -- silently missed the baseLabel differentiation added for the Herbalist-base Caster-F rows
        -- (see Config.SENKAMATI_LOOKS' own comment) had it stayed a separate copy here.
        local out = {}
        for _, s in ipairs(Config.SENKAMATI_LOOKS or {}) do
            out[#out + 1] = Testbed.SenkaShortKey(s)
        end
        return out
    end)() },
    { key = "animals", label = "Animals/Livestock (Num8)", entries = (function()
        local out = {}
        for _, t in ipairs({ Config.BOARS, Config.GOATS, Config.DODOS, Config.WOLVES, Config.CROCODILES }) do
            for _, e in ipairs(t or {}) do out[#out + 1] = e.name end
        end
        return out
    end)() },
    -- "Woman With Hair" split into "Base 1" (Gatherer)/"Base 2" (Herbalist) 2026-08-14 -- both
    -- reachable here via Testbed.SpawnFemaleWalkerByName, same as every other entry in this list; no
    -- separate lblook-only entry needed (a short-lived one existed for a few minutes this same day,
    -- removed once this proper roster integration made it redundant -- see testbed.lua's own note).
    { key = "women", label = "Walking Women (Numpad .)", entries = Testbed.FEMALE_RESKIN_TARGETS or {} },
    { key = "barbie", label = "Barbie (lblook only)", entries = { "Female_Barbie" } },
    -- standingcrewtest/standingcrewposetest lblook entries REMOVED (2026-08-15) -- both were
    -- scaffolding for the now-CLOSED pose-porting investigation; the frozen crew/mob-body idle
    -- rows added to Num7 (Config.SENKAMATI_LOOKS, item 66) cover the same "see a frozen look for
    -- comparison" need these existed for, without a separate test-only entry.
    { key = "decor", label = "Decor (';')", entries = (function()
        local out = {}
        for _, catKey in ipairs(Config.DECOR_ORDER or {}) do
            for _, d in ipairs((Config.DECOR_CATEGORIES or {})[catKey] or {}) do out[#out + 1] = d.name end
        end
        return out
    end)() },
}

if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lblook", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lblook] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local function usage()
                say("Usage: lblook <name>  e.g. lblook Letty | lblook Buccaneers Musketeer | lblook Warrior_crew_Mask | lblook Boar")
                say("       lblook list            -- show categories + counts")
                say("       lblook list <category>  -- e.g. lblook list crew / townsman / standing / senka / animals / women / decor")
                say("       lblook list all         -- dump every category")
                say("For a raw engine class with none of this mod's recipes applied, use lbspawn instead.")
            end
            local arg1 = Parameters and Parameters[1]
            if not arg1 or arg1 == "?" then
                usage()
                return true
            end
            if arg1:lower() == "list" then
                local which = Parameters[2] and Parameters[2]:lower()
                if not which then
                    say("lblook categories:")
                    for _, cat in ipairs(LBLOOK_CATEGORIES) do
                        say(string.format("  %-8s %s (%d)", cat.key, cat.label, #cat.entries))
                    end
                    say("Run 'lblook list <category>' for the full names in one, or 'lblook list all' for everything.")
                    return true
                end
                local shown = 0
                for _, cat in ipairs(LBLOOK_CATEGORIES) do
                    if which == "all" or which == cat.key then
                        say(cat.label .. " (" .. #cat.entries .. "):")
                        for _, entryName in ipairs(cat.entries) do say("  " .. entryName) end
                        shown = shown + 1
                    end
                end
                if shown == 0 then
                    say("Unknown category '" .. Parameters[2] .. "'. Run 'lblook list' to see valid categories.")
                end
                return true
            end
            -- Multi-word names ("Buccaneers Musketeer") arrive as separate Parameters entries
            -- (console argument splitting is space-delimited, same as every other command here) --
            -- rejoin them so a name with spaces can be typed without needing quotes to work.
            local name = table.concat(Parameters, " ")
            -- Tried in the same order as LBLOOK_CATEGORIES above (first match wins) -- covers
            -- every named recipe LivingBase's own placement keys can produce (2026-08-13, full
            -- coverage pass: townsman/statues/decor added alongside crew/senka/women/livestock).
            local order = {
                { fn = Testbed.SpawnCrewByName,          via = "crew" },
                { fn = Testbed.SpawnWalkerByName,        via = "townsman" },
                { fn = Testbed.SpawnStandingByName,      via = "standing statue" },
                { fn = Testbed.SpawnSeatedByName,        via = "floor sitter" },
                { fn = Testbed.SpawnChairByName,         via = "chair/stool sitter" },
                { fn = Testbed.SpawnInteractiveByName,   via = "interactive statue" },
                { fn = Testbed.SpawnSenkaByKey,          via = "Senkamati" },
                { fn = Testbed.SpawnLivestockByName,     via = "livestock" },
                { fn = Testbed.SpawnFemaleWalkerByName,  via = "walking woman" },
                { fn = Testbed.SpawnBarbieByName,        via = "Barbie" },
                { fn = Testbed.SpawnDecorByName,         via = "decor" },
            }
            local actor, reason, via
            for _, entry in ipairs(order) do
                actor, reason = entry.fn(name)
                if actor then via = entry.via; break end
            end
            if actor and actor ~= false and (type(actor) ~= "userdata" or actor:IsValid()) then
                say("Spawned (" .. via .. "): " .. name)
            else
                say("No named look matched '" .. name .. "' in crew, townsman, statues, Senkamati, "
                    .. "livestock, walking-women, or decor -- run 'lblook list' to browse, check "
                    .. "DISPLAY_NAMES.md for the exact current identifiers, or use lbspawn for a raw class.")
            end
            return true
        end)
    end)
    log("Console command registered: lblook <name>")
    registerCmdInfo("lblook", "lblook <name>", "Spawn one specific named look/character (e.g. Letty, Marita, a Senkamati row) directly, without stepping through its roster cycle key.")
else
    log("lblook unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbsexchange" (2026-08-15) -- grew out of the ApplyBodySex investigation
-- (CLAUDE.md item 64): comp:SetCharacterSex() is a genuine engine function that actually
-- re-renders post-build, unlike the confirmed-dead ColorParams/ArchetypePreset property writes --
-- an interesting enough capability to keep as a real feature instead of throwaway dev scaffolding.
-- Acts on the nearest SPAWNED actor in front of you (same target-lock-aware picker despawn/cycle/
-- live-edit already share -- RedFalcon: "it only has to work on spawned ones", not arbitrary wild
-- NPCs), not the dev-only HOME probe target the old F6 test key used. Checks
-- IsBodySexChangeAvailable() before attempting anything, per RedFalcon's explicit spec, and
-- reports exactly one of two outcomes. See Spawner.ApplySexChangeToNearest's own comment for the
-- full mechanism. Deliberately NOT documented in README/NEXUS docs (RedFalcon: results could be
-- NSFW) -- console-only, undiscoverable unless you already know the command name.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbsexchange", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbsexchange] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.ApplySexChangeToNearest(say) end)
            if not ok then say("lbsexchange FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbsexchange")
    registerCmdInfo("lbsexchange", "lbsexchange", "Swap the nearest spawned actor's body sex, if IsBodySexChangeAvailable() allows it for that class.")
else
    log("lbsexchange unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestswapbodysex" (2026-08-19) -- THROWAWAY DEV TEST, see
-- Spawner.TestSwapBodySex's own comment. Answers whether SwapBodySex (found via lbprobedump's
-- function listing) can change sex on an actor lbsexchange refuses (IsBodySexChangeAvailable()
-- false). Deliberately NOT documented in README/NEXUS docs, same reasoning as lbsexchange.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestswapbodysex", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestswapbodysex] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.TestSwapBodySex(say) end)
            if not ok then say("lbtestswapbodysex FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestswapbodysex")
    registerCmdInfo("lbtestswapbodysex", "lbtestswapbodysex", "THROWAWAY DEV TEST: tries the SwapBodySex function directly, bypassing the availability gate lbsexchange respects.")
else
    log("lbtestswapbodysex unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestparamswap" (2026-08-19) -- THROWAWAY DEV TEST. RedFalcon asked whether an
-- ALREADY-SPAWNED actor with an empty slot (e.g. the Gatherer, no Headgear entry in
-- BuildedCompositeMeshes) could have a piece added live, instead of needing to respawn with
-- different composite params -- which is how every reskin in this mod has worked so far. Turns out
-- this was ALREADY answered: Spawner.ApplyComposite's own dead-end note (right above
-- Spawner.ApplyBodySex, spawner.lua) says its `paramsPath` argument (== DefaultParams, the outfit)
-- is "the proven, working half" post-build -- only `archetypePath` (body/skin/hair) was ever
-- confirmed dead. ApplyComposite itself was never wired to a console command though (only ever
-- called from other dev-test code), so this is just that missing wrapper -- targets whatever
-- lbprobe last aimed at, same as lbtestswapbodysex. Full /Game/... path required (no short-name
-- index for composite-params DataAssets), e.g. the Buccaneers Merchant 01's own DefaultParams:
-- /Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/CompositeMesh/Merchant/
-- DA_NPC_AnimatedActor_Buccaneers_Merchant_01_CompositeMeshComponentParams.
-- DA_NPC_AnimatedActor_Buccaneers_Merchant_01_CompositeMeshComponentParams
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestparamswap", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestparamswap] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local paramsPath = Parameters and Parameters[1]
            if not paramsPath then
                say("Usage: lbtestparamswap <full /Game/... DefaultParams DataAsset path> -- run lbprobe on a target first.")
                return true
            end
            local actor = Spawner._lastProbedActor
            if not (actor and actor:IsValid()) then
                say("No valid probed target -- run lbprobe on something first.")
                return true
            end
            local ok, err = pcall(function() Spawner.ApplyComposite(actor, paramsPath) end)
            if not ok then say("lbtestparamswap FAILED: " .. tostring(err)) end
            say("Done -- see ue4ss.log ([LivingBase:Composite] lines) for the before/after readback.")
            return true
        end)
    end)
    log("Console command registered: lbtestparamswap")
    registerCmdInfo("lbtestparamswap", "lbtestparamswap", "THROWAWAY DEV TEST: swaps a composite-params DataAsset on the nearest actor post-build, to probe whether outfit changes actually re-render.")
else
    log("lbtestparamswap unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestparamswap2" (2026-08-19) -- THROWAWAY DEV TEST, second variant. See
-- Spawner.ApplyCompositeOrdered's own comment: lbtestparamswap's first attempt left
-- BuildedCompositeMeshes unchanged (5 -> 5, no actual rebuild) even though the DefaultParams
-- property write itself landed -- this wraps the write+rebuild INSIDE the StartCharacterEdit/
-- EndCharacterEdit session instead of firing the rebuild before the session opens, to see if call
-- ORDER was the reason nothing rebuilt. Same targeting/usage shape as lbtestparamswap.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestparamswap2", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestparamswap2] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local paramsPath = Parameters and Parameters[1]
            if not paramsPath then
                say("Usage: lbtestparamswap2 <full /Game/... DefaultParams DataAsset path> -- run lbprobe on a target first.")
                return true
            end
            local actor = Spawner._lastProbedActor
            if not (actor and actor:IsValid()) then
                say("No valid probed target -- run lbprobe on something first.")
                return true
            end
            local ok, err = pcall(function() Spawner.ApplyCompositeOrdered(actor, paramsPath, say) end)
            if not ok then say("lbtestparamswap2 FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestparamswap2")
    registerCmdInfo("lbtestparamswap2", "lbtestparamswap2", "Variant of lbtestparamswap -- wraps the write+rebuild inside the Start/EndCharacterEdit session instead of before it, testing whether call order matters.")
else
    log("lbtestparamswap2 unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestprebuildparams" (2026-08-19) -- THROWAWAY DEV TEST. lbtestparamswap/
-- lbtestparamswap2 both confirmed POST-build DefaultParams swapping is dead (BuildedCompositeMeshes
-- never rebuilds on an already-spawned actor, see Spawner.ApplyCompositeOrdered's own dead-end
-- note). This is the control test done the RIGHT way: spawns a BRAND NEW actor with the override
-- DefaultParams set in the pre-build deferred window -- the exact same compositeLook.params
-- mechanism Spawner.SetCompositeParams already runs safely dozens of times a session (Senkamati/
-- Warrior cross-skeleton reskins, every crew/townsfolk look) -- no new engine surface, no new
-- crash risk. Answers: does a cross-class DefaultParams override (e.g. Gatherer body + Buccaneers
-- Merchant outfit) actually render correctly when set at the only time this component reads it, or
-- does the cross-skeleton/cross-archetype mismatch block it regardless of timing? Same ShortName|
-- ClassPath resolution as lbspawn. Spawns as a plain (non-friendly) raw validation spawn, same as
-- lbspawn -- not tracked into any roster.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestprebuildparams", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestprebuildparams] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local input = Parameters and Parameters[1]
            local paramsPath = Parameters and Parameters[2]
            if not (input and paramsPath) then
                say("Usage: lbtestprebuildparams <ShortName|ClassPath> <full /Game/... DefaultParams DataAsset path>")
                say("  e.g. lbtestprebuildparams BP_NPC_Handyman_Gatherer /Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/CompositeMesh/Merchant/DA_NPC_AnimatedActor_Buccaneers_Merchant_01_CompositeMeshComponentParams.DA_NPC_AnimatedActor_Buccaneers_Merchant_01_CompositeMeshComponentParams")
                return true
            end
            local classPath = input
            if not input:match("^/") then
                classPath = ClassIndex[input] or ClassIndexLower[input:lower()]
                if not classPath then
                    say("Unknown short name: " .. input .. " (pass the full /Game/... path instead)")
                    return true
                end
            end
            local ok, actor = pcall(function()
                return Spawner.Spawn(classPath, "PrebuildParamsTest_" .. input, nil, nil, nil, nil, false,
                    { params = paramsPath })
            end)
            if ok and actor and actor:IsValid() then
                say("Spawned " .. input .. " with DefaultParams override -- check BuildedCompositeMeshes via lbprobe+lbprobedump.")
            else
                say("FAILED to spawn: " .. classPath .. " (see ue4ss.log SPAWN FAILED / [LivingBase:Composite] lines)")
            end
            return true
        end)
    end)
    log("Console command registered: lbtestprebuildparams")
    registerCmdInfo("lbtestprebuildparams", "lbtestprebuildparams", "THROWAWAY DEV TEST: sets composite params PRE-build (the only time this component reliably reads them) on a raw validation spawn.")
else
    log("lbtestprebuildparams unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbcustomnpc" (2026-08-19) -- DEV TOOL, see Spawner.ListCustomizationControllers/
-- Spawner.SetCustomizationController's own comments. General-purpose replacement for the earlier
-- throwaway lbtestsethair -- RedFalcon asked for a proper get/set pair to explore the
-- GetCustomizationMeshControllers/SetCustomizationMeshControllerValue system on whatever's
-- currently probed (lbprobe first), not just the Hairs slot. `lbcustomnpc get` lists every
-- controller (category/current/options/selectable); `lbcustomnpc set <category|index> <value>`
-- writes one, matched by category name (exact or a case-insensitive suffix after
-- "Customization.UID.", e.g. "hairs") or by plain MeshGroupIndex for a controller with no usable
-- tag. Not documented in README/NEXUS docs, same as every other dev probe/test command.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbcustomnpc", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbcustomnpc] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local function usage()
                say("Usage: lbcustomnpc get")
                say("       lbcustomnpc set <category|index> <value>   e.g. lbcustomnpc set hairs 5")
            end
            local sub = Parameters and Parameters[1] and Parameters[1]:lower()
            local ok, err
            if sub == "get" then
                ok, err = pcall(function() Spawner.ListCustomizationControllers(say) end)
            elseif sub == "set" then
                local which, newValue = Parameters[2], Parameters[3]
                if not (which and newValue) then
                    usage()
                    return true
                end
                ok, err = pcall(function() Spawner.SetCustomizationController(Spawner._lastProbedActor, which, newValue, say) end)
            else
                usage()
                return true
            end
            if not ok then say("lbcustomnpc FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbcustomnpc")
    registerCmdInfo("lbcustomnpc", "lbcustomnpc [list|set <category|index> <value>]", "Lists (or sets) a probed actor's customization controllers (hair/armor/facial slots, etc.) by category name or index.")
else
    log("lbcustomnpc unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobeclass" (2026-08-19) -- DEV TOOL, see Spawner.ProbeClassCustomization's
-- own comment. Reads a class's customization controllers straight off its Class Default Object --
-- NO SpawnActor call -- to test whether the Armor.*/Facial.*/Hairs breakdown can be surveyed across
-- the roster without loading every actor into the world. Same ShortName|ClassPath resolution as
-- lbspawn (reuses the same class_index.lua lookup), since this is the "read-only, no spawn" sibling
-- of that command.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobeclass", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbprobeclass] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local input = Parameters and Parameters[1]
            if not input then
                say("Usage: lbprobeclass <ShortName|ClassPath>  e.g. lbprobeclass BP_AnimatedActor_TortugaCitizen_Combatant_CrossHands")
                return true
            end
            local classPath = input
            if not input:match("^/") then
                classPath = ClassIndex[input] or ClassIndexLower[input:lower()]
                if not classPath then
                    say("Unknown short name: " .. input .. " (not in the index of 2,562 known BP_ classes"
                        .. " -- check spelling, run 'lbspawn list' to browse LivingBase's own roster,"
                        .. " or pass the full /Game/... path instead)")
                    return true
                end
            end
            local ok, err = pcall(function() Spawner.ProbeClassCustomization(classPath, say) end)
            if not ok then say("lbprobeclass FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbprobeclass")
    registerCmdInfo("lbprobeclass", "lbprobeclass", "Read-only: surveys a class's own Armor/Facial/Hairs controller breakdown WITHOUT spawning it into the world.")
else
    log("lbprobeclass unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbcustomscan" (2026-08-19) -- DEV TOOL, see Spawner.ScanNearbyCustomization's
-- own comment. lbprobeclass's CDO route proved a dead end for pawn classes (controller list is only
-- built at spawn time), so this is the practical fallback: place a handful of actors (lbspawn/
-- lblook, or just use whatever's already wandering nearby), run this once, and every NEW class
-- within range gets its full controller breakdown + sex/body/customizable flags appended to
-- customization_survey.jsonl -- already-recorded classes are skipped automatically, so repeated runs
-- after placing more actors and despawning the old ones only grow the file, never duplicate it.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbcustomscan", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbcustomscan] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local radius = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.ScanNearbyCustomization(radius, say) end)
            if not ok then say("lbcustomscan FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbcustomscan")
    registerCmdInfo("lbcustomscan", "lbcustomscan", "Scans nearby actors and appends each NEW class's full customization-controller breakdown to customization_survey.jsonl (already-recorded classes are skipped).")
else
    log("lbcustomscan unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbdecorloot" (2026-08-17) -- converts the dropped item (R5LootActor) nearest in
-- front of you into inert decoration: no longer pickable, no longer physically tossable, sparkle
-- turned off. Acts on a WILD world actor, never one LivingBase spawned, so this can't reuse the
-- spawned-only nearest-in-front picker lbsexchange/despawn/cycle share -- see
-- Spawner.MakeLootDecorNearest's own comment for the FindAllOf("R5LootActor") sweep this uses
-- instead. Same say()/Ar:Log() dual-output shape as every other console command in this file.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbdecorloot", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbdecorloot] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.MakeLootDecorNearest(say) end)
            if not ok then say("lbdecorloot FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbdecorloot")
    registerCmdInfo("lbdecorloot", "lbdecorloot", "Turns the nearest WILD native loot actor into a static decor look.")
else
    log("lbdecorloot unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobestone" (2026-08-17) -- TEMP DEV TOOL, see Spawner.ProbeStoneItemMesh's
-- own comment. Read-only diagnostic for the "make a fresh inventoryDrops spawn actually show a
-- mesh" follow-up -- prints whatever the Stone item's ItemMesh SoftObjectProperty actually is.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobestone", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ProbeStoneItemMesh() end)
            if not ok then print("[LivingBase] [lbprobestone] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobestone")
    registerCmdInfo("lbprobestone", "lbprobestone", "TEMP DEV TOOL: prints a Stone resource item's ItemMesh reference, for the 'give inventoryDrops spawns a real mesh' investigation.")
else
    log("lbprobestone unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobeinteract" (2026-08-21) -- TEMP DEV TOOL, see
-- Spawner.ProbeInteractionTargetParams' own comment. Read-only diagnostic dumping
-- DA_InteractionTarget_Loot/Crop's declared properties, to see if the game's own native
-- interaction-highlight system references a reusable effect we could spawn instead of our
-- material-swap ghost highlight.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobeinteract", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ProbeInteractionTargetParams() end)
            if not ok then print("[LivingBase] [lbprobeinteract] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobeinteract")
    registerCmdInfo("lbprobeinteract", "lbprobeinteract", "TEMP DEV TOOL: dumps DA_InteractionTarget_Loot/Crop's declared properties, looking for a reusable native highlight effect.")
else
    log("lbprobeinteract unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobesparkle" (2026-08-21) -- TEMP DEV TOOL, see Spawner.ProbeLootSparkle's own
-- comment. Read-only diagnostic: drop any item, face it, run this -- prints the NiagaraSystem asset
-- reference behind the native "lootable" sparkle, a candidate reusable effect for targeting statues.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobesparkle", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbprobesparkle] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.ProbeLootSparkle(say) end)
            if not ok then say("lbprobesparkle FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbprobesparkle")
    registerCmdInfo("lbprobesparkle", "lbprobesparkle", "TEMP DEV TOOL: aim at a dropped item and run this to print the NiagaraSystem behind the native lootable sparkle effect.")
else
    log("lbprobesparkle unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobechestfx" (2026-08-21) -- TEMP DEV TOOL, see Spawner.ProbeChestFX's own
-- comment. Read-only diagnostic: run lbprobe on a chest POI first, then this -- dumps
-- DA_ChestFXParams and the live SpawnedChestVFX NiagaraComponent's Asset reference.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobechestfx", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ProbeChestFX() end)
            if not ok then print("[LivingBase] [lbprobechestfx] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobechestfx")
    registerCmdInfo("lbprobechestfx", "lbprobechestfx", "TEMP DEV TOOL: aim (lbprobe) at a chest POI first, then run this to dump its FX params and live VFX component asset.")
else
    log("lbprobechestfx unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobeksl" (2026-08-24) -- TEMP DEV TOOL, see Spawner.ProbeKSLTraceFunctions'
-- own comment. Read-only diagnostic: lists every KismetSystemLibrary function whose name contains
-- "Trace" or "Object", so the real object-type-trace function name can be read directly instead of
-- guessed again (LineTraceSingleByObjectType, the first guess, confirmed live NOT to exist as
-- called).
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobeksl", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ProbeKSLTraceFunctions() end)
            if not ok then print("[LivingBase] [lbprobeksl] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobeksl")
    registerCmdInfo("lbprobeksl", "lbprobeksl", "Dumps KismetSystemLibrary's full function list, to find a real UFUNCTION name instead of guessing one.")
else
    log("lbprobeksl unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobeniagarafuncs" (2026-08-21) -- TEMP DEV TOOL, see
-- Spawner.ProbeNiagaraFunctions' own comment. Read-only diagnostic: lists every function
-- UNiagaraFunctionLibrary declares, so we know the real spawn-attached function name/signature in
-- this UE version before attempting to call it.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobeniagarafuncs", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ProbeNiagaraFunctions() end)
            if not ok then print("[LivingBase] [lbprobeniagarafuncs] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobeniagarafuncs")
    registerCmdInfo("lbprobeniagarafuncs", "lbprobeniagarafuncs", "Dumps the Niagara-related function list available on a component, for building FX-spawning code.")
else
    log("lbprobeniagarafuncs unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobeniagarasig" (2026-08-21) -- TEMP DEV TOOL, see
-- Spawner.ProbeNiagaraSpawnAttachedSignature's own comment. Read-only diagnostic: dumps
-- SpawnSystemAttached's actual parameter list/types so it can be called correctly, not guessed.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobeniagarasig", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ProbeNiagaraSpawnAttachedSignature() end)
            if not ok then print("[LivingBase] [lbprobeniagarasig] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobeniagarasig")
    registerCmdInfo("lbprobeniagarasig", "lbprobeniagarasig", "Probes a specific Niagara-related function's parameter signature.")
else
    log("lbprobeniagarasig unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console commands "lbtestniagara"/"lbtestniagaraclear" (2026-08-21) -- TEMP DEV TOOL, see
-- Spawner.TestSpawnNiagara's own comment. First live test of spawning/attaching the confirmed
-- FX_PickUP_Chest_01 NiagaraSystem onto whatever lbprobe last cached. Manual on/off, NOT wired into
-- the real hover-highlight flow yet.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestniagara", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.TestSpawnNiagara() end)
            if not ok then print("[LivingBase] [lbtestniagara] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestniagara")
    registerCmdInfo("lbtestniagara", "lbtestniagara", "Spawns a hardcoded test Niagara effect for a quick visual check.")
    pcall(function()
        RegisterConsoleCommandHandler("lbtestniagaraclear", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.TestSpawnNiagaraClear() end)
            if not ok then print("[LivingBase] [lbtestniagaraclear] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestniagaraclear")
    registerCmdInfo("lbtestniagaraclear", "lbtestniagaraclear", "Clears/despawns the effect lbtestniagara spawned.")
else
    log("lbtestniagara/lbtestniagaraclear unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobecpd" (2026-08-21) -- TEMP DEV TOOL, see Spawner.ProbeCustomPrimitiveData's
-- own comment. Read-only diagnostic: checks whether PrimitiveComponent exposes Custom Primitive Data
-- functions in this build, and (if lbprobe cached something) dumps its current values.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobecpd", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ProbeCustomPrimitiveData() end)
            if not ok then print("[LivingBase] [lbprobecpd] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobecpd")
    registerCmdInfo("lbprobecpd", "lbprobecpd", "Probes composite-params-data (CPD) related properties on a target.")
else
    log("lbprobecpd unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobecpdsig" (2026-08-21) -- TEMP DEV TOOL, see Spawner.ProbeCPDIndexSignature's
-- own comment. Read-only diagnostic: dumps the parameter list for the CPD index-lookup functions.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobecpdsig", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ProbeCPDIndexSignature() end)
            if not ok then print("[LivingBase] [lbprobecpdsig] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobecpdsig")
    registerCmdInfo("lbprobecpdsig", "lbprobecpdsig", "Probes a CPD-related function's parameter signature.")
else
    log("lbprobecpdsig unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobecpdnames" (2026-08-21) -- TEMP DEV TOOL, see Spawner.ProbeCPDNames' own
-- comment. Pure read-only query, low risk: run lbprobe on a chest/statue/decor first, then this --
-- tries a batch of plausible tint/highlight parameter names and prints which ones (if any) resolve
-- to a real Custom Primitive Data index on that target's material.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobecpdnames", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ProbeCPDNames() end)
            if not ok then print("[LivingBase] [lbprobecpdnames] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobecpdnames")
    registerCmdInfo("lbprobecpdnames", "lbprobecpdnames", "Dumps CPD-related property/function names for discovery.")
else
    log("lbprobecpdnames unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console commands "lbtestniagaraactor"/"lbtestniagaraactorclear" (2026-08-21) -- TEMP DEV TOOL, see
-- Spawner.TestSpawnNiagaraActor's own comment. Spawns a stock NiagaraActor at the probed target's
-- location instead of calling either of the two functions that already crashed the game today --
-- uses only the proven-safe actor-spawn helper plus plain property read/write.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestniagaraactor", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.TestSpawnNiagaraActor() end)
            if not ok then print("[LivingBase] [lbtestniagaraactor] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestniagaraactor")
    registerCmdInfo("lbtestniagaraactor", "lbtestniagaraactor", "Spawns a test Niagara effect as its own actor (rather than a bare component), for a different attach/lifetime shape.")
    pcall(function()
        RegisterConsoleCommandHandler("lbtestniagaraactorclear", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.TestSpawnNiagaraActorClear() end)
            if not ok then print("[LivingBase] [lbtestniagaraactorclear] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestniagaraactorclear")
    registerCmdInfo("lbtestniagaraactorclear", "lbtestniagaraactorclear", "Clears/despawns the actor lbtestniagaraactor spawned.")
else
    log("lbtestniagaraactor/lbtestniagaraactorclear unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestniagaracycle" (2026-08-21) -- TEMP DEV TOOL, see
-- Spawner.CycleTestNiagaraEffect's own comment. Destroys and respawns the test actor with the next
-- candidate effect from the pak-listing search each time -- run it repeatedly to compare options.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestniagaracycle", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.CycleTestNiagaraEffect() end)
            if not ok then print("[LivingBase] [lbtestniagaracycle] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestniagaracycle")
    registerCmdInfo("lbtestniagaracycle", "lbtestniagaracycle", "Cycles through a small roster of test Niagara effects on the same target.")
else
    log("lbtestniagaracycle unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestniagarapath <path>" (2026-08-21) -- TEMP DEV TOOL, see
-- Spawner.TestSpawnNiagaraByPath's own comment. Paste any /Game/... asset path found in
-- Other\pakcontents.xlsx (dotted .AssetName suffix optional) to try it live on the last lbprobe'd
-- target, same Parameters[1] argument-reading pattern lbspawn already uses.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestniagarapath", function(FullCommand, Parameters, Ar)
            local arg1 = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestSpawnNiagaraByPath(arg1) end)
            if not ok then print("[LivingBase] [lbtestniagarapath] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestniagarapath")
    registerCmdInfo("lbtestniagarapath", "lbtestniagarapath <path>", "Spawns a specific Niagara effect by its exact /Game/... asset path -- the generic, path-fed FX tester.")
else
    log("lbtestniagarapath unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestpose <path>" (2026-08-25) -- same shape as lbtestniagarapath above, just
-- for animations instead of FX (RedFalcon's own request: "a function ... similar to FX"). See
-- Spawner.TestApplyPoseByPath's own comment. Paste any /Game/... AnimSequence path found in
-- Other\pakcontents.xlsx (dotted .AssetName suffix optional) to try it on the nearest spawned
-- actor in front (or the Num+ locked one).
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestpose", function(FullCommand, Parameters, Ar)
            local arg1 = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestApplyPoseByPath(arg1) end)
            if not ok then print("[LivingBase] [lbtestpose] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestpose <path>")
    registerCmdInfo("lbtestpose", "lbtestpose <path>", "Applies a specific real AnimSequence to the nearest spawned/locked actor via PlayAnimation -- see WINDROSE_MODDING_NOTES.md section 14 for what does and does not work.")
else
    log("lbtestpose unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestmaterial <path>" (2026-08-26) -- same shape as lbtestpose/
-- lbtestniagarapath, for materials instead (RedFalcon: searching pakcontents.xlsx for
-- ghost-material candidates -- M_CharacterGhost_V2, MI_Boneman_Ghost_Pirate, etc. -- found via
-- the "ghost"/"translucent"/"dissolve" keyword sweep). Paste any /Game/... Material or
-- MaterialInstance path (dotted .AssetName suffix optional) to try it on the nearest spawned
-- actor in front (or the Num+ locked one). Same proven-safe SetMaterial swap ApplyGhostMaterial
-- already uses -- no dynamic material instance involved.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestmaterial", function(FullCommand, Parameters, Ar)
            local arg1 = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestApplyMaterialByPath(arg1) end)
            if not ok then print("[LivingBase] [lbtestmaterial] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestmaterial <path>")
    registerCmdInfo("lbtestmaterial", "lbtestmaterial <path>", "Swaps a material onto every mesh component of the nearest spawned/locked actor.")
else
    log("lbtestmaterial unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestmaterial2 <skinPath> <clothPath>" (2026-08-26, RedFalcon: "Skin using
-- MI_Fable_Male_Ghost and clothes using M_CharacterGhost_V2") -- applies one material to the
-- base body/skin mesh and a different one to every composite clothing/armor piece. See
-- Spawner.ApplyTwoMaterialsToActor's own comment for the actor.Mesh-vs-everything-else split.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestmaterial2", function(FullCommand, Parameters, Ar)
            local skinArg = Parameters and Parameters[1]
            local clothArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestApplyTwoMaterialsByPath(skinArg, clothArg) end)
            if not ok then print("[LivingBase] [lbtestmaterial2] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestmaterial2 <skinPath> <clothPath>")
    registerCmdInfo("lbtestmaterial2", "lbtestmaterial2 <skinPath> <clothPath>", "Applies one material to the actor's base body/skin mesh and a different one to every other (clothing/armor) mesh piece.")
else
    log("lbtestmaterial2 unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestposefx <animPath> <fxPath>" (2026-08-25) -- combines lbtestpose +
-- lbtestniagarapath into one call, applied to the SAME target, so there's no manual gap between
-- them (RedFalcon: "otherwise i imagine the effect would be off on its timing"). See
-- Spawner.TestApplyPoseWithFx's own comment for what this does and doesn't solve (station-level
-- FX only, not a hand-socket-attached tool mesh).
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestposefx", function(FullCommand, Parameters, Ar)
            local animArg = Parameters and Parameters[1]
            local fxArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestApplyPoseWithFx(animArg, fxArg) end)
            if not ok then print("[LivingBase] [lbtestposefx] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestposefx <animPath> <fxPath>")
    registerCmdInfo("lbtestposefx", "lbtestposefx <animPath> <fxPath>", "Applies a pose AND a Niagara effect to the same target together, so they land in the same instant instead of two separate manual steps.")
else
    log("lbtestposefx unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtesttool <meshPath> [socket]" (2026-08-25) -- attaches a skeletal mesh prop
-- (e.g. SK_CraftStation_Tools_Hammer_01) to the nearest spawned actor's hand socket, reusing the
-- ALREADY-SHIPPED Spawner.AttachShield mechanism (see Spawner.TestAttachToolToNearest's own
-- comment) rather than anything new/risky. If no candidate socket matches, dumps the actor's full
-- socket list instead so the real name can be read off ue4ss.log.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtesttool", function(FullCommand, Parameters, Ar)
            local meshArg = Parameters and Parameters[1]
            local socketArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestAttachToolToNearest(meshArg, socketArg) end)
            if not ok then print("[LivingBase] [lbtesttool] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtesttool <meshPath> [socket]")
    registerCmdInfo("lbtesttool", "lbtesttool <meshPath> [socket]", "Attaches a skeletal or static mesh prop (e.g. a craft-station tool) to the nearest actor's hand socket.")
else
    log("lbtesttool unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbsockets" (2026-08-28) -- dumps EVERY socket on the nearest/locked actor's
-- Mesh, unconditionally (not just as a last-resort fallback when a guessed candidate fails). Built
-- to answer "what IK/attach sockets actually exist on this skeleton" with real data instead of the
-- scattered guesses/incidental sightings this file had before -- see
-- Spawner.TestDumpSockets's own comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbsockets", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbsockets] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.TestDumpSockets(say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbsockets")
    registerCmdInfo("lbsockets", "lbsockets", "Dumps every socket name on the nearest/locked actor's Mesh (full skeleton attach-point list) to the console and ue4ss.log.")
else
    log("lbsockets unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestarmor <slot/mesh name match> [meshPath]" (2026-08-27) -- swaps a
-- clothing/armor piece's mesh on the nearest spawned actor. Reuses the same swap mechanism
-- Spawner.DeCorrupt already uses everywhere in this mod (match a component's current mesh/name,
-- SetSkeletalMeshAsset/SetSkeletalMesh the replacement) -- see Spawner.TestSwapArmorPiece's own
-- comment. Omit the mesh path to just list the target's pieces matching that name; an unmatched
-- name dumps the target's FULL current piece list instead of failing blind.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestarmor", function(FullCommand, Parameters, Ar)
            local matchArg = Parameters and Parameters[1]
            local meshArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestSwapArmorPiece(matchArg, meshArg) end)
            if not ok then print("[LivingBase] [lbtestarmor] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestarmor <slot/mesh name match> [meshPath]")
    registerCmdInfo("lbtestarmor", "lbtestarmor <slot/mesh name match> [meshPath]", "Swaps a clothing/armor piece's mesh on the nearest actor, matched by slot or current-mesh name; omit the mesh path to just list matching pieces.")
else
    log("lbtestarmor unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestscale <slot/mesh name match> [scaleMul|sx,sy,sz] [offsetZ|ox,oy,oz]" (2026-08-28) --
-- scales/nudges a clothing piece's own component transform on the nearest spawned actor. Exposes
-- Spawner.NudgeComponentTransform's mechanism (built 2026-08-10, EXPERIMENTAL, never wired to a
-- live key/command before now) generically -- see Spawner.TestScaleClothingPiece's own comment.
-- Omit scaleMul/offsetZ to just list the target's pieces matching that name, same discovery-aid
-- shape as lbtestarmor.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestscale", function(FullCommand, Parameters, Ar)
            local matchArg = Parameters and Parameters[1]
            local scaleArg = Parameters and Parameters[2]
            local offsetArg = Parameters and Parameters[3]
            local ok, err = pcall(function() Spawner.TestScaleClothingPiece(matchArg, scaleArg, offsetArg) end)
            if not ok then print("[LivingBase] [lbtestscale] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestscale <slot/mesh name match> [scaleMul|sx,sy,sz] [offsetZ|ox,oy,oz]")
    registerCmdInfo("lbtestscale", "lbtestscale <slot/mesh name match> [scaleMul|sx,sy,sz] [offsetZ|ox,oy,oz]", "Scales and/or nudges a clothing piece's component on the nearest actor -- both scale and offset accept a plain number or a comma-separated per-axis triple; omit both to just list matching pieces.")
else
    log("lbtestscale unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestthickness [value]" (2026-08-28) -- reads/sets ArmorThicknessMorph, a
-- plain float on the nearest actor's AnimInstance. See Spawner.TestArmorThicknessMorph's own
-- comment for why this is a low-risk, already-proven-safe write. Omit the value to just read the
-- current one.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestthickness", function(FullCommand, Parameters, Ar)
            local valueArg = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestArmorThicknessMorph(valueArg) end)
            if not ok then print("[LivingBase] [lbtestthickness] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestthickness [value]")
    registerCmdInfo("lbtestthickness", "lbtestthickness [value]", "Reads (or sets, if a value is given) ArmorThicknessMorph on the nearest actor's AnimInstance -- controls how thick armor renders relative to the body.")
else
    log("lbtestthickness unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbbodymesh" (2026-08-28) -- reports the nearest actor's own body mesh (the
-- SkeletalMeshComponent named "Mesh"), e.g. to check whether a target is the raw Senkamati Witch
-- body or a human "Regular" body without wading through a full lbprobedump.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbbodymesh", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.TestReportBodyMesh() end)
            if not ok then print("[LivingBase] [lbbodymesh] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbbodymesh")
    registerCmdInfo("lbbodymesh", "lbbodymesh", "Reports the nearest/locked actor's own body mesh (short name + full path).")
else
    log("lbbodymesh unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestbodymorph [x] [y] [z]" (2026-08-28) -- reads/sets BodyMorph, a Vector on
-- the nearest actor's AnimInstance that appears to drive per-instance body-shape proportions
-- (found comparing the Merchant vs. Standing woman probe dumps -- see Spawner.TestBodyMorph's own
-- comment). Omit all three to just read the current value.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestbodymorph", function(FullCommand, Parameters, Ar)
            local xArg = Parameters and Parameters[1]
            local yArg = Parameters and Parameters[2]
            local zArg = Parameters and Parameters[3]
            local ok, err = pcall(function() Spawner.TestBodyMorph(xArg, yArg, zArg) end)
            if not ok then print("[LivingBase] [lbtestbodymorph] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestbodymorph [x] [y] [z]")
    registerCmdInfo("lbtestbodymorph", "lbtestbodymorph [x] [y] [z]", "Reads (or sets, if x/y/z are all given) BodyMorph on the nearest actor's AnimInstance -- a per-instance body-shape input, found to differ between actors sharing the same body mesh.")
else
    log("lbtestbodymorph unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console commands "lbtestmorphlist <slot/mesh name match>" and
-- "lbtestmorph <slot/mesh name match> <morphName> <value>" (2026-08-28) -- discover/set morph
-- targets baked into a clothing piece's OWN mesh, as an alternative to whole-component scaling
-- (lbtestscale). See Spawner.TestListMorphTargets' own comment -- genuinely unconfirmed whether
-- these clothing meshes have any morph targets at all; this is the tool to find out.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestmorphlist", function(FullCommand, Parameters, Ar)
            local matchArg = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestListMorphTargets(matchArg) end)
            if not ok then print("[LivingBase] [lbtestmorphlist] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestmorphlist <slot/mesh name match>")
    registerCmdInfo("lbtestmorphlist", "lbtestmorphlist <slot/mesh name match>", "Lists the morph target names available on a matched clothing piece's mesh (if any).")
else
    log("lbtestmorphlist unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestmorph", function(FullCommand, Parameters, Ar)
            local matchArg = Parameters and Parameters[1]
            local morphArg = Parameters and Parameters[2]
            local valueArg = Parameters and Parameters[3]
            local ok, err = pcall(function() Spawner.TestSetMorphTarget(matchArg, morphArg, valueArg) end)
            if not ok then print("[LivingBase] [lbtestmorph] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestmorph <slot/mesh name match> <morphName> <value>")
    registerCmdInfo("lbtestmorph", "lbtestmorph <slot/mesh name match> <morphName> <value>", "Sets a named morph target's weight on a matched clothing piece -- run lbtestmorphlist first to find real morph names.")
else
    log("lbtestmorph unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestclothassets <slot/mesh name match>" (2026-08-28) -- checks whether a
-- matched clothing piece has a bound Chaos Cloth simulation asset, as opposed to plain bone
-- skinning or morph targets. See Spawner.TestListClothAssets' own comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestclothassets", function(FullCommand, Parameters, Ar)
            local matchArg = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestListClothAssets(matchArg) end)
            if not ok then print("[LivingBase] [lbtestclothassets] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestclothassets <slot/mesh name match>")
    registerCmdInfo("lbtestclothassets", "lbtestclothassets <slot/mesh name match>", "Checks whether a matched clothing piece's mesh has a bound Chaos Cloth simulation asset (dynamic cloth deformation, distinct from morph targets/plain skinning).")
else
    log("lbtestclothassets unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestskin <family>" (2026-08-28) -- swaps a skin-tone family onto the nearest
-- spawned actor. Reuses Spawner.DeCorrupt via Config.SkinFamilySwapRules/CorruptedSkinSwapRules --
-- see Spawner.TestApplySkinFamily's own comment for the sex auto-detection this one needs.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestskin", function(FullCommand, Parameters, Ar)
            local familyArg = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestApplySkinFamily(familyArg) end)
            if not ok then print("[LivingBase] [lbtestskin] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestskin <family>")
    registerCmdInfo("lbtestskin", "lbtestskin <family>", "Swaps a skin-tone family (Adventurer/African/Albion/Fable/Native/Orient/Scum/Corrupted) onto the nearest actor, auto-detecting its sex.")
else
    log("lbtestskin unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtesthair <style> [variant]" (2026-08-28, `variant` added same day once
-- Config.CUSTOM_HAIR grew a 3rd/4th variant per style -- see that table's own comment) -- swaps a
-- hairstyle onto the nearest spawned actor. Reuses Spawner.DeCorrupt via a plain "Hair_" replace
-- rule -- see Spawner.TestApplyHairStyle's own comment for the sex auto-detection this one needs
-- too. variant defaults to "Default" (no headwear) if omitted.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtesthair", function(FullCommand, Parameters, Ar)
            local styleArg = Parameters and Parameters[1]
            local variantArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestApplyHairStyle(styleArg, variantArg) end)
            if not ok then print("[LivingBase] [lbtesthair] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtesthair <style> [Default|Hat|Headband|Bandana]")
    registerCmdInfo("lbtesthair", "lbtesthair <style> [Default|Hat|Headband|Bandana]", "Swaps a hairstyle (see Config.CUSTOM_HAIR for the full list) onto the nearest actor, auto-detecting its sex.")
else
    log("lbtesthair unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestdecor <param> [texturePath]" (2026-08-28) -- explores the 4 real
-- SkinDecor texture parameters found on a composite skin material (FaceDecor/BodyDecor/
-- "SkinDecor ID"/SkinAging -- see Spawner.TestSetSkinDecor's own header comment for how these
-- were found, on Marita). GENUINELY RISKY: requires wrapping the target's shared skin material in
-- a fresh dynamic material instance, an operation whose Kismet-library equivalent already
-- crashed this game once this session on a different character mesh -- see that same comment
-- before using this on anything you can't afford to lose.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestdecor", function(FullCommand, Parameters, Ar)
            local paramArg = Parameters and Parameters[1]
            local texArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestSetSkinDecor(paramArg, texArg) end)
            if not ok then print("[LivingBase] [lbtestdecor] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestdecor <param> [texturePath]")
    registerCmdInfo("lbtestdecor", "lbtestdecor <FaceDecor|BodyDecor|\"SkinDecor ID\"|SkinAging> [texturePath]", "RISKY: sets one of the 4 SkinDecor texture parameters (makeup/tattoo layer) on the nearest actor's skin material via a dynamic material instance.")
else
    log("lbtestdecor unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestclothes <family> <slot> <name> [sex override: M/F]" (2026-08-28) -- swaps
-- a clothing/armor piece onto the nearest spawned actor. See Spawner.TestApplyClothingPiece's own
-- comment for the slot-detection this needs (finds the current component by SLOT, not by the new
-- piece's family naming convention, avoiding the exact bug class item 89's Undercut hairstyle
-- exposed). Optional 4th arg (added same day, RedFalcon: "is there a command to see how the male
-- version of clothes fit on her?") forces which sex-path a sex-split row resolves to, instead of
-- the target's own detected sex -- e.g. `lbtestclothes Jeweler Torso "Set 1" Male` on a female
-- target.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestclothes", function(FullCommand, Parameters, Ar)
            local familyArg = Parameters and Parameters[1]
            local slotArg = Parameters and Parameters[2]
            local nameArg = Parameters and Parameters[3]
            local sexArg = Parameters and Parameters[4]
            local ok, err = pcall(function() Spawner.TestApplyClothingPiece(familyArg, slotArg, nameArg, sexArg) end)
            if not ok then print("[LivingBase] [lbtestclothes] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestclothes <family> <slot> <name> [sex override: M/F]")
    registerCmdInfo("lbtestclothes", "lbtestclothes <family> <slot> <name> [sex override: M/F]", "Swaps a clothing/armor piece (see Config.CUSTOM_CLOTHES for the full list) onto the nearest actor. Auto-detects sex by default; pass M or F to force which sex-path a sex-split piece uses.")
else
    log("lbtestclothes unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbremoveclothes <slot|all>" (2026-08-28) -- hides a clothing piece by slot (or
-- everything) on the nearest actor. See Spawner.TestRemoveClothingPiece's own comment for why this
-- HIDES rather than clears the mesh, and see Config.CLOTHING_REMOVABLE_SLOTS for the slot list.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbremoveclothes", function(FullCommand, Parameters, Ar)
            local slotArg = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestRemoveClothingPiece(slotArg) end)
            if not ok then print("[LivingBase] [lbremoveclothes] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbremoveclothes <slot|all>")
    registerCmdInfo("lbremoveclothes", "lbremoveclothes <slot|all>", "Hides a clothing/armor piece in the given slot (or every recognized slot, with 'all') on the nearest actor -- see Config.CLOTHING_REMOVABLE_SLOTS.")
else
    log("lbremoveclothes unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestaddslot <slot> <meshPath>" (2026-08-28) -- standalone test for building a
-- MISSING clothing component from scratch (e.g. a Sailor that spawned with no Torso at all) via
-- AddComponentByClass + SetLeaderPoseComponent, rather than the only existing fix (despawn/reroll
-- until the composite happens to include one). GENUINELY NEW ENGINE SURFACE -- see
-- Spawner.TestAddMissingClothingSlot's own header comment before trusting this on anything you
-- can't afford to lose.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestaddslot", function(FullCommand, Parameters, Ar)
            local slotArg = Parameters and Parameters[1]
            local meshArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestAddMissingClothingSlot(slotArg, meshArg) end)
            if not ok then print("[LivingBase] [lbtestaddslot] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestaddslot <slot> <meshPath>")
    registerCmdInfo("lbtestaddslot", "lbtestaddslot <slot> <meshPath>", "RISKY/EXPERIMENTAL: builds a missing clothing component from scratch (for a slot the composite roll never created) via AddComponentByClass + SetLeaderPoseComponent.")
else
    log("lbtestaddslot unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestgroup <slot> <family> <name>" (2026-08-29) -- the item-111 custom-outfit
-- experiment: swaps ONE slot on Marita's own real outfit for a different catalog family's piece,
-- by constructing a brand-new R5CompositeMeshGroup and a duplicated+patched params asset, then
-- spawning a fresh actor with it. GENUINELY NEW ENGINE SURFACE, more of it than anything tried
-- this session (StaticConstructObject on a new class, a TArray-of-object-references write,
-- DuplicateObject -- all three previously untried in this codebase). See
-- Spawner.TestBuildCustomOutfit's own header comment IN FULL before running this on anything you
-- can't afford to lose -- every risky call logs a breadcrumb to LivingBase_ReferenceLog.txt
-- immediately before it runs, so a crash still leaves a trace of exactly which call did it.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestgroup", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestgroup] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local slotArg = Parameters and Parameters[1]
            local familyArg = Parameters and Parameters[2]
            local nameArg = Parameters and Parameters[3]
            local ok, err = pcall(function() Spawner.TestBuildCustomOutfit(slotArg, familyArg, nameArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestgroup <slot> <family> <name>")
    registerCmdInfo("lbtestgroup", "lbtestgroup <slot> <family> <name>", "HIGH-RISK/EXPERIMENTAL: constructs a custom R5CompositeMeshGroup swapping one slot of Marita's outfit for a different family's piece, then spawns a test actor with it.")
else
    log("lbtestgroup unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestcopyparams" (2026-08-29) -- diagnostic for lbtestgroup: after two
-- confirmed-clean runs (no crash, GameplayTag copy worked, verification passed) still produced a
-- fully nude spawn (0 BuildedCompositeMeshes), this checks whether a freshly StaticConstructObject'd
-- BaseParams can build AT ALL by copying Marita's entire real CustomizationData array onto it
-- wholesale, bypassing all of lbtestgroup's own from-scratch Group construction. See
-- Spawner.TestCopyWholeParams's own header comment for what each outcome would mean.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestcopyparams", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestcopyparams] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.TestCopyWholeParams(say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestcopyparams")
    registerCmdInfo("lbtestcopyparams", "lbtestcopyparams", "DIAGNOSTIC: spawns a test actor whose fresh BaseParams' CustomizationData is a wholesale copy of Marita's own real one -- checks whether a StaticConstructObject-based BaseParams can build at all.")
else
    log("lbtestcopyparams unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestpak [path]" (2026-08-29) -- tests the offline-asset-editing route
-- (retoc + UAssetGUI, see Spawner.TestSpawnWithCustomParamsPath's own header comment): loads a
-- REAL DataAsset built outside the game and packed into R5/Content/Paks/LivingBaseCustomTest/,
-- via the exact same compositeLook.params pre-build swap already proven safe elsewhere in this
-- mod -- zero runtime construction, zero crash risk.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestpak", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestpak] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local pathArg = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestSpawnWithCustomParamsPath(pathArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestpak [path]")
    registerCmdInfo("lbtestpak", "lbtestpak [path]", "Spawns a test actor using a REAL custom DataAsset built via retoc+UAssetGUI and packed as a content mod -- defaults to the Marita-Group-with-Jeweler-Torso test asset if no path given.")
else
    log("lbtestpak unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestlook <paramsPath> <archetypePath>" (2026-08-31) -- the decisive combined
-- test: does Config.SENKA_FEMALE_BASE_CLASS (confirmed via 4 live probes to have a completely
-- stable, non-randomized ArchetypePreset by default) actually respect a pre-build archetype
-- override, combined with our own proven custom outfit? See Spawner.TestSpawnCustomLook's own
-- header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestlook", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestlook] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local paramsArg = Parameters and Parameters[1]
            local archetypeArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestSpawnCustomLook(paramsArg, archetypeArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestlook <paramsPath> <archetypePath>")
    registerCmdInfo("lbtestlook", "lbtestlook <paramsPath> <archetypePath>", "Spawns Config.SENKA_FEMALE_BASE_CLASS with BOTH a custom outfit and a custom archetype override -- tests whether this base class respects an archetype override the way mob/crew classes never do.")
else
    log("lbtestlook unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestmorphparams <morphParamsPath>" (2026-08-31) -- tests whether
-- comp.MorphParams (found to be a plain, ordinary cooked DataAsset, unlike ArchetypePreset's
-- JSON-runtime chain) can be overridden pre-build -- if it sticks, real existing body-shape/size
-- presets (DA_NPC_Common_MorphParams_Large/Medium/Neutral/Random/Small etc.) become selectable.
-- See Spawner.TestSpawnCustomMorphParams's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestmorphparams", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestmorphparams] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local morphArg = Parameters and Parameters[1]
            local classArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestSpawnCustomMorphParams(morphArg, say, classArg) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestmorphparams <morphParamsPath> [classPath]")
    registerCmdInfo("lbtestmorphparams", "lbtestmorphparams <morphParamsPath> [classPath]", "Spawns Config.SENKA_FEMALE_BASE_CLASS (or an optional given class) with a custom MorphParams (body-shape preset) override -- tests whether it sticks pre-build like DefaultParams, or reasserts like ArchetypePreset.")
else
    log("lbtestmorphparams unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestmorphshape <presetName>" (2026-08-31) -- reads the nearest/locked
-- target's own class and respawns a fresh copy of it with a named MorphParams preset
-- (Config.MORPH_PARAMS_PRESETS, 18 confirmed-exhaustive entries) applied -- lets any mesh/mob type
-- be tested against any preset by short name, no path-typing needed. See
-- Spawner.TestMorphShapeOnTargetClass's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestmorphshape", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestmorphshape] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local presetArg = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestMorphShapeOnTargetClass(presetArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestmorphshape <presetName>")
    registerCmdInfo("lbtestmorphshape", "lbtestmorphshape <presetName>", "Respawns the nearest/locked target's own class with a named MorphParams shape preset applied -- test any mesh/mob type against any of the 18 known presets by name.")
else
    log("lbtestmorphshape unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestbody <paramsPath> <bodyMeshPath>" (2026-08-31) -- spawns with the proven
-- custom outfit, then swaps the base body mesh post-build (sidesteps the confirmed-blocked
-- ArchetypePreset route entirely). See Spawner.TestSpawnCustomBody's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestbody", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestbody] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local paramsArg = Parameters and Parameters[1]
            local bodyMeshArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestSpawnCustomBody(paramsArg, bodyMeshArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestbody <paramsPath> <bodyMeshPath>")
    registerCmdInfo("lbtestbody", "lbtestbody <paramsPath> <bodyMeshPath>", "Spawns with a custom outfit then swaps the base body mesh post-build -- tests a selected body mesh independent of the blocked ArchetypePreset route.")
else
    log("lbtestbody unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestbodystill <paramsPath> <bodyMeshPath>" (2026-08-31) -- same as lbtestbody,
-- plus SetAILogic(actor, false) right after -- a stationary version for judging visual changes
-- (color, materials) without a walking animation making it hard to tell. See
-- Spawner.TestSpawnCustomBodyStill's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestbodystill", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestbodystill] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local paramsArg = Parameters and Parameters[1]
            local bodyMeshArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestSpawnCustomBodyStill(paramsArg, bodyMeshArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestbodystill <paramsPath> <bodyMeshPath>")
    registerCmdInfo("lbtestbodystill", "lbtestbodystill <paramsPath> <bodyMeshPath>", "Same as lbtestbody, then freezes the AI (StopLogic) so the actor stands still -- easier to judge visual changes on.")
else
    log("lbtestbodystill unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbfreeze [on|off]" (2026-08-31) -- freezes/unfreezes the nearest/locked actor's
-- AI (StopLogic/StartLogic) without touching mesh/animation/composite at all. Defaults to freezing
-- (off = resume). Standalone version of the freeze step lbtestbodystill already does automatically,
-- for use on any already-placed actor (e.g. the real Gatherer/BotC comparisons from tonight's color
-- investigation).
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbfreeze", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbfreeze] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local modeArg = (Parameters and Parameters[1] or "on"):lower()
            local wantFreeze = not (modeArg == "off" or modeArg == "resume" or modeArg == "unfreeze")
            local ok, err = pcall(function() Spawner.TestFreezeNearest(wantFreeze, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbfreeze [on|off]")
    registerCmdInfo("lbfreeze", "lbfreeze [on|off]", "Freezes (default) or resumes ('off') the nearest/locked actor's AI (StopLogic/StartLogic) -- stands still for easier visual inspection.")
else
    log("lbfreeze unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbinspectfn <ClassPath> <FuncName>" (2026-08-31) -- PURE READ, no invocation.
-- See Spawner.TestInspectFunctionSig's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbinspectfn", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbinspectfn] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local classArg = Parameters and Parameters[1]
            local funcArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestInspectFunctionSig(classArg, funcArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbinspectfn <ClassPath> <FuncName>")
    registerCmdInfo("lbinspectfn", "lbinspectfn <ClassPath> <FuncName>", "PURE READ: lists a function's real declared parameter list before risking a call -- no invocation, no crash risk.")
else
    log("lbinspectfn unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestcolor <bodyPart> <R> <G> <B>" (2026-08-31) -- GENUINELY UNTESTED, REAL
-- CRASH RISK. Aims at the nearest/locked actor in front (same target convention as lbtestdecor),
-- creates a dynamic material instance on the given BuildedCompositeMeshes piece, tries several
-- plausible color parameter names. See Spawner.TestSetPieceColor's own header comment for the full
-- reasoning and risk profile.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestcolor", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestcolor] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local bodyPartArg = Parameters and Parameters[1]
            local rArg = tonumber(Parameters and Parameters[2]) or 1.0
            local gArg = tonumber(Parameters and Parameters[3]) or 0.0
            local bArg = tonumber(Parameters and Parameters[4]) or 0.0
            if not bodyPartArg then
                say("usage: lbtestcolor <bodyPart enum int, e.g. 7 for Torso> <R 0-1> <G 0-1> <B 0-1>")
                return true
            end
            local colorVec = { R = rArg, G = gArg, B = bArg, A = 1.0 }
            local ok, err = pcall(function() Spawner.TestSetPieceColor(bodyPartArg, colorVec, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestcolor <bodyPart> <R> <G> <B>")
    registerCmdInfo("lbtestcolor", "lbtestcolor <bodyPart> <R> <G> <B>", "GENUINELY UNTESTED, REAL CRASH RISK: creates a dynamic material instance on a BuildedCompositeMeshes piece, tries several color parameter names.")
else
    log("lbtestcolor unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestcolorid <N>" (2026-08-31) -- NEW LEAD found via lbprobedump's own property
-- walk: AR5AICharacter owns a plain `uint8 ColorID` (ReplicatedUsing=OnRep_ColorID), a layer ABOVE
-- CompositeMeshComponent/ColorParams entirely -- see Spawner.TestSetColorID's own header comment for
-- the full reasoning. Aims at the nearest/locked actor in front (same target convention as
-- lbtestcolor/lbtestdecor). Sets actor.ColorID directly then manually calls actor:OnRep_ColorID().
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestcolorid", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestcolorid] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local idArg = Parameters and Parameters[1]
            if not idArg then
                say("usage: lbtestcolorid <N, e.g. 0-9>")
                return true
            end
            local ok, err = pcall(function() Spawner.TestSetColorID(idArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestcolorid <N>")
    registerCmdInfo("lbtestcolorid", "lbtestcolorid <N>", "Sets the nearest/locked actor's AR5AICharacter.ColorID property directly and calls OnRep_ColorID() to force re-apply. New lead above the composite-mesh-config layer entirely.")
else
    log("lbtestcolorid unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestcpd <bodyPart> <R> <G> <B>" (2026-08-31) -- NEW LEAD found via
-- PrimitiveComponent.h's own Custom Primitive Data API (SetVectorParameterForCustomPrimitiveData /
-- SetCustomPrimitiveDataVector4), a completely different mechanism than the confirmed-dead
-- CreateDynamicMaterialInstance path. See Spawner.TestSetCPDColor's own header comment for the full
-- reasoning. Aims at the nearest/locked actor in front, same target convention as lbtestcolor.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestcpd", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestcpd] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local bodyPartArg = Parameters and Parameters[1]
            local rArg = tonumber(Parameters and Parameters[2]) or 1.0
            local gArg = tonumber(Parameters and Parameters[3]) or 0.0
            local bArg = tonumber(Parameters and Parameters[4]) or 0.0
            if not bodyPartArg then
                say("usage: lbtestcpd <bodyPart enum int, e.g. 7 for Torso> <R 0-1> <G 0-1> <B 0-1>")
                return true
            end
            local colorVec = { R = rArg, G = gArg, B = bArg, A = 1.0 }
            local ok, err = pcall(function() Spawner.TestSetCPDColor(bodyPartArg, colorVec, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestcpd <bodyPart> <R> <G> <B>")
    registerCmdInfo("lbtestcpd", "lbtestcpd <bodyPart> <R> <G> <B>", "Tries the Custom Primitive Data color API (SetVectorParameterForCustomPrimitiveData + raw index fallback) on a BuildedCompositeMeshes piece -- new lead above the material-instance dead end.")
else
    log("lbtestcpd unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestcpdidx <bodyPart> <index> <R> <G> <B>" (2026-08-31) -- BREAKTHROUGH
-- ISOLATION TEST. lbtestcpd's blind "write all 8 raw indices at once" fallback produced the first
-- ever visible color change tonight ("moldy white and brown, but definitely changed") -- this
-- writes only ONE CPD index at a time so the real color slot can be found and confirmed clean
-- (without the moldy artifacting from stomping other effect slots at the same time). See
-- Spawner.TestSetCPDIndex's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestcpdidx", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestcpdidx] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local bodyPartArg = Parameters and Parameters[1]
            local idxArg = Parameters and Parameters[2]
            local rArg = tonumber(Parameters and Parameters[3]) or 1.0
            local gArg = tonumber(Parameters and Parameters[4]) or 0.0
            local bArg = tonumber(Parameters and Parameters[5]) or 0.0
            if not (bodyPartArg and idxArg) then
                say("usage: lbtestcpdidx <bodyPart enum int, e.g. 7 for Torso> <CPD index 0-7> <R 0-1> <G 0-1> <B 0-1>")
                return true
            end
            local colorVec = { R = rArg, G = gArg, B = bArg, A = 1.0 }
            local ok, err = pcall(function() Spawner.TestSetCPDIndex(bodyPartArg, idxArg, colorVec, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestcpdidx <bodyPart> <index> <R> <G> <B>")
    registerCmdInfo("lbtestcpdidx", "lbtestcpdidx <bodyPart> <index> <R> <G> <B>", "Writes ONE CPD index at a time (isolation test) to find which slot is the real color channel without stomping other effect slots.")
else
    log("lbtestcpdidx unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestcpdcolor <bodyPart> <mainIdx> <secondaryIdx> <detailIdx>" (2026-08-31) --
-- THE REAL MECHANISM. M_Common_Cloth's own NameMap (extracted+converted offline via retoc +
-- UAssetGUI's undocumented `tojson` CLI mode) spells out CPD03/04/05 = Cloth Main/Secondary/
-- DetailColor, each a 0..23 PALETTE INDEX (same Value field as SelectedColors/ColorData), looked up
-- in a CurveLinearColorAtlas by the shader. Writes exactly those 3 floats in ONE
-- SetCustomPrimitiveDataVector4(3, ...) call -- no Dirt/BloodWounds contamination this time. See
-- Spawner.TestSetCPDPaletteColor's own header comment for the full reasoning.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestcpdcolor", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestcpdcolor] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local bodyPartArg = Parameters and Parameters[1]
            local mainArg = Parameters and Parameters[2]
            local secArg = Parameters and Parameters[3]
            local detArg = Parameters and Parameters[4]
            if not (bodyPartArg and mainArg) then
                say("usage: lbtestcpdcolor <bodyPart enum int, e.g. 7 for Torso> <mainIdx 0-23> <secondaryIdx 0-23> <detailIdx 0-23>")
                return true
            end
            local ok, err = pcall(function() Spawner.TestSetCPDPaletteColor(bodyPartArg, mainArg, secArg, detArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestcpdcolor <bodyPart> <mainIdx> <secondaryIdx> <detailIdx>")
    registerCmdInfo("lbtestcpdcolor", "lbtestcpdcolor <bodyPart> <mainIdx> <secondaryIdx> <detailIdx>", "Writes the real CPD03/04/05 Main/Secondary/DetailColor palette indices (0-23) in one clean Vector4 write -- confirmed via offline material inspection.")
else
    log("lbtestcpdcolor unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestcpdfloat <bodyPart> <index> <value>" (2026-08-31) -- isolated SINGLE-FLOAT
-- CPD write (SetCustomPrimitiveDataFloat), zero overlap with neighboring indices, for empirically
-- bisecting the real color index rather than trusting M_Common_Cloth's own (possibly stale) comment
-- labels any further. See Spawner.TestSetCPDFloat's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestcpdfloat", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestcpdfloat] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local bodyPartArg = Parameters and Parameters[1]
            local idxArg = Parameters and Parameters[2]
            local valueArg = Parameters and Parameters[3]
            if not (bodyPartArg and idxArg and valueArg) then
                say("usage: lbtestcpdfloat <bodyPart enum int, e.g. 7 for Torso> <CPD float index> <value>")
                return true
            end
            local ok, err = pcall(function() Spawner.TestSetCPDFloat(bodyPartArg, idxArg, valueArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestcpdfloat <bodyPart> <index> <value>")
    registerCmdInfo("lbtestcpdfloat", "lbtestcpdfloat <bodyPart> <index> <value>", "Writes ONE isolated CPD float (no overlap) to empirically bisect the real color index.")
else
    log("lbtestcpdfloat unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestbasecpd <index> <value>" (2026-08-31) -- same as lbtestcpdfloat but
-- targets actor.Mesh (the base body component) directly, for CPD channels that live on the base
-- mesh's own material slots (e.g. CPD15 EyeColor, on the MI_Eye slot) rather than a
-- BuildedCompositeMeshes piece. See Spawner.TestSetBaseCPDFloat's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestbasecpd", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestbasecpd] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local idxArg = Parameters and Parameters[1]
            local valueArg = Parameters and Parameters[2]
            if not (idxArg and valueArg) then
                say("usage: lbtestbasecpd <CPD float index, e.g. 15 for EyeColor> <value>")
                return true
            end
            local ok, err = pcall(function() Spawner.TestSetBaseCPDFloat(idxArg, valueArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestbasecpd <index> <value>")
    registerCmdInfo("lbtestbasecpd", "lbtestbasecpd <index> <value>", "Writes ONE isolated CPD float on actor.Mesh directly (base body component) -- for EyeColor (CPD15) and similar base-mesh-slot channels.")
else
    log("lbtestbasecpd unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtesteye <colorName>" (2026-08-31) -- eyes aren't CPD-driven; swaps the eye
-- material slot on actor.Mesh to one of the game's own discrete pre-made eye-color materials
-- (Blue/Brown/Evil/Green/Grey), the same safe swap mechanism already proven for skin tone. See
-- Spawner.TestSetEyeColor's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtesteye", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtesteye] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local colorArg = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestSetEyeColor(colorArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtesteye <colorName>")
    registerCmdInfo("lbtesteye", "lbtesteye <Blue|Brown|Evil|Green|Grey|Default>", "Swaps the eye material slot on actor.Mesh to a pre-made eye-color variant (or back to the plain native default) -- eyes aren't CPD-driven, unlike cloth/hair/eyebrows.")
else
    log("lbtesteye unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobecolors" (2026-08-31) -- PURE READ, no spawn/write. Reads the nearest/
-- locked actor's CompositeMeshComponent.CurrentCustomizationData/SavedCustomizationData.SelectedColors
-- -- a per-NPC, non-soft-ptr color source one level above everything tried tonight. See
-- Spawner.TestProbeSelectedColors's own header comment for the full reasoning.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobecolors", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbprobecolors] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.TestProbeSelectedColors(say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbprobecolors")
    registerCmdInfo("lbprobecolors", "lbprobecolors", "PURE READ: dumps the nearest/locked actor's CurrentCustomizationData/SavedCustomizationData.SelectedColors (BodyPart/Value/bOverrideDefaultColor) -- a per-NPC color source above the material/CPD layer.")
else
    log("lbprobecolors unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestselcolor <bodyPart> <newValue>" (2026-08-31) -- GENUINELY UNTESTED, REAL
-- CRASH RISK. Writes SavedCustomizationData.SelectedColors[*].Value for the given BodyPart on the
-- nearest/locked actor, then calls SetBody() with the actor's own current type/sex + bForceLoad=true
-- to try to force a rebuild. See Spawner.TestSetSelectedColor's own header comment for the full
-- reasoning -- this follows directly from lbprobecolors's smoking-gun finding (SelectedColors
-- genuinely differs per NPC for the same BodyPart).
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestselcolor", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestselcolor] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local bodyPartArg = Parameters and Parameters[1]
            local valueArg = Parameters and Parameters[2]
            if not (bodyPartArg and valueArg) then
                say("usage: lbtestselcolor <bodyPart enum int, e.g. 7 for Torso> <newValue int, e.g. 0-23>")
                return true
            end
            local ok, err = pcall(function() Spawner.TestSetSelectedColor(bodyPartArg, valueArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestselcolor <bodyPart> <newValue>")
    registerCmdInfo("lbtestselcolor", "lbtestselcolor <bodyPart> <newValue>", "GENUINELY UNTESTED, REAL CRASH RISK: writes SavedCustomizationData.SelectedColors[*].Value for a BodyPart, then calls SetBody() to try to force a rebuild.")
else
    log("lbtestselcolor unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbplayerclass" (2026-08-31) -- PURE READ: reports the player's own live pawn
-- class path and current ArchetypePreset. See Spawner.TestReportPlayerClass's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbplayerclass", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbplayerclass] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.TestReportPlayerClass(say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbplayerclass")
    registerCmdInfo("lbplayerclass", "lbplayerclass", "PURE READ: reports the player's own pawn class path and current ArchetypePreset.")
else
    log("lbplayerclass unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbscanhooks <classPath>" (2026-08-29) -- PURE READ diagnostic: scans a native
-- class's own CDO for soft-object/soft-class reference properties and reports their default target
-- paths. Motivation: WINDROSE_MODDING_NOTES.md SS19c-3's own finding (a brand-new asset path never
-- resolves unless something already-loaded references it) plus a confirmed-working third-party mod
-- (KasperShipRespawn, ships a genuinely new widget/settings asset, loaded purely via letting native
-- code -- R5ReviveComponent -- resolve its own already-existing hardcoded reference) together imply
-- other native classes may have similar UNPOPULATED soft-reference slots worth finding and filling.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbscanhooks", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbscanhooks] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local classArg = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.TestScanSoftRefs(classArg) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbscanhooks <classPath>")
    registerCmdInfo("lbscanhooks", "lbscanhooks <full /Script/Module.ClassName path>", "PURE READ: scans a native class's CDO for soft-object/soft-class reference properties -- looking for unpopulated 'hook point' asset paths worth filling with custom content.")
else
    log("lbscanhooks unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestassetreg <PackageName> <AssetName>" (2026-08-29) -- tests
-- AssetRegistryHelpers:GetAsset(), the resolution mechanism the already-installed, already-enabled
-- BPModLoaderMod uses to discover brand-new Blueprint mod classes -- against our own confirmed-new,
-- confirmed-currently-unresolvable (via resolveAsset) DA_Custom_MaritaParams path. See
-- Spawner.TestResolveViaAssetRegistry's own header comment for the full reasoning.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestassetreg", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestassetreg] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local packageArg = Parameters and Parameters[1]
            local assetArg = Parameters and Parameters[2]
            local ok, err = pcall(function() Spawner.TestResolveViaAssetRegistry(packageArg, assetArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestassetreg <PackageName> <AssetName>")
    registerCmdInfo("lbtestassetreg", "lbtestassetreg <PackageName> <AssetName>", "PURE READ: resolves an asset via AssetRegistryHelpers:GetAsset() instead of resolveAsset -- tests whether a genuinely new package path is discoverable through this different API.")
else
    log("lbtestassetreg unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestlistclass <ClassModule> <ClassName>" (2026-08-31) -- enumerates every
-- registered asset of a given class via IAssetRegistry:GetAssetsByClass(), for finding sibling
-- assets (e.g. other ethnicity/profession PresetArchetype variants) that live under a package root
-- retoc's own offline pak scan can't find. See Spawner.TestListAssetsByClass's own header comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestlistclass", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbtestlistclass] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local moduleArg = Parameters and Parameters[1]
            local classArg = Parameters and Parameters[2]
            local filterArg = Parameters and Parameters[3]
            local ok, err = pcall(function() Spawner.TestListAssetsByClass(moduleArg, classArg, filterArg, say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbtestlistclass <ClassModule> <ClassName> [nameFilter]")
    registerCmdInfo("lbtestlistclass", "lbtestlistclass <ClassModule> <ClassName> [nameFilter]", "PURE READ: lists every registered asset of a given class via AssetRegistry:GetAssetsByClass() -- finds sibling assets an offline pak scan can't. Optional substring filter to narrow output.")
else
    log("lbtestlistclass unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbunlockclothes" (2026-08-28) -- toggles Config.CLOTHES_UNLOCK_ALL, the
-- off-by-default escape hatch that bypasses every women's-clothing fit rule in
-- Spawner.TestApplyClothingPiece/TestRemoveClothingPiece. See Spawner.ToggleClothesUnlock's own
-- comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbunlockclothes", function(FullCommand, Parameters, Ar)
            local ok, err = pcall(function() Spawner.ToggleClothesUnlock() end)
            if not ok then print("[LivingBase] [lbunlockclothes] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbunlockclothes")
    registerCmdInfo("lbunlockclothes", "lbunlockclothes", "Toggles Config.CLOTHES_UNLOCK_ALL (off by default) -- when on, bypasses all women's-clothing fit/resize/remove rules; outfits beyond the reviewed set may clip or look wrong.")
else
    log("lbunlockclothes unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestfacial <family> <slot> <name> [sex override: M/F]" (2026-08-28) -- swaps
-- an eyebrow/beard/mustache/whiskers piece onto the nearest spawned actor. See
-- Spawner.TestApplyFacialPiece's own comment.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbtestfacial", function(FullCommand, Parameters, Ar)
            local familyArg = Parameters and Parameters[1]
            local slotArg = Parameters and Parameters[2]
            local nameArg = Parameters and Parameters[3]
            local sexArg = Parameters and Parameters[4]
            local ok, err = pcall(function() Spawner.TestApplyFacialPiece(familyArg, slotArg, nameArg, sexArg) end)
            if not ok then print("[LivingBase] [lbtestfacial] FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbtestfacial <family> <slot> <name> [sex override: M/F]")
    registerCmdInfo("lbtestfacial", "lbtestfacial <family> <slot> <name> [sex override: M/F]", "Swaps an eyebrow/beard/mustache/whiskers piece (see Config.CUSTOM_FACIAL for the full list) onto the nearest actor. Auto-detects sex by default; pass M or F to force which sex-path Eyebrows uses.")
else
    log("lbtestfacial unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbfixraytrace" (2026-08-22) -- see Spawner.FixAllRaytraceChannels' own comment.
-- Retroactively fixes raytrace targeting on every already-placed tracked spawn (walking actors,
-- Senkamati, statues, decor) without needing a reload.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbfixraytrace", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbfixraytrace] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.FixAllRaytraceChannels(say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbfixraytrace")
    registerCmdInfo("lbfixraytrace", "lbfixraytrace", "Retroactively re-applies the raytrace-targeting collision fix to every already-placed tracked spawn, without needing a reload.")
else
    log("lbfixraytrace unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobelootmesh" (2026-08-17) -- TEMP DEV TOOL, see
-- Spawner.ProbeNearestLootMesh's own comment. Follow-up to lbprobestone dead-ending on an opaque
-- TSoftObjectPtrUserdata: reads the mesh straight off a REAL dropped item instead. Drop any item,
-- face it, run this.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobelootmesh", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbprobelootmesh] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.ProbeNearestLootMesh(say) end)
            if not ok then say("lbprobelootmesh FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbprobelootmesh")
    registerCmdInfo("lbprobelootmesh", "lbprobelootmesh", "TEMP DEV TOOL: reads the mesh straight off a real dropped item (follow-up to lbprobestone hitting an opaque property).")
else
    log("lbprobelootmesh unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbprobecam" (2026-08-20) -- TEMP DEV TOOL, see Spawner.ProbeCameraRig's own
-- comment. Reads the pawn's own SpringArmComponent (SocketOffset/TargetArmLength/world transform) --
-- run once normally, then again while actually holding the hammer in real build mode, and diff the
-- two to get the exact native camera-raise offset instead of guessing one from screenshots.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbprobecam", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print(msg)
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.ProbeCameraRig(say) end)
            if not ok then say("[LivingBase] [probecam] lbprobecam FAILED: " .. tostring(err) .. "\n") end
            return true
        end)
    end)
    log("Console command registered: lbprobecam")
    registerCmdInfo("lbprobecam", "lbprobecam", "TEMP DEV TOOL: reads the player pawn's SpringArmComponent transform/offset, to reverse-engineer the native build-mode camera raise.")
else
    log("lbprobecam unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console commands "lbdumpobj" / "lbdumpact" / "lbdumpmesh" (2026-08-13) -- thin wrappers around
-- UE4SS's own built-in DumpAllObjects()/DumpAllActors()/DumpStaticMeshes(), the same functions the
-- bundled "Keybinds" mod binds to Ctrl+J/Ctrl+Num7/Ctrl+Num8. Added because those keybinds don't
-- reliably fire in Windrose -- CONFIRMED LIVE (2026-08-13): Ctrl+J produced no dump file and no
-- log line at all, because Ctrl is already Windrose's native Dodge and J its native Journal
-- toggle, so the game's own input handling claims both keys before UE4SS's Keybinds-mod hook ever
-- sees them (see WINDROSE_MODDING_NOTES.md's own writeup). Console input doesn't compete with the
-- game's key bindings at all, so wrapping the same functions in a command sidesteps the conflict
-- entirely -- same reasoning lbspawn/lblook are built on.
-- (Ctrl+R never fires in this install either, same native-keybind conflict class as Ctrl+J -- see
-- WINDROSE_MODDING_NOTES.md. Its Lua-callable counterpart is the separate "lbreload" command,
-- CONFIRMED LIVE 2026-08-13 -- see that command's own registration comment below.)
-- One-line lbhelp descriptions for the friendlier registerDumpCommand-based commands (2026-08-27)
-- -- deliberately optional (registerCmdInfo falls back to the bare `label` for anything not
-- listed here), so this table only needs entries worth writing a real sentence for.
local DUMP_CMD_DESC = {
    lbdumpobj = "Dumps every loaded UObject to a file (wrapped as a command since its default keybind conflicts with the game's own input).",
    lbdumpact = "Dumps every actor currently in the world to a file.",
    lbdumpmesh = "Dumps every loaded static mesh to a file.",
    lbdumpusmap = "Generates Mappings.usmap next to the game .exe, needed for FModel to read Windrose's UE5 packages.",
    lbprobe = "Aims via the camera (or uses the Num+ locked target) and logs the nearest actor's class path -- the 'what am I looking at' probe.",
    lbprobedump = "Walks the last-probed actor's full property list (mesh components, sockets, anim info, etc.) up its whole class hierarchy, to its own timestamped dump file.",
    lbfixghost = "Recovery command for a build-ghost-preview object stuck mid-placement -- run lbprobe aimed at it first.",
    lbdumpbuildctx = "Probes the player's current build-ability/context state.",
    lbghosttest = "Applies the build-ghost-preview material to the last-probed actor, for testing the ghost look outside an actual placement.",
    lbghosttest2 = "Applies a solid (non-translucent) variant of the ghost material to the last-probed actor.",
    lboutlinetest = "Toggles a custom-depth render outline on the last-probed actor, for testing an alternate highlight look.",
    lbfollowteststop = "Stops an in-progress lbfollowtest loop early.",
    lbtestfemalereskin = "Manually triggers one roll of the female-walker reskin roster (same effect as the in-game Numpad-Decimal key).",
    lbshiptestclear = "Despawns the lbshiptest test actor.",
}
local function registerDumpCommand(name, fn, label)
    if not RegisterConsoleCommandHandler then return end
    pcall(function()
        RegisterConsoleCommandHandler(name, function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [" .. name .. "] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(fn)
            if ok then
                say(label .. " done -- see ue4ss.log / the file it wrote for the actual dump.")
            else
                say(label .. " FAILED: " .. tostring(err))
            end
            return true
        end)
    end)
    log("Console command registered: " .. name)
    -- One shared registerCmdInfo call point covers every registerDumpCommand-based command's
    -- lbhelp entry (2026-08-27) -- DUMP_CMD_DESC gives the friendlier ones a real one-line
    -- description; anything not listed there just falls back to its own `label`.
    registerCmdInfo(name, name, DUMP_CMD_DESC[name] or label)
end
if RegisterConsoleCommandHandler then
    registerDumpCommand("lbdumpobj", function() DumpAllObjects() end, "DumpAllObjects")
    registerDumpCommand("lbdumpact", function() DumpAllActors() end, "DumpAllActors")
    registerDumpCommand("lbdumpmesh", function() DumpStaticMeshes() end, "DumpStaticMeshes")
else
    log("lbdumpobj/lbdumpact/lbdumpmesh unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- "lbdumpusmap" (2026-08-19, FModel spike) -- FModel can't read Windrose's UE5 packages without a
-- .usmap mapping file ("Package has unversioned properties but mapping file is missing"). UE4SS
-- can generate one itself (DumpUSMAP() -> Mappings.usmap next to the .exe) -- its default keybind
-- is Ctrl+Numpad6, which is very likely the same native-keybind conflict class already documented
-- for Ctrl+J/Ctrl+R above (Ctrl is Windrose's own Dodge), so wrap it as a console command instead,
-- same reasoning lbdumpobj/lbdumpact/lbdumpmesh are already built on.
if RegisterConsoleCommandHandler and DumpUSMAP then
    registerDumpCommand("lbdumpusmap", function() DumpUSMAP() end, "DumpUSMAP")
else
    log("lbdumpusmap unavailable -- RegisterConsoleCommandHandler or DumpUSMAP missing in this UE4SS build.")
end

-- "lbgeneratesdk" / "lbgenuhtheaders" (2026-08-29) -- same Ctrl-key-conflict workaround as
-- lbdumpusmap above, for UE4SS's own BUILT-IN C++/UHT header generators (bundled in the "Keybinds"
-- mod, default Ctrl+H / Ctrl+Num9 -- broken here for the same reason every other Ctrl-based default
-- is, see WINDROSE_MODDING_NOTES.md's own "Ctrl is permanently unusable" note). Real motivation:
-- WINDROSE_MODDING_NOTES.md SS19c-4's own closing finding -- an SDK-stub-based separate Unreal
-- Editor project (built against generated header stubs for this game's own reflected native
-- classes, no source access needed) is the one credible, not-yet-attempted path toward authoring
-- genuinely NEW content (including this game's own proprietary composite-outfit classes), since
-- retoc-style byte editing can only ever override an EXISTING asset path. GenerateUHTCompatibleHeaders()
-- specifically produces headers in the format Unreal's own Header Tool expects, which is what a real
-- separate project's build pipeline needs to compile against.
if RegisterConsoleCommandHandler and GenerateSDK then
    registerDumpCommand("lbgeneratesdk", function() GenerateSDK() end, "GenerateSDK")
else
    log("lbgeneratesdk unavailable -- RegisterConsoleCommandHandler or GenerateSDK missing in this UE4SS build.")
end
if RegisterConsoleCommandHandler and GenerateUHTCompatibleHeaders then
    registerDumpCommand("lbgenuhtheaders", function() GenerateUHTCompatibleHeaders() end, "GenerateUHTCompatibleHeaders")
else
    log("lbgenuhtheaders unavailable -- RegisterConsoleCommandHandler or GenerateUHTCompatibleHeaders missing in this UE4SS build.")
end

-- Console commands "lbprobe" / "lbprobedump" (2026-08-18) -- replace the old HOME/PAUSE diagnostic
-- keybinds (RedFalcon's request: console commands over physical keys for these). Same two-step
-- design as before, same functions, just triggered by typing instead of pressing a key: lbprobe
-- (= old HOME) aims via the camera -- or uses the locked target if one's set -- logs the nearest
-- actor's class path to discovery_dump.txt, and caches it; lbprobedump (= old PAUSE) walks that
-- cached actor's full property list (up the class hierarchy) to ue4ss.log. Deliberately still two
-- commands, not one -- see Spawner.ProbeDumpProperties's own comment for the live crash that made
-- the two-step split necessary in the first place; combining them back into one call would
-- reintroduce that risk.
if RegisterConsoleCommandHandler then
    registerDumpCommand("lbprobe", function() Spawner.ProbeNearestActor() end, "ProbeNearestActor")
    registerDumpCommand("lbprobedump", function() Spawner.ProbeDumpProperties() end, "ProbeDumpProperties")
else
    log("lbprobe/lbprobedump unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- "lbfixghost" (2026-08-20) -- recovery command for a stuck-follow object SolidifyDecor's automatic
-- sweep keeps skipping (see Spawner.FixLastProbedGhost's own comment). Run lbprobe aimed at the
-- ghost first, then this.
if RegisterConsoleCommandHandler then
    registerDumpCommand("lbfixghost", function() Spawner.FixLastProbedGhost() end, "FixLastProbedGhost")
else
    log("lbfixghost unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- "lbproberadius [radius]" (2026-08-20) -- "do we still have that command that lets me probe in a
-- radius around me?" -- see Spawner.ProbeRadius's own comment for why lbcustomscan doesn't cover
-- this. Optional radius arg, uu, defaults to 500.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbproberadius", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print(msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local radius = Parameters and Parameters[1]
            local ok, err = pcall(function() Spawner.ProbeRadius(radius, say) end)
            if not ok then say("[LivingBase] [proberadius] FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbproberadius")
    registerCmdInfo("lbproberadius", "lbproberadius [radius=500]", "Scans and records every new nearby class within a radius (uu), like lbcustomscan but not limited to whatever is directly in front.")
else
    log("lbproberadius unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- "lbdumpbuildctx" (2026-08-19, build-ghost-preview spike) -- lbprobe caught the wrong actor
-- (GCA_BuildingCreate_C, the one-shot place VFX cue) when aimed at a native building ghost; this
-- goes straight at R5Ability_Building_MakeConstructCommand's ConstructionContext instead, by class
-- rather than camera sweep. See Spawner.ProbeBuildAbility's own comment in spawner.lua.
if RegisterConsoleCommandHandler then
    registerDumpCommand("lbdumpbuildctx", function() Spawner.ProbeBuildAbility() end, "ProbeBuildAbility")
else
    log("lbdumpbuildctx unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- "lbghosttest" (2026-08-19, build-ghost-preview spike, 3rd pass) -- run lbprobe on some already-
-- spawned object first to select it, then this slaps Windrose's own MI_Building_SimplifiedPreview
-- onto every material slot so we can just LOOK at it (translucent ghost look + glow-in-the-dark).
-- Does not touch the game's live building-ability objects at all -- see Spawner.ApplyGhostMaterial's
-- own comment in spawner.lua for why (those crashed the game twice already today).
if RegisterConsoleCommandHandler then
    registerDumpCommand("lbghosttest", function() Spawner.ApplyGhostMaterial() end, "ApplyGhostMaterial")
else
    log("lbghosttest unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- "lbghosttest2" (2026-08-19, build-ghost-preview spike, 4th pass) -- same idea as lbghosttest, but
-- forces a consistent solid color via a per-slot dynamic material instance instead of applying
-- MI_Building_SimplifiedPreview's raw (inconsistent) default colors. See
-- Spawner.ApplyGhostMaterialSolid's own comment in spawner.lua.
if RegisterConsoleCommandHandler then
    registerDumpCommand("lbghosttest2", function() Spawner.ApplyGhostMaterialSolid() end, "ApplyGhostMaterialSolid")
else
    log("lbghosttest2 unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- "lboutlinetest" (2026-08-19, build-ghost-preview spike, 5th pass) -- tests whether Windrose's
-- rendering pipeline has an active CustomDepth outline post-process pass at all, by enabling
-- bRenderCustomDepth on the probed actor's mesh components. See Spawner.ToggleCustomDepthOutline's
-- own comment in spawner.lua.
if RegisterConsoleCommandHandler then
    registerDumpCommand("lboutlinetest", function() Spawner.ToggleCustomDepthOutline() end, "ToggleCustomDepthOutline")
else
    log("lboutlinetest unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- "lbfollowtest [intervalMs=33] [ticks=300] [distance=300]" / "lbfollowteststop" (2026-08-19,
-- build-ghost-preview spike, 6th pass) -- tests repeated K2_SetActorLocation with zero file I/O,
-- isolating whether the documented EditNearestInFront rotate crash was disk I/O or the actor-move
-- call itself. See Spawner.StartFollowTest's own comment in spawner.lua.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbfollowtest", function(FullCommand, Parameters, Ar)
            local intervalMs = tonumber(Parameters and Parameters[1])
            local ticks = tonumber(Parameters and Parameters[2])
            local distance = tonumber(Parameters and Parameters[3])
            Spawner.StartFollowTest(intervalMs, ticks, distance)
            return true
        end)
    end)
    registerDumpCommand("lbfollowteststop", function() Spawner.StopFollowTest() end, "StopFollowTest")
    log("Console command registered: lbfollowtest [intervalMs=33] [ticks=300] [distance=300], lbfollowteststop")
    registerCmdInfo("lbfollowtest", "lbfollowtest [intervalMs=33] [ticks=300] [distance=300]", "Test loop: makes an actor follow the player at a fixed distance for N ticks, for prototyping follow/escort behavior.")
else
    log("lbfollowtest/lbfollowteststop unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbtestfemalereskin" (2026-08-18) -- console-command twin of the existing
-- Numpad Decimal key (testFemaleWalkerReskin), NOT a replacement for it -- unlike HOME/PAUSE this
-- key has no known conflict, so it stays. Cycles to the next name in Config.FEMALE_RESKIN_TARGETS
-- and spawns that walking-woman reskin test subject; see Testbed.TestFemaleWalkerReskin's own
-- comment. Safe to expose -- no crash history, unlike TestApplyBodyType (see that function's own
-- comment for why it's deliberately NOT wired to anything).
if RegisterConsoleCommandHandler then
    registerDumpCommand("lbtestfemalereskin", function() Testbed.TestFemaleWalkerReskin() end, "TestFemaleWalkerReskin")
else
    log("lbtestfemalereskin unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbreload" (2026-08-13) -- reload JUST LivingBase without a full game restart,
-- via UE4SS's own RestartMod("LivingBase"). NOT a manual teardown-then-reload: there is no exposed
-- API to individually unregister RegisterInitGameStatePostHook/RegisterConsoleCommandHandler/
-- RegisterKeyBind (UnregisterHook exists but is for the separate, lower-level RegisterHook native-
-- UFunction system this mod doesn't use, and is itself documented as buggy in some UE4SS versions
-- -- crashes in some, silently no-ops in others). Per UE4SS's own docs, UninstallCurrentMod()
-- "destroys the Lua state and removes all hooks and keybinds"; RestartMod/UninstallMod are the
-- act-on-another-mod counterparts of that same pair, so RestartMod almost certainly does the same
-- full teardown before reloading -- the docs just don't spell that out as explicitly for RestartMod
-- specifically as they do for UninstallCurrentMod.
-- CONFIRMED LIVE 2026-08-13 -- the first form of Lua-state reload ever exercised in this project
-- (Ctrl+R, UE4SS's own hot-reload keybind, has never fired in this game at all -- see
-- WINDROSE_MODDING_NOTES.md's Ctrl-conflict writeup). Picks up plain script edits (e.g. adding a
-- probe function to spawner.lua) with no world-load/menu round-trip and no full game restart --
-- this is now the standard iteration path for this mod. `Spawner.spawned`/ledger/etc. get wiped
-- (fresh Lua state) same as any reload would; the existing restore machinery
-- (Spawner.RetrackOrphans, Spawner.generation -- see their own comments) recovers already-spawned
-- actors on the next world-load-shaped event.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbreload", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbreload] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            if type(RestartMod) ~= "function" then
                say("RestartMod unavailable in this UE4SS build -- can't reload without a full game restart.")
                return true
            end
            say("Reloading LivingBase via RestartMod -- watch ue4ss.log for anything that looks duplicated.")
            -- CONFIRMED LIVE (2026-08-13): calling RestartMod("LivingBase") SYNCHRONOUSLY, from
            -- inside a handler LivingBase itself registered, logged "Error: A custom console
            -- command handle must return true or false" immediately after -- execution never
            -- reached this function's own `return true` below (the reload evidently starts
            -- tearing down/reinstalling before the call stack that triggered it finishes
            -- unwinding). The reload itself completed CLEANLY regardless (one "Stopping mod" ->
            -- full fresh re-init -> "Mod reinstalled", no duplicate hooks) -- this error was pure
            -- noise, not a real failure -- but it's still worth not producing. Fix: defer the
            -- actual RestartMod call one tick out via ExecuteWithDelay, so THIS handler invocation
            -- returns true and fully unwinds on its own call stack first, before the teardown/
            -- reinstall (which belongs to a totally separate later tick) ever starts.
            if ExecuteWithDelay then
                ExecuteWithDelay(1, function()
                    local ok, err = pcall(function() RestartMod("LivingBase") end)
                    if not ok then
                        print("[LivingBase] [lbreload] RestartMod call FAILED: " .. tostring(err) .. "\n")
                    end
                end)
            else
                local ok, err = pcall(function() RestartMod("LivingBase") end)
                if not ok then
                    say("RestartMod call FAILED: " .. tostring(err))
                end
            end
            return true
        end)
    end)
    log("Console command registered: lbreload")
    registerCmdInfo("lbreload", "lbreload", "Hot-reloads this mod's Lua scripts (re-runs main.lua) without restarting the game, for picking up code-only changes.")
else
    log("lbreload unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbshiptest [forward] [right] [up]" / "lbshiptestclear" (2026-08-25) -- DEV
-- PROBE, see Spawner.ShipPivotTestPlace/Status's own comment in spawner.lua for the full
-- rationale (testing whether ship-relative placement, for a future ship decor/crew feature,
-- can be computed from the ship actor's own pivot transform rather than Xenophon's proven
-- two-point helm/center vector). Board your own ship first (this reads BasedMovement/
-- AttachParentActor off the player, same as Xenophon's own proven detection). Usage:
--   lbshiptest              -> status only: report the test actor's CURRENT local offset
--                               relative to the ship's CURRENT transform, without moving it --
--                               run this after moving/turning the ship to check for drift.
--   lbshiptest 300 0 100    -> place (or move, if already placed) the test actor at that local
--                               (forward, right, up) offset from the ship's pivot.
--   lbshiptestclear         -> despawn the test actor.
-- Everything logs to both ue4ss.log and LivingBase_ShipPivotTest_dump.txt (Spawner.shipTestLog)
-- so a full test session's readings survive to write up in WINDROSE_MODDING_NOTES.md.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbshiptest", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbshiptest] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local fwd = Parameters and Parameters[1]
            local right = Parameters and Parameters[2]
            local up = Parameters and Parameters[3]
            local ok, err
            if fwd == nil then
                ok, err = pcall(function() Spawner.ShipPivotTestStatus() end)
            else
                ok, err = pcall(function() Spawner.ShipPivotTestPlace(fwd, right, up) end)
            end
            if ok then
                say("done -- see ue4ss.log / LivingBase_ShipPivotTest_dump.txt for the reading.")
            else
                say("FAILED: " .. tostring(err))
            end
            return true
        end)
    end)
    registerDumpCommand("lbshiptestclear", function() Spawner.ShipPivotTestClear() end, "ShipPivotTestClear")
    log("Console command registered: lbshiptest [forward] [right] [up], lbshiptestclear")
    registerCmdInfo("lbshiptest", "lbshiptest [forward] [right] [up]", "DEV TOOL: places/moves a plain test actor at a ship-relative offset and reports whether it latched onto the ship's BasedMovement -- see WINDROSE_MODDING_NOTES.md section 13.")
else
    log("lbshiptest/lbshiptestclear unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbshiplook <walker|statue|senkamati> [forward] [right] [up]" (2026-08-25) --
-- places an ACTUAL Walker, Statue, or idle Senkamati look (Testbed.SpawnShipLookPreview's own
-- comment has the full rationale, and firstIdleSenkaLook's own comment explains the "senkamati"
-- kind specifically) so RedFalcon can eyeball what real content looks like, instead of judging
-- placement quality from the ship-pivot test's plain crew-class placeholder. Boards-a-ship-or-not
-- is auto-detected --
-- if you're on your ship it uses the same proven §13 pivot math `lbshiptest` does; otherwise it
-- just places in front of you like any other spawn key. A real, tracked, persisted spawn (goes
-- through Spawner.Spawn normally) -- despawn/undo/cycle all work on it like anything else placed
-- by this mod, unlike the throwaway `lbshiptest` actor.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbshiplook", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbshiplook] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local kind = Parameters and Parameters[1]
            if not kind then
                say("Usage: lbshiplook <walker|statue|senkamati> [forward] [right] [up]")
                return true
            end
            local fwd = Parameters and Parameters[2]
            local right = Parameters and Parameters[3]
            local up = Parameters and Parameters[4]
            local ok, actor, err = pcall(function() return Testbed.SpawnShipLookPreview(kind, fwd, right, up) end)
            if ok and actor then
                say("placed -- see ue4ss.log for exact location details.")
            elseif ok then
                say("FAILED: " .. tostring(err or "see ue4ss.log for details"))
            else
                say("FAILED: " .. tostring(actor))
            end
            return true
        end)
    end)
    log("Console command registered: lbshiplook <walker|statue|senkamati> [forward] [right] [up]")
    registerCmdInfo("lbshiplook", "lbshiplook <walker|statue|senkamati> [forward] [right] [up]", "Previews a real Walker/Statue/Senkamati look at a ship-relative (or camera-aimed, if not on a ship) position.")
else
    log("lbshiplook unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbshipmovecomp" (2026-08-25) -- HIGH-RISK EXPERIMENT, see
-- Spawner.TryAddMovementComponentToNearest's own comment for the full risk writeup and the
-- three safety checks it runs BEFORE the actual risky call. RedFalcon explicitly accepted the
-- crash risk to try this after Spawner.AddShipRider's timer-sync proved jittery. Targets the
-- nearest SPAWNED actor in front (findNearestSpawnInFront, same picker lbsexchange/despawn/
-- cycle/live-edit already share) -- aim this at your placed SHIP_LOOK_Statue before running it.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbshipmovecomp", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] [lbshipmovecomp] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local ok, err = pcall(function() Spawner.TryAddMovementComponentToNearest(say) end)
            if not ok then say("FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbshipmovecomp (HIGH-RISK EXPERIMENT -- see spawner.lua comment)")
    registerCmdInfo("lbshipmovecomp", "lbshipmovecomp", "HIGH-RISK EXPERIMENT: adds a fresh CharacterMovementComponent to the nearest actor -- see spawner.lua's own comment before using.")
else
    log("lbshipmovecomp unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Console command "lbhelp [command]" (2026-08-27, RedFalcon's request) -- lists every console
-- command this mod registers, or (given a name) that one command's exact syntax + description.
-- Reads LB_COMMANDS, which every registration above already populates via registerCmdInfo right
-- next to its own real RegisterConsoleCommandHandler call -- this can never miss a command or go
-- stale the way a hand-written list would, since there's nothing else to keep in sync.
if RegisterConsoleCommandHandler then
    pcall(function()
        RegisterConsoleCommandHandler("lbhelp", function(FullCommand, Parameters, Ar)
            local function say(msg)
                print("[LivingBase] " .. msg .. "\n")
                pcall(function()
                    if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then
                        Ar:Log(msg)
                    end
                end)
            end
            local sorted = {}
            for _, c in ipairs(LB_COMMANDS) do sorted[#sorted + 1] = c end
            table.sort(sorted, function(a, b) return a.name < b.name end)

            local query = Parameters and Parameters[1]
            if query and query ~= "" then
                local ql = query:lower()
                local found = nil
                for _, c in ipairs(sorted) do
                    if c.name:lower() == ql then found = c; break end
                end
                if not found then
                    say("lbhelp: no command named '" .. query .. "' -- run lbhelp with no arguments for the full list.")
                    return true
                end
                say(found.usage)
                if found.desc and found.desc ~= "" then say(found.desc) end
                return true
            end

            say(string.format("%d console command(s) registered -- run 'lbhelp <command>' for its syntax/description:", #sorted))
            for _, c in ipairs(sorted) do
                say("  " .. c.name)
            end
            return true
        end)
    end)
    log("Console command registered: lbhelp [command]")
    registerCmdInfo("lbhelp", "lbhelp [command]", "Lists every console command this mod registers; give a command name for its exact syntax and description.")
else
    log("lbhelp unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
end

-- Leash loop: periodically pull strayed wanderers back to their spawn spot. Runs UNCONDITIONALLY
-- (not gated on Config.LEASH_ENABLED) so a later live toggle-on takes effect within one tick —
-- Spawner.LeashTick() itself does no work when there's nothing to leash, and the live flag is
-- checked fresh every tick, so this is a cheap no-op loop while off, not a wasted background cost.
if ExecuteWithDelay then
    local function leashLoop()
        ExecuteWithDelay(Config.LEASH_INTERVAL_MS or 3000, function()
            if Config.LEASH_ENABLED then
                ExecuteInGameThread(function() pcall(function() Spawner.LeashTick() end) end)
            end
            leashLoop()
        end)
    end
    leashLoop()
    log("Leash loop running (LEASH_ENABLED=" .. tostring(Config.LEASH_ENABLED == true) .. "; live via Settings > Mods).")
else
    log("Leash unavailable — ExecuteWithDelay missing; wanderers roam free.")
end
