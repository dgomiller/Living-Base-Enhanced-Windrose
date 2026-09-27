LivingBase -- Base Building, Population & Character Customization Mod for Windrose
======================================================================

A placement and character toolkit for your base. Hand-drop ambient NPCs, animals, posed statues,
and decorations wherever you want them; build a fully custom character from scratch and dress it
piece by piece; set up a camera and lighting rig for screenshots; and let it all persist across
reloads. Plus a few base-life extras: a summonable crew escort and an unlock for hidden build-menu
pieces.

The ONLY way to spawn, move, or customize anything is a real clickable GUI window --
LivingBaseSpawnMenu, a companion mod bundled with this download. There is no keyboard-only spawn
scheme anymore; the numpad works for movement/confirmation/despawn/undo either in-game or with the
window focused, but every spawn and every customization goes through the window itself. Press '-'
(Numpad Minus) in-game to open it.

A UE4SS Lua mod (plus one compiled C++ companion) for Windrose (Kraken Express, UE 5.6,
single-player). Modding is unofficial -- keep save backups; a game patch may change class paths
(all centralized in Scripts/config.lua).

======================================================================
REQUIREMENTS / INSTALL
======================================================================

- UE4SS (latest experimental / GitHub RE-UE4SS build) with [EngineVersionOverride]
  MajorVersion=5, MinorVersion=6 in UE4SS-settings.ini.
- This download contains TWO mod folders -- install both:
    ...\R5\Binaries\Win64\ue4ss\Mods\LivingBase\ -- the mod itself (Lua).
    ...\R5\Binaries\Win64\ue4ss\Mods\LivingBaseSpawnMenu\ -- the GUI window (compiled). Required
    in practice -- it's the only way to spawn or customize anything now.
