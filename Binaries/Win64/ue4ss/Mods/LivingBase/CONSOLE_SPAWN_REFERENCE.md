LivingBase — Console Spawn Reference
======================================================================

Total entries: 220

Exact console command to spawn each item lbspawn/lblook can reach. Companion
to DISPLAY_NAMES.md (same categories/order) -- that file is for choosing
friendly display names; this one is a cheat sheet for testing in-game.

lbspawn <ShortClassName>  -- ANY raw engine class by short name or full
                             /Game/... path, with NO mod recipe applied (no
                             friendly faction, no AI override, no reskin --
                             e.g. a raw-spawned Boar stays aggressive). Use it
                             for something outside LivingBase's own roster.
                             Bare "lbspawn" or "?" prints usage; "lbspawn
                             list [category]" browses this same roster.
lblook <name>             -- LivingBase's own named composite/pacify/placement
                             RECIPE -- covers every entry below (crew,
                             townsfolk, statues, Senkamati, livestock, walking
                             women, decor) as of 2026-08-13's full-coverage
                             pass, running the exact same spawn path the real
                             placement key uses for that entry -- not a
                             separate path that could drift from what the key
                             does. Multi-word names don't need quotes, e.g.
                             lblook Buccaneers Musketeer. Bare "lblook" or
                             "?" prints usage; "lblook list [category]"
                             browses this same roster.

----------------------------------------------------------------------
TOWNSFOLK  (8 entries, key: Num2)
----------------------------------------------------------------------

[Walker]
  lblook Walker

[Worker]
  lblook Worker

[Farmer]
  lblook Farmer

[Gatherer]
  lblook Gatherer

[Herbalist]
  lblook Herbalist

[Hunter]
  lblook Hunter

[Miner]
  lblook Miner

[Woodman]
  lblook Woodman

----------------------------------------------------------------------
STANDING STATUES  (38 entries, key: Num3)
----------------------------------------------------------------------

[Brethren of the Coast] BotC_Female_Standing_01
  lblook BP_AnimatedActor_BotC_Female_Standing_01

[Brethren of the Coast] BotC_Merchant_01
  lblook BP_AnimatedActor_BotC_Merchant_01

[Brethren of the Coast] BotC_Merchant_02
  lblook BP_AnimatedActor_BotC_Merchant_02

[Brethren of the Coast] BotC_Merchant_03
  lblook BP_AnimatedActor_BotC_Merchant_03

[Brethren of the Coast] BotC_Sailorhat_01
  lblook BP_AnimatedActor_BotC_Sailor_Chat_01

[Buccaneers] Buccaneers_Merchant_01
  lblook BP_AnimatedActor_Buccaneers_Merchant_01

[Buccaneers] Buccaneers_Merchant_03
  lblook BP_AnimatedActor_Buccaneers_Merchant_03

[Buccaneers] Buccaneers_Merchant_04
  lblook BP_AnimatedActor_Buccaneers_Merchant_04

[Smugglers] Smugglers_Merchant_01
  lblook BP_AnimatedActor_Smugglers_Merchant_01

[People of Tortuga] TortugaCitizen_Merchant_01
  lblook BP_AnimatedActor_TortugaCitizen_Merchant_01

[People of Tortuga] TortugaCitizenombatantrossHands
  lblook BP_AnimatedActor_TortugaCitizen_Combatant_CrossHands

[Brethren of the Coast] LeanOnWall
  lblook BP_AnimatedActor_BotC_Sergeant_LeanOnWall

[People of Tortuga] LeanOnWall
  lblook BP_AnimatedActor_TortugaCitizen_Combatant_LeanOnWall

[Smugglers] LeanOnWall (cross-hands)
  lblook BP_AnimatedActor_Smugglers_Theif_LeanOnWallCrossHands

[Buccaneers] LeanOnWall
  lblook BP_AnimatedActor_Buccaneers_Trapper_LeanOnWall

[Brethren of the Coast] LeanOnWall
  lblook BP_AnimatedActor_BotC_Sailor_LeanOnWall

[Smugglers] LeanOnWall
  lblook BP_AnimatedActor_Smugglers_Runner_LeanOnWall

[Brethren of the Coast] CarpenterIdle
  lblook BP_AnimatedActor_BotC_Musketeer_CarpenterIdle

[Brethren of the Coast] CarpenterIdle
  lblook BP_AnimatedActor_BotC_Sailor_CarpenterIdle

[People of Tortuga] CarpenterIdle
  lblook BP_AnimatedActor_TortugaCitizen_Combatant_CarpenterIdle

