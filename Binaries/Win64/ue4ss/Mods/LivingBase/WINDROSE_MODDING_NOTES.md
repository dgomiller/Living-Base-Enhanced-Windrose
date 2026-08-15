# Windrose Modding — Hard-Won Knowledge (2026-07-09)

Durable facts learned building LivingBase. Written so a fresh session can pick up cold.
Companion to `CLAUDE.md` (which is older and partly stale — trust THIS file where they disagree).

---

## 1. Spawning an actor that actually works

```
BeginDeferredActorSpawnFromClass(world, class, transform, CollisionHandling=1, Owner=nil, ScaleMethod=1)
  -> [deferred window: set AIControllerClass, CompositeMeshComponent params here]
FinishSpawningActor(actor, transform, ScaleMethod=1)
  -> SpawnDefaultController()
  -> ActivateCharacter()          <- native "bring this NPC to life"; without it they're frozen + naked
```
`resolveAsset(path)` = `StaticFindObject` → `LoadAsset` → `StaticFindObject`. Cheap once loaded.

**The deferred window (`preFinish`) is the only place pre-build state can be set.**

---

## 2. The composite (appearance) system — what sticks and what doesn't

`CompositeMeshComponent` has `DefaultParams`, `ArchetypePreset`, `BodyTypeParams`.

| Set pre-build | Sticks? |
|---|---|
| `DefaultParams` (the OUTFIT, e.g. Senkamati feather armor) | **YES** |
| `ArchetypePreset` (BODY / SKIN / HAIR) | **NO — `BeginPlay` re-randomizes it** |

Proven 2026-07-09: with `ArchetypeAfrican` pinned pre-build, 7 Warrior spawns rolled **5 different
ethnicities**. Same wall `CLAUDE.md` records for `BP_NPC_Citizen_Walker`. **Do not retry.**

Crew archetypes live at
`/R5BusinessRules/Character/Customization/NPC/ShipCrew/Sailor/Preset/DA_Mob_Regular_Sailor_Preset_Archetype<Ethnicity>`
(Adventurer, African, Albion, Fable, Native, Orient, Scum). Mobs use ONE preset
(`DA_Mob_Senkamati_Regular_Preset_Common`), which is why Hunter/Caster never vary.

**Consequence:** normalize appearance POST-build (material swaps + mesh replaces), not pre-build.
"Fable" is an *ethnicity*, not a hero body — `MI_Fable_Male_*` swaps like any other skin.

### 2a. Post-build: a genuine ENGINE FUNCTION can work where a raw property write can't (2026-08-15)

