--[[
 LivingBase / spawnmenu_manifest.lua

 Generates (and incrementally extends -- never overwrites) an INI manifest the LivingBaseSpawnMenu
 companion C++ mod reads to build its category tree. Format settled in design discussion: one
 section per leaf entry, dotted section name = the display path, `roster`/`index` point back at
 the real Config table entry to spawn. Example:

   [Senkamati.Caster-F.Crew Reskin.Helmet On]
   label = Helmet On
   roster = SENKAMATI_LOOKS
   index = 9

 Auto-generation is deliberately mechanical, not curated -- it exists so the user isn't hand-typing
 every roster/index pair from scratch, not to guess good category names. New entries land under a
 plain "<RosterName> > Entry N" path; reorganizing them into a nicer tree (renaming section paths,
 regrouping) is the user's own hand-edit pass afterward. Re-running this must NEVER touch a section
 that already exists for a given roster+index pair, even if the user has since moved/renamed it --
 same "add what's missing, never clobber what's there" discipline as modsettings.lua's own
 EnsureSavedDefaults/WriteManifest (see that file's own comment for why).

 Entirely optional/self-contained: only ever touches its own INI file, never Config itself.
]]

local M = {}

-- A bare relative filename resolves against the GAME's own working directory
-- (R5/Binaries/Win64/), not this mod's own folder -- confirmed the hard way (first run landed
-- spawn_menu.ini at R5/Binaries/Win64/spawn_menu.ini instead of alongside persist.txt/config.txt).
-- Same multi-candidate defensive pattern modsettings.lua already uses for its own root
-- (RS_ROOTS) for exactly this reason -- try the expected path first, fall back if this build's
-- CWD ever turns out different.
local INI_PATH_CANDIDATES = {
    "ue4ss/Mods/LivingBase/spawn_menu.ini",
    "Mods/LivingBase/spawn_menu.ini",
    "spawn_menu.ini",
}

local function resolve_ini_path()
    for _, p in ipairs(INI_PATH_CANDIDATES) do
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end
    return INI_PATH_CANDIDATES[1]
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

-- Returns a set of "ROSTER:index" strings already present anywhere in the file, regardless of
-- which section path they currently live under -- this is what makes re-running safe after the
-- user has renamed/moved sections by hand.
local function existing_roster_indices(content)
    local seen = {}
    if not content then return seen end
    local roster, index
    for line in content:gmatch("[^\r\n]+") do
        local r = line:match("^%s*roster%s*=%s*(.-)%s*$")
        if r then roster = r end
        local i = line:match("^%s*index%s*=%s*(%d+)%s*$")
        if i then index = tonumber(i) end
        if line:match("^%s*%[") then
            -- New section starting -- reset until we see roster/index again inside it.
            roster, index = nil, nil
        end
        if roster and index then
            seen[roster .. ":" .. index] = true
        end
    end
    return seen
end

local function ini_escape_section(path_parts)
    return table.concat(path_parts, ".")
end

-- Senkamati (Config.SENKAMATI_LOOKS) row -> a display path, mirroring testbed.lua's own
-- senkaShortKey grouping logic (name/kind/helmet/idle) so the generated tree lines up with what
-- the roster actually contains. Kept deliberately plain/mechanical -- see this file's header.
local function senkamati_path_and_label(s)
    local sub
    if s.kind == "corrupted" then
        sub = "As Original"
    elseif s.kind == "mob" then
        sub = "Mob Body"
    else -- "crew"
        sub = s.baseLabel and ("Crew Reskin (" .. s.baseLabel .. ")") or "Crew Reskin"
    end

    local leaf
    if s.kind == "corrupted" then
        leaf = s.idle and "Frozen" or "Wandering"
    else
        leaf = (s.helmet and "Helmet On" or "Helmet Off") .. (s.idle and " (Frozen)" or "")
    end

    return {"Senkamati", s.name, sub}, leaf
end

-- Short class name out of a statue row's /Game/... `path` -- e.g. ".../BP_AnimatedActor_BotC_
-- Merchant_01.BP_AnimatedActor_BotC_Merchant_01_C" -> "BP_AnimatedActor_BotC_Merchant_01_C". Same
-- pattern testbed.lua's own (private) statueEntryName uses for its by-name lookup key, and
-- main.lua's SPAWN_MENU_HANDLERS reconstructs independently for the same reason (see that file's
-- own comment) -- kept as a small duplicate here rather than threading a cross-module dependency
-- through this generator for one string pattern.
local function short_class_name(path)
    return tostring(path):match("([%w_]+)%.[%w_]+$") or tostring(path)
