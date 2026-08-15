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
    return string.format("LivingBase keys are currently %s — press %s to %s them.", status, keyName, verb)
end
print("[LivingBase] " .. keyStatusText() .. "\n")

-- Locked from the moment a world load is detected until Spawner.RestoreFromPersist actually finishes
-- (or determines there's nothing to restore) -- placing something manually in that window got written
-- to persist.txt immediately, and restore (which reads persist.txt fresh, several seconds later once
-- RESTORE_SETTLE_MS/player-movement conditions are met) then re-spawned that SAME entry again, since
-- it was already in the file by the time restore's own read happened -- a real duplicate, not a
-- cosmetic one (user-reported 2026-08-06). Separate from modEnabled (the user's own on/off toggle) so
-- they don't fight each other; Insert still works normally once unlocked.
local restoreLockActive = false
local function modGate(name)
    if restoreLockActive then
        print("[LivingBase] '" .. tostring(name) .. "' ignored — still loading/restoring your base.\n")
        return false
    end
    if modEnabled then return true end
    print("[LivingBase] '" .. tostring(name) .. "' ignored — LivingBase keys are OFF (toggle key to re-enable).\n")
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

-- DECORATION: ';' places from the active category (shares the spawn-debounce with every other
-- placement key); ''' just advances which category is active, no spawn -- same "fast repeated tap"
-- class as cycleNext/cyclePrev/undo below, so it skips the spawn-debounce via directAction.
register("decorSpawn",    gatedAction(Testbed.SpawnActiveDecorCategory, "decor: spawn active category"))
register("decorCategory", directAction(function() Testbed.CycleDecorCategory() end, "decor: change category"))

-- Blackbeard flag raid: raidflag drops the flag (Composition_70) where a raid should start; bbraid
-- spawns a pirate wave at each placed flag and charges the bonfire. FORCE-DISABLED as of 2026-08-13
-- (Config.BBRAID_ENABLED hardcoded false in config.lua, config.txt, and pulled from the
-- R5ModSettings panel) -- code kept in place, easy to revive, see config.lua's own note. This
-- feature-flag gate is a STARTUP decision (unrelated to live keybind rebinding) — if BBRAID_ENABLED
-- is off, these two actions are simply never registered this session, exactly as before.
if Config.BBRAID_ENABLED then
    local BBRaid = require("bbraid")
    register("raidflag", gatedAction(Testbed.SpawnRaidFlag, "place Blackbeard raid flag"))
    register("bbraid",   gatedAction(BBRaid.Trigger,        "blackbeard raid"))
end

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
    local msg = "LivingBase keys: " .. (modEnabled and "ON" or "OFF (numpad/F-row/DEL/live-edit free for other uses)")
    print("[LivingBase] " .. msg .. "\n")
    pcall(function() Spawner.Toast(msg, 2.5) end)
end
register("toggleMod", toggleModAction)

-- Dev-tool diagnostic (Home): probe whatever actor is under the reticle — logs its class path to
-- discovery_dump.txt and its full component list to ue4ss.log. Not a real feature, so registered
-- directly with no modGate, same treatment the toast investigation's Home/Pause probes got before
-- they were removed (CLAUDE.md item 28). See Spawner.ProbeNearestActor's own comment for why.
register("probeNearest", function()
    ExecuteInGameThread(function()
        local ok, err = pcall(function() Spawner.ProbeNearestActor() end)
        if not ok then log("probeNearest FAILED: " .. tostring(err)) end
    end)
end)

-- Second step of the probe (PAUSE) — see Spawner.ProbeDumpProperties's own comment for why this is
-- a separate key from HOME rather than one combined press.
register("probeProperties", function()
    ExecuteInGameThread(function()
        local ok, err = pcall(function() Spawner.ProbeDumpProperties() end)
        if not ok then log("probeProperties FAILED: " .. tostring(err)) end
    end)
end)

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
    register("editUp",    editAction("editUp",    hs, 0, 0, 0))
    register("editDown",  editAction("editDown", -hs, 0, 0, 0))
    register("editRotL",  editAction("editRotL",  0, -rs, 0, 0))
    register("editRotR",  editAction("editRotR",  0,  rs, 0, 0))
    register("editRot45", editAction("editRot45", 0,  45.0, 0, 0))   -- fixed 45° step, not tied to LIVE_EDIT_ROTATE_STEP
    register("editRot180",editAction("editRot180",0, 180.0, 0, 0))   -- fixed 180° flip on the object in front of you
    register("editFwd",   editAction("editFwd",  0, 0,  ms, 0))      -- arrows slide the prop in your facing frame
    register("editBack",  editAction("editBack", 0, 0, -ms, 0))
    register("editLeft",  editAction("editLeft", 0, 0, 0, -ms))
    register("editRight", editAction("editRight",0, 0, 0,  ms))

    -- Precision-mode cycle (Num-): steps Spawner.editPrecisionScale through full -> 1/2 -> 1/4 ->
    -- 1/8 -> 2x -> back to full, which editAction's callback reads live on every press (see above).
    -- 2x added at the end (2026-08-13, RedFalcon's request) as a "go big" step for coarse repositioning --
    -- placed after the finest step rather than right after full, so the cycle still reads as
    -- fine-to-coarse in one direction before wrapping, instead of bouncing 1 -> 2x -> 1/2 mid-sequence.
    local PRECISION_LEVELS = {
        { scale = 1.0,   label = "full-step (normal)" },
        { scale = 0.5,   label = "HALF-step (1/2)" },
        { scale = 0.25,  label = "QUARTER-step (1/4)" },
        { scale = 0.125, label = "EIGHTH-step (1/8)" },
        { scale = 2.0,   label = "DOUBLE-step (2x)" },
    }
    local precisionIdx = 1
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
    register("targetLock", directAction(function() Spawner.ToggleTargetLock() end, "targetLock"))

    print("[LivingBase] Live edit ON: PageUp/PageDown = height | ',' '.' = rotate | Num/ = rotate 45\194\176 | Num* = rotate 180\194\176 | arrows = slide fwd/back/left/right | Num- = cycle precision (full/half/quarter/eighth/2x) | Num+ = toggle target lock (pins despawn/cycle/live-edit to one object)  (object in front, persists).\n")
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
    local function unlockTick()
        ExecuteInGameThread(function()
            local n = 0
            pcall(function() n = UnlockBuild.Run(tries == 0) or 0 end)
            tries = tries + 1
            -- keep retrying while the catalog is empty (max ~10 tries), then a couple of top-ups
            if (n == 0 and tries < 10) or tries < 3 then
                ExecuteWithDelay(15000, unlockTick)
            end
        end)
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

-- Structure shield: make building blocks invulnerable so raiders can't wreck the base. A construction
-- hook (NotifyOnNewObject) shields each block the instant it exists — so pieces the player builds
-- mid-session are covered immediately (the old sweep left those unshielded until a raid), it also catches
-- blocks reconstructed on a world reload, and it never re-scans the whole UObject list. One delayed sweep
-- after the world settles mops up blocks already present at mod load, before the hook was installed.
if Config.PROTECT_STRUCTURES ~= false then
    pcall(function() Spawner.WatchNewStructures() end)
    if ExecuteWithDelay then
        ExecuteWithDelay((Config.RESTORE_SETTLE_MS or 6000) + 6000, function()
            ExecuteInGameThread(function() pcall(function()
                local n = Spawner.ShieldAllStructures()
                if n and n > 0 then print(string.format("[LivingBase] Structure shield: %d building blocks made invulnerable.\n", n)) end
            end) end)
        end)
    end
end

-- Shield re-assert is now on-demand: Spawner.AttachShield starts a watcher when a warrior spawns and it
-- stops itself when the last warrior is gone (see Spawner.StartShieldWatcher). No perpetual tick here.

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
        -- Drop any raiders/timers from a raid that was still live when this world was torn down, so their
        -- now-dangling pointers are never touched (bbraid holds them in module state across the load).
        if Config.BBRAID_ENABLED then pcall(function() require("bbraid").Reset() end) end
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