[Buccaneers] CarpenterIdle
  lblook BP_AnimatedActor_Buccaneers_Trapper_CarpenterIdle

[People of Tortuga] CarpenterIdle
  lblook BP_AnimatedActor_TortugaCitizen_Dogface_CarpenterIdle

[People of Tortuga] CarpenterIdle
  lblook BP_AnimatedActor_TortugaCitizen_Shooter_CarpenterIdle

[Brethren of the Coast] Francois Arno
  lblook BP_NPC_QuestStatic_BotC_FrancoisArno

[People of Tortuga] Letty
  lblook BP_NPC_QuestStatic_Letty

[Brethren of the Coast] Benjamin Hornigold
  lblook BP_NPC_QuestStatic_BotC_BenjaminHornigold

[Buccaneers] Henri Boucher
  lblook BP_NPC_QuestStatic_Buccaneers_HenriBoucher

[Smugglers] Marita Suares
  lblook BP_NPC_QuestStatic_Smugglers_MaritaSuares

[People of Tortuga] Long Ben
  lblook BP_NPC_QuestStatic_TortugaCitizen_LongBen

[People of Tortuga] Charlie Sharp
  lblook BP_NPC_QuestStatic_TortugaCitizen_CharlieSharp

[Brethren of the Coast] BotC_Merchant_04
  lblook BP_AnimatedActor_BotC_Merchant_04

[Buccaneers] Buccaneers_Jager_LeanOnWall
  lblook BP_AnimatedActor_Buccaneers_Jager_LeanOnWall

[Buccaneers] Buccaneers_Merchant_02
  lblook BP_AnimatedActor_Buccaneers_Merchant_02

[Smugglers] Smugglers_Merchant_02
  lblook BP_AnimatedActor_Smugglers_Merchant_02

[Smugglers] Smugglers_Merchant_03
  lblook BP_AnimatedActor_Smugglers_Merchant_03

[People of Tortuga] TortugaCitizen_Merchant_02
  lblook BP_AnimatedActor_TortugaCitizen_Merchant_02

[People of Tortuga] TortugaCitizen_Merchant_03
  lblook BP_AnimatedActor_TortugaCitizen_Merchant_03

[People of Tortuga] TortugaCitizen_Merchant_04
  lblook BP_AnimatedActor_TortugaCitizen_Merchant_04

----------------------------------------------------------------------
SEATED STATUES (ground)  (18 entries, key: Num4)
----------------------------------------------------------------------

[People of Tortuga] TiredSoldier
  lblook BP_AnimatedActorVoiced_TortugaCitizen_Combatant_TiredSoldier

[Brethren of the Coast] BotC_Sailor_SitterOnGround_01
  lblook BP_AnimatedActor_BotC_Sailor_SitterOnGround_01

[Brethren of the Coast] BotC_Sailor_SitterOnGround_02
  lblook BP_AnimatedActor_BotC_Sailor_SitterOnGround_02

[Brethren of the Coast] BotC_Sailor_SitterOnGround_03
  lblook BP_AnimatedActor_BotC_Sailor_SitterOnGround_03

[Brethren of the Coast] BotC_Sailor_SitterOnGround_04
  lblook BP_AnimatedActor_BotC_Sailor_SitterOnGround_04

[Buccaneers] Buccaneers_Jager_SitterOnGround
  lblook BP_AnimatedActor_Buccaneers_Jager_SitterOnGround

[Buccaneers] Buccaneers_Trapper_SitterOnGround_03
  lblook BP_AnimatedActor_Buccaneers_Trapper_SitterOnGround_03

[Smugglers] Smugglers_Theif_SitterOnGround_01
  lblook BP_AnimatedActor_Smugglers_Theif_SitterOnGround_01

[Smugglers] Smugglers_Theif_SitterOnGround_02
  lblook BP_AnimatedActor_Smugglers_Theif_SitterOnGround_02

[Smugglers] Smugglers_Theif_SitterOnGround_03
  lblook BP_AnimatedActor_Smugglers_Theif_SitterOnGround_03

[People of Tortuga] TortugaCitizenombatant_SitterOnGround
  lblook BP_AnimatedActor_TortugaCitizen_Combatant_SitterOnGround

[People of Tortuga] TortugaCitizen_Dogface_LayOnGround
  lblook BP_AnimatedActor_TortugaCitizen_Dogface_LayOnGround

[People of Tortuga] TortugaCitizen_Dogface_SitterOnGround_01
  lblook BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnGround_01

