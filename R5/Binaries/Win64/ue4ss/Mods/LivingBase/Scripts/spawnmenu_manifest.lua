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

-- M.ReadLabels() -- the read-back counterpart to GenerateOnce (2026-08-19, RedFalcon's request):
-- returns { [roster] = { [index] = curatedLabel } } for every section in spawn_menu.ini, so a
-- hand-renamed tree entry ("Tort Combatant 1") can become the ACTUAL runtime spawn label (toast/
-- target-name/persist.txt), not just something the ImGui tree displays and Lua never sees again.
-- Deliberately still no real INI parser -- same per-line pattern-match approach
-- existing_roster_indices already uses, just also capturing `label` per section instead of only
-- roster/index. Safe to call from anywhere that only needs Config (main.lua, after Testbed/Config/
-- Spawner are all loaded) -- this function itself touches neither, so it carries none of
-- GenerateOnce's "can only see Config, never require('testbed')" circular-require constraint (see
-- this file's own header).
function M.ReadLabels()
    local content = read_file(resolve_ini_path())
    local out = {}
    if not content then return out end
    local roster, index, label
    local function commit()
        if roster and index and label then
            out[roster] = out[roster] or {}
            out[roster][index] = label
        end
    end
    for line in content:gmatch("[^\r\n]+") do
        if line:match("^%s*%[") then
            commit()
            roster, index, label = nil, nil, nil
        else
            local l = line:match("^%s*label%s*=%s*(.-)%s*$")
            if l then label = l end
            local r = line:match("^%s*roster%s*=%s*(.-)%s*$")
            if r then roster = r end
            local i = line:match("^%s*index%s*=%s*(%d+)%s*$")
            if i then index = tonumber(i) end
        end
    end
    commit()
    return out
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

-- Monsterous > Standing > <name> (2026-09-20) -- Config.MONSTEROUS_STANDING's own root category,
-- deliberately separate from statue_path_and_label("Standing")'s People-tree branch (see that
-- Config table's own comment). Rows carry an explicit `label` (Ghost Pirate) since a generic
-- monster name is worth a real curated leaf from the start, not the raw class-name fallback every
-- OTHER statue roster's mechanical default settles for.
-- menuPath override (2026-09-24, same mechanism mobile_quest_npc_path_and_label already uses) --
-- Ghost Pirate's row now sets menuPath = {"Monsterous", "Ghost Pirate"} so its Idle entry lands in
-- the SAME subcategory as its Mobile counterpart (MOBILE_QUEST_NPCS' own menuPath, updated to
-- match) instead of two separate Standing/Walkers homes. Rows without an explicit menuPath keep the
-- plain default.
local function monsterous_standing_path_and_label(row)
    if row.menuPath then return row.menuPath, row.label or short_class_name(row.path) end
    return {"Monsterous", "Standing"}, row.label or short_class_name(row.path)
end

-- "Mobile" named-NPC spawns -> People.Named.<label> by default, or row.menuPath verbatim when a
-- row needs its own home (Sailor -> People.Walkers, Ghost Pirate -> Monsterous.Walkers -- see
-- Config.MOBILE_QUEST_NPCS' own comment). Always uses row.label as the leaf, never a class-name
-- fallback -- this roster's whole design requires an explicit label per row (see that Config
-- table's comment on why FriendlyLabels can't be reused here).
local function mobile_quest_npc_path_and_label(row)
    if row.menuPath then return row.menuPath, row.label end
    return {"People", "Named"}, row.label
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
    -- NewItems.xlsx batch (2026-09-25) new categories:
    -- NewItems.xlsx batch fixup: new items for EXISTING Drops themes:
    new_drops_animal_parts = {"Drops", "Animal Parts"},
    new_drops_artifacts = {"Drops", "Artifacts"},
    new_drops_clothes = {"Drops", "Clothes"},
    new_drops_currency = {"Drops", "Currency"},
    new_drops_ingredients = {"Drops", "Ingredients"},
    new_drops_meals = {"Drops", "Meals"},
    new_drops_mined = {"Drops", "Mined"},
    new_drops_misc = {"Drops", "Misc"},
    new_drops_potions_bottles_and_healing = {"Drops", "Potions, Bottles, and Healing"},
    new_drops_tailoring = {"Drops", "Tailoring"},
    new_drops_tools = {"Drops", "Tools"},
    new_drops_treasure = {"Drops", "Treasure"},
    new_drops_weapons = {"Drops", "Weapons"},
    new_drops_wood = {"Drops", "Wood"},
    new_drops_writings = {"Drops", "Writings"},
    new_campfires = "Campfires",
    new_clutter_dishes_clay = {"Clutter", "Dishes - Clay"},
    new_clutter_dishes_metal = {"Clutter", "Dishes - Metal"},
    new_clutter_dishes_wood = {"Clutter", "Dishes - Wood"},
    new_clutter_light_sources = {"Clutter", "Light Sources"},
    new_clutter_misc = {"Clutter", "Misc"},
    new_clutter_water_goods = {"Clutter", "Water Goods"},
    new_dead = "Dead",
    new_drops_belt_bags = {"Drops", "Belt Bags"},
    new_drops_bones = {"Drops", "Bones"},
    new_furniture_beds = {"Furniture", "Beds"},
    new_furniture_benches = {"Furniture", "Benches"},
    new_furniture_tables = {"Furniture", "Tables"},
    new_furniture_wardrobes = {"Furniture", "Wardrobes"},
    new_misc_animals = {"Misc", "Animals"},
    new_misc_effects = {"Misc", "Effects"},
    new_plants_coast = {"Plants", "Coast"},
    new_plants_corrupted = {"Plants", "Corrupted"},
    new_plants_highlands = {"Plants", "Highlands"},
    new_plants_jungle = {"Plants", "Jungle"},
    new_plants_ruin_overgrowth = {"Plants", "Ruin Overgrowth"},
    new_plants_swamp = {"Plants", "Swamp"},
    new_plants_trees = {"Plants", "Trees"},
    new_senkamati = "Senkamati",
    new_stockade_flooring = {"Stockade", "Flooring"},
    new_stockade_structural = {"Stockade", "Structural"},
    new_stockade_wall = {"Stockade", "Wall"},
    new_storage_bales = {"Storage", "Bales"},
    new_storage_barrels = {"Storage", "Barrels"},
    new_storage_basins = {"Storage", "Basins"},
    new_storage_baskets = {"Storage", "Baskets"},
    new_storage_chests = {"Storage", "Chests"},
    new_storage_crates = {"Storage", "Crates"},
    new_storage_other = {"Storage", "Other"},
    new_structural_fences = {"Structural", "Fences"},
    new_structural_ladders = {"Structural", "Ladders"},
    new_structural_misc = {"Structural", "Misc"},
    new_tents_and_coverings_awnings = {"Tents and Coverings", "Awnings"},
    new_tents_and_coverings_canopies = {"Tents and Coverings", "Canopies"},
    new_tents_and_coverings_enclosures = {"Tents and Coverings", "Enclosures"},
    new_tents_and_coverings_tents = {"Tents and Coverings", "Tents"},
    new_terrain_minerals_and_resources = {"Terrain", "Minerals and Resources"},
    new_terrain_rocks = {"Terrain", "Rocks"},
    new_terrain_rocks_and_boulders = {"Terrain", "Rocks and Boulders"},
    new_terrain_shipwrecks = {"Terrain", "Shipwrecks"},
    new_terrain_statues = {"Terrain", "Statues"},
    new_terrain_wood = {"Terrain", "Wood"},
    new_workbenches_alchemy = {"Workbenches", "Alchemy"},
    new_workbenches_armor = {"Workbenches", "Armor"},
    new_workbenches_blacksmith = {"Workbenches", "Blacksmith"},
    new_workbenches_cooking = {"Workbenches", "Cooking"},
    new_workbenches_farming = {"Workbenches", "Farming"},
    new_workbenches_fishing = {"Workbenches", "Fishing"},
    new_workbenches_jeweler = {"Workbenches", "Jeweler"},
    new_workbenches_utility = {"Workbenches", "Utility"},
    new_workbenches_workbench = {"Workbenches", "Workbench"},
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

-- MONSTEROUS_MOBS (2026-09-25): Monsterous > Basic/Boss/Corrupted, per-row `sub` field.
local function monsterous_mobs_path_and_label(row)
    return {"Monsterous", row.sub or "Basic"}, row.name
end
-- CRABS (2026-09-25): Animals > Crabs.
local function crabs_path_and_label(row)
    return {"Animals", "Crabs"}, row.name
end
-- NEW_PEOPLE (2026-09-25, second pass): People > Crew/Walkers/Leaning/Named/Standing, per-row `sub`.
local function new_people_path_and_label(row)
    return {"People", row.sub or "Named"}, row.label or row.name
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

-- Custom > Poses > <Top Category> > <Subcategory> > <Name> (2026-08-27) -- Config.CUSTOM_POSES
-- rows already carry their own topCategory/subCategory/name fields (imported straight from
-- Other\Poses.xlsx), so this is a near-identity mapping -- the only real work is nesting under a
-- shared "Custom.Poses" branch and omitting the subcategory segment when a row has none (Magic/
-- Statues/Misc sheets have no subcategory column at all). Unlike every other roster here, this
-- one's SPAWN_MENU_HANDLERS entry (main.lua) doesn't spawn anything -- it applies the pose to
-- whatever's already targeted -- so there's nothing new for undo/despawn/persist.txt to track;
-- see that handler's own comment.
-- subCategory as a LIST (2026-09-21, RedFalcon's "additional poses" tab, config.lua's
-- Config.CUSTOM_POSES header) -- the first rows needing more than one nesting level under
-- topCategory ("Food and Meds" > "Drink"). Existing rows are unaffected: a plain string still
-- appends exactly one segment, same as before.
local function custom_poses_path_and_label(row)
    local path = {"Custom", "Poses", row.topCategory}
    if type(row.subCategory) == "table" then
        for _, seg in ipairs(row.subCategory) do
            path[#path + 1] = seg
        end
    elseif row.subCategory and row.subCategory ~= "" then
        path[#path + 1] = row.subCategory
    end
    return path, row.name
end

-- Custom > Skin Tones (2026-08-28) -- Config.CUSTOM_SKIN_TONES is a flat name list (same shape as
-- Config.FEMALE_RESKIN_TARGETS above), so this mirrors walking_women_path_and_label's simplicity --
-- no subcategory nesting needed, the family name IS the leaf.
local function custom_skin_tones_path_and_label(name)
    return {"Custom", "Skin Tones"}, tostring(name)
end

-- Custom > Hair > Default|Hat|Headband|Bandana > <Style> (2026-08-28, RedFalcon: "sub categorize
-- Hat and No Hat" -- expanded same day to all four real variants once RedFalcon caught Marita's
-- own Bandana-variant hairstyle missing from the original two-way split; see Config.CUSTOM_HAIR's
-- own comment in config.lua for the full story). Config.CUSTOM_HAIR rows already carry `variant`
-- as a plain string -- the only real work is using it as the subcategory name directly.
local function custom_hair_path_and_label(row)
    return {"Custom", "Hair", row.variant}, row.name
end

-- Custom > Clothes > <Family> > <Slot> > <Name> (2026-08-28). Config.CUSTOM_CLOTHES rows already
-- carry family/slot/name -- straightforward three-level nest, one deeper than hair's since
-- clothing genuinely has both a family AND a slot axis, not just one style axis.
local function custom_clothes_path_and_label(row)
    return {"Custom", "Clothes", row.family, row.slot}, row.name
end

-- Custom > Clothes > Remove > <Slot|All> (2026-08-28). Config.CLOTHES_REMOVE rows carry just
-- `slot` -- a flat one-level list under its own "Remove" branch, sibling to the per-family
-- branches above.
local function custom_clothes_remove_path_and_label(row)
    return {"Custom", "Clothes", "Remove"}, row.slot
end

-- Custom > Hair > Remove > <Slot|All> (2026-09-09). Config.HAIR_REMOVE rows carry just `slot`
-- ("Hair"/"Whiskers"/"Beard"/"Mustache"/"All") -- same flat one-level-under-its-own-"Remove"-branch
-- shape as Clothes > Remove above, but sibling to Hair's own Default/Hat/Headband/Bandana
-- hairstyle-picker subcategories instead of Clothes' per-family branches. Deliberately a SEPARATE
-- roster from CLOTHES_REMOVE -- see Spawner.RemoveHairOnActor's own comment for why.
local function custom_hair_remove_path_and_label(row)
    return {"Custom", "Hair", "Remove"}, row.slot
end

-- Custom > Face > <Family> > <Slot> > <Name> (2026-08-28). Same three-level nest as Clothes,
-- since facial pieces genuinely have both a family (style) AND a slot (Eyebrows/Beard/Mustache/
-- Whiskers) axis.
local function custom_facial_path_and_label(row)
    return {"Custom", "Face", row.family, row.slot}, row.name
end

-- Roster descriptors: name (matches the `roster =` value written out and used to look entries
-- back up), the rows to walk, and a function turning one row into (path_parts, leaf_label). Add
-- more entries here to extend generation to another roster -- the append/never-clobber mechanics
-- below are already generic, only this list needs to grow.
local function roster_descriptors(Config)
    return {
        {name = "CUSTOM_POSES", rows = Config.CUSTOM_POSES, path_and_label = custom_poses_path_and_label},
        {name = "SKIN_TONES", rows = Config.CUSTOM_SKIN_TONES, path_and_label = custom_skin_tones_path_and_label},
        {name = "HAIR", rows = Config.CUSTOM_HAIR, path_and_label = custom_hair_path_and_label},
        {name = "CLOTHES", rows = Config.CUSTOM_CLOTHES, path_and_label = custom_clothes_path_and_label},
        {name = "CLOTHES_REMOVE", rows = Config.CLOTHES_REMOVE, path_and_label = custom_clothes_remove_path_and_label},
        {name = "HAIR_REMOVE", rows = Config.HAIR_REMOVE, path_and_label = custom_hair_remove_path_and_label},
        {name = "FACIAL", rows = Config.CUSTOM_FACIAL, path_and_label = custom_facial_path_and_label},
        {name = "SENKAMATI_LOOKS", rows = Config.SENKAMATI_LOOKS, path_and_label = senkamati_path_and_label},
        {name = "STANDING_STATUES", rows = Config.STANDING_STATUES, path_and_label = statue_path_and_label("Standing")},
        {name = "SEATED_STATUES", rows = Config.SEATED_STATUES, path_and_label = statue_path_and_label("Seated")},
        {name = "CHAIR_STATUES", rows = Config.CHAIR_STATUES, path_and_label = statue_path_and_label("Chair")},
        {name = "INTERACTIVE_STATUES", rows = Config.INTERACTIVE_STATUES, path_and_label = statue_path_and_label("Interactive")},
        {name = "MONSTEROUS_STANDING", rows = Config.MONSTEROUS_STANDING, path_and_label = monsterous_standing_path_and_label},
        {name = "MOBILE_QUEST_NPCS", rows = Config.MOBILE_QUEST_NPCS, path_and_label = mobile_quest_npc_path_and_label},
        {name = "TOWNSFOLK_CLASSES", rows = Config.TOWNSFOLK_CLASSES, path_and_label = townsfolk_path_and_label},
        {name = "FACTION_VISITOR_LOOKS", rows = Config.FACTION_VISITOR_LOOKS, path_and_label = crew_path_and_label},
        {name = "DECOR", rows = decor_rows(Config), path_and_label = decor_path_and_label},
        {name = "LIVESTOCK", rows = livestock_rows(Config), path_and_label = livestock_path_and_label},
        {name = "FEMALE_RESKIN_TARGETS", rows = Config.FEMALE_RESKIN_TARGETS, path_and_label = walking_women_path_and_label},
        {name = "MONSTEROUS_MOBS", rows = Config.MONSTEROUS_MOBS, path_and_label = monsterous_mobs_path_and_label},
        {name = "CRABS", rows = Config.CRABS, path_and_label = crabs_path_and_label},
        {name = "NEW_PEOPLE", rows = Config.NEW_PEOPLE, path_and_label = new_people_path_and_label},
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
