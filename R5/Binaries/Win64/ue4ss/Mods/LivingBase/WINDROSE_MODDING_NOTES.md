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

### 2c. A SECOND struct shape exists — and it's the one that finally unlocked writable per-piece customization (2026-08-19)

The `"ScriptStruct /Script/Module.Type"` shape §10/2b already document (extract the path,
`StaticFindObject` it, `:ForEachProperty` the resolved type) is not the only one. A struct
returned from inside a `TArray` element — confirmed on `R5SelectableCompositeMeshController` and
on a nested `FGameplayTag` field one level inside it — instead prints as `"UScriptStruct: <hex
address>"`, with no module/type path in the string at all. `GetClass()` on it is a dead end too
(returns a generic `"ScriptStruct"` placeholder object with 0 declared properties — not the
specific type). **The fix for THIS shape is simpler than §10's, not the same recipe reapplied**:
the value itself directly supports `:GetFName():ToString()` (gives the real type name, e.g.
`R5SelectableCompositeMeshController`, `GameplayTag`) and `:ForEachProperty(...)` called directly
on it (no separate `StaticFindObject` round-trip needed at all) — bracket-index that SAME value
for each field name found, same as always. Check which shape you've got by pattern-matching the
raw `tostring()` output before picking a recipe; guessing wrong just wastes a round-trip, doesn't
crash anything.

**Payoff, confirmed live across 6 actor types** (a composite mob, a baked Standing statue, two
Tortuga male NPCs, the Herbalist, the Gatherer): `R5CompositeMeshComponent:
GetCustomizationMeshControllers()` returns one `R5SelectableCompositeMeshController` per
customizable body-part slot — `MeshGroupIndex` (int), `CurValue`/`MaxValue` (the current pick and
how many options exist, 0-based), `bSelectionAllowed` (bool), and `GroupCategoryId` (an
`FGameplayTag` naming the slot, e.g. `Customization.UID.Hairs`, `Customization.UID.Armor.Legs`).
**`SetCustomizationMeshControllerValue(ctrl, newValue)` genuinely works** — confirmed live,
changed a Gatherer's `Hairs` controller from `2` to `3`, visually confirmed changed in-game, no
crash. This is a real, independent, per-slot customization path — nothing to do with the
`params`/composite-DataAsset-swap or component-name-`replaces` mechanisms every reskin in this
codebase has used until now, and it answers "can we get more variety than the color/sex/preset
knobs already expose" with a genuine yes, not another dead end.

What's inconsistent across actors, from the same live sample: `Hairs` was present AND selectable
on every single actor tested — the safe universal target. `Armor.*` slots exist with real option
counts on female actors too, but `bSelectionAllowed=false` locks every one of them there while the
same slots are fully open on male actors tested. `Facial.Eyebrows` was locked on both female base
walker bodies (Herbalist, Gatherer) despite `Facial.Mustache`/`Beard`/`Whiskers` on those same
actors being marked selectable despite having 0 options — an inconsistency worth expecting, not
assuming away, before building a feature on top of any one slot.

**A related dead end, same investigation**: `SwapBodySex` (sitting right next to the already-used
`SetCharacterSex`/`SetBody` in this component's function list, found via the technique in §2)
looked like a plausible way to bypass `IsBodySexChangeAvailable()==false`. Confirmed live it is
NOT a bypass — it runs with no error, but silently no-ops (`GetBodySex()` unchanged before/after)
exactly when the availability check would have refused. The gate is enforced natively inside the
function itself, not just a convention the existing `SetCharacterSex`-based code chose to respect.

**`SetCharacterSex` rebuilds the mesh controller list, wiping picks either side of the call — not
just a stale-value issue.** Confirmed live on `BP_NPC_Citizen_Walker`, round-tripped male → female
→ male: the controller SET partially collapses on the female side (11 controllers → 2, the other 9
categories not just zeroed but absent from the list entirely) and, more importantly, swapping back
to male restores the full 11-category shape (same categories, same option counts as before) but
resets every single `CurValue` to `0` — none of the original picks survive, even ones set BEFORE
the sex change (confirmed: setting a value pre-swap does not protect it, the swap wipes it anyway
on its way through). **The only order that actually works: change sex FIRST, THEN set values** — a
plain `SetCustomizationMeshControllerValue` call made AFTER the swap has already settled sticks
completely normally (confirmed live again). Don't bother trying to preserve a look across a sex
change; re-apply it after, not before.

### 2d. `BuildedCompositeMeshes` — a second, always-populated mesh-attachment layer (2026-08-19)

**Why an actor can render visible clothes despite having ZERO `Armor.*` customization controllers**
(the Gatherer/Herbalist walker bodies both do this): the mesh-controllers list in §2c
(`GetCustomizationMeshControllers()`) is a *pick list* — which option is currently selected per
slot — not the thing actually attached to the skeleton. The real attachment array is a separate
component property, `comp.BuildedCompositeMeshes`, and it's populated independent of whether that
slot has any selectable controller at all. A class with 0 Armor controllers can still have 5+
`BuildedCompositeMeshes` entries wearing a full outfit; the controller list only governs slots the
game exposes as player-changeable, not everything actually rendered.

Each entry is an `R5EquippedSlotData` struct (`GetFullName()` → `"ScriptStruct
/Script/R5.R5EquippedSlotData"`, the *named*-struct shape from §10/2b — resolve via
`StaticFindObject` + `:ForEachProperty`, not §2c's inline-`:GetFName()` shape; check which shape
you've got before picking a recipe, same caveat as 2c). Key fields: `BodyPart` (an
`ER5BLCompositeMeshBodyPartType_V0_8_0` enum value — decoded from `UE4SS_ObjectDump.txt`, e.g.
`13` = Legs) and `EquippedMesh` (the live `SkeletalMeshComponent` actually attached for that slot —
a real component, not an asset reference, so it takes the same `SetSkeletalMeshAsset`/
`SetSkeletalMesh` calls any other mesh component does).

**Confirmed dead, two independent tests, two call orderings**: mutating a `BuildedCompositeMeshes`
entry (or its `EquippedMesh`) AFTER the composite has already built does not stick — same
"reports success, rebuild count increments, rendered mesh never changes" signature as §2a's
property-write dead end. **Confirmed working**: setting the composite's PRE-build params
(`DefaultParams`/`ArchetypePreset`) so a *different class's* outfit/body bakes in at build time —
this is the mechanism the walking-women outfit rebuild (Letty/Marita/Merchant, v2.1.7) actually
ships on. Post-build mutation of the array itself is dead; pre-build substitution of what gets
built is not.

**`Spawner.SetBodyPartMesh(actor, bodyPart, meshPath, say)`** (`spawner.lua`) is the general tool
this unlocked: given a `BodyPart` enum value, it walks `BuildedCompositeMeshes` for the matching
entry and swaps that ONE slot's `EquippedMesh` — hide → `SetSkeletalMeshAsset` (fallback
`SetSkeletalMesh`) → `SetLeaderPoseComponent` rebind to the actor's own `Mesh` → show. Reuses the
exact sequence `Spawner.DeCorrupt`'s content-name-matched `replaces` rule already proved safe, just
addressed by `BodyPart` enum instead of guessing a live component's current mesh name — useful when
a cross-class `DefaultParams` swap (the pre-build fix above) bakes in one body-shape-mismatched
piece from the donor class (this fixed the Merchant walking-woman's leg-clipping: her real outfit's
Legs piece was built for a different base skeleton than the Walker pawn wears).

**CDO route confirmed dead for pawn classes, works for buildable-actor classes.** §7 already
confirmed a buildable trader's Class Default Object (`Default__<ClassName>`, same trick used
elsewhere in this file) owns a real, populated `R5CompositeMeshComponent` — readable with zero
`SpawnActor` cost. Tested this session whether that generalizes to actual pawn classes (Letty,
Marita, walker bodies, etc.): it does not. A pawn class's CDO resolves fine and has a valid
`CompositeMeshComponent`, but `GetCustomizationMeshControllers()` on it reads back empty —
confirming pawns build their composite at spawn time (an explicit runtime `SetCompositeParams`/
build call, §9) rather than having it pre-populated on the class default like a buildable actor
does. Surveying a pawn roster's customization options without paying a live-spawn cost isn't
possible via this route; `Spawner.ProbeClassCustomization` (the `lbprobeclass` command) exists to
make that distinction quickly, but still needs a live actor for any pawn class.

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

### 3g. `RegisterKeyBind` is only safe during the initial mod-load pass
Calling `RegisterKeyBind` again LATER — e.g. from a runtime poll loop, to apply a remapped key
live without a restart — reliably crashes the game itself
(`EXCEPTION_ACCESS_VIOLATION` inside the game's own executable, confirmed via crash dump — not a
Lua error, not something `pcall` can catch). The exact same remap works fine (just doesn't take
effect until a restart) when the call happens only once, synchronously, during the mod's initial
load. Bind every key exactly once at startup; treat a "live keybind rebind" feature as needing a
full game restart to apply, not a runtime `RegisterKeyBind` call.

### 3h. A function existing in the object dump doesn't mean it's safe to call (2026-08-15)
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

### 3i. `SetActorLocation`/`SetActorRotation` on a Static-mobility component silently no-ops visually (2026-08-16)
A runtime transform call **succeeds** (returns fine, the actor's own logged position updates
correctly) but the RENDERED MESH stays exactly where it was — because the component's mobility is
still `Static`, and Static components don't get re-evaluated by the render thread after their
initial placement. The transform is genuinely correct in game state; only the on-screen mesh is
stale. Symptom that gives this away: walking away and back (forcing the actor to stream out/in)
"fixes" it, because streaming rebuilds the render proxy from scratch. Fix: call the engine's own
`SetMobility(Movable)` equivalent on the component ONCE before the first runtime move — once
Movable, every subsequent `SetActorLocation`/`SetActorRotation` updates the render thread every
frame, no special handling needed after that.