[People of Tortuga] TortugaCitizen_Dogface_SitterOnGround_02
  lblook BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnGround_02

[People of Tortuga] Combatant_LayOnGround (probed 2026-07-10)
  lblook BP_AnimatedActor_TortugaCitizen_Combatant_LayOnGround

[Smugglers] Theif_LayOnGround
  lblook BP_AnimatedActor_Smugglers_Theif_LayOnGround

[People of Tortuga] TortugaCitizen_Dogface_SitterOnGround_03
  lblook BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnGround_03

[Smugglers] Smugglers_Merchant_04
  lblook BP_AnimatedActor_Smugglers_Merchant_04

----------------------------------------------------------------------
CHAIR / STOOL STATUES  (20 entries, key: Num5)
----------------------------------------------------------------------

[Brethren of the Coast] BotC_Sailor_SitterOnStool
  lblook BP_AnimatedActor_BotC_Sailor_SitterOnStool

[Brethren of the Coast] BotC_Musketeer_SitterOnStool_01
  lblook BP_AnimatedActor_BotC_Musketeer_SitterOnStool_01

[Brethren of the Coast] BotC_Musketeer_SitterOnStool_02
  lblook BP_AnimatedActor_BotC_Musketeer_SitterOnStool_02

[Brethren of the Coast] BotC_Female_Sitting_01
  lblook BP_AnimatedActor_BotC_Female_Sitting_01

[Brethren of the Coast] BotC_Female_Sitting_02
  lblook BP_AnimatedActor_BotC_Female_Sitting_02

[Brethren of the Coast] BotC_Female_Sitting_03
  lblook BP_AnimatedActor_BotC_Female_Sitting_03

[Buccaneers] Buccaneers_Jager_SitterOnStool_02
  lblook BP_AnimatedActor_Buccaneers_Jager_SitterOnStool_02

[Buccaneers] Buccaneers_Marksman_SitterOnStool
  lblook BP_AnimatedActor_Buccaneers_Marksman_SitterOnStool

[Buccaneers] Buccaneers_Marksman_SitterOnStool_02
  lblook BP_AnimatedActor_Buccaneers_Marksman_SitterOnStool_02

[Buccaneers] Buccaneers_Trapper_SitterOnStool
  lblook BP_AnimatedActor_Buccaneers_Trapper_SitterOnStool

[Buccaneers] Buccaneers_Trapper_SitterOnStool_03
  lblook BP_AnimatedActor_Buccaneers_Trapper_SitterOnStool_03

[Smugglers] Smugglers_Hitman_SitterOnStool_02
  lblook BP_AnimatedActor_Smugglers_Hitman_SitterOnStool_02

[Smugglers] Smugglers_Runner_SitterOnStool
  lblook BP_AnimatedActor_Smugglers_Runner_SitterOnStool

[Smugglers] Smugglers_Theif_SitterOnStool
  lblook BP_AnimatedActor_Smugglers_Theif_SitterOnStool

[People of Tortuga] TortugaCitizen_Combatant_SitterOnStool
  lblook BP_AnimatedActor_TortugaCitizen_Combatant_SitterOnStool

[People of Tortuga] TortugaCitizen_Combatant_SitterOnStool_02
  lblook BP_AnimatedActor_TortugaCitizen_Combatant_SitterOnStool_02

[People of Tortuga] TortugaCitizen_Dogface_SitterOnStool
  lblook BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnStool

[People of Tortuga] TortugaCitizen_Shooter_SitterOnStool_01
  lblook BP_AnimatedActor_TortugaCitizen_Shooter_SitterOnStool_01

[People of Tortuga] TortugaCitizen_Shooter_SitterOnStool_02
  lblook BP_AnimatedActor_TortugaCitizen_Shooter_SitterOnStool_02

[People of Tortuga] DrunkCanoneer
  lblook BP_AnimatedActorVoiced_TortugaCitizen_Dogface_DrunkCanoneer

----------------------------------------------------------------------
INTERACTIVE STATUES  (15 entries, key: Num6)
----------------------------------------------------------------------

[People of Tortuga] Shooter (Tortuga)
  lblook BP_AnimatedActor_TortugaCitizen_Shooter_LookerChest

[People of Tortuga] Dogface (Tortuga)
  lblook BP_AnimatedActor_TortugaCitizen_Dogface_LookerChest

[Buccaneers] Trapper (Buccaneer)
  lblook BP_AnimatedActor_Buccaneers_Trapper_LookerChest

