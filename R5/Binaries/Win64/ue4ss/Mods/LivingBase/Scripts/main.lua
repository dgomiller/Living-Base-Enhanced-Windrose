--[[
============================================================
 LivingBase — Base Building & Population Mod for Windrose
============================================================
 NUMPAD places NPCs/animals/statues (one per press):
   Num1 crew (cycles default + faction visitor looks) · Num2 townsman · Num3-6 statues
   (standing/floor/chair/interactive) · Num7 Senkamati · Num8 animal
   Num9 despawn-in-front · Num0 undo (restore last despawn)
   ';' places decor from the ACTIVE category · ''' advances which category is active (no spawn) ·
   DEL(x2) clean house.
   ']'/'[' cycle a targeted statue/decor forward/backward through its own roster
 Insert toggles EVERY key this mod binds — numpad, F-row, DEL, '\', live-edit — on/off at
 runtime (the toggle key itself always stays live, or there'd be no way back on). Lets any
 of those keys be used for something else while the toggle is off.
 Placed crowd + decorations persist across reloads; DEL(x2) clears permanently.
 Config: config.txt (plain-text toggles) + Scripts/config.lua (defaults/keymap). If the optional
 R5ModSettings mod is installed, every key here (and a few toggles) is ALSO remappable from
 Settings > Mods in-game (LivingBase-ModMenuPatch overlay) — keybind changes need a game restart
 to take effect, a handful of toggles apply live; see the "KEY REGISTRATION" section below for why.
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

-- One-time load confirmation (always shown). Decor key names read from Config.KEYS (fkeys.lua)
-- rather than hardcoded, so this stays accurate if they're ever remapped.
print(string.format(
    "[LivingBase] loaded — Numpad: 1 crew (cycles looks), 2 townsman, 3-6 statues, 7 Senkamati, 8 animal, 9 despawn-in-front, 0 undo | decor: %s = place active category, %s = change category | Insert toggle ALL mod keys on/off | DEL x2 clean-house\n",
    tostring(Config.KEYS.decorSpawn), tostring(Config.KEYS.decorCategory)))

-- Master on/off for every key this mod binds (Insert by default — off the F-row on purpose,
-- since F-keys are the ones most likely to collide with another mod/overlay): lets any of
-- those keys be used for something else while off. Runtime-only flag, checked at press time
-- by every bound key below — they stay REGISTERED either way (UE4SS has no unbind), they just
-- no-op while off. The toggle key's OWN bind is registered separately, outside this gate, or
-- there'd be no way back on.
local modEnabled = (Config.KEYS_ENABLED_ONSTART ~= false)
local function keyStatusText()
    local keyName = (Config.KEYS and Config.KEYS.toggleMod) or "INS"
    local status = modEnabled and "ENABLED" or "DISABLED"
    local verb = modEnabled and "disable" or "enable"
    return string.format("In-Game Keys are currently %s — press %s to %s them.", status, keyName, verb)
end
print("[LivingBase] " .. keyStatusText() .. "\n")

-- Bumped by the '-' key (see Config.KEYS.toggleWindow) each time the LivingBaseSpawnMenu window
-- should open/close -- published in the SPAWN MENU STATUS block further down as WINDOW_TOGGLE=<seq>.
-- A monotonic counter rather than an explicit open/closed flag since C++ owns the actual visibility
-- state outright (this side has no way to query it back) -- see MenuStatus::WindowToggleSeq()'s own
-- comment on the C++ side for why "something changed" is all that needs to cross the bridge.
local windowToggleSeq = 0

-- Bumped by the '=' key (see Config.KEYS.releaseMouse) every press -- published as FOCUS_STEAL=<seq>,
-- same bridge shape as windowToggleSeq above. SIMPLIFIED (2026-08-16, RedFalcon: "just have it steal
-- focus on = press and that's it") from an earlier version that also toggled bShowMouseCursor/
-- SetIgnoreLookInput on the player controller -- dropped entirely, this key now does exactly one
-- thing: tell the C++ window to SetForegroundWindow() on itself.
local focusStealSeq = 0

-- Locked from the moment a world load is detected until Spawner.RestoreFromPersist actually finishes
-- (or determines there's nothing to restore) -- placing something manually in that window got written
-- to persist.txt immediately, and restore (which reads persist.txt fresh, several seconds later once
-- RESTORE_SETTLE_MS/player-movement conditions are met) then re-spawned that SAME entry again, since
-- it was already in the file by the time restore's own read happened -- a real duplicate, not a
-- cosmetic one (user-reported 2026-08-06). Separate from modEnabled (the user's own on/off toggle) so
-- they don't fight each other; Insert still works normally once unlocked.
local restoreLockActive = false
-- restoreGate: the world-load restore lock alone, no In-Game Keys check -- this is the ONE gate
-- NOTHING touching real game state is exempt from, regardless of In-Game Keys (RedFalcon,
-- 2026-08-16: "ALL things should still be unavailable until the base is loaded"). Used directly by
-- the GUI window's own action handlers (spawn menu bridge, move menu bridge below) and by target
-- lock's keyboard registration -- all of these are meant to keep working with In-Game Keys OFF
-- (the GUI is the primary intended workflow now), but none of them are exempt from THIS.
local function restoreGate(name)
    if restoreLockActive then
        print("[LivingBase] '" .. tostring(name) .. "' ignored — still loading/restoring your base.\n")
        return false
    end
    return true
end
-- modGate: restoreGate PLUS the In-Game Keys toggle -- used only by the literal KEYBOARD actions
-- registered below (placement/live-edit/cycle/clear/etc, via gatedAction/directAction). NOT used by
-- the GUI window's own action handlers anymore (2026-08-16 split, RedFalcon: "disabling in-game keys
-- should disable ONLY the keys in the game... everything else [GUI buttons] should [stay independent]") --
-- see restoreGate above for what those use instead.
local function modGate(name)
    if not restoreGate(name) then return false end
    if modEnabled then return true end
    print("[LivingBase] '" .. tostring(name) .. "' ignored — In-Game Keys are OFF (toggle key to re-enable).\n")
    return false
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

-- Action wrappers mirror the three calling conventions the mod's keys have always used:
local function gatedAction(fn, name)
    -- Placement/decor/despawn/DEL/facing: modGate + shared spawn-debounce + game-thread + pcall.
    return function()
        if not modGate(name) then return end
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
local function directAction(fn, name)
    -- Undo/cycle/precision-toggle/live-edit: modGate + game-thread + pcall, no shared debounce
    -- (these are "fast repeated taps", not spawn-heavy — queuing them behind spawnBusy would just
    -- make them feel unresponsive for no safety benefit).
    return function()
        if not modGate(name) then return end
        ExecuteInGameThread(function()
            local ok, err = pcall(fn)
            if not ok then log(name .. " FAILED: " .. tostring(err)) end
        end)
    end
end
local function alwaysAction(fn, name)
    -- Like directAction, but bypasses BOTH gates entirely (not even restoreGate) -- for the three
    -- pure meta/UI keys that never touch game state at all: Insert (toggleMod, registered separately
    -- below since it's the one that flips modGate's own flag), '=' (window focus-steal), and '-'
    -- (window open/close toggle).
    return function()
        ExecuteInGameThread(function()
            local ok, err = pcall(fn)
            if not ok then log(name .. " FAILED: " .. tostring(err)) end
        end)
    end
end
local function restoreGatedAction(fn, name)
    -- Like directAction, but checks ONLY restoreGate, not the full modGate -- for actions that must
    -- stay reachable with In-Game Keys OFF (the GUI depends on them) but that DO touch real game
    -- state, so the world-load restore lock must still apply. Currently just target lock (Num+) --
    -- see its own registration comment below for why it's exempt from In-Game Keys specifically.
    return function()
        if not restoreGate(name) then return end
        ExecuteInGameThread(function()
            local ok, err = pcall(fn)
            if not ok then log(name .. " FAILED: " .. tostring(err)) end
        end)
    end
end

print("[LivingBase] ']'/'[' = cycle the targeted statue (Num3-6 lists) or decoration (its own category's list) forward/backward through its own roster; Num0 undoes it if the new pick isn't better.\n")

-- Placement toolkit: each key drops ONE actor in front of you (remap in config.lua, or live via
-- Settings > Mods if R5ModSettings is installed).
register("crew",      gatedAction(Testbed.SpawnCrew,            "place crew"))
register("townsman",  gatedAction(Testbed.SpawnWalker,          "place townsman"))
register("standing",  gatedAction(Testbed.SpawnNextStanding,    "place standing statue / quest folk"))
register("seated",    gatedAction(Testbed.SpawnNextSeated,      "place floor sitter"))
register("chairseat", gatedAction(Testbed.SpawnNextChairSeated, "place chair/stool sitter"))
register("interact",  gatedAction(Testbed.SpawnNextInteractive, "place interactive statue"))
register("plague",    gatedAction(Testbed.SpawnNextPlague,      "place Senkamati tribal human"))
-- senkaStatue/senkaStatueStanding REMOVED (2026-08-15) -- the whole Senkamati Statues feature was
-- purged (NSFW risk from the archetype-reroll's flash-through, see config.lua's own removal note
-- and CLAUDE.md). Both keys are free again.
register("livestock", gatedAction(Testbed.SpawnNextLivestock,   "place farm animal (boar/goat)"))
register("undo",      gatedAction(Testbed.DespawnInFront,       "despawn spawn in front (same floor)"))
-- TEMP DEV/TEST TOOL (2026-08-10) -- see Testbed.TestFemaleWalkerReskin's own comment.
register("testFemaleWalkerReskin", gatedAction(Testbed.TestFemaleWalkerReskin, "test: female walker reskin (Brethren Woman look)"))
-- F5/testApplyPose and F6/testApplyBodySex keys REMOVED (2026-08-15, same day) -- both were
-- scaffolding for the now-CLOSED pose-porting investigation (CLAUDE.md item 63) and the sex-change
-- discovery that grew out of it (item 64+). The sex-change capability lives on as a real console
-- command (`lbsexchange`, below -- Spawner.ApplySexChangeToNearest) instead of a dev key; pose-
-- porting's own test tools (Spawner.ApplyPose/ApplyBlueprintPose/MakePreBuildPoseSetter) are kept
-- undeployed as documented reference, matching Config.TATTOO_TEST_PARAMS' own precedent.
-- F4/testApplyBodyType key REMOVED (2026-08-15, same day) -- CONFIRMED to crash the game natively.
-- Two live tests, two crashes (crash_2026_08_15_00_37_57 and _00_41_27), both immediately
-- following an F4 press -- UE4SS.log shows ZERO [LivingBase:BodyType] output either time (that
-- line prints right after the pcall-wrapped comp:SetBody(...) call returns, before anything
-- else -- never printing means execution never returned to Lua at all, i.e. a native crash inside
-- the engine call itself, not a caught Lua error). Same "pcall cannot catch this" class of failure
-- already documented repeatedly in this codebase, but WORSE than every other post-build lever
-- tried this session (ColorParams/ArchetypePreset/pose-porting all failed SAFELY -- reported
-- success, just didn't render). See Spawner.ApplyBodyType's own comment for the full theory (why
-- SetBody looked promising) and CLAUDE.md item 64 for the writeup. Do not re-register this key or
-- call Spawner.ApplyBodyType/comp:SetBody live again without a genuinely new theory about why the
-- crash happens -- the function itself is kept (not deleted) purely as a documented cautionary
-- record, same treatment as other confirmed-dangerous paths in this file (see
-- Config.TATTOO_TEST_PARAMS' own comment for precedent).
-- testColorRandomization (Scroll Lock) REMOVED (2026-08-11) -- see Testbed.lua's own note
-- at the old call site for what it found before being cleaned up.

-- Undo (restore last despawn / DEL clean-house), Num0. No shared debounce — this is the "I made a
-- mistake" key, so it shouldn't be at risk of getting swallowed right when you need it.
register("restoreLast", directAction(function() Spawner.UndoDespawn() end, "undo"))

-- Cycle the targeted statue OR decoration through its own roster (']' forward / '[' backward) —
-- auto-detecting which kind of roster the targeted actor's class belongs to. No shared debounce — a
-- "let me flip through looks" key, not something that benefits from being queued behind placement.
register("cycleNext", directAction(function() Spawner.CycleNearestInFront(1) end, "cycleNext"))
register("cyclePrev", directAction(function() Spawner.CycleNearestInFront(-1) end, "cyclePrev"))

-- Focus-steal for the LivingBaseSpawnMenu window ('=') -- see Config.KEYS.releaseMouse's own comment.
-- Always active (bypasses modGate), one of the three "usual suspects" alongside Insert and '-'. Only
-- bumps a counter; the actual SetForegroundWindow() happens on the C++ side (StandaloneWindow.cpp)
-- once it notices FOCUS_STEAL changed in spawn_menu_status.txt (published below in the SPAWN MENU
-- STATUS block), same shape as the '-' window-toggle right below.
register("releaseMouse", alwaysAction(function()
    focusStealSeq = focusStealSeq + 1
end, "releaseMouse"))

-- LivingBaseSpawnMenu window open/close toggle ('-') -- see Config.KEYS.toggleWindow's own comment.
-- Always active (bypasses modGate), same as Insert and '='. Only bumps a counter; the actual
-- show/hide happens on the C++ side (StandaloneWindow.cpp) once it notices WINDOW_TOGGLE changed
-- in spawn_menu_status.txt (published below in the SPAWN MENU STATUS block).
register("toggleWindow", alwaysAction(function()
    windowToggleSeq = windowToggleSeq + 1
    print("[LivingBase] Spawn menu window: toggle requested (seq " .. windowToggleSeq .. ").\n")
end, "toggleWindow"))

-- DECORATION: ';' places from the active category (shares the spawn-debounce with every other
-- placement key); ''' just advances which category is active, no spawn -- same "fast repeated tap"
-- class as cycleNext/cyclePrev/undo below, so it skips the spawn-debounce via directAction.
register("decorSpawn",    gatedAction(Testbed.SpawnActiveDecorCategory, "decor: spawn active category"))
register("decorCategory", directAction(function() Testbed.CycleDecorCategory() end, "decor: change category"))

-- DEL wipes EVERYTHING, so it needs TWO presses to confirm: the first arms it, a second within the
-- window fires; otherwise it disarms. Guards against an accidental full clear.
local delArmed = false
local function confirmClear()
    if delArmed then
        delArmed = false
        Testbed.Cleanup()
    else
        delArmed = true
        print("[LivingBase] DEL armed — press DEL again to DELETE ALL spawns (disarms in a few seconds).\n")
        pcall(function() Spawner.Toast("Press DEL again to clear ALL spawns", 3.0) end)
        if ExecuteWithDelay then
            ExecuteWithDelay(Config.CLEAR_CONFIRM_MS or 3000, function() delArmed = false end)
        end
    end
end
register("clear", gatedAction(confirmClear, "despawn all (two-press confirm)"))

-- '\' toggles statue placement 180 deg: statues face away, riflers face you.
register("facing", gatedAction(Testbed.ToggleStatueFacing, "flip statue facing"))

-- Master mod-keys on/off toggle (Insert by default). ALWAYS active regardless of modEnabled's own
-- state (no modGate at all) — otherwise turning the mod's keys off would have no way back on. Goes
-- through register() like everything else; remapping it in Settings > Mods needs a restart, same
-- as every other keybind.
local function toggleModAction()
    modEnabled = not modEnabled
    local msg = "In-Game Keys: " .. (modEnabled and "ON" or "OFF (numpad/F-row/DEL/live-edit free for other uses)")
    print("[LivingBase] " .. msg .. "\n")
    pcall(function() Spawner.Toast(msg, 2.5) end)
end
register("toggleMod", toggleModAction)

-- reloadTest (Num+/NUM_ADD) REMOVED (2026-08-13) -- confirmed live that lbreload alone (no
-- world-load/menu round-trip) picks up a keybind change; see config.lua's Config.KEYS comment.
-- NUM_ADD briefly reused the same day for a "Female_Barbie" test key, then retired in favor of
-- making that an lblook-only named look instead (Testbed.SpawnBarbieByName). NUM_ADD's THIRD use
-- the same day: the target-lock toggle, registered below in the LIVE_EDIT block (Spawner.ToggleTargetLock).

-- Live edit: raise/lower + rotate the object in front of you, persistently. PageUp/PageDown =
-- height, ',' '.' = rotate.
-- Registration is an ALL-OR-NOTHING startup decision (Config.LIVE_EDIT, read once here) — the
-- live-edit keys deliberately do NOT get claimed by LivingBase at all when LIVE_EDIT is off, so
-- they stay free for other mods to bind. Toggling LIVE_EDIT in Settings > Mods needs a restart to
-- take effect, same as every keybind on that page (see the "KEY REGISTRATION" comment above).
-- Rotate axis (2026-08-18): shared by the in-game ','/'.' keys below AND the LivingBaseSpawnMenu
-- window's own ','/'.' shortcut (via ROTATE_AXIS_CYCLE, see the MOVE MENU BRIDGE section) -- ONE
-- piece of state either input path reads/cycles, so the keyboard and the GUI window can never
-- silently disagree about which axis ',' '.' currently rotate. In-memory only (a tool preference,
-- not per-object data -- unlike everything persist.txt tracks, this isn't tied to any one placed
-- object), resets to "Z" (yaw, matching the old single-axis behavior) every session/reload.
local rotateAxis = "Z"
local function cycleRotateAxis()
    rotateAxis = (rotateAxis == "X" and "Y") or (rotateAxis == "Y" and "Z") or "X"
    print("[LivingBase] Rotate axis: " .. rotateAxis .. "\n")
    pcall(function() Spawner.Toast("Rotate axis: " .. rotateAxis, 2.0) end)
end

if Config.LIVE_EDIT then
    local rs = Config.LIVE_EDIT_ROTATE_STEP or 15.0
    local hs = Config.LIVE_EDIT_HEIGHT_STEP or 10.0
    local ms = Config.LIVE_EDIT_MOVE_STEP or 10.0
    local function editAction(name, dZ, dYaw, dFwd, dRight)
        return directAction(function()
            -- Precision mode (cycled by Num-) scales TRANSLATION only — dYaw (rotation) is left
            -- alone, since only the slide/height keys were asked to get a finer-control option.
            -- Checked live at call time so cycling Num- takes effect immediately on the next press.
            local scale = Spawner.editPrecisionScale or 1.0
            Spawner.EditNearestInFront(dZ * scale, dYaw, dFwd * scale, dRight * scale)
        end, name)
    end
    -- ','/'.': rotate by `amt` around WHICHEVER axis rotateAxis currently names (X/Y=Roll/Pitch,
    -- Z=Yaw) -- checked live at call time (same "read Spawner.editPrecisionScale live" reasoning
    -- editAction's closure above already uses), so cycling the axis takes effect on the very next
    -- press, no re-registration needed.
    local function editRotAction(name, amt)
        return directAction(function()
            if rotateAxis == "X" then Spawner.EditNearestInFront(0, 0, 0, 0, 0, amt)
            elseif rotateAxis == "Y" then Spawner.EditNearestInFront(0, 0, 0, 0, amt, 0)
            else Spawner.EditNearestInFront(0, amt, 0, 0, 0, 0) end
        end, name)
    end
    register("editUp",    editAction("editUp",    hs, 0, 0, 0))
    register("editDown",  editAction("editDown", -hs, 0, 0, 0))
    register("editRotL",  editRotAction("editRotL", -rs))
    register("editRotR",  editRotAction("editRotR",  rs))
    register("toggleRotateAxis", directAction(cycleRotateAxis, "toggleRotateAxis"))
    register("editRot45", editAction("editRot45", 0,  45.0, 0, 0))   -- fixed 45° step, not tied to LIVE_EDIT_ROTATE_STEP
    register("editRot180",editAction("editRot180",0, 180.0, 0, 0))   -- fixed 180° flip on the object in front of you
    register("editFwd",   editAction("editFwd",  0, 0,  ms, 0))      -- arrows slide the prop in your facing frame
    register("editBack",  editAction("editBack", 0, 0, -ms, 0))
    register("editLeft",  editAction("editLeft", 0, 0, 0, -ms))
    register("editRight", editAction("editRight",0, 0, 0,  ms))

    -- Precision-mode cycle (Num-): steps Spawner.editPrecisionScale through 1/8 -> 1/4 -> 1/2 -> 1x
    -- -> 2x -> 4x -> back to 1/8, which editAction's callback reads live on every press (see above).
    -- REBASED (2026-08-16, RedFalcon's request): what used to be the "1/4" step turned out to be the
    -- everyday-useful one in practice, so it's now the "1x (normal)" baseline instead -- every value
    -- below is a fraction/multiple of the OLD quarter-step, not the old full step. A "4x" level was
    -- added at the top of the new range specifically so the OLD full step (1.0) is still reachable
    -- (as 4x), nothing lost, just rebased and given two extra fine steps at the bottom (the old
    -- range had nothing finer than 1/8 of the OLD full step -- new 1/8 is 1/32 of that same
    -- original unit). Same 6 levels drive the LivingBaseSpawnMenu window's precision slider
    -- (main.lua's own handleMoveMenuPrecision) -- keep both in sync if this ever changes again.
    local PRECISION_LEVELS = {
        { scale = 0.03125, label = "1/8-step" },
        { scale = 0.0625,  label = "1/4-step" },
        { scale = 0.125,   label = "1/2-step" },
        { scale = 0.25,    label = "1x (normal)" },
        { scale = 0.5,     label = "2x-step" },
        { scale = 1.0,     label = "4x-step" },
    }
    local precisionIdx = 4 -- start at "1x (normal)" (0.25 -- the old quarter-step)
    Spawner.editPrecisionScale = PRECISION_LEVELS[precisionIdx].scale
    register("editPrecisionToggle", directAction(function()
        precisionIdx = (precisionIdx % #PRECISION_LEVELS) + 1
        local level = PRECISION_LEVELS[precisionIdx]
        Spawner.editPrecisionScale = level.scale
        local msg = "Live-edit precision: " .. level.label
        print("[LivingBase] " .. msg .. "\n")
        pcall(function() Spawner.Toast(msg, 2.5) end)
    end, "editPrecisionToggle"))

    -- Target lock (Num+): toggles Spawner.lockedTarget. While locked, the SAME shared picker
    -- (findNearestSpawnInFront) that despawn/cycle/every live-edit key already goes through returns the
    -- locked actor instead of re-picking "nearest in front" — so no other key here needed to change to
    -- respect it. Deliberately registered in THIS block (LIVE_EDIT-gated), not unconditionally alongside
    -- Num9/undo/cycle: it only ever matters in combination with live-edit, and while it also affects
    -- despawn/cycle, those simply behave exactly as before (unlocked) when LIVE_EDIT is off, since the
    -- lock can never be set without this key to set it.
    -- restoreGatedAction, NOT directAction (2026-08-16, RedFalcon: "+ for targeting as its needed for
    -- the GUI") -- the GUI window's own Despawn/Replace/Coords/D-pad actions all require a locked
    -- target first, and there's no GUI button to CREATE a lock, only this key -- so it stays exempt
    -- from the In-Game Keys toggle (joining Insert/'='/'-'), but still respects the restore lock
    -- since it does touch real game state (unlike those three).
    register("targetLock", restoreGatedAction(function() Spawner.ToggleTargetLock() end, "targetLock"))

    print("[LivingBase] Live edit ON: PageUp/PageDown = height | ',' '.' = rotate | Num/ = rotate 45\194\176 | Num* = rotate 180\194\176 | arrows = slide fwd/back/left/right | Num- = cycle precision (1/8, 1/4, 1/2, 1x normal, 2x, 4x) | Num+ = toggle target lock (pins despawn/cycle/live-edit to one object)  (object in front, persists).\n")
end

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
}

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
        local ok, err = pcall(function()
            if verb == "REPLACE" then
                return Spawner.ReplaceNearestInFront(function() return handler(index) end)
            end
            return handler(index)
        end)
        if not ok then log("spawn menu " .. verb .. " " .. roster .. " FAILED: " .. tostring(err)) end
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
-- MOVE MENU BRIDGE: LivingBaseSpawnMenu's held-repeat buttons (MoveMenu.cpp, a side panel next
-- to the spawn tree) APPEND one "MOVE:<ACTION>\n" line to move_request.txt per repeat-tick while
-- a button is held -- appended, not overwritten, so ticks that land between two of our reads
-- never get lost to a last-write-wins overwrite. Uses the SAME step sizes and precision scale the
-- keyboard live-edit keys already use (Config.LIVE_EDIT_*_STEP / Spawner.editPrecisionScale, see
-- the LIVE_EDIT block above) so the window's buttons and the keyboard stay in perfect sync --
-- this file is the only place either one's step size is defined. Gated on Config.LIVE_EDIT
-- exactly like the keyboard keys are; the queue is still drained (read + deleted) when LIVE_EDIT
-- is off so it can never silently pile up unread, it just isn't acted on.
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

-- One entry per SPATIAL action MoveMenu.cpp can send -- UNIT (dZ, dYaw, dFwd, dRight, dPitch,
-- dRoll) deltas, matching the sign/axis convention the editUp/editDown/editRotL/editRotR/editFwd/
-- editBack/editLeft/editRight key actions already use above. Multiplied by the real step sizes +
-- precision scale at flush time below, never baked into the C++ side (see MoveMenu.cpp's own
-- header comment).
-- ROTX/ROTY/ROTZ (2026-08-18): full 3-axis rotation, replacing the old single-axis Rot L/R + the
-- Flip 180 button (removed -- RedFalcon: "not useful as much" once every axis is reachable
-- directly). Z is the original yaw rotation (was ROT_L/ROT_R, renamed for the new 3-row layout);
-- X/Y are UE's Roll/Pitch respectively -- matches Unreal's own FRotator convention (X axis =
-- Roll, Y axis = Pitch, Z axis = Yaw), which conveniently lines up with RedFalcon's own X/Y/Z
-- mockup row order without needing a different mapping.
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

-- ACTION:<NAME> one-shot commands (distinct from MOVE:<ACTION> spatial nudges above) -- these
-- come from single clicks (toggle/clear/lock buttons, or the in-window +/NUM_ADD keyboard
-- shortcut), never held-repeat, so they're handled IMMEDIATELY at drain time rather than queued
-- into the flush accumulator -- no reason to wait out the flush timer for a one-shot click, and
-- nothing here calls the expensive EditNearestInFront path the flush throttle exists to protect.
local function handleMoveMenuToggleEnable()
    -- Mirrors the in-game Insert key exactly -- toggleModAction() is the SAME function that key
    -- calls, defined earlier in this file (KEY REGISTRATION section). Deliberately NOT gated by
    -- modGate: the toggle key always works regardless of enabled state, or there'd be no way to
    -- turn keys back on once off.
    toggleModAction()
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
-- Rotate-axis cycle (matches the keyboard '/' shortcut, see Config.KEYS.toggleRotateAxis's own
-- comment) -- calls the SAME cycleRotateAxis() function defined up in the LIVE_EDIT section, so
-- the window's '/' and the in-game one can never disagree about which axis is currently selected.
-- restoreGate only, NOT modGate -- same reasoning as every other move-menu one-shot action here.
local function handleMoveMenuRotateAxisCycle()
    if not restoreGate("move menu: rotate axis") then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(cycleRotateAxis)
        if not ok then log("move menu rotate-axis FAILED: " .. tostring(err)) end
    end)
end
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
    -- Shared state with the keyboard's own Num- precision cycle (Spawner.editPrecisionScale,
    -- LIVE_EDIT block above) -- whichever set it last wins, same as any other shared setting. The
    -- keyboard cycle's own on-screen index/label can drift out of sync with a value set here from
    -- the window's slider (cosmetic only: the keyboard's NEXT Num- press still cycles correctly
    -- from wherever its own index already was, just not from this value) -- acceptable, not worth
    -- cross-syncing two separate UI's own cursor state for a display label.
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
-- (slow, 250ms -- see its own comment) is the ONLY thing that ever reads it and calls
-- Spawner.EditNearestInFront, then resets it to zero.
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
                    movePendingYaw   = movePendingYaw   + d[2] * rs
                    movePendingFwd   = movePendingFwd   + d[3] * ms * scale
                    movePendingRight = movePendingRight + d[4] * ms * scale
                    movePendingPitch = movePendingPitch + d[5] * rs
                    movePendingRoll  = movePendingRoll  + d[6] * rs
                    movePendingCount = movePendingCount + 1
                    count = count + 1
                end
            end
        else
            local precisionStr = line:match("^PRECISION:([%d%.]+)$")
            if precisionStr then
                handleMoveMenuPrecision(tonumber(precisionStr))
            elseif line == "ACTION:TOGGLE_ENABLE" then
                handleMoveMenuToggleEnable()
            elseif line == "ACTION:CLEAR_ALL" then
                handleMoveMenuClearAll()
            elseif line == "ACTION:TARGET_LOCK" then
                handleMoveMenuTargetLock()
            elseif line == "ACTION:ROTATE_AXIS_CYCLE" then
                handleMoveMenuRotateAxisCycle()
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
    if not Config.LIVE_EDIT then return end -- reset above either way; just don't act on it
    -- No shared spawnBusy debounce -- same "fast repeated tap" treatment directAction gives the
    -- keyboard live-edit keys. The throttle here is the flush RATE (250ms), not a busy-flag.
    -- restoreGate only, NOT modGate (2026-08-16 split) -- see restoreGate's own comment.
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
    -- 100ms (matches the drain rate above, so there's no artificial lag beyond it) = at most 10
    -- Spawner.EditNearestInFront calls/sec. CONFIRMED (2026-08-16) the crash's real cause was
    -- EditNearestInFront's per-edit SetActorHiddenInGame toggle (spawner.lua, now disabled, see
    -- that function's own comment), not raw call rate -- a controlled test held up at 250ms with
    -- only the toggle disabled, after a stricter 500ms throttle alone had NOT been enough. persist.txt
    -- itself (the other per-call cost, two reads + one rewrite) is only ~50 entries / ~11KB on this
    -- base -- negligible even at high frequency -- so there's no remaining reason to throttle this
    -- hard; kept at 100ms rather than removed entirely purely as cheap insurance against
    -- MOVE_MENU_MAX_ACTIONS_PER_DRAIN's own race-window worst case (see that constant's comment).
    -- If persist.txt ever grows dramatically (hundreds+ entries) and nudging starts to feel
    -- hitchy, that's the first thing to revisit.
    local function moveMenuFlushLoop()
        ExecuteWithDelay(100, function()
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
-- can show live state it has no other way to know: whether keys are currently enabled
-- (`modEnabled`), whether the world-load restore lock is active (`restoreLockActive` -- see the
-- "Restore: ..." block above; every keyboard key is gated on this exact flag today, and
-- RedFalcon asked for the window's buttons to be gated the same way), and what's currently
-- target-locked (Spawner.lockedTarget, Num+). Overwrites one small file each time any of the
-- three actually changes -- POLLED AND DIFFED here rather than published eagerly at each
-- mutation site, since those sites are scattered across two files (toggleModAction/
-- restoreLockActive here in main.lua, Spawner.lockedTarget's several set/clear points in
-- spawner.lua) and this state only ever changes on an explicit user action or a restore
-- starting/ending, never on a held-repeat -- a short poll is simple, correct, and imperceptible.
------------------------------------------------------------
local SPAWN_MENU_STATUS_PATH = "ue4ss/Mods/LivingBase/spawn_menu_status.txt"
local lastPublishedEnabled, lastPublishedRestoring, lastPublishedTarget, lastPublishedId = nil, nil, nil, nil
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
local lastPublishedRotateAxis = nil
local function publishSpawnMenuStatusIfChanged()
    local enabled, restoring = modEnabled, restoreLockActive
    local target, id, x, y, z, yaw, pitch, roll = currentLockedTargetInfo()
    if enabled == lastPublishedEnabled and restoring == lastPublishedRestoring and target == lastPublishedTarget
        and id == lastPublishedId
        and x == lastPublishedX and y == lastPublishedY and z == lastPublishedZ and yaw == lastPublishedYaw
        and pitch == lastPublishedPitch and roll == lastPublishedRoll
        and windowToggleSeq == lastPublishedWindowToggle
        and focusStealSeq == lastPublishedFocusSteal
        and rotateAxis == lastPublishedRotateAxis then
        return
    end
    lastPublishedEnabled, lastPublishedRestoring, lastPublishedTarget, lastPublishedId = enabled, restoring, target, id
    lastPublishedX, lastPublishedY, lastPublishedZ, lastPublishedYaw = x, y, z, yaw
    lastPublishedPitch, lastPublishedRoll = pitch, roll
    lastPublishedWindowToggle = windowToggleSeq
    lastPublishedFocusSteal = focusStealSeq
    lastPublishedRotateAxis = rotateAxis
    local f = io.open(SPAWN_MENU_STATUS_PATH, "w")
    if not f then return end
    f:write("ENABLED=", enabled and "1" or "0", "\n")
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
    f:write("ROTATE_AXIS=", rotateAxis, "\n")
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
            -- Fires right after (and so stacks directly under) Spawner's own "base restored" toast,
            -- since RestoreFromPersist calls that BEFORE calling this completion callback -- user
            -- asked for the key-status line to appear as a toast under the base-loaded message, not
            -- just in the log (2026-08-06).
            pcall(function() Spawner.Toast(keyStatusText(), 4.0) end)
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
else
    log("lbspawn unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
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
else
    log("lbtestswapbodysex unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
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
                ok, err = pcall(function() Spawner.SetCustomizationController(which, newValue, say) end)
            else
                usage()
                return true
            end
            if not ok then say("lbcustomnpc FAILED: " .. tostring(err)) end
            return true
        end)
    end)
    log("Console command registered: lbcustomnpc")
else
    log("lbcustomnpc unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
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
else
    log("lbprobestone unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
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
else
    log("lbprobelootmesh unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
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
end
if RegisterConsoleCommandHandler then
    registerDumpCommand("lbdumpobj", function() DumpAllObjects() end, "DumpAllObjects")
    registerDumpCommand("lbdumpact", function() DumpAllActors() end, "DumpAllActors")
    registerDumpCommand("lbdumpmesh", function() DumpStaticMeshes() end, "DumpStaticMeshes")
else
    log("lbdumpobj/lbdumpact/lbdumpmesh unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
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
else
    log("lbreload unavailable -- RegisterConsoleCommandHandler missing in this UE4SS build.")
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
