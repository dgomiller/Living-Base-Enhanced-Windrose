# LivingBase — Windrose Base Population Mod (Claude Code context)

> This file replaces the old historical `CLAUDE.md` (v0.5-era, different keybinds, an
> unfinished buyer/trade design). If that history is still wanted, keep it under a
> different filename — Claude Code doesn't need it and it would only add noise given
> it's already superseded. This file is current as of **2026-08-13** and describes the
> live-edit / despawn / undo / cycle / toast-feedback system built across two long
> sessions, a third session (items 29-34) converting the Senkamati Hunter/Caster to a
> normal human walk/posture and building a side-by-side comparison roster, and a fourth
> session (item 35) building a walking re-skin of Letty/Marita/the Buccaneers Merchant and
> settling what is and isn't possible for their color/tattoos, in enough detail to keep
> working on it without re-deriving anything already learned the hard way. Items 36-40
> cover same/next-day follow-up fixes; item 41 (2026-08-13) adds per-world save support
> (v1.3.8) — see `WINDROSE_MODDING_NOTES.md` §10 for the underlying engine finding. Item 42
> (same day) adds a live-edit target lock (Num+) and a 2x precision step. Item 43 (2026-08-14) adds
> a second walking-woman base (the Herbalist) to both the Walking Women rotation and the Senkamati
> Caster-F crew re-skin, for genuine figure/hair-color/palette variety; item 44 (same day) extends
> Base 1/Base 2 to every walking-woman look, not just the generic "Woman With Hair" slot. Item 45
> (2026-08-14, v1.3.10) adds Senkamati Statues (new key, `=`) — genuinely frozen-in-place Senkamati
> Caster figures, unlike the Num7 comparison roster which stays pacified but keeps wandering. Item
> 46 (same day) fixes a bug in that key's own target-lock shortcut and confirms via live probe that
> the game's REAL posed statue bodies (Standing/Merchant/Sitting women) carry a working composite-
> mesh component after all; item 47 (same day) rebuilds the statue roster's standing/seated looks
> around those real bodies instead of a Handyman re-skin, eliminating the need to freeze AI or guess
> whether a seated pose actually landed.

## What this is
A UE4SS Lua mod for **Windrose** (Kraken Express, UE 5.6, single-player, unofficial
modding — game patches can break class paths). It's a placement toolkit: numpad/F-row
keys drop NPCs, statues, animals, and decorations in front of the player; a separate
"live-edit" key set nudges a placed object's position/rotation in place; everything
persists across reloads via `persist.txt`.

## Files
- `main.lua` — all key bindings, `resolveKey`/`VK_FALLBACK`, the `bind()`/`editBind()`
  wrappers, `Config.LIVE_EDIT` gate.
- `config.lua` — every constant, class path, keymap (`Config.KEYS`), and the statue/decor
  rosters (`STANDING_STATUES`, `SEATED_STATUES`, `CHAIR_STATUES`, `INTERACTIVE_STATUES`,
  `DECOR_CATEGORIES`, `TOWNSFOLK_CLASSES`, etc.).