- Enable both with mods.txt lines:
    LivingBase : 1
    LivingBaseSpawnMenu : 1
  (an empty enabled.txt in each mod's own folder also works).
- Load into a game world. The GUI window takes a few seconds to appear after the loading screen
  finishes -- this is deliberate (see Known Limitations), not a bug. Press '-' (Numpad Minus) to
  open it once it's ready.
- Hot reload: run the "lbreload" console command to reload LivingBase's scripts without restarting
  the game or the world (see Console commands below). UE4SS's own Ctrl+R hot-reload keybind does
  NOT work in this game -- Windrose's native Dodge action is bound to plain Ctrl and claims it
  before UE4SS's key-hook layer ever sees a Ctrl+X combo reach it, so lbreload exists specifically
  as the working replacement. Note it wipes the mod's in-memory tracking -- despawn before running
  it, or just reload the world; placement/spawn actions re-recover tracking from the ledger
  automatically. (lbreload only reloads LivingBase's Lua -- LivingBaseSpawnMenu is a compiled DLL
  and needs a full game restart to pick up an update.)

======================================================================
THE GUI (LivingBaseSpawnMenu)
======================================================================

Opening it
----------------------------------------------------------------------
Numpad '-'   Open/close the window. Starts closed each session. Works from anywhere while
             playing.
Numpad '1'   Steal OS focus for the window, if it's already open -- handy right after Numpad
             '-' opens it, so your next click lands there instead of needing an extra click to
             switch windows first.

The window is a genuinely separate, always-on-top native window, not an overlay drawn on top of
the game -- you can drag it to another monitor, resize it, and it stays put across sessions of
use. It intentionally takes OS input focus while open (so its own keyboard shortcuts work), same
as switching between any two normal Windows applications; clicking back into the game returns
focus to it.

Six tabs across the top, each with a function-key shortcut while the window has focus (Target
List has no dedicated key -- click its tab directly):

Spawn and Move (F5)
----------------------------------------------------------------------
Spawn tree (left) -- click any entry to select it (highlights). Below the tree, a four-button
row:
  Confirm  Same as Numpad 0 -- locks the currently-previewed placement/relocation in place.
           Only enabled while something is actively following your camera.
  Spawn    Places a new copy of the selected look, following your camera until you Confirm
           (or Numpad 0) or Cancel (or Numpad /) it.
  Move     Same as Numpad * -- picks up whatever's currently target-locked and starts
           carrying it the same way a fresh spawn follows your camera (no snap-pop, measured
           from its actual current distance). Needs a target lock first.
  Replace  Swaps whatever's currently target-locked (see below) for the selected look, in
           the exact same spot. Needs a target lock first.
Refresh (above the tree) re-reads spawn_menu.ini from disk (see Customizing the spawn tree
below).

Move/edit panel (right):
  Selected Target       Shows whatever's currently target-locked. Hover if the name is
                         truncated.
  Floor Clipping        Lets a placed/relocated object clip through the floor instead of
                         resting on it (mirrors in-game Numpad '.').
  Forward/Left/Right/    Slide/raise/lower the target-locked object. Real held-repeat
  Backward/Up/Down       buttons (hold to keep moving) -- unlike the same in-game keys,
                         which this UE4SS build drops most rapid repeat presses for.
  Rotate X/Y/Z           (Roll/Pitch/Yaw) -- three full rows, each with its own
                         Left/Right button, so a placed prop can rest at any angle. All
                         three drive together in Rotate mode (Numpad 2).
  Coords                 Opens the precise coordinate editor (below). Only enabled with
                         something target-locked.
  Precision              Scales how far Up/Down/slide move per press (1/8 through 4x).
  Cancel                 Same as Numpad / -- cancels the active placement/relocation (a
                         fresh spawn is removed entirely; a grabbed/Move object reverts to
                         where it was). Only enabled mid-placement.
  Despawn / Undo         Same as Numpad 3 / Ctrl+Z, acting on the target-locked object.
  Delete All             Despawns EVERYTHING LivingBase has placed. Confirmation popup
                         first.

Everything above requires a target lock first and is greyed out until you have one -- and, like
every numpad key, stays disabled until your base has finished restoring on world load.

Customize (F6)
----------------------------------------------------------------------
Spawn a from-scratch custom character (pick a sex, Body Type, and Origin, then "Spawn Custom" --
it spawns nude except underwear, auto-locked as your target), then dress and pose it -- or any
other target-locked actor -- through five sections: Body (skin tone, eye color, physique, height,
AI toggle, one-way "Make Ghost"), Hair, Clothes (with a fit-safety net that substitutes underwear
instead of clipping on a known-bad combination), Belts and Straps (plus an Accessories
detect/randomize pair), and Poses and Actions. "Read Current" fills every control to match what
the target is actually wearing/using right now; "Save Customizations" writes the current setup to
disk against that specific actor so it survives a world reload (most rosters don't need this --
see Persistence below). Full breakdown in Features -- Customize tab below.

Photo Mode (F7)
----------------------------------------------------------------------
Camera positioning (Tripod/Selfie/First Person presets, a directional move pad, target highlight,
and a precise coordinate editor) plus a 3-slot portable lighting rig (enable, color, brightness,
throw per slot) for setting up screenshots. Not persisted across reloads by design.

Target List
----------------------------------------------------------------------
Scans tracked actors within a chosen radius (3/5/8/10/15m), filtered by four category checkboxes
(People/Monsterous/Animals/Decor), and lists them nearest-first with a small "+" button to
target-lock any one directly by index -- unlike Numpad+, this can lock something out of view
entirely, useful for finding it when you don't know where it ended up. A "+/-" button next to
Selected Target locks/releases the current target (same idiom as the Move panel), and a large
live-updating distance readout shows how far away whatever's locked currently is.

Mark Target checkbox -- while checked, highlights whatever's currently locked: a glowing marker
material on decor, or a following flame-ring effect (on people, animals, and monsters) that tracks
the target as it moves. Automatically clears when unchecked or when nothing's targeted.

Instructions & History
----------------------------------------------------------------------
Instructions renders the same reference this section covers, from inside the game (reads from
help.txt, so it can be edited without a rebuild). History shows every message that's appeared as
an on-screen toast this session -- handy for catching something you missed.

Coords window
----------------------------------------------------------------------
Opens a small editor with the target's exact X, Y, Z position and X, Y, Z rotation (Roll, Pitch,
Yaw -- 0-359 degrees each, not Unreal's native -180 to 180) as editable numbers. Typing doesn't
move anything by itself -- only these:

  Preview  Moves the object to whatever you've typed, without closing. Adjust and
           preview as many times as you like.
  Apply    Same as Preview, but closes the window -- the "I'm done" button.
  Reset    Moves the object back to wherever it was when the window opened, fields
           included. Stays open.
  Cancel   (or the window's own close button) -- same as Reset, but closes.

If you lock onto a different object -- or release the lock entirely -- while this window is open,
it closes itself without moving anything. While it's open, the target-lock's normal "walked too
far away, release the lock" check is suspended, so a typo in a coordinate can't strand you locked
onto something that just flew off into the distance. The Photo Mode camera has its own equivalent
Coords popup.

Customizing the spawn tree
----------------------------------------------------------------------
The tree's category structure comes from spawn_menu.ini, auto-generated on first load (one
section per look, pointing back at the real roster + index) and never overwritten after
that -- reorganize it, rename categories, regroup entries, however you like; re-running the
generator only ADDS anything new, it never touches or removes your edits.

======================================================================
NUMPAD CONTROLS (in-game AND with the GUI window focused)
======================================================================

The ONLY keys LivingBase uses. NumLock must be ON for the numpad to register -- with it OFF,
Windows remaps it to navigation keys before UE4SS ever sees it. Every key below requires the GUI
window to be OPEN except Numpad '-' itself (which opens it).

Move mode (default) / Rotate mode (after Numpad 2)
----------------------------------------------------------------------
| Key | Move mode | Rotate mode |
|-----|-----------|--------------|
| 7   | Up        | Rotate X-    |
| 8   | Forward   | Rotate Y-    |
| 9   | Down      | Rotate X+    |
| 4   | Left      | Rotate Z-    |
| 5   | Backward  | Rotate Y+    |
| 6   | Right     | Rotate Z+    |
| 2   | Change Mode (Move <-> Rotate) |

7/8/4/5/6 sit in the same plus-shape as W/A/S/D -- Change Mode sits on the corner key below that
cross, so it's not easy to mispress while moving. Entering an active placement/grab session (a
fresh Spawn, or Numpad *) auto-switches to Rotate mode -- movement doesn't apply to something
that's already following your camera every tick. Confirming (Numpad 0) or cancelling (Numpad /)
switches back to Move mode automatically.