### 3j. A function "safe" at keyboard-driven call rates isn't necessarily safe at UI-driven rates (2026-08-16)
A visibility-toggle hack (`SetActorHiddenInGame(true)` immediately followed by `(false)`, meant to
force the render thread to re-register an actor's state) had been living in a live-edit/"nudge"
function for a long time with zero problems — because it only ever fired at the rate a human
holding a keyboard key produces — and this UE4SS build silently drops most keydown-repeat events
for a held key (confirmed by comparing accumulated-offset logs to actual press count elsewhere in
this codebase), so the *effective* call rate from even an actively-held key has always been much
lower than the key's nominal OS repeat rate.
Wiring the SAME function to a UI element with a real, undropped repeat rate (a held button/key in
a separate ImGui window, ~10 calls/sec sustained) crashed the engine natively within seconds, with
**nothing trapped in the log** — same "uncatchable, no trace" signature as 3h above. **Isolated by
a controlled A/B test, not by guessing**: throttling the call RATE alone (down to ~2 calls/sec)
did NOT stop the crash; disabling just the suspect call (`SetActorHiddenInGame`) — while leaving
the rate LESS throttled (~4-10 calls/sec) — DID. This confirmed the specific call was the actual
cause, not raw frequency; a plausible-looking cost center found first (in this case, a same-function
full-file read/rewrite for persistence) turned out to be a real but much smaller concern, not the
crash. **Lesson**: before wiring any UI element with a natural high, undropped repeat rate to an
existing function, audit everything that function does per call — a component/render-state mutation
that was fine at human-keypress frequency is not proven fine at 10x that, sustained, and the way to
find out which specific line is the problem is to disable/throttle candidates ONE AT A TIME and
retest, not to fix the first plausible-looking cost and declare victory.

### 3k. A function defined BEFORE a `local function` it calls silently binds to a global instead (2026-08-18)
A console command (`lbsexchange`) broke completely — every call failed with `attempt to call a nil
value (global 'findNearestSpawnInFront')` — despite `findNearestSpawnInFront` genuinely existing as
a `local function` elsewhere in the exact same file, and despite half a dozen OTHER callers in that
same file working fine. Root cause: Lua's `local` scoping is purely LEXICAL (by source position),
not by call-time order. A `local function foo()` statement creates the local binding at THAT POINT
in the file; any code textually written ABOVE that line — even a function that only ever executes
much later, long after the whole file has loaded — permanently resolves a bare reference to `foo`
as a GLOBAL instead, because at the moment the Lua compiler parsed that earlier code, no local
named `foo` existed yet in scope. This has nothing to do with when either function is actually
CALLED at runtime; it's fixed forever at compile/parse time by source position alone. The broken
caller here had been added near a thematically-related function earlier in the file, textually
before the shared helper it depended on (which had been relocated further down during unrelated
work) — an easy mistake to make since nothing about "add this function near its similar siblings"
suggests checking what's declared `local` below it. **Fix**: move the caller to any point in the
file after the `local function` declaration it depends on (or forward-declare the local at the top
of the file and assign it later, if ordering can't be controlled). **Diagnostic signature**: the
error names the dependency as a "global" even though you know it's declared `local` somewhere in
the same file — that mismatch (local declared, but Lua calls it a nil global) is the tell; grep the
file for two things — where the bare name is called, and where its `local function`/`local X =`
declaration actually sits — before assuming the function itself is broken or missing.

### 3l. INVOKING an unfamiliar UFunction is real crash risk, even when it looks simple (2026-08-21)
Two DIFFERENT native calls hard-crashed the game the first time each was actually invoked, in the
same session, both with **zero pcall-catchable warning**:
- `UNiagaraFunctionLibrary::SpawnSystemAttached` (10 args, a struct/enum-heavy spawn-and-attach
  call) — crashed on the first attempt where the argument COUNT was finally correct.
- `PrimitiveComponent::GetCustomPrimitiveDataIndexForVectorParameter` — a trivially simple
  single-`FName`-argument QUERY function, no structs, no enums, nothing that looked risky on paper.
  Crashed on the very first candidate name tried.

Both are genuine, real UFUNCTIONs, both resolve fine via reflection, both have obviously-correct
argument shapes. Neither warning sign ("this call has a lot of args," "this is a mutating call")
predicted the second crash. **Reflection is safe; invocation is not, and structural complexity is
not a reliable predictor of which calls will crash.** `ForEachProperty`/`ForEachFunction` (reading a
class's declared properties/functions, or a specific UFunction's own parameter list) has been 100%
safe every time across many sessions — it never actually calls anything. The moment you cross from
"reflecting on a function" to "invoking it," treat ANY function this codebase hasn't already called
successfully before as a real crash risk, save first (or accept the game may need a hard restart),
and don't let "it's just one float argument" talk you out of that caution.

### 3m. A UFunction's OWN Lua return value can be meaningless — check pcall's success, not the function's return (2026-08-21)
`GetActorBounds(bOnlyCollidingComponents, Origin, BoxExtent, bIncludeFromChildActors)` only
communicates its result through the `Origin`/`BoxExtent` OUT-PARAMS (pre-allocated empty Lua tables
passed in, populated by the call) — it has no meaningful Lua return value of its own. Code that did
`local ok = actor:GetActorBounds(false, origin, extent, false)` and then checked `if ok and
origin.X...` silently never entered that branch for ANYONE, on ANY actor, for the entire time it
shipped — `ok` was always `nil`/falsy, because there was nothing there to assign. The correct
pattern (already used elsewhere in this codebase, just not copied correctly this one time): wrap the
call in `pcall` and use PCALL's OWN true/false as the success flag —
`local ok = pcall(function() actor:GetActorBounds(false, origin, extent, false) end)` — then read
`origin`/`extent` afterward. **Any function whose real output lives in Out-params, not its return
value, needs this exact pattern; capturing `= obj:Func(...)` directly and checking THAT for
truthiness will silently do nothing, forever, with no error to notice.**

### 3n. `LineTraceSingle`'s channel argument is a DIFFERENT enum than `SetCollisionResponseToChannel`'s (2026-08-21)
`LineTraceSingle`'s trace-channel parameter is `ETraceTypeQuery` (a Blueprint-only enum built from
Project Settings → Collision → Trace Channels), NOT the raw `ECollisionChannel` enum
`SetCollisionResponseToChannel` takes — they are two separate numbering systems that happen to
overlap in low integers, which is exactly what makes a wrong guess look plausible. By Unreal's own
default project settings (confirmed live in this game), `ETraceTypeQuery` index 0 ("Visibility")
maps to raw `ECollisionChannel` index **3**, not 0. Three progressively-more-specific wrong guesses
(assuming raw channel 2 = "Pawn," then raw channel 0, then a channel-numbering mismatch theory that
turned out right in principle but was chasing the wrong root cause) all failed to change behavior AT
ALL before landing on the real fix — which, in hindsight, was ALSO gated behind a separate
`RemoteUnrealParam`-unwrap bug (§2b) silently no-op'ing every collision-response call regardless of
which channel number was used. **Lesson inside the lesson**: when several independently-reasoned
guesses all produce ZERO observable change (not "wrong value," but "nothing happened"), suspect the
write itself is silently no-op'ing (wrapper unwrap, wrong object, etc.) before spending more guesses
on the value.

### 3o. Comparing two independently-fetched actor/object handles with `==` is unreliable, even for the identical underlying object (recurring)
UE4SS Lua handles are wrapper objects, not the raw pointer — two SEPARATE calls that both resolve to
the SAME underlying engine object (e.g. a raycast hit's owner vs. a tracked ledger's own stored
actor reference) can still read as unequal under plain `==`, confirmed live more than once. Never
compare "is this the same actor" via two independently-fetched handles; either (a) always store and
re-use the SAME single fetched handle for later comparison (safe — this is same-handle identity, not
cross-fetch), or (b) compare a derived STABLE key instead (e.g. the actor's own instance path string
from `GetFullName()`/`GetPathName()`). Bit real features twice: a "is this the actor I'm already
tracking" check that read false on every tick despite visibly aiming at the same object the whole
time, and an "is this one of ours" ledger lookup that needed the same fix.

### 3p. A property write can succeed with zero pcall error yet have no lasting (or any) visible effect, if a native settings/params system re-asserts it (2026-08-22)
Distinct from 3i (a Static-mobility component silently not re-rendering) — this is a write that
genuinely takes effect internally, confirmed because a DIFFERENT probe read it back changed, but the
RENDERED result either never changes at all or eases back to some other value within about a second.
Symptom of a native "desired value" system running downstream of the property you're writing (a
camera modifier, a settings-driven params object, a per-frame recalculation) that keeps overwriting
your one-time write on its own schedule. Fighting it by re-writing every poll tick can make it WORSE
(visible pulsing, if your poll rate doesn't match the native system's own tick rate) rather than
better. The real fix is finding and disabling whatever REFERENCES the params/settings object first —
e.g. a camera component with `bUseSettingsFov`/`CameraParams` fields: setting `bUseSettingsFov =
false` and `CameraParams = nil` BEFORE writing `FieldOfView` stopped it from being blended back,
where writing `FieldOfView` alone (however many times) never stuck. **When a plain property write
reports success but the screen doesn't agree, don't conclude the property is wrong — look for a
sibling boolean/object field that opts the component OUT of whatever system keeps re-asserting it.**
A reference mod for the same game (even an old, otherwise-outdated script version) can be the
fastest way to find that specific detach mechanism, faster than reflecting blind.

### 3q. How UE4SS actually counts arguments for a raw UFunction call with a return value (2026-08-21)
Calling an arbitrary UFunction directly (`obj:SomeFunction(arg1, arg2, ...)`, not a `K2_`-prefixed
convenience wrapper) throws `"UFunction expected N parameters, received M"` if the count is off —
but N is NOT simply "however many parameters the function reflects." Confirmed by reading UE4SS's
own bundled C++ source (`UE4SS/src/LuaType/LuaUObject.cpp`, `LuaUObject::call_ufunction_from_lua`):
the function's total declared property count (`GetNumParms()`, which `ForEachProperty` on the
UFunction object will also enumerate) INCLUDES the return value as one of those properties when the
function has one — but `N` (what UE4SS actually expects you to SUPPLY) is that total **minus 1** in
that case, since the return value isn't something you pass in. Concretely: a function reflecting 11
total properties (10 real input params + 1 `ReturnValue`) expects exactly **10** supplied
arguments, not 11 and not 9. Getting the return-adjustment wrong in either direction produces the
exact same generic error message regardless of which count was actually wrong, so trust the formula
(`declared properties, minus 1 if `GetReturnValueOffset()` isn't `0xFFFF``) over trial-and-error —
and note a genuine RETURN value does NOT need (and, confirmed live, actively breaks the count if you
add) an extra placeholder Out-param table the way a true Blueprint OUT parameter would (see 3m for
that different, Out-param case) — the plain Lua return of the call already carries it.

---

## 4. Restore-on-load design (why it looks the way it does)

- `RegisterInitGameStatePostHook` fires **several times per load** (menu, then ~3x). Use
  **latest-fire-wins generation counter**, NOT a lock. A lock let the MENU's chain swallow the real
  world-load fire, then time out silently → nothing ever restored.
- Wait for player pawn (`R5Character`), then wait for the player to **move** → world is live.
- Split the save: **statues** (`AnimatedActor` / `QuestStatic`, no AI — fast) vs **movers** (each
  wakes an AI — pace them). Only movers get post-processing.
- **Decor-class actors NEVER reach `RestoreHook`/`postList`/`RESTORE_RULES`, by design, not
  oversight (2026-08-19).** Decor is spawned as part of the statics batch above with `collect=false`
  — a deliberate perf optimization (no reason to track/post-process a static prop the way a mover
  needs), but the consequence is that `RestoreHook`/`Spawner.restoreHook` and any `RESTORE_RULES`
  entry keyed to a decor class is dead code that will never fire, no matter how correct its match
  condition is (confirmed the hard way: a syntactically-correct `RESTORE_RULES` entry for restoring
  Drops-decor mesh overrides matched the persisted data perfectly and simply never ran). **Any fixup
  a decor actor needs on restore has to live inline in `restoreOne` itself**, alongside the other
  immediate-apply decor corrections (`SetDecorSolid`/`MakeMovable`/pitch-roll), not in the
  deferred/hook-based path movers use.
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
- **The game's actual process name is `Windrose-Win64-Shipping.exe`, NOT `R5-Win64-Shipping.exe`**
  (2026-08-18) -- confirmed via `MenuStatus.cpp`'s own logged "game executable" path and cross-
  checked live with `tasklist`. `R5` is the internal PROJECT/folder name (`R5/Binaries/Win64/...`,
  every path in this codebase), which makes it an easy, silent wrong guess for the process name
  specifically -- a `tasklist //FI "IMAGENAME eq R5-Win64-Shipping.exe"` check ALWAYS reports "no
  tasks found," even while the game is genuinely running, with no error to flag the mistake. This
  cost real deploy attempts this session (a DLL copy silently would have needed the correct check
  to know to wait) before being caught. A closed-game check that never once reports the game as
  running, across many real play sessions, is itself the tell that the process name is wrong --
  worth a live `tasklist` (no filter) spot-check for the real name if that pattern ever repeats
  with a different game.
- **To confirm a class path is a genuine vanilla Windrose asset (not something a mod added), check
  `class_index.lua`.** It's generated straight from the game's own `Manifest_UFSFiles_Win64.txt`
  (every `R5/Content/**/BP_*.uasset` entry) -- if the short name resolves there, it's a stock asset
  by construction, not a guess from the path shape alone. Used this way 2026-08-18 to confirm
  `BP_Shared_Camp_PropsComposition_70` (formerly repurposed as this mod's own raid-flag prop) is
  just another entry in the same vanilla numbered prop family as several already-cataloged
  furniture pieces (…67, 69, **70**, 71, 72…), not mod-created content.
- **Fully removing a feature (vs. just disabling it) in this codebase means finding every one of
  its wiring points, not just its implementation.** Confirmed 2026-08-18 removing the Blackbeard
  raid + `PROTECT_STRUCTURES`: a feature toggle here is typically wired through *(1)* a
  `Config.X` default in `config.lua` (+ matching line in `config.txt` if user-facing), *(2)* the
  actual implementation functions (`spawner.lua`/a dedicated module like the old `bbraid.lua`),
  *(3)* init-time wiring/registration in `main.lua`, *(4)* a keybind entry in `fkeys.lua` if it has
  one, and *(5)* a `modsettings.lua` `TOGGLE_DEFS`/`KEYBIND_DEFS` entry if it's player-toggleable.
  Docs need the same sweep: a removed feature can be described in as many as three separate
  places per doc -- a top-of-file summary blurb, its own dedicated feature-heading section further
  down, AND a `config.txt` toggle-list mention -- so grep the whole doc set for the feature's name
  rather than trusting the first mention found.

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

### 9c. Mechanically discovering EVERY asset of a kind: a folder-shape assumption is never provably exhaustive (2026-08-17/18)
A mechanical scan for "every drop-mesh in the game" assumed the assets all lived under exactly two
known folder prefixes (confirmed by 4 hand-probed items landing in exactly those two trees) and
built a 148-entry roster from grepping `UE4SS_ObjectDump.txt` for `StaticMesh` under just those two
paths. Revisiting it later with a DIFFERENT search strategy — grepping the whole dump for a
FILENAME pattern (`SM_Drop_*`) instead of trusting the folder shape — immediately found real items
the folder-based scan had structurally no way to catch: one drop mesh that sits one folder deeper
than its siblings AND skips the literal `Drop` folder segment entirely (still passes the filename
test), and a WHOLE THIRD asset prefix (`Character/Skeletal_Meshes/Armor/ArmorRegular/<Set>/Meshes/
Drops/`, 17 armor-piece drops) the original two-prefix search had no reason to ever look at.
**Lesson: a folder-shape assumption that explained every item found so far is not proof the
assumption is exhaustive** — it only proves it fit whatever you already found by hand. A
filename/naming-CONVENTION grep across the entire dump (not scoped to assumed folders) is a
meaningfully different, complementary search that catches structural outliers a path-based scan
categorically cannot, and is worth re-running whenever "did we get everything" matters, not just
once at the start.

Separately: an item that's real, confirmed to exist in the game, and even visible in a player's
inventory can still be COMPLETELY ABSENT from an object dump. `R5LootActor` (the native class every
world-dropped item uses) only gets a real `MeshComponent` populated at the moment something is
actually dropped/discarded as a physical actor in the world — an item still sitting in an unopened
container's own inventory list, or merely held in the player's inventory, is not a spawned actor at
all, so nothing forces its static mesh to load into memory, so it can never appear in a
`DumpAllObjects()`-style snapshot taken at that moment. Two practical consequences: (1) a single
object-dump snapshot systematically UNDER-counts relative to "everything that could exist" — it can
only ever reflect what's been dropped in front of the player (or otherwise rendered) at least once
before the dump was taken, not the full catalog of possible items; re-running the dump after more
exploration reliably finds MORE, even against the exact same folder prefixes already scanned.
(2) For confirming ONE specific known item's exact mesh path on demand (rather than a full sweep),
reading a real dropped instance's `MeshComponent:GetStaticMesh()` directly (a live probe, not a
dump grep) works regardless of whether that asset happened to be loaded when the last full dump ran
— the two techniques are complementary, not interchangeable: dump-grep for a broad sweep, live probe
for confirming one specific item you can currently see.

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
  **CORRECTION, confirmed live later: this does NOT extend to compiled AnimGraph execution
  structs (`FAnimNode_*`/`AnimGraphNode_*`).** Every struct this recipe was proven safe against
  (a per-world save identifier, a body-shape morph vector, a single-node animation-playback
  struct) is genuine DATA — a value that sits still until something explicitly changes it. An
  `AnimNode_*` struct is different in kind: a live execution node inside a compiled graph,
  rebuilt every frame by the animation runtime, not a plain value holder. Attempting the exact
  same three-step recipe on a property whose resolved type matched `AnimNode_`/`AnimGraphNode`
  crashed the game natively, with zero catchable output — the same pcall-uncatchable signature
  documented elsewhere in this file for other confirmed-fatal calls. The general claim above still
  holds for genuine data structs; it does not hold for compiled execution-graph nodes, and that
  distinction — data struct vs. runtime execution node — is the one to check before assuming this
  recipe is safe to reuse on a new, unfamiliar struct type.

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

---

## 12. Compiled C++ UE4SS mods (not Lua): rendering an interactive overlay safely (2026-08-16)

Built while adding a second, compiled C++ companion mod (a category-tree spawn menu) alongside
this project's Lua mod. Two other closed-source mods in this ecosystem prove real, fully
interactive, mouse/keyboard-capable overlay windows ARE achievable in this game — this section
is what it actually took to get there without crashing.