The composite component's `ArchetypePreset` property (2 above) and a separate `ColorParams`
property both showed the SAME dead-end signature post-build: set the property, force a rebuild
(`ConstructVisualFromParams`/`StartCharacterEdit`/`EndCharacterEdit`), the rebuild reports genuine
success (property visibly changed, build count incremented) — and the actual rendered mesh never
changes. Confirmed independently for two unrelated properties; looked like a hard rule ("post-build
composite writes are consumed once at construction, never re-read").

**It isn't a hard rule — it's specific to raw property writes.** The same component also exposes
dedicated SETTER FUNCTIONS for some of these same concepts (e.g. a sex-change function, found by
searching the UE4SS-generated object dump for every function the component's class declares, not
by guessing from its properties). Calling the genuine function post-build **actually worked** —
visibly changed and stayed changed, confirmed via before/after readback. A component can have BOTH
a property that's build-time-only AND a function that achieves the same conceptual change and
DOES work live; they are not interchangeable, and finding one dead end doesn't mean the whole
concept is dead.

**How to find the real functions**: UE4SS emits a full object dump at
`<GameRoot>/Binaries/Win64/ue4ss/UE4SS_ObjectDump.txt` (`GenerateObjectDump` module) —
plain-text, greppable. Search for `Function /Script/<Module>.<Class>:` to list every function a
class declares, each followed by its parameter properties on subsequent lines (bracket-indexed by
offset, typed). This is the same file worth checking whenever a property-based approach hits the
"reports success, never renders" wall — the function might already exist right next to the
property that didn't work, exactly where `IsXAvailable()`-style query functions (see 2b) hinted
something changeable should exist.

**Caveat — a documented function is not necessarily a SAFE one.** See 3g.

### 2b. Related tricks that fell out of the same investigation

- **`IsXChangeAvailable()`-style boolean query functions are a hint, not proof, that a live setter
  exists** — they answer "can the player-facing customization UI edit this", not "will a Lua write
  to the matching property render". Confirmed present and TRUE on a class whose matching property
  was independently confirmed build-time-only-dead (2a) — the query function and the underlying
  mechanism aren't the same thing. Still worth checking the object dump for a same-named `SetX`/
  `SwapX` function sitting near the query function; that's a real signal, just not a guarantee.
- **A gameplay tag is usually a trivial one-field struct** (`FGameplayTag` → a single `FName`
  field) — confirm via the same struct-drilling as §10's `R5BLRecordId` example, but once
  confirmed, WRITING one back is much simpler than reading an unfamiliar struct: a plain Lua table
  (`{ FieldName = "value" }`) works directly as the argument, no struct-drilling needed for the
  write direction, matching how simple math structs (`FVector`, as `{X=,Y=,Z=}`) already do.
- **Bracket-indexing a `TArray<FSomeStruct>` also returns a wrapper that needs unwrapping** — not
  just `TArray<UObject*>` (already known: bracket/`:Get()` indexing returns a `RemoteUnrealParam`,
  not the element itself, fixed by calling `:get()` on it). The exact same wrapper-and-unwrap
  requirement applies to struct-valued array elements too; a probe that reads back empty/blank
  values from an otherwise-successful array read is almost certainly missing this step, not proof
  the array itself is empty.

---

## 3. THE CRASH TRAPS (each cost hours)

### 3a. Stale UObject pointers — the big one
Rule tables live at **module scope**. Caching a resolved `UObject` (`rp._mesh`, `sw._mat`) behind a
one-shot `_tried` flag means the pointer **outlives world loads and GC**. Handing a dangling UObject
to `SetSkeletalMesh` / `SetMaterial` is a **native crash `pcall` cannot catch.**

Fix: `liveAsset(store, key, path)` — validate `:IsValid()` on EVERY use, re-resolve when dead, and
cap retries (`_miss`) so a genuinely-missing asset doesn't re-trigger `LoadAsset` each pass.

Symptoms that mean "stale pointer": fine on a fresh session, crashes after reloading/despawning a
while, hits different actors, never reproduces on demand.

### 3b. Log BEFORE the dangerous call, never after
A native crash never reaches your success line. Print `>>> REPLACE mesh on comp[X]` *immediately
before* the op. That single change localised a week-old crash to inside `SetSkeletalMesh` (dump
landed 0.2 ms later, same frame).

### 3c. Component surgery during world load
Destroying components (perception strip, nameplate) while an AI is still initialising crashes.
Defer to a post-process pass ~8s after load, spaced ~400ms.

### 3d. Spawning into a not-yet-live world
The player pawn **exists during the loading screen** — its presence is NOT proof the world is live.
Gate on the player actually MOVING horizontally. Also: the first spawn must not land in the same
frame as the restore's own synchronous head (`RESTORE_LEAD_IN_MS`).

### 3e. Two composite builds in one frame
Two spawns in the same instant crash. Debounce keypresses (`SPAWN_DEBOUNCE_MS = 300`).

### 3f. `StaticFindObject("/Script/R5.<Component>")` — NOT universally broken
It returns nil for `R5AbilitySystemComponent` (which made `MakePassive` a silent no-op for weeks),
but `R5MarkerComponent`, `R5CommonInteractionTargetComponent`, `R5PrimitiveInteractionTargetComponent`
**all resolve fine.** Measure each path; don't generalise. Reach ASC-family components by PROPERTY.

### 3g. A function existing in the object dump doesn't mean it's safe to call (2026-08-15)
Found a real, dedicated setter function for changing a body-type-style property live (see 2a for
why this looked promising — a genuine function, not a build-time-only property write). Called it
with correctly-typed arguments, matching the parameter list read straight from the object dump.
**It crashed the engine natively, twice in a row, on two separate live tests.** `pcall` around the
call caught nothing — not even the wrapping function's own FIRST log line (printed immediately
after the `pcall` returns) ever appeared, meaning execution never came back to the Lua VM at all;
same "uncatchable, no trace" signature as every other native crash in this file. A sibling function
on the exact same class, taking a conceptually near-identical argument (an enum "which variant"
selector, same component), worked perfectly with zero issues (2a). **The object dump proves a
function EXISTS and tells you its signature; it proves nothing about whether calling it is safe.**
Treat any first live call to a newly-discovered engine function as a real crash risk regardless of
how reasonable the theory behind it is, especially for anything that mutates a live pawn's
customization/composite state — save first, or accept the game may need a hard restart.

---

## 4. Restore-on-load design (why it looks the way it does)

- `RegisterInitGameStatePostHook` fires **several times per load** (menu, then ~3x). Use
  **latest-fire-wins generation counter**, NOT a lock. A lock let the MENU's chain swallow the real
  world-load fire, then time out silently → nothing ever restored.
- Wait for player pawn (`R5Character`), then wait for the player to **move** → world is live.
- Split the save: **statues** (`AnimatedActor` / `QuestStatic`, no AI — fast) vs **movers** (each
  wakes an AI — pace them). Only movers get post-processing.
- `persistAppend` is guarded by `Spawner.restoring` so restore doesn't re-record.
- Ledger writes are **buffered during restore** and flushed once (was 1 file open per spawn).
- Never fail silently — log both "waiting" and "gave up". Silence hid a total-restore-failure bug.

---

## 5. Peace / faction mechanics

- Friendly faction asset: `/Game/Gameplay/Character/Common/Relationship/Params/DA_Player_Crew_Faction`
  — load it **directly**; don't depend on a live crew existing.
- **Goats:** `GoatM` extends `GoatMega` (brawler brain) and fights crew. Fix = give GoatM the
  **GoatF prey controller** + strip `MemoryComponent` + `R5AgentComponent` (threat perception, kills
  the flee). Goat→goat brain swap is safe; the crew brain FREEZES them.