- `spawner.lua` — the engine: `Spawner.Spawn`, `EditNearestInFront`, `DespawnNearestInFront`,
  `UndoDespawn`, `CycleNearestInFront` (statues AND decorations, one function, auto-detects
  which roster the target belongs to), `PersistFindMatching`/`PersistRemoveMatching`/
  `PersistUpdatePose`, the shared `findNearestSpawnInFront` targeting helper, `Toast` (real
  on-screen notifications via the game's own native side-notification widget — see item 22+).
- `testbed.lua` — per-category spawn functions (`SpawnCrew`, `SpawnWalker`, `cycleStatues`,
  decor cyclers, etc.) — the "place a NEW thing" side, as opposed to spawner.lua's
  "edit/replace an EXISTING thing" side.
- `whistle.lua`, `bbraid.lua`, `unlockbuild.lua` — independent features (crew-escort
  whistle, Blackbeard raid, hidden-build-piece unlock), untouched this session.
- `README.md` / `WINDROSE_MODDING_NOTES.md` / `ASSET_CATALOG.md` — kept in sync with this
  session's changes; see those for user-facing docs, durable engine findings, and the
  decoration asset database respectively.

## Current keybindings (as of this session)
```
Numpad 1-8   place NPC/statue/animal (each key cycles its own roster on repeat press)
Numpad 9     despawn the object in front of you (same floor, ~250uu reach)
Numpad 0     undo — restore the last despawn (single or a whole DEL wipe), full appearance, names it
Numpad +     toggle target lock: pin despawn/cycle/live-edit to the object in front of you (toast
             confirms on/off; while locked, those keys keep hitting it even after you walk away or
             look elsewhere)
Numpad /     rotate the targeted object a fixed 45°
Numpad *     rotate the targeted object a fixed 180° (flip)
Numpad -     cycle slide/height precision: full -> 1/2 -> 1/4 -> 1/8 -> 2x -> full
\            flip statue FACING for future spawns only (does not affect placed objects)
]  /  [      cycle the targeted statue OR decoration through its own roster forward/backward (undo-able)
F1-F6        place a decoration (each cycles its own category)
F7 / F8      drop Blackbeard raid flag / trigger the raid
Insert       toggle EVERY key this mod binds (numpad, F-row, DEL, \, live-edit) on/off
Arrows       (live-edit) slide the targeted object fwd/back/left/right
PageUp/Down  (live-edit) raise/lower the targeted object
, / .        (live-edit) rotate the targeted object
DEL x2       clean-house: despawn everything + clear persist.txt (undo-able as one batch)
```
`Config.LIVE_EDIT` gates the arrow/PageUp/PageDown/`,`/`.`/Num-`/`*`/Num+ keys at BIND time (they
don't register at all if it's `false`) — but Numpad 1-9/0, `]`/`[` (placement, despawn, undo, cycle-
pose) always bind regardless of `LIVE_EDIT`. Num+ (target lock) is deliberately grouped WITH the
live-edit cluster rather than alongside despawn/cycle, even though a lock also affects despawn/cycle
once set — see `main.lua`'s own comment at that registration for why (it only ever matters in
combination with live-edit, and the lock can never be set at all without this key to set it, so
gating it the same way costs nothing when `LIVE_EDIT` is off). Insert (`Config.KEYS.toggleMod`, default `"INS"`) is a
separate, runtime, always-on toggle (`main.lua`'s `modEnabled` flag): it doesn't unregister
anything (UE4SS has no unbind), it just makes EVERY key this mod binds — `bind()`-registered
keys (numpad 1-9, F-row, DEL, `\`) and the directly-registered ones (Num0, Num+, `editBind`'s
keys, Num-) — no-op while off, checked fresh on each press via `modGate(name)`. The toggle key's
own bind sits outside the gate so there's always a way back on. Deliberately off the F-row —
F-keys are the ones most likely to be claimed by another mod (this replaced an original F9
binding after it collided with one). **UE4SS key-name gotcha**: this build wants `"INS"`, not
`"INSERT"` — confirmed via the pre-existing `HOME`/`INS` in-world-probe keys in
`ASSET_CATALOG.md`. `Config.KEYS`' own header comment (`config.lua` ~line 144) lists the known-
good names; check there before guessing a new one.

## This session's work, condensed
Started from: "moving objects left/right is inconsistent." Ended at a fairly complete
edit/despawn/undo/cycle toolkit. In order:

1. **Diagnosed the inconsistency** via `ue4ss.log` (no console access in this game) —
   confirmed the targeting/movement *logic* was correct, but two real engine issues were
   at play (see Known limitations below).
2. **Tried and rejected**, in this order, because none addressed the actual bottleneck:
   target-lock caching, an automatic per-press repeat burst, replacing arrows with
   letter keys (I/J/K/L — also fail to bind in this build), a Shift-modifier bind for
   half-step precision (UE4SS's `{modifierKeys}` bind overload never fires in this game).
3. **What actually helped**: a tighter live-edit pick radius (`LIVE_EDIT_MAX_DIST=200`,
   separate from despawn's own 250), a close-range dot-product stability floor (skip the
   "is it in front" check under 40uu — that vector is noise-sensitive point-blank), facing
   from the pawn's own body rotation (camera made targeting *worse*, not better), bigger
   step sizes (fewer presses land, so make each one count), and a **toggle key** (`Num -`)
   instead of a held modifier for a "sometimes different amount" input.
4. **Fixed a render/transform desync**: `K2_SetActorLocation`/`Rotation` update the
   logical transform correctly every call (proven via log), but the mesh doesn't visually
   refresh until something forces it — walking out of range and back does this naturally;
   the mod now does it itself via `SetActorHiddenInGame(true)` then `(false)` right after
   every move.
5. **Built Undo (Num 0)**: a capped-20 LIFO stack. Since a destroyed actor can't literally
   come back, undo respawns the same class at the same transform — enriched with AI
   controller + composite-look fields recovered from `persist.txt` (see
   `Spawner.PersistFindMatching`), so a re-skinned crew member restores looking the same,
   not with a fresh random appearance.
6. **Added Num/ (45°), Num\* (180°), Num- (precision toggle)** to live-edit — same raw-VK
   fallback treatment as arrows, since none of these are in this build's `Key[]` table
   either.
7. **Tightened Num9 despawn** to match: smaller reach (700→250uu), the same close-range
   floor, and on-screen toast feedback (previously silent — gated behind `Config.VERBOSE`,
   which defaults off).
8. **Built Num+ (`CycleNearestStatuePose`)**: swaps the targeted statue for the next entry
   in its own pose roster (`STANDING_STATUES` etc.), in place, undo-able via the same
   stack (see fix in item 10 below — this was broken until then). This is reliable
   specifically because roster entries are genuinely different classes — **it does NOT
   work for face/body/skin variety within one class**, which the engine re-randomizes on
   `BeginPlay` regardless of what's pinned pre-build (proven separately, see
   `WINDROSE_MODDING_NOTES.md` §2). Don't try to extend cycling to that.
9. **Refactored**: extracted `findNearestSpawnInFront()` — the "what's in front of me"
   targeting logic — into one shared function used by despawn, edit, and cycle. It was
   written three times independently before this; keep new features using the shared one
   rather than writing a fourth copy.
10. **Fixed Num0 undo after a Num+ cycle**: `UndoDespawn` only ever *spawns* the item on
    top of the popped batch — it never destroys anything. That's fine for Num9/DEL, where
    the spot is genuinely empty, but `CycleNearestStatuePose` destroys the old statue and
    leaves a live *replacement* standing in the same spot, so undoing just respawned the
    old pose on top of it (and repeated cycle→undo piled up duplicates). Fix: the cycle
    step now stamps `replaceActor`/`replaceClass`/`replacePos` onto its undo item once the
    new statue exists; `UndoDespawn` destroys and untracks (`Spawner.spawned` +
    `persist.txt`) that actor first, before respawning the old one. Plain despawn/DEL
    batches never set `replaceActor`, so they're unaffected. **Pattern for future
    features**: any action that destroys-and-recreates in place (not just remove) must
    attach the replacement to its own undo item so undo can clean it up — `UndoDespawn`
    won't infer it.
11. **Added F9: master mod-keys on/off** (2026-08-04). Started as "free the numpad for other
    uses when not placing"; user then asked to widen it to every key the mod binds, for
    consistency, rather than numpad-only. UE4SS's `RegisterKeyBind` has no unbind, so every
    key stays *registered* either way — F9 flips a runtime flag (`modEnabled` in `main.lua`)
    that every bound callback checks first via `modGate(name)` and no-ops on if off. `bind()`
    itself gates unconditionally now (covers numpad 1-9, F-row F1-F8, DEL, `\`); the three
    directly-registered keys (Num0 undo, Num+ cycle, Num- precision) and every `editBind`
    entry (PageUp/PageDown, `,`/`.`, arrows, Num/, Num*) got the same inline check. The toggle
    key itself is registered outside the gate, unconditionally, so there's always a way back
    on. Resets to ON on script reload/restart — not persisted, matching
    `Spawner.editPrecision`'s existing pattern.
12. **F9 → Insert** (2026-08-04, same day). F9 turned out to collide with another installed
    mod. User asked whether Shift+F-key combos were feasible instead, to reduce future
    conflicts across the board — answer: no, not via UE4SS's own mechanism (the
    `RegisterKeyBind(key, {modifiers}, callback)` overload is already documented as dead in
    this game, see Known Limitations), and a manual poll-Shift-state workaround would be
    unverified/risky to ship blind. Went with the simpler, proven-safe fix instead: moved the
    toggle off the F-row entirely, to `Config.KEYS.toggleMod = "INS"`. **Caught a naming trap
    while doing it**: tried `"INSERT"` first, which is wrong for this build — the correct
    UE4SS key name is `"INS"` (per `config.lua`'s own `Config.KEYS` header comment, and
    corroborated by the pre-existing `HOME`/`INS` in-world-probe keys in `ASSET_CATALOG.md`).
    Left the config comment with a pointer to that gotcha so it isn't rediscovered the hard
    way. F-row is now free for actual placement/decoration use only; the master toggle will
    never again default onto a key other mods commonly grab.
13. **Narrowed the targeting cone** (2026-08-06). User reported targeting "still feels a bit
    iffy" and pointed at a separate installed mod, `WindroseTextSigns` (a UE4SS C++ mod at
    `.../ue4ss/Mods/WindroseTextSigns`, targets native Wooden Label signs for its own text
    editor), which reportedly targets more reliably. It's a compiled DLL — no source to read —
    but its README/CHANGELOG gave away the load-bearing numbers: `WTS_MIN_VIEW_DOT=0.92` (a
    ~23-degree cone) at `WTS_MAX_TARGET_DISTANCE=1000` (long reach), plus a changelog line
    confirming "camera-forward selection heuristic". `findNearestSpawnInFront` (`spawner.lua`)
    was doing the opposite trade: `dot > 0` — a full 90-degree hemisphere — at short range
    (200-250uu), picking the NEAREST candidate inside that wide arc. With two spawns close
    together, "nearest in a 90-degree arc" can beat "the one actually being looked at" — the
    likely source of the iffy feel. Fix: replaced the raw dot-product sign check with a
    normalized cosine compared against a new `Config.TARGET_MIN_VIEW_DOT` (default `0.90`),
    still on the SAME body-yaw forward vector — deliberately did NOT switch to camera facing,
    since that combination (camera + wide cone) was already tried once this project and made
    things worse (see Known Limitations); a tight cone is the reasoned-out load-bearing change,
    camera-vs-body is a separate, still-untested variable. Kept the existing `MIN_STABLE_DIST`
    (40uu) point-blank bypass — angle noise gets WORSE at close range with a tighter cone, not
    better, so that guard matters more now, not less.
14. **Targeting cone: switched to camera direction** (2026-08-06, same day). User pushed back:
    they'd noticed the signs mod tracks their reticle AND lets them pick between two signs
    stacked directly on top of each other — i.e. it's genuinely camera-based, pitch included,
    not just a tighter cone on a flat body-yaw check. Asked to try that combination specifically.
    `findNearestSpawnInFront` now computes a separate camera-look vector from
    `PlayerController:GetControlRotation()` (yaw+pitch, matches UE's own `FRotator::Vector()`
    formula) and uses THAT for the cone/cosine test, with distance also switched from
    horizontal-only to true 3D — so looking up/down now genuinely changes what gets picked.
    **Critical constraint that shaped the implementation**: this function's `px/py/pz/fx/fy`
    return values are also reused by `EditNearestInFront` as the arrow-key SLIDE frame, and
    camera-driven facing was already tried there once and reverted (documented in that
    function's own comment) because mixing camera-offset position with pawn position made
    *movement* worse. So the camera vector is local to the picking loop only (`cfx/cfy/cfz`,
    never returned) — the returned pawn-based `fx/fy` are untouched, meaning EditNearestInFront's
    slide math is byte-for-byte unaffected by this change. **Lesson for future work on this
    function**: "which object gets picked" and "which way should it move" are separate questions
    that happen to share one function — they're now allowed to use different facing sources, and
    should stay that way; don't collapse them back into one vector without re-checking both call
    sites. `GetControlRotation()` was chosen over chasing `PlayerCameraManager` for the actual
    camera transform — simpler, always present on the controller, and in this game's
    third-person setup the camera follows control rotation, so it should track the reticle
    closely enough. If it doesn't in practice, `PlayerCameraManager:GetCameraRotation()`/
    `GetCameraLocation()` is the more literal "where the camera actually is" fallback to try
    next.
15. **Fixed: item 14 broke targeting completely** (2026-08-06, same day). User tested in-game:
    every single live-edit press failed — `ue4ss.log` showed "nothing within 200uu ahead" on
    every attempt across ~2 minutes, arrows/PageUp/PageDown, all directions — while a screenshot
    showed them clearly standing next to something. Total failure, not just "cone a bit tight".
    **Root cause**: item 14 used the camera's DIRECTION but left the ray ORIGIN at the pawn's
    position. In third person the camera sits well behind/above the pawn root; at WTS's 1000uu
    range that offset is negligible, but at our 200-250uu range it's comparable to or bigger
    than the target distance itself. A ray "from the pawn, aimed where the camera looks" just
    doesn't line up with what's under the reticle at close range — this is the exact same
    "camera-offset position mixed with pawn position" failure mode already documented for
    `EditNearestInFront`'s movement math, just newly reintroduced into the targeting cone by
    item 14. **Fix**: the angle test now uses camera POSITION and camera DIRECTION together
    (`PlayerCameraManager:GetCameraLocation()` + `GetCameraRotation()`, a self-consistent pair,
    with `GetControlRotation()` as a rotation-only fallback if the camera manager is
    unavailable) — while the RANGE/reach check stays pawn-based on purpose, so "how far can I
    reach" still tracks how close you're standing, not how far the camera boom happens to be
    pulled out. **Rule going forward**: an angle/cone test's origin and direction must always
    come from the SAME transform (both pawn, or both camera) — never mix one from each,
    regardless of which two functions happen to need it. This has now broken things twice from
    two different angles (movement in an earlier session, targeting here); treat it as settled,
    not a coincidence.
16. **New-spawn placement direction: also switched to camera yaw** (2026-08-06, same day, after
    confirming item 15's fix worked). User asked to extend the camera-relative idea to WHERE new
    objects appear, not just which existing one gets picked. Lower risk than the targeting cone:
    placement doesn't compare against an existing object's position, it just picks a brand-new
    point at a fixed distance (300uu) from the player, so there's no origin/direction-mismatch
    class of bug to repeat here — origin stays the player's own position on purpose (that's
    physically correct: new things should appear near YOU, not near some camera-only point in
    space). Changed `spotInFrontOfPlayer` (`spawner.lua`) and `frontSpot` (`testbed.lua`, used by
    every placement key) to read horizontal direction from `PlayerController:GetControlRotation()`
    instead of pawn body yaw. Also updated `Spawner.Spawn`'s default "face toward you" yaw
    (used whenever a caller doesn't pass an explicit facing) to camera yaw + 180, so a spawn's
    default orientation stays consistent with the point it was placed at. **Deliberately scoped
    to YAW ONLY, pitch excluded** — height still comes entirely from `playerFloorZ()` +
    `snapToFloor` (unchanged), not from where you're looking up/down; using pitch for placement
    would put spawns floating in midair or clipped into the ground depending on look angle, with
    no equivalent to targeting's "does an object already exist there" check to keep it sane.
    **Also deliberately left untouched**: `playerYaw()` in `testbed.lua` (used by `spawnPosed`
    and Senkamati mob spawns for "face the same direction I'm facing" poses) — that's about the
    player's own stance/orientation, a different question from "which way am I glancing", so it
    stays pawn-body-yaw-based unless asked otherwise.
17. **Fixed: toast feedback was never actually visible** (2026-08-06, same day). User had never
    once seen an on-screen toast despite the whole session's worth of despawn/undo/cycle/toggle
    confirmations calling `Spawner.Toast`. Added a `[toast-diag]` log line reporting which
    delivery path claimed success; user tested, log showed `via=PrintString` — meaning the call
    itself succeeds (no Lua/reflection error) while nothing renders. Root cause, confirmed against
    known engine behavior: `UKismetSystemLibrary::PrintString`'s on-screen path is gated by the
    global `GAreScreenMessagesEnabled` — when false, it silently skips
    `GEngine->AddOnScreenDebugMessage` and logs at `VeryVerbose` (invisible at any log level we'd
    notice), so the call reports success while the engine drops it entirely. This is WHY `pcall`
    never caught it: the failure is inside the engine, not the reflection call. Windrose ships
    with this off by default — common in packaged commercial UE games, to suppress third-party/
    plugin debug clutter (not Toast-specific; ANY `PrintString`-based on-screen text from any mod
    would be equally invisible here). Fix: `Spawner.Toast` now calls
    `KismetSystemLibrary:ExecuteConsoleCommand(world, "EnableAllScreenMessages", nil)` — the
    standard engine exec command that flips the flag back on — immediately before every
    `PrintString` attempt. Re-asserted on every call rather than once at load, in case something
    else in the game re-disables it mid-session. **If toasts are STILL invisible after this**:
    the `[toast-diag]` line is still in place — check whether `via` has changed to `ClientMessage`
    or `none`, which would point to a different problem entirely (this fix only addresses the
    `GAreScreenMessagesEnabled` cause, confirmed present here).
18. **Item 17's fix didn't work either** (2026-08-06, same day). User tested; toast still
    completely invisible. Screenshot of the in-game console showed the actual problem:
    `Command not recognized: EnableAllScreenMessages` — the exec command itself doesn't exist in
    this build, so item 17's fix was a silent no-op (worse, it spammed that error into the
    console on every single toast). Pulled it out. Also realized `Spawner.Toast`'s structure had
    never actually tested `ClientMessage` even once all session — it was only ever attempted when
    `PrintString`'s *call* failed, and PrintString's call was always "succeeding" (see item 17),
    so `ClientMessage` was permanently dead code up to this point. Rewrote `Toast` to try both
    unconditionally and log each independently (`PrintStringCalled=`/`ClientMessageCalled=` in
    `ue4ss.log`) so the next in-game test gives real signal on `ClientMessage` specifically,
    which we have literally never observed.
    **If `ClientMessage` also turns out invisible**: don't keep guessing at more engine
    debug-output APIs — `WindroseTextSigns`' own log (a separate, working C++ mod in this exact
    game) explicitly records that native UMG *interactive* widgets don't work here
    (`native_ui_probe supported=false ... fallback=imgui reason=missing_required_umg_or_input_mode`)
    and it falls back to UE4SS's ImGui overlay for its editor. Two caveats before copying that:
    (a) WTS's specific blocker was input-mode/focus classes for a *text editor* — its probe shows
    core UMG classes (`userWidget`, `widgetTree`, `addToViewport`) DO resolve, so a passive,
    non-interactive toast may not hit the same wall; (b) this project's own notes describe
    UE4SS's GUI console as "an OpenGL window on an external render thread... turn it off for
    play" — if `RegisterImGuiHook`-drawn content renders into that same separate window rather
    than blended onto the actual game screen, it's not useful for gameplay HUD feedback and
    isn't actually a fix, just a different dead end. The more promising route, untried: the
    player already has visible native toast/notification UI in this game (the "Rested / Stamina
    now regenerates faster" popup) — reusing THAT existing widget class via reflection (find its
    class, spawn/trigger an instance, feed it our text) is more likely to actually render than
    building new UI from scratch, but needs a runtime probe to find the right class name first.
    Not yet attempted.
19. **Confirmed item 18's diagnosis, added a probe** (2026-08-06, same day). User tested both
    delivery paths: `PrintStringCalled=true ClientMessageCalled=true` in `ue4ss.log`, but
    `ClientMessage`'s text showed up in the **UE4SS debug console window** (the separate `>`
    prompt), not the game's own HUD — a screenshot confirmed this directly. So both native
    debug-output paths are dead ends for real gameplay-visible feedback in this game: they're
    being intercepted by UE4SS's own console, never reaching the actual render surface. Per item
    18's plan, added `Spawner.DumpActiveWidgets()` — `FindAllOf("UserWidget")` (same established
    pattern this codebase already uses for actors, e.g. `FindAllOf("R5BuildingBlock")`), logging
    every active widget's class name + `IsInViewport()`. Bound to **Home**
    (`Config.KEYS.dumpWidgets`), registered directly and NOT gated by `modGate` — it's a one-off
    dev tool, not a real feature. Intended use: press Home WHILE a native popup (e.g. "Rested /
    Stamina now regenerates faster") is on screen, then read `ue4ss.log` for a plausibly-named
    class with `inViewport=true` at that moment — that's the candidate to investigate for reuse
    (find how it's normally shown/set-text, then drive it the same way from Lua). Not yet tested
    in-game; next step once the class name is known.
20. **First widget-dump run: unfiltered was useless, narrowed to keyword match** (2026-08-06,
    same day). User pressed Home: **3329** `UserWidget` instances — almost entirely
    `WBP_MiniMapMarker_*`/`WBP_MapMarker_*`/`WBP_CraftingStation_WorldMarker_C` (this game pools a
    marker widget per world point of interest, map-wide), which blew through the paste/log limit
    long before reaching anything relevant. Also every single entry read `inViewport=false`,
    including markers visibly on screen at that moment — so `IsInViewport()` is not a usable
    filter here; it's presumably only ever true on the one ROOT widget actually passed to
    `AddToViewport`, with everything else living as an unflagged child of some parent panel.
    User also flagged a concrete, better target while looking at the raw dump: a native
    status-effect/buff panel (Hunger, Deadly Finale, Perfect Counter, Executioner's Grace) —
    exactly the "appears/disappears based on game state, icon + label" shape a toast needs, and
    already confirmed visible on their screen. Rewrote `DumpActiveWidgets` to filter by class-name
    keyword (`WIDGET_DUMP_KEYWORDS`: status/buff/perk/effect/toast/notif/popup/message/alert/hud/
    banner/hint/rest/tooltip, case-insensitive plain-text match) instead of dumping everything, and
    dropped the now-known-useless `inViewport` field from the output entirely.
21. **Filtered dump found the target class; added a function-lister; picked the direction**
    (2026-08-06, same day). Re-ran the filtered Home probe: 323 matches out of 3365 widgets — a
    real, readable list this time. Strongest candidates: **`WBP_PickupNotification_C`** /
    `WBP_PickupNotificationsContainer_C` (this is almost certainly the "+1 Bird Meat [2]" /
    "+1 Dodo Egg [4]" pickup popup seen in an earlier screenshot — already free-form text, already
    appears/fades on its own), plus `WBP_SideNotificationsContainer_C` and
    `WBP_ThreatNotificationsContainer_C` as other generic notification-container types. Also
    present: the buff/status widgets (`WBP_CharacterBuff_C`, `WBP_StatusEffectsContainer_C`,
    `WBP_LongEffectsPanel_C`/`WBP_LongEffectEntity_C`, `WBP_MarkerStatusEffect_C`/
    `WBP_MarkerStatusEffects_Group_C`, `WBP_ComfortZoneBuff_C`) and a pile of context-hint widgets
    (`WBP_SmartHint_*`, `WBP_ContextHint_C`, `WBP_InputActionHint_C`, `WBP_PassiveHint_*`).
    User asked specifically about reusing the buff-icon timeout behavior (Hunger/Executioner's
    Grace, boxed in a screenshot) — clarified that timeout isn't actually the deciding factor
    either way: buffs' auto-hide is backed by a real GAS gameplay-effect duration we can't fake
    from Lua, but we don't need to borrow it regardless, since ANY widget's lifetime can be
    self-managed with `ExecuteWithDelay` (same pattern as the existing DEL confirm-window timer).
    The real difference is what each widget is FOR: buff icons are icon-per-effect-type, not built
    to show arbitrary text; pickup notification already IS a free-form text message that appears
    and fades. **Decision: pursue `WBP_PickupNotification_C`/`_Container_C` first.**
    `dump_object.lua` (bundled in UE4SS's own `ConsoleCommandsMod`) only dumps PROPERTIES, not
    callable FUNCTIONS, so it can't answer "what do I call to add an entry" — added
    `Spawner.DumpNotificationFunctions()` instead: grabs a live instance of a matching class from
    `FindAllOf`, walks its `UClass` via `ForEachFunction` (parallel to `dump_object.lua`'s
    `ForEachProperty`), AND walks up `GetSuperStruct()` so inherited functions from a parent
    widget class aren't missed. Bound to **End** (`Config.KEYS.dumpNotifFuncs`) — corrected in
    item 22 below, End produced no output at all in this build and was switched to Pause.
22. **Toast finally works on-screen** (2026-08-06, continuing the same day). `End` produced zero
    log output (not even "key received"), unlike `Home` — switched the diagnostic key to `Pause`.
    The func-dump then found the real target: `WBP_SideNotificationsContainer_C` has
    `SpawnNotification`/`RemoveNotification`, but their only real parameter (`Notification`, an
    `ObjectProperty`) takes a **pre-built widget instance**, not text — so those functions alone
    can't drive a custom message. Checked whether anything in this UE4SS install (shared
    `UEHelpers`, every other installed mod, bundled docs) had a working precedent for
    constructing a UMG widget or setting `FText` from Lua — nothing did; `StaticConstructObject`
    itself was proven (other mods use it for non-widget UObjects), but never for UMG. Given the
    risk (splicing a new widget into live UI is a real mutation, unlike every prior read-only
    reflection dump — a bad call could hard-crash rather than fail cleanly, and `pcall` doesn't
    reliably catch native-side crashes), de-risked in two steps rather than committing blind:
    (a) construct a plain `/Script/UMG.TextBlock` via `StaticConstructObject` and set its text via
    `KismetTextLibrary:Conv_StringToText` + `SetText`, WITHOUT adding it to any viewport — confirmed
    safe in isolation; (b) then actually `AddChild` it into the live `vbox_Notifications`
    VerticalBox (a real, valid instance property on the container, found via property-value
    dumping) — `AddChild` succeeded but nothing rendered, traced to the container's own
    `bHidden=true` default (it normally only reveals itself via its own `CheckVisibility` logic,
    driven by `SpawnNotification`, which this approach bypasses). Forcing the container visible
    three ways after `AddChild` (`bHidden=false`, `CheckVisibility()`, `SetVisibility(Visible)`)
    fixed it — user-confirmed real, on-screen, readable text. This became the permanent mechanism:
    `Spawner.Toast` reuses the game's own native notification widget rather than any engine
    debug-output API, and rather than the Blueprint-only `SpawnNotification` pair.
23. **Toast UX pass** (2026-08-06, same day). Once the mechanism worked, several rough edges
    needed fixing before it was actually pleasant to use: (a) a bare `TextBlock` has none of
    `WBP_SideNotification_C`'s own width/font styling, so long messages ran off-screen at a large
    default font — fixed with `SetAutoWrapText(true)`, a fixed `SetWrapTextWidth`, and shrinking
    `Font.Size` directly on the constructed widget. (b) User asked for a "Spawned: X" toast
    matching despawn's own, added inside `Spawner.Spawn` itself (one place, covers every
    placement key) — gated on `not Spawner.restoring` (skip the dozens of calls
    `RestoreFromPersist` fires on world load) and a new `Spawner._suppressSpawnToast` flag (skip
    it specifically when the caller — Undo, cycle — already shows its own more specific toast, to
    avoid double-toasting). (c) User iteratively asked to silence every "nothing within Xuu ahead"
    toast (despawn, live-edit, cycle) and the per-nudge live-edit "Editing: ..." confirmation
    (fires on every arrow/PageUp/rotate press, too spammy when tapped rapidly) — all now log-only.
    Undo's "nothing to restore" was removed then explicitly restored at the user's request: an
    empty undo stack is a real, useful thing to know, unlike a targeting miss.
24. **Two reliability bugs found only through real use** (2026-08-06, same day). First: EVERY
    toast shown all session stayed on screen forever once several fired in quick succession
    (statue cycling alone fires 4+ within a second) — this UE4SS build apparently doesn't
    reliably run many independent overlapping `ExecuteWithDelay` callbacks (each toast had
    scheduled its own removal timer). Fixed with a single self-rescheduling ticker
    (`Spawner._activeToasts`, checked every 500ms) instead — the same proven pattern already used
    for `Spawner.LeashTick`, rather than N independent timers. Second: the container, once forced
    visible, stayed visible even when empty and sat on top of other UI (reported: it blocked
    clicks on the build menu). Fixed by re-collapsing it (`bHidden=true` + `CheckVisibility()` +
    `SetVisibility(Collapsed)`) the moment the active-toast list empties out, restoring its
    original click-through default state. Separately, the "waiting for you to move" toast (fired
    the instant the player pawn is detected, which can be WHILE the loading screen is still up,
    well before the HUD widget tree mounts) silently found no container and fell through to
    log-only even with a 4-try/2.4s retry budget — bumped to 20 tries/1s (~20s) once confirmed the
    later "base restored" toast for the same load only succeeds because it fires several seconds
    later, after `RESTORE_SETTLE_MS` + staggered spawn delays.
25. **Restore-lock: fixed a real duplicate-spawn bug** (2026-08-06, same day). User reported
    placing something manually right after a world load, then getting a duplicate of it once the
    deferred restore actually ran. Root cause: a manual placement writes to `persist.txt`
    immediately (`persistAppend` inside `Spawner.Spawn`), and `RestoreFromPersist` reads
    `persist.txt` fresh several seconds later (after `RESTORE_SETTLE_MS` + player-movement
    conditions) — if the manual placement landed in that window, its own persist line was already
    in the file by the time restore read it, so restore spawned it a SECOND time on top of the
    still-live original. Fixed with `restoreLockActive` in `main.lua`: every mod key locks
    (via `modGate`, the same chokepoint the Insert toggle already uses) the instant a world load
    is detected (`scheduleRestore`'s generation bump), and unlocks only once that restore chain
    genuinely concludes — restored something, found nothing to restore, or gave up waiting for a
    pawn. `Spawner.RestoreFromPersist` gained an optional `onComplete` callback, invoked at EVERY
    exit path (including the previously-silent "0 lines to restore" early return, which would
    otherwise have left keys locked forever on a fresh base) so `main.lua` learns exactly when
    it's safe rather than guessing a fixed delay. Separate from the user's own Insert toggle —
    they don't fight each other, and Insert still works throughout the lock window.
26. **Key-status visibility + configurable startup state** (2026-08-06, same day). Added
    `Config.KEYS_ENABLED_ONSTART` (default `true`) so players who'd rather opt in each session
    than remember to press Insert can start with keys off. User then asked for a status line
    showing current enabled/disabled state and which key toggles it — first added as a log-only
    startup line, then (clarifying "I meant... in the toast") moved to fire as a real on-screen
    toast, hooked into the SAME `unlockIfCurrent` callback the restore-lock (item 25) already
    calls — since that fires right after `RestoreFromPersist`'s own "base restored" toast, the
    two stack in the expected order without any extra bookkeeping.
27. **Cycle merged into one key; precision became a 4-level cycle** (2026-08-06, same day). User
    asked to extend Num+'s "cycle the targeted statue in place" to decorations too. Built as a
    separate key first (`Num .` / `NUM_DECIMAL`, added to `VK_FALLBACK` since — like every other
    numpad operator key — it's not in this build's `Key[]` table), then the user asked "are we
    not able to use the same key" — merged into one function, `Spawner.CycleNearestInFront`,
    replacing both `CycleNearestStatuePose` and the short-lived `CycleNearestDecor`: it searches
    the statue rosters first, then the decoration categories, and branches its per-kind logic
    (statues get a baked yaw correction + bounds-based floor re-leveling; decorations get neither,
    since `placeDecorEntry`'s own comment explains decoration bounds are unreliable for
    floor-snapping — kept the exact old X/Y/Z instead, same as a fresh placement's own
    `playerFloorZ()`-based approach would need adjusting anyway). The `Num .` bind and its
    `VK_FALLBACK`/config entries were removed again once merged. Separately, user asked for the
    Num- precision toggle to be a 4-level cycle instead of a binary on/off — changed
    `Spawner.editPrecision` (boolean) to `Spawner.editPrecisionScale` (number), cycling
    full(1.0) -> half(0.5) -> quarter(0.25) -> eighth(0.125) -> full via a small
    `PRECISION_LEVELS` table, toast-confirmed on every press.
28. **Third load-stage toast; debug tooling removed** (2026-08-06, same day). Added a toast at the
    moment `RestoreFromPersist` actually begins spawning (was previously log-only), so the full
    on-load sequence is now: "waiting for you to move" -> "restoring your base (N saved
    entries)..." -> "base restored (counts)" -> key-status line. With the toast investigation
    concluded and working end-to-end, removed all now-unneeded dev-tool diagnostics: the
    Home/Pause/Scroll Lock key binds, their `Config.KEYS` entries, and the four underlying
    functions (`DumpActiveWidgets`, `DumpNotificationFunctions`, `ProbeTextBlockConstruct`,
    `ProbeAddNotificationText`) — all safely removable now that `Spawner.Toast` itself is the
    permanent, proven mechanism; those three keys are free again for other uses.

29. **Senkamati helmet removal + a real mesh-component probe** (2026-08-09). User asked to remove
    the Warrior/Hunter's tribal helmet. Extended the existing HOME/PAUSE dev probe
    (`Spawner.DumpMeshComponentNames`, later also printing full asset paths + material names/
    paths) to list every `SkeletalMeshComponent` + its mesh on the targeted actor — the missing
    piece needed to find real component names instead of guessing (`Spawner.ApplyComposite`'s own
    lesson from an earlier session). Confirmed live: `SK_ArmorCreature_Senkamati_Warrior_Feather_
    02_Head` / `..._Hunter_Feather_01_Head`, each a component DISTINCT from their hair (dreadlocks/
    mohawk, its own separate component) — so hiding it reveals the hair underneath instead of
    leaving them bald, unlike the Caster's Head (which IS her hair, already handled by a REPLACE
    to dreadlocks rather than a hide, from an earlier session). Added `Warrior_Feather_%d+_Head`
    / `Hunter_Feather_%d+_Head` to `Config.DECORRUPT_CREW`/`DECORRUPT_HUNTER`'s `hides`. Confirmed
    working; this probe pair became the load-bearing diagnostic tool for everything below.
30. **Walk-AI experiment for Hunter/Caster/Healer — DISPROVEN, a wrong theory** (2026-08-09). User
    asked to give the Hunter/Caster/Healer MOBS a "default walk pattern" like the Warrior (a crew
    re-skin) has. Tried overriding `AIControllerClass` (pre-possess, in the deferred spawn window)
    to the Warrior's own working controller, then — when that had no effect — ALSO overriding
    `AIPawnParams`/`OverriddenAIPawnParams` (new `Spawner.SetAIPawnParams`) to the Warrior's own
    data asset. Both confirmed SETTING successfully via log (`AIControllerClass override set`,
    `AIPawnParams=ok`) but produced literally no visible change. Root cause, found only once the
    user clarified what "walk pattern" actually meant: the complaint was ANIMATION/POSTURE (a
    monstrous gait), not AI wandering — neither AIController nor AIPawnParams touches animation,
    that's the Mesh's AnimBlueprint, tied to the pawn's SKELETON. Reverted (`Config.
    SENKA_MOB_WALK_AI = false`, code left in place but dormant). **Lesson: get the user's literal
    meaning of an ambiguous term ("walk pattern") confirmed before spending a cycle on the wrong
    system** — AI-behavior and animation/posture are unrelated subsystems that happen to share a
    vague English description.
31. **Hunter/Caster converted from mob spawns to human-skeleton re-skins** (2026-08-09/10). Once
    the REAL ask was clear (normal human gait, not just movement), the fix was the Warrior's own
    established trick, applied to the other two for the first time: don't spawn the mob's own
    skeleton at all — spawn a human-skeleton pawn and apply the Senkamati composite armor to IT.
    Hunter reused the Warrior's own crew-Officer base (male). The Caster had no known male-only
    workaround (she needs a female body, and "no walking women exist in this game" was this
    project's own long-standing conclusion). Re-investigated that conclusion and found it was
    about specific classes THIS MOD had tried (a unique hireable employee, a unique quest NPC, the
    male-locked procedural Citizen_Walker) — not a survey of the whole game. A live probe of a
    genuinely walking, non-unique female Handyman NPC (`BP_NPC_Handyman_Gatherer_C`, found by
    aiming the HOME probe at a real one in the world) confirmed a normal human female body
    (`SK_Adventure_Female_01`) + the same proven Handyman walk AI already used elsewhere in this
    mod — reopening a door this project had considered closed. Composite armor `params` asset
    paths for Hunter/Caster were GUESSES mirroring the Warrior's own confirmed naming convention
    one folder over — both resolved correctly on the first live test (`Spawner.SetCompositeParams`
    logs "MISS" unconditionally, so a wrong guess would have been immediately visible). Both
    `senkaMobFix`/`senkaCrewFix` and `Config.SENKAMATI_LOOKS`/`RESTORE_RULES` were restructured to
    dispatch on the pawn's base ("crew" human re-skin vs. "mob" native skeleton vs. later
    "corrupted", see item 34) rather than the old single mob-or-crew branch.
32. **Pelvis-gap saga on the new human re-skins** (2026-08-10). The new Hunter/Caster showed a
    genuine see-through hole at the pelvis, confirmed present the instant they spawn (not a
    settle-timing artifact — tried assuming it was, wasted a round trip). Root cause, confirmed
    by a direct side-by-side (`Testbed.SpawnCompareMobCaster`, a temp dev key spawning her
    original mob body for comparison): the tribal "Feather_Legs" piece is a hanging-fringe/grass-
    skirt design whose gaps are meant to show the WEARER'S OWN SKIN — present on the mob's own
    body, absent on any human body mesh in this game (confirmed via a genuinely useful technique:
    Python-scanning the raw bytes of the game's own `.utoc` pak-index files for printable ASCII
    runs found thousands of real, readable asset filenames despite the container format being
    otherwise opaque binary — searched ~56k unique strings for "Nude"/"Naked"/"Undress" and found
    none for any human body, confirming no undressed body variant exists in this game at all).
    Tried, in order: (1) replace the Legs piece with the human base's own native underwear mesh,
    recolored to skin tone — closed the gap, but the mesh's own rounded "bloomers" SHAPE read as
    an obviously separate garment regardless of color; (2) same mesh recolored to the tribal
    fringe material instead — material confirmed correctly applied via probe, but rendered as
    light denim, not the dark tribal look, because that material likely depends on UV/vertex-
    color data baked into the ORIGINAL Senkamati mesh that a borrowed human mesh doesn't have —
    swapping materials further can't fix a mesh-data dependency; (3) a different mesh entirely
    (`SK_Armor_Bandit_Waist`, spotted worn natively by a townsfolk Herbalist) — didn't work either.
    Landed on (1) again, WITHOUT the recolor — the underwear mesh's own default material, plain
    and simple, is the least-wrong-looking option found. Applied to Hunter and Caster's re-skins;
    deliberately NOT applied to the Warrior (see item 34).
33. **Silencing the female re-skin's voice lines** (2026-08-10). The Handyman Gatherer base (item
    31) carries her own idle/bark voice lines via a plain engine `AudioComponent` ("AudioVoice").
    New `Spawner.StripVoice`, reusing the existing `stripComponentsOfClass` helper (proven safe
    already for `StripInteraction`/`StripQuestScenario`), destroys just that component class —
    confirmed narrow enough to not also catch the R5-custom sound components (footsteps, cosmetic
    sounds) that live on the same pawn under different class names.
34. **Final polish + a 14-entry comparison roster** (2026-08-10, closing out this arc). Once the
    core fixes landed, iterated on exactly what should be kept: (a) de-corrupting the Hunter/
    Caster's ORIGINAL mob-body look was changed to ONLY swap skin tone/eyes/hair colour — no
    longer hiding armor pieces or facial hair, so the user could actually see what a bearded
    Hunter/full claw-armor Caster look like undiluted; (b) the Warrior was reverted to EXACTLY his
    pre-session recipe (skin/eye/hair/weapon/dreadlocks, no pelvis-gap underwear fix) at the
    user's explicit request — the gap is real on him too, just hidden by his own armor's longer
    fringe, and not worth the visual tradeoff; (c) the Healer was removed from the roster entirely
    (visually identical to the Caster, not worth 5 more comparison rows); (d) a `helmet` toggle
    (new `rulesWithHelmet` in testbed.lua) lets any entry keep the tribal headdress visible by
    filtering out any hide/replace rule whose match pattern targets `_Head`, rather than hand-
    duplicating every ruleset into with/without-helmet pairs. `Config.SENKAMATI_LOOKS` became a
    14-row comparison roster (Num7): Warrior x2 (helmet on/off), Hunter x4 (mob-body vs. re-skin,
    each x2 helmet), Caster x4 (same pattern), plus Warrior/Hunter/Caster x1 each "as original"
    (de-corrupt SKIPPED entirely — the pawn's genuine corrupted look, still pacified+friendly so
    it's safe to stand next to). Restore-on-reload for the "mob"/"corrupted" kinds can't recover
    which exact row a persisted actor was (persist.txt doesn't record it) — falls back to a fixed
    default (de-corrupted, helmet hidden) and documents the limitation; treated as acceptable for
    what is fundamentally a comparison/testing roster. Shipped as v1.3.0.

35. **Fourth session: walking Letty/Marita/Merchant, and settling color/tattoos for good**
    (2026-08-10/11). Revisited turning standing/sitting women statues into walkers (a question
    this project had visited before) — first tried giving the STATUES themselves Handyman AI
    directly (confirmed live: they never animated), then switched to the proven RE-SKIN approach
    already used for Warrior/Hunter/Caster: spawn the walking female base (`Config.
    SENKA_FEMALE_BASE_CLASS`, the Handyman Gatherer) with the Brethren-Woman composite look, then
    `Spawner.DeCorrupt` it onto specific real characters. `Config.FEMALE_WALKER_OVERLAYS` (Letty/
    Marita/Buccaneers Merchant_01) and `Testbed.TestFemaleWalkerReskin` (Numpad Decimal, cycles the
    roster) are the lasting result — iterated through several real bugs found by live testing
    (T-posing from body-swap rules, now permanently disabled per-entry; headwear rolling under two
    DIFFERENT naming conventions, `_Headband` vs `_Hat`, fixed with dual match patterns AND a
    positional `Spawner.ForceHeadwear` guarantee for Marita/Merchant; Letty's missing belt/frog
    turned out to not exist on her at all, not a hide-rule gap). Landed policy (RedFalcon's calls): Letty
    never wears a hat but a headband is fine; Marita/Merchant always guarantee SOME hat via
    `forceHat`; the generic Standing_01/Sitting_01 statues got NO overlay at all (revert — "look
    fine on spawn other than color"). A "Stripped" diagnostic entry (hide every garment) confirmed
    the Senkamati pelvis-gap issue (item 32) does NOT occur on this body/skeleton — it's specific to
    the Senkamati Feather_Legs piece, not a flaw in this human base.
    **Tattoo investigation** (inconclusive, not pursued further): confirmed real NPCs (Letty,
    Marita, the Merchant statue) DO show tattoos and the SAME tattoo recurs across different
    characters, suggesting a shared/common asset — but four separate probes all came back negative
    for WHERE it lives: the `BodyDecor` texture parameter (identical tattooed vs. not), extra mesh/
    decal components (identical component lists), `StaticSwitchParameters` (0 entries on every
    material, every character), and `VectorParameterValues` (only one entry anywhere, `BaseColor` on
    the EYE material — unrelated). A player-only "Hero" tattoo `CompositeMeshComponentParams` asset
    (`DA_Hero_CompositeMeshParams_SkinDecor_*`) was tried on an NPC and **crashed the game, twice,
    confirmed** — reverted immediately; `Config.TATTOO_TEST_PARAMS` stays in `config.lua` only as a
    documented "do not reuse `Hero_`-prefixed CompositeMeshParams on an NPC" record.
    **Color investigation (hair/outfit tint, and garment palette) — CONCLUDED DEAD, do not revisit
    without a genuinely new theory.** Three separate mechanisms were tried and all failed the same
    way: (1) `comp:SetColorControllerValue()` (the low-level per-slot tint, confirmed present for
    Hairs/Torso/Legs/Feets/Hands/Headgear/Waist/Mask/Cape via a `GetColorControllers()` probe) sets
    and reads back correctly but never visibly renders, even retried right after a hair-STYLE mesh
    swap (in case only the original mesh's material was untintable) and even with the same
    `SetActorHiddenInGame` render-refresh trick that fixed an unrelated transform-desync bug
    elsewhere in this file. (2) `comp.ColorParams` (a whole-look palette asset — this game already
    ships one per faction/role as `"..._PresetColor"`, found unused in `Config.FACTION_VISITOR_
    LOOKS`) set POST-build + a proven rebuild-trigger sequence (`ConstructVisualFromParams` +
    `Start`/`EndCharacterEdit`, the same recipe `Spawner.ApplyComposite` already uses successfully
    for outfit/archetype changes) ALSO resolves and "applies" cleanly but never visibly renders.
    (3) `comp.ColorParams` set PRE-build (the only remaining lever, since both post-build attempts
    were silently inert) reproduces a **CONFIRMED FATAL native crash** — this was already known from
    2026-08-07 on the ordinary crew class (see `Config.FACTION_VISITOR_LOOKS`' own header comment,
    which is why `Testbed.SpawnCrew` never wires `colorParams` in) and was re-confirmed here, with
    the user's explicit sign-off to test it, on the Handyman-based female walker too — so it's not
    class-specific, it's a hard engine constraint. `ue4ss.log` timestamps pinned the crash to ~2ms
    after `comp.ColorParams = color` itself succeeds, meaning the assignment is fine and the
    engine's OWN composite-build step crashes consuming it. **`persist.txt` was confirmed clean
    after both crashes** — a native crash this early in construction happens before `Spawner.Spawn`
    ever reaches its own `persistAppend` call, so this specific failure mode carries no
    crash-on-next-restore risk, unlike a crash that happened after persistence. **Conclusion: outfit
    color/palette and hair color are not achievable in this mod, full stop** — the game only
    consumes `ColorParams`/`ColorController` values ONCE, during a pawn's actual initial
    construction; nothing callable afterward re-runs that step, and forcing it earlier crashes.
    **Skin tone and hair STYLE, by contrast, both work fine** and are unaffected by any of this:
    skin tone is a plain material SWAP between the game's 7 built-in ethnicity families
    (`MI_<Family>_Female_<Size>`, matched via `Spawner.DeCorrupt`'s existing `swaps` mechanism —
    the exact technique `DECORRUPT_MOB` already used for ethnicity swaps) and hair style is a mesh
    SWAP across the `Hair/Female/` folder's ~16 style families (via `replaces`, the same `"Hair_"`
    pattern Letty/Marita/Merchant's own overlays already use) — both proven live, no crash, no
    silent no-op.
    **Cleanup**: the standalone test tool built to run these investigations (`Testbed.
    TestColorRandomization`, Scroll Lock, plus its supporting `Spawner.SetColorControllers`/
    `ApplyHairColor`/`RandomizeGarmentColors`/`ApplyColorParams` and `Config.SKIN_FAMILIES`/
    `SkinFamilySwapRules`/`FEMALE_HAIR_STYLES`) was removed once these questions were settled —
    findings are preserved in this item and in short pointer-comments left at each old call site,
    not by keeping dead code around. The "Stripped" diagnostic overlay entry (its own question
    already answered, see above) was removed the same way. `Testbed.TestFemaleWalkerReskin`
    (Numpad Decimal) — the actual walking-women feature — is untouched and stays on. Shipped as
    v1.3.5.

36. **Skin tone + hair variety reinstated as a real feature, hat/hair clipping fully root-
    caused, and restore fidelity for the female walkers** (2026-08-11, same day, continuing
    past v1.3.5). Turned out item 35's cleanup was premature on the skin/hair-style front —
    RedFalcon asked to bring it back, "in case its related to the specific hairstyle associated
    with that actor" for the color question specifically (a dead end, see below) but a real
    yes for skin tone + hair STYLE, which DO work. `Config.SKIN_FAMILIES`/
    `SkinFamilySwapRules`/`FEMALE_HAIR_STYLES` came back as permanent config (not tied to a
    test key this time): `Testbed.TestFemaleWalkerReskin`'s two generic slots
    (Standing_01/Sitting_01) now always randomize skin tone + hair on every press, and —
    at RedFalcon's further request, "to see how it looks" — Letty/Marita/Merchant ALSO get
    randomized skin tone layered on top of their fixed garment/hair (hair style stays fixed
    per character on purpose).
    **Color re-tested once more, conclusively dead**: tried tinting hair AFTER a hair-style
    mesh swap (in case only the ORIGINAL mesh's material was untintable) — still silently
    inert, confirming (a third time, see item 35) that color is a build-time-only input.
    **Hat/hair clipping — three real bugs, found only by asking RedFalcon to grab live HOME+PAUSE
    probes rather than guessing further**: (1) the hides pattern `"Female_Hat"` never matches
    a mesh literally named `SK_Armor_Flibustier_03_Female_BandanaHat` — "Female_Hat" isn't
    an actual substring of "Female_Banana"+"Hat" run together — so that hat rolled past the
    hide check every time regardless of retry budget; broadened to plain `"Hat"`/`"Headband"`
    (dropped the `"Female_"` prefix requirement), applied to both the generic Sitting overlay
    and Letty's own (Marita/Merchant were already shielded by their `forceHat` guarantee, so
    this was a real gap only for Letty). (2) A SECOND probe round found a THIRD naming
    convention slipping past even that: a plain `..._Female_Bandana` piece with neither "Hat"
    nor "Headband" in its name at all (read as a tight skullcap under the hair) — added
    `"Bandana"` to the generic Sitting overlay's hides (deliberately NOT to Letty's — a plain
    bandana reads closer to her already-accepted "headband is fine" policy than to the "hat
    looks wrong" one). (3) Root design fix, not just a pattern chase: split the two generic
    slots by POLICY instead of trying to reconcile hat+hair on the same actor forever —
    Standing ALWAYS gets a hat (`Spawner.ForceHeadwear`, same guarantee Marita/Merchant use)
    paired with a NEW `Config.FEMALE_HAIR_STYLES_HAT` roster (the `_SuspendHat_Female`/
    `_SuspendedHat_Female` variant of each style family — exact names pulled from the
    manifest, not guessed — built by the game to sit correctly under a hat, the same
    mechanism Marita's Wig / the Merchant's ShortBob already relied on); Sitting NEVER gets a
    hat (hidden outright) paired with the plain Default hair roster. Also widened Standing's
    forced hat from one fixed mesh to a 7-option `Config.GENERIC_FEMALE_HATS` roster
    (Musketeer/BandanaHat/Bandit/Brigant/Mercenary/Jeweler/Vanilla, all confirmed real assets
    from the manifest) per RedFalcon's request for variety — "it's ok to have the other variations
    as well, such as bandana hat."
    **Restore fidelity**: RedFalcon pointed out none of this survived a reload — `Testbed.
    RestoreHook` had no rule for `SENKA_FEMALE_BASE_CLASS` at all, so restored walkers came
    back as the untouched base composite. First fix was `Testbed.ApplyRandomFemaleLook` (a
    fresh random roll on restore, better than nothing but couldn't recover which character a
    given actor WAS). RedFalcon then asked to actually persist that, with one explicit constraint:
    don't break old saves. Extended `persist.txt` with a 12th field, `look.reskinTarget`
    (which `FEMALE_RESKIN_TARGETS` entry a spawn was standing in for) — see this file's own
    "persist.txt format" section above for the full backward-compatibility contract (field
    appended at the end, missing on old lines is treated as "unknown" not an error, nothing
    gets rewritten/converted since old lines never recorded this in the first place).
    Refactored the overlay-selection logic that used to live inline in
    `TestFemaleWalkerReskin` into one shared `Testbed.ApplyFemaleReskinTarget(actor,
    targetName)`, called by BOTH the live key and the new `RESTORE_RULES` entry (last in the
    list, after the Senkamati Caster-F/Healer rule which already claims this same base
    class first). Along the way, upgraded the old single global `femaleReskinBusy` flag (which
    blocked ANY new placement while ANY one was still processing) to a per-target-name busy
    table — restore can now process several different female walkers concurrently without
    them fighting each other, while still guarding the real collision case: two actors
    touching the SAME named overlay's shared `replaces`/`hides` rule tables at once.
    **Topless bug — INITIAL DIAGNOSIS WAS WRONG, corrected same day**: RedFalcon live-probed two
    actors that spawned without a Torso piece. First theory (14 components, no Torso in the
    list) assumed this was the SAME pre-existing architectural gap already documented for
    the Buccaneers Merchant — a genuine composite omission `Spawner.DeCorrupt` could never
    catch. Built `Spawner.DespawnActor(actor)` (a despawn-by-REFERENCE primitive —
    `DespawnNearestInFront` only despawns by proximity to the player — that destroys the
    actor and cleans up its tracking/persist.txt entry, returning `{class, home, yaw}`) plus
    a despawn+respawn retry in `Testbed.ApplyFemaleReskinTarget`. RedFalcon then reported it STILL
    happened and gave the actual diagnostic clue: **"the spawn before the processing is NOT
    topless"** — meaning the composite genuinely has a torso at spawn time, and OUR OWN
    post-processing was removing it, not a pre-existing composite gap at all. Root cause:
    `Spawner.ForceHeadwear`'s positional "grab the first real non-body component" logic
    (see its own comment) was only ever validated by probing Marita/Merchant, whose
    composites reliably roll WITH a headwear piece. The generic Standing slot can roll with
    NO headwear component at all (confirmed by probe) — when that happens, "first real
    component after the body" is the TORSO, and `ForceHeadwear` was overwriting it with a
    hat mesh unconditionally. Fixed two ways: (1) hardened `ForceHeadwear` itself with an
    exclusion list (`Torso`/`Legs`/`Feet`/`Hand`/`Belt`/`Frog`/`Sling`/`Eyebrows`/`Hair_`) so
    it now refuses to grab any KNOWN non-headwear piece even as a last resort, returning
    false instead of clobbering a real garment; (2) made Standing's overlay try a
    CONTENT-MATCHED `replaces` rule (`Hat`/`Headband`/`Bandana` patterns, same safe mechanism
    every other DeCorrupt rule in this file already uses) as the PRIMARY mechanism, with
    `ForceHeadwear` demoted to a backup for the rarer case nothing matches at all. Order
    matters in that `replaces` list: several hairstyle mesh names literally contain "Hat"
    (e.g. `SK_Hair_Wig_02_SuspendedHat_Female`), and `Spawner.DeCorrupt`'s replace loop
    checks every rule against the same captured mesh name without breaking after a match —
    whichever rule is listed LAST wins a collision — so `Hair_` is deliberately the last
    entry, not the first. **Lesson for next time a symptom like this shows up: ask "does it
    happen BEFORE or AFTER our own post-processing?" before assuming a pre-existing engine
    gap** — that one question is what actually found this, after an entire wrong turn.
    The `Spawner.DespawnActor` + retry mechanism built for the (wrong) first theory was kept
    anyway — a genuine composite-omission case (the ORIGINAL Merchant finding, which may
    still be real and separate from this) still has no other fix, so the retry is harmless
    insurance layered under the real fix above, not removed.

37. **Same-day follow-ups: pattern collisions, a real multi-actor restore bug, async-aware
    restore messaging, and extending the persisted-look fix to Senkamati** (2026-08-11,
    continuing item 36). Several more real bugs, each found by RedFalcon's own live testing/
    probing rather than guessed:
    - **Hair disappearing under the hat on retry passes**: the same-pass ordering fix
      (`Hair_` checked last) wasn't enough — `Spawner.DeCorrupt`'s retry loop re-reads each
      component's CURRENT mesh name every pass, and several hairstyles' own names contain
      "Hat" (`SK_Hair_ShortBob_SuspendHat_Female`), so a LATER pass would match the "Hat"
      rule against the hair component's own (already-correct) name and overwrite it again.
      Fixed by anchoring every Hat/Headband/Bandana pattern to `^SK_Armor_` — real headwear
      always has that prefix, no hair mesh ever does, so these rules can no longer match a
      hair component on any pass regardless of what substring its name has.
    - **Headband policy split**: Standing's forced-headwear roster (`Config.
      GENERIC_FEMALE_HATS`) dropped headbands per RedFalcon's call — hats/bandanas only. Sitting's
      hides list dropped "Headband" in the OTHER direction — RedFalcon's design point: headbands
      are thin enough to be designed to coexist with regular hair (unlike a rigid hat, which
      needs the dedicated SuspendHat hair variant), so a naturally-rolled one is left alone
      there, while a hat or the tight "Bandana" skullcap piece still gets hidden.
    - **Multi-actor restore bug (real, confirmed via RedFalcon's own multi-placement + reload
      test)**: the per-target busy-guard (item 36) prevented rule-table collisions but had no
      queue — a SECOND actor of the same target arriving while the first's ~12s retry loop
      was still running got silently skipped and never reprocessed, so only the first of each
      type ever came back correctly after a reload. Fixed with a real queue
      (`reskinTargetQueue`) drained one at a time as each target's busy flag clears
      (`releaseAndDrainTarget`) — nothing gets dropped now, it just waits its turn.
    - **"Base restored and ready" fired too early**: it only ever tracked whether every
      restoreHook had been CALLED, not whether the background work each call kicks off had
      actually FINISHED. Added an opt-in counter (`Spawner.postProcessPending`, `Begin`/
      `EndAsyncPostProcess`) that `Testbed.ApplyFemaleReskinTarget`'s restore path uses to
      report true completion (threaded through retries AND the new queue via an `onSettled`
      callback parameter); `scheduleRestorePostProcess` now polls it before firing the
      completion toast — with a hard `Config.POSTPROCESS_WAIT_TIMEOUT_MS` (30s) safety valve,
      since this gates the same signal that unlocks `main.lua`'s mod keys after a reload and
      must never hang forever. Also added a "post-processing N mover(s)..." toast at the
      START of this phase, which didn't exist before.
    - **"Hat hair but no hat" (baldness), generalized from the topless check**: any overlay
      with `forceHat` set pairs a hat-STYLED hair (built assuming a hat covers the top) with
      an intended hat — when neither content-matching nor the (correctly hardened, see item
      36) `Spawner.ForceHeadwear` found anything safe to turn into a hat, the hat silently
      never landed but the hair stayed hat-styled, reading as bald. The existing topless
      despawn-retry now ALSO checks this (via the same `^SK_Armor_.*Hat/Headband/Bandana`
      patterns) for any overlay that wanted a hat — covers Marita/Merchant's own earlier
      "sometimes bald" report too, since they use `forceHat` as well.
    - **Senkamati persisted-look extension**: RedFalcon asked whether `Config.SENKAMATI_LOOKS`
      (the 14-row Warrior/Hunter/Caster comparison roster) needed the same treatment —
      confirmed yes for the SAME reason (persist.txt couldn't recall which row, documented
      limitation from item 34), explicitly declined for the topless-style retry ("i never
      saw toplessness on that group"). Added `senkaRowKey(s)`/`parseSenkaRowKey(key)` — a
      `name|kind|helmet` composite string — reusing the SAME `reskinTarget` persist field the
      female walkers use (see "persist.txt format" above) rather than adding a second field.
      For the CREW rows (Warrior/Hunter/Caster-F), the character NAME was already correctly
      recovered from `look.params` string content even before this — the row key only fills
      in the one thing that couldn't: the helmet flag. For the MOB/CORRUPTED rows, NO `look`
      table was passed to `Spawner.Spawn` at all before this — nothing was recorded — so this
      is a full fix there, not just a helmet-flag patch. Both `RESTORE_RULES` entries fall
      back to their OLD fixed-default behavior for a pre-1.3.x line with no reskinTarget.
    - **Masked Senkamati "don't load properly" — a real shared-mutable-rule-table bug, same
      class as item 36's female-walker fix**: `rulesWithHelmet(baseRules, showHelmet)`'s
      `showHelmet=false` path used to return `baseRules` COMPLETELY UNCHANGED — the literal
      `Config.DECORRUPT_CREW_*`/`DECORRUPT_HUNTER`/etc. table, shared by EVERY actor of that
      character regardless of helmet. `Spawner.DeCorrupt` caches resolved-asset and
      "already-replaced" state directly ON those rule objects — now that the persisted-row
      fix above lets restore place several Senkamati (helmet-on AND off) concurrently, they
      were mutating the SAME shared objects underneath each other. Fixed by making
      `rulesWithHelmet` ALWAYS deep-copy every swap/replace entry (`deepCopyRuleList`,
      hides are plain strings so safe to share) regardless of the helmet flag, so no two
      calls ever share a mutable rule object. Also gave each Senkamati spawn's LABEL a
      kind+mask suffix (`SENKA_Hunter_mob_Mask` vs `SENKA_Hunter_mob`, etc., separate from
      `senkaRowKey`'s persist-identity string) — RedFalcon's own diagnosis ("their names arent
      differentiated") was right in spirit even though the deeper bug was the shared rule
      tables, and distinguishable labels make this kind of thing easier to spot in logs.
    - **Female walker roster renamed + reordered**: `Testbed.FEMALE_RESKIN_TARGETS` was
      `{"Female_Standing_01", "Merchant", "Letty", "Marita", "Female_Sitting_01"}` (internal
      class-path leftovers for the two generic slots, confusing in logs/toasts) — now
      `{"Woman With Hat", "Woman With Hair", "Merchant", "Letty", "Marita"}` in that order.
      These strings are BOTH the display label and the persisted `reskinTarget` value (not
      just cosmetic) — `Buccaneers Merchant_01` in `Config.FEMALE_WALKER_OVERLAYS` was
      renamed to plain `"Merchant"` to match, and `Testbed.ApplyFemaleReskinTarget`'s
      Standing-branch check updated from `"Female_Standing_01"` to `"Woman With Hat"`. A
      pre-rename persisted `reskinTarget` value falls through to the generic "Woman With
      Hair" branch (same graceful-degradation contract as a missing field entirely).

38. **Masked Senkamati, take two: the REAL bug was `DeCorruptByClass` touching every actor
    of the class, not just `rulesWithHelmet`** (2026-08-11, same day). Item 37's fix (deep-
    copying rule tables) was real and worth keeping, but RedFalcon reported the symptom was still
    happening: "looks like the script that removes the mask, removes it from the masked
    version too." Deep-copying the RULES doesn't help if the function applying them is
    itself grabbing every live actor of the class regardless of which rules belong to which
    actor — and that's exactly what `Spawner.DeCorruptByClass(shortClassName, rules)`
    (`spawner.lua`) did: `FindAllOf(shortClassName)` returns every live actor sharing that
    mob blueprint, and the old code ran `Spawner.DeCorrupt(a, rules)` on ALL of them, not
    just the one actor this particular `tryFix()` retry loop was responsible for. The
    `FindAllOf`-instead-of-captured-ref indirection exists for a real, narrower reason (its
    own comment: `K2_GetComponentsByClass` returns 0 components on a captured spawn
    reference, but works via a fresh `FindAllOf` handle) — it was never meant to broadcast
    to every instance of the class, that was just an unexamined side effect. Only
    `senkaMobFix` (the "mob"-kind rows: original-skeleton Hunter/Caster, both helmet
    variants) goes through `DeCorruptByClass` — `senkaCrewFix` (the re-skinned rows) already
    calls `Spawner.DeCorrupt(actor, rules)` directly on its own specific actor and was never
    affected. So with a helmet-ON and a helmet-OFF mob-body Hunter both alive at once (side
    by side in the Num7 roster, or both restored after a reload), each row's own retry loop
    fires roughly every 800ms for up to 12 tries, each call re-applying ITS OWN `rules` to
    BOTH actors — whichever row's retry happened to fire last at any given moment silently
    decided the headdress state for every actor of that class, including ones that should
    have kept it. Fixed by adding an optional third parameter to `DeCorruptByClass`
    (`targetActor`, passed by `senkaMobFix` as its own `actor`): reads `targetActor:GetFName()`
    off the STALE captured reference (confirmed safe — unlike the component-array reflection
    call this workaround exists for, plain `GetFName()` already works fine on a captured ref
    elsewhere in this file, e.g. `Spawner.ActivateCharacter`) and filters the fresh
    `FindAllOf` list down to the one entry whose `GetFName()` matches, before calling
    `Spawner.DeCorrupt` on it. No `targetActor` passed = old "every live actor" behavior,
    preserved for backward compatibility (this is the only call site today, but the function
    is a small standalone primitive). **Lesson: a "de-corrupt by class instead of by actor
    reference" helper is inherently multi-actor-unsafe the moment two actors of that class
    can be alive with DIFFERENT intended rules — the original comment justified WHY it reads
    a fresh reference, but never flagged that its `FindAllOf` sweep has no actor-scoping at
    all. When reviewing a "grab everything of class X" helper, check not just whether it
    WORKS but whether anything about its call site assumes there's only ever one X.**

39. **Masked Senkamati, take three: a delimiter collision, independent of item 38's bug**
    (2026-08-11, same day). Item 38's `DeCorruptByClass` fix was real and necessary, but
    RedFalcon tested a full reload afterward and reported "on reload none of them end up with
    masks" — not just the colliding pairs, ALL of them, every time. Root cause: `senkaRowKey`
    (item 37) joined `name`/`kind`/`helmet` with `"|"` (e.g. `"Hunter|mob|true"`) and wrote
    that into persist.txt's field 12 — but persist.txt's own line format ALSO uses `"|"` as
    the delimiter between its 12 top-level fields (`parsePersistLine`, `spawner.lua`), with
    no escaping mechanism. A reskinTarget value containing its own `"|"` characters doesn't
    survive as one field — `"Hunter|mob|true"` gets sliced into three pieces by the OUTER
    split, so `parts[12]` comes back as just `"Hunter"` (the rest silently become ignored
    trailing parts). `parseSenkaRowKey`'s pattern expects all three segments together and
    never matches a single `"Hunter"`, so it returns `nil` unconditionally on every restore —
    both `RESTORE_RULES` entries then fall through to their pre-1.3.x fixed default (helmet
    hidden), regardless of what was actually saved. This bug predates and is completely
    independent of item 38's collision bug (it would have produced the exact same symptom —
    no masks after reload — even with only ONE Senkamati of a given class alive); both were
    real and both needed fixing separately. Fixed by switching the internal separator to
    `"::"` (two colons), which cannot collide with the outer `"|"` split and doesn't appear
    in any Senkamati name/kind string or the `"true"`/`"false"` helmet encoding. **Lesson:
    any value that gets embedded inside ANOTHER delimited format (here, a composite identity
    string riding inside a pipe-delimited persist line) must use a separator that's provably
    disjoint from the OUTER format's own delimiter — reusing the same character "because it
    already looks like a natural join" is exactly how this slipped through initially.** The
    female walkers' own `reskinTarget` values (plain names like `"Letty"`, `"Woman With
    Hat"`) were never at risk of this — they don't join multiple values into one field, so
    there's nothing for the delimiter to collide with; this class of bug only exists for
    `senkaRowKey`'s composite encoding.

40. **A real native crash during restore, root-caused to concurrent composite surgery, and a
    global serialization fix; toast labels for the walking women made descriptive** (2026-08-11,
    same day, after RedFalcon shipped 1.3.5 and came back with two more reports). First, a small one:
    RedFalcon asked for the "Spawned: X" toast to show the actual character name ("Letty", "Woman
    With Hat", etc.) when placing a walking woman instead of the old internal
    `"TESTWALKRESKIN_<n>"` placeholder label. Fixed by using `targetName` itself as the `label`
    argument to `Spawner.Spawn` in `Testbed.TestFemaleWalkerReskin` (and in
    `ApplyFemaleReskinTarget`'s own despawn/retry respawn, which previously used a separate
    hard-coded `"TESTWALKRESKIN_RETRY"`) — `label` is exactly what the existing "Spawned: %s"
    toast (`Spawner.Spawn`'s own comment, item 23) echoes verbatim, so no toast-specific code was
    needed, just picking a better label at the source.
    Second, a real one: RedFalcon reported the game crashed while restoring a save. `ue4ss.log`
    confirmed a genuine native crash — the log simply STOPPED at 20:42:56.98 with no shutdown
    line, no exception, nothing after it (the exact signature every other confirmed native crash
    in this project has had — Lua errors get caught and logged; this didn't). At that moment: 9
    saved entries were restoring, including at least two Lettys and two Merchants (both logged
    "already being processed... queued"), and the very last line was mid-way through the restored
    Warrior's de-corrupt retry loop (`senkaCrewFix tryFix: name=Warrior try=3`) — while at least
    one Letty and one Merchant were ALSO concurrently mid-processing their own de-corrupt/reskin
    retry loops in the background. Touching ONE actor's composite while ITS OWN build is still
    settling was already a confirmed crash trigger in this project (the Warrior/Caster build-delay
    comments elsewhere in this file exist because of exactly that) — what had never been tested
    until this session's own concurrency work (the per-target female-walker queue, item 36; the
    Senkamati restore-row fixes, item 37) is whether touching TWO DIFFERENT actors' composites AT
    THE SAME TIME can also crash it. The evidence says yes: before this session, restore's post-
    processing had much less real concurrency; now it routinely does.
    **Fix**: added `Spawner.RunSerialized(fn)` (`spawner.lua`) — a GLOBAL one-at-a-time queue,
    separate from (and stricter than) the existing per-target-name busy-guard/queue (item 36),
    which only ever protected against the SAME character colliding with itself. `fn(done)` runs
    immediately if nothing else is active; otherwise it queues and waits its turn; `fn` must call
    `done()` itself exactly once when its own work — including any retry/respawn chain — has
    genuinely finished. Every call site that does composite/component surgery now routes through
    it: `spawnCleanSenkamati`'s crew and mob branches (the live Num7 key), both Senkamati
    `RESTORE_RULES` entries, `Testbed.TestFemaleWalkerReskin` (the live Numpad-Decimal key), and
    the female-walker `RESTORE_RULES` entry. `senkaMobFix`/`senkaCrewFix` gained a new optional
    `onDone` parameter (called at every exit path — invalid actor, decorrupt skipped entirely, or
    the retry loop's natural end whether converged or exhausted) so callers have a real completion
    signal to hook `done()` to; `ApplyFemaleReskinTarget` already had one (`onSettled`, item 37),
    reused directly. **Bonus fix along the way**: neither Senkamati `RESTORE_RULES` entry had ever
    called `Spawner.BeginAsyncPostProcess`/`EndAsyncPostProcess` (item 37's own mechanism) — only
    the female-walker rule had — so "base restored and ready" could already have fired before a
    restored Senkamati's de-corrupt retry loop actually finished; both entries now participate.
    **The old per-target busy-guard/queue (item 36) is now believed dead in practice** (analysis,
    not yet re-confirmed live): since every entry point serializes globally, a second call for the
    same character name can no longer start while the first is still mid-flight, so its "already
    busy, queue it" branch should never trigger anymore — left in place as a harmless safety net
    (documented at its own definition) rather than removed, since deleting it would silently
    reintroduce the original abandoned-actor bug if a future caller ever calls
    `ApplyFemaleReskinTarget` directly, bypassing `RunSerialized`. **Trade-off, stated plainly**:
    restoring a base with a lot placed will now take noticeably longer wall-clock time (everything
    that touches a composite happens strictly one actor at a time instead of overlapping) — an
    intentional, explicit trade for not crashing, confirmed acceptable to RedFalcon before implementing.
    **Not yet re-tested live** — this fix is deployed but unconfirmed against a real reload of a
    save with the same shape (several Senkamati + several female walkers) that crashed originally.
    **Separately reported, not yet investigated**: RedFalcon also said the walking women (specifically
    — "the senka are fine") still audibly talk despite `Spawner.StripVoice` being called on every
    one of them. Code inspection didn't find an obvious cause — `StripVoice` and the interaction/
    quest-scenario strips are already applied identically to the Senkamati Caster-F/Healer, which
    share the exact same base class and are NOT reported as talking — so this needs a live
    `ue4ss.log` capture (specifically the `[strip] /Script/Engine.AudioComponent -> N matching
    component(s) found` line for a talking women actor) before guessing further; RedFalcon hadn't
    reproduced it yet as of this session's end. Revisit once that log data exists — don't guess
    blind on this one, this project has been burned by that before (item 30).
    **Follow-up, same day**: RedFalcon reported strict one-at-a-time made a big restore take
    noticeably longer, and asked to try 3 concurrent instead. `Spawner.RunSerialized` changed
    from a single busy flag to an active-count against `Config.POSTPROCESS_MAX_CONCURRENT`
    (default 3) — `startSerialized` increments/decrements the count and drains the queue
    whenever a slot frees up, instead of always going back to exactly one. Explicitly NOT proven
    safe at 3 the way 1 was reasoned out from the crash log — this is a deliberate experiment
    RedFalcon asked to try; if crashes resume, the fix is lowering `Config.POSTPROCESS_MAX_CONCURRENT`
    back toward 1, not suspecting a different cause first.
    **Both open threads closed out, same day, after live testing**: (1) the "talking" report was
    a false alarm, not a bug — RedFalcon confirmed it happens BEFORE this mod's own post-processing
    ever runs, i.e. it's the base game's own one-time spawn greeting/bark playing in the instant
    a pawn is created, before `Spawner.StripVoice` (which fires a few seconds later, after the
    composite settle delay) gets a chance to destroy the AudioComponent — by then there's nothing
    left to say. `StripVoice` is doing exactly what it was built for (silencing ongoing/idle
    chatter); a one-shot bark that fires at the literal moment of creation is a different, much
    smaller thing this was never trying to catch, and not worth chasing for one initial sound.
    Good outcome from asking for the log data instead of guessing a fix (item 30's lesson, applied
    correctly this time) — a code-level fix would have been chasing the wrong mechanism entirely.
    (2) The concurrency-3 restore fix (this item's own follow-up above) tested fine in-game —
    RedFalcon reports loading is OK now, no repeat of the original crash.

## Known limitations (confirmed via log, not assumptions)
- Arrows and the numpad operator keys (`/ * - +`) are outside this build's `Key[]` table
  entirely — bound via raw Windows virtual-key codes (`VK_FALLBACK` in `main.lua`).
  **The engine drops most repeat keydown events for these specific keys** before UE4SS
  ever sees them — confirmed by mashing one and observing successive caught presses land
  3-90+ seconds apart. This is not fixable from Lua; design around it (bigger steps,
  toggles instead of held modifiers) rather than trying to catch more presses.
- UE4SS's `RegisterKeyBind(key, {modifiers}, callback)` overload does not fire in this
  game. Don't reach for modifier-key binds; use a dedicated toggle key instead.
- Archetype/skin/ethnicity randomization cannot be pinned pre-build — it re-randomizes on
  `BeginPlay` regardless (proven with 7 Warrior spawns rolling 5 different ethnicities
  despite a pinned preset). Any "make appearance deterministic" request runs into this.
- **Outfit/hair COLOR cannot be changed on this mod's NPCs, at all** — confirmed dead three
  separate ways (see item 35): per-controller tint and whole-look `ColorParams` palette both
  set + read back correctly post-build but never visibly render (the game only consumes
  color ONCE, during a pawn's initial construction); setting `ColorParams` pre-build instead
  reproduces a **confirmed fatal native crash**, on two different actor classes. Don't
  revisit any of these three approaches without a genuinely new theory. Skin TONE (a
  material swap between ethnicity families) and hair STYLE (a mesh swap) are NOT affected by
  this and both work fine — they're a different mechanism, not a color change.

## persist.txt format
One line per saved spawn:
```
classPath|X|Y|Z|aiControllerPath|yaw|makeFriendly|look.params|look.archetype|look.sex|look.bodyTypes|look.reskinTarget
```
Field 12 (`look.reskinTarget`, added 2026-08-11) is a generic "which look/row was this"
string, reused by two independent features rather than adding a second field per feature:
for a female-walker spawn it's the `FEMALE_RESKIN_TARGETS` entry name (e.g. `"Letty"`,
`"Female_Standing_01"`), read by `Testbed.ApplyFemaleReskinTarget`; for a
`Config.SENKAMATI_LOOKS` spawn (same day, see item 37) it's a `name::kind::helmet` composite
key built by `senkaRowKey`/parsed by `parseSenkaRowKey`, identifying which of the 14
comparison rows. A THIRD consumer joined 2026-08-14 (item 45, v1.3.10): a `Config.
SENKAMATI_STATUES` spawn writes `senkaStatueRowKey`'s own `"STATUE::name::kind::pose::
helmet::skipDecorrupt"` string — deliberately a DIFFERENT format (leading `"STATUE::"` literal)
rather than reusing `senkaRowKey` directly, since a statue and a Num7 spawn can share the exact
same classPath/params and `RESTORE_RULES` needs to tell them apart from the reskinTarget string
alone. Whichever feature wrote it, a reload reads it back to restore the same
look/category instead of guessing. Empty for every other spawn type. **Backward compatible by construction, not by conversion**: the field was
appended at the END, so a pre-1.3.5 line simply doesn't have it — `gmatch` produces one fewer
part, every reader treats a missing/empty field 12 as "unknown" (`Testbed.
ApplyRandomFemaleLook`, a random pick among all 5 targets) rather than erroring, and nothing
rewrites old lines on load. There was never a way to recover which target an already-saved
actor was (that information didn't exist before this field did), so "convert" isn't
meaningful here — only new spawns from 1.3.5 onward get a real value in this field. THREE
separate places parse this line (`parsePersistLine`, `restoreOne`, `PersistUpdatePose`, all
in spawner.lua) — a known duplication, not refactored into one shared parser; if you add
another field, all three need the same update, individually.
Read non-destructively via `Spawner.PersistFindMatching(classPath, loc)` (nearest-match by
class+position) — used to validate exactly what a despawn/edit/cycle is touching before
acting, and to recover look/AI fields for undo. `PersistRemoveMatching` calls this
internally rather than duplicating the search.

41. **Per-world save support — shipped as v1.3.8** (2026-08-13). RedFalcon asked whether LivingBase
    recognized that Windrose supports multiple named-save "worlds." It didn't: `PERSIST_PATHS`/
    `LEDGER_PATHS` in `spawner.lua` were one fixed filename (`persist.txt`/`spawn_ledger.txt`)
    shared by every world — loading a different world restored the wrong crew into it, and saving
    there could overwrite whichever world's data the file actually belonged to.
    No world/save identifier was read anywhere in the mod, and this project has no live game
    access outside RedFalcon's own sessions, so rather than guess at an API, a TEMP DEV PROBE
    (`Spawner.ProbeWorldInfo`, since removed) was added: wired into `RegisterInitGameStatePostHook`
    as a standalone hook (deliberately separate from `scheduleRestore`'s hook so it could never
    affect that chain's locking/generation logic — see item 25), it dumped every
    save/world/slot/name/seed/session/id-matching property off GameInstance/World/GameState/
    PlayerState to `world_probe.txt`. First pass caught nothing useful — every capture was the
    Lobby/EntranceHall/TransitionMap/GenlandiaMulty menu-navigation loop, `islandId` (a
    `GameState` field, `ScriptStruct /Script/R5BLCommon.R5BLRecordId`) came back as just its
    struct TYPE name, and `PLAYERSTATE` never populated — meaning no real world had actually
    loaded yet in any of those captures. Root-caused to the same problem restore itself already
    solves (item 25's move-detection wait): `RegisterInitGameStatePostHook` fires too early, before
    save data has streamed into GameState (`ReplicatedWorldTimeSecondsDouble` still `0.0`).
    Moved the probe call into `fire()` in `main.lua` (same point `RestoreFromPersist` itself
    runs, after the pawn-exists-and-moved wait) and added struct-field drilling (resolve the
    struct's own `UScriptStruct` via `StaticFindObject`, `ForEachProperty` over THAT, read fields
    off the struct instance by bracket-indexing) plus a `GetFullName()` → `:ToString()` fallback
    for FString fields (first attempt printed `islandId.ID` as a raw pointer, `"FString:
    0000021E..."`, since `tostring()` on an FString userdata doesn't give you its text). Next
    capture, in a real loaded world: `islandId.ID` came back `96705FCEA09642E36789F92FD1E3606C`
    — byte-for-byte identical to the ID Windrose's own world-select screen shows in that save's
    tooltip. Confirmed durable engine finding, written up in full in
    `WINDROSE_MODDING_NOTES.md` §10.
    **Fix**: `PERSIST_PATHS()`/`LEDGER_PATHS()` became functions (recomputed on every call, not
    cached — the same running process can load a different world later without restarting),
    building `persist_<islandId>.txt`/`spawn_ledger_<islandId>.txt` via a new `getIslandId()`
    helper; falls back to the old flat filenames when no id is available yet (menu/too-early),
    so nothing silently fails to save. `migrateIfNeeded()` clones the old shared file into
    whichever world's own file doesn't exist yet, once per (world, file) per session. First
    version left the old shared file in place afterward ("a different world migrating later
    still needs to read it too" — wrong premise); live-tested with RedFalcon across two real save
    slots (Landland, Worldtwo) and the SECOND world's first load cloned the FIRST world's crew
    into itself too, since the old file was still sitting there looking "available." Root cause:
    the old file only ever really belonged to ONE world (whichever was last played
    pre-update) — once claimed, it must stop being claimable. Fixed by renaming it to `.bak`
    (via `os.rename`, `pcall`-wrapped — Windows semantics, fails rather than overwrites if a
    `.bak` already exists) immediately after the first successful clone. Re-verified live with a
    full reset (deleted both worlds' per-world files, restored `.bak` back to `.txt`) and fresh
    load of both worlds — Landland correctly inherited the real save, Worldtwo came up
    genuinely empty, `.bak` files present exactly once. Shipped as v1.3.8; probe code fully
    removed post-verification (`spawner.lua`'s `WORLD_PROBE_PATHS`/`worldProbeAppend`/
    `ProbeWorldInfo`, and its two call sites in `main.lua`).

42. **Target lock + a 2x precision step** (2026-08-13, same day, after v1.3.8). Two small requests
    landed together. **Target lock**: Num+ (free — see item 12's history for its two prior brief
    uses, both retired) now toggles `Spawner.lockedTarget`, a deliberate pin on ONE tracked actor.
    Implemented at the single choke point rather than in each caller: `findNearestSpawnInFront`
    (the shared picker despawn/cycle/every live-edit key already goes through, per the project's own
    working agreement below) now checks the lock FIRST and, if set and the locked actor is still
    `IsValid()` and still in `Spawner.spawned`, returns it directly — bypassing the cone/range search
    entirely, so a locked object keeps getting hit even after walking away or turning to look
    elsewhere. `Spawner.ToggleTargetLock()` (bound in `main.lua`, inside the `Config.LIVE_EDIT`
    block alongside the precision toggle) does the actual pick when turning ON — the SAME cone/range
    check every other action already uses, so locking targets exactly what despawn/edit/cycle would
    already have hit — and just clears the pin when turning OFF; both directions toast-confirm with
    the target's label. Auto-releases (with its own toast) the moment the locked actor stops
    existing — despawning your own locked target, or a DEL wipe, doesn't leave a dangling lock
    silently eating future keypresses; the next press just falls through to a fresh unlocked pick.
    `CycleNearestInFront` needed one addition: it destroys-and-recreates in place (same pattern
    flagged in item 10 above), so without help the lock would point at a just-destroyed actor the
    instant you cycled — it now re-points `Spawner.lockedTarget` at the NEW actor when the old one
    was the locked target, so you can lock once, cycle through several looks, and keep nudging with
    live-edit the whole time without re-locking after every press. Explicitly NOT the same thing as
    the automatic per-press "target-lock caching" tried and abandoned very early in this project (see
    item 2 above, and `EditNearestInFront`'s own comment) — that was a transparent cache that never
    helped a DIFFERENT problem (engine-dropped keydown events); this is a visible, user-toggled pin
    with its own toast feedback, solving a different problem (staying on target while moving around
    it). **2x precision step**: `Spawner.editPrecisionScale`'s cycle (Num-) gained a fifth stop —
    full -> 1/2 -> 1/4 -> 1/8 -> 2x -> full — for fast coarse repositioning right after the fine end
    of the cycle, rather than inserting it next to full (which would've made the cycle bounce
    fine/coarse/fine instead of reading as one fine-to-coarse sweep before wrapping). Scales
    translation only (dZ/dFwd/dRight), same as every other precision level — rotation is untouched,
    unchanged from before this item.
    **Same-day follow-up, found via real use**: RedFalcon ran `lbreload` to pick up this item's code, then
    locked onto an actor and saw a target-lock toast reading "Target lock ON: RETRACKED" — meaningless.
    Root cause: `lbreload` wipes `Spawner.spawned` (fresh Lua state), so the very next
    `findNearestSpawnInFront` call (the lock's own pick) triggered `Spawner.RetrackOrphans()` (existing
    machinery, unrelated to this item, that re-populates tracking from the ledger after a hot-reload) —
    which had ALWAYS hardcoded `label = "RETRACKED"` for anything it recovers. Every other toast
    (despawn/cycle/undo) reads that same `label` field too, so they'd have shown the same meaningless
    text in this situation; target lock's toast just happened to be the first to surface it plainly
    enough for RedFalcon to notice and report. Fixed: `RetrackOrphans` now derives a real short name from
    the recovered actor's own class path (the same `([%w_]+)%.[%w_]+$` idiom already used at several
    other call sites in this file, e.g. `EditNearestInFront`'s `short`), same as every other label in
    the mod. Second, related ask: releasing the lock should be IMMEDIATE and visible the moment the
    locked object is actually despawned, not just the lazy fallback inside `findNearestSpawnInFront`
    (which only ever fires on the NEXT targeted keypress). Added
    `Spawner.ReleaseTargetLockIfDestroyed(actor)` — a no-op-unless-it-matches helper, so call sites
    don't need to check first — and wired it into every real destroy path that could take out a locked
    actor: `DespawnNearestInFront` (Num9), `DespawnActor` (the by-reference despawn automated retries
    use), `DespawnAll` (DEL clean-house, one call per actor inside its existing loop), and
    `UndoDespawn`'s `replaceActor` destroy (undoing a cycle you did while locked — the lock had already
    followed the cycle onto that actor per this item's own `CycleNearestInFront` change, so undoing it
    destroys the very thing that's locked). Deliberately did NOT add a call inside
    `CycleNearestInFront` itself — a plain cycle doesn't destroy the locked SPOT, it re-points the lock
    at the replacement (already handled, see above); adding a release call there would fight that
    intentional continuity, not complement it.
    **Third follow-up, same day**: RedFalcon asked for a DISTANCE-based release too ("if I walk away it
    should let go"), and separately didn't know how `uu` maps to real distance — answered using this
    project's own existing convention (see `LEASH_RADIUS_UU`'s comment further down config.lua): 100uu
    ~= 1m. Confirmed after tuning: the actual scenario isn't "am I standing close enough to reach it" —
    it's forgetting to press Num+ again before wandering off into actual gameplay (combat, exploring,
    questing) with despawn/cycle/live-edit still silently pinned to whatever was locked back at base.
    1500uu is sized to survive normal in-place work (walking around a statue, stepping back to check a
    structure) while still catching that "left for adventure and forgot" case within one tick. New `Config.TARGET_LOCK_MAX_DIST` (default 1500.0, ~15m) is checked inside the SAME lock
    block in `findNearestSpawnInFront` that already handles "target destroyed" — restructured that
    block to compute a `releaseReason` string (either "target no longer exists" or "walked Nm away
    (lock range Nm)") and release with ONE shared toast/log call at the end, rather than duplicating
    the release logic per-case. Deliberately much larger than `LIVE_EDIT_MAX_DIST` (200uu, the INITIAL
    unlocked pick radius) — once you're already locked on, the question is "are you still working on
    this" not "are you standing close enough to be sure this is what you meant to aim at", a much more
    forgiving bar. Distance is measured from the PLAYER'S body position (not the camera), matching
    every other reach check in this function (`DESPAWN_FRONT_UU`/`LIVE_EDIT_MAX_DIST` both already do
    the same) for the same "how far can you actually reach" reasoning.
    **Fourth follow-up, same day**: RedFalcon tested it live and reported "the distance doesn't seem to
    work" — `ue4ss.log` showed exactly why: locked on, then NOTHING fired for the next minute except
    RedFalcon manually pressing Num+ again to turn it off himself. Root cause: the distance check above only
    runs LAZILY, inside `findNearestSpawnInFront`, which only gets called by another mod key (despawn/
    cycle/live-edit) — walking away and pressing nothing else never triggers it at all, so the lock just
    sits there indefinitely. RedFalcon explicitly asked for the fix to be resource-conscious: only run a
    periodic check while a lock actually exists, and stop the moment it doesn't — not an always-on
    background poll like `Spawner.LeashTick`'s own loop (a DIFFERENT feature, registered once,
    unconditionally, forever). Extracted `Spawner.TargetLockDistanceCheck(px, py, pz)` — the shared
    "is this lock still good" rule, used by BOTH the lazy in-picker check (passes its own already-
    computed px/py/pz through, no extra pawn lookup) and a new self-rescheduling tick
    (`Spawner.StartTargetLockTick`, `Config.TARGET_LOCK_CHECK_MS` = 2000). The tick is started ONCE, by
    `ToggleTargetLock`'s ON branch, and each firing only reschedules ANOTHER firing if
    `Spawner.lockedTarget` is STILL set afterward — so it stops itself the instant the lock is gone, via
    ANY release path (manual toggle-off, distance, despawn), with no explicit cancel needed anywhere.
    Same self-rescheduling-only-while-there's-live-work shape as `Spawner._activeToasts`' own ticker
    (item 24 above), deliberately NOT `LeashTick`'s always-on shape — chosen specifically because this
    feature is off far more than it's on, and RedFalcon asked for exactly that trade-off.

43. **A second walking-woman base (the Herbalist) — an object-dump discovery, a name-collision bug, then
    a real feature** (2026-08-14). Started from an unrelated question: RedFalcon's own fresh object dump
    showed two buildable "merchant table" pieces (Food/Resources, plus a third — Animals — not
    previously known) each with a visible vendor standing at it, and asked whether that vendor was a
    real NPC or baked into the table. Traced via the dump: both are `BP_BuildingBlock_Employee_Trader_*`
    (native parent `R5BuildingBlock_Employee` -> `R5CraftStation`), and their own Class Default Objects
    each own an `R5CompositeMeshComponent` directly — no `AIController`/`PawnClass`/separate-actor
    reference anywhere. Confirmed live: `lbspawn`-ing one renders identically to the placed object, no
    extra params needed — the vendor is genuinely baked in, not employee-assigned at runtime as
    originally guessed. Purely informational; RedFalcon declined adding a placement key since these are
    already buildable normally in-game.
    **Then**: RedFalcon separately spotted the Herbalist walking in-world and asked for an lblook to spawn
    "Woman With Hair" on her body instead of the usual Gatherer. Found via the SAME fresh dump:
    `BP_NPC_Handyman_Herbalist_C`, living in the identical `.../Handyman/` folder as Gatherer and
    sharing the EXACT SAME immediate parent class (`BP_NPC_Handyman_C`, confirmed by comparing both
    classes' `[sps: ...]` super-struct address) — an architectural sibling, not a guess. Added
    `Config.SENKA_FEMALE_BASE_CLASS_HERBALIST`, generalized `spawnFemaleWalkerTarget` to accept a base-
    class override, and shipped a first cut as an lblook-only `Testbed.SpawnHerbalistWomanByName`
    (`lblook Herbalist`) — mirroring the existing Barbie precedent (no numpad key, not in the rotation).
    **First bug, found via real use within minutes**: RedFalcon tried `lblook Herbalist` and got the PLAIN
    vanilla townsman, not the reskin. Root cause: `Config.TOWNSFOLK_CLASSES` already had its OWN
    `"Herbalist"` entry (the real Num2 townsman roster, same underlying class), and
    `Testbed.SpawnWalkerByName` is tried earlier in `main.lua`'s `lblook` dispatch order (first match
    wins) than the new function — the townsman entry silently shadowed it completely; it was dead code
    under that name from the moment it shipped. Fixed by renaming to the two-word `"Herbalist Woman"`
    (can't collide with a single-word roster name, same as multi-word names like "Buccaneers Musketeer"
    already work).
    **Then RedFalcon asked for the real feature**: apply the same base-body variety to the actual walking-
    women rotation AND the Senkamati Caster-F crew re-skin, naming the scheme himself ("Woman with Hair
    Base 1, Woman with Hair Base 2, and so on"). Two design forks were genuinely ambiguous enough to ask
    rather than guess (see the "Working agreements" note below on that): (a) replace the single "Woman
    With Hair" ROTATION stop with two explicit stops, vs. keep it lblook-only extras — RedFalcon chose
    replace; (b) for Caster-F, add a Herbalist row for just the no-mask variant, vs. both masked/
    unmasked — RedFalcon chose both, to keep the comparison roster symmetric.
    **Implementation, once scoped**: `"Woman With Hair"` split into `"Woman With Hair Base 1"`
    (Gatherer)/`"Base 2"` (Herbalist) in `FEMALE_RESKIN_TARGETS` itself (both fall through to the exact
    same generic reskin recipe in `ApplyFemaleReskinTarget` — no dispatch changes needed there, only
    which BODY gets spawned). Refactored `spawnFemaleWalkerTarget` back down to a single `targetName`
    parameter, replacing the short-lived explicit override argument with a small internal
    `FEMALE_WALKER_BASE_OVERRIDES` lookup table (`targetName -> baseClass`) — every caller just passes a
    name, nothing to keep in sync caller-side. The now-redundant `Testbed.SpawnHerbalistWomanByName`
    (superseded — "Woman With Hair Base 2" reaches the identical result through the normal
    `SpawnFemaleWalkerByName` path) was deleted outright rather than left as dead/duplicate code, along
    with its `main.lua` registration.
    `RESTORE_RULES`' "female walker re-skin" `when` check — previously `cls ==
    Config.SENKA_FEMALE_BASE_CLASS` only — was broadened to recognize either base class, so a restored
    Herbalist-based walker gets her reskin correctly reapplied on reload instead of silently reverting
    to a plain default look (the ONLY thing deciding whether ANY female-walker post-process runs at all
    was that one class check).
    **Second bug avoided by anticipation, not live-testing**: adding two new `Config.SENKAMATI_LOOKS`
    rows (`name = "Caster-F", kind = "crew", helmet = true/false, baseClass =
    SENKA_FEMALE_BASE_CLASS_HERBALIST`) would have reproduced the EXACT SAME collision class as the
    "Herbalist" bug above — `senkaShortKey`/`rowLabel`/`Testbed.SpawnSenkaByKey`'s lblook lookup are all
    built from `name .. "_" .. kind .. helmet`, with no reference to `baseClass` at all, so the new rows
    would have been indistinguishable from (and unreachable behind) the existing Gatherer-base pair.
    Fixed BEFORE shipping, not after a report this time: added an optional `baseLabel` field
    (`"Herbalist"` on the two new rows only), threaded through `senkaShortKey`/`rowLabel` so they append
    it when present — zero effect on any existing row, which has no `baseLabel`. Deliberately did NOT
    touch `s.name` itself (must stay exactly `"Caster-F"` — `senkaCrewFix` branches on that literal
    string to pick `Config.DECORRUPT_CREW_FEMALE`; renaming it would silently fall through to the male
    Warrior ruleset instead) and deliberately did NOT thread `baseLabel` into `senkaRowKey` (the
    persist.txt identity, "::"-joined) — confirmed unnecessary AND risky: unnecessary because restore
    re-applies IDENTICAL rules regardless of which of the two ambiguous rows matches (same params/
    helmet, only baseClass differs, and the actually-spawned class always comes from persist.txt's own
    saved classPath, never re-derived from the row match); risky because changing that function's
    delimited format has broken parsing twice before (see its own comment history) for entries that
    genuinely needed the extra data — not worth the risk here for data that provably doesn't matter at
    restore time. `senkaShortKey` was also exposed as `Testbed.SenkaShortKey` and `main.lua`'s
    `LBLOOK_CATEGORIES` senka listing (previously an independent hand-duplicated copy of the same format
    string — the exact kind of drift that let the original "Herbalist" collision go unnoticed) now calls
    it directly instead.
    **Also confirmed, live (2026-08-14)**: the Herbalist base genuinely has a different figure, hair
    color, and garment palette (red/blue) from the Gatherer — expected and welcomed, not a bug. Ties
    back to the color-investigation conclusion elsewhere in this file: per-pawn color/palette can't be
    set post-construction in this game at all, so each base CLASS's own baked-in default archetype is
    the only real lever this mod has for palette variety — "add more base classes" isn't a workaround,
    it's the only mechanism that was ever going to work here.

44. **Base 1/Base 2 extended to EVERY walking woman, not just "Woman With Hair"** (2026-08-14, same
    day, immediately after item 43 shipped). RedFalcon clarified item 43's scope: "I meant I want ALL the
    walking women to have base 1 and base 2" — Letty/Marita/Merchant/"Woman With Hat" too, not just the
    generic hair slot. `FEMALE_RESKIN_TARGETS` grew from 6 entries to 10 — every one of the 5
    character/look concepts x Base 1/Base 2 (`"Letty Base 1"`, `"Letty Base 2"`, etc.).
    **The real work was in `Testbed.ApplyFemaleReskinTarget`'s dispatch**, which matched
    `Config.FEMALE_WALKER_OVERLAYS`' named entries and the literal `"Woman With Hat"` string by EXACT
    equality against `targetName` — "Letty Base 1"/"Letty Base 2" would both have missed that exact
    match and silently fallen through to the generic hair-only recipe, losing Letty's actual outfit/
    ponytail rules entirely. Fixed with a new `femaleCharacterKey(targetName)` helper (strips a
    trailing `" Base N"` suffix via one `gsub`) used ONLY for dispatch — the full `targetName` (with
    suffix) is still what's used for the Spawn label, the persisted `reskinTarget`, and every print/
    toast, so logs/persist.txt still distinguish "Letty Base 1" from "Letty Base 2" even though they
    resolve to the identical overlay recipe.
    **A second, less obvious fix, found by tracing the busy-guard's OWN stated purpose rather than by
    a live report this time**: the per-target busy-guard/queue (`reskinTargetBusy`/`reskinTargetQueue`,
    item from 2026-08-10/11) exists because `Spawner.DeCorrupt` caches state ON THE SHARED RULE TABLE
    ITSELF, not per-actor — processing two actors against the SAME rule table concurrently can corrupt
    each other's "already replaced" state. It was keyed by the full target name. Since "Letty Base 1"
    and "Letty Base 2" now read the exact same shared `Config.FEMALE_WALKER_OVERLAYS` "Letty" table
    (via `namedOverlay`, a direct reference, never copied), spawning one of each concurrently would
    have hit precisely the collision this guard was built to prevent — keeping the key as the full
    name would have silently let it through. Re-keyed the guard/queue by `characterKey` instead. This
    required ALSO storing each queued item's own `targetName` (previously implicit, since the queue
    bucket itself WAS the target name — now one bucket can hold a mix of "X Base 1"/"X Base 2" items,
    so `releaseAndDrainTarget` needed each item's own name to redispatch the right one instead of
    reusing whichever name happened to be the bucket's key).
    `FEMALE_WALKER_BASE_OVERRIDES` (item 43's per-name lookup table, one entry) was replaced with
    `femaleBaseClassFor(targetName)` — a plain suffix rule (`"Base 2"` at the end -> Herbalist,
    everything else -> Gatherer) — now that EVERY entry follows the identical pattern rather than one
    one-off needing its own table row; scales to a future "Base 3" with a one-line change instead of
    ten new table entries.
    **Deliberately NOT verified per-character yet**: whether Letty/Marita/Merchant's specific outfit
    rules (their `replaces`/`hides`/`forceHat` patterns, tuned and confirmed against the Gatherer's own
    component naming across several past sessions) apply cleanly to the Herbalist's mesh structure too.
    Expected to work — those rules are broad content-matches (`"Hat"`/`"Headband"`/`"Bandana"`/`"Hair_"`
    prefixes), not per-character hardcoded component names, and the generic "Woman With Hair" recipe
    already confirmed working on the Herbalist in item 43 uses the exact same style of matching — but
    genuinely unconfirmed for the NAMED characters specifically until tested live.
    Items 42-44 shipped together as **v1.3.9** — RedFalcon's call once item 43 wrapped, rather than
    continuing to fold same-day work into the already-released v1.3.8 (per-world saves + Caster body
    fit) indefinitely.

45. **Senkamati Statues — genuinely frozen-in-place figures, a new roster/key** (2026-08-14, same day,
    v1.3.10). RedFalcon asked for "Senkamati statues" — clarified (they confirmed explicitly) to mean
    posed/frozen NPCs in the same spirit as `Config.STANDING_STATUES`/`SEATED_STATUES`/`CHAIR_STATUES`/
    `INTERACTIVE_STATUES`, distinct from BOTH the Num7 comparison roster (pacified but still wanders —
    `senkaMobFix`'s own comment: passivity comes from the friendly faction + `MakePassive`, neither of
    which stops movement/AI) and the walking Letty/Marita/Merchant re-skins. The missing mechanism
    turned out to already exist in this file: `Spawner.SetAILogic(pawn, on)` (used elsewhere to stall a
    following crew member's own StateTree without freezing its mesh/animation) calls the AIController's
    `StopLogic()` — exactly "stop the brain, leave everything else alone." No new engine-touching code
    needed, just a new call site.
    **Scope, RedFalcon's own words, parsed carefully rather than guessed**: start with the CREW-based
    Caster-F re-skin (the human-skeleton Handyman re-skin, not the raw mob body), no mask. "Replicate
    the poses [of] standing Brethren woman, the Buccaneer merchant, and all three sitting women" —
    NOT a literal shared animation (STANDING_STATUES' own `BotC_Merchant_04` comment already
    establishes those are "plain AnimatedActor spawns, no compositeLook involved," so there's no known
    way to graft Senkamati armor onto that body at all) — read instead as staging variety: 2 standing
    rows + 3 seated rows, mirroring that roster's SHAPE (5 slots split standing/seated), all using the
    same underlying re-skin recipe. Plus "if there is an idle pose we can use for her ... masked, one
    original one decorrupted" — two more rows on the RAW mob skeleton (helmet=true always), one with
    de-corrupt skipped entirely (her genuine corrupted look, same recipe as `SENKAMATI_LOOKS`' own
    `kind="corrupted"` rows) and one with it applied (clean skin/hair, armor kept). 7 rows total.
    **The seated rows are explicitly experimental, not proven**: this mod's own `townsman` key
    ("wanders + uses furniture," `Config.KEYS` comment) already establishes the Handyman AI family CAN
    autonomously sit at nearby furniture — the seated statue rows lean on that same behavior by simply
    waiting `Config.SENKA_STATUE_SEAT_WAIT_MS` (6000ms, an unverified guess) after she settles before
    calling `SetAILogic(actor, false)`, on the theory that she'll have walked to and sat at a
    RedFalcon-placed stool/chair by then. Whether the Handyman-based CASTER RE-SKIN specifically exercises
    that behavior (as opposed to the plain, unmodified Handyman/townsman classes it's confirmed on) is
    unconfirmed — genuinely possible she's still standing when frozen. Documented as a known open
    question in config.lua's own comment rather than presented as working; the real test is RedFalcon
    placing a stool and reporting what they see.
    **Implementation, kept additive — no existing function's behavior changed**: `Config.
    SENKAMATI_STATUES` (config.lua, reuses the `CASTER_PARAMS`/`CASTER_MOB`/`SENKA_FEMALE_BASE_CLASS`
    locals already in scope from `SENKAMATI_LOOKS`' own section) + a new key, `Config.KEYS.senkaStatue`
    = `"OEM_EQUALS"` (`'='`). `spawnSenkaStatueEntry`/`Testbed.SpawnNextSenkamatiStatue` (testbed.lua)
    call `senkaCrewFix`/`senkaMobFix` COMPLETELY UNCHANGED (same de-corrupt/pacify routines the Num7
    roster already uses and depends on) and add exactly one new step after they finish: the new
    `freezeSenkaStatue`, which calls `Spawner.SetAILogic(actor, false)` (optionally after `waitMs` for
    the seated rows) via the SAME `Spawner.RunSerialized` wrapper every other composite-surgery call
    site in this file already uses, so a statue's freeze can never overlap another actor's composite
    build. Persisted/restored via a NEW, separate row-key encoding, `senkaStatueRowKey`/
    `parseSenkaStatueRowKey` — a `"STATUE::name::kind::pose::helmet::skipDecorrupt"` string riding the
    same `reskinTarget` persist.txt field the female walkers and `SENKAMATI_LOOKS` already share (see
    "persist.txt format" below), NOT a reuse of `senkaRowKey`'s existing `"::"` format: a statue and a
    Num7 spawn can point at the exact same underlying class/params (both use `CASTER_MOB`/
    `SENKA_FEMALE_BASE_CLASS`+`CASTER_PARAMS`), so `RESTORE_RULES` needs a way to tell them apart that
    doesn't depend on class path alone — the leading `"STATUE::"` literal is that marker, checked first
    in a NEW restore rule inserted at the TOP of `RESTORE_RULES` (ahead of the two existing plain
    Senkamati rules, which would otherwise silently reskin a reloaded statue correctly but never
    refreeze it, since neither of those rules knows freezing exists). `skipDecorrupt` is carried as its
    own field (not folded into `kind`, which stays `"crew"`/`"mob"`) specifically because BOTH masked
    idle rows share identical name/kind/pose/helmet and are otherwise indistinguishable on restore —
    same class of gap `SENKAMATI_LOOKS`' own `helmet` field exists to close for its rows, applied here
    to a different pair of otherwise-identical entries. Despawn/undo/`]`/`[`-cycle-target all work on a
    placed statue automatically, no new code needed — they operate on `Spawner.spawned`/`persist.txt`
    generically, same as every other spawn type in this mod.
    **Key choice**: RedFalcon's own explicit constraint — no Caps/Num/Scroll Lock, since those toggle a
    real OS-level state (their own keyboard LED) outside the game entirely, and leaving one flipped on
    from a mod keypress would keep affecting whatever else they run alongside Windrose (e.g. Excel's
    Scroll-Lock-driven arrow-scroll mode), not just this mod — a sharp, non-obvious catch worth
    recording as a standing rule for any future key choice, not just this one. Picked `'='`
    (`OEM_EQUALS`) instead: untested specifically, but same proven `OEM_*` family as `;`/`'`/`,`/`.`/
    `\`/`[`/`]`, all of which already register and fire correctly in this build — trivially remappable
    in `Config.KEYS.senkaStatue` if it turns out to collide with something.
    **Not yet tested live** — this entire feature (spawn, freeze, restore, and especially whether the
    seated rows actually produce a seated pose) is deployed but unconfirmed in-game as of this write-up.

46. **Investigating whether the ORIGINAL statue bodies can be re-skinned directly, and HOME learns
    to respect the target lock** (2026-08-14, same day, follow-up to item 45). RedFalcon pushed back on
    item 45's premise: "couldn't we just reskin the original statues" (the real `Female_Standing_01`/
    Merchant/`Female_Sitting_0X` `AnimatedActor` bodies), rather than the Handyman-based re-skin —
    exactly what "replicate the poses" was asking for the whole time, read literally. The reason that
    was set aside in item 45 doesn't actually settle it: `STANDING_STATUES`' own `BotC_Merchant_04`
    comment says THIS MOD currently spawns her with "no compositeLook involved" — true of how she's
    placed today, but not proof the class itself lacks a `CompositeMeshComponent` to drive. Nobody had
    ever actually checked. If she has one, re-skinning the REAL statue body directly would be strictly
    better than item 45's approach — no Handyman AI, no `SetAILogic` freeze, no seated-pose guessing,
    since these classes are already permanently posed with no AI to fight in the first place.
    Rather than write new probe code, pointed at tooling this mod already ships: `Spawner.
    ProbeDumpProperties` (PAUSE, after aiming with HOME) already includes `dumpCustomizability`/
    `dumpColorControllers`, both of which read `actor.CompositeMeshComponent` directly and print
    whether it resolves at all — exactly the open question, answerable with zero new code. RedFalcon then
    asked whether `lbdumpobj` (a console command wrapping UE4SS's own `DumpAllObjects()`, added
    2026-08-13) would be a better fit "since it has everything" — worth naming as a real fork: `
    lbdumpobj`/`lbdumpact` dump the ENTIRE loaded world's objects/actors to a file, genuinely
    exhaustive but exactly the kind of unfiltered dump item 20 already got burned by once (3329
    widgets, unreadable, before narrowing to a keyword filter) — for "does ONE specific actor have
    ONE specific component," the already-scoped HOME/PAUSE probe answers it in one log line instead
    of a manual search through a whole-world dump. Recommended HOME/PAUSE first; `lbdumpobj`/
    `lbdumpact` as the fallback only if that comes back incomplete and a broader "what does this class
    even have" sweep is needed. Live test not yet run — waiting on RedFalcon's report from
    `ue4ss.log`'s `[probe-customizable]`/`[probe-color]` lines.
    **Separately, a real quality-of-life fix landed while investigating**: RedFalcon asked to wire HOME
    itself into the target lock (Numpad +) — "to make life easier" while doing exactly this kind of
    repeated probing (walk around a statue, re-aim HOME each time). `Spawner.ProbeNearestActor`
    (spawner.lua) previously always ran its own independent full-world `FindAllOf("Actor")` cone/range
    sweep, entirely unaware of `Spawner.lockedTarget`. Now checks the lock FIRST — if set and valid,
    probes that actor directly (own distance computed for the log line, no cone/range check at all,
    same as how the lock already bypasses `findNearestSpawnInFront`'s own pick) and skips the sweep
    entirely; falls through to the normal sweep unchanged if nothing's locked. PAUSE needed no change
    — it already reads `Spawner._lastProbedActor`, which HOME sets unconditionally regardless of which
    path found `best`. Only ever helps for something the lock could target in the first place (an
    actor tracked in `Spawner.spawned` — e.g. a statue placed via this mod's own Num3/Num5, exactly
    the Brethren Woman/Sitting Women case at hand) — a wild, never-spawned-by-us NPC or undiscovered
    world decoration was never lockable, so probing one still falls through to the unchanged full
    sweep exactly as before.

47. **A real live-caught bug in item 46's own lock shortcut, a decisive probe result, and the
    Senkamati Statue roster rebuilt around it** (2026-08-14, same day). RedFalcon tested HOME while
    locked onto a statue (via Numpad +) and reported it printed `[probe] key received.` and
    nothing else — twice, with two different locked actors (Letty, then the real Standing
    Brethren Woman), ruling out an actor-specific cause. Root cause, found by re-reading item 46's
    own new code against `Spawner.lockedTarget`'s ACTUAL shape: `Spawner.lockedTarget` is a WRAPPER
    TABLE (`{ actor, label, class }`, set in `Spawner.ToggleTargetLock`/`CycleNearestInFront`), not
    the raw actor — item 46's `Spawner.lockedTarget:IsValid()` called a method that doesn't exist
    on a plain Lua table, throwing "attempt to call a nil value" immediately after the `key
    received` print, with nothing further to catch it usefully. **Lesson: when reusing a shared
    module-level variable in a NEW call site, check its actual runtime shape at an existing call
    site first (here, `findNearestSpawnInFront`'s own `lt.actor` usage a few hundred lines away
    would have shown this immediately) rather than assuming from the name alone.** Fixed:
    `Spawner.lockedTarget.actor:IsValid()` / `best = Spawner.lockedTarget.actor`. Confirmed live
    immediately after — HOME then correctly printed `using locked target...` then `TARGET @
    ...uu: ...` for both Letty and the Standing Brethren Woman.
    **Then the actual investigation, using the now-working lock-assisted HOME+PAUSE**: RedFalcon probed
    six real posed/QuestStatic actors — `Female_Sitting_01/02/03`, `Buccaneers_Merchant_01`,
    Marita, Letty. Every one came back `IsCharacterCustomizable=true` with a full, live
    `CompositeMeshComponent` (19-25 color controllers each: `Hairs`/`Torso`/`Legs`/`Feets`/
    `Hands`/`Headgear`/`Waist`/`Mask`/`Cape`) and, decisively for Letty, `comp.DefaultParams`/
    `comp.ArchetypePreset` already populated with her own dedicated composite-params/archetype
    assets — the EXACT SAME two properties `Spawner.ApplyComposite`/`Spawner.Spawn`'s
    `compositeLook` argument already sets pre-build on every other composite-driven pawn in this
    mod. This directly overturned item 45's founding assumption (borrowed from `STANDING_STATUES`'
    own `BotC_Merchant_04` comment, "no compositeLook involved") — that comment only ever described
    how THIS MOD spawns these actors today (no `look` argument passed), never a class-level
    limitation; nobody had actually checked until now. Bonus confirmation: the mesh piece names on
    these real statues (`SK_Armor_Flibustier_03_Female_BandanaHat`, `SK_Belt_03_Female`,
    `SK_Frog_03_Female`, `SK_Hair_Wig_02_SuspendedBandana_Female`, etc.) are the SAME asset family
    `Spawner.DeCorrupt`'s existing content-matched rules (`Config.DECORRUPT_CREW_FEMALE`) already
    know how to hide/replace — built for the Handyman base originally, but matched by MESH NAME
    content rather than component name or base class, so directly reusable.
    **Rebuilt `Config.SENKAMATI_STATUES`/`spawnSenkaStatueEntry` around this finding, replacing
    item 45's Handyman-based "crew" kind entirely.** The 5 standing/seated rows now spawn the REAL
    statue bodies directly (`BP_AnimatedActor_BotC_Female_Standing_01`/
    `BP_AnimatedActor_Buccaneers_Merchant_01`/`BP_AnimatedActor_BotC_Female_Sitting_01/02/03` — the
    exact classes `STANDING_STATUES`/`CHAIR_STATUES` already place) with `compositeLook.params =
    CASTER_PARAMS` overriding just `DefaultParams` (archetype left untouched, same recipe already
    proven safe for the Caster-F crew rows in `SENKAMATI_LOOKS` — forcing archetype would rebuild
    the wrong body), then `senkaCrewFix` UNCHANGED for the mask/skin/hair de-corrupt pass. New
    `kind = "posed"` (replacing the old `"crew"` value in this roster only — `SENKAMATI_LOOKS`'
    own `"crew"` kind is untouched). This **eliminates the entire "is she actually sitting"
    problem item 45 shipped as experimental** — `Female_Sitting_0X` are already permanently posed
    sitting, by construction, nothing to wait for or guess about — and **drops
    `Spawner.SetAILogic`/`freezeSenkaStatue` entirely for these 5 rows**: an `AnimatedActor` statue
    class has never shown any AI movement in this mod's whole history of placing it via Num3/Num5,
    so there's nothing to freeze. `Config.SENKA_STATUE_SEAT_WAIT_MS` and the `waitMs` field/
    parameter thread were removed outright as now-dead code, not left disabled.
    The 2 masked "idle" rows (raw `CASTER_MOB` skeleton) are UNCHANGED — that class genuinely has
    a live wandering AIController (same one Num7's own "mob"/"corrupted" rows keep running), so
    `freezeSenkaStatue` (simplified: dropped its now-unused `waitMs` parameter, always immediate)
    still applies there. `senkaStatueRowKey`'s persist.txt encoding (`STATUE::name::kind::pose::
    helmet::skipDecorrupt`) is unchanged in SHAPE — only the `kind` value changed from `"crew"` to
    `"posed"` for these rows — and the restore rule (testbed.lua) was updated to dispatch on
    `"posed"` the same way. **Not yet tested live** — deployed to the live install, `lbreload`'d,
    but RedFalcon hadn't placed one of the rebuilt standing/seated looks as of this write-up; the mob
    "idle" rows are unaffected by this rebuild and should behave exactly as before.

48. **First live test of the rebuilt statue roster: three real findings, one dead end ruled out
    with certainty, one experiment shipped** (2026-08-14, same day). RedFalcon placed and HOME+PAUSE
    probed all 5 posed rows plus both mob "idle" rows, post-settle. Findings:
    (a) **A genuine pelvis gap** on all 5 posed rows, same class of issue as the original crew
    Caster's own (the `Witch_Feather_%d+_Legs` fringe piece's gaps are meant to show the WEARER'S
    OWN SKIN, which human bodies don't have there) — "just like there used to be for the crew
    before the nude mod fix."
    (b) **4 of 5 show bare chest** (Merchant excluded) — but the live probe data ruled out a
    missing-component theory decisively: Standing has a COMPLETE armor set (Torso/Neck/
    TorsoCloth/Hands/Legs/Feet, all valid meshes) yet is uncovered anyway, while Merchant (fully
    covered) is missing her Hands piece entirely — the opposite of what a "missing piece" theory
    would predict. Actual pattern found: the Torso/Legs pieces roll between at least two named
    variants (`_01_`/`_02_`) per spawn — Standing/Merchant both got `_01_Torso`, all 3 Sitting
    women got `_02_Torso` — consistent with this composite's already-documented tendency to
    re-randomize certain things at BeginPlay regardless of what's requested (same class of thing
    documented for archetype/skin elsewhere in this file). Not yet confirmed which variant is
    skimpier or whether it's truly random (RedFalcon hasn't re-placed the same slot repeatedly to
    check) — logged as the open question, not resolved.
    (c) **Armor appears to sink into the body** — RedFalcon's read: "all the sitting are the same,
    standing looks a little less sunken in... proportions of this body are different." Plausible:
    Standing/Sitting/Merchant use 4 DIFFERENT body archetypes (Albion/Orient/African/Native
    respectively — confirmed via probe, not guessed), and the Senkamati armor was fitted against
    one specific body, not all seven of this game's ethnicity families. Not fixed this round — a
    real fix needs live visual tuning (`Spawner.NudgeComponentTransform`, scale/offset), likely
    per-archetype since a single value probably won't suit all four; deferred pending RedFalcon's call
    on whether it's worth the iteration cost.
    (d) **The "decorrupted idle" walk-before-freeze bug (item 47's #3) is fixed** — see the
    `freezeSenkaStatue`/`spawnSenkaStatueEntry` reorder above (freeze now runs first, with a short
    retry, before senkaMobFix starts) — deployed, not yet re-confirmed live as of this write-up.
    **Investigated whether more nude-mod paks could fix (a) — ruled out with certainty, not just
    inferred.** Read the actual source folder for the bundled nude mod (`Other\Nightly Build Full
    Nude Mod V1.0.25-...`): it ships exactly TWO paks (`Female_NUDE_P`, `NO_Underwear_P`, only the
    former bundled into LivingBase) and its own `exports/` folder confirms the body-mesh fix
    covers exactly ONE archetype, Adventurer (`SK_Adventure_Female_01` — the same body the crew/
    walker base already uses, which is WHY it fixed the crew Caster). No Albion/Orient/African/
    Native equivalents exist anywhere in that package. Combined with the already-documented T-pose
    dead end for swapping a statue's base body mesh via code (`Config.FEMALE_WALKER_OVERLAYS`'
    Marita entry, proven 2026-08-10), **there is currently no available fix for (a) on 4 of the 5
    posed rows** (Merchant, also Adventurer-adjacent via a different path, may be the exception —
    unconfirmed) — a genuine, documented known limitation, not a to-do.
    **Shipped one cheap, reversible experiment for (a) anyway**: `Config.
    SENKA_STATUE_PELVIS_BACKING`, a NEW rules table (deliberately NOT folded into the shared
    `Config.DECORRUPT_CREW_FEMALE`, which the crew doesn't need this on) that swaps the
    Feather_Legs piece for `Config.SENKA_UNDERWEAR_LEGS_F` (the vanilla `SK_Armor_Underwear_02_
    Female_Legs`, no recolor — same choice the original crew-side saga landed on as
    least-wrong-looking) via a new `applyStatuePelvisBacking(actor)` helper, run as one extra
    `Spawner.DeCorrupt` pass immediately after `senkaCrewFix` settles, on both live placement and
    restore. This is a full REPLACE of the tribal fringe Legs piece with plain underwear geometry,
    not an added backing layer — trades the tribal look on that one piece for closing the gap.
    Untested live as of this write-up; the original attempt's rejection reason (mesh's own
    "bloomers" silhouette reads as an obviously separate garment) was about the mesh itself, not
    the crew's specific body, so it may or may not read better here.

49. **Pelvis-gap experiment rejected and reverted; a THIRD fix avenue also confirmed dead; the
    real remaining option identified but not yet pursued** (2026-08-14, same day). RedFalcon: "not
    what i wanted... I dont want different pants, i want to fix that [missing skin geometry]." He
    also asked whether `NO_Underwear_P` (the nude mod's second, unbundled pak) would help — no:
    that pak HOLLOWS OUT `SK_Armor_Underwear_02_Female_Legs` (confirmed from this project's own
    2026-08-13 investigation), the exact opposite of adding coverage, and would have broken item
    48's experiment had it been installed (same target asset).
    Before reverting, checked whether the PROPER pre-build lever (`compositeLook.archetype`,
    which sets `comp.ArchetypePreset` — the mechanism that actually controls BODY/skin, as
    opposed to `DefaultParams`/outfit, which is all that's proven to work anywhere in this mod)
    could force these statues onto the Adventurer archetype instead of a mesh-swap trick. Already
    settled, before this session even started: `WINDROSE_MODDING_NOTES.md` §2's own table records
    `ArchetypePreset` as NOT sticking pre-build — `BeginPlay` re-randomizes it regardless (proven:
    7 Warrior spawns pinned to African rolled 5 different ethnicities). So BOTH the only two
    mechanisms Lua/UE4SS scripting has for changing a composite pawn's body (post-build mesh swap,
    pre-build archetype pin) are now confirmed dead ends for this specific problem — not just
    "not yet tried hard enough."
    Reverted item 48's `Config.SENKA_STATUE_PELVIS_BACKING` / `applyStatuePelvisBacking` cleanly
    (both call sites in `spawnSenkaStatueEntry` and the restore rule, the helper function, and the
    config table itself — removed outright, not left disabled, since RedFalcon's rejection means it
    isn't the direction to pursue). `Config.SENKA_UNDERWEAR_LEGS_F` itself is untouched (still used
    elsewhere) — only the new statue-specific rules table and its plumbing came out.
    **The one remaining, not-yet-explored option**: `Config.FEMALE_WALKER_OVERLAYS`' own Letty
    entry already establishes her REAL body is `SK_Adventure_Female_01` — meaning at least one
    other posed-statue-eligible class in this game is natively Adventurer-bodied, already covered
    by the bundled fix, no scripting trick needed at all. If OTHER female posed/QuestStatic classes
    (beyond the 5 currently in `Config.SENKAMATI_STATUES`) also turn out to be Adventurer-bodied,
    swapping which statue CLASS a roster slot points at (not touching her mesh, just picking a
    body that's already compatible) would sidestep the whole problem for free. Not pursued yet —
    finding candidates needs live probing (HOME+PAUSE) of other faction statue classes to check
    their body mesh, same technique already used throughout this investigation; nothing to do from
    static config alone.

50. **Re-attempting the T-posed body-mesh-swap technique, on the theory it was locomotion-
    specific, not static-pose-specific** (2026-08-14, same day). RedFalcon's own observation: the
    proven T-pose (`Config.FEMALE_WALKER_OVERLAYS`' Marita entry, item 49) happened on the WALKING
    Handyman re-skin, where an AnimInstance continuously blends locomotion against the mesh every
    frame — these posed statues have no locomotion at all, a single static pose, so the same
    failure mode may not apply. Worth the live test: if it works, it's the actual root-cause fix
    (real Adventurer skin geometry instead of a workaround); if it also T-poses, that closes this
    avenue for good by showing the AnimInstance issue isn't locomotion-specific.
    `Config.SENKA_STATUE_BODY_SWAP_TEST` (config.lua): a `Spawner.DeCorrupt` `replaces` table
    matching each of the 4 non-Adventurer body meshes these statues use (Albion/Orient/African/
    Native, all confirmed via live probe, not guessed) to `SK_Adventure_Female_01` — the one
    archetype the bundled `Female_NUDE_P` actually covers. `applyStatueBodySwapTest(actor)`
    (testbed.lua) runs it as one more pass after `senkaCrewFix` settles (same "separate pass, own
    DeCorrupt call" shape the reverted pelvis-backing experiment used, item 48/49), and prints a
    plain component-count marker either way so a T-pose is unambiguous in `ue4ss.log` before RedFalcon
    even needs to look at her. **Deliberately NOT wired into the restore rule yet** — this is
    unproven and could T-pose, so a world reload shouldn't auto-apply it broadly across every
    restored statue before it's confirmed safe; if it works, wiring restore is the natural
    follow-up. Not yet tested live as of this write-up.

51. **Body-swap experiment live-tested: mixed result, pulled back out of the automatic path**
    (2026-08-14, same day, closing out item 50). RedFalcon placed all 5 posed rows with the experiment
    active. Result: **Standing** never matched at all (`changed=0`, Albion left untouched,
    unexplained). **Sitting 1** (Orient) matched and rendered correctly — no T-pose, correct
    armor. **Merchant** (also Orient — right alongside the Orient one that worked), **Sitting 2**
    (African), and **Sitting 3** (Native) all T-posed. So the "static pose avoids the
    locomotion-specific AnimInstance failure" theory from item 50 is only partially right — one
    static actor succeeded cleanly, but archetype alone doesn't predict the outcome (two Orient
    actors, one fine, one broken), so something else about Sitting 1's specific case differs and
    isn't understood yet. Immediately pulled `applyStatueBodySwapTest` out of
    `spawnSenkaStatueEntry`'s automatic call (RedFalcon was told to despawn the 3 T-posed actors right
    away) so new placements can't T-pose from this again. `Config.SENKA_STATUE_BODY_SWAP_TEST` and
    `applyStatueBodySwapTest` are kept in place, not deleted — the Sitting 1 success is a real,
    unexplained positive result worth a manual single-actor investigation later — but BOTH must
    stay un-wired from automatic placement AND restore until that discrepancy is actually
    understood, not just retried and hoped. **Net status of the pelvis-gap problem after items
    48-51**: still unfixed, three attempted fixes now confirmed dead-or-unreliable (underwear-mesh
    swap: rejected by RedFalcon; ArchetypePreset pre-build: proven non-sticky before this session even
    started; body-mesh post-build swap: T-poses 3-4 of 5 times) — the one remaining unexplored
    option is still finding an already-Adventurer-bodied alternate statue class (see item 49's own
    note).

52. **A third architecture for the statue roster: standing goes back to the crew body, seated
    stays on the real statue bodies** (2026-08-14, same day, closing out the pelvis-gap saga for
    now). RedFalcon's question cut through the false dichotomy items 47-51 had been stuck in ("re-skin
    a real posed body" vs "fix the wrong-archetype body"): *"is it not possible to assign a pose
    to an existing body... it has to be reskinned?"* Answer: pose is baked into each statue
    class's own AnimBP, not a settable property — but a STANDING pose doesn't need one at all. A
    character with its AI stopped while just standing there already looks like a standing statue.
    That's exactly the crew Caster's own body (Handyman/`Config.SENKA_FEMALE_BASE_CLASS`) — the
    one body in this whole investigation that was NEVER broken (correctly covered by the bundled
    `Female_NUDE_P` fix, armor already fits) — frozen via the SAME `Spawner.SetAILogic`/
    `freezeSenkaStatue` mechanism already built and proven for the mob "idle" rows.
    Brought a `"crew"` kind back into `spawnSenkaStatueEntry` (config.lua's `Config.
    SENKAMATI_STATUES`, testbed.lua's dispatch, and the restore rule all updated together) — freeze
    called FIRST (unserialized, immediately on spawn), THEN `senkaCrewFix` on the now-stationary
    body, same "freeze before de-corrupt" order item 48 already established for the mob rows and
    for the same reason. This is NOT simply reverting to item 45's original design: that version
    had TWO standing rows (mirroring `STANDING_STATUES`' Brethren Woman + Buccaneers Merchant for
    staging variety); since both would now be mechanically IDENTICAL (same base class, same
    params, same freeze — no second real body to vary them anymore), collapsed to ONE standing row
    rather than ship two redundant cycle stops.
    Seated rows are UNCHANGED (still `"posed"` kind, the real `Female_Sitting_01/02/03` bodies,
    still carrying the known unfixed gap/clipping issues from items 48-51) — there is currently no
    known way to force a genuinely SEATED pose onto the crew body; the two untried ideas from this
    same conversation (swap which AnimBP/animation class drives her existing mesh without
    touching the mesh itself; or let her AI wander to and sit at nearby placed furniture, the
    original pre-item-45 idea) are real candidates for a future session, not attempted here.
    Roster is now 6 rows: 1 standing (crew, fully fixed) + 3 seated (posed, gap/clipping still
    open) + 2 masked idle (mob, unaffected by any of this). Not yet tested live as of this
    write-up.

53. **A new probe for the next pose-matching investigation** (2026-08-14, same day). RedFalcon tested
    item 52's crew-based standing statue: correctly covered/fitted, but frozen into a generic
    neutral rest pose rather than the distinctive stance `Female_Standing_01` herself has baked
    into her own AnimBP -- expected, since `SetAILogic` just stops whatever pose the AI happened
    to be idling in, with no concept of "look like that OTHER actor." RedFalcon wants both (proper body
    AND proper pose) rather than settling for the neutral one. Proposed a genuinely different
    technique from anything tried today: port just the ANIMATION driving her pose, not the mesh --
    since nothing about her skeleton/body would change, this should sidestep the whole class of
    T-pose failure items 49-51 hit. Needs live data first to know what to port, so added
    `dumpAnimInfo(actor)` (spawner.lua) to the HOME+PAUSE probe chain (`Spawner.
    ProbeDumpProperties`): reads `actor.Mesh`'s `AnimationMode` (BlueprintMode vs
    SingleNodeMode -- tells you which of the next two matters), `AnimClass` (the AnimInstance
    Blueprint, if BlueprintMode), `AnimationData.AnimToPlay` (the single AnimSequence, if
    SingleNodeMode -- plausible given these are literally named "AnimatedActor" classes, possibly
    simpler than a full gameplay AnimBP), and the actual runtime `GetAnimInstance()` class as a
    cross-check. Pure reads, no side effects, same safety profile as every other probe in this
    chain. Next step: RedFalcon probes `Female_Standing_01` (what the pose SHOULD be) and the
    Handyman-based Caster (what she currently has) with HOME+PAUSE, compare the two `[probe-anim]`
    lines, then decide what's actually portable before attempting anything live.
    **Same-day follow-up, real bug caught immediately**: RedFalcon tested and PAUSE went completely
    silent again (not even its own first unconditional print) -- same total-silence signature as
    item 46's earlier bug, but this time on PAUSE, right after HOME completed normally. Root
    cause: the `AnimationData.AnimToPlay` read used plain dot-access
    (`mesh.AnimationData.AnimToPlay`) on `AnimationData`, which is a native engine STRUCT, not an
    object reference -- exactly the class of read this project had already been burned by once
    before (the per-world save-ID work, `WINDROSE_MODDING_NOTES.md` #10, needed real
    struct-drilling instead of plain `x.y`) -- a lesson that existed in this codebase's own
    history but wasn't cross-checked before writing this probe. A native crash from a bad struct
    read isn't catchable by `pcall`, so it silently killed the whole `Spawner.
    ProbeDumpProperties` call with zero error output, same non-catchable-crash class documented
    repeatedly elsewhere in this file. Fixed by dropping that one read entirely --
    `AnimationMode` (a plain enum) and `AnimClass` (a plain object reference) are both safe,
    precedented patterns and likely already answer the real question; `AnimToPlay` can be added
    back properly (real struct-drilling) later if it turns out to be needed. Deployed; not yet
    re-confirmed live as of this write-up.

54. **AnimClass swap implemented -- ports the real pose without touching mesh/skeleton**
    (2026-08-14, same day). After the double-lbreload scare (a genuine operational hazard, not a
    code bug -- RedFalcon fired `lbreload` twice ~7s apart, racing the reinstall; fixed by a full game
    restart, not more reloads) and a clean relaunch, both `[probe-anim]` reads landed without
    incident (confirming item 53's crash fix held): `Female_Standing_01` runs `AnimationMode=0`
    (BlueprintMode) driven by `ABP_StandingNPC_Regular_AI_C` (`.../Human/Regular/Share_HumanAI/...`
    -- the folder name itself suggesting a generic, reusable AnimBP); the crew Caster runs the same
    mode via her own `ABP_Human_NPC_C`. Same mode, both plain AnimBlueprint classes under
    `Human/Regular/...` -- good evidence the pose is portable via a straightforward AnimClass swap,
    a standard supported UE operation, fundamentally different from (and much safer than) the
    `SetSkeletalMeshAsset` calls that T-posed 3-4 of 5 statues in items 49-51, since the skeleton
    binding never changes here.
    Built `Spawner.SetAnimClass(actor, animClassPath)` (spawner.lua): resolves the class via the
    existing `resolveClass` helper (same one `Spawner.Spawn` itself uses for its own classPath
    argument), tries the proper runtime UFUNCTION (`mesh:SetAnimInstanceClass(cls)`, which
    reconstructs the live AnimInstance) first, falls back to a plain `mesh.AnimClass = cls`
    property assignment if that call isn't exposed in this build. `Config.
    SENKA_STATUE_STANDING_ANIM_CLASS` (config.lua) holds the confirmed path. Wired into BOTH the
    live-placement "crew" branch (`spawnSenkaStatueEntry`, right after `freezeSenkaStatue`) and the
    restore rule's "crew" branch, so a reloaded standing statue keeps the ported pose too. Not yet
    tested live as of this write-up -- next step is RedFalcon placing a fresh Standing statue and
    checking whether she actually takes on Female_Standing_01's stance instead of the generic
    neutral rest pose.

55. **AnimClass swap ALSO T-poses -- reverted immediately, pose-porting now looks structurally
    closed** (2026-08-14, same day, closing out item 54). RedFalcon tested: T-posed on the very first
    placement. Despite not touching the mesh/skeleton at all -- the theoretical safety argument
    item 54 made (skeleton binding never changes, only which AnimBP computes the pose) turned out
    not to matter in practice. Most likely explanation, not yet confirmed: `ABP_StandingNPC_
    Regular_AI_C` is very likely authored against a SPECIFIC target Skeleton asset (standard for
    any UE AnimBlueprint), and the "Share_HumanAI" folder name was a hopeful inference from this
    session, not a confirmed compatibility guarantee -- if the Handyman Gatherer's own skeleton
    isn't that exact skeleton (or a compatible child of it), the AnimGraph can't resolve bone names
    against it and the engine falls back to a T-pose, the same visible symptom as a botched mesh
    bind despite being a completely different underlying mechanism.
    Reverted immediately (RedFalcon despawned the T-posed actor) -- pulled the `Spawner.SetAnimClass`
    call out of both `spawnSenkaStatueEntry`'s "crew" branch and the restore rule's "crew" branch.
    `Spawner.SetAnimClass` and `Config.SENKA_STATUE_STANDING_ANIM_CLASS` are kept, not deleted (the
    function itself is a reasonable, generically-useful primitive; the constant records a
    confirmed-real asset path), but neither is called from anywhere as of this write-up.
    **Net status of the standing-pose-matching problem after items 53-55**: two independent
    techniques tried (mesh swap in the original T-pose precedent items 45/49-51; AnimClass swap
    here), both T-pose, for what look like two DIFFERENT underlying reasons (skeleton/mesh mismatch
    vs. skeleton/AnimBP mismatch) that happen to produce the identical visible failure. This isn't
    proof no fix exists, but two independent dead ends on the two most Lua-reachable techniques is
    a real signal, not a coincidence -- treat "port Female_Standing_01's pose onto the crew body"
    as closed unless a genuinely new, third mechanism is identified (not a retry of either of
    these). The crew-based Standing statue's neutral rest pose (item 52, still live) remains the
    working, shippable state: correct body/coverage, generic pose.

56. **A real lead: an Albion-archetype content pak, live-testing set up** (2026-08-14, same day).
    RedFalcon found a third-party "Alibon_Nude_P" pak (`Other\nudemods\Alibon_Nude_P_V2\`). Confirmed
    via a raw string-scan of its `.utoc` (same technique `WINDROSE_MODDING_NOTES.md` #9 already
    used on the game's own pak index) that it overrides `SK_Albion_Female_01.uasset` plus a
    matching texture -- Standing_01's OWN body archetype, exactly the one the bundled
    `Female_NUDE_P` (Adventurer-only) never covered. If it actually closes the gap the way
    `Female_NUDE_P` does, the REAL `Female_Standing_01` body becomes usable again -- fixing the
    coverage gap AND recovering her authentic baked-in pose simultaneously, fully sidestepping the
    T-pose dead ends from items 49-51 and 54-55 (neither the mesh-swap nor the AnimClass-swap
    trick would be needed at all).
    Installed as a STANDALONE test pak (`R5/Content/Paks/AlibonTest/`, live install only -- NOT
    bundled into LivingBase's own Paks folder or copied into `Working` yet) so it can be cleanly
    pulled if it doesn't work. Switched the "Standing" row in `Config.SENKAMATI_STATUES` back to
    `kind = "posed"` (was `"crew"`, item 52) pointing at the real `Female_Standing_01` body, so the
    test actually exercises the Albion archetype. The `"crew"` kind machinery in
    `spawnSenkaStatueEntry`/the restore rule was deliberately kept (not deleted) specifically so
    this is a one-line revert back to the known-safe crew body if the pak test fails.
    **Needs a FULL GAME RESTART, not `lbreload`, to test** -- per `WINDROSE_MODDING_NOTES.md` #11's
    own established finding, pak mounting only happens at game startup, it is not
    hot-reloadable. Not yet tested live as of this write-up.

57. **A standing-only test key, and a real archetype-randomization finding from the Albion pak
    test** (2026-08-14, same day). RedFalcon did a full game restart (paks need one, confirmed working
    per item 56) and re-tested the Standing statue with the Albion pak installed -- gap still
    visible. But the probe showed her body mesh was `SK_Fable_Female_01`, not Albion at all --
    meaning the test didn't actually exercise the pak; she rolled a different archetype this
    placement. This suggests the "posed" statue bodies' archetype may not be fixed per class the
    way items 47-51 assumed -- possibly the same "BeginPlay re-randomizes ArchetypePreset
    regardless of what's pre-built" behavior already documented for crew/mob composites
    (`WINDROSE_MODDING_NOTES.md` #2) also applies here, which would also help explain some of the
    earlier confusing per-actor inconsistency (e.g. item 51's Sitting-1-survives-but-
    Merchant-T-poses split). Not yet confirmed -- needs several repeated placements, each probed,
    to establish whether it's genuinely randomizing or something else caused this one result.
    To make that repeated testing fast, added a new key: `senkaStatueStanding` = `'-'`
    (`OEM_MINUS`, top-row minus, NOT `NUM_SUBTRACT` which is already precision-cycle) ->
    `Testbed.SpawnSenkaStatueStanding()` (testbed.lua) -- always places
    `Config.SENKAMATI_STATUES`' `pose == "standing"` row directly, bypassing
    `Testbed.SpawnNextSenkamatiStatue`'s cycle so repeated presses don't have to step through the
    other 5 looks first. Same safe OEM_* key family as `=`. Registered as a normal gated placement
    action (modGate + spawn-debounce), same as every other placement key -- not a bare/ungated
    dev-tool like HOME/PAUSE, since it genuinely places a persistent actor.

58. **Archetype forcing implemented: a genuinely untested mechanism, not a retry of a known dead
    end** (2026-08-14, same day). RedFalcon confirmed the Albion pak (item 56) genuinely closes the
    gap when she rolls Albion -- but per item 57's randomization finding, that's only ~1-in-7
    placements. RedFalcon asked directly: can the body type just be forced? Worth distinguishing from
    the already-proven-dead pre-build archetype pin (`compositeLook.archetype`, `WINDROSE_
    MODDING_NOTES.md` #2): `Spawner.ApplyComposite` (spawner.lua) is a DIFFERENT mechanism -- set
    `comp.ArchetypePreset` POST-build, then force a rebuild via `ConstructVisualFromParams`/
    `Start+EndCharacterEdit` (the same recipe already proven to work for outfit/DefaultParams
    changes) -- marked `EXPERIMENTAL` in its own comment and never actually called anywhere in the
    live codebase until now. Closest precedent (the same post-build-plus-rebuild recipe tried on
    `ColorParams` instead of archetype, item 35) resolved cleanly with no crash, just silently no
    visual effect -- a much safer failure mode than the T-pose risk of the mesh/AnimClass swaps.
    `Config.SENKA_STATUE_FORCE_ARCHETYPE`: NOT a guessed path -- read directly off a live
    `Standing_01` actor's own `comp.ArchetypePreset` (via HOME+PAUSE's `dumpArchetypeInfo`) at the
    exact moment she'd naturally rolled Albion, confirmed real for this class family
    specifically (`.../NPC/BrethrenOfTheCoast/Common/Female/DA_Mob_Brethren_Regular_Female_
    Preset_ArchetypeAlbion`) -- deliberately NOT the ShipCrew/Sailor archetype-preset family
    `WINDROSE_MODDING_NOTES.md` #2 documents for crew pawns, which is a different preset family
    entirely and would likely have resolved to nothing on a FactionActor statue class.
    Wired into ALL FOUR "posed" kind rows at once (Standing + 3 seated, since they share
    `spawnSenkaStatueEntry`'s one code path) -- both live placement and the restore rule. Runs
    via `Spawner.ApplyComposite(actor, params, forceArchetype)` after the same
    `Config.WARRIOR_DECORRUPT_DELAY_MS` settle delay senkaCrewFix's own first de-corrupt attempt
    already waits (touching a still-building composite is a confirmed crash trap), BEFORE
    senkaCrewFix's de-corrupt pass (ordering matters: `ApplyComposite` does a FULL rebuild, which
    would undo any component-level hide/replace senkaCrewFix already made if run after it), and
    inside the same `Spawner.RunSerialized` wrapper as everything else that touches composite
    state. Not yet tested live as of this write-up -- the Albion pak (item 56) needs to stay
    installed for this to show any visible effect; forcing the archetype without it would just
    move the gap back to a covered-nowhere state.

59. **Archetype forcing CONCLUDED DEAD -- reverted, fourth independent technique closed**
    (2026-08-14, same day, closing out item 58). RedFalcon tested: `[LivingBase:Composite]` logged a
    genuine success at every step (`BEFORE Archetype=...African` -> `AFTER Archetype=...Albion`,
    then `applied params archetype -> BuildedCompositeMeshes=5 BodySex=2`) -- but the actual
    rendered body never changed. Same "build-time-only consumed input" wall this mod already hit
    with `ColorParams` (item 35): the composite system reads archetype exactly once, during the
    pawn's TRUE initial construction, and nothing callable afterward -- not even the full rebuild
    sequence that demonstrably works for outfit/`DefaultParams` changes -- re-triggers that one
    step. Reverted cleanly: pulled `Spawner.ApplyComposite`'s archetype call out of both the
    "posed" branch in `spawnSenkaStatueEntry` and the restore rule (both back to calling
    `senkaCrewFix` directly, identical to their pre-item-58 shape). Documented the conclusion
    directly on `Spawner.ApplyComposite`'s own definition (spawner.lua, right after the function,
    matching how `ColorParams`' dead end is recorded next to it) -- `paramsPath` (outfit) remains
    proven and working; `archetypePath` is now a documented dead end, not just untested.
    `Config.SENKA_STATUE_FORCE_ARCHETYPE` is left in config.lua as a confirmed-real, useful
    reference asset path (in case a genuinely different mechanism is found later that CAN
    consume it), but nothing calls it.
    **Net status after items 53-59**: four independent techniques tried for controlling which
    body archetype a posed statue gets — pre-build pin (overridden by BeginPlay), post-build mesh
    swap (T-poses 3-4/5), AnimClass swap (T-poses), post-build archetype set + rebuild (silently
    no-ops) — all closed. The Albion content pak (item 56) is the only proven-working fix
    available, and it only helps on the ~1-in-7 placements that happen to roll Albion naturally.
    Real remaining options: (a) find/create equivalent paks for the other 6 archetype families
    (Adventurer already covered by the original `Female_NUDE_P`, so 5 more needed for full
    coverage), or (b) the still-unexplored "find an already-Adventurer-bodied alternate statue
    class" idea from item 49. Nothing else Lua-reachable is left to try on forcing/swapping the
    body itself.

60. **Archetype reroll-until-good, reusing the proven "topless retry" primitive** (2026-08-14,
    same day). Since forcing the archetype is now confirmed dead (item 59), RedFalcon asked for the
    same fix pattern already used for the walking-women "topless" problem: check what she actually
    landed on right after spawn, and if it isn't one of the archetypes with real coverage,
    despawn and respawn until it is. Also wanted the observed ratio visible, not just a silent
    retry.
    `Config.SENKA_STATUE_GOOD_BODY_MESHES` (config.lua): an allowlist of confirmed-covered body
    mesh names -- `SK_Adventure_Female_01` (bundled `Female_NUDE_P`) and `SK_Albion_Female_01`
    (the `Alibon_Nude_P` test pak, item 56) -- add more here the moment another archetype's
    coverage is confirmed, no other code changes needed. `Config.SENKA_STATUE_REROLL_MAX_TRIES`
    (20) caps the loop -- at ~2/7 odds per try, the chance of never landing a good one in 20 tries
    is under half a percent.
    `rerollStatueArchetype(s, actor, tries, done)` (testbed.lua): reads `actor.Mesh`'s current
    skeletal mesh name (`currentBodyMeshName`, same property `dumpMeshComponentNames` already
    reads), and if it's not in the allowlist, calls `Spawner.DespawnActor` + a fresh `Spawner.Spawn`
    at the same spot + recurses -- the EXACT same despawn+respawn+recurse shape already proven
    for `Testbed.ApplyFemaleReskinTarget`'s topless retry, just checking archetype instead of
    torso presence. Wired into ONLY the "posed" kind's live-placement path (the 4 rows that
    actually have this archetype-randomization problem) -- NOT the restore rule, deliberately:
    RedFalcon's ask was specifically about fresh placement ("when it spawns"), and rerolling on every
    reload would risk a player-placed statue's archetype silently changing across a save/reload,
    a bigger behavior change than asked for. Revisit if that's wanted too.
    **The ratio ask**: `tallyAndLogArchetype` keeps a module-scope running count of every roll
    (good or bad, every try, across every placement this session) and prints it with each roll --
    `ue4ss.log` now shows a live "session tally (N total): SK_X=n(p%), ..." breakdown, giving a
    real observed distribution across the 7 archetype families as more statues get placed, not
    just a one-off estimate.
    **Same-day follow-up**: RedFalcon asked for the final body type in the on-screen toast too, not
    just the log. `rerollStatueArchetype`'s `done` callback now passes `(finalActor,
    finalMeshName)` (harmless extra args -- every other caller in this file's plain no-arg
    `done()` convention still works fine). `spawnSenkaStatueEntry`'s "posed" branch wraps the
    whole spawn+reroll sequence in `Spawner._suppressSpawnToast` (the same flag `Spawner.
    UndoDespawn` already uses to avoid double-toasting a batch restore) so the intermediate
    reroll respawns stay silent, then fires ONE combined toast once the final body is known --
    `"Spawned: Senkamati Standing (Albion)"` etc. New `shortArchetypeLabel(meshName)` turns
    `SK_Albion_Female_01` into `Albion` for the display text.

61. **Per-try toast added; live archetype coverage now visually confirmed across all 7 families**
    (2026-08-14, same day). RedFalcon wanted every reroll try's body type on screen, not just the final
    settled one, so bad archetypes that get rerolled away could actually be looked at (in case one
    outside the allowlist turns out fine after all). Added a direct `Spawner.Toast("Try N: Family",
    2.0)` call in `rerollStatueArchetype`, right after `tallyAndLogArchetype` and before the
    allowlist check -- bypasses `Spawner._suppressSpawnToast` entirely since it calls `Spawner.Toast`
    directly rather than going through `Spawner.Spawn`'s own gated toast. Also promoted
    `currentBodyMeshName`/`shortArchetypeLabel` out of testbed.lua into shared
    `Spawner.CurrentBodyMeshName`/`Spawner.ShortArchetypeLabel`, and gave `Spawner.Spawn`'s own
    generic "Spawned: X" toast a body-type suffix too (delayed ~4.5s for composite-look spawns,
    same settle time `senkaCrewFix` already waits, so it reads the built mesh not a placeholder).
    First test of this still only showed good rolls -- turned out the edited Working files had
    never actually been copied to the live install (no deploy script exists; `diff` confirmed
    `spawner.lua`/`testbed.lua` were stale on disk under `J:\...\ue4ss\Mods\LivingBase\Scripts`).
    Copied both files over; `lbreload` picked up the change with the game still running.
    With per-try visibility working, RedFalcon placed enough statues to see all 7 archetype families
    roll and confirmed by eye: **only Adventurer and Albion actually look right with the armor** --
    matching `Config.SENKA_STATUE_GOOD_BODY_MESHES` exactly as it already stood. This closes the
    "which archetypes are covered" question with a real visual answer instead of a
    two-confirmed-so-far placeholder. RedFalcon also corrected the diagnosis: this isn't a skin/coverage
    gap like `Female_NUDE_P`/`Alibon_Nude_P` fix -- it's the ARMOR itself not conforming to the
    body shape. Their read: the Senkamati Caster mob likely only ever ships with ONE archetype in
    vanilla, so its armor was rigged/skinned for that one body only; forcing a different archetype
    underneath just exposes that it was never built to deform across shapes. That means another
    Alibon_Nude_P-style body-mesh pak is the wrong tool for the other 5 families -- a real fix
    would mean reshaping/reskinning the ARMOR per archetype, a much bigger asset-authoring task,
    not a body swap. No code change needed here -- the allowlist was already correct; updated its
    comment (and `SENKA_STATUE_GOOD_BODY_MESHES`' own header) to record the corrected diagnosis.

62. **A genuinely new post-build lever confirmed working: BodySex -- plus what it means (and
    doesn't) for pose** (2026-08-14, same day). RedFalcon probed an unrelated wild male Standing
    NPC and noticed `IsBodySexChangeAvailable=true` -- asked whether a POST-build sex change
    could actually render, unlike the confirmed-dead `ColorParams`/`ArchetypePreset` struct-field
    writes (items 35, 59). Built `Spawner.ApplyBodySex` (`comp:SetCharacterSex(newSex)` + the same
    rebuild-trigger recipe) and a throwaway test key (F6, `Testbed.TestApplyBodySex`, flips
    whatever HOME last probed). **Confirmed live: it worked** -- BodySex genuinely changed and
    rendered. This is a real, useful distinction for future work in this codebase: `ColorParams`/
    `ArchetypePreset` are struct FIELDS the rebuild recipe writes and then hopes gets picked up;
    `SetCharacterSex` is a dedicated ENGINE FUNCTION with its own side effects -- post-build writes
    to composite state aren't uniformly dead, genuine setter FUNCTIONS can still work where raw
    field writes don't.
    RedFalcon then asked the natural follow-up: can a POSE be assigned the same way? Built the
    analogous `Spawner.ApplyPose` (`mesh:SetAnimationMode(SingleNode)` +
    `mesh:SetAnimation(seq)` + `mesh:Play(false)` + `mesh:SetPosition(0)`) plus a second test key
    (F5, `Testbed.TestApplyPose`, reads `Config.TEST_POSE_ANIM_SEQUENCE`) -- deliberately NOT a
    retry of the AnimClass swap that already T-posed (item 54/55), since single-node playback of
    one static AnimSequence only needs the skeleton to match, not the whole AnimBP's movement/
    event-graph wiring.
    Needed the REAL pose asset first, not a guess. `dumpAnimInfo` (spawner.lua) got a new safe
    read for `AnimationData.AnimToPlay` -- the exact struct-drilling recipe
    `WINDROSE_MODDING_NOTES.md` #10 established for the per-world save ID (top-level struct
    property read is safe; `:GetFullName()` on the wrapper hands back its OWN UScriptStruct path
    instead of guessing one; `StaticFindObject` + `ForEachProperty` + bracket-indexing the
    instance reads each field safely) -- plain dot-access into this exact field
    (`mesh.AnimationData.AnimToPlay`) is what crashed the game earlier this same session. **Live-
    confirmed: the safe version works, no crash**, full property dump completed cleanly.
    **Result on the real `Female_Standing_01`**: `AnimationMode=0` (BlueprintMode, NOT SingleNode)
    -- she's driven live by `ABP_StandingNPC_Regular_AI_C`, the EXACT SAME AnimBlueprint class the
    item 54/55 AnimClass swap already tried and T-posed with. `AnimationData.AnimToPlay` read back
    `A_Regular_Carpenter_Idle`, but that's just SingleNode's unused fallback field on the struct --
    irrelevant, since BlueprintMode ignores it entirely. **So `Spawner.ApplyPose` cannot help port
    Standing_01's exact stance** -- there's no static AnimSequence to grab; her pose is generated
    live by the same AnimBP already confirmed dead for this purpose. `Config.
    TEST_POSE_ANIM_SEQUENCE` deliberately left `nil` rather than set to the misleading Carpenter-
    Idle value. Next step (RedFalcon's call): probe a real SEATED statue (`Female_Sitting_01/02/
    03`) instead -- a static sit-and-do-nothing pose is more likely to genuinely be SingleNode,
    where this tool would actually apply. Not yet tested as of this write-up.

63. **Pose-porting CLOSED -- five independent techniques, same failure mode, timing ruled out**
    (2026-08-14/15, continuing the same session). `Female_Sitting_01` probed the same as Standing --
    also `AnimationMode=0` (BlueprintMode), same shared `ABP_StandingNPC_Regular_AI_C` class, same
    irrelevant SingleNode fallback data. Confirms `Spawner.ApplyPose` is dead for BOTH pose types,
    not just Standing.
    Went one level deeper: dumped the AnimInstance's OWN declared properties (new `dumpObjectProperties
    (animInstance, "ANIMINSTANCE")` call inside `dumpAnimInfo`, reusing the existing safe
    reflection walk unchanged) on both real statues. Found the actual pose selector: a plain
    `Animation` UObject-reference property directly on the AnimInstance (fed into
    `AnimGraphNode_SequencePlayer`) -- Standing_01 reads `A_AnimatedActor_Regular_Female_Idle_
    Standing_05`, Sitting_01 reads `...SittingOnChair_01`. Built `Spawner.ApplyBlueprintPose`
    (`SetAnimClass` + set the fresh instance's `Animation` property) -- **first live test: the
    property write itself succeeded and read back correctly (`BEFORE=(none) AFTER=<requested
    sequence>`), and she STILL T-posed.**
    Re-probed her afterward and found two more mismatched AnimInstance variables vs. the real
    statue: `IsFemale?` read `false` (real statue: `true`) -- a bare class swap never inherits the
    statue's own construction-script values -- and `ArmorThicknessMorph` read `0.0` (real statue:
    `0.35`). Extended `ApplyBlueprintPose` to also set both, hardcoded to the real statue's own
    probed values. **Second live test: all three properties set AND read back correctly
    (`IsFemale? false->true`, `ArmorThicknessMorph 0.0->0.35`, `Animation` correct) -- RedFalcon:
    "i dont see a difference"** -- still T-posed, identical to before.
    Last angle: since `Spawner.SetCompositeParams` already proved PRE-build composite writes stick
    where POST-build ones don't (that's its entire reason for existing), tried the same timing
    shift for anim state -- `Spawner.MakePreBuildPoseSetter` returns a `preFinish`-compatible
    closure (runs in the deferred spawn window, before `BeginPlay`) that does the exact same
    `SetAnimInstanceClass` + `IsFemale?`/`ArmorThicknessMorph`/`Animation` sequence.
    **Third live test: `AnimInstance IS available at preFinish time` (genuinely uncertain going
    in -- components can exist before their AnimInstance does), every write reported `ok` --
    RedFalcon: "she tposed on spawn."** Identical failure, now confirmed regardless of timing.
    **Conclusion: timing is ruled out as the variable** (unlike the composite/outfit system, where
    it was the whole answer) -- pre-build and post-build now both fail identically despite clean
    writes at every level. The remaining explanation is structural, not a property we can reach
    from Lua: `AnimGraphNode_ControlRig` (seen in every AnimInstance property dump this session) is
    almost certainly bound to specific rig/bone data baked into its own Control Rig asset at author
    time -- exposed Blueprint variables can't retarget that. Five independently-designed techniques,
    same "reports success, never renders" signature -- same status as `ColorParams`/`ArchetypePreset`
    (items 35, 59) pending one more check (RedFalcon's own follow-up, same session -- see below)
    before actually calling it closed.
    **RE-OPENED immediately, same session**: RedFalcon: "what if we set every anim setting the same
    as the standing pose, in case something important was missed" -- a fair challenge to the
    "confirmed dead" framing above. Checking it honestly: `dumpObjectProperties`'s generic reader
    prints any STRUCT-typed property as its bare TYPE name only ("ScriptStruct /Script/CoreUObject.
    Vector"), never the actual field values -- so `BodyMorph` (sitting right next to
    `ArmorThicknessMorph` in the exact same property list, clearly a per-archetype body-shape input
    given the name) was NEVER actually compared between the real statue and any test actor, unlike
    `IsFemale?`/`ArmorThicknessMorph`/`Animation`, which all were. A real gap, not a re-litigation of
    something already checked. Added a targeted, safe read for it in `dumpAnimInfo` -- same struct-
    drilling recipe as `AnimationData.AnimToPlay` (`GetFullName` for the type path, `StaticFindObject`,
    `ForEachProperty`, bracket-index the instance) -- deliberately NOT extended to the OTHER struct
    properties in that same dump (`AnimGraphNode_Root`/`Slot`/`ControlRig`/`SequencePlayer`,
    `UberGraphFrame`): those are internal anim-runtime state/raw execution pointers the compiled
    graph rebuilds every frame, not configuration -- a plain `FVector` is a fundamentally different,
    much safer thing to read (or write, via a plain `{X=,Y=,Z=}` Lua table -- same pattern
    `Spawner.WarpNear` already uses for `K2_SetActorLocation`) than those are.
    **Probed both actors: genuinely different.** Real Standing_01: `X=0.0 Y=0.84752953052521
    Z=0.093581974506378`. The crew test actor's class default (what a bare `SetAnimClass` leaves it
    at): `X=0.0 Y=0.0 Z=1.0` -- Z pushed to a full 1.0 vs. the real statue's 0.093, plausibly an
    untested extreme for whatever blend this feeds. Added as a third write (plain Lua table
    assignment, no struct-drilling needed to WRITE it) to both `ApplyBlueprintPose` (post-build) and
    `MakePreBuildPoseSetter` (pre-build), hardcoded to the real statue's probed values.
    **Live test: the write succeeded, and RedFalcon's own re-probe (not just an immediate post-write
    echo) confirmed it genuinely stuck -- `BodyMorph` now reads the exact real-statue values. She
    STILL T-posed, identical to every prior attempt.**
    **This closes the "was something missed" question for real.** Every exposed Blueprint variable
    on the AnimInstance that differed from the real statue (`IsFemale?`, `ArmorThicknessMorph`,
    `BodyMorph`) plus the pose selector itself (`Animation`) have now all been matched to the real
    statue's own values and independently re-verified as actually holding -- not just reporting
    success in the moment. Six independent attempts (mesh-swap, AnimClass-only, SingleNode/
    AnimSequence, the 3-property post-build combo, the same combo pre-build, and now +BodyMorph on
    both paths), same outcome every time. **Pose-porting is CLOSED, same status as `ColorParams`/
    `ArchetypePreset` (items 35, 59) -- don't re-chase without a genuinely new theory that addresses
    the Control Rig's own binding specifically** (`AnimGraphNode_ControlRig`, present in every
    AnimInstance dump this session -- almost certainly bound to rig/bone data baked into its own
    Control Rig asset at author time, a layer below anything an exposed Blueprint variable can
    reach). Nothing about the shipped feature changes: the crew-body Standing statue (`lblook
    StandingCrewTest`) still works fine with her plain neutral idle pose; only porting Standing_01's
    EXACT baked stance onto her remains unsolved. All test tools (`Spawner.ApplyPose`,
    `ApplyBlueprintPose`, `MakePreBuildPoseSetter`, F5/F6 keys, both lblook entries) are kept, not
    deleted -- harmless, and useful precedent/scaffolding if a real new theory ever shows up.

64. **A real SetBody function found via the object dump -- CONFIRMED TO CRASH THE GAME, two-for-two**
    (2026-08-15, same session, right after item 63 closed). RedFalcon's follow-up to `ApplyBodySex`'s
    success: "something like the sexchange or pose change [for] the mesh in use, something we
    missed?" -- a fair question, since `SetCharacterSex` worked specifically BECAUSE it's a real
    engine function, not a raw property write. Checked `UE4SS_ObjectDump.txt` directly for every
    function `R5CompositeMeshComponent` declares (the actual source `SetCharacterSex`/
    `IsBodySexChangeAvailable` were found in originally, back in the 2026-08-13 refresh) and found
    `SetBody(InBodyType: FGameplayTag, InBodySex: EBodySex, bForceLoad: bool)` sitting right next to
    `SetCharacterSex`, with matching getters `GetBodyType()`/`GetAvailableBodyTypes()`. Genuinely
    different mechanism from the confirmed-dead `ArchetypePreset` DataAsset property (item 59): body
    type here is a GAMEPLAY TAG (`Customization.Morph.BodyType.<Family>`), not an asset reference.
    Built a safe discovery probe (`dumpAvailableBodyTypes`, wired into PAUSE) rather than guess a tag
    string -- confirmed live all 7 known families plus two extras (`GalenSkelton`, `Ksante`, filtered
    out at the Female sex filter -- presumably male-only/named-character bodies), and confirmed
    `FGameplayTag` is a trivial one-field struct (`TagName`, an FName) safe to write as a plain
    `{ TagName = "..." }` Lua table (same convention `Spawner.WarpNear` already uses for `FVector`).
    Hit one real bug along the way: bracket-indexing the returned `TArray<FGameplayTag>` gave a
    `RemoteUnrealParam` wrapper, not the struct directly (same issue already solved once for
    component arrays -- needs `:get()` to unwrap) -- fixed before the roster read actually worked.
    Built `Spawner.ApplyBodyType` (same BEFORE/AFTER readback pattern as `ApplyBodySex`) and a test
    key (F4) to force a probed actor onto Albion specifically -- a known-covered archetype, so the
    result would be directly checkable either way.
    **CONFIRMED LIVE: `comp:SetBody(...)` crashes the game natively.** Two presses, two crashes
    (`crash_2026_08_15_00_37_57` and `_00_41_27`), `UE4SS.log` showing ZERO `[LivingBase:BodyType]`
    output either time -- that line is the very FIRST thing `ApplyBodyType` prints, right after the
    `pcall`-wrapped `SetBody` call returns; never printing means execution never came back to Lua at
    all. Same "pcall cannot catch this" class of native crash as `Config.TATTOO_TEST_PARAMS`, but a
    materially different failure mode than every OTHER post-build lever tried this session
    (`ColorParams`/`ArchetypePreset`/all five pose-porting attempts) -- those all failed SAFELY,
    reporting success and just not rendering; this one crashes the engine outright. No debugger was
    available to symbolize the raw `.dmp` minidumps -- the log evidence alone was unambiguous enough
    not to need one.
    **F4/`testApplyBodyType` REMOVED from the key rotation immediately** (main.lua/config.lua both
    updated with prominent removal notes). `Spawner.ApplyBodyType`/`Testbed.TestApplyBodyType` are
    kept, not deleted, marked CONFIRMED-DANGEROUS in their own comments -- same treatment
    `Config.TATTOO_TEST_PARAMS` already got. **Do not wire `comp:SetBody` into any live key or spawn
    path again without a genuinely new theory about why it crashes** -- the archetype-coverage
    problem stays on the reroll-until-good workaround (item 60); this was a real, well-motivated
    attempt at a proper fix, and it's now a confirmed dead end, not an untried one.

65. **Loose-file content replacement investigated -- a real process bug found and fixed along the
    way, final result inconclusive-to-negative** (2026-08-15, same session). RedFalcon asked
    whether an extracted `.uasset` could just be dropped into a matching `Content/` path instead of
    packaged into a `.pak`, prompted by a forum claim that Windrose's DEMO build had properly
    fitting pelvis meshes. Two separate questions untangled: (1) cooked vs. uncooked format --
    `WINDROSE_MODDING_NOTES.md` #11 already established a raw EDITOR-exported `.uasset` can't be
    loaded without re-cooking; RedFalcon's export was via FModel's raw/"Save Package" mode instead,
    which preserves actual cooked bytes, so that blocker didn't apply here. (2) whether THIS
    Shipping build honors loose files under `Content/` at all instead of requiring the pak/IoStore
    system -- genuinely unknown, untested before now.
    First test (single Adventure mesh, `Female_NUDE_P.pak` moved to a `..._backup` folder): looked
    like a success ("loose files work"). Found a FormModel-sourced "release day" build online (the
    actual demo build itself couldn't be found) and exported ALL 7 archetype body meshes from it --
    theory being the release build's meshes might not have this pelvis-gap problem at all. Disabled
    the `Alibon_Nude_P` pak the same way, copied all 6 non-Adventure meshes into place (Adventure
    left untouched per RedFalcon's instruction). **Result: Albion and Adventure still looked fine,
    the other 5 still gapped** -- RedFalcon suspected the "disabled" paks were still being picked up.
    **Confirmed correct, and a real bug**: `WINDROSE_MODDING_NOTES.md` #11 states pak discovery is
    RECURSIVE under `R5/Content/Paks/` -- both `..._backup`/`..._DISABLED` folders were created
    AS SUBFOLDERS of `Paks/` itself, so renaming never actually stopped them being auto-mounted.
    This means the FIRST "loose files work" result is also unverified -- Adventure may have been
    rendering correctly via the still-active old pak the entire time, not the loose file at all.
    Fixed by moving both backups fully outside the game install (`Other/disabled_pak_backups/` in
    the project folder, not anywhere under `R5/Content/`) and re-tested clean.
    **Final result: it reverted** -- with the paks genuinely disabled this time, Adventure and
    Albion ALSO went back to gapped, same as the other 5. Loose-file placement of just the body
    mesh is NOT sufficient on its own to fix the coverage problem (matches
    `WINDROSE_MODDING_NOTES.md` #11's own "a mesh that attaches and animates correctly is not the
    same as one that fits visually" finding, and its note that a companion `.uexp`/`.ubulk` may be
    required alongside the `.uasset` -- the release-day export only produced single `.uasset`
    files, no companions, for all 7). RedFalcon's own conclusion: closing this investigation out.
    Real, reusable process lesson either way: **disabling a pak means moving it fully OUTSIDE
    `R5/Content/Paks/`, not just renaming/relocating it to a sibling folder within that tree** --
    every earlier pak A/B test this session that used a `Paks/<name>_backup` pattern should be
    treated as potentially having had this same flaw, though those were swap tests between two
    paks fixing the SAME problem, so a silently-still-mounted old pak likely didn't change those
    conclusions the way it did here.

66. **Num7 roster: frozen "idle" comparison rows added, for NSFW safety during casual browsing**
    (2026-08-15, same session). RedFalcon: add "idle masked"/"idle not masked" rows after each
    Senkamati type in `Config.SENKAMATI_LOOKS` (Num7), including mob-body versions -- motivated by
    the "posed" statue rows (`Config.SENKAMATI_STATUES`) flashing bare skin/nipples repeatedly
    during their archetype reroll, and even a normal walking Num7 crew row being briefly nude while
    her composite layers build before de-corrupt catches up. An idle row can't wander the base
    still exposed for that whole ~4.5s window the way a walking one can, even though freezing alone
    doesn't eliminate the initial composite-build flash itself (a rendering-timing issue, unrelated
    to AI state) -- mob-kind rows were never at risk either way (a single pre-baked, already-clothed
    skeletal mesh, no composite layering at all), added mainly for parity/comparison.
    Added `idle=true` as a new optional field on `Config.SENKAMATI_LOOKS` rows; `spawnSenkaEntry`
    (testbed.lua) now calls `freezeSenkaStatue` FIRST (unserialized, same proven ordering the
    statue roster already uses) when `s.idle`, for both "crew" and "mob" kinds -- 12 new rows total
    (4 per type -- idle crew masked/unmasked + idle mob masked/unmasked -- across Warrior/Hunter/
    Caster-F; "corrupted" kind untouched, never had this ask).
    Two real bugs caught and fixed before this actually worked, both from touching shared
    infrastructure other rows already depend on:
    - `senkaRowKey`'s persist.txt encoding (`name::kind::helmet`) had no way to tell a new idle row
      apart from an existing walking row of the same name+kind+helmet -- extended to a 4th `::idle`
      segment. `baseLabel` was deliberately kept OUT of this same key in an earlier session
      (collision was harmless there since restore re-applies identical rules either way) -- idle
      genuinely changes restore behavior, so this one couldn't be left out. Old 3-segment persisted
      keys simply fail to match the new 4-segment pattern and fall through to the already-
      established "can't recover this row exactly" default, same graceful degradation as any other
      pre-existing-format save.
    - `spawnSenkaEntry` (which needed to call `freezeSenkaStatue`) is defined EARLIER in testbed.lua
      than `freezeSenkaStatue` itself (written originally for the statue roster, further down) --
      Lua resolves an as-yet-undeclared name as a global at the point a function is DEFINED, not
      when it's later called, so this would have silently resolved to a nonexistent global and
      crashed the first time an idle row actually spawned. Fixed with the standard Lua forward-
      declaration idiom: `local freezeSenkaStatue` pre-declared near `spawnSenkaEntry`, then the
      `local` keyword dropped from the real `function freezeSenkaStatue(...)` definition so it
      assigns to that same variable instead of shadowing it. Both `RESTORE_RULES` entries for Num7
      (mob and crew) also updated to freeze-first on `row.idle` when a saved idle row reloads.
    **Same-day follow-up**: RedFalcon asked for idle versions of the "corrupted" rows too. No code
    change needed -- `spawnSenkaEntry`'s mob/corrupted branch already covers `s.kind ==
    "corrupted"` under the exact same `if s.idle then freezeSenkaStatue(actor) end` check written
    for "mob", since both kinds share one branch. Just 3 new rows (Warrior/Hunter/Caster-F,
    `idle = true`, no masked/unmasked split since "corrupted" skips de-corrupt entirely and never
    had one) -- 15 new rows in `Config.SENKAMATI_LOOKS` total from this item.

67. **A third-party pak (`AFrancisLouis_NudeFemalePlayerWR_P`, `R5/Content/Paks/WR_1/`) looked
    like a comprehensive fix for the archetype-coverage problem -- closed, contents unreachable**
    (2026-08-15, same session). String-scanned its `.utoc`/`.pak`/`.ucas` (same technique already
    proven on `Alibon_Nude_P`/`mFemale_Nude_P`): unlike every prior pak (each fixed exactly ONE
    archetype), this one's texture table covers ALL 7 families (Adventure/African/Albion/Fable/
    Native/Orient/Scum), each at 3 body sizes, each with 3 map types (Albedo/Normal/SRM) -- plus
    morph-target and bone-name strings (`Morph_Zone_Body`, `Correct_l/r`, several waist/torso/legs
    mesh names) suggesting body-shape correction morphs, not just textures, and shader-type-info
    references in the `.pak` index suggesting custom materials too. By far the broadest-scoped
    candidate found this session.
    RedFalcon: it's ALSO built to remove/hide the underwear slot entirely -- the opposite of what's
    wanted (coverage, not more exposure) -- and neither FModel nor UModel can extract or properly
    browse it, so there's no way to separate the wanted texture/morph fix from the unwanted
    behavior, or inspect/edit it at all.
    Diagnosed WHY, ruling out theories in order rather than guessing: (1) header structurally
    valid -- correct IoStore magic (`-==--==--==--==-`), same `FIoStoreTocHeader` field pattern as
    the confirmed-working `Alibon_Nude_P.utoc`, just different values -- not corrupted at the
    container level. (2) NOT AES-encrypted (confirmed by FModel directly -- an earlier encryption
    theory here was wrong, corrected once real tool output was available rather than left
    standing). (3) UModel's real error, once pointed at the correct root
    (`R5/Content/Paks`, not the whole game install -- pointing at the game root walks into UE4SS's
    own SEPARATE `.../ue4ss/Mods/Content/Paks/~mods/` folder too and gets confused trying to
    resolve a global container for pak files found there): `FString is not null terminated`,
    inside `FIoDirectoryIndexResource::Serialize`, failing at entry 161 of 162 in the pak's
    internal file-name table -- essentially the very LAST entry. RedFalcon's read, and the
    genuinely likely explanation: deliberate, not accidental -- a common, simple anti-extraction
    technique is to intentionally corrupt just the human-readable directory index (which generic
    browsing tools depend on to build a file tree) while leaving the actual chunk data intact,
    since the game's own loader resolves assets by chunk ID at runtime and may never need that
    index to be valid at all.
    **Closed**: no extraction path available with the tools on hand, and even if the coverage/morph
    fix inside is genuinely as good as the string-scan suggests, the baked-in underwear removal
    makes it unusable as-is regardless. Worth revisiting only if a differently-packaged source for
    the same fix turns up, or a tool with a tolerant/skip-bad-entries parse mode becomes available.

68. **Test-key cleanup, and the sex-change discovery graduated to a real (undocumented) console
    command** (2026-08-15, same session, closing out the Senkamati statue work). RedFalcon: "I
    dont want those test keys any more since we moved them into the 7 roster" -- the frozen
    crew/mob-body idle rows added to Num7 (item 66) made the standalone pose-porting test spawns
    redundant. Removed: F5/`testApplyPose` + `Testbed.TestApplyPose`, F6/`testApplyBodySex` +
    `Testbed.TestApplyBodySex`, and the lblook-only `StandingCrewTest`/`StandingCrewPoseTest`
    entries (both the `LBLOOK_CATEGORIES` listing and the by-name dispatch `order` table in
    main.lua) along with their backing `Testbed.SpawnStandingCrewTest`/`SpawnStandingCrewPoseTest`
    functions. Kept, undeployed, as documented reference (same treatment as `Config.
    TATTOO_TEST_PARAMS`): `Spawner.ApplyPose`/`ApplyBlueprintPose`/`MakePreBuildPoseSetter` (the
    pose-porting investigation itself, item 63, stays closed) and `Spawner.ApplyBodyType`/
    `Testbed.TestApplyBodyType` (the confirmed-crashing `SetBody` call, item 64 -- already
    unregistered from any key before this item, no further change needed here).
    RedFalcon also asked to turn the sex-change capability itself into a real console command
    (`lbsexchange`) instead of throwaway scaffolding -- explicit spec: check
    `IsBodySexChangeAvailable()` FIRST rather than just attempting the swap, then report exactly
    "`<name> has been switched to <male|female>`" or "`<name> does not support changing sex`".
    Targets the nearest SPAWNED actor in front (`findNearestSpawnInFront`, the same target-lock-
    aware picker despawn/cycle/live-edit already share) rather than the dev-only HOME probe the old
    F6 key used -- RedFalcon: "it only has to work on spawned ones", not arbitrary wild NPCs.
    `Spawner.ApplySexChangeToNearest(say)` does the actual work (reuses the already-proven
    `Spawner.ApplyBodySex` for the swap itself, independently re-reads `GetBodySex()` afterward to
    confirm it genuinely stuck rather than trusting an immediate echo); `say` is passed in from
    main.lua's command handler so spawner.lua has no dependency on UE4SS's console output-device
    machinery. **Deliberately NOT documented in README.md/NEXUS_*.txt** (RedFalcon: results could
    be NSFW) -- console-only, undiscoverable unless you already know the command name; this
    CLAUDE.md entry is the only record of it existing.
69. **Senkamati Statues (item 45) fully REMOVED -- the whole `=`/`-` feature, not just trimmed**
    (2026-08-15, same session). Before this: `Distribution\LivingBaseEnhanced\1.3.10\` was built
    (RedFalcon: "let's get this into distribution") following the standard checklist (docs first,
    mirror Working, strip dev-only files, zip), and `Alibon_Nude_P` (the Albion-archetype body-mesh
    fix, item 56/61, live-tested standalone in `AlibonTest\`) got folded into the mod's OWN bundled
    content pak alongside `Female_NUDE_P` (RedFalcon: "lets get the albion paks in there too",
    confirmed openly shared on LoversLab so no permission gap like `Female_NUDE_P` needed) --
    `R5/Content/Paks/LivingBase/` now ships both, the standalone `AlibonTest\` folder retired.
    Then RedFalcon flagged a stale CHANGELOG mention of the `=` key; checking confirmed it was
    still very much live, not stale -- and RedFalcon's real ask was to remove the whole thing:
    "if its still there we need to get rid of it as the cycles produce NSFW results. no - or =.
    whats in 7 is all we should have." Root cause: the Statues' posed rows auto-rerolled body
    archetype on placement until the armor fit cleanly, briefly flashing through OTHER archetypes
    (bare skin) first -- exactly the exposure risk item 66 built the Num7 frozen-idle rows to
    avoid, so the Statues feature undermined its own sibling. Removed entirely: both keys
    (`Config.KEYS.senkaStatue`/`senkaStatueStanding`, `=`/`-`), `Config.SENKAMATI_STATUES` and
    every constant that only served it (`SENKA_STATUE_STANDING_ANIM_CLASS`, `TEST_POSE_ANIM_
    SEQUENCE`, `SENKA_STATUE_FORCE_ARCHETYPE`, `SENKA_STATUE_GOOD_BODY_MESHES`, `SENKA_STATUE_
    REROLL_MAX_TRIES`, `SENKA_STATUE_BODY_SWAP_TEST`), `senkaStatueRowKey`/`parseSenkaStatueRowKey`,
    `applyStatueBodySwapTest`, `statueArchetypeTally`/`tallyAndLogArchetype`, `shortArchetypeLabel`,
    `rerollStatueArchetype`, `spawnSenkaStatueEntry`, `Testbed.SpawnNextSenkamatiStatue`/
    `SpawnSenkaStatueStanding`, their `main.lua` key registrations, and the `RESTORE_RULES` entry
    matching `"^STATUE::"`. Kept, confirmed still load-bearing (RedFalcon, mid-removal: "we want to
    keep the idles on 7 though"): `freezeSenkaStatue` -- built for the Statues but reused by item
    66's Num7 `idle=true` rows, its header comment updated to say so -- plus the bundled `Female_
    NUDE_P`/`Alibon_Nude_P` body-mesh fixes themselves, which still help ordinary Num7/crew
    archetype rolls elsewhere and were never part of what made Statues risky. Scrubbed every
    mention from `CHANGELOG.txt` (v1.3.10 hadn't shipped publicly yet, so rewritten clean rather
    than documented as "added then removed"), `NEXUS_CHANGELOG_1.3.10.txt`, `NEXUS_DESCRIPTION.txt`,
    `README.md`, `NEXUS_README.txt`, and this file's own keybinding table/intro. `lint.py` clean
    after every edit (`compile: 10 scripts OK`). Also caught mid-task: the archive-before-overwriting
    rule (below) had silently lapsed again for this session's earlier doc edits (`CHANGELOG.txt`,
    `NEXUS_CHANGELOG_1.3.10.txt` went unsnapshotted) -- fixed going forward for the rest of this
    task's edits, not retroactively reconstructed for those two.
- **Archive before overwriting.** Before editing an existing file under `Scripts/` (or `README.md`/
  `CHANGELOG.txt`/`NEXUS_DESCRIPTION.txt`), copy its CURRENT (pre-edit) contents into `archive/` as
  `archive/<basename>_<YYYYMMDD_HHMMSS>.<ext>` (e.g. `archive/config.lua_20260813_143022.lua`) —
  the pattern already used for the dozens of snapshots already in that folder. This was previously
  only encoded as pre-approved one-off commands in `Working\.claude\settings.json`, never written
  down as a rule, so it silently lapsed for several sessions (last real snapshot: 2026-08-11) until
  the gap was noticed on 2026-08-13. Skip it only for genuinely new files (nothing to snapshot yet).
- **Keep `Windrose_Modding_Notes.txt` in sync with `WINDROSE_MODDING_NOTES.md`.** The public,
  shareable copy lives at `Working\Windrose_Modding_Notes.txt` (repo root, one level up from this
  mod's own folder) — same underlying engine knowledge as `WINDROSE_MODDING_NOTES.md`, but
  regenerated through a generalization pass: strip this mod's own function/variable names and any
  "this mod"/version-specific framing, keep the durable technique, and only name a specific
  third-party mod/asset if it's already safe to name publicly (skip attribution for anything used
  under an informal/no-attribution permission — see the 2026-08-13 nude-body-mesh add-on for the
  pattern to follow). Any time `WINDROSE_MODDING_NOTES.md` gains a new numbered section, or an
  existing one changes meaningfully, regenerate the public copy to match in the same pass — don't
  leave it for later. This was previously only written down in Claude's own memory system (not
  durable to a fresh session or a different tool), which is why it's captured here now.
- **Building a `Distribution\LivingBaseEnhanced\<version>\` release: update docs FIRST, then
  mirror Working, then strip dev-only files before zipping.** Three steps, in order:
  1. **Update the docs, before touching Distribution at all.** For whatever actually changed
     this round:
     - `CHANGELOG.txt` — the all-in-one, every-version history. Add/amend the entry under the
       CURRENT version's own `====...====` block if folding into an existing version (no new
       version number — see the 2026-08-13 Caster body-fit entry for the pattern), or add a new
       block if this IS a version bump.
     - `NEXUS_CHANGELOG_<version>.txt` — the per-version, Nexus-post-formatted counterpart to the
       above. Keep it in step with whatever `CHANGELOG.txt` just got for that version.
     - `NEXUS_DESCRIPTION.txt` — the main Nexus page body. Only needs a real edit if a change
       affects a FEATURE description already written there (e.g. keybind behavior, roster counts)
       — most bugfix-only changes won't touch this at all; check, don't assume either way.
     - `README.md` — the actual end-user reference (controls/features/config/known limitations).
       This is the one most likely to need a real edit for anything user-visible.
     - `WINDROSE_MODDING_NOTES.md` — double-check whether this session's work surfaced any
       durable engine/tooling finding not yet captured (see that file's own §-numbered pattern),
       not just whether existing sections are still accurate. If it changes, regenerate
       `Working\Windrose_Modding_Notes.txt` to match in the same pass (separate rule above).
     - `NEXUS_README.txt` — a BBCode transliteration of the CURRENT `README.md` (full technical
       reference: controls, console commands, features, config, known limitations, license), NOT
       the shorter marketing-style `NEXUS_DESCRIPTION.txt`. Match that file's own established
       BBCode conventions (`[size=5][b]...[/b][/size]` headers, `[color=#D4D4D8]...[/color]` body
       text, `[b]`/`[url=...]` inline) rather than inventing new formatting. Regenerate this any
       time `README.md` changes. **Never include it in the actual `Distribution\` build/zip** —
       it exists purely so there's a ready-to-paste BBCode version on hand when updating the
       Nexus page itself; nothing in it is needed by an end user's local install.
     Skip whichever of these a given change genuinely doesn't touch — this isn't "edit all six
     every time," it's "check all six every time, edit what actually needs it."
  2. **Mirror Working into Distribution.** Copy the CURRENT `R5\Binaries\Win64\ue4ss\Mods\
     LivingBase\` folder from Working wholesale (so nothing new in Working gets missed), then
     remove the dev-only files below.
  3. **Strip dev-only files, verify, then zip** (see the exact include/exclude list below).
  - `archive/` (this folder's own snapshot history — never shipped)
  - `__pycache__/` and any other Python bytecode cache (`*.pyc`) — regenerates every time
    `lint.py` runs locally; pure build artifact, not tied to any specific file/date to check for
  - `lint.py` — dev-only syntax/reference checker, no runtime dependency on it at all (confirmed
    2026-08-13); shipped in 1.3.5/1.3.7/the first 1.3.8 build, deliberately DROPPED starting with
    the 2026-08-13 rebuild of 1.3.8 — don't revive it without being asked again
  - `NEXUS_CHANGELOG_*.txt`, `NEXUS_README.txt`, `REDDIT_POST.md`, `CONSOLE_SPAWN_REFERENCE.md`,
    `DISPLAY_NAMES.md` — dev/posting reference material, never shipped in any version (confirmed
    by diffing 1.3.5/1.3.7/old-1.3.8's actual file lists on 2026-08-13, not by any prior written
    rule; `NEXUS_README.txt` didn't exist yet at that point but belongs in the same category)
  What SHOULD ship, confirmed against that same diff: `ASSET_CATALOG.md`, `CHANGELOG.txt`,
  `CLAUDE.md`, `config.txt`, `enabled.txt`, `mod.txt`, `NEXUS_DESCRIPTION.txt`, `README.md`,
  `WINDROSE_MODDING_NOTES.md`, and everything under `Scripts/` (including `class_index.lua` as of
  2026-08-13 — genuinely new, actually `require`d by `main.lua`, unlike the dev-reference docs
  above). If `R5\Content\Paks\LivingBase\` exists (a bundled content pak, e.g. the nude-body-mesh
  add-on folded in 2026-08-13), it ships too — it's a sibling of the Lua side, not dev-only.
  Do a final `find`/listing pass against this exact set before compressing — don't assume a
  wholesale directory mirror is already correct just because it compiles/runs.
- Every engine-touching call wrapped in `pcall`.
- Diagnostics needed for live troubleshooting (edit/despawn/undo/cycle) print
  **unconditionally**, not gated behind `Config.VERBOSE` — that flag is for routine
  per-spawn noise only; hiding troubleshooting output behind an off-by-default flag
  defeats the point (there's no in-game console; `ue4ss.log` is the only window in).
- Syntax-check every edit (`luac -p file.lua`, or `lupa` if `luac` isn't installed)
  before considering a change done.
- Game-version-dependent strings/paths live only in `config.lua`.
- When two features need the same "find/target the object in front of the player" logic,
  use the shared `findNearestSpawnInFront` rather than writing it again.
- On-screen feedback always goes through `Spawner.Toast` — never reach for
  `KismetSystemLibrary:PrintString` or `PlayerController:ClientMessage` again for gameplay-visible
  text; both are confirmed dead ends in this game (screen-messages flag off with no working exec
  command to flip it; routes to UE4SS's own separate console window, not the game's HUD). `Toast`
  itself is the real mechanism: constructs a native `TextBlock`, splices it into the game's own
  `WBP_SideNotificationsContainer_C` via `AddChild`, and manages removal through one shared
  self-rescheduling ticker rather than a timer per call (see item 24 for why per-call timers
  weren't reliable here).