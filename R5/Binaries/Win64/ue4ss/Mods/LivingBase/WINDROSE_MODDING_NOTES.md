# Windrose Modding — Hard-Won Knowledge (2026-07-09)

Durable facts learned building LivingBase. Written so a fresh session can pick up cold.
Companion to `CLAUDE.md` (which is older and partly stale — trust THIS file where they disagree).

---

## Table of contents

- [1. Spawning an actor that actually works](#1-spawning-an-actor-that-actually-works)
- [2. The composite (appearance) system — what sticks and what doesn't](#2-the-composite-appearance-system-what-sticks-and-what-doesnt)
  - [2a. Post-build: a genuine ENGINE FUNCTION can work where a raw property write can't (2026-08-15)](#2a-post-build-a-genuine-engine-function-can-work-where-a-raw-property-write-cant-2026-08-15)
  - [2b. Related tricks that fell out of the same investigation](#2b-related-tricks-that-fell-out-of-the-same-investigation)
  - [2c. A SECOND struct shape exists — and it's the one that finally unlocked writable per-piece customization (2026-08-19)](#2c-a-second-struct-shape-exists-and-its-the-one-that-finally-unlocked-writable-per-piece-customization-2026-08-19)
  - [2d. `BuildedCompositeMeshes` — a second, always-populated mesh-attachment layer (2026-08-19)](#2d-buildedcompositemeshes-a-second-always-populated-mesh-attachment-layer-2026-08-19)
- [2e. Anatomy of a full NPC, confirmed via a comprehensive live probe (2026-08-31)](#2e-anatomy-of-a-full-npc-confirmed-via-a-comprehensive-live-probe-2026-08-31)
- [3. THE CRASH TRAPS (each cost hours)](#3-the-crash-traps-each-cost-hours)
  - [3a. Stale UObject pointers — the big one](#3a-stale-uobject-pointers-the-big-one)
  - [3b. Log BEFORE the dangerous call, never after](#3b-log-before-the-dangerous-call-never-after)
  - [3c. Component surgery during world load](#3c-component-surgery-during-world-load)
  - [3d. Spawning into a not-yet-live world](#3d-spawning-into-a-not-yet-live-world)
  - [3e. Two composite builds in one frame](#3e-two-composite-builds-in-one-frame)
  - [3f. `StaticFindObject("/Script/R5.<Component>")` — NOT universally broken](#3f-staticfindobjectscriptr5component-not-universally-broken)
  - [3g. `RegisterKeyBind` is only safe during the initial mod-load pass](#3g-registerkeybind-is-only-safe-during-the-initial-mod-load-pass)
  - [3h. A function existing in the object dump doesn't mean it's safe to call (2026-08-15)](#3h-a-function-existing-in-the-object-dump-doesnt-mean-its-safe-to-call-2026-08-15)
  - [3i. `SetActorLocation`/`SetActorRotation` on a Static-mobility component silently no-ops visually (2026-08-16)](#3i-setactorlocationsetactorrotation-on-a-static-mobility-component-silently-no-ops-visually-2026-08-16)
  - [3j. A function "safe" at keyboard-driven call rates isn't necessarily safe at UI-driven rates (2026-08-16)](#3j-a-function-safe-at-keyboard-driven-call-rates-isnt-necessarily-safe-at-ui-driven-rates-2026-08-16)
  - [3k. A function defined BEFORE a `local function` it calls silently binds to a global instead (2026-08-18)](#3k-a-function-defined-before-a-local-function-it-calls-silently-binds-to-a-global-instead-2026-08-18)
  - [3l. INVOKING an unfamiliar UFunction is real crash risk, even when it looks simple (2026-08-21)](#3l-invoking-an-unfamiliar-ufunction-is-real-crash-risk-even-when-it-looks-simple-2026-08-21)
  - [3m. A UFunction's OWN Lua return value can be meaningless — check pcall's success, not the function's return (2026-08-21)](#3m-a-ufunctions-own-lua-return-value-can-be-meaningless-check-pcalls-success-not-the-functions-return-2026-08-21)
  - [3n. `LineTraceSingle`'s channel argument is a DIFFERENT enum than `SetCollisionResponseToChannel`'s (2026-08-21)](#3n-linetracesingles-channel-argument-is-a-different-enum-than-setcollisionresponsetochannels-2026-08-21)
  - [3o. Comparing two independently-fetched actor/object handles with `==` is unreliable, even for the identical underlying object (recurring)](#3o-comparing-two-independently-fetched-actorobject-handles-with-is-unreliable-even-for-the-identical-underlying-object-recurring)
  - [3p. A property write can succeed with zero pcall error yet have no lasting (or any) visible effect, if a native settings/params system re-asserts it (2026-08-22)](#3p-a-property-write-can-succeed-with-zero-pcall-error-yet-have-no-lasting-or-any-visible-effect-if-a-native-settingsparams-system-re-asserts-it-2026-08-22)
  - [3q. How UE4SS actually counts arguments for a raw UFunction call with a return value (2026-08-21)](#3q-how-ue4ss-actually-counts-arguments-for-a-raw-ufunction-call-with-a-return-value-2026-08-21)
  - [3r. A generic `ForEachProperty` walk over `FAssetData` is safe for one asset class and a real crash for another (2026-08-31)](#3r-a-generic-foreachproperty-walk-over-fassetdata-is-safe-for-one-asset-class-and-a-real-crash-for-another-2026-08-31)
- [4. Restore-on-load design (why it looks the way it does)](#4-restore-on-load-design-why-it-looks-the-way-it-does)
- [5. Peace / faction mechanics](#5-peace-faction-mechanics)
- [5b. Movement: THIS GAME DOES NOT USE THE UE NAVMESH](#5b-movement-this-game-does-not-use-the-ue-navmesh)
- [6. Workflow that works](#6-workflow-that-works)
- [7. Useful class paths](#7-useful-class-paths)
- [7b. Reacting to things the GAME spawns](#7b-reacting-to-things-the-game-spawns)
- [8. Drowned / night-raid scouting (2026-07-09, not yet built)](#8-drowned-night-raid-scouting-2026-07-09-not-yet-built)
- [9. Cross-skeleton re-skinning: what actually determines the result (2026-08-10)](#9-cross-skeleton-re-skinning-what-actually-determines-the-result-2026-08-10)
  - [9c. Mechanically discovering EVERY asset of a kind: a folder-shape assumption is never provably exhaustive (2026-08-17/18)](#9c-mechanically-discovering-every-asset-of-a-kind-a-folder-shape-assumption-is-never-provably-exhaustive-2026-08-1718)
- [10. The per-world identifier (2026-08-13)](#10-the-per-world-identifier-2026-08-13)
- [11. Content-replacer paks (asset overrides): what's possible from Lua and what isn't (2026-08-13)](#11-content-replacer-paks-asset-overrides-whats-possible-from-lua-and-what-isnt-2026-08-13)
- [12. Compiled C++ UE4SS mods (not Lua): rendering an interactive overlay safely (2026-08-16)](#12-compiled-c-ue4ss-mods-not-lua-rendering-an-interactive-overlay-safely-2026-08-16)
  - [12a. A relative path resolves against the GAME's working directory, in C++ too](#12a-a-relative-path-resolves-against-the-games-working-directory-in-c-too)
  - [12b. Hooking a DXGI/D3D vtable function: `x64Detour`, never a raw vtable swap](#12b-hooking-a-dxgid3d-vtable-function-x64detour-never-a-raw-vtable-swap)
  - [12c. Capture the REAL command queue by hooking swapchain creation, not by guessing](#12c-capture-the-real-command-queue-by-hooking-swapchain-creation-not-by-guessing)
  - [12d. This game's DLSS-G (NVIDIA Streamline) frame generation breaks a naive swapchain-Present](#12d-this-games-dlss-g-nvidia-streamline-frame-generation-breaks-a-naive-swapchain-present)
  - [12e. A standalone window on its own thread is a safe, working alternative to hooking Present](#12e-a-standalone-window-on-its-own-thread-is-a-safe-working-alternative-to-hooking-present)
  - [12g. `GImGui` is a single global — two ImGui contexts/threads in one DLL is not safe by default](#12g-gimgui-is-a-single-global-two-imgui-contextsthreads-in-one-dll-is-not-safe-by-default)
  - [12h. Minidump analysis without a full debugger install: extract `cdb.exe` from the WinDbg Store package](#12h-minidump-analysis-without-a-full-debugger-install-extract-cdbexe-from-the-windbg-store-package)
  - [12i. A mutex around one race can hide a second, independent race behind it](#12i-a-mutex-around-one-race-can-hide-a-second-independent-race-behind-it)
  - [12j. `RegisterKeyBind` only fires while the GAME window has OS focus — stealing focus programmatically can break a "press again to undo" key](#12j-registerkeybind-only-fires-while-the-game-window-has-os-focus-stealing-focus-programmatically-can-break-a-press-again-to-undo-key)
  - [12k. Not every `UGameViewportClient` property is reachable from Lua reflection, even when it visibly exists on the class](#12k-not-every-ugameviewportclient-property-is-reachable-from-lua-reflection-even-when-it-visibly-exists-on-the-class)
  - [12l. Toolchain / project shape for a compiled UE4SS C++ mod](#12l-toolchain-project-shape-for-a-compiled-ue4ss-c-mod)
  - [12m. A toggle reachable from BOTH the game and a companion C++ window needs ONE owner, not two (2026-08-18)](#12m-a-toggle-reachable-from-both-the-game-and-a-companion-c-window-needs-one-owner-not-two-2026-08-18)
  - [12n. Constructing real UMG widgets natively from C++ — the same primitives a Lua UMG binding uses, just called directly (2026-08-22)](#12n-constructing-real-umg-widgets-natively-from-c-the-same-primitives-a-lua-umg-binding-uses-just-called-directly-2026-08-22)
  - [12o. A property's "official" C++ accessor can resolve through a WRONG vtable offset for a specific game build, and crash uncatchably — prefer a raw memory write when the layout is simple and known (2026-08-22)](#12o-a-propertys-official-c-accessor-can-resolve-through-a-wrong-vtable-offset-for-a-specific-game-build-and-crash-uncatchably-prefer-a-raw-memory-write-when-the-layout-is-simple-and-known-2026-08-22)
  - [12p. Binding a native multicast delegate (e.g. UMG's `OnClicked`) from C++, avoiding the same vtable risk as §12o (2026-08-22)](#12p-binding-a-native-multicast-delegate-eg-umgs-onclicked-from-c-avoiding-the-same-vtable-risk-as-12o-2026-08-22)
  - [12q. An inherited UFUNCTION can intermittently fail to resolve on an otherwise-valid, freshly-constructed object, for reasons not fully root-caused — build self-healing verification, not just an existence/liveness check (2026-08-23)](#12q-an-inherited-ufunction-can-intermittently-fail-to-resolve-on-an-otherwise-valid-freshly-constructed-object-for-reasons-not-fully-root-caused-build-self-healing-verification-not-just-an-existenceliveness-check-2026-08-23)
  - [12r. Before claiming a native keybind, audit EVERY installed mod's key configuration, not just your own mod's (2026-08-22)](#12r-before-claiming-a-native-keybind-audit-every-installed-mods-key-configuration-not-just-your-own-mods-2026-08-22)
  - [12s. A native post-hook scoped to one instance can still fire from unrelated causes — the mechanism isn't the risk, the CHOICE of bound function is (2026-08-23)](#12s-a-native-post-hook-scoped-to-one-instance-can-still-fire-from-unrelated-causes-the-mechanism-isnt-the-risk-the-choice-of-bound-function-is-2026-08-23)
  - [12t. `GetAsyncKeyState` can be completely blind to mouse buttons in a specific game process while keyboard keys work perfectly through the identical call — and a framework's OWN input pipeline can silently share that same blind spot (2026-08-23)](#12t-getasynckeystate-can-be-completely-blind-to-mouse-buttons-in-a-specific-game-process-while-keyboard-keys-work-perfectly-through-the-identical-call-and-a-frameworks-own-input-pipeline-can-silently-share-that-same-blind-spot-2026-08-23)
  - [12u: Never mutate or rebuild a widget tree synchronously from inside a native UFUNCTION hook's callback — it can hang the game, not crash it (2026-08-23)](#12u-never-mutate-or-rebuild-a-widget-tree-synchronously-from-inside-a-native-ufunction-hooks-callback-it-can-hang-the-game-not-crash-it-2026-08-23)
  - [12v: A panel's own "clear all children" UFUNCTION can silently do nothing live, even though it resolves and returns cleanly — track what you added and remove it explicitly instead (2026-08-23)](#12v-a-panels-own-clear-all-children-ufunction-can-silently-do-nothing-live-even-though-it-resolves-and-returns-cleanly-track-what-you-added-and-remove-it-explicitly-instead-2026-08-23)
  - [12w: Combining a broad-but-reliable native signal with a cheap, independent, per-instance filter beats hunting for a "perfectly exclusive" one (2026-08-23)](#12w-combining-a-broad-but-reliable-native-signal-with-a-cheap-independent-per-instance-filter-beats-hunting-for-a-perfectly-exclusive-one-2026-08-23)
  - [12x: A C++ mod's `on_update()` call rate can silently decay from ~180/sec to ~1/sec over the first ~90 seconds of every session, for a cause not yet root-caused — and Lua's `ExecuteWithDelay` timing is NOT a reliable proxy for whether it's affected (2026-08-23)](#12x-a-c-mods-on_update-call-rate-can-silently-decay-from-180sec-to-1sec-over-the-first-90-seconds-of-every-session-for-a-cause-not-yet-root-caused-and-luas-executewithdelay-timing-is-not-a-reliable-proxy-for-whether-its-affected-2026-08-23)
  - [12y: A generated integration manifest is only as complete as its OWN translation table — adding a new value to the primary consumer doesn't automatically reach a SECONDARY one (2026-08-24)](#12y-a-generated-integration-manifest-is-only-as-complete-as-its-own-translation-table-adding-a-new-value-to-the-primary-consumer-doesnt-automatically-reach-a-secondary-one-2026-08-24)
- [13. Placing an actor relative to a moving ship (2026-08-25)](#13-placing-an-actor-relative-to-a-moving-ship-2026-08-25)
- [14. Playing a specific canned animation on a live Character](#14-playing-a-specific-canned-animation-on-a-live-character)
- [15. `ExecuteWithDelay`'s callback does not run on the game thread — and nesting it inside `ExecuteInGameThread` is its own separate, differently-broken thing](#15-executewithdelays-callback-does-not-run-on-the-game-thread-and-nesting-it-inside-executeingamethread-is-its-own-separate-differently-broken-thing)
- [16. Comparing two independently-obtained component references with `==` is unreliable in this UE4SS build — compare `GetFName():ToString()` instead](#16-comparing-two-independently-obtained-component-references-with-is-unreliable-in-this-ue4ss-build-compare-getfnametostring-instead)
- [17. Windrose Mod Settings CAN probably render a real slider ("scalar") and dropdown ("discrete") widget — a single unconfirmed exploratory test, not a proven, ready-to-use recipe (2026-08-29)](#17-windrose-mod-settings-can-probably-render-a-real-slider-scalar-and-dropdown-discrete-widget-a-single-unconfirmed-exploratory-test-not-a-proven-ready-to-use-recipe-2026-08-29)
- [18. Line-trace-based targeting: object-type queries aren't a strict superset of channel-based ones, and a "does this component exist" check needs `:IsValid()`, not `~= nil`](#18-line-trace-based-targeting-object-type-queries-arent-a-strict-superset-of-channel-based-ones-and-a-does-this-component-exist-check-needs-isvalid-not-nil)
- [19. Constructing a composite outfit from scratch: the real 3-level asset structure, what's safe to build via Lua, and what crashes (2026-08-29)](#19-constructing-a-composite-outfit-from-scratch-the-real-3-level-asset-structure-whats-safe-to-build-via-lua-and-what-crashes-2026-08-29)
  - [19a. The real structure, confirmed via direct asset-JSON exports (not a live probe this time)](#19a-the-real-structure-confirmed-via-direct-asset-json-exports-not-a-live-probe-this-time)
  - [19b. What's actually constructible from Lua — confirmed piece by piece, live](#19b-whats-actually-constructible-from-lua-confirmed-piece-by-piece-live)
  - [19c-2. The actual working recipe, found once the runtime approach was abandoned: edit a REAL asset offline, don't construct one at runtime](#19c-2-the-actual-working-recipe-found-once-the-runtime-approach-was-abandoned-edit-a-real-asset-offline-dont-construct-one-at-runtime)
  - [19c-3. New asset paths are not discoverable; overriding an existing path works cleanly](#19c-3-new-asset-paths-are-not-discoverable-overriding-an-existing-path-works-cleanly)
  - [19c-4. A real third-party counter-example investigated exhaustively — same conclusion holds; the wall is the TOOLING, not the engine](#19c-4-a-real-third-party-counter-example-investigated-exhaustively-same-conclusion-holds-the-wall-is-the-tooling-not-the-engine)
  - [19d. A related, already-proven primitive worth remembering here](#19d-a-related-already-proven-primitive-worth-remembering-here)
  - [19e. Evaluated and rejected: Nexus Mods' own "Nexus Mods Author Tools" Editor plugin](#19e-evaluated-and-rejected-nexus-mods-own-nexus-mods-author-tools-editor-plugin)
  - [19f. SkinMaterials (the "Size" dimension) -- build started 2026-09-02](#19f-skinmaterials-the-size-dimension----build-started-2026-09-02)
  - [19g. The manual UAssetGUI retarget step is no longer manual (2026-09-02)](#19g-the-manual-uassetgui-retarget-step-is-no-longer-manual-2026-09-02)
  - [19h. SkinMaterials rolled out to all 30 remaining male-source templates (2026-09-02)](#19h-skinmaterials-rolled-out-to-all-30-remaining-male-source-templates-2026-09-02)
  - [19i. Full female rollout + a genuinely new architecture: sourceless "prepping for the future" entries (2026-09-02)](#19i-full-female-rollout-a-genuinely-new-architecture-sourceless-prepping-for-the-future-entries-2026-09-02)
  - [19j. A genuinely new alternative to reskinning: swap the AI brain instead, keep the real body (2026-09-02)](#19j-a-genuinely-new-alternative-to-reskinning-swap-the-ai-brain-instead-keep-the-real-body-2026-09-02)
  - [19k. RedFalcon's own reframe wins: swap the WALKER's body, not the mob's brain (2026-09-02)](#19k-redfalcons-own-reframe-wins-swap-the-walkers-body-not-the-mobs-brain-2026-09-02)
  - [19l. Checking whether the vanilla human mesh truly lacks Senkamati's pelvis geometry -- two more offline dead ends, and the one path that actually works (2026-09-02)](#19l-checking-whether-the-vanilla-human-mesh-truly-lacks-senkamatis-pelvis-geometry----two-more-offline-dead-ends-and-the-one-path-that-actually-works-2026-09-02)
  - [19m. "Barbies" -- the native-statue investigation dead-ends into the final answer, and the finalized unique-proportions roster (2026-09-02)](#19m-barbies----the-native-statue-investigation-dead-ends-into-the-final-answer-and-the-finalized-unique-proportions-roster-2026-09-02)
  - [19n. "Every slot filled" -- built, broke on sex-variance, fixed, confirmed live (2026-09-02)](#19n-every-slot-filled----built-broke-on-sex-variance-fixed-confirmed-live-2026-09-02)
  - [19o. Facial hair (Eyebrows/Mustache/Beard/Whiskers/Hairs) -- four real bugs stacked on top of each other, all found and fixed (2026-09-03)](#19o-facial-hair-eyebrowsmustachebeardwhiskershairs----four-real-bugs-stacked-on-top-of-each-other-all-found-and-fixed-2026-09-03)
  - [19p. Default to underwear with every slot still built, real belt Attachments (pouches/knife), and a genuine engine-crash found and guarded (2026-09-04)](#19p-default-to-underwear-with-every-slot-still-built-real-belt-attachments-pouchesknife-and-a-genuine-engine-crash-found-and-guarded-2026-09-04)
  - [19q. A full structural catalog of every real per-slot item in the game, built once, browsable forever (2026-09-04)](#19q-a-full-structural-catalog-of-every-real-per-slot-item-in-the-game-built-once-browsable-forever-2026-09-04)
  - [19r. Real baked alignment for hand-attached items, a hidden-but-still-solid collision bug, `lblook` vs `lbtestlook` finally disentangled, and a fill-every-socket test command (2026-09-04)](#19r-real-baked-alignment-for-hand-attached-items-a-hidden-but-still-solid-collision-bug-lblook-vs-lbtestlook-finally-disentangled-and-a-fill-every-socket-test-command-2026-09-04)
  - [19s. Belt is standalone; Sling/Strap are not -- a real dependency rule found by watching native NPCs (2026-09-07)](#19s-belt-is-standalone-slingstrap-are-not----a-real-dependency-rule-found-by-watching-native-npcs-2026-09-07)
  - [19t. `fillall`/`aps`/`lbsockets` grow sub-filters and a player-targeting mode; two more curated sockets; the real Belt/Sling/Strap linkage rule finished; and a random belt-layout roller (2026-09-05/07)](#19t-fillallapslbsockets-grow-sub-filters-and-a-player-targeting-mode-two-more-curated-sockets-the-real-beltslingstrap-linkage-rule-finished-and-a-random-belt-layout-roller-2026-09-0507)
  - [19u. `lbtestsocketitems` -- a full item/weapon randomizer driven entirely by a hand-authored spreadsheet (2026-09-07)](#19u-lbtestsocketitems----a-full-itemweapon-randomizer-driven-entirely-by-a-hand-authored-spreadsheet-2026-09-07)

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

**A related but DIFFERENT failure found 2026-09-01, initially misdiagnosed as this same wall, then
CONFIRMED as this same wall after all via direct repeated observation — corrected twice in one day.**
`BP_NPC_Citizen_Walker_C` was assumed to be a stable native-male Adventurer-family source (his
`GetBodyType()=Adventurer` had been confirmed via a probe, see §2e's own "Real class hierarchy" entry)
— but that probe was taken AFTER sex-changing him to Female, never in his native male state. Building
an `AdventurerMaleAsAfrican` template and testing it on him repeatedly never produced an African body.
A single genuine, untouched `lbprobedump` of his native state (predating any of this session's
BodyTypeParams work) read `GetBodyType() = Customization.Morph.BodyType.Native` — first taken as proof
he's simply Native family, not Adventurer, full stop (a wrong-tag problem, not a randomization
problem). That was too hasty: a single probe is one data point, and the exact same "looks stable from
one read" mistake had already produced a wrong conclusion twice before in this project (the statue
roster, and this class's own earlier "Adventurer" mislabel). Real confirmation came from repeated live
observation instead — spawning him fresh multiple times shows genuinely **different skin tones/
ethnicity families across spawns**, the same directly-observable tell already established for the
randomizing Standing/Sitting statue roster. **Conclusion: `BP_NPC_Citizen_Walker_C` re-rolls his
archetype family on `BeginPlay` regardless of native sex, the same reassertion wall as the Warrior —
he is not usable as a fixed BodyTypeParams source under ANY tag (Adventurer, Native, or otherwise),
not just the wrong one.** Do not build a template around him in any family. Isolated via the identical
male-retarget mechanism tested on Woodman (Scum family) instead — a source confirmed rock-stable
across 25 earlier female-tagged tests plus this new male one — which worked cleanly, confirming the
mechanism itself was never the problem, only the choice of source class. **Net: there is currently no
confirmed native-male Adventurer-family source, and Citizen Walker is not a candidate for one under any
tag** — Scum-male (Woodman/Miner/Farmer) remains the one confirmed-stable native-male source. A future
Adventurer-male source, if one exists, needs to be a DIFFERENT native-male NPC class, found by the same
repeated-spawn/skin-tone-variation check that closed this one out — a single probe is not sufficient
evidence of stability, only repeated observation across several fresh spawns is.

**Second same-day data point, forming a real pattern.** `BP_NPC_Citizen_Worker_C` (a different class,
same "Citizen" NPC family as Citizen Walker — he also blocks `IsBodySexChangeAvailable`, which is
unrelated to this and just meant the earlier sex-change-based `BodyMorph` comparison technique couldn't
be used on him) read `GetBodyType()=African` on one probe, then — checked properly this time, via
repeated fresh `lbspawn`s rather than trusting the single read — confirmed to ALSO re-roll his
archetype family across spawns, same as Citizen Walker. **Both known members of the "Citizen" NPC
family randomize on `BeginPlay`; neither is a usable BodyTypeParams source.** Treat any other
`BP_NPC_Citizen_*` class as suspect for the same reason until proven otherwise by the same repeated-
spawn check — don't spend time probing another one without doing that check first. By contrast, every
Handyman-family class tested (Gatherer/Herbalist/Woodman/Miner/Farmer/Hunter) and the one Employee-family
class tested (Rosalinda Mercer) have all held up as stable across dozens of repeated tests — those two
NPC FAMILIES (professions), not "Citizen," are where a future male source candidate is more likely to be
found.

**The real, generalized rule (2026-09-01, confirmed with 3 more data points the same day): stability
tracks "generic procedural family member" vs. "unique named individual," not the specific
Handyman/Employee/Citizen family label itself.** Four more native-male NPCs were checked the same
way — repeated fresh `lbspawn`s, watching for skin-tone/appearance variation, not a single probe:
`BP_NPC_Employee_WeaponStation_JasperCrowe_C` (Adventurer family, `SK_Adventurer_Male_01`),
`BP_NPC_Employee_CookingStation_BlackAxel_C` (Albion family, `SK_Albion_Male_01`),
`BP_NPC_MortarMan_C` (Native family, `SK_Native_Male_01`), and `BP_NPC_Ksant_C` (his own unique
`Customization.Morph.BodyType.Ksante` tag, `IsBodyTypeChangeAvailable=false`). All four are genuinely
UNIQUE, individually-named NPCs (not a generic "one of many workers" class the way Citizen Walker/
Worker are) — and all four hold rock-stable with zero appearance variation across repeated spawns,
same as Rosalinda/Letty/Marita before them. **The actual predictor is whether the class represents ONE
specific named character (stable) or a generic interchangeable "one of several" role (randomizes) —
Handyman/Employee/Citizen are just which folder happens to hold each kind, not the cause.** `Ksant`
specifically is confirmed unusable as a BodyTypeParams source regardless of stability
(`IsBodyTypeChangeAvailable=false` — no pool lookup exists to hijack), independent of this rule.

**`BodyMorph` (shape) comparison across all sources known so far, 2026-09-01** — the free lever this
project already established (§2e below): a source is only useful for real VARIETY if its `BodyMorph`
value is actually distinct from what's already covered, on top of being a stable, retargetable source.
| Source | Family | BodyMorph (X,Y,Z) | Distinct? |
|---|---|---|---|
| Gatherer / Rosalinda / Miner | Adventurer(F)/Albion(F)/Scum(M) | (0, 0, 1) | shared baseline |
| Herbalist | Adventurer (F) | (0, 0.618, 0.222) | yes |
| Woodman | Scum (M) | (0, 0.232, 0.226) | yes |
| Farmer | Scum (M) | (0, 0.311, 0.288) | yes |
| Senkamati Caster | Senkamati (F) | (0.5, 0, 0) | yes |
| Hunter | African (M) | (0, 0, 1) | **redundant** — matches Gatherer/Rosalinda/Miner exactly |
| Ksant | own/locked | (0, 0, 1) | redundant, and unusable as a source regardless |
| Jasper Crowe | Adventurer (M) | (0, 0.246, 0.250) | yes — close to Woodman's but distinct |
| Black Axel | Albion (M) | (0, 0.580, 0.309) | yes — close to Herbalist's Y but distinct on Z |
| MortarMan | Native (M) | (0, 1.0, 0.0) | yes — the most distinct new value found |
Citizen Walker's own (0, 0.919, 0.040), while a real reading, is moot — he's disqualified as a source
entirely regardless of shape. **Net: Jasper (Adventurer-male) and Black Axel (Albion-male) are the two
most valuable new confirmed-stable sources** — they close the exact family gaps this session's own
male-source search was chasing AND add genuine shape variety. MortarMan adds a wholly new shape value
if a Native-family male source is wanted. Hunter, while a legitimate stable African-family source, adds
no new shape — lower priority unless family coverage alone (not shape variety) is the goal.

**CONFIRMED LIVE, 2026-09-01: HunterAsOrient, JasperAsAfrican, AxelAsAfrican, and MortarAsAfrican all
work.** Built via the same offline SDK-stub Editor pipeline as every prior template (§2e/§19c below),
but for the first time this session, driven end-to-end headlessly via `UnrealEditor-Cmd.exe -run=
pythonscript`/`-run=cook` directly from the command line rather than the interactive Editor GUI for
the authoring/cook steps — only the two genuinely GUI-only steps (the `GameplayTag` property-picker,
confirmed yet again this session that headless Python cannot construct one from a string under any
call shape tried, including the plain `unreal.GameplayTag(value=...)` struct constructor; and the
`BodyMesh` retarget via UAssetGUI) still needed manual work. Jasper and Axel needed ZERO manual tag
work at all — duplicated from `AdventurerMaleAsAfrican`/`AlbionAsAfrican` (already correctly tagged),
same scaling insight already established. `Customization.Morph.BodyType.African` and `.Native` are
now both registered tags, alongside the original Adventurer/Albion/Scum/Senkamati four. **Full
confirmed native-male source roster now**: Scum (Woodman/Miner/Farmer), Adventurer (Jasper Crowe),
Albion (Black Axel), Native (MortarMan), African (Hunter, shape-redundant but family-complete).
**Real environment gotcha hit along the way, worth remembering for any future headless Editor work
on this project**: a C++ project living under an OneDrive-synced folder can intermittently fail
`UnrealBuildTool -Clean`/rebuild with "Unable to delete" errors on `Intermediate/Build` subfolders —
OneDrive transiently locks files it's scanning/syncing. Closing OneDrive (or just retrying the delete
a few times) resolves it; it is NOT a real build/permission problem. Separately, a PARTIAL module
rebuild (only one of `LivingBaseExtended`/`R5`/`R5BusinessRules` recompiled without the other two)
leaves mismatched internal build IDs across the three DLLs, which the Editor reports as "modules
missing or built with a different engine version" — the fix is a genuine clean rebuild of ALL modules
together (delete `Binaries/Win64` + the per-module `Intermediate/Build/Win64/x64/*` folders, then
rebuild), not a partial one. A first rebuild attempt on this project also hit `error C3859: Failed to
create virtual memory for PCH` / Windows error 1455 ("paging file too small") during UBA's parallel
PCH generation for the `R5` module — resolved by rebuilding with `-NoUBA` (disables the parallel
local executor, trading build speed for lower peak commit-charge), not by changing any actual
project/engine setting.

**Full male BodyTypeParams coverage CONFIRMED LIVE, 2026-09-01, same day** — the male-source
investigation is closed out. Batched all 5 confirmed-stable sources (Jasper=Adventurer, Axel=Albion,
Mortar=Native, Hunter=African, ScumMale=Scum via Woodman) to each other's remaining destination
families via one generalized batch script (`build_bodytype_male_batch_all_sources.py`, same pattern as
the female rollout's `build_bodytype_batch_all_sources.py`) — 25 new entries, all duplicated from an
already-tagged template so NONE needed manual GameplayTag work, only the `BodyMesh` retarget. All 30
combinations (5 sources × 6 destinations each, including the one each source already had) confirmed
working end-to-end after a full restart. **Two real process mistakes made and corrected along the
way, worth remembering**: (1) a mismatched pair caught by verification (`ScumMaleAsAdventurer` showed
a leftover `SK_Albion_Male_01` string alongside the correct `SK_Adventurer_Male_01` — never
root-caused for certain, but consistent with a UAssetGUI cross-tab mix-up when multiple files are open
at once; fixed by resetting that ONE source asset's `BodyMesh` back to a fresh placeholder and having
it redone in isolation) — worth opening files one at a time rather than many UAssetGUI tabs together
when doing a large batch. (2) **A costly one**: re-cooking (`-run=cook -CookAll`) to pick up that one
fix wiped out ALL 25 mesh retargets back to placeholder, not just the one being fixed — cooking always
regenerates every cooked file fresh from the SOURCE asset in `Content/`, which UAssetGUI never
touches (it only ever edits the COOKED copy under `Saved/Cooked/`), so any post-editing re-cook
discards every retarget done so far, whether broken or correct. **Standing rule for any future
batch**: cook exactly ONCE, before any UAssetGUI editing begins on that batch; if a single entry needs
fixing after that, fix its cooked file directly (or reset+redo just that one file's own retarget) —
never re-cook the whole batch to fix one entry.
**Scripted verification, not manual inspection, is what caught both real mistakes** — a small
string-scan check (does the cooked `.uasset` contain the expected destination mesh string, and NOT
any other family's mesh string) run over every entry in the batch before packaging, both times,
caught issues invisible to a visual spot-check. Worth doing this same check on any future N-entry
batch before packaging/installing, not just trusting "I did all of them."

**Senkamati male source built and CONFIRMED PARTIALLY WORKING, 2026-09-01 (same day) — found the
real blocker for a full fix, next step identified but NOT YET BUILT.** Live-probed all three raw male
Senkamati mob classes (`BP_Mob_SenkamatiCorrupted_Regular_Hunter_C`/`_Regular_Warrior_C`/`_Thrall_C`)
the right way this time (repeated fresh spawns, not one probe) — all three resolve the IDENTICAL key
(`GetBodyType()=Senkamati`, native mesh `SK_SenkamatiCorrupted_Male_Medium`, native sex Male) despite
each showing `IsBodyTypeChangeAvailable=false`. **That flag is confirmed NOT a real blocker for this
family** — the already-proven-working female Caster shows the identical `false` value, so it doesn't
predict non-usability the way it plausibly does for a fully hardcoded named character (Ksant). Built
`SenkaMaleAsAfrican` (one entry, duplicated from the female `SenkamatiAsAfrican` template with sex
flipped to Male — zero new tag work) — since all three classes share one key, ONE entry covers all
three as a source, and each still gives a genuinely different `BodyMorph` shape (baked per-class):
Thrall=(0.70,0.15,0.15) and Hunter=(0,0,0) are both new/distinct values; Warrior=(0,1.0,0) duplicates
MortarMan's.

**Live test result: the MESH retargeted correctly (confirmed `SK_African_Male_01`), but the SKIN
MATERIAL did not — it stayed `MI_Senkamati_Feather_Male_Medium`.** Root cause, confirmed via
`lbtestskin`'s own failure plus a live repeated-spawn check RedFalcon ran on request: `SkinMaterials`
(a `TMap<GameplayTag, MaterialInstance>` field on `R5CompositeMeshComponentBodyTypeParams`, left
completely empty on every template built this whole session including this one) is a SEPARATE
dimension from `BodyMesh`, and the SIZE portion of a skin material (Small/Medium/Large) genuinely
RANDOMIZES per spawn independent of family — confirmed directly: three fresh native Warrior spawns
read `MI_Senkamati_Feather_Male_Large`/`_Medium`/`_Small` in that order. This is not new/
Senkamati-specific — every class in the game has this same unpinned randomization; it was simply
invisible on the human-family templates because whatever default fallback rendered close enough,
and glaringly obvious here because the fallback is Senkamati-branded content on an African mesh.
`lbtestskin` separately fails on this class for an UNRELATED reason: its swap-matching logic expects
a 4-token `MI_<Family>_<Sex>_<Size>` material name, but this asset's real name has an extra token
(`MI_Senkamati_Feather_Male_Medium`, 5 tokens) — a different, narrower bug in that tool, not evidence
about SkinMaterials itself.

**Real `SkinMaterials` structure confirmed by extracting a genuine game asset offline** (`retoc
to-legacy` + a string-scan of the result — UAssetGUI's own CLI, `tojson`/`fromjson`, remains
confirmed-broken as it has been all session; reading this required the `.usmap` mappings file,
`Other/R5-5.6.1-0+UE5-e09d3821.usmap`, already present in this project from earlier work).
`DA_NPC_BodyTypes_AfricanMaleParams` (a real, shipped per-family asset, one of 16 found by string-
scanning `DA_NPC_BodyTypesParams_Common` itself for its own `BodyTypeData` array contents) shows
exactly 3 `SkinMaterials` entries, keyed by GameplayTags ALREADY REGISTERED in this project's own
`DefaultGameplayTags.ini` from early in the session (`Customization.Morph.SkinType.Small/Medium/
Large`, tags 9-11, unused until now):
```
SkinMaterials = {
  Customization.Morph.SkinType.Small  -> MI_African_Male_Small
  Customization.Morph.SkinType.Medium -> MI_African_Male_Medium
  Customization.Morph.SkinType.Large  -> MI_African_Male_Large
}
```
**This is the exact mechanism the still-unstarted "Size" dimension of the male/female "Barbies" work
needs** — fixing the Senkamati mismatch and delivering real Small/Medium/Large size control are the
SAME fix, not two separate tasks.

**Next step, planned but NOT YET ATTEMPTED**: populate all 3 `SkinMaterials` entries on ONE template
(same one-time-manual-step-then-duplicate-forever pattern already proven for `BodyType`) — headless
Python still can't construct a fresh `GameplayTag` (see below), so adding even one TMap entry with a
real key needs the Editor's own property-picker, this time three times instead of once; each entry's
VALUE (a `MaterialInstance` soft reference) will need the same transient-placeholder-then-UAssetGUI-
retarget trick already used for `BodyMesh`, applied 3x per entry instead of once. Real added
per-entry cost going forward, but a proven, well-understood structure — not a new unknown.

**Generalized 2026-08-31: this is not a mob/crew-specific quirk — confirmed on a non-mob base too.**
`Config.SENKA_FEMALE_BASE_CLASS` (the Handyman Gatherer, this mod's own proven walking-women base)
shows the IDENTICAL `ArchetypePreset` value across every spawn with zero pre-build writes involved —
looked at first like evidence this class might not re-randomize at all. Testing it directly (pinning
a real, curated player character-creation archetype preset pre-build, combined with a proven custom
outfit in the same spawn) disproved that: the pre-build write resolved and applied with no error
(`archetype=ok`), but a post-spawn live probe showed `ArchetypePreset` had reverted to the class's OWN
default by the time the actor was fully live — the outfit stuck, the archetype did not. **The real
explanation: this class's own reassertion source apparently has only ONE entry, so it always
reasserts the SAME value regardless of what's written pre-build — stability was never evidence of
skipping the reassertion, just evidence of a single-entry source.** Do not assume a class is exempt
from this wall just because it happens to look stable across ordinary spawns; test an actual override
directly, the same way this was just re-confirmed. This closes off the one plausible-looking exception
to the original wall — it appears to be universal to every class with a `CompositeMeshComponent`, not
scoped to mob/crew classes specifically.

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

## 2e. Anatomy of a full NPC, confirmed via a comprehensive live probe (2026-08-31)

RedFalcon's real end goal: "Barbies" — a full custom NPC (chosen body/skin archetype AND clothing)
that can then be dressed, for both male and female presets, starting with peaceful (non-combat)
professions before eventually extending to combat-capable ones too. Before building further, a full
`lbprobedump` sweep of a real, wild `BP_NPC_Citizen_Walker_C` (aimed at in Tortuga, not one of this
mod's own spawns) settled exactly what "building an NPC from scratch" would actually require.

**Real class hierarchy, corrected from an earlier guess**: `BP_NPC_Citizen_Walker_C` →
`BP_NPC_Base_C` → `BP_R5AICharacter_Base_C` → **`AR5AICharacter`** → `ACharacter` → `Pawn` → `Actor`
→ `Object`. **`AR5AICharacter` is a SIBLING of `AR5Character` (the earlier, wrong guess for "the"
player/character base), not a subclass of it** — confirmed by reading both classes' own generated
headers directly; `AR5AICharacter` extends `ACharacter` on its own. It implements ~26 custom R5
interfaces of its own (more than `AR5Character`'s ~18) and owns `ActivateCharacter()` — the exact
native function this file's own §1 spawn recipe already calls to "bring an NPC to life," confirming
this is genuinely the right native base for any AI-driven NPC, not a guess.

**The practical finding: almost nothing about "what makes an NPC" is compiled behavior that needs
replicating — it's almost entirely reference fields, on top of one unavoidable native base class.**
- **Behavior is exactly two references**, both already fully understood how to work with (a class
  reference and a DataAsset reference — no logic needed): `Pawn.AIControllerClass` → a Blueprint
  AIController class (e.g. `BP_NPC_AIController_Citizen_Walker_C`) governs how she thinks and moves;
  `AR5AICharacter.AIPawnParams` → a `R5AIPawnParams` DataAsset the controller reads for behavior
  tuning. A THIRD reference, `AbilitySystemParams` (another DataAsset), governs combat/ability
  stats — present on every NPC, but only load-bearing for combat-capable ones.
- **Appearance is the already-solved `R5CompositeMeshComponent` system** documented throughout this
  file — `DefaultParams`/`ArchetypePreset`/`ColorParams`/`MorphParams`/`BodyDecorParams`, all plain
  references.
- **Animation is also just a reference**, not custom logic: `Mesh.AnimClass` → `R5PawnAnimInstance`
  (a data-driven AnimBlueprint reading exposed variables like `IsWalking`/`IsFemale`/`BodyMorph` —
  the SAME kind of thing a new pawn just needs to point at, not rebuild).
- **Real correction to how `CustomizationData`'s `GroupCategoryId` tags actually work, confirmed
  live**: it's per-body-part, not one flat bucket. Confirmed tags on this real NPC:
  `Customization.UID.Armor.Head`/`.Torso`/`.Belt`/`.Hands`/`.Legs`/`.Feet`, plus `.Hairs` and
  `.Facial.Eyebrows`/`.Mustache`/`.Whiskers`/`.Beard`. §19's own custom-outfit test used a single flat
  `Customization.UID.Armor` tag for the whole outfit — that worked for a one-piece proof of concept,
  but a genuinely complete, multi-slot custom outfit needs a separate `CustomizationData` entry per
  slot with its own specific tag, not one entry covering everything.
- **The one real, unavoidable cost**: `AR5AICharacter`'s own ~26-interface compile requirement, for
  anyone wanting a genuinely NEW pawn CLASS (as opposed to reusing an existing one and only swapping
  its composite-mesh DataAsset references, which is what every walking-women reskin in this file
  already does). Everything that class would reference — AIController, pawn-params, outfit,
  animation — is reusable AS-IS from existing content; only the class itself needs authoring.

**Practical implication for "Barbies," peaceful-first**: `BP_NPC_Citizen_Walker_C` (this probe's own
subject) is combat-armed — weapons, ammo, `CombatComponent`, `AR5AICharacter`'s own
`AbilitySystemParams`/`AIBehaviorAttributeSet` all load-bearing. A Handyman-family base (Gatherer,
already this mod's own proven walking-women/outfit-test target) is the simpler reuse target to start
from — fewer components genuinely doing anything, nothing combat-related to reason about. Combat-
capable "Barbies" remain a real, later stretch goal (RedFalcon's own call — start peaceful, "its less
[to] manage"), not a different technical wall — the same AIControllerClass/AIPawnParams-reference
recipe applies either way, just pointed at a combat-capable donor's own values instead.

**2026-08-31, same day — a selected body mesh CONFIRMED LIVE, via a completely different mechanism
than the blocked `ArchetypePreset` route, no new class authoring needed at all.** Rather than fighting
`ArchetypePreset`'s reassertion wall, swapped the actor's own BASE body mesh (`actor.Mesh`, the
LEADER component every `BuildedCompositeMeshes` piece leader-poses off of) directly, post-build — the
exact same `hide → SetSkeletalMeshAsset → show` pattern §2d's `Spawner.SetBodyPartMesh` already
proves safe for one outfit piece, just applied to the leader itself (no `SetLeaderPoseComponent`
rebind needed, since the leader doesn't leader-pose off itself). Target mesh found via
`lbtestlistclass /Script/Engine SkeletalMesh African`:
`/Game/Character/Skeletal_Meshes/Human/Regular/African/Meshes/SK_African_Female_01`. **Confirmed
live: spawned `Config.SENKA_FEMALE_BASE_CLASS` with the already-proven custom outfit, swapped the
base body mesh post-build, and got a genuinely different, correctly-chosen body — the outfit stayed
on, nothing broke.** This deliberately never touches `ArchetypePreset`/`BeginPlay`'s reassertion
logic at all — it operates entirely AFTER the build (and BeginPlay) have already finished, so the wall
simply never applies. **This means full "Barbies" (chosen body mesh + chosen outfit) is achievable
on an EXISTING NPC class today — the much bigger `AR5AICharacter`-interface-stubbing undertaking
(SS2e above) is not a prerequisite for this, only for a genuinely NEW pawn class with the archetype
baked in as a compiled default, which remains a separate, optional, later goal.**
**Skin material confirmed correct too, via the same live probe**: the new body mesh's own material
slot 2 now reads `MI_African_Female_Medium`, with correctly-matched textures
(`T_African_Female_Medium_A/N/SRM`) — the new mesh's own default material came through cleanly,
nothing leftover from whatever archetype/skin was previously active. `SetSkeletalMeshAsset` alone
doesn't touch material overrides, so the new asset's own baked-in default material slots simply took
over — body shape AND skin tone both solved by the one mesh swap, no separate material step needed.
Also unconfirmed for other outfits/pieces:
SS11's own "a mesh that fits one body shape can clip against a different one" finding — the Jeweler
torso happened to look right on the new body in this one test, but that's not a guarantee every
piece/body combination will.
**A crash confirmed and fixed along the way**: `lbtestlistclass`'s first version (a generic
`ForEachProperty` walk over every field of the returned `FAssetData` structs) crashed the game
natively partway through the `SkeletalMesh`-class query, despite working cleanly for a plain
`DataAsset` query moments earlier — see SS3r below, a genuine, separate lesson.

**Same-night follow-up on COLOR specifically, once RedFalcon reasonably asked "if body mesh can now
be swapped post-build, why not re-evaluate color too" — genuinely re-tested, and the original
conclusion holds, now for a much better-understood reason.** Body mesh worked by bypassing the
config PROPERTY entirely and swapping the render component directly (a discrete asset swap). The
natural question: does the same "operate on the component, not the property" trick work for color?
Tested directly, exhaustively, this session:
- `mesh:CreateDynamicMaterialInstance(slotIdx)` (1 arg, what an existing but never-actually-run
  function in this file assumed) — Lua-level error, "UFunction expected 4 parameters, received 1."
- The real signature, found SAFELY via the SDK header dump rather than live reflection
  (`PrimitiveComponent.h`): `CreateDynamicMaterialInstance(int32 ElementIndex, UMaterialInterface*
  SourceMaterial, FName OptionalName)` — 3 real params + 1 return = 4 declared properties.
- **Calling with exactly the 3 real parameters (matching the header exactly) CRASHED THE GAME
  NATIVELY on the very first call, zero log output** — this specific UFunction's own UE4SS
  reflection metadata genuinely expects 4 supplied values despite the C++ signature showing 3.
- Calling with 4 arguments (3 real + a 4th placeholder) did NOT crash, but consistently errored
  ("expected 4, received 4") — tried the 4th slot as both an empty table and `nil`, and tried the
  `SourceMaterial` argument as both a valid resolved material and `nil`: **all four combinations
  produced the IDENTICAL error**, strong evidence the error is a generic marshaling-failure wrapper
  (not a precise per-argument diagnosis) and that no argument-value combination fixes it — this is a
  binding-level limitation for this specific UFunction, not a call-shape mistake.
- This is the THIRD independently-confirmed failure mode for `CreateDynamicMaterialInstance` in this
  project's own history (the composite-component-level call crashed before; the Kismet-library
  version crashed before, in an unrelated ghost-material context; now the leaf-component version
  fails/crashes too) — a real, converging pattern: this function is not safely invokable from this
  UE4SS binding in ANY tested form, not a fluke tied to one specific call site.
- **Separately confirmed there is no fallback "swap to an existing pre-colored variant" option
  either** (the mechanism that DOES work for skin tone, e.g. `MI_Native_Male_Large` ->
  `MI_African_Female_Medium`) — searched the game's own materials directly via
  `lbtestlistclass`: the armor material family (`MI_TS_ArmorRegular_01`) has no numbered
  color-variant siblings at all, only an `_LOD1` level-of-detail variant. Skin tone is a small,
  discrete, pre-baked set (a handful of ethnicity materials) — exactly why a swap works. Garment
  color is a CONTINUOUS parameter the shared material exposes, with no discrete alternate
  instances to swap to at all.
**Conclusion at that point, now resting on exhausting every architecturally-plausible route, not just
the config-property layer**: garment color is consumed once at construction time with no safe
intervention point found anywhere — pre-build write (crashes), post-build property write (silently
never renders), post-build direct material manipulation (fails/crashes in every tested form), and
pre-baked-variant swap (no such variants exist for this axis). This is genuinely different from body
mesh and skin tone, both of which are discrete asset swaps with real existing alternatives to switch
between — color has neither a safe write path nor alternatives to switch to.

**REOPENED AND SOLVED, same night, by RedFalcon's own sharp pushback**: the conclusion above only
ever tested the composite-config layer (`ColorParams`/`ColorController`/`SelectedColors`) and
material-instance manipulation (`CreateDynamicMaterialInstance`). RedFalcon pointed out a real
observation neither of those explained: "if we swap outfits and such on the gatherer, theyre always
som shade of brown. on BotC its always some shade of red... I dont think they are clothing specific,
i think they are entity specific. like a color theme not a specific color" — implying a THIRD layer,
tied to the NPC/entity rather than the config asset or the material call. That layer turned out to be
**Custom Primitive Data (CPD)**, a real, common UE5 mechanism entirely bypassed by every earlier
attempt: a small per-INSTANCE float buffer a material reads directly via a "Custom Primitive Data"
material-expression node, needing no `MaterialInstanceDynamic` at all — explaining in one shot why no
color-variant material instances exist (SS above) and why `CreateDynamicMaterialInstance` was never
going to be the right tool regardless of its own binding problems.

**Found via a real diagnostic trail, not a lucky guess**:
1. Every `AR5AICharacter`(-family) actor carries a `CPDEffectsComponent`
   (`R5CustomPrimitiveDataEffectsComponent`) — "CPD" in the name was the actual clue.
2. `UPrimitiveComponent` (confirmed via the SDK header dump, `PrimitiveComponent.h`) exposes plain
   BlueprintCallable CPD functions: `SetCustomPrimitiveDataFloat(int32 DataIndex, float Value)`,
   `SetCustomPrimitiveDataVector4(int32 DataIndex, FVector4 Value)` (writes 4 CONSECUTIVE floats
   starting at `DataIndex` — NOT 4 independent "slots" multiplied by index, a real early
   misunderstanding this session that produced a confusing "moldy blood+mud" result before it was
   corrected), plus named-parameter variants
   (`SetVectorParameterForCustomPrimitiveData(FName, FVector4)`,
   `GetCustomPrimitiveDataIndexForVectorParameter(FName)` — the latter genuinely crashed once when
   passed a raw Lua STRING where the binding wants a real `FName`; fixed with the same
   `UEHelpers.FindOrAddFName(str)` conversion already established elsewhere in this codebase for
   exactly this class of parameter).
3. **The exact CPD layout was found offline, not guessed**: extracted the equipped piece's own
   material chain (`MI_ArmorRegular_01` → parent `M_Common_Cloth`) via `retoc to-legacy` +
   UAssetGUI's undocumented `tojson` CLI verb, and read the master material's own NameMap, which
   spells out designer comments for every CPD float index in use:
   ```
   CPD00 RandomID              CPD08 BloodWounds Intensity
   CPD03 Cloth/Hair MainColor  CPD11 Effect FireWeapon
   CPD04 Cloth SecondaryColor  CPD12 Effect SharpWeapon
   CPD05 Cloth DetailColor     CPD15 EyeColor, CPD16-23 BodyDecor/FaceDecor/SkinAging
   ```
   `CPD07`/`CPD08` (Dirt/Blood) being adjacent to `CPD03-05` (color) is exactly what produced the
   earlier "moldy blood+mud" red herring when this was still being explored with overlapping
   4-float Vector4 writes at the wrong offsets, before the comment map was in hand.
4. **Confirmed live via a clean, isolated bisection** (`SetCustomPrimitiveDataFloat`, ONE float at a
   time — no overlap, unlike a Vector4 write): index 3 = Main, 4 = Secondary, 5 = Detail, each an
   independent garment-region color selector; index 7/8 independently confirmed as Dirt/Blood,
   matching the comment map exactly and cross-validating the whole offset scheme.
5. **The value written to each of those 3 floats is a 0..23 PALETTE INDEX**, not raw RGB — the same
   `Value` field already found (and previously assumed dead) in `FR5BLCharacterColorData`
   (`SelectedColors`/`ColorData`, both DataAsset- and struct-level). The actual palette is a real,
   shared, named 24-color `CurveLinearColorAtlas` asset,
   `/Game/Common/Textures/Gradients/CRV_CharacterClothPalette` (found by RedFalcon directly via a
   JSON export of that `.uasset`), confirmed identical across DIFFERENT NPCs (Gatherer, BotC) — one
   universal palette, not baked per-archetype:
   ```
   0 Harp            6 Crimson          12 EmeraldGreen    18 Purple
   1 IceBerg         7 Carmine          13 ColdGreen       19 Violet
   2 Ivory           8 Bordeaux         14 OliveGreen      20 Lilac
   3 BlueCharcoal    9 PaleOrange       15 LightBlue       21 ChocolateBrown
   4 BlackOlive     10 YellowGreen      16 NavyBlue        22 BrownLeather
   5 WoodBark       11 PaleGold         17 OceanBlue       23 BrownCopper
   ```

**The finished, safe, reusable recolor mechanism**: on the equipped piece's own leaf
`SkeletalMeshComponent` (the same one `BuildedCompositeMeshes[i].EquippedMesh` already resolves to
for outfit work), call `target:SetCustomPrimitiveDataVector4(3, {X=mainIdx, Y=secondaryIdx,
Z=detailIdx, W=0})` — one clean call, three garment regions, using indices from the palette table
above. No crash risk (a plain `int32` + `FVector4` write, nothing like
`CreateDynamicMaterialInstance`'s confirmed-dead binding), confirmed live, repeatedly, with zero
errors. This is a genuinely different, safe layer below everything else tried in this section —
**garment color IS achievable after all**, just not through the composite-config or material-instance
layers this section originally exhausted.

**CONFIRMED LIVE, same night, extending to every remaining customization category — hair, eyebrows,
and eyes all recolor via the same or a closely related mechanism.** `ER5BLCompositeMeshBodyPartType`'s
real enum ordinals (`Hairs=3`, `Eyebrows=1`, `Torso=7` — matching every `BodyPart` value already seen
in `lbprobecolors` dumps exactly) let the same `SetCustomPrimitiveDataVector4(3, {main, secondary,
detail, 0})` write be targeted at the hair and eyebrow pieces' own leaf components instead of a
garment piece — **confirmed live, both genuinely recolor**, same mechanism, same shared palette.

Eyes are a hybrid, worth its own note: the material actually assigned (`MI_Eye`, confirmed identical
across every Gatherer probe dump all session) is a plain, shared, generic material — NOT one of the 5
discrete pre-made `MI_EyeRound_<Color>_01` variants (Blue/Brown/Evil/Green/Grey). That 5-item list was
confirmed EXHAUSTIVE via a live `IAssetRegistry:GetAssetsByClass()` sweep for every
`MaterialInstanceConstant` with "Eye" anywhere in its path across the whole game — everything else
matching that substring is an animal/creature eye material (Dodo/Crocodile/Wolf/Goat/Boar/SwampToad)
or an unrelated FX/post-process material (`"...StrictEyeAdaptation"`) with no bearing on human
characters at all. Since `MI_Eye` itself doesn't match any NPC's actual rendered eye color by default,
it turns out to ALSO be CPD-driven — `CPD15 EyeColor` (from the same master-material comment map),
written directly on `actor.Mesh` (the base body component, since the eye material is a SLOT on the
base mesh, not a separate `BuildedCompositeMeshes` piece). One early test (value `3`) showed no
change — the exact same "unlucky value" trap the cloth Main channel hit at `23` before `20` worked —
a proper sweep through the rest of the range confirmed real, clearly visible color shifts. So there
are TWO independent, both-safe levers for eyes: the CPD15 palette shift on the current material
(mirrors cloth/hair/eyebrows exactly, value range and named palette not yet mapped), and the discrete
5-variant material swap (a completely different iris style, not just a different shade of the current
one) — genuinely different axes, not redundant with each other.

**A real discrepancy in this project's own history, resolved 2026-09-02**: the code comment right
above `Spawner.TestSetEyeColor` in spawner.lua flatly says "Eyes are NOT CPD-driven -- confirmed by
`lbtestbasecpd(15, ...)` doing nothing," given as the reason the discrete-swap approach was built at
all -- directly contradicting the paragraph above (which says a proper sweep found real color
shifts). The code comment was never updated after the later, correcting discovery in the same
session. RedFalcon settled it empirically: BOTH are real and both are meant to be used together --
`lbtesteye`'s 5 discrete variants render as VIVID, almost-glowing colors (a distinct iris style, not
a natural shade), while `lbtestbasecpd 15 <value>` applies as a subtler, more natural-looking shift
ON TOP OF the plain default `MI_Eye` material. The planned permanent design is a combo: the 5
discrete variants for dramatic/stylized colors, CPD15 (on the default material) for natural color
variety -- not an either/or choice between them. Still TODO: an actual 0-23 sweep on CPD15 to build
a real reference (what each index actually looks like on eyes specifically, don't assume it matches
the cloth/hair palettes' own indices -- confirmed THIS SAME SESSION that hair's own palette is a
completely different, smaller 9-color atlas from cloth's 24-color one despite sharing the identical
CPD-write mechanism, so eyes' own mapping cannot be assumed without directly testing it too).

**CONFIRMED LIVE, same night: body-SHAPE variety (bust/waist/hip-style proportions within one shared
body mesh) is also achievable, on at least one whole class family, using entirely existing content —
no custom asset authoring needed.** This was previously investigated in a closed session and
concluded dead: a per-instance body-shape blend (`BodyMorph`, a plain Vector variable on the
AnimInstance) differs between two real characters sharing the identical archetype mesh — confirmed
via direct comparison — but every attempt to WRITE it live (pre-build, post-build, with matching
supporting variables set too) reported success and changed nothing visible, traced to a Control Rig
graph binding that doesn't re-evaluate after construction.

Reopened by finding the actual upstream DATA ASSET that feeds that blend:
`R5CompositeMeshComponentMorphParams` — a plain, ordinary, offline-inspectable DataAsset (unlike the
JSON-runtime `ArchetypePreset` chain), holding one `Axis3` barycentric-blend controller per body zone
(Body/Head/Nose/Ears/Brows), each with a `Value`/`AllowedRange` (a 3-corner blend triangle) and a
`bRandomizeMorph` flag. It's referenced by the composite component as a plain object property
(`comp.MorphParams`), structurally identical to `DefaultParams` (outfit) rather than
`ArchetypePreset` (which gets reasserted). A real, ready-made roster of alternates already exists in
the pak: `DA_NPC_Common_MorphParams_Large/Medium/Neutral/Random/Small`, plus per-role ones
(`DA_NPC_Citizen_Townsman_MorphParams`, `DA_NPC_Citizen_Worker_MorphParams`, several mob-family ones).

**Decisive live evidence, found from real gameplay, not a test override**: two different
in-game statue-type actor classes, both independently rolling the identical shared body-mesh
archetype, were caught referencing two DIFFERENT `MorphParams` assets — one the generic default, the
other a role-specific one — and visibly have different proportions as a result. This confirmed the
mechanism is real BEFORE any override was attempted.

**The override itself was then tested and confirmed working — but the result is class-family
specific, not universal**:
- On the ORIGINAL closed investigation's class family (an AI-controlled NPC pawn, e.g. a walking
  Handyman-based actor) — setting `comp.MorphParams` to a different asset pre-build reads back
  correctly (the reference genuinely sticks, unlike `ArchetypePreset`) but produces **no visible
  change** — the same "write succeeds, doesn't render" signature as the original closed `BodyMorph`
  investigation, just one layer up.
- On a DIFFERENT class family — a posed/statue-type actor (the same family the two real, differently-
  shaped statues above belong to) — the identical pre-build override **worked perfectly**: spawning
  one class with a DIFFERENT class's own `MorphParams` reference produced an EXACT proportion match to
  that other class, not the spawned class's own (normally randomized) default — confirmed across
  multiple repeated spawns, ruling out coincidence.

**Practical conclusion**: body-shape variety via `MorphParams` is a real, safe, no-crash-risk,
existing-content-only lever — but only proven so far for the statue/posed-actor class family, not the
walking AI-pawn family. For "Barbies" work specifically targeting a walking NPC base, this may still
need the AR5AICharacter class family's own equivalent trigger (untested: a post-build write plus the
same rebuild-trigger sequence already proven for outfit changes — never actually tried for
`MorphParams` specifically, only pre-build was), or accepting body-shape variety on statue-type actors
for now while pursuing outfit/color/hair/eyes variety on the walking-pawn family as already proven.

**UPDATE, same overall investigation, one class further tested: explicit body-MESH family and
explicit MorphParams-shape, TOGETHER on the same statue-family actor, are NOT achievable by any
technique tried, in either order.** Two combinations tested live:
- **Mesh forced POST-build** (after `Spawn()` returns): the mesh reliably sticks (confirmed
  repeatedly — always the requested family), but the shape does not visibly change at all — it
  always reads as the new mesh's own plain default proportions, regardless of which preset was
  requested. Consistent with the same "computed once during construction, a later mesh swap
  replaces it with a fresh undeformed instance" theory as the original finding above.
- **Mesh forced PRE-build** (in the same deferred-spawn window as the `MorphParams` override, hoping
  native construction would read the chosen mesh from the start): made things WORSE — confirmed via
  `lbprobedump` on 3 separate fresh spawns that BOTH the mesh reference AND the `MorphParams`
  reference silently reverted to fixed values (a hardcoded default MorphParams asset, and a random
  archetype for the mesh) regardless of what was explicitly requested. Touching the base mesh
  pre-build appears to trigger (or coincide with) a full native "rebuild from class defaults" that
  discards both overrides together, not just the mesh. A separate apparent "success" on a different
  class earlier in this same test round turned out to be a false positive — the preset used was
  already that class's own native default, so it couldn't have distinguished a real override from
  no override at all; always cross-check a preset choice against the class's actual native default
  before trusting a "no visible difference" OR a "matched!" result either way.

Net: mesh alone (post-build) and shape alone (via a plain, no-mesh-forcing spawn) both remain
reliable, independently, on the statue class family — but the two cannot currently be combined to
get an explicit, deterministic mesh+shape combination on demand. Don't re-attempt the pre-build
combination without a genuinely new theory for why touching the mesh triggers a full defaults reset.

**2026-09-01, a first attempt at forcing body-type SELECTION through native construction (rather
than a post-hoc mesh swap) FAILED — but the corrected version, a few hours later the same night,
WORKED, and generalizes well.** Recorded here as it actually happened, since the failure is what
led to the real technique.

**First attempt, wrong theory, confirmed dead**: constrain `comp.BodyTypeParams` (a plain, ordinary
DataAsset — a flat `TArray` of per-body-type entries, confirmed via a live JSON export of the real
`DA_NPC_BodyTypesParams_Common`: 14 entries, 7 families × Male/Female) down to a single NEW-family
entry, authored offline via a real SDK-stub Editor project (see §19c), hoping the archetype's own
selection could be starved of any other option to pick. Tested on the Gatherer with a
`BodyTypeParams` containing exactly one entry (African Female): the custom list itself DID stick
(unlike `ArchetypePreset`, confirmed via readback — not reasserted), and `GetAvailableBodyTypes()`
honestly reflected the narrowed pool. But `GetBodyType()` resolved to
`Customization.Morph.BodyType.Adventurer` anyway — the Gatherer's own native family, completely
unrelated to the custom list — and the rendered body fell back to a hardcoded generic
(`SK_Adventurer_Male_01`, wrong family AND wrong sex). **Root cause**: `comp.ArchetypePreset` is
what actually DECIDES which family+sex key gets REQUESTED; `BodyTypeParams` is only the POOL that
request gets resolved against, not the selector. A pool missing an entry for the key that's actually
requested doesn't get a substitute picked from it — it fails and the engine falls back to a
hardcoded default.

**The corrected technique, confirmed live and working, repeatedly, across four genuinely different
NPC class families**: don't add a NEW-family entry — instead build an entry that KEEPS the tag the
class already requests (so the lookup key still matches, and the entry is actually consulted) but
retargets that entry's own `BodyMesh` field to a DIFFERENT family's real mesh. This hijacks what
"the class's own native key" resolves to, for one custom asset only, without ever touching the real
shared `BodyTypeParams` asset the rest of the game still uses unmodified.

Build recipe (via the SDK-stub Editor project, §19c):
1. Expand the stub `R5CompositeMeshComponentBodyTypeParams` class to its real fields (matched to the
   SDK header dump exactly): `BodyType` (`FGameplayTag`), `BodyTypeSex` (`ER5BLCharacterSex`),
   `BodyMesh` (`TSoftObjectPtr<USkeletalMesh>`), `AnimClass`, `SkinMaterials`, `BodyTypeMorphPrefix`,
   `BodyTypeText`.
2. Author a fresh instance via headless Python: set `BodyTypeSex` (Python-settable directly), leave
   `BodyType` at default (see step 4), and set `BodyMesh` to a **transient placeholder**
   (`unreal.SkeletalMesh()`) — headless Python cannot marshal a soft-object reference to an
   external/unmounted asset path directly (confirmed via repeated failure: a plain string, a
   `SoftObjectPath`, and a loaded wrong-type object were all rejected with a type-conversion error;
   only an actual object of the correct class is accepted, and a transient one works fine and
   serializes as a clean, later-editable `SoftObjectPropertyData` field once cooked).
3. Cook. Confirm the cooked asset is a plain versioned `NormalExport` (`IsUnversioned: false`) with
   `BodyMesh` showing as an editable `PackageName`/`AssetName` pair pointing at
   `/Engine/Transient`/`SkeletalMesh_N` — this is what makes step 5 possible.
4. **The one unavoidable manual step**: `BodyType` (a `FGameplayTag`) cannot be constructed from a
   string via any headless-Python API found (`GameplayTagLibrary` has no `request_gameplay_tag`;
   `TagName` is read-only; `make_literal_gameplay_tag` itself needs an already-valid tag as input —
   all confirmed by direct testing, not assumed). Register the tag name in the project's own
   `Config/DefaultGameplayTags.ini`, then set it once via the Editor's own property-picker widget on
   the entry asset (open the PROJECT'S SOURCE asset under `Content/Mods/...`, not the cooked output).
5. Re-cook (this bakes the tag in but reverts `BodyMesh` back to the placeholder, since cooking
   re-derives from the source asset — order matters: tag first, then the mesh retarget last).
6. Retarget `BodyMesh` on the freshly-cooked `.uasset` via UAssetGUI's Export Data grid — a plain
   two-field text edit (`PackageName`/`AssetName`), no JSON round-trip needed (`fromjson` remains
   broken, confirmed again this session — do the edit interactively in the GUI).
7. Package (`retoc to-zen`, root mount point `../../../`) and install as a sidecar pak.
8. Wrap the entry in a `R5CompositeMeshBodyTypeListParams` (`BodyTypeData = [entry]`) — this is what
   `Spawner.SetCompositeParams`'s `bodyTypesPath` argument actually points at.

**Scaling this is cheap once one tagged template exists for a given source key**: the `BodyType`
tag survives `unreal.EditorAssetLibrary.duplicate_asset()` wholesale — so producing a SECOND
destination mesh under an ALREADY-tagged source needs zero further manual tag-picking, just
duplicate → set a fresh placeholder `BodyMesh` → cook → one more UAssetGUI retarget. Confirmed live:
duplicated each of the four tagged source templates into every remaining destination mesh in a
couple of Python batch runs, tag intact and verified on every one before the manual retarget pass.

**Full coverage confirmed live, 2026-09-01, closing this out for real**: all 25 non-native
(source, destination) combinations across the four source families below were built, verified via
readback before packaging, installed, and individually spawn-tested in-game via `lbtestbodytypes`
— every single one confirmed rendering the correct destination mesh on the correct source class.
Not a sample — the full cross-product: `Adventurer`×{African/Albion/Fable/Native/Orient/Scum},
`Albion`×{African/Adventurer/Fable/Native/Orient/Scum},
`Scum`×{African/Adventurer/Albion/Fable/Native/Orient} (sex-forced, per the Woodman finding above),
`Senkamati`×{African/Adventurer/Albion/Fable/Native/Orient/Scum}.

**Confirmed live, working, across four genuinely different NPC source classes** (each needing its
own one-time tagged template, since the native key varies per class, not fixed game-wide):
- `Adventurer` — `BP_NPC_Handyman_Gatherer_C` and `BP_NPC_Handyman_Herbalist_C` resolve
  `GetBodyType()=Adventurer` natively, despite each having its OWN separate `ArchetypePreset`
  asset — the resolved KEY is what matters, not which preset asset produced it.
  **CORRECTION (2026-09-02): this bullet previously also listed `BP_NPC_Citizen_Walker_C` (sex-
  changed) as a third confirmed-working Adventurer source — that was wrong, and contradicted this
  same file's own earlier, correct finding (§ "the statue roster" / "wrong-tag problem" section)
  that he re-rolls his archetype family on `BeginPlay` regardless of native sex and is NOT usable
  as a fixed `BodyTypeParams` source under any tag. RedFalcon confirmed live he's ineligible.
  He WAS legitimately included in the separate, narrower `BodyMorph`-carries-over-a-sex-change
  check just below (reading a native property once doesn't care about randomization) — that
  finding stands; only his inclusion in THIS "confirmed working fixed source" list was the error.**
- `Albion` — `BP_NPC_Employee_AlchemyStation_RosalindaMercer_C` (a completely different NPC
  family, `BP_NPC_Employee_C`, not `BP_NPC_Handyman_C` — confirming the technique isn't
  Handyman-specific).
- `Scum` — three native-MALE laborer NPCs (`BP_NPC_Handyman_Woodman_C`/`_Miner_C`/`_Farmer_C`) all
  resolve `GetBodyType()=Scum`. Needed one extra fix: since every custom entry authored this session
  is `BodyTypeSex=Female`, a natively-male class's own `ArchetypePreset` requests
  `Scum+Male` — force `compositeLook.sex=2` (Female) in the SAME pre-build spawn call. Confirmed
  live this DOES stick correctly when combined with the `BodyTypeParams` override in one spawn
  (result matched a separately-confirmed post-build `SetCharacterSex` conversion of the same class
  exactly) — a genuine, worthwhile exception to this file's own general "the archetype's own sex
  usually wins" caution elsewhere; that caution still applies to setting sex ALONE, this is
  specifically about setting it ALONGSIDE a matching `BodyTypeParams` override.
- `Senkamati` — the raw NATIVE MOB skeleton (`BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster_C`,
  a Corrupted mob class, NOT a "Human/Regular" NPC at all) resolves `GetBodyType()=Senkamati`,
  backed by her OWN dedicated `DA_Mob_Senkamati_Regular_Shaman_BodyTypesParams` pool (not the
  shared `DA_NPC_BodyTypesParams_Common` every "Regular" class used) — confirmed the SAME technique
  applies regardless, successfully retargeting her own unique native mesh
  (`SK_Senkamati_Witch_01_Female`) to a standard human one. One real oddity noted but not fully
  explained: her raw `ArchetypePreset` property reads a non-null pointer in a generic property dump
  but reads as `(invalid/none)` via the dedicated archetype-validity probe — suggesting mob classes
  may not carry a genuine `R5CharacterCustomizationPresetArchetype` the same way human NPCs do —
  yet the retarget worked identically regardless, so this didn't end up mattering in practice.

**Shape (`BodyMorph`) is NOT a tunable parameter on this class family, but it IS a free lever via
source-class choice — a distinction worth being precise about.** `MorphParams` (the asset reference)
sticks correctly when set pre-build (unlike `ArchetypePreset`), but a decisive test proved it's never
actually CONSUMED into a real shape on the `AR5AICharacter` walking-NPC family: two different NPC
classes (Gatherer, Herbalist) were confirmed to reference the IDENTICAL `MorphParams` asset
(`DA_Hero_MorphPrams`) yet produced completely DIFFERENT `BodyMorph` results — proof the runtime
reference plays no role at all; `BodyMorph` is baked into each Blueprint's own construction as a
fixed per-class default, independent of both the mesh currently equipped and whatever `MorphParams`
is nominally referenced.

That means shape can't be dialed in as a parameter — but it DOES persist reliably across a
`BodyTypeParams` mesh retarget (confirmed on every one of the four source classes above: each one's
`BodyMorph` after being retargeted to the African mesh matched its own pre-retargeted baseline
exactly, byte for byte). So "which shape a Barbie gets" reduces entirely to "which source class you
spawn from" — a free, wide, but fixed-not-tunable pool. **Sex-changing a native-male NPC
(`SetCharacterSex`/`comp:SwapBodySex`, already established elsewhere in this file) carries that
male class's own native `BodyMorph` over completely unchanged** — confirmed across four male
classes (Woodman/Miner/Farmer/Citizen Walker), three of which produced genuinely distinct values —
meaning ANY male walking NPC in the game is a usable shape source too, not just the handful of
naturally-female ones. Across 7 classes checked this session, 5 distinct shape values were found (2
classes shared the same fallback default). One structural note: every `Adventurer`/`Albion`/`Scum`
-keyed class showed `BodyMorph.X = 0` with all the variation living in Y/Z; the `Senkamati`-keyed
class was the only one with a non-zero X (`0.5, 0, 0`) — consistent with her having a genuinely
separate morph blend space tied to her own dedicated `BodyTypeParams` pool, not the shared human one.

**A real clarification of the earlier Senkamati-armor fit-compatibility finding (see §11's original
allowlist work), discovered as a side effect of this retarget technique.** The original finding was:
Senkamati-family armor clips badly on most human archetypes, fits cleanly only on a short allowlist
(Adventure/Albion/her own native body). Retargeting the raw native Senkamati Caster's OWN `BodyMesh`
to the African mesh (a family NOT on that allowlist) was expected to make her own armor clip —
tested live, and it did NOT clip; it fit exactly as well as before. **Why**: the retarget only
swaps which mesh RENDERS as the base body — it never touches the underlying Skeleton. Composite
pieces (armor, clothes) deform via the shared skeleton through leader-pose, not by binding to the
base mesh's own specific vertex geometry. Since her skeleton never changed (still her own native
Senkamati rig), armor rigged against that skeleton keeps fitting regardless of which mesh currently
paints the visible skin layer. This reframes the ORIGINAL compatibility problem correctly: it was
never really about "which mesh is assigned" at all — it's about DIFFERENT NPC CLASSES having
genuinely different underlying skeletons/proportions, even when they happen to share an
ethnicity-family NAME. Swapping which mesh renders on the SAME actor/skeleton was never actually at
risk of breaking that fit, and testing confirmed it doesn't. (The separate, unrelated pelvis-gap
issue — a mesh-authoring gap in the Legs piece assuming the wearer's OWN skin shows through
underneath — is NOT affected by any of this and remains open exactly as originally documented; it's
a texture/geometry issue, not a skeleton-fit one.)

**Practical design conclusion**: a fully custom "Barbie" NPC on this class family reduces to three
completely independent, freely stackable choices — (1) source class (fixes shape, sex-change
included), (2) `BodyTypeParams` retarget (mesh/ethnicity, skip entirely if the source's own native
mesh is already wanted), (3) outfit (`compositeLook.params`, already proven independent of both).
None of these three are live-editable on an already-spawned actor — every one is construction-time
only — so a future "change this NPC's body type" feature needs to snapshot all three (plus any
separate post-build CPD-color/hair/skin overrides already applied) and do a destroy-and-respawn
with the new choice, replaying everything else — the same pattern this file's own restore-on-reload
system already uses elsewhere, not a new design problem.

**One separately real, NOT investigated finding worth a pointer**: probing a real Employee NPC
(Rosalinda Mercer) to see what drives her workbench-using behavior found her `AIControllerClass`
and `AIPawnParams` are LITERALLY IDENTICAL to a generic Handyman NPC's — so her distinct behavior
is NOT a class-level behavior-tree difference reachable via the already-established
`AIControllerClass`/`AIPawnParams`-swap technique. It's most likely a separate RUNTIME ASSIGNMENT
(a reference to whichever building/workstation she's actually hired to) set by the game's own
hiring/placement system — genuinely unexplored this session, a real candidate for "give a custom
NPC a craft-station job" as a future, separate investigation, not solved here.

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

### 3r. A generic `ForEachProperty` walk over `FAssetData` is safe for one asset class and a real crash for another (2026-08-31)

`ForEachProperty`/reflection walks are documented elsewhere in this file (SS3l) as "100% safe every
time... it never actually calls anything" — true for reading a class's own DECLARED properties, but
NOT unconditionally true for walking every field of a STRUCT VALUE whose shape can vary by what kind
of object it describes. `IAssetRegistry:GetAssetsByClass()` returns an array of `FAssetData` structs
(see SS9c's own addendum for the tool this was built for) — a generic `ForEachProperty` walk over
every field of each returned struct worked cleanly for a plain `DataAsset`-derived class (244
entries, zero issues) and **crashed the game natively** partway through an identical query against
`SkeletalMesh` instead — almost certainly `TagsAndValues` or some other field `FAssetData` carries
that varies wildly in size/shape by asset type (mesh assets carry substantially more asset-registry
tag data than a plain small DataAsset does). **Fix: read only the specific, known-safe fields you
actually need (`PackageName`/`PackagePath`/`AssetName`, bracket-indexed directly), never a blind
`ForEachProperty` walk over a struct type whose full shape varies by what it's describing.** The
lesson from SS3l still holds for a class's own fixed property list; it does not extend to "every
struct returned from every API," and this is the second confirmed case (after SS10's own
`AnimNode_*` correction) where a previously-safe recipe needed a real, class-specific carve-out
rather than being trusted blindly on a new target.

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

**A native module's own bundled content root can be completely invisible to `retoc`'s offline pak
scan, while the game's own AssetRegistry knows about it fine (2026-08-31).** A real, live-resolvable
asset (`comp.ArchetypePreset`, confirmed valid via a live probe on multiple spawns) lives under
`/R5BusinessRules/Character/Customization/...` — NOT `/Game/...` — and a `retoc to-legacy` filename
scan across the ENTIRE `Content/Paks` folder found zero matches for it under any filter, even ones
confirmed to work for ordinary `/Game/`-rooted content moments earlier. `/R5BusinessRules/` is very
likely a separate native-module content mount (matching a real C++ module name, same convention this
project's own SDK-stub work uses), stored somewhere `retoc`'s generic pak scan doesn't reach — not a
sign the asset doesn't exist. **The fix: ask the game's own AssetRegistry directly instead of
continuing to guess offline.** `IAssetRegistry:GetAssetsByClass(FTopLevelAssetPath, OutArray,
bSearchSubClasses)` enumerates every registered asset of a given class, regardless of package root or
whether it's currently loaded — wrapped as `lbtestlistclass <ClassModule> <ClassName> [nameFilter]`
in this mod. One real gotcha hit building it: each result is an `FAssetData` STRUCT VALUE returned
from inside a `TArray` — the exact shape already documented above (`§2c`) — printing it naively gives
`"UScriptStruct: <hex>"`; the fix is the same `:GetFullName()`/`:ForEachProperty()`-on-the-value-
directly recipe, not a fresh problem. This tool is generally useful any time an asset's PATH is known
(from a live probe) but its exact identity/siblings need confirming and static extraction can't find
it — broader than just this one investigation.

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

**2026-08-31, later same day -- that remaining step is done, CONFIRMED LIVE with a real piece of
clothing rendering on a genuinely new, independent character.** Two more real findings on the way
there, both worth remembering:
- **A byte-relabeled copy of already-shipped content is NOT equivalent to a fresh cook, even under
  `/Game/Mods/...`.** First attempt: took Letty's own real `BaseParams`+`Group` (already proven,
  unmodified originals), renamed their `PackageName` fields via UAssetGUI to a new `/Game/Mods/...`
  path (the same text-edit technique already proven for retargeting a deep reference), retargeted the
  `BaseParams`' own import of the `Group` to match. Result: **MISS**, on both packages, via the
  asset-registry API -- confirmed directly, this is not a guess. Conclusion: `/Game/Mods/...` is
  necessary but not sufficient -- the package also needs an actual fresh cook (real cook-time identity
  metadata), not just a relabeled copy of bytes that were originally cooked as something else. This
  matches and extends this section's own earlier finding (SS19c-4): a real cook is what a genuinely new
  package needs, full stop, regardless of path.
- **The fix: author the container fresh in the Editor (so it gets real cook identity), but retarget its
  DEEP piece reference via the already-proven UAssetGUI text-edit trick afterward, leaving the
  container's own `PackageName` untouched.** Built a real `R5CompositeMeshComponentBaseParams` +
  `R5CompositeMeshGroup` pair from scratch via headless Editor Python (`unreal.AssetToolsHelpers`,
  `set_editor_property` for nested structs/`TMap`/hard object-reference arrays -- all worked directly,
  no crash-risk analog to the Lua/runtime construction wall documented above, since this goes through
  the Editor's own first-party object-authoring path, not live reflection into a running game process),
  referencing a placeholder piece purely to have something valid for the array slot. Cooked for real (0
  errors) -- confirmed resolvable via the asset-registry API immediately, and via this mod's own
  `resolveAsset` after its fallback fix. Composite build with the placeholder in place produced 0
  pieces (expected -- the placeholder is a deliberately gutted stub with no real mesh data). Converted
  ONLY the `Group` package to legacy, retargeted its ONE deep object-reference import from the
  placeholder to a real existing piece asset -- same two-row Import Data edit as every override in this
  file -- converted back to Zen, reinstalled. **Confirmed live: a real piece of clothing rendered on the
  new, independent character.** The container's own `PackageName` was never touched in this second
  pass, only the one deep reference -- exactly mirroring how an override already worked, just inside a
  brand-new container instead of an existing character's real asset.
- **One real Python-API gap worth knowing**: no exposed Editor-Python function can construct a
  `GameplayTag` from a raw string -- every `GameplayTagLibrary` function (`make_literal_gameplay_tag`,
  `make_gameplay_tag_container_from_array`, etc.) requires an ALREADY-VALID `GameplayTag` as input, and
  the struct's own `tag_name` property is read-only even in the constructor. The one tag-valued field
  in this whole chain (`GroupCategoryId`) had to be set via the Editor's own normal property-picker UI
  by hand, after registering the desired tag name in the project's own `Config/DefaultGameplayTags.ini`
  (a tag is just a declared string -- it doesn't need to match anything about the real target game,
  only exist in the AUTHORING project so the picker can find it). Confirmed safe to script everything
  else around this one manual step and re-verify it landed correctly via a follow-up read-back script
  before cooking. Also worth knowing: Python enum names for an exposed `UENUM` strip the leading `E`
  (`ER5BLCharacterSex` in C++ is `unreal.R5BLCharacterSex` in Python) -- an easy first guess to get
  wrong.
**The full recipe for genuinely new content, now proven start to finish**: (1) author the top-level
container(s) fresh via the Editor (GUI or headless Python, either works) at a path under
`/Game/Mods/...`; (2) cook for real; (3) if a deep reference needs to point at existing real content the
authoring project doesn't have, convert just that ONE package to legacy, retarget the reference via
UAssetGUI's Import Data grid, convert back to Zen -- never touch the container's own `PackageName` in
this pass; (4) package with `repak` and install as a normal content mod; (5) load it through
`resolveAsset`'s asset-registry fallback (or `AssetRegistryHelpers:GetAsset()` directly). Every step of
this is now individually confirmed, not theorized.

### 19d. A related, already-proven primitive worth remembering here

§2d's `Spawner.SetBodyPartMesh` already established the working recipe for swapping ONE
`BuildedCompositeMeshes` slot post-build: hide → `SetSkeletalMeshAsset` (fallback `SetSkeletalMesh`)
→ **`SetLeaderPoseComponent`** rebind to the actor's own body mesh → show. `SetLeaderPoseComponent`
is therefore NOT new/unproven engine surface the way this section's other findings are — it was
already a working, shipped technique before this investigation started; worth checking this file
before treating a call as untested just because it's new to the specific feature being built.

### 19e. Evaluated and rejected: Nexus Mods' own "Nexus Mods Author Tools" Editor plugin

Tried as a possible replacement for the `retoc`+`UAssetGUI`+`repak` final-packaging leg of §19c's
pipeline (`github.com/Nexus-Mods/NexusModsAuthorToolsUE`, official Nexus Mods plugin, UE 4.26→5.8).
Installed clean into this SDK-stub project (Editor module, only depends on the already-enabled
`EditorScriptingUtilities` — no engine/source changes needed) and read its actual packaging source
rather than trusting the README.

**What it does under the hood, confirmed from source**: cooks via the exact same
`UnrealEditor-Cmd.exe -run=Cook -Map=<pkgs> -cooksinglepackage` invocation this project's own headless
pipeline already uses, then packages via plain unmodified `UnrealPak.exe -CreateGlobalContainer=...`
(IoStore) or `-Create=...` (legacy) — the real Epic tool, not a third-party converter. Replicated its
exact `-CreateGlobalContainer`/`-PackageStoreManifest`/`-ScriptObjects` command line by hand against an
already-cooked test package (bypassing the plugin's UI entirely) and it produced a structurally normal
`.pak`/`.utoc`/`.ucas` triple, comparable in size/shape to a known-good `retoc`-built one — so a vanilla
stock-UnrealPak IoStore build is NOT inherently incompatible with this game's container format, which
was the one real open question worth checking here.

One theoretical concern turned out to be a non-issue: the plugin bakes the SDK-stub project's own name
(`LivingBaseExtended`, not the real game's `R5`) into the disk-mount-path string it hands UnrealPak.
Checked an already-shipped, confirmed-working pak from this project's own pipeline and it has the exact
same string baked in the same way (`/Game/Mods/LivingBaseExtended/...`) — IoStore addresses packages by
their `/Game/...` path via the packagestore manifest, not by that disk-side mount string, so the project
name never needing to match `R5` isn't a real requirement.

**Why it was rejected anyway**: the plugin's packaging service exposes zero `UFUNCTION`/`UCLASS`
surface — it's Slate-UI-only, with no Python or commandlet hook into it at all. Adopting it would mean
opening the full Editor and manually clicking through "Add Mod → select content → Package" dialogs for
every template, in place of the current pipeline's fast, scriptable `retoc`/`repak` CLI calls (the only
manual step already in that pipeline, the UAssetGUI soft-reference retarget, is a far lighter app to
keep reopening than the whole Editor). It would trade a scriptable step for a GUI-only one without
actually removing any manual work — a worse deal, not a better one. Uninstalled; not adopted. (Its
Nexus-upload and deploy/launch automation were not evaluated — the packaging-step question was the only
one that mattered for this project's pipeline, and it settled the question on its own.)

### 19f. SkinMaterials (the "Size" dimension) -- build started 2026-09-02

Picking back up the deferred `SkinMaterials` work (SS2's addendum): a `DA_Custom_SkinTypeKeys_Master`
utility asset was built under `/Game/Mods/LivingBaseExtended/` -- never cooked or shipped, its only
job is holding one correctly-tagged `SkinMaterials` entry per size so every future template can copy
the real `GameplayTag` key objects out of it via script instead of paying the manual property-picker
cost again. The one manual step (registering+picking `Customization.Morph.SkinType.Small/Medium/
Large` on this one asset) is done and verified. First real target: `DA_Custom_BodyType_HunterAsOrient`,
retargeting to the real `MI_Orient_Male_Small/Medium/Large` materials (confirmed to exist via
`pakcontents.xlsx`) -- this required resetting and redoing its `BodyMesh` retarget too, since adding
a new field means a fresh cook, which wipes the previous cooked retarget per SS5's rule (expected,
not a mistake).

**A real bug found and fixed along the way**: `unreal.EditorAssetLibrary.save_loaded_asset()` on an
asset LOADED from disk (as opposed to one just `create_asset()`'d in the same script) reported
success while silently NOT writing anything -- confirmed via the file's own mtime and raw bytes never
changing across two separate repro attempts. Root cause: the default `only_if_is_dirty=True` behavior
skips the write because editing via `set_editor_property` doesn't reliably mark an already-clean,
already-on-disk package dirty. Fix: pass `only_if_is_dirty=False` to force the write regardless. This
never surfaced in any earlier from-scratch template build (a freshly created asset is already dirty
from creation, so its first save always writes) -- it only bites a script that loads and edits an
EXISTING asset in place, which the "copy tag keys from a donor asset" trick above makes newly common
going forward. Written up in `Windrose_Unreal_SDK_Notes.txt` SS2 too.

**Also confirmed empirically**: the actual runtime selector that decides which of `SkinMaterials`'
Small/Medium/Large keys gets requested for a given spawn is NOT exposed anywhere reflection can see
it -- checked the full property list on both the pool-entry class and every "Skin"/"Size"-named class
in the SDK-stub headers (nothing), and checked a live `lbprobedump` of a native Warrior across 3
repeated spawns (Large/Medium/Small in sequence, per the original finding) for any GameplayTag that
might be the selector (only `Customization.UID.Armor.*`/`Customization.UID.Hairs` appear -- nothing
resembling a skin-size key). Practical conclusion: this is very likely intentional per-spawn visual
variety on the native side, not a bug to suppress -- the goal isn't to force a specific size, just to
make sure whichever size gets requested resolves to the CORRECT destination family's own material
instead of an empty/mismatched one. Populating all 3 keys with the destination's own real variants
achieves that regardless of which one the native selector picks.

**Status: CONFIRMED LIVE (2026-09-02).** `DA_Custom_SkinTypeKeys_Master` built and verified;
`DA_Custom_BodyType_HunterAsOrient` fully carried through -- source updated, re-cooked, all 4
soft-references retargeted via UAssetGUI (BodyMesh -> `SK_Orient_Male_01`,
SkinMaterials[Small/Medium/Large] -> the 3 real `MI_Orient_Male_*` materials), re-verified via a
fresh `tojson` export (all 4 correct, zero stray `/Engine/Transient` object references left),
packaged (`retoc to-zen` for utoc/ucas + `repak pack` on an empty dir for the header-only companion
pak, per SS9's own established rule to not use retoc's own bundled pak), reinstalled to the live
`~mods` folder, and tested in-game via `lbtestbodytypes .../DA_Custom_BodyTypeList_HunterAsOrient -
.../BP_NPC_Handyman_Hunter.BP_NPC_Handyman_Hunter_C -` + `lbprobedump`: real `probedump_*.txt`
output shows `CharacterMesh0` resolving to `SK_Orient_Male_01` with skin material
`MI_Orient_Male_Medium` -- both mesh AND skin now correctly matched to the same destination
family, confirming the whole mechanism end-to-end (only one spawn observed so far, landed on
Medium; Small/Large hold real materials too and there's no reason to expect them to behave
differently, but neither has been directly observed yet).

This is the proof-of-concept for the whole SkinMaterials mechanism, now proven, not just theorized.
Rolling it out to the rest of the male-source templates (Jasper/Axel/Mortar-as-African,
SenkaMaleAsAfrican, the 25-entry batch) is a mechanical repeat of this same recipe: for each, find
its destination family's 3 real Small/Medium/Large skin materials (via `pakcontents.xlsx`), run the
same "copy the master's 3 tag keys, assign 3 fresh placeholders" script (see
`add_skinmaterials_hunterasorient.py` as the template), re-cook, redo ITS OWN BodyMesh retarget
alongside the 3 new SkinMaterials ones (unavoidable per SS5 -- adding a new field means a fresh
cook, which wipes whatever was already retargeted on that cooked file), repackage, reinstall.

**Live retest note**: 3 repeat spawns of the same `DA_Custom_BodyTypeList_HunterAsOrient` override
all came back `MI_Orient_Male_Medium` -- no variation, unlike the earlier native-Warrior test (which
cycled Large/Medium/Small over 3 spawns). Likely this specific class (a Handyman-family NPC, not a
Senkamati mob) just doesn't naturally vary size -- consistent with this project's broader finding
that per-spawn variance is a property of the SPECIFIC class, not something universal. Not
investigated further since RedFalcon's actual ask was more useful: real user-facing size CONTROL.

### 19g. The manual UAssetGUI retarget step is no longer manual (2026-09-02)

Investigated after RedFalcon asked about `pip install UAssetAPI` -- that exact package doesn't
exist on PyPI (confirmed: 404, and no plausible name variant exists either), but the real thing it
was pointing at does: `UAssetAPI` is the actual open-source .NET library UAssetGUI itself is built
on (NuGet, not pip), and it's directly usable from plain Python via `pythonnet` (`pip install
pythonnet`) hosting a real .NET CLR inside the same process -- no Unreal Editor involved at all.

**Confirmed working, thoroughly**: downloaded the library's own NuGet package directly (a `.nupkg`
is just a zip file, fetched via the plain NuGet v3 flat-container URL, no `dotnet` SDK/restore
needed -- only the .NET 8 RUNTIME, already present system-wide) along with its 2 dependencies
(Newtonsoft.Json, ZstdSharp.Port), reflected the real API surface directly (`Type.GetMethods()`/
`GetFields()`) rather than trusting a webpage's possibly-approximate usage example, and built a
real Python module wrapping it. Verified three ways: (1) a plain read-then-write round trip with
no edits at all is BYTE-FOR-BYTE IDENTICAL to the original, both via the library's own
`VerifyBinaryEquality()` and an independent raw `cmp` diff; (2) a real single-field soft-reference
retarget (the exact operation this whole project's pipeline needed UAssetGUI's GUI for) reloads
correctly from disk in a fresh load; (3) independently cross-checked by UAssetGUI's own `tojson`
export -- a completely separate codepath agreeing the write landed correctly. Tested on both a
plain scalar soft-reference (`BodyMesh`) and a `TMap<GameplayTag, TSoftObjectPtr<...>>` entry's
value (`SkinMaterials`, selected by its already-set GameplayTag key's name) -- both work.

**One real C# gotcha hit and worked around**: `FSoftObjectPath`/`FTopLevelAssetPath` are STRUCTS
(value types), so reading a property's `.Value` and mutating nested fields on it edits a COPY --
silently a no-op. The fix: construct a whole new struct value and assign it back to the property's
`.Value` in one shot, never mutate through a chained property-getter.

**What this changes for the whole pipeline going forward**: the retarget step in this whole
project's SDK-stub recipe (WINDROSE SDK notes SS4/SS7/SS8) is no longer a manual, GUI-only,
one-asset-at-a-time chore -- it's now a plain, scriptable, batchable Python call
(`Tools/UAssetAPI/uassetapi_helper.py`, `retarget_soft_object_property()` /
`retarget_map_soft_object_value()`), runnable as part of the same kind of batch script this
project already uses for everything else. This does NOT remove the one remaining genuinely
unavoidable manual step (the GameplayTag property-picker, since neither this nor headless Editor
Python can construct a fresh tag from a string) -- but it removes the OTHER manual step that
used to follow every cook. The rest of the SkinMaterials rollout (Jasper/Axel/Mortar-as-African,
SenkaMaleAsAfrican, the 25-entry batch) can now be done as one script per template with zero
GUI interaction at all, instead of the multi-step Editor-handoff dance HunterAsOrient needed.

**`lbtestskinsize <Small|Medium|Large>` (2026-09-02) -- the scalable answer to "choose a size when
spawning."** Rejected the obvious-but-unscalable option (3 size-locked DataAsset variants per
template, tripling retarget work forever) in favor of a pure runtime fix needing zero new assets:
every human skin material observed so far (Senkamati/Orient/African, native or custom-retargeted)
shares the exact same `<Family>_<Sex>_<Size>` naming convention, always ending in
`_Small`/`_Medium`/`_Large`. The new command finds whichever material slot on the target's `Mesh`
is CURRENTLY a sized skin material (by name pattern, not a hardcoded slot index), derives that
family's own sibling path by swapping just the trailing size word, and `SetMaterial`s it in -- the
exact same safe swap mechanism `lbtesteye` already uses for eye color. Works on ANY already-spawned
actor's family automatically, custom-overridden or fully native, with no per-template engineering
ever needed again -- the family is read live from whatever material is already applied, not
pre-declared. **Confirmed live 2026-09-02, after one real fix.** First attempt failed:
`mat:GetPathName()` (used to derive the material's own folder for building the sibling path)
returned nil -- unlike `GetFullName()`, `GetPathName()` on a plain asset reference isn't a
proven-safe call anywhere else in this codebase (`GetFullName()` is used hundreds of times for
exactly this kind of path-string need). Fixed by switching to `GetFullName()` (format "ClassName
/Package/Path.AssetName") and stripping the leading class-name token. Deployed via `lbreload`
while the game was already running (confirmed working: no restart needed for a pure-Lua change).
Retested: `lbtestskinsize Small` on an already-spawned HunterAsOrient actor logged
`SetMaterial(2, MI_Orient_Male_Small) = true (was MI_Orient_Male_Medium)`, and a fresh
`lbprobedump` confirmed the applied material really is `MI_Orient_Male_Small` -- swapped in place,
no respawn needed, exactly as designed.

**Important scope clarification (2026-09-02, RedFalcon's own question)**: `SkinMaterials` is
TEXTURE-ONLY -- confirmed, not assumed. It changes which material/skin gets applied; it cannot and
does not change the actual mesh geometry. Every probe across every family (native or
custom-retargeted) shows the mesh name itself staying fixed regardless of which size material is
applied. Real body SHAPE/size (an actual bigger/smaller frame) is very likely a completely
separate, untouched system -- the composite mesh component exposes real functions for it
(`GetCurrentMorphControllers`, `SetMorphControllerValue`, `SetMorphToType`,
`GetAvailableBodyDecorData`), plus a per-actor `BodyMorph` vector property seen in earlier probes
(`X=0.0 Y=0.0 Z=1.0`). Investigating that system was explicitly deferred by RedFalcon's own choice
("stick with the texture-only fix for now") -- worth revisiting later if real mesh-level size
control becomes a priority, but don't assume `SkinMaterials`/`lbtestskinsize` do this; they don't.

### 19h. SkinMaterials rolled out to all 30 remaining male-source templates (2026-09-02)

The full male-source roster (Jasper/Axel/Mortar/Hunter/ScumMale as sources, 7 destination families:
Adventurer/African/Albion/Fable/Native/Orient/Scum) now all have a real, correct SkinMaterials map
-- the exact same recipe proven on HunterAsOrient, batched across all 30 remaining entries in one
pass using the new UAssetAPI helper (SS19g) instead of 30 rounds of manual UAssetGUI clicking:

1. One combined Python/Editor script reset BodyMesh + populated SkinMaterials (3 fresh
   placeholders, real tag keys copied from `DA_Custom_SkinTypeKeys_Master`) on all 30 entries,
   using `only_if_is_dirty=False` throughout (SS19g's dirty-flag fix).
2. One combined cook (`-Map=<60 packages>+...`) -- **a real gotcha hit here**: a BARE `-run=Cook`
   with no `-Map=` argument at all does NOT cook `/Game/Mods/...` content the way the project's
   own per-asset cooks always had (which always passed explicit `-Map=`) -- it only picked up
   ~280-528 generic Engine-default packages and silently produced ZERO of our target files, no
   error at all. Caught immediately by checking the cooked output directory was empty before
   proceeding to the next step -- always verify a cook's OWN OUTPUT FILES exist on disk, not just
   that the commandlet exited with "Success".
3. One combined Python (plain, pythonnet-hosted) script ran all 120 retargets (30 x [1 BodyMesh +
   3 SkinMaterials]) via `uassetapi_helper.py` -- no GUI step anywhere in this pass. Each call
   self-verified via its own reload-and-check; 3 additional entries independently spot-checked via
   UAssetGUI's own `tojson` agreed.
4. Packaged into the SAME 3 existing pak bundle names already live (`BodyTypeMaleSources2`,
   `SenkaMaleAsAfrican`, `BodyTypeMaleBatch25`) -- retoc to-zen + repak pack (empty dir) for the
   header-only companion pak, per SS9's rule. All 3 `.ucas` string-scanned clean before install
   (correct Small/Medium/Large counts per group, zero stray `/Engine/Transient` placeholder refs).
5. Install hit the expected file-lock wall: `.pak` overwrote fine but `.utoc`/`.ucas` were
   `Device or resource busy` while Windrose was still running (memory-mapped IoStore containers).
   Waited for the user to close the game, then finished the copy -- consistent with SS9's "needs a
   full restart" rule, just discovered from the write side this time rather than the load side.

**Confirmed live**: RedFalcon tested a couple of these post-install and confirmed the mesh+material
mismatch is fixed, same result as HunterAsOrient's own confirmation.

### 19i. Full female rollout + a genuinely new architecture: sourceless "prepping for the future" entries (2026-09-02)

Two follow-on phases, same session:

**Phase 1 -- the rest of the existing roster (27 entries)**: all 25 pre-existing female entries
(Adventurer/Albion/Scum/Senkamati as sources, 6-7 destinations each) plus 2 missed male ones
(`AdventurerMaleAsAfrican`, and `ScumMaleAsAfrican` which had been content-fixed in the male batch
above but never actually repackaged into its real live pak, `BodyTypeMaleSources` -- not
`MaleSources2`). Same recipe, same tooling, packaged back into the exact 7 fragmented existing pak
bundles this history had produced (`BodyTypeAdventurerAsAfrican`, `BodyTypeAdventurerCrossRest`,
`BodyTypeAlbionAsAfrican`, `BodyTypeCrossSources`, `BodyTypeMaleSources`, `BodyTypeScumAsAfrican`,
`BodyTypeSenkamatiAsAfrican`) rather than consolidating -- identified via string-scanning each
existing pak's own `.ucas` for which `DA_Custom_BodyType_*` names it actually contains, to avoid
shipping the SAME asset in two different paks at once (a real load-order risk, not just tidiness).
One real naming irregularity caught by checking rather than assuming: Adventurer's own FEMALE mesh
is `SK_Adventure_Female_01` (no trailing "r") while its MATERIALS use `MI_Adventurer_Female_*` (with
the "r") -- a genuine inconsistency in the game's own shipped asset names, not a typo on our side.

**Phase 2 -- a real scope change, RedFalcon's own framing: "we don't have walkers in those families,
that's the point... we are prepping for the future."** Audited the full family x source matrix
programmatically (not by eye) and found: only 5 of 7 families have a confirmed native MALE walker
(missing Fable, Orient), and only 4 of 7 have a confirmed native FEMALE walker (missing African,
Native, Orient, Fable) -- plus SenkaMale (the Senkamati mob source) only ever got 1 of its own 6
possible destinations built. The ask: build the MISSING SOURCE identities anyway, even with no real
NPC alive today that requests them, so the day Windrose adds (or we discover) a genuine Orient- or
Fable-native walker, retargeting to it costs nothing further.

This works because the technique never actually required a live NPC to test against -- only a real,
committed `GameplayTag` object matching what SOME class would someday request. Registered `Fable`
and `Orient` as new BodyType tags in `Config/DefaultGameplayTags.ini` (Adventurer/Albion/Scum/
Senkamati/African/Native already existed from earlier work), built 2 tiny seed assets, and did the
ONE unavoidable manual step (the Editor's own property-picker, same limitation as ever) to pick
each tag onto its seed -- 2 total picks for the whole phase. Every other entry's tag came from
copying an already-real tag object off an existing asset via script (African from any HunterAsX
entry, Native from any MortarAsX entry, Senkamati from SenkaMaleAsAfrican) -- zero further manual
picking. Also checked whether any OTHER families exist in the pak beyond the known 7
(`pakcontents.xlsx` scan of `Human/Regular/*/Meshes/`): found `Drowned`, `Drowned_Spitter`, and
`Ghost`, all genuinely unusable for this technique -- Drowned has its own dedicated Animation
Blueprint (implying a distinct skeleton, incompatible with the shared-rig mesh-swap trick),
Drowned_Spitter and Ghost are single-mesh one-off variants with no Small/Medium/Large split at all.
Nothing to add there; the 7 known families really are the complete set today.

Built 42 new entries in one pass: Fable (12: both sexes x 6 destinations), Orient (12: both sexes x
6 destinations), African-as-female-source (6), Native-as-female-source (6), and SenkaMale's 6
missing destinations. Naming: since both a male AND female version of the SAME family-as-source
needed to coexist for Fable/Orient (unlike every prior source, which only ever had one confirmed
sex), used explicit `FableMaleAsX`/`FableAsX` (female unqualified, matching the existing
`AdventurerMaleAsAfrican` vs `AdventurerAsAfrican` precedent) rather than inventing a new scheme.
All 42 cooked in one explicit `-Map=` pass (84 packages), all 168 retargets done via
`uassetapi_helper.py` with zero GUI steps, independently spot-checked via UAssetGUI on 3 samples,
packaged into a single new bundle (`BodyTypeFutureFamilies-Windows`) since this is genuinely new
content with no existing pak to overwrite.

**Net result of this whole family-coverage push**: every one of the 7 known human families
(Adventurer/African/Albion/Fable/Native/Orient/Scum) now has a real, tag-correct, SkinMaterials-
correct source identity for BOTH sexes, each covering all 6 other destinations as a target -- the
full N x N cross-family matrix RedFalcon asked for, minus only the fact that Fable/Orient/African-
female/Native-female sources have no live NPC to actually SPAWN as yet (their own entries exist and
are correct; nothing in the game currently requests their key, so nothing visibly changes until a
real walker for one of them is found or added). **Confirmed live**: tested `SenkaMaleAsFable` (brand new) on the Warrior mob class via
`lbtestbodytypes` + `lbremoveclothes all` + `lbprobedump` -- real dump shows
`BodyTypeParams=DA_Custom_BodyTypeList_SenkaMaleAsFable`, mesh=`SK_Fable_Male_01`,
skin=`MI_Fable_Male_Small`, both correctly matched. `SenkaMaleAsAfrican` (earlier batch)
re-confirmed alongside it. The Fable/Orient/African-female/Native-female SOURCE entries still
have no live NPC to spawn as (nothing requests their key yet, as expected/intended), but the
underlying mechanism -- new tag, correct mesh, correct SkinMaterials, all built without touching
a single existing template -- is proven live via SenkaMale's own newly-added destinations.

### 19j. A genuinely new alternative to reskinning: swap the AI brain instead, keep the real body (2026-09-02)

RedFalcon's own idea, tried as an alternative to the whole SkinMaterials/BodyTypeParams reskin
approach: instead of making a Senkamati LOOK human, give a native Senkamati MOB pawn the Gatherer/
Handyman AI brain instead of its own hostile Mob AI, keeping its real mesh/skeleton entirely
untouched. Motivated by an earlier finding that ordinary human poses already apply fine to
Senkamati bodies.

**The mechanism already existed** -- `Spawner.Spawn`'s own `aiControllerClassPath` parameter (used
once before to give Hunter the Warrior's own native mob AIController) -- so this needed a new test
command, not new engine surface: `lbtestai <ClassPath> <AIControllerClassPath> [friendly: 1/0]`
(`Spawner.TestSpawnWithAIOverride`).

**A real, directly relevant prior result surfaced BEFORE testing, not after**: `Config.
HANDYMAN_FOR_CREW`'s own comment already documented a 2026-07-07 finding that giving the Handyman
brain to re-skinned "crew" (a Handyman-lineage human-body class wearing Senkamati's own armor) did
NOT crash, but also did not wander -- the pawn just stood still, "their pawn lacks the worker data
it needs." Flagged this to RedFalcon as a likely-relevant precedent (different starting point --
raw native Mob class here, not a Handyman-lineage crew class -- so not guaranteed to recur, but a
real risk worth knowing going in) before running the first test.

**Real result, and it's a THIRD outcome, not either of the two anticipated ones**: the pawn came
out aggressive on the first test -- traced to a tooling mistake, not a real finding: the test
command's own first cut hardcoded `makeFriendly=false` in the underlying `Spawn()` call, an
entirely separate, already-proven faction-copying mechanism ("copy a live crew's faction onto the
spawn") unrelated to which AIController class is possessing the pawn. Fixed to default
`friendly=true` so the AI-brain question isn't confounded with an unrelated hostility setting.

**With that fixed, the real result**: the pawn is peaceful and DOES move/navigate (confirmed via
`AIControllerClass`/`Controller` both correctly showing the Handyman controller in a live
`lbprobedump`) -- genuinely different from the crew test's "just stands still" outcome, so a raw
Mob pawn accepting the Handyman brain's actual navigation decisions is a real, new, positive
finding. But it SLIDES rather than walks, stuck in its native idle pose the whole time. Root cause
confirmed via the same probe dump, not guessed: `AnimClass` is still
`ABP_SenkamatiCorrupted_Regular_Warrior_C` (the Warrior's own native Animation Blueprint, entirely
untouched by the controller swap -- pose/animation is a separate axis from which brain is deciding
where to go), and every speed-related property that AnimBP's locomotion state machine plausibly
reads is sitting at a stale `0.0` despite real physical movement:
`__CustomProperty_Speed_...`, `Want Forward Speed`, `Want Right Speed`, `GroundSpeed` all read 0.0
live. Strongly suggests the Warrior's OWN native Mob AIController was writing to these custom
properties directly every tick to drive its Blueprint locomotion state machine (rather than the
AnimBP reading `CharacterMovementComponent`'s own Velocity directly) -- the Handyman controller,
a completely different Blueprint hierarchy, has no idea these properties exist and never touches
them, so the AnimBP keeps reading "not moving" forever regardless of actual movement.

**Status**: genuinely promising partial result -- hostility is fully solved (existing
`makeFriendly` mechanism), navigation/wandering works (new finding, better than the crew
precedent), only the animation-sync layer remains broken, and its root cause is now understood
precisely, not mysterious. Not yet fixed -- next step, if pursued, would be finding what actually
writes to those Speed properties (worth checking whether `R5AICharacter`/`Character` base classes
expose a generic "sync locomotion properties from velocity" function that could be ticked manually
via Lua after possession, rather than needing to replicate the Mob AIController's own internal
logic) before attempting a fix. Deferred at RedFalcon's own pace -- pick back up whenever.

### 19k. RedFalcon's own reframe wins: swap the WALKER's body, not the mob's brain (2026-09-02)

Following straight on from 19j's real AnimBP wall, RedFalcon proposed the inverse: instead of
forcing the Senkamati MOB class to behave like a walker, take an already-perfect walker (correct
AI, correct self-computing locomotion) and retarget ITS `BodyMesh` to Senkamati's own real mesh
instead of any of the 7 established families. Zero new engine surface -- the exact same
`BodyTypeParams` mechanism used all session, Senkamati as a DESTINATION for the first time instead
of a SOURCE.

**Confirmed this is literally the same foundation the existing "Crew Reskin" system already stands
on** -- `Config.SENKA_FEMALE_BASE_CLASS = BP_NPC_Handyman_Gatherer_C`, and its own comment says so
outright: *"This is the Warrior's own trick (re-skin a human-skeleton pawn instead of using the
mob's own skeleton) applied to a female base."* The difference from Crew Reskin: that system puts
Senkamati's real ARMOR PIECES onto Gatherer's normal human body; this puts Senkamati's own actual
BODY MESH (`SK_Senkamati_Witch_01_Female` -- her own skin, no human clothes) directly onto
Gatherer instead, via `DA_Custom_BodyType_AdventurerAsSenkamati` (built the exact same way as
every other entry this session: BodyType tag copied from an existing Adventurer-tagged donor,
zero manual picking; SkinMaterials handles a real irregularity confirmed via `pakcontents.xlsx`
first -- Senkamati's own materials aren't organized like the 7 established families at all, female
has only ONE size, `MI_Senkamati_Female_Medium`, no Small/Large -- used that same material for all
3 SkinMaterials keys rather than inventing sizes that don't exist).

**CONFIRMED LIVE: it just works, no animation issues at all** -- since nothing about Gatherer's
own AI or AnimBP is touched, only her BodyMesh/SkinMaterials, exactly like every other successful
retarget this whole session. Real native proportions are available too: the actual Senkamati
Caster/Witch's own `BodyMorph` is already documented (`(0.5, 0, 0)`, this file's own SS on
per-instance body-shape variety) -- applies via the already-proven `lbtestbodymorph 0.5 0 0`.

**A real, expected limitation surfaced**: Gatherer's own composite-outfit slot roster doesn't
match the Witch's -- a native Mob class and a human NPC class run on different composite-outfit
systems entirely (mobs use one shared preset, human NPCs use another), so Gatherer's own outfit
was never built with slots for whatever Senkamati-specific extras (feathers, tribal decorations)
the Witch naturally has. `lbtestaddslot <slot> <meshPath>` already exists for building a missing
slot from scratch (`AddComponentByClass` + `SetLeaderPoseComponent`) but is marked
RISKY/EXPERIMENTAL in its own registration -- a real option, not yet a proven-safe one.

**A genuinely new, reusable probe capability came out of chasing her real color scheme**:
`dumpNamedStruct` (the "list this struct's own fields" recipe already used all over this file) was
flat, one level only -- a field that's itself a resolvable named struct (like
`BuildedCompositeMeshes[i].ColorData`) printed only as its TYPE string, never drilled into. Made it
properly recursive (depth-capped at 3, pure safety margin, nothing observed needs it) -- this now
helps every future probe in this file, not just this one case. Drilling one level into `ColorData`
found its real field name for the first time: `ColorIndexesMap`, a `TMap` -- a different, more
detailed shape than `FR5BLCharacterColorData.Value` (a DIFFERENT struct entirely, used by
`SelectedColors`/`ArchetypePreset.ColorData` elsewhere in this file), not the same thing as
previously assumed.

**A real, clean dead end, worth recording precisely so it isn't re-attempted blind**: reading that
`TMap`'s own entries from Lua failed three independent ways, no crash any time, ruling each out for
certain rather than guessing: (1) `pairs(fv)` -- "bad argument #1 to 'for iterator' (table
expected, got TMap)", this Map wrapper doesn't implement `__pairs`; (2) `getmetatable(fv)` --
returned `nil`, the metatable is locked down, no Lua-side introspection possible; (3) `fv:get()`
(the same unwrap idiom `dumpBuildedCompositeMeshes` already uses for `TArray` elements) -- no such
method. This UE4SS build's `Map` userdata exposes NONE of the standard reflection paths this file
already relies on for other types (`TArray` has `GetArrayNum()`/`Get(i)`; a named struct has
`ForEachProperty` via its resolved type) -- reading a `TMap`'s entries from Lua is, as of this
finding, not possible with anything tried so far. The more promising remaining path, not yet
tried: find and decode whatever static preset DataAsset actually stores Senkamati's default color
indices OFFLINE via `retoc`+`UAssetGUI` (the same technique that already decoded the CPD comment
map and both color palettes this session) rather than fighting a live runtime read -- her colors
are almost certainly baked into a preset asset, not randomized at runtime.

### 19l. Checking whether the vanilla human mesh truly lacks Senkamati's pelvis geometry -- two more offline dead ends, and the one path that actually works (2026-09-02)

Directly following 19k: RedFalcon's reminder that "senkamati has the pelvis area, the vanilla
gatherer doesn't" raised the real question -- is that geometry genuinely absent from the vanilla
human mesh (`SK_Adventure_Female_01`, Gatherer's own), or does it exist but sit hidden/unused?
With `LivingBaseExtended`'s Unreal Editor now up and running, tried inspecting both meshes
directly. Extracted `SK_Adventure_Female_01` and `SK_Senkamati_Witch_01_Female` (+ their `.uexp`
bulk data) from the real game paks via `retoc to-legacy`, same as always.

**Dead end 1 -- the Editor flatly refuses to load them at all.** Copied both into the SDK-stub
project's `Content/` and ran a headless `-run=pythonscript` inspection. Every Editor build (this
one included) hard-refuses to `LoadPackage` an unversioned cooked package -- `LogLinker: Warning:
... is unversioned and we cannot safely load unversioned files in the editor` -- this is a
hardcoded `FPlatformProperties::RequiresCookedData()` gate in engine code, not an ini/config
option; no amount of project settings changes it. Only an actual cooked/packaged (non-Editor)
executable can load these files, which the real Windrose game already is.

**Dead end 2 -- re-serializing to versioned form via UAssetAPI doesn't survive the round trip.**
Reused this session's own `UAssetAPI`-via-pythonnet infrastructure, this time loading the real
`.usmap` (`R5-5.6.1-0+UE5-e09d3821.usmap`, already sitting in `Other/` and the game's own
`ue4ss/` folder from earlier palette-decoding work) so the unversioned property blob actually
decodes correctly instead of misreading raw bytes as garbage. This worked -- `LODInfo`,
`PhysicsAsset`, `Skeleton`, `bHasVertexColors` etc. all decoded to sane, readable values. But
**the `Materials` property itself never appears at all** on either mesh's `SkeletalMesh` export --
consistent with this whole session's established architecture (material assignment happens at
runtime via `BodyTypeParams.SkinMaterials`, not baked as a static property on the base mesh).
Tried clearing the `PKG_UnversionedProperties` bit on `PackageFlags` and re-`Write()`ing to force
a versioned (fully-tagged) output the Editor could load -- this throws
`InvalidOperationException: Attempt to add name "None" to name map during serialization time`,
because most property names were never in the original unversioned file's name table (they were
resolved purely via the `.usmap` schema at read time, not stored as literal strings) and
UAssetAPI won't grow the name table mid-`Write()`. Fixable in principle (pre-register every
property name via `AddNameReference` before writing) but not worth doing, because of a deeper
problem: **the actual section/geometry data that would answer the real question --
`FSkeletalMeshLODModel`/render-data, which is where a "missing pelvis section" would actually
show up -- is custom-serialized bulk data, not a reflected `UProperty` at all.** Structurally
invisible to UAssetAPI/UAssetGUI regardless of versioned/unversioned status, for the exact same
underlying reason `CurveLinearColor` couldn't be read earlier this session (SS19k) -- a
`Serialize()` override bypasses the property-reflection system both tools are built on.

**The path that actually works: ask the live, already-cooked game process, not the Editor.**
The real Windrose executable *is* a cooked build, so it loads these packages just fine, and
UE4SS's Lua reflection already exposes the component's own real UFUNCTIONs
(`GetNumMaterials()`/`GetMaterial(i)`) regardless of the property-serialization wall above --
this is the exact same proven pattern `Spawner.TestSetSkinSize` already uses. Built
`Spawner.TestDumpMeshSlots(say)` / console command `lbtestmeshslots` (no args): dumps the
nearest/locked actor's live `Mesh:GetNumMaterials()` count plus each slot's material name. A
genuinely missing pelvis *section* (not just a hidden material on an existing one) will show up
as a real, smaller slot count on the vanilla mesh vs. Senkamati's own -- run it once on a stock
human walker and once on a Senkamati-bodied actor (e.g. `DA_Custom_BodyType_AdventurerAsSenkamati`
from 19k) and compare. Not yet run live as of this writing -- that comparison is the next step.

### 19m. "Barbies" -- the native-statue investigation dead-ends into the final answer, and the finalized unique-proportions roster (2026-09-02)

Following 19l's decisive negative result (statue `BodyType` resolution is unreachable offline no
matter which asset in the chain gets edited -- confirmed via the ACTUAL live test, not just theory:
retargeting `BP_AnimatedActor_BotC_Female_Standing_01`'s hardcoded mesh import survived a restart
and still showed a different family every spawn; adding a brand-new mesh override to the "static
look" `BP_AnimatedActor_BotC_Merchant_01` did the same -- `GetBodyType()` stayed `African` regardless,
and a full probedump confirmed the real per-slot outfit data (`DefaultParams`/`CustomizationData`)
has nothing to do with body/`BodyType` at all, only Armor/Facial/Hair pieces), RedFalcon's call:
statues are done, walker-as-statue substitute is the only path forward for that goal.

Also worth recording precisely so nobody re-trusts it: this same investigation found the game's
FULL `BodyType` tag vocabulary via a live probe -- 9 entries, not the 7 human families this whole
session has worked with: `Adventurer, African, Albion, Fable, GalenSkelton, Ksante, Native, Orient,
Scum`. `GalenSkelton`/`Ksante` are real named-character body types (`BP_NPC_GalenSkelton`,
`BP_NPC_Ksant`), not generic ethnicities -- two more potential one-off mesh-swap destinations like
Senkamati, not yet explored.

**A real correction to 19h/19i's own "four source classes" claim**: that section's first bullet
listed `BP_NPC_Citizen_Walker_C` (sex-changed) as a third confirmed-working `Adventurer` source --
RedFalcon confirmed live he's actually ineligible (re-rolls his archetype family on `BeginPlay`,
matching this file's own earlier, correct finding elsewhere) -- fixed in place at 19h/19i, don't
trust that stale line if seen anywhere else (e.g. an old build script comment).

**The real "Barbies" work, now underway**: full custom NPC bodies (chosen proportions + chosen
mesh/ethnicity + full clothing customization), building on the already-proven three-independent-
levers design (source class = shape, `BodyTypeParams` retarget = mesh/ethnicity, outfit = independent
third lever). The remaining unknown was "how many genuinely UNIQUE proportions actually exist among
the peaceful/fixed (non-randomizing) walker roster" -- answered by a fresh, corrected live sweep,
10 classes checked (`lbtestbodymorph` before/after `lbtestswapbodysex`, confirmed shape survives a
sex-change in BOTH directions now, not just male->female as 19h/19i established): `BP_NPC_Citizen_
Worker_C` is ALSO a confirmed randomizer (joins `Citizen_Walker`, excluded) -- 10 real candidates
remained, yielding exactly **7 unique `BodyMorph` values, not 10** (4 of the 10 share the identical
fallback default `(0.0, 0.0, 1.0)`):

| BodyMorph | Native source(s) | Sex-change needed? |
|---|---|---|
| (0.0, 0.0, 1.0) | `Gatherer` (F) **and** `Hunter` (M) | No -- both sexes already covered natively |
| (0.0, 0.618, 0.222) | `Herbalist` (F) | Yes, for Male |
| (0.0, 0.311, 0.288) | `Farmer` (M) | Yes, for Female |
| (0.0, 0.232, 0.226) | `Woodman` (M) | Yes, for Female |
| (0.0, 0.580, 0.309) | `BlackAxel` (M, `BP_NPC_Employee_CookingStation_BlackAxel_C`) | Yes, for Female |
| (0.0, 1.0, 0.0) | `MortarMan` (M) | Yes, for Female |
| (0.0, 0.246, 0.250) | `JasperCrowe` (M, `BP_NPC_Employee_WeaponStation_JasperCrowe_C`) | Yes, for Female |

(`Miner` and `RosalindaMercer` also matched the shared `(0,0,1)` fallback -- dropped as redundant,
already covered by Gatherer/Hunter.) **Final roster: 7 unique proportions x 2 sexes = 14 total
Barbie body variants, from 8 source spawns and 6 sex-change operations** (down from the naive
10-classes-times-2 approach) -- picking the "no sex-change needed" pair for the shared fallback was
RedFalcon's own optimization once the duplicate cluster was visible.

**A real tooling bug found and fixed along the way**: `Spawner.TestBodyMorph`/`TestSwapBodySex` both
printed `e.label` as the actor's "name" -- but for anything spawned via `lbspawnnoai`, `e.label` is
literally the fixed string `"SpawnNoAI"` (the tag argument that spawn call always passes), identical
across every class -- useless once you're running the same 3-command sequence back-to-back across
many different classes and trying to match log lines to classes afterward. Fixed both to resolve the
actor's own real class short-name via `GetClass():GetFullName()` (same idiom `RetrackOrphans`
already used elsewhere in this file) and prefer that over `e.label`.

Not yet started: the actual `BodyTypeParams` construction for all 7 x 2 = 14 variants -- see 19n
for the separate "every clothing/item slot available" work, which turned out to be its own real
investigation.

### 19n. "Every slot filled" -- built, broke on sex-variance, fixed, confirmed live (2026-09-02)

The player's own `DA_Hero_CompositeMeshComponentParams` turned out to be a dead end for this --
it only covers Underwear/Belt/Hairs/Facial (7 categories), NOT Torso/Legs/Waist/Headgear/Cape/etc,
because the player's actual armor comes from the live inventory/equipment system, not a fixed
customization list. Real per-slot Armor pieces live one level inside whatever single
`R5CompositeMeshGroup` a `DefaultParams` asset's own "Armor" category references (e.g. Merchant_01's
`..._Equipment_CompositeMeshGroup`) -- each individual piece (an `R5CompositeMeshParams` asset,
e.g. `DA_Armor_Regular_Character_Frog_01_CompositeMeshData`) is self-describing via its own
`MeshBodyPart` enum field (confirmed via direct UAssetAPI inspection), so array order/position
doesn't matter, only which pieces get referenced.

Built `DA_Custom_CompositeMeshGroup_FullSlots`, a new synthetic `R5CompositeMeshGroup` bundling one
real piece per body-part slot, and `DA_Custom_BarbieDefaultParams_FullSlots` (a new
`R5CompositeMeshComponentBaseParams`) referencing it under `Customization.UID.Armor`. Two new,
permanent, reusable techniques came out of this:
- **GameplayTag construction with zero manual GUI picking**: `tag = unreal.GameplayTag();
  tag.import_text("Customization.UID.Armor")` works directly from a plain string, confirmed live --
  a real improvement over every prior BodyType tag build this session, which needed a one-time
  manual property-picker pick for a genuinely new tag. Only requires the tag already registered in
  this project's own `DefaultGameplayTags.ini`.
- **Import-table array-element retargeting**: extending the single-hard-reference retarget
  technique from 19l/19m to an ARRAY of hard references (`CompositeMeshesParams`) -- same
  leaf-import + outer-package-import rename, just looped per array index. `R5CompositeMeshGroup`'s
  own array entries needed real placeholder sub-DataAssets (not lightweight engine types like
  `SkeletalMesh()`/`MaterialInstanceConstant()`), since `R5CompositeMeshParams` is itself a full
  DataAsset class with no Python-exposed lightweight constructor.

**Real wall hit and fixed**: `Sash` has ZERO assets anywhere in the entire game's content --
confirmed via a full pakcontents scan, not a search gap. Genuinely unused/vestigial slot; skipped.
**CORRECTION (2026-09-04): this was wrong, not a search gap that got closed later -- a genuine
false negative in the original method.** A full structural scan of all 486 real
`CompositeMeshData` pieces (19q, via UAssetAPI, not a filename/path search) found 5 real,
dual-sex, richly-attached `Sash` body-part entries. The reason the original pakcontents scan missed
them: `MeshBodyPart` is classified per SUB-ENTRY inside a piece's own `CompositeMeshesData` array,
completely independent of the piece's own file/asset NAME -- all 5 real Sash entries live inside
pieces literally named `..._Belt_01/02/03...` (e.g. `DA_Armor_Regular_Sailor_Belt_03_
CompositeMeshData`), so a search for the literal word "Sash" in asset paths/names was always going
to come back empty, regardless of how thorough it was. **General lesson: a body-part's real
CONTENT can only be found by reading the actual `MeshBodyPart` enum values inside each piece's own
data, never by searching for the body-part's name in asset paths/filenames** -- the two are
frequently unrelated.

**Real dead end from the "duplicate + rename a real extracted asset" shortcut**: tried reusing
Merchant_01's own real `DefaultParams` asset by duplicating+renaming the extracted file and
retargeting just its Armor reference via UAssetAPI. Resolved as a silent `params=MISS` in-game --
confirmed the reason via `spawner.lua`'s own `resolveAsset`/`resolveViaAssetRegistry` comments: the
`/Game/Mods/...` AssetRegistry-based resolution (the ONLY thing that finds a genuinely new package)
only works for packages actually COOKED BY THIS PROJECT under that exact path -- a raw file
copy+rename never generates that registry metadata, no matter how internally correct its content
is. Fixed by building the DataAsset properly from scratch via Editor Python instead (struct type
`R5CompositeMeshComponentRandomizedSection`, confirmed via direct `.usmap` schema query rather than
guessing -- Python-exposed fields `group_category_id`/`allow_customization`/
`composite_mesh_groups_by_body_sex`; the sex map's VALUE type is `R5CompositeMeshGroupForBodySex`
wrapping its own `composite_meshes_params` array, not a bare array -- also discovered from a
Python error message rather than guessed).

**Real wall hit and fixed**: first full 17-piece attempt (Merchant_01's Combatant/Musketeer armor +
GalenSkelton's own Cape/facial pieces) only built 6/17 on a live FEMALE test spawn (Gatherer) --
confirmed root cause via direct `SexVariations` map inspection on each piece: most of those sources
are MALE-ONLY content (no Female entry in their own `SexVariations` map at all), so the composite
build silently drops them for a female actor, no error, no log line. Re-sourced every piece from
confirmed dual-sex sets instead: `Set_Vanilla` (Torso/Legs/Feet/Headgear/Waist/Belt -- Belt's own
piece bundles Frog+Sling internally, confirmed dual-sex), `Armor/Default` (Strap), `Jeweler`
(Cape_02 -- RedFalcon's own tip, "jeweler has a lot of shared parts", confirmed correct),
`BlackBeard_Sailor_Mask_03` (the one dual-sex Mask variant out of 4 checked), and the shared
"Hero" pool's own sex-neutral Hairs_Afro_01 (no Male/Female suffix at all -- genuinely unisex,
unlike GalenSkelton's own single-sex Hairs asset).

**Genuinely deferred, not solved**: Eyebrows/Mustache/Beard/Whiskers. Mustache/Beard/Whiskers
confirmed to be genuinely MALE-ONLY concepts in this game's content (a full pakcontents scan found
zero female-equivalent assets for any of them -- makes real-world sense). Eyebrows genuinely has
real `_Male`/`_Female` asset pairs. Tried building a proper 3-key (Any/Male/Female) sex-keyed
`CompositeMeshGroupsByBodySex` map to handle this correctly -- the data structure itself verified
byte-for-byte correct via UAssetAPI reload (`{[Any]=FullSlots(10), [Male]=MaleExtra(4),
[Female]=FemaleExtra(1)}`, all real, all resolvable) -- but it built ZERO pieces live, a regression
from the 6/17 the flat single-key version got, including the Female-only single-entry case. Root
cause NOT YET FOUND -- reverted to the single-"Any"-key structure (now pointing at the corrected
10-piece dual-sex-only group) as the working baseline, confirmed live: **10/10 pieces built**
(`BuildedCompositeMeshes entries total = 10`) on the female Gatherer test. The facial-hair sex
split remains open for a future session with a fresh angle -- don't re-attempt the exact same
3-key Python construction blind; something about having multiple sex keys present simultaneously on
one section broke ALL of them, not just the sex-specific ones, which the single-Female-key-alone
failure rules out as "wrong key resolved" and points toward something structural in how multiple
map entries interact with the native composite-build code, or in how Python constructs multiple
struct instances sharing GameplayTag identity across map entries.

**Also confirmed along the way**: cooking ANY package that depends on an already-UAssetAPI-
retargeted package can silently re-cook that dependency FRESH FROM SOURCE, discarding the retarget
-- this bit twice in this session alone. The safe order is: cook everything once, retarget with
UAssetAPI, then package/install immediately with NO further cook step touching any retargeted
package (even indirectly, as a dependency) -- if another cook is unavoidable, always re-verify (or
just re-run the retarget script) on the freshly cooked output before packaging, never assume a
prior retarget survived.

**Waist mystery SOLVED (2026-09-03) -- RedFalcon's own theory, confirmed live: Torso and Waist are
mutually exclusive.** Three different real, dual-sex-confirmed Waist sources (Vanilla, Jeweler,
and `DA_Armor_Regular_Hero_Starter_Waist_02_CompositeMeshData` -- the last one independently
confirmed rendering correctly on a real, live, native `BP_NPC_Handyman_Farmer_C`) all silently
failed to build -- 11 `BuildedCompositeMeshes` entries instead of 12 -- every single time, on BOTH
a female (Gatherer) and male (Hunter) skeleton, ruling out per-asset validity and sex/skeleton as
causes. RedFalcon noticed the actual pattern from older probe archives: every native NPC he'd ever
successfully swapped a Waist piece on had NO Torso piece equipped at all. Built an isolated
single-entry test group (`DA_Custom_CompositeMeshGroup_WaistOnly`, containing ONLY the
Farmer-confirmed Waist piece, no Torso) -- confirmed live: Waist renders correctly the moment
Torso is absent. This is a genuine, real engine/design-level exclusivity rule in this composite
system -- not a bug in any of the tooling built this session, and not something to keep re-testing
with new Waist assets. **Practical implication for the "every slot filled" Barbie outfit: Torso
and Waist can never both be part of the same default loadout -- pick one as the baseline default,
leave the other as a real, working alternative reachable via the Clothes swap UI (which already
correctly lets you choose between them, just never display both at once).**

**Reinforcing an already-established rule this session briefly drifted from**: `Windrose_Unreal_
SDK_Notes.txt` SS9 already correctly states a new pak install needs a FULL GAME RESTART to take
effect -- mid-session, chasing the Waist mystery, a fresh brand-new-filename pak (`WaistOnly-
Windows`) reported `params=MISS` on its first live test, and the wrong fix was suggested (retry
the same command again without restarting, based on an unrelated earlier session's apparent
same-session success). RedFalcon restarted instead -- that's what actually fixed it. **Don't
re-suggest a same-session retry for a MISS on a brand-new pak again -- restart is the real, only
confirmed fix**, matching what was already written down.

**Final confirmation, cleanest possible case**: built a second isolated group with ONLY Torso +
Waist together (2 entries, nothing else) -- confirmed live: still only 1 of the 2 builds, not 2.
The mutual exclusion is real, clean, and unambiguous -- fully closed, no further re-testing needed
on this specific question.

### 19o. Facial hair (Eyebrows/Mustache/Beard/Whiskers/Hairs) -- four real bugs stacked on top of each other, all found and fixed (2026-09-03)

RedFalcon wanted facial hair addable to the Barbie outfit (kept sex-linked -- an earlier idea to
unlock cross-sex facial hair via a synthetic `SexVariations` entry was explicitly dropped: "never
mind then, just keep it sex linked"). Getting it working took peeling back four independent,
stacked failures, each fully real and each confirmed live before moving to the next:

**Bug 1 -- two `R5CompositeMeshGroup` references in one `composite_meshes_params` list silently
drops the second group, always.** First attempt built the outfit as its own group (`FullSlots`)
and the facial pieces as a second group (`MaleExtra`/`FemaleExtra`), then referenced BOTH under one
sex key's list (`[FullSlots, MaleExtra]`) -- exactly how `FullSlots_Sailor`'s own outfit had
earlier been split across an isolated 2-entry test with no problems, so multiple groups in one list
looked safe. It isn't: the second group in the list never builds, regardless of the first group's
own entry count (ruled out an ">10 entries" theory first by trimming the first group back to
exactly 10 and re-testing -- still broken). **Fix**: merge every piece -- outfit AND facial --
directly into ONE group's own array. One group, one list, just more entries in it.

**Bug 2 -- re-cooking a group whose entries were previously retargeted via UAssetAPI resets EVERY
entry back to a blank placeholder, not just the newly-added ones.** The retarget-with-UAssetAPI
technique only ever edits the raw import table of the already-cooked `.uasset` sitting in
`Saved/Cooked/` -- it never feeds back into the SOURCE `.uasset` under `Content/Mods/...`, which
the Editor keeps as empty placeholder pieces forever. So growing `FullSlots` from 10 to 15 entries
(to bake in 5 facial pieces) required a fresh cook to bake in the new array size -- and that cook
re-derived the WHOLE array from the untouched source, discarding the previous retarget of the
original 10 outfit entries too. Result: a pak that built literally nothing ("everyone is totally
naked and hairless") even though the facial slice had, by itself, verified correctly retargeted.
A blank placeholder piece at index 0 appears to abort the entire group's build, turning a partial
loss into a total one. **Fix, now a standing rule**: after ANY cook of a group that has ever been
UAssetAPI-retargeted, always re-retarget its FULL array (index 0..N-1), never just the slice that
changed -- exactly the pattern `retarget_all_facial_round.py` already used earlier in the session
for unrelated reasons; the mistake here was deviating from it for a "surely still fine" slice-only
shortcut.

**Bug 3 -- the real-game facial asset paths used as retarget targets were `R5CompositeMeshGroup`
CONTAINERS, not the `R5CompositeMeshParams` LEAF type this array slot expects.** Even with bugs 1
and 2 fixed, facial hair still built nothing. Built a new live-only diagnostic command,
`lbcheckclass <path>` (`Spawner.TestCheckAssetClass` in `spawner.lua`, resolves a path exactly the
way the composite pipeline does and prints `GetClass():GetFName()`), because the SDK-stub Editor
project cannot load these paths at all (same unversioned-cooked-package wall as 19l -- they're real
game content, never extracted into this project). Confirmed live: every one of
`DA_Hero_CompositeMesh_Group_Eyebrows_01_Male`, `_Facial_Hungover_{M,B,W}`, and
`_Hairs_Afro_01` is class `R5CompositeMeshGroup`, each wrapping exactly ONE real
`R5CompositeMeshParams` leaf piece one folder level down (`CompositeMeshGroup/` sibling to
`CompositeMeshData/`, e.g. `.../Eyebrows/CompositeMeshData/DA_CompositeMeshData_Hero_Eyebrows_01_
Male`). The raw import-table FName-renaming retarget technique never checks the target's actual
class, so it "succeeds" and reload-verifies fine while pointing at completely the wrong object
type -- the load silently fails to resolve as a piece at runtime instead of erroring anywhere
visible. **Fix**: always resolve one level deeper to the leaf `CompositeMeshData`-named asset
before treating any real-game facial/hair path as a retarget target. Confirmed leaf names don't
follow the group's own naming 1:1 -- e.g. `_Facial_Hungover_M` (mustache) leafs to
`DA_CompositeMeshData_Hero_Mustaches_Hungover`, `_B` to `..._Beard_Hungover`, `_W` to
`..._Whiskers_Hungover` -- so check each one live via `lbcheckclass` rather than guessing the
pattern from one confirmed example.

**Bug 4 -- not a bug: Mask (a real, mutually-exclusive slot) was still in the outfit list, and it
excludes facial hair the same way Torso excludes Waist (19n).** With bugs 1-3 fixed, Eyebrows and
Hairs built correctly but Mustache/Beard/Whiskers still didn't, on every test, consistently. Mask's
only real content is `DA_Armor_Regular_BlackBeard_Sailor_Mask_03` -- a narrow, one-off
BlackBeard-pirate-specific scarf mesh that visually covers the lower face -- and RedFalcon
correctly guessed the parallel to the Torso/Waist finding before a planned isolation test even
finished building. Rather than spend more effort confirming and working around a second
mutual-exclusion rule for a single niche asset, the call was to just drop Mask from the outfit
entirely ("only the blackbeard pirate has a scarf. i feel like we dont need to build to that
exception"). **Fix**: removed Mask from `FullSlots`, `FullSlots_Sailor`, and `FullSlots_Female`.
Confirmed live immediately after: all three combined DefaultParams now build every single intended
piece --

- `DA_Custom_BarbieDefaultParams_Regular_Male`: 15/15 (full outfit minus Mask + Eyebrows +
  Mustache + Beard + Whiskers + Hairs)
- `DA_Custom_BarbieDefaultParams_Regular_Female`: 12/12 (full outfit minus Mask + Eyebrows +
  Hairs -- correctly scoped, no male-only content anywhere near it)
- `DA_Custom_BarbieDefaultParams_Sailor_Male`: 15/15 (shirtless outfit including a real,
  independently-rendering Waist -- no Torso to conflict with it -- + all 5 facial pieces)

**Structural outcome, worth keeping as the standing pattern**: rather than one shared group
referenced by both sexes, each sex now has its OWN fully self-contained, fully-merged group
(`FullSlots` for male, `FullSlots_Female` for female, `FullSlots_Sailor` for the male-only
shirtless variant) -- outfit pieces reused by reference across groups where content is genuinely
sex-neutral (e.g. Hairs), sex-specific leaf pieces (Eyebrows_Male vs. Eyebrows_Female) built as
separate placeholders per group. This sidesteps bug 1 entirely (each DefaultParams references
exactly one group, never two) and keeps male-only content (Mustache/Beard/Whiskers) physically
absent from anything the female variant could ever load, rather than relying on a `SexVariations`
map lookup to gracefully no-op on a missing sex key (which the original 6-of-17-pieces failure
earlier this session showed does NOT gracefully no-op).

### 19p. Default to underwear with every slot still built, real belt Attachments (pouches/knife), and a genuine engine-crash found and guarded (2026-09-04)

RedFalcon's next ask: spawn a Barbie fully dressed (every slot built, so it stays swappable via
`lbtestclothes`/the Clothes GUI), but default the VISIBLE look to underwear with everything else
hidden -- not by leaving pieces out of the build, by hiding them after the fact.

**The exact mechanism already existed, just needed extracting and a timing fix.** `Spawner.
TestRemoveClothingPiece` ("Custom > Clothes > Remove", 19n-era) already hides via `SetVisibility
(false)` rather than clearing the mesh (so a slot stays re-dressable), and already applies a
modesty-guard underwear substitution for Torso/Legs (female) and Legs (male) when `Config.
CLOTHES_UNLOCK_ALL` is off (default) -- everything else, including a male's own Torso, gets a true
hide (shirtless), matching the already-established Sailor precedent. Extracted its core into
`Spawner.RemoveClothingOnActor(actor, slotArg, name)` so it can run on an actor the code already
holds a reference to, not just the nearest-in-front console-test target.

**Real timing bug, not a logic bug: the composite build does not finish synchronously inside
`Spawner.Spawn`'s own call.** Calling the hide-step immediately after spawn found 0 built pieces
every time (nothing to hide yet). Fixed with a short, capped, self-rescheduling poll (same
self-rescheduling idiom as this file's own toast ticker, but per-actor and ONE-SHOT instead of a
permanent shared ticker) -- checks `comp.BuildedCompositeMeshes` every 300ms, up to 12 attempts
(~3.6s, matching this file's own established "~12x per spawn" convention for post-build settling
elsewhere), then calls `RemoveClothingOnActor(actor, "all", name)` the moment it's actually
populated. `lbtestlook` now defaults to this behavior; pass `underwear=0` as its 5th console arg to
see the full dressed look instead.

**Belt pouches/knife -- confirmed real content exists, confirmed dual-sex, swapped in.**
RedFalcon's own question: do belt pouches need to pre-exist at build time the same way clothing
slots do, or can they be added live? Answer, confirmed by direct asset inspection (`retoc to-legacy`
+ the UAssetAPI/pythonnet reader, same technique as every other real-asset investigation this
session): a piece's `Attachments` array (socket-attached extras, baked `Rotation`/`Translation`/
`Scale3D` per entry, `AttachmentMesh` a soft path to a real `StaticMesh`) lives INSIDE the piece's
own `CompositeMeshesData` entry and is consumed at build time, same rule as `BaseMesh`/`ColorData`
-- build-time only, same as everything else in this pipeline. Scanned the real game's own shared
`/Regular/Belts/CompositeMeshData/` pool (30 belt pieces) for one matching RedFalcon's own
description from a live `lbsockets` scan ("two belt pouches and a knife") and found an exact match:
`DA_Armor_Regular_BlackBeard_Grenadier_Belt_01_CompositeMeshData` -- a single piece bundling 4
body-part sub-entries (Sling/Strap/Frog/Belt, same bundling shape our own Belt slot already had),
whose own "Belt" sub-entry carries exactly `SM_Belt_Misc_Knife_01` + `SM_Belt_Misc_Pouch_02` +
`SM_Belt_Misc_Pouch_01`, and -- checked explicitly before using it -- every one of its 4 sub-entries
has real Male AND Female `BaseMesh` values, safe to use on both the Male and Female Barbie variants
without the sex-mismatch silent-drop bug. Retargeted our existing Belt array entry (single-entry
retarget, same technique as always, no new group/piece construction) across all three groups.

**Confirmed live: attachments become real, independently-hideable components, not baked into one
fused mesh.** Built a throwaway diagnostic (`lbtestpouch`) that lists every `StaticMeshComponent` on
an actor (name/mesh/socket) and hides the first one whose mesh name contains "Pouch" -- confirmed
live: exactly one pouch disappeared, the other pouch and the knife stayed visible. This resolves the
open question from the original `Attachments` discovery (whether attachments are separate
components or fused into the parent piece) in favor of "separate, independently controllable."

**Real, now-fixed gap: the hide-all mechanism only ever swept `SkeletalMeshComponent`s.**
`Spawner.RemoveClothingOnActor`'s original sweep never touched `StaticMeshComponent`s at all, so
hiding the Belt slot hid only the belt's own skeletal mesh -- the knife/pouches, a completely
separate component class, stayed floating with nothing visibly holding them. Fixed by extending the
sweep to run over BOTH component classes (the exact same dual-sweep idiom `socketOccupants` already
used, for an unrelated reason, one screen up in this same file) -- zero new matching logic needed,
because the real attachment mesh names (`SM_Belt_Misc_Knife_01`, `SM_Belt_Misc_Pouch_01/02`) all
happen to contain "Belt", so the existing substring-based `clothingSlotOf` resolver already
classifies them as slot "Belt" for free. The modesty-guard underwear-substitution branch is
naturally never reached for these (guarded only ever fires for Torso/Legs, both skeletal-mesh-only
slots), so no special-casing was needed there either.

**A second, real bug in that same fix, caught by a live before/after `lbsockets` comparison, not
assumed fixed on the first attempt.** The dual-sweep's own per-component mesh-name resolver tried
`.SkeletalMesh` THEN `.StaticMesh` as a fallback, both inside ONE shared `pcall`. Accessing
`.SkeletalMesh` on an actual `StaticMeshComponent` throws (the property genuinely doesn't exist on
that class) -- which aborted the WHOLE pcall'd block before it ever reached the `.StaticMesh`
fallback lines below it. Confirmed live: every `StaticMeshComponent` (every knife/pouch/etc.)
silently resolved to an empty mesh name and never matched `clothingSlotOf` at all -- `lbremoveclothes
all` correctly hid every SKELETAL sub-piece (Sling/Strap/Frog/Belt itself) but left every single
attachment fully visible, with the socket-occupancy list identical before and after (expected --
hiding via `SetVisibility` never detaches a component from its socket, so `lbsockets`' own occupied
list can't distinguish hidden-but-attached from visible-but-attached; it only proves something is
STILL attached, not whether it's showing). RedFalcon caught this by running `lbsockets` before AND
after `lbremoveclothes all` and diffing the two dumps by eye -- a real, reusable verification
pattern for this exact class of "did the hide actually work" question, since neither `lbprobedump`
(now denylisted for `Attachments`, see above) nor the occupancy list alone can answer it; only a
before/after comparison of the SAME live view can. **Fix: split into two independent pcalls, one
per accessor family**, exactly matching `socketOccupants`' own already-correct pattern (which is
why `lbsockets` itself never had this bug -- its per-accessor-attempt pcalls were already isolated
from each other from the start). **General lesson, worth remembering for any future "try accessor A,
fall back to accessor B" pattern across two structurally different component/object classes**: a
property access that doesn't exist on a class isn't guaranteed to just return nil -- it can throw --
so bundling a multi-accessor fallback chain into ONE pcall risks the first failure silently
swallowing every later fallback attempt in the same block, not just itself.

**Known, deliberately not-yet-fixed asymmetry**: re-dressing the Belt afterward via `lbtestclothes`/
the Clothes GUI restores the belt's OWN mesh and visibility, but does not currently know to also
restore any sibling `StaticMeshComponent` attachments that were hidden alongside it -- `Spawner.
TestApplyClothingPiece` only ever restores visibility on the ONE component it's re-dressing. Fixing
the swap-BACK side symmetrically (finding and re-showing sibling attachments tied to the slot being
re-dressed) is real, scoped follow-on work, not done as of this writing.

**A genuine, reproducible engine crash found and guarded, not a Lua bug.** The very first live
`lbprobedump` against an actor wearing the new Grenadier belt crashed the whole game, twice,
reproducibly, mid-dump -- the log simply stops with no error, immediately after printing the
built-piece entry's `SexVariations` line and before its `Attachments` line, for the specific
built-piece entry that (unlike every other one) actually has non-empty `Attachments` content for
the first time this whole session. Root cause: `dumpNamedStruct`/`dumpUnknownStruct` (the two
generic, `ForEachProperty`-driven struct dumpers this whole probe system is built on) both do a
plain `val[pname]` bracket-index read of EVERY declared property, unconditionally, including
`Attachments` -- and reading THIS property, with genuinely non-empty content, apparently triggers a
hard native crash, not a catchable Lua error (a `pcall` around a Lua-level read protects nothing
against an actual engine-side crash -- established elsewhere in this file for other "invoking
unfamiliar engine surface" risks, and this is the same category: every piece ever probed before now
happened to have an EMPTY `Attachments` array, so this exact read path had genuinely never been
exercised with real data). **Fix: denylist the property NAME "Attachments" in both generic
dumpers** -- skip reading it outright and print a static "skipped, confirmed crash risk" placeholder
instead, rather than trying to read-then-catch it. This is a permanent, standing exclusion, not a
one-off workaround -- any future struct with a genuinely populated `Attachments` field will hit the
exact same crash through the exact same generic code path, since the dumpers are fully generic and
have no per-struct-type awareness. **Practical implication for anyone extending these two dump
functions**: a property name being safe to read on every struct tried SO FAR is not evidence it's
safe on a struct with genuinely different (non-empty, richly-typed) content -- this crash is the
concrete proof, not a hypothetical.

### 19q. A full structural catalog of every real per-slot item in the game, built once, browsable forever (2026-09-04)

RedFalcon's ask: rather than discover pieces for a slot (Belt, Strap, Sling, etc.) one at a time by
guessing a plausible family name and inspecting it, get a complete list of every real item that can
occupy each body-part slot, across the WHOLE game's content, in one pass.

**Fully mechanical, using tooling already built this session -- no new technique needed, just
applied at scale.** `pakcontents.xlsx` (a full asset-path listing from an earlier session) found 486
real `..._CompositeMeshData` piece assets under the usable "Regular Customization" pool (excluded a
further ~16 Boss-specific ones under a completely different, likely differently-skeletoned system).
Extracted all 486 in one `retoc to-legacy` pass (filtering broadly on `Customization/Regular`, then
narrowing locally to the `CompositeMeshData`-suffixed files), then ran one batch Python/UAssetAPI
script (the same usmap-loaded reader used for every real-asset inspection this session) over all of
them: for each piece, walk its own `CompositeMeshesData` array, and for each sub-entry record
`MeshBodyPart`, which sexes have a real `BaseMesh` (dual-sex or single-sex), and every `Attachments`
entry (socket name + attachment mesh, shortened to just the leaf asset name for readability). Zero
load/parse errors across all 486 pieces. Yielded 560 total body-part entries (some pieces bundle
multiple body parts internally, same shape as the Grenadier belt discovered in 19p; most bundle
exactly one).

**Real counts, worth having on record** (total entries / entries with real baked `Attachments`):
Legs 68/0, Torso 66/0, Headgear 65/0, Feets 63/0, Hands 57/0, Frog 37/0, Hairs 36/0, Sling 34/28,
Belt 30/29, Beard 16/0, Mustache 16/0, Whiskers 16/0, Waist 15/0, Strap 11/10, Cape 11/0, Eyebrows
11/0, Sash 5/5, Mask 3/0. **Belt, Sling, Strap, and Sash are where nearly every real piece carries
baked extras** (knives/pouches/bags/grenades/etc, same family this whole investigation started
with) -- every other slot's own `Attachments` array is empty across the entire game's content, not
just the handful this session happened to check by hand.

**A real correction to an earlier, wrongly-confident finding, caught only because this scan reads
structure instead of names.** 19n claimed `Sash` has zero assets anywhere in the game, "confirmed
via a full pakcontents scan, not a search gap." That confirmation was itself wrong -- a genuine
false negative, not a stale-but-once-true fact. This scan found 5 real, dual-sex, richly-attached
Sash entries, all living as an internal sub-entry inside pieces literally named `..._Belt_01/02/
03...` -- `MeshBodyPart` is classified per sub-entry, entirely independent of the piece's own
file/asset name, so a path/filename search for the word "Sash" was mathematically guaranteed to
come back empty regardless of how thorough it was. **General lesson, worth applying retroactively
to any other "X has zero assets" claim resting on a name-based search rather than a structural
one**: a body-part's real content can only be found by reading the actual `MeshBodyPart` enum
values baked inside each piece's own data -- never by searching for the body part's name in asset
paths, since the two are frequently and silently unrelated.

**Deliverable**: `Other/Barbie_Slot_Item_Catalog.xlsx` -- a Summary sheet (per-body-part counts),
an "All Items" sheet (all 560 rows, sorted by body part then by attachment-richness, filterable),
and one dedicated sheet each for Belt/Strap/Sling/Frog/Sash/Cape (the accessory-bearing slots) for
quick browsing without wading through the full 560-row list. Regenerating this after any future
content patch is the same mechanical 3-step pipeline (retoc extract -> UAssetAPI batch scan ->
openpyxl workbook build) -- no manual re-discovery needed ever again for this class of question.

**A live per-actor version of this same query (`lbtesttool aps`, `Spawner.
TestListAttachmentPoints`) went through two real, confirmed-live bugs before settling on its final
shape -- both stemming from the same underlying cause.** First cut filtered by a requested body
part, matching each currently-equipped `StaticMeshComponent`'s mesh name against `clothingSlotOf`
(the same substring resolver every clothing-slot command in this file uses). Two real problems
surfaced, both live-confirmed by RedFalcon comparing this command's output against a raw `lbsockets`
dump on the same actor, not assumed:
1. **Every `SM_Belt_Misc_*` mesh (19q's scan: 234 of 254 total attachment instances) contains
   "Belt"**, regardless of which structural sub-entry (Belt/Sling/Strap/Sash) it actually belongs to
   in the piece's own authored data -- so `clothingSlotOf` resolved ALL of them to "Belt" no matter
   which body part was actually requested. Confirmed on the Grenadier belt: `aps belt` reported 9
   attachment points, when the piece's own real per-sub-entry breakdown is Sling=2 + Strap=4 +
   Frog=0 + Belt=3 (RedFalcon: "i think its ignoring the type"). Root cause is structural, not
   fixable by a better string match: a live `StaticMeshComponent` genuinely does not retain which
   structural sub-entry it was built from (that classification only ever existed in the offline
   authored piece data), and even socket NAME isn't a reliable substitute -- this exact piece reuses
   `soc_Strap01F`, a Strap-sounding name, for its own Belt sub-entry.
2. **`SM_Drop_*` mesh names (19q's scan: the remaining 20 of 254 instances -- decorative,
   non-skeletal weapon-replica props like `SM_Drop_MusketT02_01`) contain none of `clothingSlotOf`'s
   clothing-family tokens at all**, so they matched NO body part and were silently excluded from the
   list entirely -- not miscategorized like the `SM_Belt_Misc_*` family, genuinely invisible.
   Confirmed on the Bucc Merchant Woman: her real `soc_Sling04B <- SM_Drop_MusketT02_01` showed up
   in a raw `lbsockets` dump but never in `aps belt`'s own output (RedFalcon: "the sling slot with
   the musket doesnt come up").

**Fixed by abandoning the body-part filter entirely, per RedFalcon's own call once bug 1's
structural cause was clear** ("since it displays all sockets, just make it lbtesttool aps, no need
to say belt") **and matching on the two real mesh-name prefixes directly instead of routing through
`clothingSlotOf` at all** (fixing bug 2 in the same pass, since the new match condition catches both
families by construction: `meshName:find("^SM_Belt_Misc_")` or `meshName:find("^SM_Drop_")` -- the
19q scan already established these are the ONLY two prefixes any real Attachment entry anywhere in
the game ever uses, zero exceptions). **Final command: `lbtesttool aps`, no argument, unfiltered.**
This is a strict improvement, not a loss of information -- the body-part filter never actually
distinguished anything real to begin with (bug 1), and dropping it fixed a genuine exclusion bug
(bug 2) for free.

**The same `SM_Drop_*` exclusion existed in `Spawner.RemoveClothingOnActor` (`lbremoveclothes`) too,
independently caught and fixed the same way** (RedFalcon: "i think sm_drop also needs to be added
to removeall") -- its own `StaticMeshComponent` sweep also only ever recognized `clothingSlotOf`
matches, so a decorative weapon-replica prop would survive `lbremoveclothes all` untouched while
every `SM_Belt_Misc_*` attachment correctly hid. Fixed by treating an unmatched `SM_Drop_*` mesh the
same as the already-caught `SM_Belt_Misc_*` family: falls back to slot "Belt" when `clothingSlotOf`
returns nothing, consistent with how both families already collapse into that one bucket for hide
purposes regardless of which structural sub-entry they actually came from.

### 19r. Real baked alignment for hand-attached items, a hidden-but-still-solid collision bug, `lblook` vs `lbtestlook` finally disentangled, and a fill-every-socket test command (2026-09-04)

**Alignment: `lbtesttool`-attached items initially used identity transform (no rotation/offset/scale),
which looked visibly wrong on anything but the simplest props** (RedFalcon: "it does have issues with
alignment of the items"). Fix reused the exact same 19q scan output rather than inventing a new
extraction pass: every real piece's `Attachments` array already bakes a real `Transform`
(Rotation/Translation/Scale3D) per `(socket, attachment mesh)` pair, so a second batch pass over the
same 486-piece legacy extract pulled every one of those pairs into `Config.
KNOWN_ATTACHMENT_TRANSFORMS`, keyed `"<socket>|<meshShortName>"` (112 of 254 total instances
resolved cleanly; the rest hit an unresolved edge-case struct shape and were skipped rather than
guessed at). `attachMeshAtSocket` (the shared core both `lbtesttool` and the new `fillall`, below, use)
looks up this table first and only falls back to identity when no real entry exists for that exact
pair. The engine's own rotation is a raw quaternion, but every other relative-rotation call in this
file uses `K2_SetRelativeRotation` with a Pitch/Yaw/Roll Rotator -- so a small from-scratch
`quatToRotator(x,y,z,w)` (the standard `FQuat::Rotator()` formula, with a Lua-version-safe
`atan2` shim since not every Lua build exposes `math.atan2`) converts once at attach time. Confirmed
live on the musket and the `beltSlot_01_lSocket` pistol pairing.

**Hidden items were still solid.** `SetVisibility`/`SetHiddenInGame` only ever touch rendering, never
collision -- a long hidden prop (a musket, a sling weapon) could still physically block movement or
raycasts (RedFalcon: "I have found that long items can still block things even when hidden"). Fixed
by pairing every hide with `SetCollisionResponseToAllChannels(0)` ("Ignore" all channels) and every
restore with `SetCollisionResponseToAllChannels(2)` ("Block" all) -- the same proven-safe API this
file already used elsewhere (the ghost-highlight ray-trace fix). Applied everywhere clothing gets
hidden or restored: `RemoveClothingOnActor`'s hide branch, `RemoveAllSocketAttachments`, and both
restore paths in `TestApplyClothingPiece`.

**A real, extended debugging detour that turned out to be two unrelated systems sharing one name.**
RedFalcon reported male Barbies randomizing hair/skin/belts on every spawn. Initial theory --
`bAllowCustomization` (real property `bAllowCustomization`, Python-exposed as `allow_customization`)
enabling a per-spawn reroll -- was flipped to `False` on all three `DA_Custom_BarbieDefaultParams_*`
assets and verified to stick via UAssetAPI, but the randomization persisted. Direct proof the theory
was wrong: Hunter's own real native `DA_NPC_Handyman_Hunter_CompositeMeshData` also ships
`bAllowCustomization=True`, on a section with exactly one group referenced for its sex -- and Hunter
obviously never randomizes in the base game. A single-choice picker cannot visibly reroll regardless
of the flag, so the flag was never the actual switch (the `False` change was kept anyway as
harmless and consistent with this file's own established rule that a fixed/authored character's
composite params should be non-customizable while a real player-facing picker stays customizable).
**The real cause, found only after re-reading `testbed.lua` in full**: `lblook <name>`
(`Testbed.SpawnBarbieByName`, a real command dating to 2026-08-13, unrelated to this session's own
`DA_Custom_BarbieDefaultParams_*` work) spawns its `Male_Barbie`/`Male_Barbie_Sailor` entries via
`Config.TOWNSFOLK_WALKER_CLASS`/`Config.CREW_CLASS` with `compositeLook = nil` -- no override
supplied at all -- then strips `SK_Armor_*` meshes to reveal skin/hair underneath. It deliberately
embraces whatever random native look that class rolls, by design, because it exists to test gear
against a different skeleton/proportion family than Hunter's. RedFalcon had been testing with
`lblook`, not `lbtestlook` (the real, purpose-built command for this session's actual outfit system) --
two commands that happen to share the word "Barbie" but are otherwise completely unrelated spawn
mechanisms. **Resolution**: `lblook` is left exactly as-is (it's doing its own, different job
correctly); `lbtestlook` is the one and only command for the real curated outfit. Worth remembering
permanently: never assume a report about one implies a bug in the other just because both mention
"Barbie."

**A new test command: fill every real attachment socket with one item at once**, so a single mesh's
fit can be eyeballed everywhere it might plausibly go without running `lbtesttool` once per socket by
hand (RedFalcon: "a command that lets me give it a slot item, and it puts that item in every slot so i
can see what works where"). `lbtesttool fillall <meshPath>` resolves the mesh once, then calls the
same `attachMeshAtSocket` helper once per socket in a fixed whitelist, skipping any socket the actor's
own skeleton doesn't actually have (`DoesSocketExist`). The whitelist itself, `Config.
KNOWN_ATTACHMENT_SOCKETS`, was originally derived mechanically from `KNOWN_ATTACHMENT_TRANSFORMS`'s
own keys, then replaced entirely with RedFalcon's own hand-curated 33-socket list after live testing
(each entry carries a plain-text location comment -- e.g. `soc_beltB` "Belt, Middle", `soc_Sling02F`
"Middle Left Front" -- to keep the raw names legible) plus the native weapon-equip sockets
(`Axe1h_backsocket`, `Axe2h_backsocket`, `Crossbow2h_backsocket`, `GSword_backsocket`,
`Halberd_backsocket`, `Musket_backsocket`, `swordSlot_lSocket`, `rapierSlot_lSocket`).

**The native weapon-equip sockets have no real baked transform and structurally never will, via this
system.** Checked directly: none of the 486 real pieces' `Attachments` arrays ever reference any
`_backsocket`/`swordSlot`/`rapierSlot` name -- those sockets are driven entirely by the game's native
weapon-equip logic, a completely separate system from the composite-outfit `Attachments` array this
whole investigation is built on. `lbtesttool`/`fillall` can still attach a mesh there (any socket that
exists on the skeleton accepts an attachment), but always at identity transform, and making an item
there actually behave like a wielded weapon is a distinct, unstarted future project, not something
this system can grow into by adding more transform data. One real pairing was confirmed useful as-is
without further work: `beltSlot_01_lSocket` + `SM_Drop_PistolT01_03`.

**Follow-up, closed out (2026-09-04/05): a handful of the curated 33 sockets still had no known real
transform** (`soc_Sling03B`, `soc_Strap01B/02B/03B/04B`, `soc_beltSlingF`, `soc_LanternLight` --
`soc_Sling02B` was already covered, keyed to `SM_Belt_Misc_BonesBelt_01_FR`). Rather than hand-tune
these in-engine, re-ran the raw scan across all 486 pieces looking only at `SocketName` values
(ignoring whether the transform itself parsed), to settle whether any real piece uses these sockets
at all. **Zero hits, for every one of the 7.** This isn't an extraction gap -- these sockets exist on
the skeleton (`DoesSocketExist` finds them) but no shipped item in the entire game ever places
anything there, so there is no real transform anywhere to extract. Decision: leave them at identity
transform; not worth hand-tuning for now.

### 19s. Belt is standalone; Sling/Strap are not -- a real dependency rule found by watching native NPCs (2026-09-07)

RedFalcon, from live observation across many native characters: "Belt does NOT always need a strap
and a sling when added, but it does appear that sling and strap never appear without a belt." The
"Custom > Clothes" GUI let all three be picked fully independently, which could put a Sling or Strap
on a character with no Belt at all -- something no real NPC in the game ever actually looks like.

**Fixed in `Spawner.TestApplyClothingPiece` itself** (so it applies through every entry point that
calls it -- the GUI, `lbtestclothes`, everything), right after the requested piece resolves and
before any of the existing fit-mechanism gates: if the requested slot is Sling or Strap, find the
actor's current Belt-slot component the same way the function already finds its own swap target
(`clothingSlotOf` on the component's current mesh name). If a Belt component exists but is hidden
(from a prior Custom > Clothes > Remove), restore its visibility/collision as-is -- deliberately
NOT swapping its mesh, so whichever Belt was already equipped before it got hidden comes back
unchanged rather than being silently replaced. If no Belt component exists at all (shouldn't happen
given 19n's "every slot filled" build, but handled rather than assumed away), apply a plain default
(`Belt`/`Belt`/`Set 1`) first. Either way, the originally-requested Sling/Strap piece still applies
normally right after. Belt itself gets no such check -- confirmed live as the one slot of the three
allowed to stand alone.

### 19t. `fillall`/`aps`/`lbsockets` grow sub-filters and a player-targeting mode; two more curated sockets; the real Belt/Sling/Strap linkage rule finished; and a random belt-layout roller (2026-09-05/07)

A batch of smaller, related tool upgrades, all still on the socket/attachment-placement tools from
19r/19s, in the order they landed:

**`lbtesttool fillall` gained real category sub-filters.** RedFalcon: "can you adjust fillall to have
sub options. so 'lbtesttool fillall soc \<mesh\>' or 'lbtesttool fillall belt \<mesh\>' and fillall
all \<mesh\> does what it does today." `Config.KNOWN_ATTACHMENT_SOCKETS` was restructured from a flat
`{ "socket", -- comment }` array into `{ socket=, location=, category= }` rows (`belt`/`sling`/
`strap`/`weapon`, matching RedFalcon's own refined "Type" column from a follow-up screenshot).
`Spawner.TestFillAllSockets(filterArg, meshPathArg, say)` now filters on `filterArg`: `all` (default,
unchanged), `soc` (belt+sling+strap combined -- i.e. every real attachment-point socket, the OPPOSITE
of the native weapon-equip group), or one specific category. `lbtesttool fillall` (no filter word)
still means "all," so the old bare form keeps working.

**A new `lbtesttool list \<meshPath\> socket1,socket2,...` command**, for validating a specific
handful of named sockets instead of a whole category sweep (RedFalcon: "a command that lets me give
it a slot item, and it puts that item in every slot so i can see what works where" -- clarifying an
existing ask into something new: "make it do lbtesttool list... where each option is a different
socket"). Unlike `fillall`, it isn't filtered against the curated whitelist at all (so it also works
for probing a socket that isn't on it), and unlike `fillall` it reports each named socket
individually if it doesn't exist on the target's skeleton, rather than just tallying a count --
built specifically for precise validation. `resolveMeshAndActorForFill(meshPathArg, say)` was
extracted out of `TestFillAllSockets`'s own preamble so both commands share the exact same mesh/
actor-resolution code instead of a second near-identical copy.

**Two more curated sockets added**: `beltSlot_01_lSocket`/`beltSlot_01_rSocket` (category `belt`) --
already had one real known-good transform on record (`beltSlot_01_lSocket|SM_Drop_PistolT01_03`).
Checking whether these were genuinely new sockets or just missed the first curation pass: confirmed
via a full raw-socket scan across all 486 real pieces that the OTHER 7 sockets still lacking a known
real transform (`soc_Sling03B`, `soc_Strap01B/02B/03B/04B`, `soc_beltSlingF`, `soc_LanternLight`)
have **zero** real usage anywhere in the game's own content -- not an extraction gap, genuinely no
shipped item ever places anything there. Decision: leave those 7 at identity transform.

**A live way to inspect the PLAYER's own sockets, not just a spawned test actor.** RedFalcon: "how do
i check the socket placement on a character. It has a pistol on its belt but it doesnt match any
existing sockets... on the player i mean." Every socket tool up to this point (`aps`, `fillall`,
`list`, `lbsockets`) only ever resolved its target through `findNearestSpawnInFront`, which walks
`Spawner.spawned` -- the mod's OWN tracked list of actors it spawned. The player's live pawn was
never in that list, so none of these tools could ever target it. New `getPlayerPawnAsActor()`
(same `UEHelpers.GetPlayerController().Pawn` read already proven safe in `lbplayerclass`) plus a
`useSelf` parameter threaded through `Spawner.TestListAttachmentPoints`/`Spawner.TestDumpSockets`:
`lbtesttool aps player` and `lbsockets player` (`self` also works as an alias) now target the
player's own pawn. Also re-confirmed live that `lbsockets` already reports OCCUPANCY, not just the
raw socket-name list (`socketOccupants`, from 19-something's own "what item is IN the socket" fix) --
so `lbsockets player` alone answers "which real socket is this equipped item on" directly, no need
to cross-reference against `aps` separately.

**The Belt/Sling/Strap dependency rule, finished properly.** 19s built the one-way "Sling/Strap
require Belt" check inside `Spawner.TestApplyClothingPiece`, but a MUCH older feature (2026-08-28,
"choosing a belt replaces all 3 since they have to be linked") was still forcing the same-numbered
Frog/Sling/Strap onto the character every time ANY Belt piece applied -- through the GUI AND through
what became `lbtestbeltroll` below. RedFalcon: "i also want to remove that from the clothing spawning
in the window menu. Belt should only spawn a belt, but sling and strap should always ensure theres a
belt. I'm guessing they should also check if there is already the opposite strap and sling and match
the type if its there." **Removed the old Belt-\>Frog/Sling/Strap auto-link entirely** (from
everywhere, including the GUI -- there is no reverse cascade any more). Extended the Sling/Strap
dependency block with a NEW rule: when applying a Sling and a Strap is already visible (or vice
versa), look up which "Set N" the existing one actually is (matching its current mesh name against
`Config.CUSTOM_CLOTHES`), and if a same-named row exists for the slot being applied, use THAT instead
of whatever was originally requested -- so an independently-picked Sling/Strap pair still reads as
one matching family when both end up present, without Belt forcing either of them. `findCurrentSlotComponent(actor, slotName)` was extracted as a shared helper (comp/curName/visible for
whichever component currently resolves to a given canonical slot) so this new opposite-matching
logic and the existing Belt-visibility check share one implementation instead of two near-identical
copies.

**`lbtestbeltroll` -- a random Belt/Sling/Strap layout roller, "for some fun."** RedFalcon: "I want
to make a command that generates a random belt layout. So 70% of the time, add a belt. then, of
there's a belt, 50% of the time added a strap, and 50% of the time added a sling. They are not
exclusive so both can sometimes appear" (percentages later reduced to 30% each, and made to clear
Belt/Sling/Strap first every call, matching the "clean slate" idiom already established for random
generation). `Spawner.TestRandomBeltLayout(say)`: clears all three slots, rolls Belt at 70%, and only
if that piece ACTUALLY applied does it go on to roll Strap and Sling independently at 30% each.
**Three real bugs found and fixed while dialing this in, each instructive on its own:**
1. **A `pcall`-vs-return-value crossed wire.** RedFalcon: "I think we got a crossed wire here. Only
   roll for strap and sling if a belt was rolled." The Strap/Sling loop was gated on the 70% dice
   roll HAPPENING at all, not on the Belt piece having actually gone on -- `pcall`'s own `ok=true`
   only means no Lua error was thrown, and `TestApplyClothingPiece` reports every real failure (no
   path resolved, mesh didn't resolve, no component in that slot) as a normal `return false`, not an
   error. Fixed by capturing and checking the ACTUAL return value, hard-stopping before the Strap/
   Sling loop if Belt didn't really apply.
2. **Every `math.random()` call in this entire mod was running unseeded.** Confirmed by RedFalcon
   testing: "i have not had a single roll without both a strap and a sling appearing... should be 9%
   but its 100%," then, after re-testing, "ok, i just got one only sling" -- proving the independence
   logic itself was correct, just fed a bad RNG. A search of both Lua files found zero
   `math.randomseed` calls anywhere, ever -- meaning Lua's default un-seeded sequence (fully
   deterministic, identical every module load/`lbreload`/game launch) had been silently driving
   EVERY random pick this mod has ever made, this feature included. Fixed with one seed call at
   module load (`os.time()` + `os.clock()`'s sub-second fraction, `collectgarbage("count")` as a
   last-resort fallback if neither `os` function is available in this sandboxed Lua build).
3. **The real, dominant cause, found last: the old Belt auto-link (see above) was firing on every
   single Belt roll**, force-applying Sling+Strap regardless of `lbtestbeltroll`'s own independent
   rolls -- this, not the RNG seed, is why "both" showed up essentially every time Belt landed.
   Removing the auto-link (see above) fixed this at the source; the earlier `skipBeltLinkage`
   opt-out parameter added as a stopgap was deleted again once the auto-link itself was removed
   entirely, since no caller needed the flag any more.
Final, confirmed-working shape: `lbtestbeltroll` clears Belt/Sling/Strap, rolls Belt at 70% (nothing
else rolls if it misses or fails to apply), then rolls Strap and Sling independently at 30% each --
genuinely all four outcomes (neither/either/both) possible, and now automatically type-matched by
the Sling<->Strap rule above whenever both land.

### 19u. `lbtestsocketitems` -- a full item/weapon randomizer driven entirely by a hand-authored spreadsheet (2026-09-07)

RedFalcon designed a genuinely bigger randomizer from scratch in a 5-tab spreadsheet
(`Other/SocketItems.xlsx`: Sockets, Item Ratios, Rarity Ratios, Items, Weapons) and asked to "dial in
the logic" together before any code was written -- the design was talked through and confirmed BEFORE
implementation started, not built first and corrected after.

**The data, mechanically converted, never hand-transcribed** (same standing rule as every other
generated table in this file): a Python/openpyxl script reads all 5 sheets and emits `Config.
SOCKETITEMS_SOCKETS` (35 rows: socket, plain-text location, `socType` soc/weapon, `beltpiece`
belt/sling/strap dependency, `locationTag` Front/Back/Side/Sheath/Hip), `Config.SOCKETITEMS_RATIOS`
(10 rows: which (Location,Type) combinations exist and their max Count, plus a `mandatory` flag),
`Config.SOCKETITEMS_RARITY_WEIGHTS` (Common=30/Uncommon=10/Rare=5), and `Config.SOCKETITEMS_ITEMS`/
`Config.SOCKETITEMS_WEAPONS` (47 and 111 rows). Two real data-quality issues, both handled at
generation time rather than by hand-editing the spreadsheet: one Item row's `Limit` cell was the
string `"1_L"` instead of a number (parsed defensively, kept as 1); several `Available Socket` cells
had stray blank entries from double-commas (dropped when splitting). Regenerate the same script
after any future spreadsheet edit -- same pattern as `KNOWN_ATTACHMENT_TRANSFORMS`/`CUSTOM_CLOTHES`.

**A real naming inconsistency caught before it became a bug**: the Weapons sheet's own `Location`
column calls the belt-holster sockets "Pistol," while the Sockets and Item Ratios sheets both call
that same location "Hip." Rather than reconcile the label text, eligibility for every item/weapon row
is decided purely by matching its `Available Socket` list against real socket names (which ARE
authoritative and consistent) -- the sheets' own free-text location/type columns are read for
convenience only, never trusted as the source of truth for grouping.

**RedFalcon's own rule set, confirmed in chat, then implemented literally:**
1. SocType "soc" (general belt accessories) and "weapon" (weapon-equip sockets) get separate rules.
2. Only sockets whose `beltpiece` is CURRENTLY VISIBLE are ever considered -- including for weapon
   sockets: every `*_backsocket` depends on Sling being visible, `swordSlot_lSocket`/
   `rapierSlot_lSocket`/`beltSlot_01_*Socket` depend on Belt. A weapon location's whole 60% roll is
   skipped outright if its required piece isn't visible, not just filtered afterward.
3. `soc_Strap_r` is the one MANDATORY exception (Item Ratios' own "Always When Strap is Visible"
   note) -- always filled whenever Strap is visible, not a 0..Count roll like every other group.
4. Tag synergy: once an item or weapon carrying a given tag is placed, anything else sharing that
   tag gets a 2x selection-weight bonus for the rest of the SAME generation pass, to encourage a
   themed look. Soc items are rolled entirely before weapons, sharing one growing tag set, so a
   themed accessory pick can influence which weapon gets favored afterward too (RedFalcon's own
   design choice was left open on ordering; soc-then-weapon was picked as the more natural default
   and flagged as easy to flip if it reads wrong).
5/6. Each weapon LOCATION (Back/Sheath/Hip) gets exactly ONE independent 60% roll, and a hit picks
   exactly one weapon for that whole location -- this alone is what makes "only one weapon per
   location" true by construction, not a separate rule that needed enforcing on top.
7/8. Rarity's Chance column is used as a RELATIVE WEIGHT for a weighted-random pick among the
   eligible pool for a given socket/location (not an independent per-item percentage) -- standard
   cumulative-weight roulette selection.

**Implementation shape** (`Spawner.TestGenerateSocketItems`, `lbtestsocketitems`): clears every
existing socket attachment first via the ALREADY-fixed `Spawner.RemoveAllSocketAttachments` (19r's
own true-destroy fix -- RedFalcon: "like the belts we want to clear all sockets at the start of each
call"), so repeated rolls never accumulate leftovers the way the original hide-only version once did.
Builds two lookup tables once from `Config.SOCKETITEMS_SOCKETS`: real sockets grouped by
`(locationTag, beltpiece)` for soc items, and by `locationTag` alone for weapons -- a socket whose
`beltpiece` lists MORE than one piece (`soc_Strap01F` is `"strap,belt"`, a real socket some Belt
pieces reuse for their own bundled strap sub-entry, per 19q) lands in BOTH groups; a shared
`filledSockets` set stops the two groups from ever double-booking it if both happen to roll it in the
same pass. Soc items run first (random count 0..Count per visible-piece group, random subset of that
group's real sockets, weighted item pick per chosen socket, respecting each item's own `Limit`
across the WHOLE run), then weapons (per-location 60% roll, weighted weapon pick, placed on
whichever of that weapon's own sockets belongs to the location that just rolled). Reuses
`attachMeshAtSocket` (the same shared per-socket attach+real-transform-lookup core `fillall`/`list`
already use) for every placement, so alignment/identity-fallback behavior is identical to every
other attachment tool in this file -- no new placement mechanism was needed for this feature.
**One accepted, rare edge case, not worked around**: a single weapon row (`SM_Drop_ClubArtifact_01`)
lists sockets in BOTH the Sheath and Back groups -- it's eligible for either location's independent
roll, and could in principle win both in the same generation pass (a club sheathed at the hip AND a
second one slung on the back). Weapons has no `Limit` column at all (unlike Items), and rule 6 only
requires one weapon PER LOCATION, not one per weapon type across the whole body, so this is treated
as acceptable rather than a bug worth special-casing for one row out of 111.

**Real crash found on first live use, fixed same day**: `resolveAsset` threw
`GetPackageNameFromLongName: Name wasn't long` on every single item/weapon. Cause: SocketItems.xlsx's
own "Asset" column is a bare `/Game/...` PACKAGE path with no `.AssetName` suffix -- every OTHER
caller of `resolveAsset` in this file (console-typed mesh paths via `lbtesttool`/`fillall`/`list`)
already normalizes a bare path to `Package.AssetName` before resolving (`resolveMeshAndActorForFill`'s
own fix), but the new `resolveMeshInfo` helper inside `TestGenerateSocketItems` skipped that step
entirely. Fixed by applying the exact same normalization there too.

**First tuning pass, after live testing (2026-09-07): a per-side TOTAL cap, on top of each
individual (Location, Type) group's own Count.** RedFalcon: "I'd like to create limits on items
based just on the side. So total of 5 soc items on the front and 8 soc items on the back total."
Front's own 3 groups (Belt=3/Sling=3/Strap=3) could otherwise sum to 9, well past what looks right on
one side of a body. New `Config.SOCKETITEMS_SIDE_CAPS = { Front = 5, Back = 8 }` is checked as a
shared ceiling across all soc groups on the same Location -- each group's own random roll is clamped
to whatever room remains under the cap, and a running total is updated as items actually land (not
just rolled). "Side" (`soc_Strap_r`) is deliberately excluded -- it's its own separate Location, and
mandatory rather than rolled, so a Front/Back cap was never going to touch it anyway. **A related,
proactive fix bundled with this**: group processing order is now shuffled per generation instead of
always walking `Config.SOCKETITEMS_RATIOS` in its fixed Belt/Sling/Strap table order -- otherwise
Belt (always listed first) would always claim a capped side's remaining room first, and Strap would
always be the one squeezed out on every single roll. Shuffling means any of the three can end up
favored, not always the same one.