- Boar is docile only because `BP_Mob_Boar_Friend` is a dedicated friendly class.
- Senkamati humanoids respect the friendly faction; wild animals largely ignore it (need the AI swap).
- **To make something HOSTILE: simply don't apply the friendly faction.** It keeps its own.

---

## 5b. Movement: THIS GAME DOES NOT USE THE UE NAVMESH

Every AI pawn carries `MercunaGroundNavigationComponent` (`/Script/R5Mercuna.R5MercunaGroundNavigationComponent`).
Windrose navigates with **Mercuna**, a third-party system. Consequences:

- `UAIBlueprintHelperLibrary::SimpleMoveToActor` **does nothing.** It doesn't throw and doesn't
  return failure — it posts into a nav system these pawns never read. Any log line that says
  "move order issued" off the back of it is meaningless. Cost: two sessions.
- Reach the component **by property** (`pawn.MercunaGroundNavigationComponent`), never
  `StaticFindObject` on the R5 component class. Never cache it (dangling pointer across GC).
- The API you want (`UMercunaGroundNavigationComponent`, in `Mercuna.hpp`):
  - `TrackActor(Actor, Distance, Speed, Offset, UsePartialPath)` — **continuous follow. Use this.**
  - `MoveToActor(Actor, EndDistance, Speed, UsePartialPath)` — one-shot. Re-issuing it every tick
    can restart pathfinding before the pawn takes a step, which looks exactly like "ignored".
  - `Stop()` / `CancelMovement()`, `PauseNavigation()` / `ResumeNavigation()`
  - `SetNavGridToBest()` — **no nav grid = every order silently discarded.** Rule it out first.
  - `GetRemainingPathLength()`, `GetPathInfo(Valid, DistanceToEnd)` — the only honest way to know
    whether a path exists. `Speed = 0` means "the pawn's own default speed".
- **Diagnosing a pawn that won't move**, from speed + remaining path length:
  - path > 0, speed > 0 → working
  - path > 0, speed ≈ 0 → a path exists but something cancels it each frame (its own StateTree —
    `StopLogic()` on the controller)
  - path ≤ 0 forever → no route: no nav grid, navigation paused, or the goal is off-grid
- **Distance alone never proves following.** If the player walks toward a frozen pawn the distance
  shrinks and it reads as success. Check the distance while the player stands STILL, or read speed.

---

## 6. Workflow that works

- **Run `python lint.py` before handing over any edit.** Compiling is NOT enough: `lupa` proves the
  Lua *parses*, and happily compiles a call to a function that doesn't exist. v2.19 shipped
  `always(...)` with no definition — every call raised "attempt to call a nil value" and killed
  the restore chain, while the compile check said OK. `lint.py` does three things: compiles,
  flags **called-but-undefined** functions, and asserts every `Config.X` reference resolves.