end

-- Statue row ({faction, path}) -> a display path/leaf, shared by all four statue rosters --
-- `treeLabel` picks which top-level branch (Standing/Seated/Chair/Interactive) a given roster
-- generates under.
local function statue_path_and_label(treeLabel)
    return function(w)
        return {treeLabel, tostring(w.faction)}, short_class_name(w.path)
    end
end

local function townsfolk_path_and_label(cls)
    return {"Townsfolk"}, cls.name
end

local function crew_path_and_label(entry)
    return {"Crew", tostring(entry.faction or "Other")}, entry.name
end

-- Most decor categories map to ONE path segment under "Decor" (a plain string). The 18
-- invdrop_<theme> categories (2026-08-17, see fkeys.lua's own comment on `invdrop_animalparts` for
-- the full history -- hand-curated from RedFalcon's spreadsheet review, replacing the earlier
-- folder-shaped grouping entirely) need a SECOND level -- everything grouped under one shared
-- "Drops" branch, with the theme (Animal Parts/Weapons/Currency/...) as its own sub-branch -- so
-- their labels are a TABLE of path segments instead of a bare string. decor_path_and_label below
-- handles either shape.
local DECOR_CATEGORY_LABELS = {
    nature = "Nature", boats = "Boats", wrecks = "Wrecks",
    tents = "Tents & Bedrolls", storage = "Storage Clutter", furniture = "Furniture",
    invdrop_animalparts = {"Drops", "Animal Parts"},
    invdrop_artifacts = {"Drops", "Artifacts"},
    invdrop_clothes = {"Drops", "Clothes"},
    invdrop_currency = {"Drops", "Currency"},
    invdrop_ingredients = {"Drops", "Ingredients"},
    invdrop_keys = {"Drops", "Keys"},
    invdrop_meals = {"Drops", "Meals"},
    invdrop_mined = {"Drops", "Mined"},
    invdrop_misc = {"Drops", "Misc"},
    invdrop_potions = {"Drops", "Potions, Bottles, and Healing"},
    invdrop_seeds = {"Drops", "Seeds"},
    invdrop_tailoring = {"Drops", "Tailoring"},
    invdrop_tools = {"Drops", "Tools"},
    invdrop_treasure = {"Drops", "Treasure"},
    invdrop_trophies = {"Drops", "Trophies"},
    invdrop_weapons = {"Drops", "Weapons"},
    invdrop_wood = {"Drops", "Wood"},
    invdrop_writings = {"Drops", "Writings"},
}