[Smugglers] Theif (Smuggler)
  lblook BP_AnimatedActor_Smugglers_Theif_LookerChest

[Buccaneers] Trapper LookerTable
  lblook BP_AnimatedActor_Buccaneers_Trapper_LookerTable

[Brethren of the Coast] Musketeer LookerChest
  lblook BP_AnimatedActor_BotC_Musketeer_LookerChest

[Brethren of the Coast] FireWarm
  lblook BP_AnimatedActor_BotC_Sailor_FireWarm

[Brethren of the Coast] FireWarm
  lblook BP_AnimatedActor_BotC_Sergeant_FireWarm

[Buccaneers] FireWarm
  lblook BP_AnimatedActor_Buccaneers_Marksman_FireWarm

[Smugglers] FireWarm
  lblook BP_AnimatedActor_Smugglers_Theif_FireWarm

[People of Tortuga] FireWarm
  lblook BP_AnimatedActor_TortugaCitizen_Dogface_FireWarm

[Brethren of the Coast] BotC_Sailor_LookerTable
  lblook BP_AnimatedActor_BotC_Sailor_LookerTable

[People of Tortuga] TortugaCitizen_Combatant_FireWarm
  lblook BP_AnimatedActor_TortugaCitizen_Combatant_FireWarm

[People of Tortuga] TortugaCitizen_Dogface_LookerTable
  lblook BP_AnimatedActor_TortugaCitizen_Dogface_LookerTable

[People of Tortuga] TortugaCitizen_Shooter_FireWarm
  lblook BP_AnimatedActor_TortugaCitizen_Shooter_FireWarm

