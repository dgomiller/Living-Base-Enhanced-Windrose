--[[
 LivingBase / modsettings.lua  (LivingBase-ModMenuPatch overlay -- new file)
 Shared R5 Mod Settings integration. Required by BOTH config.lua (one-time manifest write + initial
 saved-value load, at mod load) and main.lua (a live poll for TOGGLES ONLY -- see main.lua's "KEY
 REGISTRATION" comment for why keybinds are read once at load and never polled: an earlier version
 polled and live-rebound keybinds too, and it reliably crashed the game via RegisterKeyBind called
 outside the initial load pass. Keybind changes require a restart; the toggle poll never calls
 RegisterKeyBind, so it stayed).

 Entirely optional: every function here first checks whether the "R5ModSettings" UE4SS mod is
 actually installed (IsInstalled(), memoized) and no-ops harmlessly if not. Nothing in LivingBase
 outside this file, config.lua's one delegating call, and main.lua's key-registration section knows
 or cares whether R5ModSettings exists.

 Deliberately does NOT require("R5ModSettings") -- UE4SS mods aren't guaranteed to see each other's
 Scripts folder on the Lua path, and R5ModSettings's OWN example integration mod
 (R5ModSettingsExample) ships self-contained file I/O rather than requiring R5ModSettings.lua, for
 that reason. This only reads/writes the same plain Lua-table files (registrations/*.lua,
 saved/*.lua) and the same UE4SS shared variables that R5ModSettings itself reads/writes.
]]

local M = {}

M.MOD_ID = "LivingBase"
local RS_ROOTS = { "ue4ss/Mods/R5ModSettings/", "Mods/R5ModSettings/" }
local SHARED_PREFIX = "R5ModSettings/" .. M.MOD_ID .. "/"

-- 2026-08-07: the native Settings > Mods panel crashed the game multiple times this same session
-- (keybind capture, passive hovering, and toggle-only display all reproduced it independently) --
-- all confirmed via crash-dump analysis to be inside the game's own native code, not this file or
-- main.lua. Briefly held keybinds back from the manifest (cutting the panel to 10 toggle-only rows)
-- on the theory that LivingBase's 33-keybind list was the trigger -- DISPROVEN: it crashed again
-- with only 10 rows registered. The actual trigger, confirmed reproducible: moving the mouse cursor
-- QUICKLY over the panel's settings list crashes it, independent of row count, entry type, or which
-- mod owns the row. That's a genuine R5ModSettings bug, worth reporting upstream with that repro
-- step -- not something a smaller LivingBase footprint changes, so keybinds are back in the
-- manifest. If you're hit by this: move the cursor slowly over the settings list.
M.REGISTER_KEYBINDS_IN_PANEL = true

-- Memoized: which relative root R5ModSettings actually lives at, or nil if it isn't installed.
-- Checked once no matter how many times IsInstalled() is called (config.lua calls it once at load,
-- main.lua's toggle poll calls ReadLiveToggles() every ~1.5s for the rest of the session).
local rsRootChecked, rsRoot = false, nil
function M.IsInstalled()
  if not rsRootChecked then
    rsRootChecked = true
    for _, root in ipairs(RS_ROOTS) do
      local f = io.open(root .. "enabled.txt", "r")
      if f then f:close(); rsRoot = root; break end
    end
  end
  return rsRoot
end

-- R5ModSettings' in-game keybind picker is the game's own NATIVE key-binding widget, so it reads
-- and saves STANDARD Unreal FKey names (confirmed on the mod's own Nexus page: "F8, SpaceBar,
-- LeftShift, LeftMouseButton, ThumbMouseButton") -- a different naming convention from this UE4SS
-- build's OWN Key[] table, which main.lua's key resolution already had to work around once before
-- ("INS" not "INSERT"). Translate both directions: LivingBase's own name -> Unreal's name when
-- WRITING a manifest default (so the Settings UI shows/matches a real key from the start), and
-- Unreal's name -> LivingBase's own name when READING a picked value back (so main.lua's
-- Key[]/VK_FALLBACK lookup can resolve it).
--
-- Covers the full standard keyboard + mouse buttons, not just the keys LivingBase itself binds by
-- default -- a player can point ANY action at ANY key via the picker, so this needs to understand
-- whatever they might choose, not just our own shipped defaults. Single letters (A-Z) need no
-- entry -- Epic's FKey name for a letter key IS the bare capital letter, which doubles as a
-- perfectly good LivingBase-side name too (identical in both conventions, same as F1-F12). The
-- entries below exist because our own ALL_CAPS_WITH_UNDERSCORES convention and Epic's PascalCase
-- one-word names differ in case/spelling for everything else -- built from Epic's well-documented,
-- unchanged-since-UE4 EKeys names, not individually verified against this specific build's picker
-- output. Callers log every applied translation, so a wrong guess shows up in ue4ss.log as a clear
-- "key not recognized" rather than a silent no-op; report it and it gets added here.
--
-- NOTE on mouse buttons: RegisterKeyBind is a KEYBOARD-input API in every confirmed use in this
-- codebase. Whether it accepts a mouse-button virtual-key code at all is untested -- the raw codes
-- are provided as a best-effort (matching main.lua's VK_FALLBACK), but a mouse-button pick may
-- simply never fire, independent of anything translation can fix.
local LB_TO_UE = {
  NUM_ONE = "NumPadOne", NUM_TWO = "NumPadTwo", NUM_THREE = "NumPadThree", NUM_FOUR = "NumPadFour",
  NUM_FIVE = "NumPadFive", NUM_SIX = "NumPadSix", NUM_SEVEN = "NumPadSeven", NUM_EIGHT = "NumPadEight",
  NUM_NINE = "NumPadNine", NUM_ZERO = "NumPadZero",
  NUM_ADD = "Add", NUM_SUBTRACT = "Subtract", NUM_MULTIPLY = "Multiply", NUM_DIVIDE = "Divide",
  INS = "Insert", DEL = "Delete", PAGE_UP = "PageUp", PAGE_DOWN = "PageDown",
  OEM_COMMA = "Comma", OEM_PERIOD = "Period", OEM_FIVE = "Backslash",
  UP = "Up", DOWN = "Down", LEFT = "Left", RIGHT = "Right",
  HOME = "Home", END = "End", BACKSPACE = "BackSpace",
  -- Top-row digits (distinct physical keys from the numpad ones above -- Epic calls them by name,
  -- "Zero".."Nine", not "Digit0" etc; DIGIT_ prefix here avoids colliding with NUM_ZERO etc).
  DIGIT_0 = "Zero", DIGIT_1 = "One", DIGIT_2 = "Two", DIGIT_3 = "Three", DIGIT_4 = "Four",
  DIGIT_5 = "Five", DIGIT_6 = "Six", DIGIT_7 = "Seven", DIGIT_8 = "Eight", DIGIT_9 = "Nine",
  -- Whitespace / control cluster.
  TAB = "Tab", ENTER = "Enter", ESCAPE = "Escape", SPACE = "SpaceBar",
  CAPS_LOCK = "CapsLock", NUM_LOCK = "NumLock", SCROLL_LOCK = "ScrollLock",
  PRINT_SCREEN = "PrintScreen", PAUSE = "Pause",
  -- Modifiers (left/right specific -- the picker reports which physical side was pressed).
  LEFT_SHIFT = "LeftShift", RIGHT_SHIFT = "RightShift",
  LEFT_CONTROL = "LeftControl", RIGHT_CONTROL = "RightControl",
  LEFT_ALT = "LeftAlt", RIGHT_ALT = "RightAlt",
  -- Punctuation / OEM keys not already covered above.
  OEM_SEMICOLON = "Semicolon", OEM_EQUALS = "Equals", OEM_MINUS = "Hyphen", OEM_SLASH = "Slash",
  OEM_TILDE = "Tilde", OEM_LEFT_BRACKET = "LeftBracket", OEM_RIGHT_BRACKET = "RightBracket",
  OEM_QUOTE = "Quote",
  -- Mouse buttons (see NOTE above -- support unverified).
  MOUSE_LEFT = "LeftMouseButton", MOUSE_RIGHT = "RightMouseButton", MOUSE_MIDDLE = "MiddleMouseButton",
  MOUSE_THUMB1 = "ThumbMouseButton", MOUSE_THUMB2 = "ThumbMouseButton2",
}
local UE_TO_LB = {}
for lb, ue in pairs(LB_TO_UE) do UE_TO_LB[ue] = lb end

function M.ToUnreal(lbName) return LB_TO_UE[lbName] or lbName end
function M.ToLivingBase(ueName) return UE_TO_LB[ueName] or ueName end

-- Every key LivingBase binds. `title`/`description` drive the Settings > Mods page; `key` is both
-- the R5ModSettings saved-value key AND the Config.KEYS field name main.lua reads.
M.KEYBIND_DEFS = {
  { key = "toggleMod", title = "Toggle All Mod Keys",       description = "Turn EVERY key this mod binds on/off at runtime. Always stays active so there's a way back on." },
  { key = "toggleWindow", title = "Open/Close GUI Window",  description = "Open or close the LivingBaseSpawnMenu window. Works from anywhere while playing, always active regardless of In-Game Keys." },
  { key = "releaseMouse", title = "Focus GUI Window",       description = "Steal OS focus for the LivingBaseSpawnMenu window if it's already open, so your next click lands there. Does nothing if the window is closed." },
  { key = "crew",      title = "Place Crew",               description = "Cycle + place a crew pawn (default look or a faction visitor re-skin)." },
  { key = "townsman",  title = "Place Townsman",            description = "Spawn a townsman (wanders + uses furniture)." },
  { key = "standing",  title = "Place Standing Statue",     description = "Cycle + place a standing statue / quest-NPC pose." },
  { key = "seated",    title = "Place Floor Sitter",        description = "Cycle + place a statue that sits on the ground." },
  { key = "chairseat", title = "Place Chair/Stool Sitter",  description = "Cycle + place a statue that sits on a chair/stool you provide." },
  { key = "interact",  title = "Place Interactive Statue",  description = "Cycle + place a statue rifling a chest/equipment." },
  { key = "plague",    title = "Place Senkamati Tribal",    description = "Cycle + place a friendly Senkamati tribal human." },
  { key = "livestock", title = "Place Farm Animal",         description = "Cycle + place a friendly farm animal (boar/goat)." },
  { key = "undo",      title = "Despawn In Front",          description = "Despawn the spawn directly in front of you, on your floor." },
  { key = "restoreLast", title = "Undo Despawn",            description = "Restore the last despawned object(s) at their exact spot." },
  { key = "cycleNext", title = "Cycle Targeted Look Forward",  description = "Cycle the targeted statue or decoration to the next look in its own roster." },
  { key = "cyclePrev", title = "Cycle Targeted Look Backward", description = "Cycle the targeted statue or decoration to the previous look in its own roster." },
  { key = "decorSpawn",    title = "Place Decor (Active Category)", description = "Place one decoration from whichever category is currently active." },
  { key = "decorCategory", title = "Change Decor Category",         description = "Advance which decor category is active (nature/boats/wrecks/tents/storage/furniture). Doesn't spawn anything itself." },
  { key = "editUp",    title = "Live-Edit: Raise",        description = "Raise the targeted object." },
  { key = "editDown",  title = "Live-Edit: Lower",        description = "Lower the targeted object." },
  { key = "editRotL",  title = "Live-Edit: Rotate Left",  description = "Rotate the targeted object left." },
  { key = "editRotR",  title = "Live-Edit: Rotate Right", description = "Rotate the targeted object right." },
  { key = "editRot45", title = "Live-Edit: Rotate 45\194\176",  description = "Rotate the targeted object a fixed 45 degrees." },
  { key = "editRot180", title = "Live-Edit: Flip 180\194\176", description = "Rotate the targeted object a fixed 180 degrees." },
  { key = "editPrecisionToggle", title = "Live-Edit: Cycle Precision", description = "Cycle slide/height precision: full -> 1/2 -> 1/4 -> 1/8 -> 2x -> full." },
  { key = "targetLock", title = "Live-Edit: Toggle Target Lock", description = "Pin despawn/cycle/live-edit to one object so they keep acting on it even after you walk away or look elsewhere. Press again to release." },
  { key = "editFwd",   title = "Live-Edit: Slide Forward", description = "Slide the targeted object away from you." },
  { key = "editBack",  title = "Live-Edit: Slide Back",    description = "Slide the targeted object toward you." },
  { key = "editLeft",  title = "Live-Edit: Slide Left",    description = "Slide the targeted object to your left." },
  { key = "editRight", title = "Live-Edit: Slide Right",   description = "Slide the targeted object to your right." },
  { key = "facing", title = "Flip Statue Facing",     description = "Flip statue placement 180 degrees for FUTURE spawns only." },
  { key = "clear",  title = "Clean House (DEL x2)",   description = "Despawn ALL spawns and clear the save. Press twice to confirm." },
}

-- Every boolean config.txt exposes, plus a few more player-relevant switches. Deliberately NOT
-- every Config.* toggle -- most of config.lua is tuning knobs (timings/distances/material paths),
-- not things a player would ever want to flip.
--
-- `live = true` means main.lua's poll (see its "TOGGLE POLL" section) applies a change within
-- ~1.5s, no restart. `live` omitted/false means the setting is only read ONCE at mod load (same
-- as config.txt always worked) -- either because the setting decides a STARTUP-only state
-- (KEYS_ENABLED_ONSTART), or because turning it OFF can't be cleanly undone at runtime: none of
-- WHISTLE_CREW / UNLOCK_HIDDEN_BUILDING have a reverse
-- operation anywhere in the codebase (no "re-hide build items", no way
-- to dismiss an active whistle escort) -- turning one off mid-session would silently do nothing to
-- what's already active, which is worse than just requiring a restart. LIVE_EDIT additionally
-- claims a whole key cluster (PageUp/PageDown/comma/period/etc) that needs to stay free for other
-- mods when it's off -- see main.lua's "KEY REGISTRATION" section for that guarantee. Every
-- restart-only entry says so in its own `description` (shown in the Settings > Mods help panel),
-- not just here, since that's the only place a player actually sees it.
-- Order matches the user's own numbered layout for the Settings > Mods panel (screenshotted
-- 2026-08-07), not alphabetical or grouped-by-live-ness -- now that serialize()'s numeric-key sort
-- bug is fixed (see that function's own comment), this insertion order is what actually displays.
M.TOGGLE_DEFS = {
  { key = "KEYS_ENABLED_ONSTART", title = "Keys Enabled On Launch",    description = "Start with every LivingBase key ready to use. Off = starts OFF until you press the toggle key. (Restart required -- this only sets the STARTING state; use the toggle key for live on/off.)" },
  { key = "RESTORE_ON_LOAD",      title = "Auto-Restore Base On Load", description = "Automatically repopulate your saved base when you load into the world.", live = true },
  { key = "UNLOCK_HIDDEN_BUILDING",  title = "Unlock Hidden Build Pieces", description = "Surface build-menu pieces hidden from standard play (keeps normal progression gates intact). Session-only either way -- resets on relaunch. (Restart required to take effect either direction.)" },
  { key = "WHISTLE_CREW",            title = "Whistle Summons Crew",       description = "The boar whistle summons 2 crew instead of a boar. (Restart required to take effect either direction.)" },
  { key = "WHISTLE_FOLLOW_DEBUG",    title = "Whistle Follow Debug Log",   description = "Extra logging for the crew-escort follow behavior.", live = true },
  { key = "DECOR_COLLISION",      title = "Solid Decorations",         description = "Spawn decorations SOLID (you collide with them) instead of pass-through. Applies to future spawns immediately; decorations already placed keep their current collision until the world reloads.", live = true },
  { key = "LEASH_ENABLED",        title = "Leash Wanderers",           description = "Keep wandering crew/townsfolk near where you placed them.", live = true },
  { key = "LIVE_EDIT",            title = "Enable Live-Edit Keys",     description = "Bind the live-edit key set (raise/lower/rotate/slide/precision) for fine-tuning placed objects. (Restart required to take effect either direction.)" },
}

local function is_identifier(s)
  return type(s) == "string" and s:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function serialize(value, indent)
  indent = indent or "    "
  local vt = type(value)
  if vt == "number" or vt == "boolean" then return tostring(value) end
  if vt == "string" then return string.format("%q", value) end
  if vt ~= "table" then return "nil" end
  local parts = { "{\n" }
  -- Numeric keys (the `settings` ARRAY itself, e.g. settings[1], settings[2], ...) sort
  -- NUMERICALLY, preserving insertion order -- NOT as strings like the rest of this function's
  -- keys, which used to sort EVERYTHING via tostring(a) < tostring(b). That's correct for the
  -- per-setting field names (key/title/description/type/default -- just for deterministic, readable
  -- output) but silently scrambles any array past 9 entries ("10" < "2" lexicographically), which
  -- is exactly what made the `settings` array's display order in R5ModSettings' panel effectively
  -- random rather than the order it was built in. String keys keep the original alphabetical sort.
  local numericKeys, stringKeys = {}, {}
  for k in pairs(value) do
    if type(k) == "number" then numericKeys[#numericKeys + 1] = k
    else stringKeys[#stringKeys + 1] = k end
  end
  table.sort(numericKeys, function(a, b) return a < b end)
  table.sort(stringKeys, function(a, b) return a < b end)
  local keys = numericKeys
  for _, k in ipairs(stringKeys) do keys[#keys + 1] = k end
  for _, k in ipairs(keys) do
    local kt = is_identifier(k) and k or ("[" .. serialize(k, indent .. "    ") .. "]")
    parts[#parts + 1] = indent .. kt .. " = " .. serialize(value[k], indent .. "    ") .. ",\n"
  end
  parts[#parts + 1] = indent:sub(1, math.max(#indent - 4, 0)) .. "}"
  return table.concat(parts)
end

function M.ReadSavedFile()
  local root = M.IsInstalled()
  if not root then return nil end
  local f = io.open(root .. "saved/" .. M.MOD_ID .. ".lua", "r")
  if not f then return nil end
  local content = f:read("*all")
  f:close()
  if not content or content == "" then return nil end
  if content:sub(1, 3) == "\239\187\191" then content = content:sub(4) end
  local loader = load(content)
  if not loader then return nil end
  local ok, data = pcall(loader)
  return (ok and type(data) == "table") and data or nil
end

function M.WriteManifest(Config)
  local root = M.IsInstalled()
  if not root then return false end

  -- Toggles listed FIRST (user's requested panel layout, 2026-08-07), keybinds after -- relies on
  -- serialize()'s numeric-key sort fix above to actually come out in this order; before that fix
  -- the settings array's display order was effectively scrambled regardless of insertion order.
  local settings = {}
  for _, def in ipairs(M.TOGGLE_DEFS) do
    settings[#settings + 1] = {
      key = def.key, title = def.title, description = def.description, type = "toggle",
      default = Config[def.key] and true or false,
    }
  end
  -- Every keybind is restart-only (see main.lua's "KEY REGISTRATION" comment: a live keybind poll
  -- used to exist here and reliably crashed the game). Appended once, here, rather than duplicated
  -- across all 29 KEYBIND_DEFS descriptions -- one place to keep in sync if that ever changes.
  local KEYBIND_RESTART_NOTE = " (Restart required to take effect.)"
  if M.REGISTER_KEYBINDS_IN_PANEL then
    for _, def in ipairs(M.KEYBIND_DEFS) do
      local lbDefault = Config.KEYS[def.key] or "None"
      settings[#settings + 1] = {
        key = def.key, title = def.title, description = def.description .. KEYBIND_RESTART_NOTE, type = "keybind",
        default = { primary = M.ToUnreal(lbDefault), secondary = "None" },
      }
    end
  end
  -- https://www.nexusmods.com/windrose/mods/535 -- this fork's own page. NOT 519, which is the
  -- original "Living Base" mod (me123420) this fork was built on top of, credited in
  -- NEXUS_DESCRIPTION.txt but a different Nexus listing from this one.
  local manifest = {
    name = M.MOD_ID, display = "Living Base Enhanced", version = "2.1.0", nexus_id = "535",
    settings = settings,
  }
  local body = "-- Generated by LivingBase (modsettings.lua). Do not edit; regenerated on every mod load.\nreturn "
    .. serialize(manifest, "    ") .. "\n"

  local dir = root .. "registrations/"
  os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')
  local path = dir .. M.MOD_ID .. ".lua"
  local existingF = io.open(path, "r")
  if existingF then
    local existingBody = existingF:read("*all")
    existingF:close()
    if existingBody == body then return true end
  end
  local f = io.open(path, "w")
  if not f then return false end
  f:write(body)
  f:close()
  return true
end

-- One-time apply: called by config.lua at mod load. Mutates Config.KEYS[*] / Config[toggle] in
-- place from whatever's currently saved (file only -- this runs too early in the load sequence for
-- UE4SS shared variables to be reliably populated yet, since mod load order between "LivingBase"
-- and "R5ModSettings" isn't guaranteed). A keybind changed here still needs a game restart to
-- actually take effect -- see main.lua's "KEY REGISTRATION" comment.
--
-- Deliberately still reads M.KEYBIND_DEFS from the saved file here even though
-- M.REGISTER_KEYBINDS_IN_PANEL is currently false (WriteManifest no longer offers keybinds as
-- editable rows in the panel, to cut its crash surface -- see that flag's own comment). This is
-- pure file I/O, not a panel interaction, so it carries none of that risk -- and it means anyone
-- who already remapped a key through the UI before this change keeps that remap working, rather
-- than silently reverting to the shipped default.
function M.ApplyOnce(Config)
  if not M.IsInstalled() then return 0, 0 end
  M.WriteManifest(Config)
  local saved = M.ReadSavedFile()
  if not saved then return 0, 0 end
  local appliedKeys, appliedToggles = 0, 0
  for _, def in ipairs(M.KEYBIND_DEFS) do
    local v = saved[def.key]
    if type(v) == "table" and type(v.primary) == "string" and v.primary ~= "" and v.primary ~= "None" then
      local translated = M.ToLivingBase(v.primary)
      if translated ~= Config.KEYS[def.key] then
        print(string.format("[LivingBase] R5ModSettings: %s -> raw='%s' resolved='%s' (was '%s')\n",
          def.key, v.primary, translated, tostring(Config.KEYS[def.key])))
      end
      Config.KEYS[def.key] = translated
      appliedKeys = appliedKeys + 1
    end
  end
  for _, def in ipairs(M.TOGGLE_DEFS) do
    local v = saved[def.key]
    if type(v) == "boolean" then
      Config[def.key] = v
      appliedToggles = appliedToggles + 1
    end
  end
  if appliedKeys > 0 or appliedToggles > 0 then
    print(string.format("[LivingBase] R5ModSettings: applied %d keybind(s), %d toggle(s) from Settings > Mods.\n",
      appliedKeys, appliedToggles))
  end
  return appliedKeys, appliedToggles
end

-- Live read for main.lua's TOGGLE POLL: prefers UE4SS shared variables (published the instant the
-- player flips a toggle in Settings > Mods -- no file-write/read round trip needed), falls back to
-- the saved file if ModRef isn't available or shared variables haven't published yet this session.
-- Only reads the M.TOGGLE_DEFS entries marked `live = true` -- there is no reason to pay the read
-- cost for a toggle nothing ever polls (and no keybind entries -- see main.lua for why those are no
-- longer polled at all).
function M.ReadLiveToggles()
  local out = {}
  local sawSharedAny = false
  if ModRef then
    for _, def in ipairs(M.TOGGLE_DEFS) do
      if def.live then
        local ok, v = pcall(function() return ModRef:GetSharedVariable(SHARED_PREFIX .. def.key) end)
        if ok and type(v) == "boolean" then
          out[def.key] = v
          sawSharedAny = true
        end
      end
    end
  end
  if not sawSharedAny then
    local saved = M.ReadSavedFile()
    if saved then
      for _, def in ipairs(M.TOGGLE_DEFS) do
        if def.live and type(saved[def.key]) == "boolean" then
          out[def.key] = saved[def.key]
        end
      end
    end
  end
  return out
end

return M