Everything else
----------------------------------------------------------------------
Numpad 1   Release Cursor -- steals OS focus for the GUI window.
Numpad 3   Despawn whatever's in front of you, on your floor.
Numpad +   Target Lock -- toggle locking onto whatever's in front of you. Every move/edit
           key, the whole Customize tab, and Replace/Despawn/Coords all act on the locked
           object. Press again on something different to move the lock straight to it; press
           again on the same thing (or nothing) to release. Auto-releases (with a toast) if
           the locked object gets despawned or you walk ~19m away from it. A newly placed or
           spawned object becomes the lock automatically.
Numpad /   Cancel the current placement -- destroys the previewed object, no trace.
Numpad *   Grab -- picks up whatever's currently target-locked and carries it like a fresh
           placement, from its actual current distance (no snap-pop on pickup).
Numpad -   Open/close the GUI window.
Numpad 0   Confirm Placement -- locks the currently-previewed object in place. Nothing is
           written to the persistent save until this fires.
Numpad .   (decimal) Floor Clipping toggle.

While the GUI window has focus, it ALSO responds to: Arrows = slide, PageUp/PageDown = height
(GUI-only, no in-game equivalent); F1/F5/F6/F7/F10 = tab switches; F2/F3/F4 = Spawn/Replace/
Despawn; Ctrl+Z = Undo. These go through Windows' own key-repeat, so holding one works like a
held button -- unlike the same in-game keys, which this UE4SS build drops most rapid repeats for.

Remap anything by editing Config.KEYS in Scripts/config.lua.

======================================================================
FEATURES
======================================================================

GUI window (LivingBaseSpawnMenu)
----------------------------------------------------------------------
Six tabs -- a categorized clickable spawn tree with a held-repeat move/edit panel; a full
character-customization workspace (spawn-from-scratch, body, hair, clothes, belts/straps, poses);
a photo-mode camera + lighting rig; a Target List for locking any tracked actor by name/distance
plus a "Mark Target" highlight toggle; and an in-window Instructions/History reference. See "THE
GUI" above for the full breakdown.

Placement toolkit + live-edit
----------------------------------------------------------------------
Drop NPCs, animals, posed statues, and decorations, then nudge each one into place. Everything you
place is SAVED AND RESTORED on the next world load.