- `lupa` runs Lua 5.5 (stricter than UE4SS's 5.4 — a useful forward-compat canary). One
  unterminated string kills the whole mod.
- **Never edit Lua by generating it from a Python heredoc.** Escaping `
` through two languages
  has silently written literal newlines into Lua strings (breaking the file) and silently failed
  to match (dropping the edit). Use the file editor for anything with escapes.
- Verify config refactors by **executing config.lua** and asserting keys/table sizes, not by eye.
- `Config.VERBOSE` gates per-spawn logging. Keep the `>>>` breadcrumbs — they're the debugger.
- UE4SS GUI console (`GuiConsoleEnabled/Visible`) is an OpenGL window on an external render thread.
  Turn it OFF for play.
- All engine-touching Lua in `pcall`. Game-version strings ONLY in `config.lua`.
- **Undo only ever spawns, never destroys.** `Spawner.UndoDespawn` respawns whatever's in
  the popped batch; it does not infer anything to remove first. Fine for a pure despawn
  (the spot is empty). Any feature that destroys-and-recreates IN PLACE (e.g.
  `CycleNearestInFront` swapping a statue/decoration for its next roster entry) must attach the live
  replacement actor to its own undo item (`replaceActor`/`replaceClass`/`replacePos`) so
  undo destroys+untracks it before respawning the old one — otherwise undo stacks a
  duplicate on top of the still-live replacement. Cost a follow-up fix (2026-07-27) after
  shipping cycle-pose undo without it.
- **`Ctrl` is permanently unusable as a UE4SS modifier key in Windrose -- confirmed systemic, not
  a one-off.** Windrose's own native Dodge action is bound to plain `Ctrl`, and the game's own
  input handling claims it before UE4SS's key-hook layer ever sees a `Ctrl+X` combo. This silently
  breaks EVERY one of UE4SS's Ctrl-based defaults at once:
  - **The entire built-in "Keybinds" mod** (`Mods/Keybinds/Scripts/main.lua`, separate from any
    Windrose-specific mod) -- Ctrl+J ObjectDumper (`DumpAllObjects()`, dumps every loaded UObject
    + its properties to `UE4SS_ObjectDump.txt`), Ctrl+Num7 DumpAllActors, Ctrl+H/Ctrl+Num9 C++/UHT
    header generators, Ctrl+Num8 DumpStaticMeshes, Ctrl+Num6 DumpUSMAP. **CONFIRMED LIVE
    (2026-08-13) for Ctrl+J specifically**: pressing it produced no dump file and no log line at
    all (checked `UE4SS_ObjectDump.txt` under `ue4ss/`, the whole game root, and
    `%LOCALAPPDATA%/R5/Saved` -- nothing). The other five were never separately live-tested, but
    there's no reason to expect any of them behave differently -- same Ctrl conflict, same hook
    layer. Treat all six as "assume broken until proven otherwise" in this game, not just the one
    that happened to get tested.
  - **UE4SS's own hot-reload system.** Its modifier is not just conventionally Ctrl, it's
    **hardcoded** -- `UE4SS-settings.ini`'s own `HotReloadKey` comment says outright "The CTRL key
    is always required," and only the second key (default `R`) is configurable. **CONFIRMED LIVE
    (2026-08-13): Ctrl+R has never worked in this project either, same root cause.** Unlike the
    Keybinds-mod tools above, there is no rebind fix for this one -- Ctrl can't be swapped out.
  - **The workaround differs by category.** For a plain callable Lua function (`DumpAllObjects()`,
    `DumpAllActors()`, `DumpStaticMeshes()`, etc.), wrap it in a `RegisterConsoleCommandHandler`
    command instead of a keybind -- console input doesn't compete with the game's own bindings at
    all (the same reasoning LivingBase's own `lbspawn`/`lblook` are built on). **Done**:
    LivingBase now ships `lbdumpobj`/`lbdumpact`/`lbdumpmesh` (`main.lua`) doing exactly this.
    Hot-reload has **no Lua-callable equivalent to wrap at all** (checked -- the only two triggers
    UE4SS exposes are the native keybind and the "Restart All Mods" button in UE4SS's own GUI
    console, no global function), so the console-command trick doesn't apply there; the GUI
    console button (`GuiConsoleEnabled`/`Visible` in `UE4SS-settings.ini`, normally left off for
    play -- see this section's own earlier note on it) is the only way left to reload mods short
    of a full game relaunch.
- **Other installed UE4SS mods worth knowing about, found while investigating console commands
  (2026-08-13):** `CheatManagerEnablerMod` forces a real `CheatManager` object onto the
  PlayerController on `ClientRestart` (many shipping UE games, this one included, never
  instantiate one by default, which silently no-ops every native `exec` cheat command) --
  almost certainly a prerequisite for `ConsoleCommandsMod`'s `summon`/`set`/`dump_object`
  commands to work at all. `BPML_GenericFunctions` is unrelated plumbing for a separate
  Blueprint-based mod-loading framework (BPModLoader), not something LivingBase or any Lua/
  UE4SS mod depends on.

---

## 7. Useful class paths

```
Player pawn class name contains  : R5Character
Crew (regular / officer)         : /Game/Gameplay/Character/AI/Crew/{Regular,Officer}/Faction/Player/BP_Mob_Crew_{Regular,Officer}_Player
Townsfolk                        : /Game/Gameplay/Character/AI/NPC/Handyman/Handyman_<Prof>/BP_NPC_Handyman_<Prof>
                                   /Game/Gameplay/Character/AI/NPC/Citizen/BP_NPC_Citizen_{Walker,Worker}
Senkamati mobs                   : /Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_<Type>/BP_Mob_SenkamatiCorrupted_Regular_<Type>
Goats / Boar                     : /Game/Gameplay/Character/AI/Mob/Goat/{GoatF,GoatM}/... , .../Mob/Boar/Friend/BP_Mob_Boar_Friend
DROWNED                          : /Game/Gameplay/Character/AI/Mob/Drowned/BP_Mob_Drowned_{Naked,Armored}_Gamescom
Map                              : /Game/Maps/GYM/Genlandia/GenlandiaMulty
Buildable "employee" trader posts: /Game/Gameplay/Building/BuildingEmployees/BP_BuildingBlock_Employee_Trader_{Food,Resources,Animals}
```

**Buildable "employee" posts render their vendor directly on the building block itself, not as a
separate NPC** (2026-08-13/14). The Food/Resources/Animals trader tables place a visible person at
them, which reads as an NPC but isn't one: their native parent chain is `R5BuildingBlock_Employee`
(itself a `R5CraftStation` subclass, same family as the Alchemy/Blacksmith/Cooking crafting tables)
— a plain building-block actor, no `AIController`/`PawnClass`/separate-actor reference anywhere.
Each one's own Class Default Object owns an `R5CompositeMeshComponent` directly (property `Mesh` +
`CompositeMeshComponent` on the native class) — the same composite-body-rig system this mod already
drives for player-shaped NPCs, just attached to a building-block actor instead of a pawn. Confirmed
live: `lbspawn`-ing one of these classes renders identically to the placed object with zero extra
composite params supplied — the look is baked into the class's own construction, not assigned at
runtime by some separate "hire a worker" system as originally guessed.

---

## 7b. Reacting to things the GAME spawns

`NotifyOnNewObject(classPath, callback)` (UE4SS) fires the **instant** an object of that class is
constructed. No polling, no per-frame cost. This is how to catch a summon, a totem, a spawned mob.
Learned from the PlagueWitchPet_FollowHelper Nexus mod. `LoopAsync(ms, fn)` is its periodic partner.

**Confirmed class paths (from that mod, cross-checked against our probe):**
```
whistle pet   : /Game/Gameplay/Character/AI/Mob/Boar/Friend/BP_Mob_Boar_Friend.BP_Mob_Boar_Friend_C
whistle pet L2: .../BP_Mob_Boar_FriendLvl2.BP_Mob_Boar_FriendLvl2_C
caster totem  : /Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Shaman_Caster/Totem/
                BP_Mob_SenkamatiCorrupted_Reglar_Shaman_Caster_Totem.  <- the game's own typo, "Reglar"
```

**There is NO `UR5PetSummonParams` in this game.** The whistle spawns `BP_Mob_Boar_Friend` directly.
The PlagueWitchPet pak simply *replaces that uasset*. Changing the summon "properly" needs a cooked
pak; from Lua, anchor the spawned pet instead (hide it, disable collision, make it immune) and let it
keep holding the game's timer/cooldown/dismiss bookkeeping while your own pawns do the work.

## 8. Drowned / night-raid scouting (2026-07-09, not yet built)

- Classes exist: `BP_Mob_Drowned_{Naked,Armored,Spitter}`, `BP_Mob_Crab_Drowned`, each with its own
  `BP_Mob_AIController_Drowned*`. Only the **`_Gamescom`** variants were observed live.
- **They are already in the world**, placed in `PersistentLevel`, seen 52–66m from the player's base.
- Native spawn machinery: `AR5SpawnPoint` (holds `UR5SpawnPointParams`), `AR5AISpawnPoint`,
  `AR5SpawnAnchor`, `AR5POISpawner`. Gating conditions: `UR5SpawnerCondition_{DayCycleTime,Weather,
  Preset,ComplexCondition}`; `FR5AISpawnRestrictionData { DayCycleTimeInterval, AllowedWeatherPresets }`.
- **No bonfire/base radius appears in the native restriction struct** — whatever suppresses spawns
  near a base is Blueprint-side, not in `R5.hpp`.
- Day-cycle read: no obvious native getter. Only `FR5NamedDayCycleTime`, `DayCycleTimes`,
  `OverrideDayCycleTimes`, `DayCycleComponentCurve` exist. Needs a runtime probe (`FindAllOf`) to
  locate the actor/component exposing current time.
- **Recommended approach:** don't fight the suppression. Spawn our own Drowned around the base at
  night, hostile (just don't apply the friendly faction), and let their own AI engage the crew.

## 9. Cross-skeleton re-skinning: what actually determines the result (2026-08-10)

The Warrior's original trick — spawn a HUMAN-skeleton pawn, then apply a DIFFERENT class's
composite armor via `Spawner.SetCompositeParams` pre-build (see §2) — generalizes to any
composite-armor family, not just crew. Applied this session to give the Senkamati Hunter/Caster
a normal walk (their own mob skeleton has its own heavy AI/anim set, same "zombie shuffle" the
Warrior always avoided). What matters and what doesn't:

- **Which mesh a component uses is independent of the component's own name/slot.** A skeletal
  mesh's render position/deformation comes from ITS OWN skin weights against the shared skeleton
  bones (leader-pose bound), not from which named component happens to host it. In practice this
  means a REPLACE rule can point ANY matched component at ANY mesh and it'll render wherever that
  mesh's own rigging puts it — useful for borrowing an unrelated piece, but it also means a wrong
  guess doesn't fail loudly, it just renders in a place that looks wrong.
- **A material successfully applying is not the same as it looking right.** Some composite armor
  materials (confirmed: `MI_ArmorCreature_Senkamati`) depend on UV layout or vertex-color data
  baked into the SPECIFIC mesh they were authored for. Assigning that same material (confirmed
  correct via a live probe showing the exact right material path) onto a borrowed, differently-
  authored mesh does not reproduce the same visual result — it rendered as a flat, wrong color
  instead of the intended tribal tone. `resolveAsset` succeeding only proves the asset exists, not
  that it'll look right in a new context.
- **This game's SHIPPED human body meshes have no nude/undressed variant, anywhere** (as originally
  written, before §11 below). Confirmed by extracting every readable string from every pak file
  (see the scanning technique below) and searching for "Nude"/"Naked"/"Undress" — zero hits for
  any human body (the only "Naked" hits were an unrelated Drowned mob variant and rock-formation
  names that happen to contain the substring) — but that's a statement about the BASE GAME's own
  assets specifically, not a hard engine wall: §11 covers a third-party content-replacer pak later
  found to supply gap-free geometry for exactly this zone. These bodies are modeled assuming a
  garment ALWAYS covers the pelvis region; there is no fallback skin geometry under a stripped-away
  garment IN THE ORIGINAL ASSET. A "grass skirt"-style piece (gaps between hanging strands, meant
  to show the wearer's own skin through them) looks correct on the Senkamati mob's own body (which
  does have that geometry) and shows a literal hole straight through to the world on any human-
  skeleton body. The fix used here: replace it with a solid garment mesh instead of a fringe/gap
  design (see also §11's note on mesh-fit assumptions when a body mesh is later swapped).
- **Pak files ARE partially string-scannable without a real UE unpacking tool.** `.utoc`/`.pak`
  containers are compressed/hashed IoStore data, not plaintext (confirmed: `global.utoc` yields
  effectively nothing when scanned) — but some of this game's pak chunks (the `pakchunk0*-
  Windows.utoc` set specifically) embed thousands of readable `.uasset` filename fragments as
  leftover/uncompressed string-table data. A plain Python scan —
  `re.findall(rb'[\x20-\x7e]{5,}', open(path,'rb').read())` — over each `.utoc` file surfaces
  real, confirmable asset filenames (~56k unique strings across this game's pak set). This found
  the exact male equivalent of a female garment asset already confirmed live (same folder,
  swapped `_Female_`→`_Male_`) without needing an in-game probe of a male NPC wearing it, and
  ruled out the nude-body-variant search above without guessing paths one at a time. Cheap,
  read-only, no risk to game files — worth trying before assuming an asset must be found live.
- **A genuinely walking, non-unique FEMALE NPC class exists**: `BP_NPC_Handyman_Gatherer_C`
  (`/Game/Gameplay/Character/AI/NPC/Handyman/Handyman_Gatherer/`), body `SK_Adventure_Female_01`,
  AI `BP_NPC_AIController_Handyman_C` + `DA_NPC_Handyman_AIPawnParams` — the same proven Handyman
  walk/wander brain already used elsewhere in this mod. Found by aiming the HOME/PAUSE probe at a
  real one wandering the world. This overturns an earlier "no walking women exist in this game"
  conclusion recorded elsewhere in this project — that was about specific classes already tried
  (a unique hireable employee, a unique quest NPC, the male-locked procedural Citizen_Walker), not
  an exhaustive survey. **If a similar "doesn't exist" wall gets hit again, check whether it was a
  survey of the whole game or just of what was already tried before treating it as settled.**
- **Silencing an NPC's voice lines**: the plain engine `/Script/Engine.AudioComponent` (property
  name `AudioVoice` on Handyman-family NPCs) drives idle/bark dialogue. It's a DIFFERENT class
  from the R5-custom sound components on the same pawn (`R5CosmeticSoundComponent`,
  `R5InterruptibleSoundComponent`, `R5FootstepComponent`), so destroying just the plain
  `AudioComponent` class (via the existing `stripComponentsOfClass` helper, already proven safe
  for `StripInteraction`/`StripQuestScenario`) silences voice lines without touching footsteps or
  other cosmetic sound.
- **Finding a compatible sibling base from an object dump, without a live probe first** (2026-08-14):
  a second walking-female class was needed. Rather than guessing a class path and testing it blind,
  compared its declared parent in a `DumpAllObjects()`-style dump: both `BP_NPC_Handyman_Gatherer_C`
  and the candidate `BP_NPC_Handyman_Herbalist_C` list the identical `[sps: <hex address>]` (super-
  struct) value, both resolving to the same immediate parent `BP_NPC_Handyman_C` — i.e. they're
  proven architectural siblings (same skeleton/AI/component shape) purely from the STATIC class
  graph, before ever spawning either. This only proves shape, not instance data (sex, starting
  archetype, which mesh actually loads) — that still needs a live spawn or a real in-world NPC of
  that class to confirm — but it's a genuinely useful FIRST filter: any class sharing a proven base's
  exact `[sps: ...]` is a much safer next guess than an unrelated class in the same rough folder.

---

## 10. The per-world identifier (2026-08-13)

Windrose supports multiple named-save "worlds" selectable from a world-list menu (each shown
with a GUID-like ID in that menu's own tooltip), but nothing about which world is loaded was
ever exposed to this mod before v1.3.8 — `persist.txt`/`spawn_ledger.txt` were one flat filename
shared by every world.

- **The identifier**: `World.GameState.islandId.ID` — an `R5BLRecordId` struct's `ID` field
  (an `FString`). Confirmed live: this value is byte-identical to the ID shown in the
  world-select screen's own tooltip for that save.
- **It is EMPTY until the world is genuinely live.** Reading it straight off
  `RegisterInitGameStatePostHook` returns `""` every time — that hook also fires for the
  Lobby/EntranceHall/TransitionMap menu chain, and even for the real destination map, GameState
  exists before save data has streamed into it (`GameState.ReplicatedWorldTimeSecondsDouble` is
  still `0.0` at that point). It only reads back correctly by the time `RestoreFromPersist`
  actually runs — i.e. after the same pawn-exists-and-moved wait §4 already does for restore
  timing. Don't add a second, earlier read path for this; hook it to the same "world is live"
  signal restore already uses.
- **Reading a struct-VALUE property (not a UObject reference) needs one extra layer.**
  `gameState["islandId"]` returns a struct wrapper, not the instance data directly — calling
  `:GetFullName()` on it (the usual move for a UObject property) returns the STRUCT'S OWN TYPE
  name (`"ScriptStruct /Script/R5BLCommon.R5BLRecordId"`), not anything useful. To read its
  actual fields: `StaticFindObject("/Script/R5BLCommon.R5BLRecordId")` to get the struct's own
  `UScriptStruct`, then `:ForEachProperty(...)` over THAT (same call struct/class definitions
  already support), reading each field back off the struct instance by the same bracket-indexing
  every other property read in this codebase already uses (`structVal[fieldName]`).
- **FString-typed fields need `:ToString()`, not `:GetFullName()` or bare `tostring()`.**
  `tostring()` on an FString userdata prints its raw pointer (`"FString: 0000021E..."`), not the
  text. `:GetFullName()` fails outright (not a UObject). Fallback chain that actually works for
  any userdata value: try `:GetFullName()` first (UObject refs), then `:ToString()` (FString/
  FName-style wrappers), then `tostring()` as a last resort.
- **`os.rename` is available** in this UE4SS Lua build (used for the `persist.txt` →
  `persist.bak` migration step) — Windows semantics apply (fails rather than overwrites if the
  destination already exists), so wrap it in `pcall` and treat failure as non-fatal.
- **The struct-drilling recipe above generalizes to ANY unfamiliar native struct, without needing
  to already know its type path** (2026-08-15 refinement). Plain dot-access ONE level further into
  a struct wrapper (e.g. reading a nested field directly off it) is exactly the kind of read that
  causes an uncatchable native crash — confirmed again this session on a completely different
  struct. The fix each time is the same three-step recipe: (1) the TOP-LEVEL struct-valued
  property read itself is safe on its own (`holder.StructField`, one dot, no further drilling
  yet); (2) call `:GetFullName()` on THAT wrapper — normally read as "useless, just reports the
  struct's own type" (see above), but that's exactly what hands you the type path to feed
  `StaticFindObject` WITHOUT having to already know or guess it (`"ScriptStruct /Script/
  <Module>.<StructName>"` — strip the `"ScriptStruct "` prefix); (3) `:ForEachProperty()` over the
  resolved `UScriptStruct`, bracket-indexing the ORIGINAL wrapper instance (never the struct
  DEFINITION) for each field name found. This turns "I don't know this struct's shape" from a
  blocking problem into a fully mechanical, crash-safe discovery — no need to find the struct's
  definition in an object dump first.

---

## 11. Content-replacer paks (asset overrides): what's possible from Lua and what isn't (2026-08-13)

Distinct from everything above — this is about REPLACING a shipped asset (mesh/texture) at the
content level via a `.pak`/`.ucas`/`.utoc` trio, not about spawning/scripting behavior. Explored
while evaluating a third-party body-mesh replacer for compatibility with this mod.

- **A `_P`-suffixed override pak replaces content at the SAME virtual asset path, for EVERY
  reader, with no per-caller escape hatch.** This is standard UE IoStore patch-chunk behavior:
  once mounted, any code that resolves that path — the game's own systems, or your own
  `LoadAsset` call — gets the override version. The original (vanilla) version becomes
  unreachable through that path for as long as the override is mounted. There is no way to
  "opt out" for one specific caller/actor while the override stays mounted; scoping an override
  to just one NPC/situation requires giving the replacement a genuinely DIFFERENT asset path
  (which needs re-cooking — see below), not a scripting trick.
- **Content mods live in their own subfolder under `R5/Content/Paks/<ModName>/`**, containing the
  matching `.pak`/`.ucas`/`.utoc` trio (all three needed together — `.ucas`/`.utoc` is the IoStore
  container, `.pak` alone is a small index/header). The engine auto-discovers pak folders
  recursively; no manifest file is needed to register one (confirmed by an existing installed pak
  mod using this same layout).
- **Pak mounting only happens at game STARTUP — it is NOT hot-reloadable.** Unlike this mod's own
  Lua (which picks up edits via a console-command-triggered restart with no world/menu round
  trip), adding or removing a content pak needs a full game relaunch to take effect. There is also
  no accessible log of pak-mount events in this game — `UE4SS.log` doesn't cover engine-level
  content mounting, and no client-side `Saved/Logs` directory with mount-relevant detail was found
  (only a dedicated-server-build log path existed). Confirming a content override actually took
  is a VISUAL check in-game, not a log-grep.
- **Two benign UE4SS log patterns, easy to mistake for real errors:**
  - Lines like `FArchiveState::ArIsError = 0x29` are UE4SS's own SDK struct-OFFSET dump (byte
    offsets within a struct, printed once during startup/hook generation) — not a runtime error
    report, despite the field name.
  - `Error: A custom console command handle must return true or false` fires as a side effect of
    invoking a `RegisterConsoleCommandHandler`-registered command (confirmed on two unrelated
    custom commands) — it's noise tied to how this UE4SS build's console-command return value is
    checked, not a sign the command itself failed.
- **Extracting/inspecting what's actually inside a cooked pak needs a real tool (e.g. FModel), not
  a hex/string scan** — unlike the plaintext-fragment scanning technique in §9 (which only surfaces
  asset NAMES, not usable content). A tool built for IoStore/UAsset formats can export a texture as
  a plain image, or a mesh as a raw `.uasset`.
- **Whether an extracted `.uasset` is usable depends entirely on WHICH export mode produced it —
  this is not automatic, and easy to get wrong (refined 2026-08-15).** A tool like FModel offers
  several distinct export paths: format-CONVERTED exports (texture → `.png`, mesh → `.glb`/`.psk`,
  etc.) are for viewing/reference only, never game-loadable. A RAW/"Save Package" export instead
  preserves the actual COOKED bytes byte-for-byte, exactly as shipped inside the pak — genuinely
  the same format the game itself reads. `UnrealPak.exe -Extract` (Epic's own official pak tool)
  or `repak` (a common open-source reimplementation) both do the equivalent of the raw path by
  design — there's no ambiguity with those, since unpacking an archive can't convert format. A
  cooked package is also usually split across companion files (`.uasset` = metadata, `.uexp` = the
  actual data, `.ubulk` too for texture/mesh bulk data) — ALL of them need to travel together to
  the same destination folder with matching names; a lone `.uasset` with no `.uexp` may be an
  incomplete extraction even from a correctly-raw export.
- **Loose files (dropped directly into `Content/`, no pak) MAY OR MAY NOT be honored — this is a
  per-build packaging setting, not something true of UE games in general.** Most commercial
  Shipping builds disable loose-file fallback; some don't. Confirming a shipped commercial build
  supports it (or doesn't) requires a live test, not an assumption either way — and note the pak-
  auto-discovery pitfall directly below can easily contaminate that exact test.
- **Disabling a pak means moving it FULLY OUTSIDE the `R5/Content/Paks/` tree — renaming or
  relocating it to a sibling subfolder WITHIN that tree does not disable it.** Pak discovery is
  RECURSIVE under `Paks/` (already noted above) — a folder named `..._disabled` or `..._backup`
  still sitting anywhere under `Paks/` is still auto-mounted regardless of its name. This
  invalidated an entire A/B test before the bug was caught: a body-mesh replacement that appeared
  to work was actually still being rendered by the "disabled" original pak the whole time, not the
  new content being tested. Move a pak-under-test's backup to a folder genuinely outside
  `R5/Content/` entirely (or at minimum outside the `Paks/` subtree) to get a clean disable — never
  trust a same-directory rename for this.
- **A mesh that attaches and animates correctly is not the same as one that FITS visually.** Two
  meshes sharing a skeleton (so a clothing/garment piece skins and animates correctly on a body)
  can still visibly clip or show a seam/gap where they meet if the BODY mesh's geometry changes
  shape at that seam — a garment piece is typically fitted with clearance for one specific body
  shape, not skeleton-compatibility alone. Confirmed live: an underwear/garment mesh that
  correctly covered a gap on the original body visibly clipped/gapped at the same seam once the
  body mesh underneath was replaced with a different (though skeleton-compatible) one. Swapping a
  body mesh can require re-checking every garment piece that sits close against it, not just
  confirming the new body mesh itself looks right in isolation.
- **A single-file `.uasset` swap (no `.uexp` companion) was NOT sufficient to fix a body-mesh
  clipping problem, once the pak-auto-discovery bug above was corrected for a genuinely clean
  test.** Result was indistinguishable from not replacing the mesh at all. Left genuinely
  unresolved which factor mattered — missing `.uexp`/bulk-data companions, loose-file loading not
  being supported by this build at all, or the source meshes themselves not actually differing in
  the way that was hoped. Recorded as a negative result, not a proof that loose-file replacement
  can never work here — a properly complete cooked-package export (all companion files present)
  would be the next thing to try before concluding the mechanism itself is the blocker.
- **Diagnosing "a pak won't open in FModel/UModel" — rule out causes in order, don't guess.**
  (1) Check the header is structurally valid first: correct IoStore magic (`-==--==--==--==-`,
  16 bytes) and a header size matching the known `FIoStoreTocHeader` size (0x90/144 bytes in this
  engine version) — if that's wrong, the file itself is genuinely corrupt/truncated. (2) Check
  whether it's actually encrypted (the tool will usually say so directly) before assuming
  encryption — an earlier guess that a failure was AES-related here was wrong, and cost a
  detour before being corrected against real tool output. (3) A "global container not found"
  error means the extraction tool needs `global.utoc`/`global.ucas` (the base game's shared
  IoStore container — holds the name/script-object map every individual pak's TOC references)
  present in the SAME directory as the pak being scanned; point the tool at the game's real
  content-paks folder directly, not a standalone copy of just the one pak. **Pointing an
  extraction tool at the whole game root instead of the specific content-paks folder can walk it
  into a mod-loader's OWN separate pak folder** (this game's Lua modding framework keeps its own
  `.../Mods/Content/Paks/` tree for hot-reloadable content mods, entirely separate from the base
  game's real asset paks) and cause it to fail trying to resolve a global container against pak
  files found THERE instead of the real one — confusing, but not actually a sign anything is
  broken, just a wrong scan root. (4) A parse failure deep inside the directory-index
  deserialization (e.g. "string not null terminated"), especially one that fails on very nearly
  the LAST entry in an otherwise-successful read (161 of 162, not entry 3 of 162), is a real
  signature worth recognizing: **a common, simple anti-extraction technique is to deliberately
  corrupt just the human-readable directory index** (which generic browsing tools need to build a
  file tree) while leaving the actual chunk data intact, since the game's own loader resolves
  assets by chunk ID at runtime and may never need that index to be valid at all. Failing almost
  at the very end of an otherwise-clean parse is a meaningfully different signal than failing
  immediately — treat it as likely-intentional, not likely-corrupt, and don't expect a different
  tool or a re-download to fix it.
