--[[
 LivingBase / config.lua
 Central constants. Every game-version-dependent string lives HERE.
 Class paths below were discovered from the player's own world dump
 (2026-07-06). A game patch may invalidate them; re-run discovery if
 spawns silently fail after an update.
]]

local Config = {}

-- Verbose per-spawn logging. Off for smooth play; set true to debug.
Config.VERBOSE = false

-- DECOR_COLLISION: spawn decorations SOLID (player collides with them) instead of pass-through. Physics
-- is frozen so a solid prop can't eject/drop. false = old pass-through behavior. Restored decorations
-- are solidified on load, so flipping this doesn't require respawning existing props (just a reload).
Config.DECOR_COLLISION = true

-- UNLOCK_HIDDEN_BUILDING: surface build-menu pieces that are hidden from standard play (bShowItem=false)
-- WITHOUT touching normal progression (standard items keep their recipe gate). Session-only — it edits
-- loaded data assets, which reset each launch, so it never affects the save. See unlockbuild.lua.
Config.UNLOCK_HIDDEN_BUILDING = false

-- Config.KEYS_ENABLED_ONSTART / the "In-Game Keys" on-off toggle concept REMOVED (2026-08-24,
-- numpad-only keybind rebuild) -- every in-game key is numpad now, and every numpad key (other
-- than Config.KEYS.toggleWindow itself, which has to stay reachable to open the window in the
-- first place) is gated purely on the LivingBaseSpawnMenu window being open, via windowGatedAction
-- (main.lua) -- the same gate confirmPlacement/cancelPlacement/grabTarget/targetLock already used.
-- There's no longer a separate "enabled" concept to toggle: closing the window IS turning the keys
-- off. Config.KEYS.toggleMod ('INS') is removed for the same reason -- nothing left to toggle.

-- Auto-restore the saved crowd on world load?
--   true  = your placed base repopulates automatically when you load in (default).
--   false = nothing comes back on its own; place everything by keystroke each
--           session (spawns are still SAVED, just not auto-restored).
-- Clean-house (DEL) always clears the save file regardless of this setting.
Config.RESTORE_ON_LOAD = true
-- Wait this long after the player pawn appears before restoring (lets the world finish
-- streaming — restoring mid-load crashed natively in ActivateCharacter). Then restore
-- spawns one pawn per ~180ms rather than all at once.
Config.RESTORE_SETTLE_MS = 6000
-- Restored spawns still need their post-processing (Senkamati de-corrupt/passive, goat
-- perception-strip) — but that's COMPONENT SURGERY and doing it mid-load crashed. So it
-- runs only after the world is fully stable (this delay after the last spawn), one actor
-- at a time. Set RESTORE_POSTPROCESS=false to skip it entirely if it ever still crashes
-- (restored goats will flee / the Caster returns corrupted, but the world loads clean).
Config.RESTORE_POSTPROCESS = true
Config.RESTORE_POSTPROCESS_MS = 8000
-- Spread-out timings for HEAVY worlds. Restore spawns one pawn per RESTORE_STAGGER_MS, then
-- runs post-processing one pawn per RESTORE_POSTPROCESS_SPACING_MS. Bigger = gentler on the
-- engine (a heavy base takes longer to fully populate, but is far less likely to choke the
-- game thread on load). Raise these if a big base still hitches/crashes on load.
Config.RESTORE_STAGGER_MS = 350          -- movers (crew/townsfolk/animals) — each wakes an AI
Config.RESTORE_STATIC_STAGGER_MS = 150   -- statues (posed AnimatedActors / QuestStatic) — cheap
Config.RESTORE_POSTPROCESS_SPACING_MS = 400
-- Max time scheduleRestorePostProcess will WAIT for outstanding async post-process work
-- (Spawner.postProcessPending, see its own comment) before giving up and firing "base
-- restored and ready" anyway (2026-08-11). Safety valve: main.lua's restoreLockActive
-- key-gate depends on that callback eventually firing, so a miscounted/stuck restoreHook
-- rule must not lock the player out of every mod key forever.
Config.POSTPROCESS_WAIT_TIMEOUT_MS = 30000
-- How many actors' worth of composite/component surgery (Senkamati de-corrupt/reskin,
-- female-walker reskin) Spawner.RunSerialized lets run at once (2026-08-11). Was strict 1
-- (see that function's own comment for the crash it fixes) until RedFalcon reported a big restore
-- took noticeably longer that way; raised to 3 as a middle ground -- not proven safe at any
-- value above 1, so if crashes resume, lower this back toward 1 before suspecting anything else.
Config.POSTPROCESS_MAX_CONCURRENT = 3
-- Pause after the restore begins, BEFORE the first actor spawns. A statue-led base absorbed
-- this naturally; an all-movers base spawned an AI pawn in the restore's own frame and died.
Config.RESTORE_LEAD_IN_MS = 2000
-- Min gap between two keypress-spawns. Two composite builds in the same instant crash the
-- engine, so an accidental double-press is ignored within this window.
Config.SPAWN_DEBOUNCE_MS = 300
-- DEL (clean house) wipes everything, so it needs two presses to confirm; the arm disarms after this.
Config.CLEAR_CONFIRM_MS = 3000
-- The player pawn exists DURING the loading screen, so it can't gate the restore on its own.
-- Wait until the player moves this far horizontally (uu) — only possible once the world is
-- actually live. Spawning movers mid-stream hung the game. Fall back after TIMEOUT_S if the
-- player loads in and just stands there.
Config.RESTORE_MOVE_EPSILON = 100
Config.RESTORE_MOVE_TIMEOUT_S = 120
-- How long to wait after a Senkamati MOB (Caster/Hunter) spawns before de-corrupting its
-- meshes — must be long enough for its composite to finish building, or the mesh surgery
-- crashes natively. The crew Warrior uses WARRIOR_DECORRUPT_DELAY_MS for the same reason.
Config.MOB_DECORRUPT_DELAY_MS = 4000
-- Same wait for the crew Warrior's composite. Both were undeclared `or 4000` fallbacks in
-- testbed.lua; declared here so every tuning knob lives in config (project rule).
Config.WARRIOR_DECORRUPT_DELAY_MS = 4000
-- "despawn what's in front of me" (NUM_NINE) reach, in unreal units.
-- Was 700 (tuned for "anything in the room"), which made it easy to despawn the wrong thing out of a
-- cluster of spawns. Tightened to roughly match the vertical same-floor band below, same reasoning as
-- LIVE_EDIT_MAX_DIST: walk up to the specific bad spawn rather than reaching across the room for it.
Config.DESPAWN_FRONT_UU = 250.0
-- ...and the vertical band: only consider spawns within this many UU of the PLAYER'S Z, so it can't
-- reach down/up through a floor and delete a character on a different storey (RedFalcon hit this). ~250uu
-- is about one character height — same floor only. Raise if you place things on tall props.
Config.DESPAWN_FRONT_Z_UU = 250.0
-- WARRIOR HAIR. The de-corrupt replaces his hair with dreadlocks and swaps MI_Hair -> black; both
-- stay. The crew composite sometimes re-asserts its own hair material afterwards and he comes out
-- light-haired. We used to read the colour back and HIDE the hair when it hadn't taken —
-- RedFalcon (2026-07-09): that never worked properly, so it is gone. Don't force baldness; a
-- light-haired Warrior just gets respawned. Spawner.EnforceDarkHair was deleted with it.

-- WARRIOR SHIELD. Harvested live from BP_Mob_SenkamatiCorrupted_Regular_Warrior (2026-07-09):
-- the mob carries a SkeletalMeshComponent "Temp_SkeletalMesh_Shield" holding
-- SK_Weapon_Dendromorph_ShieldMedium on socket "ik_weapon_lSocket" of CharacterMesh0.
-- That is the LEFT/offhand socket -- the game puts the shield left and the macuahuitl right.
-- We ADD a component and attach it; we never replace an armour mesh (those are skinned to the
-- body and a shield swapped onto one would deform into garbage).
Config.WARRIOR_SHIELD = true
Config.WARRIOR_SHIELD_MESH =
  "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Dendromorph/SK_Weapon_Dendromorph_ShieldMedium.SK_Weapon_Dendromorph_ShieldMedium"
Config.WARRIOR_SHIELD_SOCKET = "ik_weapon_lSocket"
-- The socket DOES exist on the crew rig (it's their left pistol hand), so the attach works — but it
-- inherits a WEAPON GRIP orientation, so the Warrior holds the shield out like a pistol. The mob's
-- creature skeleton orients that socket differently, which is why identity worked there and not
-- here. Fix is a rotation offset, not a different socket.
-- Candidates are tried in order; K2_AttachToComponent does NOT fail on a missing socket (it
-- silently attaches at the component origin), so we verify with DoesSocketExist first.
Config.WARRIOR_SHIELD_SOCKETS = { "ik_weapon_lSocket", "ik_hand_lSocket", "hand_lSocket", "hand_l" }
Config.WARRIOR_SHIELD_OFFSET   = { X = 0.0, Y = 0.0, Z = 0.0 }
-- Tuned in-game by RedFalcon with the live nudger (2026-07-10, 64 nudges). Read straight off the log.
Config.WARRIOR_SHIELD_ROTATION = { Pitch = 90.0, Yaw = 165.0, Roll = -15.0 }
-- Combat disturbs the shield: it's aligned until the warrior fights, then sits wrong afterward. We
-- re-assert the attachment + tuned rotation when he LEAVES combat, checked on this slow tick.
Config.SHIELD_REASSERT_MS = 2000

-- LIVE EDIT: raise/lower + rotate the placed object in front of you, in place and persistently, to
-- fine-tune sitters and decorations in the base. Rotate step + height step per keypress. The log
-- prints the running yaw offset (bake into a sitter's `yaw`) and height.
-- Config.LIVE_EDIT (the on/off flag this used to require) REMOVED (2026-08-24, numpad-only keybind
-- rebuild) -- this functionality is unconditionally registered now, gated purely on the
-- LivingBaseSpawnMenu window being open (windowGatedAction, main.lua) like everything else, same
-- as Config.KEYS_ENABLED_ONSTART's own removal note above. The step-size constants below are still
-- read live by the new numpad move/rotate handlers.
Config.LIVE_EDIT_ROTATE_STEP = 15.0   -- deg per press (45 was too strong; 15 = finer control)
-- Bumped from 8/10: ue4ss.log confirmed targeting + accumulation are both correct (right object every
-- time, offsets add up correctly press to press) — the "unresponsive" feel is that a lot of keydown
-- events never reach the mod at all (engine drops most repeats for these keys), so few small nudges land.
-- Can't fix the drop rate from Lua, so making each nudge that DOES land bigger and more noticeable.
Config.LIVE_EDIT_HEIGHT_STEP = 20.0   -- uu per press (was 8)
Config.LIVE_EDIT_MOVE_STEP   = 30.0   -- uu per press for arrow-key slide (was 10)
-- How close you must be (and roughly facing) an object for a live-edit key to pick it as the target.
-- Kept separate from DESPAWN_FRONT_UU (700, tuned for "anything in the room") so live-edit can be much
-- tighter — you're standing right next to the thing you're nudging, so there's no reason to search
-- further than this and risk grabbing a different nearby spawn. Only matters for an UNLOCKED pick (every
-- ordinary press, and the moment Num+ establishes a new target lock) — once Spawner.lockedTarget is set,
-- this radius/cone is bypassed by the shared picker (findNearestSpawnInFront, spawner.lua) in favor of
-- the much more generous TARGET_LOCK_MAX_DIST below, so a locked object keeps getting hit after walking
-- away or turning to look elsewhere, up to that larger leash.
-- Raised 200 -> 500 -> 600 (2026-08-20). Now shared by BOTH target-lock's cone/distance fallback
-- AND the hover-highlight raycast (Spawner.UpdateHoverHighlight reads this same value) -- RedFalcon:
-- "target and highlight should be synced both by source and by distance... it doesn't make sense
-- otherwise" -- so this one number is the single source of truth for both. As of 2026-08-20 the
-- raycast itself is now the ONLY source (target-lock no longer falls back to this file's cone sweep
-- at all -- see pickTargetPreferringHover's own comment), so this value now purely tunes the
-- raycast's reach. The raycast traces from the CAMERA (must stay that way -- see
-- Spawner.UpdateHoverHighlight's own comment for why mixing pawn-position with camera-direction is a
-- confirmed-broken anti-pattern here), and in third person the camera sits noticeably behind the
-- player -- RedFalcon eyeballed that gap at ~100uu. 1100 (was 600) is the visual compensation for
-- that offset, tuned live rather than computed, so the ray's effective forward reach FROM THE PLAYER
-- roughly matches the old 600uu number. The separate "how far can a lock survive walking away"
-- leash (Config.TARGET_LOCK_MAX_DIST, Spawner.TargetLockDistanceCheck) is untouched by this --
-- that check is already pawn-based, not camera-based, per RedFalcon's explicit "target drop" ask.
Config.LIVE_EDIT_MAX_DIST = 1100.0
-- Placement zoom (2026-08-20): Spawner.AdjustPlacementDistance's step size and clamp range for
-- Config.KEYS.placementZoomIn/Out. MIN keeps it off the camera's own near-clip / out of the pawn's
-- own collision.
-- MAX: 2000 -> lowered to 750 (2026-08-21) when RedFalcon reported the statue's forward raycast
-- "freaks out" around 800uu -- then RAISED BACK to 1800 the same day once the real cause turned out
-- to be aim angle, not a hard raycast distance limit (see beginFollowLoop's own comment): the ray
-- follows the camera's exact view direction, so at longer range it needs MORE downward pitch to
-- still reach the same relative floor point -- purely geometric, not a raycast breakdown. RedFalcon:
-- "my brain was thinking max 1000 not 2000" (the original number when this was first bumped up from
-- decor's old close-range default) -- 1800 splits the difference, comfortably under the old 2000
-- ceiling while well past the ~1000 RedFalcon actually had in mind.
Config.PLACEMENT_ZOOM_STEP_UU = 50.0
Config.PLACEMENT_ZOOM_MIN_UU = 100.0
Config.PLACEMENT_ZOOM_MAX_UU = 1800.0
-- Starting follow distance for a FRESH spawn (F5 flow via the spawn menu) -- was a hardcoded 300uu
-- fallback inside beginFollowLoop itself. Matched to the 1800uu max above (2026-08-21, RedFalcon:
-- "i want to change that 750 to 1800, because as i said i misunderstood the distances we were
-- working with before") -- starts at FULL reach immediately, no zooming needed to use the whole
-- range; PAUSE/HOME (Spawner.AdjustPlacementDistance) can still pull it closer if wanted. Applies to
-- decor AND statues (RedFalcon's explicit call). Doesn't affect StartRelocatePreview (F7) -- that
-- always computes its own grab distance from where the object already was, this only matters for a
-- brand new spawn.
Config.PLACEMENT_START_DIST_UU = 1800.0
-- Free-build mode (2026-08-21, RedFalcon: "a floor collision toggle so that items can also behave
-- as they did before with the same static limit. That way if they want to free build they can.")
-- -- F8 (Spawner.ToggleFreeBuild) flips the floor-lock raycast off entirely (statues AND decor) in
-- favor of the pre-floor-lock center-anchored/static-distance behavior, unaffected by
-- Config.PLACEMENT_FLOOR_LOCK_DECOR. START_DIST is its own separate spawn distance -- RedFalcon:
-- "set the distance at 350uu, that will be about one platform distance from the player" -- NOT the
-- same as the 1800uu non-free-build default above. MIN_GRAB_UU is a floor-build-only clamp on F7's
-- grabDistance ("keep the original distance unless it reaches or is less than 125uu from the
-- camera -- that should be about when a camera zoom in will freak out") -- non-free-build grabs are
-- untouched by this (RedFalcon: "for non free build spawning and grabbing, keep it exactly as it
-- is"), still measuring/using the real distance with no clamp at all.
-- Both bumped +100uu (2026-08-21, RedFalcon: "the distance for spawning and minimum distance while
-- moving in free build needs to be further. lets add 100 to the distance.") -- 350->450 spawn,
-- 125->225 grab floor.
Config.PLACEMENT_FREEBUILD_START_DIST_UU = 450.0
Config.PLACEMENT_FREEBUILD_MIN_GRAB_UU = 225.0
-- NiagaraActor highlight scale (2026-08-21, RedFalcon: "is it possible to resize it to match the
-- hitbox of the object?") -- BASE_RADIUS_UU is the object size the effect's default 1x scale was
-- eyeballed against (largest half-extent axis of GetActorBounds) -- tune this once you've seen the
-- scaled version live on a few different-sized objects. MIN/MAX_SCALE clamp so a tiny trinket or a
-- huge statue can't produce a degenerate (invisible or absurdly huge) scale.
Config.NIAGARA_HIGHLIGHT_BASE_RADIUS_UU = 50.0
Config.NIAGARA_HIGHLIGHT_MIN_SCALE = 0.3
Config.NIAGARA_HIGHLIGHT_MAX_SCALE = 4.0
-- PRODUCTION hover-highlight for character targets (2026-08-22, RedFalcon: "use the effect thing we
-- were trying but us this effect halfway up their body... It loops, is small and is visible through
-- objects") -- replaces the material-swap ghost highlight for statues/walkers/Senkamati (anything
-- with a SkeletalMeshComponent); decor keeps the material swap. Fixed scale, not bounds-based like
-- the test tooling's ground-ring use case -- this sits mid-body regardless of the target's size.
Config.HOVER_EFFECT_SCALE = 0.6
-- ISOLATION TEST RESULT (2026-08-21, RedFalcon: "let's disable the other slot and see if it
-- doesn't change. if not then we know they're tied together") -- with this flag ON (full no-op,
-- zero material slots touched on hover), the white area around the eyes still appeared exactly the
-- same. CONFIRMED: not caused by our highlight/restore code -- same pre-existing root cause as the
-- skin-white issue (RedFalcon: "i think we can go ahead and say they are connected"), just visible
-- on the eye area too. Nothing left for our own code to fix here. Back to false -- normal
-- highlighting restored (skin+eye slots still individually skipped, see applyHoverHighlight).
Config.HOVER_HIGHLIGHT_DISABLE_ALL_TEST = false
-- Placement camera raise + FOV widen (2026-08-22) -- height raise confirmed live via lbprobecam
-- (in vs. out of real build mode): camera height +35uu relative to the pawn, FOV 70 -> 76 (+6).
-- FOV now confirmed working too (RedFalcon: "fov works"), via a detach-first fix found by reading a
-- reference UE4SS camera mod (Other\Camera Toggle System (UE4SS)-32-4-1-1778381431): Windrose's
-- FollowCamera has a settings-driven camera system (CameraParams) that keeps re-asserting its own
-- FOV unless you explicitly detach first (bUseSettingsFov = false, CameraParams = nil) -- see
-- Spawner.ApplyPlacementCameraOffset's own comment for the full history. A separate camera-pullback
-- (TargetArmLength) experiment was also tried and REMOVED -- RedFalcon: "not the backwards 100 of
-- the sprintarm we tried" -- only the height raise + FOV ship now.
Config.PLACEMENT_CAMERA_RAISE_UU = 35.0
Config.PLACEMENT_CAMERA_FOV_DELTA = 6.0
-- How tightly you must actually be LOOKING at an object (camera direction, pitch included — not just
-- have it somewhere in front of your body) for findNearestSpawnInFront to consider it a candidate at
-- all. Shared by despawn/live-edit/cycle-pose — they all pick their target through that one function.
-- Was `dot > 0` on flat pawn-body yaw, i.e. a full 90-degree hemisphere ignoring up/down entirely: with
-- two spawns near each other (or stacked vertically), "nearest" could easily win over "the one you're
-- actually looking at". WindroseTextSigns (a separate UE4SS mod, targets native signs for its own text
-- editor) reportedly targets more reliably and tracks the reticle including vertical look (confirmed by
-- being able to pick between two signs stacked on top of each other) — its shipped config uses a narrow
-- ~23-degree cone (`WTS_MIN_VIEW_DOT=0.92`) at long range (1000uu). This cosine threshold now applies
-- to the CAMERA's look direction (see findNearestSpawnInFront's comment for why that's safe to change
-- here specifically, without reopening the earlier camera-for-movement regression). 0.90 ~= a
-- 25.8-degree half-angle — tighter than before, a bit more forgiving than WTS's exact value since our
-- ranges are much shorter. Still bypassed under MIN_STABLE_DIST (point-blank) the same way the old
-- check was, since angle noise gets worse, not better, at close range.
Config.TARGET_MIN_VIEW_DOT = 0.90

-- How far you can walk from a LOCKED target (Num+, Spawner.ToggleTargetLock) before the lock
-- auto-releases (2026-08-13, added after RedFalcon used the lock live and asked for one). This project's
-- own conversion (see LEASH_RADIUS_UU's comment further down): 100uu ~= 1 meter. 1500uu ~= 15m — enough
-- to walk fully around a statue, step back to check a whole structure, or glance at a nearby build
-- bench, without losing the lock, but tight enough that wandering off to a different part of the base
-- releases it rather than silently keeping despawn/cycle/live-edit pinned to something you've left
-- behind. Deliberately much larger than LIVE_EDIT_MAX_DIST (200uu) — that radius is for the INITIAL
-- unlocked pick (staying close enough to be sure you're aiming at the right thing); this one is for
-- staying LOCKED once you already are, a different and more forgiving question. Checked in
-- findNearestSpawnInFront (spawner.lua) against the PLAYER'S body position, same as every other
-- distance check in that function — not the camera, for the same "how far can I actually reach"
-- reasoning DESPAWN_FRONT_UU/LIVE_EDIT_MAX_DIST already use.
-- Bumped 1500 -> 1900 (2026-08-22, RedFalcon: "since we have the max distance for spawning at
-- 1800uu, but the untargeting limit is 1500, it gets untargeted during far placement... give some
-- wiggle room") -- this is PAWN-based while Config.PLACEMENT_ZOOM_MAX_UU (1800) is CAMERA-based, so
-- an object placed at the full 1800uu camera distance could exceed a pawn-based 1500uu leash before
-- ever reaching it, auto-releasing the lock mid-placement. 1900 clears the max placement distance
-- with margin to spare.
Config.TARGET_LOCK_MAX_DIST = 1900.0
-- How often (ms) the periodic tick (Spawner.StartTargetLockTick, started only while a lock is active
-- and self-stopping the moment it isn't -- see that function's own comment) re-checks TARGET_LOCK_MAX_DIST
-- against a locked target, so walking away releases the lock on its own without needing to press
-- another mod key first. Same order of magnitude as LEASH_INTERVAL_MS (3000, a different feature's own
-- periodic check) -- frequent enough that "walked away" feels prompt, not so frequent it's wasted work
-- for a value (position) that only changes as fast as the player walks.
Config.TARGET_LOCK_CHECK_MS = 2000

-- SHIP RIDER TICK (2026-08-25) -- how often a non-Character actor "moored" to a ship
-- (Spawner.AddShipRider/ShipRiderTick) has its position/rotation re-synced to the ship's
-- CURRENT transform. Exists because the real engine attach (Spawner.AttachActorToShip)
-- CONFIRMED CRASHES THE GAME LIVE (CLAUDE.md item 71) -- this is the safe fallback: recompute
-- world position each tick from a fixed local (forward/right/up) offset via the same proven
-- Spawner.ShipLocalToWorld math §13 already confirmed holds through real sailing/turning, then
-- K2_SetActorLocation/K2_SetActorRotation (both already proven safe everywhere else in this
-- file) -- no attach call at all.
-- 200ms (5/sec) CONFIRMED LIVE (2026-08-25) as too slow -- RedFalcon reported visible jitter: the
-- statue sits frozen while the ship's own bob/sail motion (rendered every frame) moves out from
-- under it, then snaps back, 5 times a second. Raised to 40ms (25/sec) -- still two plain
-- transform writes per tick, same trivial cost reasoning as before (see TARGET_LOCK_CHECK_MS's
-- own comment for the "cheap either way" baseline), just paid 5x more often. This is a discrete
-- teleport either way, never truly continuous like a real attach would be -- expect SOME residual
-- stepping is possible at this rate too; if 40ms still isn't smooth enough, the next lever is a
-- shorter interval still (UE4SS's own timer resolution is the real floor, not cost), not a
-- fundamentally different mechanism.
Config.SHIP_RIDER_TICK_MS = 40

-- INVINCIBLE LIVESTOCK. makeSetDressing() already sets bCanBeDamaged=false, but damage in this
-- game flows through the GAS ability system, not UE's damage path -- which is why boars and goats
-- still die in raids. GE_Mob_ImmuneToDamage is the game's own mob immunity effect. Its /Game/ path
-- is not recorded in any dump, so we try guesses and then a by-name object search, and log
-- whatever resolves so it can be hardcoded.
Config.CREATURE_INVINCIBLE = true
Config.IMMUNE_GE_NAME = "GE_Mob_ImmuneToDamage_C"
-- CONFIRMED path (resolved live 2026-07-09 by the by-name search; hardcoded so we stop guessing).
Config.IMMUNE_GE_CANDIDATES = {
  "/Game/Gameplay/Character/AI/AIBaseLogic/CommonAbilities/AttributeTtracker/GE_Mob_ImmuneToDamage.GE_Mob_ImmuneToDamage_C",
}

-- Beat after the Warrior's de-corrupt settles, before the shield attaches.
Config.WARRIOR_POSTFIX_MS = 1500

------------------------------------------------------------
-- KEYBINDS — remap freely. Values are UE4SS key names (no CTRL added).
-- If a name is invalid, the mod falls back to the default and prints a note.
------------------------------------------------------------
-- NUMPAD-ONLY SCHEME (2026-08-24 rebuild, RedFalcon: "in game we should only be using the numpad
-- now" -- minimize in-game footprint/mod-collision risk now that the LivingBaseSpawnMenu window
-- covers all spawning). Every key below is gated on that window being open (windowGatedAction,
-- main.lua) except toggleWindow itself, which has to stay reachable to open the window in the
-- first place. ⚠ NumLock must be ON — with it OFF, Windows remaps the numpad to navigation keys
-- (1->End, 2->Down, ...) before UE4SS ever sees them, and the binds go dead -- this matters MORE
-- now than it used to, since every placement/movement control lives here, not just spawning.
--
-- Dual-purpose direction keys (7/8/4/6/5): MOVE (translate) by default, ROTATE (per-axis) once
-- Numpad 2 toggles Spawner.placementMode to "ROTATE" -- see spawner.lua's own comment on
-- Spawner.placementMode/TogglePlacementMode, and this file's numpadMoveOrRotate builder in the KEY
-- REGISTRATION section, for how these dispatch. Entering an active placement/relocate session
-- auto-forces Rotate mode (movement doesn't make sense on an object the follow loop is already
-- repositioning every tick from camera aim); confirming/cancelling forces back to Move.
-- 5/2 SWAPPED from the original numpad rebuild (2026-08-24, RedFalcon: "swapping 5 and 2 would
-- give more of a WASD feel and remove the chance to accidentally change mode based on
-- mispressing") -- 8/4/5/6 now sit in the same plus-shape as W/A/S/D (5 directly below 8, same as
-- S below W), and Change Mode moves off the key you're most likely to rest a finger on/reach
-- through during normal movement onto the far corner key instead.
Config.KEYS = {
  numpadUp    = "NUM_SEVEN",  -- Move: Up       | Rotate: X-
  numpadFwd   = "NUM_EIGHT",  -- Move: Forward  | Rotate: Y-
  numpadDown  = "NUM_NINE",   -- Move: Down     | Rotate: X+
  numpadLeft  = "NUM_FOUR",   -- Move: Left     | Rotate: Z-
  changeMode  = "NUM_TWO",    -- toggle Move <-> Rotate
  numpadRight = "NUM_SIX",    -- Move: Right    | Rotate: Z+
  numpadBack  = "NUM_FIVE",   -- Move: Backward | Rotate: Y+
  -- Steals OS focus for the LivingBaseSpawnMenu window (SetForegroundWindow, C++ side --
  -- StandaloneWindow.cpp) -- was OEM_EQUALS ('=') before the numpad rebuild.
  releaseCursor = "NUM_ONE",
  -- Despawn whatever's in front of you -- was NUM_NINE ("undo") before the numpad rebuild freed
  -- that slot for numpadDown.
  despawn = "NUM_THREE",
  -- Target lock (2026-08-13): pins despawn/live-edit to ONE tracked actor instead of re-picking
  -- "nearest in front" on every press -- lets you back away/turn to check an angle without losing
  -- it. UNCHANGED by the 2026-08-24 numpad rebuild.
  targetLock = "NUM_ADD",
  -- BUILD-GHOST-PREVIEW (2026-08-20): confirm/cancel a live-following placement started from the
  -- LivingBaseSpawnMenu Spawn button (see main.lua's pollSpawnMenuRequest + Spawner.
  -- ConfirmPlacement/CancelPlacement). Moved off F5/F6/F7/F8 onto the numpad (2026-08-24).
  cancelPlacement  = "NUM_DIVIDE",   -- was F6 -- destroy the currently-previewed object, no trace
  -- Grab-and-relocate (2026-08-20): pick up whatever's currently target-locked (Num+) and carry it
  -- like a fresh placement.
  grabTarget       = "NUM_MULTIPLY", -- was F7 -- start relocating the target-locked object
  -- Opens/closes the LivingBaseSpawnMenu window. The ONE key that stays reachable even while the
  -- window is closed -- there'd be no way to open it otherwise. Was OEM_MINUS ('-').
  toggleWindow     = "NUM_SUBTRACT",
  confirmPlacement = "NUM_ZERO",     -- was F5 -- lock the currently-previewed object in place
  -- Free-build/floor-clipping toggle (2026-08-21) -- flips floor-lock off/on globally. Was F8.
  toggleFreeBuild  = "NUM_DECIMAL",
}

-- Decor key bindings + category data live in fkeys.lua (see that file's own header) -- merge them
-- in here so the rest of the mod keeps reading Config.KEYS / Config.DECOR_CATEGORIES /
-- Config.DECOR_ORDER exactly as before.
do
    local FKeys = require("fkeys")
    for k, v in pairs(FKeys.KEYS) do Config.KEYS[k] = v end
    Config.DECOR_CATEGORIES = FKeys.DECOR_CATEGORIES
    Config.DECOR_ORDER = FKeys.DECOR_ORDER
end

-- Cone/range for Spawner.ProbeNearestActor — generous on purpose (this is a deliberate look-and-
-- press action, not fast-twitch targeting), shares Config.TARGET_MIN_VIEW_DOT for the cone.
Config.PROBE_MAX_DIST = 800.0
-- Candidates closer to the CAMERA than this are skipped outright. Exists because per-player manager
-- actors (PlayerCameraManager, the controller) sit at/near the camera's own position and would
-- otherwise win "nearest" trivially — see Spawner.ProbeNearestActor's own comment (confirmed live
-- 2026-08-07: every press returned PlayerCameraManager before this fix).
Config.PROBE_MIN_DIST = 50.0



Config.HARD_LEASH_UU = 6000


------------------------------------------------------------
-- LEASH: keep wandering NPCs (crew/townsmen) near where you PLACED them.
-- TWO-TIER (no more teleport jerk):
--   * Past LEASH_RADIUS_UU (soft): the NPC is told to WALK back home via its
--     AI — a natural stroll, not a snap. This is how the base's own NPCs stay
--     put. Re-issued every LEASH_INTERVAL_MS while it's outside.
--   * Past HARD_LEASH_UU (far backstop): it's teleported home. Only fires if
--     an NPC is truly stuck/way off (e.g. shoved off the navmesh) — rare.
-- Stationary spawns (statues/quest folk/women) never move, so this only
-- affects wanderers. 100 uu ≈ 1 m. Smaller LEASH_RADIUS_UU = tighter cluster.
------------------------------------------------------------
-- OFF by default (2026-07-09): the leash pinged every spawn every interval (MoveToLocation
-- across the whole crowd), which is pure overhead on a big base and a stability risk during
-- the load-settle window. Wanderers now roam free. Set true to re-enable the walk-home leash.
Config.LEASH_ENABLED     = false
Config.LEASH_RADIUS_UU   = 600    -- ~6 m wander leash: walk home past this
Config.LEASH_INTERVAL_MS = 2000   -- how often to check / re-nudge

------------------------------------------------------------
-- NPC CLASSES (discovered)
------------------------------------------------------------
Config.CREW_CLASS =
  "/Game/Gameplay/Character/AI/Crew/Regular/Faction/Player/BP_Mob_Crew_Regular_Player.BP_Mob_Crew_Regular_Player_C"

-- Base pawn re-skinned into the Senkamati WARRIOR. The default regular crew RANDOMIZES its
-- face/hair each spawn, and a roll that's missing a component (e.g. bald) can crash the
-- Senkamati composite rebuild (RedFalcon's theory). Swapping this to a FIXED-appearance officer
-- gives a consistent, always-complete base — try the player's own officer first (not a
-- quest NPC). Falls back to CREW_CLASS.
--   Officer (fixed):  /Game/Gameplay/Character/AI/Crew/Officer/Faction/Player/BP_Mob_Crew_Officer_Player.BP_Mob_Crew_Officer_Player_C
Config.WARRIOR_BASE_CLASS =
  "/Game/Gameplay/Character/AI/Crew/Officer/Faction/Player/BP_Mob_Crew_Officer_Player.BP_Mob_Crew_Officer_Player_C"

-- Friendly boar (farm vibe). BP_Mob_Boar_Friend is a friendly subclass of the
-- boar — no faction work needed. Exact /Game/ path unknown from the dump, so
-- the spawner tries these best-guesses in order; if all MISS, F8/F11 a boar and
-- paste its class here.
-- ⚠ BP_Mob_Boar_Friend IS THE WHISTLE SUMMON. It is the ONLY class in the entire game dump with
-- a kill timer: GE_Mob_Boar_Friend_KillTimer. Spawned boars therefore die on a timer and never
-- come back (RedFalcon, 2026-07-09). Class chain: BP_Mob_Boar -> BP_Mob_Boar_Friend -> ..._FriendLvl2,
-- so the PLAIN BP_Mob_Boar is the same animal without the self-destruct.
-- Docility does NOT come from the Friend class — this config's own note recorded that the Friend
-- boar spawns "hostile until we apply the friendly-faction copy". Peace comes from our faction
-- copy + the Boar_Friend AI controller override (Config.BOAR_AI), both of which still apply.
-- The plain boar's /Game/ path was never captured, so try the likely folders first and fall back
-- to the summon. spawnCreature() walks this list until one spawns, so a wrong guess costs nothing.
Config.BOAR_CANDIDATES = {
  "/Game/Gameplay/Character/AI/Mob/Boar/BP_Mob_Boar.BP_Mob_Boar_C",
  "/Game/Gameplay/Character/AI/Mob/Boar/Boar/BP_Mob_Boar.BP_Mob_Boar_C",
  "/Game/Gameplay/Character/AI/Mob/Boar/Regular/BP_Mob_Boar.BP_Mob_Boar_C",
  -- LAST RESORT: the summon. Works, but carries the kill timer. spawnCreature warns loudly.
  "/Game/Gameplay/Character/AI/Mob/Boar/Friend/BP_Mob_Boar_Friend.BP_Mob_Boar_Friend_C",
}

-- EXPERIMENTAL: copy a live crew's faction onto spawned creatures (boar, plague)
-- so they're friendly to you + your crew. Needs a crew in the world. Set false
-- to spawn them as-is (hostile).  CONFIRMED WORKING for the boar.
Config.MAKE_CREATURES_FRIENDLY = true
-- The friendly faction data asset, loaded directly so peace doesn't require a live crew to
-- be present (no crew used to mean animals/Senkamati stayed hostile). This is the same
-- FactionsParams a player crewman points at.
Config.FRIENDLY_FACTION_ASSET =
  "/Game/Gameplay/Character/Common/Relationship/Params/DA_Player_Crew_Faction.DA_Player_Crew_Faction"

-- Crew (F1) and the crew-based tribal Warrior (F6) are hostile to goats/boars — their
-- crew FactionComponent reads animals as prey. As ambient set-dressing they shouldn't
-- fight anyone, so strip their ability system (MakePassive) on spawn. This matches the
-- "invulnerable, no-combat" spec and stops the crew/goat brawls. See [[crew-goat-hostility]].
-- OFF (2026-07-08): keep the crew's combat so they still defend the base. Peace with goats
-- now comes from giving the GOAT a faction-respecting brain (Config.GOAT_AI) + the friendly
-- faction, not from disabling anyone's combat. Set true again to strip CombatComponent.
Config.CREW_PASSIVE = false
-- Which combat component(s) MakePassive destroys, IF CREW_PASSIVE. Reached by property.
-- Destroying the AbilitySystemComponent also freezes the pawn (movement runs on the ASC),
-- so default to CombatComponent only.
Config.PASSIVE_STRIP = { "CombatComponent" }

-- GoatF vs GoatM (in-game 2026-07-08): the FEMALE goat has a prey/FLEE brain — the crew
-- ignores it entirely (it just runs). The MALE goat has the aggressive mega-goat brain —
-- it and the crew attack on sight. So give GoatM the GoatF (prey) brain; it's a goat->goat
-- swap so it shouldn't freeze like the crew brain did. GoatF keeps its own brain (nil).
Config.GOATF_AI =
  "/Game/Gameplay/Character/AI/Mob/Goat/GoatF/Behavior/BP_Mob_AIController_GoatF.BP_Mob_AIController_GoatF_C"

-- Boar went hostile — force its own friendly brain explicitly (our deferred spawn +
-- SpawnDefaultController can leave the Friend variant on a default/aggressive controller).
Config.BOAR_AI =
  "/Game/Gameplay/Character/AI/Mob/Boar/Friend/Behavior/BP_Mob_AIController_Boar_Friend.BP_Mob_AIController_Boar_Friend_C"

-- The remaining problem is the FLEE: the prey brain runs from the player/crew. Attempt to
-- kill it by stripping the goat's threat PERCEPTION (its AI memory/agent), so it never
-- registers anyone as scary. Applied to both goats so we can see if it stops GoatF running.
-- If it freezes them (wander may need perception) or doesn't stop the flee, this is the end.
Config.GOAT_DISABLE = { "MemoryComponent", "R5AgentComponent" }

-- BOAR FAMILY variants (2026-08-07): Sow (female), Charging Boar, and Boar Mega join the base Boar
-- in the livestock cycle. Paths confirmed from Manifest_UFSFiles_Win64.txt. Unlike the base Boar
-- (which needed Config.BOAR_AI, a controller swap to a known-passive sibling, to stop it going
-- hostile) these three have NOT been live-tested yet -- no known-passive controller has been found
-- for any of them, so they spawn with their OWN default AI + the friendly-faction copy only, same
-- starting point that worked for the Dodo. If any of them still fight despite the friendly faction,
-- it needs the same treatment as Boar/GoatM: find a passive sibling controller and add an `ai`
-- override here.
Config.BOARS = {
  { name = "Boar",        candidates = Config.BOAR_CANDIDATES, ai = Config.BOAR_AI },
  { name = "Sow",         candidates = { "/Game/Gameplay/Character/AI/Mob/Boar/BoarF/BP_Mob_BoarF.BP_Mob_BoarF_C" } },
  { name = "BoarCharger", candidates = { "/Game/Gameplay/Character/AI/Mob/Boar/Charger/BP_Mob_Boar_Charger.BP_Mob_Boar_Charger_C" } },
  { name = "BoarMega",    candidates = { "/Game/Gameplay/Character/AI/Mob/BoarMega/BP_Mob_Boar_Mega.BP_Mob_Boar_Mega_C" } },
}

-- WOLVES (2026-08-07). Paths confirmed from the manifest, never live-tested -- same "friendly-faction
-- copy only, no AI override yet" starting point as the new boar variants above.
Config.WOLVES = {
  { name = "Wolf",      candidates = { "/Game/Gameplay/Character/AI/Mob/Wolf/BP_Mob_Wolf.BP_Mob_Wolf_C" } },
  { name = "AlphaWolf", candidates = { "/Game/Gameplay/Character/AI/Mob/Wolf/BP_Mob_AlphaWolf.BP_Mob_AlphaWolf_C" } },
}

-- CROCODILE (2026-08-07). Paths confirmed from the manifest, never live-tested. CrocodileCorrupted
-- mirrors the same folder shape as the SenkamatiCorrupted human mobs (own Behavior/GameplayAbilities/
-- ChildForQuests) -- a distinct "plague" crocodile pawn, not just a material swap on the regular one.
Config.CROCODILES = {
  { name = "Crocodile",        candidates = { "/Game/Gameplay/Character/AI/Mob/Crocodile/BP_Mob_Crocodile.BP_Mob_Crocodile_C" } },
  { name = "CrocodilePlague",  candidates = { "/Game/Gameplay/Character/AI/Mob/CrocodileCorrupted/BP_Mob_CrocodileCorrupted.BP_Mob_CrocodileCorrupted_C" } },
}

-- Plague creatures ("SenkamatiCorrupted" mobs).
-- Class names confirmed by grepping the game's .utoc asset index (2026-07-07).
-- There is NO "Witch" — the caster-type Senkamati is the "Shaman Caster"
-- (offensive spellcaster). A "Shaman Healer" also exists. Asset names are
-- confirmed; folder segments are guessed from the confirmed naming pattern
-- (Warrior→Regular_Warrior, Hunter→Regular_Hunter), so each has a couple of
-- folder candidates — the spawner tries them in order and keeps the one that
-- resolves. Others in the family you could add: Giant_Shaker (a boss), Caster's
-- Totem, etc. (grep .utoc for BP_Mob_SenkamatiCorrupted*).
Config.PLAGUE_CREATURES = {
  { name = "Warrior", candidates = {
      "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Warrior/BP_Mob_SenkamatiCorrupted_Regular_Warrior.BP_Mob_SenkamatiCorrupted_Regular_Warrior_C" } },
  { name = "Thrall", candidates = {
      "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Thrall/BP_Mob_SenkamatiCorrupted_Thrall.BP_Mob_SenkamatiCorrupted_Thrall_C" } },
  { name = "Hunter", candidates = {
      "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Hunter/BP_Mob_SenkamatiCorrupted_Regular_Hunter.BP_Mob_SenkamatiCorrupted_Regular_Hunter_C" } },
  { name = "Caster", candidates = {  -- the "witch" (Shaman Caster spellcaster)
      "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Shaman_Caster/BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster.BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster_C",
      "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Caster/BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster.BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster_C",
      "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Shaman/BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster.BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster_C" } },
  { name = "Healer", candidates = {  -- Shaman Healer (support caster)
      "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Shaman_Healer/BP_Mob_SenkamatiCorrupted_Regular_Shaman_Healer.BP_Mob_SenkamatiCorrupted_Regular_Shaman_Healer_C",
      "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Healer/BP_Mob_SenkamatiCorrupted_Regular_Shaman_Healer.BP_Mob_SenkamatiCorrupted_Regular_Shaman_Healer_C",
      "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Shaman/BP_Mob_SenkamatiCorrupted_Regular_Shaman_Healer.BP_Mob_SenkamatiCorrupted_Regular_Shaman_Healer_C" } },
}

-- CLEAN (de-corrupted) plague look. The Num7 key spawns a friendly CREW pawn
-- (walks + is your faction) and re-skins it with the game's REGULAR (non-
-- corrupted) Senkamati composite look: a darker-skinned tribal human in the
-- feather outfit — NOT the creepy undead mob. Discovered from the pak index:
-- the corrupted mob is these SAME "Regular" params + a corruption overlay.
--   * PLAGUE_USE_CLEAN = true  -> Num7 = clean tribal crew (this feature).
--   * PLAGUE_USE_CLEAN = false -> Num7 = the original corrupted mobs above.
-- Param leaf names confirmed from .utoc; Hunter's folder confirmed from the
-- pak, Warrior/Thrall folders mirror it (ApplyComposite logs if one misses).
-- Archetype preset (sex + darker skin + feather groups) confirmed from pak.
Config.PLAGUE_USE_CLEAN = true
Config.SENKAMATI_ARCHETYPE =
  "/R5BusinessRules/Character/Customization/AI/Senkamati/Preset/DA_Mob_Senkamati_Regular_Preset_Common.DA_Mob_Senkamati_Regular_Preset_Common"
-- RESULT (2026-07-07): crew FROZE with the Handyman brain (they reject it, as
-- before). So re-skinned crew can't use Handyman; leave this false. Crew keep
-- their own AI (they move, but don't wander/sit like Handyman townsfolk).
Config.SENKAMATI_HANDYMAN = false

-- WALK PATTERN for the Hunter/Caster/Healer MOBS (2026-08-09). Unlike the Warrior (a
-- re-skinned crew pawn, which walks normally for free because its base class already IS
-- crew), these three spawn as the actual SenkamatiCorrupted mob classes, each possessed by
-- its own native mob AIController (e.g. BP_Mob_SenkamatiCorrupted_Regular_Hunter_AIController) --
-- built for a hostile creature, not ambient set-dressing, so it likely doesn't wander the
-- way a peaceful crewman does. Give them the SAME AI controller class the Warrior already
-- uses successfully -- confirmed via a live probe on a spawned Warrior (2026-08-09), so this
-- is a known-good class, not a guess like Handyman was. EXPERIMENTAL/UNTESTED on a mob pawn
-- specifically: Handyman froze crew because crew "lack the worker data it needs" (see above)
-- -- the same failure mode is possible here if this AI controller expects crew-specific pawn
-- components the mob pawn doesn't have. If they freeze or misbehave in-game, set false.
-- DISPROVEN (2026-08-09): both overrides confirmed setting successfully in-game (log showed
-- "AIControllerClass override set" + "AIPawnParams=ok OverriddenAIPawnParams=ok"), but walk
-- behavior was unchanged -- because the actual complaint was ANIMATION/POSTURE (a "monstrous"
-- gait), not AI wandering. Neither AIControllerClass nor AIPawnParams touches animation --
-- that's the Mesh's AnimBlueprint, tied to the pawn's SKELETON. Left OFF: no benefit, and
-- possessing a mob pawn with a crew-built AI controller is unverified territory for zero gain.
Config.SENKA_MOB_WALK_AI = false
Config.SENKA_MOB_WALK_AI_CLASS =
  "/Game/Gameplay/Character/AI/Crew/Officer/Behavior/BP_Mob_AIController_Crew_Officer.BP_Mob_AIController_Crew_Officer_C"
-- RESULT (2026-08-09): AIControllerClass override alone had NO visible effect (confirmed
-- in-game -- no freeze, no crash, no wander either). Working theory: the controller class
-- is a thin dispatcher and the actual walk/wander behavior comes from a Data Asset the PAWN
-- itself references (AIPawnParams), which the override above never touched -- see
-- Spawner.SetAIPawnParams's own comment. This is the Warrior's own confirmed-working asset
-- (from a live probe dump), applied to the mob pawn alongside the controller override.
Config.SENKA_MOB_WALK_AI_PARAMS =
  "/Game/Gameplay/Character/AI/Crew/Regular/Behavior/DA_Mob_Crew_Regular_AIPawnParams.DA_Mob_Crew_Regular_AIPawnParams"

-- The Caster's AoE spells damage the player even though she's faction-friendly.
-- Strip the ability system on Senkamati MOB spawns so they can't attack at all.
-- EXPERIMENTAL: if they freeze or misbehave, set false.
Config.SENKAMATI_PASSIVE = true
-- The Caster summons witch totems that fight for her. The totems are separate actors that do NOT
-- inherit her friendly faction, so they attack the player. Remove ONLY the summon ability by
-- class-name pattern; her close-range AoE is harmless and stays. If none of these match, the mod
-- dumps every ability she was granted (once) so we can target the real name instead of guessing.
-- NEVER strip the whole AbilitySystemComponent: movement runs on it and the pawn freezes.
Config.CASTER_DISABLE_ABILITIES = { "Summon", "Totem" }

-- RESULT (2026-07-07): forcing sex=Female on the Senkamati look did NOTHING —
-- all male. The Senkamati ARCHETYPE dictates sex at build and is authored male;
-- SetCharacterSex is overridden. No female Senkamati archetype exists, so
-- Senkamati stays male-only. (For real women, use a FEMALE archetype — see the
-- TEST-Female-BotC row below, which drives gender the correct way.)
-- ALL MOB SPAWNS now (2026-07-08). De-corrupting the real mobs beats re-skinning a
-- crewman: they come with the correct Senkamati weapons (macuahuitl / dart — no
-- inherited crew cutlass), correct proportions, and distinct per-type looks. The
-- pattern-based DECORRUPT rules clean their skin + eyes; the Witch-only HIDE/REPLACE
-- rules leave the men's feather armor intact (it IS their outfit).
-- `mob` = spawn that class directly, friendly (needs a crew nearby to copy a
-- faction). Thrall dropped (too zombie to de-corrupt). Paths confirmed from the pak.
-- The crew re-skin path still exists for entries that use `params` instead.
local SC = "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/"
-- ALL MOBS. De-corrupting the real mobs beats re-skinning crew: correct Senkamati
-- weapons (macuahuitl/dart — no inherited crew cutlass), correct proportions, and
-- distinct per-type looks. Caster's de-corrupt is CONFIRMED GOOD; Warrior/Hunter
-- still need rules matched to their (as-yet-undumped) material names.
-- NOTE: the Warrior's BODY/SKIN/HAIR come from a randomized ArchetypePreset in the ShipCrew
-- pool. We tried pinning it pre-build (Config.WARRIOR_ARCHETYPE = ...ArchetypeAfrican) and
-- PROVED it does not stick: BeginPlay re-randomizes, and 7 Warrior spawns rolled 5 different
-- ethnicities anyway. Do not retry. The post-build de-corrupt normalizes skin+hair regardless,
-- Light-hair/bald rolls are simply respawned; we no longer try to force them.

-- FEMALE base pawn for Caster/Healer's re-skin (2026-08-10). The old "no walking women exist"
-- conclusion further below was about classes THIS MOD had tried (a unique hireable employee, a
-- unique quest NPC, the male-locked procedural Citizen_Walker) -- not a survey of the whole
-- game. Confirmed via a live HOME/PAUSE probe on a real, already-walking female townsfolk: she's
-- BP_NPC_Handyman_Gatherer_C -- a GENERIC role class (same family as the Walker/Worker roles
-- already used elsewhere, not a unique character), body SK_Adventure_Female_01 (a normal human
-- female mesh, not the Senkamati-specific female skeleton), AI BP_NPC_AIController_Handyman_C +
-- DA_NPC_Handyman_AIPawnParams -- the exact same Handyman brain already proven to walk/wander/
-- sit normally elsewhere in this mod. This is the Warrior's own trick (re-skin a human-skeleton
-- pawn instead of using the mob's own skeleton) applied to a female base for the first time.
Config.SENKA_FEMALE_BASE_CLASS =
  "/Game/Gameplay/Character/AI/NPC/Handyman/Handyman_Gatherer/BP_NPC_Handyman_Gatherer.BP_NPC_Handyman_Gatherer_C"

-- SECOND walking-woman base: the Herbalist (2026-08-14). RedFalcon spotted her walking in-world and asked
-- for an alternative base for the "Woman With Hair" look. Found via a fresh object dump
-- (UE4SS_ObjectDump.txt): `BP_NPC_Handyman_Herbalist_C`, living in the SAME `.../Handyman/` folder as
-- Gatherer above and sharing the EXACT SAME immediate parent class, `BP_NPC_Handyman.BP_NPC_Handyman_C`
-- (confirmed by comparing both classes' `[sps: ...]` super-struct address in the dump) -- i.e. she's an
-- architectural sibling of the already-proven Gatherer, not a guess. Sex/walking behavior weren't
-- re-derived from the dump (a static class/property-declaration graph doesn't show instance data like
-- that) -- taken on RedFalcon's own in-world observation instead, the same "aim the HOME probe at a real one"
-- standard this project has always used for a NEW base pawn (see Config.SENKA_FEMALE_BASE_CLASS's own
-- comment for the precedent). LIVE-TESTED (same day): confirmed she has a genuinely different figure,
-- hair color, and garment palette (red/blue) from the Gatherer -- expected and welcomed, not a bug: per
-- CLAUDE.md's color-investigation writeup, per-pawn color/palette can't be set post-construction in this
-- game, so each base class's own BAKED-IN default archetype is the only real source of palette variety
-- available at all. Reused for two features: every "* Base 2" entry in testbed.lua's
-- FEMALE_RESKIN_TARGETS (picked by femaleBaseClassFor's suffix rule) and a second Caster-F crew row
-- pair (Config.SENKAMATI_LOOKS below).
Config.SENKA_FEMALE_BASE_CLASS_HERBALIST =
  "/Game/Gameplay/Character/AI/NPC/Handyman/Handyman_Herbalist/BP_NPC_Handyman_Herbalist.BP_NPC_Handyman_Herbalist_C"

-- TATTOO TEST -- CONFIRMED LIVE (2026-08-10) TO CRASH THE GAME, reproduced twice in a row.
-- Found via the game's own UFS manifest (Manifest_UFSFiles_Win64.txt): a whole PLAYER-side
-- ("Hero") composite-mesh-params system for tattoos, one DataAsset per body region, 6 numbered
-- variants each -- same DataAsset TYPE (CompositeMeshComponentParams) as the Brethren Woman/
-- Senkamati armor `params` already proven safe all session on NPC pawns, so it looked like a
-- reasonable thing to try. It is NOT safe: applying a "Hero_"-prefixed CompositeMeshComponentParams
-- asset as an NPC's compositeLook.params via Spawner.SetCompositeParams reliably crashes the game
-- (native crash, not a Lua error -- pcall does not and cannot catch it, same class of crash
-- documented elsewhere in this file). Path kept below purely as a record of what was tried; DO NOT
-- wire this back into any spawn call, and treat every "Hero_"-prefixed CompositeMeshParams asset in
-- this game as off-limits for NPC pawns via this mechanism unless a real theory emerges for why a
-- DIFFERENT one would behave differently.
Config.TATTOO_TEST_PARAMS =  -- UNUSED, unsafe -- see comment above. Do not apply.
  "/Game/Gameplay/Character/Player/Parameters/CompositeMeshParams/SkinDecor/Chest/DA_Hero_CompositeMeshParams_SkinDecor_Chest_Tattoo_01.DA_Hero_CompositeMeshParams_SkinDecor_Chest_Tattoo_01"

-- Shared crew-recipe fields for the "crew" kind entries below -- same base class/composite
-- mechanism proven on the Warrior since early sessions, now used for Hunter/Caster/Healer too
-- (see each `params` path's own history in this file's earlier revisions for how they were
-- confirmed). Kept as locals purely to avoid repeating them across 8 crew-kind rows below.
local WARRIOR_CREW_BASE = Config.WARRIOR_BASE_CLASS or Config.CREW_CLASS
local WARRIOR_PARAMS = SC .. "Regular_Warrior/CompositeMesh/DA_Mob_Senkamati_Regular_Warrior_CompositeMeshComponentParams.DA_Mob_Senkamati_Regular_Warrior_CompositeMeshComponentParams"
local HUNTER_PARAMS  = SC .. "Regular_Hunter/CompositeMesh/DA_Mob_Senkamati_Regular_Hunter_CompositeMeshComponentParams.DA_Mob_Senkamati_Regular_Hunter_CompositeMeshComponentParams"
local CASTER_PARAMS  = SC .. "Regular_Shaman_Caster/CompositeMesh/DA_Mob_Senkamati_Regular_Shaman_Caster_CompositeMeshComponentParams.DA_Mob_Senkamati_Regular_Shaman_Caster_CompositeMeshComponentParams"
local HEALER_PARAMS  = SC .. "Regular_Shaman_Healer/CompositeMesh/DA_Mob_Senkamati_Regular_Shaman_Healer_CompositeMeshComponentParams.DA_Mob_Senkamati_Regular_Shaman_Healer_CompositeMeshComponentParams"
-- Raw mob class paths -- same ones Config.PLAGUE_CREATURES uses (confirmed live), needed here
-- for the "mob" (original zombie-gait stance, still de-corrupted) and "corrupted" (untouched,
-- pre-de-corrupt look) kind entries below.
local WARRIOR_MOB = SC .. "Regular_Warrior/BP_Mob_SenkamatiCorrupted_Regular_Warrior.BP_Mob_SenkamatiCorrupted_Regular_Warrior_C"
local HUNTER_MOB   = SC .. "Regular_Hunter/BP_Mob_SenkamatiCorrupted_Regular_Hunter.BP_Mob_SenkamatiCorrupted_Regular_Hunter_C"
local CASTER_MOB    = SC .. "Regular_Shaman_Caster/BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster.BP_Mob_SenkamatiCorrupted_Regular_Shaman_Caster_C"
local HEALER_MOB    = SC .. "Regular_Shaman_Healer/BP_Mob_SenkamatiCorrupted_Regular_Shaman_Healer.BP_Mob_SenkamatiCorrupted_Regular_Shaman_Healer_C"

-- COMPARISON ROSTER (2026-08-10) -- Num7 cycles through every look tried this session, in a
-- fixed order, so they can be lined up side by side before picking favorites. Healer removed
-- (2026-08-10, same day) -- she and Caster-F looked the same, not worth 5 extra rows. Three
-- `kind`s:
--   "crew"      -- human-skeleton re-skin (normal walk/posture). baseClass + params + optional
--                  forceArchetype (pins the male Senkamati archetype for Warrior/Hunter; left
--                  off for Caster, whose Handyman base is already female natively).
--   "mob"       -- the pawn's own native Senkamati skeleton (original zombie-gait stance),
--                  still de-corrupted -- but de-corrupt now ONLY changes skin tone/eyes/hair
--                  colour (armor pieces and facial hair are kept, not hidden -- see
--                  Config.DECORRUPT_MOB/DECORRUPT_HUNTER's own comments). `mob` = class path.
--   "corrupted" -- same native skeleton, but DE-CORRUPT IS SKIPPED ENTIRELY -- the pawn's
--                  actual corrupted/hostile appearance, "as original", though still
--                  pacified+friendly so it's safe to stand next to for comparison.
-- `helmet=true` keeps the headdress/helmet visible (rulesWithHelmet in testbed.lua strips the
-- head-only hide/replace rule); omitted/false = helmet hidden. Warrior has no "mob" comparison
-- rows and no pelvis-gap fix -- his crew re-skin was already the established, working recipe
-- before this session started, and per user request he's spawned exactly as he was before
-- today's changes (skin/eye/hair/weapon/dreadlocks + toggleable helmet), no underwear piece.
-- `idle=true` (2026-08-15, RedFalcon's request) -- frozen counterpart of a "crew" or "mob" row
-- (freeze-first, same ordering originally proven on the now-removed Senkamati Statues feature),
-- added after EACH type below. Motivation: that feature's "posed" statue rows could flash bare
-- skin/nipples repeatedly during their archetype reroll (part of why it was removed, same day --
-- see this file's own removal note further down), and even a normal WALKING crew row here is briefly
-- nude while her composite layers build before de-corrupt catches up -- an idle row can't wander
-- around the base still exposed for that whole window the way a walking one can. Does not apply
-- to "corrupted" kind (never had this ask, and it's the raw hostile look, not meant to be "posed").
Config.SENKAMATI_LOOKS = {
  -- WARRIOR -- crew only (2 rows)
  { name = "Warrior", kind = "crew", helmet = true,  baseClass = WARRIOR_CREW_BASE, forceArchetype = true, params = WARRIOR_PARAMS },
  { name = "Warrior", kind = "crew", helmet = false, baseClass = WARRIOR_CREW_BASE, forceArchetype = true, params = WARRIOR_PARAMS },
  -- WARRIOR -- idle (frozen) crew + mob (4 rows)
  { name = "Warrior", kind = "crew", helmet = true,  idle = true, baseClass = WARRIOR_CREW_BASE, forceArchetype = true, params = WARRIOR_PARAMS },
  { name = "Warrior", kind = "crew", helmet = false, idle = true, baseClass = WARRIOR_CREW_BASE, forceArchetype = true, params = WARRIOR_PARAMS },
  { name = "Warrior", kind = "mob",  helmet = true,  idle = true, mob = WARRIOR_MOB },
  { name = "Warrior", kind = "mob",  helmet = false, idle = true, mob = WARRIOR_MOB },

  -- HUNTER -- original mob stance, then crew re-skin (4 rows)
  { name = "Hunter", kind = "mob",  helmet = true,  mob = HUNTER_MOB },
  { name = "Hunter", kind = "mob",  helmet = false, mob = HUNTER_MOB },
  { name = "Hunter", kind = "crew", helmet = true,  baseClass = WARRIOR_CREW_BASE, forceArchetype = true, params = HUNTER_PARAMS },
  { name = "Hunter", kind = "crew", helmet = false, baseClass = WARRIOR_CREW_BASE, forceArchetype = true, params = HUNTER_PARAMS },
  -- HUNTER -- idle (frozen) crew + mob (4 rows)
  { name = "Hunter", kind = "crew", helmet = true,  idle = true, baseClass = WARRIOR_CREW_BASE, forceArchetype = true, params = HUNTER_PARAMS },
  { name = "Hunter", kind = "crew", helmet = false, idle = true, baseClass = WARRIOR_CREW_BASE, forceArchetype = true, params = HUNTER_PARAMS },
  { name = "Hunter", kind = "mob",  helmet = true,  idle = true, mob = HUNTER_MOB },
  { name = "Hunter", kind = "mob",  helmet = false, idle = true, mob = HUNTER_MOB },

  -- CASTER -- same 4-row pattern as Hunter
  { name = "Caster-F", kind = "mob",  helmet = true,  mob = CASTER_MOB },
  { name = "Caster-F", kind = "mob",  helmet = false, mob = CASTER_MOB },
  { name = "Caster-F", kind = "crew", helmet = true,  baseClass = Config.SENKA_FEMALE_BASE_CLASS, forceArchetype = false, params = CASTER_PARAMS },
  { name = "Caster-F", kind = "crew", helmet = false, baseClass = Config.SENKA_FEMALE_BASE_CLASS, forceArchetype = false, params = CASTER_PARAMS },
  -- Herbalist-base counterparts (2026-08-14, RedFalcon's request, mirrors the Gatherer pair exactly).
  -- `name` stays "Caster-F" on purpose -- testbed.lua's senkaCrewFix branches on THIS EXACT string
  -- to pick Config.DECORRUPT_CREW_FEMALE (see its own comment); renaming it here would silently fall
  -- through to the male Warrior ruleset instead. `baseLabel` is the ONLY new field, purely for
  -- display/lookup: testbed.lua's senkaShortKey/rowLabel append it so these two rows get distinct
  -- lblook keys/toast text ("Caster-F_crew_Herbalist_Mask" etc.) instead of colliding with the
  -- Gatherer pair's identical-otherwise key ("Caster-F_crew_Mask") -- the exact same class of bug
  -- just found and fixed for the walking-woman "Herbalist" name, see testbed.lua's own writeup.
  -- Deliberately NOT threaded into senkaRowKey (the persist.txt identity) -- confirmed harmless to
  -- leave that ambiguous between these two rows, since restore re-applies the SAME rules (identical
  -- params/helmet, only baseClass differs) regardless of which of the two matches, and the actual
  -- spawned CLASS always comes from persist.txt's own saved classPath, never re-derived from the
  -- row match -- changing senkaRowKey's "::"-joined format has broken parsing twice before (see
  -- that function's own comment), so this deliberately doesn't touch it.
  { name = "Caster-F", kind = "crew", helmet = true,  baseClass = Config.SENKA_FEMALE_BASE_CLASS_HERBALIST, forceArchetype = false, params = CASTER_PARAMS, baseLabel = "Herbalist" },
  { name = "Caster-F", kind = "crew", helmet = false, baseClass = Config.SENKA_FEMALE_BASE_CLASS_HERBALIST, forceArchetype = false, params = CASTER_PARAMS, baseLabel = "Herbalist" },
  -- CASTER -- idle (frozen) crew + mob (4 rows) -- Gatherer base only here; the Herbalist-base
  -- frozen pair is appended at the very END of this whole table instead (see the comment down
  -- there for why), not inserted here alongside it.
  { name = "Caster-F", kind = "crew", helmet = true,  idle = true, baseClass = Config.SENKA_FEMALE_BASE_CLASS, forceArchetype = false, params = CASTER_PARAMS },
  { name = "Caster-F", kind = "crew", helmet = false, idle = true, baseClass = Config.SENKA_FEMALE_BASE_CLASS, forceArchetype = false, params = CASTER_PARAMS },
  { name = "Caster-F", kind = "mob",  helmet = true,  idle = true, mob = CASTER_MOB },
  { name = "Caster-F", kind = "mob",  helmet = false, idle = true, mob = CASTER_MOB },

  -- HEALER removed from the roster (2026-08-10) -- she and Caster-F looked the same, not worth
  -- the extra 5 comparison rows. Config.SENKA_FEMALE_BASE_CLASS/HEALER_PARAMS/HEALER_MOB are
  -- kept (harmless, still valid) in case she's wanted back later.

  -- FINALLY -- remaining three "as original": untouched corrupted look, full armor, still safe
  -- to stand next to (pacified+friendly, just not de-corrupted).
  { name = "Warrior",  kind = "corrupted", mob = WARRIOR_MOB },
  { name = "Hunter",   kind = "corrupted", mob = HUNTER_MOB },
  { name = "Caster-F", kind = "corrupted", mob = CASTER_MOB },
  -- ...and their idle (frozen) counterparts (2026-08-15, RedFalcon's follow-up) -- no code change
  -- needed, spawnSenkaEntry's mob/corrupted branch (testbed.lua) already covers `s.kind ==
  -- "corrupted"` under the same `if s.idle then freezeSenkaStatue(actor) end` check the mob rows
  -- use. No separate masked/unmasked split here, matching the walking "corrupted" rows above --
  -- de-corrupt is skipped entirely for this kind, so there's no helmet/mask distinction to make.
  { name = "Warrior",  kind = "corrupted", idle = true, mob = WARRIOR_MOB },
  { name = "Hunter",   kind = "corrupted", idle = true, mob = HUNTER_MOB },
  { name = "Caster-F", kind = "corrupted", idle = true, mob = CASTER_MOB },

  -- CASTER, Herbalist base -- frozen (idle) crew reskin pair (2026-08-16, RedFalcon's request:
  -- "add frozen versions of the herbalist crew caster"). Mirrors the Herbalist non-idle pair
  -- (helmet true/false, baseClass = SENKA_FEMALE_BASE_CLASS_HERBALIST, baseLabel = "Herbalist")
  -- further up, just idle = true. Originally scoped out of that pair's own idle block ("not worth
  -- doubling to 8 rows for a body-base difference orthogonal to the idle/NSFW-safety ask") --
  -- reversed on request. APPENDED HERE AT THE VERY END rather than inserted next to the Gatherer
  -- idle pair above: spawnmenu_manifest.lua/main.lua's SPAWN_MENU_HANDLERS address every
  -- SENKAMATI_LOOKS row by its plain array INDEX, and spawn_menu.ini already has live entries
  -- pointing at specific indices from a previous run -- inserting anywhere but the end would shift
  -- every later row's index and silently repoint those existing tree entries at the wrong look.
  { name = "Caster-F", kind = "crew", helmet = true,  idle = true, baseClass = Config.SENKA_FEMALE_BASE_CLASS_HERBALIST, forceArchetype = false, params = CASTER_PARAMS, baseLabel = "Herbalist" },
  { name = "Caster-F", kind = "crew", helmet = false, idle = true, baseClass = Config.SENKA_FEMALE_BASE_CLASS_HERBALIST, forceArchetype = false, params = CASTER_PARAMS, baseLabel = "Herbalist" },
}
-- NOTE: the Villager moved OFF this cycle to its own key (Config.KEYS.villager)
-- while we iterate on it, so testing doesn't mean cycling past the other three.

------------------------------------------------------------
-- SENKAMATI STATUES FEATURE REMOVED ENTIRELY (2026-08-15) -- shipped in v1.3.10 (the '='/'-'
-- keys, Config.SENKAMATI_STATUES' "crew"/"posed"/"mob" three-kind roster, full saga in CLAUDE.md
-- items 45-67), then purged the same day: the "posed" kind's archetype-reroll mechanism (item 60)
-- could flash through OTHER body types -- bare skin/nipples -- on the way to a good one, an NSFW
-- risk during otherwise-normal use that RedFalcon decided wasn't worth keeping, especially once
-- Num7's own frozen "idle" rows (item 66, directly above) already cover the same "see a static
-- Senkamati look" need without that risk -- those rows use fixed crew/mob bodies, never the
-- random-archetype composite system this feature's reroll existed to work around. See CLAUDE.md
-- for the full removal writeup. Every Config.SENKA_STATUE_*/TEST_POSE_ANIM_SEQUENCE constant and
-- the whole Config.SENKAMATI_STATUES table are gone; the Adventurer/Albion body-mesh fixes
-- (Female_NUDE_P/Alibon_Nude_P, both still bundled in R5/Content/Paks/LivingBase/) stay -- those
-- also benefit ordinary archetype rolls elsewhere in the mod, not just the removed feature.
------------------------------------------------------------

-- DE-CORRUPT: swap corrupted materials on mob spawns (the Caster) to clean ones,
-- post-build. Each rule: any material slot whose current name CONTAINS `match`
-- gets replaced with the material at `to`. Slot layout confirmed via the END
-- probe (2026-07-07): eyes = MI_EyeRound_Evil_01 on the body mesh. Start with the
-- eyes (the striking corruption); add hands/hair rules once we find clean mats.
-- `match` is a Lua PATTERN tested against the current material's name.
-- Skins follow MI_<Ethnicity>_<Sex>_<Build>; "Senkamati" is just another
-- ethnicity — and it IS the disfigured tribal skin. Swap it for clean Native.
-- SKIN TONE: pick the ethnicity whose skin the Senkamati get. "Native" is the
-- meso-American tone (mid); "African" is noticeably darker. One-line switch — the
-- material folder and the MI_ prefix both follow the ethnicity name.
Config.SENKAMATI_SKIN = "Native"   -- try "African" for darker
local SKIN_DIR = "/Game/Character/Skeletal_Meshes/Human/Regular/" .. Config.SENKAMATI_SKIN .. "/Materials/"
-- Skins come per BUILD (Small/Medium/Large) as well as sex, so swap like-for-like.
local function skinMat(sex, build)   -- sex = "Male"|"Female", build = "Small"|"Medium"|"Large"
  local n = "MI_" .. Config.SENKAMATI_SKIN .. "_" .. sex .. "_" .. (build or "Medium")
  return SKIN_DIR .. n .. "." .. n
end

Config.DECORRUPT = true
local EYE_BROWN = "/Game/Character/Shaders/InstanceMaterials/Eyes/Round/MI_EyeRound_Brown_01.MI_EyeRound_Brown_01"
local HAIR_BLACK = "/Game/Character/Shaders/InstanceMaterials/Hairs/Colored/MI_Hair_Black_01.MI_Hair_Black_01"
-- Fixed dreadlocks for the named Senkamati (Caster + Warrior match each other).
local DREADS_F = "/Game/Character/Skeletal_Meshes/Hair/Female/PartialDreadlocks/SK_Hair_PartialDreadlocks_01_Default_Female.SK_Hair_PartialDreadlocks_01_Default_Female"
local DREADS_M = "/Game/Character/Skeletal_Meshes/Hair/Male/PartialDreadlocks/SK_Hair_PartialDreadlocks_01_Default_Male.SK_Hair_PartialDreadlocks_01_Default_Male"
-- Warrior gets a MOHAWK (RedFalcon's pick — the African + mohawk crew base looked best).
local MOHAWK_M = "/Game/Character/Skeletal_Meshes/Hair/Male/Mohawk/SK_Hair_Mohawk_01_Default_Male.SK_Hair_Mohawk_01_Default_Male"

-- Tribal men shouldn't wear pirate beards. Component meshes confirmed from the
-- probe: SK_Beard_Hungover, SK_Mustache_Shag_02, SK_Whiskers_Hungover.
local FACIAL_HAIR = { "SK_Beard_", "SK_Mustache_", "SK_Whiskers_" }
local function withFacialHair(t)
  local out = {}
  for _, v in ipairs(t or {}) do table.insert(out, v) end
  for _, v in ipairs(FACIAL_HAIR) do table.insert(out, v) end
  return out
end

-- CRITICAL (learned 2026-07-08): human skin materials (MI_<Ethnicity>_<Sex>_<Build>)
-- are authored for HUMAN body UVs. Painting one onto a SENKAMATI body mesh
-- (SK_Senkamati_Witch_01_Female etc.) maps garbage — the skin renders like BARK.
-- So the rules are split by what BODY the pawn has:

-- MOB rules. CONFIRMED WORKING on the Caster: her skin DOES swap
-- (MI_Senkamati_Female_Medium -> clean skin), eyes -> brown, headdress -> dreadlocks,
-- claw armor hidden. The Warrior/Hunter mobs matched NOTHING ("0 swapped ... over 9
-- components"), so their material names differ — the VERBOSE probe on mob spawns
-- dumps them so we can add matching rules.
-- Real material names, dumped from the mobs (2026-07-08):
--   Caster : body SK_Senkamati_Witch_01_Female   skin MI_Senkamati_Female_Medium
--            eyes MI_EyeRound_Evil_01
--   Warrior: body SK_SenkamatiCorrupted_Male_Medium  skin MI_Senkamati_Feather_Male_Medium
--   Hunter : same body                                skin MI_Senkamati_Feather_Male_Large
--            (men's eyes are already MI_EyeRound_Green_01 — nothing to fix)
-- The men's skin has TWO segments before "_Male" (Senkamati_Feather), which is why
-- the old "MI_%a+_Male_%a+" pattern never matched them (%a+ excludes underscores).
Config.DECORRUPT_MOB = {
  swaps = {
    { match = "MI_EyeRound_Evil", to = EYE_BROWN },              -- Caster only
    -- Caster's skin (confirmed working)
    { match = "MI_Senkamati_Female_Small",  to = skinMat("Female", "Small") },
    { match = "MI_Senkamati_Female_Medium", to = skinMat("Female", "Medium") },
    { match = "MI_Senkamati_Female_Large",  to = skinMat("Female", "Large") },
    -- Warrior/Hunter bark-like skin, matched per build
    { match = "MI_Senkamati_Feather_Male_Small",  to = skinMat("Male", "Small") },
    { match = "MI_Senkamati_Feather_Male_Medium", to = skinMat("Male", "Medium") },
    { match = "MI_Senkamati_Feather_Male_Large",  to = skinMat("Male", "Large") },
    -- other Senkamati male skin variant that exists in the assets
    { match = "MI_Senkamati_Wood_Male_Small",  to = skinMat("Male", "Small") },
    { match = "MI_Senkamati_Wood_Male_Medium", to = skinMat("Male", "Medium") },
    { match = "MI_Senkamati_Wood_Male_Large",  to = skinMat("Male", "Large") },
    -- Dark hair. Anchored so it hits the plain "MI_Hair" only — not MI_HairScalp,
    -- and not MI_Hair_Black_01 itself (which would re-match forever).
    { match = "^MI_Hair$", to = HAIR_BLACK },
  },
  -- (2026-08-10) hides emptied -- user wants the armor pieces (and facial hair) kept, not
  -- hidden, for the "mob" original-stance comparison rows. De-corrupt for those now ONLY
  -- changes skin tone, eyes, and hair colour. The Head piece's dreadlocks REPLACE below is
  -- unrelated to this (it's about her hair, not armor) and still applies, still toggleable via
  -- the "helmet" field on Config.SENKAMATI_LOOKS entries (see rulesWithHelmet in testbed.lua).
  hides = {},
  replaces = {
    -- The Witch's "Head" piece IS her hair, so hiding it left her bald. Give her
    -- DREADLOCKS specifically (the random pool rolled short styles like Wavy_02).
    { name = "dreadlocks (F)", match = "Witch_Feather_%d+_Head", to = DREADS_F },
  },
}

-- HUNTER variant: same skin/eye/facial-hair cleanup as the Caster, but LEAVE HIS HAIR
-- ALONE (RedFalcon: he already has a mohawk natively — SK_Hair_Mohawk_01_Default_Male showed in
-- the log). The shared Caster rule was replacing his head piece with dreads; here we just
-- drop that replacement (empty `replaces`) so his own hair stays.
-- HUNTER: same Native skin + black hair as the other two, but a MOHAWK (RedFalcon's spec).
-- His natural hair reads as full dreads, so we replace it. Best guess is that it's a
-- standard "SK_Hair_*" mesh (as the crew's is); if the probe shows a Senkamati-specific
-- hair mesh instead, widen this match to that name.
-- NOTE: own `hides` table (not a shared reference to Config.DECORRUPT_MOB.hides) --
-- appending the Hunter-only helmet pattern below must not also hide the Caster's/
-- Healer's own Witch_Feather pieces, which alias that same table.
Config.DECORRUPT_HUNTER = {
  swaps = Config.DECORRUPT_MOB.swaps,
  -- (2026-08-10) Dropped the facial-hair wrap and claw-armor hides -- user wants to actually
  -- see his beard and armor on the original mob stance, not have them stripped. Only the
  -- helmet-hide pattern remains, and even that's now conditional -- see rulesWithHelmet in
  -- testbed.lua, driven by the "helmet" field on Config.SENKAMATI_LOOKS entries.
  hides = {
    -- HELMET (2026-08-09): hide just the head/headdress armor piece, confirmed via live
    -- probe as "SK_ArmorCreature_Senkamati_Hunter_Feather_01_Head" -- a component distinct
    -- from his mohawk (SK_Hair_Mohawk_01_Default_Male, its own separate component), so
    -- hiding it reveals the mohawk underneath rather than leaving him bald.
    "Hunter_Feather_%d+_Head",
  },
  replaces = {
    { name = "mohawk (M)", match = "SK_Hair_", to = MOHAWK_M },
  },
}

-- CREW re-skin rules — the men. Their body IS a human mesh (e.g. SK_Orient_Male_01),
-- so a human skin material maps correctly: force the chosen tone so they stop
-- rolling light-skinned. Also hide the cutlass they inherit from being crew
-- (confirmed component: SK_SaberT02_01).
-- PELVIS GAP -- ROOT CAUSE CONFIRMED (2026-08-10): the tribal "Feather_Legs" piece is a
-- hanging-fringe/grass-skirt design -- gaps BETWEEN the strands are intentional, meant to show
-- the WEARER'S OWN SKIN behind them. On the Senkamati mob's own body that skin is there (proven
-- via a live side-by-side: Testbed.SpawnCompareMobCaster has a normal-looking rear). On the
-- human re-skin base, that skin geometry simply doesn't exist there (these bodies were modeled
-- assuming permanent clothing coverage -- confirmed via a full scan of the game's own asset pak
-- files: no "nude"/undressed body variant exists for any human body mesh in this game). So the
-- fringe's gaps show straight through to the world instead of skin. NudgeComponentTransform
-- (scale/offset) was tried and is a dead end -- it doesn't add the missing backing, it just
-- makes the same holes bigger; disabled (1.0/0.0) rather than removed, in case it's useful for
-- an unrelated fit issue later.
Config.SENKA_LEGS_NUDGE_SCALE = 1.0
Config.SENKA_LEGS_NUDGE_OFFSET_Z = 0.0
-- ATTEMPT HISTORY: (1) underwear-Legs mesh recolored to skin tone -- closed the gap, but its own
-- rounded "bloomers" SHAPE read as an obviously separate garment regardless of color. (2) same
-- mesh recolored to the tribal fringe material instead -- material confirmed correctly applied
-- via live probe, but rendered as light denim, not the dark tribal look -- that material likely
-- depends on UV/vertex-color data baked into the ORIGINAL Senkamati meshes that this borrowed
-- human garment mesh doesn't have, so swapping materials further won't fix it. (3) tried
-- SK_Armor_Bandit_Waist instead (a piece seen worn natively by a townsfolk Herbalist) -- didn't
-- work either (visual call, not further diagnosed).
-- CURRENT: back to the underwear-Legs mesh, its OWN default/native material, no recolor at all
-- -- closes the gap (confirmed), and this is the least-wrong-looking option found so far.
-- Female's path is LIVE-CONFIRMED (seen attached via probe). Male's is NOT live-confirmed as a
-- component, but the asset file itself IS confirmed to exist (found via a pak-file scan), same
-- folder/naming convention as the female one.
Config.SENKA_UNDERWEAR_LEGS_M =
  "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Underwear/Meshes/SK_Armor_Underwear_02_Male_Legs.SK_Armor_Underwear_02_Male_Legs"
Config.SENKA_UNDERWEAR_LEGS_F =
  "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Underwear/Meshes/SK_Armor_Underwear_02_Female_Legs.SK_Armor_Underwear_02_Female_Legs"
-- Torso sibling (2026-08-28), added for the Senkamati Torso/Legs fit-compatibility fallback in
-- Spawner.TestApplyClothingPiece -- same underwear family already swept into Config.CUSTOM_CLOTHES
-- ("Underwear" family, "Set 1" Torso) as a Female-only unisexPath entry, no Male Torso variant was
-- found in the catalog, so there's no _M sibling to add here.
Config.SENKA_UNDERWEAR_TORSO_F =
  "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/Underwear/Meshes/SK_Armor_Underwear_01_Female_Torso.SK_Armor_Underwear_01_Female_Torso"

-- Config.SENKAMATI_TORSO_LEGS_COMPATIBLE_BODIES -- live-tested by RedFalcon (2026-08-28): "all the
-- named women, the buccaneer merchant, and albion + Adventure standing/sitting women can wear the
-- senkamati torso and legs without major clipping" -- everything else clips badly. Matches item
-- 61's own already-confirmed finding (the Senkamati armor was rigged for exactly one archetype and
-- doesn't deform correctly onto the other 5) -- this is that same compatibility limit, now applied
-- generically via Custom > Clothes instead of only the removed Senkamati Statues roster. The named
-- women (Letty/Marita, "Woman With Hair Base 1") already resolve to SK_Adventure_Female_01, so
-- they're covered by this allowlist automatically -- no separate name/class check needed. Checked
-- by Spawner.TestApplyClothingPiece against the target's OWN current body mesh.
-- Same-day follow-up: RedFalcon also confirmed the Herbalist and Gatherer both work -- a live
-- probedump (probedump_20260828_104940.txt) confirms the Herbalist-based walker ALSO reads
-- SK_Adventure_Female_01 (identical to the Gatherer), so both were already covered without a code
-- change. The one genuine addition needed: the RAW Senkamati Witch body herself
-- (SK_Senkamati_Witch_01_Female) -- obviously compatible, this is literally her own native armor,
-- but she wasn't in the list since the fallback logic only ever checked for pieces being applied
-- ONTO an unrelated body, never considered the trivial case of applying her own armor back onto
-- her own body.
Config.SENKAMATI_TORSO_LEGS_COMPATIBLE_BODIES = {
  "SK_Adventure_Female_01", "SK_Albion_Female_01", "SK_Senkamati_Witch_01_Female",
}

-- Config.SENKAMATI_TORSO_LEGS_COMPATIBLE_CLASSES -- an UNCONDITIONAL pass by class name,
-- independent of body mesh (2026-08-28, same day). RedFalcon confirmed "Marita and buccaneer
-- merchant woman" also fit -- probe dumps showed these are NOT the walking Handyman-based
-- re-skins (already covered via body mesh above): "Marita" here is the real base-game quest NPC
-- (body mesh SK_Fable_Female_01 -- Fable, not in the mesh allowlist), and the Buccaneers Merchant
-- was caught on SK_Orient_Female_01 this time (also not in the allowlist, and different from
-- Adventure/Albion she's rolled in earlier probes -- her body genuinely randomizes per spawn,
-- item 57). Since both fit regardless of which archetype mesh they happen to be wearing, this
-- isn't archetype-dependent for these two specific classes -- something about their OWN
-- composite/outfit build apparently avoids the clipping. Checked via
-- actor:GetClass():GetFName():ToString() in Spawner.TestApplyClothingPiece.
Config.SENKAMATI_TORSO_LEGS_COMPATIBLE_CLASSES = {
  "BP_NPC_QuestStatic_Smugglers_MaritaSuares_C",
  "BP_AnimatedActor_Buccaneers_Merchant_01_C",
}

-- SENKAMATI STATUE PELVIS GAP / SENKA_STATUE_BODY_SWAP_TEST REMOVED (2026-08-15) -- both were
-- specific to the now-removed Senkamati Statues feature. See config.lua's earlier removal note
-- (right after Config.SENKAMATI_LOOKS) and CLAUDE.md for the full writeup.

Config.DECORRUPT_CREW = {
  swaps = {
    { match = "MI_EyeRound_Evil", to = EYE_BROWN },
    -- Crew skins are single-segment (e.g. MI_Orient_Male_Medium), so %a+ works here.
    -- Match per build so a Large crewman doesn't get a Medium skin.
    -- NATIVE skin, same tribal tone as the Caster/Hunter mobs. (The "African" crew base
    -- RedFalcon liked is the BASE MODEL to pin, not the skin target.)
    { match = "MI_%a+_Male_Small",  to = skinMat("Male", "Small") },
    { match = "MI_%a+_Male_Medium", to = skinMat("Male", "Medium") },
    { match = "MI_%a+_Male_Large",  to = skinMat("Male", "Large") },
    { match = "^MI_Hair$", to = HAIR_BLACK },   -- dark hair
    -- (2026-08-10) PELVIS GAP recolor rules removed -- both recolor attempts (skin tone, tribal
    -- fabric) looked wrong on the borrowed underwear mesh; Config.SENKA_UNDERWEAR_LEGS_M/_F now
    -- use that mesh's own default/native material instead (see that constant's own comment).
  },
  hides = withFacialHair({
    -- HELMET (2026-08-09): hide just the head/headdress armor piece, confirmed via live
    -- probe as "SK_ArmorCreature_Senkamati_Warrior_Feather_02_Head" -- a component distinct
    -- from his hair (replaced with dreadlocks below), so hiding it reveals the dreadlocks
    -- underneath rather than leaving him bald.
    "Warrior_Feather_%d+_Head",
  }),   -- Warrior: no beard/mustache/whiskers
  replaces = {
    -- Don't just hide the crew's cutlass — REPLACE its mesh with the Senkamati
    -- macuahuitl the real Warrior mob carries. Visual only (the weapon still behaves
    -- like the crew's), which is all we want. Confirmed component: SK_SaberT02_01.
    { name = "macuahuitl", match = "SK_Saber",
      to = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Dendromorph/SK_Weapon_Dendromorph_Macuahuitl.SK_Weapon_Dendromorph_Macuahuitl" },
    -- DREADLOCKS (RedFalcon's spec: Warrior + Caster = dreads, Hunter = mohawk). Match
    -- "SK_Hair_" (not "..._Default_Male") because some hair meshes have no sex suffix
    -- (e.g. SK_Hair_Shag_06_Default). Crew are always male here.
    -- CAVEAT: the crew composite sometimes builds NO hair component at all, and we can't
    -- replace a mesh that doesn't exist — that crewman comes out bald. Build-time pinning
    -- (ArchetypePreset, probe in progress) is the real fix for the bald roll.
    { name = "dreadlocks (M)", match = "SK_Hair_", to = DREADS_M },
    -- (2026-08-10) PELVIS GAP fix deliberately NOT applied to the Warrior -- user asked to
    -- spawn him exactly as he was before this session's changes (skin/eye/hair/weapon/dreads +
    -- toggleable helmet only), no underwear piece. The gap is real on him too, just hard to
    -- notice under his own armor's hanging fringe. Hunter/Caster/Healer's crew rows still use
    -- Config.SENKA_UNDERWEAR_LEGS_M/_F (see their own replaces) since it visibly helped there.
  },
}

-- HUNTER re-skin (2026-08-10): Hunter converted from a mob spawn to the Warrior's own crew
-- re-skin recipe (see Config.SENKAMATI_LOOKS' own comment -- same zombie-gait complaint).
-- His body is now the Officer crew's HUMAN mesh, so skin matching follows the CREW pattern
-- (MI_%a+_Male_*), not the mob's "MI_Senkamati_Feather_Male_*" naming DECORRUPT_HUNTER uses --
-- that's why this is a separate table and not a copy of DECORRUPT_HUNTER. The helmet-hide
-- pattern ("Hunter_Feather_%d+_Head") and mohawk replace are carried over unchanged from
-- DECORRUPT_HUNTER since the composite armor asset family should be the same regardless of
-- which base pawn wears it. Weapon: replace the crew's inherited cutlass with the same spear
-- his mob form carries (SK_Weapon_Dendromorph_Spear_Scale075, confirmed via live probe).
Config.DECORRUPT_CREW_HUNTER = {
  swaps = Config.DECORRUPT_CREW.swaps,
  hides = withFacialHair({
    "Hunter_Feather_%d+_Head",
  }),
  replaces = {
    { name = "spear", match = "SK_Saber",
      to = "/Game/Character/Skeletal_Meshes/Weapons/Weapon_Dendromorph/SK_Weapon_Dendromorph_Spear_Scale075.SK_Weapon_Dendromorph_Spear_Scale075" },
    { name = "mohawk (M)", match = "SK_Hair_", to = MOHAWK_M },
    -- PELVIS GAP fix -- see the note above Config.DECORRUPT_CREW.
    { name = "legs cover (M)", match = "Hunter_Feather_%d+_Legs", to = Config.SENKA_UNDERWEAR_LEGS_M },
  },
}

-- FEMALE re-skin (2026-08-10): Caster/Healer converted from mob spawns to a re-skin of
-- Config.SENKA_FEMALE_BASE_CLASS (a genuine human-skeleton, normally-walking female NPC --
-- see Config.SENKA_FEMALE_BASE_CLASS's own comment for how it was found). Skin matching
-- follows the same "generic human female" pattern the male CREW rules use (MI_%a+_Female_*),
-- NOT the mob's Senkamati-specific naming, since her body is now a normal human mesh.
-- BUG FOUND (2026-08-10): this table originally copied Config.DECORRUPT_MOB's `hides` list
-- verbatim ("Witch_Feather_%d+_Hands/Legs/Feet") without noticing WHY those patterns exist
-- there -- on the mob, that list deliberately HIDES those pieces because they looked bad
-- ("claw armor hidden", per DECORRUPT_MOB's own comment). Copying it here meant this de-corrupt
-- pass was hiding her Hands/Legs/Feet the instant the composite attached them -- the bare-leg
-- gap the user saw wasn't an asset/fitting problem at all, it was this rule actively hiding
-- correctly-attached armor. Only the head->dreadlocks replace (needed so hiding her literal
-- hair-piece "Head" component doesn't leave her bald) is carried over; hides is now empty.
Config.DECORRUPT_CREW_FEMALE = {
  swaps = {
    { match = "MI_EyeRound_Evil", to = EYE_BROWN },
    { match = "MI_%a+_Female_Small",  to = skinMat("Female", "Small") },
    { match = "MI_%a+_Female_Medium", to = skinMat("Female", "Medium") },
    { match = "MI_%a+_Female_Large",  to = skinMat("Female", "Large") },
    { match = "^MI_Hair$", to = HAIR_BLACK },
    -- (2026-08-10) PELVIS GAP recolor rules removed -- see the matching note in
    -- Config.DECORRUPT_CREW's own swaps.
  },
  hides = {},
  -- PELVIS GAP fix ("legs cover (F)") REMOVED (2026-08-13) -- superseded by bundling a body-mesh
  -- replacement (used with permission -- see R5/Content/Paks/LivingBase/Female_NUDE_P) as a
  -- standard part of this mod. That mesh has no gap at the pelvis to begin with, so the old
  -- underwear-leg swap is not just unneeded now but actively wrong: it was fitted to the OLD
  -- (vanilla) body's geometry and visibly clips/see-throughs against the new body's geometry.
  replaces = {
    { name = "dreadlocks (F)", match = "Witch_Feather_%d+_Head", to = DREADS_F },
  },
}

-- VILLAGER rules (Handyman townsfolk base; man or woman, human body).
-- Garments are components named SK_Armor_<Set>_<NN>[_Sex]_<Part> (Torso/Legs/Feet).
-- Sailor legs are "_Legs_Long" and have NO female variant, so women use a
-- female-fitted set. Rules are chosen by the pawn's BodySex at spawn.
local ARM = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/"
local ARMC = "/Game/Character/Skeletal_Meshes/Armor/ArmorCreature/"


-- MEN: bare chest, sailor pants, barefoot, no facial hair.
-- Villager hair: broader + native. Dreadlocks/wavy/mohawk (no wigs — too European).
-- Mohawk exists for BOTH sexes, so women can wear it too.
local VILLAGER_STYLES = { "PartialDreadlocks_01", "Wavy_01", "Wavy_02", "Wavy_03", "Mohawk_01" }
local function hairPoolFrom(styles, sex)
  local out = {}
  for _, style in ipairs(styles) do
    local folder = style:match("^(%a+)_%d+$") or style
    local asset  = "SK_Hair_" .. style .. "_Default_" .. sex
    table.insert(out, "/Game/Character/Skeletal_Meshes/Hair/" .. sex .. "/" .. folder
      .. "/" .. asset .. "." .. asset)
  end
  return out
end
Config.VHAIR_MALE   = hairPoolFrom(VILLAGER_STYLES, "Male")
Config.VHAIR_FEMALE = hairPoolFrom(VILLAGER_STYLES, "Female")







------------------------------------------------------------
-- TOWNSFOLK women (the townsman key) share base classes with the villager, so give
-- them the fancy JEWELER set + a different (tied/styled, not tribal) hairstyle so the
-- two read as distinct people. Jeweler_03_Female is the only complete set: Torso,
-- Legs, Hands, Feet_Long, Hat.
------------------------------------------------------------
------------------------------------------------------------
-- OUTFIT SETS. Garment components are SK_Armor_<Set>[_Sex]_<Part>[_Long|_NN].
-- Naming is inconsistent (Bandit_Male_Legs vs Blackbeard_Musketeer_02_Torso), so each
-- part offers several candidate names; the replace picks whichever RESOLVES and drops
-- the rest (each miss logs once). Rules are MEMOISED per (set, sex, parts) so asset
-- resolution — and its LoadAsset cost — happens once, not per spawn.
------------------------------------------------------------
local function setFolder(s) return (s:gsub("_%d+$", "")) end

local function partCandidates(setName, sex, part)
  local base = ARM .. setFolder(setName) .. "/Meshes/"
  local out, roots = {}, { setName .. "_" .. sex, setName }
  local sfx
  if part == "Head" then
    sfx = { "_Head", "_Hat", "_BandanaHat", "_Bandana" }
    for _, r in ipairs(roots) do
      for _, s in ipairs(sfx) do
        local a = "SK_Armor_" .. r .. s
        table.insert(out, base .. a .. "." .. a)
      end
    end
    return out
  end
  sfx = { "", "_Long" }
  if part == "Torso" then sfx = { "", "_Long", "_01", "_02", "_03", "_Long_01" } end
  for _, r in ipairs(roots) do
    for _, s in ipairs(sfx) do
      local a = "SK_Armor_" .. r .. "_" .. part .. s
      table.insert(out, base .. a .. "." .. a)
    end
  end
  return out
end

local outfitMemo = {}
-- parts: e.g. {"Torso","Legs","Feet","Hands","Head"} or villager {"Legs","Feet","Hands"}
function Config.OutfitRules(setName, sex, parts)
  local key = setName .. "|" .. sex .. "|" .. table.concat(parts, ",")
  if outfitMemo[key] then return outfitMemo[key] end
  local replaces = {}
  for _, part in ipairs(parts) do
    table.insert(replaces, {
      name = setName .. " " .. part,
      match = "SK_Armor_.-_" .. part,
      toList = partCandidates(setName, sex, part),
    })
  end
  outfitMemo[key] = { swaps = {}, hides = {}, replaces = replaces }
  return outfitMemo[key]
end


Config.TOWNSFOLK_HAIR_COLOR = nil  -- random per spawn

-- Two female professions exist: HERBALIST and GATHERER. Give them distinct outfits
-- (and both distinct from the tribal villager). Keyed by profession name.

-- HIDE whole mesh pieces whose skeletal-mesh name matches one of these Lua
-- (Hide/replace rules now live inside DECORRUPT_MOB / DECORRUPT_CREW above.
-- Feather variant numbers are RANDOM per spawn, hence the %d+ in those patterns.)

-- Farm goats. Paths CONFIRMED from the game's pak index (2026-07-07). The goat
-- key cycles this roster; made friendly via the crew-faction copy like the boar.
-- GoatF is the passive doe (Calm/Fear AI only). GoatM has a charge/melee attack
-- (friendly copy keeps it from targeting you/crew). GoatMega (a big variant) is
-- available too — add it here if you want it in the cycle.
Config.GOATS = {
  { name = "GoatF", candidates = {
      "/Game/Gameplay/Character/AI/Mob/Goat/GoatF/BP_Mob_GoatF.BP_Mob_GoatF_C" } },
  { name = "GoatM", candidates = {
      "/Game/Gameplay/Character/AI/Mob/Goat/GoatM/BP_Mob_GoatM.BP_Mob_GoatM_C" } },
  -- GoatMega added 2026-08-07 (per user request) -- path was already confirmed, just never
  -- uncommented. Never live-tested; same default-AI + friendly-faction-copy starting point as the
  -- other new creatures added alongside it (Sow, Boar Charger, Boar Mega, Wolf, Alpha Wolf, Crocodile).
  { name = "GoatMega", candidates = {
      "/Game/Gameplay/Character/AI/Mob/Goat/GoatMega/BP_Mob_GoatMega.BP_Mob_GoatMega_C" } },
}

-- DODOS (2026-07-10). Confirmed friendly in-game with the crew-faction copy alone — the male "azure"
-- dodo (BP_Mob_Dodo) spawned calm, no fighting either way — so both sexes join the livestock cycle
-- (NUM_8) and get the same friendly-faction + invincibility treatment as the boar/goats. The male
-- resolved from the standard Mob folder; the female (BP_Mob_DodoF) sits beside it.
-- Folder note: goats live in per-sex subfolders (/Mob/Goat/GoatF/, /Mob/Goat/GoatM/), so the dodos
-- very likely do too — the male that spawned resolved from /Mob/Dodo/Dodo/, and the female (which
-- failed on the flat /Mob/Dodo/ path) is almost certainly under /Mob/Dodo/DodoF/. Candidates are
-- ordered most-likely first; the resolver keeps whichever loads. If the female STILL doesn't appear,
-- capture a wild one (there's one near RedFalcon's base) and read its class off the probe.
Config.DODOS = {
  { name = "Dodo",  candidates = {   -- male, "azure" — verified calm 2026-07-10
      "/Game/Gameplay/Character/AI/Mob/Dodo/Dodo/BP_Mob_Dodo.BP_Mob_Dodo_C",
      "/Game/Gameplay/Character/AI/Mob/Dodo/BP_Mob_Dodo.BP_Mob_Dodo_C" } },
  { name = "DodoF", candidates = {   -- female
      "/Game/Gameplay/Character/AI/Mob/Dodo/DodoF/BP_Mob_DodoF.BP_Mob_DodoF_C",
      "/Game/Gameplay/Character/AI/Mob/Dodo/BP_Mob_DodoF.BP_Mob_DodoF_C",
      "/Game/Gameplay/Character/AI/Mob/DodoF/BP_Mob_DodoF.BP_Mob_DodoF_C" } },
}
-- false = keep the dodo's own brain (what worked). If the FEMALE flees or aggros, set this to its AI
-- controller path to hand it an explicit brain, or add the passive-goat perception strip (GOAT_DISABLE).
Config.DODO_AI = false
--   Config.DODO_AI = "/Game/Gameplay/Character/AI/Mob/Dodo/Behavior/BP_Mob_AIController_Dodo.BP_Mob_AIController_Dodo_C"

-- DODO EGG NEST (EXPERIMENT, END key). The wild harvestable dodo-egg spot is the "MineralNest" prop
-- (paths confirmed in the world dump). We spawn it as a COMBATANT (skips the invulnerable set-dressing
-- so it can still be harvested) and PERSIST it. WHETHER IT RESPAWNS EGGS depends on the actor's own
-- logic registering when raw-spawned — same open question as the trader blocks, which raw-spawned
-- didn't register their interaction. So this is a test: place one, harvest it, see if it refills. If
-- not, capture a wild nest with the probe so we can read what registration/params it carries.
-- DECORATIONS (nature/boats/wrecks/tents/storage/furniture) moved to fkeys.lua (2026-08-13) --
-- see Config.DECOR_CATEGORIES / Config.DECOR_ORDER, merged in above from require("fkeys").

-- Character sex enum (ER5BLCharacterSex, from CXX dump 2026-07-06).
-- Used with UR5CompositeMeshComponent:SetCharacterSex / GetAvailableBodyTypes.
Config.SEX = { Any = 0, Male = 1, Female = 2 }


-- Wandering civilians ("milling around")
Config.TOWNSFOLK_WALKER_CLASS =
  "/Game/Gameplay/Character/AI/NPC/Citizen/Walker/BP_NPC_Citizen_Walker.BP_NPC_Citizen_Walker_C"
Config.TOWNSFOLK_WORKER_CLASS =
  "/Game/Gameplay/Character/AI/NPC/Citizen/Worker/BP_NPC_Citizen_Worker.BP_NPC_Citizen_Worker_C"

-- TOWNSFOLK ROSTER — the townsman key picks one at RANDOM each press (never the
-- same one twice in a row), so outfits vary instead of alternating Walker/Worker.
-- Each Citizen class ships basically ONE outfit, so real variety comes from using
-- more classes. The Handyman profession NPCs each have their own outfit AND are
-- the pawns the Handyman AI was built for, so they wander + use furniture with
-- their OWN default AI (no override — `handymanAI` stays false for them).
-- Paths confirmed from the pak index (2026-07-07).
-- VARIETY WITHIN A CLASS. Each Handyman profession has exactly ONE PresetArchetype,
-- so every Farmer looks identical. The archetype is what carries face/body/skin/sex,
-- so we assign a RANDOM one per spawn (pre-build) to break the clones.
--   * BodyTypeParams is the list the body mesh is resolved FROM. AI pawns lack
--     female entries, so a female archetype would build on a male body. Setting the
--     player's list (HERO_BODY_TYPES) gives every body type, male and female.
--   * Archetype ethnicity names (Adventurer/African/Albion/Fable/Native/Orient/Scum)
--     match the DA_Mannequin_BodyTypes_<Ethnicity><Sex>Params assets.
-- RESULT (2026-07-08): FAILED, reverted to false.
--   * BodyTypeParams DID take — but each body type carries its own AnimClass, so the
--     hero list gave AI pawns the player's anim setup: they SKATED (no leg animation).
--   * The archetype override did NOT take — Handyman classes re-apply their own
--     archetype in BeginPlay (like Citizen_Walker). Only CREW holds an override.
-- So: don't touch BodyTypeParams on a pawn that must walk, and don't expect an
-- archetype override to stick on Handyman/Citizen classes.
Config.TOWNSFOLK_VARY_ARCHETYPE = false
Config.HERO_BODY_TYPES =
  "/Game/Gameplay/Character/Customization/CompositeMeshParams/DA_Hero_CompositeMesh_BodyTypesParams.DA_Hero_CompositeMesh_BodyTypesParams"

local ETHN = { "Adventurer", "African", "Albion", "Fable", "Native", "Orient", "Scum" }
local function objPath(folder, asset) return folder .. asset .. "." .. asset end
Config.TOWNSFOLK_ARCHETYPES = {}
-- 21 male civilian looks: TortugaCitizen Musketeer/Sailor/Sergeant x 7 ethnicities
local TC = "/R5BusinessRules/Character/Customization/NPC/TortugaCitizen/Common/"
for _, role in ipairs({ "Musketeer", "Sailor", "Sergeant" }) do
  for _, e in ipairs(ETHN) do
    table.insert(Config.TOWNSFOLK_ARCHETYPES,
      objPath(TC .. role .. "/", "DA_Mob_TortugaCitizen_Regular_" .. role .. "_Preset_Archetype" .. e))
  end
end
-- 7 female looks: Brethren women (the only female archetype set in the game)
local BF = "/R5BusinessRules/Character/Customization/NPC/BrethrenOfTheCoast/Common/Female/"
for _, e in ipairs(ETHN) do
  table.insert(Config.TOWNSFOLK_ARCHETYPES,
    objPath(BF, "DA_Mob_Brethren_Regular_Female_Preset_Archetype" .. e))
end

local HM = "/Game/Gameplay/Character/AI/NPC/Handyman/Handyman_"
Config.TOWNSFOLK_CLASSES = {
  { name = "Walker",    path = Config.TOWNSFOLK_WALKER_CLASS, handymanAI = true },
  { name = "Worker",    path = Config.TOWNSFOLK_WORKER_CLASS, handymanAI = true },
  { name = "Farmer",    path = HM .. "Farmer/BP_NPC_Handyman_Farmer.BP_NPC_Handyman_Farmer_C" },
  { name = "Gatherer",  path = HM .. "Gatherer/BP_NPC_Handyman_Gatherer.BP_NPC_Handyman_Gatherer_C" },
  { name = "Herbalist", path = HM .. "Herbalist/BP_NPC_Handyman_Herbalist.BP_NPC_Handyman_Herbalist_C" },
  { name = "Hunter",    path = HM .. "Hunter/BP_NPC_Handyman_Hunter.BP_NPC_Handyman_Hunter_C" },
  { name = "Miner",     path = HM .. "Miner/BP_NPC_Handyman_Miner.BP_NPC_Handyman_Miner_C" },
  { name = "Woodman",   path = HM .. "Woodman/BP_NPC_Handyman_Woodman.BP_NPC_Handyman_Woodman_C" },
}



-- WALKING FACTION VISITORS (confirmed working 2026-08-07, replacing an earlier dead-end).
-- Original idea (ambient, no trade — decision 2026-07-06) assumed each faction had its own walking
-- Crew-type class under /Crew/Regular/Faction/<Name>/, guessed by name, never confirmed. Checked
-- Manifest_UFSFiles_Win64.txt directly: only Player and Blackbeard actually have one. Buccaneers/
-- Smugglers/TortugaCitizen/BrethrenOfTheCoast only ship AnimatedActor (static, non-walking) content
-- — there was no real asset at any of those guessed paths, confirmed via Spawner.Spawn's own
-- unconditional "SPAWN FAILED (class unresolved)" log.
-- REAL mechanism: spawn Config.CREW_CLASS (the proven-walking Player crew pawn, own default AI —
-- do NOT pass Config.HANDYMAN_AI_CLASS, crew freezes with it) re-skinned via compositeLook's
-- `params` field, same technique already proven by the Senkamati Warrior re-skin (spawnCleanSenkamati
-- in testbed.lua). MUST be `params` (a CompositeMeshComponentParams asset, a direct composite-mesh
-- definition), NOT `archetype` (an ArchetypePreset) — an archetype override was tried first and
-- confirmed to resolve fine (Spawner.SetCompositeParams logged "archetype=ok") yet still produced a
-- default-looking crew pawn: BeginPlay silently re-resolves/discards ArchetypePreset on CREW_CLASS,
-- the same "BeginPlay wins" failure already known for Citizen_Walker/Handyman, just not previously
-- known to also apply to this field on this class. `params` (confirmed live, screenshot-verified: a
-- Buccaneers Musketeer reskin actually looked like one and still walked normally) is the one that
-- survives BeginPlay.
-- Every FactionActors faction ships the SAME three generic ("Common", not per-named-NPC)
-- composite-mesh params — Musketeer/Sailor/Sergeant — except Brethren of the Coast, which also has
-- a Female_01 look (the only female option; Buccaneers/Smugglers/Tortuga are male-only here).
-- colorParams added 2026-08-07: found live via dump_object on a spawned visitor's
-- CompositeMeshComponent -- ColorParams (type R5CompositeMeshColorCustomizationParams) was
-- defaulting to a generic /R5BusinessRules/.../NPC/Common/DA_NPC_Common_CompositeMeshColorCustomiz-
-- ationParams (the blue-top/red-white-bottom look every visitor had regardless of faction). Each
-- role ships its own "..._PresetColor" asset of this same type, under a DIFFERENT plugin root
-- (/R5BusinessRules/...) than the CompositeMeshComponentParams above (/Game/...) -- two separate
-- content mounts for what looks like one naming family, easy to conflate.
-- RESULT: setting comp.ColorParams in the same PRE-BUILD preFinish window as params/archetype caused
-- a FATAL native crash on startup/restore (confirmed live 2026-08-07, real crash-stack-trace, not a
-- soft ensure) -- theory: unlike params/archetype (the INPUT to construction, safe before the mesh
-- exists), ColorParams may only be valid POST-build (coloring mesh slots that don't exist pre-build),
-- same class of bug as the documented Senkamati de-corrupt-too-early crash (1.2s was too soon there
-- too). Testbed.SpawnCrew no longer passes colorParams (see its own comment) -- the paths below are
-- kept, verified-correct and ready to use, for a future POST-build+delay attempt (mirror
-- Spawner.ApplyComposite's rebuild-trigger pattern, with an ExecuteWithDelay settle first) rather
-- than rediscovering them. Do not wire colorParams back into the pre-build path again.
-- MERGED INTO NUM1 (2026-08-07): this was its own key (Num+) at first; user asked to fold it into
-- the crew key instead now that no other class type is in play (every entry here is CREW_CLASS,
-- same as plain crew) -- one press cycles default crew -> the 12 faction looks -> back to default,
-- freeing Num+ again. The plain "Player Crew" entry (params=nil) is index 1 so first press matches
-- old Num1 behavior exactly; Testbed.SpawnCrew handles params=nil as "spawn with no compositeLook".
local FV  = "/Game/Gameplay/Character/AI/NPC/FactionActors/"
local FVC = "/R5BusinessRules/Character/Customization/NPC/"
Config.FACTION_VISITOR_LOOKS = {
  { faction = "Player", name = "Player Crew" },
  { faction = "Buccaneers", name = "Buccaneers Musketeer",
    params = objPath(FV .. "Buccaneers/CompositeMesh/Common/", "DA_NPC_AnimatedActor_Bucaneers_Common_Musketeer_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "Buccaneers/Common/Musketeer/", "DA_AnimatedActor_Bucaneers_Common_Musketeer_PresetColor") },
  { faction = "Buccaneers", name = "Buccaneers Sailor",
    params = objPath(FV .. "Buccaneers/CompositeMesh/Common/", "DA_NPC_AnimatedActor_Bucaneers_Common_Sailor_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "Buccaneers/Common/Sailor/", "DA_AnimatedActor_Bucaneers_Common_Sailor_PresetColor") },
  { faction = "Buccaneers", name = "Buccaneers Sergeant",
    params = objPath(FV .. "Buccaneers/CompositeMesh/Common/", "DA_NPC_AnimatedActor_Bucaneers_Common_Sergeant_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "Buccaneers/Common/Sergeant/", "DA_AnimatedActor_Bucaneers_Common_Sergeant_PresetColor") },
  -- Smugglers/Tortuga/Brethren Musketeer/Sailor/Sergeant looks (9 entries) removed 2026-08-18,
  -- RedFalcon's spawn-tree reorg pass -- kept Player, all 3 Buccaneers looks, and Brethren Woman.
  -- RESULT (2026-08-07): tried sex=Female + bodyTypes=HERO_BODY_TYPES here -- confirmed WORSE, not
  -- better. Still presented male (the sex/bodyType override didn't stick, same "BeginPlay wins"
  -- pattern as archetype) AND made the pawn skate (no leg animation) instead of walking normally.
  -- This is the SAME HERO_BODY_TYPES failure already documented for Handyman/Citizen
  -- (TOWNSFOLK_VARY_ARCHETYPE's own comment), now confirmed to also break CREW_CLASS, not just
  -- Handyman/Citizen as previously thought. Reverted to params-only: presents male (wrong), but at
  -- least walks correctly (right) -- the lesser-broken state. Getting a genuinely female-bodied,
  -- correctly-animated crew reskin needs a different fix, not attempted again blind -- likely a
  -- female-specific BodyTypeParams that shares crew's own AnimClass, if one exists at all; unconfirmed.
  { faction = "Brethren of the Coast", name = "Brethren Woman",
    params = objPath(FV .. "BrethrenOfTheCoast/CompositeMesh/Common/", "DA_NPC_AnimatedActor_BotC_Common_Female_01_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "BrethrenOfTheCoast/Common/Female/", "DA_AnimatedActor_BotC_Common_Female_PresetColor") },
}

------------------------------------------------------------
-- FEMALE WALKER OVERLAYS (2026-08-10) -- "look like Letty/Marita/etc but walking": post-spawn
-- hide/replace rules (the SAME Spawner.DeCorrupt mechanism the Senkamati re-skins use) that swap
-- the Handyman-Gatherer walker's Brethren Woman composite pieces for a SPECIFIC character/statue's
-- own mesh pieces, captured via a live HOME+PAUSE probe on each (2026-08-10). CONFIRMED: our own
-- composite, Letty, Marita, the merchant, and the statue poses ALL draw from the same shared
-- modular human armor/hair library (Flibustier/Jeweler/Conquistador/Mercenary/Brigant/Starter
-- families, standard Belt/Sling/Frog accessories, standard Eyebrows_Female_0X, standard Hair
-- styles) on a Human/Regular body mesh -- just a different combination of pieces (and sometimes a
-- different body mesh) per character/statue, not a fundamentally different system.
-- `replaces[].match` is checked against the WALKER'S OWN current mesh name at the moment this
-- runs. FIRST VERSION (2026-08-10) hardcoded the exact mesh name from ONE probed Brethren Woman
-- spawn (e.g. "Jeweler_02_Female_Torso_Long_01") -- CONFIRMED LIVE this was wrong: the composite
-- RANDOMIZES some slots per spawn (a second probe of a fresh walker showed Torso rolled
-- "Jeweler_03_..." and Feet rolled "Flibustier_02_..." instead of the first probe's "Jeweler_02_"
-- values), so a fixed match only hit on the lucky spawns that happened to roll the same variant --
-- this is why most pieces silently failed to swap and "none of the statics look like their
-- source" even for Letty, whose ruleset otherwise had no bugs. FIXED: every `match` below is now
-- the SLOT SUFFIX ONLY (e.g. "Female_Torso", not the family+variant-number prefix), broad enough
-- to catch whichever variant that slot rolled while staying unique per slot (confirmed no
-- cross-slot collisions across the walker's known component list). "Hair_" is deliberately the
-- broadest of all -- hair can roll a different STYLE entirely (Shag/Ponytail/Wig/Afro/ShortBob),
-- not just a different number, so there's no shared family substring to key off like the armor
-- pieces have; every hair skeletal mesh in this game is named "SK_Hair_...", so this is still safe
-- and unique. Re-matching a rule's OWN already-applied target on a retry pass is already handled
-- by Spawner.DeCorrupt's existing `_targetNames` dedup guard (see its own comment), so broadening
-- these patterns doesn't risk an infinite replace loop.
-- SECOND ROUND OF BUGS FOUND LIVE (2026-08-10, same day, after the slot-suffix fix above):
-- (1) headwear can roll under a COMPLETELY DIFFERENT WORD, not just a different family/number --
-- confirmed via probe: the same walker rolled "SK_Armor_Jeweler_03_Female_Hat" ("..._Hat") on two
-- separate spawns, which "Female_Headband" never matches. Every entry that touches headwear now
-- has TWO rules (or two hide patterns for Letty) -- "Female_Headband" AND "Female_Hat" -- pointing
-- at the same target, since there's no shared substring between the two words to key off safely
-- (a short prefix like "Female_H" would also catch "Female_Hands", a different slot entirely).
-- This was very likely also the cause of the "1 ended up bald" report -- an unreplaced random hat
-- roll can visually read as a bald cap if nothing swaps it out. (2) Letty's own probe was
-- re-checked and actually has NO belt or frog either (only 6 real pieces total -- feet/hands/legs/
-- torso/eyebrows/hair) -- the original ruleset wrongly assumed those matched the walker's default
-- without checking her specific dump; her hides list now covers all four missing slots.
-- `hides` covers a slot the target doesn't wear at all (e.g. Letty has no headband/hat or sling)
-- -- broadened the same way. Anything NOT listed
-- for a given entry (Belt/Frog, mostly) is left alone on purpose -- their probe showed the
-- identical asset the walker already has, so there's nothing to change.
-- Body mesh is ALSO just another comp[] match (Spawner.DeCorrupt sweeps actor.Mesh the same as
-- every sub-piece, see its own "pcall(function() local mm = actor.Mesh... doComp(mm) end)" call),
-- so a target on a different body COULD in principle get a full body swap, not just a costume
-- swap. CONFIRMED LIVE (2026-08-10) this T-poses the walker -- Marita/Merchant/Standing_01/
-- Sitting_01 all froze in a T-pose the moment their body-swap rule fired; Letty (the one entry
-- with no body swap, same body as the walker already) was the only one that kept walking/posing
-- normally. Root cause not fully diagnosed (VERBOSE was off, so the per-component log detail
-- wasn't captured), but the likely mechanism: SetSkeletalMeshAsset on actor.Mesh doesn't survive
-- with a working AnimInstance the way DeCorrupt applies it -- possibly the "re-bind leader pose to
-- actor.Mesh" step inside DeCorrupt's replace handler misbehaving when the component AND the
-- leader are the SAME object (c == actor.Mesh), possibly something else. Every body-swap rule
-- below is commented out (not deleted) rather than guessed-and-retried blind; each affected entry
-- keeps the walker's own SK_Adventure_Female_01 body until this is properly root-caused.
-- NOT YET PROBED: Female_Sitting_02/03 (the other two chair-sitting women) -- no overlay entry
-- yet, so Testbed.TestFemaleWalkerReskin falls back to the plain Brethren Woman look for those two
-- slots until they're probed the same way.
local ARM   = "/Game/Character/Skeletal_Meshes/Armor/ArmorRegular/"
local HMN   = "/Game/Character/Skeletal_Meshes/Human/Regular/"
local BROW  = "/Game/Character/Skeletal_Meshes/Facial/Female/Eyebrows/Meshes/"
local HAIRD = "/Game/Character/Skeletal_Meshes/Hair/Female/"
local HAIRM = "/Game/Character/Skeletal_Meshes/Hair/Male/"

-- Config.SKIN_FAMILIES / Config.SkinFamilySwapRules(family, sex) — "skin tone" for this
-- game's human bodies. Confirmed via probe (2026-08-10, during the tattoo investigation)
-- that skin tone is NOT a shader tint: the body's own skin material (MI_<Family>_<Sex>_
-- <Size>) has ZERO Vector/Scalar/StaticSwitch override parameters of its own — the tone
-- comes entirely from which baked ALBEDO TEXTURE that material ships, i.e. which of the
-- game's own ethnicity families the composite happened to build with. Confirmed present
-- in the game's own asset manifest: 7 families (Adventurer/African/Albion/Fable/Native/
-- Orient/Scum), each in Large/Medium/Small body-BUILD variants (a mismatched size would
-- put the wrong build's texture set on the mesh, so rules are generated per-size, not one
-- wildcard rule). Reuses Spawner.DeCorrupt's already-proven `swaps` mechanism (matches
-- current material name via Lua pattern, SetMaterial + read-back) — the same mechanism
-- DECORRUPT_MOB already uses for its own ethnicity swaps — rather than new engine code.
-- REINSTATED (2026-08-11) as a real feature (previously only a removed demo tool) — see
-- Testbed.TestFemaleWalkerReskin's own use of this for the generic "plain Brethren Woman"
-- walker slots (Standing_01/Sitting_01, no named-character overlay).
Config.SKIN_FAMILIES = { "Adventurer", "African", "Albion", "Fable", "Native", "Orient", "Scum" }
function Config.SkinFamilySwapRules(family, sex)
  sex = sex or "Female"
  local rules = {}
  for _, size in ipairs({ "Large", "Medium", "Small" }) do
    local asset = "MI_" .. family .. "_" .. sex .. "_" .. size
    table.insert(rules, {
      match = "MI_%a+_" .. sex .. "_" .. size,
      to = objPath(HMN .. family .. "/Materials/", asset),
    })
  end
  return rules
end

-- Config.CorruptedSkinSwapRules(sex) -- an 8th "Custom > Skin Tones" entry (2026-08-28,
-- RedFalcon's request: "including the corrupted skin"). Swaps a HUMAN-bodied actor's skin TO the
-- Senkamati mob's own native skin material -- the reverse direction of Config.DECORRUPT_MOB's
-- swaps above (which go corrupted -> clean), same underlying mechanism either way.
-- Confirmed via pakcontents.xlsx (NOT guessed) that this material lives at
-- `Human/Regular/Senkamati/Materials/MI_Senkamati_<Sex>_<Build>` -- the SAME folder shape as every
-- other family above (`Human/Regular/<Family>/Materials/...`), meaning it's a genuine
-- ethnicity-style asset authored for the human body/UVs, NOT the "Senkamati MESH" case the comment
-- earlier in this file warns about (painting a human skin onto the native SENKAMATI skeletal mesh
-- maps garbage) -- this only ever targets a human-skeleton actor, same as every other family here.
-- Asset availability is UNEVEN, also confirmed via the catalog rather than assumed: only a Medium
-- build exists for Female (Small/Large do not), so all three Female match patterns swap TO that
-- same Medium asset regardless of the target's actual build -- may look slightly off-scale on a
-- Small/Large-build target, but it's the only Female corrupted-skin asset that exists. Male ships
-- a genuine per-build set under the "Feather" sub-family (Warrior/Hunter's own default).
function Config.CorruptedSkinSwapRules(sex)
  sex = sex or "Female"
  local dir = "/Game/Character/Skeletal_Meshes/Human/Regular/Senkamati/Materials/"
  local rules = {}
  if sex == "Male" then
    for _, size in ipairs({ "Large", "Medium", "Small" }) do
      table.insert(rules, {
        match = "MI_%a+_Male_" .. size,
        to = objPath(dir, "MI_Senkamati_Feather_Male_" .. size),
      })
    end
  else
    for _, size in ipairs({ "Large", "Medium", "Small" }) do
      table.insert(rules, {
        match = "MI_%a+_Female_" .. size,
        to = objPath(dir, "MI_Senkamati_Female_Medium"),
      })
    end
  end
  return rules
end

-- Config.CorruptedWoodSkinSwapRules(sex) -- a second Senkamati corrupted-skin option (2026-08-28).
-- The earlier comment above (before this addition) said a "Wood" male variant was referenced by
-- Config.DECORRUPT_MOB but wasn't found in the catalog -- a re-check of pakcontents.xlsx found it
-- after all: `MI_Senkamati_Wood_Male_Medium` genuinely exists, just as a SINGLE Medium-only asset
-- (no Small/Large Wood variant, same one-size-fits-all situation as the Female corrupted skin
-- above) rather than the full per-build "Feather" set. Female has no Wood equivalent at all, so
-- this falls back to the identical Female Medium asset Config.CorruptedSkinSwapRules already uses
-- for that sex -- "Corrupted (Wood)" and "Corrupted" render identically on a Female target, only
-- Male actually differs between the two.
function Config.CorruptedWoodSkinSwapRules(sex)
  sex = sex or "Female"
  local dir = "/Game/Character/Skeletal_Meshes/Human/Regular/Senkamati/Materials/"
  local rules = {}
  if sex == "Male" then
    for _, size in ipairs({ "Large", "Medium", "Small" }) do
      table.insert(rules, {
        match = "MI_%a+_Male_" .. size,
        to = objPath(dir, "MI_Senkamati_Wood_Male_Medium"),
      })
    end
  else
    for _, size in ipairs({ "Large", "Medium", "Small" }) do
      table.insert(rules, {
        match = "MI_%a+_Female_" .. size,
        to = objPath(dir, "MI_Senkamati_Female_Medium"),
      })
    end
  end
  return rules
end

-- Config.CUSTOM_SKIN_TONES -- flat name list for the "Custom > Skin Tones" GUI branch
-- (spawn_menu.ini, via spawnmenu_manifest.lua) -- the 7 confirmed human ethnicity families plus
-- "Corrupted"/"Corrupted (Wood)" (Config.CorruptedSkinSwapRules/CorruptedWoodSkinSwapRules above).
-- Spawner.TestApplySkinFamily(name) is what actually applies one -- see its own comment for the
-- sex auto-detection this needs that lbtestpose/lbtestarmor's simpler path-only testers never did.
Config.CUSTOM_SKIN_TONES = { "Adventurer", "African", "Albion", "Fable", "Native", "Orient", "Scum", "Corrupted", "Corrupted (Wood)" }

-- Config.FEMALE_HAIR_STYLES — "hair style": a MESH swap, not a tint. One entry per
-- hairstyle FAMILY (the game's own folder grouping under Hair/Female/), each pointing at
-- that family's "_Default_Female" variant (no suspended-under-hat/headband version --
-- Testbed.TestFemaleWalkerReskin hides any rolled hat/headband on the generic slots this
-- applies to, same fix as before). Reuses the exact same proven mechanism Letty/Marita/
-- Merchant's own overlays already use for their hair — a Spawner.DeCorrupt `replaces`
-- rule matching "Hair_" — rather than the ColorController tint path (confirmed dead, see
-- the "Known limitations" section of CLAUDE.md).
-- Config.FEMALE_HAIR_STYLES_HAT — the SAME style families, but each pointing at that
-- family's "_SuspendHat_Female" (or "_SuspendedHat_Female", naming varies per family --
-- exact names pulled from the game's own asset manifest, not guessed) mesh instead of
-- "_Default_Female" -- built by the game to sit correctly UNDER a hat, the same mechanism
-- Marita's Wig and the Merchant's ShortBob already use. Only families confirmed (via the
-- manifest) to actually ship a SuspendHat variant are listed -- Bristle/Mohawk/
-- PartialDreadlocks/Undercut don't have one and are left out rather than guessed.
Config.FEMALE_HAIR_STYLES_HAT = {
  { name = "Afro",       path = objPath(HAIRD .. "Afro/",       "SK_Hair_Afro_02_SuspendedHat_Female") },
  { name = "Braid",      path = objPath(HAIRD .. "Braid/",      "SK_Hair_Braid_01_SuspendHat_Female") },
  { name = "Bun",        path = objPath(HAIRD .. "Bun/",        "SK_Hair_Bun_01_SuspendHat_Female") },
  { name = "LayeredBob", path = objPath(HAIRD .. "LayeredBob/", "SK_Hair_LayeredBob_01_SuspendHat_Female") },
  { name = "Pixie",      path = objPath(HAIRD .. "Pixie/",      "SK_Hair_Pixie_01_SuspendHat_Female") },
  { name = "Ponytail",   path = objPath(HAIRD .. "Ponytail/",   "SK_Hair_Ponytail_01_SuspendHat_Female") },
  { name = "Shag",       path = objPath(HAIRD .. "Shag/",       "SK_Hair_Shag_02_SuspendHat_Female") },
  { name = "ShortBob",   path = objPath(HAIRD .. "ShortBob/",   "SK_Hair_ShortBob_SuspendHat_Female") },
  { name = "Slickback",  path = objPath(HAIRD .. "Slickback/",  "SK_Hair_Slickback_SuspendHat_Female") },
  { name = "Wavy",       path = objPath(HAIRD .. "Wavy/",       "SK_Hair_Wavy_01_SuspendHat_Female") },
  { name = "Wick",       path = objPath(HAIRD .. "Wick/",       "SK_Hair_Wick_01_SuspendHat_Female") },
  { name = "Wig",        path = objPath(HAIRD .. "Wig/",        "SK_Hair_Wig_02_SuspendedHat_Female") },
}

-- Config.GENERIC_FEMALE_HATS — a roster of forced HEAD-COVERING meshes for the Standing
-- walker slot (2026-08-11, widened from a single fixed hat at RedFalcon's request -- "it's ok
-- to have the other variations as well, such as bandana hat", then further widened to
-- "any head covering available not just hats", then NARROWED again the same day -- "we
-- dont want headbands on them" -- so headbands were pulled back out; hats + bandanas only.
-- Every entry confirmed in the game's own asset manifest, not guessed. Kept the name
-- GENERIC_FEMALE_HATS (not renamed to _HEADWEAR) so every existing reference to it doesn't
-- need touching too; the comment is what matters. One picked at random per spawn via the
-- same Spawner.ForceHeadwear mechanism already validated end-to-end via the Merchant's own
-- forceHat.
Config.GENERIC_FEMALE_HATS = {
  objPath(ARM .. "Musketeer/Meshes/",  "SK_Armor_Musketeer03_Head"),
  objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Female_BandanaHat"),
  objPath(ARM .. "Bandit/Meshes/",     "SK_Armor_Bandit_Female_Hat"),
  objPath(ARM .. "Brigant/Meshes/",    "SK_Armor_Brigant_Female_Hat"),
  objPath(ARM .. "Mercenary/Meshes/",  "SK_Armor_Mercenary_Female_Hat"),
  objPath(ARM .. "Jeweler/Meshes/",    "SK_Armor_Jeweler_03_Female_Hat"),
  objPath(ARM .. "Vanilla/Meshes/",    "SK_Armor_Vanilla_Female_BandanaHat"),
  -- Plain bandanas (no rigid "Hat" shape) -- kept per "it's ok to have the other
  -- variations... such as bandana hat"; headbands specifically were the ones un-wanted.
  objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Bandana"),
  objPath(ARM .. "Jeweler/Meshes/",    "SK_Armor_Jeweler_02_Female_Bandana_01"),
  objPath(ARM .. "Mercenary/Meshes/",  "SK_Armor_Mercenary_Female_Bandana"),
}

Config.FEMALE_HAIR_STYLES = {
  { name = "Afro",             path = objPath(HAIRD .. "Afro/",             "SK_Hair_Afro_01_Default_Female") },
  { name = "Braid",            path = objPath(HAIRD .. "Braid/",            "SK_Hair_Braid_01_Default_Female") },
  { name = "Bristle",          path = objPath(HAIRD .. "Bristle/",          "SK_Hair_Bristle_01_Default_Female") },
  { name = "Bun",              path = objPath(HAIRD .. "Bun/",              "SK_Hair_Bun_01_Default_Female") },
  { name = "LayeredBob",       path = objPath(HAIRD .. "LayeredBob/",       "SK_Hair_LayeredBob_01_Default_Female") },
  { name = "Mohawk",           path = objPath(HAIRD .. "Mohawk/",           "SK_Hair_Mohawk_01_Default_Female") },
  { name = "PartialDreadlocks",path = objPath(HAIRD .. "PartialDreadlocks/","SK_Hair_PartialDreadlocks_01_Default_Female") },
  { name = "Pixie",            path = objPath(HAIRD .. "Pixie/",            "SK_Hair_Pixie_01_Default_Female") },
  { name = "Ponytail",         path = objPath(HAIRD .. "Ponytail/",         "SK_Hair_Ponytail_01_Default_Female") },
  { name = "Shag",             path = objPath(HAIRD .. "Shag/",             "SK_Hair_Shag_Default_Female") },
  { name = "ShortBob",         path = objPath(HAIRD .. "ShortBob/",         "SK_Hair_ShortBob_Default_Female") },
  { name = "Slickback",        path = objPath(HAIRD .. "Slickback/",        "SK_Hair_Slickback_Default_Female") },
  { name = "Undercut",         path = objPath(HAIRD .. "Undercut/",         "SK_Undercut_01_Default_Female") },
  { name = "Wavy",             path = objPath(HAIRD .. "Wavy/",             "SK_Hair_Wavy_01_Default_Female") },
  { name = "Wick",             path = objPath(HAIRD .. "Wick/",             "SK_Hair_Wick_01_Default_Female") },
  { name = "Wig",              path = objPath(HAIRD .. "Wig/",              "SK_Hair_Wig_01_Default_Female") },
}

-- Config.CUSTOM_HAIR -- "Custom > Hair" GUI branch (2026-08-28, revised AGAIN same day). The
-- previous revision added Headband/Bandana variants but still collapsed each family down to ONE
-- representative numbered mesh (e.g. "Wig" always meant Wig_01) -- RedFalcon caught that this
-- still didn't cover Marita's own hair: her real mesh is specifically `Wig_02_SuspendedBandana`,
-- not `Wig_01`, since several families genuinely ship MULTIPLE numbered sub-styles (Afro has 5,
-- Shag/Pixie/Wavy have 3, Bun/Wick/Wig have 2) that are real, visually distinct looks, not
-- interchangeable copies of the same style the way "pick any one to represent the family" assumed.
-- Rebuilt to expose every numbered sub-style as its own named entry ("Wig 1"/"Wig 2", "Afro 1".."Afro
-- 5", etc.) -- families with only one real style keep their bare name (e.g. "ShortBob"). Also
-- surfaced a genuine naming collision the earlier per-family sweep silently lost: LayeredBob ships
-- TWO distinct meshes both nominally "01" under the SAME folder -- plain `LayeredBob_01_...` and a
-- separate `LayeredBobDecor_01_...` -- now kept as "LayeredBob" and "LayeredBob Decor" instead of
-- one silently overwriting the other. One confirmed real asymmetry excluded rather than guessed
-- around: Male Shag ships 3 extra numbered variants (04/05/06) that Female Shag doesn't have at
-- all -- since this table needs both sexes' paths for the same entry (sex is auto-detected at
-- apply time), those 3 Male-only numbers aren't included; every other family/number is
-- confirmed present for both sexes via pakcontents.xlsx before being added.
-- `variant`/femalePath/malePath/Spawner.TestApplyHairStyle's own sex-auto-detection are otherwise
-- unchanged from the previous revision -- see that function's own comment.
Config.CUSTOM_HAIR = {
  { name = "Afro 1", variant = "Default", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_01_Default_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_01_Default_Male") },
  { name = "Afro 1", variant = "Headband", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_01_SuspendedHeadband_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_01_SuspendedHeadband_Male") },
  { name = "Afro 2", variant = "Default", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_02_Default_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_02_Default_Male") },
  { name = "Afro 2", variant = "Hat", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_02_SuspendedHat_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_02_SuspendedHat_Male") },
  { name = "Afro 2", variant = "Headband", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_02_SuspendedHeadband_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_02_SuspendedHeadband_Male") },
  { name = "Afro 2", variant = "Bandana", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_02_SuspendedBandana_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_02_SuspendedBandana_Male") },
  { name = "Afro 3", variant = "Default", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_03_Default_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_03_Default_Male") },
  { name = "Afro 3", variant = "Hat", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_03_SuspendedHat_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_03_SuspendedHat_Male") },
  { name = "Afro 3", variant = "Headband", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_03_SuspendedHeadband_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_03_SuspendedHeadband_Male") },
  { name = "Afro 3", variant = "Bandana", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_03_SuspendedBandana_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_03_SuspendedBandana_Male") },
  { name = "Afro 4", variant = "Default", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_04_Default_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_04_Default_Male") },
  { name = "Afro 4", variant = "Headband", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_04_SuspendedHeadband_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_04_SuspendedHeadband_Male") },
  { name = "Afro 5", variant = "Default", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_05_Default_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_05_Default_Male") },
  { name = "Afro 5", variant = "Hat", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_05_SuspendedHat_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_05_SuspendedHat_Male") },
  { name = "Afro 5", variant = "Headband", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_05_SuspendedHeadband_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_05_SuspendedHeadband_Male") },
  { name = "Afro 5", variant = "Bandana", femalePath = objPath(HAIRD .. "Afro/", "SK_Hair_Afro_05_SuspendedBandana_Female"), malePath = objPath(HAIRM .. "Afro/", "SK_Hair_Afro_05_SuspendedBandana_Male") },
  { name = "Braid", variant = "Default", femalePath = objPath(HAIRD .. "Braid/", "SK_Hair_Braid_01_Default_Female"), malePath = objPath(HAIRM .. "Braid/", "SK_Hair_Braid_01_Default_Male") },
  { name = "Braid", variant = "Hat", femalePath = objPath(HAIRD .. "Braid/", "SK_Hair_Braid_01_SuspendHat_Female"), malePath = objPath(HAIRM .. "Braid/", "SK_Hair_Braid_01_SuspendHat_Male") },
  { name = "Braid", variant = "Headband", femalePath = objPath(HAIRD .. "Braid/", "SK_Hair_Braid_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Braid/", "SK_Hair_Braid_01_SuspendHeadband_Male") },
  { name = "Braid", variant = "Bandana", femalePath = objPath(HAIRD .. "Braid/", "SK_Hair_Braid_01_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Braid/", "SK_Hair_Braid_01_SuspendBandana_Male") },
  { name = "Bristle", variant = "Default", femalePath = objPath(HAIRD .. "Bristle/", "SK_Hair_Bristle_01_Default_Female"), malePath = objPath(HAIRM .. "Bristle/", "SK_Hair_Bristle_01_Default_Male") },
  { name = "Bun 1", variant = "Default", femalePath = objPath(HAIRD .. "Bun/", "SK_Hair_Bun_01_Default_Female"), malePath = objPath(HAIRM .. "Bun/", "SK_Hair_Bun_01_Default_Male") },
  { name = "Bun 1", variant = "Hat", femalePath = objPath(HAIRD .. "Bun/", "SK_Hair_Bun_01_SuspendHat_Female"), malePath = objPath(HAIRM .. "Bun/", "SK_Hair_Bun_01_SuspendHat_Male") },
  { name = "Bun 1", variant = "Headband", femalePath = objPath(HAIRD .. "Bun/", "SK_Hair_Bun_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Bun/", "SK_Hair_Bun_01_SuspendHeadband_Male") },
  { name = "Bun 1", variant = "Bandana", femalePath = objPath(HAIRD .. "Bun/", "SK_Hair_Bun_01_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Bun/", "SK_Hair_Bun_01_SuspendBandana_Male") },
  { name = "Bun 2", variant = "Default", femalePath = objPath(HAIRD .. "Bun/", "SK_Hair_Bun_02_Default_Female"), malePath = objPath(HAIRM .. "Bun/", "SK_Hair_Bun_02_Default_Male") },
  { name = "Bun 2", variant = "Hat", femalePath = objPath(HAIRD .. "Bun/", "SK_Hair_Bun_02_SuspendHat_Female"), malePath = objPath(HAIRM .. "Bun/", "SK_Hair_Bun_02_SuspendHat_Male") },
  { name = "Bun 2", variant = "Headband", femalePath = objPath(HAIRD .. "Bun/", "SK_Hair_Bun_02_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Bun/", "SK_Hair_Bun_02_SuspendHeadband_Male") },
  { name = "Bun 2", variant = "Bandana", femalePath = objPath(HAIRD .. "Bun/", "SK_Hair_Bun_02_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Bun/", "SK_Hair_Bun_02_SuspendBandana_Male") },
  { name = "LayeredBob", variant = "Default", femalePath = objPath(HAIRD .. "LayeredBob/", "SK_Hair_LayeredBob_01_Default_Female"), malePath = objPath(HAIRM .. "LayeredBob/", "SK_Hair_LayeredBob_01_Default_Male") },
  { name = "LayeredBob", variant = "Hat", femalePath = objPath(HAIRD .. "LayeredBob/", "SK_Hair_LayeredBob_01_SuspendHat_Female"), malePath = objPath(HAIRM .. "LayeredBob/", "SK_Hair_LayeredBob_01_SuspendHat_Male") },
  { name = "LayeredBob", variant = "Headband", femalePath = objPath(HAIRD .. "LayeredBob/", "SK_Hair_LayeredBob_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "LayeredBob/", "SK_Hair_LayeredBob_01_SuspendHeadband_Male") },
  { name = "LayeredBob", variant = "Bandana", femalePath = objPath(HAIRD .. "LayeredBob/", "SK_Hair_LayeredBob_01_SuspendBandana_Female"), malePath = objPath(HAIRM .. "LayeredBob/", "SK_Hair_LayeredBob_01_SuspendBandana_Male") },
  { name = "LayeredBob Decor", variant = "Default", femalePath = objPath(HAIRD .. "LayeredBob/", "SK_Hair_LayeredBobDecor_01_Default_Female"), malePath = objPath(HAIRM .. "LayeredBob/", "SK_Hair_LayeredBobDecor_01_Default_Male") },
  { name = "LayeredBob Decor", variant = "Hat", femalePath = objPath(HAIRD .. "LayeredBob/", "SK_Hair_LayeredBobDecor_01_SuspendHat_Female"), malePath = objPath(HAIRM .. "LayeredBob/", "SK_Hair_LayeredBobDecor_01_SuspendHat_Male") },
  { name = "LayeredBob Decor", variant = "Headband", femalePath = objPath(HAIRD .. "LayeredBob/", "SK_Hair_LayeredBobDecor_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "LayeredBob/", "SK_Hair_LayeredBobDecor_01_SuspendHeadband_Male") },
  { name = "LayeredBob Decor", variant = "Bandana", femalePath = objPath(HAIRD .. "LayeredBob/", "SK_Hair_LayeredBobDecor_01_SuspendBandana_Female"), malePath = objPath(HAIRM .. "LayeredBob/", "SK_Hair_LayeredBobDecor_01_SuspendBandana_Male") },
  { name = "Mohawk", variant = "Default", femalePath = objPath(HAIRD .. "Mohawk/", "SK_Hair_Mohawk_01_Default_Female"), malePath = objPath(HAIRM .. "Mohawk/", "SK_Hair_Mohawk_01_Default_Male") },
  { name = "Mohawk", variant = "Headband", femalePath = objPath(HAIRD .. "Mohawk/", "SK_Hair_Mohawk_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Mohawk/", "SK_Hair_Mohawk_01_SuspendHeadband_Male") },
  { name = "PartialDreadlocks", variant = "Default", femalePath = objPath(HAIRD .. "PartialDreadlocks/", "SK_Hair_PartialDreadlocks_01_Default_Female"), malePath = objPath(HAIRM .. "PartialDreadlocks/", "SK_Hair_PartialDreadlocks_01_Default_Male") },
  { name = "PartialDreadlocks", variant = "Hat", femalePath = objPath(HAIRD .. "PartialDreadlocks/", "SK_Hair_PartialDreadlocks_01_Hat_Female"), malePath = objPath(HAIRM .. "PartialDreadlocks/", "SK_Hair_PartialDreadlocks_01_Hat_Male") },
  { name = "PartialDreadlocks", variant = "Headband", femalePath = objPath(HAIRD .. "PartialDreadlocks/", "SK_Hair_PartialDreadlocks_01_Headband_Female"), malePath = objPath(HAIRM .. "PartialDreadlocks/", "SK_Hair_PartialDreadlocks_01_Headband_Male") },
  { name = "PartialDreadlocks", variant = "Bandana", femalePath = objPath(HAIRD .. "PartialDreadlocks/", "SK_Hair_PartialDreadlocks_01_Bandana_Female"), malePath = objPath(HAIRM .. "PartialDreadlocks/", "SK_Hair_PartialDreadlocks_01_Bandana_Male") },
  { name = "Pixie 1", variant = "Default", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_01_Default_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_01_Default_Male") },
  { name = "Pixie 1", variant = "Hat", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_01_SuspendHat_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_01_SuspendHat_Male") },
  { name = "Pixie 1", variant = "Headband", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_01_SuspendHeadband_Male") },
  { name = "Pixie 1", variant = "Bandana", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_01_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_01_SuspendBandana_Male") },
  { name = "Pixie 2", variant = "Default", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_02_Default_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_02_Default_Male") },
  { name = "Pixie 2", variant = "Hat", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_02_SuspendHat_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_02_SuspendHat_Male") },
  { name = "Pixie 2", variant = "Headband", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_02_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_02_SuspendHeadband_Male") },
  { name = "Pixie 2", variant = "Bandana", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_02_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_02_SuspendBandana_Male") },
  { name = "Pixie 3", variant = "Default", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_03_Default_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_03_Default_Male") },
  { name = "Pixie 3", variant = "Hat", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_03_SuspendHat_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_03_SuspendHat_Male") },
  { name = "Pixie 3", variant = "Headband", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_03_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_03_SuspendHeadband_Male") },
  { name = "Pixie 3", variant = "Bandana", femalePath = objPath(HAIRD .. "Pixie/", "SK_Hair_Pixie_03_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Pixie/", "SK_Hair_Pixie_03_SuspendBandana_Male") },
  { name = "Ponytail", variant = "Default", femalePath = objPath(HAIRD .. "Ponytail/", "SK_Hair_Ponytail_01_Default_Female"), malePath = objPath(HAIRM .. "Ponytail/", "SK_Hair_Ponytail_01_Default_Male") },
  { name = "Ponytail", variant = "Hat", femalePath = objPath(HAIRD .. "Ponytail/", "SK_Hair_Ponytail_01_SuspendHat_Female"), malePath = objPath(HAIRM .. "Ponytail/", "SK_Hair_Ponytail_01_SuspendHat_Male") },
  { name = "Ponytail", variant = "Headband", femalePath = objPath(HAIRD .. "Ponytail/", "SK_Hair_Ponytail_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Ponytail/", "SK_Hair_Ponytail_01_SuspendHeadband_Male") },
  { name = "Ponytail", variant = "Bandana", femalePath = objPath(HAIRD .. "Ponytail/", "SK_Hair_Ponytail_01_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Ponytail/", "SK_Hair_Ponytail_01_SuspendBandana_Male") },
  { name = "Shag 1", variant = "Default", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_Default_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_Default_Male") },
  { name = "Shag 1", variant = "Hat", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_SuspendHat_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_SuspendHat_Male") },
  { name = "Shag 1", variant = "Headband", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_SuspendHeadband_Male") },
  { name = "Shag 1", variant = "Bandana", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_SuspendBandana_Male") },
  { name = "Shag 2", variant = "Default", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_02_Default_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_02_Default_Male") },
  { name = "Shag 2", variant = "Hat", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_02_SuspendHat_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_02_SuspendHat_Male") },
  { name = "Shag 2", variant = "Headband", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_02_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_02_SuspendHeadband_Male") },
  { name = "Shag 2", variant = "Bandana", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_02_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_02_SuspendBandana_Male") },
  { name = "Shag 3", variant = "Default", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_03_Default_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_03_Default_Male") },
  { name = "Shag 3", variant = "Hat", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_03_SuspendHat_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_03_SuspendHat_Male") },
  { name = "Shag 3", variant = "Headband", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_03_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_03_SuspendHeadband_Male") },
  { name = "Shag 3", variant = "Bandana", femalePath = objPath(HAIRD .. "Shag/", "SK_Hair_Shag_03_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Shag/", "SK_Hair_Shag_03_SuspendBandana_Male") },
  { name = "ShortBob", variant = "Default", femalePath = objPath(HAIRD .. "ShortBob/", "SK_Hair_ShortBob_Default_Female"), malePath = objPath(HAIRM .. "ShortBob/", "SK_Hair_ShortBob_Default_Male") },
  { name = "ShortBob", variant = "Hat", femalePath = objPath(HAIRD .. "ShortBob/", "SK_Hair_ShortBob_SuspendHat_Female"), malePath = objPath(HAIRM .. "ShortBob/", "SK_Hair_ShortBob_SuspendHat_Male") },
  { name = "ShortBob", variant = "Headband", femalePath = objPath(HAIRD .. "ShortBob/", "SK_Hair_ShortBob_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "ShortBob/", "SK_Hair_ShortBob_SuspendHeadband_Male") },
  { name = "ShortBob", variant = "Bandana", femalePath = objPath(HAIRD .. "ShortBob/", "SK_Hair_ShortBob_SuspendBandana_Female"), malePath = objPath(HAIRM .. "ShortBob/", "SK_Hair_ShortBob_SuspendBandana_Male") },
  { name = "Slickback", variant = "Default", femalePath = objPath(HAIRD .. "Slickback/", "SK_Hair_Slickback_Default_Female"), malePath = objPath(HAIRM .. "Slickback/", "SK_Hair_Slickback_Default_Male") },
  { name = "Slickback", variant = "Hat", femalePath = objPath(HAIRD .. "Slickback/", "SK_Hair_Slickback_SuspendHat_Female"), malePath = objPath(HAIRM .. "Slickback/", "SK_Hair_Slickback_SuspendHat_Male") },
  { name = "Slickback", variant = "Headband", femalePath = objPath(HAIRD .. "Slickback/", "SK_Hair_Slickback_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Slickback/", "SK_Hair_Slickback_SuspendHeadband_Male") },
  { name = "Slickback", variant = "Bandana", femalePath = objPath(HAIRD .. "Slickback/", "SK_Hair_Slickback_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Slickback/", "SK_Hair_Slickback_SuspendBandana_Male") },
  { name = "Undercut", variant = "Default", femalePath = objPath(HAIRD .. "Undercut/", "SK_Undercut_01_Default_Female"), malePath = objPath(HAIRM .. "Undercut/", "SK_Undercut_01_Default_Male") },
  { name = "Undercut", variant = "Headband", femalePath = objPath(HAIRD .. "Undercut/", "SK_Undercut_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Undercut/", "SK_Undercut_01_SuspendHeadband_Male") },
  { name = "Wavy 1", variant = "Default", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_01_Default_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_01_Default_Male") },
  { name = "Wavy 1", variant = "Hat", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_01_SuspendHat_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_01_SuspendHat_Male") },
  { name = "Wavy 1", variant = "Headband", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_01_SuspendHeadband_Male") },
  { name = "Wavy 1", variant = "Bandana", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_01_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_01_SuspendBandana_Male") },
  { name = "Wavy 2", variant = "Default", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_02_Default_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_02_Default_Male") },
  { name = "Wavy 2", variant = "Hat", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_02_SuspendHat_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_02_SuspendHat_Male") },
  { name = "Wavy 2", variant = "Headband", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_02_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_02_SuspendHeadband_Male") },
  { name = "Wavy 2", variant = "Bandana", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_02_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_02_SuspendBandana_Male") },
  { name = "Wavy 3", variant = "Default", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_03_Default_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_03_Default_Male") },
  { name = "Wavy 3", variant = "Hat", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_03_SuspendHat_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_03_SuspendHat_Male") },
  { name = "Wavy 3", variant = "Headband", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_03_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_03_SuspendHeadband_Male") },
  { name = "Wavy 3", variant = "Bandana", femalePath = objPath(HAIRD .. "Wavy/", "SK_Hair_Wavy_03_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Wavy/", "SK_Hair_Wavy_03_SuspendBandana_Male") },
  { name = "Wick 1", variant = "Default", femalePath = objPath(HAIRD .. "Wick/", "SK_Hair_Wick_01_Default_Female"), malePath = objPath(HAIRM .. "Wick/", "SK_Hair_Wick_01_Default_Male") },
  { name = "Wick 1", variant = "Hat", femalePath = objPath(HAIRD .. "Wick/", "SK_Hair_Wick_01_SuspendHat_Female"), malePath = objPath(HAIRM .. "Wick/", "SK_Hair_Wick_01_SuspendHat_Male") },
  { name = "Wick 1", variant = "Headband", femalePath = objPath(HAIRD .. "Wick/", "SK_Hair_Wick_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Wick/", "SK_Hair_Wick_01_SuspendHeadband_Male") },
  { name = "Wick 1", variant = "Bandana", femalePath = objPath(HAIRD .. "Wick/", "SK_Hair_Wick_01_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Wick/", "SK_Hair_Wick_01_SuspendBandana_Male") },
  { name = "Wick 2", variant = "Default", femalePath = objPath(HAIRD .. "Wick/", "SK_Hair_Wick_02_Default_Female"), malePath = objPath(HAIRM .. "Wick/", "SK_Hair_Wick_02_Default_Male") },
  { name = "Wick 2", variant = "Hat", femalePath = objPath(HAIRD .. "Wick/", "SK_Hair_Wick_02_SuspendHat_Female"), malePath = objPath(HAIRM .. "Wick/", "SK_Hair_Wick_02_SuspendHat_Male") },
  { name = "Wick 2", variant = "Headband", femalePath = objPath(HAIRD .. "Wick/", "SK_Hair_Wick_02_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Wick/", "SK_Hair_Wick_02_SuspendHeadband_Male") },
  { name = "Wick 2", variant = "Bandana", femalePath = objPath(HAIRD .. "Wick/", "SK_Hair_Wick_02_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Wick/", "SK_Hair_Wick_02_SuspendBandana_Male") },
  { name = "Wig 1", variant = "Default", femalePath = objPath(HAIRD .. "Wig/", "SK_Hair_Wig_01_Default_Female"), malePath = objPath(HAIRM .. "Wig/", "SK_Hair_Wig_01_Default_Male") },
  { name = "Wig 1", variant = "Hat", femalePath = objPath(HAIRD .. "Wig/", "SK_Hair_Wig_01_SuspendHat_Female"), malePath = objPath(HAIRM .. "Wig/", "SK_Hair_Wig_01_SuspendHat_Male") },
  { name = "Wig 1", variant = "Headband", femalePath = objPath(HAIRD .. "Wig/", "SK_Hair_Wig_01_SuspendHeadband_Female"), malePath = objPath(HAIRM .. "Wig/", "SK_Hair_Wig_01_SuspendHeadband_Male") },
  { name = "Wig 1", variant = "Bandana", femalePath = objPath(HAIRD .. "Wig/", "SK_Hair_Wig_01_SuspendBandana_Female"), malePath = objPath(HAIRM .. "Wig/", "SK_Hair_Wig_01_SuspendBandana_Male") },
  { name = "Wig 2", variant = "Default", femalePath = objPath(HAIRD .. "Wig/", "SK_Hair_Wig_02_Default_Female"), malePath = objPath(HAIRM .. "Wig/", "SK_Hair_Wig_02_Default_Male") },
  { name = "Wig 2", variant = "Hat", femalePath = objPath(HAIRD .. "Wig/", "SK_Hair_Wig_02_SuspendedHat_Female"), malePath = objPath(HAIRM .. "Wig/", "SK_Hair_Wig_02_SuspendedHat_Male") },
  { name = "Wig 2", variant = "Headband", femalePath = objPath(HAIRD .. "Wig/", "SK_Hair_Wig_02_SuspendedHeadband_Female"), malePath = objPath(HAIRM .. "Wig/", "SK_Hair_Wig_02_SuspendedHeadband_Male") },
  { name = "Wig 2", variant = "Bandana", femalePath = objPath(HAIRD .. "Wig/", "SK_Hair_Wig_02_SuspendedBandana_Female"), malePath = objPath(HAIRM .. "Wig/", "SK_Hair_Wig_02_SuspendedBandana_Male") },
}
-- Config.CUSTOM_CLOTHES -- "Custom > Clothes" GUI branch (2026-08-28). Swept `Character/
-- Skeletal_Meshes/Armor/ArmorRegular/` in pakcontents.xlsx the same way Config.CUSTOM_HAIR swept
-- Hair/ -- 25 family folders, 401 real (SK_-prefixed, non-PHYS_, non-SM_Drop_) mesh files, parsed
-- into (family, slot, number, sex) and grouped. Genuinely messier than hair turned out to be:
-- - The "Belt" folder is actually FOUR separate accessory types (Belt/Frog/Sling/Strap) named
--   `SK_<Type>_<NN>_<Sex>` -- a completely different filename shape from every other family
--   (`SK_Armor_<Family>_[NN_]?[Sex_]?<Slot>[_<style>]`) -- split into their own pseudo-families
--   here rather than forced into one "Belt" bucket.
-- - Two casing-duplicate family pairs confirmed in the catalog (same content, different pak
--   chunks, same "WorkBenches"/"Workbenches" class of quirk documented in WINDROSE_MODDING_NOTES.md
--   §14): `BlackBeard_Musketeer`/`Blackbeard_Musketeer` and `BlackSmith`/`Blacksmith` -- the
--   capitalized duplicates are dropped here, only the lowercase-b versions are kept.
-- - Sex pairing is NOT always symmetric, confirmed real rather than assumed: Dogface has no Female
--   content at all (a male-only NPC type); Jeweler's Torso/Waist pieces have a genuine content
--   asymmetry (Female gets 3 torso shape sub-variants per outfit "set", Male gets 1); Flibustier
--   Set 1's Male torso and Female torso use DIFFERENT style tokens (plain vs "_Long") for what's
--   presumably the same conceptual look. Rather than guess which asymmetric entries "should" pair
--   with which, every (family, slot, number, style) combination that has BOTH a Female and Male
--   file with the EXACT SAME style token gets one femalePath/malePath row (sex auto-detected at
--   apply time, same as hair/skin); anything that only exists for one sex (or has no sex token at
--   all, e.g. Musketeer/Combatant/Dogface's own generally single-sex-styled pieces) becomes a
--   single `unisexPath` row instead, applied regardless of the target's detected sex -- this can
--   read as slightly wrong-cut on the "other" sex for a genuinely asymmetric piece, but that's an
--   honest reflection of what the asset catalog actually has, not a guessed workaround.
-- `name` is a best-effort readable label ("Set 2 Long 3" etc.) built mechanically from the
-- filename's own number+style tokens -- some of the more deeply-nested Jeweler names read a
-- little clunky as a direct result, not worth hand-polishing 242 entries individually before any
-- of them have been tried live.
-- Spawner.TestApplyClothingPiece finds the CURRENT component to replace by SLOT (parsing ITS
-- current mesh's own name the same way this table was built, looking for a recognized slot token
-- anywhere in the name) rather than a single fixed substring -- deliberately avoiding the exact
-- class of bug the Undercut hairstyle exposed (a component becoming permanently unmatchable once
-- one specific naming convention lands on it): as long as whatever's currently equipped contains
-- ANY of the recognized slot tokens somewhere in its name, re-matching keeps working regardless of
-- which specific family is currently applied.
-- Config.SENKAMATI_WITCH_REGULAR_CLOTHES_SCALE -- WALKED BACK (2026-08-28, same day it shipped).
-- Originally: live-tuned by RedFalcon via lbtestscale to fix regular clothes reading undersized on
-- the raw Senkamati Witch body (SK_Senkamati_Witch_01_Female) at scale 1.0, auto-applied by
-- Spawner.TestApplyClothingPiece. RedFalcon then reported "setting scale doesn't work, so I want
-- to look at a different direction" -- the auto-apply call was removed from
-- TestApplyClothingPiece; this constant is kept only as a documented, no-longer-called record
-- (same treatment this file gives other confirmed-inadequate levers) -- do not re-wire it without
-- a genuinely different approach than "just scale the component."
Config.SENKAMATI_WITCH_REGULAR_CLOTHES_SCALE = { X = 1.5, Y = 1.1, Z = 1.0 }

-- Config.CLOTHING_REMOVABLE_SLOTS -- the "Custom > Clothes > Remove" GUI branch (2026-08-28,
-- RedFalcon: "can we have a clothes section for 'remove' where it has each slot available as well
-- as a remove all... and it hides the item in that slot"). Same canonical slot vocabulary as
-- spawner.lua's own CLOTHING_SLOT_TOKENS list (kept in sync manually -- if a new slot token is
-- ever added there, add its canonical name here too). Spawner.TestRemoveClothingPiece hides
-- (SetVisibility(false)), not swaps to nil -- clearing a component's mesh entirely would make
-- clothingSlotOf unable to re-identify that slot afterward (it matches by the CURRENT mesh name),
-- breaking the ability to dress that slot again later.
Config.CLOTHING_REMOVABLE_SLOTS = {
  "Headgear", "Torso", "TorsoCloth", "Legs", "Hands", "Feet", "Head", "Neck",
  "Waist", "Cape", "Scarf", "Belt", "Frog", "Sling", "Strap",
}

-- Config.CLOTHES_REMOVE -- flat roster feeding "Custom > Clothes > Remove" (one entry per
-- Config.CLOTHING_REMOVABLE_SLOTS, plus one "All"), consumed by spawnmenu_manifest.lua's
-- custom_clothes_remove_path_and_label and SPAWN_MENU_HANDLERS.CLOTHES_REMOVE (main.lua), which
-- both just call Spawner.TestRemoveClothingPiece(row.slot).
Config.CLOTHES_REMOVE = {}
for _, slotName in ipairs(Config.CLOTHING_REMOVABLE_SLOTS) do
  table.insert(Config.CLOTHES_REMOVE, { slot = slotName })
end
table.insert(Config.CLOTHES_REMOVE, { slot = "All" })

-- Women's-clothing fit rules (2026-08-28) -- see Spawner.TestApplyClothingPiece's own comment for
-- the full mechanism. "Senkamati women just can't wear regular torso or legs. Others slots seem
-- ok. For the rest of the female actors, only the torso is of concern."

-- Config.CLOTHES_UNLOCK_ALL -- off-by-default escape hatch (lbunlockclothes). When true, bypasses
-- every rule below entirely -- RedFalcon's own framing: "these outfits and poses have not been
-- reviewed and many likely will not work or look improper."
Config.CLOTHES_UNLOCK_ALL = false

-- Body-group classification (by CLASS, RedFalcon's own call -- Gatherer and Herbalist share the
-- identical SK_Adventure_Female_01 body mesh, so mesh alone can't tell them apart). Native BotC
-- statue classes ALSO count as Group2, but only when the specific instance's rolled body is
-- Adventure or Albion -- checked separately in Spawner.getFemaleBodyGroup since one statue class
-- covers all 7 archetypes (item 57).
Config.CLOTHES_BODY_GROUP1_CLASSES = { "BP_NPC_Handyman_Gatherer_C", "BP_NPC_QuestStatic_Smugglers_MaritaSuares_C" }
Config.CLOTHES_BODY_GROUP2_CLASSES = { "BP_NPC_Handyman_Herbalist_C", "BP_NPC_QuestStatic_Letty_C" }

-- Per-body-group scale+offset, live-tuned by RedFalcon (2026-08-28) for the RESIZED family list
-- below -- a NEW, separate use of lbtestscale's mechanism from the walked-back Senkamati-Witch
-- auto-scale (that one is dead; this one is a fresh, confirmed-by-testing value for a different
-- body/family combination).
Config.CLOTHES_BODY_GROUP_SCALE = {
  Group1 = { scale = { X = 1.03, Y = 1.05, Z = 1.0 }, offset = { X = 0.0, Y = 1.5, Z = -1.0 } },
  Group2 = { scale = { X = 1.03, Y = 1.05, Z = 1.0 }, offset = { X = 0.0, Y = 2.5, Z = -1.0 } },
}

-- Families gated by the SAME compatible-bodies check as real Senkamati Torso/Legs pieces
-- (Config.SENKAMATI_TORSO_LEGS_COMPATIBLE_BODIES/CLASSES) -- RedFalcon: "only those allowed to
-- wear the senkamati clothes can wear this."
Config.CLOTHES_SENKAMATI_GATED_FAMILIES = { "Conquistador" }

-- Unisex-only families explicitly allowed on a woman's Torso with NO change at all (fits fine as
-- authored). CORRECTED (2026-08-28, same day): the original "allow sailors torsos" reading (add
-- Blackbeard_Sailor here) was wrong -- RedFalcon clarified "blackbeard sailor torsos should only
-- be allowed for women in unlocked mode, otherwise replace with underwear." Blackbeard_Sailor is
-- entirely unisex-cut (confirmed: every row in Config.CUSTOM_CLOTHES has femalePath=nil), so
-- simply NOT listing it here (and not in CLOTHES_RESIZED_FAMILIES_WOMEN either) already gives the
-- exact wanted behavior via Mechanism B's own default-deny path: Remove (-> underwear on women)
-- unless Config.CLOTHES_UNLOCK_ALL is on -- no special-case code needed, just the omission itself.
Config.CLOTHES_ALLOWED_ASIS_FAMILIES_WOMEN = {}

-- Unisex-only families that need the per-body-group resize above rather than being blocked
-- outright. `true` = every piece in the family; a table = only those specific piece names.
Config.CLOTHES_RESIZED_FAMILIES_WOMEN = {
  Musketeer = true,
  Flibustier = { "Set 1" },
  Dogface = true,
  DrGalen = true,
  Ksante = true,
  Blackbeard_Grenadier = true,
  Blackbeard_Musketeer = true,
  Combatant = true,
}

-- Config.CLOTHES_MALE_ONLY_LEGS_FAMILIES -- "Male Only Pants" (2026-08-28, same day, RedFalcon's
-- correction: the earlier lists above were Torso-only; this is the separate, explicit list for
-- LEGS). Unisex-cut families whose Legs piece is male-only unless unlocked -- same "block unless
-- unlocked, else apply raw" treatment as Mechanism B's resize-list families, but with NO scale
-- correction at all (none was given for Legs) -- unlocked just applies the piece as requested.
-- Deliberately an EXPLICIT list, not a default-deny-everything-unisex rule like Torso has -- any
-- OTHER unisex-only Legs family not listed here is untouched/normal.
Config.CLOTHES_MALE_ONLY_LEGS_FAMILIES = {
  "Musketeer", "Blackbeard_Sailor", "Dogface", "Blackbeard_WolfTamer",
  "DrGalen", "Ksante", "Blackbeard_Grenadier", "Blackbeard_Musketeer", "Combatant",
}

Config.CUSTOM_CLOTHES = {
  { family = "Brigant", slot = "Headgear", name = "Default", femalePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Hat"), malePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Male_Hat"), unisexPath = nil },
  { family = "Brigant", slot = "Hands", name = "Default", femalePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Hands"), malePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Male_Hands"), unisexPath = nil },
  { family = "Brigant", slot = "Feet", name = "Default Long", femalePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Feet_Long"), malePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Male_Feet_Long"), unisexPath = nil },
  { family = "Brigant", slot = "Torso", name = "Default", femalePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Torso"), malePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Male_Torso"), unisexPath = nil },
  { family = "Brigant", slot = "Waist", name = "Default", femalePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Waist"), malePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Male_Waist"), unisexPath = nil },
  { family = "Brigant", slot = "Feet", name = "Default", femalePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Feet"), malePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Male_Feet"), unisexPath = nil },
  { family = "Brigant", slot = "Legs", name = "Default", femalePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Legs"), malePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Male_Legs"), unisexPath = nil },
  { family = "Brigant", slot = "Hands", name = "Default Long", femalePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Hands_Long"), malePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Male_Hands_Long"), unisexPath = nil },
  { family = "Brigant", slot = "Legs", name = "Default Long", femalePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Legs_Long"), malePath = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Male_Legs_Long"), unisexPath = nil },
  { family = "Belt", slot = "Belt", name = "Set 2", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Belt_02_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Belt_02_Male"), unisexPath = nil },
  { family = "Frog", slot = "Frog", name = "Set 4", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Frog_04_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Frog_04_Male"), unisexPath = nil },
  { family = "Sling", slot = "Sling", name = "Set 1", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Sling_01_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Sling_01_Male"), unisexPath = nil },
  { family = "Sling", slot = "Sling", name = "Set 3", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Sling_03_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Sling_03_Male"), unisexPath = nil },
  { family = "Belt", slot = "Belt", name = "Set 3", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Belt_03_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Belt_03_Male"), unisexPath = nil },
  { family = "Sling", slot = "Sling", name = "Set 4", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Sling_04_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Sling_04_Male"), unisexPath = nil },
  { family = "Belt", slot = "Belt", name = "Set 4", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Belt_04_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Belt_04_Male"), unisexPath = nil },
  { family = "Belt", slot = "Belt", name = "Set 1", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Belt_01_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Belt_01_Male"), unisexPath = nil },
  { family = "Strap", slot = "Strap", name = "Set 4", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Strap_04_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Strap_04_Male"), unisexPath = nil },
  { family = "Frog", slot = "Frog", name = "Set 3", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Frog_03_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Frog_03_Male"), unisexPath = nil },
  { family = "Strap", slot = "Strap", name = "Set 1", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Strap_01_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Strap_01_Male"), unisexPath = nil },
  { family = "Strap", slot = "Strap", name = "Set 3", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Strap_03_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Strap_03_Male"), unisexPath = nil },
  { family = "Frog", slot = "Frog", name = "Set 1", femalePath = objPath(ARM .. "Belt/Meshes/", "SK_Frog_01_Female"), malePath = objPath(ARM .. "Belt/Meshes/", "SK_Frog_01_Male"), unisexPath = nil },
  { family = "Jeweler", slot = "Headgear", name = "Set 2 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Bandana_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Bandana_01"), unisexPath = nil },
  { family = "Jeweler", slot = "Cape", name = "Set 1 03", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Cape_03"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Cape_03"), unisexPath = nil },
  { family = "Jeweler", slot = "Hands", name = "Set 1", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Hands"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Hands"), unisexPath = nil },
  { family = "Jeweler", slot = "Feet", name = "Set 2 Long", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Feet_Long"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Feet_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Hands", name = "Set 2", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Hands"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Hands"), unisexPath = nil },
  { family = "Jeweler", slot = "Headgear", name = "Set 3", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Hat"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Hat"), unisexPath = nil },
  { family = "Jeweler", slot = "Hands", name = "Set 3", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Hands"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Hands"), unisexPath = nil },
  { family = "Jeweler", slot = "Headgear", name = "Set 1 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_BandanaHat_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_BandanaHat_01"), unisexPath = nil },
  { family = "Jeweler", slot = "Legs", name = "Set 2", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Legs"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Legs"), unisexPath = nil },
  { family = "Jeweler", slot = "Feet", name = "Set 1 Long", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Feet_Long"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Feet_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Feet", name = "Set 3 Long", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Feet_Long"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Feet_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Headgear", name = "Set 1 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_BandanaHat_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_BandanaHat_02"), unisexPath = nil },
  { family = "Jeweler", slot = "Legs", name = "Set 3", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Legs"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Legs"), unisexPath = nil },
  { family = "Jeweler", slot = "Headgear", name = "Set 2 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Bandana_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Bandana_02"), unisexPath = nil },
  { family = "Jeweler", slot = "Legs", name = "Set 1", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Legs"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Legs"), unisexPath = nil },
  { family = "Jeweler", slot = "Cape", name = "Set 2", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Cape"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Cape"), unisexPath = nil },
  { family = "Jeweler", slot = "Cape", name = "Set 1 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Cape_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Cape_02"), unisexPath = nil },
  { family = "Musketeer", slot = "Hands", name = "Default Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Musketeer/Meshes/", "SK_Armor_Musketeer02_Hands_Long") },
  { family = "Musketeer", slot = "Head", name = "Default", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Musketeer/Meshes/", "SK_Armor_Musketeer01_Head") },
  { family = "Musketeer", slot = "Legs", name = "Default", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Musketeer/Meshes/", "SK_Armor_Musketeer03_Legs") },
  { family = "Musketeer", slot = "Torso", name = "Default", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Musketeer/Meshes/", "SK_Armor_Musketeer02_Torso") },
  { family = "Musketeer", slot = "Torso", name = "Default Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Musketeer/Meshes/", "SK_Armor_Musketeer01_Torso_Long") },
  { family = "Musketeer", slot = "Feet", name = "Default Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Musketeer/Meshes/", "SK_Armor_Musketeer02_Feet_Long") },
  { family = "Bandit", slot = "Hands", name = "Default Long", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Hands_Long"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Hands_Long"), unisexPath = nil },
  { family = "Bandit", slot = "Torso", name = "Default Long", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Torso_Long"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Torso_Long"), unisexPath = nil },
  { family = "Bandit", slot = "Feet", name = "Default", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Feet"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Feet"), unisexPath = nil },
  { family = "Bandit", slot = "Headgear", name = "Default", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Hat"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Hat"), unisexPath = nil },
  { family = "Bandit", slot = "Torso", name = "Default", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Torso"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Torso"), unisexPath = nil },
  { family = "Bandit", slot = "Feet", name = "Default Long", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Feet_Long"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Feet_Long"), unisexPath = nil },
  { family = "Bandit", slot = "Hands", name = "Default", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Hands"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Hands"), unisexPath = nil },
  { family = "Bandit", slot = "Waist", name = "Default", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Waist"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Waist"), unisexPath = nil },
  { family = "Bandit", slot = "Legs", name = "Default Long", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Legs_Long"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Legs_Long"), unisexPath = nil },
  { family = "Bandit", slot = "Legs", name = "Default", femalePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Female_Legs"), malePath = objPath(ARM .. "Bandit/Meshes/", "SK_Armor_Bandit_Male_Legs"), unisexPath = nil },
  { family = "Flibustier", slot = "Headgear", name = "Set 1", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Bandana"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Male_Bandana"), unisexPath = nil },
  { family = "Flibustier", slot = "Hands", name = "Set 2 Long", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Female_Hands_Long"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Male_Hands_Long"), unisexPath = nil },
  { family = "Flibustier", slot = "Hands", name = "Set 2", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Female_Hands"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Male_Hands"), unisexPath = nil },
  { family = "Flibustier", slot = "Hands", name = "Set 1 Long", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Hands_Long"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Male_Hands_Long"), unisexPath = nil },
  { family = "Flibustier", slot = "Torso", name = "Set 2 Long", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Female_Torso_Long"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Male_Torso_Long"), unisexPath = nil },
  { family = "Flibustier", slot = "Feet", name = "Set 2 Long", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Female_Feet_Long"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Male_Feet_Long"), unisexPath = nil },
  { family = "Flibustier", slot = "Legs", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Female_Legs") },
  { family = "Flibustier", slot = "Headgear", name = "Set 3", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Female_BandanaHat"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Male_BandanaHat"), unisexPath = nil },
  { family = "Flibustier", slot = "Torso", name = "Set 4", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_04_Female_Torso"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_04_Male_Torso"), unisexPath = nil },
  { family = "Flibustier", slot = "Legs", name = "Set 1", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Legs"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Male_Legs"), unisexPath = nil },
  { family = "Flibustier", slot = "Hands", name = "Set 1", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Hands"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Male_Hands"), unisexPath = nil },
  { family = "Flibustier", slot = "Legs", name = "Default", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Female_Legs"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Male_Legs"), unisexPath = nil },
  { family = "Flibustier", slot = "Waist", name = "Set 1", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Waist"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Male_Waist"), unisexPath = nil },
  { family = "Flibustier", slot = "Torso", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Male_Torso") },
  { family = "Flibustier", slot = "Torso", name = "Default", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Female_Torso"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Male_Torso"), unisexPath = nil },
  { family = "Flibustier", slot = "Waist", name = "Default", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Female_Torso_Waist"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Male_Waist"), unisexPath = nil },
  { family = "Flibustier", slot = "Torso", name = "Set 2", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Female_Torso"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Male_Torso"), unisexPath = nil },
  { family = "Flibustier", slot = "Feet", name = "Set 1 Long", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Feet_Long"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Male_Feet_Long"), unisexPath = nil },
  { family = "Flibustier", slot = "Feet", name = "Default Long", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Female_Feet_Long"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Male_Feet_Long"), unisexPath = nil },
  { family = "Flibustier", slot = "Torso", name = "Set 3", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Female_Torso"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Male_Torso"), unisexPath = nil },
  { family = "Flibustier", slot = "Headgear", name = "Set 2", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Female_Headband"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Male_Headband"), unisexPath = nil },
  { family = "Flibustier", slot = "Hands", name = "Default", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Female_Hands"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Male_Hands"), unisexPath = nil },
  { family = "Flibustier", slot = "Torso", name = "Set 5", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_05_Female_Torso"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_05_Male_Torso"), unisexPath = nil },
  { family = "Flibustier", slot = "Legs", name = "Set 2", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Female_Legs"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Male_Legs"), unisexPath = nil },
  { family = "Flibustier", slot = "Hands", name = "Default Long", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Female_Hands_Long"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_Adventurer_Male_Hands_Long"), unisexPath = nil },
  { family = "Flibustier", slot = "Cape", name = "Set 1", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Cape"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Male_Cape"), unisexPath = nil },
  { family = "Flibustier", slot = "Torso", name = "Set 1 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Torso_Long") },
  { family = "Flibustier", slot = "Headgear", name = "Set 2", femalePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Female_BandanaHat"), malePath = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Male_BandanaHat"), unisexPath = nil },
  { family = "Blackbeard_Sailor", slot = "Hands", name = "Set 1 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_01_Hands_Long") },
  { family = "Blackbeard_Sailor", slot = "Legs", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_03_Legs") },
  { family = "Blackbeard_Sailor", slot = "Feet", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_01_Feet") },
  { family = "Blackbeard_Sailor", slot = "Waist", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_03_Waist") },
  { family = "Blackbeard_Sailor", slot = "Waist", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_02_Waist") },
  { family = "Blackbeard_Sailor", slot = "Hands", name = "Set 3 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_03_Hands_Long") },
  { family = "Blackbeard_Sailor", slot = "Legs", name = "Set 1 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_01_Legs_Long") },
  { family = "Blackbeard_Sailor", slot = "Scarf", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_02_Scarf") },
  { family = "Blackbeard_Sailor", slot = "Scarf", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_01_Scarf") },
  { family = "Blackbeard_Sailor", slot = "Scarf", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_03_Scarf") },
  { family = "Blackbeard_Sailor", slot = "Torso", name = "Set 3 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_03_Torso_Long") },
  { family = "Blackbeard_Sailor", slot = "Legs", name = "Set 2 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_02_Legs_Long") },
  { family = "Blackbeard_Sailor", slot = "Headgear", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_02_Headband") },
  { family = "Blackbeard_Sailor", slot = "Feet", name = "Set 3 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_03_Feet_Long") },
  { family = "Blackbeard_Sailor", slot = "Torso", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_02_Torso") },
  { family = "Blackbeard_Sailor", slot = "Headgear", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_01_Bandana") },
  { family = "Blackbeard_Sailor", slot = "Hands", name = "Set 2 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_02_Hands_Long") },
  { family = "Blackbeard_Sailor", slot = "Feet", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_02_Feet") },
  { family = "Blackbeard_Sailor", slot = "Torso", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_03_Torso") },
  { family = "Blackbeard_Sailor", slot = "Torso", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Sailor/Meshes/", "SK_Armor_Blackbeard_Sailor_01_Torso") },
  { family = "Dogface", slot = "Feet", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_02_Male_Feet") },
  { family = "Dogface", slot = "Torso", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_01_Male_Torso") },
  { family = "Dogface", slot = "Legs", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_01_Male_Legs") },
  { family = "Dogface", slot = "Legs", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_02_Male_Legs") },
  { family = "Dogface", slot = "Head", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_01_Male_Head") },
  { family = "Dogface", slot = "Torso", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_03_Male_Torso") },
  { family = "Dogface", slot = "Feet", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_01_Male_Feet") },
  { family = "Dogface", slot = "Legs", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_03_Male_Legs") },
  { family = "Dogface", slot = "Head", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_02_Male_Head") },
  { family = "Dogface", slot = "Torso", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_02_Male_Torso") },
  { family = "Dogface", slot = "Feet", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_03_Male_Feet") },
  { family = "Dogface", slot = "Head", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Dogface/Meshes/", "SK_Armor_Dogface_03_Male_Head") },
  { family = "Vanilla", slot = "Headgear", name = "Default", femalePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Female_BandanaHat"), malePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Male_BandanaHat"), unisexPath = nil },
  { family = "Vanilla", slot = "Feet", name = "Default Long", femalePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Female_Feet_Long"), malePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Male_Feet_Long"), unisexPath = nil },
  { family = "Vanilla", slot = "Torso", name = "Default", femalePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Female_Torso"), malePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Male_Torso"), unisexPath = nil },
  { family = "Vanilla", slot = "Waist", name = "Default", femalePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Female_Waist"), malePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Male_Waist"), unisexPath = nil },
  { family = "Vanilla", slot = "Hands", name = "Default Long", femalePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Female_Hands_Long"), malePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Male_Hands_Long"), unisexPath = nil },
  { family = "Vanilla", slot = "Legs", name = "Default", femalePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Female_Legs"), malePath = objPath(ARM .. "Vanilla/Meshes/", "SK_Armor_Vanilla_Male_Legs"), unisexPath = nil },
  { family = "Blackbeard_WolfTamer", slot = "Legs", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_WolfTamer/Meshes/", "SK_Armor_Blackbeard_WolfTamer_01_Legs") },
  { family = "DrGalen", slot = "Legs", name = "Default", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "DrGalen/Meshes/", "SK_Armor_DrGalen_Legs") },
  { family = "DrGalen", slot = "Cape", name = "Default", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "DrGalen/Meshes/", "SK_Armor_DrGalen_Cape") },
  { family = "DrGalen", slot = "Feet", name = "Default Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "DrGalen/Meshes/", "SK_Armor_DrGalen_Feet_Long") },
  { family = "DrGalen", slot = "Torso", name = "Default Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "DrGalen/Meshes/", "SK_Armor_DrGalen_Torso_Long") },
  { family = "Ksante", slot = "Cape", name = "Default 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Ksante/Meshes/", "SK_Armor_Ksante_Cape_01") },
  { family = "Ksante", slot = "Legs", name = "Default", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Ksante/Meshes/", "SK_Armor_Ksante_Legs") },
  { family = "Ksante", slot = "Torso", name = "Default Torn", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Ksante/Meshes/", "SK_Armor_Ksante_Torso_Torn") },
  { family = "Ksante", slot = "Hands", name = "Default", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Ksante/Meshes/", "SK_Armor_Ksante_Hands") },
  { family = "Ksante", slot = "Feet", name = "Default Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Ksante/Meshes/", "SK_Armor_Ksante_Feet_Long") },
  { family = "Blackbeard_Grenadier", slot = "Torso", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_01_Torso") },
  { family = "Blackbeard_Grenadier", slot = "Feet", name = "Set 3 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_03_Feet_Long") },
  { family = "Blackbeard_Grenadier", slot = "Hands", name = "Set 2 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_02_Hands_Long") },
  { family = "Blackbeard_Grenadier", slot = "Headgear", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_01_Bandana") },
  { family = "Blackbeard_Grenadier", slot = "Torso", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_02_Torso") },
  { family = "Blackbeard_Grenadier", slot = "Headgear", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_02_Bandana") },
  { family = "Blackbeard_Grenadier", slot = "Torso", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_03_Torso") },
  { family = "Blackbeard_Grenadier", slot = "Legs", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_03_Legs") },
  { family = "Blackbeard_Grenadier", slot = "Hands", name = "Set 3 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_03_Hands_Long") },
  { family = "Blackbeard_Grenadier", slot = "Legs", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_02_Legs") },
  { family = "Blackbeard_Grenadier", slot = "Feet", name = "Set 1 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_01_Feet_Long") },
  { family = "Blackbeard_Grenadier", slot = "Headgear", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_03_Bandana") },
  { family = "Blackbeard_Grenadier", slot = "Feet", name = "Set 2 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_02_Feet_Long") },
  { family = "Blackbeard_Grenadier", slot = "Hands", name = "Set 1 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_01_Hands_Long") },
  { family = "Blackbeard_Grenadier", slot = "Legs", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Grenadier/Meshes/", "SK_Armor_Blackbeard_Grenadier_01_Legs") },
  { family = "Blackbeard_Musketeer", slot = "Legs", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_03_Legs") },
  { family = "Blackbeard_Musketeer", slot = "Feet", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_01_Feet") },
  { family = "Blackbeard_Musketeer", slot = "Hands", name = "Set 1 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_01_Hands_Long") },
  { family = "Blackbeard_Musketeer", slot = "Feet", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_03_Feet") },
  { family = "Blackbeard_Musketeer", slot = "Feet", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_02_Feet") },
  { family = "Blackbeard_Musketeer", slot = "Torso", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_03_Torso") },
  { family = "Blackbeard_Musketeer", slot = "Hands", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_03_Hands") },
  { family = "Blackbeard_Musketeer", slot = "Legs", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_01_Legs") },
  { family = "Blackbeard_Musketeer", slot = "Headgear", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_03_Hat") },
  { family = "Blackbeard_Musketeer", slot = "Hands", name = "Set 2 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_02_Hands_Long") },
  { family = "Blackbeard_Musketeer", slot = "Headgear", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_02_Hat") },
  { family = "Blackbeard_Musketeer", slot = "Torso", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_01_Torso") },
  { family = "Blackbeard_Musketeer", slot = "Torso", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_02_Torso") },
  { family = "Blackbeard_Musketeer", slot = "Legs", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_02_Legs") },
  { family = "Blackbeard_Musketeer", slot = "Headgear", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_01_Hat") },
  { family = "Blackbeard_Musketeer", slot = "Feet", name = "Set 2 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_02_Feet_Long") },
  { family = "Blackbeard_Musketeer", slot = "Feet", name = "Set 3 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Blackbeard_Musketeer/Meshes/", "SK_Armor_Blackbeard_Musketeer_03_Feet_Long") },
  { family = "Conquistador", slot = "Cape", name = "Set 1", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Female_Cape"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Male_Cape"), unisexPath = nil },
  { family = "Conquistador", slot = "Legs", name = "Set 2", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Female_Legs"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Male_Legs"), unisexPath = nil },
  { family = "Conquistador", slot = "Torso", name = "Set 1", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Female_Torso"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Male_Torso"), unisexPath = nil },
  { family = "Conquistador", slot = "Cape", name = "Set 3", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_03_Female_Cape"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_03_Male_Cape"), unisexPath = nil },
  { family = "Conquistador", slot = "Hands", name = "Set 1 Long", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Female_Hands_Long"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Male_Hands_Long"), unisexPath = nil },
  { family = "Conquistador", slot = "Headgear", name = "Set 3", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_03_Female_Helmet"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_03_Male_Helmet"), unisexPath = nil },
  { family = "Conquistador", slot = "Feet", name = "Set 2 Long", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Female_Feet_Long"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Male_Feet_Long"), unisexPath = nil },
  { family = "Conquistador", slot = "Torso", name = "Set 3", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_03_Female_Torso"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_03_Male_Torso"), unisexPath = nil },
  { family = "Conquistador", slot = "Legs", name = "Set 1", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Female_Legs"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Male_Legs"), unisexPath = nil },
  { family = "Conquistador", slot = "Hands", name = "Set 2", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Female_Hands"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Male_Hands"), unisexPath = nil },
  { family = "Conquistador", slot = "Waist", name = "Default", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_Female_Waist"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_Male_Waist"), unisexPath = nil },
  { family = "Conquistador", slot = "Feet", name = "Set 1 Long", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Female_Feet_Long"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_01_Male_Feet_Long"), unisexPath = nil },
  { family = "Conquistador", slot = "Headgear", name = "Set 4", femalePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_04_Female_Helmet"), malePath = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_04_Male_Helmet"), unisexPath = nil },
  { family = "Starter", slot = "Torso", name = "Default", femalePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Female_Torso"), malePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Male_Torso"), unisexPath = nil },
  { family = "Starter", slot = "Headgear", name = "Default", femalePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Female_Headband"), malePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Male_Headband"), unisexPath = nil },
  { family = "Starter", slot = "Legs", name = "Default", femalePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Female_Legs"), malePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Male_Legs"), unisexPath = nil },
  { family = "Starter", slot = "Feet", name = "Default Long", femalePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Female_Feet_Long"), malePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Male_Feet_Long"), unisexPath = nil },
  { family = "Starter", slot = "Hands", name = "Default Long", femalePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Female_Hands_Long"), malePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Male_Hands_Long"), unisexPath = nil },
  { family = "Starter", slot = "Waist", name = "Default", femalePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Female_Waist"), malePath = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Male_Waist"), unisexPath = nil },
  { family = "Mercenary", slot = "Headgear", name = "Default", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Hat"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Hat"), unisexPath = nil },
  { family = "Mercenary", slot = "Waist", name = "Default", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Waist"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Waist"), unisexPath = nil },
  { family = "Mercenary", slot = "Legs", name = "Default Long", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Legs_Long"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Legs_Long"), unisexPath = nil },
  { family = "Mercenary", slot = "Headgear", name = "Default", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Headband"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Headband"), unisexPath = nil },
  { family = "Mercenary", slot = "Legs", name = "Default", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Legs"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Legs"), unisexPath = nil },
  { family = "Mercenary", slot = "Feet", name = "Default Long", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Feet_Long"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Feet_Long"), unisexPath = nil },
  { family = "Mercenary", slot = "Hands", name = "Default", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Hands"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Hands"), unisexPath = nil },
  { family = "Mercenary", slot = "Torso", name = "Default", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Torso"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Torso"), unisexPath = nil },
  { family = "Mercenary", slot = "Headgear", name = "Default", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Bandana"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Bandana"), unisexPath = nil },
  { family = "Mercenary", slot = "Torso", name = "Default Long", femalePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Torso_Long"), malePath = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Male_Torso_Long"), unisexPath = nil },
  { family = "Restored", slot = "Feet", name = "Default Long", femalePath = objPath(ARM .. "Restored/Meshes/", "SK_Armor_Restored_Female_Feet_Long"), malePath = objPath(ARM .. "Restored/Meshes/", "SK_Armor_Restored_Male_Feet_Long"), unisexPath = nil },
  { family = "Restored", slot = "Legs", name = "Default", femalePath = objPath(ARM .. "Restored/Meshes/", "SK_Armor_Restored_Female_Legs"), malePath = objPath(ARM .. "Restored/Meshes/", "SK_Armor_Restored_Male_Legs"), unisexPath = nil },
  { family = "Restored", slot = "Torso", name = "Default", femalePath = objPath(ARM .. "Restored/Meshes/", "SK_Armor_Restored_Female_Torso"), malePath = objPath(ARM .. "Restored/Meshes/", "SK_Armor_Restored_Male_Torso"), unisexPath = nil },
  { family = "Restored", slot = "Waist", name = "Default", femalePath = objPath(ARM .. "Restored/Meshes/", "SK_Armor_Restored_Female_Waist"), malePath = objPath(ARM .. "Restored/Meshes/", "SK_Armor_Restored_Male_Waist"), unisexPath = nil },
  { family = "Combatant", slot = "Feet", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_03_Feet") },
  { family = "Combatant", slot = "Legs", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_02_Legs") },
  { family = "Combatant", slot = "Head", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_02_Head") },
  { family = "Combatant", slot = "Hands", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_03_Hands") },
  { family = "Combatant", slot = "Torso", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_03_Torso") },
  { family = "Combatant", slot = "Legs", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_01_Legs") },
  { family = "Combatant", slot = "Feet", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_01_Feet") },
  { family = "Combatant", slot = "Hands", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_02_Hands") },
  { family = "Combatant", slot = "Head", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_03_Head") },
  { family = "Combatant", slot = "Legs", name = "Set 3", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_03_Legs") },
  { family = "Combatant", slot = "Hands", name = "Set 1 Long", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_01_Hands_Long") },
  { family = "Combatant", slot = "Torso", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_01_Torso") },
  { family = "Combatant", slot = "Feet", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_02_Feet") },
  { family = "Combatant", slot = "Torso", name = "Set 2", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Combatant/Meshes/", "SK_Armor_Combatant_02_Torso") },
  { family = "Underwear", slot = "Torso", name = "Set 1", femalePath = nil, malePath = nil, unisexPath = objPath(ARM .. "Underwear/Meshes/", "SK_Armor_Underwear_01_Female_Torso") },
  { family = "Underwear", slot = "Legs", name = "Set 2", femalePath = objPath(ARM .. "Underwear/Meshes/", "SK_Armor_Underwear_02_Female_Legs"), malePath = objPath(ARM .. "Underwear/Meshes/", "SK_Armor_Underwear_02_Male_Legs"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 2 Long 03", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Torso_Long_03"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Torso_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 3 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Torso_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Torso"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 2 Long 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Torso_Long_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Torso_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 3 Long 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Torso_Long_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Torso_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Waist", name = "Set 2 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Waist_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Waist"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 2 03", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Torso_03"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Torso"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 1 Long 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Torso_Long_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Torso_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 2 Long 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Torso_Long_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Torso_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 2 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Torso_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Torso"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 3 03", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Torso_03"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Torso"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 2 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Female_Torso_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_02_Male_Torso"), unisexPath = nil },
  { family = "Jeweler", slot = "Waist", name = "Set 1 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Waist_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Waist"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 3 Long 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Torso_Long_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Torso_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Waist", name = "Set 1 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Waist_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Waist"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 3 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Torso_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Torso"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 1 02", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Torso_02"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Torso"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 1 Long 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Torso_Long_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Torso_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 3 Long 03", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Female_Torso_Long_03"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_03_Male_Torso_Long"), unisexPath = nil },
  { family = "Jeweler", slot = "Torso", name = "Set 1 01", femalePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Female_Torso_01"), malePath = objPath(ARM .. "Jeweler/Meshes/", "SK_Armor_Jeweler_01_Male_Torso"), unisexPath = nil },
  { family = "Senkamati Hunter", slot = "Feet", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_01_Feet_Long") },
  { family = "Senkamati Hunter", slot = "Feet", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_02_Feet_Long") },
  { family = "Senkamati Hunter", slot = "Feet", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_03_Feet_Long") },
  { family = "Senkamati Hunter", slot = "Hands", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_01_Hands_Long") },
  { family = "Senkamati Hunter", slot = "Hands", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_02_Hands_Long") },
  { family = "Senkamati Hunter", slot = "Hands", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_03_Hands_Long") },
  { family = "Senkamati Hunter", slot = "Head", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_01_Head") },
  { family = "Senkamati Hunter", slot = "Head", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_02_Head") },
  { family = "Senkamati Hunter", slot = "Head", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_03_Head") },
  { family = "Senkamati Hunter", slot = "Legs", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_01_Legs") },
  { family = "Senkamati Hunter", slot = "Legs", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_02_Legs") },
  { family = "Senkamati Hunter", slot = "Legs", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_03_Legs") },
  { family = "Senkamati Hunter", slot = "Legs", name = "Wood 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Wood_01_Legs") },
  { family = "Senkamati Hunter", slot = "Legs", name = "Wood 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Wood_02_Legs") },
  { family = "Senkamati Hunter", slot = "Legs", name = "Wood 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Wood_03_Legs") },
  { family = "Senkamati Hunter", slot = "Torso", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_01_Torso") },
  { family = "Senkamati Hunter", slot = "Torso", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_02_Torso") },
  { family = "Senkamati Hunter", slot = "Torso", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Hunter/Meshes/", "SK_ArmorCreature_Senkamati_Hunter_Feather_03_Torso") },
  { family = "Senkamati Thrall", slot = "Feet", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_01_Feet_Long") },
  { family = "Senkamati Thrall", slot = "Feet", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_02_Feet") },
  { family = "Senkamati Thrall", slot = "Feet", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_03_Feet_Long") },
  { family = "Senkamati Thrall", slot = "Feet", name = "Wood 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Wood_01_Feet_Long") },
  { family = "Senkamati Thrall", slot = "Feet", name = "Wood 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Wood_02_Feet_Long") },
  { family = "Senkamati Thrall", slot = "Feet", name = "Wood 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Wood_03_Feet_Long") },
  { family = "Senkamati Thrall", slot = "Hands", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_01_Hands_Long") },
  { family = "Senkamati Thrall", slot = "Hands", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_02_Hands_Long") },
  { family = "Senkamati Thrall", slot = "Hands", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_03_Hands_Long") },
  { family = "Senkamati Thrall", slot = "Hands", name = "Wood 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Wood_01_Hands_Long") },
  { family = "Senkamati Thrall", slot = "Hands", name = "Wood 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Wood_02_Hands_Long") },
  { family = "Senkamati Thrall", slot = "Hands", name = "Wood 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Wood_03_Hands_Long") },
  { family = "Senkamati Thrall", slot = "Head", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_01_Head") },
  { family = "Senkamati Thrall", slot = "Head", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_02_Head") },
  { family = "Senkamati Thrall", slot = "Head", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_03_Head") },
  { family = "Senkamati Thrall", slot = "Head", name = "Feather 04", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_04_Head") },
  { family = "Senkamati Thrall", slot = "Legs", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_01_Legs") },
  { family = "Senkamati Thrall", slot = "Legs", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_02_Legs") },
  { family = "Senkamati Thrall", slot = "Legs", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_03_Legs") },
  { family = "Senkamati Thrall", slot = "Legs", name = "Wood 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Wood_01_Legs") },
  { family = "Senkamati Thrall", slot = "Legs", name = "Wood 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Wood_02_Legs") },
  { family = "Senkamati Thrall", slot = "Legs", name = "Wood 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Wood_03_Legs") },
  { family = "Senkamati Thrall", slot = "Torso", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_01_Torso") },
  { family = "Senkamati Thrall", slot = "Torso", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_02_Torso") },
  { family = "Senkamati Thrall", slot = "Torso", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Thrall/Meshes/", "SK_ArmorCreature_Senkamati_Thrall_Feather_03_Torso") },
  { family = "Senkamati Warrior", slot = "Feet", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_01_Feet_Long") },
  { family = "Senkamati Warrior", slot = "Feet", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_02_Feet_Long") },
  { family = "Senkamati Warrior", slot = "Feet", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_03_Feet_Long") },
  { family = "Senkamati Warrior", slot = "Hands", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_01_Hands_Long") },
  { family = "Senkamati Warrior", slot = "Hands", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_02_Hands_Long") },
  { family = "Senkamati Warrior", slot = "Hands", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_03_Hands_Long") },
  { family = "Senkamati Warrior", slot = "Head", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_01_Head") },
  { family = "Senkamati Warrior", slot = "Head", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_02_Head") },
  { family = "Senkamati Warrior", slot = "Head", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_03_Head") },
  { family = "Senkamati Warrior", slot = "Legs", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_01_Legs") },
  { family = "Senkamati Warrior", slot = "Legs", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_02_Legs") },
  { family = "Senkamati Warrior", slot = "Legs", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_03_Legs") },
  { family = "Senkamati Warrior", slot = "Torso", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_01_Torso") },
  { family = "Senkamati Warrior", slot = "Torso", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_02_Torso") },
  { family = "Senkamati Warrior", slot = "Torso", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Warrior/Meshes/", "SK_ArmorCreature_Senkamati_Warrior_Feather_03_Torso") },
  { family = "Senkamati Witch", slot = "Feet", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_01_Feet") },
  { family = "Senkamati Witch", slot = "Feet", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_02_Feet") },
  { family = "Senkamati Witch", slot = "Hands", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_01_Hands") },
  { family = "Senkamati Witch", slot = "Hands", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_02_Hands") },
  { family = "Senkamati Witch", slot = "Head", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_01_Head") },
  { family = "Senkamati Witch", slot = "Head", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_02_Head") },
  { family = "Senkamati Witch", slot = "Head", name = "Feather 03", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_03_Head") },
  { family = "Senkamati Witch", slot = "Legs", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_01_Legs") },
  { family = "Senkamati Witch", slot = "Legs", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_02_Legs") },
  { family = "Senkamati Witch", slot = "Neck", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_01_Neck") },
  { family = "Senkamati Witch", slot = "Neck", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_02_Neck") },
  { family = "Senkamati Witch", slot = "Torso", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_01_Torso") },
  { family = "Senkamati Witch", slot = "Torso", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_02_Torso") },
  { family = "Senkamati Witch", slot = "TorsoCloth", name = "Feather 01", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_01_TorsoCloth") },
  { family = "Senkamati Witch", slot = "TorsoCloth", name = "Feather 02", femalePath = nil, malePath = nil, unisexPath = objPath(ARMC .. "Senkamati_Witch/Mesh/", "SK_ArmorCreature_Senkamati_Witch_Feather_02_TorsoCloth") },
}

-- Config.CUSTOM_FACIAL -- "Custom > Face" (2026-08-28). Same shape as Config.
-- CUSTOM_CLOTHES (family/slot/name/femalePath/malePath/unisexPath), swept from
-- Character/Skeletal_Meshes/Facial/ the same way. "Eyebrows" is a genuine sex-paired family
-- (Female has 5 numbered variants, Male has 4 -- paired by matching number, Female 05 left as
-- female-only since no Male 05 exists). Every OTHER family (Bristle/HalfPonytail/Hungover/Jag/
-- Nordic/RoyalMarine/Shag/Sparse/BlackSmith) is a Beard-folder style with up to three
-- INDEPENDENT slots -- Beard/Mustache/Whiskers -- confirmed genuinely male-only (no female
-- facial-hair assets exist anywhere in the catalog), so femalePath is nil for all of them.
-- BlackSmith/Blacksmith casing-duplicate folders (same pattern documented in
-- WINDROSE_MODDING_NOTES.md #14) collapsed to one. Not every style has all three slots (e.g.
-- Bristle only has a Beard piece) -- reflects the real catalog, not an assumed symmetry.
-- Spawner.TestApplyFacialPiece finds the current component to replace by SLOT the same way
-- TestApplyClothingPiece does for clothing (facialSlotOf on each component's current mesh
-- name), a separate token list from clothing's own since these live in a different folder.
Config.CUSTOM_FACIAL = {
  { family = "Eyebrows", slot = "Eyebrows", name = "01", femalePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Female/Eyebrows/Meshes/", "SK_Eyebrows_Female_01"), malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Eyebrows/Meshes/", "SK_Eyebrows_Male_01"), unisexPath = nil },
  { family = "Eyebrows", slot = "Eyebrows", name = "02", femalePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Female/Eyebrows/Meshes/", "SK_Eyebrows_Female_02"), malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Eyebrows/Meshes/", "SK_Eyebrows_Male_02"), unisexPath = nil },
  { family = "Eyebrows", slot = "Eyebrows", name = "03", femalePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Female/Eyebrows/Meshes/", "SK_Eyebrows_Female_03"), malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Eyebrows/Meshes/", "SK_Eyebrows_Male_03"), unisexPath = nil },
  { family = "Eyebrows", slot = "Eyebrows", name = "04", femalePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Female/Eyebrows/Meshes/", "SK_Eyebrows_Female_04"), malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Eyebrows/Meshes/", "SK_Eyebrows_Male_04"), unisexPath = nil },
  { family = "Eyebrows", slot = "Eyebrows", name = "05", femalePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Female/Eyebrows/Meshes/", "SK_Eyebrows_Female_05"), malePath = nil, unisexPath = nil },
  { family = "BlackSmith", slot = "Beard", name = "BlackSmith", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/BlackSmith/", "SK_Beard_BlackSmith"), unisexPath = nil },
  { family = "BlackSmith", slot = "Eyebrows", name = "BlackSmith", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/BlackSmith/", "SK_Eyebrow_BlackSmith"), unisexPath = nil },
  { family = "BlackSmith", slot = "Mustache", name = "BlackSmith", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/BlackSmith/", "SK_Mustache_BlackSmith"), unisexPath = nil },
  { family = "Bristle", slot = "Beard", name = "Bristle 01", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Bristle/", "SK_Beard_Bristle_01"), unisexPath = nil },
  { family = "HalfPonytail", slot = "Beard", name = "HalfPonytail", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/HalfPonytail/", "SK_Beard_HalfPonytail_Adventurer_Male"), unisexPath = nil },
  { family = "HalfPonytail", slot = "Mustache", name = "HalfPonytail", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/HalfPonytail/", "SK_Mustache_HalfPonytail_Adventurer_Male"), unisexPath = nil },
  { family = "HalfPonytail", slot = "Whiskers", name = "HalfPonytail", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/HalfPonytail/", "SK_Whiskers_HalfPonytail_Adventurer_Male"), unisexPath = nil },
  { family = "Hungover", slot = "Beard", name = "Hungover", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Hungover/", "SK_Beard_Hungover"), unisexPath = nil },
  { family = "Hungover", slot = "Mustache", name = "Hungover", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Hungover/", "SK_Mustaches_Hungover"), unisexPath = nil },
  { family = "Hungover", slot = "Whiskers", name = "Hungover", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Hungover/", "SK_Whiskers_Hungover"), unisexPath = nil },
  { family = "Jag", slot = "Beard", name = "Jag 01", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Jag/", "SK_Beard_Jag_01"), unisexPath = nil },
  { family = "Jag", slot = "Beard", name = "Jag 02", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Jag/", "SK_Beard_Jag_02"), unisexPath = nil },
  { family = "Jag", slot = "Mustache", name = "Jag 01", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Jag/", "SK_Mustache_Jag_01"), unisexPath = nil },
  { family = "Jag", slot = "Mustache", name = "Jag 02", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Jag/", "SK_Mustache_Jag_02"), unisexPath = nil },
  { family = "Jag", slot = "Whiskers", name = "Jag 01", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Jag/", "SK_Whiskers_Jag_01"), unisexPath = nil },
  { family = "Jag", slot = "Whiskers", name = "Jag 02", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Jag/", "SK_Whiskers_Jag_02"), unisexPath = nil },
  { family = "Nordic", slot = "Beard", name = "Nordic", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Nordic/", "SK_Beard_Nordic_Adventurer_Male"), unisexPath = nil },
  { family = "Nordic", slot = "Mustache", name = "Nordic", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Nordic/", "SK_Mustache_Nordic_Adventurer_Male"), unisexPath = nil },
  { family = "Nordic", slot = "Whiskers", name = "Nordic", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Nordic/", "SK_Whiskers_Nordic_Adventurer_Male"), unisexPath = nil },
  { family = "RoyalMarine", slot = "Beard", name = "RoyalMarine", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/RoyalMarine/", "SK_Beard_RoyalMarine_Adventurer_Male"), unisexPath = nil },
  { family = "RoyalMarine", slot = "Mustache", name = "RoyalMarine", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/RoyalMarine/", "SK_Mustaches_RoyalMarine_Adventurer_Male"), unisexPath = nil },
  { family = "RoyalMarine", slot = "Whiskers", name = "RoyalMarine", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/RoyalMarine/", "SK_Whiskers_RoyalMarine_Adventurer_Male"), unisexPath = nil },
  { family = "Shag", slot = "Beard", name = "Shag 02", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Beard_Shag_02"), unisexPath = nil },
  { family = "Shag", slot = "Beard", name = "Shag 03", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Beard_Shag_03"), unisexPath = nil },
  { family = "Shag", slot = "Beard", name = "Shag 04", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Beard_Shag_04"), unisexPath = nil },
  { family = "Shag", slot = "Beard", name = "Shag 05", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Beard_Shag_05"), unisexPath = nil },
  { family = "Shag", slot = "Mustache", name = "Shag 02", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Mustache_Shag_02"), unisexPath = nil },
  { family = "Shag", slot = "Mustache", name = "Shag 03", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Mustache_Shag_03"), unisexPath = nil },
  { family = "Shag", slot = "Mustache", name = "Shag 04", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Mustache_Shag_04"), unisexPath = nil },
  { family = "Shag", slot = "Mustache", name = "Shag 05", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Mustache_Shag_05"), unisexPath = nil },
  { family = "Shag", slot = "Whiskers", name = "Shag 02", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Whiskers_Shag_02"), unisexPath = nil },
  { family = "Shag", slot = "Whiskers", name = "Shag 03", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Whiskers_Shag_03"), unisexPath = nil },
  { family = "Shag", slot = "Whiskers", name = "Shag 04", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Whiskers_Shag_04"), unisexPath = nil },
  { family = "Shag", slot = "Whiskers", name = "Shag 05", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Shag/", "SK_Whiskers_Shag_05"), unisexPath = nil },
  { family = "Sparse", slot = "Beard", name = "Sparse 01", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Sparse/", "SK_Beard_Sparse_01"), unisexPath = nil },
  { family = "Sparse", slot = "Beard", name = "Sparse 02", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Sparse/", "SK_Beard_Sparse_02"), unisexPath = nil },
  { family = "Sparse", slot = "Beard", name = "Sparse 03", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Sparse/", "SK_Beard_Sparse_03"), unisexPath = nil },
  { family = "Sparse", slot = "Mustache", name = "Sparse 01", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Sparse/", "SK_Mustache_Sparse_01"), unisexPath = nil },
  { family = "Sparse", slot = "Mustache", name = "Sparse 02", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Sparse/", "SK_Mustache_Sparse_02"), unisexPath = nil },
  { family = "Sparse", slot = "Mustache", name = "Sparse 03", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Sparse/", "SK_Mustache_Sparse_03"), unisexPath = nil },
  { family = "Sparse", slot = "Whiskers", name = "Sparse 01", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Sparse/", "SK_Whiskers_Sparse_01"), unisexPath = nil },
  { family = "Sparse", slot = "Whiskers", name = "Sparse 02", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Sparse/", "SK_Whiskers_Sparse_02"), unisexPath = nil },
  { family = "Sparse", slot = "Whiskers", name = "Sparse 03", femalePath = nil, malePath = objPath("/Game/Character/Skeletal_Meshes/Facial/Male/Beard/Sparse/", "SK_Whiskers_Sparse_03"), unisexPath = nil },
}

-- Config.CUSTOM_COMPOSITE_PIECES (2026-08-29) -- catalog of the game's own native per-piece
-- 'CompositeMeshData' DataAssets (R5CompositeMeshParams), swept from pakcontents.xlsx the same
-- way Config.CUSTOM_CLOTHES was built from raw meshes -- but these are a DIFFERENT, higher-level
-- asset than a plain SkeletalMesh: each one is the game's own wrapper around one piece (mesh +
-- any socket-attached extras + baked color indices), the exact building block a real
-- R5CompositeMeshGroup references (see Marita's own real Equipment group, item 111's
-- investigation). 354 entries across 33 families -- a partially different catalog from
-- Config.CUSTOM_CLOTHES' own 25 families (some overlap -- Dogface/Musketeer/Jeweler/Flibustier --
-- some new: BlackBeard_Grenadier/Huntsman/Sergeant, Combatant, Crafter, Default, Drowned,
-- Drowned_Armored, the Senkamati_*_Feather/Wood families, the NPC_*/Set_* families, and two
-- head-only oddities T01_Head_SoloPlayer/T03_Head_MaskSenkamati). `name` is just the piece's own
-- numbered suffix ("01"/"02"/...) or "Default" for an un-numbered/None variant -- not hand-
-- polished, expect some rough names. Built as reference data for constructing a custom
-- R5CompositeMeshGroup (mixing pieces from different families into one bundle) -- not yet wired
-- into anything; see Spawner.TestBuildCustomOutfit's own comment for the actual construction
-- experiment this feeds.
Config.CUSTOM_COMPOSITE_PIECES = {
  { family = "BlackBeard_Grenadier", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Grenadier_Feet_01_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Grenadier_Feet_02_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Grenadier_Feet_03_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Grenadier_Hands_01_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Grenadier_Hands_02_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Grenadier_Hands_03_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Grenadier_Head_01_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Grenadier_Head_02_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Grenadier_Head_03_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Grenadier_Legs_01_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Grenadier_Legs_02_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Grenadier_Legs_03_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Grenadier_Torso_01_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Grenadier_Torso_02_CompositeMeshData" },
  { family = "BlackBeard_Grenadier", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Grenadier/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Grenadier_Torso_03_CompositeMeshData" },
  { family = "BlackBeard_Huntsman", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Huntsman/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Huntsman_Legs_01_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Feet", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Musketeer_Feet_01_Long_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Feet", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Musketeer_Feet_02_Long_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Feet", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Musketeer_Feet_03_Long_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Musketeer_Feet_01_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Musketeer_Feet_02_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Musketeer_Feet_03_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Musketeer_Hands_01_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Musketeer_Hands_02_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Musketeer_Hands_03_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Musketeer_Head_01_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Musketeer_Head_02_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Musketeer_Head_03_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Musketeer_Legs_01_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Musketeer_Legs_02_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Musketeer_Legs_03_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Musketeer_Torso_01_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Musketeer_Torso_02_CompositeMeshData" },
  { family = "BlackBeard_Musketeer", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Musketeer/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Musketeer_Torso_03_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Feet", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Sailor_Feet_None_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Sailor_Feet_01_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Sailor_Feet_02_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Sailor_Feet_03_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Hands", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Sailor_Hands_None_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Sailor_Hands_01_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Sailor_Hands_02_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Sailor_Hands_03_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Head", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Sailor_Head_None_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Sailor_Head_01_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Sailor_Head_02_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Sailor_Legs_01_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Sailor_Legs_02_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Sailor_Legs_03_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Mask", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Mask/DA_Armor_Regular_BlackBeard_Sailor_Mask_01_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Mask", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Mask/DA_Armor_Regular_BlackBeard_Sailor_Mask_02_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Mask", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Mask/DA_Armor_Regular_BlackBeard_Sailor_Mask_03_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Sailor_Torso_01_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Sailor_Torso_02_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Sailor_Torso_03_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Waist", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Waist/DA_Armor_Regular_BlackBeard_Sailor_Waist_02_CompositeMeshData" },
  { family = "BlackBeard_Sailor", slot = "Waist", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sailor/CompositeMeshData/Waist/DA_Armor_Regular_BlackBeard_Sailor_Waist_03_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Sergeant_Feet_01_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Sergeant_Feet_02_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Feets/DA_Armor_Regular_BlackBeard_Sergeant_Feet_03_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Sergeant_Hands_01_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Sergeant_Hands_02_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Hands/DA_Armor_Regular_BlackBeard_Sergeant_Hands_03_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Sergeant_Head_01_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Sergeant_Head_02_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Head/DA_Armor_Regular_BlackBeard_Sergeant_Head_03_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Sergeant_Legs_01_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Sergeant_Legs_02_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Legs/DA_Armor_Regular_BlackBeard_Sergeant_Legs_03_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Sergeant_Torso_01_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Sergeant_Torso_02_CompositeMeshData" },
  { family = "BlackBeard_Sergeant", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/BlackBeard_Sergeant/CompositeMeshData/Torso/DA_Armor_Regular_BlackBeard_Sergeant_Torso_03_CompositeMeshData" },
  { family = "Combatant", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Feets/DA_Armor_Regular_Combatant_Feet_01_CompositeMeshData" },
  { family = "Combatant", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Feets/DA_Armor_Regular_Combatant_Feet_02_CompositeMeshData" },
  { family = "Combatant", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Feets/DA_Armor_Regular_Combatant_Feet_03_CompositeMeshData" },
  { family = "Combatant", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Hands/DA_Armor_Regular_Combatant_Hands_01_CompositeMeshData" },
  { family = "Combatant", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Hands/DA_Armor_Regular_Combatant_Hands_02_CompositeMeshData" },
  { family = "Combatant", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Hands/DA_Armor_Regular_Combatant_Hands_03_CompositeMeshData" },
  { family = "Combatant", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Head/DA_Armor_Regular_Combatant_Head_01_CompositeMeshData" },
  { family = "Combatant", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Head/DA_Armor_Regular_Combatant_Head_02_CompositeMeshData" },
  { family = "Combatant", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Head/DA_Armor_Regular_Combatant_Head_03_CompositeMeshData" },
  { family = "Combatant", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Legs/DA_Armor_Regular_Combatant_Legs_01_CompositeMeshData" },
  { family = "Combatant", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Legs/DA_Armor_Regular_Combatant_Legs_02_CompositeMeshData" },
  { family = "Combatant", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Legs/DA_Armor_Regular_Combatant_Legs_03_CompositeMeshData" },
  { family = "Combatant", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Torso/DA_Armor_Regular_Combatant_Torso_01_CompositeMeshData" },
  { family = "Combatant", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Torso/DA_Armor_Regular_Combatant_Torso_02_CompositeMeshData" },
  { family = "Combatant", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Combatant/CompositeMeshData/Torso/DA_Armor_Regular_Combatant_Torso_03_CompositeMeshData" },
  { family = "Crafter", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Crafter/CompositeMeshData/Legs/DA_Armor_Regular_Crafter_Legs_01_CompositeMeshData" },
  { family = "Crafter", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Crafter/CompositeMeshData/Legs/DA_Armor_Regular_Crafter_Legs_02_CompositeMeshData" },
  { family = "Crafter", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Crafter/CompositeMeshData/Legs/DA_Armor_Regular_Crafter_Legs_03_CompositeMeshData" },
  { family = "Default", slot = "Belt", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Default/CompositeMeshData/Belt/DA_Armor_Regular_Character_Belt_01_CompositeMeshData" },
  { family = "Default", slot = "Frog", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Default/CompositeMeshData/Frog/DA_Armor_Regular_Character_Frog_01_CompositeMeshData" },
  { family = "Default", slot = "Sling", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Default/CompositeMeshData/Sling/DA_Armor_Regular_Character_Sling_01_CompositeMeshData" },
  { family = "Default", slot = "Strap", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Default/CompositeMeshData/Strap/DA_Armor_Regular_Character_Strap_01_CompositeMeshData" },
  { family = "Dogface", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Feets/DA_Armor_Regular_Dogface_Feet_01_CompositeMeshData" },
  { family = "Dogface", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Feets/DA_Armor_Regular_Dogface_Feet_02_CompositeMeshData" },
  { family = "Dogface", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Feets/DA_Armor_Regular_Dogface_Feet_03_CompositeMeshData" },
  { family = "Dogface", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Head/DA_Armor_Regular_Dogface_Head_01_CompositeMeshData" },
  { family = "Dogface", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Head/DA_Armor_Regular_Dogface_Head_02_CompositeMeshData" },
  { family = "Dogface", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Head/DA_Armor_Regular_Dogface_Head_03_CompositeMeshData" },
  { family = "Dogface", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Legs/DA_Armor_Regular_Dogface_Legs_01_CompositeMeshData" },
  { family = "Dogface", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Legs/DA_Armor_Regular_Dogface_Legs_02_CompositeMeshData" },
  { family = "Dogface", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Legs/DA_Armor_Regular_Dogface_Legs_03_CompositeMeshData" },
  { family = "Dogface", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Torso/DA_Armor_Regular_Dogface_Torso_01_CompositeMeshData" },
  { family = "Dogface", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Torso/DA_Armor_Regular_Dogface_Torso_02_CompositeMeshData" },
  { family = "Dogface", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Dogface/CompositeMeshData/Torso/DA_Armor_Regular_Dogface_Torso_03_CompositeMeshData" },
  { family = "Drowned", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Feets/DA_Armor_Regular_Drowned_Feet_01_CompositeMeshData" },
  { family = "Drowned", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Feets/DA_Armor_Regular_Drowned_Feet_02_CompositeMeshData" },
  { family = "Drowned", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Feets/DA_Armor_Regular_Drowned_Feet_03_CompositeMeshData" },
  { family = "Drowned", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Hands/DA_Armor_Regular_Drowned_Hands_01_CompositeMeshData" },
  { family = "Drowned", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Hands/DA_Armor_Regular_Drowned_Hands_02_CompositeMeshData" },
  { family = "Drowned", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Hands/DA_Armor_Regular_Drowned_Hands_03_CompositeMeshData" },
  { family = "Drowned", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Head/DA_Armor_Regular_Drowned_Head_01_CompositeMeshData" },
  { family = "Drowned", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Head/DA_Armor_Regular_Drowned_Head_02_CompositeMeshData" },
  { family = "Drowned", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Head/DA_Armor_Regular_Drowned_Head_03_CompositeMeshData" },
  { family = "Drowned", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Legs/DA_Armor_Regular_Drowned_Legs_01_CompositeMeshData" },
  { family = "Drowned", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Legs/DA_Armor_Regular_Drowned_Legs_02_CompositeMeshData" },
  { family = "Drowned", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Legs/DA_Armor_Regular_Drowned_Legs_03_CompositeMeshData" },
  { family = "Drowned", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Torso/DA_Armor_Regular_Drowned_Torso_01_CompositeMeshData" },
  { family = "Drowned", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Torso/DA_Armor_Regular_Drowned_Torso_02_CompositeMeshData" },
  { family = "Drowned", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned/CompositeMeshData/Torso/DA_Armor_Regular_Drowned_Torso_03_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Feets/DA_Armor_Regular_Drowned_Armored_Feet_01_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Feets/DA_Armor_Regular_Drowned_Armored_Feet_02_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Feets/DA_Armor_Regular_Drowned_Armored_Feet_03_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Hands/DA_Armor_Regular_Drowned_Armored_Hands_01_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Hands/DA_Armor_Regular_Drowned_Armored_Hands_02_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Hands/DA_Armor_Regular_Drowned_Armored_Hands_03_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Head/DA_Armor_Regular_Drowned_Armored_Head_01_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Head/DA_Armor_Regular_Drowned_Armored_Head_02_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Head/DA_Armor_Regular_Drowned_Armored_Head_03_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Legs/DA_Armor_Regular_Drowned_Armored_Legs_01_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Legs/DA_Armor_Regular_Drowned_Armored_Legs_02_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Legs/DA_Armor_Regular_Drowned_Armored_Legs_03_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Torso/DA_Armor_Regular_Drowned_Armored_Torso_01_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Torso/DA_Armor_Regular_Drowned_Armored_Torso_02_CompositeMeshData" },
  { family = "Drowned_Armored", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Drowned_Armored/CompositeMeshData/Torso/DA_Armor_Regular_Drowned_Armored_Torso_03_CompositeMeshData" },
  { family = "Flibustier", slot = "Cape", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Cape/DA_Armor_Regular_Flibustier_Cape_02_CompositeMeshData" },
  { family = "Flibustier", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Feet/DA_Armor_Regular_Flibustier_Feet_01_CompositeMeshData" },
  { family = "Flibustier", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Feet/DA_Armor_Regular_Flibustier_Feet_02_CompositeMeshData" },
  { family = "Flibustier", slot = "Hands", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Hands/DA_Armor_Regular_Flibustier_Hands_01_Long_CompositeMeshData" },
  { family = "Flibustier", slot = "Hands", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Hands/DA_Armor_Regular_Flibustier_Hands_02_Long_CompositeMeshData" },
  { family = "Flibustier", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Hands/DA_Armor_Regular_Flibustier_Hands_01_CompositeMeshData" },
  { family = "Flibustier", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Hands/DA_Armor_Regular_Flibustier_Hands_02_CompositeMeshData" },
  { family = "Flibustier", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Head/DA_Armor_Regular_Flibustier_Head_01_CompositeMeshData" },
  { family = "Flibustier", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Head/DA_Armor_Regular_Flibustier_Head_02_CompositeMeshData" },
  { family = "Flibustier", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Head/DA_Armor_Regular_Flibustier_Head_03_CompositeMeshData" },
  { family = "Flibustier", slot = "Head", name = "04", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Head/DA_Armor_Regular_Flibustier_Head_04_CompositeMeshData" },
  { family = "Flibustier", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Legs/DA_Armor_Regular_Flibustier_Legs_01_CompositeMeshData" },
  { family = "Flibustier", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Legs/DA_Armor_Regular_Flibustier_Legs_02_CompositeMeshData" },
  { family = "Flibustier", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Legs/DA_Armor_Regular_Flibustier_Legs_03_CompositeMeshData" },
  { family = "Flibustier", slot = "Torso", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Torso/DA_Armor_Regular_Flibustier_Torso_02_Long_CompositeMeshData" },
  { family = "Flibustier", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Torso/DA_Armor_Regular_Flibustier_Torso_01_CompositeMeshData" },
  { family = "Flibustier", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Torso/DA_Armor_Regular_Flibustier_Torso_02_CompositeMeshData" },
  { family = "Flibustier", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Torso/DA_Armor_Regular_Flibustier_Torso_03_CompositeMeshData" },
  { family = "Flibustier", slot = "Torso", name = "04", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Torso/DA_Armor_Regular_Flibustier_Torso_04_CompositeMeshData" },
  { family = "Flibustier", slot = "Torso", name = "05", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Torso/DA_Armor_Regular_Flibustier_Torso_05_CompositeMeshData" },
  { family = "Flibustier", slot = "Waist", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Flibustier/CompositeMeshData/Waist/DA_Armor_Regular_Flibustier_Waist_01_CompositeMeshData" },
  { family = "Jeweler", slot = "Cape", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Cape/DA_Armor_Regular_Jeweler_Cape_02_CompositeMeshData" },
  { family = "Jeweler", slot = "Cape", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Cape/DA_Armor_Regular_Jeweler_Cape_03_CompositeMeshData" },
  { family = "Jeweler", slot = "Cape", name = "04", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Cape/DA_Armor_Regular_Jeweler_Cape_04_CompositeMeshData" },
  { family = "Jeweler", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Feet/DA_Armor_Regular_Jeweler_Feet_01_CompositeMeshData" },
  { family = "Jeweler", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Feet/DA_Armor_Regular_Jeweler_Feet_02_CompositeMeshData" },
  { family = "Jeweler", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Feet/DA_Armor_Regular_Jeweler_Feet_03_CompositeMeshData" },
  { family = "Jeweler", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Hands/DA_Armor_Regular_Jeweler_Hands_01_CompositeMeshData" },
  { family = "Jeweler", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Hands/DA_Armor_Regular_Jeweler_Hands_02_CompositeMeshData" },
  { family = "Jeweler", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Hands/DA_Armor_Regular_Jeweler_Hands_03_CompositeMeshData" },
  { family = "Jeweler", slot = "Head", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Head/DA_Armor_Regular_Jeweler_Head_None_CompositeMeshData" },
  { family = "Jeweler", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Head/DA_Armor_Regular_Jeweler_Head_01_CompositeMeshData" },
  { family = "Jeweler", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Head/DA_Armor_Regular_Jeweler_Head_02_CompositeMeshData" },
  { family = "Jeweler", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Head/DA_Armor_Regular_Jeweler_Head_03_CompositeMeshData" },
  { family = "Jeweler", slot = "Head", name = "04", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Head/DA_Armor_Regular_Jeweler_Head_04_CompositeMeshData" },
  { family = "Jeweler", slot = "Head", name = "07", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Head/DA_Armor_Regular_Jeweler_Head_07_CompositeMeshData" },
  { family = "Jeweler", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Legs/DA_Armor_Regular_Jeweler_Legs_01_CompositeMeshData" },
  { family = "Jeweler", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Legs/DA_Armor_Regular_Jeweler_Legs_02_CompositeMeshData" },
  { family = "Jeweler", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Legs/DA_Armor_Regular_Jeweler_Legs_03_CompositeMeshData" },
  { family = "Jeweler", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Torso/DA_Armor_Regular_Jeweler_Torso_01_CompositeMeshData" },
  { family = "Jeweler", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Torso/DA_Armor_Regular_Jeweler_Torso_02_CompositeMeshData" },
  { family = "Jeweler", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Torso/DA_Armor_Regular_Jeweler_Torso_03_CompositeMeshData" },
  { family = "Jeweler", slot = "Torso", name = "04", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Torso/DA_Armor_Regular_Jeweler_Torso_04_CompositeMeshData" },
  { family = "Jeweler", slot = "Torso", name = "05", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Torso/DA_Armor_Regular_Jeweler_Torso_05_CompositeMeshData" },
  { family = "Jeweler", slot = "Torso", name = "06", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Torso/DA_Armor_Regular_Jeweler_Torso_06_CompositeMeshData" },
  { family = "Jeweler", slot = "Torso", name = "07", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Torso/DA_Armor_Regular_Jeweler_Torso_07_CompositeMeshData" },
  { family = "Jeweler", slot = "Torso", name = "08", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Torso/DA_Armor_Regular_Jeweler_Torso_08_CompositeMeshData" },
  { family = "Jeweler", slot = "Waist", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Waist/DA_Armor_Regular_Jeweler_Waist_01_CompositeMeshData" },
  { family = "Jeweler", slot = "Waist", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Waist/DA_Armor_Regular_Jeweler_Waist_02_CompositeMeshData" },
  { family = "Jeweler", slot = "Waist", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Jeweler/CompositeMeshData/Waist/DA_Armor_Regular_Jeweler_Waist_03_CompositeMeshData" },
  { family = "Musketeer", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Feets/DA_Armor_Regular_Musketeer_Feet_01_CompositeMeshData" },
  { family = "Musketeer", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Feets/DA_Armor_Regular_Musketeer_Feet_02_CompositeMeshData" },
  { family = "Musketeer", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Feets/DA_Armor_Regular_Musketeer_Feet_03_CompositeMeshData" },
  { family = "Musketeer", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Hands/DA_Armor_Regular_Musketeer_Hands_01_CompositeMeshData" },
  { family = "Musketeer", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Hands/DA_Armor_Regular_Musketeer_Hands_02_CompositeMeshData" },
  { family = "Musketeer", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Hands/DA_Armor_Regular_Musketeer_Hands_03_CompositeMeshData" },
  { family = "Musketeer", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Head/DA_Armor_Regular_Musketeer_Head_01_CompositeMeshData" },
  { family = "Musketeer", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Head/DA_Armor_Regular_Musketeer_Head_02_CompositeMeshData" },
  { family = "Musketeer", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Head/DA_Armor_Regular_Musketeer_Head_03_CompositeMeshData" },
  { family = "Musketeer", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Legs/DA_Armor_Regular_Musketeer_Legs_01_CompositeMeshData" },
  { family = "Musketeer", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Legs/DA_Armor_Regular_Musketeer_Legs_02_CompositeMeshData" },
  { family = "Musketeer", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Legs/DA_Armor_Regular_Musketeer_Legs_03_CompositeMeshData" },
  { family = "Musketeer", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Torso/DA_Armor_Regular_Musketeer_Torso_01_CompositeMeshData" },
  { family = "Musketeer", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Torso/DA_Armor_Regular_Musketeer_Torso_02_CompositeMeshData" },
  { family = "Musketeer", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Musketeer/CompositeMeshData/Torso/DA_Armor_Regular_Musketeer_Torso_03_CompositeMeshData" },
  { family = "NPC_GalenSkelton", slot = "Feet", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_GalenSkelton/CompositeMeshData/Feets/DA_Armor_Regular_NPC_GalenSkelton_Feet_CompositeMeshData" },
  { family = "NPC_GalenSkelton", slot = "Legs", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_GalenSkelton/CompositeMeshData/Legs/DA_Armor_Regular_NPC_GalenSkelton_Legs_CompositeMeshData" },
  { family = "NPC_GalenSkelton", slot = "Torso", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_GalenSkelton/CompositeMeshData/Torso/DA_Armor_Regular_NPC_GalenSkelton_Torso_CompositeMeshData" },
  { family = "NPC_GalenSkelton", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_GalenSkelton/CompositeMeshData/Torso/DA_Armor_Regular_NPC_GalenSkelton_Belt_01_CompositeMeshData" },
  { family = "NPC_GalenSkelton", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_GalenSkelton/CompositeMeshData/Torso/DA_Armor_Regular_NPC_GalenSkelton_Cape_01_CompositeMeshData" },
  { family = "NPC_Ksante", slot = "Feet", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_Ksante/CompositeMeshData/Feets/DA_Armor_Regular_NPC_Ksante_Feet_CompositeMeshData" },
  { family = "NPC_Ksante", slot = "Hands", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_Ksante/CompositeMeshData/Hands/DA_Armor_Regular_NPC_Ksante_Hands_CompositeMeshData" },
  { family = "NPC_Ksante", slot = "Legs", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_Ksante/CompositeMeshData/Legs/DA_Armor_Regular_NPC_Ksante_Legs_CompositeMeshData" },
  { family = "NPC_Ksante", slot = "Torso", name = "Default", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_Ksante/CompositeMeshData/Torso/DA_Armor_Regular_NPC_Ksante_Torso_Torn_CompositeMeshData" },
  { family = "NPC_Ksante", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_Ksante/CompositeMeshData/Torso/DA_Armor_Regular_NPC_Ksante_Belt_01_CompositeMeshData" },
  { family = "NPC_Ksante", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/NPC_Ksante/CompositeMeshData/Torso/DA_Armor_Regular_NPC_Ksante_Cape_01_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Hunter_Feather_Feet_01_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Hunter_Feather_Feet_02_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Hunter_Feather_Feet_03_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Hunter_Feather_Hands_01_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Hunter_Feather_Hands_02_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Hunter_Feather_Hands_03_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Hunter_Feather_Head_01_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Hunter_Feather_Head_02_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Hunter_Feather_Head_03_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Hunter_Feather_Legs_01_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Hunter_Feather_Legs_02_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Hunter_Feather_Legs_03_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Hunter_Feather_Torso_01_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Hunter_Feather_Torso_02_CompositeMeshData" },
  { family = "Senkamati_Hunter_Feather", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Hunter_Feather_Torso_03_CompositeMeshData" },
  { family = "Senkamati_Hunter_Wood", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Wood/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Hunter_Wood_Legs_01_CompositeMeshData" },
  { family = "Senkamati_Hunter_Wood", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Wood/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Hunter_Wood_Legs_02_CompositeMeshData" },
  { family = "Senkamati_Hunter_Wood", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Hunter_Wood/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Hunter_Wood_Legs_03_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Cape", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Cape/DA_Armor_Regular_Senkamati_Shaman_Feather_Cape_01_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Cape", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Cape/DA_Armor_Regular_Senkamati_Shaman_Feather_Cape_02_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Shaman_Feather_Feet_01_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Shaman_Feather_Feet_02_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Shaman_Feather_Hands_01_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Shaman_Feather_Hands_02_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Shaman_Feather_Head_01_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Shaman_Feather_Head_02_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Shaman_Feather_Head_03_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Shaman_Feather_Legs_01_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Shaman_Feather_Legs_02_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Neck", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Neck/DA_Armor_Regular_Senkamati_Shaman_Feather_Neck_01_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Neck", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Neck/DA_Armor_Regular_Senkamati_Shaman_Feather_Neck_02_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Shaman_Feather_Torso_01_CompositeMeshData" },
  { family = "Senkamati_Shaman_Feather", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Shaman_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Shaman_Feather_Torso_02_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Thrall_Feather_Feet_01_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Thrall_Feather_Feet_02_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Thrall_Feather_Feet_03_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Thrall_Feather_Hands_01_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Thrall_Feather_Hands_02_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Thrall_Feather_Hands_03_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Thrall_Feather_Head_01_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Thrall_Feather_Head_02_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Thrall_Feather_Head_03_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Head", name = "04", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Thrall_Feather_Head_04_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Thrall_Feather_Legs_01_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Thrall_Feather_Legs_02_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Thrall_Feather_Legs_03_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Thrall_Feather_Torso_01_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Thrall_Feather_Torso_02_CompositeMeshData" },
  { family = "Senkamati_Thrall_Feather", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Thrall_Feather_Torso_03_CompositeMeshData" },
  { family = "Senkamati_Thrall_Wood", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Wood/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Thrall_Wood_Feet_01_CompositeMeshData" },
  { family = "Senkamati_Thrall_Wood", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Wood/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Thrall_Wood_Feet_02_CompositeMeshData" },
  { family = "Senkamati_Thrall_Wood", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Wood/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Thrall_Wood_Feet_03_CompositeMeshData" },
  { family = "Senkamati_Thrall_Wood", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Wood/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Thrall_Wood_Hands_01_CompositeMeshData" },
  { family = "Senkamati_Thrall_Wood", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Wood/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Thrall_Wood_Hands_02_CompositeMeshData" },
  { family = "Senkamati_Thrall_Wood", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Wood/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Thrall_Wood_Hands_03_CompositeMeshData" },
  { family = "Senkamati_Thrall_Wood", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Wood/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Thrall_Wood_Legs_01_CompositeMeshData" },
  { family = "Senkamati_Thrall_Wood", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Wood/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Thrall_Wood_Legs_02_CompositeMeshData" },
  { family = "Senkamati_Thrall_Wood", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Thrall_Wood/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Thrall_Wood_Legs_03_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Warrior_Feather_Feet_01_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Warrior_Feather_Feet_02_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Feet", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Feets/DA_Armor_Regular_Senkamati_Warrior_Feather_Feet_03_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Warrior_Feather_Hands_01_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Hands", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Warrior_Feather_Hands_02_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Hands", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Hands/DA_Armor_Regular_Senkamati_Warrior_Feather_Hands_03_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Warrior_Feather_Head_01_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Warrior_Feather_Head_02_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Head", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Head/DA_Armor_Regular_Senkamati_Warrior_Feather_Head_03_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Warrior_Feather_Legs_01_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Warrior_Feather_Legs_02_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Legs", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Legs/DA_Armor_Regular_Senkamati_Warrior_Feather_Legs_03_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Warrior_Feather_Torso_01_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Warrior_Feather_Torso_02_CompositeMeshData" },
  { family = "Senkamati_Warrior_Feather", slot = "Torso", name = "03", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Senkamati_Warrior_Feather/CompositeMeshData/Torso/DA_Armor_Regular_Senkamati_Warrior_Feather_Torso_03_CompositeMeshData" },
  { family = "Set_Adventurer", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Adventurer/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Adventurer_Feet_01_CompositeMeshData" },
  { family = "Set_Adventurer", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Adventurer/CompositeMeshData/Hands/DA_Armor_Regular_Hero_Adventurer_Hands_01_CompositeMeshData" },
  { family = "Set_Adventurer", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Adventurer/CompositeMeshData/Head/DA_Armor_Regular_Hero_Adventurer_Head_01_CompositeMeshData" },
  { family = "Set_Adventurer", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Adventurer/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Adventurer_Legs_01_CompositeMeshData" },
  { family = "Set_Adventurer", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Adventurer/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Adventurer_Waist_01_CompositeMeshData" },
  { family = "Set_Adventurer", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Adventurer/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Adventurer_Belt_01_CompositeMeshData" },
  { family = "Set_Adventurer", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Adventurer/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Adventurer_Torso_01_CompositeMeshData" },
  { family = "Set_Bandit", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Bandit/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Bandit_Feet_01_CompositeMeshData" },
  { family = "Set_Bandit", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Bandit/CompositeMeshData/Hands/DA_Armor_Regular_Hero_Bandit_Hands_01_CompositeMeshData" },
  { family = "Set_Bandit", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Bandit/CompositeMeshData/Head/DA_Armor_Regular_Hero_Bandit_Head_01_CompositeMeshData" },
  { family = "Set_Bandit", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Bandit/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Bandit_Legs_01_CompositeMeshData" },
  { family = "Set_Bandit", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Bandit/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Bandit_Waist_01_CompositeMeshData" },
  { family = "Set_Bandit", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Bandit/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Bandit_Belt_01_CompositeMeshData" },
  { family = "Set_Bandit", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Bandit/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Bandit_Torso_01_CompositeMeshData" },
  { family = "Set_Brigant", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Brigant/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Brigant_Feet_01_CompositeMeshData" },
  { family = "Set_Brigant", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Brigant/CompositeMeshData/Hands/DA_Armor_Regular_Hero_Brigant_Hands_01_CompositeMeshData" },
  { family = "Set_Brigant", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Brigant/CompositeMeshData/Head/DA_Armor_Regular_Hero_Brigant_Head_01_CompositeMeshData" },
  { family = "Set_Brigant", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Brigant/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Brigant_Legs_01_CompositeMeshData" },
  { family = "Set_Brigant", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Brigant/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Brigant_Waist_01_CompositeMeshData" },
  { family = "Set_Brigant", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Brigant/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Brigant_Torso_01_CompositeMeshData" },
  { family = "Set_Conquistador", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Conquistador/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Conquistador_Feet_01_CompositeMeshData" },
  { family = "Set_Conquistador", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Conquistador/CompositeMeshData/Hands/DA_Armor_Regular_Hero_Conquistador_Hands_01_CompositeMeshData" },
  { family = "Set_Conquistador", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Conquistador/CompositeMeshData/Head/DA_Armor_Regular_Hero_Conquistador_Head_01_CompositeMeshData" },
  { family = "Set_Conquistador", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Conquistador/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Conquistador_Legs_01_CompositeMeshData" },
  { family = "Set_Conquistador", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Conquistador/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Conquistador_Belt_01_CompositeMeshData" },
  { family = "Set_Conquistador", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Conquistador/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Conquistador_Torso_01_CompositeMeshData" },
  { family = "Set_Flibustier", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Flibustier/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Flibustier_Feet_01_CompositeMeshData" },
  { family = "Set_Flibustier", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Flibustier/CompositeMeshData/Hands/DA_Armor_Regular_Hero_Flibustier_Hands_01_CompositeMeshData" },
  { family = "Set_Flibustier", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Flibustier/CompositeMeshData/Head/DA_Armor_Regular_Hero_Flibustier_Head_01_CompositeMeshData" },
  { family = "Set_Flibustier", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Flibustier/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Flibustier_Legs_01_CompositeMeshData" },
  { family = "Set_Flibustier", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Flibustier/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Flibustier_Waist_01_CompositeMeshData" },
  { family = "Set_Flibustier", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Flibustier/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Flibustier_Belt_01_CompositeMeshData" },
  { family = "Set_Flibustier", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Flibustier/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Flibustier_Torso_01_CompositeMeshData" },
  { family = "Set_Mercenary", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Mercenary/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Mercenary_Feet_01_CompositeMeshData" },
  { family = "Set_Mercenary", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Mercenary/CompositeMeshData/Hands/DA_Armor_Regular_Hero_Mercenary_Hands_01_CompositeMeshData" },
  { family = "Set_Mercenary", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Mercenary/CompositeMeshData/Head/DA_Armor_Regular_Hero_Mercenary_Head_Bandana_01_CompositeMeshData" },
  { family = "Set_Mercenary", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Mercenary/CompositeMeshData/Head/DA_Armor_Regular_Hero_Mercenary_Head_Hat_01_CompositeMeshData" },
  { family = "Set_Mercenary", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Mercenary/CompositeMeshData/Head/DA_Armor_Regular_Hero_Mercenary_Head_Headband_01_CompositeMeshData" },
  { family = "Set_Mercenary", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Mercenary/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Mercenary_Legs_01_CompositeMeshData" },
  { family = "Set_Mercenary", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Mercenary/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Mercenary_Waist_01_CompositeMeshData" },
  { family = "Set_Mercenary", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Mercenary/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Mercenary_Belt_01_CompositeMeshData" },
  { family = "Set_Mercenary", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Mercenary/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Mercenary_Torso_01_CompositeMeshData" },
  { family = "Set_Pikeman", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Pikeman/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Pikeman_Feet_01_CompositeMeshData" },
  { family = "Set_Pikeman", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Pikeman/CompositeMeshData/Hands/DA_Armor_Regular_Hero_Pikeman_Hands_01_CompositeMeshData" },
  { family = "Set_Pikeman", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Pikeman/CompositeMeshData/Head/DA_Armor_Regular_Hero_Pikeman_Head_01_CompositeMeshData" },
  { family = "Set_Pikeman", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Pikeman/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Pikeman_Legs_01_CompositeMeshData" },
  { family = "Set_Pikeman", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Pikeman/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Pikeman_Waist_01_CompositeMeshData" },
  { family = "Set_Pikeman", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Pikeman/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Pikeman_Belt_01_CompositeMeshData" },
  { family = "Set_Pikeman", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Pikeman/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Pikeman_Torso_01_CompositeMeshData" },
  { family = "Set_Starter", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Starter_Feet_01_CompositeMeshData" },
  { family = "Set_Starter", slot = "Feet", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Starter_Feet_02_CompositeMeshData" },
  { family = "Set_Starter", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Hands/DA_Armor_Regular_Hero_Starter_Hands_01_CompositeMeshData" },
  { family = "Set_Starter", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Head/DA_Armor_Regular_Hero_Starter_Head_01_CompositeMeshData" },
  { family = "Set_Starter", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Starter_Legs_01_CompositeMeshData" },
  { family = "Set_Starter", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Starter_Waist_01_CompositeMeshData" },
  { family = "Set_Starter", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Starter_Legs_02_CompositeMeshData" },
  { family = "Set_Starter", slot = "Legs", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Starter_Waist_02_CompositeMeshData" },
  { family = "Set_Starter", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Starter_Belt_01_CompositeMeshData" },
  { family = "Set_Starter", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Starter_Torso_01_CompositeMeshData" },
  { family = "Set_Starter", slot = "Torso", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Starter/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Starter_Torso_02_CompositeMeshData" },
  { family = "Set_Vanilla", slot = "Feet", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Vanilla/CompositeMeshData/Feet/DA_Armor_Regular_Hero_Vanilla_Feet_01_CompositeMeshData" },
  { family = "Set_Vanilla", slot = "Hands", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Vanilla/CompositeMeshData/Hands/DA_Armor_Regular_Hero_Vanilla_Hands_01_CompositeMeshData" },
  { family = "Set_Vanilla", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Vanilla/CompositeMeshData/Head/DA_Armor_Regular_Hero_Vanilla_Head_01_CompositeMeshData" },
  { family = "Set_Vanilla", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Vanilla/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Vanilla_Legs_01_CompositeMeshData" },
  { family = "Set_Vanilla", slot = "Legs", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Vanilla/CompositeMeshData/Legs/DA_Armor_Regular_Hero_Vanilla_Waist_01_CompositeMeshData" },
  { family = "Set_Vanilla", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Vanilla/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Vanilla_Belt_01_CompositeMeshData" },
  { family = "Set_Vanilla", slot = "Torso", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/Set_Vanilla/CompositeMeshData/Torso/DA_Armor_Regular_Hero_Vanilla_Torso_01_CompositeMeshData" },
  { family = "T01_Head_SoloPlayer", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/T01_Head_SoloPlayer/CompositeMeshData/Head/DA_Armor_Regular_Hero_SoloPlayer_Head_01_CompositeMeshData" },
  { family = "T01_Head_SoloPlayer", slot = "Head", name = "02", path = "/Game/Gameplay/Character/Customization/Regular/Armor/T01_Head_SoloPlayer/CompositeMeshData/Head/DA_Armor_Regular_Hero_SoloPlayer_Head_02_CompositeMeshData" },
  { family = "T03_Head_MaskSenkamati", slot = "Head", name = "01", path = "/Game/Gameplay/Character/Customization/Regular/Armor/T03_Head_MaskSenkamati/CompositeMeshData/Head/DA_Armor_Regular_Hero_MaskSenkamati_Head_01_CompositeMeshData" },
}


Config.FEMALE_WALKER_OVERLAYS = {
  -- LETTY -- same body as our walker (SK_Adventure_Female_01), so no body swap needed. BUG FIX
  -- (2026-08-10): her own probe showed exactly 6 real pieces -- feet/hands/legs/torso/eyebrows/
  -- hair -- and NOTHING else (no headband, no belt, no sling, no frog; "12 skeletal mesh
  -- components total" = those 6 + body(counted twice) + 5 empty weapon slots). Original ruleset
  -- wrongly assumed belt/frog matched the walker's own default without actually checking her
  -- dump for their presence -- they're not there at all. Now hides belt/sling/frog.
  -- POLICY DECISION (2026-08-10, RedFalcon, live-test judgment call): a HAT visibly looks wrong on her
  -- (matches her real look of having neither), but a HEADBAND looks fine even though she doesn't
  -- technically wear one in-game -- close enough to not bother fighting it. So headband is no
  -- longer hidden (removed from `hides`); "Female_Hat" stays hidden since that's the one that
  -- actually reads as wrong on her.
  { name = "Letty",
    replaces = {
      { match = "Female_Feet",         to = objPath(ARM .. "Brigant/Meshes/", "SK_Armor_Brigant_Female_Feet_Long") },
      { match = "Female_Hands",             to = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Hands") },
      { match = "Female_Legs",              to = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Legs") },
      { match = "Female_Torso",     to = objPath(ARM .. "Starter/Meshes/", "SK_Armor_Starter_Female_Torso") },
      { match = "Eyebrows_Female",                  to = objPath(BROW, "SK_Eyebrows_Female_03") },
      { match = "Hair_", to = objPath(HAIRD .. "Ponytail/", "SK_Hair_Ponytail_01_Default_Female") },
    },
    -- BUG FIX (2026-08-11, confirmed via a live probe on the generic roster): "Female_Hat"
    -- never matches a mesh literally named "..._Female_BandanaHat" (no "Female_Hat"
    -- substring in "Female_Banana"+"Hat" run together) -- broadened to plain "Hat" so any
    -- naming variant is caught. Marita/Merchant weren't affected in practice since their
    -- own `forceHat` positional guarantee already covered for this; Letty has no such
    -- guarantee (her policy is hide-the-hat, not force-a-specific-one), so this was a real
    -- gap for her specifically.
    hides = { "Hat", "Sling_", "Belt_", "Frog_" },
  },
  -- MARITA SUARES -- CONFIRMED LIVE (2026-08-10) the body swap below T-poses the walker -- SEE
  -- THE SECTION COMMENT'S "UNPROVEN EDGE CASE" NOTE, now proven bad: SetSkeletalMeshAsset on
  -- actor.Mesh does not survive with a working AnimInstance, at least not the way DeCorrupt does
  -- it. Body swap rule REMOVED (disabled, not deleted -- kept as a comment for whoever revisits
  -- this) until a real fix is found; she keeps the walker's own SK_Adventure_Female_01 body for
  -- now. A bandana hat instead of a headband, no sling.
  { name = "Marita",
    replaces = {
      -- { match = "SK_Adventure_Female_01", to = objPath(HMN .. "Fable/Meshes/", "SK_Fable_Female_01") }, -- T-POSES, disabled
      { match = "Female_Feet",         to = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Female_Feet_Long") },
      { match = "Female_Hands",             to = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Hands") },
      { match = "Female_Legs",              to = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Female_Legs") },
      { match = "Female_Torso",     to = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_01_Female_Torso_Long") },
      { match = "Female_Headband",       to = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Female_BandanaHat") },
      -- BUG FIX (2026-08-10): headwear can ALSO roll as "..._Female_Hat" (a totally different
      -- naming convention, not just a different family/number) -- confirmed live via probe, see
      -- this section's own header comment. Same target, second match pattern to catch it.
      { match = "Female_Hat",            to = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Female_BandanaHat") },
      { match = "Eyebrows_Female",                  to = objPath(BROW, "SK_Eyebrows_Female_03") },
      { match = "Hair_", to = objPath(HAIRD .. "Wig/", "SK_Hair_Wig_02_SuspendedBandana_Female") },
    },
    hides = { "Sling_" },
    -- SETTLED (2026-08-10, RedFalcon's call): the two match patterns above still intermittently missed
    -- some roll of the headwear slot (bald, or wrong item) -- rather than keep chasing naming
    -- variants, always guarantee SOME hat via Spawner.ForceHeadwear (see its own comment).
    forceHat = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_03_Female_BandanaHat"),
  },
  -- BUCCANEERS MERCHANT_01 -- confirmed by live probe to be a genuinely female-bodied merchant
  -- (SK_Orient_Female_01), unlike the Brethren Merchant_04 (male body under women's clothing, per
  -- STANDING_STATUES' own comment) originally assumed to be "the" female merchant -- corrected
  -- 2026-08-10 after RedFalcon rescanned every candidate live. Her own Legs piece is oddly the MALE
  -- Conquistador mesh -- a real quirk of her own outfit, kept faithful rather than "corrected".
  -- She also wears a Strap accessory (SK_Strap_04_Female) the walker has no matching component
  -- for -- Spawner.DeCorrupt can only replace/hide EXISTING components, not add a new one, so that
  -- one piece can't be reproduced this way; everything else can. Eyebrows already match the
  -- walker's own default (Female_01 on both) -- no rule needed.
  -- Body swap CONFIRMED LIVE (2026-08-10) to T-pose the walker -- disabled, see Marita's own note
  -- just above for the root-cause writeup. Keeps the walker's own SK_Adventure_Female_01 body.
  -- Renamed from "Buccaneers Merchant_01" to plain "Merchant" (2026-08-11, RedFalcon's request) --
  -- this name is also the persisted reskinTarget value now, so it's what shows up in logs/
  -- toasts and in Testbed.FEMALE_RESKIN_TARGETS; shorter reads better in both places.
  { name = "Merchant",
    replaces = {
      -- { match = "SK_Adventure_Female_01", to = objPath(HMN .. "Orient/Meshes/", "SK_Orient_Female_01") }, -- T-POSES, disabled
      { match = "Female_Feet",         to = objPath(ARM .. "Mercenary/Meshes/", "SK_Armor_Mercenary_Female_Feet_Long") },
      { match = "Female_Hands",             to = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_02_Female_Hands_Long") },
      -- Female_Legs (2026-08-19, RedFalcon: "booty sticks out of her pants"): the original rule
      -- pointed at SK_Armor_Conquistador_02_MALE_Legs -- confirmed via a live probe on the real
      -- female Merchant statue (Buccaneers_Merchant_01) that this is genuinely what she wears
      -- in-game too (every other piece here matches her real outfit exactly), so it wasn't a wrong
      -- guess -- it's a real body-shape mismatch between the Walker's own skeleton and a mesh built
      -- to fit the Standing statue's body. FIXED: confirmed via Manifest_UFSFiles_Win64.txt that a
      -- genuine SK_Armor_Conquistador_02_Female_Legs.uasset exists (part of the actual
      -- player-equippable Conquistador armor set, its own CompositeMeshGroup) -- using that instead.
      { match = "Female_Legs",              to = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Female_Legs") },
      { match = "Female_Torso",     to = objPath(ARM .. "Flibustier/Meshes/", "SK_Armor_Flibustier_04_Female_Torso") },
      { match = "Female_Headband",       to = objPath(ARM .. "Musketeer/Meshes/", "SK_Armor_Musketeer03_Head") },
      -- BUG FIX (2026-08-10): see Marita's own note on the "Female_Hat" naming variant.
      { match = "Female_Hat",            to = objPath(ARM .. "Musketeer/Meshes/", "SK_Armor_Musketeer03_Head") },
      { match = "Hair_", to = objPath(HAIRD .. "ShortBob/", "SK_Hair_ShortBob_SuspendHat_Female") },
    },
    hides = {},
    -- SETTLED (2026-08-10, RedFalcon's call): see Marita's own note just above -- same intermittent
    -- headwear-slot miss, same fix.
    forceHat = objPath(ARM .. "Musketeer/Meshes/", "SK_Armor_Musketeer03_Head"),
  },
  -- FEMALE_STANDING_01 and FEMALE_SITTING_01 (2026-08-10, RedFalcon's call): REVERTED to no overlay at
  -- all -- the plain Brethren Woman look already reads close enough to these two on spawn ("look
  -- fine other than color"), so the outfit-swap post-processing they used to have here is
  -- unnecessary complexity/risk for no visible benefit. Matches how Female_Sitting_02/03 (never
  -- probed) already behave: Testbed.TestFemaleWalkerReskin falls back to the plain look whenever
  -- no entry below matches the target name. The removed rulesets swapped Feet/Hands/Legs/Torso/
  -- Headband-or-Hat/Eyebrows/Hair to each statue's own probed pieces, in case this is ever
  -- revisited -- see archive/config_*.lua from earlier 2026-08-10 for the exact ruleset if wanted.
  -- "Stripped" DIAGNOSTIC entry REMOVED (2026-08-11, debug-tool cleanup) -- it existed only to
  -- test whether the Senkamati pelvis-gap issue (item 32 in this project's history) also
  -- affected this body/skeleton. RESULT (2026-08-10, live test): NO pelvis gap on the bare
  -- body -- the gap is specific to the Senkamati Feather_Legs garment piece, not this
  -- skeleton. Question answered, nothing left to check for.
}

-- Config.FEMALE_CHARACTER_PARAMS (2026-08-19) -- REPLACES the old shared-"Brethren Woman"-
-- params-plus-DeCorrupt-piece-overlay approach for Letty/Marita/Merchant specifically, now that a
-- real cross-class pre-build DefaultParams swap is confirmed to render correctly (this session's
-- investigation, see WINDROSE_MODDING_NOTES.md's composite section) -- no more per-piece replace/
-- hide/forceHat rules, no more topless/bald settle-check retry loop, because the REAL outfit is
-- correct from the moment the actor is built, not reconstructed piece-by-piece after the fact.
-- `params` for Letty/Marita is their OWN real QuestStatic NPC's composite params, live-probed
-- directly off the actual characters (not guessed/reused from something else) -- Merchant reuses
-- Buccaneers Merchant 01's, the closest thematic fit among the confirmed-clean female-authored
-- outfits surveyed this session. `hairs`/`eyebrows` are those SAME real NPCs' own live controller
-- values (also live-probed) -- "preloaded" onto the spawned actor right after the composite swap
-- (see Testbed.ApplyFemaleReskinTarget's own branch for these characters) because
-- GetCustomizationMeshControllers() reflects whichever composite is CURRENTLY built, not the
-- walker's own base body -- her carried-over index otherwise lands in the wrong pool for this new
-- outfit's controller range (confirmed live this session: a stale index rendered a visibly wrong
-- hairstyle until corrected). Keyed by femaleCharacterKey (testbed.lua) -- the character name with
-- any trailing " Base N" stripped -- since the outfit/hair choice doesn't depend on which base
-- body (Gatherer/Herbalist) is underneath, only which NAMED character this is.
Config.FEMALE_CHARACTER_PARAMS = {
  -- "Woman" (2026-08-19, RedFalcon's call, revised after his own live probe): the collapsed
  -- replacement for the old separate "Woman With Hat"/"Woman With Hair" entries -- those two
  -- produced IDENTICAL results once the ForceHeadwear/content-matched-replace/topless-retry
  -- system was dropped (see below), so keeping 4 roster entries (x Base 1/2) for 2 real outcomes
  -- was pure clutter. Now just "Woman Base 1"/"Woman Base 2" in Config.FEMALE_RESKIN_TARGETS.
  -- Uses the SHARED Brethren Woman outfit (NOT the walker's own plain vanilla one -- that was
  -- this entry's first draft, reverted same session). Two live lbcustomnpc-get probes of
  -- BP_AnimatedActor_BotC_Female_Standing_01_C (shares this IDENTICAL DefaultParams asset)
  -- showed 8 controllers total -- SIX different Armor.* slots (Head 0..8, Torso 0..9, Hands 0..6,
  -- Legs 0..4, Feet 0..4, Belt 0..5), each locked from further live edits (selectable=false) but
  -- with a genuinely different BUILD-TIME-RANDOM value each spawn, plus Facial.Eyebrows and Hairs
  -- (both selectable) also varying spawn to spawn (19->28 seen live). So this shared composite
  -- already randomizes essentially her WHOLE outfit for free, including whether she rolls
  -- headwear at all -- confirmed live: same class, one spawn had a hat, another didn't. That's
  -- WHY the old ForceHeadwear/content-matched-replace/topless-retry system existed in the first
  -- place (reacting to/steering this pre-existing randomness) -- and why it can be dropped
  -- entirely now that RedFalcon confirmed the randomness itself already produces a valid look:
  -- no forcing needed, just spawn with this outfit and layer skin tone on top, same as before.
  -- An EMPTY table here (no `.params`) is enough to trigger Testbed.ApplyFemaleReskinTarget's fast
  -- path (skip the whole old overlay/retry system) while spawnFemaleWalkerTarget's own fallback
  -- still resolves the actual outfit to Brethren Woman's params, same as it always has.
  -- hairsRandomMax (2026-08-19, RedFalcon's live testing): the Armor.* build-time randomization
  -- confirmed above does NOT extend to Hairs for this walking (CREW_CLASS-hosted) spawn, unlike
  -- the Standing statue (AnimatedActor-hosted) probes which showed both varying -- confirmed live,
  -- her hair stayed static across spawns even as hat/outfit varied. Fix confirmed live too:
  -- `lbcustomnpc set hairs #` correctly picks a hat-COMPATIBLE hair variant even when a hat rolled
  -- that spawn -- the controller write coordinates properly on its own, no risk of the old hair-
  -- through-hat clipping bug forcing a value manually was worried about. 32 is this shared
  -- composite's own confirmed real Hairs max (BP_AnimatedActor_BotC_Female_Standing_01_C probes),
  -- NOT the vanilla Gatherer/Herbalist's own smaller 0..7 range used by Letty/Marita/Merchant's
  -- controller preloads below -- different composite, different pool size.
  Woman = { hairsRandomMax = 32 },
  Letty = {
    params = objPath("/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/CompositeMesh/Letty/",
      "DA_NPC_QuestStatic_TortugaCitizen_Letty_CompositeMeshComponentParams"),
    hairs = 16, eyebrows = 2,
  },
  Marita = {
    params = objPath("/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/CompositeMesh/MaritaSuares/",
      "DA_NPC_QuestStatic_Smugglers_MaritaSuares_CompositeMeshComponentParams"),
    hairs = 32, eyebrows = 2,
  },
  Merchant = {
    params = objPath("/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/CompositeMesh/Merchant/",
      "DA_NPC_AnimatedActor_Buccaneers_Merchant_01_CompositeMeshComponentParams"),
    hairs = 23, eyebrows = 0,
    -- meshFixes (2026-08-19): the SAME "booty sticks out of her pants" bug the old
    -- FEMALE_WALKER_OVERLAYS "Merchant" entry already root-caused and fixed THIS SAME DAY --
    -- her real DefaultParams genuinely bakes in SK_Armor_Conquistador_02_MALE_Legs (confirmed
    -- via a live probe on her own real statue, not a wrong guess -- see that entry's own
    -- comment) -- a real body-shape mismatch between the Walker's skeleton and a mesh built for
    -- the Standing statue's body, not a simple wrong-sex-asset mistake. The old fix swapped in
    -- SK_Armor_Conquistador_02_Female_Legs by content-matching the live component's mesh name;
    -- this is the same fix, same target mesh, just applied via Spawner.SetBodyPartMesh's
    -- BodyPart-enum lookup (13 = Legs, ER5BLCompositeMeshBodyPartType_V0_8_0) since the new
    -- pre-build-params spawn path bypasses the old content-matched `replaces` rule entirely.
    meshFixes = {
      { bodyPart = 13, mesh = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Female_Legs") },
    },
  },
}

-- Config.FEMALE_RESKIN_TARGETS -- the walking-women name roster (testbed.lua's
-- Testbed.TestFemaleWalkerReskin/SpawnFemaleWalkerByName cycle/look up these exact strings against
-- Config.FEMALE_WALKER_OVERLAYS above). MOVED HERE from a local table in testbed.lua (2026-08-16,
-- RedFalcon's request -- "get the women back in the list") so spawnmenu_manifest.lua can enumerate
-- it into the LivingBaseSpawnMenu tree without a circular require (that generator runs from THIS
-- file's own tail and can only see Config, never require("testbed") -- see spawnmenu_manifest.lua's
-- own header for the full story). Every character x Base 1/Base 2 (2026-08-14) -- Base 1 = the
-- original Gatherer body, Base 2 = the Herbalist, see testbed.lua's femaleBaseClassFor for how the
-- suffix picks the body. Deliberately does NOT include "Female_Barbie" -- that one's lblook-only by
-- design (Testbed.SpawnBarbieByName's own comment), not part of this rotation.
Config.FEMALE_RESKIN_TARGETS = {
    -- "Woman With Hat"/"Woman With Hair" collapsed into plain "Woman" (2026-08-19) -- see
    -- Config.FEMALE_CHARACTER_PARAMS' own "Woman" entry comment for why they became identical.
    "Woman Base 1",           "Woman Base 2",
    "Merchant Base 1",        "Merchant Base 2",
    "Letty Base 1",           "Letty Base 2",
    "Marita Base 1",          "Marita Base 2",
}

------------------------------------------------------------
-- WALKING WOMEN — NOT VIABLE (concluded 2026-07-06). The only dressed
-- walking women are UNIQUE story NPCs, all unusable as ambient spawns:
--   • Rosalinda Mercer (hireable employee) → duplicates the one already in
--     your base. Removed at RedFalcon's request.
--   • Letty (QuestStatic) → spawns WITH her quest dialogue attached.
-- Procedural Citizen_Walker is male-locked (re-randomizes to TortugaCitizen
-- male). ⇒ female presence comes ONLY from posed FACTION_STATUES (below,
-- incl. the Brethren woman). Their class paths are kept here for reference:
--   Rosalinda: /…/Employee/AlchemyStation/BP_NPC_Employee_AlchemyStation_RosalindaMercer…_C
--   Letty:     /…/QuestStatic/BP_NPC_QuestStatic_Letty.BP_NPC_QuestStatic_Letty_C
------------------------------------------------------------
-- Handyman AI controller — walks + has an idle-sit behavior (Rosalinda's
-- controller, via F11). CONFIRMED 2026-07-06: citizens spawned with this
-- brain WALK AND SIT on nearby furniture. (Note: does NOT override a
-- QuestStatic NPC like Letty — those keep their own controller.)
Config.HANDYMAN_AI_CLASS =
  "/Game/Gameplay/Character/AI/NPC/Handyman/Base/Behavior/BP_NPC_AIController_Handyman.BP_NPC_AIController_Handyman_C"

-- Give placed NPCs the Handyman brain so they wander AND use furniture.
-- NOTE: works on CITIZENS (they wander + idle-sit) but NOT crew — crew given
-- this brain just stand there (their pawn lacks the worker data it needs), so
-- keep crew on their own AI. Furniture use only fires when a citizen idles
-- NEAR a seat; they don't path across the base to find one.
Config.HANDYMAN_FOR_TOWNSFOLK = true   -- citizens wander + sit if near furniture
Config.HANDYMAN_FOR_CREW      = false  -- crew use their own AI (Handyman freezes them)

-- Persistence is handled entirely mod-side: every spawn is recorded to persist.txt and
-- re-created on world load (the game does not save our runtime actors). Clean-house (DEL)
-- destroys tracked + ledgered instances by exact path and clears the file. No actor tagging
-- or registrator-stripping — those earlier approaches are gone.

-- Hide the floating nameplate on our spawns by DESTROYING the marker
-- component (a clean component-destroy — NOT the FText writes that likely
-- crashed). Removes named-NPC nameplates (e.g. Marita/Letty) so they read
-- as anonymous residents. No-op on actors without a marker.
-- ON: destroys the R5Marker component (the version that worked pre-v0.38).
-- Safe now that persistence is mod-side. Hides the 'provisioner'/'bounty
-- agent' merchant tags and named-NPC nameplates.
Config.HIDE_NAMEPLATES = true

-- Strip the interaction-target components so spawns can't be "talked to" and
-- show no mouseover/look-at name or prompt. This is what removes the name on
-- QuestStatic NPCs (e.g. Marita) that the nameplate-destroy can't touch. No-op
-- on actors without interaction. Applied to every spawn (incl. restores).
Config.STRIP_INTERACTION = true

-- GENERALIZE quest NPCs: destroy the R5ScenarioComponent (class
-- /Script/R5.R5ScenarioComponent_ForIslandActor) so a placed QuestStatic NPC (Letty, Francois Arno)
-- doesn't retain their live quest dialogue. Found via live probing (2026-08-07, see the "HOME/PAUSE
-- probe + dump_object" session): a QuestStatic NPC still showed her nameplate AND "[E] Talk" prompt
-- live in-game despite STRIP_INTERACTION -- tracing the interaction chain (R5CommonInteractionTarget
-- -> Params -> Options[0] "Speak" -> R5Ability_InteractOption_ScenarioDispencer) led to this SEPARATE
-- component, not either of the two STRIP_INTERACTION already destroys. Its ScenarioSettings/Executor
-- point at a NAMED dialogue graph (e.g. DA_ScSettings_Dialogue_NPC_Shared_Letty_MainGraph for Letty)
-- -- that's the actual mechanism tying a placed NPC to their live quest identity. A separate flag
-- from STRIP_INTERACTION on purpose: this is a NEW, not-yet-battle-tested component destroy (unlike
-- the interaction-target strip, which has run on every spawn for a long time) -- set false here if
-- it turns out to misbehave, without losing the interaction strip that's proven fine.
Config.STRIP_QUEST_SCENARIO = true

------------------------------------------------------------
-- PLACEMENT: posed statues + ground snap + nameplates
------------------------------------------------------------
-- Ground placement is done per-actor by a BOUNDS SNAP (measure the actor,
-- drop it so its bounding-box bottom rests on the floor) — a fixed offset
-- can't work because posed actors have different pivots (some at the head,
-- which is why women buried head-up). This is a fallback nudge only if the
-- bounds snap is unavailable; 0 = spawn at player height (float, not bury).
Config.STATUE_GROUND_OFFSET = 0

------------------------------------------------------------
-- STATUE LINEUPS. One statue per press, cycled (numpad keys):
--   Num3 = STANDING_STATUES (incl. women + quest folk) · Num4 = SEATED_STATUES
--   Num5 = CHAIR_STATUES · Num6 = INTERACTIVE_STATUES
-- Curated by RedFalcon from the Tortuga capture pass (leaning + hand-warming poses cut).
------------------------------------------------------------
Config.STANDING_STATUES = {
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Female_Standing_01.BP_AnimatedActor_BotC_Female_Standing_01_C" },  -- BotC_Female_Standing_01
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Merchant_01.BP_AnimatedActor_BotC_Merchant_01_C" },  -- BotC_Merchant_01
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Merchant_02.BP_AnimatedActor_BotC_Merchant_02_C" },  -- BotC_Merchant_02
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Merchant_03.BP_AnimatedActor_BotC_Merchant_03_C" },  -- BotC_Merchant_03
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_Chat_01.BP_AnimatedActor_BotC_Sailor_Chat_01_C" },  -- BotC_Sailorhat_01
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Merchant_01.BP_AnimatedActor_Buccaneers_Merchant_01_C" },  -- Buccaneers_Merchant_01
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Merchant_03.BP_AnimatedActor_Buccaneers_Merchant_03_C" },  -- Buccaneers_Merchant_03
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Merchant_04.BP_AnimatedActor_Buccaneers_Merchant_04_C" },  -- Buccaneers_Merchant_04
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Merchant_01.BP_AnimatedActor_Smugglers_Merchant_01_C" },  -- Smugglers_Merchant_01
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Merchant_01.BP_AnimatedActor_TortugaCitizen_Merchant_01_C" },  -- TortugaCitizen_Merchant_01
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Combatant_CrossHands.BP_AnimatedActor_TortugaCitizen_Combatant_CrossHands_C" },  -- TortugaCitizenombatantrossHands

  -- ---- New poses (probed 2026-07-10): leaning on a wall, warming by a fire, working (CarpenterIdle) ----
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sergeant_LeanOnWall.BP_AnimatedActor_BotC_Sergeant_LeanOnWall_C" },  -- LeanOnWall
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Combatant_LeanOnWall.BP_AnimatedActor_TortugaCitizen_Combatant_LeanOnWall_C" },  -- LeanOnWall
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Theif_LeanOnWallCrossHands.BP_AnimatedActor_Smugglers_Theif_LeanOnWallCrossHands_C" },  -- LeanOnWall (cross-hands)
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Trapper_LeanOnWall.BP_AnimatedActor_Buccaneers_Trapper_LeanOnWall_C" },  -- LeanOnWall
  -- ---- More pose variants (probed 2026-07-10) ----
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_LeanOnWall.BP_AnimatedActor_BotC_Sailor_LeanOnWall_C" },  -- LeanOnWall
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Runner_LeanOnWall.BP_AnimatedActor_Smugglers_Runner_LeanOnWall_C" },  -- LeanOnWall
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Musketeer_CarpenterIdle.BP_AnimatedActor_BotC_Musketeer_CarpenterIdle_C" },  -- CarpenterIdle
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_CarpenterIdle.BP_AnimatedActor_BotC_Sailor_CarpenterIdle_C" },  -- CarpenterIdle
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Combatant_CarpenterIdle.BP_AnimatedActor_TortugaCitizen_Combatant_CarpenterIdle_C" },  -- CarpenterIdle
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Trapper_CarpenterIdle.BP_AnimatedActor_Buccaneers_Trapper_CarpenterIdle_C" },  -- CarpenterIdle
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Dogface_CarpenterIdle.BP_AnimatedActor_TortugaCitizen_Dogface_CarpenterIdle_C" },  -- CarpenterIdle
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Shooter_CarpenterIdle.BP_AnimatedActor_TortugaCitizen_Shooter_CarpenterIdle_C" },  -- CarpenterIdle

  -- QUEST FOLK folded into STANDING (2026-07-10) to free their own key. They are QuestStatic NPCs:
  -- they stand in place (already statue-like) and keep their name + quest dialogue. Their originals
  -- live in Tortuga so a base copy doesn't clash. Cycled here like any other standing statue.
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/QuestStatic/BP_NPC_QuestStatic_BotC_FrancoisArno.BP_NPC_QuestStatic_BotC_FrancoisArno_C" },  -- Francois Arno
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/QuestStatic/BP_NPC_QuestStatic_Letty.BP_NPC_QuestStatic_Letty_C" },  -- Letty

  -- Faction leaders / prominent quest-givers (added 2026-08-07, found via Manifest_UFSFiles_Win64.txt
  -- rather than a live encounter -- see DA_ScSettings_Dialogue_NPC_Shared_*_MainGraph asset paths for
  -- confirmation each is a genuine dialogue character, same STRIP_QUEST_SCENARIO generalization as
  -- Letty/Francois Arno applies to all QuestStatic spawns automatically.
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/QuestStatic/BP_NPC_QuestStatic_BotC_BenjaminHornigold.BP_NPC_QuestStatic_BotC_BenjaminHornigold_C" },  -- Benjamin Hornigold
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/QuestStatic/BP_NPC_QuestStatic_Buccaneers_HenriBoucher.BP_NPC_QuestStatic_Buccaneers_HenriBoucher_C" },  -- Henri Boucher
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/QuestStatic/BP_NPC_QuestStatic_Smugglers_MaritaSuares.BP_NPC_QuestStatic_Smugglers_MaritaSuares_C" },  -- Marita Suares
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/QuestStatic/BP_NPC_QuestStatic_TortugaCitizen_LongBen.BP_NPC_QuestStatic_TortugaCitizen_LongBen_C" },  -- Long Ben
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/QuestStatic/BP_NPC_QuestStatic_TortugaCitizen_CharlieSharp.BP_NPC_QuestStatic_TortugaCitizen_CharlieSharp_C" },  -- Charlie Sharp

  -- Num2/3/4/5/6 manifest audit (2026-08-07): diffed every AnimatedActor blueprint in each faction's
  -- folder against everything already referenced anywhere in this file -- these were shipped but
  -- never wired in. Merchant/LeanOnWall variants are siblings to ones already present. DrunkCanoneer
  -- (a real gap, flagged earlier this session) turned out to be a CHAIR-sitting pose, and
  -- Smugglers_Merchant_04 a GROUND-sitting pose -- neither name/path gave any hint of that -- both
  -- confirmed live 2026-08-07 and moved to CHAIR_STATUES / SEATED_STATUES respectively.
  -- BotC_Merchant_04: intended as the female Brethren merchant, but confirmed live 2026-08-07 to be a
  -- male body under the women's clothing -- a baked-in quirk of this specific game asset (this is a
  -- plain AnimatedActor spawn, no compositeLook involved, so nothing on our end causes or can fix
  -- this). Left in deliberately at the user's request -- may be intentional on Windrose's part, and
  -- the walking faction-visitor crew's own "woman" look (Config.FACTION_VISITOR_LOOKS) has the exact
  -- same mismatch, so it's not unique to this entry.
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Merchant_04.BP_AnimatedActor_BotC_Merchant_04_C" },  -- BotC_Merchant_04
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Jager_LeanOnWall.BP_AnimatedActor_Buccaneers_Jager_LeanOnWall_C" },  -- Buccaneers_Jager_LeanOnWall
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Merchant_02.BP_AnimatedActor_Buccaneers_Merchant_02_C" },  -- Buccaneers_Merchant_02
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Merchant_02.BP_AnimatedActor_Smugglers_Merchant_02_C" },  -- Smugglers_Merchant_02
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Merchant_03.BP_AnimatedActor_Smugglers_Merchant_03_C" },  -- Smugglers_Merchant_03
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Merchant_02.BP_AnimatedActor_TortugaCitizen_Merchant_02_C" },  -- TortugaCitizen_Merchant_02
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Merchant_03.BP_AnimatedActor_TortugaCitizen_Merchant_03_C" },  -- TortugaCitizen_Merchant_03
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Merchant_04.BP_AnimatedActor_TortugaCitizen_Merchant_04_C" },  -- TortugaCitizen_Merchant_04
}


-- Posed statues let PLACED FURNITURE overlap them (so a stool tucks under a sitter) while still
-- blocking walking characters. Applied to any spawned AnimatedActor (standing / seated / interactive)
-- on both fresh placement and restore. See Spawner.LetFurniturePass. Set false to restore full
-- statue collision (furniture would then be blocked from sharing their footprint).
Config.STATUE_IGNORE_FURNITURE = true

-- Seated figures, cycled one per F4 press.
--
-- NO FURNITURE IS EVER SPAWNED HERE. The seated cycler hands {faction, path} to spawnPosed()
-- with a nil `furniture` arg, so the figure lands alone; RedFalcon places the stool/table/bench
-- themselves in-game. Do not add a `furniture` key to these entries — that would re-enable the
-- stool injection they explicitly asked us to leave out.
--
-- Two pose families live here (table sitters added 2026-07-10):
--   *_SitterOnGround / *_LayOnGround  — floor poses, need nothing under them.
--   *_SitterOnStool / *_Sitting_0*    — the tavern-table figures from Tortuga. They are posed at
--                                       SEAT height, so they hang in the air until RedFalcon puts a
--                                       stool under them. That is intended, not a bug.
-- Every path below was read out of discovery_dump.txt / scene_dump.txt — none are guessed.
Config.SEATED_STATUES = {
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActorVoiced_TortugaCitizen_Combatant_TiredSoldier.BP_AnimatedActorVoiced_TortugaCitizen_Combatant_TiredSoldier_C" },  -- TiredSoldier
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_SitterOnGround_01.BP_AnimatedActor_BotC_Sailor_SitterOnGround_01_C" },  -- BotC_Sailor_SitterOnGround_01
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_SitterOnGround_02.BP_AnimatedActor_BotC_Sailor_SitterOnGround_02_C" },  -- BotC_Sailor_SitterOnGround_02
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_SitterOnGround_03.BP_AnimatedActor_BotC_Sailor_SitterOnGround_03_C" },  -- BotC_Sailor_SitterOnGround_03
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_SitterOnGround_04.BP_AnimatedActor_BotC_Sailor_SitterOnGround_04_C" },  -- BotC_Sailor_SitterOnGround_04
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Jager_SitterOnGround.BP_AnimatedActor_Buccaneers_Jager_SitterOnGround_C" },  -- Buccaneers_Jager_SitterOnGround
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Trapper_SitterOnGround_03.BP_AnimatedActor_Buccaneers_Trapper_SitterOnGround_03_C" },  -- Buccaneers_Trapper_SitterOnGround_03
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Theif_SitterOnGround_01.BP_AnimatedActor_Smugglers_Theif_SitterOnGround_01_C" },  -- Smugglers_Theif_SitterOnGround_01
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Theif_SitterOnGround_02.BP_AnimatedActor_Smugglers_Theif_SitterOnGround_02_C" },  -- Smugglers_Theif_SitterOnGround_02
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Theif_SitterOnGround_03.BP_AnimatedActor_Smugglers_Theif_SitterOnGround_03_C" },  -- Smugglers_Theif_SitterOnGround_03
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Combatant_SitterOnGround.BP_AnimatedActor_TortugaCitizen_Combatant_SitterOnGround_C" },  -- TortugaCitizenombatant_SitterOnGround
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Dogface_LayOnGround.BP_AnimatedActor_TortugaCitizen_Dogface_LayOnGround_C" },  -- TortugaCitizen_Dogface_LayOnGround
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnGround_01.BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnGround_01_C" },  -- TortugaCitizen_Dogface_SitterOnGround_01
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnGround_02.BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnGround_02_C" },  -- TortugaCitizen_Dogface_SitterOnGround_02
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Combatant_LayOnGround.BP_AnimatedActor_TortugaCitizen_Combatant_LayOnGround_C" },  -- Combatant_LayOnGround (probed 2026-07-10)
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Theif_LayOnGround.BP_AnimatedActor_Smugglers_Theif_LayOnGround_C" },  -- Theif_LayOnGround
  -- Manifest audit (2026-08-07): missing SitterOnGround sibling to the two already present.
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnGround_03.BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnGround_03_C" },  -- TortugaCitizen_Dogface_SitterOnGround_03
  -- Moved here from STANDING_STATUES (2026-08-07): a ground-sitting pose despite the "Merchant"
  -- name giving no hint of that -- confirmed live during testing.
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Merchant_04.BP_AnimatedActor_Smugglers_Merchant_04_C" },  -- Smugglers_Merchant_04
}

-- CHAIR / STOOL sitters (own key NUM_FIVE, 2026-07-10). Split out of SEATED_STATUES because these
-- are posed at SEAT height and hang in the air until you place a stool/chair under them, whereas the
-- SEATED list above sits flat on the ground. NO furniture is spawned — you build the seat yourself,
-- and STATUE_IGNORE_FURNITURE lets it slide right under. Every path verified in the world dumps.
Config.CHAIR_STATUES = {
  { yaw = 180.0, faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_SitterOnStool.BP_AnimatedActor_BotC_Sailor_SitterOnStool_C" },  -- BotC_Sailor_SitterOnStool
  { yaw = 180.0, faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Musketeer_SitterOnStool_01.BP_AnimatedActor_BotC_Musketeer_SitterOnStool_01_C" },  -- BotC_Musketeer_SitterOnStool_01
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Musketeer_SitterOnStool_02.BP_AnimatedActor_BotC_Musketeer_SitterOnStool_02_C" },  -- BotC_Musketeer_SitterOnStool_02
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Female_Sitting_01.BP_AnimatedActor_BotC_Female_Sitting_01_C" },  -- BotC_Female_Sitting_01
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Female_Sitting_02.BP_AnimatedActor_BotC_Female_Sitting_02_C" },  -- BotC_Female_Sitting_02
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Female_Sitting_03.BP_AnimatedActor_BotC_Female_Sitting_03_C" },  -- BotC_Female_Sitting_03
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Jager_SitterOnStool_02.BP_AnimatedActor_Buccaneers_Jager_SitterOnStool_02_C" },  -- Buccaneers_Jager_SitterOnStool_02
  { yaw = 180.0, faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Marksman_SitterOnStool.BP_AnimatedActor_Buccaneers_Marksman_SitterOnStool_C" },  -- Buccaneers_Marksman_SitterOnStool
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Marksman_SitterOnStool_02.BP_AnimatedActor_Buccaneers_Marksman_SitterOnStool_02_C" },  -- Buccaneers_Marksman_SitterOnStool_02
  { yaw = 180.0, faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Trapper_SitterOnStool.BP_AnimatedActor_Buccaneers_Trapper_SitterOnStool_C" },  -- Buccaneers_Trapper_SitterOnStool
  { yaw = 180.0, faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Trapper_SitterOnStool_03.BP_AnimatedActor_Buccaneers_Trapper_SitterOnStool_03_C" },  -- Buccaneers_Trapper_SitterOnStool_03
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Hitman_SitterOnStool_02.BP_AnimatedActor_Smugglers_Hitman_SitterOnStool_02_C" },  -- Smugglers_Hitman_SitterOnStool_02
  { yaw = 180.0, faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Runner_SitterOnStool.BP_AnimatedActor_Smugglers_Runner_SitterOnStool_C" },  -- Smugglers_Runner_SitterOnStool
  { yaw = 180.0, faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Theif_SitterOnStool.BP_AnimatedActor_Smugglers_Theif_SitterOnStool_C" },  -- Smugglers_Theif_SitterOnStool
  { yaw = 180.0, faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Combatant_SitterOnStool.BP_AnimatedActor_TortugaCitizen_Combatant_SitterOnStool_C" },  -- TortugaCitizen_Combatant_SitterOnStool
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Combatant_SitterOnStool_02.BP_AnimatedActor_TortugaCitizen_Combatant_SitterOnStool_02_C" },  -- TortugaCitizen_Combatant_SitterOnStool_02
  { yaw = 180.0, faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnStool.BP_AnimatedActor_TortugaCitizen_Dogface_SitterOnStool_C" },  -- TortugaCitizen_Dogface_SitterOnStool
  { yaw = 180.0, faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Shooter_SitterOnStool_01.BP_AnimatedActor_TortugaCitizen_Shooter_SitterOnStool_01_C" },  -- TortugaCitizen_Shooter_SitterOnStool_01
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Shooter_SitterOnStool_02.BP_AnimatedActor_TortugaCitizen_Shooter_SitterOnStool_02_C" },  -- TortugaCitizen_Shooter_SitterOnStool_02
  -- Moved here from STANDING_STATUES (2026-08-07): a CHAIR/STOOL-sitting pose despite the name
  -- giving no hint of that -- confirmed live during testing. No yaw override yet; report back if it
  -- needs one once you've placed a stool under it.
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActorVoiced_TortugaCitizen_Dogface_DrunkCanoneer.BP_AnimatedActorVoiced_TortugaCitizen_Dogface_DrunkCanoneer_C" },  -- DrunkCanoneer
}

-- Interactive: figures rifling through a chest/equipment. RedFalcon free-places the props
-- (barrels/chests) around them, so no furniture is spawned.
Config.INTERACTIVE_STATUES = {
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Shooter_LookerChest.BP_AnimatedActor_TortugaCitizen_Shooter_LookerChest_C" },  -- Shooter (Tortuga)
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Dogface_LookerChest.BP_AnimatedActor_TortugaCitizen_Dogface_LookerChest_C" },  -- Dogface (Tortuga)
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Trapper_LookerChest.BP_AnimatedActor_Buccaneers_Trapper_LookerChest_C" },  -- Trapper (Buccaneer)
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Theif_LookerChest.BP_AnimatedActor_Smugglers_Theif_LookerChest_C" },  -- Theif (Smuggler)
  -- Rummaging a table of goods (probed 2026-07-10) — same "going through stuff" theme as the chest lookers.
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Trapper_LookerTable.BP_AnimatedActor_Buccaneers_Trapper_LookerTable_C" },  -- Trapper LookerTable
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Musketeer_LookerChest.BP_AnimatedActor_BotC_Musketeer_LookerChest_C" },  -- Musketeer LookerChest
  -- FireWarm (warming hands by a fire) — moved here from STANDING per RedFalcon (it's an interaction pose).
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_FireWarm.BP_AnimatedActor_BotC_Sailor_FireWarm_C" },  -- FireWarm
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sergeant_FireWarm.BP_AnimatedActor_BotC_Sergeant_FireWarm_C" },  -- FireWarm
  { faction = "Buccaneers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Buccaneers/AnimatedActor/BP_AnimatedActor_Buccaneers_Marksman_FireWarm.BP_AnimatedActor_Buccaneers_Marksman_FireWarm_C" },  -- FireWarm
  { faction = "Smugglers", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/Smugglers/AnimatedActor/BP_AnimatedActor_Smugglers_Theif_FireWarm.BP_AnimatedActor_Smugglers_Theif_FireWarm_C" },  -- FireWarm
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Dogface_FireWarm.BP_AnimatedActor_TortugaCitizen_Dogface_FireWarm_C" },  -- FireWarm
  -- Manifest audit (2026-08-07): missing LookerTable/FireWarm siblings to ones already present.
  { faction = "Brethren of the Coast", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/BrethrenOfTheCoast/AnimatedActor/BP_AnimatedActor_BotC_Sailor_LookerTable.BP_AnimatedActor_BotC_Sailor_LookerTable_C" },  -- BotC_Sailor_LookerTable
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Combatant_FireWarm.BP_AnimatedActor_TortugaCitizen_Combatant_FireWarm_C" },  -- TortugaCitizen_Combatant_FireWarm
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Dogface_LookerTable.BP_AnimatedActor_TortugaCitizen_Dogface_LookerTable_C" },  -- TortugaCitizen_Dogface_LookerTable
  { faction = "People of Tortuga", path = "/Game/Gameplay/Character/AI/NPC/FactionActors/TortugaCitizen/AnimatedActor/BP_AnimatedActor_TortugaCitizen_Shooter_FireWarm.BP_AnimatedActor_TortugaCitizen_Shooter_FireWarm_C" },  -- TortugaCitizen_Shooter_FireWarm
}



------------------------------------------------------------------
-- BOAR WHISTLE -> CREW ESCORT (anchor method).
-- There is NO UR5PetSummonParams in this game; the whistle spawns BP_Mob_Boar_Friend directly.
-- Confirmed by our own probe AND by the PlagueWitchPet Nexus mod, whose pak replaces exactly
-- BP_Mob_Boar_Friend.uasset and touches no summon params. Overwriting the pet needs a cooked pak,
-- which Lua cannot do -- so we let the game summon its boar, turn that boar into an invisible,
-- collision-free, damage-immune ANCHOR, and spawn crew beside it. The anchor keeps holding the pet
-- timer, the item cooldown, and the dismiss/re-summon bookkeeping; we never fight that logic.
-- When the anchor dies, the escort is dismissed with it.
-- Detection is free: NotifyOnNewObject fires the instant the boar is constructed (technique learned
-- from PlagueWitchPet_FollowHelper). Only the BASE tier is touched; Lvl2 is left alone.
------------------------------------------------------------------
Config.WHISTLE_CREW = false        -- SHIPPED DEFAULT: OFF. Enable in config.txt.
Config.WHISTLE_PET_CLASS_PATH =
  "/Game/Gameplay/Character/AI/Mob/Boar/Friend/BP_Mob_Boar_Friend.BP_Mob_Boar_Friend_C"
Config.WHISTLE_CREW_CLASS =
  "/Game/Gameplay/Character/AI/Crew/Regular/Faction/Player/BP_Mob_Crew_Regular_Player.BP_Mob_Crew_Regular_Player_C"
Config.WHISTLE_CREW_COUNT = 2
-- Two composite builds in ONE frame is a native crash -- that is why SPAWN_DEBOUNCE_MS exists and
-- why the restore staggers every AI spawn. 250ms is imperceptible. Set 0 to force same-frame.
Config.WHISTLE_CREW_STAGGER_MS = 250
Config.WHISTLE_CREW_SPREAD_UU = 120   -- fan them out either side of the anchor
-- Drives both the "is the pet still summoned?" check and the follow order. 1s is a comfortable
-- re-issue cadence for SimpleMoveToActor without spamming the navigation system.
Config.WHISTLE_ANCHOR_CHECK_MS = 1000
-- ⚠ NEVER make the anchor damage-immune. GE_Mob_Boar_Friend_KillTimer ends the pet by DEALING
-- DAMAGE, so immunity stops the timer dead: v2.22 left RedFalcon with a permanent invisible Truffles
-- and an escort that was never dismissed. The anchor must stay mortal — that IS the mechanism.
-- Instead we hide it, kill its collision, strip its senses, and remove its nameplate/health bar.

-- ⚠ WHISTLE_PET_AI FROZE THEM (2026-07-10, confirmed in-game). Giving crew the boar's pet
-- controller is a cross-species brain swap, and our goat notes already recorded that a mismatched
-- controller freezes pawns. The PlagueWitchPet mod never had to solve this: its pak REPLACES
-- BP_Mob_Boar_Friend in place, so its pet keeps the pet's own AI. We cannot cook a pak. Leave OFF.
Config.WHISTLE_PET_AI = false

-- FOLLOW instead: keep the crew's own controller (so they still fight) and simply hand it a
-- destination on a slow tick — UAIBlueprintHelperLibrary::SimpleMoveToActor(controller, player).
-- Emergency warp when they fall hopelessly behind: the PlagueWitchPet mod does exactly this for its
-- own pets at 80m, which is a good sign it's the pragmatic answer rather than a hack.
-- ⚠ WINDROSE USES MERCUNA NAVIGATION, NOT THE UE NAVMESH. Every AI pawn carries a
-- MercunaGroundNavigationComponent. UAIBlueprintHelperLibrary::SimpleMoveToActor posts into the
-- stock nav system, which these pawns never read — it neither throws nor fails, it just does
-- nothing. The log happily said "move order issued" every second while the escort wandered 65m
-- away. Drive Mercuna instead:
--   UR5MercunaGroundNavigationComponent::MoveToActor(AActor*, float EndDistance, float Speed,
--                                                    bool UsePartialPath)
-- Mercuna also ships TrackActor(Actor, Distance, Speed, Offset, UsePartialPath) — a CONTINUOUS
-- follow, which is what we actually wanted. Spawner.Follow() issues it once rather than re-issuing
-- a one-shot move every tick (which can restart pathfinding before the pawn takes a single step).
Config.FOLLOW_END_UU = 300.0     -- trail ~3m behind the player, not on top of him
-- ⚠ SPEED MUST BE NON-ZERO. In-game (2026-07-10) the escort held a stable, valid Mercuna path for
-- 4+ seconds straight — GetRemainingPathLength returned the exact 25m to the player — while
-- distance never changed and the pawn only ROTATED to face us. Mercuna was steering (facing) but
-- translating at ~0. The one difference between our order and the crew's OWN brain (which walks
-- them around this same component at full speed) is the Speed arg: I had passed 0 on the belief
-- that "0 = max speed" (standard Mercuna). This build takes 0 LITERALLY — steer, don't move. So
-- pass a real speed. In-game 550 followed at a WALK — they kept up only when RedFalcon walked. He moves
-- faster than that, so they lagged. Raise it so they can keep his pace. NOTE: this is capped by the
-- pawn's own CharacterMovementComponent max speed — if they still top out at a walk, the cap is the
-- movement component (their run gait), not this number, and we'd raise MaxWalkSpeed next.
Config.FOLLOW_SPEED = 900.0
Config.FOLLOW_PARTIAL = true     -- accept a partial path rather than refusing to move

-- ⚠ THE REAL SPEED CAP is the pawn's CharacterMovement.MaxWalkSpeed, NOT the Mercuna Speed arg.
-- In-game the escort held a flat ~110 uu/s no matter whether FOLLOW_SPEED was 550 or 900 — a slow
-- walk — because Mercuna can't push a character past its own movement-component max. So we RAISE
-- MaxWalkSpeed to track the player's pace: crew speed = clamp(player_speed + margin, min, max),
-- re-applied every follow tick (in case a gait system resets it). This is what actually makes them
-- keep up. FOLLOW_SPEED above stays high so Mercuna never clamps BELOW MaxWalkSpeed.
Config.FOLLOW_MATCH_PACE = true
Config.FOLLOW_PACE_MARGIN = 300.0   -- move this much faster than the player, to close/hold the gap
Config.FOLLOW_SPEED_MIN = 700.0     -- never crawl. DIAGNOSTIC (v2.50): MaxWalkSpeed set fine (350 read
                                    -- back) but they CRUISED at only ~220 -- below the cap -- so the
                                    -- limiter is Mercuna's commanded speed / acceleration, not the cap.
                                    -- Raised the floor + the multiplier below to push the cruise up.
-- Out of combat the crew keep their WALK gait (they only ran, and matched pace, IN combat). Raising
-- MaxWalkSpeed doesn't help because the walk gait's own desired speed caps them ~110. So multiply
-- their speed while following via CheatMovementSpeedModifer (reset to 1.0 when they arrive/fight).
-- ~3x turned the walk into ~220uu/s (2x-ish), still slow. Pushing harder; drives both the movement
-- component's CheatMovementSpeedModifer AND Mercuna's OverrideSpeedMultiplier. Lower if they foot-slide.
Config.FOLLOW_SPEED_MULT = 6.0
Config.FOLLOW_SPEED_MAX = 900.0     -- ceiling (a sprint) so they can catch up but not teleport-slide

-- FOLLOW PRIORITY: "follow me over anything except actively fighting." We do NOT stop their brain
-- (that froze them before). Instead: (a) when a crew member is engaging ANY hostile, follow YIELDS
-- for that member so its combat AI runs (detected per-pawn via Spawner.IsFighting — the enemy it's
-- already targeting, so it covers every hostile, not a fixed class list); (b) otherwise follow is
-- ASSERTIVE — if the StateTree wanders it off (velocity pointing AWAY from you for 2 ticks), we
-- re-issue the follow instead of waiting for the path to die.
Config.FOLLOW_ASSERTIVE = true

-- Auto-stop the pawn's StateTree when it stalls. TESTED 2026-07-10 and it did NOT help: stopping
-- the StateTree stabilised the path (the flicker stopped) but the pawn STILL didn't translate, so
-- the StateTree was never the blocker (Speed=0 was). Worse, the StateTree is the likely LOCOMOTION
-- APPLIER — the thing that consumes Mercuna's steering and drives the character — so stopping it is
-- probably exactly wrong. Default OFF now; the speed fix is tried WITH the brain running. The lever
-- stays wired in case the StateTree turns out to fight a correctly-sped order.
Config.FOLLOW_AUTOSTOP_LOGIC = false
Config.FOLLOW_STALL_TICKS = 3

Config.WHISTLE_FOLLOW = true
Config.WHISTLE_FOLLOW_START_UU = 700    -- start walking to you beyond ~7m
Config.WHISTLE_WARP_UU = 8000           -- ~80m: stuck on nav / through geometry -> teleport
Config.WHISTLE_WARP_RING_UU = 500       -- land them ~5m around you
-- "Didn't follow, didn't warp" is useless feedback: the warp is pure arithmetic, no AI and no engine
-- call, so if it never fired then followTick never ran or the escort was never recorded. This makes
-- each tick report exactly where it stops (no player / empty crew / no controller / lib missing).
Config.WHISTLE_FOLLOW_DEBUG = false
-- If their own StateTree re-issues a destination every tick it will stomp our move order and they'll
-- just wander (which is what "walk around like normal crew" looks like). AR5AIController exposes
-- StopLogic()/StartLogic(); silencing the brain while they're far away makes our order stick, and we
-- give it back once they reach you so they fight again. Opt-in until the debug output confirms.
Config.WHISTLE_FOLLOW_STOP_LOGIC = false
Config.WHISTLE_PET_AI_CLASS =
  "/Game/Gameplay/Character/AI/Mob/Boar/Friend/Behavior/BP_Mob_AIController_Boar_Friend.BP_Mob_AIController_Boar_Friend_C"

-- CASTER TOTEMS. Her witch totems are separate actors that never inherit her friendly faction, so
-- they attack the player. Stripping abilities by GUESSED name removed nothing ("removed ability"
-- appears 0 times in the log). The real class path (note the game's own typo, "Reglar") came from
-- the PlagueWitchPet mod, so we simply destroy each totem as it spawns. Her AoE is untouched.
Config.CASTER_KILL_TOTEMS = true
Config.CASTER_TOTEM_CLASS_PATH =
  "/Game/Gameplay/Character/AI/Mob/SenkamatiCorrupted/Regular_Shaman_Caster/Totem/BP_Mob_SenkamatiCorrupted_Reglar_Shaman_Caster_Totem.BP_Mob_SenkamatiCorrupted_Reglar_Shaman_Caster_Totem_C"

------------------------------------------------------------------
-- Config.CUSTOM_POSES (2026-08-27) -- flat pose roster imported from Other\Poses.xlsx,
-- built by RedFalcon while live-testing lbtestpose across the full asset catalog. One row per
-- confirmed-testable animation: `path` is the /Game/... asset (the argument half of the
-- `lbtestpose <path>` command actually run to verify it), `topCategory`/`subCategory` (nil when
-- a sheet had no subcategory column) build the Custom > Poses > ... branch in spawn_menu.ini via
-- spawnmenu_manifest.lua's CUSTOM_POSES descriptor, `name` is the display leaf. Order preserved
-- exactly as authored: sheet order (Standing, SittingKneeling, Work Benches, Battle, Magical,
-- Monsterous, Statues, Misc), then row order within each sheet -- this is also the ROSTER INDEX
-- spawn_menu.ini's `index = N` values point back into, so don't reorder rows once entries exist
-- in that file (same append-only discipline every other roster here already follows).
Config.CUSTOM_POSES = {
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Victory/AM_Regular_Male_NPC_ShipCrew_Boarding_Victory_001", topCategory = "Standing", subCategory = "Cheer", name = "Cheer 1" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Victory/AM_Regular_Male_NPC_ShipCrew_Boarding_Victory_002", topCategory = "Standing", subCategory = "Cheer", name = "Cheer 2" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Victory/AM_Regular_Male_NPC_ShipCrew_Boarding_Victory_003", topCategory = "Standing", subCategory = "Cheer", name = "Cheer 3" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Victory/AM_Regular_Male_NPC_ShipCrew_Boarding_Victory_004", topCategory = "Standing", subCategory = "Cheer", name = "Cheer 4" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Victory/AM_Regular_Male_NPC_ShipCrew_Boarding_Victory_005", topCategory = "Standing", subCategory = "Cheer", name = "Cheer 5" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Consumables/Eating/AM_Regular_Male_Hero_Eating_Coconut", topCategory = "Standing", subCategory = "Food and Meds", name = "Eat Coconut" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Consumables/Eating/AM_Regular_Male_Hero_Eating_Meat", topCategory = "Standing", subCategory = "Food and Meds", name = "Eat Meat" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Consumables/Eating/AM_Regular_Male_Hero_Eating_Soup", topCategory = "Standing", subCategory = "Food and Meds", name = "Eat Soup" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Consumables/Pills/AM_Regular_Male_Hero_Axe_Armed_Pills", topCategory = "Standing", subCategory = "Food and Meds", name = "Fast Drink" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Consumables/Salve/AM_Regular_Male_Hero_Salve", topCategory = "Standing", subCategory = "Food and Meds", name = "Slather in Salve" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Consumables/Potion/AM_Regular_Male_Hero_Axe_Armed_Potion", topCategory = "Standing", subCategory = "Food and Meds", name = "Slow Drink" },
  { path = "/Game/Character/Animations/Human/Regular/BlackBeard/Other/A_Regular_PrisonerStand2_Idle", topCategory = "Standing", subCategory = "Hang", name = "Hang From Shackles" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Shroud/A_Regular_Male_NPC_ShipCrew_Shroud_HangForFrigat_LeftSide_Cycle", topCategory = "Standing", subCategory = "Hang", name = "Hang on Pole Left 1" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Shroud/AM_Regular_Male_NPC_ShipCrew_Shroud_HangForFrigat_LeftSide", topCategory = "Standing", subCategory = "Hang", name = "Hang on Pole Left 2" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Shroud/A_Regular_Male_NPC_ShipCrew_Shroud_HangForFrigat_RightSide_Cycle", topCategory = "Standing", subCategory = "Hang", name = "Hang on Pole Right 1" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Shroud/AM_Regular_Male_NPC_ShipCrew_Shroud_HangForFrigat_RightSide", topCategory = "Standing", subCategory = "Hang", name = "Hang on Pole Right 2" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Standing_02", topCategory = "Standing", subCategory = "Idle", name = "Regular Idle 1" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/A_Regular_Male_Calm_Idle", topCategory = "Standing", subCategory = "Idle", name = "Regular Idle 2" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/IdleBreak/AM_Regular_Male_Hero_IdleBreak_Neutral", topCategory = "Standing", subCategory = "Idle", name = "Regular Idle 3" },
  { path = "/Game/Character/Animations/Human/Regular/BlackBeard/A_Regular_Male_Scum_IdleBreak_01", topCategory = "Standing", subCategory = "Idle", name = "Regular Idle 4" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Vendors/A_Regular_Male_Vendor02", topCategory = "Standing", subCategory = "Lean", name = "Lean on Table" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Vendors/A_Regular_Male_LongBen_InteractionIdle", topCategory = "Standing", subCategory = "Lean", name = "Long Ben Lean on Counter" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Universal/Lean/A_Regular_Male_NPC_Universal_LeanOnWall_Idle_01_Loop", topCategory = "Standing", subCategory = "Lean", name = "Wall Lean" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Vendors/A_Regular_Male_Vendor03", topCategory = "Standing", subCategory = "Lean", name = "Wall Lean Arms Crossed" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Bulwark/AM_Regular_Male_NPC_ShipCrew_Bulwark_Lean_Relaxed_01", topCategory = "Standing", subCategory = "Lean", name = "Wall Lean Face Front" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Bulwark/AM_Regular_Male_NPC_ShipCrew_Bulwark_Lean_Active_RightSide", topCategory = "Standing", subCategory = "Lean", name = "Wall Lean Face Left" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Bulwark/AM_Regular_Male_NPC_ShipCrew_Bulwark_Lean_Active_LeftSide", topCategory = "Standing", subCategory = "Lean", name = "Wall Lean Face Right" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Vendors/A_Regular_Male_Vendor04", topCategory = "Standing", subCategory = "Stand", name = "Arms Behind Back" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Vendors/A_Regular_Male_Vendor01", topCategory = "Standing", subCategory = "Stand", name = "Arms Tightly Crossed" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Standing_06", topCategory = "Standing", subCategory = "Stand", name = "Benjamin" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/IdleBreak/AM_Regular_Male_Hero_IdleBreak_Snots", topCategory = "Standing", subCategory = "Stand", name = "Blow Out Nose" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Standing_05", topCategory = "Standing", subCategory = "Stand", name = "BotC Merchant" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Standing_07", topCategory = "Standing", subCategory = "Stand", name = "Charlie" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/AM_Regular_Male_Calm_IdleBreak_03", topCategory = "Standing", subCategory = "Stand", name = "Checks Things Out" },
  { path = "/Game/Character/Animations/Human/Regular/BlackBeard/Other/AM_Regular_BoardingEnd_Lose", topCategory = "Standing", subCategory = "Stand", name = "Cowering" },
  { path = "/Game/Character/Animations/Human/Regular/BlackBeard/A_Regular_Male_Scum_IdleBreak_04", topCategory = "Standing", subCategory = "Stand", name = "Dust Off Body" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/AM_Regular_Male_Calm_IdleBreak_04", topCategory = "Standing", subCategory = "Stand", name = "Dusts Legs" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Fists/A_Regular_Male_Hero_Fists_Combat_BlockCycle", topCategory = "Standing", subCategory = "Stand", name = "Fists Up Like Boxing" },
  { path = "/Game/Character/Animations/Bosses/IsraelHands/A_IsraelHands_Agressive_BlockCycle", topCategory = "Standing", subCategory = "Stand", name = "hand out, looks like old man with cane" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Vendors/A_Regular_Male_Vendor05", topCategory = "Standing", subCategory = "Stand", name = "Hands on Hips" },
  { path = "/Game/Character/Animations/Human/Regular/BlackBeard/A_Regular_Male_Scum_IdleBreak_05", topCategory = "Standing", subCategory = "Stand", name = "Hands on Hips Look Around" },
  { path = "/Game/Character/Animations/Human/Regular/BlackBeard/Other/A_Regular_Carpenter_Idle", topCategory = "Standing", subCategory = "Stand", name = "Hands on Hips, Shuffle" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Saber/A_Regular_Male_Hero_Saber_Armed_Idle", topCategory = "Standing", subCategory = "Stand", name = "Idle with Saber" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/AM_Regular_Male_Calm_IdleBreak_02", topCategory = "Standing", subCategory = "Stand", name = "Kicks Dirt" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/AM_Regular_Male_Calm_Alert", topCategory = "Standing", subCategory = "Stand", name = "Looking Around" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Standing_08", topCategory = "Standing", subCategory = "Stand", name = "Palms Clasped" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/AM_Regular_Male_Calm_IdleBreak_01", topCategory = "Standing", subCategory = "Stand", name = "Rolls Shoulders" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Universal_Interact/SearchOnTheTable/A_Regular_Male_Hero_Universal_Interact_SearchOnTheTable_Loop", topCategory = "Standing", subCategory = "Stand", name = "Rummaging Table" },
  { path = "/Game/Character/Animations/Human/Regular/BlackBeard/A_Regular_Male_Scum_IdleBreak_03", topCategory = "Standing", subCategory = "Stand", name = "Scratch Chin" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Standing_04", topCategory = "Standing", subCategory = "Stand", name = "Scrathing Head, thinking" },
  { path = "/Game/Character/Animations/Human/Regular/BlackBeard/A_Regular_Male_Scum_IdleBreak_02", topCategory = "Standing", subCategory = "Stand", name = "Shake Arm" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Combat_Saber/Sergeant/A_Regular_Male_Combat_Saber_Sergeant_Idle", topCategory = "Standing", subCategory = "Stand", name = "Standing Aggressively" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Speaking_01", topCategory = "Standing", subCategory = "Stand", name = "Standing and Talking" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Standing_03", topCategory = "Standing", subCategory = "Stand", name = "Standing, Arm on Hip and Proud" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Standing_01", topCategory = "Standing", subCategory = "Stand", name = "Standing, Looking Left" },
  { path = "/Game/Character/Animations/Human/Regular/BlackBeard/A_Regular_Male_Scum_IdleBreak_06", topCategory = "Standing", subCategory = "Stand", name = "Swat at Bugs" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/IdleBreak/AM_Regular_Male_Hero_IdleBreak_Mosquitoes", topCategory = "Standing", subCategory = "Stand", name = "Swat At Mosquitos" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Taunt/AM_Regular_Male_NPC_ShipCrew_Boarding_Taunt_001_01", topCategory = "Standing", subCategory = "Taunt", name = "Taunt 1" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Taunt/AM_Regular_Male_NPC_ShipCrew_Boarding_Taunt_001_02", topCategory = "Standing", subCategory = "Taunt", name = "Taunt 2" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Taunt/AM_Regular_Male_NPC_ShipCrew_Boarding_Taunt_002_01", topCategory = "Standing", subCategory = "Taunt", name = "Taunt 3" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Taunt/AM_Regular_Male_NPC_ShipCrew_Boarding_Taunt_002_03", topCategory = "Standing", subCategory = "Taunt", name = "Taunt 4" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Taunt/AM_Regular_Male_NPC_ShipCrew_Boarding_Taunt_003_01", topCategory = "Standing", subCategory = "Taunt", name = "Taunt 5" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Taunt/AM_Regular_Male_NPC_ShipCrew_Boarding_Taunt_003_03", topCategory = "Standing", subCategory = "Taunt", name = "Taunt 6" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Taunt/AM_Regular_Male_NPC_ShipCrew_Boarding_Taunt_005_01", topCategory = "Standing", subCategory = "Taunt", name = "Taunt 7" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Consumables/Bandages/A_Regular_Male_Hero_Unarmed_BandagesCycle", topCategory = "Standing", subCategory = "Work", name = "Bandage No Sound" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Fishing_Rod/AM_Regular_Male_Hero_Fishing_Throw", topCategory = "Standing", subCategory = "Work", name = "Crouched Fishing" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Shovel/AM_Regular_Male_Hero_Shovel_Terraform", topCategory = "Standing", subCategory = "Work", name = "Faster Digging" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Fishing_Rod/AM_Regular_Male_Hero_Fishing_IdleFishing", topCategory = "Standing", subCategory = "Work", name = "Fishing" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Building/AM_Regular_Male_Hero_Building_HammerHit", topCategory = "Standing", subCategory = "Work", name = "Hammering" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Cannons/AM_Regular_Male_NPC_ShipCrew_Cannon_L", topCategory = "Standing", subCategory = "Work", name = "Hold Cannon Left" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Cannons/AM_Regular_Male_NPC_ShipCrew_Cannon_R", topCategory = "Standing", subCategory = "Work", name = "Hold Cannon Right" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Wheel/AM_Regular_Male_NPC_ShipCrew_Wheel_FakeInteraction", topCategory = "Standing", subCategory = "Work", name = "Hold Ship Wheel" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Building/A_Regular_Male_Hero_Building_Armed_Idle", topCategory = "Standing", subCategory = "Work", name = "Holding Hammer" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Fishing_Rod/A_Regular_Male_Hero_Fishing_Armed_Idle", topCategory = "Standing", subCategory = "Work", name = "Idle with Fishing Pole" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Fishing_Rod/AM_Regular_Male_Hero_Fishing_Fight", topCategory = "Standing", subCategory = "Work", name = "Reel In Fish" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Shovel/A_Regular_Male_Hero_Shovel_Armed_G1", topCategory = "Standing", subCategory = "Work", name = "Slower Digging" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Ropes/AM_Regular_Male_NPC_ShipCrew_RopePull_HipToHip_Active_01", topCategory = "Standing", subCategory = "Work", name = "Stand and Pull Rope" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Female_Idle_Standing_01", topCategory = "Standing", subCategory = "Stand", name = "Fem Bucc Merchant" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Female_Idle_Standing_05", topCategory = "Standing", subCategory = "Stand", name = "Fem Hands on Hips" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Female_Idle_Standing_02", topCategory = "Standing", subCategory = "Stand", name = "Letty" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Female_Idle_Standing_03", topCategory = "Standing", subCategory = "Stand", name = "Marita" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Default/A_Regular_Female_Hero_Lobby_Idle_03", topCategory = "Standing", subCategory = "Idle", name = "Regular Fem Player Idle" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Female_Idle_Standing_07", topCategory = "Standing", subCategory = "Stand", name = "Fem Table Merchant" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Default/A_Regular_Male_Hero_Lobby_Idle_03", topCategory = "Standing", subCategory = "Idle", name = "Regular Masc Player Idle" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Female_Idle_SittingOnChair_01", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Chair Sit", name = "Fem Sit 1" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Female_Idle_SittingOnChair_02", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Chair Sit", name = "Fem Sit 2" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Female_Idle_SittingOnChair_03", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Chair Sit", name = "Fem Sit 3" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_SittingOnChair_02", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Chair Sit", name = "Sit on Chair, look left" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Universal_Interact/SittingOnAstool/A_Regular_Male_Hero_Universal_Interact_SittingOnAstool_Loop", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Chair Sit", name = "Sit on Stool" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Defeat/AM_Regular_Male_NPC_ShipCrew_Boarding_Defeat_005", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Crouch", name = "Crouch and Cower" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Universal_Interact/SittingOnGround/A_Regular_Male_Hero_Universal_Interact_SittingOnGround_Idle03_Loop", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Crouch", name = "Crouching" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Ropes/AM_Regular_Male_NPC_ShipCrew_RopePull_HipToFloor_Active_01", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Ground Sit", name = "Sit and Pull Rope" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Defeat/AM_Regular_Male_NPC_ShipCrew_Boarding_Defeat_004", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Ground Sit", name = "Sit on Floor Cowering" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Universal_Interact/SittingOnGround/A_Regular_Male_Hero_Universal_Interact_SittingOnGround_Idle01_Loop", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Ground Sit", name = "Sit on Ground Arms on Legs" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Universal_Interact/SittingOnGround/A_Regular_Male_Hero_Universal_Interact_SittingOnGround_Idle02_Loop", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Ground Sit", name = "Sit on Ground Crossed Legs" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_SittingOnChair_For_JacquesArno", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Ground Sit", name = "Sit on ground, holding stomach" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Defeat/AM_Regular_Male_NPC_ShipCrew_Boarding_Defeat_003", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Ground Sit", name = "Sit on ground, holding stomach out of breath" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Calm/Idle/A_AnimatedActor_Regular_Male_Idle_Sitting_01", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Ground Sit", name = "Sit on ground. Head on hand" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Defeat/AM_Regular_Male_NPC_ShipCrew_Boarding_Defeat_001", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Kneel", name = "Defeat Fall to Knees" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Boarding_Defeat/AM_Regular_Male_NPC_ShipCrew_Boarding_Defeat_002", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Kneel", name = "Defeat Fall to Kness and Cower" },
  { path = "/Game/Character/Animations/Bosses/IsraelHands/A_IsraelHands_Agressive_OutOfPostureCycle", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Kneel", name = "Kneeling, Out of Breath" },
  { path = "/Game/Character/Animations/Bosses/IsraelHands/A_IsraelHands_HumanForm_Spawn_Cycle", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Kneel", name = "Praying" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Universal_Interact/SearchingInObject/A_Regular_Male_Hero_Universal_Interact_SearchingInObject_Loop", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Kneel", name = "Rummaging Chest" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Universal_Interact/Employee/A_Regular_Male_Hero_Universal_Interact_Garden_Loot", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Kneel", name = "Rummaging Low" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Universal/Idle/A_Regular_Male_NPC_Universal_FloorCleaning_Brush01_Idle01", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Kneel", name = "Scrub Floor 1" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Universal/Idle/A_Regular_Male_NPC_Universal_FloorCleaning_Brush02_Idle", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Kneel", name = "Scrub Floor 2" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Hammock/AM_Regular_Male_NPC_ShipCrew_Hammock_Hammock_Sleep", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Hammock" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/SleepOnBed/AM_Regular_Male_Hero_Universal_Interact_SleepOnBed_001_L", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Sleep On Back" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/SleepOnBed/AM_Regular_Male_Hero_Universal_Interact_SleepOnBed_002_L", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Sleep On Back Knees Up" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/SleepOnBed/AM_Regular_Male_Hero_Universal_Interact_SleepOnBed_005_L", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Sleep On Back Left Knee Up" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/SleepOnBed/AM_Regular_Male_Hero_Universal_Interact_SleepOnBed_005_R", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Sleep On Back Right Knee Up" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/SleepOnBed/AM_Regular_Male_Hero_Universal_Interact_SleepOnBed_003_L", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Sleep On Front Left Arm Dangling" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/SleepOnBed/AM_Regular_Male_Hero_Universal_Interact_SleepOnBed_003_R", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Sleep On Front Right Arm Dangling" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/SleepOnBed/AM_Regular_Male_Hero_Universal_Interact_SleepOnBed_004_R", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Sleep On Left Side" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/SleepOnGround/A_Regular_Male_Hero_SleepOnGround_Loop", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Sleep on Left Side on Floor" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/SleepOnBed/AM_Regular_Male_Hero_Universal_Interact_SleepOnBed_004_L", topCategory = "Sit, Crouch, Kneel, Sleep", subCategory = "Sleep", name = "Sleep On Right Side" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Alchemy/TableInteract/A_Regular_Male_Hero_Alchemy_TableInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Alchemy Table" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Blacksmith/AnvilInteract/A_Regular_Male_Hero_Blacksmith_AnvilInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Anvil" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Jevellery/TableInteract/A_Regular_Male_Hero_Jevellery_TableInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Check Gems" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Cooking/CuttingTable/A_Regular_Male_Hero_Cooking_CuttingTableInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Chopping Table (Has Fish)" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Equipment/TableInteract/A_Regular_Male_Hero_Equipment_TableInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Cut Leather" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Blacksmith/BellowsInteract/Coal/A_Regular_Male_Hero_Blacksmith_BellowsInteract_Coal_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Dig Coals" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Enchanter/TableInteract/A_Regular_Male_Hero_Enchanter_TableInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Enchanting Table" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/ShelfInteract/AM_Regular_Male_Hero_ShelfInteract_Start", topCategory = "Workbenches", subCategory = "No Props", name = "Get Stuff From Shelves" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Equipment/ShoemakerInteract/A_Regular_Male_Hero_Equipment_ShoemakerInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Make Shoes" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Blacksmith/BarrelInteract/A_Regular_Male_Hero_Blacksmith_BarrelInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Quenching Barrel" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Workbench/SawmillInteract/AM_Regular_Male_Hero_Workbench_SawmillInteract", topCategory = "Workbenches", subCategory = "No Props", name = "Sawhorse" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Blacksmith/TableInteract/A_Regular_Male_Hero_Blacksmith_TableInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Weapons Table" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Workbench/TableInteract/A_Regular_Male_Hero_Workbench_TableInteract_Loop", topCategory = "Workbenches", subCategory = "No Props", name = "Workbench" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Alchemy/TableInteract/AM_Regular_Male_Hero_Alchemy_TableInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Alchemy Table" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Blacksmith/AnvilInteract/AM_Regular_Male_Hero_Blacksmith_AnvilInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Anvil" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Jevellery/TableInteract/AM_Regular_Male_Hero_Jevellery_TableInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Check Gems" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Cooking/CuttingTable/AM_Regular_Male_Hero_Cooking_CuttingTableInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Chopping Table" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Equipment/TableInteract/AM_Regular_Male_Hero_Equipment_TableInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Cut Leather" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Blacksmith/BellowsInteract/Coal/AM_Regular_Male_Hero_Blacksmith_BellowsInteract_Coal", topCategory = "Workbenches", subCategory = "With Props", name = "Dig Coals" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Equipment/MannequinInteract/AM_Regular_Male_Hero_Equipment_MannequinInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Dust Mannequin" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Enchanter/TableInteract/AM_Regular_Male_Hero_Enchanter_TableInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Enchanting Table" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/ShelfInteract/A_Regular_Male_Hero_ShelfInteract_Loop", topCategory = "Workbenches", subCategory = "With Props", name = "Get Stuff From Shelves" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Equipment/ShoemakerInteract/AM_Regular_Male_Hero_Equipment_ShoemakerInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Make Shoes" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Blacksmith/BellowsInteract/Lever/AM_Regular_Male_Hero_Blacksmith_BellowsInteract_Lever", topCategory = "Workbenches", subCategory = "With Props", name = "Pump Bellows" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Blacksmith/BarrelInteract/AM_Regular_Male_Hero_Blacksmith_BarrelInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Quenching Barrel" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Workbench/SawmillInteract/AM_Regular_Male_Hero_Workbench_SawmillInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Sawhorse" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Cooking/PotInteract/AM_Regular_Male_Hero_Cooking_PotInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Smelling and Warming By Fire" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Blacksmith/TableInteract/AM_Regular_Male_Hero_Blacksmith_TableInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Weapons Table" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/CampActivity/Workbench/TableInteract/AM_Regular_Male_Hero_Workbench_TableInteract", topCategory = "Workbenches", subCategory = "With Props", name = "Workbench" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Axe/AM_Regular_Male_Hero_Axe_Armed_G1", topCategory = "Combat", subCategory = "Attack", name = "Axe Attack" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Shovel/AM_Regular_Male_Hero_Shovel_Combat_Attack_H1", topCategory = "Combat", subCategory = "Attack", name = "Hard Two Handed Down Thrust" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Pickaxe/AM_Regular_Male_Hero_Pickaxe_Armed_G1", topCategory = "Combat", subCategory = "Attack", name = "Pickaxe Swing 1" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Pickaxe/AM_Regular_Male_Hero_Pickaxe_Armed_G2", topCategory = "Combat", subCategory = "Attack", name = "Pickaxe Swing 2" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Combat_Musket/A_Regular_Male_Combat_Musket_Shot", topCategory = "Combat", subCategory = "Attack", name = "Shoot Musket" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Combat_Saber/Sergeant/A_Regular_Male_Combat_Pistol_Shot", topCategory = "Combat", subCategory = "Attack", name = "Shoot Pistol" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Default/A_Kill_Behind_01", topCategory = "Combat", subCategory = "Attack", name = "Stabbing From Behind" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Sword2h/A_Regular_Male_Hero_Sword2h_Combat_BlockCycle", topCategory = "Combat", subCategory = "Guard", name = "Hold 2H Defensively" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Halberd/A_Regular_Male_Hero_Halberd_Combat_BlockCycle", topCategory = "Combat", subCategory = "Guard", name = "Hold Halberd Defensively" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Combat_Musket/A_Regular_Male_Combat_Musket_BlockCycle", topCategory = "Combat", subCategory = "Guard", name = "Hold Musket Defensively 1" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Musket/A_Regular_Male_Hero_Musket_Combat_BlockCycle", topCategory = "Combat", subCategory = "Guard", name = "Hold Musket Defensively 2" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Combat_Saber/AM_Regular_Male_Combat_Saber_Block", topCategory = "Combat", subCategory = "Guard", name = "Hold Saber Defensively" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Shovel/A_Regular_Male_Hero_Shovel_Combat_BlockCycle", topCategory = "Combat", subCategory = "Guard", name = "Hold Shovel Defensively" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Saber/A_Regular_Female_Hero_Saber_Armed_Idle", topCategory = "Combat", subCategory = "Idle", name = "Fem Stand With  Saber" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Fists/A_Regular_Female_Hero_Fists_Unarmed_Idle", topCategory = "Combat", subCategory = "Idle", name = "Fem Stand with Fist Clenched" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Sword2h/A_Regular_Female_Hero_GSword_Armed_Idle", topCategory = "Combat", subCategory = "Idle", name = "Fem Stand With Great Sword" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Halberd/A_Regular_Female_Hero_Halberd_Armed_Idle", topCategory = "Combat", subCategory = "Idle", name = "Fem Stand With Halberd" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Musket/A_Regular_Female_Hero_Musket_Armed_Idle", topCategory = "Combat", subCategory = "Idle", name = "Fem Stand With Musket" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Fists/A_Regular_Male_Hero_Fists_Unarmed_Idle", topCategory = "Combat", subCategory = "Idle", name = "Masc Stand with Fist Clenched" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Sword2h/A_Regular_Male_Hero_GSword_Armed_Idle", topCategory = "Combat", subCategory = "Idle", name = "Masc Stand With Great Sword" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Halberd/A_Regular_Male_Hero_Halberd_Armed_Idle", topCategory = "Combat", subCategory = "Idle", name = "Masc Stand With Halberd" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Combat_Musket/A_Regular_Male_Combat_Musket_Idle", topCategory = "Combat", subCategory = "Idle", name = "Masc Stand with Musket" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Combat_Saber/A_Regular_Male_Combat_Saber_Idle", topCategory = "Combat", subCategory = "Idle", name = "Masc Stand with Saber" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Consumables/Oil/AM_Regular_Male_Hero_Axe_Armed_Oil", topCategory = "Combat", subCategory = "Prep", name = "Oil Up Blade" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Consumables/Bandages/AM_Regular_Male_Hero_Bandage_WithoutLoop", topCategory = "Combat", subCategory = "Prep", name = "Wrap Arm with Sound" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Combat_Musket/A_Regular_Male_Combat_Musket_IdleAim", topCategory = "Combat", subCategory = "Readied", name = "Aim Musket" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Combat_Saber/Sergeant/A_Regular_Male_Combat_Pistol_AimCycle", topCategory = "Combat", subCategory = "Readied", name = "Aim Pistol 1" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Pistol/A_Regular_Male_Hero_Pistol_S1Cycle", topCategory = "Combat", subCategory = "Readied", name = "Aim Pistol 2" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Pistol/A_Regular_Male_Hero_Pistol_Armed_Idle", topCategory = "Combat", subCategory = "Readied", name = "Standing with Pistol Ready" },
  { path = "/Game/Character/Animations/Bosses/Boatswain/Polehook/A_Boss_Boatswain_Attack_Idle", topCategory = "Combat", subCategory = "Readied", name = "Standing With Spear Ready" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Pistol/AM_Regular_Male_Hero_Pistol_ActiveReload_First", topCategory = "Combat", subCategory = "Reload", name = "Pistol Reload" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Musket/AM_Regular_Male_Hero_Musket_ActiveReload", topCategory = "Combat", subCategory = "Reload", name = "Reload Musket" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Musket/AM_Regular_Male_Hero_Musket_ActiveReload_Fast", topCategory = "Combat", subCategory = "Reload", name = "Reload Musket Fast" },
  { path = "/Game/Character/Animations/Bosses/Boatswain/Polehook/AM_Human_Adventurer_Combat_Grab_Target", topCategory = "Combat", subCategory = "Yeet", name = "Slammed to the Ground" },
  { path = "/Game/Character/Animations/Creatures/Crocodile/A_Human_Adventurer_Crocodile_Grab_Target", topCategory = "Combat", subCategory = "Yeet", name = "Swung Back and Forth" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Sword2h/AM_Regular_Male_Hero_Sword2h_Combat_SoulHarvest", topCategory = "Magic", subCategory = nil, name = "Glowing Fist Pump" },
  { path = "/Game/Character/Animations/Bosses/IsraelHands/A_IsraelHands_Agressive_Shot", topCategory = "Magic", subCategory = nil, name = "Leans Back, Sparks shoot. Sound" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/AM_SenkamatiCorrupted_Regular_Shaman_GroundSpikeConePush_Previs", topCategory = "Magic", subCategory = nil, name = "Witch Cast Dome" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/Caster/A_SenkamatiCorrupted_Regular_Shaman_Caster_repulsion", topCategory = "Magic", subCategory = nil, name = "Witch Cast Repulsion No Sound" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/AM_SenkamatiCorrupted_Regular_Shaman_HealZone", topCategory = "Magic", subCategory = nil, name = "Witch Stabs Arm Grows Flowers" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/AM_SenkamatiCorrupted_Regular_Shaman_HealWave", topCategory = "Magic", subCategory = nil, name = "Witch Stabs Arm Grows Tentacles" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/AM_SenkamatiCorrupted_Regular_Shaman_MassHeal", topCategory = "Magic", subCategory = nil, name = "Witch Stabs Arm Yellow Glow" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/AM_SenkamatiCorrupted_Regular_Shaman_DeployTotem", topCategory = "Magic", subCategory = nil, name = "Witch Summon Totem" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/Caster/A_SenkamatiCorrupted_Regular_Shaman_Caster_DeployTotem", topCategory = "Magic", subCategory = nil, name = "Witch Summon Totem No Sound" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/AM_SenkamatiCorrupted_Regular_Shaman_GroundSpikesCircle", topCategory = "Magic", subCategory = nil, name = "Witch with Spikes (Cause Damage)" },
  { path = "/Game/Character/Animations/Human/Regular/Drowned/AM_Drowned01_Alert", topCategory = "Monsterous", subCategory = "Drowned", name = "Drowned Alerted" },
  { path = "/Game/Character/Animations/Human/Regular/Drowned/AM_Drowned01_IdleBreak1", topCategory = "Monsterous", subCategory = "Drowned", name = "Drowned Calm" },
  { path = "/Game/Character/Animations/Human/Regular/Drowned/A_Drowned01_Agressive_Idle", topCategory = "Monsterous", subCategory = "Drowned", name = "Drowned ready to fight" },
  { path = "/Game/Character/Animations/Human/Regular/Drowned/AM_Drowned01_Agressive_RageStart", topCategory = "Monsterous", subCategory = "Drowned", name = "Drowned Roar" },
  { path = "/Game/Character/Animations/Human/Regular/Drowned/Spitter/AM_Drowned01_Spitter_ChannelingBeam", topCategory = "Monsterous", subCategory = "Drowned", name = "Drowned Spitting" },
  { path = "/Game/Character/Animations/Bosses/IsraelHands/A_IsraelHands_Agressive_Idle", topCategory = "Monsterous", subCategory = "Other", name = "Slow Undead Idle" },
  { path = "/Game/Character/Animations/Bosses/IsraelHands/AM_IsraelHands_SpiritualReleaseLight", topCategory = "Monsterous", subCategory = "Other", name = "Standing, Leans Back with Roar" },
  { path = "/Game/Character/Animations/Bosses/IsraelHands/AM_IsraelHands_Agressive_IdleBreak", topCategory = "Monsterous", subCategory = "Other", name = "Stands Idle then Roars (with sound)" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Default/A_Regular_Senkamati_Corrupted_Thrall_Aggressive_Grab_Instigator", topCategory = "Monsterous", subCategory = "Senkamati", name = "Bite Then Push" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Hunter/AM_Regular_SenkamatiCorrupted_Hunter_Alert", topCategory = "Monsterous", subCategory = "Senkamati", name = "Hunter Looking Around" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Hunter/A_SenkamatiCorrupted_Regular_Hunter_Agressive_Idle", topCategory = "Monsterous", subCategory = "Senkamati", name = "Hunter Ready to Fight" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Hunter/AM_SenkamatiCorrupted_Regular_Hunter_Throwing_Throw", topCategory = "Monsterous", subCategory = "Senkamati", name = "Hunter Throw Spear" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Thrall/A_Regular_SenkamatiCorrupted_Thrall_Agressive_Idle", topCategory = "Monsterous", subCategory = "Senkamati", name = "Thrall Calm 1" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Thrall/A_Regular_SenkamatiCorrupted_Thrall_Calm_Idle", topCategory = "Monsterous", subCategory = "Senkamati", name = "Thrall Calm 2" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Thrall/AM_Regular_SenkamatiCorrupted_Thrall_Calm_Alert", topCategory = "Monsterous", subCategory = "Senkamati", name = "Thrall Look Around" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Warrior/A_SenkamatiCorrupted_Regular_Warrior_Calm_Idle", topCategory = "Monsterous", subCategory = "Senkamati", name = "Warrior Calm" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Warrior/AM_SenkamatiCorrupted_Regular_Warrior_Calm_Alert", topCategory = "Monsterous", subCategory = "Senkamati", name = "Warrior Looks Around" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Warrior/A_SenkamatiCorrupted_Regular_Warrior_Agressive_BlockCycle", topCategory = "Monsterous", subCategory = "Senkamati", name = "Warrior Standing Defensively" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/Caster/AM_Regular_Female_Senkamati_Witch_Calm_IdleBreak_01", topCategory = "Monsterous", subCategory = "Senkamati", name = "Witch Calm 1" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/Caster/AM_Regular_Female_Senkamati_Witch_Calm_IdleBreak_02", topCategory = "Monsterous", subCategory = "Senkamati", name = "Witch Calm 2" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/Caster/A_Regular_Female_Senkamati_Witch_AlertCycle", topCategory = "Monsterous", subCategory = "Senkamati", name = "Witch Looking Around" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/Caster/A_Regular_Female_Senkamati_Witch_Agressive_Idle", topCategory = "Monsterous", subCategory = "Senkamati", name = "Witch Ready to Fight" },
  { path = "/Game/Character/Animations/Human/Regular/Senkamati_Shaman/A_SenkamatiCorrupted_Regular_Shaman_Agressive_Heal_loop", topCategory = "Monsterous", subCategory = "Senkamati", name = "Witch Stab Arm" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Default/AM_Regular_Male_Hero_Barrel_Pose", topCategory = "Statues", subCategory = nil, name = "Arms Outstretched 1" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Default/A_Regular_Male_Hero_Carrying_Barrel", topCategory = "Statues", subCategory = nil, name = "Arms Outstretched 2" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Default/A_Regular_Male_Hero_Carrying_FireBowl", topCategory = "Statues", subCategory = nil, name = "Arms Outstretched 3" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Default/A_Regular_Male_Hero_Carrying_Vase", topCategory = "Statues", subCategory = nil, name = "Arms Outstretched 4" },
  { path = "/Game/Character/Animations/Human/Regular/Shared/Ship/Transition/A_Regular_Male_Hero_BoardingTransitionDown_HoldToLanding", topCategory = "Statues", subCategory = nil, name = "Mid Jump" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Saber/A_Regular_Male_Hero_Saber_Armed_Falling", topCategory = "Misc", subCategory = nil, name = "Falling or Floating" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Swimming/A_Regular_Male_Hero_Swimming_Idle", topCategory = "Misc", subCategory = nil, name = "Floating in Water" },
  { path = "/Game/Character/Animations/Human/Regular/Hero/Saber/A_Regular_Male_Hero_Saber_Armed_Jump", topCategory = "Misc", subCategory = nil, name = "Floaty Jump" },
}

------------------------------------------------------------------
-- PLAIN-TEXT config.txt (for users who don't touch Lua). A file next to the mod with simple
--   name = value    lines (e.g.  WHISTLE_CREW = true   or   FOLLOW_SPEED_MAX = 900 ).
-- true/false -> boolean, numbers -> number, anything else -> string. '#' starts a comment.
-- This is the ONE override file: config.lua holds the shipped defaults, config.txt overrides them.
------------------------------------------------------------------
do
    local function coerce(s)
        s = (s:gsub("^%s+", ""):gsub("%s+$", ""))
        if s == "true" then return true elseif s == "false" then return false end
        local num = tonumber(s)
        if num then return num end
        return (s:gsub('^"(.*)"$', "%1"))
    end
    local paths = { "ue4ss/Mods/LivingBase/config.txt", "Mods/LivingBase/config.txt", "config.txt" }
    local f
    for _, p in ipairs(paths) do f = io.open(p, "r"); if f then break end end
    if f then
        local n = 0
        for rawline in f:lines() do
            local line = (rawline:gsub("%s*#.*$", ""))              -- strip comments
            local key, val = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if key and val ~= "" then Config[key] = coerce(val); n = n + 1 end
        end
        f:close()
        if n > 0 then print("[LivingBase] config.txt applied " .. tostring(n) .. " override(s)\n") end
    end
end

------------------------------------------------------------------
-- OPTIONAL: R5 Mod Settings integration (LivingBase-ModMenuPatch overlay). All the actual logic
-- (translation tables, manifest writing, saved-value reading) now lives in modsettings.lua, shared
-- with main.lua's live keybind poll -- see that file for the full explanation. This just applies
-- the one-time startup values (config.lua defaults, then config.txt, then whatever's saved in
-- R5ModSettings, highest precedence last) into Config before main.lua reads it. A key changed in
-- Settings > Mods AFTER this point is picked up live by main.lua's poll, not by this call again.
------------------------------------------------------------------
do
  local ok, ModSettings = pcall(require, "modsettings")
  if ok and ModSettings then
    pcall(function() ModSettings.ApplyOnce(Config) end)
  end
end

------------------------------------------------------------------
-- OPTIONAL: LivingBaseSpawnMenu companion mod manifest. Generates spawn_menu.ini (add-only, never
-- overwrites hand-curated entries) so that mod's category tree has something to read -- see
-- spawnmenu_manifest.lua for the full explanation.
------------------------------------------------------------------
do
  local ok, SpawnMenuManifest = pcall(require, "spawnmenu_manifest")
  if ok and SpawnMenuManifest then
    pcall(function() SpawnMenuManifest.GenerateOnce(Config) end)
  end
end

return Config