Live placement preview, relocate, and hover-highlight
----------------------------------------------------------------------
Decor and statues both: a fresh spawn follows your camera in real time before it's placed (Numpad
0 to confirm, Numpad / to cancel, Home/Pause to zoom), and Grab (Numpad *) picks up anything
already placed to carry it the same way. Placement snaps to the real floor/surface under your
reticle by default -- Floor Clipping toggles open placement instead, for spots the floor-lock
doesn't suit. Whatever your reticle is over lights up automatically so it's always clear what
you're about to target or grab.

Unique per-placement names
----------------------------------------------------------------------
Every placed object gets its own distinguishable name (e.g. "Brethren Woman 1", "Brethren Woman
2") instead of every copy of the same look sharing one identical label -- visible wherever a
target's name is shown (target-lock toasts, the GUI's Selected Target readout, the Coords window).
Stored in persist.txt, so names stay stable across reloads.

Senkamati -- Wild and Original Upright
----------------------------------------------------------------------
Two full presentations of the same Senkamati archetypes (Warrior, Hunter, Thrall, Caster), each
organized Mask On / Mask Off, and each with a moving and a frozen ("Idle," statue-like) version of
every entry:

- Wild -- the original re-skinned crew-based looks, on a naturally-upright human skeleton, with
  their own curated legs/underwear look on Caster/Hunter/Thrall (Warrior unchanged) instead of
  showing plain default underwear once the mask-off DeCorrupt pass hides the original leg armor.
- Original Upright -- the native Senkamati mob body given an upright walking gait via a foreign
  AI/animation pairing, purely cosmetic: it walks upright convincingly, but cannot fight with real
  weapons (melee/magic/unarmed attack animations are baked per character family and don't transfer
  to a foreign skeleton). Warrior and Hunter have their weapons stripped accordingly.

Both presentations restore correctly (mask state, weapons, idle freeze) on a world reload, not
just on first spawn.

Animals -- Mobile and Idle
----------------------------------------------------------------------
Every livestock family (boars, goats, dodos, wolves, crocodiles, plus crabs) has a wandering
"(Mobile)" version and a frozen, statue-like "(Idle)" version of every individual look --
previously only the "Corrupted"/monstrous variants had this Idle option; now the ordinary wildlife
does too.

Drops (18 themed decoration categories)
----------------------------------------------------------------------
A dedicated decor branch covering everything from weapon and armor pieces to currency,
ingredients, and treasure -- Animal Parts, Artifacts, Clothes, Currency, Ingredients, Keys, Meals,
Mined, Misc, Potions/Bottles/Healing, Seeds, Tailoring, Tools, Treasure, Trophies, Weapons, Wood,
Writings. Every entry has a real display name (e.g. "Bezoar," not "Loot_T02_Bezoar_01").

Console commands
----------------------------------------------------------------------
Type these into UE4SS's console (the same input used for the game's own dev/cheat commands) for
spawning by name instead of browsing the tree. All print their response both on-screen and to
ue4ss.log (look for [LivingBase] lines).

lblook <name>          Spawns one of LivingBase's own NAMED LOOKS -- a base class plus its full
                        reskin/de-corrupt/pacify recipe. This is what the GUI's Spawn button
                        uses internally, by name.
lblook list             Lists every category (crew, townsman, standing, seated, chair,
                        interactive, senka, animals, women, decor) with a count.
lblook list <category>  Lists every name in one category, e.g. "lblook list crew" or
                        "lblook list senka".
lblook list all         Dumps every name in every category at once.
lbspawn <ShortName>     Spawns a RAW ENGINE CLASS, with none of this mod's re-skin/
 or <full /Game/...     de-corrupt/pacify recipe applied -- just the game's own default
 path>                  look/behavior. Short names resolve through a generated index of
                        ~2,500 known BP_ classes; anything not in that index needs the
                        full path.
lbspawn list /          Same idea as lblook's listing, but for LivingBase's own statue/decor
lbspawn list <category>/rosters specifically -- reference only, not a guarantee those exact
lbspawn list all        names resolve as short-name input.
lbreload (no args)      Reloads LivingBase's Lua from disk WITHOUT restarting the game or
                        reloading the world -- picks up script edits immediately. Doesn't
                        affect content-pak changes or the GUI's own compiled DLL (both need a
                        full relaunch); tracked spawns recover automatically afterward.
lbunlockclothes         Toggles the Customize tab's Clothes fit-safety net on/off (see the
 (no args)              Customize tab section below). Off by default. Prints a one-time
                        caveat when turned on: an unlocked piece/body combination hasn't been
                        visually reviewed and may clip.