### 12a. A relative path resolves against the GAME's working directory, in C++ too
Same trap as Lua's `io.open` (nothing about this is Lua-specific): a bare relative path/filename
opened from a C++ mod's DLL resolves against the game process's actual CWD
(`R5/Binaries/Win64/`), NOT the mod's own folder, NOT the calling DLL's location. Confirmed live
— a first attempt at a mod-to-mod file bridge landed its output file one level too high before
this was caught. Prefix every path explicitly from the known process root (e.g.
`"ue4ss/Mods/<YourModName>/..."`) rather than trusting a bare filename, on both sides of any
cross-mod or cross-language file bridge.

### 12b. Hooking a DXGI/D3D vtable function: `x64Detour`, never a raw vtable swap
A raw vtable-pointer swap hook (swapping the function pointer directly in the vtable, e.g.
PolyHook2's `VFuncSwapHook`) on `IDXGISwapChain::Present` causes **infinite recursion with
Steam's own overlay hook** (`gameoverlayrenderer64.dll`) — confirmed via a live debugger catch
showing a stack overflow inside Steam's own overlay hook function. Steam's overlay ALSO hooks
`Present`, and the two raw-swap approaches step on each other. An inline/trampoline-style detour
(PolyHook2's `x64Detour`, or equivalent) composes correctly with other hookers (Steam's overlay
included) and does not have this problem. If a DXGI/D3D function needs hooking at all, use a
trampoline detour, not a vtable swap.

### 12c. Capture the REAL command queue by hooking swapchain creation, not by guessing
For D3D12 specifically, the officially-documented way to get the exact `ID3D12CommandQueue*`
paired with a given swapchain is to hook `IDXGIFactory2::CreateSwapChainForHwnd` (vtable index
15) — for D3D12, its `pDevice` parameter IS the command queue pointer, by the API's own contract.
A heuristic guess instead ("the first DIRECT-type queue seen via `ExecuteCommandLists`") captured
the WRONG queue and caused an unrecoverable hang (the game had to be force-closed — not a clean
crash, a deadlock). Don't guess; hook the creation call. Separately: any fence/event wait tied to
frame presentation should use a bounded timeout, never `INFINITE` — a wrong or stale queue/fence
pairing turns an `INFINITE` wait into a permanent hang instead of a recoverable skipped frame.

### 12d. This game's DLSS-G (NVIDIA Streamline) frame generation breaks a naive swapchain-Present
overlay
Windrose has NVIDIA Streamline's DLSS Frame Generation active, which wraps/proxies the real
swapchain (`FStreamlineD3D12DXGISwapchainProvider`). A hook that writes ImGui draw data directly
onto the raw back buffer via the captured `Present`/command-queue — even with the correct queue
(12c) and a safe hook style (12b) — still produced genuine GPU device removal
(`DXGI_ERROR_DEVICE_REMOVED`), confirmed via live debugging across multiple iterations, including
one run where disabling Streamline's swapchain-provider wrapping (`-slnoswapchainprovider`)
changed the crash's failure signature but did not eliminate it. Root cause not fully closed out —
last theory was a deeper Streamline-side hook or interaction, not simply "wrong buffer state."
Streamline does document its own official overlay integration point (`kFeatureImGUI`) meant to
coexist with Frame Generation, but it isn't bundled in this game and wasn't pursued this round.
**Practical takeaway: don't build a raw Present/back-buffer overlay for a game running DLSS-G (or
likely FSR/AMD frame interpolation, also present here) without first confirming the engine's own
supported overlay-injection path — assume a naive approach will eventually device-remove.**

### 12e. A standalone window on its own thread is a safe, working alternative to hooking Present
Instead of drawing into the game's own swapchain, create an entirely separate OS window
(`CreateWindowW`) with its own D3D11 device/swapchain and its own independent ImGui context —
running on its own `std::thread`, with its own Win32 message pump. This has zero interaction
with the game's D3D12 rendering pipeline or Streamline's swapchain wrapping, since it never
touches either. Confirmed safe and fully interactive via live testing — no crashes, real
mouse/keyboard input, movable/resizable. Tradeoff: it's a genuinely separate window (alt-tab
target, own taskbar entry), not an in-game overlay drawn over the 3D view — for a
control-panel-style tool (as opposed to a HUD/reticle-style overlay) this is a fully acceptable,
much lower-risk trade. `WM_CLOSE` should hide the window (`ShowWindow(..., SW_HIDE)`) rather than
destroy it, if the intent is a toggleable panel rather than a one-shot dialog.

### 12g. `GImGui` is a single global — two ImGui contexts/threads in one DLL is not safe by default
Adding a SECOND standalone window (own thread, own D3D11 device, own ImGui context — the pattern
12e calls "confirmed safe") alongside an already-working first one does **not** inherit that
safety automatically. Dear ImGui's current-context pointer (`GImGui`) is a single **global**
variable, not thread-local, shared across the whole process no matter how many independent
`ImGui::CreateContext()` calls exist. Two threads each calling `ImGui::` functions against their
OWN context, concurrently, race on that shared global — whichever context isn't "current" at the
moment gets corrupted. Confirmed live: **100% reproducible crash on every single launch** once a
second window/thread/context was added (unlike most races in this file, which are intermittent),
with visible secondary symptoms (buttons in the FIRST window randomly failing to disable) proving
real cross-context state corruption, not just a clean crash.
**The fix is architectural, not a bigger mutex** (see 12i for why a mutex alone wasn't enough
anyway): don't run two ImGui contexts/threads in one process if it can be avoided. Collapse to a
single ImGui window/thread/context and present what would have been separate windows as
`ImGui::BeginTabBar` tabs of the ONE window instead. For a compiled UE4SS mod's own auxiliary
tool UI (as opposed to something that genuinely needs to be two independent OS windows), this is
strictly safer and sidesteps the whole class of `GImGui` races rather than chasing each one.

