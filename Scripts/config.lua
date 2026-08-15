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

-- Whether every key this mod binds (numpad, F-row, DEL, '\', live-edit) starts ON or OFF when the
-- game launches. true (default) = ready to use immediately, same as always. false = starts OFF, so
-- the mod's keys don't interfere with anything until you explicitly press the toggle key
-- (Config.KEYS.toggleMod, "INS" by default) to turn them on -- for players who'd rather opt in each
-- session than remember to opt out. Purely a starting state; the toggle key still flips it either way
-- at runtime regardless of this setting.
Config.KEYS_ENABLED_ONSTART = true

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

-- LIVE EDIT (dev): raise/lower + rotate the placed object in front of you, in place and persistently,
-- to fine-tune sitters and decorations in the base. Rotate step + height step per keypress. The log
-- prints the running yaw offset (bake into a sitter's `yaw`) and height. Enable in config.txt.
Config.LIVE_EDIT = false
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
Config.LIVE_EDIT_MAX_DIST = 200.0
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
Config.TARGET_LOCK_MAX_DIST = 1500.0
-- How often (ms) the periodic tick (Spawner.StartTargetLockTick, started only while a lock is active
-- and self-stopping the moment it isn't -- see that function's own comment) re-checks TARGET_LOCK_MAX_DIST
-- against a locked target, so walking away releases the lock on its own without needing to press
-- another mod key first. Same order of magnitude as LEASH_INTERVAL_MS (3000, a different feature's own
-- periodic check) -- frequent enough that "walked away" feels prompt, not so frequent it's wasted work
-- for a value (position) that only changes as fast as the player walks.
Config.TARGET_LOCK_CHECK_MS = 2000

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
-- KEYBINDS — remap freely. Values are UE4SS key names (no CTRL added):
-- function keys "F1".."F9", letters "A".."Z", "DEL", "INS", "HOME", etc.
-- If a name is invalid, the mod falls back to the default and prints a note.
-- Each key drops ONE actor in front of you (Num 0 = undo, DEL = clean house).
------------------------------------------------------------
-- NOTE: F10/F11/F12 are avoided — they collide with the game chat window,
-- windowed-mode toggle, and Steam screenshot respectively. The raid keys use F7/F8.
-- PLACEMENT KEYS moved to the NUMPAD (2026-07-10, RedFalcon's layout). One coherent cluster for the
-- hand, freeing the whole F-row. ⚠ NumLock must be ON — with it OFF, Windows remaps the numpad to
-- navigation keys (1->End, 2->Down, ...) before UE4SS ever sees them, and the binds go dead.
Config.KEYS = {
  -- Place a crew pawn, cycling forward one look per press through Config.FACTION_VISITOR_LOOKS
  -- (index 1 = plain default crew, the other 12 = Buccaneers/Smugglers/Tortuga/Brethren re-skins).
  -- Was its own separate key (Num+/NUM_ADD) briefly on 2026-08-07 while being proven out; merged
  -- into this key the same day once nothing else needed NUM_ADD, freeing it back up.
  crew      = "NUM_ONE",
  townsman  = "NUM_TWO",   -- place a townsman (wanders + uses furniture)
  standing  = "NUM_THREE", -- STANDING statue — merchants, chat, cross-hands, woman, + quest folk
  seated    = "NUM_FOUR",  -- FLOOR sitter (SitterOnGround / LayOnGround) — sits on the ground
  chairseat = "NUM_FIVE",  -- CHAIR/STOOL sitter (SitterOnStool / Sitting) — place a stool yourself
  interact  = "NUM_SIX",   -- INTERACTIVE statue (rifling a chest/equipment)
  plague    = "NUM_SEVEN", -- friendly Senkamati tribal human (cycles looks)
  livestock = "NUM_EIGHT", -- friendly farm animal (cycles boar / GoatF / GoatM)
  undo      = "NUM_NINE",  -- despawn the spawn in front of you, ON YOUR FLOOR (walk up + press)
  restoreLast = "NUM_ZERO", -- undo: respawn the last despawned object(s) (single despawn or DEL batch) at their exact spot
  -- Cycle the targeted statue OR decoration through its own roster (statue pose roster / decoration
  -- category) -- Spawner.CycleNearestInFront auto-detects which kind is targeted. Was a single
  -- forward-only Num+ key until 2026-08-07; changed to a bidirectional pair on request. Tried ']'/'['
  -- first, moved to 'O'/'U' once the user's own control list showed ']'/'[' are the GAME's "Change
  -- Target" bind (combat) -- then moved BACK to ']'/'[' the same day: more intuitive, and the
  -- collision is low-risk in practice (Insert can disable every mod key outright, and building/
  -- cycling isn't happening mid-combat anyway).
  cycleNext = "OEM_RIGHT_BRACKET", -- ']'  cycle forward
  cyclePrev = "OEM_LEFT_BRACKET",  -- '['  cycle backward
  toggleMod = "INS", -- toggle EVERY key this mod binds (numpad, F-row, DEL, '\', live-edit) on/off at
                      -- runtime, so any of them is free for other uses when you're not actively using
                      -- the mod. Always active itself (not gated by the toggle it controls). Off the
                      -- F-row on purpose: F-keys are the most likely to be claimed by other mods/
                      -- overlays (F9 collided with one). "INS" (not "INSERT") is this build's confirmed
                      -- key name — see the HOME/INS in-world probe keys in ASSET_CATALOG.md. Remap here
                      -- if this one conflicts too.
  -- Decor placement keys (decorSpawn/decorCategory) + Blackbeard raid keys live in fkeys.lua --
  -- see the require/merge below Config.KEYS's closing brace.
  -- LIVE EDIT (LIVE_EDIT): fine-tune the object in front of you. RedFalcon asked for [/] + '+/-', but '['
  -- and numpad-0 don't register binds in this build (the game eats them), so these use the proven
  -- shield-tuner keys instead. Rotate: ',' / '.'   Height: PageUp / '-'.
  editUp    = "PAGE_UP",     -- raise
  editDown  = "PAGE_DOWN",   -- lower
  editRotL  = "OEM_COMMA",   -- ','  rotate left
  editRotR  = "OEM_PERIOD",  -- '.'  rotate right
  editRot45 = "NUM_DIVIDE",  -- numpad '/'  rotate a fixed 45 deg (not scaled by LIVE_EDIT_ROTATE_STEP)
  editRot180 = "NUM_MULTIPLY", -- numpad '*'  rotate a fixed 180 deg (flip the object in front of you)
  editPrecisionToggle = "NUM_SUBTRACT", -- numpad '-'  cycle slide/height precision: full -> 1/2 -> 1/4 -> 1/8 -> 2x -> full
  -- Target lock (2026-08-13): pins despawn/cycle/live-edit to ONE tracked actor instead of re-picking
  -- "nearest in front" on every press -- lets you back away/turn to check an angle, or work on a spawn
  -- that's momentarily outside the normal targeting cone, without losing it. Toggle on/off; toast-
  -- confirmed each way. NUM_ADD was free (see the removed-reloadTest comment in main.lua's own history
  -- for its prior two brief uses) -- numpad '+' rounds out the operator cluster next to '/'  (45°),
  -- '*' (180°), and '-' (precision).
  targetLock = "NUM_ADD",
  -- Slide keys: arrows are NOT in this build's Key[] table at all (see VK_FALLBACK in main.lua) — they
  -- only work via a raw-Windows-virtual-key workaround. Tried I/J/K/L (which should go through the normal
  -- Key[] path) but they didn't bind AT ALL in this game — meaning this game's Key[] table doesn't have
  -- plain single-letter entries either, so that's a dead end here. Back to arrows, which at least
  -- partially work via the VK fallback.
  editFwd   = "UP",          -- arrow up:    slide the prop AWAY from you (along your facing)
  editBack  = "DOWN",        -- arrow down:  slide it TOWARD you
  editLeft  = "LEFT",        -- arrow left:  slide it to your left
  editRight = "RIGHT",       -- arrow right: slide it to your right
  facing    = "OEM_FIVE",  -- '\'  flip statue placement 180 deg (back-to-you / riflers face you)
  clear     = "DEL",       -- despawn ALL (clean house) — off the pad (destructive)

  -- DEV-TOOL diagnostic, not a real feature — see Spawner.ProbeNearestActor's own comment. Aim at
  -- ANY actor (ours, wild NPCs, undiscovered decor) and press HOME: logs its class path to
  -- discovery_dump.txt (the ASSET_CATALOG.md workflow) and caches it for probeProperties.
  -- Registered directly, NOT gated by the Insert toggle, so it works even with mod keys off.
  probeNearest = "HOME",
  -- DEV-TOOL diagnostic, second step — see Spawner.ProbeDumpProperties's own comment. After HOME has
  -- targeted something, press PAUSE to dump its declared properties to ue4ss.log. Deliberately a
  -- SEPARATE key from HOME (split after a live crash inside the old single-key version's component
  -- sweep) and deliberately PAUSE, not END — "END" is CONFIRMED DEAD in this build (produced zero
  -- log output at all, not even "key received", per the 2026-08-06 toast investigation).
  probeProperties = "PAUSE",
  -- TEMP DEV/TEST TOOL (2026-08-10) -- see Testbed.TestFemaleWalkerReskin's own comment. Reuses the
  -- slot the now-settled SpawnCompareMobCaster tool had (and, briefly, the failed
  -- TestFemaleStatueAI attempt). NUM_DECIMAL needs the VK_FALLBACK raw-virtual-key treatment,
  -- same as every other numpad operator key in this build (see main.lua's own VK_FALLBACK
  -- table/comment).
  testFemaleWalkerReskin = "NUM_DECIMAL",
  -- testApplyBodySex ("F6") REMOVED (2026-08-15) -- was scaffolding for confirming Spawner.
  -- ApplyBodySex's post-build sex change actually renders (it does -- CLAUDE.md item 64). That
  -- capability lives on as the `lbsexchange` console command instead of a dev key. F6 is free
  -- again.
  -- testApplyPose ("F5") REMOVED (2026-08-15) -- was scaffolding for the pose-porting
  -- investigation, now CLOSED (item 63/65). F5 is free again.
  -- testApplyBodyType ("F4") REMOVED (2026-08-15, same day it was added) -- CONFIRMED to crash the
  -- game natively (comp:SetBody call, two live tests, two crashes, zero Lua-side trace either
  -- time). See main.lua's own removal note at the old register() call site, and CLAUDE.md item 64,
  -- for the full writeup. F4 is free again, but don't reuse it for another SetBody test without a
  -- genuinely new theory about the crash.
  -- testColorRandomization ("SCROLL_LOCK") REMOVED (2026-08-11) -- its dev/test tool
  -- concluded and was removed; see Testbed.lua's own note at the old call site for
  -- findings. SCROLL_LOCK is free again.
  -- reloadTest ("NUM_ADD") REMOVED (2026-08-13) -- temp key confirmed lbreload alone picks up a
  -- keybind change with no world-load/menu round-trip needed (RegisterKeyBind runs unconditionally
  -- at top-level module load). Confirmed live, tool removed. NUM_ADD is free again -- its brief
  -- reuse for a "Female_Barbie" test key (same day) was retired in favor of making that an
  -- lblook-only named look instead (Testbed.SpawnBarbieByName) -- no numpad key needed.
  -- senkaStatue ('=')/senkaStatueStanding ('-') REMOVED (2026-08-15) -- the entire Senkamati
  -- Statues feature was purged (RedFalcon: the archetype-reroll mechanism could flash through
  -- other body types -- bare skin/nipples -- on the way to a good one, an NSFW risk not worth
  -- keeping once Num7's own frozen "idle" rows cover the same "see a static look" need safely).
  -- See CLAUDE.md for the full writeup. Both keys are free again.
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
  -- CASTER -- idle (frozen) crew + mob (4 rows) -- Gatherer base only (idle rows aren't split by
  -- baseLabel the way the walking Herbalist pair is; not worth doubling to 8 rows for a body-base
  -- difference that's orthogonal to the actual idle/NSFW-safety ask).
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
  { faction = "Smugglers", name = "Smugglers Musketeer",
    params = objPath(FV .. "Smugglers/CompositeMesh/Common/", "DA_NPC_AnimatedActor_Smugglers_Common_Musketeer_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "Smugglers/Common/Musketeer/", "DA_AnimatedActor_Smugglers_Common_Musketeer_PresetColor") },
  { faction = "Smugglers", name = "Smugglers Sailor",
    params = objPath(FV .. "Smugglers/CompositeMesh/Common/", "DA_NPC_AnimatedActor_Smugglers_Common_Sailor_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "Smugglers/Common/Sailor/", "DA_AnimatedActor_Smugglers_Common_Sailor_PresetColor") },
  { faction = "Smugglers", name = "Smugglers Sergeant",
    params = objPath(FV .. "Smugglers/CompositeMesh/Common/", "DA_NPC_AnimatedActor_Smugglers_Common_Sergeant_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "Smugglers/Common/Sergeant/", "DA_AnimatedActor_Smugglers_Common_Sergeant_PresetColor") },
  { faction = "People of Tortuga", name = "Tortuga Musketeer",
    params = objPath(FV .. "TortugaCitizen/CompositeMesh/Common/", "DA_NPC_AnimatedActor_TortugaCitizen_Common_Musketeer_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "TortugaCitizen/Common/Musketeer/", "DA_AnimatedActor_TortugaCitizen_Common_Musketeer_PresetColor") },
  { faction = "People of Tortuga", name = "Tortuga Sailor",
    params = objPath(FV .. "TortugaCitizen/CompositeMesh/Common/", "DA_NPC_AnimatedActor_TortugaCitizen_Common_Sailor_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "TortugaCitizen/Common/Sailor/", "DA_AnimatedActor_TortugaCitizen_Common_Sailor_PresetColor") },
  { faction = "People of Tortuga", name = "Tortuga Sergeant",
    params = objPath(FV .. "TortugaCitizen/CompositeMesh/Common/", "DA_NPC_AnimatedActor_TortugaCitizen_Common_Sergeant_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "TortugaCitizen/Common/Sergeant/", "DA_AnimatedActor_TortugaCitizen_Common_Sergeant_PresetColor") },
  { faction = "Brethren of the Coast", name = "Brethren Musketeer",
    params = objPath(FV .. "BrethrenOfTheCoast/CompositeMesh/Common/", "DA_NPC_AnimatedActor_BotC_Common_Musketeer_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "BrethrenOfTheCoast/Common/Musketeer/", "DA_AnimatedActor_BotC_Common_Musketeer_PresetColor") },
  { faction = "Brethren of the Coast", name = "Brethren Sailor",
    params = objPath(FV .. "BrethrenOfTheCoast/CompositeMesh/Common/", "DA_NPC_AnimatedActor_BotC_Common_Sailor_01_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "BrethrenOfTheCoast/Common/Sailor/", "DA_AnimatedActor_BotC_Common_Sailor_PresetColor") },
  { faction = "Brethren of the Coast", name = "Brethren Sergeant",
    params = objPath(FV .. "BrethrenOfTheCoast/CompositeMesh/Common/", "DA_NPC_AnimatedActor_BotC_Common_Sergeant_CompositeMeshComponentParams"),
    colorParams = objPath(FVC .. "BrethrenOfTheCoast/Common/Sergeant/", "DA_AnimatedActor_BotC_Common_Sergeant_PresetColor") },
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
      { match = "Female_Legs",              to = objPath(ARM .. "Conquistador/Meshes/", "SK_Armor_Conquistador_02_Male_Legs") },
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
-- BLACKBEARD FLAG RAID. Drop the flag with F7 (Composition_70, its own dedicated key) where a raid
-- should originate, then press F8: a wave of hostile Blackbeard pirates spawns at EACH placed flag and
-- charges the nearest bonfire. Reusable (press again = another wave), non-persisting, self-despawns.
-- See bbraid.lua. Enemy paths are the Blackbeard crew (regular auto-mixes musketeer/sailor archetypes,
-- officer = sergeant-tier). Toggle with BBRAID_ENABLED.
------------------------------------------------------------------
-- FORCE-DISABLED (2026-08-13) -- feature kept in place (bbraid.lua, this config, the raidflag/bbraid
-- keys in fkeys.lua) but not something the mod currently wants active. Flip back to `true` here AND
-- in config.txt to revive it -- it's also been pulled from the R5ModSettings panel (modsettings.lua),
-- so re-add its M.TOGGLE_DEFS/M.KEYBIND_DEFS entries too if you want it player-toggleable again.
Config.BBRAID_ENABLED = false
Config.BBRAID_FLAG_CLASS = "/Game/Gameplay/Foliage/FoliageActors/Shared/CampPropsComposition/BP_Shared_Camp_PropsComposition_70.BP_Shared_Camp_PropsComposition_70_C"
Config.BBRAID_REGULAR_CLASS = "/Game/Gameplay/Character/AI/Crew/Regular/Faction/Blackbeard/BP_Mob_Crew_Regular_Blackbeard.BP_Mob_Crew_Regular_Blackbeard_C"
Config.BBRAID_OFFICER_CLASS = "/Game/Gameplay/Character/AI/Crew/Officer/Faction/Blackbeard/BP_Mob_Crew_Officer_Blackbeard.BP_Mob_Crew_Officer_Blackbeard_C"
Config.BBRAID_BONFIRE_CLASS = "/Game/Gameplay/Building/Actors/BP_BuildingBlock_BuildingCenterT01.BP_BuildingBlock_BuildingCenterT01_C"
Config.BBRAID_REGULARS = 5        -- regulars per wave (per flag)
Config.BBRAID_OFFICERS = 1        -- officers per wave (per flag)
Config.BBRAID_SPREAD_UU = 350     -- pirates scatter this far around the flag on spawn
Config.BBRAID_STAGGER_MS = 400    -- one AI pawn per tick (a burst of AI spawns crashes natively)
Config.BBRAID_DESPAWN_MS = 300000 -- 5 min: survivors despawn if the player never kills them
Config.BBRAID_LEVEL_OFFSET = -2   -- target enemy level = player level + this (v1: best-effort; see bbraid)
Config.BBRAID_CHARGE_MS = 3000    -- re-issue the "charge the bonfire" order this often (nav needs a beat
                                  -- to init after spawn; a one-shot order beelines via stock nav)
Config.BBRAID_RUN_SPEED = 450     -- MaxWalkSpeed cap so raiders RUN the approach, not trudge at walk gait
Config.BBRAID_SPEED_MULT = 1.5    -- movement multiplier to push their cruise up to the cap (cap alone
                                  -- left the crew cruising well below it — see the FOLLOW speed notes)

-- PROTECT_STRUCTURES: make building blocks invulnerable so raiders (and anything else) can't damage the
-- base. Runtime-only (resets on reload). Applied in a couple of passes just after load (base streams in),
-- and instantly at raid start — which re-shields anything you built since. The flag stays set once
-- applied, so no perpetual sweep is needed. See Spawner.ShieldAllStructures.
Config.PROTECT_STRUCTURES = true

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

return Config