----------------------------------------------------------------------
DECOR: Nature  (13 entries, key: ' / ; -- category 'nature')
----------------------------------------------------------------------

[CoastJungleMineralMushroom_01]
  lblook CoastJungleMineralMushroom_01

[CoastJungleMineralMushroom_02]
  lblook CoastJungleMineralMushroom_02

[CoastJungleMineralNestDodo_01]
  lblook CoastJungleMineralNestDodo_01

[CoastJungleMineralNestDodo_02]
  lblook CoastJungleMineralNestDodo_02

[CoastJungleMineralRootDebris_01]
  lblook CoastJungleMineralRootDebris_01

[Mineral_MiddleRock_04]
  lblook Mineral_MiddleRock_04

[Mineral_MiddleRock_05]
  lblook Mineral_MiddleRock_05

[Segment_Coast_Jungle_PalmCoconutFruit_700cm]
  lblook Segment_Coast_Jungle_PalmCoconutFruit_700cm

[Segment_Coast_Jungle_PalmCoconutFruit_1000cm]
  lblook Segment_Coast_Jungle_PalmCoconutFruit_1000cm

[Segment_Coast_Jungle_PalmCoconutFruit_1400cm]
  lblook Segment_Coast_Jungle_PalmCoconutFruit_1400cm

[Segment_Coast_Jungle_PalmSabal_250cm]
  lblook Segment_Coast_Jungle_PalmSabal_250cm

[Segment_Coast_Jungle_PalmSabal_450cm]
  lblook Segment_Coast_Jungle_PalmSabal_450cm

[Segment_Highlands_Divi_1200cm]
  lblook Segment_Highlands_Divi_1200cm

----------------------------------------------------------------------
DECOR: Boats  (5 entries, key: ' / ; -- category 'boats')
----------------------------------------------------------------------

[PortBoat_01]
  lblook PortBoat_01

[PortBoat_02]
  lblook PortBoat_02

[Shared_Camp_PropsComposition_72]
  lblook Shared_Camp_PropsComposition_72

[Shared_Camp_PropsComposition_75]
  lblook Shared_Camp_PropsComposition_75

[Shared_Camp_PropsComposition_76]
  lblook Shared_Camp_PropsComposition_76

----------------------------------------------------------------------
DECOR: Wrecks  (5 entries, key: ' / ; -- category 'wrecks')
----------------------------------------------------------------------

[Shipwreck_Boat_01_01]
  lblook Shipwreck_Boat_01_01

[Shipwreck_Boat_01_03]
  lblook Shipwreck_Boat_01_03

[Shipwreck_Cutter_01_02]
  lblook Shipwreck_Cutter_01_02

[Shipwreck_Cutter_02_02]
  lblook Shipwreck_Cutter_02_02

[Shipwreck_Spanthout_01_02]
  lblook Shipwreck_Spanthout_01_02

----------------------------------------------------------------------
DECOR: Tents / Bedrolls  (12 entries, key: ' / ; -- category 'tents')
----------------------------------------------------------------------

[Shared_CampTents_02]
  lblook Shared_CampTents_02

[Shared_CampTents_04_01]
  lblook Shared_CampTents_04_01

[Shared_CampTents_11]
  lblook Shared_CampTents_11

[Shared_CampTents_12]
  lblook Shared_CampTents_12

[Shared_CampTents_13]
  lblook Shared_CampTents_13

[Shared_CampTents_14]
  lblook Shared_CampTents_14

[Shared_CampTents_15]
  lblook Shared_CampTents_15

[Shared_CampTents_19]
  lblook Shared_CampTents_19

[Shared_CampTents_Abandoned_01]
  lblook Shared_CampTents_Abandoned_01

[Shared_CampTentsBB_11]
  lblook Shared_CampTentsBB_11

[Shared_CampTentsBB_12]
  lblook Shared_CampTentsBB_12

[Shared_CampTentsBB_14]
  lblook Shared_CampTentsBB_14

----------------------------------------------------------------------
DECOR: Storage Clutter  (21 entries, key: ' / ; -- category 'storage')
----------------------------------------------------------------------

[Shared_Camp_PropsComposition_01]
  lblook Shared_Camp_PropsComposition_01

[Shared_Camp_PropsComposition_02]
  lblook Shared_Camp_PropsComposition_02

[Shared_Camp_PropsComposition_05]
  lblook Shared_Camp_PropsComposition_05

[Shared_Camp_PropsComposition_11]
  lblook Shared_Camp_PropsComposition_11

[Shared_Camp_PropsComposition_12]
  lblook Shared_Camp_PropsComposition_12

[Shared_Camp_PropsComposition_14]
  lblook Shared_Camp_PropsComposition_14

[Shared_Camp_PropsComposition_15]
  lblook Shared_Camp_PropsComposition_15

[Shared_Camp_PropsComposition_18]
  lblook Shared_Camp_PropsComposition_18

[Shared_Camp_PropsComposition_23]
  lblook Shared_Camp_PropsComposition_23

[Shared_Camp_PropsComposition_24]
  lblook Shared_Camp_PropsComposition_24

[Shared_Camp_PropsComposition_26]
  lblook Shared_Camp_PropsComposition_26

[Shared_Camp_PropsComposition_27]
  lblook Shared_Camp_PropsComposition_27

[Shared_Camp_PropsComposition_28]
  lblook Shared_Camp_PropsComposition_28

[Shared_Camp_PropsComposition_30]
  lblook Shared_Camp_PropsComposition_30

[Shared_Camp_PropsComposition_46]
  lblook Shared_Camp_PropsComposition_46

[Shared_Camp_PropsComposition_47]
  lblook Shared_Camp_PropsComposition_47

[Shared_Camp_PropsComposition_51]
  lblook Shared_Camp_PropsComposition_51

[Shared_Camp_PropsComposition_52]
  lblook Shared_Camp_PropsComposition_52

[Shared_Camp_PropsComposition_53]
  lblook Shared_Camp_PropsComposition_53

[Shared_Camp_PropsComposition_64]
  lblook Shared_Camp_PropsComposition_64

[Shared_Camp_PropsComposition_65]
  lblook Shared_Camp_PropsComposition_65

----------------------------------------------------------------------
DECOR: Furniture  (20 entries, key: ' / ; -- category 'furniture')
----------------------------------------------------------------------

[BenchCrateT01_01]
  lblook BenchCrateT01_01

[BrokenStockade_LadderComposition_01]
  lblook BrokenStockade_LadderComposition_01

[ChestVisual_BigWooden_BBChest_04]
  lblook ChestVisual_BigWooden_BBChest_04

[ChestVisual_Blackbeard_01]
  lblook ChestVisual_Blackbeard_01

[ChestVisual_Clay_01]
  lblook ChestVisual_Clay_01

[Shared_Camp_PropsComposition_04]
  lblook Shared_Camp_PropsComposition_04

[Shared_Camp_PropsComposition_10]
  lblook Shared_Camp_PropsComposition_10

[Shared_Camp_PropsComposition_16]
  lblook Shared_Camp_PropsComposition_16

[Shared_Camp_PropsComposition_25]
  lblook Shared_Camp_PropsComposition_25

[Shared_Camp_PropsComposition_29]
  lblook Shared_Camp_PropsComposition_29

[Shared_Camp_PropsComposition_31]
  lblook Shared_Camp_PropsComposition_31

[Shared_Camp_PropsComposition_59]
  lblook Shared_Camp_PropsComposition_59

[Shared_Camp_PropsComposition_60]
  lblook Shared_Camp_PropsComposition_60

[Shared_Camp_PropsComposition_61]
  lblook Shared_Camp_PropsComposition_61

[Shared_Camp_PropsComposition_69]
  lblook Shared_Camp_PropsComposition_69

[Tortuga_Wardrobe_02]
  lblook Tortuga_Wardrobe_02

[WardrobeAshlands_04]
  lblook WardrobeAshlands_04

[WardrobeAshlands_06]
  lblook WardrobeAshlands_06

[WardrobeAshlands_09]
  lblook WardrobeAshlands_09

[WindChime_02]
  lblook WindChime_02

----------------------------------------------------------------------
CREW (Num1)  (14 entries)
----------------------------------------------------------------------

[Player] Player Crew
  lblook Player Crew

[Buccaneers] Buccaneers Musketeer
  lblook Buccaneers Musketeer

[Buccaneers] Buccaneers Sailor
  lblook Buccaneers Sailor

[Buccaneers] Buccaneers Sergeant
  lblook Buccaneers Sergeant

[Smugglers] Smugglers Musketeer
  lblook Smugglers Musketeer

[Smugglers] Smugglers Sailor
  lblook Smugglers Sailor

[Smugglers] Smugglers Sergeant
  lblook Smugglers Sergeant

[People of Tortuga] Tortuga Musketeer
  lblook Tortuga Musketeer

[People of Tortuga] Tortuga Sailor
  lblook Tortuga Sailor

[People of Tortuga] Tortuga Sergeant
  lblook Tortuga Sergeant

[Brethren of the Coast] Brethren Musketeer
  lblook Brethren Musketeer

[Brethren of the Coast] Brethren Sailor
  lblook Brethren Sailor

[Brethren of the Coast] Brethren Sergeant
  lblook Brethren Sergeant

[Brethren of the Coast] Brethren Woman
  lblook Brethren Woman

----------------------------------------------------------------------
SENKAMATI (Num7)  (13 entries)
----------------------------------------------------------------------

[Warrior -- crew, full armor/mask]
  lblook Warrior_crew_Mask

[Warrior -- crew, no helmet]
  lblook Warrior_crew

[Hunter -- mob, full armor/mask]
  lblook Hunter_mob_Mask

[Hunter -- mob, no helmet]
  lblook Hunter_mob

[Hunter -- crew, full armor/mask]
  lblook Hunter_crew_Mask

[Hunter -- crew, no helmet]
  lblook Hunter_crew

[Caster-F -- mob, full armor/mask]
  lblook Caster-F_mob_Mask

[Caster-F -- mob, no helmet]
  lblook Caster-F_mob

[Caster-F -- crew, full armor/mask]
  lblook Caster-F_crew_Mask

[Caster-F -- crew, no helmet]
  lblook Caster-F_crew

[Warrior -- corrupted (original monster look)]
  lblook Warrior_corrupted

[Hunter -- corrupted (original monster look)]
  lblook Hunter_corrupted

[Caster-F -- corrupted (original monster look)]
  lblook Caster-F_corrupted

----------------------------------------------------------------------
ANIMALS / LIVESTOCK (Num8)  (13 entries)  -- lblook, NOT lbspawn (2026-08-13:
raw lbspawn of these classes skips the friendly-faction/AI-override/
component-disable treatment, so they stay wild/aggressive -- lblook runs the
same spawnCreature() path the real Num8 key uses, so they come out tame)
----------------------------------------------------------------------

[Boar]
  lblook Boar

[Sow]
  lblook Sow

[BoarCharger]
  lblook BoarCharger

[BoarMega]
  lblook BoarMega

[GoatF]
  lblook GoatF

[GoatM]
  lblook GoatM

[GoatMega]
  lblook GoatMega

[Dodo]
  lblook Dodo

[DodoF]
  lblook DodoF

[Wolf]
  lblook Wolf

[AlphaWolf]
  lblook AlphaWolf

[Crocodile]
  lblook Crocodile

[CrocodilePlague]
  lblook CrocodilePlague

----------------------------------------------------------------------
WALKING WOMEN (Numpad .)  (5 entries)
----------------------------------------------------------------------

[Woman With Hat]
  lblook Woman With Hat

[Woman With Hair]
  lblook Woman With Hair

[Merchant]
  lblook Merchant

[Letty]
  lblook Letty

[Marita]
  lblook Marita