When to use which: if you want the mod's actual recipe (correct faction, posture, gear, etc.) use
lblook. If you want to spawn something completely untouched -- including things this mod doesn't
otherwise place -- use lbspawn. You'll see an occasional "Error: A custom console command handle
must return true or false" line after running any of these -- that's harmless UE4SS noise tied to
how this build checks a console command's return value, not a real failure.

Walking Women
----------------------------------------------------------------------
A real, walking female NPC, spawnable as one of four looks: Letty, Marita Suares, and the
Buccaneers Merchant each wear their own real, distinct outfit; a fourth, plain "Woman" entry
rounds out the roster with an outfit, hat presence, and hair that all vary naturally for general
crowd variety. Every placement also rolls a random skin tone. Reloading correctly restores which
look each placed NPC was standing in for.

Customize tab (GUI only -- spawn-from-scratch character + full appearance/pose editor)
----------------------------------------------------------------------
The Customize tab (F6) works on the currently target-locked actor -- lock onto something first
(Numpad +), or spawn a fresh custom character (which auto-locks itself).

- Spawn (collapsed by default) -- builds a brand-new character from scratch: pick a sex, a Body
  Type, and an Origin (donor figure/ethnicity), then "Spawn Custom." Spawns nude except underwear,
  ready to dress via the sections below -- the only way to get a genuinely custom body combination
  beyond this mod's other fixed rosters.
- Selected Target -- shows the current lock. "Read Current" scans the target's live appearance and
  fills every control below to match what it's actually wearing/using right now (disabled for a
  target this mod hasn't finished detecting yet, and for animals/decor/statues, which have no
  clothing/hair to read). "Save Customizations" writes everything below to disk against that
  specific actor's own persistent name, so it survives a world reload exactly as left -- most
  rosters DON'T need this (see Persistence below); use it only when you want a specific change kept.
- Body -- Skin Tone and Eye Color swatches, a Physique dropdown, and a Height slider (3'-8'',
  ground-compensated). Toggle AI starts/stops the target's own AI logic (reversible; greyed out for
  statues/decor). Make Ghost permanently reskins the target as a ghost -- clearly marked NOT
  REVERSIBLE.
- Hair (109 entries) -- swaps hairstyle and hair color, organized by style/headwear-compatible
  variant/cut. Sex-detected automatically.
- Clothes (304 entries) -- swaps one clothing/armor slot at a time and its palette color, spanning
  the ordinary armor catalog plus the tribal Senkamati sets. The fit-safety net (see
  lbunlockclothes above) substitutes underwear instead of letting a known-bad combination clip,
  and holds back several male-cut families from female targets by default. "Remove" (16 entries:
  one per slot, plus "All") takes a piece off instead of swapping it.
