# LivingBase — Spawnable Asset Catalog

A living database of world assets discovered via the `HOME`/`INS` in-world probes (→ `discovery_dump.txt`,
written per-line so a crash can't eat a capture; the probe matches any `/Game/` actor). The old asset-registry
auto-dump was deleted (v2.71) — it never extracted paths. **The INS probe is the one cataloging tool.**

**Status:** ✅ have path, ready to wire · 🟡 candidate (probe/spawn-test) · ⬜ category empty.

---

# DECORATIONS — proposed F-row layout (NOT built yet)
RedFalcon's grouping. Each category would get one F-key (F-row is free since placement moved to the numpad).
Currently everything is on the `END` cycler; this is the plan for splitting it. Statue POSES are separate
(they stay on the numpad F3/F4/F5 lists) — see the bottom section.

| Key (proposed) | Category | Count | Fill |
|---|---|---|---|
| F1 | **Nature** | many ✅ | nests, mushrooms, rocks, **trees (palms/ficus)**, **farm crops** |
| F2 | **Boats** (intact) | 5 ✅ | PortBoat_01/02 · **DecorShip Cutter/Frigate/Ketch** |
| F3 | **Debris / Wrecks** | 3 ✅ | ship mast/spanthout/boat wrecks · need: box/chest/barrel wrecks |
| F4 | **Tents / Hammocks** | 5 ✅ | CampTents 11/12/19, RespawnTent, bedrolls · need: hammock |
| F5 | **Crates / Chests / Barrels** | 9 ✅ | **BP_Storage_* — now filled** (barrel/box/chest/bale/bag) |
| F6 | **Other props** | many ✅ | lamps, torches, flagpoles, urns+flowers, fountains, chandeliers… (will split) |
| F7 | **Group compositions** | 5 ✅ | CampPropsComposition (can't parse into individuals) |

---

## F1 · Nature
| Status | Asset | Path root / note |
|---|---|---|
| ✅ | `BP_CoastJungleMineralNestDodo_01` / `_02` | `/Environment/Props/RuinsTypeA/Debris/BP_Mineral/` |
| ✅ | `BP_CoastJungleMineralMushroom_01` / `_02` | same folder |
| ✅ | `BP_CoastJungleMineralMushroomDebris_03` | same folder |
| ✅ | `BP_CoastJungleMineralRootDebris_01` | same folder — root/log debris |
| ✅ | `BP_Mineral_MiddleRock_05` | `/Foliage/MinaralNodes/MiddleRock/` — standalone rock |
| ✅ | **Trees** — `BP_Segment_Coast_Jungle_Ficus_1800cm` | `/Foliage/SegmentTrees/BPSegmentTrees/` |
| ✅ | **Palms** — `BP_Segment_Coast_Jungle_PalmCoconutFruit_700/1000/1400cm` | same — height in the name |
| ✅ | `BP_Segment_Coast_Jungle_PalmSabal_250cm` | same — short sabal palm |
| ✅ | `BP_Segment_Sand_Beach_PalmCoconutEmpty_700/900/1400cm` | same — beach palms (no fruit) |
| 🟡 | boar den ("big stump" near mushrooms) | likely a `BP_Mineral` sibling — probe |
| 🟡 | closed scallop, triton horn | `AR5PickupResource` (walk-over?) — probe |
| ❌ | `SticksRocksDebris_01` | dropped per RedFalcon |

### F1b · Farm crops (sub-group — decide if own key)  `/Gameplay/Building/Actors/Farming/`
Spawnable grown-plant actors. Each crop has a live `BP_Farming_<Crop>` and `..Dummy_Stage_NN` variants (growth stages).
| ✅ paths captured | Aloe · Banana · Batata/SweetPotato · BlackBean · Corn · Ficus · Flax · Icaco · LimeTree · Mancinella · PalmSabal · Pepper · Tomato |
|---|---|

## F2 · Boats (intact)
| Status | Asset | Note |
|---|---|---|
| ✅ | `BP_PortBoat_01` / `_02` | `/Environment/Props/PortProps/` — intact boats on shore |
| ✅ | `BP_BuildingBlock_DecorShip_Cutter_01` | `/Gameplay/Building/Actors/` — **full decorative ships** |
| ✅ | `BP_BuildingBlock_DecorShip_Frigate_01` | same — frigate |
| ✅ | `BP_BuildingBlock_DecorShip_Ketch_01` | same — ketch |
| 🟡 | canoes / dinghies | RedFalcon saw "lots of boat types" — keep probing |

## F3 · Debris / Wrecks  `/Foliage/FoliageActors/Shared/WrecksNode/`
| Status | Asset | Path root |
|---|---|---|
| ✅ | `BP_Shipwreck_Mast_03_01` | `…/MastWreck/` |
| ✅ | `BP_Shipwreck_Spanthout_01_02` | `…/SpanthoutWreck/` |
| ✅ | `BP_Shipwreck_Boat_01_01` | `…/BoatWreck/` |
| 🟡 | `BP_Shipwreck_Box_01/03`, `Chest_01`, `Barrel*` | headers exist — probe for paths |

## F4 · Tents / Hammocks
| Status | Asset | Note |
|---|---|---|
| ✅ | `BP_Shared_CampTents_11` / `_12` / `_19` | **real camp tents** (`/Foliage/…/DestructibleStructures/CampTents/`) — numbered 1..N, probe more |
| ✅ | `BP_BuildingBlock_RespawnTent` | tent (Furniture). May carry respawn function — test |
| ✅ | `BP_BuildingBlock_BedrollT02_01` / `T04_01` / `T04_02` | bedrolls (lie flat) — `/…/Actors/Furniture/` |
| 🟡 | `ABP_Hammock`, `BP_ShipObject_Hammock` | headers exist — probe for paths |

## F5 · Crates / Chests / Barrels  ✅  `/Gameplay/Inventory/`
| Status | Asset | Note |
|---|---|---|
| ✅ | `BP_Storage_MediumBarrel` | barrel |
| ✅ | `BP_Storage_MediumBox` | crate/box |
| ✅ | `BP_Storage_MediumBale` | bale (cloth/hay) |
| ✅ | `BP_Storage_MediumChest` / `SmallChest` | chests |
| ✅ | `BP_Storage_WoodenChest_01` / `_04` / `_08` | wooden chests (variants) |
| ✅ | `BP_Storage_DecorBag_01` | sack/bag |
| ⚠️ | these are FUNCTIONAL storage (openable inventory) | fine as decor; note they may be interactable |
| 🟡 | loot crates w/ guns/gunpowder | still not seen as standalone actors — keep probing |

## F6 · Other props  ✅ (large — will split into sub-keys later)  mostly `/Gameplay/Building/Actors/`
| Status | Group | Assets |
|---|---|---|
| ✅ | **Lamps** | `BP_BuildingBlock_Lamp_01`–`_06`, `BP_LampT04_01`–`_04`, `BP_WallLampT04_01`–`_03`, `BP_BuildingBlock_LampHookT02_01` |
| ✅ | **Torches / fire** | `BP_TorchT02_01`/`_02`, `BP_BuildingBlock_FloorTorch`, `BP_BuildingBlock_WallTorch`/`_02`, `BP_SignalFireT01`, `BP_BuildingBlock_FireplaceT04_01` |
| ✅ | **Flagpoles** | `BP_BuildingBlock_FlagpoleT01_01`, `T03_02`, `T04_02`, `BP_BuildingBlock_DecorFlagpole_01` |
| ✅ | **Urns + flowers** | `BP_BuildingBlock_DecorUrnFlower_01`–`_10` |
| ✅ | **Fountains** | `BP_GardenFountain_01` / `_02` / `_03` |
| ✅ | **Chandeliers** | `BP_ChandelierT04_01` / `_03` / `_04` |
| ✅ | **Misc** | `BP_BuildingBlock_PendulumClockT04_01` (clock), `BP_WallMount_Senkamati_01`, `BP_Tortuga_Wardrobe_02` |
| 🟡 | **Furniture** (own key?) | armchairs `BP_ArmchairT01/T04`, benches `BP_BenchT01/T02/T04`, chairs `BP_ChairT02/T04`, stools `BP_StoolT01/T04`, wardrobes `BP_WardrobeT04_*` — `/Actors/Furniture/` |
| — | **building shells** (doors/windows) | `BP_BuildingBlock_Door*`, `Windowframe*`, `DoorWay*` captured — spawnable but structural, probably skip |

## F7 · Group compositions
| Status | Asset | Note |
|---|---|---|
| 🟡 | `BP_Shared_Camp_PropsComposition_05 / _15 / _72 / _75 / _76` | 5 captured. Whole prop clusters as ONE actor; can't parse into pieces. Spawnable in theory — needs a spawn test. Numbered 1..N |

## ⚙️ NOT decor — functional stations, noted for reference
- **Craft stations** `/Gameplay/Craft/CraftStation/`: AlchemyTable, BlackSmith, CookingStation, DisassemblyBench, EnchantingTable, Equipment, Jewellery, ShipEquipment, WorkBench, Furnace_T3, Kiln_T02, Millstones_T02, SpinningWheel_T02, Tannery_T02, ShipDock_02, `BP_FastTravelBell_02`/`_03` (functional bell).
- **Traders / trade posts**: `BP_BuildingBlock_Employee_Trader_{Animals,Food,Resources}`, `BP_Trade_{Brethren,Bucaneers,Civilians,Smugglers}1_PlayerBuys/PlayerSells*` — the dropped trade feature.
- **Bonfire**: `BP_BuildingBlock_BuildingCenterT01` (the base's building center).

---

# STATUE POSES — on the numpad lists (separate from decorations)
| Status | Pose → list | Assets |
|---|---|---|
| ✅ | STANDING (Num 3) | merchants, chat, cross-hands, woman, **LeanOnWall x3, FireWarm x3, CarpenterIdle x3** |
| ✅ | FLOOR SITTERS (Num 4) | SitterOnGround x n, LayOnGround x2 |
| ✅ | CHAIR SITTERS (Num 5) | SitterOnStool x n, Female_Sitting x3 |
| ✅ | INTERACTIVE / rummaging (Num 6) | LookerChest x4, **LookerTable x1** |
| ✅ | QUEST FOLK (in STANDING) | Francois, Letty |
| 🟡 | new poses seen this session | **DrunkCanoneer** (`BP_AnimatedActorVoiced_TortugaCitizen_Dogface_DrunkCanoneer`) — voiced; SitterOnGround_03, SitterOnStool_02 variants |

**Named NPCs: EXCLUDED per RedFalcon** (only Francois + Letty). Do not add Marita, GalenSkelton, Ksant,
MortarMan, RosalindaMercer. (`BP_NPC_Employee_CookingStation_BlackAxel` seen but excluded — named.)

---

## Workflow
1. `HOME`/`INS` on a wild asset → `CLASS:` lands in `discovery_dump.txt` (durable, any `/Game/` actor).
2. Say "check the dump" → I sort new `CLASS:` lines into the category tables above as 🟡/✅.
3. When the categories are fleshed out and the layout is locked, I build the F-row cyclers.
