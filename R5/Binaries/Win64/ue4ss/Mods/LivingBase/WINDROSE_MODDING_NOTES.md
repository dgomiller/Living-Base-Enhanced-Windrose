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
