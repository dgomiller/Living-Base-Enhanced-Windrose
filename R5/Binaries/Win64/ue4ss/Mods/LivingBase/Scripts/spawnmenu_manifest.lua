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

------------------------------------------------------------------------------------------------
-- Custom-*.ini drop-in content (2026-10-08, RedFalcon: let a sophisticated end user -- or a
-- tree-only content update -- add new poses/people/animals/monstrous/decor/signs without touching
-- the shipped spawn_menu.ini or needing a code/DLL change). Any file matching "Custom-*.ini" next
-- to spawn_menu.ini is scanned at startup, parsed into rows, and fed through the SAME
-- roster_descriptors/GenerateOnce machinery below as every built-in roster -- so tree-building,
-- the append-only "never clobber a hand-renamed section" discipline, and spawn_menu.ini's own
-- format are all reused as-is, nothing new to learn there.
--
-- `type = pose` rows always land under Custom > Poses > Custom > <category> (alongside the
-- built-in Standing/Battle/... branches in that same Poses tree); every other `type` lands on the
-- MAIN spawn tree under Custom > <People|Decor|Signs|Monstrous|Animals> > <category> (RedFalcon,
-- 2026-10-08: "Add Custom on the main spawn screen... automatically add a 2nd tier based on type
-- and then the ini can decide on sub tree entries").
--
-- Each discovered file becomes TWO synthetic rosters (one SPAWN, one POSE), not one -- a single
-- file is allowed to mix pose rows with spawn rows, but main.lua's NON_SPAWNING_ROSTERS REPLACE-
-- safety guard is keyed by roster NAME, not by row, so a mixed roster would let a pose row's
-- REPLACE button incorrectly destroy-then-recreate whatever's targeted. Splitting by kind keeps
-- that guard correct without main.lua needing to inspect row contents itself.
------------------------------------------------------------------------------------------------

local function ini_dir(ini_path)
    return ini_path:match("^(.*[/\\])[^/\\]+$") or ""
end

-- No real directory listing (2026-10-08, 2nd fix): BOTH io.popen (produced nothing, no error) and
-- os.execute + temp file (the command verified correct when run manually from the game's own
-- working directory, but still read back 0 files live -- os.execute very likely doesn't block
-- until the spawned process finishes in this sandbox, so the temp file was read before `dir` had
-- written it) failed to actually list files in this UE4SS Lua sandbox. Dropping shelling out
-- entirely: a small index file (CustomFilesIndex.txt, one filename per line, a ';'-prefixed line
-- is a comment) lists which Custom-*.ini files to load, read with the exact same plain io.open
-- pattern already used everywhere else in this codebase (spawn_menu.ini itself included) -- the
-- one thing proven reliable so far. One extra step for the end user (add the filename to the
-- index after creating their ini), but it actually works.
local function list_custom_ini_files(ini_path)
    local dir = ini_dir(ini_path)
    local indexPath = dir .. "CustomFilesIndex.txt"
    local content = read_file(indexPath)
    local files = {}
    if not content then
        return files
    end
    for line in content:gmatch("[^\r\n]+") do
        local name = line:match("^%s*(.-)%s*$")
        if name and name ~= "" and name:sub(1, 1) ~= ";" then
            local fullPath = dir .. name
            local probe = io.open(fullPath, "r")
            if probe then
                probe:close()
                files[#files + 1] = fullPath
            else
                print("[LivingBase] spawnmenu_manifest: CustomFilesIndex.txt lists '" .. name .. "' but that file was not found at " .. fullPath .. "\n")
            end
        end
    end
    table.sort(files)
    return files
end

-- Uppercase-only, no digits (2026-10-08 fix): main.lua's spawn_request.txt parser matches roster
-- names against `(%u[%u_]*)` -- uppercase letters and underscores ONLY, same convention every
-- built-in roster name (CUSTOM_POSES, DECOR, LIVESTOCK, ...) already follows. A filename's mixed
-- case (and any digit) broke that match outright ("malformed spawn_request.txt"), so both are
-- normalized away here rather than relaxing that regex, keeping every roster name in the same
-- shape everywhere.
local function sanitize_roster_name(path)
    local base = tostring(path):match("([^/\\]+)%.ini$") or tostring(path)
    base = base:upper()
    return (base:gsub("[^%u]", "_"))
end

-- display_name_for_file(path) (2026-10-09, RedFalcon: "use whatever is after the Custom- as the
-- name of the custom thing... that keeps each download its own thing so its easier to know
-- whats what") -- the human-readable branch name a file's own content groups under in the tree,
-- as opposed to sanitize_roster_name's all-caps/no-punctuation ROSTER name above (an internal
-- spawn_request.txt identifier, never shown to the player). Keeps case and punctuation from the
-- filename itself -- "Custom-DansStuff.ini" -> "DansStuff" -- since this IS the display text.
local function display_name_for_file(path)
    local base = tostring(path):match("([^/\\]+)%.ini$") or tostring(path)
    return base:match("^Custom%-(.+)$") or base
end

-- One Custom-*.ini file -> (spawnRows, poseRows). Same per-line pattern-match parsing style as
-- existing_roster_indices/ReadLabels above -- this file never needed a real INI parser, and a
-- user-authored file is no different.
local function parse_custom_ini_file(path)
    local content = read_file(path)
    local spawnRows, poseRows = {}, {}
    if not content then return spawnRows, poseRows end
    local row
    local function commit()
        -- `kind = effect` (2026-10-09, RedFalcon: "can it be either actor or mesh, like the
        -- others" re: Decor > Misc > Effects' invisible-actor-plus-niagara items) -- `path` is
        -- normally required (see the check below), but an effect row's real content is `fx`, not
        -- `path`; default `path` to the native NiagaraActor class (the SAME bare actor Decor >
        -- Misc > Water's built-in fx entries already use, see fkeys.lua's own `fx =` rows) so an
        -- ini author can omit it entirely.
        if row and row.kind == "effect" and not row.path then row.path = "/Script/Niagara.NiagaraActor" end
        if row and row.path and row.type then
            if row.type == "pose" then
                poseRows[#poseRows + 1] = row
            else
                spawnRows[#spawnRows + 1] = row
            end
        end
    end
    for line in content:gmatch("[^\r\n]+") do
        local sectionName = line:match("^%s*%[(.-)%]%s*$")
        if sectionName then
            commit()
            row = { name = sectionName }
        elseif row then
            local k, v = line:match("^%s*([%a_]+)%s*=%s*(.-)%s*$")
            if k and v and v ~= "" then
                if k == "type" then row.type = v:lower()
                elseif k == "path" then row.path = v
                elseif k == "category" then row.category = v
                elseif k == "label" then row.label = v
                elseif k == "idle" then row.idle = (v:lower() == "true" or v == "1")
                -- `kind` (2026-10-08, decor/sign only): "actor" (default, path is a Blueprint class
                -- -- Spawner.Spawn(path) directly) vs "mesh" (path is a bare /Game/... static mesh
                -- -- spawned as a generic R5LootActor wrapper, same recipe Testbed.TestSpawnDropMesh
                -- already uses for console-tested mesh paths) vs "effect" (2026-10-09, RedFalcon:
                -- "in decor > Misc > Effects we have some items that apply an effects item to an
                -- invisible actor... I'd like to add that as an option to the custom spawning" --
                -- spawns the native NiagaraActor and attaches the `fx` field's Niagara System asset,
                -- same recipe Decor > Misc > Water's built-in fx entries already use via fkeys.lua's
                -- `fx =` rows + testbed.lua's placeDecorEntry). Explicit field, not auto-detected
                -- from the path string (RedFalcon: "i think the explicit is better").
                elseif k == "kind" then row.kind = v:lower()
                -- `fx` (2026-10-09, `kind = effect` only): the Niagara System asset path attached
                -- to the spawned NiagaraActor's NiagaraComponent -- see the `kind` comment above.
                elseif k == "fx" then row.fx = v
                -- `solid` (2026-10-08): per-entry collision override, either direction, winning over
                -- the global Config.DECOR_COLLISION default -- see placeDecorEntry's own comment.
                elseif k == "solid" then row.solid = (v:lower() == "true" or v == "1")
                -- Sign text-layout fields (2026-10-08, `type = sign` only, all optional) -- same
                -- x/y/z/depth/yaw/pitch/roll/bw/bh/size/rows names `lbtestsigntext` already reports
                -- back when tuning an existing sign live, so transcribing tuned numbers into a
                -- Custom-*.ini row is the exact same step as every built-in entry in signs.lua's own
                -- Signs.TYPES already went through (RedFalcon: "shouldn't signs have options for the
                -- different sizes and directions needed for the text?"). Untuned fields fall back to
                -- generic defaults in main.lua's Signs.RegisterType call -- the sign still gets text,
                -- just not necessarily well-placed, until tuned.
                elseif k == "x" then row.anchorX = tonumber(v)
                elseif k == "y" then row.anchorY = tonumber(v)
                elseif k == "z" then row.anchorZ = tonumber(v)
                elseif k == "depth" then row.depth = tonumber(v)
                elseif k == "yaw" then row.yaw = tonumber(v)
                elseif k == "pitch" then row.pitch = tonumber(v)
                elseif k == "roll" then row.roll = tonumber(v)
                elseif k == "bw" then row.boardW = tonumber(v)
                elseif k == "bh" then row.boardH = tonumber(v)
                elseif k == "marginX" then row.marginX = tonumber(v)
                elseif k == "marginY" then row.marginY = tonumber(v)
                elseif k == "size" then row.maxSize = tonumber(v)
                elseif k == "rows" then row.rows = tonumber(v)
                end
            end
        end
    end
    commit()
    return spawnRows, poseRows
end

-- Auto-derived 2nd tier under Custom (RedFalcon's "automatically add a 2nd tier based on type") --
-- the ini only ever supplies `category` (everything from here down); it never names this heading.
local CUSTOM_FILE_TYPE_HEADINGS = {
    decor = "Decor", sign = "Signs", people = "People",
    monstrous = "Monstrous", animals = "Animals",
}

local function split_category(category)
    local parts = {}
    if category and category ~= "" then
        for seg in category:gmatch("[^>]+") do
            local trimmed = seg:match("^%s*(.-)%s*$")
            if trimmed ~= "" then parts[#parts + 1] = trimmed end
        end
    end
    return parts
end

-- Top-level root is "Custom Content", NOT "Custom" (2026-10-08 fix): SpawnMenu.cpp has a
-- hardcoded `if (child->label == "Custom") continue;` in its main tree draw loop (added
-- 2026-09-16 to hide the old Poses/SkinTones/Hair/Clothes branch, which moved to its own tab) --
-- a literal "Custom" top-level section is permanently invisible there regardless of what's under
-- it, confirmed by reading that file directly. Any other name avoids the collision with no C++
-- change needed. Pose entries are unaffected -- they live under "Custom.Poses.*", a different
-- top-level root ("Custom" there is 2 levels down, not the top-level label checked).
-- Grouped by SOURCE FILE first, then type (2026-10-09, RedFalcon: "use whatever is after the
-- Custom- as the name of the custom thing... Custom-DansStuff would become Custom Content >
-- DanStuff, then split by type... keeps each download its own thing so its easier to know whats
-- what") -- `fileDisplayName` (display_name_for_file's own output, passed down from
-- build_custom_block's loop, which has the source path d.rows doesn't carry on each row) is its
-- own path segment ABOVE the type heading, so every entry from one Custom-*.ini file stays
-- together under one named branch instead of getting scattered across the shared Decor/Signs/
-- People/etc branches alongside every other installed pack's content.
-- `type = handitem` is a DIFFERENT top-level destination from every other spawn type: it lives
-- in the Custom tab's own "Custom > Hand > <file> > <category>" tree (SpawnMenu::
-- GetHandItemsTree(), same shape as GetPosesTree()), not the main tree's "Custom Content" root --
-- a hand item is never "spawned" through the normal roster:index dispatch at all, it's applied by
-- the C++ Hand tree's own "+" button writing a HANDITEM: request with the leaf's label (the
-- friendlyName) directly. `category` becomes the item's TYPE grouping (Weapons/Tools/Bottles/
-- Other, or whatever a custom row names) -- note this is ONE path segment, not split_category'd,
-- matching how Config.SOCKETITEMS_TOOLS' own `type` field is used.
local function custom_spawn_path_and_label(row, fileDisplayName)
    if row.type == "handitem" then
        return { "Custom", "Hand", fileDisplayName or "Custom", row.category or "Custom" }, row.label or row.name
    end
    local path = { "Custom Content", fileDisplayName or "Custom", CUSTOM_FILE_TYPE_HEADINGS[row.type] or "Misc" }
    for _, seg in ipairs(split_category(row.category)) do path[#path + 1] = seg end
    return path, row.label or row.name
end

local function custom_pose_path_and_label(row, fileDisplayName)
    local path = { "Custom", "Poses", fileDisplayName or "Custom" }
    for _, seg in ipairs(split_category(row.category)) do path[#path + 1] = seg end
    return path, row.label or row.name
end

-- Built-in hand items (2026-10-08): Config.SOCKETITEMS_TOOLS (config.lua, the Other\
-- SocketItems.xlsx "Tools" tab) already has exactly the shape this tree needs --
-- {friendlyName, type, asset} -- generated here for the FIRST time into spawn_menu.ini under
-- "Custom > Hand > <type>", same append-only mechanics as every other built-in roster. This is
-- what let SpawnMenu.cpp's old hardcoded Weapons/Tools/Bottles/Other C++ arrays (copy-pasted from
-- this exact table, needing manual re-sync) be deleted entirely.
local function hand_item_path_and_label(row)
    return { "Custom", "Hand", row.type }, row.friendlyName
end

-- Computed once per Lua session (same one-time-read assumption spawn_menu.ini itself already
-- relies on elsewhere in this file -- a hand-edited Custom-*.ini needs a restart to take effect).
-- Shared by GenerateOnce below (tree-building) and main.lua's M.CustomFileDescriptors() (handler
-- registration) so the file list is only scanned/parsed once.
local cachedCustomFileDescriptors = nil
local function custom_file_descriptors()
    if cachedCustomFileDescriptors then return cachedCustomFileDescriptors end
    local found = list_custom_ini_files(resolve_ini_path())
    print("[LivingBase] spawnmenu_manifest: scanning for Custom-*.ini -- found " .. #found .. " file(s)\n")
    local out = {}
    for _, path in ipairs(found) do
        local base = sanitize_roster_name(path)
        local displayName = display_name_for_file(path)
        local spawnRows, poseRows = parse_custom_ini_file(path)
        print("[LivingBase] spawnmenu_manifest:   " .. path .. " -> " .. #spawnRows .. " spawn row(s), " .. #poseRows .. " pose row(s)\n")
        if #spawnRows > 0 then
            out[#out + 1] = { name = "CUSTOMFILE_" .. base .. "_SPAWN", rows = spawnRows,
                path_and_label = custom_spawn_path_and_label, kind = "SPAWN", displayName = displayName }
        end
        if #poseRows > 0 then
            out[#out + 1] = { name = "CUSTOMFILE_" .. base .. "_POSE", rows = poseRows,
                path_and_label = custom_pose_path_and_label, kind = "POSE", displayName = displayName }
        end
    end
    cachedCustomFileDescriptors = out
    return out
end

-- Exposed so main.lua can register one spawn-menu handler per discovered file/kind without
-- re-parsing every Custom-*.ini itself.
function M.CustomFileDescriptors()
    return custom_file_descriptors()
end

-- M.ForceRescan() (2026-10-09, RedFalcon: the Spawn Tree's new Update button -- "make it so it
-- pulls in the customs every time"). Drops the memoized descriptor cache so the NEXT
-- custom_file_descriptors() call (via CustomFileDescriptors() or GenerateOnce's own internal use)
-- actually re-reads every listed Custom-*.ini file from disk instead of returning what was there
-- at Lua startup. Caller still has to call M.GenerateOnce(Config) afterward to actually rewrite
-- spawn_menu.ini's custom block from the fresh scan -- this alone only clears the cache.
function M.ForceRescan()
    cachedCustomFileDescriptors = nil
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
    new_misc_water = {"Misc", "Water"},
    new_furniture_tables_more = {"Furniture", "Tables"},
    new_furniture_shelving = {"Furniture", "Shelving"},
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
-- LIVESTOCK_IDLE (2026-09-25) added as a 6th, TRAILING source -- appended last so every existing
-- family's flattened index above it is untouched (see Config.LIVESTOCK_IDLE's own header comment
-- in config.lua). It has no fixed `label` of its own (its rows span all 5 families) -- each row's
-- own `family` field is used instead, checked in livestock_path_and_label below.
local LIVESTOCK_SOURCES = {
    {key = "BOARS", label = "Boar"}, {key = "GOATS", label = "Goat"}, {key = "DODOS", label = "Dodo"},
    {key = "WOLVES", label = "Wolf"}, {key = "CROCODILES", label = "Crocodile"},
    {key = "LIVESTOCK_IDLE", label = nil},
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
    return {"Animals", row.entry.family or row.label}, row.entry.name
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
-- SENKAMATI_ORIGINAL_UPRIGHT (2026-09-25, RedFalcon: "People > Senkamati > Original Upright >
-- Mask On/Off > Type (Idle/Mobile)") -- a NEW branch under "People > Senkamati", distinct from
-- senkamati_path_and_label's own existing top-level "Senkamati" (Mob Body/Crew Reskin/As Original)
-- -- the two are not merged. Mask On/Off is the top split under "Original Upright"; the archetype +
-- Idle/Mobile becomes the leaf text underneath it.
local function original_upright_path_and_label(row)
    local maskGroup = row.showHelmet and "Mask On" or "Mask Off"
    local leaf = row.archetype .. (row.idlePose and " (Idle)" or " (Mobile)")
    return {"People", "Senkamati", "Original Upright", maskGroup}, leaf
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
    local list = {
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
        {name = "SENKAMATI_ORIGINAL_UPRIGHT", rows = Config.SENKAMATI_ORIGINAL_UPRIGHT, path_and_label = original_upright_path_and_label},
        {name = "HAND_ITEMS", rows = Config.SOCKETITEMS_TOOLS, path_and_label = hand_item_path_and_label},
    }
    return list
end

-- Custom-*.ini content gets its OWN rewrite path (rewrite_custom_block below), fully rebuilt every
-- launch instead of append-only like every roster above -- RedFalcon (2026-10-08): "is it possible
-- to keep the ini dynamic vs hardcoding the custom ini into it? It's not very user friendly
-- otherwise." Safe to do because nobody hand-edits this block (its category/label already come
-- straight from the user's own Custom-*.ini, which IS the thing they hand-edit -- there's nothing
-- here for the append-only "preserve a hand-rename" rule to protect) and because Spawner.Spawn
-- persists by resolved class path, not by roster:index, so freely reordering/renaming entries in a
-- Custom-*.ini file never corrupts anything already placed in the world.
local CUSTOM_BLOCK_BEGIN = "; ===== BEGIN CUSTOM-INI CONTENT (auto-generated from Custom-*.ini files, fully rebuilt every launch -- edit the Custom-*.ini files, not this block) ====="
local CUSTOM_BLOCK_END = "; ===== END CUSTOM-INI CONTENT ====="

local function build_custom_block()
    local lines = { CUSTOM_BLOCK_BEGIN, "" }
    for _, d in ipairs(custom_file_descriptors()) do
        for i, row in ipairs(d.rows) do
            local path_parts, leaf_label = d.path_and_label(row, d.displayName)
            table.insert(path_parts, leaf_label)
            lines[#lines + 1] = string.format("[%s]\nlabel = %s\nroster = %s\nindex = %d\n",
                ini_escape_section(path_parts), leaf_label, d.name, i)
        end
    end
    lines[#lines + 1] = CUSTOM_BLOCK_END
    return table.concat(lines, "\n") .. "\n"
end

-- Strips any previous custom-ini block (by exact marker text, plain-text find -- these markers
-- contain no Lua pattern metacharacters that matter here, but plain=true is used anyway since
-- parentheses in the text would otherwise need escaping) and writes a fresh one reflecting
-- whatever custom_file_descriptors() returns RIGHT NOW. A no-op (no file write at all) when
-- there's neither an old block to remove nor any custom files currently discovered.
local function rewrite_custom_block(ini_path)
    local content = read_file(ini_path)
    local hasBlock = content and content:find(CUSTOM_BLOCK_BEGIN, 1, true)
    local descriptors = custom_file_descriptors()
    if not hasBlock and #descriptors == 0 then
        return
    end
    content = content or ""
    if hasBlock then
        local beginIdx = content:find(CUSTOM_BLOCK_BEGIN, 1, true)
        local endIdx = content:find(CUSTOM_BLOCK_END, beginIdx, true)
        if endIdx then
            content = content:sub(1, beginIdx - 1) .. content:sub(endIdx + #CUSTOM_BLOCK_END)
        end
    end
    content = content:gsub("%s+$", "")
    local f = io.open(ini_path, "w")
    if not f then
        print("[LivingBase] spawnmenu_manifest: failed to open " .. ini_path .. " to rewrite custom-ini block\n")
        return
    end
    if #descriptors > 0 then
        f:write(content .. "\n\n" .. build_custom_block())
        local rowCount = 0
        for _, d in ipairs(descriptors) do rowCount = rowCount + #d.rows end
        print("[LivingBase] spawnmenu_manifest: wrote " .. rowCount .. " custom-ini entr" ..
            (rowCount == 1 and "y" or "ies") .. " across " .. #descriptors .. " roster(s) into " .. ini_path .. "\n")
    else
        f:write(content .. "\n")
        print("[LivingBase] spawnmenu_manifest: no Custom-*.ini content found -- removed old custom-ini block from " .. ini_path .. "\n")
    end
    f:close()
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

    if #appended > 0 then
        local f = io.open(ini_path, "a")
        if not f then
            print("[LivingBase] spawnmenu_manifest: failed to open " .. ini_path .. " for append\n")
        else
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
        end
    end

    -- Custom-*.ini content: fully rebuilt every launch, see rewrite_custom_block's own comment.
    rewrite_custom_block(ini_path)

    return #appended
end

return M
