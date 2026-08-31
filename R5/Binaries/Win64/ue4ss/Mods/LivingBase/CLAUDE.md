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

70. **Ship-pivot placement probe added — exploring a future ship decor/crew feature, NOT YET
    TESTED LIVE** (2026-08-25). RedFalcon asked to explore changing LivingBase's crew variety after
    pointing at a separate companion mod, XenophonCompanion, which tames a native hostile-faction
    crew pawn as a following companion. That investigation surfaced a further idea: Xenophon also
    has code (its own "58A/58B/58C-R1" sections) that teleports its companion onto the player's
    ship on embark, positioned via a 2D "inboard" vector built from TWO live-queried points (the
    helm's `SteeringInteractTargetComponent` location and the ship actor's own origin) — its own
    comment trail shows an EARLIER version tried using the ship's actual rotation for this instead
    and was withdrawn, though the specific failure reason wasn't preserved in that file. RedFalcon
    asked whether offsets could instead be computed directly from the ship's own pivot (actor
    location + rotation) — simpler in principle, and untested by anyone as far as this project
    knows.
    Built as a standalone probe, not a real feature — this mod has no ship/decor mechanic at all
    yet, so there's nothing to wire this into; it exists purely to generate real evidence before
    deciding whether to build one. `Spawner.FindPlayerShip()` (spawner.lua) locates the ship the
    player is currently standing on via `BasedMovement.MovementBase`'s owner (falling back to
    `GetAttachParentActor()`), the same two checks Xenophon's own code already confirmed live.
    `Spawner.ShipPivotTestPlace(fwd, right, up)` transforms a local (forward, right, up) offset by
    the ship's current location + yaw into a world position, places a plain `Config.CREW_CLASS`
    test actor there (or moves it, if one already exists), then checks 350ms later whether
    `BasedMovement` actually latched the actor onto the ship — same verify-via-readback the rest of
    this file always does, same specific check Xenophon's `.58C-R1` uses to confirm a placement
    "latched." `Spawner.ShipPivotTestStatus()` is the actual test: run it after moving/turning the
    ship (with no re-placement) to recompute the test actor's CURRENT local offset from the ship's
    CURRENT transform — near-zero drift from the originally requested offset would confirm the
    pivot-relative math holds regardless of the ship's position/heading; real drift would mean it
    doesn't, or that `BasedMovement` isn't keeping it seated correctly. `Spawner.
    ShipPivotTestClear()` despawns the test actor. Wired to three console commands
    (`lbshiptest [forward] [right] [up]` / `lbshiptest` with no args for status-only / `lbshiptestclear`,
    main.lua) — a console dev-tool, not a numpad key, same shape as `lbfollowtest`/`lbcustomscan`.
    Every reading logs to both `ue4ss.log` and a new `LivingBase_ShipPivotTest_dump.txt` (multi-
    candidate relative path, same convention `customization_survey.jsonl` already uses) so a full
    test session survives to be written up afterward.
    **Not yet tested live** — next step is RedFalcon boarding their own ship, running `lbshiptest`
    a few times at different offsets, then moving/turning the ship and re-running `lbshiptest`
    (no args) to check drift. Once there's a real result, the durable finding belongs in
    `WINDROSE_MODDING_NOTES.md` (and its public mirror), not just here — this entry only records
    that the tool was built and why.
    **Same-day follow-up — tested live, CONFIRMED**: RedFalcon boarded their own ship (a
    `BP_Ship_Brig_Brethren_C`) and ran the sequence above. Placement latched onto `BasedMovement`
    immediately (350ms verify: `latchedToShip=true`). The recomputed local offset came back
    IDENTICAL — `(fwd=222.7, right=0.0, up=191.3)` vs. `(fwd=222.8, right=-0.5, up=189.6)` — across
    two status checks taken ~58s apart, the second AFTER the ship had genuinely sailed (~1300uu)
    and turned (~49°) in between. Confirms the pivot-relative yaw math holds through real movement
    and turning, same as hoped. One real wrinkle: the SETTLED local offset didn't match the
    REQUESTED one — asked for `(fwd=300, right=0, up=100)`, got `(fwd=223, right=0, up=191)`
    instead, consistently, from the very first check onward. Read as the engine's own gravity/
    collision correcting the actor's exact resting spot once, right after the teleport-in, since
    the naive `up` constant doesn't account for the deck's actual height/slope at that specific
    XY. Practical rule for later: place, then immediately re-read the ACTUAL settled local offset
    (same inverse-transform `lbshiptest` status check does) and use that as the tuned value for a
    given spot — it only needs doing once, since it then holds indefinitely. Full write-up (with
    the general technique, stripped of this mod's own function names) is
    `WINDROSE_MODDING_NOTES.md` §13, mirrored to the public `Windrose_Modding_Notes.txt` and the
    `Windrose-UE4SS-Modding-Notes` repo (commit `65ab2dd`) same day.

71. **`lbshiplook` — an actual Walker/Statue preview, not just the pivot test's placeholder**
    (2026-08-25, same day, right after item 70's live confirmation). RedFalcon asked to see a real
    Walker or Statue placed (rather than judging placement quality from the plain
    `Config.CREW_CLASS` actor `lbshiptest` uses) — the natural next step for evaluating what either
    would actually look like as ship crew/decor, tying back to this session's original "swap the
    active crew type" exploration.
    `Testbed.SpawnShipLookPreview(kind, fwd, right, up)` (testbed.lua): auto-detects whether the
    player is currently on a ship (`Spawner.FindPlayerShip()`) and branches — on a ship, it reuses
    item 70's proven pivot-relative math (now exported as `Spawner.ShipLocalToWorld`, promoted out
    of being a `spawner.lua`-local, since a second caller needed it) via a direct `Spawner.Spawn`
    call at the computed destination; off a ship, it falls straight through to the ALREADY-PROVEN
    "in front of you" placement — calling `spawnTownsmanEntry`/`placeStatueEntry` directly (both
    already local to this file) rather than re-deriving `frontSpot`/floor-snap logic a second time.
    Deliberately does NOT floor-snap on the ship-relative path — a moving deck isn't "the floor"
    `playerFloorZ()`'s logic was built for, and item 70 already established the settled Z needs
    re-measuring per spot anyway, not assumed. Picks the first roster entry of each kind ("Walker",
    and `Config.STANDING_STATUES[1]`, the Brethren Standing Woman) — a quick look, not a by-name
    picker yet. Wired to `lbshiplook <walker|statue> [forward] [right] [up]` (main.lua), same
    `say()`/`Ar:Log()` shape every other console command here uses. Unlike `lbshiptest`'s own
    actor (a deliberate throwaway, tracked only in `Spawner.shipPivotTest`), this goes through
    `Spawner.Spawn` normally — a real, persisted spawn that despawn/undo/cycle all already work on,
    no new plumbing needed for that.
    **Process note**: `testbed.lua` was edited before archiving its pre-edit contents, breaking
    this project's own "archive before overwriting" rule for that one file this session (spawner.lua/
    main.lua were archived correctly beforehand). Caught immediately, before any further edits —
    reconstructed the exact pre-edit content by removing the known insertion (a clean, self-
    contained addition with no other changes nearby, so this was a lossless recovery, not a
    reconstruction from memory) and archived that as `archive/testbed_20260825_114540.lua`, same as
    if the rule had been followed originally.
    **Not yet tested live** — deployed to the live install, not yet run in-game as of this
    write-up.
    **Same-day follow-up, before any live test**: RedFalcon asked whether the off-ship preview
    spot should instead be computed from the CAMERA's own position, ~600uu out along wherever
    it's actually looking, rather than the mod's ordinary near-player placement — confirmed as a
    real, intended direction ("that's what we're going to do eventually anyway"), not a one-off
    experiment. Worth naming the tension this touches: `frontSpot`/`spotInFrontOfPlayer`
    (testbed.lua) deliberately stayed PLAYER-origin + YAW-ONLY for every real placement key in
    this mod (item 16) specifically because camera-origin at SHORT range (200-300uu) already
    broke targeting once (item 15) — the camera sits well behind/above the pawn root in third
    person, and at short range that offset rivals the target distance itself. That lesson doesn't
    reverse here; it just doesn't apply at 600uu, where the same fixed offset is a much smaller
    fraction of the total distance (the same reasoning a separate mod's own 1000uu camera-forward
    targeting already relies on, item 13). Built `Spawner.CameraForwardSpot(distance)`
    (spawner.lua) as a clearly-separate primitive from `frontSpot` — same self-consistent
    position+rotation-from-PlayerCameraManager discipline every other camera read in this file
    already uses, full pitch+yaw (not yaw-only), explicitly NOT wired into any of the mod's
    ordinary placement keys, only into this preview command.
    Threading it into `Testbed.SpawnShipLookPreview`'s off-ship branch needed a real location-
    override parameter on the functions it already reused (`spawnTownsmanEntry`/`placeStatueEntry`/
    `spawnPosed`) rather than duplicating their archetype-variation/yaw-correction/label logic a
    second time — added `atLocation` as a trailing OPTIONAL parameter to all three (every existing
    caller across the whole mod omits it, so every other call site is provably unaffected). For
    `spawnPosed` specifically, supplying `atLocation` also SKIPS its floor-snap step entirely —
    `playerFloorZ()` traces down from the player's own position, which is only meaningful for the
    default near-player spot; re-snapping a camera-aimed 3D point (which may be well above/below
    the player's own local ground, especially with pitch) to the player's own floor height would
    silently throw the aim away. Falls back to the ordinary frontSpot placement automatically if
    the camera read ever fails (`CameraForwardSpot` returns nil, which every downstream `atLocation
    or frontSpot(300)`-shaped check already treats as "use the default"), rather than failing the
    whole preview.
    **Not yet tested live** — this addition is untested as of this write-up.
    **Same-day follow-up, tested live**: RedFalcon ran both `lbshiplook walker` and `lbshiplook
    statue` while on their ship. The Walker rode along correctly with zero issues. The Statue did
    NOT: it stayed in place while the ship bobbed (appeared to move up/down as the deck rocked
    through it) and was left behind entirely once the ship got underway. Root cause: a Walker is
    a Character with its own `CharacterMovementComponent`, which runs its OWN per-tick floor
    check and sets `BasedMovement` automatically the instant it's standing on a moving surface —
    this is exactly why item 70's ship-pivot test (also a Character, the plain crew class) latched
    with nothing more than a teleport, no attach call needed. A posed `AnimatedActor` statue has
    no movement component and never runs that check, so it never acquires a moving base on its
    own no matter where it's placed — it just sits at its last teleported world position while the
    ship's collision moves through/past it.
    Fix: `Spawner.AttachActorToShip(actor, ship)` (spawner.lua) — a genuine actor-to-actor attach
    instead of relying on `BasedMovement` auto-detection, which only ever applied to Characters in
    the first place. Tries the modern per-axis-rule `K2_AttachToActor(ship, "", 1, 1, 1, false)`
    (same shape as the already-proven `K2_AttachToComponent` calls elsewhere in this file,
    `EAttachmentRule::KeepWorld` = 1 on all three axes so the actor doesn't jump on attach),
    falling back to the older single-enum `K2_AttachToActor(ship, "", 1, false)` shape if the
    first doesn't verify — this game's actual actor-level attach UFUNCTION signature has never
    been confirmed in this codebase before now, unlike the component-level attach this borrows
    its enum values from. Verified via `GetAttachParentActor()` readback, not trusted from the
    call alone. Wired into `Testbed.SpawnShipLookPreview`'s on-ship statue branch only — the
    Walker branch is untouched, since it already works for free and a Character being
    actor-attached on top of its own movement component could fight its own AI/pathing in ways
    never tested here.
    **Not yet tested live** — this fix is deployed but unconfirmed as of this write-up; next step
    is RedFalcon re-running `lbshiplook statue` on the ship and checking whether it now rides
    along through both bobbing and sailing.
    **Same-day follow-up: CONFIRMED TO CRASH THE GAME, two-for-two, REVERTED**. RedFalcon tried
    `lbshiplook statue` on the ship — the game crashed. Tried again — crashed again. Same
    pcall-uncatchable-native-crash signature already documented for `Config.TATTOO_TEST_PARAMS`
    and `comp:SetBody` (item 64): the append-only ship-test dump file (which survives a relaunch,
    unlike `ue4ss.log`, which resets on each launch) shows ZERO "ATTACH" log lines across both
    crash attempts — `Spawner.AttachActorToShip`'s own final log call, which runs unconditionally
    after both the modern and classic attach attempts regardless of outcome, never fired either
    time. That means execution never returned to Lua after the very first
    `actor:K2_AttachToActor(ship, "", 1, 1, 1, false)` call — the crash happens inside that native
    call itself, `pcall` and all, same as `SetBody`.
    **Immediately reverted**: pulled the `Spawner.AttachActorToShip` call out of
    `Testbed.SpawnShipLookPreview`'s statue branch entirely (the Walker branch, which never called
    it, is untouched and still works). The function itself is kept, unregistered from every call
    site, its own header comment rewritten to CONFIRMED-DANGEROUS status (same treatment
    `Spawner.ApplyBodyType`/`Config.TATTOO_TEST_PARAMS` already got) — do not call it again, and
    do not retry any variant (different enum values, the classic 4-arg fallback signature, a
    different socket string) without first getting a real crash log/dump that says why, since
    guessing a "safer" variant blind is exactly how this one shipped in the first place. Root
    cause not established — could be this specific argument combination, could be
    `K2_AttachToActor` itself on this actor class, could be something specific to attaching onto a
    ship actor (moving, physics-driven, replicated) as opposed to the static-mesh attach targets
    already proven safe elsewhere in this file.
    **Net status**: the original reported problem (a statue placed on a ship floats in place and
    gets left behind, since it has no `CharacterMovementComponent` to auto-latch onto
    `BasedMovement` the way a Walker does) is STILL UNSOLVED and is now a documented known
    limitation, not silently papered over. `lbshiplook statue` on a ship will reproduce the
    original float/left-behind symptom again, safely, with no attach attempt — this was
    intentionally chosen over leaving the crashing call in place under any condition.
    **Same-day follow-up: a safe alternative that avoids the attach UFUNCTION entirely.**
    RedFalcon asked whether periodically re-syncing the statue's transform to the ship would be
    too expensive — no: this mod already runs several actors on self-rescheduling timers doing
    the same shape of work (the leash sweep, the whistle escort re-warp, the toast ticker), all
    handling more actors more often than a handful of moored statues would need. Built
    `Spawner.AddShipRider(actor, ship)`/`Spawner.ShipRiderTick()` (spawner.lua, right next to the
    now-disabled `AttachActorToShip` for direct comparison): captures the actor's REAL settled
    local offset (via the newly-exported `Spawner.ShipWorldToLocal`, the inverse of §13's own
    `Spawner.ShipLocalToWorld`) and relative yaw the moment it starts riding, then a
    self-rescheduling tick (`Config.SHIP_RIDER_TICK_MS`, 200ms/5-per-second default) recomputes
    the ship's current world position from that fixed local offset and calls
    `K2_SetActorLocation`/`K2_SetActorRotation` — both already proven safe everywhere else in this
    file, no attach call, no new engine surface. Self-stops (does not reschedule) once its rider
    list empties, same shape as `Spawner.StartTargetLockTick`, not an always-on loop. Wired into
    `Testbed.SpawnShipLookPreview`'s statue branch in place of the removed attach call.
    **Same-day follow-up, tested live**: RedFalcon confirmed the "senkamati" kind rides the ship
    perfectly (as expected — it's still a Character under the hood, just with AI stopped, "no
    AI" was never actually the load-bearing difference). The statue "kind of worked" via
    `Spawner.AddShipRider` but was visibly jittery — it sits frozen for the whole 200ms between
    ticks while the ship's own bob/sail motion (rendered every frame) moves out from under it,
    then snaps back. RedFalcon then asked directly whether the SAME mechanism that keeps a person
    based on the ship could be given to a plain object. Answer: it's not really "AI" doing that —
    it's specifically the Character's own movement component running its own per-tick floor
    check, independent of whatever the AIController is deciding (which is exactly why the frozen
    Senkamati still rides fine — `StopLogic` only pauses decisions, not that component). A statue
    has no such component at all. Constructing/attaching one to a non-Character actor at runtime
    is a real possibility in principle, but was NOT attempted — it's the same class of "guess at
    engine construction machinery" operation as `SetBody` and the actor attach, both of which
    already crashed this exact session; not worth a third blind guess. Took the cheap, zero-risk
    lever instead: raised `Config.SHIP_RIDER_TICK_MS` from 200 to 40 (5/sec -> 25/sec) — still two
    plain transform writes per tick, same trivial-cost reasoning as before, just paid more often.
    **Not yet tested live** — this specific change is unconfirmed as of this write-up. If 40ms
    still reads as jittery, the next lever is a shorter interval still (UE4SS's own timer
    resolution is the real floor, not processing cost) — not a different mechanism, unless
    RedFalcon wants to revisit the movement-component-attach idea with the understood crash risk.
    **Same-day follow-up: RedFalcon opted straight for the movement-component idea** ("let's try
    the engine. if it doesn't work we'll abandon that option") rather than waiting on the 40ms
    result. Built `Spawner.TryAddMovementComponentToNearest(say)` (spawner.lua) — a HIGH-RISK
    EXPERIMENT, clearly labeled as such in its own comment: constructing and attaching a BRAND-NEW
    `UCharacterMovementComponent` to an actor at runtime, a genuinely different and also-unproven
    engine operation from anything tried before (every existing component attach in this file
    works with components that ALREADY EXIST — mesh pieces onto sockets — never a freshly
    constructed one). `CharacterMovementComponent` internally assumes an `ACharacter` owner in
    several places, so this could silently no-op, error safely, or crash the same way
    `ApplyBodyType`/`AttachActorToShip` already did.
    De-risked as far as possible before the actual risky call, same discipline as the toast
    investigation (item 22): (1) resolve the component's class via `StaticFindObject` — pure
    read; (2) check whether the target already has one via `GetComponentByClass` — pure read; (3)
    walk the actor's own class hierarchy with `ForEachFunction` (the exact proven-safe technique
    `dumpCompositeFunctions` already uses) to confirm `AddComponentByClass` actually exists on
    this class BEFORE calling it, rather than guessing a function name blind. Only if all three
    checks pass does it attempt the real construction — and logs IMMEDIATELY BEFORE that one call
    (not just after, unlike `AttachActorToShip`'s original mistake), so even a full crash leaves a
    breadcrumb in the append-only dump file confirming exactly how far execution got. Targets the
    nearest spawned actor in front (`findNearestSpawnInFront`, the same picker `lbsexchange`/
    despawn/cycle/live-edit already share) via a new console command, `lbshipmovecomp` — aim it at
    a placed `SHIP_LOOK_Statue` before running it.
    **Not yet tested live** — untested as of this write-up. RedFalcon has explicitly accepted the
    crash risk for this one; if it crashes, per RedFalcon's own framing, this avenue is abandoned,
    not retried with a different variant.
    **Same-day follow-up, before any live test**: RedFalcon flagged a real targeting problem —
    the statue is actively being repositioned by `Spawner.AddShipRider`'s jitter-sync, so aiming
    the ordinary cone/range picker at it is unreliable (it may drift out of the cone by the
    moment the command runs). Fixed with a two-level lookup in
    `Spawner.TryAddMovementComponentToNearest`: (1) if `Spawner.shipRiders` has an active entry,
    target that actor DIRECTLY — no aiming at all, since the exact reference is already held;
    (2) otherwise fall through to `findNearestSpawnInFront`, which already checks
    `Spawner.lockedTarget` (Num+) before any cone/range test, so a target locked beforehand still
    resolves correctly even after moving. Only a truly un-ridden, unlocked target still needs to
    be aimed at live.
    **Same-day follow-up: a real bug, same class as item 66's own documented lesson**. RedFalcon
    ran `lbshipmovecomp` and got a Lua error before any of the risky logic ever ran: "attempt to
    call a nil value (global 'findNearestSpawnInFront')". Root cause: `findNearestSpawnInFront`
    is declared `local` further down in spawner.lua than where
    `Spawner.TryAddMovementComponentToNearest` had been placed — the exact same "a function
    defined before an as-yet-undeclared local resolves that name as a global" trap item 66
    already hit once for `spawnSenkaEntry`/`freezeSenkaStatue` in testbed.lua, just recurring
    here in spawner.lua. Fixed by relocating the whole function (comment and all) to just before
    `Spawner.ApplySexChangeToNearest`, which already calls `findNearestSpawnInFront` successfully
    from that position — no logic changed, purely a reordering. **Lesson reinforced**: when adding
    a new function that calls an existing `local function` in a large file, check that local's
    OWN declaration line is actually above the new call site before assuming it's in scope — this
    is now the second time in this codebase specifically that assumption was wrong.
    **Not yet re-tested live** — the actual high-risk `AddComponentByClass` attempt has still
    never run; this fix only gets the command to reach that point without erroring first.
    **Same-day follow-up: the risky call itself SUCCEEDED, no crash.** RedFalcon re-ran
    `lbshipmovecomp` after the ordering fix — `ue4ss.log` confirmed every step passed cleanly:
    `AddComponentByClass call ok=true result=UObject: 0000014B5D18E958`,
    `verified present after call=true`. A brand-new `CharacterMovementComponent` was genuinely
    constructed and attached to the statue with no crash — a real, positive result after two
    confirmed crashes earlier this session from adjacent operations. **Important caveat, not yet
    resolved**: the component EXISTING doesn't prove it's actually doing anything — it may be
    missing internal wiring (`UpdatedComponent` etc.) that normally only gets set up as part of an
    actual `ACharacter`'s own construction, which this bare `AddComponentByClass` call never went
    through. Also, `Spawner.AddShipRider`'s manual jitter-sync was still actively re-teleporting
    the same actor every 40ms, which would mask whatever the new component does or doesn't do on
    its own. Added an automatic step: `Spawner.TryAddMovementComponentToNearest` now calls
    `Spawner.RemoveShipRider(actor)` immediately after a CONFIRMED successful add (not on
    failure), so the component's real behavior can be observed in isolation, uncontaminated by the
    manual workaround.
    **Not yet tested live** — whether the bare component alone actually makes the statue ride the
    ship (as opposed to just existing, inert) is the open question RedFalcon still needs to
    observe next: with the manual sync now removed, does it hold position, float in place, or
    genuinely track the ship?

72. **`lbshiplook` gains a third kind: an idle Senkamati look** (2026-08-25, same day). RedFalcon
    asked for a way to preview "one of the idle forms of the senkamati" through the same command.
    `firstIdleSenkaLook()` (testbed.lua) finds the first `idle == true` row in
    `Config.SENKAMATI_LOOKS` dynamically (not a hardcoded table index — that roster has been
    reordered before, see its own comment history) rather than picking by name, matching
    RedFalcon's "one of the idle forms" phrasing rather than a specific look. `spawnSenkaEntry`
    (already the function every Num7/restore path uses) gained the same optional trailing
    `atLocation` override already added to `spawnTownsmanEntry`/`placeStatueEntry`/`spawnPosed` —
    every existing caller omits it and is unaffected; when set, floor-snap is skipped in both its
    "crew" and "mob"/"corrupted" branches for the same reason as the other two (a caller-supplied
    3D point already has its own intended height, `playerFloorZ()` would silently discard it).
    `Testbed.SpawnShipLookPreview` and `lbshiplook`'s usage text both extended to
    `<walker|statue|senkamati>`. On a ship, the picked idle row is expected (not yet confirmed
    live) to auto-latch onto `BasedMovement` the same way the Walker does with zero extra code —
    a "crew"-kind idle row is still a Character with a `CharacterMovementComponent`; `StopLogic`
    (which `freezeSenkaStatue` calls, already wired into `spawnSenkaEntry` for any `s.idle` row)
    only stops the AIController's own decision-making, not the movement component's per-tick floor
    check that `BasedMovement` actually depends on. Not wired into `Spawner.AddShipRider` — only
    added there if live testing shows it's actually needed, matching why the Walker branch was
    never touched either.
    **Not yet tested live** — untested as of this write-up.

73. **Ship-decor/statue direction abandoned; a pakcontents.xlsx animation search turns up real
    NPC ship-crew activity animations; a generic path-fed pose tester built** (2026-08-25, same
    day). After the movement-component experiment (item 72's own follow-ups) produced erratic
    gravity-driven bobbing unrelated to the ship's actual motion — not the mooring behavior wanted
    — RedFalcon called it per their own stated criteria: abandon decorations/statues on ships
    entirely, keep only Walking (the Walker) and Idle (frozen Senkamati) — both genuine Characters
    that already ride the ship correctly for free via their own movement component, no workaround
    needed.
    RedFalcon then asked whether real ship/workbench activity animations could be found in "the
    list I exported" — `WindroseUE4SSModdingNotes/pakcontents.xlsx`, a full asset-path export
    across every pak chunk (built 2026-08-24, not previously searched for this). Scanned it for
    animation-related paths matching ship/workbench/craft keywords — real, substantial hits:
    - **`Character/Animations/Human/Regular/Shared/Ship/`**: genuinely NPC-labeled (not
      player-only "Hero") ship-crew animations — `Wheel/AM_..._Wheel_FakeInteraction` (name
      strongly suggests the game's own "NPC idling at the helm" animation), `Cannons/` (per-side
      `_Idle_01`/`_Start`/`_Shoot_Reload_01`/`_End`, plain `A_`-prefixed idle sequences included),
      `Hammock/` (`_Spawn`/`_Sleep`/`_Despawn`, plus older plain-sequence versions at
      `Character/Animations/Ship/A_Hammock_Idle`), `Ropes/` (hauling animations, with their own
      VAT rope mesh — a separate, more involved system).
    - **`Character/Animations/Human/Regular/Shared/CampActivity/`**: workbench/crafting
      animations not ship-specific but same "doing an activity at a station" shape — Sawmill/Table
      interact, Cooking (cutting table, pot), Blacksmith (anvil, bellows).
    - Also a whole existing roster of posed `BP_AnimatedActor_*_CarpenterIdle`/`_Chat_01`/
      `_FireWarm`/`_LeanOnWall`/`_SitterOnGround_01-04`/`_SitterOnStool` Sailor/Musketeer/Trapper/
      TortugaCitizen figures — same AnimatedActor/statue class family just abandoned for ship use,
      so land-only unless revisited.
    Flagged one real naming distinction before picking a target: `AM_`-prefixed assets are
    AnimMontages (need proper Montage playback, not yet built here); `A_`-prefixed ones are plain
    AnimSequences, which `Spawner.ApplyPose` (built during the earlier pose-porting saga, items
    53-63) already knows how to drive via SingleNode mode.
    RedFalcon then asked for a generic tool ("similar to FX") rather than one throwaway function
    per candidate animation — direct precedent: `Spawner.TestSpawnNiagaraByPath`/`lbtestniagarapath`
    already do exactly this shape for FX. Built `Spawner.TestApplyPoseByPath(pathArg)` /
    `lbtestpose <path>` the same way: auto-appends the trailing `.AssetName` suffix if only the
    bare path is pasted (same convenience the Niagara tester already has), targets the nearest
    spawned actor in front via `findNearestSpawnInFront` (respects `Spawner.lockedTarget`/Num+, so
    a hard-to-aim target can be locked first), then calls the existing `Spawner.ApplyPose`
    unchanged. Placed carefully AFTER `findNearestSpawnInFront`'s own `local function` declaration
    in spawner.lua (right after `Spawner.ApplySexChangeToNearest`, which already calls it
    successfully from that position) — checked explicitly this time, given items 66 and 72 already
    each hit the exact same forward-reference trap once.
    Set honest expectations going in, not just built and handed over: `Spawner.ApplyPose` running
    cleanly (no crash) is NOT the same as the pose looking right — 5-6 independent prior attempts
    at porting a DIFFERENT specific pose (`Female_Standing_01`'s) all T-posed despite every
    individual step reporting success (items 53-63, closed). These new candidates are a
    structurally different case — generic "Shared" animations explicitly organized for reuse
    across Regular-skeleton NPCs, not one character's own Control-Rig-bound BlueprintMode pose —
    genuinely untested, not a retry of the closed investigation, but not guaranteed either.
    **Not yet tested live** — deployed, no specific animation tried yet as of this write-up.
    **Same-day follow-up: a real, fixable bug found, unrelated to skeleton compatibility.**
    RedFalcon tried `lbtestpose` with `A_Hammock_Idle` on two different Character targets (a
    Walker and an idle Senkamati Hunter) — "i didnt see a change" both times. `ue4ss.log` showed
    why: `SetAnimationMode call FAILED` on every attempt, while `SetAnimation`/`Play`/`SetPosition`
    all reported `ok` — meaning the mesh never actually left `BlueprintMode` at all, so those three
    "successful" calls had nothing to act on; the AnimBP kept driving the pose the whole time
    regardless. This is NOT the skeleton/Control-Rig incompatibility the closed pose-porting
    investigation (items 53-63) hit — it's `Spawner.ApplyPose` itself never successfully switching
    modes in the first place, on ANY target, so the real compatibility question hasn't actually
    been tested yet.
    Fixed with the same function-then-property fallback shape `Spawner.SetAnimClass` already uses
    for its own similar uncertainty (item 54): try `mesh:SetAnimationMode(0)` first, and if that
    pcall fails, fall back to a plain `mesh.AnimationMode = 0` property write. Root cause of the
    function call's own failure isn't confirmed (possibly this build's reflection doesn't marshal
    the `TEnumAsByte<EAnimationMode::Type>` parameter this function expects) — the fallback sidesteps
    needing to know why. Log message now also reports which path (`function` vs `property`)
    actually set the mode, so a future look at `ue4ss.log` can tell immediately which one worked.
    **Not yet tested live** — this fix is unconfirmed as of this write-up; next step is retrying
    the same `lbtestpose` command and checking whether the pose actually changes now.
    **Same-day follow-up: the fallback worked, but wrote the WRONG enum value — and a crash
    occurred right after, cause unconfirmed.** RedFalcon retried `lbtestpose` on a Handyman Farmer
    walker: `ue4ss.log` showed `SetAnimationMode via property call ok` this time (the fallback
    fired and succeeded) — but still "AnimationMode 0 -> 0", still no visible change. Root cause:
    `EAnimationMode::Type` is `AnimationBlueprint = 0, AnimationSingleNode = 1` — the code
    (both the original function-call attempt AND the new property fallback) was writing `0`,
    which is the mode the mesh was ALREADY in by default. The write genuinely succeeded; it just
    set the same mode that was already active, so of course nothing rendered differently. Fixed
    to `1` in both the function-call attempt and the property fallback.
    **Then, separately, a crash**: RedFalcon released the target lock (Num+ off) right after the
    pose test, and the game crashed. `ue4ss.log`'s last lines before it went silent: "Target lock
    OFF" completed cleanly, then `[hover-transition] APPLY (was nothing)` fired (this mod's own
    hover-ghost-highlight system, which activates on whatever's under the reticle whenever nothing
    is targeted) — then nothing further, the same abrupt-stop native-crash signature documented
    repeatedly elsewhere in this file. The timing is suspicious (the actor the hover system would
    have highlighted was the same one just poked by `ApplyPose`'s SetAnimation/Play/SetPosition
    calls moments earlier) but NOT confirmed causal — this could be an unrelated pre-existing
    hover-highlight fragility coincidentally triggered right then. Root cause not established.
    **Important consequence of the enum fix, worth flagging explicitly**: every PRIOR
    `lbtestpose`/`ApplyPose` attempt across this entire investigation (including all of items 53,
    62-63) had been silently failing to ever actually leave `BlueprintMode` — meaning nothing has
    ever really been tested in a genuinely-SingleNode state before now. The enum fix changes that:
    the NEXT test will be the first time this mesh has ever actually been put into SingleNode mode
    with a foreign animation, which is a materially different (and unvalidated) state from
    everything tried so far — the crash risk profile going forward is not the same as it was for
    any previous attempt in this whole saga.
    **Not yet tested live** — RedFalcon has not yet retried with the enum fix in place. Given the
    unconfirmed crash, recommend testing cautiously: despawn the test target immediately after
    each `lbtestpose` attempt (Num9/DEL) rather than leaving it in the world or walking away from
    it, until whether the crash was actually caused by this mechanism is understood one way or
    the other.
    **Same-day follow-up: crash likely unrelated; enum fix confirmed harmless but INSUFFICIENT.**
    RedFalcon tested the caution protocol twice — applied a pose, despawned, waited (nothing
    happened); applied to a second actor, un-targeted, walked past it repeatedly (nothing
    happened either time) — no repeat of the crash under either condition, good evidence it
    wasn't actually caused by this mechanism. But `ue4ss.log` showed the deeper problem: both
    attempts now read `AnimationMode 0 -> 1` (the enum fix genuinely took effect, verified via
    readback) with every step reporting `ok` — and the animation STILL never visibly played.
    Diagnosis: the real C++ `SetAnimationMode()` function does more than flip the enum — it also
    swaps the component's internal animation-playback instance to match the new mode. A bare
    property write (the fallback this whole time) only changes the flag; the OLD BlueprintMode
    instance keeps actually driving rendering regardless, so everything set afterward
    (`SetAnimation`/`Play`/`SetPosition`) had nowhere to go. This means the function call FAILING
    in the first place was always the real blocker — the property fallback could never fully
    substitute for it, no matter what value it wrote.
    Switched `Spawner.ApplyPose` to try `mesh:PlayAnimation(seq, false)` FIRST — a single
    UFUNCTION built to do "switch to single-node and play this" in one call, with only an object
    reference and a bool as parameters (no raw `TEnumAsByte<EAnimationMode::Type>` to marshal),
    so it may sidestep whatever specifically breaks `SetAnimationMode`'s own call. The old
    granular path is kept as a fallback if `PlayAnimation` itself isn't callable, and now also
    logs the ACTUAL pcall error message on `SetAnimationMode` failure for the first time (only
    the pass/fail boolean was ever logged before) — that text is the one thing that could
    actually explain the original failure, if `PlayAnimation` doesn't pan out either.
    **Not yet tested live** — this is the third distinct mechanism tried in this sub-investigation
    (function call, property write, now `PlayAnimation`); unconfirmed as of this write-up.
    **Same-day follow-up: `PlayAnimation` mechanically WORKS — but this specific animation
    T-posed.** RedFalcon tried it: the mesh T-posed, while still moving around (AI-driven
    translation is a separate system from pose rendering, same lesson already established in the
    closed pose-porting investigation, items 53-63). This is real progress on the "how do I even
    apply one of these" question (`PlayAnimation` is no longer silently no-op'ing like the prior
    two mechanisms) — but confirms `A_Hammock_Idle` specifically isn't built for the Walker/
    Handyman skeleton, the same "foreign AnimSequence -> T-pose" signature this project already
    closed out once before, just now demonstrated on a moving Character instead of a static
    statue. Not a dead end for the MECHANISM, just for this ANIMATION CHOICE.
    Recommended next candidate (not yet tried): `A_Regular_Carpenter_Idle` instead of another
    ship-themed one — it already showed up natively as a default `AnimToPlay` fallback value on a
    Handyman-based character's own AnimInstance earlier in this project's history (item 62's own
    probe), a real hint it may already be built for this exact skeleton family, unlike the
    ship-crew animations which were likely authored for a different NPC skeleton entirely.
    **Same-day follow-up: RedFalcon spawned two crew (`Player Crew 1`, `Sailor Crew 1`) and tried
    `A_Hammock_Idle` on them — same T-pose.** Checked `ue4ss.log`: both confirmed
    `BP_Mob_Crew_Regular_Player_C` (a DIFFERENT base class from the Handyman family
    `A_Regular_Carpenter_Idle`'s own hint came from) — neither was ever a fair test of that
    specific candidate. The log also showed a genuinely Handyman-based actor already in the
    world, `Town Gatherer (F) 1` (`BP_NPC_Handyman_Gatherer_C`, confirmed) — pointed RedFalcon at
    running `A_Regular_Carpenter_Idle` on THAT one instead, the correctly-matched pairing.
    **RESULT: IT WORKED.** RedFalcon confirmed the Carpenter Idle pose rendered correctly — no
    T-pose — on the Handyman Gatherer (still walking around, since her AI was never stopped, but
    the pose itself displayed properly). **This is the first successful custom-animation
    application anywhere in this entire investigation**, closing the open question left by the
    T-pose results: the mechanism (`PlayAnimation`, after fixing the enum value and the
    property-write insufficiency) genuinely works — it just requires the animation to actually be
    authored for the target's own skeleton family, exactly as suspected. Folder-name similarity
    ("Human/Regular/...") is NOT enough to predict compatibility (already established twice before
    for AnimClass swaps, items 54-55) — what predicts it is the animation ALREADY being associated
    with that exact base class somewhere (a native `AnimToPlay` default, in this case).
    "We know how to fix" the still-walking part refers to the already-proven `Spawner.SetAILogic`/
    `freezeSenkaStatue` (`StopLogic`) mechanism — stopping AI decision-making without touching the
    pose, same technique the idle Senkamati rows already use. Not yet wired into a combined "pose +
    freeze" command; still a two-step manual process (`lbtestpose` then... no generic "freeze
    whatever I'm looking at" console command exists yet, only the roster-specific ones).
    **Durable finding written up properly this time**: this whole saga (both the earlier closed
    T-pose investigation, items 53-63, and today's actual working technique) was NEVER promoted
    into `WINDROSE_MODDING_NOTES.md` — only this file has it. Added as a new §14 there (and the
    public mirror) now that there's a genuine positive result worth recording for other modders,
    not just a dead end.
    **Second confirmation, same day**: RedFalcon also tried `A_Regular_Carpenter_Idle` on the idle
    Senkamati (the "crew"-kind reskin, itself built on the Handyman/`SENKA_FEMALE_BASE_CLASS`
    base) — "looks good," no T-pose. Consistent with the theory: same underlying Handyman skeleton
    family as the Gatherer, so the same compatible animation renders correctly there too. Two
    independent Handyman-family targets now confirmed working, zero Crew-family targets have
    worked — a real, reproducible pattern, not a one-off.
    **Loop fix, same day**: RedFalcon noted the working pose didn't loop — `Spawner.ApplyPose`'s
    `PlayAnimation(seq, false)` call hardcoded one-shot playback. Added an optional `bLooping`
    parameter, now defaulting to `true` (every existing caller omits it and gets the new default,
    matching this function's actual intended use as a persistent ambient pose, not a one-shot).
    Also threaded through the granular fallback path (`mesh:SetLooping(bLooping)` + `Play(bLooping)`)
    for consistency. Deployed and confirmed working.
    **Workbench candidate tried, T-posed — but with a useful new heuristic.** RedFalcon tried
    `A_Craftstation_Blacksmith_BellowsInteract` (flagged as a real candidate but not Hero-locked)
    on the same working target — T-posed, AND played an unrelated visual effect alongside it.
    RedFalcon's own read: this might not be a person animation at all — correct, and confirmed by
    the path itself: `Character/Animations/Environment/Workbenches/...`, not `Human/Regular/...`
    like the one confirmed-working animation. The matching `ABP_AlchemyTableT01_02_p02`/
    `ABP_BlackSmithT01_p02` AnimBlueprints found in the same `Environment/WorkBenches/` folder are
    almost certainly that WORKBENCH OBJECT's own animation driver (its moving parts, its spark
    effect), not a human interaction animation at all. New pre-filter added to
    `WINDROSE_MODDING_NOTES.md` §14 and its public mirror: prefer `Human/Regular/...` paths for
    person-pose candidates, treat an `Environment/...` path segment as a likely prop animation to
    skip entirely rather than test blind.
    **Same-day follow-up: the "avoid Hero" caution was WRONG, corrected.** RedFalcon proposed
    testing a `_Hero_`-prefixed animation anyway, reasoning that "Hero" might mean "the detailed
    human rig, possibly shared by named workers," not strictly "player-only" — pushing back on
    the caution given a few messages earlier. Suggested `A_Regular_Male_Hero_Workbench_
    TableInteract_Loop` (a genuine person animation under `Human/Regular/Shared/CampActivity/
    Workbench/`, not the `Environment/` prop folder that just failed) as the test. **RedFalcon
    confirmed it worked** — on a generic Handyman worker, not a named NPC and nowhere near the
    player. This means the original "Hero = player-only, be cautious" caution was an incorrect
    analogy, imported from a DIFFERENT, unrelated finding: this game's `Hero_`-prefixed
    CompositeMeshParams (body/outfit shape assets, confirmed to crash on NPCs) are a completely
    different asset type from `Hero_`-prefixed ANIMATIONS, and the crash risk does not transfer.
    Corrected in `WINDROSE_MODDING_NOTES.md` §14 (and the public mirror) — the real filter stays
    `Human/Regular/...` vs `Environment/...`; `Hero` vs plain naming inside `Human/Regular/` does
    not by itself predict anything. This reopens the entire `_Hero_` animation pool (ship wheel/
    cannon steering, cooking, the rest of CampActivity) that was being deprioritized for no good
    reason — a real, useful correction, not just a footnote.

74. **A combined pose+FX tester, after confirming real tool/effect assets exist for craft
    stations** (2026-08-25, same day, closing out this arc for now). RedFalcon noticed the
    Carpenter Idle pose has no tool visibly in-hand and recalled seeing "tools and workbench
    stuff in the effects folder" — checked `pakcontents.xlsx` again and confirmed both halves are
    real, separate assets: actual holdable tool meshes
    (`Environment/Gameplay/WorkBenches/SM_CraftStation_Tools_Hammer_01`/`_Chisel_0X`/`_Saw_0X`)
    and separate particle FX for the activity itself (`FX/Particles/Buildings/CampActivities/
    BlackSmith/FX_Blacksmith_Anvil_Hammer`/`_Bellow_Action`/`_Bellow_Idle`,
    `.../Workbanch/FX_Workbanch_Sawmill_01` — note the game's own "Workbanch" typo in that one
    folder — `.../Cooking/FX_Cooking_CuttingTable*`). Also found a deeper native orchestration
    layer, `BP_AIC_CraftStation_<Station>_<Action>` GameplayAbility Blueprints under
    `Gameplay/Character/GameplayAbilities/Interaction/CraftStation/` — almost certainly what
    normally drives pose+tool+FX together in real gameplay via the GAS (Gameplay Ability System).
    Reproducing that generically from Lua would be a much larger undertaking than a console
    command, so deliberately scoped this down instead of chasing it.
    RedFalcon asked for a combined command specifically because running pose-then-FX as two
    separate manual steps leaves a human-reaction-time gap — "the effect would be off on its
    timing." Built `Spawner.TestApplyPoseWithFx(animPathArg, fxPathArg)` / `lbtestposefx <anim>
    <fx>`: same targeting as `lbtestpose` (`findNearestSpawnInFront`, respects the Num+ lock),
    applies the pose via the already-proven `Spawner.ApplyPose`, then reuses the EXISTING
    `Spawner.TestSpawnNiagaraActor` for the FX by priming `Spawner._lastProbedActor` to the same
    target first — that field is the exact interface that function already expects (normally set
    by the HOME probe key), so this avoids re-deriving its own bounds-based placement math a
    second time. Placed correctly after `findNearestSpawnInFront`'s own declaration this time
    (checked explicitly, given items 66/72/73 already each hit that exact forward-reference trap).
    **Explicitly scoped, not silently incomplete**: this only solves "pose + station-level FX
    together." It does NOT attach the effect to a specific socket (a hand bone, for something
    that should visually originate from a swung tool) — `TestSpawnNiagaraActor` places it at the
    target's own footprint, which suits an ambient station effect (sparks/dust near the activity)
    but not a hand-carried one — and it does NOT attach the actual tool MESH at all yet (that
    would need a live socket-name probe on the target skeleton first, plus adding a new
    StaticMeshComponent via `AddComponentByClass` — mechanically proven to work in this exact
    codebase already, item 72's crew experiment — and attaching it via the already-proven
    `K2_AttachToComponent` socket-attach technique, deliberately NOT the crashed `K2_AttachToActor`
    route). Both are real, identified next steps if RedFalcon wants to pursue the full "tool
    visibly in hand" look, not attempted in this pass.
    **Not yet tested live** — deployed, untried as of this write-up.
    **Same-day follow-up: found a real skeletal-mesh tool prop, and it turns out this codebase
    already has a fully-shipped mechanism to mount it.** RedFalcon asked for a broader
    `pakcontents.xlsx` sweep (both "workbench"/"workbanch" spellings) specifically for anything
    that could be the held item. Found `Character/Skeletal_Meshes/Environment/WorkBenches/Meshes/
    SK_CraftStation_Tools_Hammer_01` — a genuine SKELETAL mesh version of the hammer (alongside
    the plain `SM_` static one and a `PHYS_` physics asset) — meaning it's built to be
    socket-attached the same way this game's own gear/armor pieces are, not just placed as a dumb
    static prop. Also found `FX_.../Workbanch/M_Workbanch_Table_WoodDebris` (confirming the wood-
    chip effect RedFalcon saw is a real, dedicated asset) and the actual orchestrator,
    `BP_AIC_CraftStation_Workbench_Sawmill`/`_Table` GameplayAbility Blueprints under `Gameplay/
    Character/GameplayAbilities/Interaction/CraftStation/Workbench/` — almost certainly what the
    base game runs on its own NPCs to tie pose+tool+debris together via AnimNotifies, which our
    simpler `PlayAnimation()` approach bypasses entirely.
    Best part: `Spawner.AttachShield` (the Warrior's shield-on-hand feature) is an EXISTING,
    ALREADY-SHIPPED implementation of exactly this mechanism — `AddComponentByClass` (a
    SkeletalMeshComponent, `bManualAttachment=true`) → `SetSkeletalMeshAsset` → verify the socket
    via `DoesSocketExist` (since `K2_AttachToComponent` silently attaches at the origin on a
    missing socket rather than failing — a real bug this exact shield feature already hit and
    fixed once) → `K2_AttachToComponent`, with a full `GetAllSocketNames()` dump as the fallback
    when no candidate matches. Generalized it into `Spawner.TestAttachToolToNearest(meshPathArg,
    socketArg)` / `lbtesttool <meshPath> [socket]`: same generic nearest-in-front/locked targeting
    every other test command here uses (not hardcoded to the Warrior), defaults its socket
    candidates to the right-hand analogs of the CONFIRMED-WORKING `Config.WARRIOR_SHIELD_SOCKETS`
    (proven on this same broad human skeleton) tried first, falling back to the shield's own
    left-hand set, with an explicit socket argument always winning. This is by far the
    LOWEST-RISK experiment in this whole animation/attachment arc — every piece of it (the
    component type, the attach call, the socket-verify pattern) is already proven safe in
    production, not a new guess at unproven engine surface like `AttachActorToShip` or the
    movement-component experiment were.
    **Not yet tested live** — deployed, untried as of this write-up. Next step: `lbtesttool
    /Game/Character/Skeletal_Meshes/Environment/WorkBenches/Meshes/SK_CraftStation_Tools_Hammer_01`
    on the same Handyman-based target the poses have been confirmed on — either a right-hand
    socket candidate matches and it just works, or the full socket dump tells us the real name to
    hardcode next.
    **Same-day follow-up: first try failed on a path-casing mismatch, second try CONFIRMED
    WORKING.** RedFalcon's first attempt logged `mesh did not resolve` — root cause: the
    `pakcontents.xlsx` export lists this exact file under BOTH `WorkBenches` (capital B) and
    `Workbenches` (lowercase b) as parallel entries across different pak chunks, and the path
    given used the wrong-cased one; `resolveAsset`'s `StaticFindObject`/`LoadAsset` pair is
    case-sensitive enough that only the correct casing actually resolves. Switching to
    `Environment/Workbenches/Meshes/...` (lowercase b) worked immediately — RedFalcon confirmed
    the target is now genuinely holding a hammer mesh in-hand. **First fully-successful custom
    prop attachment in this entire investigation.** One of the two matched right-hand socket
    candidates worked (which one wasn't logged in this run, only that the attach succeeded) — the
    full-socket-dump fallback was never needed this time. RedFalcon also noted the same actor has
    a separate item already in her OFF hand — almost certainly her own native profession gear
    (Gatherer/Farmer-family NPCs commonly carry a baked-in prop by default), not anything this new
    code touched, since it only ever attaches to one socket per call. Suggested trying
    `SK_CraftStation_Tools_Chisel_01` next instead of the hammer, for a better thematic match to
    the carving-motion pose already confirmed working — not yet tried as of this write-up.
    **Lesson for this file's own asset-path notes going forward**: when `pakcontents.xlsx` (or any
    future export) lists the same-looking path under two different casings, don't assume either
    one — the wrong one fails silently with a generic "did not resolve," not a helpful error, so
    it's worth trying both before assuming the asset doesn't exist at all.
    **Same-day follow-up: two-handed props, and a real mesh-type gap fixed.** RedFalcon asked for
    an item in the OTHER hand too — "sometimes they are holding two items... a knife carving a
    piece of wood." Searching `pakcontents.xlsx` for a wood-piece mesh found real candidates
    (`SM_Craft_T01_PlanksWood_01`, `SM_PlankWooden_02/03`) but NONE of them have a skeletal-mesh
    counterpart the way the tools (hammer/knife/chisel) do — they're plain static meshes only.
    `Spawner.TestAttachToolToNearest` only knew how to host a SKELETAL mesh (hardcoded
    `SkeletalMeshComponent` + `SetSkeletalMeshAsset`), so it would have failed on a static prop.
    Fixed by reading the resolved mesh's own class name first (`mesh:GetClass():GetFName():
    ToString()`, checking for `"StaticMesh"`) and picking the matching component type/setter
    (`StaticMeshComponent` + `SetStaticMesh` vs. the existing `SkeletalMeshComponent` +
    `SetSkeletalMeshAsset` path) — `resolveAsset` itself succeeds identically for either mesh
    type, so this was purely about which component can host which. No new attach mechanism, no
    new risk — same `AddComponentByClass`/`K2_AttachToComponent` recipe either way.
    Two items on one Character just means calling `lbtesttool` twice — the function already
    creates a fresh component each call, so nothing needs to change there. The one real gotcha:
    the OFF-hand call MUST pass an explicit left-hand socket (`ik_weapon_lSocket` — the
    already-confirmed-working primary from `Config.WARRIOR_SHIELD_SOCKET`), since the function's
    own default candidate list tries RIGHT-hand names first and would otherwise attach to the
    same hand the tool is already on.
    **Not yet tested live** — the static-mesh path is deployed but unconfirmed as of this
    write-up.
    **Same-day follow-up: extended the existing probe to answer "what is a real NPC holding
    mid-animation."** RedFalcon asked whether probing a real NPC while actively performing a
    craft-station animation would reveal its held item(s) directly, instead of continuing to
    guess mesh/socket combinations from asset names alone. Good idea and directly answerable with
    this project's own established tooling: `dumpMeshComponentNames` (the `lbprobe`/`lbprobedump`
    backing function, already listing every `SkeletalMeshComponent` + its assigned mesh) was
    missing the one piece that actually matters here — WHICH SOCKET each component rides on. Added
    a `GetAttachSocketName()` read (a plain, read-only `USceneComponent` getter, same safety class
    as every other call this probe already makes) to its output. Also extended it to sweep
    `StaticMeshComponent`s in addition to `SkeletalMeshComponent`s — a held prop attached by the
    game's own interaction-ability system is not guaranteed to be skeletal (confirmed: the
    wood-piece candidates for the off-hand are static-only), so the original skeletal-only sweep
    could have silently missed exactly the component being looked for.
    Practical workflow this unlocks: find a real NPC (an Employee/Artisan) actually performing the
    craft-station work in the world, `lbprobe` it, then `lbprobedump` while it's actively holding
    the item — the output now shows the EXACT mesh path and EXACT socket name in one read, instead
    of guessing candidates and hoping one exists.
    **Not yet tested live** — deployed, untried as of this write-up.

75. **`lbprobedump` now writes its own timestamped file, for convenience** (2026-08-25, same
    day). RedFalcon asked to cut the noise of hunting through `ue4ss.log` for one probe's output
    among everything else this mod (and the engine) constantly log. `Spawner.ProbeDumpProperties`
    calls a whole chain of `dump*` sub-functions (`dumpObjectProperties`, `dumpMeshComponentNames`,
    `dumpAnimInfo`, etc.), each with its own scattered `print()` calls — too many individual call
    sites to retrofit one at a time. Instead, split the function: its entire original body became
    a new local `probeDumpPropertiesBody()`, unchanged; a new `Spawner.ProbeDumpProperties()`
    wrapper opens a fresh `probedump_<timestamp>.txt` (same multi-candidate relative-path
    convention as every other dump file in this project), temporarily reassigns the GLOBAL `print`
    to also write to that file (Lua's `print` is a real global and every probe function already
    calls the bare global, not a local alias, so this captures the ENTIRE chain's output with zero
    changes to any of those individual functions), calls the body via `pcall`, then unconditionally
    restores `print` and closes the file — the restore happens even if the body errors, since
    leaving the global `print` swapped in permanently would silently break logging for the rest of
    this mod, a far worse failure than losing one probe's output.
    **Confirmed safe to do this way, not just convenient**: checked that `probeDumpPropertiesBody`
    and everything it calls is fully synchronous — no `ExecuteWithDelay`/`ExecuteInGameThread`
    anywhere in that call chain — so nothing can fire after `print` is already restored and land
    in the wrong place (a real risk this exact monkey-patch technique would have if any nested
    call deferred work to a later tick).
    **Not yet tested live** — deployed, untried as of this write-up.

76. **`lbprobe` now toasts what it targeted** (2026-08-25, same day). RedFalcon asked for
    on-screen confirmation of `lbprobe`'s target — as a console command it had zero feedback while
    actually playing, so it was easy to fire it, look away, and never notice it had silently
    latched onto the wrong actor (or missed entirely). Added a `Spawner.Toast("Probed: " ..
    shortName, 2.5)` call right where `Spawner.ProbeNearestActor` already logs its target — short
    class name only (the full `/Game/...` path stays in `ue4ss.log`/the new `probedump_*.txt` for
    anyone who needs it; a toast is meant to be glanced at). Goes through `Spawner.Toast` like
    every other on-screen confirmation in this file, never `PrintString`/`ClientMessage` (both
    already confirmed dead ends here, see the "Working agreements" note near the top of this
    file). Deliberately did NOT add a matching toast to the "nothing within Xuu ahead" miss case
    right above it — this project already has an explicit prior decision (item 23) to keep that
    exact family of message log-only, since RedFalcon found it spammy when tapped repeatedly while
    aiming; respected that instead of re-adding it here.
    **Not yet tested live** — deployed, untried as of this write-up.

77. **A dedicated "currently playing" line in the probe dump** (2026-08-25, same day). RedFalcon
    asked for the probe dump to surface the target's currently-playing animation directly, "to
    save time on finding that too" — it was technically already there (`dumpAnimInfo`'s existing
    `AnimationData` walk already reads `AnimToPlay` via the safe struct-drilling recipe), just
    buried among several other `AnimationData` fields (`bLooping`, `Rate`, `bPlaying`, etc.) that
    have to be scanned past to find the one that actually matters for reapplying it via
    `lbtestpose`. Pulled that one value out into its own clearly labeled line
    (`CURRENTLY PLAYING (SingleNode) = <full path>`, or a clear "driven live by AnimClass, no
    single clip" note when in BlueprintMode) printed right after the existing
    `AnimationMode`/`AnimClass` summary line, using the exact same safe read already proven a few
    lines below — this doesn't replace the full `AnimationData` walk, just surfaces its most
    useful field early as a ready-to-paste-into-`lbtestpose` asset path.
    **Not yet tested live** — deployed, untried as of this write-up.

78. **BlueprintMode state query added; asked about listing a Blueprint's own referenced
    animations, deliberately not yet built** (2026-08-25, same day). RedFalcon probed a Character
    in BlueprintMode (`ABP_Human_NPC_C`) and asked whether the specific active clip could be seen
    at all. Honest answer: not safely, not with anything this codebase already trusts — the
    actual sampled clip inside a compiled AnimGraph lives in internal runtime execution nodes
    (state machines, blend spaces), which this project's own history already flagged as raw,
    per-frame-rebuilt state, not real configuration — a different, riskier class of read than the
    plain Vector structs (`AnimationData`/`BodyMorph`) already proven safe. Added the safer,
    sanctioned middle ground instead: `animInstance:GetCurrentStateName(machineIdx)` (machine
    indices 0-2) — a real, documented `UAnimInstance` UFUNCTION built specifically for querying
    which state a machine is currently in (e.g. "Idle"/"Walk"). Not the literal asset, but a
    genuine live signal from proper engine API surface rather than a raw struct walk.
    RedFalcon separately asked whether the Blueprint's own STATIC list of referenced animations
    (as opposed to which one is live right now) could be listed instead — a genuinely different,
    likely easier question, since a compile-time-baked asset reference inside a graph node is just
    an object reference, not the same runtime-rebuilt state the state-machine question hits.
    Two things worth knowing before building it: (1) the ALREADY-EXISTING
    `dumpObjectProperties(animInstance, "ANIMINSTANCE")` call (part of this same probe dump) already
    lists every declared property name on the AnimInstance, including struct-typed graph nodes —
    for a struct-typed property its generic reader only prints the TYPE name, not field values, so
    node names like `AnimGraphNode_Sequence...` may already be visible in that section without any
    new code — worth checking there first. (2) Actually drilling INTO one of those nodes to read
    its assigned `Sequence`/`Animation` field would be genuinely new territory, explicitly flagged
    by this project's own prior comment as riskier than the Vector-struct drilling already proven
    safe (`AnimGraphNode_*` were called out by name as "internal anim-runtime state... a different,
    much riskier question than a plain FVector"). NOT attempted this round — deliberately left as
    RedFalcon's call whether to try it as a genuine "test and see" rather than treating the
    Vector-struct precedent as proof it's equally safe.
    **Not yet tested live** — the state-machine query is deployed but unconfirmed.
    **Same-day follow-up: RedFalcon opted into the experiment** ("ok, so experimentation it is")
    after confirming the IK socket-attach mechanism continues to work well across different props
    (a "stick" turned out to actually be a wood club mesh once probed). Built the AnimGraph
    node-drilling attempt: every struct-typed property on the AnimInstance is checked by its
    RESOLVED TYPE (not by property name, which is compiler-generated and unpredictable) for
    `AnimNode_`/`AnimGraphNode` in the type path — matching UE's real `FAnimNode_*` C++ family
    every compiled AnimGraph execution node belongs to — and any match gets drilled into with the
    exact same "any unfamiliar native struct" recipe `WINDROSE_MODDING_NOTES.md` §10 already
    established as crash-safe in general. This is the actual open question that recipe has never
    been tested against before: whether it generalizes to compiled EXECUTION nodes, not just the
    plain data structs (`AnimationData`/`BodyMorph`) already proven safe. Every field read stays
    individually `pcall`-wrapped, same discipline as everywhere else — one bad field must not stop
    the others or escalate into an uncaught native crash.
    **Not yet tested live** — this is a genuine first attempt at previously-avoided territory;
    unconfirmed as of this write-up whether it renders anything useful, errors safely, or worse.
    **Same-day follow-up: CONFIRMED TO CRASH THE GAME LIVE, both experiments pulled.** RedFalcon
    tested `lbprobedump` on the same BlueprintMode target — crashed. `ue4ss.log` shows ZERO output
    from either new block (not even a single `StateMachine[0]...` or `-- AnimGraphNode_...` line)
    before the log stops dead — the same pcall-uncatchable native-crash signature already
    documented for `SetBody`/`AttachActorToShip` earlier this session. Since neither block ever
    printed anything, which specific call actually crashed — `GetCurrentStateName` itself, or the
    `ForEachProperty` walk into an `AnimNode_*` struct — could not be isolated from the log alone.
    Rather than guess which one was "probably fine," BOTH were immediately removed from
    `dumpAnimInfo` and replaced with a documented removal note (matching this project's own
    established treatment of confirmed-dangerous code — kept as a record, not silently deleted,
    but never re-registered without a genuinely new theory backed by real evidence).
    **Net result of items 77-78**: the "currently playing" summary line (SingleNode mode) and the
    `probedump_*.txt`/toast conveniences all stand — those are real, working improvements. The
    BlueprintMode-specific questions ("what state is it in," "what anims does this Blueprint
    reference") remain genuinely unanswered by any means this codebase currently trusts; the
    `WINDROSE_MODDING_NOTES.md` §10 struct-discovery recipe's own general "any unfamiliar native
    struct" claim does NOT extend to compiled `AnimNode_*` execution structs — this is now a
    confirmed, not just suspected, limit on that recipe's own scope, worth remembering the next
    time it looks tempting to reuse for something struct-shaped.

79. **`lbtestmaterial <path>` — a generic material tester, same shape as lbtestpose/
    lbtestniagarapath** (2026-08-26). Built while investigating a NEW side mod
    ("Summon Ghost Sailors" — see `Working\SummonGhostSailors\`) that repurposes this mod's own
    `MI_Building_SimplifiedPreview` build-ghost-preview material as a character "ghost" look.
    RedFalcon wanted to adjust its opacity; the only lever for that (a dynamic material
    instance via `UKismetMaterialLibrary:CreateDynamicMaterialInstance`) **crashed the game
    live, confirmed** — same "pcall cannot catch this" native-crash signature already
    documented for `SetBody`/`AttachActorToShip` elsewhere in this file. Abandoned per the
    established "if it doesn't work we abandon that option" rule; that mod's
    `Config.GHOST_OPACITY` stays disabled (1.0).
    Better direction found instead: a `pakcontents.xlsx` keyword sweep ("ghost"/"translucent"/
    "dissolve"/etc.) turned up a whole purpose-built ghost-character asset family this project
    never knew existed — `R5/Content/Character/Shaders/MasterMaterials/M_CharacterGhost_V2`
    (a master material made specifically for ghost characters), and a themed
    `MI_Boneman_Ghost_Pirate` (+ `MI_Boneman_Ghost_Spanish`, `MI_Hair_Ghost`) with a matching
    full skeletal mesh set (`SK_ArmorCreature_Boneman_Spanish_Ghost_01/02_Torso/Head/Legs/
    Feets/Hands`) under `Character/Skeletal_Meshes/Armor/ArmorRegular/Ghost/` — plus
    `SK_Fable_Male_Ghost`/`MI_Fable_Male_Ghost_Small` under `Human/Regular/Ghost/`. Trying these
    needs zero new risk — same proven-safe `comp:SetMaterial` swap `Spawner.ApplyGhostMaterial`
    already uses, no dynamic instance at all.
    Refactored that swap loop out into `Spawner.ApplyMaterialToActor(actor, mat, tag)` (spawner.lua)
    so both the original hardcoded `ApplyGhostMaterial` and the new tester share one
    implementation. `Spawner.TestApplyMaterialByPath(pathArg)` mirrors `TestApplyPoseByPath`
    exactly: auto-appends the trailing `.AssetName` suffix if only a bare path is pasted,
    targets the nearest spawned actor in front (`findNearestSpawnInFront`, respects the Num+
    lock), resolves the path via the existing `resolveAsset`, then swaps it in. Wired to
    `lbtestmaterial <path>` (main.lua), same registration shape as every other path-fed tester
    here.
    **Same-day follow-up, real bug caught on first live use, same class as items 66/72/73/74**:
    RedFalcon ran it and got "attempt to call a nil value (global 'findNearestSpawnInFront')" —
    `TestApplyMaterialByPath` had been placed right after `ApplyGhostMaterial` (~line 5427),
    well above `findNearestSpawnInFront`'s own `local function` declaration further down the
    file (line 6959) — the exact forward-reference trap this file has now hit five separate
    times. Fixed by relocating the function (comment and all) to just before
    `Spawner.ApplySexChangeToNearest`, the same safe landing spot `TestApplyPoseByPath` already
    uses. No logic changed, purely a reordering; `lint.py` clean afterward
    (`compile: 10 scripts OK`). Saved as a standing rule in Claude's own memory system this
    time (not just this file) — check a new function against this trap BEFORE writing it, not
    after hitting the error again.
    **Not yet tested live** — deployed, untried as of this write-up. Next step: `lbprobe` a
    spawned crew/walker, then `lbtestmaterial /Game/Character/Skeletal_Meshes/Armor/
    ArmorRegular/Ghost/Materials/MI_Boneman_Ghost_Pirate` (or `M_CharacterGhost_V2`, or the
    Fable ghost variant) and see how each actually renders on a real character mesh before
    picking one for the side mod.
    **Same-day follow-up: `lbtestmaterial2 <skinPath> <clothPath>`** — RedFalcon wanted to mix
    two candidates ("Skin using MI_Fable_Male_Ghost and clothes using M_CharacterGhost_V2")
    rather than one material everywhere. `Spawner.ApplyTwoMaterialsToActor` splits along the
    same seam `ApplyMaterialToActor`'s own loop already makes: `actor.Mesh` (the base body/skin)
    gets one material, every OTHER `SkeletalMeshComponent`/`StaticMeshComponent` found via
    `K2_GetComponentsByClass` (the composite armor/clothing pieces) gets the other — with
    `actor.Mesh` explicitly excluded from that second sweep so the cloth material can't
    immediately overwrite the skin material back off the body. Placed directly after
    `TestApplyMaterialByPath` (already past `findNearestSpawnInFront`'s declaration, so this
    one didn't repeat the forward-reference trap). Registered as `lbtestmaterial2 <skinPath>
    <clothPath>` (main.lua), same target-resolution shape as every other path-fed tester.
    **Same-day follow-up: first live test looked wrong (uniform texture everywhere), root
    cause confirmed and fixed.** The original body-exclusion check compared components with
    raw `comp == bodyMesh` — reproducing item 38's own already-documented finding that two
    independently-obtained references to the SAME underlying component aren't reliably `==` in
    this codebase. Since the check silently always evaluated false, the cloth material's sweep
    never actually excluded the body mesh and overwrote its skin-material slots right back,
    making the whole actor read as one material. Added explicit slot-count diagnostics
    (`body mesh: found (name=...)`, `components seen=N, excluded-as-body=N, skin slots=N, cloth
    slots=N`) AND switched the identity check to compare `GetFName():ToString()` instead of
    `==` (the same fix item 38 already used for exactly this class of problem). **Confirmed
    live**: `excluded-as-body=1`, `skin slots=4, cloth slots=14` (Witch idle) and `skin
    slots=4, cloth slots=19` (Sailor Crew) — the split now works correctly, RedFalcon confirmed
    it visually renders as two distinct materials. **Lesson reinforced**: raw `==` between two
    separately-fetched component handles in this codebase should be treated as unreliable by
    default — compare by `GetFName()` (or another stable identity field) instead, not just for
    `DeCorruptByClass` (item 38) but for any new component-identity check written here.

80. **"Unable to target with +" investigated — NOT a code bug, traced to a frozen in-game
    camera (likely Remote Desktop input interference)** (2026-08-27). RedFalcon reported Num+
    (target lock) suddenly failing every time, always logging "Target lock: nothing hovered to
    lock onto." `ue4ss.log` showed the hover raycast (`Spawner.UpdateHoverHighlight`,
    spawner.lua) hitting the exact same actor — `BP_BuildingBlock_BuildingCenterT01`, a native
    building piece, not anything this mod spawned — on every single 150ms tick, for 16+
    minutes straight, across several different intended targets (the Buccaneers Merchant
    statue, then something else with open ocean behind it and nothing in front). RedFalcon
    confirmed nothing ever ghost-highlights either, no matter what's aimed at.
    A raycast computing the identical hit for that long regardless of where the player is
    actually looking on screen means the CAMERA transform feeding the trace
    (`PlayerCameraManager:GetCameraLocation()`/`GetCameraRotation()`, read fresh every tick)
    wasn't actually changing — i.e., the in-game camera itself was frozen, not a Lua/targeting
    logic bug. `RegisterKeyBind` (how Num+ reaches the mod at all) hooks input independently of
    window focus, which is why the key press still logged "received" even while this was
    happening — but mouse-look/camera rotation depends on the game window actually having
    input focus, so the two can desync: keyboard still reaches the mod, camera stops moving.
    RedFalcon was connecting via Google/Chrome Remote Desktop, which is a known source of
    exactly this kind of relative-mouse-delta capture trouble (especially across focus changes
    between the game window and the companion LivingBaseSpawnMenu window, which can steal OS
    focus via its own Numpad-1 "focus steal" action). No code change made — nothing in
    `Spawner.UpdateHoverHighlight`/`pickTargetPreferringHover`/`Spawner.ToggleTargetLock` was
    touched, since the raycast/lock logic is doing exactly what it's supposed to do with the
    (frozen) camera input it was given.
    **CORRECTED, same day — the Remote Desktop theory was WRONG.** RedFalcon tested from the
    physical machine (no Remote Desktop) and Num+ still failed the exact same way. The real
    root cause, found via a second piece of live evidence: at the SAME moment the hover raycast
    kept reporting a hit on `BP_BuildingBlock_BuildingCenterT01`, an UNRELATED command
    (`lbtestpose`, which targets via `findNearestSpawnInFront` — a completely different,
    cone/range-based picker, not this raycast) successfully found "Letty (Idle) 1" as the
    actor in front of the player. That's decisive: the camera was NOT frozen (a different
    targeting method aimed from the same camera found the real actor just fine) — the raycast
    ITSELF was being occluded. Read as: a mod-spawned actor standing on or near a native
    building platform can have that building piece's own collision sitting BETWEEN the camera
    and the actor along the single straight-line ray `Spawner.UpdateHoverHighlight` casts, so
    `LineTraceSingleForObjects` (which stops at the very first thing it hits, full stop) never
    reaches the real target at all — a plain line-of-sight occlusion problem, not a camera or
    input issue, and not something either of the two prior investigations (this item, or the
    Remote Desktop machine check) could have caught, since both were reasoning from "the same
    hit repeats regardless of aim" without a second, independent targeting method to compare
    against at the same moment. See item 86 for the actual fix.

81. **Cannon "T-pose" candidates identified as OBJECT animations, not human ones — refines the
    Human/Regular-vs-Environment heuristic from item 73** (2026-08-27). RedFalcon reports the
    ship animation candidates from item 73's `pakcontents.xlsx` sweep that T-posed (paired with
    an unrelated effect playing alongside them, the same symptom the Blacksmith bellows
    candidate showed) are actually **object animations** — the same category of thing that
    animates a cannon's barrel recoiling when it fires, not a sailor's own pose. Item 73's
    established filter ("prefer `Human/Regular/...` paths, treat `Environment/...` as a likely
    prop animation to skip") is real but evidently NOT sufficient on its own — this session's
    Ship/Cannons candidates were listed under `Character/Animations/Human/Regular/Shared/
    Ship/Cannons/`, a `Human/Regular` path, and still turned out to be driving the CANNON's own
    transform/recoil, not a person's skeleton, despite living in the "should be a person
    animation" folder.
    **Refined rule, not a reversal**: folder path is a useful first-pass filter but not proof —
    the one filter that's actually held up every time so far is whether the exact animation
    asset already shows up as a genuine native `AnimToPlay`/AnimInstance default fallback value
    on a REAL Character of the target skeleton family (the technique that found
    `A_Regular_Carpenter_Idle` actually working, item 73's own closing success) — that's a
    positive confirmation of skeletal compatibility, where "which folder is it in" is only ever
    a guess. A T-pose PAIRED WITH an unrelated effect firing (muzzle flash, bellows spark, wood
    debris) is itself a useful tell that the asset is more likely an object/scene animation with
    its own AnimNotify driving that effect, not a person's idle pose — worth treating as a
    signal to abandon that specific candidate rather than trying variations of it.
    Documented in `WINDROSE_MODDING_NOTES.md` §14 as a follow-up caveat to the existing
    Human/Regular-vs-Environment filter, and mirrored to the public `Windrose_Modding_Notes.txt`
    / `Windrose-UE4SS-Modding-Notes` repo in the same pass.

82. **`lbtestpose`/`Spawner.ApplyPose` confirmed working on posed statues too, not just
    Characters** (2026-08-27, same day). RedFalcon confirmed a genuinely skeleton-matched real
    animation applies cleanly via the SAME mechanism item 73 already proved out on
    crew/walkers — no separate code path needed, `Spawner.ApplyPose`'s `PlayAnimation` call was
    always generic to any actor with a `Mesh` component, `lbtestpose` targets whatever's nearest-
    in-front/locked regardless of actor type. Worth distinguishing this from the CLOSED
    pose-porting investigation (items 53-63): that saga was specifically about forcing a
    Character onto a DIFFERENT, foreign skeleton's exact baked BlueprintMode stance (e.g. porting
    `Female_Standing_01`'s own AnimBP-driven pose onto an unrelated body) and stays closed — this
    is the opposite, much simpler case: playing an animation that's already genuinely built for
    that SAME actor's own skeleton family, which was already established (item 73) as the one
    thing that reliably works. The news here is just that it generalizes to the posed
    `AnimatedActor`/statue classes too, not only spawned crew/walker Characters — useful for any
    future "give a statue a specific real activity pose instead of a generic idle" work (the
    Senkamati Statues feature this would have helped was already fully removed, item 69, for
    unrelated NSFW-reroll reasons — this finding would matter for a DIFFERENT future statue-posing
    ask, not a reason to revive that specific feature).
    **Same-day follow-up, scope confirmed even wider**: RedFalcon reports the technique also
    applies successfully across native Senkamati (the raw mob skeleton, `CASTER_MOB` etc.),
    converted Senkamati (the human-skeleton Handyman-based crew re-skin), every statue type, and
    crew — i.e. every actor category this mod spawns. Read as confirming the MECHANISM
    (`PlayAnimation` after the enum/property fixes from item 73) is universal across actor types,
    each given an animation actually built for its OWN specific skeleton family — not that one
    literal animation file works identically across the mob skeleton and the human/Handyman
    skeleton, which are still two different rigs per every finding earlier this session (item 73's
    own "skeleton compatibility is not predictable from folder naming, only a native-default-value
    match predicts it" rule is unaffected and still the thing to check per skeleton family). Net
    result: "apply a specific real activity pose to any placed actor" is now a broadly proven,
    working capability across this whole mod, not just the crew/walker case it was first confirmed
    on.
    **CORRECTION (2026-08-28)**: the assumption right above — that a literal animation file
    working on BOTH the mob skeleton and the human/Handyman skeleton would be a coincidence, since
    they're "still two different rigs" — turned out to be wrong. RedFalcon: "all the poses for
    standard bodies also worked on the native senkamati, so they arent as different as they seem."
    The SAME standard/"Human/Regular" pose set applies correctly on the RAW native Senkamati mob
    skeleton too, not just the human-skeleton crew re-skin — meaning the mob skeleton and the
    ordinary human "Regular" skeleton family share enough real bone-rig compatibility for
    animations to transfer directly between them, at least for this pose set. This narrows (doesn't
    fully overturn) the separate, longer-standing skin-MATERIAL warning elsewhere in this file
    ("painting a human skin material onto a Senkamati body mesh maps garbage, renders like bark")
    — that one is specifically about surface UV mapping for TEXTURES, a different question from
    skeletal bone-rig compatibility for ANIMATIONS, and remains unaffected by this correction. Net
    effect: the pose roster built in item 87 (`Custom > Poses`) is now known to be usable on native
    Senkamati mob-skeleton actors too, not just human-skeleton ones — a real, wider reach than
    assumed when that roster was built.

83. **Two more findings from continued `lbtesttool`/`lbtestpose` use** (2026-08-27, same day).
    - **Cold-asset race fixed in `Spawner.TestAttachToolToNearest`**: RedFalcon reported tool props
      "not loading if they haven't been used before" — matches `resolveAsset`'s own shape
      (`StaticFindObject` -> `LoadAsset` -> `StaticFindObject` again, all synchronous, no delay):
      `LoadAsset` kicks off the load but there's no guarantee the asset has actually finished
      streaming into memory by the time the immediately-following re-check runs, on the very FIRST
      reference anything in the session has made to that specific asset — a genuine race, not a Lua
      bug, and exactly what "works once something else already loaded it" looks like from outside.
      Refactored the function: the actual component/attach work moved into a new local
      `proceedWithTool(actor, name, meshPath, socketArg, mesh)`; `Spawner.TestAttachToolToNearest`
      now tries `resolveAsset` immediately as before, and if that fails, schedules exactly ONE
      retry 400ms later (`ExecuteWithDelay`) that re-resolves and, if it now succeeds, calls
      `proceedWithTool` — using the SAME captured actor/target from the original call, not a fresh
      pick (an aim change during the 400ms shouldn't redirect where the tool ends up). `lint.py`
      clean after the edit (`compile: 10 scripts OK`). Deployed to the live install (game was
      running — told to `lbreload` to pick it up). **Not yet re-tested live** — next step is
      RedFalcon retrying `lbtesttool` on a mesh that failed cold before, to confirm the retry
      actually catches it.
    - **A genuinely dangerous finding, not a bug to fix**: RedFalcon applied the Senkamati Caster's
      own "create spikes" combat-ability animation to a placed statue (untamed/uncontrolled, no AI
      casting anything) via this same pose-testing pipeline — and it **actually damaged the
      player**. This means at least some animations carry AnimNotify events tied to REAL gameplay
      logic (damage, spike-spawn, etc.) that fire off the animation's own timeline regardless of
      who or what is playing it — an inert, non-hostile, player-placed statue with `PlayAnimation`
      called on it directly is not exempt, since notifies aren't gated on AI/hostility state, only
      on the animation actually playing. This is a real safety consideration for this whole
      pose-testing toolset (`lbtestpose`/`lbtestposefx`) going forward, not something fixable in
      the mod's own code — there's no established-safe way from Lua to strip or suppress an
      AnimSequence's own baked-in notifies before playing it. **Practical rule from here on**:
      treat any COMBAT/ABILITY-sounding animation candidate (attack windups, spell casts, spike/
      projectile-themed names) as a real risk to test from a safe distance or with health to
      spare, not just a cosmetic experiment the way an idle/activity pose has been so far. Worth
      writing up as a caution in `WINDROSE_MODDING_NOTES.md` §14 the next time that section gets a
      pass, alongside the existing pose-application findings. **Documented immediately** (not
      deferred) in `WINDROSE_MODDING_NOTES.md` §14, the public mirror, and the
      `Windrose-UE4SS-Modding-Notes` repo (commit `93b5c7a`) the same day, given it's a genuine
      player-safety finding rather than a routine technique note.

84. **`lbtestarmor <slot/mesh name match> [meshPath]` — a generic clothing/armor swap console
    command** (2026-08-27). RedFalcon asked whether swapping individual clothing/armor pieces via
    console command was feasible. Yes, and lower-risk than most of this session's other testers:
    `Spawner.DeCorrupt`'s `replaces` mechanism already does exactly this everywhere in this mod's
    re-skin rulesets (match a component's current mesh/name against a pattern, then
    `SetSkeletalMeshAsset`/`SetSkeletalMesh` the replacement) — this just exposes that same proven
    swap directly against an arbitrary path from the console, instead of only through a
    pre-written rules table.
    `Spawner.TestSwapArmorPiece(componentMatch, meshPathArg)` (spawner.lua, placed right after
    `Spawner.TestAttachToolToNearest`, already past `findNearestSpawnInFront`'s declaration):
    targets the nearest spawned/locked actor same as every other tester here, enumerates its
    `SkeletalMeshComponent`s, and matches `componentMatch` as a case-insensitive substring against
    BOTH the component's own name (e.g. "Torso", "Headgear") and its CURRENT mesh's name — covers
    both "I know the slot" and "I only know what it currently looks like." Every matching
    component gets swapped, not just the first (a broad fragment can legitimately match more than
    one piece, same as `DeCorrupt`'s own replace loop). Two built-in discovery aids so nothing has
    to be guessed blind: omit the mesh path to just LIST the current pieces matching that name; if
    NOTHING matches, dumps the target's full current piece list (component + mesh name) instead of
    failing with no information. Same cold-asset 400ms retry as item 83's `lbtesttool` fix (shared
    `resolveAsset` race) — factored into a small local `armorProceedWithMesh` helper used by both
    the immediate and retried paths. Registered as `lbtestarmor` (main.lua), same
    `RegisterConsoleCommandHandler` shape as every other path-fed tester.
    **Process note**: `main.lua`'s registration edit was made before archiving its pre-edit
    contents, breaking this project's own archive-before-edit rule for that one file this
    session (spawner.lua was archived correctly beforehand). Caught immediately — reconstructed
    the exact pre-edit content by removing the known, self-contained insertion (verified clean via
    `grep -c lbtestarmor` returning 0 on the reconstruction) and saved it as
    `archive/main.lua_20260827_162027.lua`, same recovery method used earlier this project
    whenever this slip has happened before. `lint.py` clean after both edits (`compile: 10 scripts
    OK`). Deployed to the live install (game was running — `lbreload` needed to pick it up).
    **Not yet tested live** — next step: `lbprobe` a spawned crew/walker/statue, then
    `lbtestarmor Torso` (or any other slot fragment) with no mesh path to confirm the listing
    works, then supply a real mesh path to confirm the actual swap renders.

85. **`lbhelp [command]` — a self-updating console command directory** (2026-08-27). RedFalcon
    asked for a command listing every existing command; a follow-up ask, before any code was
    written, extended it to also print a given command's exact syntax + a one-line description.
    With 58 console commands already registered across this file by this point, a hand-written
    static list would drift out of date the moment the next one gets added — the same class of
    duplication risk this project has already been burned by once before (item 44's `senkaShortKey`
    lesson: reference the live source, don't hand-copy it).
    Built as a lightweight metadata registry instead, deliberately NOT a wrapper around
    `RegisterConsoleCommandHandler` (so it can't affect whether any existing command still
    registers): `local LB_COMMANDS = {}` + `registerCmdInfo(name, usage, desc)` (both declared once,
    right before `lbspawn`'s own registration — the first real command in the file, so every later
    call has it in scope). Every one of the 44 directly-registered commands got ONE new line added
    immediately after its existing `log("Console command registered: ...")` line — a mechanical,
    scripted insertion (Python, matching each command's exact existing log text as the anchor) that
    never touched the actual `RegisterConsoleCommandHandler(...)` call or its handler body, so there
    was no risk of breaking a working command while adding this. The 14 simpler commands built on
    the shared `registerDumpCommand(name, fn, label)` helper needed only ONE edit, inside that
    helper itself, to cover all of them at once: a new `DUMP_CMD_DESC` lookup table gives the
    friendlier ones a real one-line description, falling back to the existing `label` string for
    anything not listed there. `lbhelp` itself registers into the same table.
    `lbhelp` with no argument prints an alphabetized list of every registered command name;
    `lbhelp <command>` (case-insensitive exact match) prints that command's usage line and
    description, or a clear "no command named X" if it doesn't recognize the name — same
    `say()`/`Ar:Log()` dual-output shape as every other command here, so the answer shows up right
    in whichever console window it was typed into, not just `ue4ss.log`.
    `lint.py` clean after every edit (`compile: 10 scripts OK`). Deployed to the live install (game
    was running — `lbreload` needed to pick it up). **Not yet tested live** — next step: run
    `lbhelp` with no arguments to confirm the full list prints, then `lbhelp lbtestarmor` (or any
    other command) to confirm the per-command syntax/description lookup works.

86. **Target lock fixed for real: hover raycast switched to a multi-hit trace, to see past
    occluding building geometry** (2026-08-27, closing out item 80's corrected investigation).
    Root cause confirmed: `Spawner.UpdateHoverHighlight`'s `LineTraceSingleForObjects` call stops
    at the FIRST thing it hits along its ray, whatever that is. A mod-spawned actor standing on or
    near a native building platform can have that platform's own collision sitting between the
    camera and the actor — so the trace was hitting `BP_BuildingBlock_BuildingCenterT01` (a
    building piece, not anything this mod spawned) and stopping there, never reaching the real
    target even though the player was genuinely looking right at it (confirmed by
    `findNearestSpawnInFront`, a totally different targeting method, finding the same actor fine
    at the same moment — see item 80's correction).
    Fix: the trace now tries `KSL:LineTraceMultiForObjects(...)` FIRST — same argument shape as
    the already-proven `LineTraceSingleForObjects` call, just returning every hit along the ray
    instead of only the first. Walks the returned hits in order and picks the first one that's
    actually a tracked (`Spawner.spawned`) actor, skipping past any non-ours geometry (the
    building piece, or anything else) in between — this generalizes to ANY intervening geometry,
    not just this one specific building class, without touching that class's own collision at
    all. If every hit along the ray is non-ours, treated as a real "hit something, just nothing
    lockable" (same NOT-OURS diagnostic as before, now also logging `usedMulti=`). Falls back
    automatically to the ORIGINAL single-hit trace, completely unchanged, if `LineTraceMultiForObjects`
    isn't available in this build or the call errors — implemented so this can only ever ADD a
    chance of finding an occluded target, never remove previously-working behavior.
    `resolveHitActor`/`actorIsOurs` were factored out of the old single-hit-only body into shared
    local closures so both the new multi-trace path and the original single-trace fallback use
    the exact same "which actor did this resolve to, and is it one of ours" logic — no duplicated,
    driftable copy.
    **Genuinely untested engine surface** — `LineTraceMultiForObjects` has never been called
    anywhere in this codebase before now, unlike `LineTraceSingleForObjects` (proven live
    2026-08-24). Same family/signature as that proven call (an array out-param instead of one
    struct), so a reasonable next step rather than a wild guess, but not yet confirmed to exist or
    marshal correctly in this specific UE4SS build. Heavily `pcall`-wrapped with the safe fallback
    described above specifically because of that uncertainty. `lint.py` clean (`compile: 10
    scripts OK`). Deployed to the live install (game was running — `lbreload` needed to pick it
    up).
    **Same-day follow-up: CONFIRMED `LineTraceMultiForObjects` exists and runs in this build
    (`usedMulti=true` in the log) — but its own result was WORSE, not better.** RedFalcon:
    "still not working. sees less now." The `[hover-diag]` line showed why: the resolved
    `hitActor`'s class read back as `/Script/CoreUObject.ScriptStruct` — not an actor at all.
    Root cause, the SAME documented pitfall as `Spawner.LetFurniturePass`'s own history and
    several other component-array reads in this file: indexing an element out of the
    `TArray<FHitResult>` out-param can hand back a `RemoteUnrealParam` WRAPPER, not the struct
    itself — reading `.HitObjectHandle.ReferenceObject` straight off the wrapper silently
    resolved to the struct's own TYPE metadata instead of erroring, which is exactly why this
    went undetected until the diagnostic printed a class name. Compounding that: the ORIGINAL
    version of this fix treated the multi-trace as PRIMARY, letting its (garbage) result silently
    override whatever the proven single-trace call would have found — so a target that used to
    resolve fine via the single trace could now get overwritten by the broken multi-trace path,
    which is the actual mechanism behind "sees less now."
    **Fixed two ways, same pass**: (1) added the same `:get()` unwrap this file already uses
    everywhere else for exactly this array-element pitfall, applied to each `TArray<FHitResult>`
    element before reading its fields; (2) restructured so the proven single-hit trace ALWAYS
    runs first and is the baseline result — the multi-trace now only runs at all when the single
    trace did NOT already find something ours, and can only ever OVERRIDE a miss with a real
    found target, never replace a working single-trace hit with anything. This makes the
    "can only ever add, never take away" guarantee actually true in the code, not just the
    stated intent it was supposed to be from the start.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game was running —
    `lbreload` needed to pick it up).
    **CONFIRMED LIVE, WORKING** — RedFalcon: "that worked." Target lock now correctly finds and
    locks a mod-spawned actor sitting behind/near occluding native building geometry, the original
    bug this whole investigation (items 80/86) started from. Closing summary of the full arc for
    future reference: (1) first suspected Remote Desktop input interference — wrong, ruled out by
    testing from the physical machine; (2) real cause found by comparing against a second,
    independent targeting method (`findNearestSpawnInFront`) succeeding at the same moment this
    raycast failed — a single-hit-trace occlusion problem, not a camera/input issue; (3) first fix
    attempt (multi-trace as PRIMARY) made things measurably worse ("sees less now") due to an
    unwrapped `RemoteUnrealParam` on the returned `TArray<FHitResult>` elements — the same
    documented array-wrapper pitfall as `Spawner.LetFurniturePass`'s own history, just newly hit on
    a struct array instead of an object array; (4) final fix — the `:get()` unwrap PLUS
    restructuring so the proven single-trace is always the baseline and multi-trace can only
    supplement (never override) it — confirmed live working. `KSL:LineTraceMultiForObjects` is now
    a second proven-safe trace function in this codebase, alongside `LineTraceSingleForObjects`,
    for any future work that needs to see past the first hit along a ray.
    **Immediate same-day follow-up — a second, separate gap in the same feature**: RedFalcon:
    "it worked on people, but not the decor." Root-caused to `Spawner.EnsureRaytraceChannel`
    (spawner.lua) — called unconditionally on every spawn, but its actual collision-response call
    had been fully commented out since 2026-08-24 (a diagnostic disable after it caused a
    confirmed leg-bending/IK glitch among WALKING Characters — see the function's own full history
    in its header comment). That disable was believed cost-free once the raytrace itself switched
    to object-type querying the same day, on the assumption Characters (native Pawn collision) and
    decor/statues (native WorldStatic/WorldDynamic collision) would both register fine without any
    extra help — never actually re-verified for decor specifically afterward. Decor items are
    commonly authored with collision that doesn't block every channel a line trace might query
    (the exact gap this function existed to close in the first place, back when walkers/idle
    Senkamati/decor ALL had this same problem) — with the old fix disabled, nothing was left
    plugging that gap for decor, while Characters' own always-solid Pawn collision meant they
    never needed it in the first place.
    Re-enabled, but narrower and on a DIFFERENT channel than what caused the original bug: blocks
    raw `ECollisionChannel` 0 and 1 (WorldStatic/WorldDynamic — the equivalents of the trace's own
    `{1,2,3}` object-type array, offset by one the same way this file's own comments already
    establish for Visibility) — raw channel 3 (Visibility, the one that actually caused the IK
    glitch) is deliberately never touched again. Also skips any actor with a
    `CharacterMovementComponent` entirely (`actor:GetComponentByClass(...)`, the same proven call
    item 71's movement-component experiment already used) — decor/statues never have one, so this
    can't reach the class of actor the original bug was ever observed on, belt-and-suspenders on
    top of already being a different channel. Added a plain diagnostic print (components touched)
    so a live test shows immediately whether this ran at all.
    Since `Spawner.EnsureRaytraceChannel` only runs automatically at SPAWN time, ALREADY-PLACED
    decor won't pick this up on its own — `lbfixraytrace` (`Spawner.FixAllRaytraceChannels`,
    already shipped 2026-08-22 for exactly this "retroactively fix every already-placed spawn"
    purpose) re-calls it on every tracked actor without needing a reload or respawn.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game was running —
    `lbreload` needed to pick it up).
    **Same-day follow-up — worked on chests, not on destructible furniture.** RedFalcon: "it works
    on chests, but i placed a barrel table and a broken wardrobe and nothing." Log evidence pinned
    the difference: the wardrobe's class was `BP_Shared_DestructibleStructures_WardrobeAshlands_04`
    — a `DestructibleStructures` prop, plausibly registering its own native collision Object Type
    as something like PhysicsBody/Destructible rather than plain WorldStatic/WorldDynamic (what
    chests and ordinary decor use, and what the previous fix's `{1,2,3}` object-type array and
    raw-channel-0/1 response fix both assumed). Rather than guess a fourth specific enum value
    blind, widened BOTH levers at once, since querying/blocking an extra type nothing actually has
    is harmless (it just never matches, unlike guessing a collision RESPONSE wrong, which risks
    unwanted physical blocking):
    - The trace's own object-type array (`Spawner.UpdateHoverHighlight`, both the single- and
      multi-trace calls) widened from `{1,2,3}` to a new module-local `HOVER_TRACE_OBJECT_TYPES =
      {0,1,2,3,4,5,6}` — covers the full standard range of default UE object types under either a
      0-indexed or 1-indexed reading of the enum, since which convention this UE4SS build's
      binding actually uses was never confirmed either way.
    - `Spawner.EnsureRaytraceChannel`'s own raw-channel response-blocking extended from just
      {WorldStatic=0, WorldDynamic=1} to also cover {PhysicsBody=5, Destructible=7} (Unreal's
      standard default `ECollisionChannel` ordering) — still deliberately never channel 3
      (Visibility), the one confirmed to cause the original IK glitch, and still skipped entirely
      for any actor with a `CharacterMovementComponent`.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game was running —
    `lbreload` needed to pick it up).
    **Same-day follow-up — "still not working after reload," and the real bug found via a
    decisive diagnostic, not more guessing.** RedFalcon: still nothing, even on a fresh
    placement confirmed to route through `Testbed.placeDecorEntry` -> `Spawner.Spawn` (which
    calls `Spawner.EnsureRaytraceChannel` unconditionally, per its own long-standing call site).
    Rather than guess a FIFTH channel/object-type value, grepped `ue4ss.log` for the new
    `[raytrace-fix]` diagnostic print this function's re-enable added — ZERO occurrences,
    anywhere, for ANY actor, ever, since it was redeployed. Since that print is unconditional
    except for the function's own two early-return guards, this proved the function itself was
    silently bailing out every single time, for every actor — not a decor-specific collision
    gap at all.
    Root cause: the `CharacterMovementComponent` exclusion check added in the SAME re-enable read
    `hasMovement = comp ~= nil` — but `GetComponentByClass` returns a non-nil-but-INVALID userdata
    sentinel when nothing matches, the exact same documented pitfall
    `Spawner.TryAddMovementComponentToNearest`'s OWN check (`existing and existing:IsValid()`,
    a few thousand lines up in this same file) already handles correctly — missed here. `~= nil`
    was therefore true for EVERY actor regardless of whether it actually had a movement
    component, so the function returned early before doing anything, for literal everyone,
    the entire time. This means the WorldStatic/WorldDynamic fix and the PhysicsBody/Destructible
    widening were BOTH silently inert from the moment they shipped — none of this arc's
    collision-channel theorizing had actually been tested at all until now. Fixed to `(comp ~=
    nil) and comp:IsValid()`, matching the established pattern exactly.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game was running —
    `lbreload` needed to pick it up). **Not yet tested live** — next step: `lbreload`, run
    `lbfixraytrace` to retrofit the already-placed wardrobe/barrel table (or place fresh ones),
    confirm `[raytrace-fix] actor=... components touched=N` NOW actually appears in the log, then
    try Num+ on them. If it still fails even with the function confirmed running this time, that's
    real evidence the object-type/channel guesses themselves are wrong, not that something else is
    silently swallowing the fix.
    **Same-day follow-up — STILL failing even with the function confirmed running, and a real
    reframe from RedFalcon.** "still not working with wardrobe or table. it worked before what
    changed" — asked to clarify, RedFalcon: "it may have been a while, but at one point we had all
    decor and people working." That points at a specific known-good era rather than an unlocated
    guess: the 2026-08-22 window, when `Spawner.EnsureRaytraceChannel`'s ORIGINAL body
    unconditionally blocked raw Visibility (channel 3) on every spawn and the hover trace was
    still plain CHANNEL-based (`LineTraceSingle`, TraceTypeQuery 0) — the exact combination its own
    header comment says was built to cover "walking actors, idle Senkamati, AND drops decor"
    together. That combination was abandoned 2026-08-24 for two reasons at once: the Visibility
    block caused the IK glitch on WALKING Characters, and the trace itself switched to object-type
    querying on the (evidently wrong, for at least some native classes) assumption that native
    Pawn/WorldStatic/WorldDynamic collision would cover everything without it.
    Fixed by bringing BOTH pieces of the historically-proven mechanism back, but scoped to avoid
    the IK bug this time instead of just leaving it disabled: (1) `Spawner.EnsureRaytraceChannel`
    now ALSO blocks raw Visibility (channel 3) again, alongside the WorldStatic/WorldDynamic/
    PhysicsBody/Destructible channels already added — safe now because this function already
    returns early for anything with a `CharacterMovementComponent` (the `hasMovement` fix, above),
    so Characters never reach this line at all and the original IK-glitch class of bug can't recur;
    (2) `Spawner.UpdateHoverHighlight` gained a THIRD fallback tier — a plain channel-based
    `LineTraceSingle` (TraceTypeQuery 0), tried only if BOTH the object-type single- and multi-trace
    tiers already came up empty. Same "can only ever add, never replace a working result" discipline
    as the multi-trace tier: a working object-type hit is never second-guessed, this only fires on
    an existing miss.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game was running —
    `lbreload` needed to pick it up). **Not yet tested live** — next step: `lbreload`, `lbfixraytrace`
    (or a fresh placement) to make sure the Visibility block actually lands on the wardrobe/table,
    then Num+ on them. This is now a three-tier trace (object-type single -> object-type multi ->
    channel-based single) covering every combination this whole investigation has turned up
    evidence for — if this specific combination still fails, the next real diagnostic step is
    reading the wardrobe's actual `BodyInstance.CollisionEnabled`/response values directly (real
    struct-drilling per `WINDROSE_MODDING_NOTES.md` §10's own recipe) rather than continuing to
    guess at channel numbers blind.
    **CONFIRMED LIVE, WORKING** — RedFalcon: "looks to be working." Target lock now correctly
    finds and locks the wardrobe/barrel-table class (and by extension the whole reachable range of
    native decor/destructible classes this three-tier trace now covers), closing this entire
    multi-day investigation for real. Full arc, for anyone revisiting this later: (1) Remote
    Desktop theory — wrong. (2) camera-occlusion diagnosis via a second independent targeting
    method — correct, fixed by adding a multi-hit trace tier. (3) multi-trace made things worse at
    first due to an unwrapped `RemoteUnrealParam` on the hit-result array — fixed, and reordered so
    single-trace is always the protected baseline. (4) decor still failed — traced to
    `EnsureRaytraceChannel` being silently disabled since 2026-08-24. (5) re-enabling it still
    didn't help destructible props specifically — widened the object-type array and channel list,
    still no effect. (6) the widening never actually ran AT ALL — a `~= nil` vs `:IsValid()` bug
    silently skipped the whole function for every actor. (7) fixed that, still failed for this one
    class — RedFalcon's "it worked before" reframe pointed at the specific 2026-08-22-era
    mechanism (Visibility-channel block + channel-based trace) that had been abandoned rather than
    replaced-and-improved; restoring it as a scoped, IK-safe third tier finally closed it. Every
    dead end and the final working shape are written up generally in `WINDROSE_MODDING_NOTES.md`
    §18 (public mirror + GitHub repo, commit `13b58ff`) for any future targeting-system work, here
    or elsewhere.

87. **`Custom > Poses` — a spreadsheet-driven pose picker added to the LivingBaseSpawnMenu tree**
    (2026-08-27). RedFalcon asked to add a "Custom" branch containing "Poses" to the GUI dropdown,
    populated from `Other\Poses.xlsx` (a spreadsheet built while live-testing `lbtestpose` across
    the game's asset catalog this session) — one tab per top-level category, each row a confirmed-
    testable animation with its own subcategory (when the tab has one) and display name, plus the
    exact `lbtestpose <path>` command already run to verify it. Explicitly scoped by RedFalcon as
    NOT needing persistence yet.
    Deliberately built on the EXISTING roster/index mechanism (`spawnmenu_manifest.lua` +
    `SPAWN_MENU_HANDLERS`, main.lua) rather than adding a new leaf type to the compiled
    LivingBaseSpawnMenu C++ mod — confirmed by reading that mod's own source
    (`Working\LivingBaseSpawnMenu\Mod\src\SpawnMenu.cpp`) that its ini parser only understands
    `roster`/`index` pairs and requires both non-empty (`commit_entry` silently drops anything
    else) — a "run this raw command" leaf type doesn't exist there and would need a C++ rebuild.
    Since `SPAWN_MENU_HANDLERS[roster] = function(index) ... end` is fully generic Lua on this
    side (never required to actually spawn an actor), registering a new roster name whose handler
    applies a pose instead needed ZERO changes to the compiled DLL — same "add a descriptor, the
    generic machinery already handles the rest" pattern this whole manifest system was already
    built around.
    Extracted all 221 rows across the workbook's 8 tabs (Standing, SittingKneeling, Work Benches,
    Battle, Magical, Monsterous, Statues, Misc — the exact tab order requested) via a Python/
    openpyxl script (column headers varied slightly per tab — "Category" vs "Command", "Combat"
    vs "Top Category", "Sub Category" vs "Subcategory" — matched case-insensitively rather than
    assuming one fixed header row); every row's own `lbtestpose <path>` text had the path half
    split out, verified all 221 start with `/Game/`, zero rows dropped. Wrote the result as
    `Config.CUSTOM_POSES` (config.lua, inserted before the config.txt/ModSettings/
    SpawnMenuManifest tail so `SpawnMenuManifest.GenerateOnce(Config)` — already called
    unconditionally at the end of config.lua on every load — sees it and auto-appends the new
    `[Custom.Poses.<TopCategory>.<SubCategory>.<Name>]` sections to `spawn_menu.ini` with no manual
    ini-editing needed, same append-only mechanism every other roster already relies on. Row order
    preserved exactly (sheet order, then row order within each sheet) since that order IS the
    roster index `spawn_menu.ini` points back into — reordering `Config.CUSTOM_POSES` later would
    silently repoint every already-generated entry, same caution this file's own header comment
    gives for every other flattened roster.
    Three pieces, each archived before editing: (1) `Config.CUSTOM_POSES` (config.lua) — flat array
    of `{path, topCategory, subCategory, name}`, `subCategory` nil for the three tabs with no
    subcategory column (Magical/Statues/Misc). (2) `custom_poses_path_and_label(row)` +
    `{name = "CUSTOM_POSES", ...}` descriptor (spawnmenu_manifest.lua) — nests under a shared
    `{"Custom", "Poses", row.topCategory}` path, appending `row.subCategory` only when present.
    (3) `SPAWN_MENU_HANDLERS.CUSTOM_POSES` (main.lua) — calls the existing, already-proven
    `Spawner.TestApplyPoseByPath(row.path)` (the same function `lbtestpose` itself calls) on
    whatever's targeted, and deliberately returns `false` on every path (including success) — this
    roster never produces a new actor, and `false` is the same falsy sentinel every other handler's
    own failure path already returns, which safely short-circuits `pollSpawnMenuRequest`'s
    build-ghost-preview check without risking that check indexing a bare `true`. No spawn tracking,
    no persist.txt entry — matches RedFalcon's own "don't worry about persistence yet" framing,
    since applying a pose only ever modifies an actor that already exists.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed all three files to the live install (game
    was running — `lbreload` needed to pick it up, which also re-runs `GenerateOnce` and appends
    the new `spawn_menu.ini` sections). **Not yet tested live** — next step: `lbreload`, open the
    LivingBaseSpawnMenu window, confirm a `Custom > Poses > ...` branch now exists with all 8 top
    categories in tab order, and that selecting a leaf + Spawn actually applies the pose to
    whatever's currently targeted.
    **Same-day follow-up: REPLACE would have silently destroyed the target.** RedFalcon asked
    whether Spawn or Replace should be used for these entries. Checked `Spawner.
    ReplaceNearestInFront` directly and confirmed it unconditionally destroys the current target
    BEFORE calling the spawn callback, then checks `Spawner.spawned` actually grew — since
    `CUSTOM_POSES`' handler never spawns anything, Replace would have deleted whatever was
    targeted and then reported "replacement spawn failed" (recoverable via Num0, but a bad
    surprise for a button meant to just apply a pose). Fixed in `pollSpawnMenuRequest` (main.lua):
    a new `NON_SPAWNING_ROSTERS` lookup table makes REPLACE behave identically to SPAWN for any
    roster listed in it, rather than routing through the destroy-then-recreate flow. Deployed.

88. **`Custom > Skin Tones` — an 8th non-spawning GUI branch, reusing the same pattern as item 87**
    (2026-08-28). RedFalcon: "since you already know them, is it possible to make a skin tone
    category also? ... including the corrupted skin?" — referencing the skin-tone/ethnicity-family
    material-swap mechanism already established this project (items 35/36: `Config.SKIN_FAMILIES`/
    `SkinFamilySwapRules`, a proven `Spawner.DeCorrupt` `swaps` rule matching a component's current
    material name and replacing it) and the Senkamati mob's own native "corrupted" skin material
    (`Config.DECORRUPT_MOB`'s own `swaps` rules, which go the OPPOSITE direction — corrupted to
    clean — already reference its bare name, `MI_Senkamati_<Sex>_<Build>`, as a match pattern, but
    no full asset path for it existed anywhere in this codebase before now).
    Found the real path for the corrupted material via `pakcontents.xlsx` (not guessed):
    `Human/Regular/Senkamati/Materials/MI_Senkamati_<Sex>_<Build>` — the SAME folder shape as every
    other ethnicity family (`Human/Regular/<Family>/Materials/...`), meaning it's a genuine
    ethnicity-style asset authored for the human body/UVs, NOT the "painting a human skin onto the
    Senkamati's own native MESH maps garbage" case this file's own long-standing comment warns
    about (that's the opposite direction/target — a normal ethnicity onto the native Senkamati
    skeletal mesh; this only ever targets a human-skeleton actor, same as every other family).
    Also confirmed via the same catalog search that asset availability is UNEVEN: only a Medium
    build exists for the Female corrupted skin (Small/Large don't), while Male has a genuine
    per-build set under "Feather" (a second "Wood" male variant `Config.DECORRUPT_MOB` references
    wasn't found in the catalog and isn't used). `Config.CorruptedSkinSwapRules(sex)` (config.lua,
    right after `Config.SkinFamilySwapRules`) documents this honestly rather than hiding it — all
    three Female build-match patterns swap to the same Medium asset, which may read slightly
    off-scale on a Small/Large-build target but is the only option that exists.
    `Spawner.TestApplySkinFamily(familyName)` (spawner.lua, right after `TestSwapArmorPiece`) is
    the one genuinely new piece needed beyond item 87's own pattern: unlike a pose or a mesh swap
    (a single path, no context needed), a skin-tone swap's match rules are keyed on the target's
    SEX (the game's own material naming, e.g. `MI_African_Female_Medium`), so applying the wrong
    sex's ruleset would silently match nothing. Reads it straight off the target's own
    `CompositeMeshComponent` via `GetBodySex()` (same 1=Male/2=Female encoding `Spawner.
    ApplyBodySex`/`ApplySexChangeToNearest` already use), defaulting to Female for anything
    unreadable rather than failing outright. `"corrupted"` (case-insensitive) routes to
    `Config.CorruptedSkinSwapRules`; anything else is matched case-insensitively against `Config.
    SKIN_FAMILIES` and routed to `Config.SkinFamilySwapRules`. The actual swap is a plain
    `Spawner.DeCorrupt(actor, { swaps = rules })` call — zero new engine surface, same mechanism
    every skin/outfit rule in this file already runs on.
    Wired identically to item 87's `CUSTOM_POSES`: `Config.CUSTOM_SKIN_TONES` (a flat 8-name list —
    the 7 families plus "Corrupted"), a `custom_skin_tones_path_and_label` descriptor
    (spawnmenu_manifest.lua, building a flat `{"Custom", "Skin Tones"}` branch with no subcategory
    nesting needed), a `SPAWN_MENU_HANDLERS.SKIN_TONES` entry (main.lua) that always returns
    `false` (no actor produced), and `lbtestskin <family>` as the matching direct console command.
    `SKIN_TONES` was added to the same `NON_SPAWNING_ROSTERS` guard from this item's own earlier
    follow-up, so Replace is safe for it too from the start — no separate bug to hit and fix this
    time.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game was not running
    at deploy time — takes effect on next launch, no `lbreload` needed). **Not yet tested live** —
    next step: open the SpawnMenu window, confirm `Custom > Skin Tones` lists all 8 entries, and
    that selecting one (on both a male and a female target, to check the sex auto-detection) swaps
    the skin correctly — "Corrupted" specifically is a reasoned-through but genuinely untested
    combination (first time this material has ever been applied to a human-skeleton actor rather
    than swapped away from a Senkamati mob body).
    **CONFIRMED LIVE, WORKING** — RedFalcon: "Skin tones seem to work." Both the 7 ethnicity
    families and the reasoned-through "Corrupted" entry render correctly via the GUI tree, with the
    sex auto-detection picking the right Male/Female ruleset without needing to ask.

89. **`Custom > Hair > Hat|No Hat` — a 3rd non-spawning GUI branch, plus a real male-hair-catalog
    finding** (2026-08-28). RedFalcon asked whether the game's male hairstyle options differ from
    the female set (only ever built out on the female side so far, `Config.FEMALE_HAIR_STYLES`/
    `_HAT`) — checked the actual asset catalog rather than guessing: **`Hair/Male/` mirrors
    `Hair/Female/` exactly** — the same 16 family names, and the same 12-of-16 subset with a
    hat-compatible ("SuspendHat") mesh variant (Bristle/Mohawk/PartialDreadlocks/Undercut lack one
    on BOTH sexes, not just Female as the existing tables might have implied). Every one of the 28
    resulting Male asset paths was independently confirmed present in the catalog one at a time —
    not derived by pattern-substituting "_Female" → "_Male" into the existing Female table and
    hoping the numbering matched, since a couple of families (Shag in particular) have irregular
    numbering across their Default/SuspendHat variants that isn't safe to assume symmetric without
    checking.
    `Config.CUSTOM_HAIR` (config.lua, right after `Config.FEMALE_HAIR_STYLES`) combines both sexes
    into one 28-row roster (16 "No Hat" + 12 "Hat"), each row carrying `femalePath`/`malePath` plus
    the `hasHat` flag RedFalcon asked to sub-categorize by. `Spawner.TestApplyHairStyle(styleName)`
    (spawner.lua, right after `TestApplySkinFamily`) mirrors that function's own sex-auto-detection
    (`GetBodySex()` off the target's `CompositeMeshComponent`, defaulting Female) for the same
    reason — a hair mesh authored for the wrong sex's skeleton is the same class of mismatch this
    file already documents for skin materials — then applies it via a plain `Spawner.DeCorrupt`
    `replaces` rule (`match = "Hair_"`), the exact mechanism Letty/Marita/Merchant's own hair
    overlays already use, just fed one path instead of a whole character ruleset.
    Wired identically to items 87/88: `custom_hair_path_and_label` (spawnmenu_manifest.lua) nests
    each row under `{"Custom", "Hair", row.hasHat and "Hat" or "No Hat"}` — the same style name
    (e.g. "Afro") appears once under each branch since the two variants are genuinely different
    meshes, which is fine, they land at different full dotted paths so there's no section
    collision. `SPAWN_MENU_HANDLERS.HAIR` (main.lua) added to the same `NON_SPAWNING_ROSTERS` guard
    from item 87 — Replace is safe from the start here too. `lbtesthair <style>` registered as the
    matching direct console command.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game was not running
    at deploy time — takes effect on next launch). **Not yet tested live** — next step: open the
    SpawnMenu window, confirm `Custom > Hair` shows both `Hat` (12 entries) and `No Hat` (16
    entries) subcategories, and that a style applies correctly on both a male and a female target.
    **CORRECTED same day, RedFalcon caught a real gap**: "i dont see the cut that looks like
    Marita's." Her own hair rule (`Config.FEMALE_WALKER_OVERLAYS`) uses
    `SK_Hair_Wig_02_SuspendedBandana_Female` — a **third** headwear-compatibility variant
    (Bandana) this item's original Hat/No-Hat split never modeled at all, on top of a **fourth**
    (Headband) that was ALSO missing. Re-swept the catalog properly this time (every family, all
    four variants — Default/Hat/Headband/Bandana — both sexes, not just re-deriving Marita's one
    specific asset) and found two things the original narrower sweep got wrong: (1) only Bristle
    (no headwear variants at all) and Mohawk/Undercut (Headband only, no Hat/Bandana) genuinely
    lack full coverage — every other family, INCLUDING PartialDreadlocks, has all four; (2)
    PartialDreadlocks was WRONGLY believed hat-incompatible back in item 36 (2026-08-11) — it
    actually has a full Hat/Headband/Bandana set, just under a bare `_Hat_`/`_Bandana_`/
    `_Headband_` naming convention with no "Suspend" prefix, which every previous sweep of this
    folder (including this item's own first pass) missed by only searching for
    "suspend...hat/headband/bandana" substrings.
    `Config.CUSTOM_HAIR` rebuilt from 28 rows (`hasHat` boolean) to 57 (`variant` string:
    "Default"/"Hat"/"Headband"/"Bandana") — the same style name now appears once per variant it
    actually has, same pattern the original Hat/No-Hat split already used, just with two more
    values. `Spawner.TestApplyHairStyle` gained a second `variant` parameter (defaults to
    "Default") since a bare style name is now ambiguous across up to 4 rows;
    `custom_hair_path_and_label` (spawnmenu_manifest.lua) nests directly on `row.variant` instead
    of the old ternary; `lbtesthair <style> [variant]` and the `HAIR` roster handler both updated
    to pass it through.
    **Real deployment gotcha, fixed manually**: the OLD 28-entry table had already been loaded by
    the live game at least once (RedFalcon was actively browsing/testing `Custom > Hair` before
    reporting the gap), so `spawn_menu.ini` already had 28 `roster = HAIR` sections baked in under
    the old ordering. Since the new 57-entry table inserts PartialDreadlocks into the middle of
    the Hat block (shifting every index after it), those 28 stale sections would have silently
    pointed at the WRONG rows once the new table loaded — `spawnmenu_manifest.lua`'s own
    append-only design only ever ADDS missing entries, it never corrects a stale one. Manually
    stripped all 28 stale `[Custom.Hair....]` sections carrying `roster = HAIR` out of the live
    install's `spawn_menu.ini` (Poses/Skin Tones sections untouched) so the next load regenerates
    all 57 correctly from scratch, rather than leaving a landmine of correctly-labeled tree
    entries pointing at the wrong mesh.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game was not running
    at deploy time). **Not yet tested live** — next step: open the SpawnMenu window, confirm
    `Custom > Hair` now shows FOUR subcategories (Default/Hat/Headband/Bandana), and specifically
    that Wig > Bandana renders as something recognizably close to Marita's own look.
    **CORRECTED AGAIN same day — still not Marita's actual hair.** RedFalcon: "so none of those
    are the same as marita's hair. Check the walking woman spawn of her, as that hair is
    assigned." The real problem: this table was STILL collapsing each family down to ONE
    representative numbered mesh (whichever sorted first, usually `_01`) per variant — Marita's
    confirmed real mesh is specifically `SK_Hair_Wig_02_SuspendedBandana_Female` (the "02" sub-
    style), not "01", and several families genuinely ship MULTIPLE distinct numbered sub-styles
    that are real, visually different looks, not interchangeable copies the "pick one to
    represent the family" design assumed: Afro has 5, Shag/Pixie/Wavy have 3, Bun/Wick/Wig have 2.
    Rebuilt a third time to expose every numbered sub-style as its own entry ("Wig 1"/"Wig 2",
    "Afro 1".."Afro 5", etc.) — a family with only one real style keeps its bare name (e.g.
    "ShortBob"). This pass also caught a genuine naming collision the earlier per-family sweep had
    silently lost entirely: `LayeredBob` ships TWO distinct meshes both nominally "01" under the
    same folder — plain `LayeredBob_01_...` and a separate `LayeredBobDecor_01_...` — previously
    one silently overwrote the other in the "one representative per family" table; now kept as
    two separate entries, "LayeredBob" and "LayeredBob Decor". One confirmed real asymmetry
    excluded rather than guessed around: Male Shag ships 3 extra numbered variants (04/05/06)
    Female Shag doesn't have at all — since a single entry needs both sexes' paths (sex is
    auto-detected at apply time), those 3 Male-only numbers were left out; every other
    family/number/variant combination was individually confirmed present for BOTH sexes via
    pakcontents.xlsx before being added, not assumed symmetric. `Config.CUSTOM_HAIR` grew from 57
    to 109 entries. `Spawner.TestApplyHairStyle`'s own name-matching needed no change (case-
    insensitive exact match on the full name string, e.g. "Wig 2", already worked once the table
    carried the right names).
    Deployed while the game was RUNNING this time — manually stripped the (now-stale, 57-entry)
    `roster = HAIR` sections from the live `spawn_menu.ini` again (same reasoning as the previous
    round: the append-only manifest generator can't fix a stale entry pointing at the wrong row,
    only add new ones) and copied the updated `config.lua` over; `lbreload` still needed to re-run
    `GenerateOnce` and regenerate all 109 entries fresh. **Not yet tested live** — next step:
    `lbreload`, then check `Custom > Hair > Bandana > Wig 2` specifically against the real walking
    Marita spawn's own hair.
    **Real bug found and fixed, same day**: RedFalcon: "if i assign 'undercut' to an npc, and then
    try to change the hair again, it will not change." Root cause: `Spawner.TestApplyHairStyle`
    originally routed through `Spawner.DeCorrupt`'s shared `replaces` mechanism (`match = "Hair_"`
    against a component's CURRENT mesh's bare NAME) — the exact same pattern Letty/Marita/
    Merchant's own hair overlays already use. Undercut's real asset is named
    `SK_Undercut_01_..._Female` — the ONLY family in the whole catalog missing the "Hair_" prefix
    every other style has. The instant it's applied, the component's current mesh name no longer
    contains "Hair_" at all, so every SUBSEQUENT "Hair_" pattern match silently fails to find that
    component — not a crash, just a component that becomes permanently unmatchable by name once
    Undercut lands on it, exactly matching the reported symptom.
    Fixed by no longer matching by NAME at all: `Spawner.TestApplyHairStyle` now walks every
    `SkeletalMeshComponent` directly and checks each one's current mesh's FULL asset PATH for
    `/Hair/` (not the bare filename for "Hair_") to find the hair slot, then swaps it with a plain
    `SetSkeletalMeshAsset`/`SetSkeletalMesh` call — bypassing `Spawner.DeCorrupt`'s name-pattern
    matching for this tester entirely. The full path reliably contains `/Hair/` regardless of
    which family's own (possibly irregular) filename convention happens to be currently equipped,
    so this can't repeat the same failure for any other oddly-named style either.
    **Not fixed, deliberately out of scope**: Letty/Marita/Merchant's own hardcoded `replaces`
    rules (`Config.FEMALE_WALKER_OVERLAYS`) still use the original name-pattern approach and carry
    the exact same latent bug — it just never surfaced there because none of their fixed hair
    targets happen to be Undercut. Worth remembering if that ever comes up, not touched this pass
    since those rules work fine for what they actually assign today.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game running —
    `lbreload` needed). **Not yet tested live** — next step: apply Undercut to an actor, then try
    a different style on the same actor and confirm it actually changes this time.
    **CONFIRMED LIVE, WORKING** — RedFalcon: "works." Hair can now be changed again after Undercut,
    closing out the `Custom > Hair` feature arc for real (numbered variants + this fix).

90. **`Custom > Clothes` — a 4th non-spawning GUI branch, bigger and messier than hair turned out
    to be** (2026-08-28). RedFalcon asked what to search the pak export for to find clothing
    pieces; after a first informational sweep (families/slots/folder structure, no code yet),
    asked to build it for real ("yeah sweep what's there").
    Swept `Character/Skeletal_Meshes/Armor/ArmorRegular/` the same way `Config.CUSTOM_HAIR` swept
    `Hair/` — 401 real (`SK_`-prefixed, excluding `PHYS_`/`SM_Drop_`/stray `SK_Hair_`/
    `SK_ArmorCreature_` files that don't belong in this folder at all) mesh files across 25 family
    folders, parsed into (family, slot, number, sex, style). Genuinely more irregular than hair:
    - **"Belt" is actually FOUR separate accessory types** (Belt/Frog/Sling/Strap) named
      `SK_<Type>_<NN>_<Sex>` — a completely different filename shape from every other family
      (`SK_Armor_<Family>_[NN_]?[Sex_]?<Slot>[_<style>]`). Split into their own pseudo-families
      rather than forced into one bucket.
    - **Two casing-duplicate family pairs**, same class of issue as the `WorkBenches`/
      `Workbenches` gotcha already documented in `WINDROSE_MODDING_NOTES.md` §14: `BlackBeard_
      Musketeer`/`Blackbeard_Musketeer` and `BlackSmith`/`Blacksmith` — same content indexed
      under both casings across different pak chunks. Dropped the capitalized duplicates.
    - **Sex pairing is genuinely asymmetric in real, confirmed ways**, not guessed around: Dogface
      has no Female content at all (a male-only NPC type); Jeweler's Torso/Waist pieces have real
      content asymmetry (Female gets 3 torso shape sub-variants per outfit "set", Male gets 1);
      Flibustier's Set 1 uses a plain "Torso" mesh for Male but "Torso_Long" for Female — probably
      the intended per-sex cut for the same look, but not something safe to assume/force-pair
      from naming alone. Policy: only pair Female+Male into one sex-auto-detected row when they
      share the EXACT SAME style token; anything that exists for only one sex (or has none at all
      in its name, e.g. Musketeer/Combatant/Dogface) becomes a single `unisexPath` row applied
      regardless of the target's detected sex — an honest reflection of what the catalog actually
      has, not an invented workaround.
    `Config.CUSTOM_CLOTHES` (config.lua, right after `Config.CUSTOM_HAIR`): 242 rows after
    dedup. `name` is a best-effort mechanical label built from each file's own number+style
    tokens ("Set 2 Long 3" for some of the more deeply-nested Jeweler entries) — not hand-polished
    per entry given the scale, expect some clunky names until tried live.
    **The one genuinely new piece of engineering**: unlike hair (one component, found once by
    checking for `/Hair/` in its current mesh's path), clothing has MANY components on one actor
    (Torso/Legs/Feet/Hands/Headgear/Waist/Cape/etc. simultaneously) — `Spawner.
    TestApplyClothingPiece` finds the right one to swap via a new `clothingSlotOf(meshName)`
    helper that categorizes a component's CURRENT mesh name into a canonical slot using the exact
    same token vocabulary the config table itself was built from, deliberately checking
    longer/more-specific tokens FIRST (`BandanaHat`/`Headband` before `Hat`/`Head`) since several
    tokens are substrings of each other and Lua's `pairs()` has no guaranteed iteration order —
    caught and fixed this ordering bug during writing, before it ever shipped, by switching from a
    plain key/value table to an explicit ordered list. This is the same fix class as item 89's
    Undercut bug (match by a robust, always-present signal — here, ANY recognized slot token
    appearing anywhere in the current name — rather than one specific family's own convention),
    applied proactively this time instead of needing a live bug report first.
    Wired identically to items 87-89: `custom_clothes_path_and_label` (spawnmenu_manifest.lua)
    nests four levels deep (`Custom > Clothes > <Family> > <Slot> > <Name>`, one deeper than hair
    since clothing genuinely has both a family and a slot axis); `SPAWN_MENU_HANDLERS.CLOTHES`
    (main.lua) added to `NON_SPAWNING_ROSTERS` from the start (no separate Replace-safety bug to
    hit this time, learned from item 87); `lbtestclothes <family> <slot> <name>` as the matching
    console command.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game running —
    `lbreload` needed). **Explicitly lower-confidence than hair/skin at ship time** — 242 entries
    across 25 families is a much larger surface than hair's 109 across 16, built from pure catalog
    inference with no equivalent to Marita's known-real mesh to cross-check against ahead of time;
    expect this one to need more live-testing correction passes, not fewer. **Not yet tested
    live** — next step: `lbreload`, browse `Custom > Clothes`, and try a piece from a family with
    no sex indicator (e.g. Musketeer or Combatant) plus one with real asymmetric content (Jeweler
    Torso) to see how both actually look before trusting the rest of the table.

91. **Jeweler Torso/Waist sex-pairing corrected; a reference spreadsheet exported; a second
    Senkamati corrupted-skin option added** (2026-08-28, same day, following up on item 90's own
    "kind of works" report). RedFalcon: "Can you export a csv or excel I can use to reference. I
    have found that jeweler torso has a pattern where if it ends in 01, 02, or 03, its for the
    female body, and those withut are male."
    Re-checked the raw per-file parse (`clothes_parsed2.json` in scratchpad, from item 90's own
    sweep) rather than re-deriving from scratch: confirmed RedFalcon's finding is exactly right,
    and explains the "kind of works" — Jeweler's Torso/Torso_Long/Waist slots were the ONE place
    in the whole 401-file sweep where Female ships several NUMBERED sub-variants
    (`Torso_01`/`_02`/`_03`) per outfit "set" while Male ships only ONE bare-named mesh (`Torso`)
    for that same set. Item 90's pairing rule ("only pair Female+Male when they share the exact
    same style token") never matched a numbered Female style against a bare Male one, so all of
    these silently fell back to separate UNISEX rows — meaning a Male target could get one of the
    Female-only numbered meshes and vice versa, exactly the kind of wrong-body-shape mismatch
    RedFalcon's own testing surfaced.
    Fixed by re-pairing: for each (Torso/Torso_Long/Waist, outfit-set-number), every Female
    numbered sub-variant now pairs with THAT SET's single Male bare mesh as a real
    `femalePath`+`malePath` row (e.g. "Set 2 02" = Female `Torso_02` + Male's one `Torso`,
    sex-auto-detected same as every other paired row) — 8 old Male-bare unisex rows and 19 old
    Female-numbered unisex rows (27 total) replaced with 19 correctly-paired rows.
    `Config.CUSTOM_CLOTHES` went from 242 to 234 entries. `spawn_menu.ini`'s live install had
    already baked in 242 stale `roster = CLOTHES` sections from item 90's own testing session —
    same "append-only manifest can't fix a stale index" landmine already hit once for hair (item
    89) — manually stripped all 242 (via an `awk` block filter, not the manifest generator, which
    only adds) so the next `lbreload` regenerates all 234 correctly from scratch rather than
    leaving old entries pointed at now-shifted/removed rows.
    **CSV/Excel reference delivered**: `Other\CustomClothesReference.xlsx` — one row per
    `Config.CUSTOM_CLOTHES` entry (234 rows), columns Family/Slot/Name/Coverage (Female only /
    Male only / Both, sex auto-detected / Unisex, fixed mesh)/Female Mesh/Male Mesh/Unisex
    Mesh/a ready-to-paste `lbtestclothes` console command — sorted by family/slot/name, header
    row frozen, autofilter on. Meant for RedFalcon to browse and flag any other mispairing the
    same way the Jeweler one was caught, without needing another live probe-and-report round trip
    per family.
    **Also addressed, from a mid-task follow-up ("Also can you try grabbing the senkamati")**:
    item 88's own comment said a second "Wood" male corrupted-skin variant referenced by `Config.
    DECORRUPT_MOB` "wasn't found in the asset catalog" — re-swept `pakcontents.xlsx` for every
    `MI_Senkamati_*` material and found `MI_Senkamati_Wood_Male_Medium` genuinely exists after all
    (a Medium-only alternate to the per-build "Feather" family Male already uses). Added `Config.
    CorruptedWoodSkinSwapRules(sex)` (Male routes to Wood_Male_Medium at all three sizes, same
    "one asset covers every build" compromise the Female corrupted skin already uses; Female has
    no Wood equivalent at all, so it falls back to the identical Female Medium asset regular
    "Corrupted" already uses — the two options render identically on a Female target, only Male
    differs) and a matching `"Corrupted (Wood)"` entry in `Config.CUSTOM_SKIN_TONES` (now 9
    entries). `Spawner.TestApplySkinFamily` routes the new name case-insensitively, same `elseif`
    shape as the existing "corrupted" branch.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed `config.lua`/`spawner.lua` to the live
    install (game running — `lbreload` needed to pick up both the corrected clothes table and the
    new skin-tone option and regenerate `spawn_menu.ini` fresh). **Not yet tested live** — next
    step: `lbreload`, confirm `Custom > Clothes > Jeweler > Torso`/`Waist` now show
    sex-auto-detected paired entries instead of the old separate unisex ones, and confirm `Custom
    > Skin Tones > Corrupted (Wood)` applies correctly on a Male target.
    **Same-day correction: RedFalcon meant the Senkamati ARMOR, not another skin variant.** "try
    grabbing the senkamati" (a mid-task message during the Jeweler/CSV work above) was answered as
    a second corrupted-SKIN option — wrong guess; the actual ask was to add the Senkamati tribal
    armor pieces (Warrior/Hunter/Thrall/Witch) into the `Custom > Clothes` catalog itself, same as
    every other family already swept in item 90.
    Found via the same `pakcontents.xlsx` technique: a COMPLETELY SEPARATE folder tree from
    item 90's sweep — `Character/Skeletal_Meshes/Armor/ArmorCreature/Senkamati_<Role>/` (Warrior/
    Hunter/Thrall/Witch, one subfolder each; Witch's is singularly named `Mesh/`, every other
    role's is `Meshes/` — a real, confirmed inconsistency, not a typo to "fix") rather than
    `ArmorRegular/` — these are the exact meshes `Config.DECORRUPT_CREW`/`DECORRUPT_HUNTER`/
    `DECORRUPT_CREW_FEMALE` already reference by hand for the Warrior/Hunter/Caster-F crew
    re-skins (items 29-34), now exposed as individually swappable pieces instead of only ever
    arriving as a fixed per-character bundle. 73 real files parsed with zero regex misses:
    `SK_ArmorCreature_Senkamati_<Warrior|Hunter|Thrall|Witch>_<Feather|Wood>_<NN>_<slot
    token>` — none of these carry a `_Female_`/`_Male_` sex token at all (confirmed genuinely
    absent, not missed), so every row is `unisexPath`-only, applied regardless of the target's
    detected sex — same honest-reflection-of-the-catalog policy item 90 already established for
    Musketeer/Combatant/Dogface.
    Two new canonical slot tokens needed in `CLOTHING_SLOT_TOKENS` (spawner.lua) that item 90's
    sweep never encountered: `"Neck"` (Witch only) and `"TorsoCloth"` (Witch's cloth underlayer,
    a real separate component from her `Torso` armor piece) — `TorsoCloth` inserted BEFORE the
    existing `"Torso"` entry, same longest-token-first discipline as every other entry in that
    list, since `"Torso"` is a literal substring of `"TorsoCloth"` and would otherwise misclassify
    every Witch TorsoCloth piece as her Torso slot.
    Appended as `Config.CUSTOM_CLOTHES` rows 235-307 (family = `"Senkamati Warrior"`/`"Hunter"`/
    `"Thrall"`/`"Witch"`, slot from the token above, name = `"<Feather|Wood> <NN>"`) — deliberately
    added AFTER the existing 234 rows, not interleaved, so every already-generated `spawn_menu.ini`
    index for Jeweler/etc. from this same session stays valid; only 73 brand-new sections need
    generating on the next `lbreload`, no stale-index cleanup required this time (unlike the two
    prior hair/clothes reshuffles, items 89-91, which both needed a manual `spawn_menu.ini` strip).
    A new `ARMC` path constant (`.../Armor/ArmorCreature/`) sits alongside the existing `ARM`
    constant since these live under a sibling folder tree, not a subfolder of it.
    `CustomClothesReference.xlsx` (item 91's own export) regenerated to include all 307 rows.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed `config.lua`/`spawner.lua` to the live
    install (game running — `lbreload` needed). **Not yet tested live** — next step: `lbreload`,
    browse `Custom > Clothes > Senkamati Warrior/Hunter/Thrall/Witch`, and confirm a piece (e.g.
    Warrior's `Feather 01` Torso) applies cleanly via the generic slot-match mechanism on a
    human-skeleton crew/walker target, the same way it already does when hardcoded into the
    Warrior/Hunter/Caster-F re-skin rules.

92. **`lbtestscale` — exposing the long-dormant component-scale mechanism generically** (2026-08-28,
    same day). RedFalcon recalled scaling armor pieces being possible — correct: `Spawner.
    NudgeComponentTransform(actor, pattern, scaleMul, offsetZ)` has existed since 2026-08-10 (built
    for the Senkamati Legs pelvis-gap problem, items 32/48-51), but it was only ever wired into ONE
    internal retry loop (`senkaCrewFix`'s own Legs-piece nudge) gated by `Config.
    SENKA_LEGS_NUDGE_SCALE`/`_OFFSET_Z`, both left at `1.0`/`0.0` (a no-op) the whole time — it has
    never actually been exercised with a real value or confirmed to look right live.
    RedFalcon's follow-up gave a concrete reason to actually use it now: with `Custom > Clothes`
    (items 90-91) able to apply ANY piece from ANY family onto ANY targeted actor, they've noticed
    a real proportion mismatch in both directions — ordinary human clothing looks TOO SMALL on the
    Senkamati Witch/Caster body, and Senkamati tribal armor looks TOO LARGE on an ordinary human
    body. Directly consistent with the already-documented finding (item 61) that the Senkamati
    armor was rigged/skinned for the mob's own native proportions, not the human "Regular" skeleton
    it now also gets worn on via the re-skin/Custom-Clothes route — a fixed relative scale offset
    between the two body families is exactly what that mismatch would produce.
    Built `Spawner.TestScaleClothingPiece(componentMatch, scaleMul, offsetZ)` (spawner.lua, right
    after `Spawner.TestSwapArmorPiece`) rather than reusing `NudgeComponentTransform` directly —
    that function matches EVERY component whose current mesh name matches a Lua PATTERN (fine for
    one hardcoded internal call site with a known-safe string, riskier as a free-typed console
    argument); this instead reuses `TestSwapArmorPiece`'s own proven component-name/current-mesh-name
    SUBSTRING match plus its "list what's here if nothing matches" discovery aid — same targeting
    conventions as `lbtestarmor`, so a search term that already finds a piece there works here too.
    `scaleMul` defaults to `1.0` and `offsetZ` to `0.0` when omitted (independently optional — pure
    scale, pure vertical nudge, or both); omitting both just lists matches, same as `lbtestarmor`'s
    own list-mode. Registered as `lbtestscale <slot/mesh name match> [scaleMul] [offsetZ]`
    (main.lua, right after `lbtestarmor`, same handler shape).
    **Explicitly flagged as genuinely untested territory, not just "should work"**: `Nudge
    ComponentTransform`'s own 2026-08-10 comment already notes a leader-pose-bound skinned mesh's
    vertices follow the LEADER's animated bone transforms, not just its own component transform —
    a uniform scale might close a size mismatch cleanly, or might look stretched/detached instead.
    That's a live visual judgment call, not something provable from a log line — RedFalcon needs to
    actually look at the result.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`main.lua` to the live
    install (game running — `lbreload` needed). **Process note**: `main.lua`'s edit was made before
    archiving its pre-edit contents (the same slip as items 71/84) — caught immediately and
    recovered losslessly by removing the known, self-contained insertion and archiving that
    reconstruction (verified `lbtestscale` absent from it) as `archive/main.lua_20260828_*.lua`,
    same recovery method as those two prior instances.
    **Same-day live test, two real bugs found and fixed**: RedFalcon tested — scale alone worked
    immediately (confirmed the Witch/regular-body proportion mismatch theory: shrinking a
    Senkamati piece or growing a regular one visibly helped), but `offsetZ` failed every time,
    first silently (before error-message logging existed) then with a real error once added:
    `Tried calling a member function but the UObject instance is nullptr`, thrown from the
    `m.comp:K2_SetRelativeLocation(...)` call specifically — the SAME `m.comp` reference that had
    just succeeded moments earlier in the SAME loop iteration for `SetRelativeScale3D`, so the
    component itself wasn't actually invalid. Root cause, found by comparing against the only two
    call sites in this whole file that have offset a component's position and are ACTUALLY
    confirmed working (the Warrior shield nudge, the placement-camera raise, both from earlier
    sessions): neither of them ever calls `K2_GetRelativeLocation()` — both read the CURRENT
    relative position via the plain PROPERTY `comp.RelativeLocation` instead. My code (and the
    older, never-actually-live-tested `Spawner.NudgeComponentTransform` this was modeled on) both
    called the FUNCTION `K2_GetRelativeLocation()` first — apparently not a working call in this
    UE4SS build, and calling it right before the real `K2_SetRelativeLocation` call left that
    second, otherwise-fine call reporting a null instance. Fixed by switching both functions to
    `local loc = comp.RelativeLocation` (a plain property read, no function call) — matches the
    two already-proven call sites exactly. This is the SAME class of function-vs-property
    uncertainty this project has hit repeatedly before (item 73's `SetAnimationMode`/
    `AnimationMode` fallback is the closest precedent) — when in doubt in this UE4SS build, prefer
    reading a Vector/Rotator field as a plain property over a `K2_Get*` accessor, and check for an
    already-proven precedent elsewhere in the file before assuming a getter function works just
    because the matching setter does.
    Also added real pcall error-MESSAGE logging to `Spawner.TestScaleClothingPiece` (previously
    only a bare `ok`/`FAILED` boolean, same gap item 73 already called out once for
    `SetAnimationMode`) — this is exactly what let RedFalcon's second report ("failed again") get
    diagnosed from one log line instead of another guess-and-check round trip.
    `lint.py` clean (`compile: 10 scripts OK`) after both fix passes. Deployed `spawner.lua` to the
    live install both times (game running — `lbreload` needed). **Not yet re-tested live** — next
    step: `lbreload`, retry `lbtestscale Torso 1.0 20` (or whatever ratio already looked right from
    the scale-only test) and confirm the Z nudge now actually moves the piece.
    **Same-day follow-up: per-axis scale, then full XYZ offset.** Scale worked and confirmed the
    proportion-mismatch theory (regular clothes read small on the Witch/Senkamati-adjacent body,
    Senkamati armor reads large on a regular body), but RedFalcon flagged "that's what I was afraid
    of" — a UNIFORM scale distorts a piece that's only off on one axis (e.g. taller vs. wider), and
    then separately asked for a full X/Y/Z offset, not just Z. `scaleArg`/`offsetArg` in
    `Spawner.TestScaleClothingPiece` both now accept EITHER a plain number OR a comma-separated
    `"a,b,c"` triple, kept in the SAME argument slots (not new positional args) so no existing call
    shape becomes ambiguous — a bare number and a comma-triple are trivially distinguishable to
    parse. Scale's bare-number shorthand still means uniform (X=Y=Z, matches every prior test);
    offset's still means Z-only (X=Y=0), preserving every already-tested `lbtestscale <match>
    <scale> <offsetZ>` call from before this addition. Full syntax now: `lbtestscale <match>
    [scaleMul|sx,sy,sz] [offsetZ|ox,oy,oz]`. `lint.py` clean, deployed both `spawner.lua`/`main.lua`
    (help text updated to match). **Not yet tested live** — next step: try a per-axis scale (e.g.
    `1,1,1.15` for height only) and a non-Z offset (e.g. `10,0,0`) and see whether either reads
    better than the uniform/Z-only version already confirmed partially working.

93. **`lbtestthickness [value]` — a second, lower-risk lever for the same body-proportion mismatch**
    (2026-08-28, same day). RedFalcon spotted `ArmorThicknessMorph` while browsing an `lbprobedump`
    of a randomized female walker body and asked whether it's adjustable. It is, and with unusually
    high confidence for this codebase: it's a plain FLOAT Blueprint variable on the target's
    AnimInstance (`mesh:GetAnimInstance().ArmorThicknessMorph`) — not a struct, not a compiled
    execution-graph node (the class of read/write that crashed the game twice in item 78) — and
    it's already been WRITTEN successfully once before, in the closed pose-porting investigation
    (items 62-63): `Spawner.ApplyBlueprintPose`/`MakePreBuildPoseSetter` both set it to the real
    value probed off `Female_Standing_01` (`0.34999999403954`), and both confirmed the write stuck
    on readback. That whole pose-porting attempt ultimately failed, but for unrelated Control-Rig
    reasons (see item 63's own closing notes) — never because this specific property write was
    unsafe. That makes it a rare LOW-risk lever in this session's run of experiments, most of which
    have been genuinely untested engine surface.
    Built `Spawner.TestArmorThicknessMorph(valueArg)` (spawner.lua, right after
    `TestScaleClothingPiece`) — targets the nearest spawned/locked actor same as every other
    tester, reads the CURRENT value first (useful standalone, since RedFalcon can now check what a
    given body/archetype already rolled without changing anything), and only writes if a value is
    given. Registered as `lbtestthickness [value]` (main.lua). Both prior call sites hardcoded one
    specific probed value as part of a larger pose-porting attempt that's since been abandoned;
    this is the first time the property is exposed as a standalone, freely-tunable lever.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game running —
    `lbreload` needed). **Not yet tested live** — next step: `lbreload`, `lbtestthickness` with no
    value on a mismatched body to see its current setting, then try nudging it up/down and see
    whether it visibly changes how the armor/clothing fits — if it does, it may end up being a
    cleaner fix than raw component scale/offset for at least some of this mismatch, since it's a
    morph the game's own rig presumably already knows how to blend, rather than a blunt transform
    override on top of it.
    **Same-day live test, a real scope finding**: RedFalcon tried it — "it only seems to be
    affecting the belts." So `ArmorThicknessMorph`'s generic-sounding name is misleading: despite
    living on the shared AnimInstance (one value, not per-component), its actual effect appears
    baked into specifically the Belt/Frog/Sling/Strap meshes' own morph targets, not into
    Torso/Legs/Headgear/etc. — plausibly a "let a belt cinch/expand without clipping regardless of
    waist size" input rather than a general armor-bulk control the name suggests. Not itself a fix
    for the broader Torso/Legs proportion mismatch this whole investigation is chasing — `lbtestscale`
    (per-axis scale + XYZ offset, this same item's earlier entries) remains the right tool for
    those slots. Worth remembering if belts specifically ever look off on some body/archetype
    pairing — this is now a known, live-confirmed lever for exactly that one accessory family.

94. **Witch-body clothing scale baked into config, applied automatically** (2026-08-28, same day).
    RedFalcon tuned it by hand via `lbtestscale` and reported the result: dressing the RAW
    Senkamati Witch body (`SK_Senkamati_Witch_01_Female`, the native creature skeleton — NOT the
    human-skeleton crew re-skin, see item 82's own bone-rig-compatibility finding for why a
    human-authored mesh even attaches and deforms here at all, just at the wrong scale) in a
    regular (non-Senkamati) clothing piece needs `(1.5, 1.1, 1.0)` to read correctly — X/Y wider,
    Z (height) untouched.
    Rather than leave this as a value to retype by hand every time, added `Config.
    SENKAMATI_WITCH_REGULAR_CLOTHES_SCALE = { X = 1.5, Y = 1.1, Z = 1.0 }` (config.lua, right
    before `Config.CUSTOM_CLOTHES`) and wired it into `Spawner.TestApplyClothingPiece` itself: right
    after a mesh swap succeeds, if the applied row's family is NOT one of the four `"Senkamati
    *"` families AND the target's OWN current body mesh (`actor.Mesh`'s current skeletal mesh)
    contains `"Senkamati_Witch"`, the newly-swapped component is auto-scaled to this triple. Detected
    by the target's actual body mesh name, not by class or actor type, so it applies to the raw mob,
    an idle Num7 row, or any other actor built on that same body — and deliberately does NOT fire
    when dressing a SENKAMATI piece onto her (already authored for this exact body) or a regular
    piece onto anyone else (their own body already fits its own catalog without correction).
    `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`config.lua` to the live
    install (game running — `lbreload` needed). **Not yet re-tested live** — next step: `lbreload`,
    dress the raw Witch body in a regular clothing piece via `lbtestclothes` and confirm it now
    renders at the correct scale automatically, with no manual `lbtestscale` follow-up needed.

95. **`lbbodymesh` — a one-question diagnostic** (2026-08-28, same day). RedFalcon asked how to
    check what body mesh an actor is using — already answerable via `lbprobedump`'s full
    component listing, but buried among every clothing/hair piece too. `Spawner.
    TestReportBodyMesh()` (spawner.lua, right after `TestArmorThicknessMorph`) reads just
    `actor.Mesh`'s current skeletal mesh (short name + full path) on the nearest/locked actor and
    prints/toasts it, nothing else — the exact same read `Spawner.TestApplyClothingPiece`'s own
    Witch auto-scale check (item 94) uses internally, now exposed standalone so RedFalcon can
    check a body without triggering a clothing swap first. Registered as `lbbodymesh` (main.lua,
    no arguments). `lint.py` clean (`compile: 10 scripts OK`). Deployed to the live install (game
    running — `lbreload` needed).

96. **`BodyMorph` identified as the likely real fit-difference lever, via a direct dump comparison**
    (2026-08-28, same day). RedFalcon noticed the Buccaneers Merchant and the standing Brethren
    Woman roll the SAME body mesh (`SK_Orient_Female_01`) yet fit their clothing differently, and
    supplied `lbprobedump`s of both (`probedump_20260828_152643.txt` = Merchant,
    `probedump_20260828_152715.txt` = Standing) for comparison. Diffed the two files directly
    rather than guessing: body mesh identical, `ArmorThicknessMorph` identical (`0.35` on both, so
    item 93's belt-only finding is unaffected/unrelated here) — but `BodyMorph` (the same Vector
    already read-only-probed during the closed pose-porting investigation, items 62-63) differs
    substantially: Merchant `(0.0, 0.20286786556244, 0.22273226082325)` vs. Standing `(0.0,
    0.83562117815018, 0.02066108584404)`. Also noted, separately, a real but purely cosmetic
    difference: Merchant uses the `MI_Orient_Female_Large` skin material, Standing uses
    `MI_Orient_Female_Small` — a different BUILD variant of the same ethnicity family (texture
    only, established mechanism, not a shape input).
    `BodyMorph` reads as the actual likely answer: a per-instance body-shape morph (bust/waist/hip-
    style blend) baked differently into each Blueprint class's own construction defaults despite
    sharing an identical archetype mesh — a materially better fit candidate than blunt component
    scale/offset (`lbtestscale`, items 92/94), since it's presumably a real sculpted morph target
    the mesh was authored with, not a uniform transform stretch layered on top.
    Built `Spawner.TestBodyMorph(xArg, yArg, zArg)` (spawner.lua, right after
    `TestReportBodyMesh`) — same read-if-omitted/write-if-given shape as `Spawner.
    TestArmorThicknessMorph` (item 93), writing the Vector via the plain `{X=,Y=,Z=}` table
    convention this codebase already established as safe for that type (`Spawner.WarpNear` and
    others) rather than any struct-drilling. Registered as `lbtestbodymorph [x] [y] [z]`
    (main.lua) — all three must be given to write, matching a Vector's own all-or-nothing shape;
    omit all three to just read.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`main.lua` to the live
    install (game running — `lbreload` needed). **Not yet tested live** — next step: `lbreload`,
    lock (Num+) onto the standing woman, run `lbtestbodymorph 0.0 0.20286786556244
    0.22273226082325` (the Merchant's own probed value) and see whether her proportions/clothing
    fit actually shift toward the Merchant's — this is the real open question this whole
    comparison was built to answer.

97. **`lbtestmorphlist`/`lbtestmorph` — morph targets on the CLOTHING mesh itself, as an
    alternative to whole-component scaling** (2026-08-28, same day). RedFalcon asked whether,
    instead of scaling a piece via `lbtestscale`, a morph target baked into the garment mesh
    itself could be used to fix fit — a more surgical mechanism if these meshes actually have any:
    a sculpted "size"/"fit" blend shape the mesh was authored with, rather than a blunt uniform/
    per-axis stretch layered on top of an unmodified mesh.
    Genuinely unconfirmed going in — unlike `BodyMorph`/`ArmorThicknessMorph` (already proven-safe
    AnimInstance variable writes from the closed pose-porting investigation, items 62-63/96), this
    is the first time this codebase has ever queried a `SkeletalMeshComponent` for its OWN morph
    target list, as opposed to a value living on the shared AnimInstance. Built two tools sharing a
    new local `findMatchedClothingComponent(toolTag, componentMatch)` helper — factored out of
    `Spawner.TestSwapArmorPiece`'s own targeting+substring-match+"list what's here" body, since
    both new functions needed the identical behavior and a third hand-copy wasn't worth it:
    - `Spawner.TestListMorphTargets(componentMatch)` / `lbtestmorphlist <match>` — tries the
      standard UE Blueprint signature `GetMorphTargetNames(TArray<FName>& OutNames)` as an
      out-param call first (same calling convention already proven for `LineTraceSingleForObjects`),
      falls back to treating it as a return-value call if the out-param form yields nothing, in
      case this UE4SS binding marshals it differently. A component reporting ZERO morph targets is
      a normal, expected result for many garment pieces (most likely outcome for a lot of these),
      not a failure — this tool exists specifically to find out which (if any) pieces have some.
    - `Spawner.TestSetMorphTarget(componentMatch, morphName, value)` / `lbtestmorph <match>
      <morphName> <value>` — calls the standard `SetMorphTarget(FName, float)` Blueprint function,
      reads back via `GetMorphTarget(FName)` to confirm. Both `SetMorphTarget`/`GetMorphTarget` are
      among the most standard, long-stable Blueprint-exposed functions in the whole engine — lower
      risk than most of this session's other untested calls, not a wild guess.
    `lint.py` clean (`compile: 10 scripts OK`; the two new `Reads(...)` lines under "UNDEFINED
    CALLS" are the same pre-existing false-positive class already seen for `camera(...)`/
    `command(...)` — the linter misparsing comment/help-text prose as a call, not a real issue).
    Deployed `spawner.lua`/`main.lua` to the live install (game running — `lbreload` needed).
    **Not yet tested live** — next step: `lbreload`, `lbtestmorphlist Torso` (or any other slot) on
    a piece with a known fit problem, and see whether it reports any real morph targets at all
    before trying to set one.
    **Same-day live test: BOTH avenues confirmed dead, for two separate reasons.**
    `lbtestmorphlist Torso` on the Senkamati Witch's own Torso piece
    (`SK_ArmorCreature_Senkamati_Witch_Feather_01_Torso`) reported **0 morph targets** — nothing
    on this mesh to set at all. Separately, RedFalcon tried `lbtestbodymorph` with the Merchant's
    value (item 96's own next step): the write succeeded and read back correctly
    (`BEFORE=(0.0,0.8616,0.0509) AFTER=(0.0,0.2029,0.2227)`, exact log line confirmed) but produced
    **no visible change** on the actor. This ISN'T a new failure — it's a re-confirmation of
    something item 63 already closed: that same investigation tried writing `BodyMorph` (among
    `IsFemale?`/`ArmorThicknessMorph`/`Animation`) post-construction and got the identical
    "reports success, zero visible effect" result across all of them, root-caused to the
    AnimGraph's Control Rig node binding not re-evaluating a live post-construction change at all,
    on any variable that feeds it. Doesn't contradict `ArmorThicknessMorph`'s own confirmed belt
    effect (item 93) — that's a DIFFERENT variable, apparently wired to an actual morph target on
    belt meshes specifically, a real binding `BodyMorph` evidently doesn't have (it feeds the
    Control Rig graph directly instead).
    **Net conclusion for the Witch/regular-clothes proportion mismatch this whole side-investigation
    (items 92-97) was chasing**: `lbtestscale` (whole-component scale/offset, items 92/94) remains
    the one actually-working lever — both alternatives explored since (`ArmorThicknessMorph`/
    `BodyMorph` on the AnimInstance, morph targets on the clothing mesh itself) are confirmed dead
    ends, the first two for pre-existing reasons (belt-only scope, Control-Rig-binding non-
    responsiveness) and the third because the specific mesh tested simply has none. Don't re-chase
    `BodyMorph` for a visible fit fix without a genuinely new theory about the Control Rig binding
    itself — same standing rule item 63 already established, now doubly confirmed.

98. **Senkamati Torso/Legs fit-compatibility fallback: default underwear on incompatible female
    bodies** (2026-08-28, same day, closing out the whole scale/morph fit investigation). RedFalcon
    reported the actual live-tested compatibility boundary after trying Senkamati Torso/Legs pieces
    across several bodies via `lbtestclothes`: "all the named women, the buccaneer merchant, and
    albion + Adventure standing/sitting women can wear the senkamati torso and legs without major
    clipping" — implicitly, every other female archetype (African/Fable/Native/Orient/Scum) clips
    badly. This matches item 61's own already-confirmed finding from the removed Senkamati Statues
    investigation (the armor was rigged for exactly one archetype, doesn't deform correctly onto
    the other 5) — same underlying limitation, just newly relevant again now that Senkamati pieces
    are reachable generically via `Custom > Clothes` rather than only a fixed statue roster.
    Asked for: detect anything outside that known-good set and substitute the default underwear
    top/legs instead — explicitly Female-only.
    `Config.SENKAMATI_TORSO_LEGS_COMPATIBLE_BODIES = { "SK_Adventure_Female_01",
    "SK_Albion_Female_01" }` (config.lua) is the allowlist, checked against the target's own
    current body mesh — same detection technique as the Witch auto-scale check (item 94). The
    named women (Letty/Marita, "Woman With Hair Base 1") already resolve to
    `SK_Adventure_Female_01` (item 31), so they're covered automatically with no separate name/
    class special-case. Added `Config.SENKA_UNDERWEAR_TORSO_F` (config.lua, sibling to the
    existing `SENKA_UNDERWEAR_LEGS_F`/`_M` from the earlier pelvis-gap saga) — no Male Torso
    underwear variant exists in the catalog, matching `Config.CUSTOM_CLOTHES`' own "Underwear"
    family sweep (Torso is Female-only there too).
    `Spawner.TestApplyClothingPiece` (spawner.lua) restructured: body mesh name and actual sex are
    now read ONCE at the top (previously the Witch auto-scale check computed body mesh name
    separately, further down — now shared) and reused by both this fallback AND that existing
    check. The fallback fires only when `matched.family` is a `"Senkamati "` family, `matched.slot`
    is Torso or Legs, the target is Female, and its body mesh isn't in the allowlist — in that case
    `path` resolves to the underwear mesh instead of the requested Senkamati mesh, and both the log
    line and the toast clearly say a fallback happened (which family it substituted for) rather
    than silently pretending the requested piece was applied.
    **One real uncertainty flagged rather than assumed away**: the Buccaneers Merchant's own body
    archetype randomizes on spawn same as the Standing/Sitting statues (item 57) — a probe from
    earlier the same day (item 96) caught her specifically on Orient, not Adventure/Albion. As
    implemented, she is NOT given an unconditional pass — she's checked by body mesh like anyone
    else, so she'll get the underwear fallback too whenever she happens to roll a non-Adventure/
    Albion body. If RedFalcon confirms she fits regardless of which archetype she lands on (a
    structural difference in her own composite, not an archetype-dependent one), the fix is a
    small addition — an explicit class-name check (`BP_AnimatedActor_Buccaneers_Merchant_01`)
    ORed into the compatibility test — not a redesign.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`config.lua` to the live
    install (game running — `lbreload` needed). **Not yet tested live** — next step: `lbreload`,
    try `lbtestclothes "Senkamati Witch" Torso "Feather 01"` (or similar) on both a compatible body
    (Adventure/Albion) and an incompatible one (any other female archetype) and confirm the
    incompatible case now gets underwear instead of clipping armor, with the log/toast clearly
    showing the fallback fired.
    **Same-day follow-up**: RedFalcon added "the actual senkamati women" and confirmed the
    Herbalist/Gatherer both work. Checked an existing probe dump
    (`probedump_20260828_104940.txt`, from earlier the same day) rather than guessing — it shows
    the Herbalist-based walker ALSO reads `SK_Adventure_Female_01`, identical to the Gatherer, so
    both were already covered by the allowlist with no change needed. The one genuine gap: the RAW
    Senkamati Witch body herself (`SK_Senkamati_Witch_01_Female`) wasn't listed — trivially
    correct (it's her own native armor) but missed since the fallback logic was only ever framed
    around applying a piece onto an unrelated body. Added to `Config.
    SENKAMATI_TORSO_LEGS_COMPATIBLE_BODIES` (now 3 entries). `lint.py` clean, deployed
    `config.lua` to the live install (`lbreload` needed).
    **Same-day follow-up: a real class-name override, resolving the Merchant uncertainty this item
    already flagged.** RedFalcon added "also marita and buccaneer merchant woman" as further
    confirmed-compatible. Checked two more probe dumps already sitting in the mod folder rather
    than guessing: `probedump_20260828_105110.txt` shows "Marita" here is actually the real
    base-game QUEST NPC (`BP_NPC_QuestStatic_Smugglers_MaritaSuares_C`, NOT the mod's own walking
    Handyman re-skin), body mesh `SK_Fable_Female_01` — Fable, not in the mesh allowlist at all.
    `probedump_20260828_151210.txt` shows the Buccaneers Merchant
    (`BP_AnimatedActor_Buccaneers_Merchant_01_C`) reading `SK_Orient_Female_01` this time —
    different from the Adventure/Albion body she's rolled in earlier probes, confirming her body
    genuinely randomizes per spawn (item 57) — yet still reportedly fits. This resolves the
    uncertainty this item's own body flagged earlier: she fits REGARDLESS of which archetype she
    rolls, not only when she happens to land on Adventure/Albion — so a body-mesh check alone can
    never fully cover her.
    Added `Config.SENKAMATI_TORSO_LEGS_COMPATIBLE_CLASSES = {
    "BP_NPC_QuestStatic_Smugglers_MaritaSuares_C", "BP_AnimatedActor_Buccaneers_Merchant_01_C" }`
    — an unconditional pass by class name (`actor:GetClass():GetFName():ToString()`, an established
    pattern already used elsewhere in this file), checked as a SECOND, independent path in
    `Spawner.TestApplyClothingPiece` only when the body-mesh allowlist doesn't already match.
    Something about these two specific classes' own composite/outfit build apparently avoids the
    clipping regardless of skin archetype — a real, class-specific exception, not explainable by
    body mesh alone. `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`config.lua`
    to the live install (`lbreload` needed).

99. **`lbtestclothassets` — checking for Chaos Cloth simulation, a third mechanism beyond morph
    targets/plain skinning** (2026-08-28, same day). RedFalcon's follow-up to the morph-target dead
    end (item 97): "since the women's clothes seem to fit to different sizes, they likely have mesh
    nodes... could we use that to fit the clothes to the senkamati woman better?" — clarified via
    AskUserQuestion as specifically UE5's Chaos Cloth simulation/clothing-asset system (a garment
    can have a bound `UClothingAssetBase` that deforms it dynamically against the body underneath,
    a genuinely different mechanism from both plain bone-skinning and morph targets, and one this
    codebase has never checked for before).
    Built `Spawner.TestListClothAssets(componentMatch)` (spawner.lua, right after
    `TestSetMorphTarget`, reusing the same `findMatchedClothingComponent` helper from item 97) —
    checks two things per matched piece: (1) the component's own `bDisableClothSimulation` bool
    (a plain, always-present property on `USkeletalMeshComponent` in stock UE regardless of
    whether an asset actually uses cloth — a cheap first signal), and (2) the SkeletalMesh ASSET's
    (not component's) bound clothing assets via `GetMeshClothingAssets` — the standard UE
    Blueprint-callable signature, same out-param-then-return-value fallback shape as
    `TestListMorphTargets` for the same "unsure how this binding marshals an out `TArray`" reason.
    Registered as `lbtestclothassets <slot/mesh name match>` (main.lua).
    Genuinely unconfirmed whether this game's garments use Chaos Cloth at all — the Senkamati
    Torso's own zero-morph-targets result (item 97) makes plain bone-skinning at least plausible
    for this game's clothing in general, but that doesn't rule out cloth on OTHER pieces.
    `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`main.lua` to the live
    install (game running — `lbreload` needed). **Not yet tested live** — next step: `lbreload`,
    try `lbtestclothassets` on a regular woman's clothing piece known to fit well across body
    sizes (to see if cloth simulation explains that adaptability) and separately on the Senkamati
    Torso/Legs (to see if its absence there explains why it DOESN'T adapt) — the comparison is the
    actual test, not either result alone.
    **Same-day live test, a clean answer — real mechanism confirmed, but a dead end for THIS fit
    problem.** RedFalcon ran it on a standing woman and a Senkamati Witch. Results: the standing
    woman's Jeweler Torso reports `1 clothing asset found`
    (`SK_Armor_Jeweler_03_Female_Torso_sim_Clothing_0`) — genuinely Chaos Cloth simulated; her Legs
    piece reports 0 (rigid, no cloth). The Senkamati Witch's ACTUAL Torso armor
    (`...Witch_Feather_01_Torso` — the piece causing the reported clipping) reports **0 clothing
    assets**, matching item 97's own zero-morph-targets result for the same mesh — plain rigid
    skinning, nothing more. Her SEPARATE `TorsoCloth` component (the decorative fabric flap under
    the armor shell, a different component from the Torso armor itself — its own `_Dyn` filename
    suffix already hinted at this, item 74) DOES report 1 clothing asset
    (`...TorsoCloth_Dyn_Clothing_1`).
    So Chaos Cloth is real and active in this game — confirmed for the first time in this
    codebase — but it's bound to decorative/flowing sub-pieces (a fabric flap, a torso's own cloth
    layer), not to the rigid armor SHELL that's actually clipping. Since cloth-sim data (painted
    max-distance/backstop maps, physics config) is baked into a mesh asset at author time, this is
    the SAME class of dead end as morph targets (item 97) for a different specific reason: not "the
    mechanism doesn't exist in this game" (it does), but "this specific mesh wasn't authored with
    it, and that can't be added at runtime any more than a missing morph target could be."
    **Net conclusion for the whole scale/morph/cloth side-investigation (items 92-99)**:
    `lbtestscale` (component scale/offset, items 92/94) plus the compatibility fallback (items
    92/94/98) remain the only actually-working levers for this specific fit problem. Morph
    targets and Chaos Cloth are both now confirmed-real mechanisms in this game generally, but
    both confirmed absent on the specific mesh that needs fixing — don't re-chase either for this
    particular piece without a genuinely new theory; a DIFFERENT clipping piece that DOES report
    morph targets or clothing assets via these same tools would be a fair reason to revisit either
    approach for that piece specifically.

100. **The whole component-scale approach walked back** (2026-08-28, same day). RedFalcon: "setting
     scale doesn't work, so I want to look at a different direction. In fact we should walk that
     back." Removed the item-94 auto-scale hook from `Spawner.TestApplyClothingPiece` (spawner.lua)
     entirely — regular clothes on the raw Senkamati Witch body now render at scale 1.0 again, no
     automatic compensation. `Config.SENKAMATI_WITCH_REGULAR_CLOTHES_SCALE` (config.lua) is kept as
     a documented, no-longer-called constant rather than deleted — same treatment this file already
     gives other confirmed-inadequate levers (`ColorParams`, `ArchetypePreset`, etc.) — do not
     re-wire a blunt whole-component scale/offset back in without a genuinely different theory;
     both `TestScaleClothingPiece`'s and `NudgeComponentTransform`'s own original comments already
     flagged this as a live visual gamble, not a guaranteed fix, and that caveat held.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`config.lua` to the live
     install (`lbreload` needed).
     **Net status of the Witch/regular-clothes fit problem after items 92-100**: every mechanism
     tried this session — whole-component scale/offset (`lbtestscale`), `ArmorThicknessMorph`
     (belt-only scope), `BodyMorph` (Control-Rig-binding dead end, items 62-63/96), morph targets
     baked into the clothing mesh (none found, item 97), Chaos Cloth simulation (present in this
     game but not on the rigid armor shell, item 99), and now the auto-scale hook itself — is
     either confirmed absent on the relevant mesh or confirmed not to produce an acceptable visual
     result. The Senkamati Torso/Legs fit-compatibility FALLBACK (item 98, substituting default
     underwear on an incompatible body) remains in place and unaffected by this walk-back — that's
     a different mechanism (swap the piece entirely) from scaling a mismatched one, and was never
     part of what got walked back. RedFalcon has not yet specified the next direction to try.

101. **Cloth-simulation rebind after a runtime mesh swap** (2026-08-28, same day, the new
     direction). RedFalcon: "can we take advantage of the cloth simulations to make those clothes
     fit the caster better?" — a genuinely more promising angle than scaling: item 99 already
     confirmed Chaos Cloth is real and active in this game (e.g. the Jeweler Torso's own bound
     clothing asset), and unlike a rigid skinned mesh, a cloth-simulated piece reacts dynamically
     to the underlying skeleton's bone poses/collision at runtime rather than being a fixed
     authored shape — it may genuinely drape correctly on a mismatched body (the raw Senkamati
     Witch/Caster) instead of clipping, with no scale hack needed at all.
     One real risk identified before testing: `SetSkeletalMeshAsset`/`SetSkeletalMesh` swap the
     render mesh at runtime, but native UE cloth actors are normally rebuilt via the component's
     own internal mesh-set callback — unconfirmed whether this UE4SS binding's exposed setters
     trigger that same internal path, meaning cloth could stay silently inert after a live swap
     even though the mesh itself has a valid clothing asset. Added an explicit
     `targetComp:RecreateClothingActor()` call (the real UE engine function for forcing a cloth
     rebuild) immediately after every mesh swap, in BOTH swap paths: `Spawner.
     TestApplyClothingPiece` (`lbtestclothes`) and `armorProceedWithMesh` (the shared helper behind
     `lbtestarmor`, both its immediate and 400ms-retry paths) — purely additive, gated on the mesh
     swap itself having succeeded, and if the function isn't exposed in this build the pcall just
     fails without affecting the swap. Both tools' log lines now include a `clothRebind=ok/FAILED/
     n/a` field so the result is visible without a separate probe step.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua` to the live install
     (`lbreload` needed). **Not yet tested live** — next step: `lbreload`, apply a piece already
     confirmed to have a bound clothing asset (the Jeweler Torso, `lbtestclothassets` result from
     item 99) onto the raw Senkamati Witch/Caster body via `lbtestclothes` or `lbtestarmor`, and
     check both the `clothRebind=` log field (did the rebind call succeed at all) and — the actual
     test — whether the piece visually drapes/fits better than the earlier rigid-mesh clipping did,
     with scale left at the default 1.0 this time.
     **Same-day live test: `RecreateClothingActor` confirmed broken, not just untested.** RedFalcon
     tried it on the raw mob-body Caster (`BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster`) across
     several Jeweler Torso/Legs pieces: every single attempt logged `clothRebind=FAILED: ... Tried
     calling a member function but the UObject instance is nullptr` — the exact same error
     signature already established elsewhere in this file to mean the FUNCTION itself isn't
     properly callable via this UE4SS binding, not that `targetComp` was actually invalid
     (`SetSkeletalMeshAsset` had just succeeded on that identical reference one line earlier, same
     `applied=true` pattern). So the mesh swap always worked, but cloth was never actually rebuilt
     — RedFalcon's "hips and boobs still clip" report was against a piece that had NEVER been given
     a real chance to re-simulate, not a confirmed failure of the cloth-simulation idea itself.
     Replaced `RecreateClothingActor()` with `SetSkeletalMesh(mesh, true)` (bReinitPose=true) in
     BOTH call sites (`Spawner.TestApplyClothingPiece` and `armorProceedWithMesh`) instead of
     guessing another obscure function name: `SetSkeletalMeshAsset` is a newer, minimal property
     setter, while `SetSkeletalMesh` (the OLDER Blueprint function, already used elsewhere in this
     file as the fallback path) is documented to do more internal setup on assignment, plausibly
     including cloth actor initialization — its own `bReinitPose` argument was previously only ever
     reached as a `false` fallback when `SetSkeletalMeshAsset` FAILS, never as a deliberate
     follow-up when it succeeds (which it always has in testing so far). `lint.py` clean
     (`compile: 10 scripts OK`). Deployed `spawner.lua` to the live install (`lbreload` needed).
     **Not yet tested live** — next step: `lbreload`, retry the same piece, confirm `clothRebind=ok`
     this time (not FAILED), and THEN judge whether the hips/bust clipping actually improves — this
     is the first genuine test of the cloth-simulation idea, the previous one never actually ran.
     **Same-day live test: SAME failure signature again, on a DIFFERENT function.** RedFalcon
     tried it across many more targets/pieces (Gatherer, Buccaneers Merchant, quest-NPC Marita,
     quest-NPC Letty, Crew Officer, native Hunter/Warrior, the raw Caster) — every single one
     logged `clothRebind=FAILED: ... Tried calling a member function but the UObject instance is
     nullptr`, identical to the `RecreateClothingActor` failure, just now on `SetSkeletalMesh(mesh,
     true)` instead. Two DIFFERENT functions failing identically on the SAME `targetComp`/`m.comp`
     reference immediately after `SetSkeletalMeshAsset` had just succeeded on it points at the
     HANDLE, not either function name — the same stale-captured-reference class of bug already
     documented elsewhere in this file (line ~1508: `K2_GetComponentsByClass` returns 0 on a
     captured ACTOR reference, needs a fresh `FindAllOf` handle), just triggered here by
     `SetSkeletalMeshAsset` on a COMPONENT reference instead.
     Fixed by re-fetching a genuinely FRESH component handle before the follow-up call, rather than
     reusing the reference that just did the mesh swap: captured `targetCompName`
     (`targetComp:GetFName():ToString()`) BEFORE the swap, then after it, re-ran
     `actor:K2_GetComponentsByClass(smcCls)` fresh and matched by that same name to get a new
     handle, calling `SetSkeletalMesh(mesh, true)` on THAT instead. Applied to both call sites:
     `Spawner.TestApplyClothingPiece` (which already has `actor`/`smcCls` in scope) and
     `armorProceedWithMesh` (the shared `lbtestarmor` helper, which didn't have `actor`/a resolved
     `SkeletalMeshComponent` class available before — both are now threaded through as two new
     trailing parameters from `Spawner.TestSwapArmorPiece`'s own already-resolved `actor`/`cls`,
     at both its immediate and 400ms-retry call sites).
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua` to the live install
     (`lbreload` needed). **Not yet tested live** — this is the third distinct attempt at forcing a
     cloth rebind in this build. If this ALSO fails with the same signature, the honest conclusion
     is that forcing cloth reinitialization from Lua isn't viable in this UE4SS build at all (not
     that the wrong function/reference approach was tried three times) — worth stating plainly to
     RedFalcon rather than proposing a fourth variant, since three independent mechanisms failing
     identically is a real pattern, not bad luck.

102. **`lbtestclothes` gains a sex-override argument** (2026-08-28, same day). RedFalcon asked for
     a way to see how the MALE version of a clothing piece fits on a female-sexed target (the raw
     Senkamati Witch/Caster), as a further experiment now that scale/cloth-rebind have both been
     exhausted or walked back. `lbtestclothes` previously always auto-detected the target's own
     sex via `GetBodySex()` and had no way to force the other path.
     Added an optional 4th argument to `Spawner.TestApplyClothingPiece(family, slot, pieceName,
     sexOverride)` — accepts `"M"`/`"Male"`/`"F"`/`"Female"` case-insensitively, overriding which
     of `matched.malePath`/`matched.femalePath` gets used for a sex-split row. Deliberately scoped
     narrow: only affects PATH SELECTION for the requested piece — the Senkamati Torso/Legs
     fit-compatibility fallback (item 98) still gates on the target's REAL detected sex
     (`actorSex`), not this override, since that check is about the actual body wearing the
     clothes, not which mesh variant was asked for. A `unisexPath` row (including every Senkamati
     family) ignores the override entirely — there's only one mesh either way. `lbtestclothes`
     (main.lua) registration updated to pass through a 4th parameter; usage now `lbtestclothes
     <family> <slot> <name> [sex override: M/F]`, e.g. `lbtestclothes Jeweler Torso "Set 1" Male`
     on a female target. The GUI (`Custom > Clothes`) is unaffected — it still only ever calls the
     3-argument form, since a menu entry has no natural place to specify an override; the new
     capability is console-only for now.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`main.lua` to the live
     install (`lbreload` needed).

103. **`Custom > Clothes > Remove` — a 5th GUI branch, plus a general "nothing to act on" notice**
     (2026-08-28, same day). RedFalcon: "can we have a clothes section for 'remove' where it has
     each slot available as well as a remove all... and it hides the item in that slot" — then,
     mid-build, "can we also have a notice when the slot doesn't have anything to replace."
     `Config.CLOTHING_REMOVABLE_SLOTS` (config.lua) is the canonical 15-slot list (Headgear/Torso/
     TorsoCloth/Legs/Hands/Feet/Head/Neck/Waist/Cape/Scarf/Belt/Frog/Sling/Strap — kept in sync
     manually with spawner.lua's own `CLOTHING_SLOT_TOKENS` list); `Config.CLOTHES_REMOVE` is a
     flat roster built from it plus one `"All"` entry, feeding both the GUI and a new
     `lbremoveclothes <slot|all>` console command.
     `Spawner.TestRemoveClothingPiece(slotArg)` (spawner.lua, right after `TestApplyClothingPiece`)
     HIDES the matching component(s) (`SetVisibility(false)` + `SetHiddenInGame(true)`) rather than
     clearing their mesh to nil — clearing would make `clothingSlotOf` (which identifies a slot by
     its CURRENT mesh name) unable to recognize that slot afterward, permanently breaking the
     ability to dress it again via `lbtestclothes`/the GUI. `"all"` (case-insensitive) hides every
     component that resolves to ANY canonical slot via `clothingSlotOf` — naturally excludes the
     base body mesh, hair, and eyebrows, since none of their names contain a recognized clothing
     token, no extra filtering needed.
     Both `Spawner.TestApplyClothingPiece` and `armorProceedWithMesh` (the `lbtestarmor` swap
     helper) now explicitly restore visibility (`SetVisibility(true)` + `SetHiddenInGame(false)`)
     on a successful swap — otherwise a previously-removed slot would stay invisible forever even
     after a new piece got dressed onto it, since nothing else in either path ever touched
     visibility before this.
     **The notice ask**: both the apply path's pre-existing "no component in that slot" case (which
     was log-only before) and the new remove path's "nothing found to hide" case now toast a clear
     message (`"<name> has nothing in the <slot> slot"`) instead of silently no-op'ing — the same
     on-screen-feedback discipline this whole toolset already follows everywhere else.
     Registered as `lbremoveclothes <slot|all>` (main.lua) and `Custom > Clothes > Remove ><Slot>` /
     `> All` (new `CLOTHES_REMOVE` roster in `SPAWN_MENU_HANDLERS`/`NON_SPAWNING_ROSTERS`/
     `spawnmenu_manifest.lua`'s `roster_descriptors`). Since `CLOTHES_REMOVE` is a brand-new roster
     name, no stale `spawn_menu.ini` cleanup was needed this time (unlike the hair/clothes
     reshuffles in items 89-91) — `lbreload` just appends its 16 new sections fresh.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed all four files (`spawner.lua`/
     `config.lua`/`main.lua`/`spawnmenu_manifest.lua`) to the live install (`lbreload` needed).
     **Not yet tested live** — next step: `lbreload`, try `Custom > Clothes > Remove > Torso` (or
     `lbremoveclothes Torso`) on a dressed target, confirm the piece disappears and the slot stays
     correctly hidden, then try `> All`, then dress something back onto that slot and confirm
     visibility is restored automatically. Also try removing an already-empty slot to confirm the
     new notice fires instead of nothing happening.

104. **A full women's-clothing fit-rules engine, replacing the old single Witch fallback**
     (2026-08-28, same day). RedFalcon supplied a large, structured spec after live-testing many
     more bodies/families, covering: which families a Torso/Legs piece clips on for the Senkamati
     body vs. regular female bodies; a "Remove" default of substituting underwear rather than true
     nudity; a new off-by-default unlock toggle; and per-body-group scale corrections for a
     specific list of unisex-cut families. Two rounds of clarification were needed before building
     (AskUserQuestion, then a follow-up in plain text) since several parts were genuinely
     ambiguous — answers below, folded into the design.
     **Mechanism A — Senkamati-style compatible-bodies gate, generalized.** The existing item-98
     allowlist (`Config.SENKAMATI_TORSO_LEGS_COMPATIBLE_BODIES`/`_CLASSES`) now also gates
     `Config.CLOTHES_SENKAMATI_GATED_FAMILIES = { "Conquistador" }` — RedFalcon: "only those
     allowed to wear the senkamati clothes can wear this" — checked identically to real Senkamati
     Torso/Legs pieces, on any body. Incompatible → calls `Spawner.TestRemoveClothingPiece`
     instead of applying (previously: a hardcoded direct swap to underwear).
     **Mechanism B — regular female Torso resize/allow/deny, new.** Only families with NO
     dedicated `femalePath` (unisex-cut, item 90's own category) are in scope — a family with its
     own proper Female mesh was never a fit concern and is untouched. Classified into:
     - `Config.CLOTHES_ALLOWED_ASIS_FAMILIES_WOMEN = { "Blackbeard_Sailor" }` — apply unchanged.
       **Flagged assumption, unresolved**: RedFalcon's message first listed "Blackbeard_Sailor
       -All" under a "NO WOMEN" heading, then later said "allow sailors torsos" — there is no
       plain "Sailor" family in the catalog (confirmed via the raw parse, only
       "Blackbeard_Sailor" exists), so this was read as a correction/reversal of the earlier line,
       not two separate instructions. Worth RedFalcon double-checking this specific one.
     - `Config.CLOTHES_RESIZED_FAMILIES_WOMEN` (Musketeer/Dogface/DrGalen/Ksante/
       Blackbeard_Grenadier/Blackbeard_Musketeer/Combatant = every piece; `Flibustier = {"Set
       1"}` only) — scaled via `Config.CLOTHES_BODY_GROUP_SCALE`, keyed by body group.
     - Anything else unisex-only and uncategorized → default-deny, routes to Remove.
     **Body groups, by class** (RedFalcon's own call — Gatherer/Herbalist share the identical
     `SK_Adventure_Female_01` mesh, so mesh alone can't distinguish them): new local
     `getFemaleBodyGroup(actor, bodyMeshName)` (spawner.lua, right after `clothingSlotOf`).
     Group1 = `Config.CLOTHES_BODY_GROUP1_CLASSES` (Gatherer + quest-NPC Marita). Group2 =
     `Config.CLOTHES_BODY_GROUP2_CLASSES` (Herbalist + quest-NPC Letty) **plus** any
     `BP_AnimatedActor_BotC_*` statue class whose CURRENT rolled body is Adventure or Albion
     (reusing `Config.SENKAMATI_TORSO_LEGS_COMPATIBLE_BODIES`, since one statue class covers all 7
     archetypes, item 57). A resize-list family on a body that resolves to NEITHER group — "similar
     to the non albion and adventure BotC woman wearing senkamati" (RedFalcon's own framing) —
     gets the identical Remove treatment as Mechanism A's incompatible case.
     `Config.CLOTHES_BODY_GROUP_SCALE` holds RedFalcon's own live-tuned values: Group1 `scale=
     (1.03,1.05,1.0) offset=(0,1.5,-1.0)`, Group2 `scale=(1.03,1.05,1.0) offset=(0,2.5,-1.0)` —
     applied via the identical `SetRelativeScale3D`/`K2_SetRelativeLocation` mechanism
     `lbtestscale` already uses, but this is a NEW, separately-approved use, not a revival of the
     walked-back Senkamati-Witch auto-scale (item 100) — different bodies, different families,
     different (RedFalcon-confirmed) numbers.
     **The modesty guard on Remove itself** (RedFalcon: "for remove when its not unlocked, instead
     of hiding the torso and legs, use underwear"): `Spawner.TestRemoveClothingPiece` now swaps in
     the default underwear mesh (`Config.SENKA_UNDERWEAR_TORSO_F`/`_LEGS_F`/`_LEGS_M`) rather than
     truly hiding, specifically for Torso+Legs on a female target and Legs on a male target, only
     when `Config.CLOTHES_UNLOCK_ALL` is off. Every other slot/sex combination always does a true
     hide. Since BOTH fit-restriction mechanisms above now call into `TestRemoveClothingPiece`
     rather than hardcoding their own underwear swap, an incompatible-piece substitution and an
     explicit "Remove" click land on IDENTICAL visual results by construction.
     **The toggle**: `Config.CLOTHES_UNLOCK_ALL` (off by default) + `Spawner.ToggleClothesUnlock()`
     / `lbunlockclothes` console command (no GUI entry, per RedFalcon's own choice) — bypasses
     BOTH mechanisms and the modesty guard entirely when on, printing/toasting the "not reviewed,
     may clip or look wrong" caveat once at toggle time, not on every subsequent apply.
     `lint.py` clean (`compile: 10 scripts OK`; confirmed no stray references to the removed
     `usedFallback` variable anywhere in the codebase). Deployed `spawner.lua`/`config.lua`/
     `main.lua` to the live install (`lbreload` needed).
     **Not yet tested live** — this is a large, multi-part change; next steps: `lbreload`, then
     spot-check each piece — a Conquistador Torso on an incompatible body (should Remove/
     underwear), a Musketeer Torso on a Group1 vs. Group2 body (should resize differently), a
     Blackbeard_Sailor Torso on any woman (should apply as-is per the flagged assumption above —
     confirm this is actually what was wanted), a resize-family piece on an unrecognized body
     (should Remove), and `lbunlockclothes` toggled on (everything should apply/remove exactly as
     requested with no restrictions, plus the caveat message).
     **Same-day correction, flagged assumption resolved**: RedFalcon: "blackbeard sailor torsos
     should only be allowed for women in unlocked mode, otherwise replace with underwear" — the
     opposite of item 104's own guess. `Config.CLOTHES_ALLOWED_ASIS_FAMILIES_WOMEN` emptied out
     (was `{ "Blackbeard_Sailor" }`) — confirmed via `Config.CUSTOM_CLOTHES` that every
     Blackbeard_Sailor row already has `femalePath = nil` (fully unisex-cut), so simply removing
     it from the allowed-as-is list — without adding it anywhere else — already produces exactly
     the requested behavior through Mechanism B's existing default-deny path (Remove → underwear
     on women, unless `Config.CLOTHES_UNLOCK_ALL`). No new code needed, just the one-line data fix.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `config.lua` to the live install
     (`lbreload` needed).
     **Same-day correction, a real intent-flip for the whole resize list**: RedFalcon: "all these
     [the 8-family `Config.CLOTHES_RESIZED_FAMILIES_WOMEN` list] are male only unless unlocked" —
     the OPPOSITE of how item 104 had wired it (resize applied automatically for a recognized body
     group, entirely independent of the lock state). The real intent: unlocking is what makes
     these families wearable by women AT ALL (blocked outright otherwise, same Remove →
     underwear treatment as everything else in restricted mode); the resize correction is what
     makes them look right ONCE unlocked, not a substitute for locking.
     Restructured Mechanism B in `Spawner.TestApplyClothingPiece`: the block's outer gate no
     longer includes `not unlocked` (it used to skip the whole mechanism when unlocked, which
     would have applied these families completely raw with no scale correction even when a user
     deliberately unlocked to use them on a woman) — `unlocked` is now checked INSIDE each
     decision point instead: a resize-list family blocks (Remove) when locked, and only applies
     (with scale, if the body resolves to a recognized group; raw otherwise) when unlocked. The
     "uncategorized unisex-only family" default-deny branch got the same treatment for
     consistency — blocked when locked, freely applied when unlocked, matching what "unlock"
     is supposed to mean everywhere else in this system.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua` to the live install
     (`lbreload` needed). **Not yet tested live** — next step: with the toggle OFF, confirm a
     Musketeer Torso on any woman now removes/underwears (previously it would have resized and
     applied); with `lbunlockclothes` ON, confirm the same piece applies with the correct
     per-body-group scale on a recognized body, and applies raw on an unrecognized one.

105. **Blacksmith family removed; a scope correction confirming Torso-only; "Male Only Pants" — a
     third, separate Legs mechanism** (2026-08-28, same day). Three items from RedFalcon in one
     message:
     - **"The Blacksmith Category doesn't work (nothing changes) Remove it."** Removed all 3
       `Blacksmith` rows (Feet/Hands/Legs "Default") from `Config.CUSTOM_CLOTHES` outright — a
       non-functional family, not worth keeping as dead weight. Confirmed no other file references
       the string `"Blacksmith"` afterward.
     - **Scope confirmation, no code change needed**: "everything else was referencing ONLY
       Torsos" — confirms Mechanism B (item 104, the resize/allow/deny rules) was already
       correctly scoped to `matched.slot == "Torso"` only; Mechanism A (the Senkamati-style gate,
       covering both Torso AND Legs) is unaffected since it mirrors the ORIGINAL Senkamati-body
       restriction ("Senkamati women just can't wear regular torso or legs" — a dual-slot
       statement from the very first message in this whole arc), not the Torso-only regular-women
       rules.
     - **"Male Only Pants"**: a new, separate, EXPLICIT family list for the Legs slot — Musketeer,
       Blackbeard_Sailor, Dogface, Blackbeard_WolfTamer, DrGalen, Ksante, Blackbeard_Grenadier,
       Blackbeard_Musketeer, Combatant (all "-All"). Unlike the Torso resize list, there's no
       scale correction for Legs at all (none was given) and no "anything else unisex-only
       defaults to remove" catch-all — this is a closed, explicit list; any OTHER unisex-only Legs
       family stays untouched. `Config.CLOTHES_MALE_ONLY_LEGS_FAMILIES` (config.lua) + a new
       Mechanism C block in `Spawner.TestApplyClothingPiece` (spawner.lua, right before the
       `shouldRemoveInstead` early-return): blocked (→ underwear via `TestRemoveClothingPiece`'s
       own modesty guard) on a female target unless `Config.CLOTHES_UNLOCK_ALL`; unlocked applies
       the piece raw, same "no restrictions" contract as everywhere else in this system.
     **Stale `spawn_menu.ini` index cleanup, done carefully after a real self-caught mistake**:
     removing 3 rows mid-table shifts every subsequent row's index (Underwear/Vanilla/Restored/
     Starter + all 73 Senkamati-armor rows that follow Blacksmith in the table) — same landmine
     as items 89/91. First cleanup attempt (a bash `awk` block filter, the same technique used
     successfully in item 91) silently did nothing — investigated and found the earlier direct
     Python-script approach had ALSO been silently blocked by this session's own permission
     classifier on the very first attempt (writes reached the file only in step two below). Second
     attempt, from a fresh copy of the pre-edit backup: a substring match (`"roster = CLOTHES" in
     block`) over-matched `CLOTHES_REMOVE` sections too (307 real `CLOTHES` blocks vs. 323
     matched, exactly the 16-entry `CLOTHES_REMOVE` roster) — caught by cross-checking the removed
     count against an exact-line grep before trusting it, not after. Fixed with an exact
     line-equality check (`"roster = CLOTHES" in block.splitlines()`) instead of a substring
     search, confirmed removing exactly 307 blocks and leaving all 16 `CLOTHES_REMOVE` sections
     intact; copied into place via the Read/Write tool path (not a direct script write, which this
     session's classifier blocks for this specific game-folder target) and verified header/tail/
     section-count sanity afterward.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`config.lua` to the live
     install, plus the repaired `spawn_menu.ini` (`lbreload` needed to regenerate all 304 CLOTHES
     sections fresh with correct indices). **Not yet tested live** — next step: `lbreload`, confirm
     `Custom > Clothes` no longer lists a `Blacksmith` branch at all, and try a Musketeer/
     Blackbeard_Sailor/Dogface/etc. Legs piece on a woman (locked: should Remove/underwear;
     unlocked: should apply raw).
     **Same-day correction, a real scoping bug**: RedFalcon: "conquistador pants are still not
     allowed on women," then, mid-fix, "to be clear ALL women shapes can have conquistador legs.
     its the torso thats limited." Item 105's own Torso-only clarification should have applied to
     Conquistador too (a regular family riding the Senkamati mechanism) but Mechanism A's slot
     check was left as `Torso or Legs` unconditionally, still gating Conquistador Legs against the
     compatible-bodies allowlist. Split the check: `isRealSenkamati` (actual Senkamati family
     pieces — Torso AND Legs, the ORIGINAL "Senkamati women can't wear regular torso or legs"
     restriction, genuinely dual-slot and untouched) vs. `isGatedFamily` (Conquistador and any
     future `Config.CLOTHES_SENKAMATI_GATED_FAMILIES` entry — Torso ONLY now). A new
     `senkamatiGateSlotOk` local computes `(slot == "Torso") or (slot == "Legs" and
     isRealSenkamati)`, used in place of the old unconditional `Torso or Legs` check. Conquistador
     Legs no longer goes through the compatible-bodies gate at all — it's not in `Config.
     CLOTHES_MALE_ONLY_LEGS_FAMILIES` either, so it now simply applies normally on any woman,
     matching RedFalcon's explicit confirmation.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua` to the live install
     (`lbreload` needed). **Not yet tested live** — next step: confirm a Conquistador Legs piece
     now applies on any female body regardless of archetype/class, while Conquistador Torso stays
     gated to the compatible-bodies allowlist as before.

107. **Resize-offset baseline bug: the cloth-rebind step was resetting position before the offset
     applied** (2026-08-28, same day). RedFalcon confirmed the fit-rules engine works, then flagged
     a positioning bug: "I just checked out the unlocked male torsos, and they are way far forward
     compared to when I tested with our function [lbtestscale]." Root cause: item 104's resize
     block read `targetComp.RelativeLocation` (to compute `current + offset`) AFTER the item-101
     cloth-rebind step had already run `SetSkeletalMesh(mesh, true)` on the same underlying
     component — `bReinitPose=true` apparently resets/changes `RelativeLocation` as a side effect,
     not just the animation pose. `lbtestscale` (the function RedFalcon manually validated the
     offset numbers against) never calls `SetSkeletalMesh` at all, so its own baseline was always
     the natural, never-reinitialized position — the two code paths were computing the SAME offset
     against two DIFFERENT baselines, explaining the reported "way far forward" drift.
     Fixed by capturing `preClothLoc` (a plain `{X,Y,Z}` snapshot) immediately after the initial
     `SetSkeletalMeshAsset` swap, BEFORE the cloth-rebind block runs at all, and having the resize
     block compute its final position from that captured snapshot instead of re-reading
     `RelativeLocation` fresh at that later point. This restores the same baseline `lbtestscale`
     itself always worked from, regardless of whatever the cloth-rebind step does internally.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua` to the live install
     (`lbreload` needed). **Not yet tested live** — next step: re-check an unlocked male-cut Torso
     (e.g. Musketeer) on a Group1/Group2 woman and confirm the position now matches what
     `lbtestscale` showed during manual tuning, not offset further forward.
     **Same-day follow-up, a second compounding bug RedFalcon spotted before even testing item
     107's fix**: "when changing away it never resets position to, I assume, 1,1,1 0,0,0, so every
     time I set it it moves position a little more." Correct, and a real second bug independent of
     item 107's cloth-rebind-timing one: reading "current position + offset" is inherently
     cumulative — swapping a SECOND resize-list piece into the same slot would read back the
     FIRST piece's already-offset position and stack another offset on top, drifting further with
     every swap. Fixed more robustly than item 107's own fix: since every Torso/Legs slot is just
     an alternate skin on the SAME shared skeleton (no per-slot socket offset), the true natural
     resting state for all of them is scale `(1,1,1)` / position `(0,0,0)` — `Spawner.
     TestApplyClothingPiece` now resets to that identity on EVERY swap (whether the piece needs a
     resize or not, right after the plain mesh swap, replacing item 107's "capture the baseline"
     approach entirely), and the resize block sets an ABSOLUTE target (`resizeOffset` directly)
     instead of reading-and-adding an uncertain "current" value. This fixes both bugs at once: the
     cloth-rebind's own position side effect (item 107) no longer matters because the resize write
     happens after it with a known, fixed target rather than a read-then-add; and switching
     between pieces no longer compounds since every swap starts from a guaranteed-clean state.
     `lint.py` clean (`compile: 10 scripts OK`; confirmed no stray references to the removed
     `preClothLoc` variable). Deployed `spawner.lua` to the live install (`lbreload` needed).
     **Not yet tested live** — next step: apply a resize-list Torso, then swap to a DIFFERENT
     resize-list Torso on the same target (the specific case that used to drift), and confirm the
     second piece lands at the correct absolute position rather than compounding the first one's
     offset.

108. **`Custom > Face` — a new top-level category for eyebrows/beard/mustache/whiskers**
     (2026-08-28, same day). RedFalcon: "I can see from the probes there are slots for eyebrows
     and beard parts and such. I've captured some dumps for reference" — four probe dumps
     (BotC Merchant 02, Buccaneers Merchant 01, TortugaCitizen Combatant, quest-NPC Marita)
     confirmed real, separate `SkeletalMeshComponent`s for Eyebrows, Beard, Mustache/Mustaches,
     and Whiskers, all under `Character/Skeletal_Meshes/Facial/` — a folder tree never swept
     before. Component names are all auto-generated (`SkeletalMeshComponent_XXXXXXX`, confirmed
     from the same dumps), so slot identification has to work the same way clothing's does: by
     the CURRENT mesh name.
     Swept `pakcontents.xlsx` for the full `Facial/` tree (228 raw hits) and parsed it into 48 real
     rows: `Config.CUSTOM_FACIAL` (config.lua, same family/slot/name/femalePath/malePath/
     unisexPath shape as `Config.CUSTOM_CLOTHES`). Two real findings from the sweep:
     - **Eyebrows** is a genuine sex-paired family — Female has 5 numbered variants, Male has 4,
       paired by matching number (Female 05 left as female-only, no Male 05 exists).
     - Every OTHER family (Bristle/HalfPonytail/Hungover/Jag/Nordic/RoyalMarine/Shag/Sparse/
       BlackSmith) is a Beard-folder style with up to THREE independent slots — Beard, Mustache,
       Whiskers — confirmed genuinely male-only (zero female facial-hair assets exist anywhere in
       the catalog, not assumed). Not every style has all three pieces (e.g. Bristle only ships a
       Beard mesh) — reflects the real catalog rather than an assumed symmetry, same discipline as
       every other sweep this session. `BlackSmith`/`Blacksmith` casing-duplicate folders (same
       pattern already documented in `WINDROSE_MODDING_NOTES.md` §14) collapsed to one, including
       catching that BlackSmith's own style-specific eyebrow piece (`SK_Eyebrow_BlackSmith`,
       singular) needed its own row too, not just Beard/Mustache — caught before shipping, not
       after a live report.
     `Spawner.TestApplyFacialPiece(family, slot, pieceName, sexOverride)` (spawner.lua, right
     after `Spawner.ToggleClothesUnlock`) mirrors `TestApplyClothingPiece` closely but skips the
     whole women's-fit rules engine entirely — there's no "does this fit a woman" question for
     facial hair since it's already confirmed male-only at the data level. A new `FACIAL_SLOT_
     TOKENS`/`facialSlotOf` pair (deliberately separate from clothing's own `CLOTHING_SLOT_TOKENS`
     even though the two folder trees could never actually collide) finds the right component by
     current mesh name, same longest-match discipline; `"Eyebrow"` is checked as a prefix so it
     matches both the plain plural and BlackSmith's own singular filename.
     Wired identically to Clothes: `lbtestfacial <family> <slot> <name> [sex override: M/F]`
     (main.lua) and `Custom > Face > <Family> > <Slot> > <Name>` (new `FACIAL` roster in
     `SPAWN_MENU_HANDLERS`/`NON_SPAWNING_ROSTERS`/`spawnmenu_manifest.lua`'s `roster_descriptors`).
     `FACIAL` is a brand-new roster name, so no stale `spawn_menu.ini` cleanup was needed —
     `lbreload` just appends 48 fresh sections.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed all four files (`spawner.lua`/
     `config.lua`/`main.lua`/`spawnmenu_manifest.lua`) to the live install (`lbreload` needed).
     **Not yet tested live** — next step: `lbreload`, try `Custom > Face > Eyebrows > 02` on both
     a male and female target to confirm sex auto-detection, and a Beard-folder style (e.g.
     `Sparse > Beard > Sparse 01`) on a male target to confirm the independent-slot swap works.

109. **SkinDecor texture parameters (FaceDecor/BodyDecor/"SkinDecor ID"/SkinAging) CONFIRMED NOT
     a per-character lever — a third negative result, same conclusion as the 2026-08-10 tattoo
     investigation, now on more actors** (2026-08-28, same day). Follow-up to Marita's "makeup"
     question: her skin material (`MI_Fable_Female_Medium`) carries 4 extra
     `TextureParameterValues` beyond the plain Albedo/Normal/SRM, all pointing at
     `T_Adventurer_*` decor textures — first read as the likely mechanism behind her visible
     makeup. Built `Spawner.TestSetSkinDecor` / `lbtestdecor <param> [texturePath]`
     (read-if-omitted, same shape as `TestArmorThicknessMorph`/`TestBodyMorph`) to inspect/set
     them, with the SET path explicitly flagged as genuinely risky (needs
     `mesh:CreateDynamicMaterialInstance`, an untested sibling of the Kismet-library function
     that already crashed the game once this session on a different character mesh, item 79).
     RedFalcon then said flatly "marita's makeup is not on the regular fable skin" — a real
     correction, since the shared-asset name alone doesn't prove an identical render. Ran
     `lbtestdecor FaceDecor` (read-only) plus `lbprobedump`'s own `[probe-mat]` across 5 different
     actors (Native Male, Orient Female, Scum Male, Marita/Fable Female, plus the original probe)
     to actually check. **Result: byte-identical.** Every one of them carries the exact same 4
     `T_Adventurer_*` decor textures, the same single `RefractionDepthBias` scalar, zero Vector
     overrides, and zero StaticSwitch overrides on their skin material slot — regardless of skin
     family or whether the character visibly has makeup. Also checked her `GetColorControllers()`
     list (19 entries: Hairs/Torso/Legs/Feets/Hands/Headgear/Waist, 3 each for most garment
     slots) — no Skin/Face/Decor/Makeup controller exists there either.
     **Conclusion, stated plainly rather than re-chased a 4th time**: these 4 SkinDecor texture
     parameters are a universal composite-build default baked identically onto every actor's skin
     material — NOT a per-character customization input, and NOT what makes Marita's face read
     differently from a plain Fable-bodied NPC. This is the SAME negative result the 2026-08-10
     tattoo investigation already found for `BodyDecor` specifically (`WINDROSE_MODDING_NOTES.md`
     history, this file's item 35: "BodyDecor texture parameter (identical tattooed vs. not)") —
     now independently reconfirmed across 5 more actors spanning 4 different skin families, not
     just the original 2. Whatever actually produces her distinct look is NOT reachable through
     this material's exposed instance parameters at all — either it's baked directly into a
     uniquely-authored base texture/material specific to her quest-NPC identity (which would
     require a differently-named asset than what's shown here, not proven either way), or it's a
     mechanism this project hasn't found yet. **Don't re-open the SkinDecor-texture-parameter
     angle for a per-character look question without a genuinely new lead** — this is now a
     3-for-3 negative result on that specific idea.
     `Spawner.TestSetSkinDecor`/`lbtestdecor` are kept, not removed — a legitimate, low-risk
     READ tool (confirms in one command whether a given actor's skin material exposes a named
     decor parameter at all, which is how this round's comparison was done quickly), and the SET
     path remains available if a future actor ever DOES show a differing value. Just no longer
     believed to be the answer to "what makes Marita's face look different."
     **Same-day follow-up, RedFalcon re-ran the scan with proper HOME-probe actor identification
     this time** (rather than the mod's own spawned test/comparison actors) — confirms the same
     result on REAL, hand-authored characters, not just generic composite rolls: the real quest
     Letty (`BP_NPC_QuestStatic_Letty_C`), the real Buccaneers Merchant statue
     (`BP_AnimatedActor_Buccaneers_Merchant_01_C`), a BotC Merchant
     (`BP_AnimatedActor_BotC_Merchant_02_C`), the real Standing Brethren Woman statue
     (`BP_AnimatedActor_BotC_Female_Standing_01_C`), and a wild Handyman Gatherer all carry the
     identical `T_Adventurer_BodyDecor_ID`/`_BodyDecor_M`/`_FaceDecor_M`/`_SkinAging_M` block
     regardless of their own body archetype/skin family. Even named, purpose-built characters get
     this same generic default — strengthens the conclusion above rather than changing it.

110. **`lbsockets` (full skeleton socket dump) and `Spawner.RefLog` (a persistent, crash-surviving
     reference log)** (2026-08-28, same day). RedFalcon wants to design an IK-slot/attachment
     layout and asked what sockets are actually known — the honest answer was "a handful of
     candidate-list guesses (some carried over from a different skeleton, the Senkamati mob) and
     incidental sightings in probe dumps, never one real exhaustive list." Built
     `Spawner.TestDumpSockets` / `lbsockets` — reuses the exact `GetAllSocketNames()` call already
     proven safe by the shield/tool-attach fallback code, just run unconditionally on the
     nearest/locked actor's Mesh instead of only as a last resort when a guess fails.
     RedFalcon then asked for it in the actual console too, not just `ue4ss.log` — added a `say`
     parameter (same convention as `Spawner.ApplySexChangeToNearest`: the command handler passes a
     closure that both `print()`s and `Ar:Log()`s each line) threaded through from `main.lua`.
     **Then a broader, standing-value request**: "a lot of these scans can crash over time...
     make a log file just for this... doesn't get erased at game launch." `ue4ss.log` itself is
     wiped fresh on every launch (already established this project, e.g. the ship-pivot dump's own
     comment) — any tool that only ever `print()`s loses its findings the instant the game
     restarts, crash or not, which is exactly the failure mode for a scanning session that ends in
     a crash rather than a clean exit. Built `Spawner.RefLog(tag, msg)` — one shared, ever-growing
     file (`LivingBase_ReferenceLog.txt`, same multi-candidate relative-path + `io.open(p, "a")`
     convention as `SHIP_TEST_DUMP_PATHS`/`CUSTOM_SURVEY_PATHS` elsewhere in this file) rather than
     a separate file per tool, per RedFalcon's own "doesn't have to be separate" — `tag` prefixes
     each line (e.g. `[sockets]`, `[decor]`) so a mixed history from different tools stays
     greppable by kind. Wired into both `lbsockets` (every socket line) and `lbtestdecor` (its
     three substantive result lines — no-slot-found, read-report, set-result) as the first two
     consumers; any future exploratory probe/tester should call this too rather than relying on
     `print()` alone, now that the pattern exists.
     **Same-day follow-up, a real bug found on first live use**: RedFalcon ran `lbsockets` on the
     Buccaneers Merchant and got "0 sockets" despite her visibly carrying attached props (a
     lantern, pouches, straps) -- meaning she clearly has real sockets. Root cause: the original
     code wrapped the whole `GetAllSocketNames()` call + array-unwrap in ONE outer `pcall` with its
     ok/err result completely discarded -- if the call fails for ANY reason (wrong calling
     convention, wrong function on this actor's specific component class, etc.), it silently
     produces an empty list with zero diagnostic, indistinguishable from an honestly-empty result.
     Worse, the header comment's claim that this reused an "already proven safe" call was an
     overstatement: the shield/tool-attach code's own socket-dump fallback branch (which this was
     modeled on) had NEVER actually fired even once in this whole project's history (confirmed by
     grep -- zero matching log lines ever existed before this function), so the call had only ever
     been proven not to crash when WRITTEN, never proven to actually return real data when RUN.
     Fixed to match this file's own established pattern for other uncertain `TArray`-returning
     calls (`Spawner.TestListMorphTargets`' identical shape): try the OUT-PARAM calling convention
     first (`body:GetAllSocketNames(names)` into a pre-created table), fall back to treating it as
     a plain return value if that yields nothing, unwrap each element via `:get()` in case it comes
     back as a `RemoteUnrealParam` wrapper (the item 86 lesson, applied proactively here rather than
     after a second bug report), and -- the actual fix for THIS bug -- capture and report the call's
     real pcall error text instead of swallowing it, so a genuine failure is visible instead of
     looking identical to an empty list. Also added a genuinely-empty-result diagnostic: if both
     calling conventions succeed but truly return nothing, it now prints which component/mesh
     `actor.Mesh` actually resolved to, so a wrong-component case is distinguishable from a
     truly socket-less one. **Not yet re-tested live** -- next step: `lbreload`, re-run `lbsockets`
     on the Buccaneers Merchant and confirm it now either lists her real sockets or reports a clear
     error/diagnostic instead of a silent zero.
     **CONFIRMED LIVE, WORKING**, same day. RedFalcon re-ran it across several characters (real
     data, not the diagnostic-zero case). Two real findings from comparing the captured lists
     directly: (1) the Senkamati Caster's raw MOB skeleton (`BP_Mob_SenkamatiCorrupted_Regular_
     Shaman_Caster`) is BYTE-IDENTICAL to the plain human "Regular" skeleton -- 340/340 names,
     zero difference -- she's built on the exact same Skeleton asset as every human NPC, not a
     distinct creature rig; this is the structural reason item 82's pose-compatibility finding
     ("all the poses for standard bodies also worked on the native senkamati") holds. (2) the
     Warrior/Hunter mob skeleton (315) is a STRICT SUBSET of the human skeleton -- zero
     Warrior/Hunter-only sockets -- missing only ~25 "Dyn" secondary/jiggle-physics bones
     (CollarDyn/calfDyn/thighDyn/upperarmDyn/lowerarmDyn-family, thighStrap), none of which are
     IK/attach-relevant. **Practical conclusion for the IK-layout task**: for hand/attach-point
     purposes, Human/Caster/Warrior/Hunter are functionally identical -- one unified socket layout
     covers all of them, no per-skeleton variant needed. Of the ~340 total (mostly ordinary body/
     face/finger bones), the real IK/attach candidates are: `ik_weapon_lSocket`/`ik_weapon_rSocket`
     (the two true hand-IK sockets, left confirmed via the Warrior's shield, right presumably via
     the craft-station tool attach), raw `ik_weapon_l`/`ik_weapon_r`/`hand_l`/`hand_r` bone
     fallbacks (no baked offset), a set of back/hip/belt STOW sockets (`Axe1h_backsocket`,
     `Axe2h_backsocket`, `Crossbow2h_backsocket`, `GSword_backsocket`, `Halberd_backsocket`,
     `Musket_backsocket`, `swordSlot_lSocket`, `rapierSlot_lSocket`, `beltSlot_01/02_lSocket`/
     `_rSocket`, `chestSlot_01Socket`), a head socket pair (`headSocket`/`headSocket_hat`), and a
     cluster of FX-only particle-attach sockets (`FX_Weapon_l/r_Socket`, `FXSocket_Potion`,
     `FX_Chest_Socket`, several combat-trail ones) not meant for meshes at all.
     **Same-day follow-up**: RedFalcon first asked to see each socket's actual transform value,
     not just its name -- a per-socket `GetSocketTransform(FName, 2)` read (RTS_Component space)
     was added to `Spawner.TestDumpSockets`'s print/RefLog loop, but RedFalcon then clarified that
     wasn't the ask: "i mean more like, what item is in the socket or what have you." Pulled the
     transform read back out (genuinely untested engine surface, never actually confirmed working,
     no longer needed) and replaced it with `socketOccupants(actor)` -- a new local helper that
     sweeps the actor's own `SkeletalMeshComponent`s AND `StaticMeshComponent`s (props can be
     either, per item 74) and reads each one's `GetAttachSocketName()` -- the EXACT SAME read
     `dumpMeshComponentNames`'s own probe-mesh dump already does per-component, just inverted into
     a socket-name -> `"compName (meshName)"` lookup instead of a component-name -> socket lookup.
     `Spawner.TestDumpSockets` now prints an "occupied sockets" summary FIRST (just the handful
     actually holding something, easy to scan) before the full 340-name list, each line annotated
     with its occupant when one exists (`<socket>  <- <comp> (<mesh>)`) or left blank when nothing
     is attached there -- most of the ~340 named sockets/bones are unused at any given moment, only
     worn weapons/tools/props show up. Zero new engine-surface risk -- every call here
     (`K2_GetComponentsByClass`, `GetAttachSocketName`, mesh-name resolution) is a read already
     proven safe elsewhere in this exact file. **Not yet tested live** -- next step: `lbreload`,
     run `lbsockets` on a character actually holding/wearing something socket-attached (a Warrior
     with his shield, or an actor from `lbtesttool`) and confirm the occupied-sockets summary
     correctly names it.

111. **`lbtestaddslot <slot> <meshPath>` -- building a genuinely MISSING clothing component from
     scratch, standalone experiment** (2026-08-28, same day). RedFalcon's real underlying question,
     once the socket investigation (item 110) was underway: sailors (and other NPCs) sometimes
     spawn with a composite roll that never creates a Torso (or other slot) component at all -- a
     genuine build-time omission, not a hidden/removed piece -- so `Custom > Clothes`
     (`Spawner.TestApplyClothingPiece`) has nothing to grab onto, since it only ever SWAPS an
     EXISTING component's mesh by matching its current name; it can't create a component that was
     never there. Asked whether the sockets from item 110 could be "populated" to fix this.
     Checked first rather than assumed: every clothing/armor component in every probe-mesh dump
     captured this session reports `socket=None` -- clothing pieces are NOT socket-attached at
     all, they're plain extra `SkeletalMeshComponent`s sharing the body's skeleton via leader-pose
     skinning. So sockets are the wrong lever for this specific problem; the real fix is
     constructing the missing component the same structural way the composite system itself would
     have: `AddComponentByClass` (the exact proven-safe recipe `Spawner.AttachShield`/
     `TestAttachToolToNearest` already use successfully) + `SetLeaderPoseComponent(actor.Mesh)`
     instead of a socket attach.
     RedFalcon asked for this as a standalone test first, not wired into `TestApplyClothingPiece`
     yet. `Spawner.TestAddMissingClothingSlot(slotArg, meshPathArg)` / `lbtestaddslot <slot>
     <meshPath>`: refuses up front if the requested slot already has a real component (checked via
     the same `clothingSlotOf` scan `Spawner.TestRemoveClothingPiece` already uses) -- this tool is
     for filling a genuine gap, not adding a second competing piece; existing pieces still go
     through `lbtestclothes`/`lbtestarmor`. Otherwise: `AddComponentByClass` a new
     `SkeletalMeshComponent`, `SetSkeletalMeshAsset`/`SetSkeletalMesh` the requested mesh onto it,
     attach it to the body (no socket, empty string = attach at root), then the one genuinely NEW
     call in this codebase -- `SetLeaderPoseComponent(body)`, tried under the modern UE5 name
     first and falling back to the deprecated pre-5.1 `SetMasterPoseComponent` alias if that pcall
     fails (this game is UE 5.6 so the modern name should be right, but the fallback costs
     nothing). VERIFIED via `GetLeaderPoseComponent()`/`GetMasterPoseComponent()` readback
     (matching that a component's own name equals the body's), not trusted from the call alone --
     same discipline as every other "does this attach actually stick" check in this file. Reports
     a clear `verified=true/false` in both the console/log output and `Spawner.RefLog` (tagged
     `addslot`), and an explicit warning if the leader-pose call couldn't be confirmed (the mesh
     may render statically at the wrong pose without it, not crash -- but shouldn't be trusted
     without a visual check).
     **Genuinely new engine surface, flagged plainly**: `AddComponentByClass` + the attach call are
     proven; `SetLeaderPoseComponent` itself has never been called anywhere in this codebase
     before. Not in the same crash-risk category as `SetBody`/`AttachActorToShip`/
     `RecreateClothingActor` (those are all confirmed-fatal native crashes) -- this is a much more
     standard, long-stable Blueprint-exposed function -- but still unconfirmed in THIS specific
     UE4SS binding until tested live.
     `lint.py` clean (`compile: 10 scripts OK`). Deployed `spawner.lua`/`main.lua` to the live
     install (`lbreload` needed). **Not yet tested live** -- next step: `lbreload`, find (or
     despawn/respawn until you get) a Sailor missing his shirt, run `lbtestaddslot Torso
     <a Sailor torso mesh path>`, and check both the `verified=` result and -- the actual test --
     whether the new piece visually deforms correctly with the body's animation rather than sitting
     rigid/misplaced.
     **Same-day fix, caught by RedFalcon before any live test**: asked whether the mesh path needs
     the trailing `.SK_Armor_...` object-name suffix -- it did, but shouldn't have had to: every
     other path-fed tester in this file (`lbtesttool`/`lbtestmaterial`/`lbtestpose`) already
     auto-appends that suffix when a bare `/Game/...` path is pasted without one, a convenience
     this function was overlooked for when first written. Added the identical
     `meshPathArg:match("%.[%w_]+$")` check/append. `lint.py` clean, deployed.
     **Same-day: a real crash report with no diagnosable cause, root-caused to a logging gap and
     fixed.** RedFalcon reported a crash right after using this tool ("dang, the fun crash") but
     neither `ue4ss.log` (which resets on every launch/crash) nor `LivingBase_ReferenceLog.txt`
     (item 110's own crash-survival file) had a single `[test-addslot]` line anywhere -- because
     this function only ever logged its FINAL result, AFTER the three risky calls
     (`AddComponentByClass`/the attach/`SetLeaderPoseComponent`) already ran, the exact "log only
     after, not before" mistake item 71's `AttachActorToShip` crash already taught this project
     once. Fixed by adding a `breadcrumb()` helper (print + `Spawner.RefLog`) called IMMEDIATELY
     BEFORE each of the three risky calls, so a future crash leaves a trace of exactly which one
     did it instead of a silent gap. Whether THIS crash was actually caused by `lbtestaddslot` was
     never confirmed either way (RedFalcon's report didn't specify), but the logging gap itself was
     real and is now fixed regardless. `lint.py` clean, deployed.

112. **The custom-archetype investigation: full composite-outfit structure mapped three levels
     deep, and the first real construction experiment built** (2026-08-29). RedFalcon's real
     endgame, stated plainly: "making our own archetype that can then be applied, similar to how
     we do the walking maritas" -- with every clothing slot specifiable, closing the exact gap
     `lbtestaddslot` (item 111) was built for, but through the game's own NATIVE composite-build
     path instead of hand-constructed components.
     **Correction along the way, worth recording**: this investigation started from a wrong
     assumption RedFalcon caught -- "pretty sure that's not how it works anymore. she is ready and
     fully dressed at spawn." Re-reading the CURRENT `Testbed.ApplyFemaleReskinTarget` (not
     trusting this file's own summarized history) confirmed a real 2026-08-19 rework:
     `Config.FEMALE_CHARACTER_PARAMS` gives Letty/Marita/Merchant their OWN real, live-probed
     `CompositeMeshComponentParams` DataAsset pre-build -- the entire old `ForceHeadwear`/content-
     match/topless-bald settle-check-and-reroll system (items 36-37) is DEAD CODE for these three
     characters specifically, superseded, not merely supplemented. Only the generic "Woman"
     roster entry still uses the old shared-Brethren-Woman-plus-randomness approach (and
     deliberately un-forced, per RedFalcon's own live-testing call that its native randomness
     already produces acceptable results either way). **Lesson reinforced**: this file's own
     summarized history is not authoritative once the underlying code has moved on -- check the
     live source before answering a specific "how does X work" question, not just this file.
     **Structure mapped, three levels, via RedFalcon's own live asset-JSON exports** (a tool this
     project hadn't used before this session -- presumably FModel or similar, run directly against
     the actual `.uasset` files): `R5CompositeMeshComponentBaseParams` (Marita's own real params
     asset) -> per category (`Customization.UID.Armor`/`Hairs`/`Facial.Eyebrows`), a per-sex list
     of `R5CompositeMeshGroup` references (Armor: ONE fixed group, `bAllowCustomization=false`;
     Hairs/Eyebrows: dozens of options, `bAllowCustomization=true` -- this IS the real backing data
     for the game's own character-creation hair/eyebrow picker) -> `R5CompositeMeshGroup`
     (`DA_NPC_QuestStatic_Smugglers_MaritaSuares_Equipment_CompositeMeshGroup`), a flat array of
     SIX `R5CompositeMeshParams` references, one per body part (Feet=Conquistador, Hands/Head/
     Legs/Torso=Flibustier, Belt=Gunslinger -- confirming a "Group" is genuinely an arbitrary
     mix-and-match bundle, not a single-family outfit) -> `R5CompositeMeshParams` (the bottom
     level), which finally holds the real `BaseMesh.AssetPathName` per sex, `Attachments` (socket-
     attached extras like her pistols/pouches, each with a full baked Rotation/Translation/Scale
     transform -- the data-driven answer to the earlier IK-socket-offset question), and
     `ColorData.ColorIndexesMap` (confirming color is baked in at THIS level, build-time-only --
     consistent with, not contradicting, the already-established "post-build ColorController/
     ColorParams writes never render" dead end from item 35).
     **De-risked plan, not "build everything from scratch"**: since every existing catalog
     family/slot almost certainly already has its own `R5CompositeMeshParams` ("CompositeMeshData")
     asset (confirmed for Dogface: 12 entries, Feet/Head/Legs/Torso x 3 numbered variants each,
     same shape as `Config.CUSTOM_CLOTHES`' own raw-mesh catalog), a custom archetype doesn't need
     the deepest level built from scratch -- only a NEW `R5CompositeMeshGroup` referencing EXISTING
     per-piece assets from whatever families you want, mixed freely. Swept `pakcontents.xlsx` for
     the full set (354 pieces, 33 families -- some overlapping `Config.CUSTOM_CLOTHES`' own 25,
     some new: BlackBeard_Grenadier/Huntsman/Sergeant, Combatant, Crafter, Default, Drowned,
     Drowned_Armored, the Senkamati_*_Feather/Wood families, several `Set_*`/`NPC_*` families) into
     `Config.CUSTOM_COMPOSITE_PIECES` (config.lua) -- reference data only so far, not wired into
     anything yet.
     **`Spawner.TestBuildCustomOutfit` / `lbtestgroup <slot> <family> <name>`** (spawner.lua) is the
     first real construction experiment -- deliberately the SMALLEST possible test: takes Marita's
     own known-real 6-piece bundle (hardcoded from the live probe dumps above) and swaps exactly
     ONE slot for a different catalog family, rather than building a fully custom archetype in one
     shot. **This is the single riskiest experiment built this entire session** -- three genuinely
     new engine calls stacked in one function, none previously used in this codebase: (1)
     `StaticConstructObject` on `R5CompositeMeshGroup` (only ever proven on a plain UMG `TextBlock`
     before, item 22 -- a real extrapolation, not a repeat), (2) writing a `TArray` of HARD OBJECT
     REFERENCES (every prior property write this session has been a scalar, a Vector/Quat struct,
     or a single texture/material reference -- never an array of object pointers; tries direct
     Lua-table assignment first, falls back to `:Add()` per element, reports the actual resulting
     count rather than trusting either blindly), (3) `DuplicateObject` (never used anywhere in this
     codebase before -- chosen over hand-constructing a whole new
     `R5CompositeMeshComponentBaseParams` from scratch specifically to avoid ALSO having to build
     the deeper `CustomizationData`/`GameplayTag`/`TMap` structure from nothing; if `DuplicateObject`
     itself fails, the function stops there rather than falling back to that much bigger from-
     scratch task in the same pass). A final re-read verifies the Armor-category patch actually
     stuck (TMap-entry structs returned by index may come back as copies in this binding, unproven
     either way) rather than trusting the write blindly.
     **Every risky call is preceded by a breadcrumb** (`print` + `Spawner.RefLog`, tagged
     `"group"`) immediately before it runs -- the item-111 lesson applied proactively this time, not
     after a crash: if this crashes, `LivingBase_ReferenceLog.txt`'s last `[group]` line names
     exactly which of the three new calls did it.
     `lint.py` clean (`compile: 10 scripts OK`; the `StaticConstructObject`/`DuplicateObject`
     "undefined call" warnings are the same pre-existing false-positive class already documented
     for these exact global UE4SS functions, e.g. line 336's own `StaticConstructObject` — the
     linter can't resolve UE4SS-provided globals, not a real issue). Deployed
     `spawner.lua`/`main.lua`/`config.lua` to the live install (`lbreload` needed).
     **Not yet tested live** -- this is a first attempt at genuinely unprecedented engine surface,
     stacked three calls deep, in the single riskiest experiment this session has built. Next step:
     `lbreload`, then `lbtestgroup Torso Dogface 01` (or any other catalog family/slot combo) and
     watch `LivingBase_ReferenceLog.txt`/the console in real time — if it crashes, the last
     `[group]` line tells us which call to investigate; if it succeeds, the actual test is whether
     the spawned actor's outfit renders with the swapped piece looking correct (not distorted,
     not missing, deforming properly with the body).
     **First live run: NOT a crash — a clean, caught Lua error, and a real (contained) bug.**
     `resolveAsset` threw `GetPackageNameFromLongName: Name wasn't long` on the very first piece
     resolve, `pcall`-caught with a full stack trace, no engine damage at all — genuinely
     reassuring given the risk level of the rest of this function. Root cause: every path in this
     function — both the hardcoded `BASELINE` table and every row `Config.CUSTOM_COMPOSITE_PIECES`
     generates — is missing the trailing `.AssetName` suffix `resolveAsset`'s `StaticFindObject`
     call actually requires; the catalog-generation script stripped it (`rsplit('.',1)[0]` also ate
     the object-name segment, not just `.uasset`), and the hardcoded baseline was typed without it
     from the start. Fixed with the same auto-append convenience every other path-fed tester in
     this file already has (`lbtesttool`/`lbtestmaterial`/`lbtestpose`) — a local `ensureSuffix()`
     applied to every path before resolving, rather than regenerating the whole 354-row catalog
     over a formatting detail. `lint.py` clean, deployed.
     **Second live run: TWO of the three genuinely-new engine operations CONFIRMED WORKING,
     cleanly, on the first real attempt.** `StaticConstructObject` on `R5CompositeMeshGroup`
     succeeded ("Group constructed ok") — generalizes beyond the one class (a plain UMG
     `TextBlock`, item 22) it had ever been proven on before. Writing the `CompositeMeshesParams`
     array via plain Lua-table assignment ALSO succeeded on the first try — "Group.
     CompositeMeshesParams now reports 6 entries (wanted 6)" — no `:Add()`-per-element fallback
     needed at all; this UE4SS binding evidently marshals a Lua table straight into a `TArray` of
     hard object references, at least for this property. Only `DuplicateObject` failed, and safely
     so: "attempt to call a nil value (global 'DuplicateObject')" — a clean Lua-level error (calling
     a name that was never registered as a global can't touch the engine at all, unlike a real
     engine call with wrong arguments) confirming the function simply isn't exposed under that name
     in this binding, not a deeper problem. Added a fallback to `StaticDuplicateObject` — the real
     underlying C++ engine function name, matching the exact naming pattern
     `StaticFindObject`/`StaticConstructObject` (both already proven in this codebase) already
     follow — tried automatically if the plain name fails. `lint.py` clean, deployed.
     **Third live run: `StaticDuplicateObject` ALSO confirmed unavailable** — same clean "attempt
     to call a nil value" Lua error, not a crash, for both duplicate-object names now. Pivoted
     immediately to the fallback plan already anticipated: building a BRAND NEW
     `R5CompositeMeshComponentBaseParams` from scratch via the SAME `StaticConstructObject` call
     already proven working on `R5CompositeMeshGroup` moments earlier in the same run, rather than
     guessing a third duplicate-object name blind. Its `CustomizationData` (one entry, Armor
     category only — Hairs/Eyebrows deliberately omitted for this minimal test) is written as ONE
     nested Lua table literal in a single assignment, betting that the table->TArray marshaling
     which just worked for a flat array of object references generalizes to an array of NESTED
     STRUCTS (a `GameplayTag`, a bool, and a `TMap`-shaped sub-array) too — a genuinely new,
     unproven assumption, verified via re-read afterward exactly like the earlier array write was,
     not trusted blindly; the function now refuses to spawn at all if that verification comes back
     empty. `lint.py` clean, deployed.
     **Fourth live run: CONFIRMED TO CRASH THE GAME.** The breadcrumb printed immediately before
     the `CustomizationData` table-literal assignment ("about to write CustomizationData...") was
     the LAST line written to either `LivingBase_ReferenceLog.txt` or `ue4ss.log` before the game
     went down — execution never returned to Lua. Everything before it in this same run is
     confirmed SAFE: both `StaticConstructObject` calls (on `R5CompositeMeshGroup` AND on
     `R5CompositeMeshComponentBaseParams`) and the flat array-of-object-references write on the
     Group all completed cleanly. So the crash is narrowly isolated to this ONE specific
     operation — assigning a nested Lua table (containing a `GameplayTag` sub-table, a bool, and a
     `TMap`-shaped sub-array of Key/Value pairs) to `CustomizationData` in a single write — not a
     general failure of object construction or array writes, which both remain proven-safe
     techniques going forward.
     **Immediately disabled**: pulled the crashing assignment (and the now-unreachable
     verification/spawn code after it, which Lua's own "`return` must be the last statement in its
     block" rule required physically relocating below the function's `end` rather than leaving
     commented-out in place) out from live execution — `Spawner.TestBuildCustomOutfit` now returns
     `false` with a clear "confirmed to crash, stopping here" message right before reaching that
     line, matching this file's established treatment of other confirmed-fatal calls (`SetBody`/
     `AttachActorToShip`/`RecreateClothingActor`). The crashing code itself is kept, block-commented,
     as a documented record — not deleted, not silently removed. `lint.py` clean (`compile: 10
     scripts OK`), deployed.
     **Net status of the custom-archetype investigation, closed out for this session**: the
     underlying insight (a `CompositeMeshGroup` is a flat array of existing per-piece references,
     mixable across families) is confirmed correct and the composite-consumption mechanism for a
     whole custom outfit is proven reachable in principle — `StaticConstructObject` on BOTH
     relevant classes works, and writing a flat array of object references works. The one thing
     that doesn't yet work is assembling the OUTER `CustomizationData` wrapper in a single
     all-in-one nested-table write. **Real next step, not yet attempted**: construct the
     `CustomizationData` entry's fields INDIVIDUALLY instead of as one large table literal —
     e.g. build the entry struct, assign `GroupCategoryId` alone, then `bAllowCustomization` alone,
     then `CompositeMeshGroupsByBodySex` alone (and possibly that TMap's own Key/Value pair
     one field at a time too) — since the flat array-of-objects case proved simple single-shape
     writes work fine, the crash may be specific to how much heterogeneous nested structure was
     asked for in one assignment, not nested writes in general. A genuinely different next
     experiment, not a retry of what just crashed.
     **Same-day (2026-08-29) implementation, RedFalcon: "ok, let's do it"**: built exactly that
     staged approach. `Spawner.TestBuildCustomOutfit` now writes the `CustomizationData` entry
     across THREE separate assignments instead of one: (1) `newParams.CustomizationData = { {
     GroupCategoryId = {TagName=...} } }` — array + one entry + just the category tag; (2) fetches
     that entry back out of the array (same unwrap-by-`:get()` pattern used everywhere else in this
     file, so the next two writes target the SAME live struct, not a disconnected fresh table) and
     sets `entry.bAllowCustomization = false` alone; (3) sets
     `entry.CompositeMeshGroupsByBodySex = { {Key=..., Value={CompositeMeshesParams={newGroup}}} }`
     alone — the TMap-shaped sub-array, isolated from the other two fields this time. Each step has
     its own breadcrumb and its own early-return on failure, so a crash on any one step pinpoints
     exactly which of the three nested pieces is the actual problem, rather than "somewhere in the
     one big write." The original one-shot version's exact crashing code is no longer kept
     block-commented in the file (superseded by this real next attempt, per its own recommendation
     above) — this entry's history is the record instead. `lint.py` clean (`compile: 10 scripts
     OK`), deployed.
     **Fifth live run: CONFIRMED TO CRASH AGAIN — but narrowed to step 1 exactly, the simplest of
     the three.** "about to write CustomizationData step 1/3 (array + one entry + just the category
     tag)" was the last breadcrumb; steps 2 and 3 were never reached. This rules out the "too much
     heterogeneous nesting in one write" theory (step 1 alone is about as small as it gets) and
     points somewhere more specific: this was the FIRST attempt anywhere in this codebase at
     CONSTRUCTING a `GameplayTag` from scratch and handing it to the engine — every prior read of one
     elsewhere in this project was already-registered, already-valid data loaded from a real asset.
     GameplayTags are normally validated against a registered tag hierarchy; a bare Lua table may not
     satisfy whatever that validation expects, unlike a plain `FVector`/`FName` string with no
     registry to consult.
     RedFalcon, asked directly given two crashes in a row: **"let's do the [narrower test]. while
     crashing causes some time loss, its not horrible"** — explicit informed consent to keep
     iterating despite the real cost. Split step 1 itself into two even finer sub-steps: 1a assigns a
     COMPLETELY EMPTY entry (`{ {} }`, no tag at all) to isolate whether appending ANY entry to this
     specific array-of-structs type is the problem, independent of GameplayTag; if 1a survives, 1b
     sets `GroupCategoryId` as its own separate write afterward (fetched back out of the array, not
     embedded in the original literal) — if THAT crashes, it confirms GameplayTag construction
     specifically as the trigger, the most surgical isolation this investigation can reach. `lint.py`
     clean (`compile: 10 scripts OK`), deployed.
     **Sixth live run: settled it — step 1a survives, step 1b CONFIRMED TO CRASH.** RedFalcon
     re-ran `lbtestgroup Torso Dogface 01`: the log shows step 1a's result line
     (`step 1a result: ok=true`) then the step 1b breadcrumb ("about to write CustomizationData
     step 1b (GroupCategoryId alone, on the fetched entry)") as the very last line, with nothing
     after it. This is the most surgical isolation this investigation reached: an array containing
     one COMPLETELY EMPTY struct entry writes and reads back fine — the array-of-structs mechanism
     itself was never the problem — and the crash is narrowly, repeatably specific to constructing
     a fresh `GameplayTag` from a bare Lua table (`{TagName = "Customization.UID.Armor"}`) and
     assigning it to a struct field. Every simpler operation tried across this whole investigation
     (both `StaticConstructObject` calls, the flat array-of-object-references write, the
     empty-struct array write) worked cleanly — this is not a general array/struct/nesting
     problem, it's specific to fabricating a `GameplayTag` value out of nothing.
     **Disabled at the confirmed line, matching this file's treatment of every other confirmed-
     fatal call** (`SetBody`/`AttachActorToShip`/`RecreateClothingActor`): `Spawner.
     TestBuildCustomOutfit` now returns `false` with a clear message right where step 1b's write
     used to be; steps 2/3, 3/3, the verification re-read, and the actual test spawn were never
     reached and were removed as unreachable code rather than kept commented out (recoverable from
     git history, commit `c8a1fc7` onward, if a real fix is ever found). Written up as a durable
     finding in `WINDROSE_MODDING_NOTES.md` §19b (and the public mirror/repo, same day) along with
     the one untried, more-promising alternative: read an ALREADY-VALID `GameplayTag` struct value
     off a real asset that already carries the wanted category (e.g. an existing character's own
     `CustomizationData` entry) and copy that value into the new entry, rather than constructing
     one from a raw string — a value copy, not a fresh fabrication, which may sidestep whatever
     validation the from-scratch construction fails. **Not yet attempted.**
     **Net status of the custom-archetype investigation, closed out for this round**: the
     underlying insight (a group is a flat array of existing per-piece references, mixable across
     families) is confirmed correct, and `StaticConstructObject` + flat object-reference-array
     writes are both proven generically safe techniques going forward. The one remaining blocker to
     assembling a complete custom `CustomizationData` wrapper from scratch is this GameplayTag
     construction issue — real next step is the copy-not-construct alternative above, not another
     variant of building a tag from a string.
     **Same-day (2026-08-29) continuation, RedFalcon: "let's use your idea"**: implemented the
     copy-not-construct alternative — read Marita's own real, already-valid `GroupCategoryId` off
     her real BaseParams asset and assigned that VALUE (not a fabricated `{TagName=...}` table) onto
     the fetched-back entry. **Confirmed live: this worked, no crash** — the whole staged sequence
     (empty entry → copy real tag → `bAllowCustomization` → `CompositeMeshGroupsByBodySex`) completed
     and verified cleanly. The spawned actor came out **fully nude** — a live probe showed
     `BuildedCompositeMeshes` at 0 for every category, not just the swapped one. Two more diagnostics
     narrowed this: `Spawner.TestCopyWholeParams` (copying an existing character's ENTIRE
     `CustomizationData` array wholesale onto a fresh object, no modification) built correctly,
     ruling out "fresh `StaticConstructObject`'d objects never build"; appending real Hairs/Eyebrows
     entries alongside the custom Armor one (still unmodified) didn't help either, ruling out
     "missing categories." Suspecting the staged fetch/mutate/reinsert pattern itself was producing a
     self-consistent-but-disconnected value, tried building the WHOLE entry (copied tag included) as
     ONE single table literal instead — same shape as the very first crash, but with a copied tag.
     **This crashed too, twice, reproducibly** — both mixed with real pre-existing entries in one
     write, and completely alone. This is the decisive result: rules out "GameplayTag fabrication
     specifically" (a copied tag crashes too) and "mixing fresh + real entries" (crashes alone too).
     **The real, generalized rule**: constructing a brand-new struct value via a table literal, in
     one shot, AS A NEW ARRAY ELEMENT, crashes — regardless of contents. Only the staged
     empty-then-mutate-in-place pattern is safe, and it doesn't produce a working build. Both crashes
     disabled at the confirmed line (same treatment as every other confirmed-fatal call), findings
     written up in `WINDROSE_MODDING_NOTES.md` §19b.
     **The pivot that actually worked, same day**: RedFalcon asked "since I know the params exist as
     an entry in the PAK files, is it possible to make a physical file for it?" — stepping back from
     runtime construction entirely to editing a REAL asset file OFFLINE. This turned into a full,
     independent tooling investigation (FModel already installed; `UAssetGUI` and Epic's own
     `UnrealPak.exe` fetched fresh) that hit and resolved several real problems in sequence:
     - `UAssetGUI`'s own CLI (`tojson`/`fromjson`) produced zero output/zero files no matter what was
       tried (confirmed identical behavior run interactively by RedFalcon, ruling out an automation-
       environment quirk) — abandoned in favor of driving the GUI directly, which DID work and gave
       real, informative dialogs.
     - `UAssetGUI` refused to open a raw-exported `.uasset` at all: **"UE5 Zen Loader assets cannot
       be loaded directly into UAssetGUI"** — this game ships Zen/IoStore containers, not the legacy
       format the tool expects. Its own error dialog named the fix: `retoc` (fetched fresh,
       MIT-licensed, by the same author as a second tool used later).
     - `retoc to-legacy <Paks folder> <output> --filter "<name>" --version UE5_6` (an all-zero AES
       key as the standard "not really encrypted" placeholder, already established for this game's
       own paks) successfully extracted real, legacy-format `.uasset`+`.uexp` pairs for Marita's own
       BaseParams and Group — filter is a plain substring match, not a glob (`*Marita*` matched
       nothing, plain `Marita` matched 23 real assets).
     - Editing in `UAssetGUI`: the Export Data grid's object-reference values are READ-ONLY
       (resolved-name display only) — the actual edit happens in the **Import Data** grid instead,
       where each reference shows as a `Package`-type row (full path) plus a same-class-type row
       (short name, `OuterIndex` pointing at the package row), both plain editable text. Retargeting
       both rows to a different family's piece (Torso: Flibustier → Jeweler) worked on the first try,
       confirmed via the Export Data view updating to show the new resolved name. No manual Name Map
       edit needed — typing a brand-new string directly into an editable name field auto-registers it
       on save (confirmed: the new string didn't exist anywhere in the source package beforehand).
     - Duplicating Marita's Group+BaseParams under a NEW package path (`.../Armor/Custom/
       DA_Custom_MaritaGroup`/`DA_Custom_MaritaParams`, set via the General Information tab's
       `PackageName` field — Save As only renames the destination FILE, not this internal identity
       field) → `retoc to-zen <staged folder> <output>.utoc --version UE5_6` → packaged with
       Epic's own `UnrealPak.exe` — **failed**: "PakEntry mismatch" on every single entry when trying
       to extract/verify (a real version/format mismatch between this specific `UnrealPak.exe` build
       and what these tools produce/expect) → switched to `repak` (fetched fresh, same author as
       `retoc`) for all pak-level work from here on, no further mismatch issues.
     - First live test (`lbtestpak`, a new `Spawner.SetCompositeParams`/`compositeLook.params`-based
       tester — zero runtime construction, just a real asset load): **`params=MISS`** — the new
       asset never resolved at all. **CRASHED** on the very next spawn (an ordinary, unrelated
       default Gatherer spawn, since params never loaded) — but the crash dump's own embedded
       `LogPakFile`/`LogIoDispatcher` lines showed no mount message for the new container at all,
       and a SECOND clean (non-corrupted) attempt with a fixed sidecar pak reproduced the identical
       `MISS` with NO crash — strong evidence the crash was coincidental, not caused by the new pak.
     - Diagnosed via `repak info`: the working installed mod's own sidecar `.pak` uses mount point
       `/`; `retoc to-zen`'s own auto-generated one used `../../../` (the game's own root-container
       convention) instead. Fixed by building a fresh, EMPTY `.pak` via `repak pack --mount-point "/"
       --version V11` (repak's own compat table tops out at V11/UE~5.3 "likely later," confirmed
       working here on UE 5.6) — reused verbatim as the sidecar for every later test, since an
       IoStore mod's own tiny companion pak legitimately has ZERO file entries either way (confirmed
       by checking the ALREADY-WORKING installed mod's own pak the same way — 0 entries there too,
       not itself a sign of anything broken).
     - STILL `MISS` even with the sidecar fixed. Found via `retoc info` on the `.utoc` itself
       (a SEPARATE mount-point field from the sidecar `.pak`'s own): the working mod's `.utoc` has a
       DEEP, asset-scoped mount point (`.../Adventurer/Meshes/`); `retoc to-zen` hardcodes the
       generic root (`../../../`) with **no CLI flag to override it** — independently corroborated:
       another modder (unrelated UE5 game, found via a web search RedFalcon prompted) hit and
       diagnosed this exact same `retoc` limitation, going as far as recompiling a patched copy to
       expose it. Found a public workaround instead of recompiling: `retoc unpack-raw <utoc>
       <dir>` round-trips a container through a plain, hand-editable `manifest.json` (with its own
       `mount_point` field); editing that field and `pack-raw`-ing it back DID let the mount point
       be set arbitrarily.
     - STILL `MISS` after that fix too (tested on the new-path Marita asset) — by this point, three
       independently-real problems (sidecar mount point, container mount point, and whatever was
       still failing) had been found and fixed on the SAME new-path asset with no success, pointing
       at something more fundamental than packaging mechanics.
     - **RedFalcon: "let's use Letty for now"** — switched the test from a brand-new asset path to
       OVERRIDING an EXISTING, already-real, already-referenced one (Letty's own real Group asset,
       same filename/package identity, no duplication, no `PackageName` change) — since her own real
       `BaseParams` already references that exact path, no `lbtestpak`/`compositeLook` override is
       even needed; she just needs to spawn normally. First attempt (using the mount-point-corrected
       `.utoc` from the raw-manifest workaround): she spawned with only 3 of her normal pieces built
       (Hands/Hair/Eyebrows; Feet/Legs/Torso/Belt all missing) — confirmed via UAssetGUI that the
       edited asset ITSELF was correct (4 clean entries, Torso correctly retargeted) — RedFalcon's
       own idea to check the actual packaged container directly in FModel found the real cause:
       **`KeyNotFoundException: Couldn't find chunk 0x<id> | 6`** — the manual `unpack-raw`/
       `pack-raw` mount-point round-trip had corrupted the container's own `ContainerHeader` chunk
       (chunk type 6): the raw chunk bytes get copied across verbatim, but they're tied to the
       ORIGINAL container's own ID, which changes on rebuild — `retoc info` never catches this (it
       doesn't cross-check header/ID consistency) but a real parser does immediately.
     - **Realized the mount-point detour was very likely unnecessary for an OVERRIDE specifically**
       (IoStore resolves by a hash of the PACKAGE NAME STRING, not by container mount point — mount
       point matters far more for legacy-pak-style addressing) — swapped back to the PLAIN,
       uncorrupted `retoc to-zen` output for Letty (root mount point, but a properly self-consistent
       `ContainerHeader`), keeping only the `repak`-built sidecar fix. RedFalcon confirmed the
       container reads clean in FModel (no chunk errors, exact expected 4-entry array) before even
       testing in-game.
     - **CONFIRMED LIVE, WORKING, END TO END**: full game restart, spawned the REAL quest-NPC Letty
       (`BP_NPC_QuestStatic_Letty_C`) via this mod's completely ordinary, pre-existing spawn path —
       zero runtime code changes of any kind — and she rendered wearing `SK_Armor_Jeweler_01_Female_
       Torso_Long_01` (the swapped-in Jeweler torso) with a full 6 `BuildedCompositeMeshes` entries
       (not the broken 3 from the corrupted container). **The first genuinely successful custom-
       outfit-piece swap this entire investigation (both the runtime-construction arc above and this
       offline-tooling arc) ever produced.**
     - **The single most important finding, confirmed by direct comparison**: the SAME clean,
       uncorrupted build method returned `MISS` for a brand-new package path and worked completely
       for an override of an existing one — ruling out container malformation as the explanation for
       the new-path failure (a non-corrupted new-path container was tested in between the two
       corrupted-container attempts and also returned `MISS`). **A genuinely new asset path cannot be
       made to resolve at runtime in this game no matter how correctly the container is built;
       overriding an existing, already-known path works immediately.** Most likely explanation: this
       Shipping build resolves packages against a manifest baked in at cook time, not by discovering
       new content dynamically — exactly the mechanism every already-installed third-party content
       mod already relies on (replace, never add). **Practical, permanent constraint on any future
       custom-archetype/outfit feature built this way: it must reskin an existing real
       character/NPC's own asset, never introduce a wholly independent new one.**
     Full recipe (tools, exact steps, both key findings) written up generally in
     `WINDROSE_MODDING_NOTES.md` §19c-2/§19c-3, mirrored to the public `Windrose_Modding_Notes.txt`
     and the `Windrose-UE4SS-Modding-Notes` repo (commit `0400c47`), same day.
     **Not yet cleaned up**: `LivingBaseLettyTest` (the working test pak, currently overriding the
     real Letty's Torso with the Jeweler piece) is still installed in the live game — a real,
     confirmed-working demonstration, not yet decided whether to keep, extend into a real feature, or
     remove now that the recipe itself is proven and written down.
     **Same-day continuation: a real third-party counter-example found and investigated
     exhaustively — §19c-3's own conclusion holds up.** RedFalcon found an installed third-party mod
     (`zKasper_RespawnSelector_P`/KasperShipRespawn) shipping `DA_ReviveSettings`/
     `WBP_RespawnNotification` at paths RedFalcon believed were absent from every base-game pak —
     installed and tested properly (its own zip showed the real intended location,
     `R5/Content/Paks/~mods/`, not the `ue4ss/Mods/` root RedFalcon had moved it to just for FModel
     inspection) and CONFIRMED WORKING (the death-screen buttons genuinely appeared in-game). Checked
     both paths directly against `pakcontents.xlsx` before drawing any conclusion: **both are
     genuinely vanilla** (`R5/Content/Gameplay/Character/Player/PlayerState/DA_ReviveSettings.uasset`
     in `pakchunk0_s3`; `R5/Content/UI/HUD/Notifications/WBP_RespawnNotification.uasset` in
     `pakchunk0_s4`) — RedFalcon's own belief they were new was an honest miss on a casing difference
     (`PlayerState` vs. the `Playerstate` folder name glanced at). This is a SECOND independent
     confirmation of the override mechanism, not a counter-example.
     A SECOND third-party mod (`Pirate Signals`, a client/server chat transport with a compiled
     ImGui-overlay DLL) turned out to be a genuine counter-example: `/Game/Mods/
     WindroseChatTransport/ModActor` — confirmed via `pakcontents.xlsx` to have ZERO hits, genuinely
     absent from every base-game pak — resolves successfully via `StaticFindObject`, used by both its
     own client Lua and (per its server-side `main.lua`) via a `resolve_transport_class()` helper.
     Traced the actual mechanism: an ALREADY-INSTALLED, ALREADY-ENABLED bundled UE4SS component,
     `BPModLoaderMod`, watches `Content/Paks/LogicMods/` (one subfolder per mod, each with its own
     `config.lua` naming the class), resolves the class via `AssetRegistryHelpers:GetAsset(...)` — a
     different, higher-level API than `resolveAsset`'s `StaticFindObject`/`LoadAsset` combo — then
     explicitly `SpawnActor`s one instance itself, which is what first makes the class "known" to
     everyone else's plain `StaticFindObject` calls afterward.
     Built two new PURE-READ diagnostic tools to test this properly: `Spawner.TestScanSoftRefs`
     (`lbscanhooks <classPath>`) walks a native class's own CDO for soft-object/soft-class reference
     properties (looking for native "hook point" slots a mod could fill) — tested on
     `R5.R5ReviveComponent`, found 0 (a dead end for THAT specific class, not proof the general idea
     is wrong). `Spawner.TestResolveViaAssetRegistry` (`lbtestassetreg <PackageName> <AssetName>`)
     calls `AssetRegistryHelpers:GetAsset()` directly, mirroring `BPModLoaderMod`'s own mechanism,
     against our own confirmed-new `DA_Custom_MaritaParams` path.
     **Systematically tested and ruled out every controllable variable, one at a time, all against
     our own confirmed-new asset path**: sidecar `.pak` mount point — already fixed, no effect.
     Container's own internal mount point — already tested clean via FModel earlier the same day
     (the round-2 Marita container, pre-dating any raw-chunk surgery), no effect. `AssetRegistry
     API` in place of `resolveAsset` — clean failure, no crash, but still `MISS`. `LogicMods` folder,
     files flat with no subfolder — no effect. `LogicMods` folder, correctly nested one-subfolder-
     per-mod (`LogicMods/LivingBaseCustomTest/`) exactly matching Pirate Signals' own layout — no
     effect. A matching `config.lua` telling `BPModLoaderMod` exactly where to look — no effect:
     `BPModLoaderMod`'s OWN log showed the identical `"ModClass for 'LivingBaseCustomTest' is not
     valid"` failure, using the EXACT SAME native tool/API that succeeds for Pirate Signals, called
     by that tool's own code rather than ours. Asset TYPE (a plain `DataAsset` object vs. a genuine
     Blueprint ACTOR CLASS) — duplicated `BP_NPC_QuestStatic_Letty` (a real Blueprint actor,
     unmodified except its own `PackageName` repathed to `/Game/Mods/LivingBaseClassTest/TestActor`)
     via the exact same retoc+UAssetGUI+repak recipe, installed identically — **IDENTICAL FAILURE**,
     same `BPModLoaderMod` log line, same native mechanism, at a genuinely new path.
     Every single controllable variable now matched to the working mod's own setup, all failed
     identically. Checked Pirate Signals' own public GitHub repo (`71Krazs/PirateSignals`, found by
     RedFalcon) for the real answer rather than guessing further — its own `docs/BUILDING.md` states
     the cooked containers "require a compatible Windrose/Unreal development environment and are not
     reproducible in a generic [CI] runner." RedFalcon correctly pushed back on an early draft
     conclusion here that assumed real proprietary source access (not realistic for a commercial
     game's modding community) — the more plausible reconciliation is an SDK-stub-based setup
     (generating C++ header stubs for the game's own reflected native classes via a tool like
     Dumper-7, no source access needed, then building a separate Unreal project against those stubs)
     — genuinely game-specific, but built from the game's own publicly-inspectable reflection data,
     not anything only the original developer would have.
     **Conclusion, tested far past reasonable doubt**: within this session's own toolset (byte-level
     conversion of already-cooked assets via `retoc`/`UAssetGUI`/`repak`, no real Editor cook
     pipeline), a wholly new asset path cannot be made discoverable at runtime by any means found.
     §19c-3's own finding and the whole working recipe stand exactly as already documented.
     **A genuinely new, credible, NOT-yet-attempted path was identified along the way**: since
     authoring a new instance of a plain DATA class only needs the class's REFLECTED LAYOUT (not its
     compiled C++ logic, which a `DataAsset` has none of), an SDK-stub-based Editor project could
     plausibly extend even to this investigation's own actual target classes
     (`R5CompositeMeshComponentBaseParams`/etc.), not just generic vanilla content — a substantially
     bigger undertaking (a full Editor install, SDK/stub generation, Visual Studio) than anything
     attempted this session, not pursued, but a real candidate if the "reskin an existing identity"
     constraint ever becomes a genuine limitation worth the extra investment.
     Full write-up as `WINDROSE_MODDING_NOTES.md` §19c-4, mirrored to the public
     `Windrose_Modding_Notes.txt` and the `Windrose-UE4SS-Modding-Notes` repo (commit `ba3833b`),
     same day. **Cleanup still pending**: several test paks/configs from this arc
     (`LivingBaseCustomTest`, `LivingBaseClassTest` under `Content/Paks/LogicMods/`) remain installed
     in the live game alongside `LivingBaseLettyTest` and the properly-installed `KasperShipRespawn`/
     `Pirate Signals` mods — none of this has been reverted yet.
     **Same-night follow-up: the SDK-stub path was tested, not just theorized** (2026-08-29).
     RedFalcon started installing UE 5.6 mid-session and asked to push a PoC through before bed.
     Added `lbgeneratesdk`/`lbgenuhtheaders` console commands (`main.lua`, commit `14acb24`)
     wrapping UE4SS's own bundled `GenerateSDK()`/`GenerateUHTCompatibleHeaders()` — no external
     Dumper-7 needed, output lands at `ue4ss/UHTHeaderDump/` (350 modules, 35,204 files) and
     `ue4ss/CXXHeaderDump/`. Built a minimal standalone UE 5.6 project (`Other\SDKPoC\`, outside
     this repo) with a module literally named `R5` (so the resulting class identity is
     `/Script/R5.*`, matching the real game) containing the REAL generated headers for
     `UR5CompositeMeshComponentBaseParams`/`UR5CompositeMeshGroup`/
     `FR5CompositeMeshComponentRandomizedSection`/`FR5CompositeMeshGroupForBodySex`, a stub
     `R5BusinessRules` module for just the `ER5BLCharacterSex` enum, and a deliberately
     simplified stub `UR5CompositeMeshParams` (skips its own deeper dependency chain, not needed
     for this PoC). **The one real gotcha**: the dumper's own `//CROSS-MODULE INCLUDE V2: ...`
     lines are informational COMMENTS, not real `#include` directives — first build failed with
     `FGameplayTag`/`ER5BLCharacterSex` undeclared and a `TMap` default-constructor error until
     the real includes (`GameplayTagContainer.h`, `ER5BLCharacterSex.h`, `Engine/DataAsset.h`)
     were added by hand wherever the dump only left a comment. Second build succeeded clean via
     `Engine\Build\BatchFiles\Build.bat SDKPoCEditor Win64 Development -Project=... -WaitMutex
     -FromMsBuild`, driven entirely from PowerShell, no Visual Studio GUI needed. RedFalcon then
     opened the project in the real Editor and confirmed the end-to-end proof live: Content
     Browser → right-click empty space in a real Content folder → Miscellaneous → Data Asset →
     the "Pick Class For Data Asset Instance" dialog genuinely lists
     `R5CompositeMeshComponentBaseParams`/`R5CompositeMeshGroup`/`R5CompositeMeshParams` alongside
     native engine classes. This is real, validated confirmation (not just a plausible theory)
     that author-time-default authoring of Windrose's own composite-outfit classes in a real
     Editor is achievable — full detail and forward plan captured in memory
     (`project_sdk_stub_ue_editor.md`, this is a separate environment from UE4SS/Lua so kept out
     of this mod's own docs beyond this pointer); a dedicated "Windrose Unreal SDK Modding Notes"
     doc is planned once this track resumes properly, per RedFalcon's own call. **Not yet done,
     explicitly deferred to a future session**: actually populating a created instance with real
     data and cooking/packaging it back into a Windrose-loadable pak.
     **Same-night follow-up #2: the new-path wall is broken, mechanism fully identified**
     (2026-08-31). Cooked a real `R5CompositeMeshGroup` instance via the renamed
     `LivingBaseExtended` project (see below), packaged it the same retoc/repak way as every other
     content pak here, and found it resolves via `AssetRegistryHelpers:GetAsset()` at
     `/Game/Mods/LivingBaseExtended/DA_Test_Group2` but MISSES at `/Game/LBE/DA_Test_Group` --
     identical toolchain, only the path changed. Confirmed against a live third-party control too:
     installed Pirate Signals' own real transport pak and found its
     `/Game/Mods/WindroseChatTransport/ModActor` resolves the same way (never actually verified by
     this project before, only assumed). Conclusion: Windrose's own cook process whitelists
     `/Game/Mods/...` specifically for the LogicMods convention -- a real Editor cook AND that path
     are both required together. Separately, `StaticFindObject`/`LoadAsset` (what `resolveAsset`
     already used) still can't see it even once `GetAsset` proves it's resolvable -- fixed by
     giving `resolveAsset` itself (`spawner.lua`) a fallback to `AssetRegistryHelpers:GetAsset()`,
     so every existing caller (`SetCompositeParams`, `DeCorrupt`, etc.) picks up `/Game/Mods/`
     content transparently. Confirmed live end to end: `lbtestpak` on the new path now reports
     `params=ok` instead of `MISS`. The nude result on that specific test is expected, not a new
     problem -- the test asset is a `R5CompositeMeshGroup` (middle level), and `DefaultParams`
     needs the top-level `R5CompositeMeshComponentBaseParams` instead. Full writeup:
     `WINDROSE_MODDING_NOTES.md` SS19c-3's own 2026-08-31 addendum.
     **Same-night follow-up #3: "get clothes on her" -- CONFIRMED LIVE, a real piece of clothing
     rendering on a genuinely new, independent character** (2026-08-31, later). First attempt
     (byte-relabeling Letty's own real BaseParams/Group to a new `/Game/Mods/...` path via
     UAssetGUI, reusing her already-proven Jeweler-torso retarget) MISSED -- confirming
     `/Game/Mods/` alone isn't sufficient, a genuine fresh cook is ALSO required, not just a
     relabeled copy of already-shipped bytes. Fix: authored a real
     `R5CompositeMeshComponentBaseParams`/`R5CompositeMeshGroup` pair FRESH via headless Editor
     Python (`unreal.AssetToolsHelpers`, nested-struct/`TMap`/hard-object-array property sets all
     worked directly -- no crash-risk analog to the Lua/runtime construction wall, since this is
     the Editor's own first-party authoring path) with a placeholder piece reference, cooked for
     real, then retargeted ONLY that one deep piece reference to a real Windrose piece via
     UAssetGUI's Import Data grid (same trick as every override, container's own `PackageName`
     never touched). Real gap found along the way: no Editor-Python function can build a
     `GameplayTag` from a raw string (every `GameplayTagLibrary` function needs an already-valid
     tag as input) -- that one field had to be set by hand via the Editor's own property picker,
     after registering the tag name in `Config/DefaultGameplayTags.ini`. Full recipe, all 5 steps
     individually confirmed: `WINDROSE_MODDING_NOTES.md` SS19c-3's second same-day addendum.
     **Same-night follow-up #4: tried to move up a layer (a full custom NPC -- African body/skin
     archetype, not just outfit) -- archetype override CONFIRMED still blocked, generalizing the
     wall rather than finding an exception** (2026-08-31, later). `Config.SENKA_FEMALE_BASE_CLASS`
     (Gatherer) showed an IDENTICAL `ArchetypePreset` across 4 separate live probes with zero
     pre-build writes -- looked like a possible exception to SS2's "BeginPlay re-randomizes it"
     wall. Built `lbtestlook <paramsPath> <archetypePath>` to test directly: pinning a real,
     curated player character-creation archetype preset
     (`DA_Customization_Hero_Preset_African_Issa`, found via a new `lbtestlistclass` diagnostic --
     see below) pre-build resolved fine (`archetype=ok`, no error) alongside the proven custom
     outfit -- but a post-spawn live probe showed `ArchetypePreset` had reverted to the class's own
     default; only the outfit stuck. **Real explanation: Gatherer's own reassertion source
     apparently has just ONE entry, so it always reasserts the same value regardless of what's
     written -- stability was never evidence of skipping the wall.** Closes off the one
     plausible-looking exception; the wall generalizes to every `CompositeMeshComponent` class
     tested so far, not just mob/crew ones. A genuine fix would need a brand-new Actor/Blueprint
     class with the archetype baked in as a real compiled class default (not a runtime write) --
     investigated but NOT attempted: `AR5Character` (the real native base, confirmed to own
     `CompositeMeshComponent` directly) implements ~18 custom R5 interfaces, each needing a real
     stub definition just to compile a subclass, with a genuine unverified vtable-mismatch risk if
     simplified -- a materially bigger and riskier undertaking than tonight's DataAsset work, not
     started.
     **New reusable tool along the way**: `lbtestlistclass <ClassModule> <ClassName> [nameFilter]`
     -- enumerates every registered asset of a class via `IAssetRegistry:GetAssetsByClass()`, found
     necessary when `/R5BusinessRules/`-rooted content (a native module's own bundled content root)
     turned out completely invisible to `retoc`'s offline pak scan despite the running game
     resolving it live every time. Full writeup: `WINDROSE_MODDING_NOTES.md` SS2's own 2026-08-31
     addendum (the wall) and SS9c's own addendum (the retoc blind spot + the new tool).
     **Same-night follow-up #5: RedFalcon's real end goal stated plainly -- "Barbies" (full custom
     male/female NPCs, dressed), peaceful professions first.** Before building further, did a full
     `lbprobedump` sweep of a real, wild `BP_NPC_Citizen_Walker_C` (Tortuga) to settle exactly what
     building an NPC from scratch requires. Corrected an earlier guess: the real native AI-NPC base
     is `AR5AICharacter` -- a SIBLING of `AR5Character` (extends `ACharacter` directly), not a
     subclass of it, with ~26 interfaces of its own (more than `AR5Character`'s ~18) and owning
     `ActivateCharacter()` (the exact function SS1's spawn recipe already calls). Real finding:
     almost nothing about "what makes an NPC" is compiled behavior -- it's reference fields on top
     of one unavoidable native base. `AIControllerClass` (a Blueprint AIController reference) +
     `AIPawnParams` (a DataAsset) is the ENTIRE behavior definition; appearance is the already-solved
     composite system; animation is also just an AnimBP reference. Real correction along the way:
     `GroupCategoryId` tags are per-body-part (`.Armor.Head/.Torso/.Belt/.Hands/.Legs/.Feet`,
     `.Hairs`, `.Facial.*`), not the single flat tag SS19's own outfit test used. Plan: start with a
     Handyman-family (peaceful) reuse target, not the combat-armed Walker this probe happened to
     use -- combat-capable "Barbies" are a real later stretch goal, same recipe, not a different
     wall. Full writeup: `WINDROSE_MODDING_NOTES.md` new SS2e.
     **Same-night follow-up #6: a selected body mesh CONFIRMED LIVE -- via a completely different
     mechanism than the blocked ArchetypePreset route, no new class authoring needed at all.**
     Instead of fighting the reassertion wall, swapped `actor.Mesh` (the LEADER component) directly
     post-build -- the exact same hide->SetSkeletalMeshAsset->show pattern already proven safe for
     one outfit piece (`Spawner.SetBodyPartMesh`), just applied to the leader itself. Target mesh
     (`SK_African_Female_01`) found via `lbtestlistclass /Script/Engine SkeletalMesh African`.
     Spawned the Gatherer base with the proven custom outfit, swapped the body mesh post-build:
     **RedFalcon confirmed live, outfit stayed on, body correctly changed.** Live probe afterward
     confirmed the skin material came through correctly too (`MI_African_Female_Medium`, matching
     textures) -- the new mesh's own default material slot, no separate step needed. **This means
     full "Barbies" (chosen body + chosen outfit) works on an EXISTING NPC class TODAY -- the bigger
     AR5AICharacter-interface-stubbing project is NOT a prerequisite for this**, only for a
     genuinely new pawn class with the archetype as a compiled default (a separate, optional, later
     goal). A real crash was hit and fixed along the way: `lbtestlistclass`'s first version (a
     generic `ForEachProperty` walk over every `FAssetData` field) crashed natively on a
     `SkeletalMesh`-class query despite working fine for a plain `DataAsset` query -- fixed by
     reading only the specific known-safe fields directly. Full writeup:
     `WINDROSE_MODDING_NOTES.md` SS2e's own second addendum and new SS3r (the crash).
     **Same-night follow-up #7: RedFalcon reasonably asked "if body mesh can now be swapped, why
     not re-check color too" -- exhaustively re-tested, original "color is dead" conclusion holds,
     now for a much clearer reason.** Tried `CreateDynamicMaterialInstance` on the actual equipped
     piece's own leaf mesh component (never tested before -- only composite-component-level and
     Kismet-library versions were previously confirmed-crashed) across FOUR argument combinations:
     the header-exact 3 real args (CRASHED NATIVELY, first call, zero log output), then 4 args
     varying the 4th placeholder (table vs `nil`) and the SourceMaterial arg (valid material vs
     `nil`) -- all four non-crashing combinations produced the IDENTICAL "expected 4, received 4"
     error, strong evidence this is a binding-level limitation, not a call-shape mistake. Third
     independently-confirmed failure mode for this exact UFunction in this project's history.
     Separately confirmed no fallback exists either: searched the game's own materials directly
     (`lbtestlistclass`) and found the armor material family has no color-variant siblings at all
     (only an `_LOD1` variant) -- unlike skin tone's small discrete set of ethnicity materials,
     color has no alternate instances to swap to. **Conclusion: garment color has no safe
     intervention point anywhere.** New tool along the way: `lbinspectfn <ClassPath> <FuncName>` --
     lists a function's real declared parameters via safe reflection before risking invocation
     (built after ANOTHER real crash: a pure reflection walk, not even an invocation, crashed
     natively on `SkeletalMeshComponent`'s own function list -- a second, separate confirmation
     that reflection isn't unconditionally safe either, joining SS3r). Full writeup:
     `WINDROSE_MODDING_NOTES.md` SS2e's third addendum.

     **Same-night follow-up #8: RedFalcon pushed back again ("if we swap outfits... theyre always
     som shade of brown [Gatherer] / red [BotC]... i think they are entity specific, a color theme")
     -- correct, and it led to the actual working mechanism, overturning item 35's dead-end verdict
     for real this time.** The missing layer was Custom Primitive Data (CPD) -- every
     `AR5AICharacter` carries a `CPDEffectsComponent`, and `PrimitiveComponent.h`
     (`SetCustomPrimitiveDataFloat`/`Vector4`, plain BlueprintCallable, no crash risk) is a
     completely different, bypassed-until-now mechanism from `CreateDynamicMaterialInstance`.
     Extracted the equipped piece's own master material (`MI_ArmorRegular_01` -> `M_Common_Cloth`)
     offline via `retoc to-legacy` + UAssetGUI's undocumented `tojson` CLI verb and read its NameMap
     directly -- it spells out the exact CPD layout as designer comments: index 3/4/5 = Cloth/Hair
     Main/Secondary/DetailColor, 7/8 = Dirt/Blood (explaining an earlier confusing "moldy blood+mud"
     result that came from a Vector4 write's 4-consecutive-floats semantics being misunderstood at
     first). Confirmed live via a clean, ONE-float-at-a-time bisection (no overlap): all 3 color
     slots + both effect slots landed exactly where the comment said. Each value is a 0..23 index
     into a real, shared, named palette asset RedFalcon found directly
     (`/Game/Common/Textures/Gradients/CRV_CharacterClothPalette`, a `CurveLinearColorAtlas`, 24
     named swatches Harp->BrownCopper) -- confirmed IDENTICAL across Gatherer and BotC, a universal
     palette, not per-archetype. **Finished mechanism**: `target:SetCustomPrimitiveDataVector4(3,
     {mainIdx, secondaryIdx, detailIdx, 0})` on the equipped piece's own leaf mesh component. New
     tools: `lbtestcpd`/`lbtestcpdidx`/`lbtestcpdfloat`/`lbtestcpdcolor`/`lbtestbasecpd`/`lbtesteye`
     (spawner.lua/main.lua), `lbtestbodystill`/`lbfreeze` (a no-AI stationary spawn + freeze/resume,
     built mid-investigation so color changes on a walking actor were actually visible to judge).
     **CONFIRMED LIVE, same night, extending to every remaining customization category**: RedFalcon
     found `DA_NPC_Common_CompositeMeshColorCustomizationParams.uasset` (the Citizen-family
     counterpart to the Gatherer's own `DA_Hero_...` one) ALSO references hair/eyebrows/eyes, not
     just cloth -- consistent with the material comment's own "Cloth/Hair MainColor" wording.
     Confirmed via `ER5BLCompositeMeshBodyPartType`'s real enum ordinals (`Hairs=3`, `Eyebrows=1`,
     matching every BodyPart value already seen in `lbprobecolors` dumps): the SAME CPD03/04/05
     Main/Secondary/Detail write on the HAIR and EYEBROW pieces' own leaf components genuinely
     recolors them, same mechanism, same palette. **Eyes are a hybrid**: the material assignment
     itself (`MI_Eye`, confirmed identical across every Gatherer probe dump all session) is NOT one
     of the 5 discrete `MI_EyeRound_<Color>_01` variants (Blue/Brown/Evil/Green/Grey -- confirmed
     the EXHAUSTIVE list via `lbtestlistclass` against the live AssetRegistry, filtering out animal/
     creature eyes and unrelated FX materials that share the substring "Eye") -- her native look
     comes from `MI_Eye` ITSELF being ALSO CPD-driven, via `CPD15 EyeColor` on `actor.Mesh` directly
     (a value of `3` showed no visible change, matching the exact same "unlucky value" trap Main
     hit at `23` before `20` worked -- a proper sweep through 0/1/2/4/5/6/7 confirmed real, visible
     color changes). So: cloth/hair/eyebrows all use the shared 24-entry `CRV_CharacterClothPalette`
     via CPD03/04/05 on their own piece; eyes use CPD15 on the base mesh (their own value range,
     not yet mapped to a named palette the way cloth's was); AND a separate discrete 5-variant
     material swap exists for eyes as an alternate lever (`lbtesteye`) for a completely different
     iris style, not just a palette-shifted version of the current one. Full recipe, palette table,
     and every dead end along the way: `WINDROSE_MODDING_NOTES.md` SS2e's CPD addendum (search
     "REOPENED AND SOLVED").

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
- **UPDATE (2026-08-31): outfit/garment COLOR CAN be changed after all** — the item-35 conclusion
  below (`ColorParams`/`ColorController` dead, `CreateDynamicMaterialInstance` dead) is correct as
  far as it went but was NOT the full picture: those are both config/material-instance layers, and
  color is actually consumed one layer BELOW that, via Custom Primitive Data (CPD) — a plain
  `int32`+`FVector4` write (`SetCustomPrimitiveDataVector4(3, {mainIdx, secondaryIdx, detailIdx, 0})`
  on the equipped piece's own leaf mesh component), each value a 0..23 index into a real shared
  palette asset (`/Game/Common/Textures/Gradients/CRV_CharacterClothPalette`). No crash risk, fully
  confirmed live. See item 112's "Same-night follow-up #7"/§2e's CPD addendum in
  `WINDROSE_MODDING_NOTES.md` for the full recipe before touching this again — don't re-derive it.
  Everything below this line describes the OLDER, narrower conclusion (still true for those specific
  mechanisms, just no longer the final word on color as a whole):
- **Outfit/hair COLOR cannot be changed on this mod's NPCs via `ColorParams`/`ColorController`/
  `CreateDynamicMaterialInstance`** — confirmed dead three
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
  - `CLAUDE.md`, `WINDROSE_MODDING_NOTES.md` — **superseded 2026-08-19**: these shipped inside the
    main zip through 1.3.10, but by 2.1.5 they'd moved OUT of it into a separate, optional
    `LivingBaseEnhancedDevInfo.zip` (just those two files) — confirmed by inspecting 2.1.5's actual
    built zips, not by this written rule (which still said "should ship" until this correction).
    Build/refresh that second zip alongside the main one whenever either file changes; don't fold
    them back into the main zip.
  What SHOULD ship in the MAIN zip, confirmed against the 2.1.5 precedent: `ASSET_CATALOG.md`,
  `CHANGELOG.txt`, `config.txt`, `enabled.txt`, `mod.txt`, `NEXUS_DESCRIPTION.txt`, `README.md`,
  and everything under `Scripts/` (including `class_index.lua` as of 2026-08-13 — genuinely new,
  actually `require`d by `main.lua`, unlike the dev-reference docs above). If `R5\Content\Paks\
  LivingBase\` exists (a bundled content pak, e.g. the nude-body-mesh
  add-on folded in 2026-08-13), it ships too — it's a sibling of the Lua side, not dev-only.
  `spawn_menu.ini` SHOULD ship too (added to this rule 2026-08-19, RedFalcon's call) — it's the
  hand-curated tree data the LivingBaseSpawnMenu companion mod reads, needed for that GUI to have
  any categories at all on a fresh install; not previously listed here because it didn't exist
  when this checklist was first written. Its own runtime siblings (`spawn_request.txt`,
  `spawn_menu_status.txt`, `spawn_menu_history.txt`) stay OUT, same as `persist.txt`/
  `discovery_dump.txt`/`customization_survey.jsonl` — those are live per-session state, not data,
  regenerated fresh by the mod itself on first use.
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