- Belts and Straps -- Belt/Sling/Strap/Frog attachment pieces, plus an Accessories section with
  Detect (reads what's currently equipped) and Randomize (rolls a fresh random set), and its own
  Belt and Straps Location Guide reference.
- Poses and Actions (221 entries) -- plays a specific real animation on the target (idle stances,
  sitting poses, work-bench activity, combat animations, and more), organized by category. Works
  on walking crew/NPCs, posed statues, even raw native mob skeletons. A small number of
  combat/ability-themed poses carry real gameplay damage baked into their own animation notifies
  regardless of who's playing them -- test those from a safe distance, not right next to yourself.

None of this needs a numpad key or a roster to cycle through -- browse and click.

Photo Mode tab (GUI only -- camera + lighting for screenshots)
----------------------------------------------------------------------
Camera: three starting presets (Tripod, Selfie, First Person, each with its own Reset), a Target
Highlight toggle, a directional move pad, and a Coords button for precise camera placement (same
Preview/Apply/Reset/Cancel shape as the object Coords window). Lights: a 3-slot portable rig --
each slot toggles Enable/Disable (spawns/despawns a light the same way any other placement works),
a Color swatch, and Brightness/Throw sliders. Not persisted across reloads by design.

Cycle (']' / '[') and target highlighting
----------------------------------------------------------------------
']'/'[' cycle the targeted statue or decoration forward/backward through its own roster in place
(facing preserved for statues). Whatever your reticle is over highlights automatically whenever
the GUI window is open, independent of target lock, so it's always clear what Numpad + or Grab
would act on before you commit.

Undo (Ctrl+Z, or the GUI's Undo button)
----------------------------------------------------------------------
Restores whatever was most recently despawned -- a single despawn, an entire Delete All wipe
(restored as one batch), or a cycle swap. Since a destroyed actor can't literally come back, this
respawns a fresh copy of the same class at the exact same position/rotation, using data
cross-checked against persist.txt -- for actors with a recorded appearance (e.g. a custom
character or re-skinned crew member), that appearance is restored too. Steps back through your
last 20 despawn actions if pressed repeatedly. Names what it restored on-screen.

On-screen feedback (toasts)
----------------------------------------------------------------------
Despawn, undo, cycle, spawn, and restore progress all confirm on-screen -- not just in
ue4ss.log -- by splicing a message into the game's own native side-notification widget, so it
looks and behaves like a normal game notification. Every toast is also logged to the GUI's
History tab.

Persistence & clean-house
----------------------------------------------------------------------
Windrose doesn't save mod-spawned actors, so LivingBase records every placement to persist.txt
(class, full position/rotation, look, and its unique display name) and re-spawns it on world load.

- If you play multiple Windrose worlds, each one gets its own save automatically --
  persist_<world id>.txt / spawn_ledger_<world id>.txt.
- Config.RESTORE_ON_LOAD = true (default) repopulates on load (not on lbreload). false = place
  fresh each session.
- Delete All despawns everything and clears the save file for the current world.
- Most rosters' appearance is NOT persisted by default -- a mask-off Original Upright Senkamati,
  for instance, regenerates a fresh look on every world load exactly as if it were a brand-new
  spawn, the same way the game's own native NPCs work, rather than locking in whatever it happened
  to roll the first time. Use "Save Customizations" (Customize tab) on a specific actor if you want
  its exact current appearance to survive a reload instead.
- Every mod key AND the GUI's buttons are locked from the moment a world load is detected until the
  restore genuinely finishes (or determines there's nothing to restore) -- everything unlocks
  automatically; Numpad '-' and '1' still work throughout in case you need to override it.

Whistle crew escort (WHISTLE_CREW)
----------------------------------------------------------------------
Use the boar whistle and instead of a boar you get a small crew escort that follows you and fights
at your side. Transient (never persisted).

Unlock hidden build pieces (UNLOCK_HIDDEN_BUILDING)
----------------------------------------------------------------------
Surfaces build-menu pieces that are hidden from standard play (cut/dev content) while leaving
normal progression intact -- it never unlocks pieces you're meant to earn. Runtime-only; open the
build menu once after loading so the catalog is present.

======================================================================
CONFIGURATION
======================================================================

There are two files:

config.txt          Plain-text overrides you can edit without touching Lua. Lines are
                     NAME = value (true/false or numbers). This is the one file you
                     normally edit; it overrides the defaults. Current toggles include
                     WHISTLE_CREW, UNLOCK_HIDDEN_BUILDING, LIVE_EDIT.
Scripts/config.lua  The shipped defaults and all class paths. Highlights:
  - Config.KEYS -- the numpad keymap (see NUMPAD CONTROLS above).
  - Config.VERBOSE -- false (quiet); true for per-spawn debug logging.
  - Config.LIVE_EDIT_MOVE_STEP / LIVE_EDIT_HEIGHT_STEP / LIVE_EDIT_ROTATE_STEP -- per-press
    step sizes for the move panel's slide/height/rotate buttons.
  - Config.TARGET_MIN_VIEW_DOT (0.90) -- how directly your camera needs to be looking at an
    object for it to be picked as the reticle target (despawn, cycle, target lock). Lower =
    more forgiving/wider; higher = you have to look more squarely at it.
  - Config.TARGET_LOCK_MAX_DIST (1500.0, ~15m -- this mod's own convention is 100uu = 1m) --
    how far you can walk from a target-locked object before the lock auto-releases.
    Suspended entirely while a Coords window is open.
  - Config.DECOR_CATEGORIES (in Scripts/fkeys.lua) -- the six base decoration lists plus 18
    themed Drops categories.
  - Config.DECOR_COLLISION (true) -- placed decorations are solid (physics frozen so they
    can't drift). false = pass-through.
  - Statue rosters: STANDING_STATUES (includes the women and quest-folk actors),
    SEATED_STATUES, CHAIR_STATUES, INTERACTIVE_STATUES.
  - Config.HANDYMAN_FOR_TOWNSFOLK (true) -- townsmen wander AND use furniture.
  - Config.HIDE_NAMEPLATES (true) -- hide floating name/role tags on placed NPCs.

======================================================================
KNOWN LIMITATIONS
======================================================================

- The GUI window takes a few seconds to appear after the game finishes loading -- deliberate: its
  own render thread waits before creating its device/swapchain, so Steam's overlay hook attaches to
  the game's real swapchain first instead of this window's (otherwise Steam's F12 screenshot and
  FPS-counter target the GUI instead of the game). Not a bug; give it a moment on launch.
- Occasional native crash during a long, active placement/relocate session (an object still
  following your camera, especially with a lot of movement) -- an engine-level UE4SS fragility, not
  something Lua-side error handling can catch. Confirming or cancelling a placement sooner rather
  than carrying an object around for a long stretch lowers the odds of hitting it.
- The numpad direction/operator keys drop most rapid repeat presses before UE4SS ever sees them
  when used IN-GAME -- an engine-level limitation. The GUI's own buttons and numpad handling don't
  have this problem.
- The Brethren of the Coast "woman" crew re-skin currently has a male body under the female
  clothing -- known, not yet fixed.
- Original Upright Senkamati (the upright-gait cosmetic variants) walk convincingly upright but
  cannot fight with real weapons -- melee/magic/unarmed attack animations are baked per character
  family and don't transfer to the foreign skeleton pairing used to get the upright gait. Cosmetic
  only, by design; Warrior and Hunter have their weapons stripped accordingly.
- Outfit/hair PALETTE COLOR can be changed via the Customize tab's Clothes/Hair sections for
  anything this mod places -- this replaces an earlier limitation where color was believed to be a
  hard engine restriction; it turned out to be reachable via the same Custom Primitive Data
  mechanism the game's own character customization uses, just not through any UI the base game
  exposes.

Note on townsfolk: the townsman entry spawns a mixed-sex crowd of dressed, wandering NPCs (men and
women) that also use nearby furniture. The statue entries are intentionally static posed actors --
that's the feature, not a limitation.

======================================================================
LICENSE / OWNERSHIP
======================================================================

All rights reserved by default, except for the specific permissions below -- nothing here
is implied beyond what's listed. See LICENSE (in this mod's own folder) for the full text.

Permitted, without needing to ask:
  1. Modify this mod for your own personal use.
  2. Reuse this mod's code or assets in your own separate mod, WITH CREDIT.
  3. Convert or port this mod to other games, WITH CREDIT.

Not permitted:
  1. Reuploading or rehosting this mod -- modified or unmodified -- anywhere other than
     the original author's own page(s)/repo(s). If you build something on top of it, link
     back to the original instead of rehosting it.
  2. Selling this mod, or using it in anything sold or monetized, in whole or in part.
     (Nexus Mods' own Donation Points system is fine -- that's Nexus's own charity-linked
     mechanism, not third-party monetization.)

This covers this fork's own code and content. The original Living Base toolkit this
project builds on remains public domain under its own author's terms (see Credits below);
Windrose and its game assets, class names, and intellectual property belong to Kraken
Express -- this is an unofficial, unaffiliated mod.

======================================================================
CREDITS
======================================================================

This project started as a fork of Living Base
(https://www.nexusmods.com/windrose/mods/519) by me123420
(https://www.nexusmods.com/profile/me123420) -- thank you to them for the original
concept and toolkit, and for open-sourcing it into the public domain in the first place.
The amount that's changed since then means this README no longer walks through it
point-by-point, but the debt is real and gladly acknowledged.

Thanks also to IceBoxStudio (https://www.nexusmods.com/windrose/users/77413713) for
Windrose Mod Settings (https://www.nexusmods.com/windrose/mods/442), which this mod
optionally integrates with for in-game keybind/toggle configuration.

Thanks also to irecode (https://www.nexusmods.com/profile/irecode) for a resource this mod
relies on.

Built iteratively with Claude.

======================================================================

See CLAUDE.md and WINDROSE_MODDING_NOTES.md (bundled separately in the optional
LivingBaseEnhancedDevInfo.zip download) for the full technical history and engine
findings, and ASSET_CATALOG.md for the spawnable-asset database.
