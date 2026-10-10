-- signs.lua (2026-09-29) -- editable text on sign objects, up to 4 rows. Self-contained: main.lua only
-- does `require("signs").Install(Spawner)`; nothing here adds a file-level local to main/spawner
-- (both sit at Lua's 200-local ceiling).
--
-- Inspired by the behaviour of the third-party "WindroseTextSigns" mod (observed only from its README/
-- log -- its DLL was never decompiled); the implementation here is our own: hide the sign's picture
-- component, then attach one TextRenderComponent per row to the actor.
--
-- Data for the first entry comes from a real lbprobe/lbprobedump of a placed Wooden Label (2026-09-29):
--   class  BP_BuildingBlock_WallPlaqueT02_0N_C (parent R5BuildingBlock)
--   frame  component "StaticMesh" (SM_WallPlaqueT02_01) at the actor origin
--   picture component "Plane" (engine BasicShapes/Plane, MI_DD_PlaqueSign_01) at rel (11.83, 0, -0.16),
--          rot (P0,Y-90,R90), scale 0.36 -> a ~36x36uu picture facing +X; collision NoCollision.
--
-- lbtestsigntext <Line1|Line2|Line3|Line4> [yaw]   -- applies to the last lbprobe'd actor
-- lbtestsigntext clear                              -- removes our text, restores the picture

local Signs = {}

-- ---------------------------------------------------------------------------------------------
-- The sign list. One row per sign type; adding a sign later = adding one entry here.
--   match     class-name prefix tested against the actor's class name
--   hide      names of picture components to hide while text is shown
--   anchor    text-plane centre, relative to the actor root (uu)
--   yaw       text yaw relative to the actor (0 = faces the actor's +X)
--   boardW/H  full picture area (uu)
--   marginX/Y empty border kept on EACH side (uu) -- the writable part of a board is smaller than its
--             picture area, so text is sized to (boardW-2*marginX) x (boardH-2*marginY). Tune live with
--             `lbsignmargin <x> [y]`.
--   anchor    surface point the text is centred on, relative to the actor root (uu)
--   depth     how far in FRONT of that point the text floats, along the facing direction `yaw` (uu).
--             Tune live with `lbtestsigntext ... depth=<n>` (`x=` is an alias).
--   color     ink colour (R,G,B,A 0-255)
--   maxSize   largest world text size allowed (uu)
-- ---------------------------------------------------------------------------------------------
Signs.TYPES = {
    {
        name    = "Wooden Label (Wall Plaque T02)",
        match   = "BP_BuildingBlock_WallPlaque",
        hide    = { "Plane" },
        anchor  = { x = 0.0, y = 0.0, z = 0.0 },   -- the surface point (the label's own origin)
        depth   = 11.8,                            -- how far out in front of it the text sits, along `yaw`
        yaw     = 0.0,
        -- Whole plaque, estimated from a live screenshot at margin 0 (2026-09-29): ~62x41uu. The 36uu
        -- "picture" plane is much smaller than the board. Margin keeps text off the rim/screws/wavy edge.
        boardW  = 62.0,
        boardH  = 41.0,
        marginX = 2.0,
        marginY = 2.0,
        color   = { R = 25, G = 15, B = 5, A = 255 },
        maxSize = 100.0,
    },
    -- ---------------------------------------------------------------------------------------------
    -- Storage containers (2026-09-29). They have NO sign component of their own; RedFalcon placed real
    -- wooden labels on them as scale/position references and `lbsignscan` measured each label in the
    -- container's own frame -- anchor = the label's origin, yaw = its facing (all +X except the bag's 15
    -- degrees), depth = the wall label's 11.8 to start with (tune per container with `lbtestsigntext ...
    -- depth=<n>`). Yellow ink by default (dark brown was hard to read on the wood). Board is the label's size (62x41). Nothing to hide -- there is no picture.
    -- Box and bale have room to spare, so they get a taller area and a looser row pitch; the barrel and
    -- bag are curved, so they get a bigger margin to keep text off the bend.
    -- ---------------------------------------------------------------------------------------------
    { name = "Wooden Chest 01", match = "BP_Storage_WoodenChest_01_C", hide = {},
      anchor = { x = 29.1, y = 1.7, z = 23.9 }, depth = 1.0, yaw = 0.0,
      boardW = 62.0, boardH = 41.0, marginX = 2.0, marginY = 2.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Wooden Chest 04", match = "BP_Storage_WoodenChest_04_C", hide = {},
      anchor = { x = 29.1, y = -0.7, z = 17.9 }, depth = -1.0, yaw = 0.0,
      boardW = 62.0, boardH = 41.0, marginX = 2.0, marginY = 2.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Wooden Chest 08", match = "BP_Storage_WoodenChest_08_C", hide = {},
      anchor = { x = 33.8, y = 1.1, z = 20.4 }, depth = 3.0, yaw = 0.0,
      boardW = 62.0, boardH = 41.0, marginX = 2.0, marginY = 2.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Medium Chest", match = "BP_Storage_MediumChest_C", hide = {},
      anchor = { x = 29.0, y = 1.5, z = 19.2 }, depth = -1.0, yaw = 0.0,
      boardW = 62.0, boardH = 41.0, marginX = 2.0, marginY = 2.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Medium Bale", match = "BP_Storage_MediumBale_C", hide = {},
      anchor = { x = 40.4, y = -3.4, z = 46.5 }, depth = 8.0, yaw = 0.0,
      boardW = 70.0, boardH = 52.0, marginX = 3.0, marginY = 3.0, rowStep = 1.4, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Medium Box", match = "BP_Storage_MediumBox_C", hide = {},
      anchor = { x = 47.7, y = 0.5, z = 48.0 }, depth = -1.5, yaw = 0.0,
      boardW = 70.0, boardH = 52.0, marginX = 3.0, marginY = 3.0, rowStep = 1.4, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Medium Barrel", match = "BP_Storage_MediumBarrel_C", hide = {},
      anchor = { x = 45.5, y = -2.5, z = 55.9 }, depth = 1.0, yaw = 0.0,
      boardW = 62.0, boardH = 41.0, marginX = 6.0, marginY = 3.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Decor Bag", match = "BP_Storage_DecorBag_01_C", hide = {},
      anchor = { x = 36.7, y = 5.9, z = 75.0 }, depth = -10.0, yaw = 15.0,
      boardW = 62.0, boardH = 41.0, marginX = 6.0, marginY = 3.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    -- Sign Post (the SignCacheTMP pole sign, spawned from the Signs tab's Special Items). The game will NOT let a wooden label be
    -- placed on it (labels only snap to building pieces), so there is no label to measure with `lbsignscan`. STARTING GUESS only:
    -- the anchor began as an earlier stray label's position (~103uu above the post's base) converted into the post's own frame; now tuned. Tune by
    -- eye: `lbtestsigntext <text> depth=<n> y=<n> z=<n> yaw=<n> bw=<board width> bh=<board height>`, then send me the numbers.
    { name = "Sign Post", match = "BP_SignCacheTMP_01_C", hide = {},
      -- Tuned live by RedFalcon 2026-09-30 (y=5 z=-4 on the starting anchor; depth=-6 yaw=0 roll=-8 bw=80 bh=40 size=25).
      anchor = { x = 19.7, y = -0.1, z = 98.9 }, depth = -6.0, yaw = 0.0, roll = -8.0,
      boardW = 80.0, boardH = 30.0, marginX = 4.0, marginY = 3.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },  -- high on purpose: the fit (board size minus margins) decides the size, not this cap
    -- ---------------------------------------------------------------------------------------------
    -- Raw loot-mesh pieces (2026-09-30, RedFalcon; spawned from the Text tab's Additional Items). They are all R5LootActor, so each type also
    -- matches on `mesh` (the static mesh's short name). `rows` limits the text to that many lines (the one-line boards).
    -- FIRST GUESSES from `lbprobe` bounds, assuming every face looks along the actor's +X with its width along Y (the banner and boards 04/05 get
    -- a base rotation to line up, see Config.LOOT_MESH_BASE_ROT): anchor = centre-in-actor-frame with x moved out to the front surface, board =
    -- ~90% of the face. If the text lands on the back, flip `depth` negative / `yaw` 180. Tune by eye with `lbtestsigntext depth= y= z= yaw=
    -- pitch= roll= bw= bh= size=` and send me the numbers.
    -- ---------------------------------------------------------------------------------------------
    -- (2nd pass 2026-10-01: Flag 3 z -22, Board 2 z +2 bh 35 size 40, Board 3 bh 50, Obelisk bh 100.) TUNED LIVE by RedFalcon 2026-10-01 with `lbtestsigntext` and baked in here: anchor = the old anchor + his y/z offsets, depth = his x, board = bw x bh,
    -- maxSize = his size= (where given), pitch for the obelisk. The Pirate Banner was removed (not conducive to writing); its mesh base rotation stays in
    -- Config.LOOT_MESH_BASE_ROT so any banner already placed in a world still restores upright. Boards 2 and 3 also carry a mesh shift out of the wall
    -- (Config.LOOT_MESH_BASE_OFFSET); Signs.MeshShift() adds it to the anchor so the text always follows the mesh.
    { name = "Wall Flag 1", match = "R5LootActor", mesh = "SM_FlagWall_01", hide = {},
      anchor = { x = 10.7, y = 2.6, z = -1.0 }, depth = -2.0, yaw = 0.0,
      boardW = 90.0, boardH = 60.0, marginX = 3.0, marginY = 3.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Wall Flag 2", match = "R5LootActor", mesh = "SM_FlagWall_02", hide = {},
      anchor = { x = 17.8, y = 1.0, z = 2.7 }, depth = -6.0, yaw = 0.0,
      boardW = 80.0, boardH = 100.0, marginX = 3.0, marginY = 3.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Wall Flag 3", match = "R5LootActor", mesh = "SM_FlagWall_03", hide = {},
      anchor = { x = 15.7, y = 0.6, z = -10.4 }, depth = -6.0, yaw = 0.0,
      boardW = 95.0, boardH = 65.0, marginX = 3.0, marginY = 3.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Wall Flag 4", match = "R5LootActor", mesh = "SM_FlagWall_04", hide = {},
      anchor = { x = 15.1, y = -6.7, z = -14.3 }, depth = -6.0, yaw = 0.0,
      boardW = 140.0, boardH = 60.0, marginX = 4.0, marginY = 3.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Board 1 (One line)", match = "R5LootActor", mesh = "SM_WoodElements_01_Board02", hide = {}, rows = 1,
      anchor = { x = 10.6, y = 0.0, z = 15.2 }, depth = -3.0, yaw = 0.0,
      boardW = 600.0, boardH = 45.0, marginX = 6.0, marginY = 4.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Board 2 (One line)", match = "R5LootActor", mesh = "SM_WoodElements_01_Board04", hide = {}, rows = 1,
      anchor = { x = 3.8, y = 0.5, z = -4.0 }, depth = 1.0, yaw = 0.0,
      boardW = 190.0, boardH = 35.0, marginX = 5.0, marginY = 3.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Board 3 (One line)", match = "R5LootActor", mesh = "SM_WoodElements_01_Board05", hide = {}, rows = 1,
      anchor = { x = 1.4, y = 0.5, z = -5.5 }, depth = -1.0, yaw = 0.0,
      boardW = 300.0, boardH = 50.0, marginX = 8.0, marginY = 5.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
    { name = "Obelisk", match = "R5LootActor", mesh = "SM_Obelisk", hide = {},
      anchor = { x = 116.4, y = 0.0, z = -28.9 }, depth = -15.0, yaw = 0.0, pitch = 11.0,
      boardW = 180.0, boardH = 100.0, marginX = 8.0, marginY = 8.0, color = { R = 242, G = 217, B = 38, A = 255 }, maxSize = 100.0 },
}

-- Exported (2026-10-08, Custom-*.ini drop-in content, `type = sign`): lets main.lua register a
-- text-layout entry for a user-added sign item the exact same shape as every entry above, without
-- this file needing to know anything about the custom-ini loader. Tune a fresh entry live with
-- `lbtestsigntext ... depth= y= z= yaw= pitch= roll= bw= bh= size=` the same way every entry above
-- was tuned, then put the final numbers in the Custom-*.ini row -- see that file's own comment on
-- the x/y/z/depth/yaw/pitch/roll/bw/bh/size/rows field names it accepts.
function Signs.RegisterType(t)
    -- Replace-by-name, not append (2026-10-09, RedFalcon's Spawn Tree Update button -- custom
    -- content can now be re-registered live, not just once at startup) -- without this, clicking
    -- Update repeatedly on an unchanged Custom-*.ini sign row would pile up duplicate TYPES
    -- entries forever (harmless for matching, since FindType just uses the first hit, but pure
    -- waste). A genuinely new sign (different name) still just appends as before.
    for i = #Signs.TYPES, 1, -1 do
        if Signs.TYPES[i].name == t.name then table.remove(Signs.TYPES, i) end
    end
    table.insert(Signs.TYPES, t)
end

Signs.FONT     = "/Engine/EngineFonts/RobotoDistanceField"
-- "Glow" (2026-09-29, RedFalcon: text should ignore darkness when a checkbox is ticked). The default text
-- material darkens with scene lighting; a glowing sign swaps in an UNLIT / emissive material instead.
-- Which engine materials exist in this shipping build isn't known ahead of time, so these candidates
-- are tried in order at runtime and the one used is logged (`[signs] glow material = ...`). Add a path
-- here (or reorder) once a run shows which one really renders unlit.
Signs.GLOW_MATERIALS = {
    "/Engine/EngineMaterials/DefaultTextMaterialTranslucent",
    "/Engine/EngineMaterials/EmissiveMeshMaterial",
    "/Engine/EngineDebugMaterials/VertexColorMaterial",
    "/Engine/EngineMaterials/DefaultLightFunctionMaterial",
    "/Engine/EngineMaterials/DefaultTextMaterialOpaque",
}

-- Full-bright light tuning (see the FULL BRIGHT block in Signs.Apply). Offset is how far in front of the text (uu).
Signs.GLOW_INTENSITY = 800.0
Signs.GLOW_RADIUS    = 500.0
Signs.GLOW_OFFSET    = 30.0
Signs.GLOW_FALLOFF   = 0.0   -- falloff exponent, only used when GLOW_INVSQ is false: 0 = flat, 2 = steep
-- Settled by RedFalcon live (2026-09-29): `lbsignglow 800 500 30 0 0` -- a flat, wide light. It is safe to be
-- wide because the light is masked to the text (lighting channel 2 only) AND has its indirect/Lumen bounce
-- zeroed, so it does not light the surroundings; flat falloff removes the centre-to-edge gradient.
Signs.GLOW_INVSQ     = false

Signs.MIN_ANY_APPLY_GAP = 0.5   -- seconds between applies on ANY sign (crash guard, see Signs.Apply)
Signs.MIN_APPLY_GAP = 0.6   -- seconds between text rebuilds on the same actor (crash guard, see Signs.Apply)
-- IN-PLACE EDITS are OFF unless Config.SIGNS_IN_PLACE = true (2026-10-01). The in-place path calls K2_SetRelativeLocationAndRotation(..., false, {}, true) on every
-- text row of every re-apply, passing an empty Lua table as the out-struct hit result. On stock UE4SS the game then died in UE4SS.dll's Lua table reads
-- (+0x9347f0, garbage RAX that was ASCII text = a freed table) on the 2nd-5th re-apply of the same sign, every time. Rebuilding the pieces is the
-- older, slower path that does not use that call.
do
    local okC, cfg = pcall(require, "config")
    if not (okC and type(cfg) == "table" and cfg.SIGNS_IN_PLACE == true) then Signs._inPlaceOK = false end
end
-- Per-font letter-spacing adjustment (see Signs.Apply). Empty until tuned by eye with `lbtestsigntext ... spacing=<n>`.
Signs.FONT_SPACING = {
    ["/Game/Mods/LivingBaseExtended/Fonts/F_SignScriptOleo"] = -15,   -- Script (Oleo): its letters are designed to overlap, so it wants to be pulled together
    ["/Game/Mods/LivingBaseExtended/Fonts/F_SignGreengoth"] = -1,    -- Greengoth
}
-- Per-font line pitch (multiples of the text size). Starting guesses from RedFalcon's screenshots: Oleo overlapped at 1.25.
-- Tune with `lbtestsigntext ... font=<path> rowstep=<n>`.
Signs.FONT_ROWSTEP = {
    ["/Game/Mods/LivingBaseExtended/Fonts/F_SignScriptOleo"] = 0.7,    -- Script (Oleo)
    ["/Game/Mods/LivingBaseExtended/Fonts/F_SignGreengoth"] = 0.8,    -- Greengoth
    ["/Engine/EngineFonts/RobotoDistanceField"] = 0.9,    -- Built-in
}

-- Per-font vertical metrics (2026-09-29, RedFalcon: script fonts bleed into the next line and the block hangs off the bottom
-- of the board). extent = how tall a line of this font REALLY is, as a multiple of the text size (Roboto = 1.0; script fonts'
-- loops/tails reach well past it) -- used by the fit so the whole block stays on the board. vshift = shift of the whole block
-- as a multiple of the text size, + = up. Tune with `lbtestsigntext ... font=<path> extent=<n> vshift=<n>`.
Signs.FONT_METRICS = {
    ["/Game/Mods/LivingBaseExtended/Fonts/F_SignScriptOleo"] = { extent = 1.0, vshift = 0.0 },   -- Script (Oleo): tuned live by RedFalcon 2026-09-30
    ["/Game/Mods/LivingBaseExtended/Fonts/F_SignGreengoth"] = { extent = 1.0, vshift = 0.1 },   -- Greengoth: extent tuned live; vshift kept at its starting value
    ["/Engine/EngineFonts/RobotoDistanceField"] = { extent = 0.0, vshift = 0.1 },   -- Built-in (the game's default font): tuned live by RedFalcon
}

-- Per-FONT adjustments that apply to EVERY sign (2026-10-01, RedFalcon, after testing the other fonts: "a general change to how the font is applied"), keyed by
-- font asset path like the tables above. dz = extra Z offset in uu added to the text block; maxSize = the largest size that font may be rendered at (it only ever
-- LOWERS the size -- a sign whose own cap or fit is already smaller is untouched; an explicit size= still wins). Script (Oleo) sits 3uu too low; the built-in
-- Roboto font runs too large at the big sizes (Board 1 fitted to 40, wanted 25).
Signs.FONT_TUNE = {
    ["/Game/Mods/LivingBaseExtended/Fonts/F_SignScriptOleo"] = { dz = 3.0 },   -- Script (Oleo)
    ["/Engine/EngineFonts/RobotoDistanceField"] = { maxSize = 25.0 },           -- Built-in
}

-- The fonts a sign can use (2026-09-29, RedFalcon: "one font in one place and the default font in another").
-- key is what is saved per sign and sent by the Signs tab; path = nil means the game's own default text font. The
-- two non-default fonts ship in the optional LivingBaseSignFonts pak (see FONT_CREDITS.txt); if it is not installed
-- Signs.Apply falls back to the default font. Keep the order/keys in step with SignMenu.cpp's kFontKeys.
Signs.FONTS = {
    { key = "builtin",   label = "Built-in",      path = nil },
    { key = "greengoth", label = "Greengoth",     path = "/Game/Mods/LivingBaseExtended/Fonts/F_SignGreengoth" },
    { key = "oleo",      label = "Script (Oleo)", path = "/Game/Mods/LivingBaseExtended/Fonts/F_SignScriptOleo" },
}
-- Greengoth is the default (RedFalcon, 2026-09-29): a sign with no font chosen uses it; if the optional font pak is
-- missing the font fails to load and Signs.Apply quietly uses the built-in font instead.
Signs.DEFAULT_FONT_KEY = "greengoth"
function Signs.FontPath(key)
    for _, f in ipairs(Signs.FONTS) do if f.key == key then return f.path end end
    return nil
end

Signs.MAX_ROWS = 4
Signs.CHAR_W   = 0.62   -- average glyph width as a fraction of world size (Roboto-ish)
Signs.ROW_STEP = 1.25   -- row pitch as a multiple of world size
Signs._applied = {}     -- [actorKey] = { comps = {...}, hidden = {...} }

local function say(msg, Ar)
    print("[LivingBase] [signs] " .. tostring(msg) .. "\n")
    pcall(function()
        if type(Ar) == "userdata" and Ar.type and Ar:type() == "FOutputDevice" then Ar:Log(tostring(msg)) end
    end)
end

local function actorKey(actor)
    local k = "?"
    pcall(function() k = actor:GetFullName() end)
    return k
end

local function className(actor)
    local n = ""
    pcall(function() n = actor:GetClass():GetFName():ToString() end)
    return n
end

-- Short name of the static mesh on a raw loot-mesh actor (R5LootActor + SetLootMesh); nil when there is none.
local function lootMeshName(actor)
    local n
    pcall(function()
        local mc = actor.MeshComponent
        if mc and mc:IsValid() then
            local sm = mc.StaticMesh
            if sm and sm:IsValid() then n = sm:GetFName():ToString() end
        end
    end)
    return n
end

-- MeshShift (2026-10-01): Config.LOOT_MESH_BASE_OFFSET moves a loot-mesh component relative to its actor (see Spawner.SetLootMesh) -- used to pull Boards 2 and 3 out
-- of the wall they spawn inside. The text anchor must move with the mesh, so Apply adds this. Axes are the ACTOR frame: +X = out from the wall, +Y = right, +Z = up.
function Signs.MeshShift(t)
    local z = { X = 0.0, Y = 0.0, Z = 0.0 }
    local tbl = Signs._config and Signs._config.LOOT_MESH_BASE_OFFSET
    if not (t and t.mesh and type(tbl) == "table") then return z end
    for path, o in pairs(tbl) do
        if type(path) == "string" and path:match("%.([%w_]+)$") == t.mesh then
            return { X = o.X or 0.0, Y = o.Y or 0.0, Z = o.Z or 0.0 }
        end
    end
    return z
end

-- A type matches on the class-name prefix and, when it carries `mesh`, ALSO on the actor's static-mesh name -- the raw loot-mesh pieces all
-- share one class (R5LootActor), so the mesh is what tells a Wall Flag from a Board.
function Signs.FindType(actor)
    local cn = className(actor)
    local meshName
    for _, t in ipairs(Signs.TYPES) do
        if cn:sub(1, #t.match) == t.match then
            if not t.mesh then return t end
            if meshName == nil then meshName = lootMeshName(actor) or false end
            if meshName == t.mesh then return t end
        end
    end
    return nil
end

local function getComp(actor, name)
    local c
    pcall(function() c = actor[name] end)
    if c and c:IsValid() then return c end
    return nil
end

local function setHidden(comp, hidden)
    pcall(function() comp:SetVisibility(not hidden, false) end)
    pcall(function() comp:SetHiddenInGame(hidden, false) end)
end

-- Removes text we added and shows the picture again. Safe to call repeatedly.
function Signs.Clear(actor, keepLight)
    local key = actorKey(actor)
    local rec = Signs._applied[key]
    if not rec then return 0 end
    local n = 0
    -- The "ignore lighting" light lives in rec.light (NOT rec.comps). An internal re-apply keeps it (keepLight) so it is not
    -- destroyed and rebuilt on every text edit -- that render-state churn is the suspect in a game-side crash (2026-09-30).
    if not keepLight and rec.light then
        pcall(function() if rec.light:IsValid() then rec.light:K2_DestroyComponent(rec.light) ; n = n + 1 end end)
    end
    for _, c in ipairs(rec.comps) do
        pcall(function()
            if c:IsValid() then c:K2_DestroyComponent(c) ; n = n + 1 end
        end)
    end
    for _, name in ipairs(rec.hidden) do
        local pc = getComp(actor, name)
        if pc then setHidden(pc, false) end
    end
    Signs._applied[key] = nil
    return n
end

local function resolveGlowMaterial(override)
    local list = override and { override } or Signs.GLOW_MATERIALS
    for _, base in ipairs(list) do
        local name = base:match("([^/]+)$")
        local path = base .. "." .. name
        local m = StaticFindObject(path)
        if not (m and m:IsValid()) then
            pcall(function() LoadAsset(base) end)
            m = StaticFindObject(path)
        end
        if m and m:IsValid() then return m, path end
    end
    return nil
end

-- Rotation helpers (2026-09-30, RedFalcon: "rotate it around the x axis too as the sign is crooked"). UE's FRotator -> FQuat, same
-- formula the engine uses (roll about X applied first, then pitch about Y, then yaw about Z; angles in degrees).
function Signs.EulerQuat(pitch, yaw, roll)
    local hp, hy, hr = math.rad(pitch) / 2, math.rad(yaw) / 2, math.rad(roll) / 2
    local sp, cp, sy, cy, sr, cr = math.sin(hp), math.cos(hp), math.sin(hy), math.cos(hy), math.sin(hr), math.cos(hr)
    return {
        X =  cr * sp * sy - sr * cp * cy,
        Y = -cr * sp * cy - sr * cp * sy,
        Z =  cr * cp * sy - sr * sp * cy,
        W =  cr * cp * cy + sr * sp * sy,
    }
end
-- Rotate vector v = {x,y,z} by quaternion q = {X,Y,Z,W}.
function Signs.QuatRotate(q, v)
    local tx = 2 * (q.Y * v.z - q.Z * v.y)
    local ty = 2 * (q.Z * v.x - q.X * v.z)
    local tz = 2 * (q.X * v.y - q.Y * v.x)
    return {
        x = v.x + q.W * tx + (q.Y * tz - q.Z * ty),
        y = v.y + q.W * ty + (q.Z * tx - q.X * tz),
        z = v.z + q.W * tz + (q.X * ty - q.Y * tx),
    }
end

-- lines: array of up to 4 strings. Returns ok, message.
function Signs.Apply(actor, lines, opts)
    opts = opts or {}
    if not (actor and actor:IsValid()) then return false, "no valid actor" end
    local t = Signs.FindType(actor)
    if not t then return false, "actor class '" .. className(actor) .. "' is not in Signs.TYPES" end

    -- A font KEY (saved per sign / sent by the Signs tab) resolves to its path; an explicit opts.font (the test
    -- command's font=) still wins. Default key = no path = the game's default font.
    if not opts.font then opts.font = Signs.FontPath(opts.fontKey or Signs.DEFAULT_FONT_KEY) end

    -- RATE LIMIT (2026-09-29, RedFalcon: the game crashed when text position was adjusted very fast). Each Apply
    -- destroys the old text/light components and builds new ones; hammering it several times a second races the
    -- engine's own deferred cleanup. So one rebuild per actor per MIN_APPLY_GAP seconds; the internal fit pass
    -- (a second Apply on purpose) and restores (noSave) are exempt.
    if not opts._fitPass and not opts.noSave then
        local now = os.clock()
        Signs._lastApply = Signs._lastApply or {}
        local key = actorKey(actor)
        local last = Signs._lastApply[key]
        if last and (now - last) < Signs.MIN_APPLY_GAP then
            return false, string.format("too fast -- wait %.1fs between changes to the same sign", Signs.MIN_APPLY_GAP)
        end
        -- Also a short pause between ANY two applies, even on different signs (2026-09-30: the game crashed while text was being
        -- updated on several chests in a row) -- back-to-back rebuilds of text pieces on neighbouring actors are the same churn.
        if Signs._lastAnyApply and (now - Signs._lastAnyApply) < Signs.MIN_ANY_APPLY_GAP then
            return false, string.format("too fast -- wait a moment between changes (%.1fs)", Signs.MIN_ANY_APPLY_GAP)
        end
        Signs._lastAnyApply = now
        Signs._lastApply[key] = now
    end

    -- Drop empty trailing rows, cap to MAX_ROWS.
    local rows = {}
    for i = 1, math.min(#lines, t.rows or Signs.MAX_ROWS) do rows[i] = lines[i] end
    while #rows > 0 and (rows[#rows] == nil or rows[#rows] == "") do rows[#rows] = nil end
    if #rows == 0 then Signs.ClearKeepStyle(actor, opts.color, opts.glow, opts.fontKey) ; return true, "cleared (no text)" end

    local prevRec = Signs._applied[actorKey(actor)]
    local prevLight, prevLightSig = prevRec and prevRec.light, prevRec and prevRec.lightSig
    -- REUSE the existing text pieces when the row count is unchanged (2026-09-30). Four game-exe crashes today, all at the same
    -- address with NO UE4SS/Lua frame in the stack and a null `this`, each 6-24s after a sign apply -- i.e. the engine's own tick
    -- stepping on something we had just destroyed. Destroying and rebuilding every text piece on every edit (twice per edit with
    -- the auto-fit pass) is the only churn we cause, so edits now update the live pieces IN PLACE instead. Falls back to the old
    -- rebuild if the row count changed, a piece is invalid, or the in-place move is ever found not to work.
    local reuseComps = false
    if Signs._inPlaceOK ~= false and prevRec and #prevRec.comps == #rows and #rows > 0 then
        reuseComps = true
        for _, c in ipairs(prevRec.comps) do
            local okV, v = pcall(function() return c:IsValid() end)
            if not (okV and v) then reuseComps = false ; break end
        end
        if reuseComps and Signs._inPlaceOK == nil then
            -- one-time probe: does K2_SetRelativeLocationAndRotation work on these? (a no-op move to where it already is)
            local c1 = prevRec.comps[1]
            local okP = pcall(function()
                local l, r = c1.RelativeLocation, c1.RelativeRotation
                c1:K2_SetRelativeLocationAndRotation({ X = l.X, Y = l.Y, Z = l.Z }, { Pitch = r.Pitch, Yaw = r.Yaw, Roll = r.Roll }, false, {}, true)
            end)
            if okP then Signs._inPlaceOK = true else Signs._inPlaceOK = false ; reuseComps = false end
            say("in-place text update " .. (okP and "works -- reusing text pieces on edits" or "NOT available -- rebuilding on edits"))
        end
    end
    if not reuseComps then Signs.Clear(actor, true) end

    local cls = StaticFindObject("/Script/Engine.TextRenderComponent")
    if not (cls and cls:IsValid()) then return false, "TextRenderComponent class did not resolve" end

    -- Autosize: limited by the tallest row that fits and by the longest row's width.
    local n = #rows
    local maxLen = 1
    for _, r in ipairs(rows) do if #r > maxLen then maxLen = #r end end
    local usableW = math.max((opts.boardW or t.boardW) - 2 * (t.marginX or 0), 4.0)
    local usableH = math.max((opts.boardH or t.boardH) - 2 * (t.marginY or 0), 4.0)
    -- Line pitch: the test command's rowstep= wins, then a per-FONT value (script fonts have tall loops and long
    -- descenders and overlap at Roboto's 1.25), then the sign type's own, then the global default.
    local rowStep = opts.rowStep or (Signs.FONT_ROWSTEP and Signs.FONT_ROWSTEP[opts.font or Signs.FONT]) or t.rowStep or Signs.ROW_STEP
    local fm = (Signs.FONT_METRICS and Signs.FONT_METRICS[opts.font or Signs.FONT]) or {}
    local ft = (Signs.FONT_TUNE and Signs.FONT_TUNE[opts.font or Signs.FONT]) or nil   -- global per-font tuning (dz, maxSize)
    local extent = opts.extent or fm.extent or 1.0
    local vshift = opts.vshift or fm.vshift or 0.0
    local byHeight = usableH / ((n - 1) * rowStep + extent)
    -- Pass 1 starts from the height limit (capped by size= or the entry's maxSize); the real rendered
    -- width is then MEASURED (GetTextLocalSize) and the size shrunk to fit the margin -- width scales
    -- linearly with world size, so one correction is enough. `size=` is a CAP, never an override.
    local cap = opts.size or t.maxSize
    if not opts.size and ft and ft.maxSize and ft.maxSize < cap then cap = ft.maxSize end
    local size = math.max(math.min(byHeight, cap, opts._fitSize or 1e9), 1.0)
    local color = opts.color or t.color
    -- The colour picker (and saved data) are in normal screen (sRGB) values. TextRenderComponent's
    -- TextRenderColor is a plain byte colour the engine treats as LINEAR light and then gamma-encodes
    -- for display, so sending the sRGB bytes as-is comes out washed out / too light (RedFalcon's green
    -- swatch 38,153,51 showed as roughly 107,204,122). Convert to linear before writing.
    local function toLinearByte(v)
        local c = math.max(0, math.min(255, v)) / 255
        local l = (c <= 0.04045) and (c / 12.92) or (((c + 0.055) / 1.055) ^ 2.4)
        return math.floor(l * 255 + 0.5)
    end
    local glowMat, glowPath
    if opts.mat then glowMat, glowPath = resolveGlowMaterial(opts.mat) end  -- experimental only; see the Glow light below
    local ink = { R = toLinearByte(color.R), G = toLinearByte(color.G), B = toLinearByte(color.B), A = 255 }
    local step = size * rowStep
    local yaw = opts.yaw or t.yaw
    local hy = math.rad(yaw) / 2
    -- Depth is measured along the direction the text FACES (yaw), not along the actor's X axis, so it is
    -- correct for a container whose text points sideways (barrel, bag) as well as for the wall label.
    local depth = opts.depth or opts.x or t.depth or 0.0
    local dirx, diry = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
    local msh = Signs.MeshShift(t)
    local ax = t.anchor.x + msh.X + depth * dirx
    local ay = t.anchor.y + msh.Y + (opts.dy or 0.0) + depth * diry
    local az = t.anchor.z + msh.Z + (opts.dz or 0.0) + (ft and ft.dz or 0.0) + vshift * size
    -- Temporary diagnostic (2026-10-09, RedFalcon: a custom sign kept landing "at the default
    -- spot" despite a correctly-registered type -- narrowing down whether t.anchor/t.depth as
    -- actually live in Signs.TYPES match what the ini says, vs the Apply math itself).
    if opts.verbose then
        say(string.format("DIAG t.name=%s t.anchor=(%.2f,%.2f,%.2f) t.depth=%.2f t.yaw=%.2f msh=(%.2f,%.2f,%.2f) depth_used=%.2f -> ax,ay,az=(%.2f,%.2f,%.2f)",
            tostring(t.name), t.anchor.x, t.anchor.y, t.anchor.z, t.depth or 0.0, t.yaw or 0.0,
            msh.X, msh.Y, msh.Z, depth, ax, ay, az))
    end

    -- Tilt of the text plane: roll turns it about the direction it faces (so the lines follow a crooked board), pitch about the
    -- board's horizontal axis. The stacked rows are offset along the TILTED vertical, so the block tilts as one piece.
    local roll = opts.roll or t.roll or 0.0
    local pitch = opts.pitch or t.pitch or 0.0
    local qfull = Signs.EulerQuat(pitch, yaw, roll)

    if opts.mat then say("text material override = " .. tostring(glowPath or "NONE FOUND (glow has no effect)")) end
    local rec
    if reuseComps then
        rec = prevRec ; rec.lines = rows ; rec.yaw = opts.yaw
    else
        rec = { comps = {}, hidden = {}, lines = rows, yaw = opts.yaw, light = prevLight, lightSig = prevLightSig }
    end
    Signs._applied[actorKey(actor)] = rec

    for i, text in ipairs(rows) do
        local rowOff = ((n - 1) / 2 - (i - 1)) * step
        local z = az + rowOff
        local o = Signs.QuatRotate(qfull, { x = 0.0, y = 0.0, z = rowOff })
        local comp
        if reuseComps then
            comp = rec.comps[i]
            pcall(function()
                comp:K2_SetRelativeLocationAndRotation({ X = ax + o.x, Y = ay + o.y, Z = az + o.z },
                    { Pitch = pitch, Yaw = yaw, Roll = roll }, false, {}, true)
            end)
        else
            pcall(function()
                comp = actor:AddComponentByClass(cls, false, {
                    Rotation    = { W = qfull.W, X = qfull.X, Y = qfull.Y, Z = qfull.Z },
                    Translation = { X = ax + o.x, Y = ay + o.y, Z = az + o.z },
                    Scale3D     = { X = 1.0, Y = 1.0, Z = 1.0 },
                }, false)
            end)
            if not (comp and comp:IsValid()) then
                return false, "AddComponentByClass(TextRenderComponent) failed on row " .. i
            end
            rec.comps[#rec.comps + 1] = comp
        end

        local okText = pcall(function() comp:K2_SetText(FText(text)) end)
        if not okText then pcall(function() comp.Text = FText(text) end) end
        pcall(function() comp:SetWorldSize(size) end)
        pcall(function() comp.WorldSize = size end)
        -- Letter spacing (2026-09-29): UTextRenderComponent.HorizSpacingAdjust widens (+) or tightens (-) every
        -- gap. Baked offline fonts have no kerning pairs, so per-font spacing is tuned here: opts.spacing (test command)
        -- or Signs.FONT_SPACING[<font path>].
        do
            local sp = opts.spacing
            if sp == nil and Signs.FONT_SPACING then sp = Signs.FONT_SPACING[opts.font or Signs.FONT] end
            if sp then
                -- In the FONT'S pixel units (these fonts are baked 64px tall), so ~1 is invisible: try 4-10. Set through both the
                -- property and the component's own setter (the setter also refreshes the render state).
                -- The engine's real names are HorizSpacingAdjust / SetHorizSpacingAdjust (2026-09-30: the long-form
                -- 'HorizontalSpacingAdjustment' read back as a TrivialObject = not bound on this class, so nothing was set).
                pcall(function() comp.HorizSpacingAdjust = sp end)
                pcall(function() comp:SetHorizSpacingAdjust(sp) end)
            end
        end
        pcall(function() comp:SetHorizontalAlignment(1) end)   -- EHTA_Center
        pcall(function() comp:SetVerticalAlignment(1) end)     -- EVRTA_TextCenter
        pcall(function() comp:SetTextRenderColor(ink) end)
        pcall(function() comp.TextRenderColor = ink end)
        -- Default font is null -> engine default. Try the Roboto engine font explicitly.
        local fontName = "none"
        pcall(function()
            -- TextRenderComponent only draws OFFLINE fonts (baked glyph pages). Plain "Roboto" is a
            -- runtime font and renders nothing here; RobotoDistanceField is the engine's own default.
            local base = opts.font or Signs.FONT
            local path = base:find("%.") and base or (base .. "." .. base:match("([^/]+)$"))
            -- Full Package.Asset path + the project's own resolver (LoadAsset alone can't see /Game/Mods/ assets).
            local f = Signs._spawner and Signs._spawner.ResolveAsset and Signs._spawner.ResolveAsset(path)
            if not (f and f:IsValid()) then
                f = StaticFindObject(path)
            end
            if f and f:IsValid() then
                comp.Font = f
                pcall(function() comp:SetFont(f) end)   -- the setter also refreshes the render state; a bare property write may not
            else
                if not Signs._fontWarned then Signs._fontWarned = {} end
                if not Signs._fontWarned[path] then
                    Signs._fontWarned[path] = true
                    say("font did not load: " .. path .. " -- using the default font instead")
                end
            end
            local cur = comp.Font
            if cur and cur:IsValid() then fontName = cur:GetFullName() end
        end)
        if glowMat then
            pcall(function() comp.TextMaterial = glowMat end)
        end
        local mat = "none"
        pcall(function()
            local m = comp.TextMaterial
            if m and m:IsValid() then mat = m:GetFullName() end
        end)
        pcall(function() comp:SetVisibility(true, false) end)
        -- Make sure the component is registered (render state only exists for registered components).
        local reg0, reg1 = "?", "?"
        pcall(function() reg0 = tostring(comp:IsRegistered()) end)
        if reg0 == "false" then pcall(function() comp:RegisterComponent() end) end
        pcall(function() reg1 = tostring(comp:IsRegistered()) end)
        pcall(function() comp:MarkRenderStateDirty() end)

        if opts.verbose then
            local wl = "?"
            pcall(function()
                local l = comp:K2_GetComponentLocation()
                wl = string.format("(%.1f, %.1f, %.1f)", l.X, l.Y, l.Z)
            end)
            say(string.format("row %d '%s' size=%.2f z=%.2f world=%s setText=%s", i, text, size, z, wl, tostring(okText)))
            say("  font=" .. fontName .. "  material=" .. mat)
            local mob, rsc = "?", "?"
            pcall(function() mob = tostring(comp.Mobility) end)
            pcall(function() rsc = tostring(comp:IsRenderStateCreated()) end)
            say(string.format("  registered(before)=%s registered(after)=%s renderStateCreated=%s mobility=%s", reg0, reg1, rsc, mob))
            pcall(function()
                say(string.format("  bVisible=%s bHiddenInGame=%s worldSize=%s yawArg=%s", tostring(comp.bVisible), tostring(comp.bHiddenInGame), tostring(comp.WorldSize), tostring(yaw)))
            end)
            pcall(function()
                local ls = comp:GetTextLocalSize()
                local ws = comp:GetTextWorldSize()
                say(string.format("  textLocalSize=(%.2f,%.2f,%.2f) textWorldSize=(%.2f,%.2f,%.2f)", ls.X, ls.Y, ls.Z, ws.X, ws.Y, ws.Z))
            end)
            pcall(function() say("  HorizSpacingAdjust readback = " .. tostring(comp.HorizSpacingAdjust) .. " (asked for " .. tostring(opts.spacing) .. ")") end)
            pcall(function() say("  text readback='" .. tostring(comp.Text:ToString()) .. "' color=" .. tostring(comp.TextRenderColor.R) .. "," .. tostring(comp.TextRenderColor.G) .. "," .. tostring(comp.TextRenderColor.B)) end)
            pcall(function()
                local rr = comp:K2_GetComponentRotation()
                say(string.format("  world rot=(P%.1f Y%.1f R%.1f)", rr.Pitch, rr.Yaw, rr.Roll))
            end)
        end
    end

    -- Verify an in-place move really landed (2026-09-30); if it did not, never trust it again (next edit rebuilds).
    if reuseComps then
        local c1 = rec.comps[1]
        local off1 = Signs.QuatRotate(qfull, { x = 0.0, y = 0.0, z = ((n - 1) / 2) * step })
        local okL, l = pcall(function() return c1.RelativeLocation end)
        if okL and l then
            local dx, dy, dz = l.X - (ax + off1.x), l.Y - (ay + off1.y), l.Z - (az + off1.z)
            if (dx * dx + dy * dy + dz * dz) > 4.0 then
                Signs._inPlaceOK = false
                say(string.format("in-place move did not land (off by %.1fuu) -- switching back to rebuild-on-edit", math.sqrt(dx * dx + dy * dy + dz * dz)))
            end
        end
    end

    -- Measure and shrink to fit the margin (pass 1 only).
    if not opts._fitPass then
        local maxW = 0
        for _, c in ipairs(rec.comps) do
            pcall(function()
                local ls = c:GetTextLocalSize()
                if ls.Y > maxW then maxW = ls.Y end
            end)
        end
        if maxW > 0 and maxW > usableW + 0.05 then
            local fit = math.max(size * usableW / maxW, 1.0)
            if opts.verbose then say(string.format("measured width %.2f > usable %.2f at size %.2f -> refitting at %.2f", maxW, usableW, size, fit)) end
            local o2 = {}
            for k, v in pairs(opts) do o2[k] = v end
            o2._fitPass = true
            o2._fitSize = fit
            return Signs.Apply(actor, rows, o2)
        elseif opts.verbose then
            say(string.format("measured width %.2f fits usable %.2f at size %.2f", maxW, usableW, size))
        end
    end

    -- FULL BRIGHT (was "Glow"; 2026-09-29, RedFalcon: "a glow is not what I'm going for" -- the text should
    -- ignore light levels and shadow, not radiate). A material swap was tried first and rejected: only
    -- the engine's default text material understands the distance-field font, so any other material
    -- painted the whole glyph area as a solid white rectangle. So instead: put the text on its OWN
    -- lighting channel (2) so world lights and shadows no longer reach it, and light it with one small
    -- white shadowless point light that is on that same channel only -- so it lights nothing else (no
    -- halo on the board) and the text keeps its own colour. Tune with `lbsignglow <intensity> [radius]`.
    if opts.glow then
        -- Channel 2 only. PrimitiveComponent has a real setter; fall back to writing the struct's fields
        -- in place, then to assigning a whole table (the last is the one that did NOT stick on the light).
        local function onlyChannel2(comp)
            local ok = pcall(function() comp:SetLightingChannels(false, false, true) end)
            if not ok then
                pcall(function()
                    local lc = comp.LightingChannels
                    lc.bChannel0 = false ; lc.bChannel1 = false ; lc.bChannel2 = true
                end)
            end
            pcall(function()
                local lc = comp.LightingChannels
                lc.bChannel0 = false ; lc.bChannel1 = false ; lc.bChannel2 = true
            end)
        end
        local function channelsOf(comp)
            local r = "?"
            pcall(function()
                local lc = comp.LightingChannels
                r = string.format("ch0=%s ch1=%s ch2=%s", tostring(lc.bChannel0), tostring(lc.bChannel1), tostring(lc.bChannel2))
            end)
            return r
        end
        for _, c in ipairs(rec.comps) do onlyChannel2(c) end
        local sig = string.format("%.2f,%.2f,%.2f|%.2f|%.1f|%.2f|%s", ax + Signs.GLOW_OFFSET * dirx, ay + Signs.GLOW_OFFSET * diry, az,
            Signs.GLOW_INTENSITY, Signs.GLOW_RADIUS, Signs.GLOW_FALLOFF, tostring(Signs.GLOW_INVSQ))
        local reuse = false
        if rec.light then pcall(function() reuse = rec.light:IsValid() end) end
        if not (reuse and rec.lightSig == sig) then
        if rec.light then
            pcall(function() if rec.light:IsValid() then rec.light:K2_DestroyComponent(rec.light) end end)
            rec.light = nil
        end
        local lightCls = StaticFindObject("/Script/Engine.PointLightComponent")
        if lightCls and lightCls:IsValid() then
            local light
            pcall(function()
                light = actor:AddComponentByClass(lightCls, false, {
                    Rotation    = { W = 1.0, X = 0.0, Y = 0.0, Z = 0.0 },
                    Translation = { X = ax + Signs.GLOW_OFFSET * dirx, Y = ay + Signs.GLOW_OFFSET * diry, Z = az },
                    Scale3D     = { X = 1.0, Y = 1.0, Z = 1.0 },
                }, false)
            end)
            if light and light:IsValid() then
                pcall(function() light:SetVisibility(false, false) end)
                pcall(function() light.IntensityUnits = 0 end)   -- legacy unitless scale, as the lantern light
                pcall(function() light.Intensity = Signs.GLOW_INTENSITY end)
                pcall(function() light.AttenuationRadius = Signs.GLOW_RADIUS end)
                pcall(function() light.bUseInverseSquaredFalloff = Signs.GLOW_INVSQ end)
                -- Lighting channels only mask DIRECT light; Lumen still adds a light's indirect bounce to the
                -- whole surroundings (the "bubble" on the floor even with both on channel 2). Zero that out.
                pcall(function() light.IndirectLightingIntensity = 0.0 end)
                pcall(function() light.VolumetricScatteringIntensity = 0.0 end)
                pcall(function() light.bAffectTranslucentLighting = false end)
                pcall(function() light.LightFalloffExponent = Signs.GLOW_FALLOFF end)
                pcall(function() light.LightColor = { R = 255, G = 255, B = 255, A = 255 } end)  -- white: the text's own colour shows
                onlyChannel2(light)
                pcall(function() light:SetMobility(2) end)
                pcall(function() light.CastShadows = false end)
                pcall(function() light.CastDynamicShadows = false end)
                pcall(function() light:SetVisibility(true, false) end)
                pcall(function() light:MarkRenderStateDirty() end)
                rec.light = light
                rec.lightSig = sig
                -- Always log the channel readback: if the light still shows ch0=true it is lighting the world.
                say("full-bright channels: light " .. channelsOf(light) .. " | text " .. channelsOf(rec.comps[1]))
                if opts.verbose then say(string.format("glow light: intensity=%.2f radius=%.0f colour=%d,%d,%d", Signs.GLOW_INTENSITY, Signs.GLOW_RADIUS, color.R, color.G, color.B)) end
            else
                say("glow: PointLightComponent could not be created")
            end
        else
            say("glow: PointLightComponent class did not resolve")
        end
        end -- (re)build light
    else
        -- glow off: the kept light is no longer wanted
        if rec.light then
            pcall(function() if rec.light:IsValid() then rec.light:K2_DestroyComponent(rec.light) end end)
            rec.light, rec.lightSig = nil, nil
        end
    end

    for _, name in ipairs(t.hide) do
        local pc = getComp(actor, name)
        if pc then
            setHidden(pc, true)
            rec.hidden[#rec.hidden + 1] = name
        end
    end

    if not opts.noSave then Signs.SaveEntry(actor, rows, opts.color, opts.glow, opts.fontKey) end

    -- Report which font the first text piece REALLY ended up with (2026-09-30: the Signs tab dropdown seemed to only resize).
    local usedFont = "?"
    pcall(function() local c = rec.comps[1]; if c and c:IsValid() then usedFont = c.Font:GetFullName() end end)
    return true, string.format("%d row(s), size %.2f, font requested=%s key=%s, font in use=%s, picture hidden: %s", n, size,
        tostring(opts.font), tostring(opts.fontKey), usedFont, table.concat(rec.hidden, ","))
end

-- GC GUARD (2026-10-01). Text applies kept crashing on stock UE4SS inside UE4SS.dll's Lua table reads (+0x9347f0, garbage RAX), mid-apply, with the
-- game-thread timer shim OFF -- so the shim was not the (only) cause. Working theory: the Lua collector runs (on the async thread's allocations) while an
-- apply is building components and holding many fresh tables/strings. Stop the collector for the duration of an apply (nested fit-pass included) and
-- restart it after, always, even on error. Disable with Config.SIGNS_GC_GUARD = false.
do
    local rawApply = Signs.Apply
    local depth = 0
    Signs.Apply = function(actor, lines, opts)
        local okC, cfg = pcall(require, "config")
        if okC and type(cfg) == "table" and cfg.SIGNS_GC_GUARD == false then return rawApply(actor, lines, opts) end
        local started = false
        if depth == 0 then
            pcall(function() collectgarbage("stop") end) ; started = true
            local sq = rawget(_G, "__LB_SetQuiet")
            if sq then pcall(sq, true) end
        end
        depth = depth + 1
        local r = table.pack(pcall(rawApply, actor, lines, opts))
        depth = depth - 1
        if started then
            pcall(function() collectgarbage("restart") end)
            local sq = rawget(_G, "__LB_SetQuiet")
            if sq then pcall(sq, false) end
        end
        if not r[1] then error(r[2], 0) end
        return table.unpack(r, 2, r.n)
    end
end

local function splitLines(s)
    local out = {}
    s = s:gsub(";", "|")
    for part in (s .. "|"):gmatch("(.-)|") do out[#out + 1] = part end
    return out
end


-- ---------------------------------------------------------------------------------------------
-- Persistence: signs_persist_<islandId>.txt, one line per sign:
--   class \t x \t y \t z \t row1 \t row2 \t row3 \t row4        (\\, \t, \n escaped inside rows)
-- Keyed by class + rounded world location, because a BuildingBlock can be rebuilt by the game (new
-- instance, same spot). Entries are pruned when their sign is really gone -- see Signs.Sweep.
-- ---------------------------------------------------------------------------------------------
Signs._saved    = {}     -- [key] = { class, x, y, z, lines = {...} }
Signs._loadedId = nil
Signs._miss     = {}     -- [key] = consecutive sweeps a nearby entry had no live sign
Signs._seen     = {}     -- [key] = true once its sign was seen live this session
Signs._sweeps   = 0      -- sweeps since (re)load, for a warmup before pruning unseen entries
Signs.PRUNE_MISSES  = 3      -- ~15s of a nearby sign being absent
Signs.PRUNE_NEAR_UU = 1500.0 -- player must be this close for absence to count (streamed-in guard)
Signs.WARMUP_SWEEPS = 6      -- ~30s after a world load before absent-and-unseen entries may prune

local function esc(s) return (tostring(s):gsub("\\", "\\\\"):gsub("\t", "\\t"):gsub("\n", "\\n"):gsub("\r", "")) end
local function unesc(s)
    return (s:gsub("\\(.)", function(c) if c == "t" then return "\t" elseif c == "n" then return "\n" else return c end end))
end

local function persistPaths()
    local id = Signs._spawner and Signs._spawner.GetIslandId and Signs._spawner.GetIslandId()
    if not id then return nil end
    local named = "signs_persist_" .. id .. ".txt"
    return { "ue4ss/Mods/LivingBase/" .. named, "Mods/LivingBase/" .. named, named }, id
end

local function entryKey(class, x, y, z)
    return string.format("%s@%d,%d,%d", class, math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5))
end

local function actorEntryKey(actor)
    local class = className(actor)
    local x, y, z
    pcall(function() local l = actor:K2_GetActorLocation(); x, y, z = l.X, l.Y, l.Z end)
    if not x then return nil end
    return entryKey(class, x, y, z), class, x, y, z
end

function Signs.Load()
    local paths, id = persistPaths()
    if not paths then return false end
    Signs._saved, Signs._miss, Signs._seen, Signs._sweeps = {}, {}, {}, 0
    -- 2026-10-06 FIX (RedFalcon: "signs have no text" after switching worlds, but fine on the first
    -- world loaded) -- these per-ACTOR caches were never cleared on a world switch, only the
    -- per-SAVE-ENTRY ones above. Both worlds share the same underlying level (GenlandiaMulty), so a
    -- leftover _applied entry from the previous world's actor can wrongly satisfy Apply's
    -- reuseComps/IsValid check against a component that no longer actually renders -- Apply then
    -- "succeeds" (logs clean) while updating a dead reference instead of building a fresh one. A
    -- manual re-Apply later works because by then the stale check finally fails and it rebuilds.
    -- None of these can possibly still be valid once a genuinely different world's data just loaded.
    Signs._applied, Signs._keyOf, Signs._keyActor = {}, {}, {}
    Signs._lastApply, Signs._lastAnyApply = {}, nil
    Signs._loadedId = id
    for _, p in ipairs(paths) do
        local f = io.open(p, "r")
        if f then
            for line in f:lines() do
                local parts = {}
                for field in (line .. "\t"):gmatch("(.-)\t") do parts[#parts + 1] = field end
                local x, y, z = tonumber(parts[2]), tonumber(parts[3]), tonumber(parts[4])
                if parts[1] and parts[1] ~= "" and x and y and z then
                    local lines = {}
                    for i = 5, math.min(#parts, 8) do lines[#lines + 1] = unesc(parts[i]) end
                    local color
                    local cr, cg, cb = (parts[9] or ""):match("^(%d+),(%d+),(%d+)$")
                    if cr then color = { R = tonumber(cr), G = tonumber(cg), B = tonumber(cb), A = 255 } end
                    Signs._saved[entryKey(parts[1], x, y, z)] = { class = parts[1], x = x, y = y, z = z, lines = lines, color = color, glow = (parts[10] == "1"), font = ((parts[11] or "") ~= "") and parts[11] or nil }
                end
            end
            f:close()
            break
        end
    end
    local n = 0
    for _ in pairs(Signs._saved) do n = n + 1 end
    say(string.format("loaded %d saved sign(s) for world %s", n, tostring(id)))
    return true
end

function Signs.Save()
    local paths = persistPaths()
    if not paths then return false end
    for _, p in ipairs(paths) do
        local f = io.open(p, "w")
        if f then
            for _, e in pairs(Signs._saved) do
                local cols = { e.class, string.format("%.1f", e.x), string.format("%.1f", e.y), string.format("%.1f", e.z) }
                for i = 1, Signs.MAX_ROWS do cols[#cols + 1] = esc(e.lines[i] or "") end
                cols[#cols + 1] = e.color and string.format("%d,%d,%d", e.color.R, e.color.G, e.color.B) or ""
                cols[#cols + 1] = e.glow and "1" or ""
                cols[#cols + 1] = e.font or ""
                f:write(table.concat(cols, "\t"), "\n")
            end
            f:close()
            return true
        end
    end
    return false
end

function Signs.SaveEntry(actor, rows, color, glow, fontKey)
    if not Signs._loadedId then Signs.Load() end
    local key, class, x, y, z = actorEntryKey(actor)
    if not key then return end
    local lines = {}
    for i = 1, #rows do lines[i] = rows[i] end
    Signs._saved[key] = { class = class, x = x, y = y, z = z, lines = lines, color = color, glow = glow and true or nil, font = fontKey }
    Signs.Track(actor, key)
    Signs._miss[key] = 0
    Signs._seen[key] = true
    Signs.Save()
end

-- Erase the text but keep the object's colour / glow / font for next time (the Text tab's Clear button). Nothing worth keeping ->
-- the saved entry is dropped entirely. Reset (Signs.Clear + Signs.Forget) is the "back to defaults" version.
function Signs.ClearKeepStyle(actor, color, glow, fontKey)
    Signs.Clear(actor)
    if not Signs._loadedId then Signs.Load() end
    local key, class, x, y, z = actorEntryKey(actor)
    if not key then return end
    local e = Signs._saved[key]
    local c = color or (e and e.color)
    local g = glow
    if g == nil then g = e and e.glow end
    local f = fontKey or (e and e.font)
    if not (c or g or f) then Signs.Forget(actor) return end
    Signs._saved[key] = { class = class, x = x, y = y, z = z, lines = {}, color = c, glow = g and true or nil, font = f }
    Signs.Track(actor, key)
    Signs._miss[key] = 0
    Signs._seen[key] = true
    Signs.Save()
end

-- MOVED SIGNS (2026-10-01, RedFalcon). The saved text is keyed by class + position, so a spawned sign moved AFTER it was written on lost
-- its text on reload (no entry within RESTORE_MATCH_UU) and the sweep then pruned the old entry as a "destroyed sign". Each sign now
-- remembers which saved key is its own (Signs._keyOf, actor -> key); RekeyMoved moves that entry to the sign's current position. Only
-- spawned signs are checked -- the game's own building blocks are never moved, only destroyed and rebuilt.
Signs._keyOf = {}
Signs._keyActor = {}   -- actor key -> actor, so the move check only visits signs that have saved text
function Signs.Track(actor, key)
    local ak = actorKey(actor)
    Signs._keyOf[ak] = key
    Signs._keyActor[ak] = actor
end
function Signs.RekeyMoved(actor)
    local ak = actorKey(actor)
    local old = Signs._keyOf[ak]
    if not old then return false end
    local key, _, x, y, z = actorEntryKey(actor)
    if not key or key == old then return false end
    local e = Signs._saved[old]
    if not e then Signs._keyOf[ak] = nil return false end
    if Signs._saved[key] and Signs._saved[key] ~= e then return false end   -- another entry already owns that spot
    e.x, e.y, e.z = x, y, z
    Signs._saved[key] = e
    Signs._saved[old] = nil
    Signs._miss[key], Signs._seen[key] = 0, true
    Signs._miss[old], Signs._seen[old] = nil, nil
    Signs._keyOf[ak] = key
    Signs.Save()
    say(string.format("moved sign: saved text re-keyed %s -> %s", old, key))
    return true
end

function Signs.RekeySpawned()
    for ak, ac in pairs(Signs._keyActor) do
        local okV, valid = pcall(function() return ac and ac:IsValid() end)
        if okV and valid then pcall(Signs.RekeyMoved, ac)
        else Signs._keyActor[ak], Signs._keyOf[ak] = nil, nil end
    end
end

function Signs.Forget(actor)
    local key = actorEntryKey(actor)
    if key and Signs._saved[key] then
        Signs._saved[key] = nil
        Signs._miss[key], Signs._seen[key] = nil, nil
        Signs.Save()
    end
end

-- ---------------------------------------------------------------------------------------------
-- Restore text on SPAWNED props (Sign Post, spawned containers) after a world restore (2026-09-30).
-- Text is already saved per class+location by SaveEntry; nothing reapplied it once the world reloaded. This runs
-- as a phase of the base restore ("Populating Signs n/N"): only Spawner.spawned actors are touched (never the
-- game's own building blocks -- that sweep stays off), one per tick, each step inside pcall, the next one chained
-- from inside the finished step (same no-overlap rule as the restore itself).
-- ---------------------------------------------------------------------------------------------
Signs.RESTORE_MATCH_UU  = 15.0   -- saved spot vs restored spot (restore places at the saved location)
Signs.RESTORE_GAP_S     = 0.3    -- pacing between signs (was 0.7; 2026-10-01 faster, a sign apply is light and nothing else runs in this phase); restores are noSave so exempt from MIN_ANY_APPLY_GAP

local function savedFor(class, x, y, z)
    local best, bestD
    for _, e in pairs(Signs._saved) do
        if e.class == class then
            local dx, dy, dz = e.x - x, e.y - y, e.z - z
            local d = dx * dx + dy * dy + dz * dz
            if d <= Signs.RESTORE_MATCH_UU * Signs.RESTORE_MATCH_UU and (not bestD or d < bestD) then best, bestD = e, d end
        end
    end
    return best
end

function Signs.RestoreSpawned(onDone)
    local function finish()
        pcall(function() Signs._inlineDone = Signs._spawner and Signs._spawner.GetIslandId and Signs._spawner.GetIslandId() end)
        if onDone then pcall(onDone) end
    end
    local okTop, errTop = pcall(function()
        local Sp = Signs._spawner
        if not Sp then return finish() end
        -- 2026-10-07 FIX (RedFalcon: second world's signs never get text, even standing right next
        -- to a freshly-restored mod-spawned one) -- this only ever reloaded Signs._saved on the
        -- FIRST call all session (`not Signs._loadedId`), so every world after the first compared
        -- its own live signs against the PREVIOUS world's saved data, found zero matches, and
        -- silently did nothing (no "Populating Signs" line, no toast -- confirmed via
        -- spawn_menu_history.txt showing that line present for world 1, absent for world 2).
        -- Signs.Sweep already does this check correctly a few lines below; RestoreSpawned just never
        -- got the same fix, which is also why Sweep's own later fallback pass eventually recovered
        -- native-item signs (it reloads correctly) while this toast-bearing pass never did.
        local id = Sp.GetIslandId and Sp.GetIslandId()
        if Signs._loadedId ~= id then Signs.Load() end
        local work = {}
        -- Spawned props (matched within RESTORE_MATCH_UU of their restored spot) AND the game's own build-mode signs/chests (matched by exact
        -- class + position, they are rebuilt in place) -- one pass, one count (2026-10-01, RedFalcon: run the sign fill in line at the end of the
        -- restore, with a count). LiveSigns lists every building block once, at this quiet moment instead of on a timer.
        local list
        if Signs._config and Signs._config.SIGNS_RESTORE_BUILDING == false then
            list = {}
            for _, en in ipairs(Sp.spawned or {}) do list[#list + 1] = en.actor end
        else
            list = Signs.LiveSigns()
        end
        for _, ac in ipairs(list) do
            local okV, valid = pcall(function() return ac and ac:IsValid() end)
            if okV and valid and Signs.FindType(ac) then
                local key, class, x, y, z = actorEntryKey(ac)
                local e = key and (Signs._saved[key] or savedFor(class, x, y, z))
                local hasText = false
                if e then for _, ln in ipairs(e.lines) do if ln ~= "" then hasText = true end end end
                local rec = Signs._applied[actorKey(ac)]
                local done = false
                if rec and rec.comps and rec.comps[1] then pcall(function() done = rec.comps[1]:IsValid() end) end
                if e and hasText and not done then work[#work + 1] = { actor = ac, e = e } end
            end
        end
        if #work == 0 then return finish() end
        say(string.format("Populating Signs: %d sign(s) have saved text", #work))
        local i = 0
        local function step()
            i = i + 1
            if i > #work then return finish() end
            local w = work[i]
            local ok, err = pcall(function()
                if w.actor:IsValid() then
                    Signs.Track(w.actor, entryKey(w.e.class, w.e.x, w.e.y, w.e.z))
                    local okA, msg = Signs.Apply(w.actor, w.e.lines, { noSave = true, color = w.e.color, glow = w.e.glow, fontKey = w.e.font })
                    say(string.format("Populating Signs %d/%d: %s", i, #work, tostring(msg)))
                end
                pcall(function() Sp.Toast(string.format("Populating Signs: %d/%d", i, #work), 1.5) end)
            end)
            if not ok then say("Populating Signs step error: " .. tostring(err)) end
            if ExecuteWithDelay then ExecuteWithDelay(math.floor(Signs.RESTORE_GAP_S * 1000), step) else step() end
        end
        if ExecuteWithDelay then ExecuteWithDelay(1000, step) else step() end
    end)
    if not okTop then say("Populating Signs failed: " .. tostring(errTop)) ; finish() end
end

-- ---------------------------------------------------------------------------------------------
-- Live signs + targeting
-- ---------------------------------------------------------------------------------------------
local function eachActor(list, fn)
    if not list then return end
    local n = 0
    pcall(function() n = list:GetArrayNum() end)
    if n == 0 then pcall(function() n = #list end) end
    for i = 1, n do
        local a = list[i]
        if not a then pcall(function() a = list:Get(i) end) end
        if a then
            local okV, valid = pcall(function() return a:IsValid() end)
            if okV and valid then fn(a) end
        end
    end
end

function Signs.LiveSigns()
    local out = {}
    local list
    pcall(function() list = FindAllOf("R5BuildingBlock") end)
    local seen = {}
    eachActor(list, function(a)
        local t = Signs.FindType(a)
        if t then out[#out + 1] = a ; pcall(function() seen[a:GetFullName()] = true end) end
    end)
    -- Spawned props (Spawner.spawned) with a sign entry -- e.g. the Sign Post, which is not a building block.
    for _, e in ipairs((Signs._spawner and Signs._spawner.spawned) or {}) do
        local ac = e.actor
        local okV, valid = pcall(function() return ac and ac:IsValid() end)
        if okV and valid and Signs.FindType(ac) then
            local fn
            pcall(function() fn = ac:GetFullName() end)
            if fn and not seen[fn] then seen[fn] = true ; out[#out + 1] = ac end
        end
    end
    return out
end

-- Signs.ListPopulated() -- for the Target List tab's "Build Signs"/"Placed Signs" categories (2026-10-06,
-- RedFalcon: detect+target populated signs/labels, split by whether the game's own build menu placed them
-- (R5BuildingBlock, isBuilt=true -- a build piece this mod doesn't own/move/despawn, Del-only on that tab) or
-- this mod spawned them (Spawner.spawned entries, isBuilt=false -- + and Del both work there). "Populated" =
-- at least one non-empty saved text row right now, the same hasText check Signs.RestoreSpawned already uses.
-- Same two-pass split as LiveSigns (building blocks, then spawned props, deduped by full name) but filtered
-- down to signs that actually have text and tagged with isBuilt instead of being a flat list.
function Signs.ListPopulated()
    local out = {}
    local list
    pcall(function() list = FindAllOf("R5BuildingBlock") end)
    local seen = {}
    eachActor(list, function(a)
        local t = Signs.FindType(a)
        if t then
            local key, class, x, y, z = actorEntryKey(a)
            local e = key and (Signs._saved[key] or savedFor(class, x, y, z))
            local hasText = false
            if e then for _, ln in ipairs(e.lines) do if ln ~= "" then hasText = true end end end
            if hasText then
                out[#out + 1] = { actor = a, label = t.name, isBuilt = true }
                pcall(function() seen[a:GetFullName()] = true end)
            end
        end
    end)
    for _, en in ipairs((Signs._spawner and Signs._spawner.spawned) or {}) do
        local ac = en.actor
        local okV, valid = pcall(function() return ac and ac:IsValid() end)
        if okV and valid then
            local t = Signs.FindType(ac)
            if t then
                local fn
                pcall(function() fn = ac:GetFullName() end)
                if not (fn and seen[fn]) then
                    local key, class, x, y, z = actorEntryKey(ac)
                    local e = key and (Signs._saved[key] or savedFor(class, x, y, z))
                    local hasText = false
                    if e then for _, ln in ipairs(e.lines) do if ln ~= "" then hasText = true end end end
                    if hasText then
                        out[#out + 1] = { actor = ac, label = en.label or t.name, isBuilt = false }
                        if fn then seen[fn] = true end
                    end
                end
            end
        end
    end
    return out
end

-- Signs.SelectFromTargetList(actor) -- deterministic version of the Delete key's ToggleTarget, for the
-- Target List tab's "Del" button (2026-10-06): always SETS this exact actor as the sign target and jumps to
-- the Signs tab, never toggles/releases it -- a GUI button click should always do the same thing, unlike the
-- real Delete key which doubles as a release when pressed again on the same target.
function Signs.SelectFromTargetList(actor)
    if not (actor and actor:IsValid()) then return false end
    Signs.SetTarget(actor)
    Signs._tabSeq = (Signs._tabSeq or 0) + 1
    Signs._statusDirty = true
    return true
end

local function playerPos()
    local x, y, z
    pcall(function()
        local pc = require("UEHelpers").GetPlayerController()
        local pawn = pc and pc:IsValid() and pc.Pawn
        if pawn and pawn:IsValid() then local l = pawn:K2_GetActorLocation(); x, y, z = l.X, l.Y, l.Z end
    end)
    return x, y, z
end

-- Aim-pick: the sign closest to the crosshair (largest view dot) within range, sign types only.
function Signs.PickSign(maxDist, minDot)
    -- 1. The regular targeting (2026-09-30): whatever the hover raycast has under the crosshair among things the mod SPAWNED -- the
    --    same pick Numpad+ uses -- if it has a sign entry. This is what finds a Sign Post reliably.
    local sp = Signs._spawner
    if sp and sp.PickTargetPreferringHover then
        local okH, found, e = pcall(sp.PickTargetPreferringHover)
        if okH and found and e and e.actor and Signs.FindType(e.actor) then
            Signs.SetTarget(e.actor)
            return e.actor
        end
    end
    -- 2. The object already locked with Numpad+, if it has a sign entry.
    local lt = sp and sp.lockedTarget
    if lt and lt.actor then
        local okV, v = pcall(function() return lt.actor:IsValid() end)
        if okV and v and Signs.FindType(lt.actor) then
            Signs.SetTarget(lt.actor)
            return lt.actor
        end
    end
    -- 3. Fallback for signs/containers the GAME placed (the regular targeting only knows mod-spawned objects): the aim cone below.
    maxDist = maxDist or 800.0
    minDot  = minDot or 0.85
    local camX, camY, camZ, fx, fy, fz
    pcall(function()
        local pc = require("UEHelpers").GetPlayerController()
        local cam = pc and pc:IsValid() and pc.PlayerCameraManager
        if cam and cam:IsValid() then
            local l = cam:GetCameraLocation(); camX, camY, camZ = l.X, l.Y, l.Z
            local r = cam:GetCameraRotation()
            local yaw, pitch = math.rad(r.Yaw), math.rad(r.Pitch)
            local cp = math.cos(pitch)
            fx, fy, fz = cp * math.cos(yaw), cp * math.sin(yaw), math.sin(pitch)
        end
    end)
    if not (camX and fx) then say("no camera available") return nil end
    local best, bestDot
    for _, a in ipairs(Signs.LiveSigns()) do
        pcall(function()
            -- Aim at the TEXT position (the board), not the actor's origin (2026-09-30: a Sign Post's origin is at its base, far below
            -- the board you are looking at, so standing close it fell outside the aim cone and Delete said "no sign in front of you").
            local l = a:K2_GetActorLocation()
            local t = Signs.FindType(a)
            local px, py, pz = l.X, l.Y, l.Z
            if t and t.anchor then
                local yawDeg = 0.0
                pcall(function() yawDeg = a:K2_GetActorRotation().Yaw end)
                local th = math.rad(yawDeg)
                px = l.X + t.anchor.x * math.cos(th) - t.anchor.y * math.sin(th)
                py = l.Y + t.anchor.x * math.sin(th) + t.anchor.y * math.cos(th)
                pz = l.Z + t.anchor.z
            end
            local dx, dy, dz = px - camX, py - camY, pz - camZ
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d > 0 and d <= maxDist then
                local dot = (dx * fx + dy * fy + dz * fz) / d
                if dot >= minDot and (not bestDot or dot > bestDot) then best, bestDot = a, dot end
            end
        end)
    end
    if not best then
        say(string.format("no sign within %.0fuu in front of you", maxDist))
        return nil
    end
    Signs.SetTarget(best)
    return best
end

-- Toggle, same idiom as Numpad+ target lock: with a sign selected this releases it, otherwise it
-- picks the sign you are aiming at. Used by both the Delete key and the tab's Select/Deselect button.
function Signs.ToggleTarget()
    local a = Signs._target
    local valid = false
    if a then pcall(function() valid = a:IsValid() end) end
    if valid then
        Signs._target = nil
        pcall(function() Signs._spawner.Toast("Sign released", 2.0) end)
        Signs._statusDirty = true
        return nil
    end
    return Signs.PickSign()
end

-- The Delete key itself (2026-09-29, RedFalcon: "if you press delete and it's on any tab other than
-- sign, change the tab to signs"): bumps SIGN_TAB_SEQ so the window switches to the Signs tab, then
-- toggles the selection. The tab's own Select/Deselect button goes through PollRequest instead and
-- deliberately does NOT bump this -- the user is already on the tab.
function Signs.KeyPressed()
    Signs._tabSeq = (Signs._tabSeq or 0) + 1
    Signs._statusDirty = true
    return Signs.ToggleTarget()
end

function Signs.SetTarget(actor)
    Signs._target = actor
    pcall(function() Signs._spawner._lastProbedActor = actor end)  -- so lbtestsigntext etc. follow it
    pcall(function() Signs._spawner.Toast("Object selected", 2.0) end)
    Signs._statusDirty = true
end

-- The sign's ink colour: its saved override, else the sign type's default.
function Signs.CurrentColor(actor)
    local key = actorEntryKey(actor)
    local e = key and Signs._saved[key]
    if e and e.color then return e.color end
    local t = Signs.FindType(actor)
    return (t and t.color) or { R = 25, G = 15, B = 5, A = 255 }
end

function Signs.CurrentFontKey(actor)
    local key = actorEntryKey(actor)
    local e = key and Signs._saved[key]
    return (e and e.font) or Signs.DEFAULT_FONT_KEY
end

function Signs.CurrentGlow(actor)
    local key = actorEntryKey(actor)
    local e = key and Signs._saved[key]
    return (e and e.glow) and true or false
end

function Signs.CurrentRows(actor)
    local key = actorEntryKey(actor)
    local e = key and Signs._saved[key]
    return e and e.lines or {}
end

-- ---------------------------------------------------------------------------------------------
-- Sweep (every ~5s): re-apply saved text to live signs that lack it, and PRUNE entries whose sign is
-- really gone. "Gone" is deliberately conservative -- a sign that is merely streamed out must never
-- lose its text -- so an entry is only dropped when the player is NEAR its spot (so it would be
-- loaded), it is absent for PRUNE_MISSES consecutive sweeps, and either the sign was seen live this
-- session or the post-load warmup has passed.
-- ---------------------------------------------------------------------------------------------
Signs.SWEEP_APPLY_BUDGET = 2
Signs.QUIET_SECONDS = 45   -- stay out of the way this long after a world loads / a restore runs
function Signs.Sweep()
    local id = Signs._spawner and Signs._spawner.GetIslandId and Signs._spawner.GetIslandId()
    if not id then return end
    pcall(Signs.RekeySpawned)   -- before anything can prune an entry whose spawned sign was simply moved
    -- Never touch building blocks while the base is being rebuilt (2026-09-29: load-time crashes inside
    -- UE4SS.dll during the restore). Restoring, or within QUIET_SECONDS of the world id first appearing /
    -- the last restore activity, means skip this sweep.
    local now = os.time()
    if Signs._quietId ~= id then Signs._quietId = id ; Signs._quietUntil = now + Signs.QUIET_SECONDS ; Signs._idSince = now end
    if Signs._spawner.restoring then Signs._quietUntil = now + Signs.QUIET_SECONDS end
    if now < (Signs._quietUntil or 0) then return end
    -- The in-line "Populating Signs n/N" restore step owns the first fill (2026-10-01). Until it has run, stay out (3 min cap in case it never runs).
    if Signs._inlineDone ~= id and not (Signs._config and Signs._config.SIGNS_RESTORE_BUILDING == false)
       and (now - (Signs._idSince or now)) < 180 then return end
    if Signs._loadedId ~= id then Signs.Load() end
    Signs._sweeps = Signs._sweeps + 1

    local liveKeys = {}
    local liveActorKeys = {}
    local budget = Signs.SWEEP_APPLY_BUDGET   -- text rebuilds per pass (2026-10-01): a base full of signs is refilled a couple per pass, never in one burst
    for _, a in ipairs(Signs.LiveSigns()) do
        local key = actorEntryKey(a)
        local ak = actorKey(a)
        liveActorKeys[ak] = true
        if key then
            liveKeys[key] = true
            local e = Signs._saved[key]
            if e then
                Signs._seen[key] = true
                Signs._miss[key] = 0
                if not Signs._keyOf[ak] then Signs.Track(a, key) end
                local rec = Signs._applied[ak]
                local ok = false
                if rec and rec.comps[1] then pcall(function() ok = rec.comps[1]:IsValid() end) end
                if not ok and budget > 0 then
                    budget = budget - 1
                    local okA, msg = Signs.Apply(a, e.lines, { noSave = true, color = e.color, glow = e.glow, fontKey = e.font })
                    say("restored sign text at " .. key .. ": " .. tostring(msg))
                end
            end
        end
    end
    -- forget bookkeeping for actors that no longer exist
    for ak in pairs(Signs._applied) do
        if not liveActorKeys[ak] then Signs._applied[ak] = nil end
    end

    local px, py, pz = playerPos()
    if not px then return end
    local pruned = false
    for key, e in pairs(Signs._saved) do
        if not liveKeys[key] then
            local dx, dy = e.x - px, e.y - py
            local near = (dx * dx + dy * dy) <= (Signs.PRUNE_NEAR_UU * Signs.PRUNE_NEAR_UU)
            local eligible = Signs._seen[key] or Signs._sweeps >= Signs.WARMUP_SWEEPS
            if near and eligible then
                Signs._miss[key] = (Signs._miss[key] or 0) + 1
                if Signs._miss[key] >= Signs.PRUNE_MISSES then
                    Signs._saved[key] = nil
                    Signs._miss[key], Signs._seen[key] = nil, nil
                    pruned = true
                    say("pruned saved text for destroyed sign at " .. key)
                end
            end
        end
    end
    if pruned then Signs.Save() end
end

-- ---------------------------------------------------------------------------------------------
-- File bridge with the LivingBaseSpawnMenu "Signs" tab.
--   sign_request.txt : line 1 = verb (APPLY | CLEAR | TARGET); APPLY is followed by 4 text lines
--   sign_status.txt  : SIGN_SEQ / SIGN_HAS_TARGET / SIGN_NAME / SIGN_L1..L4 (rewritten on change)
-- ---------------------------------------------------------------------------------------------
local function firstExisting(names)
    for _, p in ipairs(names) do
        local f = io.open(p, "r")
        if f then f:close() return p end
    end
end

function Signs.PollRequest()
    local path = firstExisting({ "ue4ss/Mods/LivingBase/sign_request.txt", "Mods/LivingBase/sign_request.txt", "sign_request.txt" })
    if not path then return end
    local f = io.open(path, "r")
    if not f then return end
    local content = f:read("*all")
    f:close()
    os.remove(path)
    local lines = {}
    for l in (content .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = l end
    local verb = lines[1]
    if verb == "TARGET" then
        Signs.ToggleTarget()
    elseif verb == "APPLY" or verb == "CLEAR" or verb == "RESET" then
        local a = Signs._target
        if not (a and a:IsValid()) then say("no object selected") return end
        if verb == "RESET" then
            Signs.Clear(a) ; Signs.Forget(a)
            say("object reset to default")
        elseif verb == "CLEAR" then
            Signs.ClearKeepStyle(a)
            say("text cleared (style kept)")
        else
            local rows, color, glow, fontKey = {}, nil, false, nil
            local first = 2
            while lines[first] do
                local cr, cg, cb = lines[first]:match("^COLOR:(%d+),(%d+),(%d+)$")
                local gl = lines[first]:match("^GLOW:([01])$")
                local fk = lines[first]:match("^FONT:([%w_]+)$")
                if cr then
                    color = { R = math.min(tonumber(cr), 255), G = math.min(tonumber(cg), 255), B = math.min(tonumber(cb), 255), A = 255 }
                elseif gl then
                    glow = (gl == "1")
                elseif fk then
                    fontKey = fk
                else
                    break
                end
                first = first + 1
            end
            for i = first, first + 3 do rows[#rows + 1] = lines[i] or "" end
            local ok, msg = Signs.Apply(a, rows, { color = color, glow = glow, fontKey = fontKey })
            say((ok and "applied: " or "apply FAILED: ") .. tostring(msg))
        end
        Signs._statusDirty = true
    end
end

function Signs.PublishStatus()
    local a = Signs._target
    local valid = false
    if a then pcall(function() valid = a:IsValid() end) end
    local akey = valid and actorKey(a) or ""
    if akey ~= Signs._statusKey then Signs._statusSeq = (Signs._statusSeq or 0) + 1; Signs._statusKey = akey; Signs._statusDirty = true end
    if not Signs._statusDirty then return end
    Signs._statusDirty = false
    local t = valid and Signs.FindType(a)
    local rows = valid and Signs.CurrentRows(a) or {}
    local out = {
        "SIGN_SEQ=" .. tostring(Signs._statusSeq or 0),
        "SIGN_TAB_SEQ=" .. tostring(Signs._tabSeq or 0),
        "SIGN_HAS_TARGET=" .. (valid and "1" or "0"),
        "SIGN_NAME=" .. (t and t.name or ""),
        "SIGN_MAX_ROWS=" .. tostring((t and t.rows) or Signs.MAX_ROWS),
    }
    local col = valid and Signs.CurrentColor(a) or { R = 25, G = 15, B = 5 }
    out[#out + 1] = string.format("SIGN_COLOR=%d,%d,%d", col.R, col.G, col.B)
    out[#out + 1] = "SIGN_GLOW=" .. ((valid and Signs.CurrentGlow(a)) and "1" or "0")
    out[#out + 1] = "SIGN_FONT=" .. (valid and Signs.CurrentFontKey(a) or Signs.DEFAULT_FONT_KEY)
    for i = 1, Signs.MAX_ROWS do
        local txt = tostring(rows[i] or ""):gsub("[\r\n]", " ")
        out[#out + 1] = "SIGN_L" .. i .. "=" .. txt
    end
    for _, p in ipairs({ "ue4ss/Mods/LivingBase/sign_status.txt", "Mods/LivingBase/sign_status.txt", "sign_status.txt" }) do
        local f = io.open(p, "w")
        if f then f:write(table.concat(out, "\n"), "\n"); f:close(); return end
    end
end

function Signs.Install(Spawner, Config)
    Signs._spawner = Spawner
    Signs._config = Config
    -- A status file left by a previous session would carry a stale SIGN_TAB_SEQ; the window baselines
    -- on its first read, so start clean.
    for _, p in ipairs({ "ue4ss/Mods/LivingBase/sign_status.txt", "Mods/LivingBase/sign_status.txt", "sign_status.txt" }) do
        pcall(function() os.remove(p) end)
    end
    if not RegisterConsoleCommandHandler then
        say("RegisterConsoleCommandHandler missing -- lbtestsigntext unavailable")
        return
    end
    RegisterConsoleCommandHandler("lbtestsigntext", function(FullCommand, Parameters, Ar)
        local function out(m) say(m, Ar) end
        local ok, err = pcall(function()
            local actor = Spawner and Spawner._lastProbedActor
            if not (actor and actor:IsValid()) then
                out("No probed actor -- aim at a sign, run lbprobe, then retry.")
                return
            end
            local t = Signs.FindType(actor)
            out("target=" .. className(actor) .. " type=" .. (t and t.name or "NOT IN LIST"))
            local params = Parameters or {}
            -- Tolerate spaces around "=" ("depth = 0" -> "depth=0"): re-join the words, close up any " = ", then split again.
            do
                local joined = table.concat(params, " "):gsub("%s*=%s*", "=")
                local fixed = {}
                for w in joined:gmatch("%S+") do fixed[#fixed + 1] = w end
                if #fixed > 0 then params = fixed end
            end
            if params[1] == "clear" then
                out("cleared " .. Signs.Clear(actor) .. " component(s)")
                Signs.Forget(actor)
                return
            end
            -- options: yaw=180 size=12 x=20 color=255,255,0 ; a bare trailing number is still yaw
            local yaw, size, ax, color, fontArg, matArg, glowArg, dyArg, dzArg, spacingArg, rowstepArg, extentArg, vshiftArg, bwArg, bhArg, rollArg, pitchArg
            local words = {}
            for _, tok in ipairs(params) do
                local k, v = tostring(tok):match("^(%a+)=(.+)$")
                if k == "yaw" then yaw = tonumber(v)
                elseif k == "size" then size = tonumber(v)
                elseif k == "x" or k == "depth" then ax = tonumber(v)
                elseif k == "dy" or k == "y" then dyArg = tonumber(v)
                elseif k == "dz" or k == "z" then dzArg = tonumber(v)
                elseif k == "font" then fontArg = v
                elseif k == "spacing" then spacingArg = tonumber(v)
                elseif k == "rowstep" then rowstepArg = tonumber(v)
                elseif k == "extent" then extentArg = tonumber(v)
                elseif k == "roll" then rollArg = tonumber(v)
                elseif k == "pitch" then pitchArg = tonumber(v)
                elseif k == "bw" then bwArg = tonumber(v)
                elseif k == "bh" then bhArg = tonumber(v)
                elseif k == "vshift" then vshiftArg = tonumber(v)
                elseif k == "mat" then matArg = v
                elseif k == "glow" then glowArg = (v == "1")
                elseif k == "color" then
                    local r, g, b = v:match("(%d+),(%d+),(%d+)")
                    if r then color = { R = tonumber(r), G = tonumber(g), B = tonumber(b), A = 255 } end
                else words[#words + 1] = tok end
            end
            local n = #words
            if n > 1 and tonumber(words[n]) then yaw = tonumber(words[n]); words[n] = nil end
            local text = table.concat(words, " ")
            out("raw text arg: '" .. text .. "' (" .. #params .. " token(s))")
            if text == "" then out("Usage: lbtestsigntext Line1|Line2|Line3|Line4 [yaw]  |  lbtestsigntext clear") return end
            local pl = getComp(actor, "Plane")
            if pl then
                pcall(function()
                    local l, r, s = pl.RelativeLocation, pl.RelativeRotation, pl.RelativeScale3D
                    out(string.format("Plane rel loc=(%.2f,%.2f,%.2f) rot=(%.1f,%.1f,%.1f) scale=%.2f", l.X, l.Y, l.Z, r.Pitch, r.Yaw, r.Roll, s.X))
                end)
            end
            local okA, msg = Signs.Apply(actor, splitLines(text), { yaw = yaw, size = size, depth = ax, dy = dyArg, dz = dzArg, color = color, font = fontArg, spacing = spacingArg, rowStep = rowstepArg, extent = extentArg, vshift = vshiftArg, boardW = bwArg, boardH = bhArg, roll = rollArg, pitch = pitchArg, mat = matArg, glow = glowArg or (matArg ~= nil), verbose = true })
            out((okA and "OK: " or "FAILED: ") .. tostring(msg))
        end)
        if not ok then out("lbtestsigntext error: " .. tostring(err)) end
        return true
    end)
    -- lbsignmat -- material tests on the targeted / last-probed actor's mesh (2026-09-29: cover the "X" that is baked
    -- into the SignCacheTMP pole sign's own albedo texture). Slot 0 only.
    --   lbsignmat <materialPath>          swap the whole material  (e.g. /Game/Environment/Gameplay/Workbenches/Materials/MI_CraftStation_06)
    --   lbsignmat albedo <texturePath>    keep the material, replace only its "Albedo" texture (dynamic instance)
    --   lbsignmat restore                 put the original material back
    RegisterConsoleCommandHandler("lbsignmat", function(FullCommand, Parameters, Ar)
        local function out(m) say(m, Ar) end
        pcall(function()
            local p = Parameters or {}
            local actor = Signs._target
            if not (actor and actor:IsValid()) then actor = Signs._spawner and Signs._spawner._lastProbedActor end
            if not (actor and actor:IsValid()) then out("no probed/selected actor -- aim at it and run lbprobe first") return end
            local comp
            for _, n in ipairs({ "StaticMeshComponent", "MeshComponent", "StaticMesh" }) do
                pcall(function() local c = actor[n]; if c and c:IsValid() then comp = comp or c end end)
            end
            if not comp then out("no mesh component found on " .. className(actor)) return end
            Signs._origMat = Signs._origMat or {}
            local key = actorKey(actor)
            if not Signs._origMat[key] then
                pcall(function() Signs._origMat[key] = comp:GetMaterial(0) end)
            end
            local function loadObj(base)
                local name = base:match("([^/%.]+)$")
                local path = base:find("%.") and base or (base .. "." .. name)
                local o = Signs._spawner and Signs._spawner.ResolveAsset and Signs._spawner.ResolveAsset(path)
                if not (o and o:IsValid()) then o = StaticFindObject(path) end
                if o and o:IsValid() then return o end
            end
            if p[1] == "restore" then
                local o = Signs._origMat[key]
                if o then pcall(function() comp:SetMaterial(0, o) end) out("original material restored") else out("nothing to restore") end
            elseif p[1] == "albedo" and p[2] then
                local tex = loadObj(p[2])
                if not tex then out("texture did not load: " .. p[2]) return end
                local mid
                pcall(function() mid = comp:CreateAndSetMaterialInstanceDynamic(0) end)
                if not (mid and mid:IsValid()) then out("could not create a dynamic material instance") return end
                local okT = pcall(function() mid:SetTextureParameterValue(FName("Albedo"), tex) end)
                out("albedo replaced with " .. p[2] .. " (call ok=" .. tostring(okT) .. ")")
            elseif p[1] then
                local mat = loadObj(p[1])
                if not mat then out("material did not load: " .. p[1]) return end
                pcall(function() comp:SetMaterial(0, mat) end)
                local now = "?"
                pcall(function() now = comp:GetMaterial(0):GetFullName() end)
                out("material set; slot 0 is now " .. now)
            else
                out("usage: lbsignmat <materialPath> | albedo <texturePath> | restore")
            end
        end)
        return true
    end)

    -- lbsignscan [pairRadius] [nearMe] -- for every placed sign-type label near a BP_Storage_* container, prints the label's
    -- position and yaw in that CONTAINER's own frame, plus the text anchor/yaw a Signs.TYPES entry for that
    -- container would need. (2026-09-29: RedFalcon placed real wooden labels on chests/box/bale/barrel/bag as
    -- scale references; the containers themselves have no sign component, so the labels ARE the measurement.)
    RegisterConsoleCommandHandler("lbsignscan", function(FullCommand, Parameters, Ar)
        local function out(m) say(m, Ar) end
        pcall(function()
            local maxD = tonumber((Parameters or {})[1]) or 200.0
            -- nearMe (uu): only report labels within this distance of the PLAYER, nearest first. 0/absent = the
            -- whole loaded world (which can be dozens of old labels). e.g. `lbsignscan 200 500` at your test row.
            local nearMe = tonumber((Parameters or {})[2]) or 0.0
            local px, py, pz = playerPos()
            local containers, signs = {}, {}
            local list
            pcall(function() list = FindAllOf("R5BuildingBlock") end)
            eachActor(list, function(a)
                local cn = className(a)
                if cn:sub(1, 11) == "BP_Storage_" then containers[#containers + 1] = a
                elseif Signs.FindType(a) then signs[#signs + 1] = a end
            end)
            if nearMe > 0 and px then
                local kept = {}
                for _, sg in ipairs(signs) do
                    local ok, l = pcall(function() return sg:K2_GetActorLocation() end)
                    if ok and l then
                        local d = math.sqrt((l.X - px) ^ 2 + (l.Y - py) ^ 2 + (l.Z - pz) ^ 2)
                        if d <= nearMe then kept[#kept + 1] = { a = sg, d = d } end
                    end
                end
                table.sort(kept, function(x, y) return x.d < y.d end)
                signs = {}
                for _, k in ipairs(kept) do signs[#signs + 1] = k.a end
            end
            -- Also treat everything WE spawned (Spawner.spawned: decor, props, spawned signs) as a host a label
            -- can be sitting on -- e.g. the SignCacheTMP pole sign -- not only the game's own BP_Storage_* boxes.
            do
                local seen = {}
                for _, c in ipairs(containers) do pcall(function() seen[c:GetFullName()] = true end) end
                for _, e in ipairs((Signs._spawner and Signs._spawner.spawned) or {}) do
                    local ac = e.actor
                    local okV, valid = pcall(function() return ac and ac:IsValid() end)
                    if okV and valid then
                        local fn
                        pcall(function() fn = ac:GetFullName() end)
                        if fn and not seen[fn] and not Signs.FindType(ac) then
                            seen[fn] = true
                            containers[#containers + 1] = ac
                        end
                    end
                end
            end
            out(string.format("scan: %d container(s), %d sign(s)%s, pairing within %.0fuu", #containers, #signs, nearMe > 0 and string.format(" within %.0fuu of you (nearest first)", nearMe) or "", maxD))
            local function loc(a)
                local l = a:K2_GetActorLocation(); return l.X, l.Y, l.Z
            end
            local function yawOf(a)
                local r = a:K2_GetActorRotation(); return r.Yaw
            end
            for _, sg in ipairs(signs) do
                local sx, sy, sz = loc(sg)
                local best, bestD
                for _, c in ipairs(containers) do
                    local cx, cy, cz = loc(c)
                    local d = math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2 + (sz - cz) ^ 2)
                    if d <= maxD and (not bestD or d < bestD) then best, bestD = c, d end
                end
                if best then
                    local cx, cy, cz = loc(best)
                    local cyaw, syaw = yawOf(best), yawOf(sg)
                    local th = math.rad(cyaw)
                    local dx, dy, dz = sx - cx, sy - cy, sz - cz
                    local lx = dx * math.cos(th) + dy * math.sin(th)
                    local ly = -dx * math.sin(th) + dy * math.cos(th)
                    local dyaw = (syaw - cyaw + 540) % 360 - 180
                    -- The text is centred on the label's own origin and floats `depth` (11.8 on the wall label)
                    -- in front of it along the label's facing (yawDelta) -- see Signs.TYPES anchor/depth/yaw.
                    out(string.format("%s: anchor (label origin, container frame) = (%.1f, %.1f, %.1f)  yaw=%.1f  depth=11.8  [dist %.0f]",
                        className(best), lx, ly, dz, dyaw, bestD))
                else
                    out(string.format("label at (%.0f,%.0f,%.0f) has no container within %.0fuu", sx, sy, sz, maxD))
                end
            end
        end)
        return true
    end)

    -- lbtestsignlist -- debug for the Target List tab's "Build Signs"/"Placed Signs" categories (2026-10-06):
    -- calls Signs.ListPopulated() directly and prints exactly what it found, bypassing the GUI request/response
    -- round-trip entirely, so a "nothing shows up" report can be isolated to either this function or the bridge.
    RegisterConsoleCommandHandler("lbtestsignlist", function(FullCommand, Parameters, Ar)
        local function out(m) say(m, Ar) end
        local ok, err = pcall(function()
            if not Signs._loadedId then Signs.Load() end
            local n = 0
            for _ in pairs(Signs._saved) do n = n + 1 end
            out(string.format("Signs._saved has %d entrie(s) loaded (world %s)", n, tostring(Signs._loadedId)))
            local populated = Signs.ListPopulated()
            out(string.format("ListPopulated() found %d populated sign(s)", #populated))
            for i, row in ipairs(populated) do
                out(string.format("  %d. %s (isBuilt=%s)", i, tostring(row.label), tostring(row.isBuilt)))
            end
        end)
        if not ok then out("lbtestsignlist FAILED: " .. tostring(err)) end
        return true
    end)

    -- lbsignmatinfo -- prints the text material's real settings (blend mode / shading model / etc.) for the
    -- last-probed sign's first text row, to find out whether the default text material is lit or unlit.
    RegisterConsoleCommandHandler("lbsignmatinfo", function(FullCommand, Parameters, Ar)
        local function out(m) say(m, Ar) end
        pcall(function()
            local actor = Signs._target
            if not (actor and actor:IsValid()) then actor = Signs._spawner and Signs._spawner._lastProbedActor end
            local rec = actor and actor:IsValid() and Signs._applied[actorKey(actor)]
            local comp = rec and rec.comps and rec.comps[1]
            if not (comp and comp:IsValid()) then out("no sign text on the targeted sign -- apply some text first") return end
            local mat = comp.TextMaterial
            if not (mat and mat:IsValid()) then out("TextMaterial is empty") return end
            out("TextMaterial = " .. mat:GetFullName())
            local parent = mat
            pcall(function() if mat.Parent and mat.Parent:IsValid() then parent = mat.Parent; out("parent = " .. parent:GetFullName()) end end)
            -- Walk the material's class hierarchy and print simple (non-struct) properties.
            local cls
            pcall(function() cls = parent:GetClass() end)
            local shown = 0
            while cls and cls:IsValid() and shown < 200 do
                pcall(function()
                    cls:ForEachProperty(function(prop)
                        local pname = "?"
                        pcall(function() pname = prop:GetFName():ToString() end)
                        local okv, val = pcall(function() return parent[pname] end)
                        if okv and val ~= nil and type(val) ~= "userdata" then
                            if pname:match("Shading") or pname:match("Blend") or pname:match("Domain") or pname:match("TwoSided")
                               or pname:match("Lit") or pname:match("Emissive") or pname:match("Translucen") or pname:match("Opacity")
                               or pname:match("Mask") or pname:match("Unlit") or pname:match("DepthTest") then
                                out("  " .. pname .. " = " .. tostring(val))
                                shown = shown + 1
                            end
                        end
                    end)
                end)
                local nxt
                pcall(function() nxt = cls:GetSuperStruct() end)
                cls = nxt
            end
            pcall(function() out("  GetBlendMode() = " .. tostring(parent:GetBlendMode())) end)
            pcall(function() out("  IsTwoSided() = " .. tostring(parent:IsTwoSided())) end)
            pcall(function() out("  LightingChannels = ch0:" .. tostring(comp.LightingChannels.bChannel0) .. " ch1:" .. tostring(comp.LightingChannels.bChannel1) .. " ch2:" .. tostring(comp.LightingChannels.bChannel2)) end)
        end)
        return true
    end)

    -- lbsignglow <intensity> [radius] [offset] [falloff] [invsq 0/1] -- live-tune the Glow light, re-applies the last-probed sign.
    RegisterConsoleCommandHandler("lbsignglow", function(FullCommand, Parameters, Ar)
        local function out(m) say(m, Ar) end
        pcall(function()
            local p = Parameters or {}
            local i, r, o, fo = tonumber(p[1]), tonumber(p[2]), tonumber(p[3]), tonumber(p[4])
            local inv = tonumber(p[5])
            if inv then Signs.GLOW_INVSQ = (inv ~= 0) end
            if fo then Signs.GLOW_FALLOFF = fo end
            if i then Signs.GLOW_INTENSITY = i end
            if r then Signs.GLOW_RADIUS = r end
            if o then Signs.GLOW_OFFSET = o end
            out(string.format("full-bright light: intensity=%.2f radius=%.0f offset=%.1f falloff=%.2f invsq=%s", Signs.GLOW_INTENSITY, Signs.GLOW_RADIUS, Signs.GLOW_OFFSET, Signs.GLOW_FALLOFF, tostring(Signs.GLOW_INVSQ)))
            local actor = Signs._target
            if not (actor and actor:IsValid()) then actor = Signs._spawner and Signs._spawner._lastProbedActor end
            local rec = actor and actor:IsValid() and Signs._applied[actorKey(actor)]
            if (i or r or o or fo or inv) and rec and rec.lines then
                local okA, msg = Signs.Apply(actor, rec.lines, { yaw = rec.yaw, glow = true, color = Signs.CurrentColor(actor), noSave = true })
                out("re-applied with glow: " .. tostring(msg))
            end
        end)
        return true
    end)

    RegisterConsoleCommandHandler("lbsignmargin", function(FullCommand, Parameters, Ar)
        local function out(m) say(m, Ar) end
        pcall(function()
            local actor = Spawner and Spawner._lastProbedActor
            local t = actor and actor:IsValid() and Signs.FindType(actor)
            if not t then out("No probed sign -- run lbprobe on a sign first.") return end
            local p = Parameters or {}
            local x, y = tonumber(p[1]), tonumber(p[2])
            if x then t.marginX = x; t.marginY = y or x end
            out(string.format("%s margin: X=%.1f Y=%.1f uu per side (board %.0fx%.0f)", t.name, t.marginX or 0, t.marginY or 0, t.boardW, t.boardH))
            local rec = Signs._applied[actorKey(actor)]
            if x and rec and rec.lines then
                local okA, msg = Signs.Apply(actor, rec.lines, { yaw = rec.yaw })
                out("re-applied: " .. tostring(msg))
            end
        end)
        return true
    end)
    -- lbmeshshift x=<n> y=<n> z=<n> | reset  (2026-10-01): live-tune how far the MESH sits from its actor (actor frame: +X out from the wall, +Y right, +Z up) for
    -- the selected object (Text tab Select Object, else the last probed one). Stored in Config.LOOT_MESH_BASE_OFFSET for this session, so every piece of that mesh
    -- (and its text anchor) uses it; the printed line is what to bake into config.lua. Re-Apply the text afterwards to see it follow.
    RegisterConsoleCommandHandler("lbmeshshift", function(FullCommand, Parameters, Ar)
        local function out(m) say(m, Ar) end
        pcall(function()
            local actor = Signs._target
            local okT = false
            if actor then pcall(function() okT = actor:IsValid() end) end
            if not okT then actor = Spawner and Spawner._lastProbedActor end
            if not (actor and actor:IsValid()) then out("Nothing selected -- use Select Object in the Text tab, or lbprobe first.") return end
            local mc = actor.MeshComponent
            if not (mc and mc:IsValid()) then out("That object has no MeshComponent.") return end
            local meshPath
            pcall(function() meshPath = mc.StaticMesh:GetFullName():match("^%S+%s+(.+)$") end)
            if not meshPath then out("Could not read the mesh path.") return end
            local cfg = Signs._config
            cfg.LOOT_MESH_BASE_OFFSET = cfg.LOOT_MESH_BASE_OFFSET or {}
            local cur = cfg.LOOT_MESH_BASE_OFFSET[meshPath] or {}
            local new = { X = cur.X or 0.0, Y = cur.Y or 0.0, Z = cur.Z or 0.0 }
            for _, tok in ipairs(Parameters or {}) do
                local k, v = tostring(tok):match("^(%a+)=(.+)$")
                if tostring(tok):lower() == "reset" then new = { X = 0.0, Y = 0.0, Z = 0.0 }
                elseif k and tonumber(v) then new[k:upper()] = tonumber(v) end
            end
            cfg.LOOT_MESH_BASE_OFFSET[meshPath] = new
            mc:K2_SetRelativeLocation({ X = new.X, Y = new.Y, Z = new.Z }, false, {}, true)
            out(string.format("mesh shift %s", meshPath:match("([^/]+)$") or meshPath))
            out(string.format("  [\"%s\"] = { X = %.1f, Y = %.1f, Z = %.1f },", meshPath, new.X, new.Y, new.Z))
            out("  (actor frame: +X out from the wall, +Y right, +Z up) -- re-Apply the text to see it follow; send me this line to bake it in.")
        end)
        return true
    end)
    -- lbsolid [on|off] (2026-10-01, RedFalcon: "so the obelisk is a mesh and not solid. is it possible to have a solid hitbox?"): TEST command. Raw meshes spawn inside
    -- R5LootActor, whose collision defaults to an OVERLAP pickup trigger (memory: feedback_r5lootactor_not_a_blocker). `on` applies the proven idiom to the mesh and the
    -- root -- SetCollisionEnabled(3 = QueryAndPhysics) + SetCollisionResponseToAllChannels(2 = Block) -- and prints what it reads back; walk into the object to see if it
    -- blocks you. If it still does not, the mesh has no collision shapes of its own (the BodySetup readout below says so) and a box collision is the fallback.
    -- `off` puts overlap-only back (QueryOnly + Overlap). Acts on the Text tab's selected object, else the locked target, else the last probed one. Session-only.
    RegisterConsoleCommandHandler("lbsolid", function(FullCommand, Parameters, Ar)
        local function out(m) say(m, Ar) end
        pcall(function()
            local actor = Signs._target
            local okT = false
            if actor then pcall(function() okT = actor:IsValid() end) end
            if not okT then
                actor = Spawner and Spawner.lockedTarget and Spawner.lockedTarget.actor
                okT = false
                if actor then pcall(function() okT = actor:IsValid() end) end
            end
            if not okT then actor = Spawner and Spawner._lastProbedActor end
            if not (actor and actor:IsValid()) then out("Nothing selected -- Select Object in the Text tab, lock with Num+, or lbprobe first.") return end
            local mode = tostring((Parameters or {})[1] or "on"):lower()
            local solid = (mode ~= "off")
            local mc, root
            pcall(function() mc = actor.MeshComponent end)
            pcall(function() root = actor:K2_GetRootComponent() end)
            local function apply(c)
                if not (c and c:IsValid()) then return end
                if solid then
                    pcall(function() c:SetCollisionEnabled(3) end)
                    pcall(function() c:SetCollisionResponseToAllChannels(2) end)
                else
                    pcall(function() c:SetCollisionEnabled(1) end)
                    pcall(function() c:SetCollisionResponseToAllChannels(1) end)
                end
            end
            pcall(function() actor:SetActorEnableCollision(true) end)
            apply(mc)
            apply(root)
            local function num(f)
                local ok, v = pcall(f)
                local n = ok and tonumber(v) or nil
                return n and tostring(n) or "?"
            end
            out(string.format("lbsolid %s on %s", solid and "ON" or "OFF", (Signs.FindType(actor) and Signs.FindType(actor).name) or "the selected object"))
            if mc and mc:IsValid() then
                out(string.format("  mesh:  CollisionEnabled=%s (3 = QueryAndPhysics)  Pawn response=%s (2 = Block)", num(function() return mc:GetCollisionEnabled() end),
                    num(function() return mc:GetCollisionResponseToChannel(3) end)))
            end
            if root and root:IsValid() then
                out(string.format("  root:  CollisionEnabled=%s  Pawn response=%s", num(function() return root:GetCollisionEnabled() end),
                    num(function() return root:GetCollisionResponseToChannel(3) end)))
            end
            -- does the mesh itself carry collision shapes? (0 shapes = Block can never stop anything)
            pcall(function()
                local bs = mc.StaticMesh.BodySetup
                if not (bs and bs:IsValid()) then out("  mesh asset has NO BodySetup (no collision data at all).") return end
                local agg = bs.AggGeom
                local parts = {}
                for _, nm in ipairs({ "ConvexElems", "BoxElems", "SphereElems", "SphylElems" }) do
                    parts[#parts + 1] = nm .. "=" .. num(function() return agg[nm]:GetArrayNum() end)
                end
                out(string.format("  mesh collision shapes: %s  CollisionTraceFlag=%s (0 default, 1 simple-and-complex, 2 simple, 3 complex-as-simple)",
                    table.concat(parts, " "), num(function() return bs.CollisionTraceFlag end)))
            end)
            out(solid and "  Now walk into it. If you can still pass through, send me these lines." or "  Back to overlap-only.")
        end)
        return true
    end)
    do
        local reg = rawget(_G, "__LB_RegisterCmdInfo")
        if reg then
            reg("lbtestsigntext", "lbtestsigntext <text; or | between lines> [size= x= y= z= yaw= roll= pitch= bw= bh= font= color= spacing= rowstep=]", "Writes text on the targeted / last-probed sign for tuning. x is the absolute depth, y and z are offsets from the anchor, size is a cap, bw/bh set the board size.")
            reg("lbsignmat", "lbsignmat <materialPath> | albedo <texturePath> | restore", "Material tests on slot 0 of the targeted sign mesh.")
            reg("lbsignscan", "lbsignscan [pairRadius] [nearMe]", "Measures placed wooden labels against nearby containers to get a sign type's anchor.")
            reg("lbsignmatinfo", "lbsignmatinfo", "Prints the sign text material's blend mode, shading model and lighting settings.")
            reg("lbsignglow", "lbsignglow [intensity] [radius]", "Tunes the full-bright light used by the sign text Add Glow option.")
            reg("lbsignmargin", "lbsignmargin <x> [y]", "Sets the text margin of the targeted sign type live.")
            reg("lbmeshshift", "lbmeshshift x=<n> y=<n> z=<n> | reset", "Moves a loot-mesh sign's mesh relative to its actor (prints the Config line to bake in).")
            reg("lbsolid", "lbsolid [on|off]", "Tests making the targeted loot mesh solid; prints collision readbacks.")
        end
    end
    say("Console commands registered: lbtestsigntext, lbsignmargin, lbmeshshift, lbsolid")

    -- Bridge poll (400ms) + sweep (~5s). Same recursive ExecuteWithDelay pattern as the Barbie bridge.
    if ExecuteWithDelay then
        local tick = 0
        local function loop()
            ExecuteWithDelay(400, function()
                -- Run on the GAME thread (2026-09-30): ExecuteWithDelay's callback is not guaranteed to be it, and text set from
                -- here rendered in the default font (the Font property write needs a render refresh that only landed from the
                -- game thread) -- while the very same Apply from lbtestsigntext, which runs on it, showed the new font.
                -- Idle unless the spawn-menu window is open (2026-09-30): every queued game-thread job is one more callback that
                -- can be run re-entrantly when the engine loads an asset mid-restore -- the suspected trigger of the recurring
                -- 'Ref was not function ... removing hook' hook death. The Signs tab is only usable with the window open anyway.
                local open = true
                if Signs._spawner and Signs._spawner.IsMenuOpen then
                    local okO, v = pcall(Signs._spawner.IsMenuOpen)
                    if okO then open = v and true or false end
                end
                if open then
                    ExecuteInGameThread(function()
                        pcall(function() Signs.PollRequest() end)
                        pcall(function() Signs.PublishStatus() end)
                        pcall(Signs.RekeySpawned)   -- a spawned sign moved with the window open: keep its saved text attached (the sweep is off by default)
                    end)
                end
                tick = tick + 1
                if tick % 150 == 0 and not (Signs._config and Signs._config.SIGNS_SWEEP == false) then   -- ~60 s safety net only (signs that stream in later); the restore itself fills signs in line now
                    ExecuteInGameThread(function() pcall(function() Signs.Sweep() end) end)
                end
                loop()
            end)
        end
        loop()
        say("sign bridge armed -- watching sign_request.txt")
    end
end

return Signs