-- Decor lives in per-category sub-tables (Config.DECOR_CATEGORIES[key]), not one flat array like
-- every other roster here -- flatten it into one ordered list (DECOR_ORDER, then each category's
-- own item order) so the append/index machinery below (which assumes `rows[i]`) works unchanged.
-- main.lua's SPAWN_MENU_HANDLERS rebuilds this EXACT SAME flattening (same order) to translate an
-- index back to an entry -- keep both in sync if this ordering ever changes.
local function decor_rows(Config)
    local rows = {}
    for _, catKey in ipairs(Config.DECOR_ORDER or {}) do
        for _, d in ipairs((Config.DECOR_CATEGORIES or {})[catKey] or {}) do
            rows[#rows + 1] = {entry = d, category = catKey}
        end
    end
    return rows
end
local function decor_path_and_label(row)
    local label = DECOR_CATEGORY_LABELS[row.category] or row.category
    local path = {"Decor"}
    if type(label) == "table" then
        for _, seg in ipairs(label) do path[#path + 1] = seg end
    else
        path[#path + 1] = label
    end
    -- `label` (2026-08-17): a hand-picked "Proper Name" (e.g. "Bezoar") some entries now carry
    -- alongside `name` (the system identifier, e.g. "Loot_T02_Bezoar_01") -- prefer it for the tree
    -- leaf a player actually sees; `name` still has to be what's written as the roster lookup value
    -- elsewhere, unrelated to this display text.
    return path, row.entry.label or row.entry.name
end

-- Livestock is spread across five separate Config tables -- flatten the same way as decor above,
-- same "main.lua's handler must rebuild this exact order" caveat applies.
local LIVESTOCK_SOURCES = {
    {key = "BOARS", label = "Boar"}, {key = "GOATS", label = "Goat"}, {key = "DODOS", label = "Dodo"},
    {key = "WOLVES", label = "Wolf"}, {key = "CROCODILES", label = "Crocodile"},
}
local function livestock_rows(Config)
    local rows = {}
    for _, src in ipairs(LIVESTOCK_SOURCES) do
        for _, e in ipairs(Config[src.key] or {}) do
            rows[#rows + 1] = {entry = e, label = src.label}
        end
    end
    return rows
end
local function livestock_path_and_label(row)
    return {"Animals", row.label}, row.entry.name
end

-- Walking women (Config.FEMALE_RESKIN_TARGETS) -- a flat list of plain name strings, not rows with
-- their own sub-fields like every other roster here, so each row IS the name (e.g. "Letty Base 1").
-- Splits the "<Character> Base <N>" suffix into a subfolder per character with "Base 1"/"Base 2" as
-- the two leaves, mirroring testbed.lua's own femaleBaseClassFor split. Falls back to a bare leaf
-- under "Walking Women" for any name that doesn't match the suffix pattern, so this never silently
-- drops an entry if the roster's naming convention ever changes.
local function walking_women_path_and_label(name)
    local charName, baseNum = tostring(name):match("^(.*) Base (%d+)$")
    if charName then
        return {"Walking Women", charName}, "Base " .. baseNum
    end
    return {"Walking Women"}, tostring(name)
end

-- Roster descriptors: name (matches the `roster =` value written out and used to look entries
-- back up), the rows to walk, and a function turning one row into (path_parts, leaf_label). Add
-- more entries here to extend generation to another roster -- the append/never-clobber mechanics
-- below are already generic, only this list needs to grow.
local function roster_descriptors(Config)
    return {
        {name = "SENKAMATI_LOOKS", rows = Config.SENKAMATI_LOOKS, path_and_label = senkamati_path_and_label},
        {name = "STANDING_STATUES", rows = Config.STANDING_STATUES, path_and_label = statue_path_and_label("Standing")},
        {name = "SEATED_STATUES", rows = Config.SEATED_STATUES, path_and_label = statue_path_and_label("Seated")},
        {name = "CHAIR_STATUES", rows = Config.CHAIR_STATUES, path_and_label = statue_path_and_label("Chair")},
        {name = "INTERACTIVE_STATUES", rows = Config.INTERACTIVE_STATUES, path_and_label = statue_path_and_label("Interactive")},
        {name = "TOWNSFOLK_CLASSES", rows = Config.TOWNSFOLK_CLASSES, path_and_label = townsfolk_path_and_label},
        {name = "FACTION_VISITOR_LOOKS", rows = Config.FACTION_VISITOR_LOOKS, path_and_label = crew_path_and_label},
        {name = "DECOR", rows = decor_rows(Config), path_and_label = decor_path_and_label},
        {name = "LIVESTOCK", rows = livestock_rows(Config), path_and_label = livestock_path_and_label},
        {name = "FEMALE_RESKIN_TARGETS", rows = Config.FEMALE_RESKIN_TARGETS, path_and_label = walking_women_path_and_label},
    }
end

function M.GenerateOnce(Config)
    local ini_path = resolve_ini_path()
    local existing_content = read_file(ini_path)
    local seen = existing_roster_indices(existing_content)

    local appended = {}
    for _, descriptor in ipairs(roster_descriptors(Config)) do
        for i, row in ipairs(descriptor.rows or {}) do
            local key = descriptor.name .. ":" .. i
            if not seen[key] then
                local path_parts, leaf_label = descriptor.path_and_label(row)
                table.insert(path_parts, leaf_label)
                table.insert(appended, string.format(
                    "[%s]\nlabel = %s\nroster = %s\nindex = %d\n\n",
                    ini_escape_section(path_parts), leaf_label, descriptor.name, i))
                seen[key] = true
            end
        end
    end

    if #appended == 0 then
        return 0
    end

    local f = io.open(ini_path, "a")
    if not f then
        print("[LivingBase] spawnmenu_manifest: failed to open " .. ini_path .. " for append\n")
        return 0
    end
    if not existing_content then
        f:write("; Auto-generated + hand-curated by you. Re-running LivingBase only ADDS missing\n")
        f:write("; roster/index entries -- it never touches or removes anything already here, so\n")
        f:write("; reorganize/rename freely.\n\n")
    end
    for _, section in ipairs(appended) do
        f:write(section)
    end
    f:close()

    print("[LivingBase] spawnmenu_manifest: added " .. #appended .. " new entr" ..
        (#appended == 1 and "y" or "ies") .. " to " .. ini_path .. "\n")
    return #appended
end

return M