### 12h. Minidump analysis without a full debugger install: extract `cdb.exe` from the WinDbg Store package
Windows ships a real crash-dump debugger (`cdb.exe`, part of the WinDbg package), but the
Microsoft Store install of WinDbg lives under `C:\Program Files\WindowsApps\...`, which is
ACL-locked — even just reading/copying its own exe out is blocked for a process launched outside
the Store's own execution alias.
**Workaround**: locate the WinDbg package folder
(`C:\Program Files\WindowsApps\Microsoft.WinDbg_...\amd64\`), copy `cdb.exe` plus its companion
DLLs into a writable scratch folder, and run it from there. Point it at BOTH the crash dump and
the LOCAL PDB your own mod's build already produces alongside its DLL (an ordinary MSVC/CMake
debug-info build), so symbols resolve for your own frames, not just system DLLs.
**Command**: `cdb -z <dumpfile> -y <symbol-search-path> -c ".ecxr; kb 20; q"` —
`.ecxr` switches to the actual exception context record (without it you're looking at cdb's own
entry state, not the crash site), `kb 20` prints a 20-frame backtrace with arguments, `q` quits
after. This turns "it's crashed on every launch" into an exact function/line in minutes, instead
of guessing from symptoms.

**Faster first pass (2026-08-24)**: `cdb -z <dumpfile> -c "!analyze -v; q"` needs no symbol path
at all — it auto-locates the exception context itself and additionally prints a bucketed
`Failure.Bucket`/`Failure.Hash` classification, which is enough on its own to tell whether a NEW
dump is the SAME recurring crash as a previous one (compare buckets across dumps) before spending
time on a full backtrace read. Confirmed working against a target process (`UE4SS.dll`) that
wasn't even this project's own mod — no local PDB needed for a triage-level read, only for
resolving symbols inside your OWN mod's frames specifically.

### 12i. A mutex around one race can hide a second, independent race behind it
After fixing the `GImGui` cross-thread race (12g) with a mutex serializing ImGui calls between
the two windows' threads, the crash appeared to be gone — then came back under the same
"every launch" reproducibility, but with a **completely different root cause**: a null D3D11
constant buffer, traced via a second minidump (12h) to the two windows' D3D11 device-creation
calls racing each other at startup (both windows created near-simultaneously on mod load, both
independently calling `D3D11CreateDeviceAndSwapChain` with no ordering guarantee between them).
**Lesson**: when a fix for one identified race doesn't fully resolve an "every time" crash,
don't assume the fix itself was wrong before checking whether a SECOND, independent race shares
the same trigger window (here: "two things happening near-simultaneously at mod startup") and
was simply masked by whichever one hit first. A fresh minidump with a genuinely different call
stack (D3D11 device creation vs. ImGui internals) is what actually proved these were two separate
bugs, not one incompletely-fixed one. Both were ultimately made moot by the SAME architectural fix
as 12g (collapse to one window/thread) rather than patched individually — worth checking whether
an architectural simplification kills a whole CLASS of races before chasing each one to its own
targeted fix.

### 12j. `RegisterKeyBind` only fires while the GAME window has OS focus — stealing focus programmatically can break a "press again to undo" key
A key bound via `RegisterKeyBind` is a GAME-input hook: it only fires while the actual game window
holds OS keyboard focus, not system-wide. This matters the moment a mod also owns its OWN separate
window (e.g. an ImGui companion tool, 12e/12g) that can end up holding OS focus instead.
Concretely: a toggle key meant to open AND close an auxiliary window (open on press while playing,
close on a SECOND press while playing) broke specifically for the "close" direction whenever the
window's own open-path called `SetForegroundWindow()` on itself — once the tool window had OS
focus, the GAME window no longer did, so the toggle key's second press never reached
`RegisterKeyBind`'s hook at all (Windows routed it to the tool window instead, which wasn't
listening for it as a hotkey).
**Fix pattern**: don't call `SetForegroundWindow` on an auxiliary window's OPEN path if a
game-side keybind needs to be able to close it again later while the game still has OS focus —
closing must be reachable without the user manually re-focusing the game window first. If
focus-stealing on open is still wanted for convenience (so a click lands in the tool immediately),
pair it with a LOCAL input check inside the tool's own render loop (`ImGui::IsKeyPressed(...)`)
so the tool can ALSO close itself while it has focus — two independent paths to the same close
action: one for "still playing" (the native keybind, fires while the game has focus) and one for
"focused on the tool" (the local key poll, fires while the tool has focus).
**Separately confirmed: `SetForegroundWindow` (or any direct Win32 focus-stealing call) is not
reachable from UE4SS Lua at all** — no exposed binding exists in UE4SS's Lua API (checked against
UE4SS's own Lua API docs). Any "make my own window take focus" behavior triggered from Lua has to
cross a file-based bridge to a companion C++ mod that calls the real Win32 API itself (see 12a's
bridge-file pattern) — it cannot be done Lua-side directly, at all.

### 12k. Not every `UGameViewportClient` property is reachable from Lua reflection, even when it visibly exists on the class
`MouseCaptureMode` and `MouseLockMode` (properties that would let a script control OS cursor
confinement to the game window, matching what several native menus already do) resolve through
UE4SS's Lua `__index` metamethod to a technically-non-nil UObject wrapper — but one that reports
`IsValid() == false` on EVERY access, confirmed via purpose-built diagnostic instrumentation (read
the property, call `:IsValid()`/`:type()` on the result, log both). This is a genuinely different
failure mode from "property doesn't exist" (which returns Lua `nil`) or "property exists and
works" — it's a placeholder object that LOOKS reachable but isn't functionally usable.
Two heavier alternatives exist but weren't pursued here: (1) UE4SS's own hardcoded byte-offset
accessor system for specific known-problematic properties, which needs UE4SS's own SDK-generation
tooling run against this specific game build first (C++-only, no Lua equivalent); (2) constructing
the engine's real input-mode struct (`FInputModeGameAndUI` or similar) and passing it to
`SetInputMode` — but that struct is polymorphic (has a vtable), and Lua's reflection layer only
knows how to marshal plain-old-data structs by value; constructing one from Lua risks the same
"uncatchable native crash" class §3 documents for any mismatched-ABI native call.
**When a property looks present but every read comes back invalid/unusable, stop retrying
different Lua access patterns** — that's a signal the property genuinely isn't exposed at this
layer. The fix, if there is one in scope, lives in C++, not in a cleverer Lua read.

### 12l. Toolchain / project shape for a compiled UE4SS C++ mod
- Clone `RE-UE4SS` as a git submodule; it itself submodules a private Epic-gated header-stub repo
  (`UEPseudo`) that 404s until your GitHub account is linked to an Epic Games account with Unreal
  Engine source access (epicgames.com account settings / github.com/settings/connections) — a
  manual, one-time, per-developer step with no code-side workaround.
- Build configurations are NOT the CMake defaults (`Debug`/`Release`) — RE-UE4SS defines its own
  custom named configs (pattern: `{Game|CasePreserving|LessEqual421}__{Debug|Dev|Shipping|Test}__Win64`).
  Passing a standard config name to `cmake --build` fails with MSB8013 ("doesn't contain
  Configuration and Platform combination..."); always pass one of the real custom names (e.g.
  `--config "Game__Shipping__Win64"`).
- A mod project is `RC::CppUserModBase` subclass + `extern "C" start_mod()`/`uninstall_mod()`
  exports, same shape regardless of what the mod actually renders. Deploys as
  `.../ue4ss/Mods/<ModName>/dlls/main.dll` (+ `enabled.txt`), same folder convention as this
  project's own Lua mod.

### 12m. A toggle reachable from BOTH the game and a companion C++ window needs ONE owner, not two (2026-08-18)
A feature needed to be triggerable from an in-game keybind AND a button/key inside the separate
compiled-mod window, with both paths meaning the same logical state (e.g. "which of three
options is currently selected"). The tempting shortcut — give the C++ window its own local
variable, toggled directly by its own keypress handler — silently produces TWO independent copies
of what's supposed to be one piece of state: the in-game key changes the Lua-side copy, the
window's own key changes the C++-local copy, and nothing keeps them in sync; whichever one the
player checks last is "wrong" from the other's perspective. **Fix**: let the SCRIPT side (Lua)
own the state as the single source of truth, exactly like every other piece of live game state
this bridge already exposes (target lock, restore-in-progress, etc.). Both input paths just SEND
A REQUEST to change it — the in-game key calls the mutator function directly; the C++ window's
own key/button appends a one-shot `ACTION:` line to the same request-file bridge every other GUI
action already uses. Neither input path ever mutates its own local copy of the state — the C++
side only ever READS the current value back via the existing status-file poll (`MenuStatus`),
same mechanism it already uses for target-lock info. This guarantees the two input paths can
never disagree, at the cost of nothing extra: the status-poll and request-bridge machinery were
already there for other shared state, so a new toggle is just one more field on each, not a new
synchronization mechanism.

### 12n. Constructing real UMG widgets natively from C++ — the same primitives a Lua UMG binding uses, just called directly (2026-08-22)
A companion C++ mod moved from a separate ImGui window to real UMG widgets living in the actual
game viewport. Confirmed live, working: `UObjectGlobals::StaticFindObject<UClass*>(nullptr,
nullptr, "/Script/UMG.<ClassName>")` resolves each stock UMG class (`UserWidget`, `WidgetTree`,
`CanvasPanel`, `Border`, `TextBlock`, `Button`, ...) by its full path; `UObjectGlobals::
NewObject<UObject>(Outer, Class, FName(...))` constructs each instance (Outer chain: GameInstance
→ root UserWidget → its own WidgetTree → root CanvasPanel → children); `UObject::ProcessEvent`
with a hand-built params struct calls ordinary UFUNCTIONs on them (`AddChildToCanvas`,
`SetContent`, `SetText`, `AddToViewport`, `RemoveFromParent`). This is not a novel technique —
it's the exact sequence an existing, proven-working Lua-side UMG-building mod already performs
via `StaticConstructObject`/`FindObject`, just invoked from native C++ instead of through the Lua
binding layer. Two structural properties (`WidgetTree` on the root widget, `RootWidget` on the
`WidgetTree`) only exist as UPROPERTYs with no setter UFUNCTION — see §12o for why the "obvious"
official accessor for writing those crashed, and what was used instead. Every `ProcessEvent`
params struct must mirror the REAL target UFUNCTION's actual parameter list in order (plus a
trailing `ReturnValue` field if it returns something) — this is standard UE4SS-C++ native-call
practice (see §3l/§3q), not specific to UMG, but the risk is easy to underweight for something as
familiar-looking as "just calling a widget setter."

### 12o. A property's "official" C++ accessor can resolve through a WRONG vtable offset for a specific game build, and crash uncatchably — prefer a raw memory write when the layout is simple and known (2026-08-22)
Writing to `WidgetTree`/`RootWidget` (see §12n) was first attempted via the SDK's own
purpose-built property accessor for object-reference properties (its equivalent of "the correct,
supported way to set an object property from C++"). **Confirmed live: this crashed the game
instantly, with no catchable error** — reproducible, first call, every time. Root cause: that
accessor is a genuine C++ virtual function on the property-reflection object, and this specific
compiled UE4SS build resolves virtual calls on engine reflection types through a **vtable-offset
lookup table populated from a version-specific dump at UE4SS startup** — for this exact game
build, the entry for that one function was apparently wrong or unresolved, so the call jumped
through a bad function pointer. Two facts made the real fix possible: (1) the property's raw
STORAGE ADDRESS (`ContainerPtrToValuePtr`, a plain offset computation, no virtual dispatch) was
separately confirmed safe by the same crash-catching test; (2) a plain object-reference
property's underlying storage is JUST a flat pointer, no smart-pointer/ref-counting machinery —
so `*reinterpret_cast<UObject**>(address) = value;` at that confirmed-correct address is both
correct and vtable-free. **Lesson: when an "official" reflected accessor is a C++ virtual
function on a reflection object (property/field types, not the target UObject itself), treat it
as unverified for this specific compiled build until proven live — even though it's the
documented/intended API — and prefer a raw memory write at a plain-old-data address when you can
independently confirm both the address and the value's true in-memory layout are simple and
correct.** This is a DIFFERENT risk class from §3l/§12n's "wrong params struct for a UFUNCTION
call" — that risk is about guessing a signature; this one is about an internals-level
version-detection table being wrong for one specific game build, something no amount of correct
C++ on the caller's part can work around except by avoiding the virtual call entirely.

### 12p. Binding a native multicast delegate (e.g. UMG's `OnClicked`) from C++, avoiding the same vtable risk as §12o (2026-08-22)
Real click interaction (not just display) needed a `Button` widget's click to reach native C++
code. The engine's own delegate-property accessor for "add a bound function to this multicast
delegate" is, like §12o's case, a C++ virtual function on the property-reflection object — same
risk class, not attempted. Instead: the delegate's own VALUE TYPE (`TMulticastScriptDelegate`, an
array of `{weak object, function name}` pairs) has a `BindUFunction(UObject*, FName)` method that
is a plain, non-virtual, two-field assignment — confirmed by reading its own definition, not
assumed — and its containing array's `Add()` is an ordinary template container method, also
non-virtual. So: get the delegate property's raw storage address the same proven way as §12o,
reinterpret it as its real value-type struct (size-checked against `sizeof()` of that struct
first — a mismatch there means the assumed layout is wrong for this build, and the fix is to bail
out cleanly rather than write through a wrong-sized reinterpret, not to guess further), then call
the plain non-virtual `BindUFunction`+`Add` directly on it. Bind to a genuinely harmless,
already-inherited, no-argument void UFUNCTION the widget already has (a real, existing lifecycle
call — never an invented one), THEN register a native post-hook (this SDK's own instance-scoped
function-hook API, itself proven, heavily-used infrastructure, not a fresh risk) on that same
UFunction scoped to that one widget instance. A real click routes through the engine's own input
handling → broadcasts the delegate → calls the bound function on that instance → the hook fires.
**Confirmed live across multiple sessions: 100+ rapid clicks, hook fire count exactly matching
click count every time (no double-fires, no misses), no click passing through to the game
underneath, no crash from the bound function's real body actually executing as a side effect of
each click.**

### 12q. An inherited UFUNCTION can intermittently fail to resolve on an otherwise-valid, freshly-constructed object, for reasons not fully root-caused — build self-healing verification, not just an existence/liveness check (2026-08-23)
After §12n/§12o/§12p were all confirmed working cleanly in one live session, a LATER session
intermittently failed: a freshly `NewObject`-constructed widget (confirmed non-null, confirmed
`IsReal()`, confirmed its class's own function table was fully populated with a normal function
count when checked in a working session) would nonetheless fail `GetFunctionByNameInChain` for
functions that had resolved perfectly moments earlier in a different session with byte-identical
code. Ruled out: memory corruption from the delegate-binding code in §12p (reproduced the same
failure with that code path fully disabled); "the class just hasn't finished loading yet" (stayed
broken for 20+ seconds and many retries within an affected session, which is not a plausible
async-loading window). Root cause not pinned down. **Practical fix, regardless of cause**: don't
let "the cached object is still a live UObject" (`IsReal()`) stand in for "the cached object is
still actually usable." Re-verify the SPECIFIC capability you depend on (here: that the one
UFUNCTION you need is still resolvable) every time you're about to rely on cached state, and
rebuild from scratch if that check ever fails — turns "silently and permanently broken for the
rest of the session" into "self-heals on the next attempt." A liveness check and a usability
check are not the same claim, and conflating them is an easy, costly mistake once you've already
convinced yourself construction succeeded.

### 12r. Before claiming a native keybind, audit EVERY installed mod's key configuration, not just your own mod's (2026-08-22)
A new native (non-Lua) keybind, registered via this SDK's own C++ input-hook API rather than the
Lua-side `RegisterKeyBind`, was assigned to an F-row key that turned out to already be another
installed mod's own menu-toggle key (hardcoded in that mod's own config file). The result looked
exactly like a crash from the new feature's own code (game exited immediately on press) and cost
real debugging time chasing the wrong cause before the actual collision was found. **F-row keys
are especially collision-prone** — multiple unrelated tools/overlays default to them — a lesson
this project's own Lua-side keybind config already carries for exactly this reason (see its own
"F9 collided with one" note). Before assigning ANY new keybind, native or scripted: grep every
installed mod's own config/settings files for hardcoded key names first, not just the mod you're
actively building — a real collision reads identically to a crash in your own new code, and the
two are easy to conflate without checking.

**Recurred (2026-08-24)**: this exact lesson was NOT followed the next time a new key was
assigned — a companion ImGui window's own F9 tab-switch shortcut was picked without re-checking,
and it turned out to be `ModManager`'s (a separate installed UE4SS mod) own hardcoded
`MenuKey = "F9"` (`ModManager/dlls/config.lua`) — pressing F9 popped that mod's own overlay up
INSIDE the companion window instead of switching tabs. No crash this time (ImGui key checks are
just silently ignored input, not a native call), but the same root mistake: assigning a bare
F-row key without grepping other installed mods' config files first. **The lesson from a past
session doesn't self-enforce** — write it into a literal pre-flight step ("before shipping ANY
new keybind, `grep -r <candidate key> <ue4ss>/Mods/*/dlls/config.lua` across every installed
mod") rather than trusting it'll be remembered from having been hit once already.

### 12s. A native post-hook scoped to one instance can still fire from unrelated causes — the mechanism isn't the risk, the CHOICE of bound function is (2026-08-23)
§12p's click-detection (bind `OnClicked` to a harmless inherited UFUNCTION, hook that UFUNCTION
scoped to one instance) worked perfectly with exactly one bound widget. The moment a SECOND widget
was bound the same way, a single real click on one widget fired the hooks of ALL bound widgets —
every one registered so far, in registration order, within a couple milliseconds of each other.
This SDK's own header comment for the instance-scoped hook API states it fires only when the
instance pointer matches, and there's no reason to doubt that claim: the actual cause was that the
bound function itself (`UWidget::ForceLayoutPrepass`, chosen because it's inherited, harmless, and
already used routinely by the widget system) is called by the engine's own layout-invalidation
pass on MANY widgets whenever anything in the tree re-layouts — which a click's own broadcast
triggers, cascading a legitimate, correctly-instance-scoped call to every OTHER widget in the same
frame. **The hook mechanism was never the bug; a "harmless, already-called" function is, almost by
definition, not an exclusive signal for the one event you actually care about**, and that only
becomes visible once more than one instance is bound to it.

### 12t. `GetAsyncKeyState` can be completely blind to mouse buttons in a specific game process while keyboard keys work perfectly through the identical call — and a framework's OWN input pipeline can silently share that same blind spot (2026-08-23)
Needed a fallback click-detection signal (poll-based, not hook-based) and reached for
`GetAsyncKeyState(VK_LBUTTON)` on a rising edge — standard, and this SDK's own async input source
uses exactly this call for its keyboard bindings (confirmed by reading its source, not assumed).
Live: logged EVERY transition of that bit, not just a rising edge, across multiple sessions with
the mouse cursor genuinely released — zero transitions, ever, despite real clicks happening. The
SAME API for a keyboard key (already in production use in this same mod) worked reliably the whole
time. Tried routing through this SDK's own key-registration API instead, using its built-in
left-mouse-button key constant, on the theory that its underlying input source might use a
different/more privileged path — ALSO silent, because (confirmed by reading its source) that
system polls `GetAsyncKeyState(key)` for every subscribed key, mouse buttons included, so it's
driven by the exact same primitive that already failed. **A modern game very plausibly captures
mouse input through a raw/exclusive path (common for aiming precision) that never touches the
legacy async-key-state table for mouse buttons specifically, while leaving keyboard state on that
table untouched** — don't assume "the framework's own proven mechanism will work here too" without
checking whether it's built on the exact primitive you already ruled out.

### 12u: Never mutate or rebuild a widget tree synchronously from inside a native UFUNCTION hook's callback — it can hang the game, not crash it (2026-08-23)
A click handler that immediately tore down and rebuilt several widgets (remove old rows, construct
new ones) directly inside the hook callback described in §12p/§12s worked for a single, static
widget, but froze the game solid — no crash log, no error, just a hang — the moment it ran for a
widget whose own click was what triggered the rebuild (e.g. expanding a category, which both
removes and adds widgets in the same handler). The callback runs while the engine's own dispatch
of the ORIGINAL event (the click's `OnClicked` broadcast) is still on the call stack; destroying or
reconstructing the very widget that broadcast is still actively processing is a form of
reentrancy the engine isn't expecting, and it hangs rather than crashing cleanly — much harder to
diagnose than a crash, since there's no stack trace or dump to read. **Fix: never touch the widget
tree from inside a hook callback. Set a dirty flag instead, and do the actual rebuild from a
per-frame tick function that runs outside any hook's call stack.** Cheap, and turns an
intermittent, undiagnosable hang into a guaranteed-safe deferred operation.

### 12v: A panel's own "clear all children" UFUNCTION can silently do nothing live, even though it resolves and returns cleanly — track what you added and remove it explicitly instead (2026-08-23)
Rebuilding a scrollable list of dynamically-constructed rows called the panel's own generic
"clear all children" UFUNCTION before repopulating it. It resolved via this SDK's own
function-lookup call (no error logged) and its `ProcessEvent` call completed without incident —
yet live, the old rows never actually disappeared; each rebuild just appended a fresh full set on
top of the last, growing without bound. Root cause not independently pinned down (a function
resolving and returning without error is not the same guarantee as "it did what its name says," a
theme that recurs elsewhere in this project too — see §12k). **Fix: track exactly which child
widgets you added (a plain list, appended on add), and remove each one explicitly via the panel's
own single-child "remove this widget" UFUNCTION before adding the new set, rather than trusting a
bulk "clear everything" call.** Worth separately noting: the container's generic single-child
add/remove functions (available on every panel-type widget, inherited from a common base) resolved
and worked reliably for every panel type tried (a scroll container, vertical/horizontal stacks);
only ONE container type in this SDK needed its own more specific, type-named add function instead
(a canvas-style panel, whose slot carries extra positioning data the generic version's default slot
doesn't) — don't assume every panel type needs its own specifically-named function; try the
generic base-class one first.

### 12w: Combining a broad-but-reliable native signal with a cheap, independent, per-instance filter beats hunting for a "perfectly exclusive" one (2026-08-23)
After §12s/§12t, the eventual fix wasn't a fourth new detection mechanism — it was recognizing that
the ORIGINAL hook-based approach from §12p/12s already gave a real, reliable signal ("this specific
widget instance's bound function was just invoked"), just not an EXCLUSIVE one for the one event
that mattered (a genuine click, as opposed to routine engine housekeeping calling the same
function). Rather than search for some other bound function that might be truly click-exclusive
(unverifiable without engine source, and this project's own history — §12s itself — shows that kind
of assumption fails silently), the hook's own callback was extended to independently check, at the
exact moment it fires, whether that SAME widget instance currently reports itself as hovered by the
mouse (an ordinary, already-reflected getter, no extra machinery). A real click's hook fire and a
"the cursor is over this exact widget right now" check coincide; an unrelated housekeeping fire on
some OTHER widget essentially never does. **When a real, hard-won signal exists but isn't specific
enough on its own, look for a second cheap, independent, per-instance check to combine it with
before abandoning the whole mechanism for something unproven.**

### 12x: A C++ mod's `on_update()` call rate can silently decay from ~180/sec to ~1/sec over the first ~90 seconds of every session, for a cause not yet root-caused — and Lua's `ExecuteWithDelay` timing is NOT a reliable proxy for whether it's affected (2026-08-23)
Real-time interactivity added to a companion C++ mod (held-repeat buttons, polled via `on_update()`)
felt sluggish and unreliable compared to an existing ImGui panel doing the equivalent thing. Direct
measurement (a counter + 1-second logging window inside `on_update()` itself) showed why: the call
rate starts healthy right at launch (~180/sec, matching a normal frame rate) and PROGRESSIVELY DECAYS
over roughly 60-90 seconds down to a steady ~1/sec, where it stays for the rest of the session. This
happens **before any companion window/panel is even opened** — it is not triggered by, or specific to,
using the new feature; it's a property of the session's age. The mod's own `on_update()` body was
separately timed (wrapping it in a steady-clock start/end) and stays fast throughout — a consistent
18-25ms every single call, no growth over time — ruling out "our own code is slow" as the cause.

**Ruled out, with evidence, not guessing:**
- The other C++ mods in the same install (temporarily disabled together via `mods.txt`, one full
  relaunch+retest) — rate was still exactly ~1/sec, identical body timing. Not them.
- Lua's own async scheduler — an existing diagnostic console command in this codebase
  (`lbtickspike`, built for an unrelated earlier investigation, see its own header comment) measures
  REAL elapsed time between `ExecuteWithDelay` reschedules. Run well after the ~90-second decay
  point (confirmed via the SAME session's `on_update()` counter still reading ~1/sec at that exact
  wall-clock time), it reported 120 ticks at nominal 16ms completing in ~2.24 REAL seconds, avg
  18.66ms, min 15ms, max 22ms — indistinguishable from healthy. If the whole engine or the shared
  UE4SS event-processing loop were bogged down, Lua's own timers (which ride the same underlying
  async infrastructure) would show it too. They didn't. Not a shared scheduler/event-queue backlog,
  and not general engine slowdown (the game itself was never reported as stuttering).

**Not yet root-caused**: `mod->fire_update()` (which calls `on_update()`) is invoked from a
single-threaded loop in UE4SS's own `UE4SSProgram.cpp`, sleeping only 5ms between iterations —
nominally capable of ~180+/sec, matching what's actually observed at session start. Something specific
to how that loop calls THIS mod's `fire_update()` — not the loop's overall iteration rate, not the
other C++ mods sharing it, not Lua's own scheduling — degrades over the first ~90 seconds of a
session and then plateaus. Investigating further would require inspecting UE4SS's OWN compiled
internals (not just this mod's code) or attaching a real profiler/debugger, neither available on this
machine (see §12h — even minidump analysis here relies on extracting `cdb.exe` by hand).

**Practical lesson regardless of root cause**: a companion window on its own independent OS thread
(see §12e) is immune to this entirely — it was never discovered until a feature was built that, for a
correctness reason (native `ProcessEvent`/UObject calls must happen on the game thread), NEEDED
`on_update()`'s cadence for the first time in this project's history. **Before depending on a
shared per-frame hook's call RATE for real-time feel (not just "eventually gets called"), measure
that rate directly and early** — don't assume it matches the
game's own frame rate just because the underlying loop's sleep interval suggests it should. A working
diagnostic console command already in the codebase (`lbtickspike`) is reusable for checking whether
a NEW suspected timing issue is this same phenomenon or something else — run it well into a session,
not just at launch, since this decays rather than starting broken.

### 12y: A generated integration manifest is only as complete as its OWN translation table — adding a new value to the primary consumer doesn't automatically reach a SECONDARY one (2026-08-24)
A mod's own `RegisterKeyBind` accepts this SDK's internal key names directly (e.g.
`"NUM_DECIMAL"`), so a new keybind value works correctly in-game the moment it's added — no
translation needed for that consumer. But a SEPARATE integration (an optional companion mod,
`R5ModSettings`, that generates its own in-game remap UI from a manifest file this mod writes)
expects real Unreal `FKey` names instead (`"Decimal"`, not `"NUM_DECIMAL"`) and maintains its own
one-way lookup table for the conversion. The new key value passed silently through that lookup
table with no entry, falling back to the untranslated raw name — no error anywhere, no crash, no
console warning — and only became visible by actually reading the generated manifest file's
content and noticing one row looked different in shape from all the others (`primary =
"NUM_DECIMAL"` instead of a real Epic-style name like the surrounding rows). **Lesson**: when a
single new value needs to flow through MULTIPLE independent consumers/translation layers (here:
the SDK's own key-bind API directly, PLUS a second mod's separate FKey-name lookup table), adding
it to the primary/obvious consumer is not evidence it reached every consumer — grep for every
translation table that touches the same category of value and confirm the new one is actually
present in each, or read the actual generated output rather than trusting the write path
compiled/ran without error.

---

## 13. Placing an actor relative to a moving ship (2026-08-25)

Confirmed live: an actor's position CAN be expressed in a ship's own local (forward/right/up)
frame and stays put in that frame as the ship moves and turns — useful groundwork for any future
"decorate/crew a ship" feature, though this mod doesn't have one yet. This investigation started
from a separate UE4SS companion mod (not part of this project) that solves the same problem with
a different, more roundabout technique (deriving direction from two live-queried points — a helm
component and the ship's own origin — rather than the ship's actual rotation); its own comment
trail records an earlier attempt at the simpler rotation-based approach being withdrawn, without
saying why. This section is the result of testing that simpler approach directly.

- **Finding the ship an actor is standing on**: `pawn.BasedMovement.MovementBase` — if the
  engine's own moving-platform physics has picked the actor up, this resolves to the ship's
  movement component; call `:GetOwner()` on it to get the actual ship actor. Falls back to
  `pawn:GetAttachParentActor()` if `BasedMovement` isn't set. Both read cleanly with plain dot/
  method access in this UE4SS build — no struct-drilling needed here (contrast §10's `islandId`,
  a genuine struct VALUE; `BasedMovement` behaved like a normal property holding an object
  reference in practice).
- **The local-offset transform (yaw-only) works, and holds through real movement.** Given the
  ship's own `K2_GetActorLocation()` and `K2_GetActorRotation().Yaw`, a local `(forward, right,
  up)` offset maps to world space as a standard 2D rotation:
  ```
  worldX = shipX + forward*cos(yaw) - right*sin(yaw)
  worldY = shipY + forward*sin(yaw) + right*cos(yaw)
  worldZ = shipZ + up
  ```
  Live test: placed an actor via this math, then re-measured its offset (the inverse transform,
  same formula solved backward) twice — once at rest, once after the ship had sailed ~1300uu and
  turned ~49°. The recomputed local offset was IDENTICAL both times (within ~1uu/0.5° of
  measurement noise) despite the real movement and turn. **The rotation-based approach the other
  mod's history suggested was unreliable actually works fine for this** — at least for yaw; this
  test never exercised a case with a very different ship size/shape, so the verdict is specific to
  a Brig-class hull until checked on others.
- **The actor's FINAL resting spot is not exactly the requested local offset — physics settles
  it, and that settled offset is what actually stays stable.** Requesting `(forward=300, right=0,
  up=100)` produced an actor that, once the engine's collision/gravity resolved where it could
  actually stand, settled at roughly `(forward=223, right=0, up=190)` — a persistent ~77uu
  short/91uu-higher offset from the naive request, present already by the first check after
  placement and unchanged after that. Read as the deck's actual height/slope at that XY spot not
  matching the flat assumption baked into a single `up` constant, with gravity/capsule collision
  correcting for it once during the initial settle. **Practical implication for real placement
  work**: don't trust a computed local offset as the actor's final position — place it, then
  IMMEDIATELY re-read its actual settled local offset (same inverse-transform check) and use THAT
  going forward as the tuned value for that spot. Once settled, it holds — this only needs doing
  once per placement spot, not per-frame or per-voyage.
- **Once genuinely `BasedMovement`-latched, no further per-tick work is needed to keep the actor
  correctly seated** — confirmed by the drift check above spanning a real sail+turn with zero
  code running in between. The engine's own moving-platform physics carries it, the same way it
  carries the player.
- **Verifying a placement actually latched**: read `actor.BasedMovement.MovementBase`'s owner
  back and compare `:GetFullName()` against the ship — same pattern §2/§9 already establish for
  composite/de-corrupt work (never trust that a call "succeeded" without an independent
  readback). A `K2_SetActorLocation(dest, false, {}, true)` (teleport=true) is sufficient to
  trigger the engine into re-basing the actor; no explicit attach call was needed.

---

## 14. Playing a specific canned animation on a live Character

Confirmed live: a Character can be made to play one specific existing AnimSequence from the
game's own animation library instead of whatever its AnimBlueprint would otherwise drive — useful
for giving an NPC a specific activity pose (at a workbench, on a ship) rather than a generic idle.
Getting there took three real, separate bugs, each worth knowing about on their own.

- **`EAnimationMode::Type` is `AnimationBlueprint = 0, AnimationSingleNode = 1`.** Easy to get
  backwards — a first attempt wrote `0` intending "single node" and instead wrote the mesh's
  already-current default mode, so nothing visibly changed despite every call reporting success.
- **The real `SetAnimationMode()` function can fail via a caught error for reasons that were
  never root-caused** (possibly this build's reflection doesn't marshal the enum-typed parameter
  that function expects). A plain property write to the same field (`mesh.AnimationMode = 1`) is
  NOT an equivalent substitute here, unlike other function-vs-property cases in this codebase
  (contrast §2's own note): the property write changes the stored flag and reads back correctly,
  but the component's internal animation-playback instance never gets swapped to match — so the
  OLD instance keeps actually driving rendering regardless of what gets set afterward. Confirmed
  by a live test that read back `AnimationMode 0 -> 1` (genuinely changed) with every subsequent
  `SetAnimation`/`Play`/`SetPosition` call ALSO reporting success — and still nothing rendered.
  The working fix: call `mesh:PlayAnimation(animSequence, bLooping)` instead — a single function
  built to switch modes AND start playback together, with only an object reference and a bool as
  parameters (no raw enum to marshal), which succeeded where the granular function call did not.
- **Skeleton/rig compatibility is not predictable from folder naming.** Animations that sound
  like they should apply broadly (this game organizes many animations under a `Human/Regular/
  Shared/...` path, implying reuse across "Regular" humanoid NPCs generically) are NOT safe to
  assume compatible across every Character class that happens to use a similarly-named skeleton
  family. Playing a genuinely foreign animation on the wrong skeleton produces a T-POSE — the
  mesh visibly freezes in its rest pose — while AI-driven movement continues completely normally,
  since movement and pose rendering are separate systems; a T-posed actor can still walk around.
  This was confirmed with TWO different animations, each tested on a base class the animation
  was NOT associated with: both T-posed. The SAME animation applied afterward to the SPECIFIC
  base class it WAS associated with (see the next point) rendered correctly, no T-pose, on the
  first attempt — folder-name similarity is not the signal that predicts success; a real,
  specific class association is.
- **Finding a genuinely compatible animation without guessing blind**: an animation that already
  shows up as a NATIVE default/fallback value on a target class's own AnimInstance (found via a
  live property probe on an actor of that class — reading its `AnimationData.AnimToPlay`-style
  fields, the same struct-drilling technique §10 established) is real evidence it was authored
  for that exact skeleton, not just a plausible-sounding guess from folder/file naming. This is
  what finally produced a working result after two folder-plausible but class-mismatched
  guesses both T-posed.
- **`PlayAnimation`'s second parameter is `bLooping` — default it to `true` for an ambient pose.**
  A one-shot play (`false`) runs the animation through once and then stops, which reads as broken
  for a persistent "doing an activity" idle rather than a genuinely continuous one. Easy to miss
  since a one-shot still visibly "works" on the first playthrough.
- **The same asset can appear under two different path casings in a full pak export, and only
  one of them actually resolves.** A full asset-path listing (built from scanning every pak
  chunk) showed one specific mesh under both `.../WorkBenches/...` (capital B) and
  `.../Workbenches/...` (lowercase b) as separate entries — almost certainly duplicate content
  across different pak chunks. `StaticFindObject`/`LoadAsset` are case-sensitive enough that the
  wrong-cased path fails to resolve, with a generic "did not resolve" message that gives no hint
  the asset actually exists one case-variant away. Worth trying both casings before concluding an
  asset genuinely isn't there.
- **A folder path segment of `Environment` (as opposed to `Human/Regular`) is a strong signal the
  animation drives an OBJECT, not a person, even when it's filed under the broader
  `Character/Animations/` tree.** A workbench-interaction animation under an `.../Environment/
  Workbenches/...` path T-posed a Character AND played an unrelated visual effect alongside it —
  consistent with it actually being the workbench APPARATUS's own animation (its moving parts,
  its spark/smoke effect), authored for that prop's own skeleton/rig, not a human one at all. The
  matching `Environment/WorkBenches/` AnimBlueprints found in the same sweep (one per station
  type) are almost certainly that object's own animation driver. Cheap pre-filter before even
  trying a candidate: prefer paths under `Human/Regular/...` (where the one confirmed-working
  animation lived) and treat an `Environment/...` path as a likely prop animation, not a
  person-pose candidate at all.
- **`_Hero_`-prefixed animations are NOT a separate, incompatible skeleton — confirmed live, this
  was an over-cautious assumption that turned out wrong.** The initial theory was that "Hero"
  meant "player-only rig," reasoning by analogy from a DIFFERENT, unrelated system (this game's
  `Hero_`-prefixed CompositeMeshParams — a body/outfit-shape asset type, not animation — are
  confirmed to crash the game when applied to an NPC, see the composite-system notes elsewhere).
  That analogy does not hold for animations: a `Human/Regular/Shared/.../A_..._Hero_..._Loop`
  sequence applied cleanly to a generic Handyman-family worker, not a named/unique character and
  nowhere near the player. The real, confirmed-working filter remains the one above (`Human/
  Regular/...` good, `Environment/...` bad) — the `Hero` vs. plain naming segment inside
  `Human/Regular/` does not by itself predict compatibility either way. Don't assume a `Hero_`
  animation is off-limits for NPC use without testing it; a genuinely different asset TYPE being
  player-locked (composite params) does not mean every asset family sharing that naming
  convention is equally restricted.
- **A `Human/Regular/...` path is a useful first-pass filter, not proof — some assets filed there
  still turn out to be OBJECT animations, not person animations.** A set of ship-cannon
  candidates lived under a `Human/Regular/Shared/...` path (matching every heuristic above) and
  still T-posed a Character, paired with an unrelated effect firing alongside it — the same
  symptom the `Environment/`-path workbench candidate produced, because it turned out to be the
  cannon's own recoil/reload animation (an object transform), not a sailor's pose, despite its
  folder placement. **A T-pose paired with an unrelated effect firing is itself a signal to
  abandon that specific candidate** — it suggests an object/scene animation with its own
  AnimNotify driving that effect, not a mis-filed person pose worth retrying. The one filter that
  has actually held up every time remains the positive one from the point above: does this exact
  asset already show up as a genuine native AnimInstance default/fallback value on a real
  Character of the target skeleton family. Folder path — even a "should be safe" one — is a
  hint, never a substitute for that check.
- **A combat/ability animation can carry a real gameplay-damage AnimNotify that fires even when
  played this way on a completely inert, non-hostile actor — confirmed live, this actually
  injured the player.** Playing a Senkamati Caster's own "create spikes" attack animation on a
  placed, untamed, non-AI statue via this exact `PlayAnimation` mechanism caused REAL damage to
  the nearby player character. AnimNotify events fire off the animation's own timeline
  regardless of who or what is playing it and regardless of AI/hostility state — an inert prop
  with no controller and no intent to attack is not exempt just because nothing is "deciding" to
  cast the spell. There's no established-safe way from Lua/UE4SS reflection to strip or suppress
  an AnimSequence's own baked-in notifies before playing it. **Treat any combat/ability-sounding
  animation candidate (attack windups, spell casts, spike/projectile-themed names) as a real risk
  to test from a safe distance or with health to spare** — this class of animation is not the
  same kind of "worst case is a T-pose" experiment an idle/activity pose candidate is.

## 15. `ExecuteWithDelay`'s callback does not run on the game thread — and nesting it inside `ExecuteInGameThread` is its own separate, differently-broken thing

Two distinct, confirmed-live rules, easy to conflate into one wrong mental model:

- **`LoadAsset` (and likely other game-thread-only engine calls) throws if called from inside an
  `ExecuteWithDelay` callback directly.** The exact error is `Function 'LoadAsset' can only be
  called from within the game thread`. A console-command handler or a key-bind callback's own
  synchronous body IS on the game thread (confirmed: the same `LoadAsset` call succeeds fine from
  there) — it's specifically the code that runs LATER, once an `ExecuteWithDelay` timer actually
  fires, that isn't. This looked at first like a "cold asset, needs more retries" problem (a
  manually-triggered resolve earlier in the session made a later automatic one succeed) — that
  was a red herring; the real fix is hopping back via `ExecuteInGameThread` immediately before the
  actual engine call, every time, not retrying more.
- **Calling `ExecuteWithDelay` from literally inside the callback function passed to
  `ExecuteInGameThread` throws `No overload found for function 'ExecuteWithDelay'`.** So the fix
  for the first rule can't simply be "wrap the whole retry function's body, recursive call and
  all, in one `ExecuteInGameThread`" — that just trades one error for the other. The correct
  shape, confirmed working: the `ExecuteInGameThread` call (the actual engine-touching work) and
  the NEXT `ExecuteWithDelay` call (scheduling the next retry tick) must be direct top-level
  SIBLING statements in the retry function — never one nested inside the other's callback body.
  Calling `ExecuteWithDelay` as the very first, synchronous action inside an
  `ExecuteInGameThread` callback is fine either way; it's specifically
  `ExecuteInGameThread(function() ... ExecuteWithDelay(...) ... end)` — the reverse nesting — that
  throws.
- **Consequence of `ExecuteInGameThread` being fire-and-forget/async**: a caller can't
  synchronously know whether the work it just queued succeeded before deciding whether to
  schedule a retry. The simplest robust pattern found: just retry a fixed number of times
  unconditionally rather than trying to gate on a success flag — re-doing an already-successful
  effect (a material swap, a faction copy) is harmless, and trying to read a "did that work" flag
  immediately after queuing it is reading a value that's at best one tick stale by design.

## 16. Comparing two independently-obtained component references with `==` is unreliable in this UE4SS build — compare `GetFName():ToString()` instead

Confirmed twice, in two unrelated features: a body-mesh-exclusion check (`comp == bodyMesh`,
comparing a reference read from `actor.Mesh` against one pulled from a
`K2_GetComponentsByClass` array) silently evaluated false on every single comparison — not an
error, just always the wrong branch — so a "skip this one component" step never actually skipped
it. Switching to `comp:GetFName():ToString() == bodyMesh:GetFName():ToString()` fixed it
immediately, confirmed via an explicit slot-count log showing the exclusion finally taking
effect. **This failure mode produces no error and no crash — it just silently always takes the
same branch**, which makes it easy to misread as "the whole feature doesn't work" rather than
"one specific identity check never fires." Actor-level `==` (comparing two actor references, not
components) has not shown this problem anywhere — treat this as a component-specific gotcha, not
a blanket "never use `==`" rule.

## 17. Windrose Mod Settings CAN probably render a real slider ("scalar") and dropdown ("discrete") widget — a single unconfirmed exploratory test, not a proven, ready-to-use recipe (2026-08-29)

**Status check (2026-08-31): this was never revisited, never adopted, and its central claim is
weaker than the confidence it was originally written with.** `modsettings.lua`'s actual shipping
integration only registers `type = "toggle"`/`type = "keybind"` (`M.TOGGLE_DEFS`/`M.KEYBIND_DEFS`)
— the `"scalar"` type described below has never been used in a real setting, and git history shows
this section was written once and never touched again. Treat everything below as a promising lead
worth re-testing before relying on it, not a settled capability.

The third-party Windrose Mod Settings mod's own Lua layer (`R5ModSettings.lua`) is pure generic
file I/O (load/save a Lua table, publish a shared variable) — it contains no type-specific
validation or widget-selection logic at all. That logic lives entirely in a bundled native DLL
(`dlls/main.dll`), unreadable as source. A plain `type = "number"` setting registration (the
obvious-seeming choice, and the only type ever documented anywhere in a working example) rendered
as a checkbox instead — readable/writable only as 0 or 1 — with no error, no warning, nothing to
suggest a different type exists. **Found via a raw UTF-16LE string extraction of the DLL rather
than more registration-schema guessing**: the strings
`WBP_Settings_EntryScalar`/`WBP_Settings_EntryDiscrete`/`WBP_Settings_EntrySwitcher` (this game's
own native settings-screen slider/dropdown/toggle widget classes, also used for ordinary
graphics/audio settings) are directly referenced, alongside the literal lowercase strings
`"scalar"` and `"discrete"` and a `"[{}] Skipped unsupported setting mod={} key={} type={}
options={}"` diagnostic format string — real evidence of an actual type-dispatch branch, not just
a checkbox default. Setting `type = "scalar"` (with guessed `min`/`max` fields — the DLL's exact
expected field names are still unconfirmed, since they live in compiled code) DID render a real
slider widget on screen, confirmed live. **What was NOT confirmed**: whether a value actually
dragged on that slider round-trips correctly — saves, and reads back as the right number through
the same `ReadSavedFile`/shared-variable path `TOGGLE_DEFS` entries are proven to use. Rendering a
widget and a working read/write round trip are different claims; only the first was ever tested.
**No integer-step/interval field was found anywhere in the DLL's strings** (checked for
"step"/"interval"/"integer"/"round"/"delta", no hits) — the slider appears to be a continuous float
with no snapping option exposed through this registration schema; a value like `8.21` is a
completely normal thing for a player to land on while dragging it, IF the guessed `min`/`max`
field names are even the real ones. If a whole number is actually required, round it explicitly on
the Lua side when reading the saved value back, rather than assuming the UI can be made to snap.
**Before shipping anything on this**: re-confirm the round trip end to end (write a real value via
the slider, restart or re-read, confirm the Lua side sees the same number), not just that the
widget appears.

**Technique worth reusing on its own**: when a third-party mod's Lua-visible source doesn't
explain an observed behavior (here: "why does a number setting render as a checkbox"), and it
ships a compiled DLL, extracting printable strings from that DLL (both plain ASCII and, easy to
miss, UTF-16LE — Windows/Unreal code frequently uses wide strings, which a naive ASCII-only
`strings`-style scan won't find at all) can reveal real internal type names, log format strings,
and referenced native class paths — genuine evidence to test against, rather than continuing to
guess at a black box from the outside.

## 18. Line-trace-based targeting: object-type queries aren't a strict superset of channel-based ones, and a "does this component exist" check needs `:IsValid()`, not `~= nil`

Building an interactive "aim and pick a world object" targeting system on top of UE4SS's exposed
`KismetSystemLibrary` trace functions hit two separate, easy-to-miss pitfalls — both confirmed
live, both worth checking for in any similar targeting system.

- **A component-existence check returned by a reflection call can be non-nil but still invalid.**
  `GetComponentByClass(SomeClass)` on an actor that has NO component of that class does not return
  Lua `nil` in this UE4SS build — it returns a non-nil userdata sentinel. A check written as
  `result ~= nil` is therefore **always true**, regardless of whether the component actually
  exists, silently breaking any logic gated on it (in this case, an entire fix intended to only
  skip one category of actor ended up skipping EVERY actor, for as long as several rounds of
  otherwise-correct-looking follow-up fixes, because nothing ever got past this check to run in
  the first place). The correct check is `result ~= nil and result:IsValid()` — same rule already
  established for actor/component array elements elsewhere (§16), now confirmed to apply to a
  plain single-object existence check too, not just arrays. **This failure mode produces no error
  and no crash — it silently no-ops the exact code path meant to fix something**, which reads
  identically to "the fix didn't work" and can burn multiple debugging rounds before anyone
  thinks to check whether the code even ran at all (a plain unconditional log line right before
  the return, checked against the actual log file, is what caught it here).
- **An object-type-based line trace (`LineTraceSingleForObjects`/`LineTraceMultiForObjects`) does
  not reliably hit every native class a channel-based trace (`LineTraceSingle` against a specific
  `ECollisionChannel`) would.** Confirmed live: after fixing every other variable, a specific
  native "destructible" prop class remained unhittable via an object-type trace querying a wide,
  generous range of standard object types — while a plain CHANNEL-based trace (against the same
  channel the object-type query's own equivalent SHOULD have covered) hit it immediately once
  something explicitly forced that channel's response to Block. The two trace styles are not
  interchangeable substitutes for "find whatever's under the reticle" in every case; a robust
  targeting system should treat them as complementary, layered tiers — try the object-type trace
  first (cheaper conceptually, and it's what a modern UE project is generally built around), then
  fall back to a channel-based trace against the same logical channel if nothing was found —
  rather than assuming one fully subsumes the other. Widening an object-type query's own type list
  costs nothing (a type nothing has just never matches), so do that too, but don't rely on it
  alone to close every gap.
- **When retrofitting a fix like this onto a wide, unopinionated raytrace (e.g. one meant to hit
  literally anything a mod might place, sourced from a broad in-game asset catalog, not just a
  small curated set of known classes), test against the WIDEST, weirdest class actually reachable
  through that catalog, not just the first few obvious cases.** A "destructible" furniture prop
  built on this game's resource/harvest-node system (visually identical to ordinary decor, but
  using a different underlying collision setup) is exactly the kind of outlier a narrow test pass
  (walking Characters, a couple of ordinary decor items) would never surface — it only showed up
  once the actual target class list widened past what the original targeting system was built and
  tested against.

## 19. Constructing a composite outfit from scratch: the real 3-level asset structure, what's safe to build via Lua, and what crashes (2026-08-29)

### 19a. The real structure, confirmed via direct asset-JSON exports (not a live probe this time)

Everything §2/§2d already document treats a composite's outfit as something you SWAP (a different
class's whole `DefaultParams` bakes in at build time) or PATCH (one `BuildedCompositeMeshes` slot's
mesh, post-build). Neither answers "can I construct a genuinely NEW, custom combination of pieces
from scratch." Exporting a real character's own params asset to JSON (via an external tool run
directly against the `.uasset` files, not a live in-game probe) revealed the actual structure, three
levels deep:

1. **`R5CompositeMeshComponentBaseParams`** (what `DefaultParams` points at) — a `CustomizationData`
   array, one entry per category (`Customization.UID.Armor`, `.Hairs`, `.Facial.Eyebrows`, etc.).
   Each entry has a `GroupCategoryId` (`FGameplayTag`), a `bAllowCustomization` bool, and
   `CompositeMeshGroupsByBodySex` — a `TMap`-shaped list of `{Key: sex enum, Value: {a list of
   R5CompositeMeshGroup references}}`. A category with `bAllowCustomization=false` (a fixed
   character's Armor) lists exactly ONE group; a real player-facing picker category (Hairs,
   Eyebrows) lists dozens — this literally IS the backing data for the game's own character-creation
   hair/eyebrow selector.
2. **`R5CompositeMeshGroup`** — just a flat `CompositeMeshesParams` array of `R5CompositeMeshParams`
   references, one per body part. Confirmed on a real NPC's own outfit group: SIX pieces (Feet,
   Hands, Head, Legs, Torso, Belt) pulled from THREE different named armor families in the game's own
   catalog — proof that a "Group" is an arbitrary bundle, not a single-family outfit.
3. **`R5CompositeMeshParams`** (the bottom level, one per body part) — finally holds the real data:
   `BaseMesh.AssetPathName` (a plain `SkeletalMesh` soft-path, per sex), `Attachments` (socket-
   attached extras — pistols, pouches — each with its own full baked `Rotation`/`Translation`/
   `Scale3D` transform, i.e. socket offsets ARE data, not something computed), and
   `ColorData.ColorIndexesMap` (confirming color is consumed at THIS level, build-time-only — the
   root cause of the already-documented "post-build `ColorController`/`ColorParams` writes never
   render" dead end, not a contradiction of it).

Every catalog family that already has ordinary content (confirmed for one family: 12 pieces across 4
body parts, 3 numbered variants each) almost certainly already has its own `R5CompositeMeshParams`
("...CompositeMeshData") asset per piece — meaning a custom outfit does NOT require authoring new
per-piece data from scratch, only a new Group referencing EXISTING pieces from whatever families you
want, mixed freely.

### 19b. What's actually constructible from Lua — confirmed piece by piece, live

- **`StaticConstructObject` generalizes beyond the one class it had ever been tried on.** Already
  proven for a plain UMG `TextBlock` (toast-notification work, elsewhere in this project); confirmed
  live this session on a completely different, unrelated class (`R5CompositeMeshGroup`, then
  separately `R5CompositeMeshComponentBaseParams`) — both constructed cleanly, no crash, no special
  handling needed beyond resolving the right `/Script/Module.ClassName` path first.
- **Writing a `TArray` of HARD OBJECT REFERENCES works via plain Lua-table assignment.** Every
  property write documented elsewhere in this file up to now has been a scalar, a Vector/Quat-shaped
  struct, or a single object/texture reference — never an array of object pointers. Confirmed live:
  `groupObject.CompositeMeshesParams = { obj1, obj2, ..., objN }` (a flat Lua table of already-
  resolved `UObject` references) populated the array correctly on the first attempt, verified by
  re-reading `GetArrayNum()` afterward — no `:Add()`-per-element fallback needed.
- **`DuplicateObject` and `StaticDuplicateObject` are BOTH absent from this UE4SS binding's global
  namespace.** Calling either produces a clean Lua "attempt to call a nil value" error — safe to
  probe (a nonexistent global can never reach the engine), but confirms there is no direct
  duplicate-an-existing-asset primitive exposed here. If you need a modified copy of an existing
  DataAsset, the only currently-known route is constructing a NEW instance of the same class via
  `StaticConstructObject` and populating its fields yourself, not cloning-then-patching.
- **Constructing a `CustomizationData`-shaped array-of-structs entry, narrowed down step by step,
  isolates the crash to ONE specific operation: constructing a `GameplayTag` from scratch.**
  The original one-shot write (an array containing one struct with a `GameplayTag` sub-table, a
  bool, and a `TMap`-shaped sub-array, all assigned together) crashed the game live. Splitting
  into three separate writes (the category tag, then the bool, then the `TMap` sub-array) crashed
  again — but now isolated to the FIRST and simplest of the three, ruling out "too much nesting in
  one write" as the cause. Splitting THAT into two even finer sub-steps settled it: (a) writing the
  array with one COMPLETELY EMPTY entry (`{ {} }`, no tag at all) — **survives cleanly**, confirmed
  live, proving the array-of-structs mechanism itself is fine; (b) then, on that same fetched-back
  entry, assigning `GroupCategoryId = { TagName = "..." }` — **CONFIRMED TO CRASH THE GAME LIVE**,
  every time, in isolation from everything else. A breadcrumb logged immediately before this exact
  call was the last line written to any log across every attempt — nothing runs after it.
  This is the first attempt anywhere in this investigation at CONSTRUCTING a `GameplayTag` from
  scratch and handing it to the engine; every prior successful read of one elsewhere in this
  project was already-registered, already-valid data loaded from a real asset. `GameplayTag`s are
  normally validated against a registered tag hierarchy at construction time — a bare table
  (`{TagName = "some.string"}`) apparently does not satisfy whatever that validation expects,
  unlike a plain `FVector`/`FName` string, which have no registry to consult at all. Every other
  operation tried in this whole investigation (both `StaticConstructObject` calls, the flat
  array-of-object-references write, and the empty-struct array write above) completed cleanly —
  this failure is specific to fabricating a `GameplayTag` value out of nothing, not a general
  problem with structs, arrays, or nested writes.
  **UPDATE — the alternative above was tried, and REFINES rather than confirms the original
  theory.** Reading an already-valid `GameplayTag` off a real asset (Marita's own real character
  params, the exact asset her walking re-skin already loads normally) and COPYING that value onto
  the fetched-back entry (`entry.GroupCategoryId = realTag`, a struct-to-struct value copy, no
  fabrication) **worked — confirmed live, no crash.** Building the rest of the entry via the SAME
  staged pattern (separate writes for the bool, then the `TMap`-shaped sub-array) also survived.
  So far, so good — but the resulting actor spawned **fully nude**: a live probe showed the build
  produced ZERO composite mesh pieces for ANY category, not just the one being tested. A separate
  diagnostic (copying an existing character's ENTIRE `CustomizationData` array wholesale onto a
  freshly-constructed params object, no modification at all) confirmed a fresh object CAN build
  correctly — ruling out "fresh objects never build." Appending real Hairs/Eyebrows entries
  alongside the custom one (still copied verbatim, unmodified) also didn't help — ruling out
  "missing categories" as the cause.
  Suspecting the staged fetch/mutate/reinsert pattern itself might be producing a value that reads
  back self-consistently in the scripting layer without being what the native build code actually
  consumes, the next attempt tried building the WHOLE entry (copied tag included) as ONE single
  table-literal assignment — the same shape as the very first crash, except with a copied tag
  instead of a fabricated one. **This ALSO crashed, twice, reproducibly** — both when combined with
  real pre-existing entries in the same write, and even completely alone (just the one custom
  entry, nothing else in the array). This is the decisive result: it rules out "GameplayTag
  fabrication specifically" as the actual cause, and rules out "mixing freshly-built and
  pre-existing entries" too. **The real rule, as best understood now: constructing a brand-new
  struct value via a table literal, in one shot, AS A NEW ARRAY ELEMENT, crashes — regardless of
  what's inside it or what else is in the array.** The only pattern ever confirmed to add a new
  struct element without crashing is: insert a COMPLETELY EMPTY placeholder first (a literal like
  `{ {} }`), fetch it back out of the array, then mutate its fields ONE AT A TIME via separate
  property assignments on that live handle — never construct a populated struct as part of the
  insertion literal itself.
  **Net status**: the crash risk for this kind of custom construction is now well understood and
  avoidable (use the staged empty-then-mutate pattern). What's NOT yet solved is why that safe
  pattern doesn't actually produce a working build — that remains open, and is a different problem
  from the crash risk documented here. Worth checking whether the TMap-shaped sub-array (itself
  built from nested table literals inside the staged writes) has the same "silently disconnected"
  risk as the outer entry did, even though it doesn't crash.

### 19c-2. The actual working recipe, found once the runtime approach was abandoned: edit a REAL asset offline, don't construct one at runtime

Everything in §19a/§19b is about constructing a composite outfit's data FROM LUA, AT RUNTIME, inside
the running game — and that whole approach hit a real, understood wall (§19b's own closing note).
Stepping back and asking a different question — "can we edit an EXISTING real asset file directly,
outside the game, and ship it as a small content pak?" — turned up a genuinely different, complete,
CRASH-FREE pipeline that actually works end to end. This is the recipe that should be reached for
first for this whole class of problem; the runtime-construction approach in §19a/§19b is now a
closed, documented dead end, not a starting point.

**Tools needed** (all free, all already used successfully elsewhere in this project's own history):
a proper asset browser/exporter (e.g. FModel) with a `.usmap` mappings file for the game (UE4SS can
usually generate one itself — a console command wrapping the engine's own `DumpUSMAP()` function,
already used earlier in this project); a low-level UE5 IoStore/Zen ⇄ Legacy pak converter (`retoc`,
open source, MIT-licensed); a `.uasset` property editor that understands the LEGACY (non-Zen) format
(`UAssetGUI`, also open source, also wants the same `.usmap`); and a modern `.pak` container writer
(`repak` — NOT the game's own bundled `UnrealPak.exe`, which choked on both extracting a
retoc-produced legacy pak AND apparently on this specific game's own real paks with checksum/version
mismatches; `repak` had none of these problems).

**The recipe, step by step:**

1. **Export the REAL target asset(s) from the game**, in a properly cooked, byte-exact form — not a
   converted/human-readable export. FModel's own JSON export (the same feature already used earlier
   in this session to read `CustomizationData` structure) is genuinely useful for UNDERSTANDING the
   asset's shape, but is a DIFFERENT schema from what `UAssetGUI` can edit and re-save — it does not
   round-trip. What's actually needed for editing is the real, cooked binary asset. This game ships
   its content as UE5 Zen/IoStore containers (`.utoc`/`.ucas`/`.pak` triples), and `UAssetGUI` cannot
   open a Zen asset directly ("UE5 Zen Loader assets cannot be loaded directly into UAssetGUI") — it
   needs the OLDER "legacy" `.uasset`+`.uexp` format instead. Get there with:
   ```
   retoc --aes-key <64-zero-hex-chars> to-legacy <game's Content/Paks folder> <output dir> \
       --filter "<a substring matching just the asset(s) you want>" --version <UE version enum, e.g. UE5_6>
   ```
   The `--filter` substring match is a plain filename filter, not a glob (`*Name*` matched nothing;
   plain `Name` matched everything containing it) — narrow it enough to avoid pulling the whole game's
   content across (which `to-legacy` CAN do — it's designed to convert an entire game — but is
   unnecessary and slow for editing one or two specific assets). The all-zero AES key is the standard
   placeholder for a game whose containers are not meaningfully encrypted (confirmed for this game
   elsewhere in this file, §9) — `retoc` still requires SOME key be supplied even when it turns out
   not to matter.
2. **Edit the extracted `.uasset` in UAssetGUI.** A composite-outfit "Group" asset's per-piece object
   references (§19a's mid-level asset, an array of `R5CompositeMeshParams` references) are NOT edited
   via the Export Data grid directly (that view is read-only, showing only the CURRENTLY-resolved
   name) — they're edited via the **Import Data** grid instead. Each object reference in this game's
   asset format shows up as TWO import rows: one `Package`-type row holding the full `/Game/...` path,
   and one row of the actual class type (e.g. `R5CompositeMeshParams`) holding just the short asset
   name, with its `OuterIndex` pointing back at the package row. Both are plain editable TEXT fields
   (`ObjectName`) — double-click to edit, type a completely different asset's full path/short name
   into these two rows, and the reference is retargeted to point at that different asset entirely, no
   need to add a new import at all. **No manual Name Map bookkeeping is needed** — typing a brand new
   string into an editable name field like this auto-registers it in the package's own Name Map on
   save; confirmed directly, since the very first such edit used a string that didn't exist anywhere
   in the source package and it saved and re-opened cleanly with the new value showing correctly in
   the (read-only) Export Data view afterward.
3. **Decide: a brand-new custom asset, or an override of an existing one — this decision matters a
   lot, see §19c-3 below.** If duplicating into a new asset (File → Save As under a new filename),
   ALSO change its own `PackageName` field (General Information tab) to a genuinely new `/Game/...`
   path — Save As only changes the destination FILENAME, the asset's own internal identity string is
   a separate field that has to be set explicitly, and it (not the .uasset's filename) is what other
   packages' cross-references and the engine's own resolution actually key on.
4. **Convert the edited legacy asset(s) back to Zen/IoStore format**, staged under a folder tree that
   mirrors the game's own logical `/Game/...` path structure (a physical folder path of
   `<stage>/<ProjectName>/Content/Foo/Bar/MyAsset.uasset` maps to the logical package
   `/Game/Foo/Bar/MyAsset` — "R5" in this game's own case is literally the project name, the same way
   "/Game/" is UE's own standard alias for "<ProjectName>/Content/"):
   ```
   retoc to-zen <staged folder> <output>.utoc --version <UE version enum>
   ```
   This alone is enough — **do NOT go further and try to hand-edit the resulting container's own
   internal mount point via `retoc unpack-raw`/`pack-raw`** (a real, exposed feature — the two
   commands round-trip a container through a plain, hand-editable `manifest.json` with its own
   `mount_point` field) **unless you have a specific, confirmed reason to need it.** `to-zen` hardcodes
   the container's own internal mount point to the game's own default root convention
   (`../../../`) with no CLI flag to override it — a real, confirmed limitation of the public tool
   (independently corroborated: another modder, working on an unrelated UE5 game, hit and diagnosed
   this exact same limitation, going as far as recompiling their own patched copy of `retoc` to expose
   it). It turned out not to matter for the working recipe below (an override resolves fine with the
   plain default root mount point) — and forcing a different one via the raw-chunk round-trip
   introduced a real, confirmed corruption: the container's own `ContainerHeader` chunk gets copied
   across VERBATIM from the original build, but its identity is tied to the ORIGINAL container's own
   ID, which changes on rebuild — the result is a `.utoc` that reports success from `retoc info` (it
   doesn't check header/ID consistency) but throws a hard, specific error the moment a real parser
   (FModel/CUE4Parse) tries to actually resolve anything in it:
   `KeyNotFoundException: Couldn't find chunk 0x<newId> | 6` (chunk type `6` is the ContainerHeader
   itself). **Confirming a container is genuinely sound before trusting it in-game**: open it in
   FModel and browse to the asset — a clean read with no exceptions is real evidence; `retoc info`
   succeeding is not, since it never cross-checks the header's own embedded identity against the
   container's actual one.
5. **Build the sidecar `.pak` with `repak`, not `retoc`'s own bundled one, and not the game's bundled
   `UnrealPak.exe`.** A Zen/IoStore mod's own tiny companion `.pak` file (alongside its real
   `.utoc`/`.ucas` payload) legitimately has ZERO file entries in its own index — confirmed by
   checking an already-installed, confirmed-working third-party content mod the exact same way — so
   an empty index is not itself a sign of a broken pak. What DOES matter and DOES differ: `retoc
   to-zen`'s own auto-generated `.pak` companion used mount point `../../../` (matching the game's own
   root container's convention), while the already-working installed mod's own `.pak` used mount
   point `/` instead. Building a fresh, empty `.pak` with the correct mount point is simple and safe:
   ```
   repak pack --mount-point "/" --version V11 <a genuinely empty directory>
   ```
   (`repak`'s own version-compatibility table tops out at V11/"Fnv64BugFix", covering UE 4.26 through
   at least 5.3 and "likely" later — confirmed working here on a UE 5.6 game.) This ONE repak-built
   empty `.pak`, reused verbatim as the sidecar for every different `.utoc`/`.ucas` payload built this
   way, was sufficient — no per-asset regeneration needed, since it never has any real content of its
   own regardless of what it accompanies.
6. **Install as `<GameContentRoot>/Paks/<AnyModName>/<AnyModName>-Windows.{pak,ucas,utoc}`** — the
   same subfolder-per-mod layout already confirmed elsewhere in this file (§11) to auto-mount
   recursively with no manifest registration needed. **Requires a full game relaunch, not a hot
   reload** — pak/container mounting only happens at startup (§11, reconfirmed here).

### 19c-3. New asset paths are not discoverable; overriding an existing path works cleanly

This is the single most important finding from the whole investigation, and the reason step 3 above
matters: **a genuinely brand-new package path — one that never existed anywhere in the original,
shipped game — could not be made to resolve from Lua (`resolveAsset`/`LoadAsset` reported a clean
miss, not an error) no matter how correctly-formed the container was**, confirmed against a
container built the exact same clean way that DOES work for an override (see below) — ruling out
container malformation as the explanation. **Overriding an EXISTING, already-known asset path — same
recipe, only the target/package-name choice differs — worked immediately and completely**: editing a
real character's own real "Group" asset in place (same filename, same internal `PackageName`, no
duplication at all) to retarget one of its piece references to a completely different family's
piece, packaging THAT, and simply letting the character's own untouched, already-shipped top-level
outfit asset go on referencing it by the same path it always has — produced the character wearing
the swapped piece, fully, correctly, on the very first clean-container attempt, with zero runtime
Lua code changes of any kind (no `compositeLook` override, no `StaticConstructObject`, nothing — she
was spawned via this mod's completely ordinary, pre-existing spawn path, and simply looked different
because the file the engine reads for her outfit now contains different data).
The most likely underlying reason (not independently confirmed, but consistent with all
observations): a Shipping-cooked UE5 game commonly resolves packages against a manifest/global name
map baked in at COOK TIME, not by discovering arbitrary new content dynamically at runtime — a path
already in that baked catalog resolves regardless of which container currently supplies its bytes
(that's the entire mechanism every already-installed third-party content mod in this game relies on),
but a path that was never in it in the first place has nothing for a bare string-path load to find,
even inside an otherwise perfectly valid container.
**Practical consequence for building a genuinely custom archetype/outfit**: it cannot be a brand-new
asset at a brand-new path. It has to live at the path of some existing, already-referenced asset — in
practice, this means picking a real existing character/NPC (or a rarely-used/little-noticed one, to
minimize unwanted side effects) and overriding ITS OWN outfit-group asset, rather than authoring
something wholly new and independent. This is a real constraint on the design, not just an
implementation detail — any custom-outfit feature built this way is fundamentally "reskin an existing
identity," never "add a new one," for as long as this constraint holds.

### 19c-4. A real third-party counter-example investigated exhaustively — same conclusion holds; the wall is the TOOLING, not the engine

A separate, independently-installed third-party mod was found shipping a package at a path that
provably does not exist anywhere in the base game (confirmed directly against the same asset catalog
used throughout this file, not assumed) — genuinely new content, apparently working. This looked like
a real counter-example to §19c-3 and was investigated exhaustively rather than dismissed:

- The mod's own Lua never resolves its new class by path at all — it only watches for the ENGINE
  itself to construct a live instance (a UE4SS `NotifyOnNewObject`-style listener), then reacts.
  Something else has to be doing the actual first load.
- That "something else" turned out to be a well-known, engine-native "Blueprint mod" convention: a
  bundled UE4SS component watches a SPECIFIC folder (`Content/Paks/LogicMods/`, one subfolder per
  mod, each carrying its own small `config.lua` naming the class to load) and, for each pak found
  there, resolves the class via `AssetRegistryHelpers:GetAsset({PackageName=.., AssetName=..})` — a
  different, higher-level API than the plain `StaticFindObject`/`LoadObject` combo used everywhere
  else in this investigation — then explicitly spawns one instance itself.
- Every element of that convention was reproduced exactly and tested directly, one variable at a
  time, ruling each one out in turn: the sidecar `.pak`'s own mount point: no effect. The container's
  own internal mount point: no effect (and hand-patching it introduces real corruption risk, see
  §19c-2 step 4 — not needed for an override, and didn't help here either). The `GetAsset` API in
  place of `StaticFindObject`/`LoadObject`: no effect — it also depends on the target already being
  known, it isn't itself a magic loader. The `LogicMods` folder, flat: no effect. The `LogicMods`
  folder, correctly nested one-subfolder-per-mod with its own `config.lua`, exactly matching the
  working mod's own layout: no effect — the SAME native tool (`GetAsset`, called by the SAME bundled
  loader component, not by this investigation's own Lua) still reported the identical "not valid"
  failure for a duplicated real `DataAsset` at this new path. Asset TYPE (a plain `DataAsset` object
  vs. a genuine Blueprint ACTOR CLASS): no effect either — repeating the exact same test with a
  duplicated, repathed Blueprint actor class (not a data object) still produced the IDENTICAL
  "ModClass ... is not valid" failure, through the exact same native mechanism, at a genuinely new
  path with zero base-game references.
- Every controllable variable was matched to the working mod's own setup and still failed
  identically. The one variable that couldn't be controlled or matched: HOW the working mod's own
  package was actually built. Its own public source repository's own build documentation was found
  and checked directly rather than left as a guess — it states plainly: "The LogicMods .pak, .utoc,
  and .ucas files are cooked Unreal artifacts. They require a compatible <Game>/Unreal development
  environment and are not reproducible in a generic GitHub Actions runner." This rules out the
  simplest theory (a fully generic, game-agnostic Unreal project with zero game-specific setup) —
  but does NOT mean the author had the target game's own proprietary source either, which is not
  realistic for a commercial game's modding community. The much more plausible reconciliation: an
  SDK-stub-based modding setup — generating C++ header stubs for the target game's own reflected
  native classes (a real, established technique; tools like Dumper-7 do exactly this by inspecting a
  RUNNING game's own reflection data, no source access needed at all) and building a SEPARATE Unreal
  project against those generated stubs, so the editor can compile and cook content that references
  or even derives from the target game's own native types, without ever touching the game's actual
  proprietary implementation. That is what "a compatible <Game>/Unreal development environment"
  most plausibly describes — genuinely game-specific setup, but built from the game's own PUBLICLY
  INSPECTABLE reflection data, not from anything only the original developer would have.
  Whichever exact variant it was, the same underlying point holds: a REAL Unreal Editor cook, of
  SOME kind, is what bakes the Asset Registry metadata a new package needs to be discoverable — the
  tool chain in §19c-2 (`retoc` converting already-cooked bytes between Zen and Legacy format,
  `UAssetGUI` hand-editing the result) can duplicate an EXISTING package's structure byte-for-byte —
  exactly why overriding an existing path works flawlessly — but it never performs a real cook, so it
  cannot fabricate the registry metadata a genuine cook generates for a package that never existed
  before.
  **This draws a real, usable line, and it may be wider than it first looks**: an SDK-stub-based
  project needs the game's reflected CLASS LAYOUT (property names/types/offsets, generatable from a
  running game with no source access, exactly what tools like Dumper-7 produce), not its underlying
  C++ IMPLEMENTATION. Authoring a new instance of a plain DATA class (setting property values in the
  Editor's own asset-creation UI) only ever needs that layout — the actual game-specific COMPILED
  LOGIC is irrelevant to a DataAsset, which has none of its own. That means this route is NOT
  necessarily limited to purely generic/vanilla content the way a first pass at this reasoning
  suggests — it could plausibly extend to authoring genuinely NEW instances of this investigation's
  own actual target classes too (`R5CompositeMeshComponentBaseParams`/`R5CompositeMeshGroup`/etc.),
  since those are exactly the same kind of plain, logic-free reflected data classes. What it almost
  certainly CANNOT do is author new instances of a class whose own COMPILED BEHAVIOR matters (a
  native Actor/Component with real gameplay logic baked into its C++, not just data fields) — for
  those, only the class's layout is knowable this way, not what it actually DOES at runtime, which
  matters far more for something like a working Blueprint Actor than for a static outfit-params
  asset.

**Conclusion, now tested far past the point of reasonable doubt with the tools actually used today**:
within THIS session's toolset (byte-level conversion/editing of already-cooked assets, no real Editor
cook pipeline of any kind), a wholly new, independent asset path cannot be made discoverable at
runtime by any means found — not a different resolution API, not a different install location/
convention, not a different asset type. Overriding an existing, already-referenced path remains the
one proven, reliable, repeatable way to ship custom content with these specific tools, and is what
this whole investigation's own working recipe (§19c-2/§19c-3) is built on.
A genuinely different, NOT YET ATTEMPTED path was identified and reasoned through, not just
theorized in the abstract: building an SDK-stub-based Unreal Editor project (generating C++ header
stubs for this game's own reflected native classes via a tool like Dumper-7, no source access
needed, then authoring and cooking new content against those stubs in a real, separate editor
project) would very plausibly let a genuinely new asset — for a plain data class, quite possibly
even this game's own proprietary composite-outfit classes specifically — become properly discoverable
at runtime, since a real cook is what bakes the Asset Registry metadata this whole investigation
found missing every other way. This is a substantially bigger undertaking than anything in this
session (a full Editor install, an SDK/stub generation pass, Visual Studio, real Unreal project
setup) and was not pursued — worth returning to as a real, credible next step if the "reskin an
existing identity" constraint ever becomes a genuine limitation worth the extra tooling investment.

**2026-08-29 update — this path has since been validated, not just theorized.** UE4SS ships its own
`GenerateSDK()`/`GenerateUHTCompatibleHeaders()` functions built in (no external Dumper-7 needed);
LivingBase wraps them as `lbgeneratesdk`/`lbgenuhtheaders` (see `main.lua`). A minimal standalone
UE 5.6 project was built against the resulting header stubs for `R5CompositeMeshComponentBaseParams`/
`R5CompositeMeshGroup`/`R5CompositeMeshComponentRandomizedSection`, compiled clean, and opened in the
real Editor — the Content Browser's Data Asset picker genuinely lists these Windrose classes as
instantiable asset types alongside native engine ones. One gotcha for anyone repeating this: the
dumper's own `//CROSS-MODULE INCLUDE V2: ...` lines are informational COMMENTS, not real `#include`
directives — add the real includes by hand (the referenced type's own header) wherever the dump
mentions one. Full detail on this track lives in a separate project memory file, not duplicated here
since it's a different environment (real Editor/C++, not UE4SS/Lua) — a dedicated "Windrose Unreal
SDK Modding Notes" doc is planned once this track resumes properly rather than blending the two.

**2026-08-31 update — the new-path wall (SS19c-3) is BROKEN THROUGH, and the actual mechanism is now
fully understood, not just a validated theory.** A real `R5CompositeMeshGroup` instance, authored and
cooked by the SDK-stub project above, then packaged the exact same retoc/repak way as every other
content pak in this file, was made genuinely resolvable at runtime -- confirmed live, both via
`AssetRegistryHelpers:GetAsset()` and (after a one-line fix, below) via this mod's own
`resolveAsset`/`Spawner.SetCompositeParams` pipeline. Two things had to both be true, and neither
alone was sufficient:
1. **The package must live under `/Game/Mods/...`, not an arbitrary new top-level folder.** The
   IDENTICAL asset, cooked and packaged by the IDENTICAL toolchain, resolved at
   `/Game/Mods/LivingBaseExtended/DA_Test_Group2` and missed at `/Game/LBE/DA_Test_Group` -- the
   only variable that changed was the path. This strongly implies Windrose's own cook process
   whitelists `/Game/Mods/` specifically to support the LogicMods third-party-mod convention (the
   same folder `BPModLoaderMod`/Pirate Signals already use) -- not a general "any new path works if
   cooked properly" result. **A genuinely new package needs BOTH a real Editor cook (SS19c-4's own
   finding -- byte-hacked retoc/UAssetGUI content never works regardless of path) AND a
   `/Game/Mods/...` path.** Confirmed directly against a real third-party counter-example too: Pirate
   Signals' own transport pak (`/Game/Mods/WindroseChatTransport/ModActor`) was installed and probed
   with this mod's own tools and resolved cleanly via the same API -- it was never actually confirmed
   to work by this investigation before this session, only assumed from its Nexus description.
2. **`StaticFindObject`/`LoadAsset` (what `resolveAsset` already used) still cannot see a package
   under `/Game/Mods/...` even once it's confirmed resolvable -- only `AssetRegistryHelpers:GetAsset()`
   can.** These are genuinely different resolution paths reaching different internal state, not two
   ways of asking the same question. **Fix, now shipped**: `resolveAsset` (`spawner.lua`) falls back to
   `AssetRegistryHelpers:GetAsset()` when `StaticFindObject`/`LoadAsset` both miss, splitting the input
   path into `PackageName`/`AssetName` on the last dot. This is a one-line-of-behavior fix to a single
   shared helper, so it transparently fixes `SetCompositeParams`/`DeCorrupt`/every other caller for
   `/Game/Mods/` content, not just the diagnostic test commands.
**Net effect**: authoring genuinely NEW Windrose content (not just overriding an existing path) is a
solved problem now, for plain data classes, provided it's packaged under `/Game/Mods/...`. The
remaining, still-untested step is populating a real `R5CompositeMeshComponentBaseParams` (the TOP
level, not the `R5CompositeMeshGroup` used for this discoverability test -- `compositeLook.params`
feeds `comp.DefaultParams`, which expects a BaseParams object specifically, confirmed live: handing it
a Group instead produces a technically-successful resolve but a fully nude build, since a Group has no
`CustomizationData` to read) with real piece references and confirming a genuinely custom outfit
renders end to end.

### 19d. A related, already-proven primitive worth remembering here

§2d's `Spawner.SetBodyPartMesh` already established the working recipe for swapping ONE
`BuildedCompositeMeshes` slot post-build: hide → `SetSkeletalMeshAsset` (fallback `SetSkeletalMesh`)
→ **`SetLeaderPoseComponent`** rebind to the actor's own body mesh → show. `SetLeaderPoseComponent`
is therefore NOT new/unproven engine surface the way this section's other findings are — it was
already a working, shipped technique before this investigation started; worth checking this file
before treating a call as untested just because it's new to the specific feature being built.
