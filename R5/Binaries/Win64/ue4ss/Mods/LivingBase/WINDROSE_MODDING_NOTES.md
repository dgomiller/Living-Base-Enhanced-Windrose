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
  - [3s. Touching a genuinely new property/function shape can crash INSIDE UE4SS.dll itself, not the game -- and a from-scratch minidump parser can prove it without a debugger installed (2026-09-08)](#3s-touching-a-genuinely-new-propertyfunction-shape-can-crash-inside-ue4ssdll-itself-not-the-game----and-a-from-scratch-minidump-parser-can-prove-it-without-a-debugger-installed-2026-09-08)
  - [3t. A "starting step" breadcrumb printed through a project's own VERBOSE-gated `log()` wrapper is not actually unconditional (2026-09-16)](#3t-a-starting-step-breadcrumb-printed-through-a-projects-own-verbose-gated-log-wrapper-is-not-actually-unconditional-2026-09-16)
  - [3u. Repeatedly re-walking the SAME `TArray`-wrapped Lua array in a tight loop can crash inside UE4SS.dll's own reflection bridge, at a DIFFERENT instruction each time (2026-09-16)](#3u-repeatedly-re-walking-the-same-tarray-wrapped-lua-array-in-a-tight-loop-can-crash-inside-ue4ssdlls-own-reflection-bridge-at-a-different-instruction-each-time-2026-09-16)
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
  - [19v. The Barbie gender-swap saga -- six real bugs stacked on top of each other, the actual reassertion wall finally isolated (2026-09-08)](#19v-the-barbie-gender-swap-saga----six-real-bugs-stacked-on-top-of-each-other-the-actual-reassertion-wall-finally-isolated-2026-09-08)
  - [19w. A second crash saga, then a real pivot: authoring a genuinely new native NPC class from scratch, CONFIRMED WORKING LIVE (2026-09-08/09)](#19w-a-second-crash-saga-then-a-real-pivot-authoring-a-genuinely-new-native-npc-class-from-scratch-confirmed-working-live-2026-09-0809)
  - [19x. Turning the from-scratch class into an actual usable NPC: invisible mesh, a cold-load race, and the still-open sex/animation gap (2026-09-09)](#19x-turning-the-from-scratch-class-into-an-actual-usable-npc-invisible-mesh-a-cold-load-race-and-the-still-open-sexanimation-gap-2026-09-09)

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

**CLOSED, 2026-09-10 — the "untested" gap above is now tested, and confirmed dead too.** Built 7
custom `DA_Custom_MorphParams_*` DataAssets (barycentric extremes/halves/center dumped from the
player character creator — see the morph-pipeline section further down) and tried every remaining
lever on a live walking `BP_NPC_Handyman_Gatherer_C`:
- `comp.MorphParams = <asset>` pre-build (the original lever): asset resolves, sets, reads back OK —
  no visible change. Same signature as always.
- The exact "post-build write + rebuild-trigger sequence" flagged above as untested:
  `comp:StartCharacterEdit()` → `comp:SetMorphControllerValue(controller, value)` ×5 →
  `comp:EndCharacterEdit(true)` → `comp:ConstructVisualFromParams(-1)`. All calls succeed,
  `GetCurrentMorphControllers()` reads back the new values (and correctly PERSISTS them across
  subsequent calls) — **and still zero visible change.** This is the AR5AICharacter-family
  equivalent trigger the note above speculated about; it does not work either.
- Raw morph-target route, one level lower: `lbdumpmorphtargets` confirmed `SK_Adventure_Female_01`
  carries exactly 10 morph targets (`morph_zone_<body|head|nose|ears|brows>_x/_y` — the barycentric
  X/Y axes per zone, Z = the neutral base with no target). Driving them directly via
  `SkeletalMeshComponent:SetMorphTarget(name, weight)` on the base mesh: **every call silently
  failed** (0/10, no crash, no error — same "component present, call rejected" shape).
- `AnimInstance.BodyMorph` (`lbtestbodymorph`, the ORIGINAL closed investigation from the top of this
  section) was independently re-confirmed on the same target: this is the exact "write succeeds,
  changes nothing, traced to a Control Rig graph binding that doesn't re-evaluate after construction"
  finding from 2026-09-01, still true.
- **Both crash dumps captured while chasing this were `UE4SS.dll +0x261ae1`** (new address, not the
  earlier `Ar`-use-after-free `+0x3a9139`) — one from a wider (all-18-components,
  `K2_SetBodyMorphValue`-included) version of the raw pass, one from an unrelated plain
  `lbtestbodyspawn` ~37s later with no morph code involved at all, strongly suggesting session state
  had already gone bad (likely the same `lbreload`-wedge class of issue as §19x/19y) rather than the
  morph code itself being the direct cause — still, the raw pass was narrowed to one component/one
  call type as a precaution and left that way.

**Final verdict, walking AI-pawn family**: body SHAPE cannot be changed at runtime by any lever tried
across two full investigations (2026-09-01 and 2026-09-10) — controller values, the asset reference,
raw morph targets, and the anim-instance Vector all either get silently ignored or commit-but-don't-
render, consistent with a Control Rig binding baked once at construction that nothing post-spawn can
force to re-evaluate. **Body-shape variety on the walking Barbie roster comes ONLY from mesh/family
selection** (the `DA_Custom_BodyType(List)_<X>As<Y>` retarget grid — already shipping, confirmed
working: different donor families genuinely render different base proportions). Do not re-open this
without a fundamentally different technique (e.g. a real Control Rig / anim-blueprint patch, well
outside Lua's reach) — every remaining "untested" lever in this section has now been tried.

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

**2026-09-08 addendum — "Main/Secondary/Detail" renamed to Color1/Color2/Color3, and a full
per-body-part CPD color reference table, from RedFalcon's own real testing across the whole game.**
The master material's own NameMap comment (this section's own earlier paragraph) names CPD03-05
"MainColor/SecondaryColor/DetailColor," and that naming was carried into `lbtestcpdcolor`'s own
arguments -- but RedFalcon's own hands-on testing across every colorable body part found those
labels overpromise a consistency that isn't really there: "they aren't used in a reliable way to say
main and detail or anything like that." Renamed throughout (`Spawner.TestSetCPDPaletteColor`'s own
params, `lbtestcpdcolor`'s usage text) to the neutral **Color1/Color2/Color3** -- same 3 floats
(CPD03/04/05), same write mechanism, just without a role name that doesn't actually hold across
pieces.

**The real per-body-part reference**, now `Config.CPD_BODYPART_COLOR_INFO` (keyed by the same
BodyPart ordinal `lbtestcpdcolor`'s first argument takes) plus `Config.CPD_HAIR_COLOR_NAMES`
(superseding the earlier hex-decoded best-guess pass with RedFalcon's own confirmed-in-game names)
and `Config.CPD_CLOTH_COLOR_NAMES`:

| BodyPart | Part | Palette | Color slots used | Notes |
|---|---|---|---|---|
| 1 | Eyebrows | hair (0-8) | 1 | |
| 2 | Beard | hair (0-8) | 1 | |
| 3 | Hair | hair (0-8) | 1 | |
| 4 | Headgear | cloth (0-23) | 3 | shares its BodyPart ordinal with Head, below |
| 4 | Head (bare) | cloth (0-23) | 1 (Color1 only) | Senkamati Head never changes color at all |
| 5 | Scarf | cloth (0-23) | 1 | only Blackbeard Pirate has this piece |
| 6 | Cape/TorsoCloth | cloth (0-23) | 1 (which slot varies by piece) | write the SAME value to all 3 slots to be safe; Senkamati TorsoCloth never changes color |
| 7 | Torso | cloth (0-23) | 3 | |
| 8 | Belt2 | none | 0 | |
| 9 | Belt1 | none | 0 | |
| 10 | Sling/Neck | none | 0 | Neck is only used by the Senkamati Witch |
| 11 | Strap | none | 0 | |
| 12 | Frog | none | 0 | |
| 13 | Legs | cloth (0-23) | 3 | |
| 14 | Shoes | cloth (0-23) | 3 | |
| 15 | Waist | cloth (0-23) | 1 (Color3 only) | Color1/Color2 have no visible effect here |
| 16 | Gloves | cloth (0-23) | 3 | |
| 17 | Moustache | hair (0-8) | 1 | |
| 18 | Whiskers | hair (0-8) | 1 | |

**The two genuinely separate palettes, confirmed distinct atlases, not one palette reused at two
sizes**: cloth/general body parts (Torso/Legs/Shoes/Gloves/Waist/Hat/Scarf/Cape) index into the
24-entry `CRV_CharacterClothPalette` (Harp/IceBerg/Ivory/BlueCharcoal/BlackOlive/WoodBark/Crimson/
Carmine/Bordeaux/PaleOrange/YellowGreen/PaleGold/EmeraldGreen/ColdGreen/OliveGreen/LightBlue/
NavyBlue/OceanBlue/Purple/Violet/Lilac/ChocolateBrown/BrownLeather/BrownCopper, indices 0-23); the
5 hair-family body parts (Hair/Eyebrows/Beard/Moustache/Whiskers) index into a SEPARATE, smaller
9-entry atlas instead (indices 0-8): **Ash Brown, Charcoal, Light Brown, Blond, Copper, Chocolate,
Slate, Silver, Salt and Pepper** -- confirmed by RedFalcon in-game across the whole roster, not
inferred. (An earlier attempt to name this 9-color hair atlas by decoding its raw
`CurveLinearColor` asset bytes directly -- retoc extract, UAssetGUI `tojson`, then a hand-validated
binary parse of the resulting base64 property blob, gamma-corrected linear-to-sRGB -- got real hex
values and reasonable-looking guesses, several of which happened to land close, but RedFalcon's own
tested names are the authoritative ones now; the decode method is kept on record since it's a
genuinely reusable technique for any future CPD-driven palette this game ships.)

**Two real per-piece exceptions, not slot-count differences**: the Senkamati Head and Senkamati
TorsoCloth pieces specifically never change color at all, regardless of which slot is written --
these are content-level exceptions on those two specific meshes, not a gap in the CPD mechanism
itself (every other Head/TorsoCloth-family piece responds normally).

**Not yet tested, planned for later**: Eye color (CPD15 on the base body mesh, plus the separate
5-variant discrete material swap already documented earlier this section) -- RedFalcon: "i plan to
verify eyes tomorrow."

**RESOLVED 2026-09-08 -- eye color verified, and it collapses to a much simpler picture than the
cloth/hair split suggested.** Same extraction/decode technique used for the hair palette (retoc
`--filter "CRV_EyeColor"` -> UAssetGUI `tojson` -> the same hand-validated binary curve parser,
zero assertion failures across all 8 entries) found a THIRD separate atlas,
`/Game/Common/Textures/Gradients/CharacterEyePalette/CRV_EyeColor_00..07`, confirmed live by
RedFalcon against every real NPC he checked: **Brown, Hazel, Amber, Green, Aquamarine, Blue, Gray,
Silver** (`Config.CPD_EYE_COLOR_NAMES`). Deliberately NOT folded into `Config.
CPD_BODYPART_COLOR_INFO` -- eyes write CPD15 on `actor.Mesh` directly (`lbtestbasecpd 15 <index>`),
not on a `BuildedCompositeMeshes` piece via `lbtestcpdcolor`'s normal bodyPart argument, so they
need their own write path, not the per-piece table.

**The real payoff: RedFalcon's own side-by-side comparison closed out the earlier "two independent,
both-real levers, meant to be used together" theory from this section's 2026-09-02 update.** Direct
comparison found the discrete `lbtesteye` material variants (Blue/Brown/Green/Grey/Default) all
visually MATCH their CPD15 counterparts -- "All the CPD colors match their lbtesteye counterparts so
we dont need the testeye ones." Only one discrete variant survives: `MI_EyeRound_Evil_01` (also the
Senkamati Caster's own real native eye material) is genuinely emissive/glowing in a way CPD's own
palette can't reproduce -- kept as its own separate swap, renamed **"Glowing"** for the user-facing
command (`lbtesteye Glowing` / `lbtesteye Default`; the underlying asset name stays `Evil` since
that's the real shipped material's own name). `Spawner.TestSetEyeColor`'s own `EYE_COLOR_VARIANTS`
list narrowed from 5 entries to this 1.

**CORRECTION (2026-09-14)**: the "visually redundant" comparison above only held for the specific
NPCs RedFalcon happened to check that day -- he has since confirmed **some NPCs genuinely use one of
the 4 discrete `MI_EyeRound_<Blue|Brown|Green|Grey>_01` materials natively, not the CPD15-driven
plain `MI_Eye`**, so `lbtestbasecpd 15 <index>` has no visible effect on them (there's no CPD15
override to move -- the color IS the material). `Spawner.TestSetEyeColor`'s `EYE_COLOR_VARIANTS`
restored to all 5 entries (Blue/Brown/Glowing/Green/Grey) so `lbtesteye` can still force one of these
NPCs into a specific color when CPD alone won't touch them; `Spawner.TestReadEyeColor` extended the
same "check the eye material's own name" detection it already had for Evil/Glowing to the other 4,
mapping each back to its matching `Config.CPD_EYE_COLOR_NAMES` index (Blue=5, Brown=0, Green=3,
Grey="Gray"=6) so Read Current still shows a sane swatch for these NPCs in the GUI instead of nothing.

**Appearance customization is now fully mapped, end to end**: Gender, Body Type (mesh/ethnicity, via
`BodyTypeParams` retarget), Body Shape (proportions, via `BodyMorph` -- 7 unique values x 2 sexes,
19m's own roster), Skin Tone (comes free with the Body Type mesh swap), Hair Style (mesh swap), Hair
Color, Cloth/Garment Color (Torso/Legs/Shoes/Gloves/Waist/Hat/Scarf/Cape, all via the same CPD
mechanism), Eye Color, and the one "Glowing" discrete eye variant -- every category on RedFalcon's
own "custom NPC from scratch" checklist now has a real, confirmed, working mechanism. Full
per-body-part reference for all of the CPD-driven categories: `Config.CPD_BODYPART_COLOR_INFO` /
`CPD_CLOTH_COLOR_NAMES` / `CPD_HAIR_COLOR_NAMES` / `CPD_EYE_COLOR_NAMES` in config.lua.

**RESOLVED 2026-09-07 -- the 24-entry cloth palette's real RGB values decoded too, and it took a
genuinely different technique from hair/eye.** The hair/eye binary parser (retoc extract ->
UAssetGUI `tojson` -> hand-validated RawExport byte layout) does NOT work on
`CRV_CharacterClothPalette` -- it's a `CurveLinearColorAtlas` (24 nested curve-sets), structurally
different from a standalone `CurveLinearColor`; every offset tried hit the wrong marker byte.
Built a live UE4SS reflection probe instead (`lbprobeclothpalette`/`Spawner.TestProbeClothPalette`)
to try reading `atlas.GradientCurves` directly in-game, following this project's own "ask the
running game instead of reverse-engineering blind" principle -- it successfully resolved the atlas
and its 24-entry array, but every `FRichCurve.Keys` came back **empty** for all 24 entries x 4
channels. Not a wrong property-name guess: this is cooked-away editor-only authoring data -- the
atlas keeps no live keyframes at runtime at all, only whatever baked texture the shader actually
samples. Left `lbprobeclothpalette` in place as a documented dead end (confirmed, not attempted).

The actual fix: **FModel's own "Save Properties" JSON export**, which understands
`CurveLinearColorAtlas`/`FRichCurve` as real reflected classes (unlike UAssetGUI, which is why the
binary route failed) and dumps genuine `Time`/`Value` keyframes directly -- no parsing needed at
all. One real surprise in the data: each of the 24 cloth colors is a **true 3-stop gradient**
(Time 0 / 0.5 / 1.0 per R/G/B channel), not a flat color like hair/eye's simple root-tip pair --
reads like a shadow/base/highlight shading ramp baked per named color. Same linear->sRGB gamma
correction (IEC 61966-2-1) applied on top. Full swatch reference (all 24, all 3 stops, real hex):
see the "Cloth Color Palette" artifact published this session. The FModel export's own filenames
already carried the real names (`CRV_ClothColor_00_Harp.json`, etc.) -- independent confirmation
that `Config.CPD_CLOTH_COLOR_NAMES` was already correct.

**2026-09-08: the first real GUI built on top of all this (LivingBaseSpawnMenu's new "Custom"
tab) immediately surfaced a real durability bug in the CPD write mechanism itself.** Full build
details live in `project_livingbase_spawn_menu` memory, not duplicated here -- short version: a
target-gated 7-category cloth-color panel (Torso/Legs/Waist/Hands/Feet/Hat/Cape, per-slot swatches
for the 5 that use all 3 CPD floats) shipped clean, including a "Read Current" round-trip to
populate swatches from a target's real colors. Read Current is what caught this, because it's the
first thing in this whole project's history to check a color back MORE than a few seconds after
setting it.

**The bug**: `SetCustomPrimitiveDataVector4` on a piece's leaf mesh returns `true` and the color
visibly changes, but re-reading `CustomPrimitiveData.Data` -- via `lbdumpcpd`, an independent,
long-established diagnostic, not just the new Custom tab code -- shows it back to 0 entries within
as little as ~2 seconds. Reproduced repeatedly, confirmed independent of the SpawnMenu companion
window entirely: same result with the window fully closed, using only `lbtestcpdcolor`/`lbdumpcpd`
console commands, on a single stable native NPC in range (so no target-identity ambiguity either --
an earlier theory, ruled out once it was clear only one candidate NPC existed nearby).

**Leading theory, not yet confirmed**: a probe dump (`lbprobedump`) on the same NPC class showed
every `BuildedCompositeMeshes` entry has an ACTIVE per-piece tick (`bTickDisabled=false`) with a
MISMATCHED significance level (`Params.EnableTickSignificanceLevel=3` vs. the live
`EnableTickSignificanceLevel=4`), plus its own `ColorData.ColorIndexesMap` -- the same official,
archetype-driven color source the 2026-08-31 investigation already found and deliberately bypassed
in favor of the simpler raw-CPD write. A significance/LOD-driven refresh re-deriving each piece's
appearance from that official data would explain a revert this fast, since the raw CPD write never
updates it. This has likely been true since CPD recoloring was first built -- nothing before Read
Current had a reason to check.

**Agreed workaround (RedFalcon, 2026-09-08), NOT YET BUILT**: rather than chase the significance/
tick system further right now, add a SEPARATE persisted color-record file (not folded into
`persist.txt`, which only ever tracks the mod's own spawns and should stay simple for anyone who
never touches NPC colors) keyed by a NATIVE actor's own name -- unlike a mod-`SpawnActor`'d object
(no stable identity across a reload, which is exactly why `persist.txt` matches by class+position
instead), a hand-placed LEVEL actor's `GetFullName()`/instance suffix is very likely deterministic
across reloads, since it comes from the level's own serialized actor list rather than runtime
object numbering -- worth confirming empirically (restart once, check the suffix matches) before
committing to it as the key. Once built, `Spawner.TestReadCategoryColors`'s priority becomes: (1)
this file (authoritative, immune to the revert), (2) live CPD, (3) the existing
`SavedCustomizationData.SelectedColors` native fallback. Sidesteps needing to fix the underlying
revert at all for now, and incidentally builds most of the real "restore custom NPC colors across
a reload" feature in the process.

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

### 3s. Touching a genuinely new property/function shape can crash INSIDE UE4SS.dll itself, not the game -- and a from-scratch minidump parser can prove it without a debugger installed (2026-09-08)

Two new Lua commands built the same session -- one calling a real, existing `UCheatManager`
UFUNCTION directly (`EnableDebugCamera()`, confirmed via the SDK header dump, no-arg/void, about
as simple a call shape as this project ever sees), one writing two ordinary `ActorComponent`
properties (`R5N_DayCycleTimeComponent.WorldDayTime`/`DayCycleSpeedInv`, both plain
`float`+`BlueprintReadWrite`) -- both **crashed the game natively**, confirmed live. Neither class,
property, nor function name was stale or wrong (independently re-confirmed against the current
build's own SDK dump before assuming otherwise, per this file's own "don't guess" discipline).

**No debugger was installed on this machine** (`Windows Kits\10\Debuggers` only has the bare DLLs,
not `cdb.exe`/WinDbg itself) -- rather than treat the crash dumps as a dead end, wrote a ~80-line
Python parser directly against the documented Microsoft `MINIDUMP_HEADER`/`MINIDUMP_DIRECTORY`/
`MINIDUMP_EXCEPTION_STREAM`/`MINIDUMP_MODULE_LIST` binary structures: read the stream directory,
pull the exception code + faulting address from the Exception stream, then walk the Module List to
find which loaded module's base/size range contains that address. No symbols needed for this much
-- just "which module." Result, all 3 crash dumps (two from the property write, one from the
UFUNCTION call): `EXCEPTION_ACCESS_VIOLATION` (0xC0000005), landing inside **`UE4SS.dll` itself**
at nearly identical offsets (0x3a9114 for both write-crashes, 0x3a9139 for the call-crash -- 37
bytes apart, same code region) -- NOT inside `Windrose-Win64-Shipping.exe`.

**This one fact reframes the whole investigation.** A crash landing in the GAME's own exe usually
means a content/asset-specific problem (a genuinely bad reference, a class that doesn't handle
some state well). A crash landing in **UE4SS.dll itself** means UE4SS's own generic Lua<->native
reflection bridge is failing on this specific property/function SHAPE -- something about how it's
declared (an unusual type, an unusual access/exposure combination, or simply "never resolved by
this UE4SS build before") trips a bug in the generic marshaling code, independent of whether the
Lua logic calling it is correct. One real, not-yet-proven lead: the property write's target,
`CheatWeatherID` (a SEPARATE, untested component from the same session), is declared `int8` and
only `EditAnywhere` -- NOT `BlueprintReadWrite` -- a genuinely different shape from the
ordinary-float-BlueprintReadWrite properties this project writes constantly elsewhere without
incident; it doesn't obviously explain the UFUNCTION-call crash landing at a near-identical offset
too, so the true common root cause is still open.

**General lesson: when a crash's own dump can be read (even without a real debugger), always check
which MODULE the fault landed in before theorizing about the Lua-level cause.** A fault inside a
mod-loading/reflection layer (UE4SS.dll, or a compiled companion mod's own DLL) points at "this
specific reflection shape isn't safe to touch this way," not at whatever business logic the Lua
code was trying to express -- a very different, and much narrower, class of problem to isolate.
**Practical follow-up discipline once a combined command is confirmed to crash**: split it into
one console command per individual operation and log a "starting attempt" line immediately BEFORE
each risky call, not just after -- a native access violation leaves ZERO further log output
(confirmed 3 times this exact session), so the isolated commands' own pre-call log line is the only
way to know which specific operation was running at the moment of a subsequent crash, and testing
one operation at a time avoids re-triggering an already-confirmed combined crash while narrowing
down which piece is actually unsafe.

---

### 3t. A "starting step" breadcrumb printed through a project's own VERBOSE-gated `log()` wrapper is not actually unconditional -- verify the wrapper itself before trusting its silence as evidence (2026-09-16)

A whole diagnostic effort (per-step "starting step N/8" breadcrumbs added specifically to catch
which step a native crash died in -- see 3s above for why that matters) turned out to have been
printing NOTHING for its entire lifetime. The project's own `log(msg)` helper is defined as `if
Config.VERBOSE then print(...) end` -- and `Config.VERBOSE` was `false` in this deployment.
Multiple real crash investigations were carried out against a log tail that LOOKED like it stopped
mid-function (no "starting step" line for the step after the last visible output), when in fact
NONE of those lines had ever been capable of printing at all, VERBOSE-gated or not; the log simply
never contained them, on the success path or the crash path alike. This produced a plausible-looking
but wrong localization (steps 8a-8c) before the gate itself was found and every breadcrumb in the
affected function switched to a small unconditional `print()` wrapper scoped to just that function
(leaving the rest of the codebase's own `log()` calls on their existing VERBOSE-gated behavior).

**General lesson: before trusting a diagnostic breadcrumb's ABSENCE as evidence of where something
died, confirm the breadcrumb itself is capable of printing unconditionally.** A project-wide logging
helper gated behind a debug/verbosity flag is exactly the kind of thing that silently defeats
purpose-built crash-diagnostic instrumentation added later without anyone re-checking that
assumption -- the fix cost nothing (a local, ungated `print()` wrapper) once found, but the gate
being invisible in the log itself (a `false`-valued config flag, not a printed line saying "logging
disabled") meant it went unnoticed through at least two full crash-investigation cycles.

### 3u. Repeatedly re-walking the SAME `TArray`-wrapped Lua array in a tight loop can crash inside UE4SS.dll's own reflection bridge, at a DIFFERENT instruction each time -- not one fixed bad line (2026-09-16)

A belts/straps read function called a shared helper 4 times per read (once per Belt/Sling/Strap/
Frog piece type), each call independently re-walking the SAME `BuildedCompositeMeshes` `TArray`
from index 1 through n via bracket-indexing (`list[i]`). A live crash dump, cross-referenced
against per-index checkpoint breadcrumbs (see 3t above for why those needed fixing first), caught
array index 4 of an 11-entry array being read CLEANLY during the first walk (the Belt lookup), then
crashing on that EXACT SAME index microseconds later during the very next walk (the Sling lookup)
-- with nothing else in the program having changed in between. Follow-up crashes on the SAME
general "Read Current"-style function, after the redundant 4x re-walk was collapsed into a single
pass (build a `{bodyPart -> value}` map once, look up all 4 pieces from it), kept recurring anyway
-- eventually confirmed via several more minidumps to be landing at DIFFERENT offsets within the
SAME native module each time (a tight cluster near the original address, plus at least one more
meaningfully distant one), across genuinely unrelated call sites (a completely different read
function, and even pre-existing restore/post-process code that had never been touched). That
"crashes at different instructions within one module, not one fixed line" pattern is the classic
signature of heap/memory corruption (a use-after-free or similar) rather than one specific bad call
-- the actual defect happens at one point, but the crash surfaces later, wherever the already-
corrupted memory next gets touched, which can look like "different locations" even though there is
one root cause.

**What actually resolved it**: the project's own vendored UE4SS build (built from the `RE-UE4SS`
source tree, not a separately-installed community binary) turned out to be 107 commits behind
upstream. Scanning the commit range between the vendored version and upstream `main` turned up
several real Lua-bridge stack/memory-corruption fixes matching this exact symptom class (a stack-
corruption fix in a delayed-action timer, multiple "unprotected Lua manipulations" hardening
commits in hook registration/dispatch, null-pointer guards, and -- most tellingly -- another game's
own bug report for "intermittent crash," the same vague, unlocalizable symptom). Pulling the update,
resyncing the RE-UE4SS project's own git submodules (`git submodule update --init --recursive`,
needed separately after the parent pull since submodule pointers move too), and rebuilding
meaningfully reduced crash frequency in the same test session (several successful "Read Current"
cycles that previously failed within 1-2 attempts), though it did not eliminate every occurrence --
treat a vendored native dependency's own version staleness as a real, checkable crash hypothesis
before assuming a native-module crash must be something the Lua code is doing wrong.

**A second, independent bug rode along with these crashes and is worth separating out**: repeated
crashes mid-restore left some spawned actors' per-session "instance label" counters un-primed (a
counter that's supposed to be seeded from every persisted actor's own label during a full restore
pass -- an interrupted restore never reaches the remaining lines, so their labels never prime it).
A later, genuinely fresh spawn of the same recipe could then reissue a label ("`<Name> 1`") already
owned by an old, still-persisted-but-never-restored actor -- two real entities sharing one identity
string. Any system keying persistent per-actor state off that label (this project's own Custom-tab
"Save Customizations" feature, see 19ah below) would silently misattribute the old entity's saved
state onto the new one. Fixed by making the label generator cross-check the actual current save-file
content as ground truth on every call, instead of trusting the in-memory counter alone -- expensive
per call only in the sense of one extra small file read, cheap in absolute terms, and correct
regardless of how many past restores were interrupted partway through. **General lesson: a
counter that's supposed to be re-primed from persisted state is only as reliable as the LAST
successful full pass over that state** -- if anything (a crash, in this case) can interrupt that
pass, either make every read of the counter re-derive from the persisted ground truth, or make
the priming step itself resilient to a partial run.

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

**STALE, CORRECTED 2026-09-08 -- this line said "not yet started" for two sessions after it was
actually done.** The `BodyTypeParams` mesh-retarget templates for all 7 donor classes were built
the SAME DAY this roster was finalized (file timestamps confirm 2026-09-02), using the general
"keep the class's native tag, retarget just the BodyMesh" recipe from this section's own earlier
2026-09-01 addendum, scaled cheaply via batch duplication (~150 `DA_Custom_BodyType(List)_<Donor>
As<Ethnicity>` assets, one per donor per destination ethnicity) -- but this work was never
committed to git and never written up here, so it sat invisible until RedFalcon asked to pick
"generation of the different body types" back up on 2026-09-08. Verified live that day: Gatherer/
Herbalist/Farmer/Woodman were already confirmed 2026-09-01; Hunter, BlackAxel, MortarMan, and
JasperCrowe were freshly confirmed via `lbtestbodytypes` -- all 4 spawned as their own correct
class with the retargeted body, no failures. Now committed (`Living-Base-Extended-Windrose`
`eeb4fe3`). **General lesson: a "not yet started" note is a claim about a point in time, not a
durable fact -- if work happens after the note is written and nobody circles back to correct it,
the note actively misleads every future session that trusts it at face value.** All 7 donors are
now confirmed working; picking the final ethnicity target per donor for the actual 14-variant
roster is the real remaining step, not asset construction.

**UPDATE 2026-09-08 -- the plan for "picking the final ethnicity" changed: it's now a live,
independently-selectable "Origin" axis (a separate picker grid), not a fixed choice baked per
donor.** RedFalcon: "pick an ethnicity... from one list using thumbnails and no hover text... and
another selection matrix of the male and female body types... when both are selected, we can
spawn." Full design in `project_livingbase_spawn_menu` memory. Running a full tag+sex existence
validation across the matrix (UAssetAPI, not guessing from filenames) before handing out capture
commands found one real, closeable gap: Hunter's own named origin templates
(`HunterAsAdventurer/Albion/Fable/Native/Orient/Scum`) had sat Editor-constructed but never
cooked+retargeted+packaged since 2026-09-02, and `HunterAsSenkamati` didn't exist at all. Closed
same session -- built the missing Senkamati entry, cooked all 6 in one pass, retargeted
BodyMesh+SkinMaterials on the cooked output, packaged as `HunterOriginBatch-Windows`, installed
live (needs a restart to confirm). With this, both the Body Type grid (14, all origins already
covered at the shared African test-origin) and the Origin grid's own Male AND Female columns
(Gatherer/Hunter, 8 origins each) have a real working asset for every cell -- the matrix is
complete; only capturing the 30 thumbnails and building the actual GUI grids remain.

See 19n for the separate "every clothing/item slot available" work, which turned out to be its own real
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

**RE-INVESTIGATED, 2026-09-11 -- mechanism identified (per-piece `SlotsToSuspend`, not a hardcoded
MeshBodyPart rule), but the ORIGINAL 2026-09-03 conclusion turns out to be correct in practice
anyway.** RedFalcon found a live counter-example while testing the rebuilt Barbie outfit: the
native Female Herbalist wears a real Torso piece AND a real Waist piece simultaneously. First
assumed this meant *some* Torso pieces suspend Waist and others don't (matching the Headgear-vs-
Hairs mechanism) -- `lbdumptorsosuspend` (2026-09-11) checked all 24 human-appropriate, dual-sex-
confirmed Torso pieces in the game and found **every single one declares `Waist=Full`, 24/24, with
zero exceptions.** The Herbalist's Torso specifically is the ONE genuinely non-suspending piece in
the whole catalog -- `DA_Armor_Regular_Character_Underwear_Torso_Female_CompositeMeshData` -- and
it's Female-ONLY (no Male equivalent exists at all). **Practical conclusion, now fully data-backed
rather than a single anecdotal test: Torso and Waist cannot coexist with any real clothing outfit,
on either sex** -- the only way to get both is the Female-only Underwear Torso, which isn't a real
"wearing clothes" look. The mechanism (`SlotsToSuspend`, not a hardcoded engine rule) is still worth
knowing -- it explains WHY, and `lbdumpsuspend <path>` / `lbdumptorsosuspend` remain useful for
checking any OTHER slot pairing that looks suspicious -- but for Torso/Waist specifically, treat it
as a universal design choice across all real garments, same practical guidance as the original 19n
call: pick Torso as the default, Waist stays real, working, swap-in-only content.

**SUPERSEDED, 2026-09-11 (same "verify what was actually tested" lesson as above) -- this specific
test's premise was itself the same Herbalist/Barbie mix-up, so its conclusion is UNCONFIRMED, not
established fact.** Original claim: "`SlotsToSuspend` only ever fires at initial composite
CONSTRUCTION, never on a later runtime swap" -- tested by spawning fresh (believed Vanilla Torso +
real Waist both built) then swapping Torso to Brigant via `lbtestclothes`, observing Waist stay
visible. Since Waist never actually built with the Vanilla Torso in the first place (24/24 real
Torsos suspend it, confirmed above), there was nothing genuine to observe surviving that swap --
this test's own premise was invalid, whatever was actually seen wasn't measuring what it claimed
to. The underlying mechanical claim (`SetSkeletalMeshAsset`-based swaps don't trigger a fresh
composite build, so already-built slots aren't re-evaluated against `SlotsToSuspend`) is still
plausible from how the code works, but is NOT independently confirmed by this test and shouldn't be
cited as settled -- re-verify properly (a slot that's genuinely built via a non-suspending source,
swapped to a piece that WOULD have suspended it if present at construction) before relying on it.

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

### 19v. The Barbie gender-swap saga -- six real bugs stacked on top of each other, the actual reassertion wall finally isolated (2026-09-08)

RedFalcon's requirement, stated plainly and non-negotiably from the start: `lbtestbodyswap` must
summon a donor NPC (to preserve their unique `BodyMorph` shape) AND swap their sex, in ONE combined
command -- not two separate manual console calls. "we will be needing to summon and swap at the
sane time and we DID have it working" -- disputing an earlier characterization that the previously-
confirmed `SwapBodySex` technique was inherently a two-step, target-an-already-spawned-actor
process. Getting this fully working took the rest of the day and surfaced six genuinely separate
bugs, several of them completely unrelated to each other -- worth reading in order, since each one
looked at first like it explained everything, until the next test proved it didn't.

**Bug 1 -- `resolveViaAssetRegistry` permanently caches a FAILED lookup.** `_assetRegistryHelpers`
was cached module-scope via `_assetRegistryHelpers = StaticFindObject(...) or false` -- if the very
first call happens before the AssetRegistry subsystem is ready (exactly what running
`lbtestbodyswap` right after a fresh restart does), it locks in as `false` for the rest of the
session and every subsequent `bodyTypesPath`/`morphParams` resolution silently MISSes forever,
including previously-confirmed-working packages untouched that session. Real bug, genuinely fixed
(only cache success now), but turned out NOT to be the cause of the symptom being chased at the
time -- a real lesson in not declaring victory on the first plausible-looking fix.

**Bug 2 -- `ensureFullPath` never prepended the required `/Game/Mods/LivingBaseExtended/` folder.**
The actual, much simpler cause of the `bodies=MISS` symptom above: typing a bare filename (e.g.
`DA_Custom_BodyTypeList_JasperAsAfrican`, no leading `/Game/...`) only got the `.AssetName` suffix
appended, never the folder -- `resolveAsset` was asked to resolve a nonsense relative package name
that could never succeed via any mechanism, regardless of pak content, mount order, or caching (both
investigated and ruled out first via `lbtestassetreg`, `retoc list --all --path` against every
installed container, and the game's own `Saved/Logs/R5.log` pak-mount sequence). Confirmed via
`lbtestassetreg` resolving the exact same asset fine when given its real, full path. **General
lesson: when a resolution call mysteriously MISSes for content independently verified byte-correct,
check the actual STRING being resolved before chasing pak/cache/mount-order theories** -- the
malformed path was sitting in plain sight in every failing log line the whole time.

**Bug 3 -- the `BodyTypeParams` hijack technique (19m) never actually generalizes to an
individually-named donor's OWN class.** Every genuinely-confirmed success for this technique in
this project's history spawned **Gatherer** (or another Handyman-family class whose own native tag
matches the override) -- re-confirmed live this same day (`AdventurerAsAfrican` on Gatherer still
works perfectly). But the Barbie roster's real requirement is spawning the DONOR's own class
(BlackAxel, MortarMan, etc.) to preserve their shape. A live probedump on Axel proved the write is
REJECTED INSTANTLY, not reasserted later (`comp.BodyTypeParams` read back the native
`DA_NPC_BodyTypesParams_Common` immediately after the write, same call, same synchronous block --
not a later BeginPlay reassertion, a genuinely different failure mode from the well-known
`ArchetypePreset` wall). Earlier "confirmed working" claims for Axel/Jasper/Mortar/Hunter's own
classes (2026-09-08 morning, same day) were almost certainly Bug 2 in disguise -- a silent MISS
that visually looked like "spawned fine, no failure" without anyone checking the skin tone
specifically.

**Bug 4 -- the "combined Male+Female" `BodyTypeList` doesn't sex-discriminate at all.** Built to
work around Bug 3 by wrapping BOTH single-sex hijack entries in one list
(`DA_Custom_BodyTypeList_AxelAsAdventurerBoth` etc., `BodyTypeData = [MaleEntry, FemaleEntry]`) --
confirmed live it always resolves to the FIRST (Male) entry regardless of the actor's actual sex:
Gatherer (native Female) got a MALE Adventurer mesh when given this list. The native
`BodyTypeParams` pool lookup, when handed a multi-entry override list, does not filter by sex the
way the single-entry hijack's own tag-matching implied it might -- an untested assumption from the
start, now disproven. Real fix: resolve the FINAL target sex in Lua and point `bodyTypesPath` at
the correct SINGLE-sex sibling list instead of the combined one -- the "Both" lists stay committed
on disk as historical record but are dead weight, unused by `SwapBodyType` from here on.

**Bug 5 -- `EmptyOverrideMaterials()` does not clear a pre-existing per-instance skin material
override.** Once the `BodyTypeParams` wall (Bug 3) made it clear the hijack technique can't be used
for a donor's own class at all, the whole approach pivoted to the ALREADY-proven-working (2026-08-
31) post-build direct swap: hide the leader mesh, `SetSkeletalMeshAsset` to the target family's real
mesh, show again. This correctly changes the SHAPE, but a probedump showed the material list still
carrying the DONOR's own native skin material at a FIXED slot index (`[MI_Eye, MI_Pirate_Mouth,
<skin>, MI_Hair]`, skin always at index 2, confirmed across every donor checked) -- calling
`EmptyOverrideMaterials()` right after the mesh swap (a reasonable-sounding fix) does NOT actually
clear that override, contrary to what the function name implies. Real fix: explicitly
`SetMaterial(2, <target family's own MI_<Family>_<Sex>_Medium>)`. This also surfaced a genuinely
new, previously-unknown gap: the whole female-origin column of the Origin-grid matrix
(`AdventurerAsAfrican`/`Albion`/`Fable`/`Native`/`Orient`/`Scum`/`Senkamati`) had SkinMaterials
correctly SHAPED (3 keys, inherited for free via `duplicate_asset()`) but never actually
RETARGETED past placeholders -- no female-source equivalent of
`rollout_skinmaterials_male_batch.py` was ever written. Fixed in one pass alongside re-fixing 3
male-source entries a same-day re-cook had regressed (cooking a package that depends on an
already-retargeted package re-cooks the dependency FRESH FROM SOURCE -- a known gotcha, hit again).
Real per-family gotcha confirmed via a fresh `pakcontents.xlsx` listing rather than assumed: the
Adventurer family's own skeletal MESH is misspelled `SK_Adventure_Female_01` (no "r"), but its
MATERIALS are spelled correctly (`MI_Adventurer_Female_*`) -- two different conventions inside the
same family. Senkamati's Female side has exactly ONE skin material at all
(`MI_Senkamati_Female_Medium`, no Small/Large) -- mirrors the already-known Male-side sparseness.

**Bug 6 (the real headline finding) -- `ArchetypePreset`, not anything else, is what actually
decides which sex+family a build resolves against, and nothing post-build can change it.** After
Bugs 1-5 were all fixed, sex-swapping a donor still produced a FULLY NUDE actor --
`BuildedCompositeMeshes` stuck at 0 forever, even though `comp.DefaultParams` was confirmed (via
probedump) to have correctly swapped to a genuinely dual-sex-safe outfit
(`DA_Custom_BarbieDefaultParams_Regular_Female`/`_Regular_Male`, the actual outfit this whole Barbie
sub-project built for exactly this purpose -- RedFalcon's own insight: "does this mix and match
with the barbie tool we made"), and `comp:GetBodySex()` correctly read the new value. Three
different native rebuild triggers were tried and ruled out, each via `lbinspectfn` (pure-read
parameter inspection, zero crash risk) before ever risking a live call:
- `ConstructVisualFromParams()` -- crashed calling it bare ("expected 1 parameters, received 0");
  `lbinspectfn` revealed its one parameter is `PredefinedArchetypeIndex`, an int into an unrelated
  predefined-archetype list, not a general "rebuild from current state" trigger. Semantics unknown,
  too risky to guess a value for.
- `SetBody(InBodyType, InBodySex, bForceLoad)` -- `lbinspectfn` found a much more promising 3-param
  signature. **This function is separately documented (item 64/CLAUDE.md, 2026-08-15) as having
  CRASHED THE GAME TWICE IN A ROW** when given a freshly-constructed `{ TagName = tagName }` Lua
  table as the body-type argument (zero Lua output either time -- execution never returned at all).
  Reusing the actor's OWN already-valid tag object from `comp:GetBodyType()` (instead of
  constructing a new one) avoided the crash this time -- call returned `OK` -- but still left
  `BuildedCompositeMeshes` at 0. So the crash risk is specifically about constructing a fresh
  GameplayTag struct via Lua, not the function itself; and even a clean, non-crashing call doesn't
  force a rebuild.
- Neither call raised `BuildedCompositeMeshes` off 0. **Conclusion: the ONE real composite build
  already happens exactly once, at spawn/construction time, resolved entirely from
  `ArchetypePreset` (which is fixed per-class and reasserted at construction, the same wall already
  known from 19c/§2's own archetype-reassertion findings) -- nothing discovered so far, including
  every function `R5CompositeMeshComponent` exposes for body/sex, can force a second one after the
  fact.** `SwapBodySex`/`SetBody`/`ConstructVisualFromParams` can all report success or even
  genuinely change their own backing property (confirmed for `DefaultParams` and `GetBodySex`) while
  the actual composite population stays permanently governed by whatever `ArchetypePreset` requested
  at the one real build.

**The actual, working fix**: build the FULL `compositeLook` (archetype + Barbie outfit + sex)
BEFORE spawning, whenever a sex swap is being requested -- never try to force a second build
afterward at all. Uses a genuinely NATIVE, already-Adventurer-tagged archetype for the target sex,
reusing the exact same "keep an archetype real, just point it at a different resolved family"
philosophy 19c/19m's own hijack technique was built on, just one level up (swapping the WHOLE
archetype reference, not hijacking one entry inside the pool it reads from): Gatherer's own
(`/R5BusinessRules/Character/Customization/NPC/Handyman/Gatherer/
DA_Customization_Handyman_Gatherer_PresetArchetype1`) for Female, JasperCrowe's own
(`/R5BusinessRules/Character/Customization/NPC/Employee/JasperCrowe/Preset/
DA_Customization_JasperCrowe_PresetArchetype`) for Male -- both found via live probedump, not
guessed. Still spawns the DONOR's own class throughout, so `BodyMorph`/shape stays theirs -- shape
is baked per-Blueprint at COMPILE time, never archetype-driven (already independently confirmed:
two classes referencing the IDENTICAL `MorphParams` asset produced different `BodyMorph` results),
so swapping which archetype OBJECT is referenced can't touch it. **CONFIRMED WORKING LIVE**
end-to-end: donor's own shape, correct sex, Adventurer skin/mesh (via the still-needed Bug-5 direct
mesh+material post-build swap, since the archetype only fixes sex+outfit population, not which
specific ethnicity mesh gets used), and real populated Barbie clothing, all from one command.
Scoped to Adventurer only (the one target family this roster needs) -- a different target family
would need its own equivalent native archetype pair, found the identical way.

**Two smaller, unrelated fixes bundled into the same command along the way:**
- `Spawner.DespawnActor` instead of a raw `K2_DestroyActor()` when replacing the previous swap
  actor -- the raw destroy call only removes the LIVE actor, leaving the `persist.txt` line
  `Spawner.Spawn` unconditionally writes for every spawn orphaned, so every subsequent world load
  re-restored every prior test's leftover NPC ("it explodes with a ton of people"). `DespawnActor`
  also calls `PersistRemoveMatching`, the same pattern `Spawner.CancelPlacement`'s own NEW-mode
  cancel already used.
- An optional underwear toggle (`Spawner.RemoveClothingOnActor`, the same call the existing
  underwear-on-spawn feature already uses) -- initially passed `"all"`, which also strips Hair (a
  separate, deliberate feature added earlier the same day for the general Remove UI) -- fixed by
  looping every removable slot except Hair individually instead.

**General lesson for this whole project, worth remembering before the next composite-mesh
investigation**: when a property write reports success (or even reads back correctly) but nothing
visibly changes, check whether `ArchetypePreset` is the actual gate BEFORE trying more post-build
setter/rebuild functions. Every other lever this session (`BodyTypeParams`, `DefaultParams`,
`SwapBodySex`, `SetBody`, `ConstructVisualFromParams`) could report success, or even correctly
change its own backing property, while the real composite population stayed governed by archetype
alone -- a `BuildedCompositeMeshes` count of 0 after any post-build attempt is now this project's
own standing signal to stop chasing rebuild triggers and go straight to "does the archetype itself
need to change," not a reason to try yet another setter function.

### 19w. A second crash saga, then a real pivot: authoring a genuinely new native NPC class from scratch, CONFIRMED WORKING LIVE (2026-09-08/09)

§19v's "CONFIRMED WORKING LIVE" turned out not to be the end of the crash chasing -- the very same
night, `lbtestbodyswap` started crashing the game again, repeatedly, in several genuinely different
ways. Three timing-based fixes were tried in sequence and each one was disproven by the NEXT crash
landing at a suspiciously exact offset FROM the delay just added (750ms, then 20s, then a 1.5s
settle delay) -- the tell that a "fix" is only relocating a deterministic bug, not preventing it.
The REAL fix turned out to be structural, not timing: `pollForBuildThenApplyBodySwap`'s phase 2 was
calling `Spawner.TestSetBaseBodyMesh` (a raw `SetSkeletalMeshAsset`) UNCONDITIONALLY for every family,
including Adventurer -- but for Adventurer specifically, the archetype+`SwapBodySex()` path (§19v's
own fix) ALREADY correctly rebuilds the mesh/sex, making that raw call a genuinely redundant second
skeleton swap on an actor whose followers had just been rebuilt moments earlier. Skipping it
specifically when `compositeLook.archetype` was set (a new `familyHandledByArchetype` flag) resolved
it. Along the way, Woodman was wrongly suspected as donor-specific (he crashed 2/2 on a female swap)
until BlackAxel -- rock-solid all night -- crashed identically, proving the instability was in the
mechanism, not any one donor's own gear.

**RedFalcon's own reaction to the whole chase, verbatim: "maybe we are approaching this from the
wrong direction... would it be feasible to make a new NPC with specific morphs etc without having to
use the preexisting."** Correct call -- every crash chased that night shared one root cause: fighting
`BeginPlay`'s own composite-mesh construction after the fact via runtime property pokes on a donor's
own hijacked Blueprint. This section is the record of pursuing that alternative to an actual, live,
confirmed conclusion, not just a plan.

**First attempt, a real and permanent dead end -- do not retry**: duplicate a donor's own Blueprint in
the SDK-stub project and override its `CompositeMeshComponent` defaults (Sex/`ArchetypePreset`/
`DefaultParams`) at author time, leaving `BodyMorph` inherited. Failed immediately: this SDK-stub
project has NEVER had the base game's own Blueprint content mounted as loadable source -- only C++
header STUBS exist for reflection, never the real `.uasset` files (`/Game/Gameplay` has zero entries
in this project's own `EditorAssetLibrary.list_assets`). `duplicate_asset` on any donor's Blueprint
fails outright; there is nothing to duplicate FROM.

**RedFalcon's own follow-up cracked the SECOND, deeper wall for good**: "are we not able to export
the data from the unencrypted paks and recreate it?" -- exactly this project's own established,
proven pattern (every successful DataAsset here was built by reading an existing asset's structure via
`retoc` extraction and RECREATING an equivalent fresh in the Editor, never by copying the raw file).
Applying that same instinct here meant reading the REAL `R5CompositeMeshComponent.h`/`R5AICharacter.h`
directly from this project's own existing 2026-08-29 `UHTHeaderDump` (35,204 files, sitting on disk
the whole time, never previously copied into the project's own `Source/R5/`), which settled something
this whole project has wondered about since its earliest sessions:

- **`UR5CompositeMeshComponent::ArchetypePreset` is declared `Transient`.** This is the actual,
  source-level reason for the archetype-reassertion wall documented all the way back in §2/§19c --
  not `BeginPlay` "fighting" a cleaner override, but a `Transient` property being structurally
  incapable of surviving a cook AT ALL, by any authoring route, Blueprint or otherwise. Confirms the
  runtime pre-`BeginPlay` write (`Spawner.SetCompositeParams`'s own `effPreFinish` hook) is the ONLY
  mechanism this specific property can ever be set through -- necessary, not a hack. `DefaultParams`
  (the outfit), `MorphParams`, `ColorParams`, `BodyDecorParams`, `BodyTypeParams` are NOT transient --
  those genuinely could be baked as real class defaults if the rest of the pipeline existed for them.
- **`AR5AICharacter` is `UCLASS(Blueprintable, NoExport)` implementing 26 interfaces.** Confirms the
  earlier "~26-interface compile requirement" note was accurate in scope, not overstated in the way
  the actual WORK turned out to be (see below) -- deriving a genuinely new, concrete C++ class from
  this base in a fresh module requires satisfying all 26.

**Pursued anyway, given how close this now looked, and it worked.** Read all 26 real interface
headers directly from the same `UHTHeaderDump` before writing a line of code: 25 of them
(`IR5DeathComponentInterface`, `IR5FactionComponentInterface`, etc.) are COMPLETELY EMPTY --
15-line files, zero declared methods, native-only marker interfaces whose real methods (if any) never
reached UHT's reflection dump at all. The 26th, `IAbilitySystemInterface`, is a standard, well-known
engine interface needing exactly one trivial accessor (`GetAbilitySystemComponent()`). The
"26-interface" fear from three weeks earlier was real in scope but wildly overstated in DIFFICULTY --
it's boilerplate, not game-logic reverse-engineering.

Built `ABarbieNPCBase` deriving from a from-scratch `AR5AICharacter` reimplementation (own module,
`NoExport` removed, a deliberately minimal constructor -- none of the ~25 real component subobjects
created, all left null, which compiles fine since nothing requires them non-null just to exist).
Three real build/link/load issues found and fixed by iterating actual build attempts, not by
guessing further:
1. **UHT requires a real, resolvable `UCLASS()` for every UPROPERTY pointer's pointee, even ones
   never read or written.** A bare C++ forward declaration is NOT enough -- confirmed empirically:
   ~38 types in `AR5AICharacter`'s own member list needed this. Fixed with a
   `R5AICharacterPlaceholderTypes.h` file: minimal empty stub `UCLASS()`es for all 38, each deriving
   from the most plausible real base (`UActorComponent`/`UAttributeSet`/`UAbilitySystemComponent`/
   `UDataAsset`/`AActor`) -- correctness of the exact base doesn't matter for this purpose, since
   nothing here is ever instantiated or has its members touched.
2. Three of the copied interface headers (`R5FactionComponentInterface`, `R5OwnershipComponentInterface`,
   `R5MercunaNavigationInterface`) still carried their ORIGINAL module's API export macro
   (`R5RELATIONSHIP_API`/`R5MERCUNA_API`) after being consolidated into this project's own `R5`
   module, which only defines `R5_API` -- real compile errors, cascading into confusing "PCH heap
   limit reached" errors on unrelated translation units until fixed.
3. `GameplayAbilities` (for the real `IAbilitySystemInterface`) and its own `GameplayTasks`
   dependency needed BOTH a `PublicDependencyModuleNames` entry in `R5.Build.cs` AND enabling as an
   actual PLUGIN in `LivingBaseExtended.uproject` -- linking succeeded with just the Build.cs change,
   but the Editor still failed to LOAD the compiled DLL at runtime (`GetLastError=126`, the classic
   "a dependent DLL couldn't be found" signature) until the plugin itself was enabled.

**Pushed the full pipeline through, live, and it FAILED on the first real attempt -- correctly
diagnosed as a parent-class mistake, not a dead end.** Created `BP_BarbieR5Char_Test`... actually, the
FIRST attempt (`BP_BarbieNPCBase_Test`) was parented to `/Script/LivingBaseExtended.BarbieNPCBase` --
our OWN module's class. Spawning it live gave `SPAWN FAILED (class unresolved)`. RedFalcon's own
diagnostic instinct found the bug in one step: "in the 'other' folder are several mods with pak
files. do any of those have blueprints in them?" -- yes. Pirate Signals ships
`/Game/Mods/WindroseChatTransport/ModActor`, a genuine Blueprint (string-dumped: `BPTYPE_Normal`,
`SimpleConstructionScript`, `ModActor_C`, `Default__ModActor_C`, real UberGraph internals) that
resolves fine live -- proving shipping a new Blueprint class in a pak works for this game in general.
Diffing its imports against ours found the actual mistake: Pirate Signals imports `/Script/Engine`
(its parent, `AActor`, EXISTS in the shipped game); ours imported `/Script/LivingBaseExtended.*` -- a
class that exists ONLY in this SDK-stub project's own compiled DLL. **A pak ships CONTENT, never
compiled code** -- the shipped game has no `LivingBaseExtended` module and never will, so it can never
resolve that parent, and the whole Blueprint silently fails to load. Fix, and the entire point of the
SDK-stub approach: reparent to `/Script/R5.R5AICharacter` -- our stub compiles under module name `R5`
with class `AR5AICharacter`, so its script path is IDENTICAL to the real game's own class. The
Blueprint stores only that path string; at runtime the REAL, fully-implemented game class answers to
it. **Rule going forward: any Blueprint intended for the live game must parent to a `/Script/R5.*`
class (or another class the shipped game actually has), never a `/Script/LivingBaseExtended.*` one.**

**Reparented, retested, and it STILL failed identically -- which turned out to rule out the parent
class entirely, not confirm it as the culprit.** `BP_BarbieR5Char_Test` (parented to the real
`/Script/R5.R5AICharacter` path) gave the exact same "SPAWN FAILED (class unresolved)". Built a
plain-`/Script/Engine.Actor` control Blueprint (`BP_PlainActor_Control`) -- deliberately matching
Pirate Signals' known-working shape exactly -- to isolate the one remaining variable. It ALSO failed
identically. Two Blueprints, two completely different parents, the exact same failure: the parent
class was never the problem. Directly comparing containers against Pirate Signals' own working pak
(`retoc info`) ruled out packaging too -- `container_header_version`
(`SoftPackageReferencesOffset`) and TOC version (`ReplaceIoChunkHashWithIoHash`) matched
byte-for-byte; only compression and mount point differed, neither of which affects package
resolution. A real gap was found in the one supporting data point for "this should already work,"
though: the project's own earlier note that Pirate Signals' ModActor "resolved cleanly via the same
API" had only ever been checked via `resolveAsset` on the NO-`_C` path -- confirming the BLUEPRINT
ASSET resolves, never its GENERATED CLASS, a different object reached by a different load path
entirely.

**Built a new pure-read diagnostic, `lbdiagresolve <path>`, that tries every resolution strategy
independently instead of stopping at the first success** (`StaticFindObject` on the `_C`/asset/
package forms, `LoadAsset` followed by each, `resolveViaAssetRegistry` on both forms, plus which
loader globals this UE4SS build even exposes). Ran it side by side on the failing Blueprint class path
and a KNOWN-WORKING DataAsset path, and found the actual bug in one direct comparison:
```
BP_PlainActor_Control.BP_PlainActor_Control_C:
  resolveViaAssetRegistry(path WITH "_C")        -> OK, valid BlueprintGeneratedClass
  resolveViaAssetRegistry(path with "_C" stripped) -> nil
DA_Custom_BarbieDefaultParams_Regular_Female (a plain DataAsset, no "_C" to strip):
  both forms -> OK, identical result (nothing was actually being stripped in this case)
```
**The AssetRegistry DOES index a Blueprint's generated class -- but only under its own
`_C`-suffixed name, not the bare Blueprint asset name.** `resolveClass`'s own AssetRegistry fallback
(added earlier the same night, to let `Spawner.Spawn` find a genuinely new class path the same way
`resolveAsset` already found new DataAssets) always STRIPPED "_C" before calling
`resolveViaAssetRegistry` -- backwards, and it had been silently correct-by-accident for every single
prior test because those were all DataAsset paths with no "_C" to strip in the first place. This is
exactly why it took an actual Blueprint CLASS path to ever surface. **Fixed**: pass the original path
straight through to `resolveViaAssetRegistry` first; only fall back to the stripped/asset-name form
if that misses.

**CONFIRMED LIVE**: both Blueprints spawn successfully via `lbspawn` after the fix. Better than a
clean spawn, `BP_BarbieR5Char_Test`'s own spawn log showed something decisive: it found and destroyed
a real `R5ScenarioComponent_ForIslandActor` component -- a component our own minimal stub constructor
NEVER creates (left null on purpose, to keep the experiment lean). That component can only exist if
the REAL game's own `AR5AICharacter` implementation constructed it at runtime. Direct, unambiguous
proof the whole mechanism works exactly as designed: a Blueprint authored against a local stub
(existing purely so the Editor has something to compile against) correctly resolves to and runs the
REAL, fully-featured game class once loaded live -- not the stub's own empty logic.

**Status, plainly**: every risk flagged about this approach since it was first scoped weeks earlier is
now empirically resolved, not theorized. The 26-interface cost was real but trivial in practice. A
Blueprint on a class with zero real compiled behavior behind it DOES survive cook, package, and live
load -- confirmed, not assumed. The actual blocker the whole way through was never the C++ scope; it
was two one-line bugs (a wrong parent-class path, then a wrong string transform before an AssetRegistry
call) that only a REAL live class-path test -- not another DataAsset test -- could ever have surfaced.
**What this unlocks, concretely**: a genuinely new, donor-independent native NPC class is now a real,
proven, repeatable capability. Author a minimal Blueprint parented to `/Script/R5.<RealClassName>`;
apply everything else (`AIPawnParams`, `AIControllerClass`, `CompositeMeshComponent`'s Sex/
`ArchetypePreset`/`DefaultParams`/`MorphParams`) at spawn time via the exact same proven pre-`BeginPlay`
mechanism `Spawner.SetCompositeParams` already uses today for donor-Blueprint hijacking (`ArchetypePreset`
still can't be baked -- it's `Transient`, see above -- so this stays a runtime-applied field regardless
of authoring route). The real payoff isn't eliminating the runtime mechanism; it's spawning a class
that's genuinely OURS, carrying no donor-specific native gear or hidden quirks along for the ride --
the exact class of problem behind this whole section's own opening crash chase.

### 19x. Turning the from-scratch class into an actual usable NPC: invisible mesh, a cold-load race, and the still-open sex/animation gap (2026-09-09)

§19w proved the mechanism; this section is the record of actually running `BP_BarbieR5Char_Test`
through the real `lbtestbodyswap` workflow (the actual Barbie-roster use case, not just a bare
`lbspawn`) and fixing what broke. Each failure here traces back to the SAME root cause: a real donor's
own class provides a pile of "free" native setup (base mesh, body-type pool, animation, movement
tuning) as class defaults; a from-scratch class provides none of it, so anything that isn't
EXPLICITLY set at runtime is simply absent, not defaulted.

**Failure 1 -- invisible NPC (empty base mesh).** First live `lbtestbodyswap` test against the new
class: no crash, but nothing visibly appeared. `lbwhereami` (new pure-read console command, prints the
player pawn's own location/yaw) confirmed the actor spawned right next to the player, ruling out
position -- a live `lbprobedump` confirmed the real problem: `CharacterMesh0`/`actor.Mesh` had no
skeletal mesh assigned at all. Root cause: `pollForBuildThenApplyBodySwap`'s `familyHandledByArchetype`
skip (the §19w-era fix that avoided a redundant, crash-prone mesh re-swap) assumed "archetype handled
it" always implies "the base mesh is already set" -- true for every real donor (which bakes a base mesh
into its own class defaults) but false here, since nothing ever sets `Mesh`'s skeletal mesh on a blank
class. **Fixed**: added a `hasBaseMesh` check (reads `actor.Mesh:GetSkeletalMeshAsset()`/`.SkeletalMesh`)
before deciding to skip -- if the archetype path claims to have handled it but the mesh is still empty,
apply the direct mesh override anyway.

**Failure 2 -- "mesh unresolved" on retry, a genuinely different bug.** After the fix above, a retest
hit a NEW error: `SK_Adventure_Female_01` failed to resolve. A BlackAxel (real donor) control test in
between confirmed this wasn't session-wide breakage. The actual cause, confirmed via a direct A/B
test (the user ran the identical failing command twice back to back): it failed on the FIRST call and
succeeded instantly on an IMMEDIATE second call. This class never touches any family-specific content
as a side effect of spawning (no "Asset loaded" log line, `R5CommonInteractionTargetComponent` always
finds 0 matches, unlike a real donor which finds 1) -- so a mesh/skin-material reference that has never
been touched anywhere else this session can miss `resolveAsset`'s single `LoadAsset`-then-retry window,
purely a cold-cache timing race, not a real resolution failure. **Fixed**: wrapped the mesh+skin-material
application in `tryApplyMeshAndMaterial(attemptsLeft)`, an internal retry loop (4 attempts, 800ms apart
via `ExecuteWithDelay`) inside `pollForBuildThenApplyBodySwap`'s `applyPhase2`. Confirmed working
cleanly on a single command afterward -- both mesh and skin material resolved OK on the first try, no
retry needed that time (the race doesn't reproduce every time, which is exactly what a cold-cache
timing issue looks like).

**Visibility is now solid.** With both of the above fixed, the class spawns visibly, wearing the
requested body mesh and skin material, with no crash -- confirmed across repeated tests.

**Still open at this point -- two more real gaps, same root cause, both being worked now:**

1. **Sex resolution never lands.** `GetBodySex` reads `before=1 after=1` (stuck Male) on this class
   even when a Female swap is explicitly requested, vs. `before=1 after=2` (correct) for every real
   donor. Working theory: `CompositeMeshComponent.BodyTypeParams` -- the pool a sex/family request
   resolves body meshes against -- is genuinely empty/invalid on a blank class, since nothing ever sets
   it (a real donor gets it from its own class defaults). Confirmed the theory's missing piece live via
   `lbtestlistclass /Script/R5 R5CompositeMeshBodyTypeListParams Common` (the exact same AssetRegistry
   enumeration technique `lbdiagresolve`/§19w used, applied to a new class type): the real, native pool
   asset is `/Game/Gameplay/Character/AI/NPC/Base/Params/Customization/DA_NPC_BodyTypesParams_Common`
   -- never previously recorded anywhere in this project as a literal path string, only ever seen by
   name via live probedumps. **Fix applied (not yet retested)**: `Spawner.SwapBodyType`'s
   `compositeLook` now explicitly sets `bodyTypes` to this path whenever a sex is requested, threading
   through the existing (already-wired, never previously populated for this call site)
   `compositeLook.bodyTypes` -> `Spawner.SetCompositeParams`'s `bodyTypesPath` parameter -> resolved
   and written to `comp.BodyTypeParams` pre-`BeginPlay`, the same mechanism already used for
   `DefaultParams`/`ArchetypePreset`/etc. This is a no-op for real donors (it's the exact same asset
   their own class defaults already point at) and should be the actual fix for the blank class.
2. **Visible but floating, T-posing with no animation.** Once the mesh/material race above was fixed,
   the actor appeared for the first time -- but floating (not settled to the ground) and holding a raw
   T-pose (no animation playing at all). Same root-cause family as failure 1: nothing ever assigns
   `Mesh.AnimClass` (the AnimBlueprint that drives the skeleton) on a blank class, so there is no
   AnimInstance running -- a real donor's own class defaults already point `Mesh.AnimClass` at one.
   `Spawner.SetAnimClass(actor, animClassPath)` (built back in the pose-porting investigation, §19w-era
   predecessor work from 2026-08-14) is the existing, already-proven mechanism for this
   (`mesh:SetAnimInstanceClass(cls)`, falling back to a plain `mesh.AnimClass = cls` write) -- it was
   built and tested against a STATUE (a non-AI decorative actor), where it correctly ported
   `ABP_StandingNPC_Regular_AI_C`'s pose onto a mismatched skeleton and T-posed for THAT unrelated
   reason (see the pose-porting closure write-up, 2026-08-14/15) -- irrelevant here, since our class
   uses a real, matching humanoid skeleton (`SK_Adventure_Female_01`), the same skeleton family
   `ABP_StandingNPC_Regular_AI_C` already natively drives for real living AI pawns (confirmed via the
   same 2026-08-14 probe: a real crew NPC runs the same BlueprintMode/AnimClass pattern). The exact
   package path was never recorded as a literal string (only the class name and a partial folder hint,
   `.../Human/Regular/Share_HumanAI/...`) -- `Config.SENKA_STATUE_STANDING_ANIM_CLASS`, which once held
   it, was deliberately deleted when the statue pose-porting work was closed out as dead for THAT use
   case. Next step (not yet run): `lbtestlistclass /Script/Engine AnimBlueprint StandingNPC` to
   re-derive the real path live via the AssetRegistry, then call `Spawner.SetAnimClass` on the swap
   actor with it. The floating (not T-pose) half of this symptom is suspected to be a related but
   separate gap -- likely `CharacterMovement` settling/ground-detection tuning a real donor's own
   Blueprint provides as an override that a blank native class doesn't -- not yet investigated.

**Status**: the core mechanism (§19w) remains fully confirmed and closed. This section's own scope --
making a from-scratch class actually usable for the real Barbie-roster workflow, not just spawnable --
is IN PROGRESS, not closed: visibility is solid, sex resolution has a fix applied pending retest, and
animation/grounding are diagnosed but not yet fixed.

**UPDATE, same night -- sex resolution CONFIRMED FIXED live; the animation attempt crashed
instead, guarded out, not yet a working fix.** Also caught a real process mistake along the way: the
`bodyTypes` fix above was edited in `Working\LivingBaseEnhanced\...` but never actually deployed to the
live install (`J:\SteamLibrary\...`) -- a full game restart still ran the STALE `spawner.lua`, which is
why the first retest still showed `bodies=-`/`GetBodySex before=1 after=1` despite the fix already
being committed. **Lesson: an edit to the `Working` copy is not live until explicitly copied to the
install path (`diff` the two `spawner.lua`s to confirm), regardless of whether the game was just
freshly restarted** -- a fresh launch only helps if the deploy step already happened first. Once
actually deployed and `lbreload`'d:
- **Sex resolution: CONFIRMED WORKING.** `bodies immediate read-back` now shows the real
  `DA_NPC_BodyTypesParams_Common` object (not empty), and `GetBodySex` read `2` (Female) immediately
  after the pre-build composite write -- the sex landed on the FIRST build, no post-build swap step
  even needed. The theory (blank class has no valid `BodyTypeParams` pool to resolve against) was
  correct, and explicitly supplying the real pool's path fixed it completely.
- **Animation: attempted, crashed, guarded out.** Wired `Spawner.SetAnimClass(actor,
  ".../ABP_StandingNPC_Regular_AI.ABP_StandingNPC_Regular_AI_C")` in behind the same
  check-before-fix pattern as the base-mesh fix (only fires when `Mesh:GetAnimInstance()` is actually
  nil, a no-op for real donors). Live result: **crashed within ~60ms of the call, no further log
  output at all** -- same crash signature as the earlier Woodman female-swap crash
  (`EXCEPTION_ACCESS_VIOLATION`, bottoms out in `VCRUNTIME140.dll`, no symbols for either
  `UE4SS.dll` or the game exe, so the real callstack is unrecoverable via `parse_minidump.py`). Timing
  correlation with the log is unambiguous even without a symbolicated stack. Revised theory:
  `ABP_StandingNPC_Regular_AI`'s "Share_HumanAI" folder name suggested a generic, reusable AnimBP back
  in the 2026-08-14 statue investigation, but it's specifically the "_AI" variant -- very likely its
  graph reads AIController/blackboard data (movement speed, IsMoving, etc.) that only exists on a real
  `AR5AIController`. This class's own `Controller` is a plain generic `/Script/AIModule.AIController`
  (confirmed via probedump), so the AnimBP almost certainly null-derefs querying data that isn't there
  on its first tick. Same root-cause family as every other gap this class has hit tonight -- this one
  just crashes instead of rendering wrong. **Guarded out** (same "confirmed crash, don't retry blind"
  rule already applied to Woodman): the check-before-fix logic still runs and still detects the missing
  AnimInstance, but no longer calls `SetAnimClass` -- logs a clear reason and leaves the actor T-posing
  (visible, no crash) instead. **Next real step, not yet attempted**: wire a real `AIControllerClass`/
  `AIPawnParams` onto this class first (the same pre-BeginPlay mechanism already proven for
  `BodyTypeParams`/`DefaultParams`/`ArchetypePreset`), giving the AnimBP an actual `AR5AIController` to
  query, then retry the AnimClass swap against that.
**Status, updated**: visibility + sex are both CONFIRMED SOLID now. Animation is a confirmed-unsafe
path pending a real `AIControllerClass`/`AIPawnParams` fix, not yet attempted. Floating/grounding
remains uninvestigated on its own.

**UPDATE, same night -- the AIController theory was tested directly and DISPROVEN. Two real process
gotchas found along the way, both worth remembering.**

First, a genuine operational hazard recurred: after the second crash, several `lbreload` calls were
fired in quick succession while iterating on a diagnostic print. Every SYNCHRONOUS part of a spawn
(the `preFinish` composite-params write, sex/body resolution, component stripping) kept working
correctly on every subsequent test -- but the DELAYED part (`applyPhase2`, scheduled via
`ExecuteWithDelay` ~1.5s after spawn -- the base-mesh override, the AI-controller override, the
animation check, even a brand-new debug print added specifically to diagnose this) produced **zero
log output at all** across several consecutive tests, with no error either. This is the exact same
"double-lbreload scare" hazard already documented earlier in this project (2026-08-14): repeated
rapid-fire `lbreload` calls can wedge the timer/delay system itself, not the code -- every synchronous
codepath still runs fine, but anything scheduled via `ExecuteWithDelay` silently stops firing, with no
error to point at the real cause. **Fixed by a full game restart, not another reload** -- confirmed:
the very next test after a real restart produced full `applyPhase2` output again, including the new
debug print. **Lesson, worth remembering going forward: if a delayed/scheduled callback produces zero
output across multiple tests while everything synchronous keeps working, suspect a wedged timer system
from reload frequency before suspecting the new code** -- chasing this as a code bug wastes real cycles
(several iterations were spent here before recognizing the pattern).

Second, a silent failure mode: `Spawner.Spawn`'s own AI-controller-class resolution failure used the
`Config.VERBOSE`-gated `log()` helper instead of the unconditional `always()` -- meaning if
`resolveClass` had failed on the override path, NOTHING would have printed anywhere, not even
`_DoEngineSpawn`'s own always-on "override set/FAILED" line (which is itself gated behind `if aiClass
then`, so it silently doesn't fire either when resolution fails upstream). Fixed to use `always()` --
a real instance of the exact failure mode `always()` was created to prevent in the first place (see its
own header comment), just one level removed (a resolution failure feeding into a conditional whose own
logging is unconditional, rather than a bare gated log call).

**Once the timer-wedge was cleared with a real restart, the actual test finally ran cleanly and gave a
definitive answer**: a debug print confirmed `Config.HANDYMAN_AI_CLASS` resolved correctly and
`AIControllerClass override set for BodyTypeSwap` fired BEFORE the `SetAnimClass` call -- a real
Windrose `AR5AIController`-family controller was genuinely wired in this time, not a generic engine
one. **The AnimClass call crashed anyway, at the IDENTICAL exception address as the first crash**
(`VCRUNTIME140.dll`, offset `0x1dc1c`, confirmed via `parse_minidump.py` both times). Two identical
crashes under two different controller states rules out the AIController/blackboard-read theory
entirely -- whatever `mesh:SetAnimInstanceClass()` is doing here, it is NOT about what's possessing the
pawn. **Re-guarded out for good this time** -- not safe to retry a third time via this same mechanism.
One genuinely untested alternative worth trying in a future session: `Spawner.SetAnimClass`'s own
fallback (a bare `mesh.AnimClass = cls` property write, skipping `SetAnimInstanceClass`'s forced
live-rebuild of the AnimInstance entirely) has never actually been exercised in isolation -- both
crashes hit the PRIMARY call before `pcall` could ever fail over to it, since a hard native access
violation isn't a catchable Lua error. Trying the bare property write directly, bypassing
`SetAnimInstanceClass` altogether, is a genuinely different mechanism, not a third attempt at the one
now disproven twice.

**Status, final for tonight**: visibility and sex resolution are both CONFIRMED SOLID and durable
fixes, safe to build on. The AI-controller wiring itself (`DONOR_INDEPENDENT_AI_CONTROLLER`,
`Config.HANDYMAN_AI_CLASS`) is real, live-confirmed working, and kept -- it's genuinely useful on its
own merits regardless of the animation dead end. Animation via `SetAnimInstanceClass` is now a
confirmed-twice dead end, not merely unattempted; the bare-property-write fallback is the one
concretely untested next idea. Floating/grounding remains completely uninvestigated.

**THE REAL BREAKTHROUGH, same night: both animation and floating fixed for good, via the Editor, not
runtime Lua at all.** The bare-property-write idea above was tried and also confirmed dead --
`mesh.AnimClass = cls` (skipping `SetAnimInstanceClass` entirely) doesn't crash, but doesn't build an
AnimInstance either (`GetAnimInstance()` stayed nil, still T-posing): instance construction only ever
happens once, during component registration/`BeginPlay`, which already ran with `AnimClass=None` for
this class. There is no safe RUNTIME mechanism left to try -- the fix had to happen before the object
is ever constructed, at author time.

**Key discovery that made this cheap instead of requiring a C++ recompile**: `Mesh` is not one of
`AR5AICharacter`'s own custom components -- it's inherited from Unreal's own `ACharacter` base class,
which creates it (as `CharacterMesh0`) unconditionally in its OWN constructor, regardless of what a
subclass's constructor does. Checked directly via a pure-read Python script
(`diag_check_mesh_cdo.py`) against our from-scratch stub's own compiled CDO in the Editor, with NO
recompile at all: `Mesh` already existed, fully valid, and `AnimationMode` was already
`ANIMATION_BLUEPRINT` by default. Only `AnimClass` itself was `None`. This meant the fix was a pure
content change (bake one property), not a code change.

**Baking `AnimClass` hit a real, structurally different wall than every prior retarget in this
project**: `TSubclassOf<UAnimInstance>` is a HARD CLASS reference, and our SDK-stub Editor project has
no access to the actual Windrose AnimBlueprint asset (same fundamental limitation as everything else in
this doc -- only header stubs, never real `.uasset` content). Every PRIOR retarget in this project's
history (body meshes, skin materials, DataAsset piece references) only ever touched a
`SoftObjectPropertyData` value in place -- a single field write, no import-table involvement. A class
reference has no such simple path: it resolves through the package's own IMPORT TABLE. Fix, proven live
for the first time:
1. Add one trivial placeholder `UCLASS() class UR5PlaceholderAnimInstance : public UAnimInstance` to
   the project's existing placeholder-types file (same file already holding 38 other such stubs) --
   `UAnimInstance` lives in the `Engine` module, already a dependency, so this compiled in ~10 seconds,
   no new build config needed.
2. Bake it as `Mesh.AnimClass` on the Blueprint's own CDO via Python (`get_editor_property`/
   `set_editor_property` on the component object itself, then `compile_blueprint`+`save_loaded_asset`)
   -- confirmed the override survives a Blueprint recompile by re-reading it fresh off the generated
   class immediately after, settling an old open question from earlier in this project (whether a
   property override on an INHERITED, not Blueprint-added, component genuinely persists as a per-
   Blueprint default).
3. Cook the single package as usual.
4. **New technique**: retarget the CLASS reference on the COOKED output. Inspected the cooked
   `.uasset`'s own export data directly (via the project's existing UAssetAPI Python helper) and found
   `AnimClass` serializes as `ObjectPropertyData` whose `Value` is an `FPackageIndex` pointing at an
   Import table entry for the placeholder class. Rather than editing that import in place (risky --
   other exports in the same package reference other entries in the same table by position), ADDED two
   new imports at the end of the table instead: one `Package`-type import for the real destination
   asset's package path, and one `BlueprintGeneratedClass`-type import for its generated class, parented
   to that package import (`FPackageIndex.FromImport`, UAssetAPI's own helper for building the right
   negative index). Repointed the property's own `FPackageIndex` at the new class import, wrote, and
   verified by reloading the file fresh. **Confirmed structurally valid via `retoc info`, and confirmed
   LIVE**: after packaging and installing, animation played correctly with ZERO runtime Lua
   intervention needed at all -- the "no AnimInstance" check-and-fix code path never even fired,
   because there was nothing left to fix.
5. Package + install exactly as before (§9). One real gotcha hit: re-cooking a package OVERWRITES the
   import-table retarget from a previous packaging pass -- if a second bug is found after the first
   fix and the source Blueprint needs another property change, the class-reference retarget has to be
   RE-APPLIED to the fresh cook before packaging, every time. (Also hit, unrelated to the technique
   itself: installing over a pak the game currently has open fails with "Device or resource busy" --
   close the game fully before overwriting an installed `.utoc`/`.ucas` pair, the same class of gotcha
   as every other live-file-lock issue in this project.)

**Floating, once animation was confirmed fixed, turned out to be a completely separate, much simpler
bug of the exact same shape.** A new pure-read diagnostic (`lbtestmovement`, dumps
`CharacterMovement`'s full property list on the current test actor) showed the movement component's
own tuning was entirely normal -- `GravityScale=1.0`, `MovementMode=1` (Walking, meaning the CAPSULE
already believed it was correctly grounded). That pointed away from physics and at the MESH's own
render offset instead: `Mesh.RelativeLocation` read `(0,0,0)`, with the actor's own world Z and the
mesh's own world Z confirmed identical (zero offset). The standard `ACharacter` idiom -- used by
virtually every character Blueprint that has ever shipped, and matching this project's own
independently-confirmed `CapsuleComponent` half-height of exactly `96.0` -- is
`Mesh.RelativeLocation.Z = -CapsuleHalfHeight`, moving the mesh's pivot down to the capsule's BASE
instead of its center, so the character's feet touch the ground the capsule is already resting on.
Baked `(0, 0, -96)` onto the same CDO the exact same way as `AnimClass` (a plain `FVector` property
this time -- no import-table complexity needed at all, since it's not a reference). **Confirmed LIVE**:
no longer floating.

**AI/wander behavior turned into its own deep sub-investigation, later in the same night -- RedFalcon
corrected the record: walking is a REQUIRED part of the final product, not a bonus curiosity ("the
photos are not the final product, just incidental").** Confirmed possessing correctly
(`AIControllerClass override set`, a real `BP_NPC_AIController_Handyman_C` instance as `Controller`)
early on, but she just stands idle with AI unfrozen. A long diagnostic chase, each step built as a
new PURE-READ console command (`lbtestaicontroller`, `lbtestblackboard`, `lbteststatetree`,
`lbtestcrewcomponents`), diffed live side by side against a real, actively-wandering Gatherer
(targeted via the existing probe-lock tooling) rather than reasoned about from documentation:

1. **Blackboard was a dead end by design, not a bug.** `Controller.Blackboard` read as generic,
   untyped "UObject:" wrappers whose `:IsValid()` calls were themselves unreliable (this UE4SS
   binding doesn't support `:IsValid()` on every property-read wrapper shape -- confirmed by checking
   `dumpObjectProperties`' own read path, which never calls it, only `:GetFullName()`). Fixed the
   diagnostic (plain nil checks instead), but the deeper finding held on the REAL Gatherer too:
   Blackboard was never the right thing to look at at all. This controller's actual brain is
   `BrainComponent = R5AIStateTreeComponent` -- a modern Unreal State Tree, which doesn't use the
   classic Blackboard+BehaviorTree system Blackboard belongs to; the property is just inherited dead
   weight from the base `AIController` class.
2. **StateTreeComponent's own `Params`/`SchemaClass` (a `R5AIStateTreeComponentParams` DataAsset,
   `DA_NPC_Handyman_StateTreeParams`) were confirmed BYTE-IDENTICAL to the real Gatherer's**, since both
   use the exact same real, shared `BP_NPC_AIController_Handyman_C` class -- ruling the controller's
   own class-default configuration out entirely as a source of difference.
3. **The actual, definitive finding**: `StateTreeComponent.StateTreeRef.StateTree` (the COMPILED tree
   asset reference itself, a separate struct field from `Params`) read back with `:GetFullName()`
   returning nil, `GetStateTreeRunStatus() = 4`, `IsRunning() = false` -- versus the real Gatherer's
   valid asset reference (`ST_Mob_Handyman_Worker_Calm_Unagressive`), status `0`, `IsRunning() = true`.
   **Her StateTree genuinely never starts running at all** -- this was never a "decides not to wander"
   problem, it's "the underlying tree literally isn't ticking."
4. Pre-warming the StateTree asset itself (`resolveAsset`, same cold-load-race fix already used twice
   tonight for the mesh/skin material) made NO difference -- ruling out a simple cold-package-load
   explanation.
5. **A second real, confirmed data gap found via `lbtestcrewcomponents`** (extended to also dump
   `R5AgentComponent`/`MemoryComponent`, beyond its original `ScenarioCrewActorComponent`/
   `FactionComponent`/`OwnershipComponent` scope): both `R5AgentComponent.Params` and
   `MemoryComponent.Params` read as unresolved generic `UObject:` wrappers on this class, versus real,
   properly-typed assets (`DA_Mob_DodoF_AgentParams`, `DA_AI_Memory`) on the Gatherer -- both living
   under generic/shared paths, not Handyman-specific naming, strongly suggesting universal AI-agent
   defaults rather than donor-specific content. Wired both in via the same pre-`BeginPlay` window as
   `AIPawnParams` -- confirmed via readback that both now correctly resolve, matching the Gatherer.
   **Did NOT fix `StateTreeRef.StateTree` or `IsRunning()`** -- still nil/false afterward, unchanged.
   (`FactionComponent.FactionsParams` was ALSO found and fixed the same way earlier in this chase:
   `makeFriendly=true`, tried as an early guess, assigns `DA_Player_Crew_Faction` -- the PLAYER'S OWN
   crew faction, wrong tool entirely for citizen identity -- reverted, and `DA_NPC_Faction`, the real
   citizen faction, assigned directly instead.)
6. **A fourth crash, a genuinely different signature from the earlier two**: tested whether
   `Spawner.SetAILogic(actor, false)` -- called within milliseconds of every spawn, to freeze AI for
   photo capture -- interrupts the StateTree's own first-time initialization before it finishes, by
   delaying the freeze 2000ms instead of calling it immediately. **Crashed live**, this time inside
   `UE4SS.dll` itself (not the game engine, unlike the two earlier `SetAnimInstanceClass` crashes) --
   she spawned in fine, then crashed a few seconds later, right around when the StateTree would have
   first started actually ticking. Reverted immediately back to the original immediate freeze (safe,
   confirmed working). The theory (freezing too early corrupts first-time StateTree init) remains
   UNTESTED, not disproven -- the test itself crashed before it could give a clean answer either way.
**Current best understanding, not yet confirmed**: `StateTreeRef.StateTree` is a property on the REAL,
shared `BP_NPC_AIController_Handyman_C` class -- not something this project owns, edits, or sets
itself. It resolves correctly on a real donor's own controller instance but is persistently broken
specifically for an actor spawned via `SpawnActor` at runtime, regardless of what other correct data
surrounds it. Neither asset pre-warming nor fixing sibling component data changed it. Leading theory:
this may be tied to the engine's own level-load/batch-population process resolving soft references in
a way an individual runtime `SpawnActor` call never triggers -- a genuinely structural difference, not
a missing-field bug, and possibly beyond what pure Lua reflection can reach at all (the failure lives
inside compiled engine code, with no symbols on either binary to trace further).
**Explicitly reconsidered and rejected as a fallback**: reusing a real donor's own class (the original
pre-this-whole-section "Barbie" approach) is NOT a clean, safe alternative -- the same donor-Blueprint
clothes+gender-swap combination already crashed repeatedly earlier the same night (Woodman, then
BlackAxel; see this section's own opening), which is why the from-scratch class was built in the first
place, and it constrains body-shape options to whatever a given donor's own archetype allows. Neither
path is currently both safe AND complete for walking specifically -- explicitly PAUSED (not abandoned)
at RedFalcon's own call, to resume with fresh eyes.
**Real, reusable tools now in place for picking this back up**: `lbtestaicontroller [filter]`,
`lbtestblackboard`, `lbteststatetree`, `lbtestcrewcomponents`, `lbtoggleswapai <on|off>` -- all pure-read
except the toggle, all built around `resolveTestDiagActor()` (falls back from `Spawner._bodySwapActor`
to `Spawner._lastProbedActor`, since a `lbreload` resets the former to nil even though the actual actor
survives) so they work on ANY currently-targeted actor, not just the current body-swap subject --
already proven useful for direct A/B comparison against a real donor targeted via the existing
probe-lock tooling.

> **UPDATE 2026-09-10 -- walking now works, see §19y.** The "paused" status below was resolved the
> next day: on a fresh game launch (not an `lbreload`) with the deployed `preFinishAIPawnParams` fixes,
> the donor-path swap walks and her StateTree reads the real-Gatherer baseline (`RunStatus=0`,
> `IsRunning=true`). RedFalcon confirmed the donor path is the shipping approach; the from-scratch
> class is shelved (kept, not deleted).

**Overall status: the STATIC appearance goal, stated plainly at the top of this whole section, is now
FULLY MET; AI/walking is a real, required, currently-open item, explicitly paused for tonight.**
A genuinely new, donor-independent NPC class spawns visible, correctly sexed/dressed, animated, and
grounded -- confirmed live, repeatedly, with no crashes. Every gap chased across this entire section
(empty mesh, cold-load timing, sex resolution, two separate crash dead ends, and finally animation +
floating) traced back to the exact same root cause every time: a real donor's own class defaults supply
a pile of "free" native setup that a from-scratch class simply doesn't have, and each one needed finding
and supplying explicitly, either at runtime (mesh, sex, AI-controller class) or, once runtime hit a
genuine wall, by baking it directly onto the Blueprint's own class defaults in the Editor (AnimClass,
Mesh offset) -- a technique now proven twice, including for a class reference for the first time ever
in this project. Wander/AI behavior is the one remaining loose end, explicitly non-blocking for the
actual use case.

### 19y. Resuming the walking wall with a real API surface: jmap + the `lbwakeai` graft attempt (2026-09-10)

Picked the AI/walking item back up (RedFalcon: this IS a required part of the final product, not
incidental). The whole §19x chase was done with blind reflection probing -- guessing property names,
never actually knowing the native function surface. `trumank/jmap` (see the SDK-stub project's
`Content/DynamicClasses/SUZIE_SETUP.md`; produces a 106 MB JSON reflection dump of the shipped game
from a Task-Manager full-memory minidump) changes that -- it gives the exact declared classes,
properties, offsets, and `UFUNCTION` signatures. Reading `windrose.jmap` for the AI classes settled
several things §19x could only guess at:

- **`R5AIController.StateTreeComponent`** is a real declared `ObjectProperty` at offset 968, class
  `R5AIStateTreeComponent` (which extends the engine's `UStateTreeComponent`). The old
  `ctrl.StateTreeComponent` probe was hitting the right thing.
- **`R5AICharacter:ActivateCharacter()`** -- `FUNC_Final | FUNC_Native | FUNC_Public |
  FUNC_BlueprintCallable`, **no parameters**. The name is exactly what §19x was theorising about ("an
  activation step a level-placed NPC gets that a runtime `SpawnActor` never triggers"). Never called
  before -- prime first thing to try.
- **`UStateTreeComponent:SetStateTree(UStateTree*)`**, **`:SetStateTreeReference(FStateTreeReference)`**,
  **`:SetStartLogicAutomatically(bool)`** -- all `BlueprintCallable`. The CDO has
  `bStartLogicAutomatically = false`, and `Default__R5AIController:StateTree.StateTreeRef.StateTree`
  is **null even on the real controller CDO** -- so the tree reference is NOT a class default at all;
  something populates it at runtime for a normally-spawned NPC.
- **`R5AIStateTreeComponentParams`** (the `Params` DataAsset on the component, confirmed byte-identical
  to a real Gatherer's in §19x) holds **`StateTreeMap`: `Map<GameplayTag, R5AIStateTreeStateData>`**,
  where `R5AIStateTreeStateData` is a one-field struct `{ UStateTree* StateTree }`. So the R5 AI system
  **selects its active tree from this map by GameplayTag** (and `R5AIStateTreeComponent:OnStateChanged(PrevState, CurrentState)`
  -- both `GameplayTag` -- is the switch hook). The map is the authoritative source of the correct tree
  for this AI, better than hard-coding `ST_Mob_Handyman_Worker_Calm_Unagressive`.
- **`R5AIController:StartLogic()` / `StopLogic()`** -- already used safely mod-wide via
  `Spawner.SetAILogic`. `R5AIPawnParamsStateTreeEvaluator` exists as a StateTree evaluator struct,
  confirming `AIPawnParams` feeds the tree at tick time (so the §19x work wiring those in was not
  wasted, it's a real input -- just not the thing that STARTS the tree).

**New command `lbwakeai [status|activate|graft]`** (`Spawner.WakeAI`), runs on the current target:
1. `status` -- reads `StateTreeRef.StateTree` / `GetStateTreeRunStatus()` / `IsRunning()` and the
   brain component class.
2. `activate` -- calls `R5AICharacter:ActivateCharacter()`, re-reads.
3. `graft` -- Xenophon's native-AI taming recipe (see `project_crew_type_exploration` memory), never
   tried in LivingBase before: pull the real `UStateTree` from `Params.StateTreeMap` (fallback: resolve
   the Handyman calm-worker asset), then `StopLogic()` -> `SetStartLogicAutomatically(true)` ->
   `SetStateTree(tree)` -> `StartLogic()`, verified by readback.
4. no arg (`auto`) -- does status -> activate -> status -> graft -> status.

Every native call is individually `pcall`'d with an `always()` line printed immediately **before and
after**, so if any of them hard-crash (the `SetAnimInstanceClass` pattern from §19x -- an access
violation is not a catchable Lua error) the log pins down the exact call. `ActivateCharacter` and
`SetStateTree` are the two genuinely-new calls; `Stop/StartLogic` are already-proven-safe.

**Result (2026-09-10): the wall came down on its own -- `lbwakeai` was NOT needed.** On the first
in-game run after deploying, a normal donor-based swap (a real native NPC donor + composite look +
`lbfreeze off`) had her **walking** -- and `lbwakeai status` (pure read) confirmed
`StateTreeRef.StateTree = ST_Mob_Handyman_Worker_Calm_Unagressive`, `GetStateTreeRunStatus() = 0`,
`IsRunning() = true`: the exact real-Gatherer baseline §19x could never reach. Even the *frozen* state
was now correct -- her head tracked the player (the look-at behaviour real frozen NPCs have), where
before she was fully inert.

**Why it works now when §19x said it didn't**: §19x did almost all its testing via `lbreload`, which
(a) does NOT re-derive scripts from `Working\` -- only a manual copy to the live install does -- and
(b) wedges `ExecuteWithDelay` after repeated rapid calls, so the deferred pre-warm / pre-possess
window (`preFinishAIPawnParams`: Faction/Agent/Memory params + the pre-warmed StateTree asset resolve)
silently never completed. A genuine cold game launch on the deployed code runs that window intact and
the StateTree initialises normally. The lesson is a process one, already in the deploy-discipline
memory: **after editing a mod file, copy it to the live install AND validate on a fresh launch, not an
`lbreload`, before concluding a fix doesn't work.**

**`lbwakeai` / `Spawner.WakeAI` are kept as a fallback** -- if a future from-scratch or exotic class
spawns with a dead StateTree, the `ActivateCharacter()` + graft path is ready and the jmap-derived API
notes above stay valid.

**Scope note**: this was verified on the **donor path** (real native NPC as the base class), which
RedFalcon confirmed (2026-09-10) is the shipping approach for the walking "Barbie" -- the from-scratch
`BP_BarbieR5Char_Test` class is shelved (not deleted; the SDK-stub authoring work, baked AnimClass /
Mesh offset all remain).

### 19z. The "the composite rebuild is fundamentally unreliable" crash saga -- it wasn't the rebuild, it was a use-after-free in a say() (2026-09-10)

Building the walking-Barbie roster, a `lbtestbodyspawn` command (a variant of `lbtestbodyswap` that
never despawns/replaces -- brand-new spawn every call, for testing) crashed **6/6**: "spawns in, then
crashes with a dump ~2s later." Chased for most of a session as "the cross-sex composite rebuild is
probabilistically unstable" (which the config comments had long claimed) and nearly pivoted the whole
project to baking the look into a cooked Blueprint to avoid runtime composite work entirely.

**It was none of that.** `parse_minidump.py` on every dump: `EXCEPTION_ACCESS_VIOLATION` at the
*identical* `UE4SS.dll +0x3a9139` every time. An A/B against plain `lbtestbodyswap` (which never
crashed) isolated the one difference: the new command's `say(msg)` did
`if Ar then pcall(function() Ar:Log(msg) end) end` (copied from other command handlers) -- and that
`say` is threaded through `SwapBodyType` -> `pollForBuildThenApplyBodySwap` -> a `ExecuteWithDelay`
callback (`applyPhase2`) that runs **~2 seconds after the console command already returned**. By then
`Ar` (the `FOutputDevice`) is destroyed; `Ar:Log` on the freed pointer is an uncatchable native AV
(`pcall` never sees it). Removing the `Ar:Log` line fixed it completely -- Gatherer + Herbalist spawn,
strip, and walk with zero crashes.

**Rules banked:**
- **Never capture `Ar` in any closure that can outlive the command handler's synchronous return.** A
  `say()` passed into deferred/polled/timer code must `print`/file-log only, never touch `Ar`.
- **UE4SS truncates `ue4ss.log` on every launch** -- a crash's last lines vanish the moment the game
  relaunches, which is what made this a multi-hour guess. Fix shipped: `spawner.lua`'s `lbLogFile()` /
  `Spawner.dbg()` append key lines to a PERSISTENT `Mods/LivingBase/livingbase_debug.log` (rotates at
  4 MB, session banners). Do **not** wrap global `print` to do this -- an attempt to, and its per-line
  file I/O on the game thread during a composite build, correlated with a fresh crash; keep the sink
  on `always()`/`dbg()`/explicit calls.
- A **leftover persisted "BodyTypeSwap" test actor** (from an earlier crashed session) is restored on
  every launch and its own composite rebuild races a new test spawn -- a real secondary crash cause,
  now fixed by marking `lbtestbodyswap`/`lbtestbodyspawn` spawns **transient** (no persist entry;
  same mechanism the night-raider spawns use). Dev/test spawns should never persist.
- **Underwear (Torso/Legs -> `SK_Armor_Underwear_0*_Female_*`) is a cold reference** -- missed on the
  first spawn of a fresh session, applied fine after a reload. Pre-warmed near the top of
  `SwapBodyType` alongside the StateTree/AIPawnParams pre-warms.

**Net**: the runtime donor-swap path (female donor -> composite build with Barbie `DefaultParams` +
Adventurer archetype -> strip to underwear -> walk) is now confirmed working end to end, no crash. The
bake / JsonAsAsset-Reflection detour is **not needed** and was stood down (Reflection stays cloned at
`Other/JsonAsAsset-Reflection` for a possible future use). **Male donors** (BlackAxel/MortarMan/
Woodman/JasperCrowe) still hit a *separate* `VCRUNTIME140.dll +0x1dc1c` memcpy crash inside
`SwapBodySex()` -- so the roster is built on the natively-female donors (Gatherer/Herbalist) with the
male-donor *body shapes* supplied by the already-baked `DA_Custom_BodyType_*AsAdventurer` retargets,
not a live sex swap.

### 19aa. The `SwapBodySex()` crash was a third-party nude mod, not our code -- and the full family×family×sex origin matrix gets finished (2026-09-10/11)

**The male-donor `SwapBodySex()` crash (§19z's closing paragraph) is RESOLVED -- root cause was
`Female_NUDE_P.pak`/`Alibon_Nude_P.pak`, two Vortex-installed third-party mods sitting in
`R5/Content/Paks/LivingBase/` (NOT `~mods` -- a separate folder this project's own paks never touch,
which is why nobody thought to check it sooner) that replace `SK_Adventure_Female_01` /
`SK_Albion_Female_01` with nude re-exports.** Found while chasing an unrelated report ("the female
Adventurer body isn't resizing even in the stock character creator, and hasn't in a while") --
`retoc list` on both paks showed each ships exactly one skeletal mesh package, overriding those two
family meshes outright. Nude mesh re-exports routinely drop the original's morph targets (confirmed:
`SK_Adventure_Female_01` under the nude mod had none), which explains the creator symptom directly,
and very plausibly explains the `SwapBodySex()` memcpy crash too -- that function swaps skeletal
buffers between the current and target sex, and a topology/vertex-count mismatch between the
nude-modded mesh and whatever the swap code expects is exactly the shape of bug that produces a raw
`memcpy` access violation. **Confirmed live**: pulled both nude paks (moved out of the `LivingBase`
paks folder, `.vortex_backup` copies left in place, real files parked in the session scratchpad --
not deleted), then ran all 6 sex-change operations the finalized 7-shape roster needs (Herbalist F→M,
Farmer/Woodman/BlackAxel/MortarMan/JasperCrowe M→F) back to back -- **zero crashes.** The
`@X,Y,Z,YAW` reproduction workflow (`lbtestbodyswap`/`lbtestbodyspawn` print their landing spot; see
§19z) stays as cheap insurance but is no longer load-bearing for this crash specifically.

**The morph-shape pipeline this triggered a full re-investigation of (design deliberately distinct
character-creator bodies, author `DA_Custom_MorphParams_*`, apply at spawn) was fully built --
R5 stub classes added to the Editor project (`R5CompositeMeshComponentMorphParams`,
`R5MorphControllerInfo/Data`, `ER5MorphControllerType`, `R5BLCharacterMorphData`/`ER5BLMorphType`),
7 assets authored/cooked/packaged -- and then CLOSED AS DEAD, again**: this is the exact same
"Control Rig binds shape once at construction, never re-evaluates" wall from 2026-09-01 (see the
body-shape section above), now doubly confirmed with every remaining lever tried (`comp.MorphParams=`
pre-build, the full `StartCharacterEdit`/`SetMorphControllerValue`/`EndCharacterEdit`/
`ConstructVisualFromParams` session, raw `SetMorphTarget` on the 10 real `morph_zone_<zone>_x/y`
targets `lbdumpmorphtargets` found on `SK_Adventure_Female_01`, and `AnimInstance.BodyMorph`/
`lbtestbodymorph` itself). See that section's own "CLOSED, 2026-09-10" entry for the full writeup --
not repeated here. Roster body-shape variety ships from mesh/family selection only.

**New read-only diagnostic commands, all PURE READ, no state changes:**
- `lbdumpmorphtargets [test]` -- lists every `UMorphTarget` name on each skeletal mesh component of
  the player pawn (no arg) or the current test target (`test`). This is what found the 10 real
  `morph_zone_<body|head|nose|ears|brows>_x/_y` targets on `SK_Adventure_Female_01`.
- `lbtestmorphlive <DA_Custom_MorphParams_X>` -- applies a custom MorphParams asset's 5-zone values
  to the current target live (controller session + raw `SetMorphTarget` fallback), dumping
  `GetCurrentMorphControllers()` before/after. Built to test the morph pipeline in place, no respawn
  -- superseded by the "CLOSED" verdict above, kept for any future re-investigation.
- `lbtargetpose` -- `lbwhereami`'s counterpart for the current test target instead of the player pawn:
  prints X/Y/Z/Pitch/Yaw/Roll and a ready `@X,Y,Z,YAW` token for `lbtestbodyswap`/`lbtestbodyspawn`'s
  own spawn-position arg.

**The full origin×origin (family×family×sex) retarget matrix is now complete -- 112/112.** Started
narrow (RedFalcon: "commands to set the gatherer and hunter shapes to every origin mesh") and widened
once the first fix surfaced a real pattern (RedFalcon: "we should have an originasotherorigin for
every mesh and sex and bodyshape"). A coverage script against `bodytype_entries.json` (group every
`DA_Custom_BodyType_<Src>As<Dest>` by its own `BodyType` tag + `BodyTypeSex`, diff against the full
8-family list) found:
- **Adventurer/Male was only 1/7** (only `AdventurerMaleAsAfrican` existed, a leftover test entry) --
  filled the other 6 (`AdventurerMaleAs{Albion,Fable,Native,Orient,Scum,Senkamati}`), packaged as
  `LivingBaseHunterOriginBatch-Windows`.
- Re-running the coverage check, **every other family/sex was missing exactly ONE destination:
  Senkamati** (except African/Male, already covered via the existing `HunterAs*` chain -- Hunter's
  own native tag is African, not Adventurer, a real mix-up worth remembering: Gatherer=Adventurer/F,
  Hunter=African/M, they only share the *shape* value, not the family tag). Filled the 11 gaps
  (`AfricanAsSenkamati`; `Albion`'s `AxelAsSenkamati` F/M via `Axel`; `Fable`'s F + `FableMaleAs*`;
  `Native`'s F + `MortarAs*`; `Orient`'s F + `OrientMaleAs*`; `Scum`'s F + `ScumMaleAs*`), packaged
  as `LivingBaseSenkamatiGapBatch-Windows`.
- Verified twice: once per-family-tag (16 rows: 8 families × 2 sexes, each 7/7), once per **named
  donor label** (`Axel`, `Jasper`, `Mortar`, `Hunter`, `ScumMale`, `OrientMale`, `FableMale`,
  `SenkaMale`, plus the plain family names) -- a per-tag pass alone can hide a gap if two different
  named donors share one tag and only one of them got fixed (this session's own batch script duped
  from ONE template per (family,sex), so this check mattered); all 16+ named labels independently
  7/7. **Jasper's own tag is Adventurer, not Albion** (Axel is Albion's male donor) -- easy to
  confuse, confirmed via `bodytype_entries.json`, not assumed.
- Recipe used both times: duplicate an already-correctly-tagged sibling entry (same family+sex,
  different destination) so `BodyType`/`BodyTypeSex` carry over for free, reset `BodyMesh` to a
  fresh placeholder, run the existing `retarget_canonical_roster.py` (already knows every family's
  mesh/material naming, including the Adventurer-mesh misspelling and Senkamati's sparse Male/Female
  asset sets) against a fresh full cook, package the NEW entries only into their own small pak
  (zero-overlap with the existing canonical pak -- no re-touching already-shipped, already-retargeted
  output). `~mods` now carries 4 paks total; see `Content/BARBIE_ROSTER.md` for the authoritative
  list (a 5th, `LivingBaseMorphParams-Windows`, ships the now-dead morph assets and is slated for
  removal).

### 19ab. The Custom/Barbie outfit was 100% hollow placeholder content all along; `SlotsToSuspend` explains hair/headwear AND the Torso/Waist wall; a working import-table-surgery technique gets built; Hands added, Mask deliberately skipped (2026-09-11)

**Starting question, RedFalcon: "do all the hairs have a version that works with the various types of headwear?"** Wrong axis -- there's no per-hair "compatible with hat X" flag. The real mechanism, found via `windrose.jmap`: every composite piece (headgear included) is an `R5CompositeMeshParams` DataAsset carrying its own `SlotsToSuspend` map (`ER5BLCompositeMeshBodyPartType` -> `ER5BLCompositeMeshSuspendType`, values `None/SuspendHat/SuspendBandana/SuspendHeadband/Light/Medium/Full`) -- a per-piece "while I'm worn, hide slot X" rule, evaluated ONCE at the actor's initial composite build, never re-consulted afterward (confirmed later the same day, see below). Built `lbdumpheadgearsuspend` (batch, all 65 real Headgear pieces) and `lbdumpsuspend <path>` (any single piece) to query this live instead of guessing. Real data: 45/65 Headgear pieces suspend Hairs (mostly `SuspendHat`/`SuspendBandana`/`SuspendHeadband` by hat style); the 12 Senkamati feather headdresses + a few Drowned/Mask pieces don't suspend Hairs at all (empty map) -- likely intentional (feather crowns sit high/back).

**Separately, RedFalcon reported the Custom/Barbie spawn's Waist/Mask/Headgear-on-Female were missing.** Investigation found the actual root cause was much deeper than a missing slot: `DA_Custom_Piece2_FullSlots_*`/`DA_Custom_Piece7_Merged_*` (the local per-piece placeholders `DA_Custom_BarbieDefaultParams_Regular_Male/Female`'s own `CompositeMeshGroup_FullSlots(_Female)` reference) are **100% empty** -- confirmed via UAssetAPI on both the uncooked source and any fresh local cook, zero properties, every single one, not just the 3 reported missing. They were built as name-only stubs back on 2026-09-02/04 (`build_barbie_full_slot_group_v2.py`) and never populated -- a same-day PoC (`build_custom_attachment_poc.py`) already proved Editor Python in this SDK-stub project literally cannot see the `R5CompositeMeshData`/`R5CompositeMeshDataForCharacterSex` struct types needed to populate them.

**The REAL shipping outfit lives entirely somewhere else**: `Content/BARBIE_ROSTER.md` (2026-09-10, re-read too late in this session) already documented that the actual outfit ships from a separate, permanently-static `SplitFacial-Windows` pak, whose own copy of `CompositeMeshGroup_FullSlots(_Female)` got a one-off, hand-done (UAssetGUI) **import-table** retarget -- the group's own piece references were repointed at real vanilla game assets directly, bypassing the local placeholders entirely (which is why they're hollow: they were never meant to carry data, just exist as compile-time stand-ins before the import-table swap). **Real mistake made and caught same session**: a first packaging pass shipped the (for-the-live-game-inert) local placeholders inside `LivingBaseBarbieRoster-Windows` too, colliding by package name with `SplitFacial-Windows`'s own copies -- exactly the overlapping-pak problem this project fought to eliminate. Fixed by rebuilding the canonical pak from its own documented BodyType-only manifest (`canonical_roster_manifest.py`, 242 packages), verified zero overlap via a `retoc list` diff, re-ran `audit_barbie_full_matrix.py` clean (20/20). **General lesson: always re-read `BARBIE_ROSTER.md` in full before touching ANY `DA_Custom_Piece*`/`CompositeMeshGroup*`/`BarbieDefaultParams*` name on this project** -- it already documents which pak is real and which is a decoy layer.

**The import-table edit turned out to be scriptable after all (RedFalcon's own call: "2 sounds easier" over hand-editing in UAssetGUI).** `UAssetGUI.exe tojson <in> <out.json> <engine>` (the GUI's own bundled CLI mode) confirmed the same opacity my own UAssetAPI read showed -- every one of these piece references reads back as `/Engine/UnknownPackage`/`UnknownExport`, a genuine, permanent limitation of how `retoc to-legacy` converts this specific kind of Zen `FPackageObjectIndex` reference (a content-hash it can't reverse without the exact global-container context the original cooker had -- confirmed later: even redoing the conversion WITH the base game's own `global.utoc`+`pakchunk0-Windows.utoc` present alongside as context still shows Unknown for these specific entries; this is inherent to the reference TYPE, not a missing-context problem). The unblock: **Legacy-format imports are plain by-name strings on the WRITE side even though unreadable on read** -- `retoc to-zen` computes a fresh, correct hash from whatever name is written, so the fix never needs to see the old value. Confirmed the array-position -> Import-index mapping directly from `CompositeMeshesParams`'s own `tojson` export (`ObjectPropertyData.Value` is a negative `FPackageIndex`; real import index = `-Value.Index-1`; that import's own `OuterIndex` similarly names its owning package import) rather than assumed.

**Second real discovery needed to make the write not crash**: UE5.6's `FPropertyTag` carries a `PropertyTypeName` (a flat pre-order-encoded tree of `FPropertyTypeNameNode{Name,InnerCount}`) -- `UAsset.Write()` NULL-REFs on ANY freshly-constructed `PropertyData` whose `PropertyTypeName` is left unset (confirmed via a minimal repro: one bare top-level `EnumPropertyData` crashes on write without it, succeeds with it). `FPropertyTypeNameNode` is a value type with no public parameterless constructor -- build via `System.Activator.CreateInstance(t)` then set `.Name`/`.InnerCount` fields directly (pythonnet allows this on the boxed struct). Every node pattern used was reverse-engineered from real, already-working cooked assets in this project (never guessed) -- see `Tools/UAssetAPI/write_composite_piece.py`'s own header comment for the exact patterns per property type (Enum/Struct/Map/Array/SoftObject).

**Rewrote all 9 real body slots** (Torso/Legs/Feet/Headgear/Waist/Belt/Strap/Cape/Hairs; Mustache/Beard/Whiskers/Eyebrows/Hairs-dup deliberately left untouched, not reported broken) on both `DA_Custom_CompositeMeshGroup_FullSlots` and `_Female` to real, dual-sex-confirmed **Set_Vanilla**-family assets (Torso/Legs/Feet/Headgear/Waist/Belt from Set_Vanilla, Strap from Armor/Default, Cape from Jeweler, Hairs from the Any/Afro_01 pool) -- the SAME family the docs say was originally used, not swapped for anything new. Verified via UAssetAPI read-back before repackaging. **Then added Hands as a genuinely NEW 10th slot** (`add_hands_slot.py`) -- unlike the 9-slot rewrite, this GROWS `CompositeMeshesParams` by one element: appends 2 new Import entries (`UAssetAPI.Import`'s 5-arg string constructor + `FPackageIndex.FromImport(idx)`), then copies the array's `PropertyData[]` (a fixed-size .NET array, no `.Add()`) into a new, one-larger array with the new `ObjectPropertyData` appended. Confirmed CONFIRMED WORKING LIVE (Torso/Legs/Feet/Headgear/Cape/Belt+Frog+Sling+Strap+Hairs+Hands all real on a spawned BlackAxel).

**Mask/Scarf deliberately skipped, RedFalcon's own call**: the only real Mask/Scarf asset in the whole game (`DA_Armor_Regular_BlackBeard_Sailor_Mask_03`) permanently suppresses Mustache/Beard/Whiskers whenever present at the initial build, with zero alternative asset to pick instead (unlike Torso, where non-suspending options existed for other slots) -- adding it would cost every Male spawn's default facial hair. Matches the original 19n call to leave Mask out entirely.

**Also fixed, same session: a real, 3-times-confirmed-broken cloth-sim rebind call, walked back entirely.** `Spawner.TestApplyClothingPiece` and `Spawner.TestSwapArmorPiece`'s shared helper both had a second `SetSkeletalMesh(mesh, true)` call after the real `SetSkeletalMeshAsset` swap, meant to refresh Chaos Cloth binding. Three separate attempts since 2026-08-28 (direct call, `RecreateClothingActor()`, and a "fresh handle refetch" fix believed working) all throw the identical "UObject instance is nullptr" -- the "fix" was simply never actually exercised until this session's real Vanilla-content swaps finally triggered it. Removed entirely (matches this project's own "don't fight a broken native call" pattern, e.g. `feedback_windrose_cheatmanager_neutered`) -- `SetSkeletalMeshAsset` alone already works and likely already triggers UE5's own internal clothing-actor recreation on its own. Now reports `clothRebind=skipped` instead of a scary traceback every swap.

**The Torso/Waist saga -- a real process mistake made, caught by RedFalcon, and fully resolved with hard data.** While testing the above, RedFalcon separately found the native Female Herbalist wearing a real Torso AND a real Waist piece simultaneously -- and reported "we got legs torso and waist" after testing the REBUILT Barbie outfit. **I conflated these two things** and wrote (now-corrected) notes claiming the 2026-09-03 Torso/Waist exclusion (19n) was piece-specific and had been overturned by the Vanilla Torso fix. RedFalcon caught it: "you never built the barbies to have an item there" -- the Herbalist result was about her own native Underwear-classified Torso, unrelated to the Barbie outfit at all. Re-checked properly with `lbdumpsuspend` on the actual Vanilla Torso used: `Waist=Full`. Built `lbdumptorsosuspend` (batch, all 24 human-appropriate dual-sex Torso pieces in the game) to settle it with full data instead of one more anecdote: **24/24 declare `Waist=Full`, zero exceptions.** The Herbalist's own Torso (`DA_Armor_Regular_Character_Underwear_Torso_Female_CompositeMeshData`) is the ONE real non-suspending piece in the entire catalog, and it's Female-ONLY (no Male equivalent exists at all). **Final, fully data-backed conclusion: Torso and Waist cannot coexist with ANY real clothing outfit, on either sex, ever** -- not by default, and NOT as swap-in-only content either, since a suspended slot's component is never built at all (suspend is a build-time-only gate; hiding Torso afterward can't retroactively create a Waist component that was never constructed). This settles back to the ORIGINAL 2026-09-03 conclusion, this time backed by a full 24-piece survey rather than a single test. The mechanism (`SlotsToSuspend`, not a hardcoded MeshBodyPart rule) is real and still useful for checking OTHER slot pairings (`lbdumpsuspend`/`lbdumptorsosuspend`) -- just not a fix for THIS pairing specifically. **Process lesson for future sessions: before treating a live test result as confirmation of a specific fix, verify it was actually exercising that fix's own content** -- two actors sharing only "has a torso and a waist" was enough surface similarity to cause a real, hour-costing mix-up.

**A genuinely useful side-discovery from the same investigation, RedFalcon's own live test**: `lbtestpiece` (`Spawner.SetBodyPartMesh`) and the clothes-swap tree (`Spawner.TestApplyClothingPiece` -> `findCurrentSlotComponent`) identify "which component is slot X" via two completely different methods. `lbtestpiece` looks up the actor's own `BuildedCompositeMeshes` array by the REAL, permanent native `MeshBodyPart` enum (Torso=7) -- an identity that never changes no matter what mesh is later assigned. The clothes tree instead scans every component and pattern-matches each one's CURRENT mesh name against known tokens (`clothingSlotOf`) -- a name heuristic, not a structural lookup. Consequence, confirmed live: using `lbtestpiece Torso <a Waist-named mesh>` puts a waist-look onto the real Torso-enum component (since that's the only slot guaranteed to build) -- but the tree's own `findCurrentSlotComponent(actor, "Torso")` then finds nothing (the component's current mesh name no longer contains "Torso"), reporting "no item in the slot," even though `lbtestpiece Torso <...>` again still works fine (it never cared what the current name was). Not simultaneous coexistence -- one physical component, one mesh at a time -- but a real, usable trick for putting a waist-style look on what is structurally the Torso slot when a bare-chested-plus-wrap look is wanted instead of a shirt. **Flagged, not yet fixed** (RedFalcon: "maybe soon, as we will be changing them a bit for the custom tab") -- the natural fix would be having the tree's own lookup fall back to the same enum-based method `lbtestpiece` uses whenever the name-heuristic comes up empty.

**Also re-clarified, not a new rule**: Belt/Sling/Frog/Strap are NOT locked together as a system rule -- the real, still-current rule (19s, 2026-09-07) is a one-way dependency (Sling/Strap each require a Belt to be present; Belt stands alone fine) plus a soft "match the existing opposite item's Set number" cosmetic nudge, not a hard block on mixing. The OLD force-link-all-three behavior was deliberately removed the same day it was found backwards. Separately (unrelated fact, specific to one asset): `DA_Armor_Regular_Hero_Vanilla_Belt_01_CompositeMeshData` happens to be authored as a single bundle that internally defines Belt+Sling+Frog together -- confirmed live when wiring it in for the outfit rewrite above produced all three from one Belt-slot reference. That's a per-asset authoring choice, not a general constraint on all Belt pieces.

### 19ac. Age axis and skin decor (tattoos/makeup) explored and CLOSED; `MF_CharacterSkinAging` corroborates rather than reopens the Age wall; Physique dropdown shipped (2026-09-11, same day)

**Age**: `R5HFSMCharacterCustomizationComponent`'s Age system (`GetCharacterAge`/`SetAgeControllerValue`, 3 states Young/Mature/Old) is real, and visually confirmed in the character creator (a genuine wrinkle-texture change RedFalcon watched happen live) -- but the component is CREATOR-ONLY (a full `FindAllOf` sweep of a real gameplay level's 248 actors found zero instances outside the creator screen, and `GetOwner()` throws a stale-handle nullptr even though other calls on the same handle work). The underlying field, `SavedCustomizationData.CharacterAge`, IS readable and writable on any regular NPC (native variety already exists: Buccaneers Trapper=Mature, Farmer=Young; a live write with 3 escalating strategies confirmed the value genuinely sticks) but produces **zero visual change** on an already-spawned actor -- a load-time snapshot, not a live-driving value. New commands: `lbdumpage`, `lbtestage`, `lbdumpageowner`, `lbdumpsavedage`, `lbtestsavedage`. Also fixed a real FString-display bug found along the way (`fstrToLua()` -- UE4SS FString values need `:ToString()`; plain `tostring()` just shows the raw pointer).

**Skin decor (tattoos/makeup)**: substantial real content exists (Marita Suares' makeup, a Sailor bot's 6 body-region tattoos) and lives on the GENERAL `R5CompositeMeshComponent` (not creator-only, unlike Age) via `GetSkinDecorData`/`GetAvailableBodyDecorData` -- but `lbcustomnpc get` confirmed no Decor category exists among the mesh controllers on 4 different NPCs, so there's no live setter on the regular path either. Found the real per-option source assets directly (`DA_Hero_CompositeMeshParams_SkinDecor_Lips_Type_01` etc., 11 options for Lips alone), each carrying an already-existing `DecorName` GameplayTag -- resolving one via `resolveAsset()` sidesteps the documented "can't construct a GameplayTag outside the Editor" wall entirely (no construction needed). A live write test (`lbtestdecor <bodyPart> <assetPath> [paletteIdx] [test]` / `Spawner.ApplyDecorTag`, same 3-strategy escalation as Age) confirmed the write STICKS as data but produces zero visual change -- identical signature to Age and the earlier body/head morph closure.

**GENERAL RULE, now confirmed 3-for-3 (morphs, Age, decor)**: anything stored in `SavedCustomizationData` (or reachable only through it) is consulted EXACTLY ONCE, at the actor's initial composite/material construction, and never re-evaluated after a live write on an already-spawned actor. Check this FIRST before investigating any future "can we change X live" question on this component, rather than re-running a fresh write test each time. The only fix that has ever worked on this component is changing what's baked in AT construction (BodyType/SkinMaterials retargeting, the SplitFacial outfit's import-table redirect) -- never fighting a value after the fact.

**`MF_CharacterSkinAging` (FModel find, same day) corroborates this, doesn't reopen it.** RedFalcon found `/Game/Common/MaterialAttributeFunctions/Character/MF_CharacterSkinAging.uasset`, a `MaterialFunction` (graph stripped in this cooked build -- only `bExposeToLibrary`/StateId visible, per the project's own ghost-preview notes on cooked MaterialFunctions). The name links directly to a texture parameter this project already found and closed on 2026-08-28 (CLAUDE.md item 109): every actor's skin material exposes 4 `TextureParameterValues` beyond plain Albedo/Normal/SRM -- `FaceDecor`/`BodyDecor`/`"SkinDecor ID"`/`SkinAging` -- almost certainly this function's own node inputs. But that investigation already proved all 4 textures (plus the material's one scalar override, `RefractionDepthBias`) are **byte-identical across every actor tested** (9 actors, 4 skin families, native quest NPCs and statues included) regardless of visible age/makeup/tattoo differences. So the function is real and explains the creator's wrinkle effect mechanically, but reinforces rather than undermines the closure above: fully generic/baked at the material level, not a per-instance override reachable on an already-built composite actor. **Renamed the 2026-08-28 tool `lbtestdecor` -> `lbtestskinaging`** while investigating -- it had been silently shadowed at the console since this same session's newer `Spawner.ApplyDecorTag` reused the same command name via a later `RegisterConsoleCommandHandler` call (last registration wins); both tools kept, now disambiguated. Not chasing this further without a genuinely new lead.

**Physique dropdown shipped (LivingBaseSpawnMenu, same day)**: RedFalcon asked for a "Physique" dropdown under Camera in the Custom tab, wired to the pre-existing (2026-09-02) `Spawner.TestSetSkinSize`/`lbtestskinsize <Small|Medium|Large>` lever (finds whichever material slot on `actor.Mesh` currently carries a sized skin material by name pattern, swaps to the sibling size via `resolveAsset()` + `SetMaterial`) -- a genuinely different, already-proven-live mechanism from everything else in this section, unrelated to `SavedCustomizationData`. Labels per RedFalcon: Small="Toned" (later renamed "Boney"), Medium="Cut", Large="Soft". `BarbieMenu.cpp` gained a `ImGui::BeginCombo`/`Selectable`/`EndCombo` dropdown (first use of that pattern in this codebase, gated on `!has_target || MenuStatus::IsRestoring()`) writing `custom_physique_request.txt`; `main.lua` gained `pollCustomPhysiqueRequest()` folded into the existing 400ms `customColorPollLoop`. Deployed same day (game closed for the DLL swap, no hot-reload for the C++ side).

**Same-day follow-up bug: a real, pre-existing ImGui ID collision, unrelated to Physique.** RedFalcon hit an ImGui "2 visible items with conflicting ID!" popup right after testing. Root cause: `DrawPreviewSwatch()` (the Body Type/Origin thumbnail previews built earlier the same session) is called twice per frame with a bare literal ID on every return path (`"Choose..."`, `"(missing)"`, `"##preview"`), no `PushID` around either call site -- once both grids had a real selection at once (as in RedFalcon's screenshot), both preview swatches collided on the same ID. Fixed by giving the helper its own `id` parameter (`PushID`/`PopID` wrapped around all 3 branches), each call site passing a distinct id. Lesson for future ImGui work in this file: any helper called more than once per frame with a literal widget ID needs a caller-supplied `PushID`.

**MortarMan floating during placement -- FIXED, same day.** RedFalcon: MortarMan (alone among the 7 Barbie-picker body types) spawns floating well above the ground. Root cause: `SwapBodyType`'s `onSpawned` callback (`StartPlacementPreview` for this picker) fired synchronously right after `Spawner.Spawn()` returned, before `comp.BuildedCompositeMeshes` had actually finished populating -- the SAME async-build race `pollForBuildThenUndress` already solved for the underwear-strip step (2026-09-04). The floor-lock bounds read (`GetActorBounds`) that early caught a pre-build fallback guess close enough to correct for the other (walking Handyman-family) bodies to go unnoticed, but wrong enough for MortarMan (a stationary gun-emplacement NPC with different root/capsule sizing) to float him visibly. Fixed with a new generalized `pollForBuildThenOnSpawned(actor, name, callback, attemptsLeft)` (same self-rescheduling ~3.6s-capped poll idiom as `pollForBuildThenUndress`, reused for any callback) -- `onSpawned` now only fires once the build is real. Applies to every Barbie-picker spawn, a general placement-accuracy fix, not MortarMan-specific.

### 19ad. Facial hair (Eyebrows/Beard/Mustache/Whiskers) on Barbies was hollow from the start, same as every other slot before §19ab -- fixed the same way; a new lossless single-package raw-chunk pak-patch technique found along the way (2026-09-11, later same day)

RedFalcon, testing §19ab's own outfit fix with `lbtestpiece`, hit `"no BuildedCompositeMeshes entry found"` for Beard(2)/Mustache(17)/Whiskers(18) on a real male Barbie, then asked directly: **"are you not adding facial hair to the males?"**

Checked the group asset's `CompositeMeshesParams` array directly (UAssetAPI dump): Male has 15 elements total, not just the 9(+1) §19ab rewrote -- positions 9-13 are Eyebrows/Mustache/Beard/Whiskers/Hairs-dup. Female has 12 -- positions 9-10 are Eyebrows/Hairs-dup only (confirms facial hair never exists on a female composite build at all, not just a display convention). All of these tail positions resolved to a literal `UnknownExport`/`UnknownPackage` placeholder -- exactly what §19ab's own 9 slots looked like BEFORE their rewrite. First read as a possible regression from §19ab's own retoc round-trip (leaving them untouched while rewriting siblings could plausibly have broken a previously-working reference) -- but checking what they originally pointed at (`DA_Custom_Piece7_Merged_Regular_{Beard,Mustache,Whiskers,Eyebrows,Hairs}` + `_Sailor_*` siblings, real packages that DO exist inside `SplitFacial-Windows`) showed each one's own `.uexp` is a bare 17 bytes -- hollow, exactly like the original `Piece2_FullSlots_*` stand-ins §19ab already found and fixed. **Conclusion: not a regression -- facial hair was never wired up, same as everything else was before §19ab, just never tested until now.**

Fixed identically to §19ab: `Tools/UAssetAPI/rewrite_fullslots_facial_imports.py` redirects the group's own array elements directly at real native `CompositeMeshData` wrapper assets (found via pakcontents.xlsx, not guessed) -- `Eyebrows_01_Male/Female`, and the "Sparse" family for Male Beard/Mustache/Whiskers (a complete matching trio, for a coherent look), Hairs-dup reusing the same `Hairs/Any/Afro_01` asset already at position 8. Bypasses the still-hollow `Piece7_Merged_*` pieces entirely, same bypass strategy as the original 9 slots. Array position doesn't need to match a specific BodyPart -- each target asset carries its own BodyPart internally, so which of the N broken slots gets which real asset doesn't matter functionally.

**New packaging capability found while deploying this fix: a lossless, single-package raw-chunk PATCH for an already-shipped Zen pak, with no full re-cook and no original staging tree needed.** `SplitFacial-Windows`'s own original staging tree no longer exists on disk (predates this project). Extracting it back to legacy format to edit in place hit a wall: `retoc to-legacy` refuses any container lacking its own `ScriptObjects` chunk (true of every mod-built pak here). Fix: `retoc gen-script-objects --version UE5_6 <windrose.jmap> <dir>/global.utoc` synthesizes one from this project's own jmap reflection dump (`Content/DynamicClasses/windrose.jmap`); pointing `to-legacy` at a DIRECTORY containing both that generated container and the target pak (not the pak file directly) then succeeds. **But that jmap-synthesized source still can't resolve MOD-created import names** -- every cross-package reference reads back as `Unknown`, the identical effect that made §19ab's original 9 slots look broken in the first place. Round-tripping a WHOLE pak through this path would destroy every inter-package reference it carries (each `Unknown` gets baked in literally, then a `to-zen` repackage hashes that garbage into a dangling reference) -- unsafe for anything beyond a read-only check.

The safe technique instead: `retoc unpack-raw <pak>.utoc <dir>` dumps every package as a byte-identical raw Zen chunk (filed by chunk ID, e.g. `4ed7fd28ceae65f000000001`) with zero format conversion and therefore zero name-resolution risk. Build fresh, correct chunks for ONLY the changed package(s) by running ordinary `to-zen` on just their already-edited legacy-format files (chunk IDs are deterministic per package path, so the new build reproduces the identical chunk-ID filenames). Substitute just those chunk files into the unpacked raw set -- leave `manifest.json` and every other chunk, including the original `ContainerHeader` chunk, byte-for-byte untouched. `retoc pack-raw <dir> <pak>.utoc` rebuilds the full container. `retoc verify` confirmed the rebuilt container clean. One gotcha: `to-zen`'s own output includes a tiny required 347-byte stub `.pak` (the game's mount system still expects one alongside `.utoc`/`.ucas`) that `pack-raw` alone doesn't generate -- just copy the ORIGINAL pak's own stub across unchanged (confirmed byte-identical across 3 unrelated mod paks, a fixed generic placeholder, not content-specific). **This generalizes to any future single/few-package fix on an already-shipped pak whose original staging tree is gone -- no full re-cook needed anymore.** Backups of both the edited source files and the original installed `SplitFacial-Windows` pak triple were kept in the session scratchpad before writing anything.

**CRASH, immediately after deploying the above: "spawning a barbie crashes every time now."** Reverted at once -- game closed, original pre-fix `SplitFacial-Windows` pak triple restored from the scratchpad backup, `retoc verify` confirmed clean. Facial hair on Barbies is back to broken-but-safe (silently unbuilt, same as before this whole section) rather than crashing.

**Leading theory, NOT yet confirmed or re-attempted**: the `Piece7_Merged_*` naming strongly suggests those 5(+2) array slots expect a genuinely DIFFERENT class than the plain `R5CompositeMeshParams` used for the other 9 -- likely a "merged" params type that combines Beard+Mustache+Whiskers into one build step with its own extra fields the composite builder reads unconditionally. `rewrite_fullslots_facial_imports.py` forced `ClassName="R5CompositeMeshParams"` uniformly on all 5 replacements -- plausibly a type/cast mismatch that resolves fine on a plain read but crashes once the composite build actually touches merge-specific fields that don't exist on a plain params object. The original hollow `UnknownExport` placeholder apparently gets skipped gracefully by the builder; a real object of the WRONG class does not. **Do not re-attempt without first determining the real expected class for these slots** -- check whether a genuine, non-hollow "Merged"-style asset exists elsewhere in the game to confirm the correct class, or inspect the group's own reflection data for the array element's declared type, before writing anything again. The raw-chunk PATCH TECHNIQUE itself is not implicated -- the revert used the identical unpack-raw/pack-raw pipeline and worked cleanly; the bug is in what was written into the 2 chunks, not the packaging mechanism, which remains valid for future fixes.

**Root cause CONFIRMED and RE-FIXED, same day.** Extracted 2 real native facial-hair assets straight from the base game (using the game's own real `global.utoc` as context this time, not the jmap-synthesized stand-in -- fully resolvable, no `Unknown` garbage): `DA_Hero_CompositeMesh_Group_Facial_Sparse_01_M` and `DA_Hero_CompositeMesh_Group_Eyebrows_01_Male`. Both are class `R5CompositeMeshGroup` -- the SAME class as the outer Barbie Group asset itself -- each wrapping exactly one real `R5CompositeMeshParams` piece plus a GameplayTag. Confirms the theory exactly: these 5(+2) slots hold a Group WRAPPER, not a bare Params piece the way positions 0-8/14 do. The crash was a genuine type mismatch: the first attempt forced `ClassName="R5CompositeMeshParams"` and pointed straight at the raw piece asset; the composite builder evidently casts/reads these specific array positions AS a Group, and dereferencing Group-only fields on an object actually laid out as a plain Params piece is what crashed. A real object of the WRONG class is worse than the original hollow placeholder, which the builder apparently skips gracefully.

**Re-fixed**: `rewrite_fullslots_facial_imports.py` updated to point these slots at the REAL native GROUP WRAPPER assets instead -- `DA_Hero_CompositeMesh_Group_Facial_Sparse_01_{B,M,W}` (Beard/Mustache/Whiskers), `DA_Hero_CompositeMesh_Group_Eyebrows_01_{Male,Female}`, `DA_Hero_CompositeMesh_Group_Hairs_Afro_01` (Hairs-dup) -- with `ClassName="R5CompositeMeshGroup"`, never touching/re-authoring the wrapper assets' own internals (same redirect-only strategy that worked for the original 9 slots). Re-ran on the local source files; a full array dump before repackaging confirmed positions 0-8/14 (the already-working slots) were untouched. Rebuilt via the identical raw-chunk-patch technique against the already-reverted `SplitFacial-Windows`, `retoc verify` clean, deployed (game closed, the previous pak backed up again first, in a second dated scratchpad folder). **THIRD CRASH -- the "confirmed" class fix ALSO crashed live.** Reverted again the same way (game closed, backup restored, `retoc verify` clean). RedFalcon then recalled, correctly, that this exact feature was already attempted once before, back on 2026-09-03 (§19q): a proper Editor-authored sex-keyed `CompositeMeshGroupsByBodySex` map, verified byte-correct via UAssetAPI reload, but it built ZERO facial-hair pieces live and the root cause was never found. **Three independent techniques now -- an Editor-authored map, a raw-piece import redirect, and a Group-wrapper import redirect -- have all failed on this exact feature.** That's strong evidence the Custom outfit's own Group asset has a genuine structural block specific to facial hair, not a "picked the wrong asset" problem, and not something worth a 4th data-level guess.

**PIVOTED to a fundamentally different, non-data-editing approach.** `Spawner.AddBarbieFacialHair` / `lbtestbarbiefacial [M|F]` (spawner.lua, 2026-09-12) builds fresh `SkeletalMeshComponent`s directly on an already-spawned actor at the Lua/runtime layer -- the exact same proven-safe recipe `Spawner.TestAddMissingClothingSlot`/`lbtestaddslot` already uses for missing CLOTHING slots (`AddComponentByClass` -> `SetSkeletalMeshAsset` -> `K2_AttachToComponent` -> `SetLeaderPoseComponent`, leader-pose skinning, no socket). This never touches the cooked pak or the Group asset at all, so it carries none of the crash risk the last 2 attempts did -- worst case is a Lua-side `pcall` failure, not a native crash. Uses real raw SkeletalMesh paths from the same "Sparse" family `Config.CUSTOM_FACIAL` already curates (Eyebrows for both sexes, Beard/Mustache/Whiskers Male-only, matching §19q's own "no female-equivalent asset exists anywhere" finding). Deployed Lua-only (`lbreload`-able, no restart needed). **Test via console first on an already-spawned Barbie, before wiring it into the automatic spawn flow** -- given 3 failed attempts on the data side, don't assume this works untested either, but it's categorically lower-risk since nothing here can corrupt a pak or crash the game natively.

**FOURTH CRASH -- but real progress this time: the crash-dump triage tool pinpointed the exact call.** `lbtestbarbiefacial` crashed live too, first try. Ran `parse_minidump.py` (this project's own existing minidump parser, see `feedback_minidump_crash_triage`) on the fresh dump: the crash lands INSIDE `UE4SS.dll` itself (`EXCEPTION_ACCESS_VIOLATION`), not the game engine -- confirming this is a UE4SS argument-marshaling bug, not a data/asset problem. Rather than re-testing live to narrow it down further, cross-referenced the `Spawner.RefLog` breadcrumb-before-every-risky-call trail (survives a crash by design) -- it got past `AddComponentByClass` and mesh assignment cleanly, then crashed exactly at `K2_AttachToComponent`, before the next breadcrumb ever printed.

Root cause, found by comparing against `Spawner.AttachShield` (a long-proven-stable feature in the same file): `K2_AttachToComponent`'s socket-name parameter needs to be wrapped `FName(...)`, not passed as a bare Lua string -- a genuine type mismatch in UE4SS's own reflection-based argument marshaling. Both this new function AND the original `lbtestaddslot` (`Spawner.TestAddMissingClothingSlot`, built 2026-08-28) had been passing a bare `""` the whole time -- `lbtestaddslot` had apparently never actually been exercised live end-to-end before now, so this exact latent bug sat undiscovered since August. **Fixed both call sites** to `FName("")`. New standalone memory `feedback_ue4ss_fname_socket_param` records this as a general UE4SS Lua-binding gotcha worth checking on any future `K2_AttachToComponent`-style call, not something specific to this feature. Deployed (Lua-only, `lbreload`-able).

**Retested -- no crash this time, but "the hair does not attach to his face."** Added proper error-text logging + a `GetLeaderPoseComponent()` readback check (both missing from the first version -- a real gap in the diagnostics, not just the fix). Real error surfaced: `SetLeaderPoseComponent(body)` failed every time with `"UFunction expected 3 parameters, received 1"`. This UE4SS build's binding requires ALL of a UFUNCTION's C++ parameters explicitly, even ones with C++ default values -- the real signature is `SetLeaderPoseComponent(NewLeaderBoneComponent, bFollowLeaderPoseOverride=true, bUpdateNumBones=false)`, 3 total. Fixed both this call and the identical bug in the original `lbtestaddslot` (same 1-arg call, same latent issue) to pass all 3/2 params explicitly. New memory `feedback_ue4ss_fname_socket_param` extended with this as a general lesson: don't trust a UE4SS Lua call to apply a UFUNCTION's C++ default parameter values -- pass everything explicitly, and always log a failed pcall's own error text rather than a bare boolean (that's what turned this into a one-line diagnosis instead of another blind guess). Deployed. **RedFalcon confirmed live: "that looks to have worked"** -- Eyebrows/Beard/Mustache/Whiskers now genuinely attach and follow the face on a spawned Barbie. `leaderPoseCallOk=true` in the log confirms the real fix; the same log line's own `verified=false` (this function's `GetLeaderPoseComponent()` readback check) is a false negative -- almost certainly the same "binding doesn't behave the way the C++ signature suggests" class of quirk as the two bugs just fixed, not a real problem, given the confirmed visual result. Not chased further since it's a diagnostic-only mismatch, not something blocking the feature.

**Final tally for this whole saga**: 3 failed attempts to fix this at the DATA level (an Editor-authored sex-keyed map, 2026-09-03; a raw-piece import redirect; a Group-wrapper import redirect) plus a 4th live crash and a 5th silent failure on the RUNTIME-level fix that ultimately worked -- both real UE4SS Lua-binding bugs (`K2_AttachToComponent` needing `FName`, `SetLeaderPoseComponent` needing all 3 params explicit) that had nothing to do with the Custom outfit's own data at all. `Spawner.AddBarbieFacialHair`/`lbtestbarbiefacial [M|F]` is the shipping mechanism.

**Wired into the automatic spawn flow same day** (RedFalcon: "yes add it to the flow"). `main.lua`'s `pollBarbieSpawnRequest` -- the handler for the Custom tab's "Spawn Custom" button -- now calls `Spawner.AddBarbieFacialHair(actor, sex, say)` inside the SAME `onSpawned` callback `StartPlacementPreview` already uses, passing the request's own already-known `sex` directly rather than relying on the function's skin-material-name auto-detect (more reliable, since the real answer is already in hand at that point). Runs through the same `pollForBuildThenOnSpawned` build-completion gate as placement (see the MortarMan-floating fix, same session) -- guaranteed to run only after the composite build has actually finished. Every new Barbie now gets facial hair automatically: Eyebrows for both sexes, Beard/Mustache/Whiskers for Male.

**New tools this session**: `lbdumpheadgearsuspend`, `lbdumpsuspend <path>`, `lbdumptorsosuspend` (spawner.lua, all "PURE READ" dev commands, `registerCmdInfo`'d in main.lua); `Tools/UAssetAPI/write_composite_piece.py` (construct-from-scratch capability for `R5CompositeMeshParams`-shaped content, reusable beyond this specific fix), `Tools/UAssetAPI/rewrite_fullslots_imports.py` (blind import-table rewrite, 9-slot pattern), `Tools/UAssetAPI/add_hands_slot.py` (array-growing pattern), `Content/Python/batch_fill_fullslots.py` (the SUPERSEDED local-placeholder population pass, kept for the record even though it doesn't affect the live game).

### 19ae. The Custom tab's clothing TREE is replaced with per-slot name dropdowns, driven entirely by a spreadsheet; real `SlotsToSuspend` data finally closes the headgear/hair interaction gap in both directions (2026-09-14)

RedFalcon: "I want to do clothes, but not in a tree this time. I want each body category in it's own dropdown using the spreadsheet you exported for me." Source: `Other/Hair_And_Clothes_Export.xlsx`, two sheets -- "Clothes Adjusted" (his own hand-validated per-body-type pass over every real clothing item, one row each with Body Part/Name/Friendly Name/Set Name/Availability/Male mesh/Female mesh/Unisex mesh/Source asset) and "Clothing Outfits" (the same shape, grouped by Set Name into 43 candidate outfits). Design locked in up front via a short Q&A: locked ("Only with Unlock") items are HIDDEN from the dropdown entirely until `lbunlockclothes` runs, not shown greyed-out; picking an Outfit only SETS the slots it defines and never clears anything else; an Outfit missing Feet+Torso+Legs is dropped from the list entirely (36/43 qualified -- "Character Underwear" itself was one of the 7 dropped, missing Feet); no artificial Torso/Waist mutual-exclusion is added on the Lua side at all, whatever a given piece's own native `SlotsToSuspend` does is what happens (a real counter-example of both coexisting already existed in this project's own notes -- an Underwear-classified Torso doesn't suspend Waist the way a regular-armor Torso does).

**Data pipeline, built as two sibling generator scripts rather than hand-transcribed** (322 items + 43 candidate outfits was too much to type by hand reliably). `gen_clothes_lua.py` (LivingBase mod folder, mirrors the existing `gen_socketitems_lua.py` convention) emits `Config.CLOTHES_ITEMS` -- one flat list per real body part (Torso/Legs/Waist/Hands/Feets/Headgear/Cape, matching `BODY_PART_ENUM_BY_NAME`'s own spelling), alphabetized, each row keeping the RAW availability string rather than pre-resolving it (mirrors `Config.HAIR_CATEGORY_ITEMS`' own convention) -- and `Config.CLOTHES_OUTFITS` (only the 36 qualifying sets, a `pieces` map of bodyPart->friendlyName, no mesh data duplicated). A second script, `gen_clothes_cpp.py`, reads the SAME workbook and emits matching C++ `constexpr` arrays for CustomMenu.cpp, since the DLL has no way to read config.lua at runtime (same "paste once, keep in sync by hand" situation `kHairFriendlyNames`/`kClothColors` are already in).

Two real data quirks were found and fixed IN THE GENERATOR, not patched around downstream: (1) whitespace typos in the raw sheet -- "Mercenary Head  1" (double space, two DIFFERENT headgear pieces sharing what should be one displayed name after normalizing) and, more seriously, "Blackbeard Musketeer 1 " (a trailing space on a SET NAME) which would have silently split one 5-piece outfit into a phantom 1-piece "outfit" plus an incomplete 4-piece one -- fixed with a blanket `re.sub(r"\s+", " ", s).strip()` pass before any grouping happens; (2) the sheet's own "Source asset" column exports paths as `/Game/R5/Content/Gameplay/...` -- an Editor-project-relative spelling that live-FAILED `resolveAsset` on the very first headgear test -- confirmed against every other hardcoded DataAsset path already in this file (`TORSO_PIECES`/`HEADGEAR_PIECES` from §19ab/19aa) that the real in-game mount path is `/Game/Gameplay/...`, no `R5/Content` segment at all; fixed with a one-line `.replace("/Game/R5/Content/", "/Game/", 1)` in the generator. Two genuine same-slot friendly-name collisions (same display name, two different underlying meshes -- e.g. two Headgear pieces both legitimately called "Mercenary Head 1") were disambiguated with a generic `(2)` counter suffix rather than guessing at a semantic label.

**Lua application layer built entirely on top of already-proven primitives** -- no new write mechanism invented. `Spawner.SetBodyPartMesh`/`BODY_PART_ENUM_BY_NAME` (§19q/19r era) do all the actual mesh swapping. `Spawner.ApplyClothesItem(bodyPart, friendlyName, say)` resolves the sex-appropriate mesh via the exact same fallback chain `Spawner.ApplyHairCategoryMesh` already used for non-Hairs rows -- `isFemale and (femaleMesh or unisexMesh or maleMesh) or (maleMesh or unisexMesh or femaleMesh)` -- which for free implements "an item RedFalcon validated as working on both sexes but which only has one mesh populated in the sheet" transparently, with zero extra logic. Two gates were added the same day, both live-caught by RedFalcon testing: "Only with Unlock" items check the pre-existing `Config.CLOTHES_UNLOCK_ALL` flag (`lbunlockclothes`, §19n-era, not a new mechanism); and items the sheet marks as GENUINELY one-sex-only ("MALE"/"MALE ONLY"/"FEMALE ONLY" -- always start with exactly those words in this data, "BOTH"/"Both (...)" never do) now substitute the real underwear item for that slot instead of forcing the wrong-sex mesh on -- "Character Underwear Legs" (a real BOTH-sex asset pair) for Legs always, "Character Underwear Torso" (FEMALE ONLY -- there is genuinely no male-Torso-underwear asset anywhere in this game's own content) for Torso only when the target actually is female; every other mismatch (including a female-only Torso item aimed at a male target) just skips with a clear log line, no fallback exists for it.

`Spawner.RemoveClothesItem` had to solve a real modesty problem live: `SetBodyPartMesh` can only ever SWAP an EXISTING `BuildedCompositeMeshes` entry, there is no "nothing equipped" mesh asset anywhere in this game's content to swap to -- so for 5 of 7 slots, removal is a plain `SetVisibility(false)`. RedFalcon caught the gap immediately after the first version shipped: "we have to remember to put underwear on them when legs are removed and the top on women when the torso is removed" -- a bare-hidden Legs or female Torso slot showed an incomplete/ugly underlying body layer that the other 5 slots don't have (nothing weird-looking about bare hands/feet/head/waist/cape). Legs now ALWAYS substitutes "Character Underwear Legs" on removal; Torso substitutes "Character Underwear Torso" for a female target, or just hides (bare chest) for male, matching this project's own long-established "assign underwear when one exists for that sex, otherwise bare is fine" convention (§19p era). `Spawner.ApplyClothesOutfit`/`Spawner.RemoveAllClothes` are thin loops over the 7 slots that inherit all of the above for free.

`Spawner.TestReadClothesStyles` is Read Current's item-detection half (colors were already covered by the pre-existing `Config.CUSTOM_TAB_CLOTH_CATEGORIES` read, §19-era cloth-color panel) -- reverse-matches each slot's current mesh name against `Config.CLOTHES_ITEMS`, same normalized-name-matching shape `Spawner.TestReadHairStyles` already used. RedFalcon asked directly, mid-build: **"if an item is hidden but not removed, will it be detected? If so we should treat it in the detection and dropdowns as if it isnt there"** -- it was already built checking `target:IsVisible()` and treating hidden as "not there" from the start; the identical fix was then retrofitted onto `Spawner.TestReadHairStyles` too, once the new Hair "(Remove)" feature (below) made the same gap real there for the first time.

**Headgear <-> hair interaction, the hardest part of this feature, found live in BOTH directions.** First: "i removed the hat and she kept her hat hair" (removing Headgear left a flattened/hat-fitted hairstyle mesh with nothing left covering it). Fixed, then immediately: "assigning headgear also needs to behave correctly with the hair" -- the REVERSE gap, picking a NEW hat never re-fit the hair either. Root cause both times: `Spawner.ApplyHairCategoryMesh`'s pre-existing "hat-variant preservation" logic (built earlier this project, see the Undercut-naming-bug era notes) only ever GUESSES the wanted category from whatever variant the CURRENT hair mesh happens to have, and only runs when applying a NEW hairstyle choice -- it was never wired to react to a headgear change in either direction, and structurally can't distinguish "should hide entirely" (a fuller helmet-style piece) from "no headgear at all" anyway.

The fix, `applyHeadgearHairFit(actor, sourceAssetPath, say)`, reads the headgear's own REAL `SlotsToSuspend` property for the Hairs ordinal (3) -- the SAME decode `lbdumpsuspend`/`DumpHeadgearSuspend` (this section's own predecessor, §19ab/19aa) already used, just applied LIVE against whatever the target is actually wearing instead of a static hardcoded roster, made possible because `sourceAsset` now rides along on every `Config.CLOTHES_ITEMS` row. `SuspendHat`/`SuspendBandana`/`SuspendHeadband` fit the current hairstyle to that real variant asset; `Full`/`Medium`/`Light` hide the hair component outright; `None`/a nil sourceAssetPath (headgear removed) ensures the hair is VISIBLE again and reverts it to its own Default (no-hat) variant. Wired into both directions: `ApplyClothesItem`'s Headgear branch calls it with the NEW item's own `sourceAsset`; a new `Spawner.SyncHairToCurrentHeadgear(actor, say)` (reverse-looks-up whatever's CURRENTLY worn in the Headgear slot, then calls `applyHeadgearHairFit` with THAT item's `sourceAsset`) runs after every hairstyle APPLY too. This fully supersedes the old `hasHeadgearEquipped` heuristic (removed, dead code) -- that function's own header had explained back when it was written that a precise per-hat check "isn't cheaply available here" because nothing linked a live composite element back to its own backing DataAsset; `sourceAsset` closes exactly that gap.

**A real pre-existing bug, unrelated to this feature, found and fixed along the way**: `hairVariantPathCandidates`'s `gsub("_Default_", "_" .. tok .. "_", 1)` -- the trailing `1` caps it to the FIRST match only. Every real asset path in this game is `Package/Path.AssetName`, with the SAME "_Default_"-bearing name repeated in BOTH halves (e.g. `.../SK_Hair_ShortBob_Default_Female.SK_Hair_ShortBob_Default_Female`) -- capping at 1 replacement fixed only the package half and left the asset-name half still literally saying "_Default_", producing a mismatched, nonexistent combined path that could never resolve. This had been silently breaking hairstyle-switching's OWN pre-existing hat-preservation logic since the day it was written (any time it tried to preserve a real Hat/Bandana/Headband variant while switching styles, it silently fell back to Default instead) -- not a new bug introduced by this session's work, just newly SURFACED by it, since nothing had exercised that exact code path enough to notice before. Fixed by dropping the count limit so `gsub` replaces both occurrences. Confirmed live afterward that some hairstyles genuinely have no Hat/Bandana/Headband variant asset at all in this game's content -- correctly falls back to Default in that case, RedFalcon: "i'm fine with it doing what it does today."

**CustomMenu.cpp UI, built in one pass only after the entire Lua backend above was proven out via 5 new console commands** (`lbclothesitem`/`lbclothesremove`/`lbclothesoutfit`/`lbclothesremoveall`/`lbreadclothes`) -- same "prove the Lua layer before touching C++" discipline this whole project has followed since the Hair section. 8 rows: a new standalone "Outfit" row (no color swatches at all, RedFalcon: "an additional 'Outfits' type with no colors... similar to the facial hair sets") plus the 7 pre-existing Torso/Legs/Waist/Hands/Feet/Hat/Cape rows, each gaining a name-dropdown wedged between its label and its already-existing color swatches. The existing `Category` struct grew `luaBodyPart`/`items`/`itemCount` fields. A new `g_clothesUnlocked` bool mirrors `Config.CLOTHES_UNLOCK_ALL` LIVE via a fresh Lua-writes/C++-reads bridge file (`clothes_unlock_state.txt`, written by `Spawner.ToggleClothesUnlock` on every `lbunlockclothes` toggle, polled every frame the same cheap-ifstream way `pollReadCurrentResult` already is) -- RedFalcon: "update the dropdowns when that command is run." Locked items are skipped from the `Selectable` loop entirely while locked (never drawn at all, not shown-disabled).

Every dropdown reserves index 0 as a literal `"(Remove)"` entry (`"(Remove All)"` for Outfit) -- clicking it forwards that sentinel string verbatim over the existing request-file bridge (main.lua's pollers already special-case the exact string) but resets the LOCAL C++ selection state back to -1 rather than persisting "(Remove)" as a shown value, per RedFalcon: "when a slot has no item, set it back to 'Select One' same with any of the removes" (the placeholder text itself was also renamed from the old "(select)" to "Select One" for the Clothes dropdowns specifically -- Hair/Physique keep their own existing "(select)"). Since a single item pick can silently substitute underwear (the sex-mismatch fallback above) and an Outfit pick touches several slots at once, BOTH now fire `requestReadCurrent()` right after their own write request -- reusing the EXISTING manual "Read Current" plumbing rather than duplicating `Config.CLOTHES_OUTFITS`' own piece-list in C++ just to guess locally. This required reordering main.lua's poll loop (`pollCustomClothesItemRequest`/`pollCustomClothesOutfitRequest` now run BEFORE `pollCustomColorReadRequest` in the same 400ms tick) so the apply actually lands before the read captures it -- both still run inside the same `ExecuteInGameThread`-queued tick, so ordering the POLL calls is sufficient regardless of whether that queue drains immediately or on the next frame. `pollReadCurrentResult` now resets every one of the 7 `g_clothesSelected[]` slots AND Hairs/Beard/Mustache/Whiskers' own `selectedName` (deliberately NOT Sets or Outfit -- neither ever receives its own read-back line, so resetting them on every read would erase a still-valid manual pick for no reason) to -1 BEFORE parsing each response, so a slot with nothing detected -- including a HIDDEN one, per the detection fix above -- correctly reverts to the placeholder instead of showing a stale prior selection.

Cloth colors were made realtime in the same pass, RedFalcon: "i also want clothing color to be real time... You can remove both the reset and apply buttons." A new `g_lastWrittenClothColor[7][3]` change-tracker (identical shape to Hair's own pre-existing `lastWrittenColor`) fires the existing `writeColorRequest()` (which already sends the FULL current `g_selected` state every call, so resending it for a single slot's change is safe/idempotent for every other already-applied row) immediately on any swatch change; the "Clear Selections" and "Apply" buttons, and the now-unused `anySelected` bookkeeping, were deleted outright.

**Hair/facial-hair Remove, added same session**, RedFalcon: "can we add remove to each of the hair and facial hair slots." `"(Remove)"` added at index 0 of `kHairFriendlyNames`/`kBeardFriendlyNames`/`kMustacheFriendlyNames`/`kWhiskersFriendlyNames` -- deliberately NOT to `kHairSetFriendlyNames`, since "Sets" is a multi-slot convenience applier rather than a real slot of its own. `Spawner.ApplyHairCategoryMesh` intercepts `friendlyName == "(Remove)"` immediately after resolving the target and calls the already-proven `Spawner.RemoveHairOnActor` (§19o/19p era -- hide + `SetHiddenInGame` + zero collision response, re-dressable afterward, never destroys the mesh reference) instead of doing any mesh lookup at all. One real name-mapping needed: `categoryKey` "Hairs" maps to `RemoveHairOnActor`'s own slot name "Hair" (singular, matches its `/Hair/`-substring classification) -- Beard/Mustache/Whiskers already match `facialSlotOf`'s own return strings exactly, no translation needed. `DrawHairRow` on the C++ side compares by STRING (`std::strcmp(name, "(Remove)")`), never by index 0, specifically because "Sets" has no such entry at all and using a bare index check would have mis-fired on whatever real style happens to sort first alphabetically in that row.

**Files touched**: new `Other/Hair_And_Clothes_Export.xlsx` (RedFalcon's own), new `gen_clothes_lua.py`/`gen_clothes_cpp.py` (LivingBase mod folder, alongside the existing `gen_socketitems_lua.py`); `config.lua` (`Config.CLOTHES_ITEMS`/`Config.CLOTHES_OUTFITS`); `spawner.lua` (`ApplyClothesItem`/`RemoveClothesItem`/`ApplyClothesOutfit`/`RemoveAllClothes`/`TestReadClothesStyles`/`applyHeadgearHairFit`/`SyncHairToCurrentHeadgear`/the `hairVariantPathCandidates` gsub fix/`hasHeadgearEquipped` removal/the `ApplyHairCategoryMesh` Remove-intercept/the `TestReadHairStyles` visibility fix/`ToggleClothesUnlock`'s new state-file write); `main.lua` (5 new console commands, `pollCustomClothesItemRequest`/`pollCustomClothesOutfitRequest`, the poll-loop reorder, the `CLOTHESITEM:` Read Current line); `CustomMenu.cpp` (the full Clothes dropdown UI, realtime cloth colors, Hair section Remove entries, the unlock-state poll). Full detail in [[project_livingbase_spawn_menu]] memory.

### 19af. "Belts and Straps" gets a full Custom-tab GUI on top of the existing `lbtestsocketitems`/`SocketItems.xlsx` line -- Set/Belt/Sling/Strap/Frog/Lantern, a manual per-socket Accessories grid, live detection, and cross-piece dependency gating (2026-09-15)

RedFalcon supplied a mockup (bottom of the Custom tab) and a new "Belts and Straps" tab on `Other/SocketItems.xlsx` (Type/Friendly Name/Male mesh/Female mesh -- the real Belt/Sling/Strap/Frog MESH pieces, distinct from this file's own `soc_*`/weapon ACCESSORY sockets), plus a new "Friendly Name" column on the Sockets/Items/Weapons tabs (Items also gained "Test Command", ignored). `gen_socketitems_lua.py` updated to match the shifted columns and to emit a new `Config.BELTSTRAPS_PIECES` table alongside the existing `SOCKETITEMS_*` ones. One data quirk carried straight through with zero special-case code: the "Shaman Necklace" row (Type=Sling) has no male mesh at all -- RedFalcon: "the senkamati neck item can be applied to either sex, even though it is female only mesh" -- the mesh-pick fallback chain (`maleMesh and femaleMesh and (sex pick) or (femaleMesh or maleMesh)`) already falls through to whichever field exists.

**Independence, not the old cross-requirement.** Mid-build, RedFalcon reversed the project's own long-standing §19s/19t rule: "let's also let the belt and strap choices work independent of each other. no forcing belts with straps, etc. Just basic replacement." `Spawner.ApplyBeltStrapPiece(pieceType, friendlyName, say)` is a plain one-slot swap/hide via the SAME `BuildedCompositeMeshes` mechanism `SetBodyPartMesh`/`RemoveClothesItem` already use -- no dependency on any other slot's state. `Spawner.ApplyBeltStrapSet(setFriendlyName, say)` is a separate convenience that still applies Belt N + Sling N + Strap N together (Frog has no Set concept, matching the spreadsheet); the independence rule governs the 4 individual dropdowns, not this bulk applier.

**New Lua** (`spawner.lua`, all inside one `do...end` block right after `TestDumpCompositeAsset`/`BODY_PART_ENUM_BY_NAME` -- see the 200-local-ceiling note below for why): `findBeltStrapComponent` (shared `BuildedCompositeMeshes` walk), `clearAccessoriesForRemovedPiece`, `Spawner.ApplyBeltStrapPiece`/`ApplyBeltStrapSet`, `Spawner.ToggleBeltLantern` (thin wrapper over the existing `TestAttachLanternSet`/`TestClearLanternSet`, `useSelf=false`), `Spawner.RemoveSocketAttachment` (destroys whatever's on ONE exact socket -- narrower than the pre-existing `RemoveAllSocketAttachments`, needed so one dropdown's "None" never disturbs another socket), `Spawner.ClearSocketAccessories` (same fragment-matched sweep, explicitly skips `soc_lantern*` so Clear never disturbs an active Lantern), `Spawner.RandomizeSocketAccessories`, `Spawner.ApplySocketItemManual`, `Spawner.ApplyWeaponSlotManual`, `Spawner.TestReadBeltStrapStyles`.

**The Senkamati-necklace socket exception.** RedFalcon: "The senkamati necklace... If that is in place, sockets related to that slot should not be added" (to a random roll). The 8 `soc_Sling*` sockets are physically part of the SLING MESH -- with the necklace occupying that body-part slot instead of a real sling model, those sockets have nothing to render on. `Spawner.TestGenerateSocketItems` (the engine behind both the console `lbtestsocketitems` and the new "Randomize Accessories" button) gained an optional 2nd param, a `{socketName=true,...}` exclude-set, filtered out of both the soc-item and weapon socket pools for that one call; every existing caller passing nothing behaves exactly as before. `Spawner.RandomizeSocketAccessories` detects the necklace by reading the Sling slot's own live mesh name and checking for `"Senkamati_Witch_Feather_01_Neck"`, building the exclude-set only when it matches.

**Manual per-socket placement deliberately ignores the randomizer's own eligibility list.** RedFalcon: "For Belt, Sling, and strap ones i want all items in the Items tab available, ignoring the randomization limitations." `Spawner.ApplySocketItemManual` looks up `Config.SOCKETITEMS_ITEMS` by friendly name only, never consulting that row's own `sockets` column (that restriction only matters for the random roll). The 4 combined weapon dropdowns (Sheath/Back Weapon/Left Pistol/Right Pistol) needed a real resolver instead: RedFalcon: "use the Location column to determine the list, and pistol can go in either pistol dropdown." Sheath and Back each genuinely combine SEVERAL real sockets behind one dropdown (only one weapon can occupy any of them at once, per the Sockets tab's own "do not use with other Back Sockets/lSockets" note) -- `Spawner.ApplyWeaponSlotManual` clears the WHOLE group first, then resolves which one specific real socket a picked weapon belongs on via that row's own `sockets` list; the two Pistol dropdowns are each just their own fixed single socket, sharing one item pool.

**Cross-piece dependency gating and cascading removal**, added after the first live look at the built GUI. RedFalcon: "the different accessory areas should be unavailable if that strap is not available. ie: if there is no strap then grey out all strap dropdowns. Pistols is dependant on belt and sheath is dependant on frog. back is fine no matter what." (A "sword frog" is the leather loop a sheathed blade actually hangs from -- hence Sheath depending on Frog, not Belt.) `Spawner.TestReadBeltStrapStyles` reads live visibility + current friendly name per Belt/Sling/Strap/Frog and feeds two new Read Current line types (`BELTVISIBLE:<Type>:0|1`, `BELTPIECE:<Type>:<name>`) that both sync the 4 dropdowns and drive real `ImGui::BeginDisabled` gating on the Accessories grid. RedFalcon, same message: "if a belt or strap is removed, any associated accessories should also be removed" -- `clearAccessoriesForRemovedPiece(pieceType, say)` (called from `ApplyBeltStrapPiece`'s own "None" branch) clears every real `soc_*` socket tagged with that piece type in `Config.SOCKETITEMS_SOCKETS`, plus the ONE weapon dependency the gating already encodes (Belt removal also clears both Pistol holster sockets; Frog removal also clears both Sheath sockets) -- Back Weapon is untouched by any piece removal, matching "back is fine no matter what." And: "I'd like the belts and straps to be detected like the other stuff" -- every Belt/Sling/Strap/Frog/Set write in the GUI (a combo pick or the red X) now also fires `requestReadCurrent()` immediately after, same convention `DrawClothesOutfitRow` already established, rather than the GUI guessing its own state locally.

**CustomMenu.cpp layout**, iterated twice from the first mockup. Final shape: a Set dropdown (+ red X) and a Lantern checkbox on one row; a label+X row for Belt/Sling/Strap/Frog immediately followed by a dropdown row lined up underneath, all 4 columns the SAME fixed width via plain `ImGui::SameLine(i * kPieceColW)` positioning rather than `ImGui::Columns()` -- the classic Columns API silently stretches its own LAST column to fill the rest of the content region regardless of any `SetColumnWidth` call on it, which is exactly what made the first version look imbalanced ("can we make the belt section fit to all the same length, so it doesn't look so imbalanced"); a "Randomize Accessories" button + its own red X (`ClearSocketAccessories`); a closed-by-default "Accessories" `CollapsingHeader` with a 4-column grid (Belt 1-7/Sling 1-8/Strap 1-9/4 combined weapon slots, STILL built with `ImGui::Columns()` -- RedFalcon: "Accessories is fine as is, its a lot to pull", left alone even though it likely has the same last-column quirk) where each dropdown defaults to that socket's own friendly name until picked, gated per-column/per-row by the visibility flags above; and a closed-by-default "Accessory Location Cheat Sheet" placeholder header (a real reference image is still pending from RedFalcon, no static-image asset pipeline exists in this ImGui overlay yet). One real ID-collision bug found and fixed in the grid: `kBeltSocketRows[0]` ("Belt 1") and `kStrapSocketRows[3]` ("Strap 4") share the SAME real socket name (`soc_Strap01F`, a genuine data quirk -- one physical socket some Belt pieces reuse for their own bundled strap sub-entry, not a bug) -- `ImGui::PushID(r.socket)` collided between the two columns; fixed with a `(column*100+row)` composite int ID instead, unique regardless of any two rows sharing a real socket name.

**A recurring Lua gotcha, hit twice this session** (also see [[feedback_lua_forward_reference_check]] for the sibling issue this is NOT): both `spawner.lua` and `main.lua` sit right at Lua's hard 200-local ceiling ("too many local variables (limit is 200) in main function") -- every bare top-level `local` in a chunk permanently occupies one of those 200 slots for the rest of the file, since main-chunk locals never go out of scope, so adding even 2-3 new top-level locals to either file can break the ENTIRE file from loading. Fixed both times without deleting any functionality: wrap a new section in `do ... end` (locals declared inside free their slot at the closing `end`; functions defined inside as `Table.field = function() ... end` keep working afterward as closures/upvalues, since only the LEXICAL name goes out of scope, not the value) or pack several related helper functions as fields on ONE new table (`local T = {}; T.thing = function() ... end`) so only the table itself costs a slot. A companion C++ gotcha: `kBeltNames`/etc and the belt-piece selected/visible state variables needed moving UP the file (next to `kEyeColors`/`g_hasDetected` respectively), since `pollReadCurrentResult`'s new parsing sits well above `DrawBeltsAndStraps`' own section and C++ namespace-scope names must be declared before use (no hoisting, unlike the functions themselves).

**Files touched**: `Other/SocketItems.xlsx` (new "Belts and Straps" tab, new "Friendly Name" columns); `gen_socketitems_lua.py` (column layout + new `Config.BELTSTRAPS_PIECES` emission); `config.lua` (regenerated `SOCKETITEMS_*` + new `BELTSTRAPS_PIECES` block); `spawner.lua` (all the new functions above, plus `TestGenerateSocketItems`'s new optional `excludeSockets` param); `main.lua` (6 new request-file bridges packed onto one `BeltStrapPolls` table for the same 200-local reason, 2 new Read Current line types); `CustomMenu.cpp` (the full section, ~2400 new lines). Full blow-by-blow (including the mockup-iteration history) in [[project_livingbase_spawn_menu]] and [[project_livingbase_socket_items]] memory.

### 19ag. A "Poses and Actions" windowshade -- a Tools-tab-style tree scoped to just the Poses branch, a live current-pose readout, and the AnimationData vs. AnimSingleNodeInstance distinction that made the readout wrong at first (2026-09-16)

RedFalcon: "let's bring over the poses. At the bottom make a 'Poses and Actions' windowshade... a similar tree view to the tools, but have it contain only everything under the poses branch." `SpawnMenu.cpp`'s existing tree (built from `spawn_menu.ini`, itself generated from `Config.CUSTOM_POSES` by `spawnmenu_manifest.lua`) already parses the WHOLE roster into a private `MenuNode` tree; rather than re-parse `spawn_menu.ini` a second time in `CustomMenu.cpp`, `SpawnMenu.hpp` gained a new public, ImGui-agnostic `PoseNode` struct + `GetPosesTree()` (a plain recursive copy of the "Custom > Poses" subtree, rebuilt every `Reload()`) and `ApplyPoseByIndex(int)` (the same `"REPLACE:CUSTOM_POSES:index"` request write the tree's own leaf click already made) -- one source of truth, no new Lua needed for the "+"-per-leaf apply button. The Tools tab's own "Custom" branch (Poses/Skin Tones/Hair/Clothes) was then hidden from that tree entirely (RedFalcon: "now that this step is done, the entire Custom branch of the tools tree is no longer needed") -- the underlying `spawn_menu.ini` generation was deliberately left untouched, since `GetPosesTree()` still reads straight out of the same parsed data regardless of whether it's drawn there.

**Reading back the CURRENT pose turned out to need two real fixes, not one.** First attempt read `mesh.AnimationData["AnimToPlay"]` (the same struct-drilling recipe an earlier probe command already proved safe -- see item 62-era notes) -- CONFIRMED WRONG live: RedFalcon applied a different pose, then immediately re-probed the SAME actor, and `AnimationData.AnimToPlay` still reported the ORIGINAL, un-posed clip while a fresh probe of `AnimSingleNodeInstance`'s own `CurrentAsset` property showed the correct, just-applied one. **`AnimationData` is evidently only the construction-time seed value and is never kept in sync by a runtime pose change** -- `CurrentAsset` on the live `AnimSingleNodeInstance` is the actual property driving playback, and (unlike the struct-valued `AnimationData`) is safely readable via a plain top-level bracket-index, since it's a genuine top-level UObject-reference property on the instance itself, the same safe class as `mesh.AnimClass`. Second fix, from a live probe dump RedFalcon ran independently: on a target the fix ABOVE still reported "BotC Merchant" for what looked like a generic idle stance -- turned out to be a correct match (the underlying clip genuinely is the one Poses.xlsx's own row happens to be named after, sourced from a native BotC Merchant NPC originally), not a bug, but RedFalcon asked for the readout to be more useful for CATALOGING unknown poses regardless: if `CurrentAsset` doesn't exist at all (a BlueprintMode-driven pawn, the vast majority of native NPCs) OR resolves to a clip with no matching `Config.CUSTOM_POSES` row, fall back to `AnimationData.AnimToPlay` (still useful as a secondary source) and, failing a catalog match either way, show the RAW clip name instead of "Unknown" -- "Unknown" is now reserved for "no clip readable from either source at all."

**Files touched**: `SpawnMenu.hpp`/`.cpp` (new `PoseNode`/`GetPosesTree`/`ApplyPoseByIndex`, Custom-branch tree-draw filter); `CustomMenu.cpp` (new windowshade, tree-draw + "+"-apply, current-pose textbox + reset-to-sex-default X, Left/Right Hand placeholder dropdowns whose X already clears the real `ik_weapon_lSocket`/`ik_weapon_rSocket` sockets via the existing per-socket "None" pipeline); `spawner.lua` (`Spawner.TestReadCurrentPoseName`, both fix iterations).

### 19ah. "Save Customizations" -- a separate, explicit-save per-target cosmetic-state file, restored automatically alongside `persist.txt` on world load (2026-09-16)

RedFalcon: "how do we tie [Custom-tab edits] into the persist file to regenerate the changes... Separate files works for me as long as it doesn't overly impact latency" -- then, once the design took shape: "we could add a 'Save Customizations' button then they can fiddle all they want, but it isn't persisted until it's saved." That one steer collapsed what could have been a debounce-and-latency problem (auto-saving on every dropdown/swatch edit, the way `persist.txt`'s own un-debounced per-action rewrites already cause a documented rotate-hold crash risk) into a non-issue: the new `custom_state_<islandId>.txt` (same per-world-file convention `persist.txt` itself uses) is written ONLY on an explicit button click, never per-edit.

**Identity, settled by a clarification that simplified the whole design**: RedFalcon: "statues and walkers are placed by us though, most are just native to the game with some tweaks" -- meaning EVERY Custom-tab-editable target already has a `Spawner.spawned` entry with a resolved, restore-stable `instanceLabel` (see item 19/`NextInstanceLabel`'s own history). No new identity scheme was needed; a target with no such entry (a genuinely untouched native NPC, never placed via the Spawn Menu) is simply out of scope for saving -- nothing to key it by.

**The file format reuses the EXACT wire-format lines the Custom tab's own request handlers already read/write** (`COLOR:`, `CLOTHESITEM:`, `BELTPIECE:`, `POSE:`, etc.) -- `Spawner.ApplyClothesItem(bodyPartKey, friendlyName, say)` already takes the same two fields a `"CLOTHESITEM:Torso:Dogface Torso 1"` line carries, so no new serialization format needed inventing. `Spawner.BuildCustomStateLines(say)` is a new shared aggregator (spawner.lua) that assembles the SAME snapshot `pollCustomColorReadRequest`'s own Read Current cycle already builds, plus 3 categories Read Current itself never covered: socket accessories/weapon slots (both already had read functions, `Spawner.TestReadSocketAccessories`/new `TestReadWeaponSlots`, sharing one factored-out `sweepAttachedMeshes` by-socket component sweep), Lantern, and AI-toggle (two brand-new small reads, reusing an existing StateTree `IsRunning()` check for the latter). Lantern/AI-toggle lines are only emitted when they differ from the native default (RedFalcon: "if there is no change, there's no need to reference it") -- every other category already reflects the target's real current state regardless, matching Read Current's own existing behavior.

**Restore replays the saved lines through the EXACT SAME `Apply*` functions the live UI already calls**, via a small prefix-keyed dispatcher (`applyCustomStateLine`) -- since almost every one of those functions resolves its own target via `findNearestSpawnInFront`'s `Spawner.lockedTarget` bypass (not an explicit actor parameter), `Spawner.RestoreCustomState` just temporarily points the lock at the matched actor before replaying that block's lines, meaning **zero signature changes were needed on any existing Apply function**. Hooked into `main.lua`'s own restore chain by wrapping the `onComplete` callback `Spawner.RestoreFromPersist` already accepts (`afterRestore = function() Spawner.RestoreCustomState(); unlockIfCurrent() end`), rather than editing `RestoreFromPersist`'s own several internal `onComplete` call sites -- guarantees this runs exactly once per real completion regardless of which internal path that function took.

**Barbie auto-save on placement**, RedFalcon: "since they are new and stripped, the barbies currently spawn fully clothed. We would want to save their look on placement" -- NOT hooked into the Barbie spawn's own `onSpawned` callback (where facial hair/auto-detect USED to fire, moved away from earlier this same session, see item 19ae-era notes: "it is detecting info before it's stripped") but into `Spawner.ConfirmPlacement()`, the SAME later point the auto-detect done-file write already moved to -- the first point a Barbie's look is genuinely settled post-strip. A live crash (see 19ai below) later proved even THIS point needed its own 500ms settle delay before reading, since the strip sequence itself is a dense burst of mesh swaps immediately preceding it.

**Files touched**: `spawner.lua` (`custom_state_<islandId>.txt` read/write helpers packed onto one `CS` table for the 200-local reason -- see 19af's own note on that trap, recurring a 4th time here -- `Spawner.BuildCustomStateLines`, `Spawner.SaveCustomState`, `Spawner.RestoreCustomState`, `Spawner.RemoveCustomStateForLabel`, `Spawner.TestReadWeaponSlots`, `Spawner.TestReadLanternState`, `Spawner.TestReadAILogicState`); `main.lua` (`BeltStrapPolls.saveCustomizations`, the `afterRestore` restore-chain wrapper, the Barbie `ConfirmPlacement` auto-save hook); `CustomMenu.cpp` (new "Save Customizations" button, its own row above "Selected Target"/Read Current).

### 19ai. A multi-day crash-hunting saga during the SAME session Save Customizations shipped -- a dead diagnostic gate, a genuine O(4n)->O(n) fix, a 107-commit-stale vendored UE4SS build, and a real label-collision bug found along the way (2026-09-16)

Shipping 19ah surfaced a pre-existing, previously-only-suspected bug hard: "Read Current" (and, by extension, the new Save Customizations, which reuses its same read machinery) started crashing the game to desktop with real frequency mid-session. The investigation is recorded in full as 3t/3u above (the dead VERBOSE-gated breadcrumbs, the O(4n) belt/strap re-walk fix, and the eventual UE4SS version-staleness root cause + update) -- this entry is the narrative/chronology and the parts that don't belong in the general durable-knowledge section.

**Sequence, roughly**: (1) breadcrumbs added, appeared to show crashes landing in steps 8a-8c of an 8-step Read Current cycle -- later proven to be measuring nothing, since `log()` was silently VERBOSE-gated the whole time (3t); (2) once fixed, breadcrumbs consistently showed `Spawner.TestReadBeltStrapStyles` crashing, root-caused via per-array-index checkpoints to repeatedly re-walking the same `BuildedCompositeMeshes` array once per piece type -- collapsed to one walk (3u), a real algorithmic fix regardless of whether it fully explained the crash; (3) crashes kept recurring at what turned out (via several more minidumps) to be DIFFERENT addresses within the same native module -- prompted RedFalcon to test with a completely fresh `persist.txt` (zero pre-existing actors/customizations) specifically to rule out stale/legacy actor state as a factor -- it still crashed, ruling that out cleanly; (4) a Read Current staged-across-frames restructure (8 sequential `ExecuteInGameThread` calls instead of one ~100-native-call burst, paced via a new `Config.CUSTOM_READ_STEP_SPACING_MS`) and a widened `Config.RESTORE_POSTPROCESS_SPACING_MS` (400->900) were tried as density-reduction mitigations -- genuinely reasonable given the evidence at the time, but the crash still recurred inside the very FIRST staged step, before the new pacing could matter, which was the point the "different addresses, same module" pattern (heap corruption, not one bad line) became the better-fitting theory; (5) checking the vendored `RE-UE4SS` submodule's own git history found it 107 commits behind upstream with several matching-symptom fixes already merged there -- pulled, resynced submodules, rebuilt, redeployed; (6) one more crash after the update, this time inside the Barbie-placement auto-save (19ah) with zero of its own log output, immediately following the underwear-strip burst -- fixed with a 500ms settle delay before that specific read, the same "reading composite-mesh structure right after a dense mutation burst on that same actor" trigger already seen once before (an Outfit "Remove All" -> immediate Read Current crash, earlier in the same investigation); (7) inspecting `persist.txt` during this same testing surfaced the independent instance-label-collision bug recorded in 3u's own closing paragraph.

**Status at end of session**: crash frequency measurably reduced after the UE4SS update (multiple successful Read Current cycles that previously failed within 1-2 attempts), not fully eliminated -- treat as an ongoing watch item, not closed. `Other/UE4SS.dll.pre-update-backup` (session scratchpad) is the pre-update binary if a revert is ever needed.

### 19aj. A second Read Current crash recurrence, closed by deferring the read a tick rather than staging it; COLOR/HAIRCOLOR/EYECOLOR gain baked-default diffing so Save Customizations stops writing untouched native values (2026-09-16/17)

A fresh reproduction after 19ai's UE4SS update -- a belt-piece apply immediately followed by its own auto-triggered Read Current -- proved the earlier staged-across-frames restructure (19ai step 4) wasn't the real fix for THIS particular trigger shape (mutate-then-immediately-read on the same tick). `pollCustomColorReadRequest` was reverted back to one monolithic `ExecuteInGameThread` block (all 8 read steps sequential again, staging removed) -- the real fix went into `customColorPollLoop` instead: every mesh-mutating poll handler (`pollCustomColorRequest`, `pollCustomPhysiqueRequest`, `pollCustomSkinToneRequest`, `pollCustomHairRequest`, `pollCustomHairColorRequest`, `pollCustomClothesItemRequest`, `pollCustomClothesOutfitRequest`, `pollCustomMakeGhostRequest`, `pollCustomEyeRequest`, every `BeltStrapPolls` entry) now returns `true` on a successful dispatch, and the loop only calls `pollCustomColorReadRequest()` on a tick where NOTHING ALSO mutated -- the read request file is left untouched when deferred, so it just gets picked up cleanly on the next tick instead of racing a mutation on the same one. Simpler and more targeted than re-staging the read itself.

**Baked-default diffing extended to colors**, closing a real gap in 19ah's own Save Customizations: `TestReadCategoryColors`/`TestReadHairColors`/`TestReadEyeColor` already had a live-value fallback chain (session cache -> live CPD -> own persisted save) but no baseline to compare against, so genuinely untouched native colors were being written into `custom_state_<islandId>.txt` as if they were real edits. Each now also resolves the archetype's own baked `SavedCustomizationData` default (already read elsewhere this project, see the CPD-colors work) as a bottom display/diff-only tier, and returns it alongside the resolved value (`bakedC1/bakedC2/bakedC3` per color row, a parallel `bakedResults` table for hair colors, a second `bakedIdx` return for eye color). `Spawner.BuildCustomStateLines` now skips a COLOR/HAIRCOLOR/EYECOLOR line entirely when the resolved value exactly equals its baked default -- only genuine deviations get saved, same "if there's no change, no need to reference it" principle 19ah already applied to Lantern/AI-toggle.

**A `TestSetCPDPaletteColor`/`ApplyHairCategoryColor`/`TestSetBaseCPDFloat`/`TestSetEyeColor`-fed in-memory session cache (`Spawner._lastAppliedColors`/`_lastAppliedHairColors`/`_lastAppliedEyeColor`)** was added as the new TIER 0 read source, ranking above even live CPD -- needed because `lbdumpcpd` independently confirmed some pieces' CPD writes genuinely don't read back correctly at the engine/reflection level (0 entries immediately after a successful-looking write) even though the write itself visibly took effect. Not a Save/Read Current bug; the cache just sidesteps depending on CPD read-back at all for anything applied this session.

**`resolveTargetOrActor` replaces the temporary-lock workaround.** RedFalcon objected to `CS.applyLine`'s prior approach (briefly setting `Spawner.lockedTarget` to the block's actor before calling each `Apply*` function, then restoring it) as "a workaround... not a true process," and pointed out `Spawner.SetAILogic` already proves a direct-actor call works fine with no targeting involved at all. `resolveTargetOrActor(actorOverride, maxDist)` was added as a new optional trailing parameter threaded into every Apply/Test function `RestoreCustomState`'s replay touches (~13 functions) -- returns the given actor directly when provided, falls through to the existing `findNearestSpawnInFront` lock/distance resolution otherwise. `CS.applyLine` and `RestoreCustomState` now pass the actor straight through; the lock-swap dance is gone entirely.

**A second real restore bug found and fixed in the same pass**: an AI-disabled walker restored via `Spawner.RestoreCustomState` would visibly walk under normal AI for the several-second window between spawn and when the replayed `AITOGGLE:0` line actually landed. Fixed by checking `CS.findPersistedLine(label, "AITOGGLE:")` for that saved value BEFORE the actor even spawns in `restoreOne`, and calling `Spawner.SetAILogic(a, false)` immediately in the same post-spawn correction block that already fixes pitch/roll/decor-solidify -- closing the gap instead of just waiting for the later full replay to catch up.

### 19ak. "How much can we cook in at spawn time" -- native belt/strap pieces already auto-bundle their own accessories at construction, proven via `livingbase_debug.log`; offline DataAsset-cooking explored and explicitly rejected in favor of keeping Barbies fully live-editable (2026-09-16/17)

Framed by RedFalcon as a load-time-optimization question: **"the goal is to save the bare minimum in order to reduce how much needs to be done on load when entering the world. So what do we have, and what do we need."** Two different directions were investigated before landing on "do nothing new here, the design is already fine":

**Offline DataAsset-cooking, investigated then rejected.** Prompted by real uasset JSON dumps RedFalcon pulled (a Merchant's `CompositeMeshComponent`, `Equipment_CompositeMeshGroup`, and a Belt piece's own bundled `DA_Armor_Regular_Hunter_Belt_01_CompositeMeshData` showing Belt/Sling/Strap/Frog as 4 sub-entries inside ONE asset -- meaning belt-swap combinatorics are `(recipes) x (belt-sets)`, not 4 independent axes). The question: could `ConstructVisualFromParams`/`StartCharacterEdit`/`EndCharacterEdit` rebuild a WHOLE outfit live from one bundled asset, the way `Tools/UAssetAPI/rewrite_fullslots_imports.py` already ships the real live Barbie outfit via an offline import-table redirect (see 19ac/`project_sdk_stub_ue_editor` memory)? Re-tested rigorously with a before/after `BuildedCompositeMeshes` snapshot (entry count + the Belt's own `EquippedMesh` name, byte-identical before and after applying a completely different piece) -- reconfirms the pre-existing 19v/19z-era finding that this 3-call bracket is construction-time-only and a genuine no-op live, now with a definitive data-level proof rather than just "nothing visibly changed." Formally re-marked **CONCLUDED DEAD** in `Spawner.TestConstructVisualFromParams`'s own header comment.

Even setting the live-no-op problem aside, RedFalcon closed the door on the whole DIRECTION once its real cost became clear: an offline-baked combo requires a script -> repackage -> game-restart round trip per combination, which is fundamentally incompatible with "**I want the barbies to be as customizable as anything else**" -- baking in ANY fixed combo trades away exactly the live-editability the Custom tab exists to provide. Not pursued further; the per-slot live-editing architecture stays as the shipping design.

**Native construction-time accessory bundling -- a genuinely new, confirmed finding.** RedFalcon: "I know the walking senkamati witches are spawned in already wearing clothes... he gets stripped when being placed. Is what's removed logged?" Yes: `RemoveClothingOnActor`'s own pre-existing `[remove-clothes]` mesh enumeration in `livingbase_debug.log` (a separate, non-rotating-until-4MB, unbuffered `io.open(p,"a")` log distinct from `UE4SS.log` -- survives a crash, doesn't reset on relaunch) caught it directly: a fresh Barbie's belt piece (`Farmer_M_African 2`) arrived at the auto-strip pass ALREADY carrying `SM_Belt_Misc_Knife_04`/`SM_Belt_Misc_Fishhook_01`/`SM_Belt_Misc_BeltBag_02_Powder_FR2`/`SM_Belt_Misc_Bag_01` as real attached `StaticMeshComponent`s, built automatically at TRUE construction time, before any of our own code ever touched the actor. This confirms native composite construction already bundles a belt/sling/strap/frog piece's own baked `Attachments` for free -- no extra code, no extra cooking, needed for that category. It's also deterministic (same recipe -> same native bundle every time), so it's fully reload-safe with zero persistence work: a fresh actor recreated on reload just re-derives the same native bundle at construction again, same as the very first spawn, as long as that category hasn't been customized away from native. This closed out the "how will this behave on a reload" pressure-test RedFalcon raised for the diffing design overall -- nothing here needs saving/replaying, it's already free every time.

### 19al. A preset-database idea -- probing every summonable NPC's default customization categories without spawning, real `Testbed.Spawn*ByName` dispatch architecture uncovered along the way, an automated batch-walker that wouldn't stay up, and a pivot to a manual HOME-keybind probe (2026-09-16/17)

RedFalcon: "if we wanted to make a preset database of all the NPCs we have available for summoning, is it possible to automatically walk all the NPCs we have available for summoning, or is a probe needed on each? If it's the second, can I summon and we automatically walk all of them with a script." Scoped down immediately, RedFalcon's own call: "any of our custom walkers can be ignored as they are built off of existing statues. Same with any of the ones that randomize on spawn" -- ruling out `TOWNSFOLK_CLASSES`/`FEMALE_RESKIN_TARGETS` (reskin wrappers) and `SENKAMATI_LOOKS` (randomized) up front, leaving only the 4 base statue rosters (`STANDING_STATUES`/`SEATED_STATUES`/`CHAIR_STATUES`/`INTERACTIVE_STATUES`) as genuinely safe-to-batch targets.

**CDO-based probing (no spawn needed) confirmed to work, but only for already-loaded classes.** `Spawner.TestProbeClassDefaultParams`/`lbprobeclassparams` resolves a class's CDO directly via `StaticFindObject(package .. ".Default__" .. className)` and reads `DefaultParams`/`CustomizationData` off it with the SAME safe property-read recipe a live instance supports -- confirmed working instantly on an already-spawned-this-session Merchant class, confirmed FAILING ("StaticFindObject could not resolve the CDO") on a never-touched Gatherer class. This rules out a pure no-spawn probe pass across the WHOLE roster; anything never yet loaded still needs a real spawn first.

**A real architecture gap found while building the spawn-based fallback**: nothing in the real Spawn Menu ever calls `Spawner.Spawn(rawClassPath, ...)` directly -- every roster type dispatches through its own `Testbed.Spawn*ByName(name)` wrapper (`SpawnWalkerByName`/`SpawnCrewByName`/`SpawnSenkaByKey`/`SpawnFemaleWalkerByName`, and for the 4 statue rosters, `SpawnStandingByName`/`SpawnSeatedByName`/`SpawnChairByName`/`SpawnInteractiveByName`, each taking a SHORT class name derived from `row.path`, not a raw path, internally routing through `statueByName`->`placeStatueEntry`->`spawnPosed`). A first `lbwalkroster` built around raw `Spawner.Spawn(classPath)` calls crashed on the very first Walker/Worker entry -- initially misread as "AI-driven Movers are inherently riskier than statues," until RedFalcon directly challenged that ("how is it different from my spawning something") and then correctly named the real cause ("oh is a custom walker?"): the tool was bypassing the real spawn mechanism entirely, not hitting a Mover-specific risk. Rebuilt around the real `Testbed.Spawn*ByName` functions restricted to the 4 statue rosters, reading via a new pure-read `Spawner.ReadDefaultParamsSummary(actor)` (no spawn/despawn logic of its own), staged as 3 separately-timed `ExecuteInGameThread` calls per entry (spawn/read/despawn, `INTRA_DELAY_MS=2000` apart per RedFalcon's "at least a second or two between each step, it can be a bit finnicky"). Since `main.lua` already requires both `Spawner` and `Testbed` (and `testbed.lua` itself requires `spawner.lua`, ruling out `spawner.lua` requiring `testbed.lua` back without a cycle), the orchestration had to live in `main.lua`, with only the pure read (`Spawner.ReadDefaultParamsSummary`) added to `spawner.lua`.

**The corrected v2 walker still crashed twice**, even with the right spawn mechanism and staged pacing -- both dumps localized (via the project's own from-scratch `parse_minidump.py`, see `feedback_minidump_crash_triage`) to `UE4SS.dll`, at close-but-different offsets and different crashing threads each time, consistent with this project's standing "general reflection-bridge instability, not one bad call" theory rather than a fixable logic bug in the tool itself. One run also showed a suspicious silent gap -- the expected read-confirmation and despawn-confirmation log lines for the first entry never printed, yet the loop advanced to entry 2 regardless several seconds later -- not explained. Left as an OPEN, unresolved reliability issue (`lbwalkroster` kept in the codebase, not removed) rather than chased further, since RedFalcon pragmatically pivoted to a simpler approach instead of asking for more automation debugging.

**Pivot: a manual HOME-keybind probe**, RedFalcon: "to make things easier on me, can we make a key run the command" -- one-at-a-time probing (via `Spawner.TestReadDefaultParamsOnTarget`, resolving the nearest/locked actor and calling `ReadDefaultParamsSummary` on it) instead of continued batch-automation debugging. Two keybind picks were tried before landing on a safe one: F12 was rejected immediately by RedFalcon ("F12 is screenshot" -- Steam's own screenshot overlay hotkey, a system-level conflict invisible to a per-mod-config grep, see `feedback_keybind_collision_check`); HOME was checked and confirmed genuinely free across every installed mod's own config. Registered as `probeDefaultParams = "HOME"` in `Config.KEYS`, with `HOME`/`END`/`INSERT`/`DELETE`/`PAGE_UP`/`PAGE_DOWN` added to `VK_FALLBACK` as a defensive safety net alongside it. Per this project's own standing rule, `RegisterKeyBind` is only safe during the initial synchronous startup pass -- this required a full game RESTART, not just `lbreload`, to take effect, which is what triggered the still-open issue in 19am below.

### 19am. OPEN ISSUE at end of session -- the restore chain appears to silently hang after a full-restart, not even reaching its own already-verified error-surfacing code (2026-09-17)

After restarting to pick up the HOME keybind (19al), RedFalcon reported: **"I don't think it loaded properly. Nothing spawned and I can't open the menu."** `UE4SS.log` showed a clean load (all bridges armed, keybind system reporting all binds/toggles applied, no load-time errors) and the restore sequence progressing normally through "Restore: player pawn ready" and "Restore: player moved after 9s -- world is live; settling 6000ms." -- then nothing further printed for 2+ minutes (well past the 6-second settle window), with the game process still alive (not a crash to desktop, a silent hang). The `RestoreFromPersist FAILED`/`RestoreCustomState FAILED` pcall-based error-surfacing added earlier this project is confirmed still present in `main.lua`'s `fire()`/`afterRestore()` and did NOT fire either -- meaning either the `ExecuteWithDelay(6000, ...)` callback itself never ran, or `RestoreFromPersist` hung on something native before reaching even its own first log line, which a Lua `pcall` cannot catch either way. Notable: OTHER `ExecuteWithDelay`-driven ticks (the 1-second "has the player moved yet" poll that produced the "moved after 9s" line itself) clearly kept firing right up to that point, so the delay mechanism as a whole isn't broken -- only this one specific 6-second callback is implicated. A `[UE4SS.EngineTick.LuaModImpl] Hook threw exception... removing hook!` line at roughly the same window was noted but reasoned to likely be unrelated, since equivalent `ExecuteWithDelay` polling continued working both before and after it in this same log.

Not yet root-caused. The keybind change itself is very unlikely to be the cause (pure config/registration addition, inert until pressed, and the log shows it registered cleanly) -- the failure point is squarely inside the pre-existing restore chain, before any keybind comes into play. Recommended next step if this recurs: check whether `RestoreFromPersist` can hang on a genuinely long-running or blocking native call for a SPECIFIC saved roster shape (as opposed to a Lua-level error, which the existing pcall already catches), and whether a fresh minidump exists from this exact hang window despite the process not having crashed outright.

**RECURRED 2026-09-20, this time with a genuine reproducible thread instead of a total hang, and a real fix for the part that WAS fixable.** During the same session as 19av's Mobile-NPC work (after several `lbreload` cycles), RedFalcon: "not everyone spawned in this time and theres an error in the log," then confirmed only 1 of 6 saved entries had actually come back ("i only see the sergeant" -- later clarified: "and the sergeant is a botc merchant statue", i.e. even that one visible actor was misidentified/mislabeled, not a second real survivor), and "the menu no longer opens" -- the SAME symptom shape as the original 19am report, word for word. The SAME `[UE4SS.EngineTick.LuaModImpl] Hook threw exception... "Ref was not function"... removing hook!` line appeared again, at almost the exact same point in the sequence (right after the first entry's `[furniturepass]`/`[raytrace-fix]` lines). This time there was enough log evidence to test whether the hook death actually explains the failure, the same way 19am's own writeup did -- and the answer is the same: **it doesn't, at least not directly.** Hover-diagnostic polling (a separate `ExecuteWithDelay`-driven loop) kept firing every ~1s for the next 50+ seconds after the hook exception, and the restore's own two-stage `spawnList` completion callback (`onDone`) DID eventually fire (`"Restored 3 statues + 3 movers"` printed 3+ seconds later) -- so `ExecuteWithDelay` as a mechanism clearly wasn't broken. The hook exception is very likely a real, separate, currently-unexplained UE4SS-internal fault that happens to correlate in timing with this recurring issue without being its direct cause -- worth continuing to note when it appears, not yet worth chasing on its own.

**The REAL, now-identified cause of the under-restore: `restoreOne` had NO failure branch at all.** `local ok, a = pcall(function() return Spawner.Spawn(...) end); if ok and a and a:IsValid() then ... return a, cls, look end` -- and nothing after that `if`. A thrown Lua error (`ok=false`) or `Spawner.Spawn` returning `nil`/invalid both fell off the end of the function with ZERO trace anywhere -- no log, no `always()`, nothing. Compounding it: `spawnList`'s own per-entry `"Restore %d/%d -> %s"` line used `log()` (VERBOSE-gated, silent by default), and the final `"Restored %d statues + %d movers"` summary printed `#statics`/`#movers` -- how many lines were CLASSIFIED going in, not how many actually produced a live actor. All three gaps together meant a partial restore failure was not just hard to diagnose, it was **completely invisible**: the log actively reported success ("Restored 3 statues + 3 movers") while 5 of those 6 had silently vanished. Grepping the whole log for the per-entry line and for `[furniturepass]`/`[strip]` side-effects (the only reliable proxy, since the real trace line was gated off) confirmed only ONE of the 6 entries ever produced any observable spawn side effect at all.

**Fix (visibility, not yet a root-cause fix for WHY those 5 calls failed)**: (1) `restoreOne` now has a real failure branch -- `always()` logs the resolved label, class, and either "returned nil/invalid" or the actual caught error message, unconditionally. (2) `spawnList`'s per-entry line changed from `log()` to `always()` -- always visible now, not VERBOSE-gated. (3) `spawnList` now tracks a real `successCount` per list (incremented only when `restoreOne` actually returns a live actor) and threads it through to `onDone`, so the final summary line reports `"Restored X/Y statics + A/B movers"` -- real successes over real totals -- and a NEW `always()` line explicitly calls out a partial failure by count when the two don't match, pointing back at the per-entry `"Restore FAILED"` lines for detail. **Next time this recurs, the log will say WHICH entries failed and WHY (the actual pcall error text, or confirmation that Spawn cleanly returned nil) instead of silently reporting success** -- that's the concrete, actionable next step for whoever picks this up, rather than re-deriving "something failed silently" from scratch again.

**Files touched**: `spawner.lua` (`restoreOne`'s new failure branch; `spawnList`'s `log`->`always` per-entry line, `successCount` tracking, `onDone` signature change; the final restore-summary print + new partial-failure `always()` line).

### 19an. Lantern/soc_Lantern coexistence, a real WEAPONSLOT diffing gap, the detect gate restored, Accessories grid always-interactable after its own detect, and Custom-view reset on untarget (2026-09-17/18)

Four bundled asks from RedFalcon in one message, all shipped together: "let's re-enable locking edits until a detect. Also is there a way to prevent it from writing the belt accessory changes if a detect hasnt been run on those? I also found some of the default NPC set other sockets with out the related belt socket, so let's not disable any accessory sockets, keep them always available after a detect accessories call. I do think clearing that section when that belt item is removed is still good. Also can we reset the custom view when a target is unselected?"

**`g_hasDetected` detect-gate restored** (`CustomMenu.cpp`) -- had been "TEMPORARILY BYPASSED" on 2026-09-16 for crash diagnostics, with its own header comment explicitly promising a revert once that experiment ended; the revert had simply never been done. Restored `|| !g_hasDetected` on all 6 `BeginDisabled` calls wrapping Body/Hair/Clothes/Belts-and-Straps/Poses-and-Actions and the Save Customizations button itself.

**Accessories grid ungated from per-piece visibility.** Previously the Belt/Sling/Strap/Weapon columns of the socket-accessory grid were each wrapped in their own `BeginDisabled(!g_beltVisible)` etc, tying accessory-editability to whether the corresponding Belt/Sling/Strap/Frog piece was currently visible -- but RedFalcon found native NPCs with real accessories sitting in sockets whose OWN parent belt piece isn't equipped/visible at all, meaning those sockets could never be reached to fix them. Removed all 4 `BeginDisabled`/`EndDisabled` pairs from the grid's own draw loop; accessories are now always interactable once the whole section unlocks via `g_hasDetected`, regardless of piece visibility. `clearAccessoriesForRemovedPiece` (Lua-side, unchanged) still clears a piece's own accessories when that piece itself gets removed -- kept per RedFalcon's "clearing that section when that belt item is removed is still good."

**WEAPONSLOT diffing gap, found via a real bug report**: "I did a save on marita. WEAPONSLOT:LeftPistol:Pistol - Rusty - Belt was saved but its spawned with her. is this a miss?" -- yes: `Spawner.BuildCustomStateLines` diffed `SOCKETITEM` against the raw-capture baseline but never consulted it for `WEAPONSLOT`, even though the SAME `RAWACC:beltSlot_01_lSocket:...` baseline line already covers the exact socket a weapon-slot location resolves to. Fixed by using `Spawner.TestReadWeaponSlots`'s new 2nd return (`resolvedSockets`, the real socket backing each detected location) to look up the matching baseline entry, with the same "None" removal-symmetry `SOCKETITEM` already had deliberately left out of scope (would need `WEAPON_GROUP_SOCKETS`, a `local` declared later in the file, out of scope at that point) -- not part of this specific report, revisit if it's ever actually needed.

**Reset custom view on unselect** -- new `ResetCustomViewState()` (`CustomMenu.cpp`) reverts every dropdown/swatch/checkbox in the Custom tab to its neutral default; called from the existing target-change-tracking block when `MenuStatus::TargetId()` (the stable per-instance identity check, not the cosmetic label) transitions from non-empty to empty. Duplicates rather than shares the reset logic `pollReadCurrentResult`/`pollSocketAccStatus` already run before their own parsing (C++ has no hoisting, and those two functions are declared before some of the fields this needs to reset) -- three independent reset blocks now exist by design, not an oversight.

**Lantern/soc_Lantern coexistence** -- "some of them have an item in the lantern spot... both should be allowed at the same time." `soc_Lantern` used to be hard-excluded from `Config.SOCKETITEMS_SOCKETS` entirely; RedFalcon's own lantern feature and a genuine native accessory can occupy the exact same socket simultaneously, so `CS.sweepAttachedMeshes(actor)` was widened to return a SECOND value (`attachedMeshList`, the full occupant list per socket, not just "last one wins") alongside the original single-value `attachedMesh` map (kept unchanged for every existing caller). New `CS.LANTERN_KNOWN_MESHES`/`CS.filterOutLanternMeshes(list)` filter our own lantern meshes (`SM_Accessories_Lantern_01`/`SM_Accessories_LanternGlass_01`) out of that occupant list wherever `soc_Lantern` is being read -- `TestReadSocketAccessories`, `CaptureRawCustomBaseline`, and `BuildCustomStateLines`' own SOCKETITEM diff all use this same filtered-list lookup instead of the plain map for this one socket. `Spawner.TestReadLanternState`/`RemoveSocketAttachment`/`ClearSocketAccessories` were all updated to protect a known lantern mesh from being treated as (or destroyed as) a regular accessory at this socket. `gen_socketitems_lua.py`'s `EXCLUDED_SOCKETS` changed from `{"soc_Lantern"}` to `{"soc_LanternLight"}` (the FX-only socket stays excluded; the real socket doesn't). New `LANTERN:` line piggybacks on the same "Detect Accessories" status-file cycle (`custom_socketacc_status.txt`) RedFalcon later confirmed via a follow-up report ("the lantern detection doesnt see it when our lantern is already there") had zero live-detection wiring anywhere at all -- `pollSocketAccStatus` now parses it into `g_lanternOn`.

**Files touched**: `spawner.lua` (`CS.sweepAttachedMeshes`/`CS.LANTERN_KNOWN_MESHES`/`CS.filterOutLanternMeshes`, `TestReadSocketAccessories`/`CaptureRawCustomBaseline`/`BuildCustomStateLines`/`TestReadLanternState`/`RemoveSocketAttachment`/`ClearSocketAccessories`); `main.lua` (`BeltStrapPolls.socketAcc`'s new `LANTERN:` status line); `gen_socketitems_lua.py` (`EXCLUDED_SOCKETS`); `CustomMenu.cpp` (`g_hasDetected` gate restored x6, Accessories grid `BeginDisabled` removal x4, new `ResetCustomViewState()`, `pollSocketAccStatus`'s `LANTERN:` parsing).

### 19ao. Long Ben (and anyone else) intermittently failing to spawn on restore -- a real closure-capture race in the restore stagger loop, found by tracing a genuine Lua error instead of guessing (2026-09-18)

RedFalcon: "i'm finding that long ben doesnt always spawn all the time and i do see an error in the log." The error -- `spawner.lua:11036: attempt to index a nil value (field '?')`, inside `spawnList`'s own `step()` closure -- looked at first like it could be malformed `persist.txt` data, but both persist files (`readBlocks`, cat -A'd for hidden characters) were clean, and `persistReadLines`/`isStaticLine`/the statics-vs-movers classification loop all build their tables via plain, hole-free sequential appends.

**Root cause**: classic closure-over-mutable-upvalue race. `spawnList`'s `step()` incremented a shared `local i`, then queued `ExecuteInGameThread(function() ... list[i] ... end)` -- the closure reads `i` as a live upvalue, not a snapshot -- and immediately called `ExecuteWithDelay(interval, step)` for the NEXT step, without waiting for the queued callback to actually run. If `ExecuteInGameThread`'s callback is even slightly delayed (very plausible mid-world-load, competing with heavy asset streaming for the same queue), several `step()` calls can advance `i` past `#list` before any of the queued callbacks fire -- each one then reads whatever `i` happens to BE by the time it finally runs, not the index it was scheduled for, so `list[i]` comes back nil and that entry's restore is silently dropped. Explains every observed symptom at once: intermittent (depends how backed-up the queue gets each load, which varies by system timing), and 2 near-simultaneous log errors in one restore (2 queued callbacks both stranded, both draining back-to-back once free, both reading the same by-then-advanced `i`). Long Ben, classified as a "static" (QuestStatic) in a short, fast-interval (40ms) statics list on a small base, had high odds of being one of the entries left behind.

**Fix**: snapshot the index into its own `local idx = i` BEFORE scheduling, so each queued closure carries a value immune to `i` racing ahead. Applied to `spawnList` (the crashing one) and the structurally-identical pattern in `scheduleRestorePostProcess`'s own `step()` (guarded there, so it silently skipped a restored actor's post-processing under the same conditions rather than crashing -- same root bug, lower-visibility symptom). A third occurrence of the same shape, `Spawner.RestoreCustomState`'s own `step()` (written earlier the same session), was checked and found ALREADY correct -- it captures `local b = blocks[i]` before scheduling, not `i` itself, so no fix was needed there.

**Files touched**: `spawner.lua` (`spawnList`, `scheduleRestorePostProcess`).

### 19ap. A Height slider for the Custom tab (3ft-8ft), and the same "scale lives on the Mesh, not the actor root" lesson `lbheight` already taught this project once before, re-learned the hard way (2026-09-18)

Prompted by a throwaway question -- "if long ben at 1.2 scale is assumed to be 7ft and marita at .95 scale is assumed to be 5ft how tall is 1" -- that turned into a real feature once RedFalcon liked the resulting number. Fitting a line through (1.2, 7ft) and (0.95, 5ft) collapses to a flat proportional relationship, `heightFt = 5.8333("5'10") * scale`, confirmed against a THIRD anchor point RedFalcon supplied directly ((1, 5'10"), (1.2, 7ft) -> Marita at 0.95 comes out to 5'6.5", which RedFalcon accepted). `CS.FEET_PER_SCALE_UNIT` is that one constant, referenced everywhere the conversion is needed.

**Test command first, `lbsetscale scale|feet <value>`** -- explicit unit parameter, RedFalcon: "to reduce confusion... in case i want to play with extremes," replacing an earlier magnitude-guessing version (>3.0 assumed feet) after the very next request made clear extreme test values needed to be unambiguous.

**Real slider shipped**: 3ft-8ft range, Body section, immediate-apply through the same request-file bridge every other Custom tab control uses (`custom_height_request.txt` -> `pollCustomHeightRequest` -> `Spawner.ApplyActorHeightFeet`), wired into Read Current (`Spawner.TestReadActorHeightFeet`, a `HEIGHT:` status line) and Save/Restore (`BuildCustomStateLines`'s own HEIGHT diff, `CS.applyLine`'s `HEIGHT:` case) exactly like every existing category.

**Native-default lookup added a genuinely new, zero-scanning technique to this project**: rather than requiring a HOME-probe rescan of all 33 tracked archetypes just to learn each one's own baked scale (RedFalcon: "the less we have to apply the better, i'm thinking rules of scale"), `CS.getClassDefaultScale(actor)` reads it straight off the actor's own class CDO at runtime, on demand, via the SAME zero-spawn CDO-reflection technique `Spawner.TestProbeClassDefaultParams` already proved (`StaticFindObject("package.Default__ClassName")`) -- no scan, no rescan, ever, for this one category. First version read `cdo.RootComponent.RelativeScale3D`, matched against a FModel dump RedFalcon pulled directly showing Marita's Blueprint CDO baking `RelativeScale3D: 0.95` -- but the JSON snippet didn't actually show WHICH component that property belonged to, and RootComponent was the wrong guess (see below).

**Two real, connected bugs found once live testing began, both traced back to the same wrong assumption**: (1) "clicking save did not add a height entry" -- the diff's `K2_GetActorScale3D()` read had no `GetActorScale3D()` fallback (every other read in this feature had one), so a failed call silently skipped the whole HEIGHT block; (2) even once fixed, "the detect isnt pulling scale" -- Long Ben's Detect came back as scale 1.0 (5.83ft) instead of his real, already-known-to-this-project 1.2 (7ft). Root cause, found by checking this project's OWN memory of an earlier `lbheight` investigation (2026-09-13, RedFalcon: "Marita is shorter so i can't quite see her face... I think she may be at a different scale") rather than re-deriving it from scratch: this game's `CapsuleComponent` stays a FIXED gameplay-collision size regardless of visual size -- a "short"/"tall" NPC variant is achieved entirely by scaling `actor.Mesh`, confirmed live back then (default mesh scale 1,1,1, Marita's 0.95,0.95,0.95). Every part of this feature had been reading/writing the ACTOR/ROOT's scale, not Mesh's -- visually resizing the target fine (root scale cascades to Mesh via normal parent-child inheritance) but blind to, and stacking on top of, a native NPC's own already-baked Mesh-level scale rather than replacing it. Fixed all three places to agree on `actor.Mesh`: `CS.setActorScaleGrounded` now calls `mesh:SetRelativeScale3D(...)` (proven binding, used pervasively elsewhere in this file) instead of `actor:K2_SetActorScale3D(...)`; `Spawner.TestReadActorHeightFeet`/the `BuildCustomStateLines` HEIGHT diff now read `actor.Mesh:K2_GetComponentScale()`; `CS.getClassDefaultScale` now reads `cdo.Mesh.RelativeScale3D`.

**Ground-compensation went through two real fixes of its own.** RedFalcon: "the scale seems to resize from the center so if x and y are 0... we'll want to make sure the move up the z axis to compensate." First version measured `actor:GetActorBounds()` before/after the scale change -- but UE caches render bounds on skinned meshes, only recomputing on the component's own next tick; reading it same-frame as the scale change ("resizing an upright character did not move them to their feet") returned stale pre-scale bounds, making the computed delta 0. Switched to a live bone/socket query instead (`mesh:GetSocketLocation(FName("root"))`, the one call already confirmed working in this exact R5 build via `Spawner._computeHeadCenterPose`'s own header -- `GetBoneLocation` never returned a usable result here) -- but once scaling moved from actor/root to Mesh itself, the ORIGINAL reference point (`mesh:K2_GetComponentLocation()`, the component's own origin) stopped moving at all from the component's own scale change (a component's origin is its pivot; scaling around your own pivot doesn't move the pivot), so that had to switch to the bone/socket read too. **Second fix**: the compensation fired unconditionally regardless of the actor's own orientation, which both doesn't make sense for a posed/tilted target (world-Z isn't "up" relative to them) and turned out to look like it was interfering with something else (see 19aq) -- RedFalcon: "I never wanted X or Y reset, just that if X and Y were 0 when scaling, then ensure the z height matched. otherwise just leave it and let it resize from the center." Now reads the actor's Pitch/Roll first and only runs the feet-tracking/Z-shift logic when both are ~0; an off-axis target just gets the plain scale applied, no location correction, resizing purely around its own current pivot.

**Files touched**: `spawner.lua` (`CS.FEET_PER_SCALE_UNIT`, `CS.getClassDefaultScale`, `CS.setActorScaleGrounded`, `Spawner.TestSetScale`/`lbsetscale`, `Spawner.ApplyActorHeightFeet`, `Spawner.TestReadActorHeightFeet`, `BuildCustomStateLines`'s HEIGHT diff, `CS.applyLine`'s HEIGHT case, `CaptureRawCustomBaseline`'s now-secondary `RAWSCALE` capture); `gen_npc_customization_reference.py` (`RAWSCALE` parsing, `scale` field emission -- kept as a fallback only, never actually populated by a rescan since the CDO read supersedes it); `main.lua` (`pollCustomHeightRequest`, the Read Current HEIGHT step); `CustomMenu.cpp` (`g_heightFeet`, the Height slider row in the Body section, `WriteHeightRequest`, `HEIGHT:` status parsing, `ResetCustomViewState`'s own reset line).

### 19aq. OPEN, not pursued -- named/quest NPCs (Ben, Marita, BlackAxel) don't visibly respond to manual pitch/roll rotation via the Live Edit tool; a generic NPC does (2026-09-18)

Surfaced as a suspected regression while testing the Height slider's new upright-only gate (19ap) -- RedFalcon: "i'm noticing that i can no longer rotate along the x or y axies" -- but investigation (log tracing through `Spawner.EditNearestInFront`/`numpadMoveOrRotate`, confirming `dPitch`/`dRoll` deltas were being read and `K2_SetActorRotation` genuinely called with correctly-accumulated values every time) plus a full world reload and a fresh spawn both still failing ruled out both "code regression from today's changes" (nothing touched this function) and "actor-level state corruption." Cross-checked against this project's own memory (`recovered-livingbase-sessions.md` #20, the "3-axis rotation rework," v2.1.0/2.1.7, shipped and confirmed working long before today) to rule out "engine hard-locks Character pitch/roll" as a blanket explanation -- it doesn't, this exact mechanism has worked before.

**The real distinguishing factor, found by RedFalcon's own test**: rotation via this tool works fine on a generic/regular NPC, but not on named/quest NPCs (Ben, Marita, BlackAxel) specifically -- the SAME category of actor this session already found carries a custom baked transform on `actor.Mesh` (the 1.2/0.95 scale, see 19ap). Plausibly the same Mesh-level override decouples rotation the same way it decouples scale, but this was NOT confirmed (the one distinguishing test proposed -- whether YAW also silently fails to visually apply on a named NPC, which would confirm full decoupling vs. something pitch/roll-specific -- was never run). RedFalcon closed the investigation as "not important enough to worry about." Revisit if it resurfaces or blocks something else; the likely next step would be checking `actor.Mesh.bAbsoluteRotation` (or the equivalent property this UE4SS binding exposes) on a named NPC vs. a generic one.

### 19ar. "Mobile Marita" -- a long, mostly-dead-end-strewn investigation into giving a named QuestStatic NPC real walking AI while keeping her true look (face morph, tattoos, makeup) intact -- one genuinely new, reusable capability found (UAssetAPI + this game's own `.usmap`), the real working AI-override mechanism found and confirmed live, and the actual remaining blocker (locomotion animation) correctly diagnosed but PAUSED, not fixed (2026-09-18)

RedFalcon's ask, evolving over the course of the investigation: "take maritas native mesh and look and apply the walking ai to it so she looks exactly the same but is mobile" -- scoped down once to "all i'm looking for is looks" (no bespoke AI/behavior fidelity needed), then corrected right back up once RedFalcon confirmed her face is a genuinely unique shape/morph AND she has unique tattoos/makeup the walker archetypes don't -- both real, both already-documented (see below), ruling out the cheap "reskin a walker" path entirely. Final framing, RedFalcon's own words: "because you can't apply it to the extant actor, we need to build it with a different ai mechanism" -- keep her own real spawned instance (her true look comes for free, since it's genuinely her), and give THAT AI/movement, since transplanting her look onto a donor was never going to work.

**Dead end 1 -- "reskin a walker with her real DefaultParams" (the pre-existing `Config.FEMALE_RESKIN_TARGETS`/"Marita Base 1/2" system).** Already shipped, already uses her REAL `CompositeMeshComponentParams` (not a guess) -- but RedFalcon confirmed live it "makes her look like the gatherer and herbalist with her clothes," i.e. outfit/hair carry over, face/body does not. Root cause confirmed by comparing her own `CompositeMeshComponent` export against Gatherer's (both extracted via `retoc to-legacy` + UAssetAPI, see below): neither has a PER-CHARACTER override on `MorphParams`/`BodyTypeParams`/`ColorParams`/`BodyDecorParams` -- both just inherit the same shared `BP_NPC_Base` defaults. Her actual tattoos/makeup and (per RedFalcon) her face morph are NOT stored as a Blueprint-class property at all -- they match this project's own already-closed "Skin Decor" investigation (`BARBIE_ROSTER.md`'s TODO section, months old: "Marita Suares has a full makeup look -- Chest tattoo + Eyeliner + Lips + Cheeks," confirmed as `SavedCustomizationData`-driven, consulted exactly once at THAT ACTOR'S OWN construction, never transplantable to a different actor afterward). This is the same "GENERAL RULE" wall this project has now hit a 4th time (body/head morphs, Age, skin decor, and now confirmed applicable to a specific named NPC's own baked look) -- not a bug, a hard constraint.

**New reusable capability found while chasing this: loading this game's own `.usmap` type-mapping file (`Other/R5-5.6.1-0+UE5-e09d3821.usmap`, the same one FModel uses) into UAssetAPI's `UAsset` constructor fixes the parser almost completely for base-game content.** Every prior UAssetAPI script in this project (`Tools/UAssetAPI/*.py`) only ever touched simple, well-known-type assets authored by this project itself (DataAssets, `BP_BarbieR5Char_Test`) and never needed a `.usmap` -- a real base-game NPC Blueprint (Marita's own `BP_NPC_QuestStatic_Smugglers_MaritaSuares`) drags in dozens of exotic native `R5*` component types UAssetAPI's built-in property registry doesn't recognize, causing EVERY export to fall back to an unparsed `RawExport` byte blob with the plain constructor. `UAsset(path, engineVersion, Usmap(usmapPath), CustomSerializationFlags.None)` (4-arg constructor, confirmed present in `UAssetAPI.xml`) turns nearly all of those into properly-parsed `NormalExport`s with real named properties. **Keep this for any future base-game asset inspection in this project** -- it would have saved real time here if reached for immediately instead of discovered mid-investigation.

**Two more dead ends chasing WHERE her AI controller assignment lives, both found via the newly-unlocked parsing:**
- `DA_NPC_QuestStatic_AIPawnParams` (referenced by her CDO as a create-dependency) turned out to be pure behavior TUNING data (WanderSpeed/AggressionRadius/memory-key tags), not a wander on/off switch -- her own copy already has `WanderSpeed=110`, identical to Citizen Walker's. Also confirmed SHARED across the whole QuestStatic category (Ben/Letty/Marita all reference the same one package) -- editing it in place was correctly vetoed by RedFalcon ("i dont want the original to walk though") before this dead end even mattered.
- `PresetParams` (a property that DOES differ per-character, `DA_NPC_QuestStatic_Smugglers_MaritaSuares_CustomizationPresetParams`) resolved to a package path under `/R5BusinessRules/Character/Customization/...` that doesn't exist in ANY shipped pak (searched all 5 chunks via `retoc list --path`) -- almost certainly a creator-tool-only reference, same category as the already-closed Age system (`R5HFSMCharacterCustomizationComponent`, confirmed creator-only, doesn't exist outside the character-creator screen).
- Her CDO itself (`Default__BP_NPC_QuestStatic_Smugglers_MaritaSuares_C`) remained an unparsed `RawExport` even WITH the usmap loaded (same true of `BP_NPC_Base`'s own CDO) -- and a direct search of her asset's name table confirmed `"AIControllerClass"` does not exist ANYWHERE in the file, not as a property, not as any substring match. Her CDO's own dependency list DOES require `BP_NPC_AIController_QuestStatic_C` to load first (a real, class-specific dependency, not inherited from Base, which depends on a DIFFERENT controller) -- but whatever mechanism creates that dependency isn't a plain named CDO property, and is most likely compiled Blueprint graph/bytecode logic (Construction Script or event graph), a category of edit this project's UAssetAPI toolkit has never attempted and was correctly not attempted here either.

**The actual working mechanism -- found, not built new.** `Spawner.Spawn`'s existing `aiControllerClassPath` parameter writes `deferred.AIControllerClass = aiClass` on the actor's DEFERRED spawn transaction, before construction finishes -- genuinely "assign it before spawning," not a live post-spawn `SpawnDefaultController()` retrofit (which the earlier "we've established we cant add ai after creation" finding correctly rules out). Already shipped, already used successfully for creature AI overrides, with its own dedicated test command (`lbtestai`, `Spawner.TestSpawnWithAIOverride`). **Confirmed live**: `lbtestai` on Marita's real class + `BP_NPC_AIController_Handyman` produced a valid controller with no visible behavior change (matches that tool's own documented "lacks the worker data it needs" failure mode -- Handyman's brain expects a workstation/work-zone assignment Marita never has). Retried with `BP_NPC_AIController_Citizen_Walker` (a brain built for pure ambient wandering, no work-zone dependency) instead -- **she genuinely moved** (confirmed: "so she slides around"). This is real progress: her own actual actor, real look intact, real AI-driven movement, zero asset edits, zero risk to the original quest NPC.

**Remaining problem, correctly diagnosed but not fixed: locomotion ANIMATION, a separate axis from AI.** She "slides" -- moves through the world with no walk-cycle animation -- because her `Mesh.AnimClass` was still her own static `ABP_StandingNPC_Regular_AI_C` (an AnimBP with no locomotion blend logic at all, appropriate for an NPC that's never supposed to move). `Spawner.SetAnimClass` already existed for swapping this (built back on 2026-08-14 for the statue pose-porting problem) -- new `Spawner.TestSetAnimClass`/`lbtestanimclass` wraps it as a target-resolving console command, deliberately ALWAYS passing `skipForceRebuild=true` (the safe bare-property-write path) since the alternative, `SetAnimInstanceClass`'s force-rebuild call, has caused hard, uncatchable native crashes on at least one other class before (`WINDROSE_MODDING_NOTES.md` 19x). The real walking AnimClass (`ABP_Human_NPC_C`, `/Game/Character/Animation_Blueprints/Human/Regular/NPC/ABP_Human_NPC.ABP_Human_NPC_C`) was found via a live `lbdumpanim` probe on an actual Citizen/Gatherer NPC (static UAssetAPI extraction hit the same "UnknownExport" reference-resolution limitation already documented for this asset-reference type -- live reads sidestep it cleanly). Applying it via `lbtestanimclass` confirmed a fresh `AnimInstance` genuinely gets built (`AnimationMode=0`, `RuntimeAnimInstanceClass=ABP_Human_NPC_C`, matching a real walker's own confirmed-good values exactly) -- but she kept sliding in her ORIGINAL default pose anyway.

**Root cause, confirmed by directly comparing two live `lbdumpanim` dumps RedFalcon captured** (a real Gatherer unmodified vs. the same Gatherer with `Spawner.ApplyPose`'s SingleNode mechanism applied -- RedFalcon's own point: "its true with any pose... if i took a walker and applied any of our poses on it, the same behavior would happen," which correctly ruled out `AnimationData`/pose-locking as Marita's specific problem, since that's a totally different, unrelated mechanism `Spawner.ApplyPose` uses (`AnimationMode=1`, `AnimSingleNodeInstance`, frozen `CurrentAsset`) that was never applied here at all): the unmodified Gatherer's `ABP_Human_NPC_C` AnimInstance carries a long list of locomotion-driving variables -- `GroundSpeed`, `Velocity`, `ShouldMove`, `IsWalking?`, `ToIdle`, `ToWalkMovement`, `LocoDirection`, etc. -- all populated with real, live-updating values. These are NOT computed internally by the AnimBP's own graph from raw physics; they're pushed onto the AnimInstance EVERY TICK by the character's own Blueprint event graph (reading its `CharacterMovementComponent`'s real velocity). A genuine Gatherer/Citizen has that Tick logic built into its own class. Marita's class never did -- she was never built to move -- so her fresh `ABP_Human_NPC_C` instance just sits at whatever those variables default to (idle/zero), regardless of her actual world-space movement. Same failure category as the 2026-08-14 static-pose T-pose bug (`IsFemale?`/`ArmorThicknessMorph`/`BodyMorph` needing explicit correction after a bare `AnimClass` swap) -- a fresh AnimInstance only ever gets pure class defaults, never a donor's own construction-time setup.

**Two fix paths considered, neither attempted -- explicitly paused here, not chosen wrong:**
1. **A live Lua per-tick sync** (read her `CharacterMovementComponent`'s real velocity, push the equivalent `GroundSpeed`/`ShouldMove`/`IsWalking?` values onto her `AnimInstance` on a repeating timer). RedFalcon's own correct objection: this project's existing repeating-timer mechanism (`ExecuteWithDelay`) only ever runs at 40-400ms cadences elsewhere in this codebase -- nowhere near animation-relevant (16-33ms) -- so this would visibly stutter/step rather than blend smoothly, and state transitions (idle->walk) would lag behind actual movement. A TRUE per-frame fix would need a real UE4SS `RegisterHook` on something like `Actor:ReceiveTick` -- confirmed via grep that this project has NEVER used `RegisterHook` for anything, ever, making this genuinely new, higher-frequency (fires every tick for every ticking actor unless carefully scoped), higher-risk territory than anything hooked in this codebase before, on top of this project's own repeated history of native-hook/reflection-bridge instability.
2. **A custom-authored Animation Blueprint** (the "cook it in like the Barbies" approach RedFalcon proposed) -- a NEW, self-contained AnimBP with its own "Blueprint Update Animation" graph logic (Get Owning Pawn -> Get Velocity -> compute speed -> feed a locomotion blend directly), so it never depends on an external character Tick pushing data into it. This is the philosophically "correct" fix, matching this whole project's own established "bake it in at construction, never fight a value live" principle -- and the `LivingBaseExtended` SDK-stub Editor project is exactly the right place to build it (same category of work as the from-scratch `BP_BarbieR5Char_Test`). But unlike every other UAssetAPI-based fix in this project, this specific piece is NOT a scriptable property retarget -- it requires actually authoring an AnimGraph/State Machine visually inside the Unreal Editor, real hands-on Editor work no script can substitute for.

**Status at end of session: PAUSED, not abandoned, not broken.** What's confirmed working right now, zero asset edits, zero risk to the real quest NPC: spawn Marita's own real class with an AI controller override (`lbtestai <her class path> <Citizen Walker AIController path>`) and she moves, in her own true look, driven by her own real actor. What's missing: proper locomotion animation instead of sliding, which needs either a genuinely new (for this project) per-frame Lua hook or real Editor-side AnimBP authoring -- both bigger, riskier, or more hands-on than anything attempted today, and both deliberately left for a future session rather than rushed.

**Files touched**: `spawner.lua` (`Spawner.TestSetAnimClass`/`lbtestanimclass`, placed after `resolveTargetOrActor`'s own declaration after an initial forward-reference placement mistake -- see that function's own header for the exact live error this caused and how it was caught); `main.lua` (the `lbtestanimclass` console command registration). No asset files, paks, or the SDK-stub Editor project were touched -- this entire session's Marita-mobility work was investigation, live console testing, and one small Lua console-command addition, nothing shipped/cooked.

**Next session, pick up here**: (1) decide between the Lua-tick-hook and custom-AnimBP paths for the animation gap (or find a third option), (2) if the custom-AnimBP path is chosen, block out real Editor time for AnimGraph authoring rather than expecting a scripted fix, (3) the `.usmap`-loaded UAssetAPI parsing capability found here should be reached for immediately on any FUTURE base-game-asset investigation in this project, not rediscovered.


**Files touched**: `main.lua` (staged Read Current restructure, VERBOSE-gate fix); `spawner.lua` (belt/strap single-pass fix, Barbie auto-save settle delay, instance-label ground-truth fix, VERBOSE-gate fix in the pose-read checkpoints); `config.lua` (`CUSTOM_READ_STEP_SPACING_MS` new, `RESTORE_POSTPROCESS_SPACING_MS` widened); `RE-UE4SS` submodule (updated 107 commits, submodules resynced); `UE4SS.dll`/`LivingBaseSpawnMenu.dll` (rebuilt + redeployed).

### 19as. Barbie auto-save on placement re-enabled via a direct, read-free write instead of the disabled `SaveCustomState` call (2026-09-19)

RedFalcon, on hearing the Barbie auto-save was still disabled (19ah/19ai): "I think its fine to treat the barbies as is. What we should do is, we know exactly what they are spawning with, so when writing the initial persist after placing, we should just write what needs to be done. They are supposed to be naked except for underwear, so we add that to the custom persist right away instead of calling save." A genuinely simpler framing than "fix the crash" -- the crash only ever happened because `Spawner.SaveCustomState` needs to READ the actor's live `BuildedCompositeMeshes` to know what to save, and that read is what dies right after the underwear-strip burst (confirmed across multiple settle-delay attempts in 19ai). But a freshly-placed Barbie's post-strip look isn't actually unknown -- `pollForBuildThenUndress`'s own `Spawner.RemoveClothingOnActor(actor, "all", name)` call *always* produces the exact same outcome: every real clothing slot hidden, Torso/Legs specifically substituted with the sex-appropriate underwear piece (unless `Config.CLOTHES_UNLOCK_ALL`). Nothing to read; it's the same fixed state every time.

**Fix**: new `Spawner.WriteBarbieDefaultCustomState(actor, say)` (`spawner.lua`, right after `Spawner.RemoveAllClothes` -- needs `CLOTHES_SLOT_KEYS`, a `local` declared further down the file than `SaveCustomState` itself lives, so it couldn't sit next to its sibling function without hitting the forward-reference trap, see `feedback_lua_forward_reference_check`). Looks up the actor's own `Spawner.spawned` label (same join key `SaveCustomState` uses) and writes a fixed line set straight to that `[label]` block via `CS.readBlocks`/`CS.writeBlocks` -- `CLOTHESITEM:<slot>:(Remove)` for all 8 `CLOTHES_SLOT_KEYS`, `BELTPIECE:<type>:None` for all 4 belt-piece types (Belt/Sling/Strap/Frog) -- zero calls that touch the actor's composite-mesh state at all. These are the exact same wire-format lines a live "Remove All" + "None" on every belt slot would produce, so restore-time replay (`CS.applyLine` -> `Spawner.RemoveClothesItem`/`Spawner.ApplyBeltStrapPiece`, both unchanged) still correctly resolves Torso/Legs to underwear (or the Female Senkamati substitution) based on the actor's own live sex/archetype AT RESTORE TIME -- that logic was never baked into the saved line, so nothing about it needed duplicating here.

Wired into `Spawner.ConfirmPlacement`'s existing Barbie-only block (`Spawner._placementIsBarbie`), replacing (not restoring) the disabled read-based auto-save call -- the old `Spawner.SaveCustomState` call is left in place, commented out, as the historical record of why a read-based approach doesn't work for this specific timing window, per this project's own "shelve, don't delete" convention for a failed-but-informative attempt.

**Files touched**: `spawner.lua` (`Spawner.WriteBarbieDefaultCustomState`, new; `Spawner.ConfirmPlacement`'s Barbie auto-save block). Lua-only, deployed live via file copy -- no restart needed (`lbreload`-able).

### 19at. "Mobile Marita" -- RESOLVED. The locomotion-animation gap from 19ar was never real; it was a stale-AnimInstance bug from applying `lbtestanimclass` AFTER spawn, and fixing that alone gave her fully real, native walk animation -- no custom AnimBP, no per-tick hook, needed after all (2026-09-19/20)

RedFalcon, picking 19ar's two candidate fixes back up: "per tick would look bad, so lets look at [the custom AnimBP] to see how native we can make it." First step was to actually read `ABP_Human_NPC_C`'s own graph (via the `.usmap`-loaded UAssetAPI technique, extracting it fresh with `retoc gen-script-objects` + `to-legacy`) to see whether it already computes locomotion internally or truly depends on external per-tick pushes -- **the cooked asset only contains `AnimNodeData`/`NodeTypeMap`/`TargetSkeleton`, a compiled bytecode representation, not readable Blueprint graph logic.** Same "graph stripped in this cooked build" wall this project already hit once on `MF_CharacterSkinAging`. This ruled out reading the answer directly and pointed at the cheaper empirical test instead: dump Marita's own LIVE AnimInstance values while she's actually moving, side by side with a real walker's own live values while it's moving -- a comparison 19ar's own investigation never actually did (it only ever compared an idle Gatherer against a POSED Gatherer, to rule out `AnimationData`/pose-locking, not this).

**That comparison immediately found the real bug, and it wasn't the one 19ar diagnosed.** Three fresh `lbdumpanim` captures on Marita (spawned via `lbtestai` then `lbtestanimclass`, ~23 seconds apart) all showed `AnimClass=ABP_Human_NPC_C` in the header line -- but `RuntimeAnimInstanceClass=ABP_StandingNPC_Regular_AI_C` underneath it, and the full `ANIMINSTANCE` property walk confirmed her live instance's actual class chain was still `ABP_StandingNPC_Regular_AI_C -> R5PawnAnimInstance -> AnimInstance -> Object` -- her original static idle AnimBP, with none of `GroundSpeed`/`ShouldMove`/`IsWalking?`/etc. even present, because that class never declares them. A same-moment Gatherer dump, for contrast, showed `RuntimeAnimInstanceClass=ABP_Human_NPC_C` with real live values (`GroundSpeed=109.9`, `ShouldMove=true`, `IsWalking?=true`).

**Root cause**: `Spawner.SetAnimClass`'s `skipForceRebuild=true` bare property write (`mesh.AnimClass = cls`, deliberately avoiding `SetAnimInstanceClass`'s confirmed crash history, see that function's own header) only actually takes effect the FIRST time an actor's `AnimInstance` is ever constructed. Marita was already spawned and ticking on her native class by the time `lbtestanimclass` ran, so the write updated the property but left her already-constructed instance completely untouched -- she'd been running her static standing AnimBP the entire time 19ar tested her, never the walking one at all. This directly contradicts 19ar's own claim that the swap "confirmed a fresh AnimInstance genuinely gets built" -- that must have been true under different circumstances (an actor whose instance hadn't been constructed yet), and this session's repeat, on an already-running actor, shows the swap silently doesn't take when done that way. **The entire "locomotion variables need an external per-tick push" diagnosis in 19ar was built on this same false premise** -- comparing an idle vs. posed Gatherer (both real ABP_Human_NPC_C instances) never actually tested whether Marita's OWN instance would populate those fields correctly; it never got far enough to find out.

**Fix**: new `Spawner.TestSpawnWithAIAndAnim`/`lbtestaianim <ClassPath> <AIControllerClassPath> <AnimBlueprintClassPath> [friendly]` (spawner.lua, main.lua) -- sets `deferred.Mesh.AnimationMode = 0` / `deferred.Mesh.AnimClass = animClass` inside `Spawner._DoEngineSpawn`'s existing `preFinish` window (after the actor and its components are constructed, but before `FinishSpawningActor` triggers `BeginPlay`/the real animation build) -- the EXACT same deferred-transaction window `aiControllerClassPath` already uses safely for `deferred.AIControllerClass`. Since her Mesh's very first real `AnimInstance` is now constructed using the new class from the start, there's no stale pre-existing instance left behind to ignore the write -- same safe bare-property mechanism as before, just applied one step earlier in her lifecycle, still zero use of the crash-prone `SetAnimInstanceClass` force-rebuild path.

**CONFIRMED WORKING LIVE, first try**: `lbtestaianim` on Marita's real class + Citizen Walker AIController + `ABP_Human_NPC_C` produced `RuntimeAnimInstanceClass=ABP_Human_NPC_C` on the very first dump, with real live locomotion values (`GroundSpeed=109.99`, `ShouldMove=true`, `IsWalking?=true`) matching a genuine walker exactly -- no custom AnimBP authoring, no `RegisterHook`, no per-tick Lua sync of any kind. RedFalcon: "holey moley, you did it." **Mobile Marita is now fully resolved**: her own real actor, her true look (face morph, tattoos, makeup all intact -- nothing about her CompositeMeshComponent was ever touched), real AI-driven wandering, and now real native walk-cycle animation, all with zero asset edits and zero risk to the original quest NPC.

**General lesson for this project**: `Spawner._DoEngineSpawn`'s `preFinish` deferred window isn't just for `AIControllerClass` -- ANY property that needs to be set before an actor's own construction-time systems (AnimInstance creation, first-tick initialization, etc.) run should go through this same window rather than being patched on after `Spawner.Spawn` returns. A bare property write that works fine on a not-yet-constructed subobject can silently no-op on an already-constructed one -- when a live post-spawn write "takes" on the property but not on its visible behavior, check whether the underlying subsystem was already initialized by the time the write landed, before concluding the property itself needs different data pushed into it.

**Files touched**: `spawner.lua` (`Spawner.TestSpawnWithAIAndAnim`, new, right after `Spawner.TestSpawnWithAIOverride`); `main.lua` (`lbtestaianim` console command registration, right after `lbtestai`'s own block). Lua-only, deployed live via file copy, syntax-verified via lupa before deploying -- no restart needed.

### 19au. Can `lbtestaianim` extend to the other statue rosters? CLOSED -- yes for the 7 named QuestStatic quest-givers (confirmed live), structurally no for everything else (confirmed via class-hierarchy read, not guessed) (2026-09-20)

RedFalcon's natural follow-up once Marita worked: "is this something we can expand onto the other statue NPCs?" The four statue rosters (`STANDING_STATUES`/`SEATED_STATUES`/`CHAIR_STATUES`/`INTERACTIVE_STATUES`, `config.lua`) turned out to be two genuinely different class families, not one:

**The 7 named quest-givers folded into `STANDING_STATUES`** (Francois Arno, Letty, Benjamin Hornigold, Henri Boucher, Marita, Long Ben, Charlie Sharp) are all `BP_NPC_QuestStatic_*` -- the exact same class family as Marita, same `BP_NPC_Base` ancestry. **Confirmed live, all of them**: `lbtestaianim` walks every one with zero changes needed -- RedFalcon: "all the quest npcs walk no problem."

**Everything else across all four rosters** (the vast majority -- Merchants, LeanOnWall/CarpenterIdle/SitterOnGround/SitterOnStool/LookerChest/FireWarm poses, ~70+ entries) is `BP_AnimatedActor_*`/`BP_AnimatedActorVoiced_*` -- confirmed LIVE via `lbtestaianim` on `BP_AnimatedActor_Buccaneers_Merchant_04_C`: `AnimClass` pre-set correctly (pose visibly changed, confirming the write took), `AIControllerClass` write reported success, but the actor never actually walked, and both `lbtestblackboard`/`lbtestaicontroller` immediately showed `actor.Controller missing or invalid`.

**First theory tried and DISPROVEN**: `AutoPossessAI` defaulting to Disabled (a class built for static display never bothering to self-possess). Forced it to `PlacedInWorldOrSpawned` (2) inside the same `preFinish` window the AnimClass fix already used -- the write read back correctly (verified via a read-after-write check added specifically because the first attempt only ever logged the value BEFORE writing) -- but `Controller` was STILL missing/invalid afterward. Ruled out cleanly, not just assumed fixed.

**Real root cause, confirmed via a class-hierarchy read (`GetSuperStruct()` walked leaf-to-root, plus `IsA(StaticFindObject("/Script/Engine.Pawn"))`), not guessed**: `BP_AnimatedActor_Buccaneers_Merchant_04_C -> BP_AnimatedActor_Base_C -> R5AnimatedCustomizableActor -> Actor -> Object` -- **`IsA(Pawn) = false`.** This entire class family isn't `Pawn`-derived at all; it's a lightweight `Actor` subclass purpose-built for frozen posed display, with no `Controller`, no `CharacterMovementComponent`, no possession machinery whatsoever. `AIControllerClass`/`AutoPossessAI` are both `Pawn`-only properties -- writing to them on this class either silently no-ops or writes to a dynamic key with no real UPROPERTY behind it, which is exactly why neither write ever errored but also never did anything.

**CLOSED, not a bug to keep chasing.** Giving the `AnimatedActor` family real walking AI would mean building genuine `Pawn`/`Character`/movement machinery from scratch and grafting their look onto it -- a materially different, much larger undertaking (same category as the SDK-stub "author a genuinely new NPC class" work), not an extension of the `lbtestaianim` recipe. Don't re-attempt an `AIControllerClass`/`AutoPossessAI`-based fix on this family without a fundamentally different starting point (e.g. building a real custom Pawn class in `LivingBaseExtended` that reuses their `CompositeMeshComponent`/look data).

**General lesson**: when a possession-style property write "succeeds" (no error) but produces zero visible effect and a direct read-back also confirms the value stuck, don't keep tuning that property -- check whether the target class is even structurally capable of using it in the first place (a class-hierarchy/`IsA` check, cheap and decisive) before spending more test cycles on property-value theories.

**Files touched this entry**: `spawner.lua` (`Spawner.TestSpawnWithAIAndAnim`'s `preFinish` -- added the `AutoPossessAI` read-back-after-write check and the `IsA(Pawn)`/class-chain diagnostic, both kept in permanently since they're cheap and generally useful for any future "why won't this thing move" question on this same command).

### 19av. "Mobile" versions of the named Quest NPCs SHIPPED as a real spawn-menu feature -- `Spawner.Spawn` gains a first-class, persistable `animClassPath` parameter; two new quest NPCs (Sailor/Ghost Pirate) added, plus a brand-new "Monsterous" root category (2026-09-20)

RedFalcon, once `lbtestaianim` was confirmed working and the statue-family wall was closed (19au): "let's add (Mobile) versions of the default Named Quest NPCs. So Letty (Mobile), Marita Suares (Mobile), Long Ben (Mobile) etc." Plus two newly-found QuestStatic classes: `BP_NPC_QuestStatic_SailorInCage` ("Scared Sailor" idle in People > Standing, "Sailor" mobile in People > Walkers -- "the sailor randomizes so treat it like other randomized npcs," i.e. a generic archetype, not a fixed-identity individual like the other 7) and `BP_NPC_QuestStatic_Ghost_01_WithFXLogic` ("Ghost Pirate," both idle and mobile, under a brand-new root category "Monsterous" -- "we'll be adding more to this category later").

**This promotes `lbtestaianim`'s console-test mechanism into a real, persistable, spawn-menu-integrated feature** -- not just a bigger test command. Real design work needed:

**1. `Spawner.Spawn` gains a first-class `animClassPath` parameter (11th positional)**, rather than every "Mobile" spawn hand-rolling its own `preFinish` closure like `lbtestaianim` does. Resolved once up front (reported via `always()` if unresolvable, matching `aiControllerClassPath`'s own pattern), then composed into `effPreFinish` the SAME way the friendly-faction/composite-look block already composes with any caller `preFinish` -- sets `Mesh.AnimationMode=0`/`Mesh.AnimClass` inside the pre-`FinishSpawningActor` deferred window, exactly the mechanism 19at proved fixes the "bare write only takes on a not-yet-constructed instance" bug. `lbtestaianim`/`Spawner.TestSpawnWithAIAndAnim` itself was left AS IS (its own bespoke `preFinish`, plus the `AutoPossessAI`/`IsA(Pawn)` diagnostics from 19au) rather than refactored onto the new param -- it's a diagnostic tool with extra checks a shipped spawn path doesn't need, no value in coupling them.

**2. Persisted as persist.txt's own NEW field 17**, so a restored "Mobile" NPC keeps its walk animation across a world reload, not just its AI controller (which field 5 already covered). Checked `Spawner.PersistUpdateLootMesh` (the field-16 writer) before adding this -- it sets `bestParts[16]` directly by array index, not by string length, so it's unaffected regardless of whether `persistAppend` emits a field-16 placeholder; confirmed safe to add field 17 unconditionally. `persistAppend` now always writes an explicit empty field 16 (previously never written by this function at all, only by that separate updater) immediately followed by the real field 17 value -- same "gap, not a gap" positional-safety approach that field's own 2026-08-19 addition established. `restoreOne` parses field 17 and threads it straight through to the restore-time `Spawner.Spawn` call.

**3. A real cross-roster label collision found and avoided BEFORE it shipped, not after.** `Spawner.FriendlyLabels` (main.lua) is a flat map keyed purely by short class name, populated by iterating `SPAWN_MENU_STATUE_ROSTERS` and reading each row's own spawn_menu.ini `label=`. Since a "Mobile" spawn shares its exact class with an EXISTING `STANDING_STATUES` entry (Marita's idle and mobile versions are the same class), registering the new roster there too would let two DIFFERENT labels ("Marita Suares (Idle)" vs "Marita Suares (Mobile)") race to overwrite the SAME map key, with the winner decided by Lua's unspecified `pairs()` iteration order -- a real, silent, hard-to-reproduce bug if shipped. **Fix**: `Config.MOBILE_QUEST_NPCS` rows carry an explicit, REQUIRED `label` field, used verbatim by the new `placeMobileQuestNPC` (testbed.lua) instead of any `FriendlyLabels` lookup -- and its `SPAWN_MENU_HANDLERS` entry (main.lua) is a bespoke, hand-written dispatcher, deliberately NOT registered in `SPAWN_MENU_STATUE_ROSTERS` at all, so it never enters that shared-key population loop in the first place. `Config.MONSTEROUS_STANDING` (Ghost Pirate's idle version) has no such collision -- its class is unique -- so it's registered normally.

**4. `spawnmenu_manifest.lua` gained two new descriptors** (`monsterous_standing_path_and_label`, `mobile_quest_npc_path_and_label`) computing the EXACT category paths RedFalcon asked for from the very first auto-generation pass, rather than the usual "generate at a mechanical default, reorganize by hand afterward" flow every other roster in this file uses -- `mobile_quest_npc_path_and_label` defaults to `People.Named.<label>` (sibling to each NPC's existing "(Idle)" entry, matching the live file's own already-hand-curated convention) but honors an optional per-row `menuPath` override for the two exceptions (Sailor -> `People.Walkers`, Ghost Pirate -> `Monsterous.Walkers`). **The one exception needing a hand-placed entry**: "Scared Sailor," appended to the LEGACY `STANDING_STATUES` table (index 39) -- that roster's own decades-old descriptor (`statue_path_and_label("Standing")`) generates at `{"Standing", faction}` with the raw class name as the leaf, which doesn't match the live file's actual hand-curated `People.Standing.<friendly name>` structure at all (every existing entry there was ALSO manually reorganized at some point) -- hand-wrote `[People.Standing.Scared Sailor]` directly into `spawn_menu.ini` with the correct `roster=STANDING_STATUES`/`index=39` bookkeeping fields, so the generator's own `existing_roster_indices` check recognizes it as already-seen and never produces a conflicting mechanical duplicate.

**Verified via a real offline harness, not just a syntax check** -- `lint.py` (this project's own pre-flight checker) has a pre-existing, unrelated gap (its minimal `require()` stub doesn't handle `fkeys`/`spawnmenu_manifest`, a gap that predates this session), so a standalone scratchpad script stubbed `require` properly, ACTUALLY EXECUTED `config.lua` + the real `spawnmenu_manifest.lua` together against a disposable copy of `spawn_menu.ini`, and confirmed the generator produces exactly the right output: `People.Named.<Name> (Mobile)` x7, `People.Walkers.Sailor`, `Monsterous.Walkers.Ghost Pirate (Mobile)`, `Monsterous.Standing.Ghost Pirate` -- all auto-generated correctly, zero hand-editing needed for any of them (only the legacy-table "Scared Sailor" entry needed a manual placement, per point 4 above). `lint.py`'s own `check_module_members()` (verifies every `Testbed.X(...)`/`Spawner.X(...)` call resolves to something actually defined) ran clean against all the new code.

**CONFIRMED WORKING LIVE, same session** -- all 9 new spawn-menu entries placed correctly, real AI movement + real walk animation confirmed immediately on spawn (no post-spawn delay needed, exactly as the deferred-window design predicted), and a full world restart confirmed the Mobile NPCs restore correctly with both AI and animation intact. Two real bugs were found and fixed along the way (both covered in their own entries, 19au/this section): the drag-and-drop/live-placement-preview gap for `MOBILE_QUEST_NPCS` (missing from the allowlist), and Ghost Pirate's own `GetActorBounds`-vs-FX-components floor-detection bug (fixed via a bounds-then-bone-query fallback). RedFalcon, after the final respawn-after-restart test: "they worked and properly respawned before so i think we can confidently say thats resolved." Feature is DONE, not a follow-up item.

**One more real gap found and fixed the same day: the Custom tab's own "AI Toggle" button was greyed out for every Mobile spawn.** RedFalcon: "is there a way to enable the ai toggle for these new mobile entries." Root cause: `currentLockedTargetInfo` (main.lua) computes the `TARGET_STATIC` flag (which `CustomMenu.cpp` reads to grey out the "Disable/Enable AI" button, tooltip: "Statues and decor have no AI to toggle") via a plain class-NAME substring check -- `lt.class:find("AnimatedActor")` or `find("QuestStatic")` -- written back when every `QuestStatic`-family class genuinely never had a Controller, so the name alone was a reliable proxy. The new Mobile spawns are QuestStatic-family classes that NOW carry a real `AIController` (19av's whole point) -- the name-only heuristic doesn't know that and greys them out anyway. **Fix**: a live Controller check (`lt.actor.Controller ~= nil and :IsValid()`, the same "actor.Controller missing or invalid" read `lbtestblackboard`/`lbtestaicontroller` already use) overrides the class-name heuristic to "has AI" whenever a real Controller is genuinely attached, regardless of class name -- never flips the other direction (a missing controller doesn't force `isStatic=true`), so decor/other non-statue classes are unaffected. `Spawner.SetAILogic`'s own `StartLogic`/`StopLogic` calls already work on any real Controller regardless of class, so no change was needed on that side -- this was purely a UI-gating gap.

**Files touched**: `spawner.lua` (`Spawner.Spawn`'s new `animClassPath` param + composition, `persistAppend`'s new field 17, `restoreOne`'s field-17 parse); `config.lua` (new `Config.MONSTEROUS_STANDING`/`Config.MOBILE_QUEST_NPCS`/`Config.MOBILE_QUEST_NPC_AI_CONTROLLER`/`Config.MOBILE_QUEST_NPC_ANIM_CLASS`, "Scared Sailor" appended to `STANDING_STATUES`); `spawnmenu_manifest.lua` (two new descriptors + `roster_descriptors()` entries); `testbed.lua` (`Testbed.SpawnMonsterousByName`, `placeMobileQuestNPC`, `Testbed.SpawnMobileQuestNPCByName`); `main.lua` (`MONSTEROUS_STANDING` added to `SPAWN_MENU_STATUE_ROSTERS`, bespoke `MOBILE_QUEST_NPCS` handler in `SPAWN_MENU_HANDLERS`); `spawn_menu.ini` (hand-placed `People.Standing.Scared Sailor` entry; the other 10 sections are auto-generated on the next load/reload, not hand-written).

**Real gap caught same day, before any live test: live-placement preview ("drag it into place") was missing for every one of the 9 new Mobile spawns.** RedFalcon: "i think you forgot to add the drag and drop options to the new walkers." `pollSpawnMenuRequest`'s own `Spawner.StartPlacementPreview` call is gated by an explicit roster allowlist -- `MONSTEROUS_STANDING` got it for free (registered in `SPAWN_MENU_STATUE_ROSTERS`, which the allowlist also checks), but `MOBILE_QUEST_NPCS` was deliberately kept OUT of that same table (see point 3 above, the `FriendlyLabels` collision) and was never added to the allowlist's own separate explicit roster-name list either -- a freshly-spawned Mobile NPC would have immediately started wandering under its own AI with no drag-to-position step at all. Fixed by adding `roster == "MOBILE_QUEST_NPCS"` directly to that allowlist condition -- a plain, independent check, unrelated to the `FriendlyLabels` mechanism, so this carries none of the collision risk the table-registration itself would have. `Spawner.StartPlacementPreview` already handles stopping/resuming AI correctly during the drag for every other AI-driven walker roster (`TOWNSFOLK_CLASSES`/`FACTION_VISITOR_LOOKS`/`SENKAMATI_LOOKS`), so no further change was needed once the gate itself was fixed.

**A SECOND, genuinely different "doesn't drag and drop" bug found the same round, this time on Ghost Pirate's IDLE version specifically**: RedFalcon: "placing the idle ghost pirate also doesnt drag and drop." The log showed `StartPlacementPreview` DID fire correctly (`isStatue=true`, matching every other statue) -- but `bottomOffset=-1462.4`, wildly outside every other statue's own range (Scared Sailor, same session: `-96.75`). Root cause: `computeStatueBottomOffset`'s own `GetActorBounds(false, origin, extent, false)` call measures the actor's FULL aggregate bounds, including whatever particle/FX components `Ghost_01_WithFXLogic`'s own "WithFXLogic" suffix implies -- the exact same "`GetActorBounds` returns unreliable values on a component-rich actor" class of bug this project already hit once on skinned meshes during the Height slider work (19ap), just triggered by FX components instead of skin-scale caching this time. Floor-lock then tried to plant the actor ~14 meters below the actual raycast hit point every frame -- reads as "doesn't drag" (the actor effectively vanishes underground) even though the mechanism itself fired correctly the whole time.

**First fix attempt (nil-fallback) was insufficient, caught immediately**: a sanity clamp returning `nil` (no floor-lock at all) stopped the underground-teleport symptom, but RedFalcon reported the real regression it introduced right away: "the ghost lets me place it through the floor and doesnt detect the ground properly" -- giving up floor-locking entirely just traded "always wrong" for "never locks," not an actual fix.

**Real fix**: `computeStatueBottomOffset` now tries a LIVE bone query as a RESCUE specifically when the bounds-based measurement is out of range, rather than giving up. `GetActorBounds` stays the PRIMARY measurement for every statue, completely unchanged -- deliberately NOT switched to bone-based for everything, since a "root" bone doesn't necessarily track a SEATED/CHAIR-posed character's actual lowest point the way it does a standing one, and this project has dozens of already-working seated/chair/interactive placements riding on the existing bounds-based math; re-validating a wholesale switch per-pose wasn't worth the regression risk to fix one FX-heavy statue. Only when the bounds result fails the same 300uu sanity check does it fall through to `mesh:GetSocketLocation(FName("root"))` -- the same live "root" socket query the Height slider work (19ap) already proved reliable on this game's human skeleton family, immune to whatever FX/particle components inflate `GetActorBounds`' aggregate, since it reads one fixed bone transform instead of aggregating every component's bounds. Only truly falls through to `nil` (no floor-lock) if BOTH measurements fail or land outside the sane range. `always()` logs at each stage (bounds rejected, bone-query result, or total failure) so a future FX-heavy statue's exact failure mode is visible in the log, not guessed at. Hit this project's own 200-local ceiling adding the fix -- inlined the `300.0` sanity threshold as a literal rather than a new top-level local. **Confirmed working live** -- log showed the bone-query rescue firing correctly (bottomOffset settling at a normal -93.0), RedFalcon confirmed the drag/floor-detection now works.

**A crash and a "didn't move" report on Ghost Pirate (Mobile), both traced to reload-accumulated instability, not new bugs.** After placing the idle Ghost Pirate successfully, RedFalcon placed the Mobile version -- it didn't wander, and the game crashed shortly after while moving around. `parse_minidump.py` on the resulting fresh dump (`crash_2026_09_20_01_36_28...dmp`) confirmed the crash landed inside `UE4SS.dll` itself (`EXCEPTION_ACCESS_VIOLATION`, offset `0x86f59d`), not the game's own exe -- this project's own long-documented "general reflection-bridge instability" signature, not obviously tied to any specific Lua logic. RedFalcon's own correct instinct: "sometimes an in game reload causes issue so lets see what happens on a fresh start" -- this whole session had gone through many `lbreload` cycles testing every new roster entry back to back. **Confirmed on an actual fresh world load (not `lbreload`): the Mobile Ghost Pirate's AI walking worked correctly.** Both symptoms (the crash and the stationary AI) are almost certainly downstream of reload-cycle state buildup, not defects in the new Mobile-spawn feature itself -- consistent with this project's own repeated prior finding that `lbreload`-heavy test sessions are a known source of instability distinct from the code being tested. Not chased further as a code bug without a fresh-start reproduction.

### 19aw. Frame-by-frame pose scrubber shipped -- `lbposescrub`/`lbposenext`/`lbposeprev`/`lbposeplay`/`lbposepause`, plus a live UE4SS gotcha (a struct field that reads back non-numeric) and a wall-clock-based live-position tracker that replaced an unreliable engine readback (2026-09-21)

RedFalcon, after the pose-color-picker tangent: "let's do it frame by frame so i can see how it looks." Built on the exact single-node-AnimInstance mechanism `Spawner.ApplyPose`/`TestApplyPoseByPath` already proved safe (`PlayAnimation` into single-node mode, `SetPosition` to hold an exact time) -- `Spawner.PoseScrubStart` adds a persistent scrub cursor (`Spawner.poseScrub`) so step/play/pause can act on it afterward without re-resolving the target or re-applying the sequence each time.

**Real UE4SS gotcha: a struct field that resolves non-nil but reads back as an unusable, non-numeric value.** First attempt read the sequence's own real sampling-frame-rate struct (`Numerator`/`Denominator`) to compute exact per-frame timing -- crashed live: `attempt to compare number with TrivialObject`. The struct field itself resolved (not nil), but its OWN sub-fields (`Numerator`/`Denominator`) came back as some non-numeric userdata rather than plain Lua numbers -- meaning neither `SamplingFrameRate` nor `PlatformTargetFrameRate` is a real, populated property on this game's `UAnimSequence`, and an unknown-property read apparently returns a placeholder object here rather than nil or erroring outright. Fixed by type-checking (`type(num) == "number"`) before comparing, falling through to a flat FPS guess (`Config.POSE_SCRUB_FALLBACK_FPS`, default 30) instead of crashing -- same "a property that resolves cleanly can still not be a real, usable value" class of gotcha this project has hit before (see the public notes' own §21), just manifesting as a non-numeric struct field this time instead of an empty read.

**Live-position tracking: reading the engine's own `AnimInstance.CurrentTime` back turned out to be unreliable -- replaced with plain wall-clock tracking instead.** The Play/Pause buttons need to report which frame a currently-PLAYING sequence is actually on (for the UI's own scrub slider). First attempt read `mesh:GetAnimInstance().CurrentTime` back on every status poll -- CONFIRMED WRONG live: the log showed "paused at frame 0/36" after several real seconds of visible playback, meaning that read was silently returning a value that never advanced. Rather than chase the correct property name/type on this build, replaced it entirely with wall-clock tracking in Lua (`os.clock()`, already proven reliable for sub-second timing elsewhere in this file) -- record a `(startClock, startFrame)` pair the moment Play/Seek runs, then compute the current frame as `(startFrame*frameTime + elapsed) % length` on every status read, wrapping correctly for a looping clip. **General lesson: when an engine-side "give me the current playback position" property is available, don't assume it's live/correct just because it resolves without error -- if the reported value doesn't visibly track real playback, tracking the same thing yourself from a known start point plus elapsed wall-clock time is a reliable, low-risk substitute already validated elsewhere in this codebase.**

**Looping**: RedFalcon: "i'd like the played animation looped." `PlayAnimation(seq, bLooping)`'s `bLooping` argument is the actual native parameter that builds the `AnimSingleNodeInstance` in the first place -- set to `true` on the initial call (not left as the scrub-tool's original `false`, which only mattered for the frozen-at-frame-0 console-only use case) rather than relying on a separate post-hoc `SetLooping(true)` call alone.

**Files touched**: `spawner.lua` (`CS.ResolveSequenceFrameInfo` shared helper, `CS.LiveScrubFrame`, `Spawner.PoseScrubStart/StartAndPlay/Step/Seek/Play/Pause/GetStatus`); `main.lua` (`lbposescrub`/`lbposenext`/`lbposeprev`/`lbposeplay`/`lbposepause` console commands, plus the Custom-tab request/status bridge -- see 19ax for the UI side).

### 19ax. Custom tab gains 4 categorized Left/Right Hand item dropdowns (Weapons/Tools/Bottles/Other) and 12 new poses from a new "additional poses"/"Tools" tab in `Other\SocketItems.xlsx`; `Config.CUSTOM_POSES` gains multi-level subcategory support (2026-09-21)

RedFalcon: "let's populate the hand dropdowns. I want to make 4 dropdowns, they all override each other... treat it like the belt sockets." The "Tools" tab in `SocketItems.xlsx` (93 rows: Friendly Name/Type/Mesh, Type is exactly Weapons/Tools/Bottles/Other) became a new `Config.SOCKETITEMS_TOOLS` table, generated by `gen_socketitems_lua.py`'s own new "Tools" section. `Spawner.ApplySocketItemManual`'s friendly-name lookup now checks this table as a fallback after `Config.SOCKETITEMS_ITEMS` -- confirmed zero name collisions between the two tables (some overlap exists between Tools and the separate, unrelated `SOCKETITEMS_WEAPONS` table, but that one is never consulted by this lookup, so no ambiguity).

**UI mechanics, matching the belt-socket convention exactly**: `g_handCategorySelected[2][4]` (hand x category), each of the 4 dropdowns defaults to showing its own category name (Weapons/Tools/Bottles/Other) via `DrawBeltAccessoryCombo`'s existing `defaultLabel` parameter -- no new widget code needed. Picking an item in ANY of the 4 for one hand clears the other 3 for that same hand (only one item can occupy a hand) and applies it via the existing `WriteSocketItemRequest` -> `Spawner.ApplySocketItemManual` pipeline (the real IK sockets, `ik_weapon_lSocket`/`ik_weapon_rSocket`, were already wired for the X-button "clear" case, just never had a real item list). Picking "None" (any of the 4) clears the whole hand, same as the X button.

**Read-back gap closed too**: `ik_weapon_lSocket`/`ik_weapon_rSocket` were never part of `Config.SOCKETITEMS_SOCKETS` (that table is belt/sling/strap accessory sockets only) or `TestReadSocketAccessories`'s own sweep -- meaning "what's in this hand" was never detectable at all before this. New `Spawner.TestReadHandItems` does a small dedicated `CS.sweepAttachedMeshes` read on just those two sockets, resolving friendly names against `SOCKETITEMS_ITEMS` then `SOCKETITEMS_TOOLS` (same two-table order as the apply side). Wired into both the Read Current status build (`HANDITEM:Left:<name>`/`HANDITEM:Right:<name>` lines) and `BuildCustomStateLines`/`CS.applyLine` (Save Customizations now persists and restores a held hand item too, with no baseline diff since this category never had one to begin with).

**`Config.CUSTOM_POSES` subcategory nesting**: the same spreadsheet's "additional poses" tab (12 rows: Fishing Armed/Reel In/Idle, plus 8 "Drink Holding <weapon>" variants) needed a menu path TWO levels deep under `topCategory` ("Standing" > "Food and Meds" > "Drink" > "<name>") -- the first time this table has ever needed more than one subcategory level. `subCategory` can now be either a plain string (every existing row, unchanged) or a list of strings for deeper nesting; `spawnmenu_manifest.lua`'s `custom_poses_path_and_label` walks the list when present. The sheet's own Path column had a stray trailing " ik_weapon_rSocket,ik_weapon_lSocket" fragment (leftover test-command-argument text) on the 8 Potion rows -- stripped by splitting on the first space before using the path.

**Files touched**: `config.lua` (`Config.SOCKETITEMS_TOOLS`, 12 new `Config.CUSTOM_POSES` rows); `gen_socketitems_lua.py` (new "Tools" tab section); `spawner.lua` (`ApplySocketItemManual`'s TOOLS fallback, `Spawner.TestReadHandItems`, `BuildCustomStateLines`/`CS.applyLine` HANDITEM lines); `spawnmenu_manifest.lua` (list-aware `custom_poses_path_and_label`); `main.lua` (HANDITEM read-current line, hand-item request/status bridge); `CustomMenu.cpp` (`kHandWeaponNames`/`kHandToolNames`/`kHandBottleNames`/`kHandOtherNames`, `kHandCategoryRows`, `g_handCategorySelected[2][4]`, the 4-dropdown-per-hand draw loop).

### 19ay. Any NEW spawn now faces the player while being dragged into place (RELOCATE unaffected); manual rotation during placement takes precedence once used (2026-09-21)

RedFalcon: "for anything spawned... as you drag it around, its rotation follows yours, so for example, the person spawn will always be looking towards you while being spawned. no rotation when relocating would be good though." `beginFollowLoop`'s own `tick()` had never once touched rotation before this (only ever called `K2_SetActorLocation`) -- confirmed by reading the whole function, which meant RELOCATE already satisfied the "no rotation change" half of the request for free, no code needed there at all.

Added: right after the per-tick location set, if `Spawner._placementMode == "NEW"` (never `"RELOCATE"`) and the player hasn't manually rotated this session (`Spawner._placementManualRotate`, set by `Spawner.RotatePlacementActor` -- the existing numpad ROTATE-mode control during placement), computes `faceYaw = cameraYaw + 180` (the object sits along the camera's forward ray, so facing back down that same ray points it at the player) and calls `K2_SetActorRotation` with Pitch/Roll forced to 0 (upright, not tilted to match camera pitch). `Spawner._placementManualRotate` resets to `false` at the start of every new `StartPlacementPreview` session, so a deliberate manual rotation sticks for that session instead of being fought back to face-player on the very next 33ms tick, and the auto-face behavior is fresh again for the next spawn.

**Files touched**: `spawner.lua` (`beginFollowLoop`'s `tick()`, `Spawner.RotatePlacementActor`, `Spawner.StartPlacementPreview`'s session-start reset).

### 19az. "Photo Mode" tab shipped: a real, non-persistent 3-slot Lights system (Enable=spawn/Disable=despawn, Color/Brightness/Throw Distance/Spill Shield Distance/Size/Show Spill Shield), plus several real engine gotchas found productionizing the existing tilt-light tool for continuous drag-placement (2026-09-21)

RedFalcon shared a UI mockup (Camera + up to 3 Lights, each with Enable/Color/Show Spill Shield/Brightness/Throw Distance/Spill Shield Distance/Spill Shield Size) and asked for a plan before building; agreed scope: reuse the exact spawn/placement/persistence machinery every other Spawn Menu item already has, built the Lights half first (`Spawner.Lights[1..3]`), then a dedicated "Photo Mode" tab (not folded into "Custom") once it worked.

**`Spawner.Spawn` silently persists everything it spawns -- had to be explicitly stripped for a "not persistent" feature.** The mesh-resolution helper (`CS.SpawnPlateMeshActor`, a deliberate SEPARATE copy of `Spawner.TestSpawnTiltedLitMesh`'s own 3-route DA_BI_/`_C`-class/generic-StaticMeshActor logic, kept separate so an edit to one can never regress the other's already-tuned behavior) calls `Spawner.Spawn` for all 3 routes, which appends a `persist.txt` line by default. Fixed by calling `Spawner.PersistRemoveLast()` immediately after each spawn call -- the actor stays in the in-memory `Spawner.spawned` list (so every generic move/rotate/target-lock system still works on it normally), only the on-disk record is stripped. `Spawner.DisableLight` uses the existing general `Spawner.DespawnActor` (not a bare `K2_DestroyActor`) for symmetric cleanup (removes the `Spawner.spawned` entry, releases any target lock); its own `PersistRemoveMatching` call is a safe no-op since the line was already gone.

**A real building-block-vs-drag conflict, TWICE.** Two different structural attempts at giving the light+plate rig a genuinely inverted pivot (light as the anchor, plate swinging around it, matching RedFalcon's original "rotation should occur at the light point" spec) both hit the SAME class of bug and were abandoned in favor of the plate-as-pivot structure `Spawner.TestSpawnTiltedLitMesh` already proves works:
- `actor:SetRootComponent(lightComp)`/`actor:K2_SetRootComponent(lightComp)` (a real `AActor` UFUNCTION, never used elsewhere in this file) was tried to promote the light to root -- **confirmed to fail every single time in live testing**, both spellings, with no working case ever observed. The code correctly logged and branched on this (so the rig kept functioning either way), but after enough live testing turned up more problems downstream of the branching complexity itself, RedFalcon called it: "let's just do it the same as `lbtesttiltlight` and let the plate be the pivot point again." All the dead root-swap branching was removed rather than kept for a path that's never taken -- **general lesson: if a fallback branch has a 100% failure rate across every real test, that's a signal to simplify to the branch that actually runs, not to keep polishing dead code.**
- Separately (still while the inversion attempt was in play): attaching the wrong component as a child of the other, unconditionally, regardless of whether the root-swap had actually succeeded, silently broke rendering entirely ("nothing spawned," no error) -- reparenting a component that's STILL the actor's own root underneath a sibling component of the same actor is structurally invalid. **General lesson: any code that conditionally promotes a different component to root must gate EVERY downstream attach/offset decision on whether that promotion actually succeeded, not just the specific write it happens to be guarding.**

**Wrong offset axis, root-caused via a working reference command instead of guessing.** RedFalcon: "it looks like the light is inside the plate," followed by "this is the command that was used before to calculate defaults and works perfectly" (`lbtesttiltlight goblet 90 15 1 1000 500`) and "its a plate so its quite thin." The new code offset the light along the plate's local X; `Spawner.TestSpawnTiltedLitMesh` offsets along local Z specifically BECAUSE, after the shared 90-degree pitch, local Z is the axis that ends up pointing toward the mesh's real post-tilt "top" -- X is roughly along a thin plate's own flat/thin dimension, so even a real 15uu offset there barely clears the mesh. Switched to Z, matching the proven tool exactly, rather than assuming the offset distance itself was too small (the identical 15uu value was already proven correct on the same mesh, just on the right axis). **General lesson: when a new feature's own tuned default doesn't look right, check whether an EXISTING, already-proven-correct tool uses the same numeric value on a DIFFERENT axis/parameter before concluding the number itself needs retuning.**

**Physics-depenetration ejection, a recurrence of an already-documented bug class.** RedFalcon: "it appears for a second and then disappears" / "its shooting really far off." Log showed a real actor DESTROYED itself a few seconds after spawn while being dragged (`Target lock released: target despawned`). This project has hit the exact symptom before (`Spawner.SetDecorSolid`'s own header: "a buried, physics-simulating prop got shoved upward by depenetration") -- a mesh coming off `R5BuildingBlock`'s native construction can inherit live physics simulation, and forcibly teleporting it every follow-loop tick while overlapping other geometry lets the physics engine "correct" the overlap by shoving it away, hard enough to eventually fly out of the loaded world. Fixed with the same explicit `SetSimulatePhysics(false)` `SetDecorSolid` already uses.

**Floor-lock exemption for lights accidentally disabled wall-avoidance too -- they were bundled in the same code path.** RedFalcon: "treat it as if floor clipping is on, so that it can be lifted into the air," then separately "its spawning, just it spawns far away, and i have a wall in front of me." A new `CS.IsLightActor` check exempts lights from the floor-snap-to-ground behavior in `beginFollowLoop`'s `wantFloorLock` computation -- but the SAME `if Spawner._placementStatueBottomOffset then ... end` block also contains a genuinely general-purpose forward raycast (lands the target on whatever solid geometry it hits first along the camera's view -- a wall included, not just a floor; only the trailing `- bottomOffset` subtraction is floor-specific), gated on that same non-nil check. Exempting lights from floor-lock also skipped this raycast entirely, so a light went straight to the raw camera-ray endpoint at the full placement distance regardless of any wall in the way. Fixed by widening the gate to `Spawner._placementStatueBottomOffset or CS.IsLightActor(...)` and defaulting `bottomOffset` to `0.0` for the light case -- reuses the exact same raycast, just with no floor-anchoring subtraction, landing on the first hit surface (wall, table, floor) or floating free in open air if nothing's hit. **General lesson: before exempting a new object type from one behavior gated behind a shared boolean/nil check, read the WHOLE block that check guards -- a single flag can bundle two logically separate behaviors (here: "snap to floor" and "stop at solid geometry") that a new caller may want split apart, not both-or-neither.**

**Placement start distance needed its own tuned constant, not a shared one.** `StartPlacementPreview`'s own fallback (`Config.PLACEMENT_START_DIST_UU`, 1800uu) is decor/statue-scale, far too distant for a light meant to sit near the player; the shared free-build constant (`Config.PLACEMENT_FREEBUILD_START_DIST_UU`, 450uu) turned out to be "right in the player's face" specifically for a light. Settled on a dedicated `Spawner.LIGHT_START_DIST_UU = 600.0`, passed explicitly to `StartPlacementPreview`'s optional distance parameter -- reusing an existing tuned constant across two different features is only safe when both features actually want the same felt distance; when they don't, give the new one its own constant rather than force a shared value to serve two purposes.

**Live light properties (Color/Brightness/Throw Distance) didn't visually update until an UNRELATED change (e.g. toggling the shield) happened to force a refresh.** `MarkRenderStateDirty()` alone was not enough, matching a real prior finding in this same file's own belt-lantern history: the actual fix there was a genuine `SetVisibility(false)` -> writes -> `SetVisibility(true)` transition, not a single already-visible `SetVisibility(true)` or `MarkRenderStateDirty()` call alone. Applied to `SetLightColor`/`SetLightIntensity`/`SetLightThrowDistance` -- wrap each property write in a visibility-off-then-on bracket. **General lesson, now confirmed twice on light components specifically: a live property write on an already-rendering light can succeed at the data level and still not visually refresh without a real visibility toggle around it -- don't assume `MarkRenderStateDirty()` alone is sufficient just because it works for other component types.**

**The "spill shield" wasn't shielding anything.** A leftover, unconfirmed idea from an earlier (reverted) conversation about the UNRELATED generic tilt-light tool -- "should a decor marker cast an unwanted shadow while being positioned" -- had been carried into this feature's own `EnableLight` as `mc.CastShadow = false`. But a spill shield's entire purpose is to block/shape light, so it needs the OPPOSITE: real shadow-casting, same as `Spawner.TestSpawnTiltedLitMesh`'s own plate already has. Fixed to `true`; "Show Spill Shield" unchecked (`SetVisibility(false)`) already naturally stops a hidden primitive from casting a shadow at all (`bCastHiddenShadow` defaults false), so no separate toggle was needed for the passthrough behavior -- this was simply the wrong default, not a missing feature. **General lesson: a design decision discussed and then explicitly reverted/paused in one conversation can still leak into a LATER, different feature's implementation if the two are conceptually adjacent -- worth double-checking a carried-over default actually matches the NEW feature's own purpose, not just the old one's.**

**Tab reorganization**: `CustomMenu.cpp`'s `DrawLightsSection` (and its state/polling helpers) lives in an anonymous namespace with internal linkage; exposing it to a DIFFERENT tab required a plain externally-linked one-line forwarder (`CustomMenu::DrawLightsSection() { DrawLightsSectionImpl(); }`) declared in the header, same "extract just the entry point" pattern `DrawTargetHeader` already established for cross-file calls. New "Photo Mode" tab added to `StandaloneWindow.cpp` on F7 (confirmed free -- retired from its old grab-target meaning by the 2026-08-24 numpad rebuild; F12 stays avoided, it's Steam's own screenshot hotkey).

**Files touched**: `spawner.lua` (`Spawner.Lights`, `CS.SpawnPlateMeshActor`, `CS.IsLightActor`, `Spawner.EnableLight/DisableLight/SetLightColor/SetLightIntensity/SetLightThrowDistance/SetLightShieldDistance/SetLightShieldSize/SetLightShieldVisible`, `beginFollowLoop`'s floor-lock/raycast gate, `Spawner.LIGHT_START_DIST_UU`); `main.lua` (7 request pollers + continuous `custom_lights_status.txt` publish, `lblighton`/`lblightoff`/`lblightcolor`/`lblightbright`/`lblightdist`/`lblightshielddist`/`lblightshieldsize`/`lblightshield` console commands); `CustomMenu.hpp`/`.cpp` (`DrawLightsSection`/`DrawLightsSectionImpl`, all Light state/poll/Write*Request plumbing); `StandaloneWindow.cpp` (new "Photo Mode" tab, F7 shortcut). Camera controls (Tripod/Selfie/First Person, per the original mockup) are noted as the next piece for this same tab, not yet built.

### 19ba. Two more Lights polish fixes, both found by live testing right after 19az shipped: a bare `:IsValid()` check doesn't reliably reflect actor destruction for this spawn type, and the hover-highlight dispatch needs to route lights through the effect-based path, not the material-swap one (2026-09-21)

**"Enable" checkbox stayed checked after despawning a light via the generic spawn tools or cancelling its placement.** RedFalcon tested both paths directly and confirmed the checkbox never auto-unchecked -- required manually toggling it off afterward. The first self-heal attempt (check `entry.actor:IsValid()` every status poll, clear the slot if false) did NOT catch either case, even though `:IsValid()` is the standard, pervasively-used "has this been destroyed" check everywhere else in this file (`beginFollowLoop`'s own placement-actor check, for one). Root-caused by checking a DIFFERENT, structurally-guaranteed signal instead: `Spawner.DespawnActor` (what every one of those paths -- `CancelPlacement`'s NEW-mode branch, the generic Despawn key -- ultimately calls) is guaranteed to synchronously remove the actor from `Spawner.spawned` as part of destroying it. Checking membership there instead of trusting `:IsValid()`'s return value fixed it immediately. **General lesson: `:IsValid()` is the right first check for "was this destroyed," but it isn't universally reliable across every actor/spawn type in this codebase -- when it doesn't catch a real destruction, look for a structural side effect the actual destroy path is GUARANTEED to produce (here: removal from a tracking list) rather than assuming the check itself is broken everywhere.**

**Hovering a light with "Show Spill Shield" off showed no highlight at all -- because the wrong highlight mechanism was being used.** First fix attempt (temporarily forcing the plate visible during hover, restoring its real state after) technically worked but felt like patching around the real issue -- RedFalcon: "highlighting when spill shield is hidden doesnt do anything. i'd be fine with the effect used on actors instead. that doesnt rely on a visible texture." That pointed at a mechanism this project already built and forgot was available here: `Spawner.SpawnHoverEffect` (2026-08-22) is a COMPLETELY SEPARATE highlight for character-type targets (statues/walkers/Senkamati) -- a small looping Niagara particle effect spawned at the target's own location, replacing an earlier material-swap attempt specifically because that swap kept causing a skin/eye white-restore bug on characters. It never touches the target's own mesh/material at all, so it's unaffected by whether that mesh is even rendering. `UpdateHoverHighlight`'s own dispatch was routing purely on `actor.Mesh` being a valid SkeletalMeshComponent (true for characters, false for decor) -- a light's own mesh lives on a DIFFERENT property (`StaticMeshComponent` from the `R5BuildingBlock`/DA_BI_ route, not `.Mesh`), so it always fell through to the material-swap branch regardless of visibility. Fixed by widening that one dispatch condition to `isCharacter or CS.IsLightActor(trackedActor)` -- reused the existing, already-proven mechanism outright rather than extending the material-swap path further; the earlier forced-visibility hack was reverted as no longer needed. **General lesson: before patching a highlight/visibility gap by forcing state around the existing mechanism, check whether this codebase already built a DIFFERENT mechanism for exactly this "the usual approach doesn't work for this target type" problem -- the dispatch condition gating which one runs may just need widening, rather than the losing mechanism needing more special-casing.**

**Files touched**: `main.lua` (`BeltStrapPolls.publishLightsStatus`'s self-heal check); `spawner.lua` (`UpdateHoverHighlight`'s highlight-mechanism dispatch condition; the forced-visibility hack added then reverted from `applyHoverHighlight`/`restoreHoverMaterials`).

### 19bb. Photo Mode "Camera" section shipped (Tripod/Selfie/First Person) after a mockup re-read caught real misses in the first pass; the base+offset persistence model; a fully-reverted Selfie rig rewrite; and the "question vs. order" lesson that came out of it (2026-09-22)

19az shipped Lights and left Camera as "the next piece for this same tab." First pass (mode buttons, movement pad, FOV, Precision, a passive Coords readout) missed real detail from RedFalcon's own original mockup, caught only after re-reading it directly: Tripod should default to "what first person would see" (stationary, not a fixed-distance placement), Selfie should continuously track the player's face every tick, the movement pad should work for all 3 modes as an offset relative to each mode's own live base pose, and Coords should be Tripod-only and behave like the real Spawn-tab Coords popup (Preview/Apply/Reset/Cancel), not a readout.

**Base+offset persistence model**: `Spawner._photoCamOffsets = {TRIPOD={fwd,right,up,pitch,yaw,roll}, SELFIE={...}}` holds each mode's own movement/rotation offset, surviving mode switches and exits, cleared only by an explicit Reset or a Coords apply. `Spawner._photoCamTripodBase` is Tripod's own anchor pose, computed ONCE (first activation or Reset) and never recomputed on a plain re-activation -- RedFalcon caught the first version snapping to the player's CURRENT position/rotation on every re-entry: "tripod is also being set relative to position. this should only happen the first time its enabled or if reset is selected. otherwise it should keep its exact position and rotation."

**Target-lock over-gating**: `pollCameraAutoReset` tore down ANY active camera mode the instant no target was locked -- RedFalcon: "tripod and selfie are requiring a target be selected or it drops back out. those are target independant." Fixed by scoping that check to only the genuinely target-scoped modes (FULLBODY/FACE), not Tripod/Selfie/FirstPerson.

**Tripod's default pose needed to match First Person's REAL eye position, not the raw camera boom.** RedFalcon: "i want the tripod camera to initialize and reset to the same view as what the current first person camera would see." `_computeFirstPersonEyePose()` was reading the SpringArm's raw boom location -- rewritten to read the actual head-bone world position (`mesh:GetSocketLocation(FName("head"))`) plus a small Z trim, since that's exactly what First Person's own camera ends up at (confirmed mathematically: `TargetOffset` is applied pre-rotation in the arm's parent/body-yaw space, so the two are equivalent by construction, not by tuning).

**First Person "orbited" the player and sat too high/back.** RedFalcon: "if i look down i see the top of my head and down my back," then "the first person camera doesnt seem centered, it sort of orbits the player." Root cause: the camera's own baked `RelativeLocation` and the boom's baked `TargetOffset` were never zeroed/overridden -- only `SocketOffset` (camera-relative, post-rotation) was being touched. `TargetOffset`, unlike `SocketOffset`, is applied PRE-rotation in the arm's PARENT (body-yaw) space -- fixed by zeroing `cam.RelativeLocation` and computing a real head-bone-centered `TargetOffset` in that same body-yaw frame (`Spawner._computeHeadCenteredTargetOffset`), which stays pinned to the head regardless of view direction instead of swinging around it. A final +5uu Z trim (`Spawner.PHOTOCAM_FIRSTPERSON_Z_TRIM_UU`) was added on top after RedFalcon confirmed the centering itself: "can we move it up the z axis the equivalent of pressing 'up' once at 1/4 precision?"

**A full Selfie-camera-rig rewrite was built, then fully reverted -- and became the source of a standing collaboration rule.** RedFalcon asked "can we use the same camera process as first person to do selfie so it's smoother?" -- read (correctly, in isolation) as a go-ahead, so Selfie was rebuilt onto the CameraBoom/FollowCamera rig with reversed rotation, matching First Person's mechanism. RedFalcon: **"that does not work at all. let's put it back. i was just asking for clarification, not giving an order. next time when i say 'question' leave it as a hypothetical and ask if you want me to try it."** Fully reverted back to the original spawned-CameraActor-based `_computeSelfieBasePose()`/`_photoCamApplyPose()` approach (recomputed fresh every tick via `Spawner.PhotoCamTick`, camera placed `PHOTOCAM_SELFIE_DISTANCE_UU` in front of the head bone along the full look vector, rotation reversed). Saved as a standing memory (`feedback_question_is_not_an_order`): a "can we...?" is a discussion prompt, not a directive, even when phrased with enough technical confidence to sound like one.

**A new hover-highlight suppression system was added for photo composition.** RedFalcon wanted a "Toggle Target Highlight" button (later simplified to "Target Highlight") that hides the targeting highlight while composing a shot in one of the 3 camera modes, but should have ZERO effect outside them ("I just want the option to show or hide it when in one of the three camera views" / "when not in one of those 3 views, highlight should always be on"). Implemented as a raw persisted flag (`Spawner._hoverHighlightSuppressed`) plus a computed EFFECTIVE value (`IsHoverHighlightEffectivelySuppressed() = raw AND mode-is-one-of-3`) read at every check site -- so the raw flag can survive a mode switch without ever visibly suppressing anything outside those 3 modes. Two follow-up bugs, both from the same root cause (state that should have been reset on exit wasn't): the raw flag needed resetting to `false` inside BOTH shared teardown funnels (`SetFirstPerson`'s and `SetPhotoTripod`'s "off" branches) so a stale "hidden" flag from a previous session didn't silently apply on the next entry, and the button's own lit/dim styling was inverted per RedFalcon's request ("reverse it so enabled is brighter and disabled is dimmed") with the label simplified from "Toggle Target Highlight" to just "Target Highlight."

**Files touched**: `spawner.lua` (`Spawner.SetFirstPerson`/`MoveFirstPersonRelative`/`_computeFirstPersonEyePose`/`_computeHeadCenteredTargetOffset`/`_computeSelfieBasePose`/`_photoCamApplyPose`/`PhotoCamAdjustOffset`/`PhotoCamSetMode`/`PhotoCamSetAbsolute`/`_hoverHighlightSuppressed`/`IsHoverHighlightEffectivelySuppressed`/`SetHoverHighlightSuppressed`/`UpdateHoverHighlight`/`SetPhotoTripod`); `main.lua` (photo-cam request/status bridge, highlight-toggle bridge, both wired into the main 400ms poll loop); `CustomMenu.cpp` (`DrawCameraSectionImpl`, `DrawPhotoCamCoordsPopupImpl`, highlight toggle button/state).

### 19bc. Photo Mode tab polish pass: column repadding, Lights top-row label reorder, Camera button height, tab renames, and a real Dear ImGui limitation confirmed by reading engine source (2026-09-22)

A batch of aesthetic requests on the same tab: "add a little more padding between the camera controls and lighting as they seem a bit tight. Camera has more room to adjust so shrink its right side a bit" -> Camera/Lights columns repadded to a fixed 24px gap with Camera at 42% / Lights at 58% of the usable width. "On the lights, can we put label text to the left of everything on the top row?" -> every Enable/Color/Show Spill Shield checkbox on Light 1-3's top row got its own `TextUnformatted` label placed to its LEFT via plain `##`-only checkboxes, fixing a run-on "EnableColor" reading caused by the checkbox's own trailing label sitting flush against the next label with no gap. "Can we have the camera section be the same height as the light section? The buttons are kinda short and cramped" -> a `kCamBtnH` constant (tuned 32.0f then 31.0f) applied to every Camera button.

**Tab renames** (`"Tools"` -> `"Spawn and Move"`, `"Custom"` -> `"Customize"`) were plain, safe label swaps since the root window already sets `ImGuiWindowFlags_NoSavedSettings`.

**`ImGuiTabItemFlags_Trailing` does not right-align tabs into unused bar width -- confirmed by reading Dear ImGui's own source, not by guessing at the API.** RedFalcon wanted History/Instructions moved to the right side of the window; the flag was added, deployed, and RedFalcon reported back with a screenshot: "they are not to the right." Rather than keep guessing at flag combinations, read the vendored `imgui_widgets.cpp` (1.92.1) directly -- confirmed the tab-bar's own offset formula (`tab_offset = min(max(0, barWidth - section2.Width), tab_offset)`) only CLAMPS trailing tabs from overflowing the bar; it never pushes them rightward into slack space when the bar is wider than its tabs. True right-alignment would require replacing the native tab bar with a hand-rolled button strip (a real visual downgrade risk for zero functional gain). Presented this finding plus the tradeoff via a direct question rather than just picking one -- RedFalcon: "Leave it as-is." The flag was fully reverted, tabs left in plain left-to-right order. **General lesson: when an ImGui flag doesn't behave as its name suggests, reading the actual vendored source is faster and more conclusive than iterating flag combinations by trial and error.**

**Files touched**: `CustomMenu.cpp` (`DrawLightsSectionImpl` top-row layout, `kCamBtnH` on every Camera button); `StandaloneWindow.cpp` (Photo Mode tab column widths/gap, tab renames, the added-then-reverted `ImGuiTabItemFlags_Trailing`).

### 19bd. Spawn Tree / Move panel action-button rows, revised twice in the same session after RedFalcon caught a missing button on the first pass (2026-09-22)

RedFalcon: "underneath the spawn tree I would like to add buttons. First 'Spawn' and 'Replace' as it is now. Then 'Move' (same as \*), Then 'Cancel' (Same as /) and finally move the 'Despawn' Button to the end... make them the same height as the current Despawn and Undo buttons." First pass built a 5-button row under the tree (Spawn/Replace/Move/Cancel/Despawn, `queue_move_action` -- a small duplicated `move_request.txt`-append helper matching this project's own established "small duplicated helper" tolerance, e.g. CoordsMenu.cpp's own pattern) and reduced `MoveMenu.cpp`'s own panel to just Undo (Despawn moved out of it).

**RedFalcon caught a missing button before using it live**: "So I forgot a button so we'll need to readjust again. Under the Spawn Tree, I want the buttons 'Confirm' (0), Spawn, Move and Replace. Then under the movement section, fitting the width, I want Cancel, Despawn, Undo." Revised to a 4-button row under the tree (Confirm/Spawn/Move/Replace -- Confirm new, maps to `CONFIRM_PLACEMENT`/Numpad 0, gated on `MenuStatus::IsPlacementActive()`; Cancel and Despawn removed from this row) and a 3-button row in `MoveMenu.cpp` (Cancel/Despawn/Undo -- Cancel and Despawn added back), reusing that file's own pre-existing `cellW`/`cellH` (28px, 3-even-column) sizing already computed for its D-pad rather than inventing new width math for "fitting the width."

**Files touched**: `SpawnMenu.cpp` (`queue_move_action`, the tree's own 4-button row, `BeginChild`'s bottom margin widened -44 -> -52 to fit the taller row); `MoveMenu.cpp` (3-button row reusing `cellW`/`cellH`).

### 19be. Photo Mode gains Weather/Time/Freeze Time controls under Light 3, thin GUI front-ends over the existing `lbphotoweather`/`lbphototime` console tooling -- plus a resume-speed bug, a one-way-checkbox design, a restore-ordering bug fix, and a real engine limitation documented rather than chased (2026-09-22)

RedFalcon: "under light 3, can we have a separator like the others and two drop downs and a checkbox? one is for weather... 'Weather'... once a weather is selected, return it back to 'Weather'. Next to that... 'Time'... 00-23... do the same as weather on selection. then next to that a checkbox for Freeze Time that is checked when the sun stops moving. then restore running time when unchecked."

**The GUI reuses the existing production console-command machinery rather than duplicating it.** `lbphotoweather`/`lbphototime` (main.lua, shipped 2026-09-08) already own a validated weather-name table and an hour-to-raw-clock conversion/fast-forward-then-freeze state machine (`pendingPhotoWeather`/`pendingPhotoTime`, each consumed by its own independent `ExecuteWithDelay` poll loop). The new GUI request pollers just set those SAME pending-request locals from a request file; the actual native work still happens in the original, already-proven loops. Weather/Time combos are fire-and-forget action menus, not persisted selectors -- their preview text is hardcoded to "Weather"/"Time" rather than bound to the last pick, matching RedFalcon's own spec exactly.

**Hit Lua's 200-local ceiling immediately, again.** A first pass added ~10 new plain top-level locals for the new request-path tables/functions -- `lint.py` failed outright: "too many local variables (limit is 200)." Fixed by packing everything onto the existing `BeltStrapPolls` table as fields instead (matching this file's own established convention for exactly this problem, see `feedback_lua_200_local_ceiling`) -- table-field assignments don't count against the ceiling since the function bodies become their own separate closures with their own local budgets. The functions still had to be DEFINED textually after `PHOTO_WEATHERS`/`findPhotoWeather`/`pendingPhotoWeather`/`pendingPhotoTime`/`realHourToRawHour` (all locals declared much later in the file, near the `lbphototime`/`lbphotoweather` command registrations) to avoid the file's own well-documented forward-reference trap -- a function literal closes over the locals visible at the point it's WRITTEN, regardless of which table holds it. The actual poll CALLS were then added to the earlier, already-running 400ms `BeltStrapPolls` loop with no ordering problem at all, since by the time that loop actually runs (long after the whole file has loaded), every field is already assigned.

**On the C++ side, the same ordering constraint applies in reverse.** The new Weather/Time/Freeze declarations were first placed textually AFTER `DrawLightsSectionImpl` (next to the similar Highlight-toggle code) -- compile failed (`identifier not found`) because C++, unlike Lua closures, needs a declaration before use, and `DrawLightsSectionImpl`'s own body (edited to add the new row at its end) is defined EARLIER in the file. Fixed by moving the whole block above `DrawLightsSectionImpl`, alongside the other Light-section state/request declarations.

**Freeze Time is a genuinely ONE-WAY uncheck, not an ordinary checkbox.** RedFalcon, after seeing the first pass: "they should not be locked to start with, except freeze time. i want it a one way uncheck once time has changed and time has stopped." Weather/Time stay freely clickable always; Freeze Time's checkbox is wrapped in `BeginDisabled(!g_photoTimeFrozen)` -- it starts (and stays) unclickable while time is running normally, since there's nothing to unfreeze yet and it can't be checked directly (freezing only ever happens as a side effect of a Time selection converging and settling). Once that happens the box becomes enabled showing checked, and the only click it can register from there is unchecking it (resume) -- structurally, it can never go disabled/false straight to checked/true from a click. Its checked state is read from the day-cycle component's REAL live tick state (`IsComponentTickEnabled()`, published every poll) rather than a cached flag, deliberately reusing the exact lesson this same session already learned from the Target Highlight toggle (a locally-cached value read wrong after an exit/re-entry the button itself didn't cause).

**Unfreezing resumed time at the wrong (fast-forward) speed.** RedFalcon: "freeze time does return time passing but it doesnt reset the speed." `lbphototime`'s own convergence step sets `DayCycleSpeedInv` to a small fast-forward value (default 0.0125) to reach the target hour quickly, then calls `SetComponentTickEnabled(false)` to freeze exactly there -- but nothing ever reset `DayCycleSpeedInv` back afterward, so re-enabling tick on uncheck resumed time at that same fast rate instead of the documented normal pace (confirmed elsewhere in this file: "100000 = near-frozen, 1.0 = normal pace"). Fixed by setting `comp.DayCycleSpeedInv = 1.0` in the same call that re-enables tick.

**A real, undocumented-until-now engine limitation: "frozen" time keeps silently advancing underneath the freeze.** RedFalcon, after a longer real test: "when unfreezing it looks like the world resyncs with the game clock. so if you froze time at 15:00 and time progress in your world until what would be 6:00, then once unfrozen the sun moves to 06:00." This is consistent with everything already known about this component (`GetCurrentTimeInHours()` appears computed from real elapsed world time, not a per-Tick accumulator -- the same reason a raw `WorldDayTime` write has zero lasting effect, and why changing `DayCycleSpeedInv` mid-stream jumps instead of transitioning smoothly): `SetComponentTickEnabled(false)` only stops this component from APPLYING its computed hour to the visuals, it does not stop the hour itself from being silently recomputed off real elapsed time in the background. Re-enabling tick just reveals wherever that hidden clock ended up. Presented two options (reconverge back to the frozen hour before resuming vs. leave it and document it) -- RedFalcon chose to leave it as-is: **a real engine limitation, not something a client-side Lua mod can truly stop**, documented in-code rather than chased with a workaround.

**"Base restored and ready" toast fired before saved customizations were actually applied.** Separately-reported same session: "the base is ready text appears before the customizations are set on the actors. I needs to wait until after they are all applied." Root cause: the toast lived inside `Spawner.RestoreFromPersist` itself (spawner.lua), fired the instant actor spawning + post-processing finished -- but `Spawner.RestoreCustomState` (which replays each actor's saved skin/hair/clothes/belts/pose, see the "Save Customizations" feature) only runs AFTERWARD, from `RestoreFromPersist`'s own `onComplete` callback in main.lua. Fixed by moving the toast out of `RestoreFromPersist` (which now just logs progress and threads `staticsCount`/`moversCount` through to `onComplete`) and into main.lua's `afterRestore`, which now fires the real "ready" toast only from INSIDE `RestoreCustomState`'s own completion callback -- same wording, now genuinely gated on customizations being done too, not just the actors existing.

**Files touched**: `main.lua` (`BeltStrapPolls.PHOTO_WEATHER_GUI_REQUEST_CANDIDATES`/`PHOTO_TIME_GUI_REQUEST_CANDIDATES`/`PHOTO_FREEZETIME_GUI_REQUEST_CANDIDATES`/`PHOTO_FREEZETIME_STATUS_PATH`/`_findPhotoDayCycleComp`/`photoWeatherGui`/`photoTimeGui`/`photoFreezeTimeGui`/`publishPhotoFreezeTimeStatus`, wired into the main 400ms poll loop; `afterRestore`'s toast-timing fix); `spawner.lua` (`RestoreFromPersist`'s post-process completion now threads counts through `onComplete` instead of toasting directly); `CustomMenu.cpp` (`kPhotoWeatherNames`, `WritePhotoWeatherRequest`/`WritePhotoTimeRequest`/`WritePhotoFreezeTimeRequest`, `pollPhotoFreezeTimeStatus`, the Weather/Time/Freeze Time row in `DrawLightsSectionImpl`).
