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
-- raidflag/bbraid are listed here even though Config.BBRAID_ENABLED is force-disabled by default
-- (see config.lua) -- harmless while unregistered, and keeps this file the single place to look if
-- that feature is ever revived. (These two still sit on the F-row -- reviving Blackbeard means
-- accepting the same F-row collision risk this file's decor keys were moved off of.)
FKeys.KEYS = {
  decorSpawn    = "OEM_SEMICOLON", -- ';'  place one from the ACTIVE category
  decorCategory = "OEM_QUOTE",     -- '''  advance the active category (no spawn)
  raidflag      = "F7",  -- drop the BLACKBEARD RAID flag (Composition_70) where a raid should originate
  bbraid        = "F8",  -- BLACKBEARD RAID: spawn a pirate wave at each placed flag and charge the bonfire
}

-- Cycle order for the active decor category (Testbed.CycleDecorCategory steps forward through
-- this list, wrapping around). Any subset/reordering of Config.DECOR_CATEGORIES' keys is valid.
FKeys.DECOR_ORDER = { "nature", "boats", "wrecks", "tents", "storage", "furniture" }

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
    -- Composition_70 (the Blackbeard raid flag) is NOT in this list — it has its own dedicated key
    -- (Config.BBRAID_FLAG_CLASS, raidflag). Placing it there keeps the "flag = raid origin" prop
    -- out of the general furniture cycle.
    { name = "Tortuga_Wardrobe_02", zoffset = 0.0, path = "/Game/Gameplay/POI/Tortuga/Tortuga_NPC_InteractionProps/BP_Tortuga_Wardrobe_02.BP_Tortuga_Wardrobe_02_C" },
    { name = "WardrobeAshlands_04", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/Furniture/BP_Shared_DestructibleStructures_WardrobeAshlands_04.BP_Shared_DestructibleStructures_WardrobeAshlands_04_C" },
    { name = "WardrobeAshlands_06", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/Furniture/BP_Shared_DestructibleStructures_WardrobeAshlands_06.BP_Shared_DestructibleStructures_WardrobeAshlands_06_C" },
    { name = "WardrobeAshlands_09", zoffset = 0.0, path = "/Game/Gameplay/Foliage/FoliageActors/Shared/DestructibleStructures/Furniture/BP_Shared_DestructibleStructures_WardrobeAshlands_09.BP_Shared_DestructibleStructures_WardrobeAshlands_09_C" },
    { name = "WindChime_02", zoffset = 0.0, path = "/Game/Gameplay/POI/CoastJungle/CoastJungle_Props/BP_WindChime_02.BP_WindChime_02_C" },
  },
}

return FKeys
