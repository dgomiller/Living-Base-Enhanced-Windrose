--[[
 LivingBase / fkeys.lua — decor placement key bindings and category data.

 2026-08-13: replaced the original F1-F8 layout (one physical key per decor category, plus the
 Blackbeard raid flag/trigger) with a 2-key "active category" design so the mod never touches the
 F-row at all. Some other mods (e.g. WeatherControl, Shift+F1-F12) also bind the F-row, and this
 UE4SS build's 3-arg modifier bind (Shift+Fx) doesn't reliably distinguish itself from plain Fx, so
 two mods binding the same physical F-key both fire on every press -- moving off the F-row entirely
 sidesteps that class of conflict by construction rather than by picking keys and hoping.

 Design: ';' (decorSpawn) always places from whichever category is currently ACTIVE; ''' (
 decorCategory) advances which category is active (wraps through Config.DECOR_ORDER, announced via
 toast/log) without spawning anything itself. See testbed.lua's Testbed.CycleDecorCategory /
 Testbed.SpawnActiveDecorCategory, and main.lua's registration of both keys.

 Isolated in its own file (rather than inline in config.lua) purely to keep config.lua from getting
 any bigger -- Config.KEYS still gets these merged in by config.lua's require of this file.
]]
local FKeys = {}

-- Which physical key each action binds.
FKeys.KEYS = {
  decorSpawn    = "OEM_SEMICOLON", -- ';'  place one from the ACTIVE category
  decorCategory = "OEM_QUOTE",     -- '''  advance the active category (no spawn)
}

-- Cycle order for the active decor category (Testbed.CycleDecorCategory steps forward through
-- this list, wrapping around). Any subset/reordering of Config.DECOR_CATEGORIES' keys is valid.
FKeys.DECOR_ORDER = {
  "nature", "boats", "wrecks", "tents", "storage", "furniture",
  "invdrop_animalparts", "invdrop_artifacts", "invdrop_clothes", "invdrop_currency",
  "invdrop_ingredients", "invdrop_keys", "invdrop_meals", "invdrop_mined", "invdrop_misc",
  "invdrop_potions", "invdrop_seeds", "invdrop_tailoring", "invdrop_tools", "invdrop_treasure",
  "invdrop_trophies", "invdrop_weapons", "invdrop_wood", "invdrop_writings",
}

-- DECORATIONS: static world props placed as scenery — dodo nests, mushroom clusters, shipwrecks,
-- etc. They spawn INERT (harvest/respawn needs registration we can't do), so they're pure set-
-- dressing: invulnerable, persisted. These props' MESH sits offset above their actor root, so a
-- fresh spawn floats; `zoffset` (UU, added to the ground Z) is a per-entry starting correction (0 =
-- root on ground, negative = lower). It only has to be close — the live-edit keys ('-'/PageUp)
-- nudge each to sit perfectly in the base, and that edit persists. Add more props by probing a
-- wild one for its class (ASSET_CATALOG.md workflow).
FKeys.DECOR_CATEGORIES = {
  -- Nature  (13)
  nature = {
    { name = "CoastJungleMineralMushroom_01", zoffset = 0.0, path = "/Game/Environment/Props/RuinsTypeA/Debris/BP_Mineral/BP_CoastJungleMineralMushroom_01.BP_CoastJungleMineralMushroom_01_C" },
    { name = "CoastJungleMineralMushroom_02", zoffset = 0.0, path = "/Game/Environment/Props/RuinsTypeA/Debris/BP_Mineral/BP_CoastJungleMineralMushroom_02.BP_CoastJungleMineralMushroom_02_C" },
    { name = "CoastJungleMineralNestDodo_01", zoffset = 0.0, path = "/Game/Environment/Props/RuinsTypeA/Debris/BP_Mineral/BP_CoastJungleMineralNestDodo_01.BP_CoastJungleMineralNestDodo_01_C" },
    { name = "CoastJungleMineralNestDodo_02", zoffset = 0.0, path = "/Game/Environment/Props/RuinsTypeA/Debris/BP_Mineral/BP_CoastJungleMineralNestDodo_02.BP_CoastJungleMineralNestDodo_02_C" },
    { name = "CoastJungleMineralRootDebris_01", zoffset = 0.0, path = "/Game/Environment/Props/RuinsTypeA/Debris/BP_Mineral/BP_CoastJungleMineralRootDebris_01.BP_CoastJungleMineralRootDebris_01_C" },
    { name = "Mineral_MiddleRock_04", zoffset = 0.0, path = "/Game/Gameplay/Foliage/MinaralNodes/MiddleRock/BP_Mineral_MiddleRock_04.BP_Mineral_MiddleRock_04_C" },
    { name = "Mineral_MiddleRock_05", zoffset = 0.0, path = "/Game/Gameplay/Foliage/MinaralNodes/MiddleRock/BP_Mineral_MiddleRock_05.BP_Mineral_MiddleRock_05_C" },
    { name = "Segment_Coast_Jungle_PalmCoconutFruit_700cm", zoffset = 0.0, path = "/Game/Gameplay/Foliage/SegmentTrees/BPSegmentTrees/BP_Segment_Coast_Jungle_PalmCoconutFruit_700cm.BP_Segment_Coast_Jungle_PalmCoconutFruit_700cm_C" },
    { name = "Segment_Coast_Jungle_PalmCoconutFruit_1000cm", zoffset = 0.0, path = "/Game/Gameplay/Foliage/SegmentTrees/BPSegmentTrees/BP_Segment_Coast_Jungle_PalmCoconutFruit_1000cm.BP_Segment_Coast_Jungle_PalmCoconutFruit_1000cm_C" },
    { name = "Segment_Coast_Jungle_PalmCoconutFruit_1400cm", zoffset = 0.0, path = "/Game/Gameplay/Foliage/SegmentTrees/BPSegmentTrees/BP_Segment_Coast_Jungle_PalmCoconutFruit_1400cm.BP_Segment_Coast_Jungle_PalmCoconutFruit_1400cm_C" },
    { name = "Segment_Coast_Jungle_PalmSabal_250cm", zoffset = 0.0, path = "/Game/Gameplay/Foliage/SegmentTrees/BPSegmentTrees/BP_Segment_Coast_Jungle_PalmSabal_250cm.BP_Segment_Coast_Jungle_PalmSabal_250cm_C" },
    { name = "Segment_Coast_Jungle_PalmSabal_450cm", zoffset = 0.0, path = "/Game/Gameplay/Foliage/SegmentTrees/BPSegmentTrees/BP_Segment_Coast_Jungle_PalmSabal_450cm.BP_Segment_Coast_Jungle_PalmSabal_450cm_C" },
    { name = "Segment_Highlands_Divi_1200cm", zoffset = 0.0, path = "/Game/Gameplay/Foliage/SegmentTrees/BPSegmentTrees/BP_Segment_Highlands_Divi_1200cm.BP_Segment_Highlands_Divi_1200cm_C" },
  },
  -- Boats  (5)
  boats = {
    { name = "PortBoat_01", zoffset = 0.0, path = "/Game/Environment/Props/PortProps/BP_PortBoat_01.BP_PortBoat_01_C" },
    { name = "PortBoat_02", zoffset = 0.0, path = "/Game/Environment/Props/PortProps/BP_PortBoat_02.BP_PortBoat_02_C" },
    { name = "Shared_Camp_PropsComposition_72", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_72.BP_Shared_Camp_PropsComposition_72_C" },
    { name = "Shared_Camp_PropsComposition_75", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_75.BP_Shared_Camp_PropsComposition_75_C" },
    { name = "Shared_Camp_PropsComposition_76", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_76.BP_Shared_Camp_PropsComposition_76_C" },
  },
  -- Wrecks  (5)
  wrecks = {
    { name = "Shipwreck_Boat_01_01", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/WrecksNode/BoatWreck/BP_Shipwreck_Boat_01_01.BP_Shipwreck_Boat_01_01_C" },
    { name = "Shipwreck_Boat_01_03", zoffset = 0.0, path = "/Game/Environment/Props/POIElements/BP_Shipwreck_Boat_01_03.BP_Shipwreck_Boat_01_03_C" },
    { name = "Shipwreck_Cutter_01_02", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/WrecksNode/CutterWreck/BP_Shipwreck_Cutter_01_02.BP_Shipwreck_Cutter_01_02_C" },
    { name = "Shipwreck_Cutter_02_02", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/WrecksNode/CutterWreck/BP_Shipwreck_Cutter_02_02.BP_Shipwreck_Cutter_02_02_C" },
    { name = "Shipwreck_Spanthout_01_02", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/WrecksNode/SpanthoutWreck/BP_Shipwreck_Spanthout_01_02.BP_Shipwreck_Spanthout_01_02_C" },
  },
  -- Tents / Bedrolls  (12)
  tents = {
    { name = "Shared_CampTents_02", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTents_02.BP_Shared_CampTents_02_C" },
    { name = "Shared_CampTents_04_01", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTents_04_01.BP_Shared_CampTents_04_01_C" },
    { name = "Shared_CampTents_11", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTents_11.BP_Shared_CampTents_11_C" },
    { name = "Shared_CampTents_12", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTents_12.BP_Shared_CampTents_12_C" },
    { name = "Shared_CampTents_13", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTents_13.BP_Shared_CampTents_13_C" },
    { name = "Shared_CampTents_14", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTents_14.BP_Shared_CampTents_14_C" },
    { name = "Shared_CampTents_15", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTents_15.BP_Shared_CampTents_15_C" },
    { name = "Shared_CampTents_19", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTents_19.BP_Shared_CampTents_19_C" },
    { name = "Shared_CampTents_Abandoned_01", zoffset = 0.0, path = "/Game/Gameplay/POI/CoastJungle/CoastJungle_Props/BP_Shared_CampTents_Abandoned_01.BP_Shared_CampTents_Abandoned_01_C" },
    { name = "Shared_CampTentsBB_11", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTentsBB_11.BP_Shared_CampTentsBB_11_C" },
    { name = "Shared_CampTentsBB_12", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTentsBB_12.BP_Shared_CampTentsBB_12_C" },
    { name = "Shared_CampTentsBB_14", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/CampTents/BP_Shared_CampTentsBB_14.BP_Shared_CampTentsBB_14_C" },
  },
  -- Storage Clutter  (21)
  storage = {
    { name = "Shared_Camp_PropsComposition_01", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_01.BP_Shared_Camp_PropsComposition_01_C" },
    { name = "Shared_Camp_PropsComposition_02", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_02.BP_Shared_Camp_PropsComposition_02_C" },
    { name = "Shared_Camp_PropsComposition_05", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_05.BP_Shared_Camp_PropsComposition_05_C" },
    { name = "Shared_Camp_PropsComposition_11", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_11.BP_Shared_Camp_PropsComposition_11_C" },
    { name = "Shared_Camp_PropsComposition_12", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_12.BP_Shared_Camp_PropsComposition_12_C" },
    { name = "Shared_Camp_PropsComposition_14", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_14.BP_Shared_Camp_PropsComposition_14_C" },
    { name = "Shared_Camp_PropsComposition_15", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_15.BP_Shared_Camp_PropsComposition_15_C" },
    { name = "Shared_Camp_PropsComposition_18", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_18.BP_Shared_Camp_PropsComposition_18_C" },
    { name = "Shared_Camp_PropsComposition_23", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_23.BP_Shared_Camp_PropsComposition_23_C" },
    { name = "Shared_Camp_PropsComposition_24", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_24.BP_Shared_Camp_PropsComposition_24_C" },
    { name = "Shared_Camp_PropsComposition_26", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_26.BP_Shared_Camp_PropsComposition_26_C" },
    { name = "Shared_Camp_PropsComposition_27", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_27.BP_Shared_Camp_PropsComposition_27_C" },
    { name = "Shared_Camp_PropsComposition_28", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_28.BP_Shared_Camp_PropsComposition_28_C" },
    { name = "Shared_Camp_PropsComposition_30", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_30.BP_Shared_Camp_PropsComposition_30_C" },
    { name = "Shared_Camp_PropsComposition_46", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_46.BP_Shared_Camp_PropsComposition_46_C" },
    { name = "Shared_Camp_PropsComposition_47", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_47.BP_Shared_Camp_PropsComposition_47_C" },
    { name = "Shared_Camp_PropsComposition_51", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_51.BP_Shared_Camp_PropsComposition_51_C" },
    { name = "Shared_Camp_PropsComposition_52", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_52.BP_Shared_Camp_PropsComposition_52_C" },
    { name = "Shared_Camp_PropsComposition_53", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_53.BP_Shared_Camp_PropsComposition_53_C" },
    { name = "Shared_Camp_PropsComposition_64", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_64.BP_Shared_Camp_PropsComposition_64_C" },
    { name = "Shared_Camp_PropsComposition_65", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_65.BP_Shared_Camp_PropsComposition_65_C" },
  },
  -- Furniture  (21)
  furniture = {
    { name = "BenchCrateT01_01", zoffset = 0.0, path = "/Game/Gameplay/Building/Actors/Furniture/BP_BenchCrateT01_01.BP_BenchCrateT01_01_C" },
    { name = "BrokenStockade_LadderComposition_01", zoffset = 0.0, path = "/Game/Gameplay/POI/CoastJungle/CoastJungle_Props/BP_BrokenStockade_LadderComposition_01.BP_BrokenStockade_LadderComposition_01_C" },
    { name = "ChestVisual_BigWooden_BBChest_04", zoffset = 0.0, path = "/Game/Gameplay/Scenario/POI/ChestVisual/BP_ChestVisual_BigWooden_BBChest_04.BP_ChestVisual_BigWooden_BBChest_04_C" },
    { name = "ChestVisual_Blackbeard_01", zoffset = 0.0, path = "/Game/Gameplay/Scenario/POI/ChestVisual/BP_ChestVisual_Blackbeard_01.BP_ChestVisual_Blackbeard_01_C" },
    { name = "ChestVisual_Clay_01", zoffset = 0.0, path = "/Game/Gameplay/Scenario/POI/ChestVisual/BP_ChestVisual_Clay_01.BP_ChestVisual_Clay_01_C" },
    { name = "Shared_Camp_PropsComposition_04", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_04.BP_Shared_Camp_PropsComposition_04_C" },
    { name = "Shared_Camp_PropsComposition_10", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_10.BP_Shared_Camp_PropsComposition_10_C" },
    { name = "Shared_Camp_PropsComposition_16", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_16.BP_Shared_Camp_PropsComposition_16_C" },
    { name = "Shared_Camp_PropsComposition_25", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_25.BP_Shared_Camp_PropsComposition_25_C" },
    { name = "Shared_Camp_PropsComposition_29", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_29.BP_Shared_Camp_PropsComposition_29_C" },
    { name = "Shared_Camp_PropsComposition_31", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_31.BP_Shared_Camp_PropsComposition_31_C" },
    { name = "Shared_Camp_PropsComposition_59", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_59.BP_Shared_Camp_PropsComposition_59_C" },
    { name = "Shared_Camp_PropsComposition_60", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_60.BP_Shared_Camp_PropsComposition_60_C" },
    { name = "Shared_Camp_PropsComposition_61", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_61.BP_Shared_Camp_PropsComposition_61_C" },
    { name = "Shared_Camp_PropsComposition_69", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_69.BP_Shared_Camp_PropsComposition_69_C" },
    -- Composition_70 (the old Blackbeard raid flag prop) is NOT in this list — it was reserved for
    -- the now-removed raid feature's dedicated key. Currently unreachable in-game; add it here if it
    -- should just become a normal furniture piece.
    { name = "Tortuga_Wardrobe_02", zoffset = 0.0, path = "/Game/Gameplay/POI/Tortuga/Tortuga_NPC_InteractionProps/BP_Tortuga_Wardrobe_02.BP_Tortuga_Wardrobe_02_C" },
    { name = "WardrobeAshlands_04", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/Furniture/BP_Shared_DestructibleStructures_WardrobeAshlands_04.BP_Shared_DestructibleStructures_WardrobeAshlands_04_C" },
    { name = "WardrobeAshlands_06", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/Furniture/BP_Shared_DestructibleStructures_WardrobeAshlands_06.BP_Shared_DestructibleStructures_WardrobeAshlands_06_C" },
    { name = "WardrobeAshlands_09", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/Furniture/BP_Shared_DestructibleStructures_WardrobeAshlands_09.BP_Shared_DestructibleStructures_WardrobeAshlands_09_C" },
    { name = "WindChime_02", zoffset = 0.0, path = "/Game/Gameplay/POI/CoastJungle/CoastJungle_Props/BP_WindChime_02.BP_WindChime_02_C" },
  },
  -- Drops (238, split into 18 hand-curated subcategories) (2026-08-17). Every OTHER category above
  -- spawns a per-prop Blueprint (BP_..._C) with its mesh baked in at the class level, so a raw
  -- Spawner.Spawn() renders it correctly with zero extra setup. R5LootActor (the single native
  -- class every dropped item shares, identified via a HOME+PAUSE live probe -- see
  -- WINDROSE_MODDING_NOTES.md) is DIFFERENT: its MeshComponent is normally populated from
  -- `LootView` at the moment a real item is actually dropped, not baked into the class --
  -- confirmed live that a bare Spawner.Spawn() alone renders INVISIBLE (collision + interact
  -- prompt, no mesh). Also confirmed live that the "proper" fix (reading the item DataAsset's own
  -- ItemMesh property) is a dead end in this UE4SS build -- ItemMesh is an opaque
  -- TSoftObjectPtrUserdata with no working methods (see Spawner.SetLootMesh's own comment). The
  -- `mesh` field below is the actual working fix: a real static-mesh asset path, force-assigned by
  -- placeDecorEntry (testbed.lua) via Spawner.SetLootMesh, immediately followed by
  -- Spawner.MakeLootDecor so these behave as pure set-dressing (no pickup prompt/toss physics/
  -- sparkle) like every other decor category, not as real pickups.
  --
  -- Originally 148 entries, found MECHANICALLY, not by dropping each one live, by grepping
  -- UE4SS_ObjectDump.txt for every StaticMesh under two assumed-exhaustive prefixes
  -- (`/Game/Environment/Gameplay/Resources/<Sub>/` and `/Game/Character/Skeletal_Meshes/
  -- Weapons/*/Drop/`), confirmed by the 4 hand-probed items (Stone/Wood/Leather/PickaxeT03, via
  -- Spawner.ProbeNearestLootMesh) all landing in exactly those two trees. `name` is the asset's own
  -- short filename (SM_/SM_Drop_ prefix stripped) -- deliberately mechanical, not hand-curated,
  -- same "auto-generation isn't prettification" philosophy spawnmenu_manifest.lua's own header
  -- already documents.
  --
  -- 2026-08-17, two rounds of revisiting this roster against a fresh object dump: (1) Fossils
  -- removed entirely as mostly duplicate meshes of Resources/Craft, its 3 Oil siblings folded into
  -- Potions instead of left as their own 3-entry category (net -6). (2) The "two assumed-exhaustive
  -- prefixes" premise above turned out to be WRONG -- re-scanning by filename pattern
  -- (`SM_Drop_*` anywhere) instead of trusting the folder shape turned up a fishing-rod drop that
  -- sits one folder deeper AND skips the literal `Drop` folder name entirely (added to Weapon
  -- Drops), a `Resources/Food/` folder that isn't `Resources/Consumables/` despite its own
  -- filenames still saying "Consumables_Second_..." (folded into Consumables, same reasoning as
  -- Oil), a Craft item the original dump snapshot hadn't loaded yet, and a WHOLE THIRD prefix
  -- (`Character/Skeletal_Meshes/Armor/ArmorRegular/<Set>/Meshes/Drops/`) the original two-prefix
  -- search had no reason to ever look at -- 17 armor-piece drops, new `invdrop_armordrops` (net
  -- +21). Current total: 163. **Takeaway for next time this needs revisiting**: don't trust a
  -- folder-shape assumption to be exhaustive just because it explained every item found so far --
  -- a `SM_Drop_`-style filename-pattern grep across the WHOLE dump is the search that actually
  -- catches outliers, and is worth re-running periodically as the game patches in new content.
  -- NOT live-tested individually beyond the original 4 -- if one
  -- renders wrong/invisible, the asset path is still worth double-checking against a live drop.
  --
  -- 2026-08-17, later the same day: RedFalcon reviewed the FULL roster (the folder-based categories
  -- above, plus everything the test-tree rounds turned up) in a spreadsheet
  -- (Other/Inventory Drops List.xlsx -- Resource Name/Tree Location/Proper Name columns) and
  -- replaced the folder-shaped groupings entirely with 18 hand-picked THEMATIC categories (Animal
  -- Parts, Artifacts, Clothes, Currency, Ingredients, Keys, Meals, Mined, Misc, Potions/Bottles/
  -- Healing, Seeds, Tailoring, Tools, Treasure, Trophies, Weapons, Wood, Writings) -- "Inventory
  -- Drops" as a GUI branch renamed to just "Drops" too (spawnmenu_manifest.lua). 8 entries got
  -- dropped in this pass as dupes/rejects (LinenFabric, Leather x1, both Tortuga Employee meshes,
  -- PickaxeT03_01, ResourcesT01_Stone/Wood_01, the review-round IronT03_RawOre_01), and
  -- StoneSource_01 (one of the 6 originally-removed Fossils entries) came back in. Every entry below
  -- now carries a `label` field too -- a real display name ("Bezoar", not "Loot_T02_Bezoar_01") used
  -- for the GUI tree leaf and spawn/despawn toasts (see decor_path_and_label in
  -- spawnmenu_manifest.lua and placeDecorEntry in testbed.lua) -- `name` stays exactly as it was,
  -- since Testbed.SpawnDecorByName/persist both key off it and it must keep matching the mesh lookup
  -- table above unchanged.
  invdrop_animalparts = { -- Drops > Animal Parts (8)
    { name = "Loot_T02_Bezoar_01", label = "Bezoar", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_Bezoar_01.SM_Loot_T02_Bezoar_01" },
    { name = "Loot_T01_BoarTusk_01", label = "Boar Tusk", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_BoarTusk_01.SM_Loot_T01_BoarTusk_01" },
    { name = "Loot_T03_CrocodileTears_01", label = "Crocodile Tears", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T03_CrocodileTears_01.SM_Loot_T03_CrocodileTears_01" },
    { name = "Loot_T03_Firefly_01_SM_Loot_T03_Firefly_01", label = "Firefly", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T03_Firefly_01_SM_Loot_T03_Firefly_01.SM_Loot_T03_Firefly_01_SM_Loot_T03_Firefly_01" },
    { name = "Loot_T02_GoatHorn_01", label = "Goat Horn", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_GoatHorn_01.SM_Loot_T02_GoatHorn_01" },
    { name = "Consumables_T01_ScallopShellClosed_01", label = "Scallop Shell", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Consumables/SM_Consumables_T01_ScallopShellClosed_01.SM_Consumables_T01_ScallopShellClosed_01" },
    { name = "Loot_T01_TritonsTrumpet_01", label = "Triton's Horn", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_TritonsTrumpet_01.SM_Loot_T01_TritonsTrumpet_01" },
    { name = "Loot_T02_WolfFang_01", label = "Wolf Fang", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_WolfFang_01.SM_Loot_T02_WolfFang_01" },
  },
  invdrop_artifacts = { -- Drops > Artifacts (9)
    { name = "DishesClay_Senkamati_05", label = "Ancient Chalice 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Artifacts/Senkamati/SM_DishesClay_Senkamati_05.SM_DishesClay_Senkamati_05" },
    { name = "DishesMetall_Senkamati_03", label = "Ancient Chalice 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Artifacts/Senkamati/SM_DishesMetall_Senkamati_03.SM_DishesMetall_Senkamati_03" },
    { name = "Mask_Senkamati_02", label = "Gold Mask of the Priest", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Artifacts/Senkamati/SM_Mask_Senkamati_02.SM_Mask_Senkamati_02" },
    { name = "DishesClay_Senkamati_02", label = "Gold Vase of the Chief", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Artifacts/Senkamati/SM_DishesClay_Senkamati_02.SM_DishesClay_Senkamati_02" },
    { name = "Knife_Senkamati_01", label = "Ritual Dagger", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Artifacts/Senkamati/SM_Knife_Senkamati_01.SM_Knife_Senkamati_01" },
    { name = "Mask_Senkamati_01", label = "Ritual Mask", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Artifacts/Senkamati/SM_Mask_Senkamati_01.SM_Mask_Senkamati_01" },
    { name = "DishesMetall_Senkamati_07", label = "Ritual Oil", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Artifacts/Senkamati/SM_DishesMetall_Senkamati_07.SM_DishesMetall_Senkamati_07" },
    { name = "Loot_T03_CorruptedSenkamatiStuff_03", label = "Tainted Mask", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T03_CorruptedSenkamatiStuff_03.SM_Loot_T03_CorruptedSenkamatiStuff_03" },
    { name = "Loot_T03_CorruptedSenkamatiStuff_02", label = "Tainted Totem", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T03_CorruptedSenkamatiStuff_02.SM_Loot_T03_CorruptedSenkamatiStuff_02" },
  },
  invdrop_clothes = { -- Drops > Clothes (17)
    { name = "Armor_Bandit_Feet", label = "Bandit's Boots", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Bandit/Meshes/Drops/SM_Drop_Armor_Bandit_Feet.SM_Drop_Armor_Bandit_Feet" },
    { name = "Armor_Bandit_Hands", label = "Bandit's Gloves", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Bandit/Meshes/Drops/SM_Drop_Armor_Bandit_Hands.SM_Drop_Armor_Bandit_Hands" },
    { name = "Armor_Bandit_Hat", label = "Bandit's Hat", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Bandit/Meshes/Drops/SM_Drop_Armor_Bandit_Hat.SM_Drop_Armor_Bandit_Hat" },
    { name = "Armor_Bandit_Waist", label = "Bandit's Waistcoat", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Bandit/Meshes/Drops/SM_Drop_Armor_Bandit_Waist.SM_Drop_Armor_Bandit_Waist" },
    { name = "HeroM01_HeadClothArtifact_01", label = "Cloth Hat", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Artifact/Meshes/Drops/SM_Drop_HeroM01_HeadClothArtifact_01.SM_Drop_HeroM01_HeadClothArtifact_01" },
    { name = "HeroM01_TorsoClothArtifact_01", label = "Cloth Shirt", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Artifact/Meshes/Drops/SM_Drop_HeroM01_TorsoClothArtifact_01.SM_Drop_HeroM01_TorsoClothArtifact_01" },
    { name = "HeroM01_FeetsClothArtifact_01", label = "Cloth Shoes", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Artifact/Meshes/Drops/SM_Drop_HeroM01_FeetsClothArtifact_01.SM_Drop_HeroM01_FeetsClothArtifact_01" },
    { name = "Armor_Conquistador_01_Torso", label = "Conquistador's Cuirass", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Conquistador/Meshes/Drops/SM_Drop_Armor_Conquistador_01_Torso.SM_Drop_Armor_Conquistador_01_Torso" },
    { name = "Armor_Conquistador_01_Hands_Long", label = "Conquistador's Gloves", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Conquistador/Meshes/Drops/SM_Drop_Armor_Conquistador_01_Hands_Long.SM_Drop_Armor_Conquistador_01_Hands_Long" },
    { name = "Armor_Conquistador_03_Helmet", label = "Conquistador's Helmet 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Conquistador/Meshes/Drops/SM_Drop_Armor_Conquistador_03_Helmet.SM_Drop_Armor_Conquistador_03_Helmet" },
    { name = "Armor_Conquistador_01_BandanaHat", label = "Conquistador's Helmet 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Conquistador/Meshes/Drops/SM_Drop_Armor_Conquistador_01_BandanaHat.SM_Drop_Armor_Conquistador_01_BandanaHat" },
    { name = "Armor_Conquistador_01_Legs", label = "Conquistador's Pants", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Conquistador/Meshes/Drops/SM_Drop_Armor_Conquistador_01_Legs.SM_Drop_Armor_Conquistador_01_Legs" },
    { name = "Armor_FlibustierHero_Feet_Long", label = "Flibustier's Boots", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Flibustier/Meshes/Drops/SM_Drop_Armor_FlibustierHero_Feet_Long.SM_Drop_Armor_FlibustierHero_Feet_Long" },
    { name = "Armor_FlibustierHero_Hands_Long", label = "Flibustier's Gloves", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Flibustier/Meshes/Drops/SM_Drop_Armor_FlibustierHero_Hands_Long.SM_Drop_Armor_FlibustierHero_Hands_Long" },
    { name = "Armor_FlibustierHero_BandanaHat", label = "Flibustier's Hat", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Flibustier/Meshes/Drops/SM_Drop_Armor_FlibustierHero_BandanaHat.SM_Drop_Armor_FlibustierHero_BandanaHat" },
    { name = "Armor_FlibustierHero_Torso", label = "Flibustier's Jacket", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Flibustier/Meshes/Drops/SM_Drop_Armor_FlibustierHero_Torso.SM_Drop_Armor_FlibustierHero_Torso" },
    { name = "Armor_FlibustierHero_Legs", label = "Flibustier's Pants", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Flibustier/Meshes/Drops/SM_Drop_Armor_FlibustierHero_Legs.SM_Drop_Armor_FlibustierHero_Legs" },
  },
  invdrop_currency = { -- Drops > Currency (7)
    { name = "Consumables_T01_PouchCoin_01", label = "Coin Puch", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Consumables/SM_Consumables_T01_PouchCoin_01.SM_Consumables_T01_PouchCoin_01" },
    { name = "Loot_T03_CoinDoubloon_01", label = "Large Doubloon Pile", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T03_CoinDoubloon_01.SM_Loot_T03_CoinDoubloon_01" },
    { name = "Loot_T03_CoinGuinea_01", label = "Large Guinea Pile", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T03_CoinGuinea_01.SM_Loot_T03_CoinGuinea_01" },
    { name = "Loot_T02_CoinPiastre_01", label = "Large Piestre Pile", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_CoinPiastre_01.SM_Loot_T02_CoinPiastre_01" },
    { name = "LootT03_Doubloons_02", label = "Single Doubloon", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_Doubloons_02.SM_LootT03_Doubloons_02" },
    { name = "LootT03_Doubloons_01", label = "Small Doubloon Pile", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_Doubloons_01.SM_LootT03_Doubloons_01" },
    { name = "Loot_T01_CoinReal_01", label = "Small Piestre Pile", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_CoinReal_01.SM_Loot_T01_CoinReal_01" },
  },
  invdrop_ingredients = { -- Drops > Ingredients (27)
    { name = "Resources_T02_AloeLeaf_01", label = "Aloe Leaf", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T02_AloeLeaf_01.SM_Resources_T02_AloeLeaf_01" },
    { name = "LootT01_Fat_01", label = "Animal Fat", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_Fat_01.SM_LootT01_Fat_01" },
    { name = "ResourcesT03_Banana_01", label = "Banana", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT03_Banana_01.SM_ResourcesT03_Banana_01" },
    { name = "Bean_01", label = "Bean", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_Bean_01.SM_Bean_01" },
    { name = "LootT01_MeatBird_01", label = "Bird Meat", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_MeatBird_01.SM_LootT01_MeatBird_01" },
    { name = "ResourcesT02_Bromeliaceae_01", label = "Bromeliad", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT02_Bromeliaceae_01.SM_ResourcesT02_Bromeliaceae_01" },
    { name = "Loot_Tortuga_CaneSugar_01", label = "Cane Sugar", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_CaneSugar_01.SM_Loot_Tortuga_CaneSugar_01" },
    { name = "ResourcesT01_Pepper_01", label = "Cayenne Pepper", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT01_Pepper_01.SM_ResourcesT01_Pepper_01" },
    { name = "Loot_Tortuga_CocoaBeans_01", label = "Cocoa Beans", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_CocoaBeans_01.SM_Loot_Tortuga_CocoaBeans_01" },
    { name = "ResourcesT01_Coconut_01", label = "Coconut", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT01_Coconut_01.SM_ResourcesT01_Coconut_01" },
    { name = "ResourcesT02_Icaco_01", label = "Cocoplum", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT02_Icaco_01.SM_ResourcesT02_Icaco_01" },
    { name = "Craft_T02_Cornmeal_01", label = "Cornmeal", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T02_Cornmeal_01.SM_Craft_T02_Cornmeal_01" },
    { name = "LootT01_MeatCrab_01", label = "Crab Meat", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_MeatCrab_01.SM_LootT01_MeatCrab_01" },
    { name = "LootT02_MeatReptile_01", label = "Crocodile Meat", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT02_MeatReptile_01.SM_LootT02_MeatReptile_01" },
    { name = "LootT01_DodoEgg_01", label = "Dodo Egg", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_LootT01_DodoEgg_01.SM_LootT01_DodoEgg_01" },
    { name = "LootT02_Feather_01", label = "Feathers", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT02_Feather_01.SM_LootT02_Feather_01" },
    { name = "Resources_T02_FlaxFiber_01", label = "Flax", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T02_FlaxFiber_01.SM_Resources_T02_FlaxFiber_01" },
    { name = "ResourcesT03_Plumeria_01", label = "Frangipani", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT03_Plumeria_01.SM_ResourcesT03_Plumeria_01" },
    { name = "Onion_01", label = "Leek", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_Onion_01.SM_Onion_01" },
    { name = "Lime_01", label = "Lime", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_Lime_01.SM_Lime_01" },
    { name = "ResourcesT01_Lobstershroom_01", label = "Lobster Mushroom", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT01_Lobstershroom_01.SM_ResourcesT01_Lobstershroom_01" },
    { name = "LootT01_Meat_01", label = "Meat", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_Meat_01.SM_LootT01_Meat_01" },
    { name = "MedicinalHerbs_01", label = "Medicinal Herbs", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_MedicinalHerbs_01.SM_MedicinalHerbs_01" },
    { name = "Resources_T01_MistyOrchid_01", label = "Misty Orchid", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T01_MistyOrchid_01.SM_Resources_T01_MistyOrchid_01" },
    { name = "Loot_Tortuga_RareSpice_01", label = "Mysterious Spice", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_RareSpice_01.SM_Loot_Tortuga_RareSpice_01" },
    { name = "Potate_01", label = "Sweet Potato", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_Potate_01.SM_Potate_01" },
    { name = "Tomato_01", label = "Tomato", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_Tomato_01.SM_Tomato_01" },
  },
  invdrop_keys = { -- Drops > Keys (1)
    { name = "Loot_T02_KeyBossArena_01", label = "Foothils Temple Key", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_KeyBossArena_01.SM_Loot_T02_KeyBossArena_01" },
  },
  invdrop_meals = { -- Drops > Meals (14)
    { name = "Consumables_Second_BaconAndEggs", label = "Bacon and Eggs", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Food/SM_Consumables_Second_BaconAndEggs.SM_Consumables_Second_BaconAndEggs" },
    { name = "ConsumablesT01_CrabShrooms_01", label = "Boiled Crab", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT01_CrabShrooms_01.SM_ConsumablesT01_CrabShrooms_01" },
    { name = "ConsumablesT03_PirateFishing_01", label = "Chowder", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT03_PirateFishing_01.SM_ConsumablesT03_PirateFishing_01" },
    { name = "ConsumablesT03_IcacoBanana_01", label = "Cocoberry and Banana", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT03_IcacoBanana_01.SM_ConsumablesT03_IcacoBanana_01" },
    { name = "ConsumablesT02_PuddingCoconut_01", label = "Coconut Pudding", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT02_PuddingCoconut_01.SM_ConsumablesT02_PuddingCoconut_01" },
    { name = "ConsumablesT01_SoupCoconut_01", label = "Coconut Soup", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT01_SoupCoconut_01.SM_ConsumablesT01_SoupCoconut_01" },
    { name = "ConsumablesT02_SoupIcaco_01", label = "Cocoplum Soup", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT02_SoupIcaco_01.SM_ConsumablesT02_SoupIcaco_01" },
    { name = "ConsumablesT01_MeatBirdFried_01", label = "Dodo Leg", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT01_MeatBirdFried_01.SM_ConsumablesT01_MeatBirdFried_01" },
    { name = "ConsumablesT02_FireInTheHole_01", label = "Meat in Tomato-Wine Sauce", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT02_FireInTheHole_01.SM_ConsumablesT02_FireInTheHole_01" },
    { name = "Consumables_Second_BirdOnPotato", label = "Spicy \"Chicken\" with Sweet Potato", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Food/SM_Consumables_Second_BirdOnPotato.SM_Consumables_Second_BirdOnPotato" },
    { name = "ConsumablesT01_CrabFried_01", label = "Spicy Skewered Crab", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT01_CrabFried_01.SM_ConsumablesT01_CrabFried_01" },
    { name = "ConsumablesT02_StewSwamp_01", label = "Swamp Stew", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT02_StewSwamp_01.SM_ConsumablesT02_StewSwamp_01" },
    { name = "ConsumablesT03_FishCrab_01", label = "Tamale", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT03_FishCrab_01.SM_ConsumablesT03_FishCrab_01" },
    { name = "Consumables_T03_SenkamatiUmbraPepper_01", label = "Umbra Pepper", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Consumables/SM_Consumables_T03_SenkamatiUmbraPepper_01.SM_Consumables_T03_SenkamatiUmbraPepper_01" },
  },
  invdrop_mined = { -- Drops > Mined (19)
    { name = "ResourcesT03_Iron_01", label = "Ancient Metal Ore", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT03_Iron_01.SM_ResourcesT03_Iron_01" },
    { name = "Craft_T01_Ash_01", label = "Ash", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T01_Ash_01.SM_Craft_T01_Ash_01" },
    { name = "ResourcesT01_Clay_01", label = "Clay", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT01_Clay_01.SM_ResourcesT01_Clay_01" },
    { name = "CraftT02_Coal_01", label = "Coal 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT02_Coal_01.SM_CraftT02_Coal_01" },
    { name = "CraftT03_Coal_01", label = "Coal 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT03_Coal_01.SM_CraftT03_Coal_01" },
    { name = "Craft_T01_CopperIngot_01", label = "Copper Ingot", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T01_CopperIngot_01.SM_Craft_T01_CopperIngot_01" },
    { name = "Resources_T01_CopperOre_01", label = "Copper Ore", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T01_CopperOre_01.SM_Resources_T01_CopperOre_01" },
    { name = "Craft_T03_GoldIngot_01", label = "Gold Ingot", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T03_GoldIngot_01.SM_Craft_T03_GoldIngot_01" },
    { name = "Loot_T02_GoldNugget_01", label = "Gold Nugget", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_GoldNugget_01.SM_Loot_T02_GoldNugget_01" },
    { name = "Resources_T03_GreyClay_01", label = "Grey Clay", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T03_GreyClay_01.SM_Resources_T03_GreyClay_01" },
    { name = "Craft_T02_HewnStone_01", label = "Hewn Stone", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T02_HewnStone_01.SM_Craft_T02_HewnStone_01" },
    { name = "Craft_T03_EnchantedIngot_01", label = "Ingot Arborum", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T03_EnchantedIngot_01.SM_Craft_T03_EnchantedIngot_01" },
    { name = "CraftT02_IngotIron_01", label = "Iron Ingot", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT02_IngotIron_01.SM_CraftT02_IngotIron_01" },
    { name = "IronSourse_01", label = "Iron Ore", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Fossils/SM_IronSourse_01.SM_IronSourse_01" },
    { name = "CraftT03_IngotIron_01", label = "Mire Metal Ingot", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT03_IngotIron_01.SM_CraftT03_IngotIron_01" },
    { name = "ResourcesT03_Salt_01", label = "Salt", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT03_Salt_01.SM_ResourcesT03_Salt_01" },
    { name = "StoneSource_01", label = "Stone", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Fossils/SM_StoneSource_01.SM_StoneSource_01" },
    { name = "ResourcesT01_Sulfur_01", label = "Sulphur", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT01_Sulfur_01.SM_ResourcesT01_Sulfur_01" },
    { name = "Craft_T03_TumbagoIngot_01", label = "Tumbago Ingot", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T03_TumbagoIngot_01.SM_Craft_T03_TumbagoIngot_01" },
  },
  invdrop_misc = { -- Drops > Misc (12)
    { name = "Loot_T03_Bones_01", label = "Bones", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T03_Bones_01.SM_Loot_T03_Bones_01" },
    { name = "Shared_BlankItem_01", label = "Cloth Pouch", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/SM_Shared_BlankItem_01.SM_Shared_BlankItem_01" },
    { name = "Craft_T02_Compost_01", label = "Compost", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T02_Compost_01.SM_Craft_T02_Compost_01" },
    { name = "Craft_T03_UmbraEssence_01", label = "Essence Arborum", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T03_UmbraEssence_01.SM_Craft_T03_UmbraEssence_01" },
    { name = "LootT01_ShipBell_01", label = "Fast Travel Bell", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_ShipBell_01.SM_LootT01_ShipBell_01" },
    { name = "Loot_Tortuga_LootCrate_01", label = "Loot Crate", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_LootCrate_01.SM_Loot_Tortuga_LootCrate_01" },
    { name = "Resources_T01_Nails_01", label = "Nails", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T01_Nails_01.SM_Resources_T01_Nails_01" },
    { name = "Loot_Tortuga_Sail_01", label = "Rolled Sail", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_Sail_01.SM_Loot_Tortuga_Sail_01" },
    { name = "LowT03_FishSpoiled_01", label = "Spoiled Fish", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LowT03_FishSpoiled_01.SM_LowT03_FishSpoiled_01" },
    { name = "Loot_T02_ToledoSteel_01", label = "Toledo Steel", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_ToledoSteel_01.SM_Loot_T02_ToledoSteel_01" },
    { name = "Loot_T01_TornFastTravelFlag_01", label = "Torn Flag", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_TornFastTravelFlag_01.SM_Loot_T01_TornFastTravelFlag_01" },
    { name = "Craft_T03_TumbagoWire_01", label = "Tumbago Wire", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T03_TumbagoWire_01.SM_Craft_T03_TumbagoWire_01" },
  },
  invdrop_potions = { -- Drops > Potions, Bottles, and Healing (29)
    { name = "Craft_T01_AlchemicalBase_01", label = "Alchemical Base", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T01_AlchemicalBase_01.SM_Craft_T01_AlchemicalBase_01" },
    { name = "ConsumablesT01_BandageHealing_01", label = "Bandage 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT01_BandageHealing_01.SM_ConsumablesT01_BandageHealing_01" },
    { name = "ConsumablesT02_BandageHealing_01", label = "Bandage 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT02_BandageHealing_01.SM_ConsumablesT02_BandageHealing_01" },
    { name = "ConsumablesT03_BandageHealing_01", label = "Bandage 3", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT03_BandageHealing_01.SM_ConsumablesT03_BandageHealing_01" },
    { name = "Craft_T03_BottleBlank_01", label = "Blank Bottle", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T03_BottleBlank_01.SM_Craft_T03_BottleBlank_01" },
    { name = "ConsumablesT02_WeightBoost_01", label = "Carry Weight Boost", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT02_WeightBoost_01.SM_ConsumablesT02_WeightBoost_01" },
    { name = "Craft_T01_ClayBottle_01", label = "Clay Bottle", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T01_ClayBottle_01.SM_Craft_T01_ClayBottle_01" },
    { name = "ConsumablesT03_FireDmg_01", label = "Fire Damage Protection", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT03_FireDmg_01.SM_ConsumablesT03_FireDmg_01" },
    { name = "ConsumablesT02_HealingBoost_01", label = "Healing Boost", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT02_HealingBoost_01.SM_ConsumablesT02_HealingBoost_01" },
    { name = "ConsumablesT03_Healing_01", label = "Healing Potion", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT03_Healing_01.SM_ConsumablesT03_Healing_01" },
    { name = "PotionT01_Heal_01", label = "Healing Potion 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Potions/SM_PotionT01_Heal_01.SM_PotionT01_Heal_01" },
    { name = "PotionT02_Heal_01", label = "Healing Potion 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Potions/SM_PotionT02_Heal_01.SM_PotionT02_Heal_01" },
    { name = "OilT03_FireDmg_01", label = "Large Oil of Fire Damage", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Oil/SM_OilT03_FireDmg_01.SM_OilT03_FireDmg_01" },
    { name = "OilT02_FireDmg_01", label = "Medium Oil of Fire Damage", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Oil/SM_OilT02_FireDmg_01.SM_OilT02_FireDmg_01" },
    { name = "ConsumablesT02_PhysDmg_01", label = "Physical Damage Boost", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT02_PhysDmg_01.SM_ConsumablesT02_PhysDmg_01" },
    { name = "PotionT01_01", label = "Potion 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Potions/SM_PotionT01_01.SM_PotionT01_01" },
    { name = "PotionT02_01", label = "Potion 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Potions/SM_PotionT02_01.SM_PotionT02_01" },
    { name = "PotionT02_02", label = "Potion 3", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Potions/SM_PotionT02_02.SM_PotionT02_02" },
    { name = "PotionT03_01", label = "Potion 4", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Potions/SM_PotionT03_01.SM_PotionT03_01" },
    { name = "PotionT03_02", label = "Potion 5", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Potions/SM_PotionT03_02.SM_PotionT03_02" },
    { name = "ConsumablesT03_RangeDmg_01", label = "Range Damage Boost", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT03_RangeDmg_01.SM_ConsumablesT03_RangeDmg_01" },
    { name = "ConsumablesT01_Repellent_01", label = "Repellent", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT01_Repellent_01.SM_ConsumablesT01_Repellent_01" },
    { name = "CraftT03_RumBarrel_01", label = "Rum Barrel", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT03_RumBarrel_01.SM_CraftT03_RumBarrel_01" },
    { name = "CraftT03_RumBase_01", label = "Rum Base", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT03_RumBase_01.SM_CraftT03_RumBase_01" },
    { name = "CraftT03_RumBottle_01", label = "Rum Bottle", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT03_RumBottle_01.SM_CraftT03_RumBottle_01" },
    { name = "OilT01_FireDmg_01", label = "Small Oil of Fire Damage", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Oil/SM_OilT01_FireDmg_01.SM_OilT01_FireDmg_01" },
    { name = "ConsumablesT01_StaminaEfficiency_01", label = "Stemina Efficiency", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Consumables/SM_ConsumablesT01_StaminaEfficiency_01.SM_ConsumablesT01_StaminaEfficiency_01" },
    { name = "Craft_T02_Tannin_01", label = "Tannin", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T02_Tannin_01.SM_Craft_T02_Tannin_01" },
    { name = "Loot_T01_UndeadEssence_01", label = "Undead Essence", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_UndeadEssence_01.SM_Loot_T01_UndeadEssence_01" },
  },
  invdrop_seeds = { -- Drops > Seeds (1)
    { name = "Resources_T02_FlaxSeeds_01", label = "Flax Seeds", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T02_FlaxSeeds_01.SM_Resources_T02_FlaxSeeds_01" },
  },
  invdrop_tailoring = { -- Drops > Tailoring (9)
    { name = "CraftT02_ResourceFabric_01", label = "Cloth Fabric", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT02_ResourceFabric_01.SM_CraftT02_ResourceFabric_01" },
    { name = "CraftT01_ResourceFabric_01", label = "Course Fabric", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT01_ResourceFabric_01.SM_CraftT01_ResourceFabric_01" },
    { name = "LootT02_Leather_01", label = "Crocodile Hide", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT02_Leather_01.SM_LootT02_Leather_01" },
    { name = "LootT03_Fiber_01", label = "Damaged Cloth", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_Fiber_01.SM_LootT03_Fiber_01" },
    { name = "LootT03_Leather_01", label = "Large Hide", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_Leather_01.SM_LootT03_Leather_01" },
    { name = "CraftT03_ResourceFabric_01", label = "Linen Fabric", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT03_ResourceFabric_01.SM_CraftT03_ResourceFabric_01" },
    { name = "ResourcesT01_Fiber_01", label = "Plant Fiber 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT01_Fiber_01.SM_ResourcesT01_Fiber_01" },
    { name = "Resources_T01_FiberPlant_01", label = "Plant Fiber 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T01_FiberPlant_01.SM_Resources_T01_FiberPlant_01" },
    { name = "Craft_T02_TanLeather_01", label = "Tanned Leather", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T02_TanLeather_01.SM_Craft_T02_TanLeather_01" },
  },
  invdrop_tools = { -- Drops > Tools (11)
    { name = "CraftT03_Bait_01", label = "Bait", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT03_Bait_01.SM_CraftT03_Bait_01" },
    { name = "PickaxeT02_01", label = "Copper Pickaxe", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponT02/Drop/SM_Drop_PickaxeT02_01.SM_Drop_PickaxeT02_01" },
    { name = "Gear_Fishing_Rod_Regular", label = "Fishing Rod", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_FishingRod/Fishing_Regular/SM_Drop_Gear_Fishing_Rod_Regular.SM_Drop_Gear_Fishing_Rod_Regular" },
    { name = "HammerT02_01", label = "Hammer", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponT02/Drop/SM_Drop_HammerT02_01.SM_Drop_HammerT02_01" },
    { name = "Gaff_Steel_01", label = "Harpoon", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Steel/Drop/SM_Drop_Gaff_Steel_01.SM_Drop_Gaff_Steel_01" },
    { name = "AxeT03_01", label = "Iron Axe", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponT03/Drop/SM_Drop_AxeT03_01.SM_Drop_AxeT03_01" },
    { name = "Loot_Tortuga_JewelerTools_01", label = "Jeweler Tools", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_JewelerTools_01.SM_Loot_Tortuga_JewelerTools_01" },
    { name = "Craft_T02_LinenThreads_01", label = "Rigging", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T02_LinenThreads_01.SM_Craft_T02_LinenThreads_01" },
    { name = "CraftT01_Rope_01", label = "Rope", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT01_Rope_01.SM_CraftT01_Rope_01" },
    { name = "ShovelT02_01", label = "Shovel", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponT02/Drop/SM_Drop_ShovelT02_01.SM_Drop_ShovelT02_01" },
    { name = "Axe_Corrupted", label = "Swamp Axe", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Corrupted/Drop/SM_Drop_Axe_Corrupted.SM_Drop_Axe_Corrupted" },
  },
  invdrop_treasure = { -- Drops > Treasure (10)
    { name = "LootT02_Amulet_01", label = "Amulet", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT02_Amulet_01.SM_LootT02_Amulet_01" },
    { name = "LootT02_AmuletPieceBig_01", label = "Amulet Gem", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT02_AmuletPieceBig_01.SM_LootT02_AmuletPieceBig_01" },
    { name = "Loot_T01_SenkamatiStuff_01", label = "Bone Beads", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_SenkamatiStuff_01.SM_Loot_T01_SenkamatiStuff_01" },
    { name = "Loot_T02_ContrabandGoods_01", label = "Contraband", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_ContrabandGoods_01.SM_Loot_T02_ContrabandGoods_01" },
    { name = "LootT03_GemGreen_01", label = "Emerald", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_GemGreen_01.SM_LootT03_GemGreen_01" },
    { name = "LootT03_GoldAmulet_01", label = "Gold Amulet", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_GoldAmulet_01.SM_LootT03_GoldAmulet_01" },
    { name = "Loot_T01_ScallopPearl_01", label = "Pearl", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_ScallopPearl_01.SM_Loot_T01_ScallopPearl_01" },
    { name = "LootT02_GemRed_01", label = "Ruby", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT02_GemRed_01.SM_LootT02_GemRed_01" },
    { name = "LootT03_GemBlue_01", label = "Saphire", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_GemBlue_01.SM_LootT03_GemBlue_01" },
    { name = "Loot_T01_SenkamatiStuff_02", label = "Wooden Talisman", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_SenkamatiStuff_02.SM_Loot_T01_SenkamatiStuff_02" },
  },
  invdrop_trophies = { -- Drops > Trophies (6)
    { name = "Loot_T01_BoarHead_01", label = "Boar Head", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_BoarHead_01.SM_Loot_T01_BoarHead_01" },
    { name = "Loot_T01_CrabShell_01", label = "Crab Shell", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_CrabShell_01.SM_Loot_T01_CrabShell_01" },
    { name = "Loot_T02_CrocodileHead_01", label = "Crocodile Head", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_CrocodileHead_01.SM_Loot_T02_CrocodileHead_01" },
    { name = "Loot_T01_DodoHead_01", label = "Dodo Head", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_DodoHead_01.SM_Loot_T01_DodoHead_01" },
    { name = "Loot_T02_EliteGoatHead_01", label = "Head Of a Goat Leader", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_EliteGoatHead_01.SM_Loot_T02_EliteGoatHead_01" },
    { name = "Loot_T02_WolfHead_01", label = "Wolf Head", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_WolfHead_01.SM_Loot_T02_WolfHead_01" },
  },
  invdrop_weapons = { -- Drops > Weapons (37)
    { name = "ClubArtifact_01", label = "Artifact Club", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Artifact/Drop/SM_Drop_ClubArtifact_01.SM_Drop_ClubArtifact_01" },
    { name = "HalberdArtifact_01", label = "Artifact Halberd", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Artifact/Drop/SM_Drop_HalberdArtifact_01.SM_Drop_HalberdArtifact_01" },
    { name = "WeaponRange_Blunderbuss_Blank", label = "Blunderbuss", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Blunderbuss/Drop/SM_Drop_WeaponRange_Blunderbuss_Blank.SM_Drop_WeaponRange_Blunderbuss_Blank" },
    { name = "WeaponRange_Musket_Baneful", label = "Buccaneer's Friend", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Musket/Drop/SM_Drop_WeaponRange_Musket_Baneful.SM_Drop_WeaponRange_Musket_Baneful" },
    { name = "CraftT02_AmmoIronBuckshot_01", label = "Buckshot", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT02_AmmoIronBuckshot_01.SM_CraftT02_AmmoIronBuckshot_01" },
    { name = "CraftT02_AmmoIron_01", label = "Bullet Arborum", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT02_AmmoIron_01.SM_CraftT02_AmmoIron_01" },
    { name = "Loot_Tortuga_Cannon_01", label = "Cannon", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_Cannon_01.SM_Loot_Tortuga_Cannon_01" },
    { name = "WeaponRange_Blunderbuss_Fateful", label = "Dragon's Breath", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Blunderbuss/Drop/SM_Drop__WeaponRange_Blunderbuss_Fateful.SM_Drop__WeaponRange_Blunderbuss_Fateful" },
    { name = "WeaponMelee_GreatSword_Voved", label = "Dueling Greatsword", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponMelee_GreatSword/Drop/SM_Drop_WeaponMelee_GreatSword_Voved.SM_Drop_WeaponMelee_GreatSword_Voved" },
    { name = "Loot_T03_EnchantedRitualKnife_01_SM_Loot_T03_EnchantedRitualKnife_01", label = "Enchanted Ritual Knife", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T03_EnchantedRitualKnife_01_SM_Loot_T03_EnchantedRitualKnife_01.SM_Loot_T03_EnchantedRitualKnife_01_SM_Loot_T03_EnchantedRitualKnife_01" },
    { name = "GreatAxeT02_01", label = "Great Axe", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponT02/Drop/SM_Drop_GreatAxeT02_01.SM_Drop_GreatAxeT02_01" },
    { name = "LootT03_AmmoPowder_01", label = "Gunpowder 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_AmmoPowder_01.SM_LootT03_AmmoPowder_01" },
    { name = "CraftT02_AmmoPowder_01", label = "Gunpowder 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT02_AmmoPowder_01.SM_CraftT02_AmmoPowder_01" },
    { name = "CraftT03_AmmoPowder_01", label = "Homemade Gunpowder", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT03_AmmoPowder_01.SM_CraftT03_AmmoPowder_01" },
    { name = "WeaponRange_Musket_Relentless", label = "Infantry Musket", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Musket/Drop/SM_Drop_WeaponRange_Musket_Relentless.SM_Drop_WeaponRange_Musket_Relentless" },
    { name = "CraftT03_AmmoIron_01", label = "Iron Bullet", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT03_AmmoIron_01.SM_CraftT03_AmmoIron_01" },
    { name = "KnifeT02_01", label = "Knife", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponT02/Drop/SM_Drop_KnifeT02_01.SM_Drop_KnifeT02_01" },
    { name = "WeaponRange_Musket_Blank", label = "Musket", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Musket/Drop/SM_Drop_WeaponRange_Musket_Blank.SM_Drop_WeaponRange_Musket_Blank" },
    { name = "MusketT01_01", label = "Musket 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/FirearmsT01/Drop/SM_Drop_MusketT01_01.SM_Drop_MusketT01_01" },
    { name = "MusketT01_02", label = "Musket 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/FirearmsT01/Drop/SM_Drop_MusketT01_02.SM_Drop_MusketT01_02" },
    { name = "MusketT01_03", label = "Musket 3", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/FirearmsT01/Drop/SM_Drop_MusketT01_03.SM_Drop_MusketT01_03" },
    { name = "MusketT02_01", label = "Musket 4", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/FirearmsT02/Drop/SM_Drop_MusketT02_01.SM_Drop_MusketT02_01" },
    { name = "WeaponRange_Pistol_Blank", label = "Pistol", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Pistol/Drop/SM_Drop_WeaponRange_Pistol_Blank.SM_Drop_WeaponRange_Pistol_Blank" },
    { name = "PistolT01_02", label = "Pistol 1", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/FirearmsT01/Drop/SM_Drop_PistolT01_02.SM_Drop_PistolT01_02" },
    { name = "PistolT01_03", label = "Pistol 2", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/FirearmsT01/Drop/SM_Drop_PistolT01_03.SM_Drop_PistolT01_03" },
    { name = "PistolT02_01", label = "Pistol 3", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/FirearmsT02/Drop/SM_Drop_PistolT02_01.SM_Drop_PistolT02_01" },
    { name = "PistolT02_04", label = "Pistol 4", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/FirearmsT02/Drop/SM_Drop_PistolT02_04.SM_Drop_PistolT02_04" },
    { name = "WeaponRange_Blunderbuss_Reliable", label = "Reliable Blunderbuss", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Blunderbuss/Drop/SM_Drop__WeaponRange_Blunderbuss_Reliable.SM_Drop__WeaponRange_Blunderbuss_Reliable" },
    { name = "WeaponRange_Musket_Reliable", label = "Reliable Musket", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Musket/Drop/SM_Drop_WeaponRange_Musket_Reliable.SM_Drop_WeaponRange_Musket_Reliable" },
    { name = "WeaponRange_Pistol_Baneful", label = "Reliable Pistol", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Pistol/Drop/SM_Drop_WeaponRange_Pistol_Baneful.SM_Drop_WeaponRange_Pistol_Baneful" },
    { name = "WeaponRange_Pistol_Faithful", label = "Reliable Pistol", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Pistol/Drop/SM_Drop_WeaponRange_Pistol_Faithful.SM_Drop_WeaponRange_Pistol_Faithful" },
    { name = "SaberFish_01", label = "Smasher", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Strange/Drop/SM_Drop_SaberFish_01.SM_Drop_SaberFish_01" },
    { name = "Spear_Steel_01", label = "Steel Spear", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Steel/Drop/SM_Drop_Spear_Steel_01.SM_Drop_Spear_Steel_01" },
    { name = "CraftT01_AmmoStone_01", label = "Stone Bullets", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Craft/SM_CraftT01_AmmoStone_01.SM_CraftT01_AmmoStone_01" },
    { name = "Spear_Corrupted", label = "Swamp Spear", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Corrupted/Drop/SM_Drop_Spear_Corrupted.SM_Drop_Spear_Corrupted" },
    { name = "WeaponRange_Musket_Wicked", label = "Wicked Musket", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Musket/Drop/SM_Drop_WeaponRange_Musket_Wicked.SM_Drop_WeaponRange_Musket_Wicked" },
    { name = "WeaponRange_Pistol_Severe", label = "Worn Out Pistol", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Character/Skeletal_Meshes/Weapons/WeaponRange_Pistol/Drop/SM_Drop_WeaponRange_Pistol_Severe.SM_Drop_WeaponRange_Pistol_Severe" },
  },
  invdrop_wood = { -- Drops > Wood (7)
    { name = "Resources_T02_Hardwood_01", label = "Hardwood", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T02_Hardwood_01.SM_Resources_T02_Hardwood_01" },
    { name = "Resources_T03_Resin_01", label = "Tar", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resources_T03_Resin_01.SM_Resources_T03_Resin_01" },
    { name = "Craft_T03_TarredPlanks_01", label = "Tarred Planks", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T03_TarredPlanks_01.SM_Craft_T03_TarredPlanks_01" },
    { name = "Resource_T02_Bark_01", label = "Tree Bark", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Resources/SM_Resource_T02_Bark_01.SM_Resource_T02_Bark_01" },
    { name = "ResourcesT03_Wood_01", label = "Wood", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Resources/SM_ResourcesT03_Wood_01.SM_ResourcesT03_Wood_01" },
    { name = "Craft_T01_PlanksWood_01", label = "Wood Plank", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T01_PlanksWood_01.SM_Craft_T01_PlanksWood_01" },
    { name = "Craft_T02_WoodenBeam_01", label = "Wooden beam", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Craft/SM_Craft_T02_WoodenBeam_01.SM_Craft_T02_WoodenBeam_01" },
  },
  invdrop_writings = { -- Drops > Writings (14)
    { name = "LootT03_BritishJournal_01", label = "British Journal", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_BritishJournal_01.SM_LootT03_BritishJournal_01" },
    { name = "LootT03_BritishNote_01", label = "British Note", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT03_BritishNote_01.SM_LootT03_BritishNote_01" },
    { name = "Loot_Tortuga_ChocolateCakeRecipe_01", label = "Chocolate Cake Recipe", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_ChocolateCakeRecipe_01.SM_Loot_Tortuga_ChocolateCakeRecipe_01" },
    { name = "Loot_Tortuga_ChocolatlRecipe_01", label = "Chocolate Recipe", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_ChocolatlRecipe_01.SM_Loot_Tortuga_ChocolatlRecipe_01" },
    { name = "Loot_T01_SenkamatiClayTablet_01", label = "Clay Tablet", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T01_SenkamatiClayTablet_01.SM_Loot_T01_SenkamatiClayTablet_01" },
    { name = "Loot_T02_SenkamatiClayTablet_01", label = "Clay Tablet", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_T02_SenkamatiClayTablet_01.SM_Loot_T02_SenkamatiClayTablet_01" },
    { name = "LootT02_CultustJournal_01", label = "Cultist Journal", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT02_CultustJournal_01.SM_LootT02_CultustJournal_01" },
    { name = "LootT02_CultistNote_01", label = "Cultist Note", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT02_CultistNote_01.SM_LootT02_CultistNote_01" },
    { name = "LootT01_NoteLore_01", label = "Lore Note", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_NoteLore_01.SM_LootT01_NoteLore_01" },
    { name = "LootT01_NoteStack_01", label = "Note Stack", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_NoteStack_01.SM_LootT01_NoteStack_01" },
    { name = "LootT01_PirateJournal_01", label = "Pirate Journal", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_PirateJournal_01.SM_LootT01_PirateJournal_01" },
    { name = "LootT01_PirateMap_01", label = "Pirate Map", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_PirateMap_01.SM_LootT01_PirateMap_01" },
    { name = "Loot_Tortuga_QualityGunpowderRecipe_01", label = "Quality Gunpowder Recipe", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/TMP/ResourcesTEMP/Loot/SM_Loot_Tortuga_QualityGunpowderRecipe_01.SM_Loot_Tortuga_QualityGunpowderRecipe_01" },
    { name = "LootT01_NoteRecipe_01", label = "Recipe Note", zoffset = 20.0, path = "/Script/R5.R5LootActor", mesh = "/Game/Environment/Gameplay/Resources/Loot/SM_LootT01_NoteRecipe_01.SM_LootT01_NoteRecipe_01" },
  },
}

return FKeys
