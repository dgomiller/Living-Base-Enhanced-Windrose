[size=5][b]Living Base Enhanced — Base Building & Population Mod for Windrose[/b][/size]
[color=#D4D4D8]A placement toolkit for your base. Hand-drop ambient NPCs, animals, posed statues, and decorations wherever you want them, fine-tune each piece in place, and let it all persist across reloads. Plus a few base-life extras: a summonable crew escort and an unlock for hidden build-menu pieces.[/color]

[color=#D4D4D8][b]The primary way to use this mod is a real clickable GUI window[/b] — LivingBaseSpawnMenu, a companion mod bundled with this download. Press '-' in-game to open it: a categorized spawn tree, held-repeat movement buttons with full X/Y/Z rotation, and a precise coordinate editor, instead of cycling numpad keys one press at a time. Every keyboard control still works exactly as before and is fully documented further down — the GUI doesn't replace anything, it's just the faster, easier way to reach the same rosters.[/color]

[color=#D4D4D8]A UE4SS Lua mod (plus one compiled C++ companion) for Windrose (Kraken Express, UE 5.6, single-player). Modding is unofficial — keep save backups; a game patch may change class paths (all centralized in Scripts/config.lua).[/color]

[size=4][b]Requirements / install[/b][/size]
[color=#D4D4D8][list]
[*]UE4SS (latest experimental / GitHub RE-UE4SS build) with [EngineVersionOverride] MajorVersion=5, MinorVersion=6 in UE4SS-settings.ini.
[*]This download contains TWO mod folders — install both: …\R5\Binaries\Win64\ue4ss\Mods\LivingBase\ (the mod itself) and …\R5\Binaries\Win64\ue4ss\Mods\LivingBaseSpawnMenu\ (the GUI window). LivingBaseSpawnMenu is optional in principle — LivingBase works fine with only keyboard controls if you skip it — but it's the intended way to use the mod now.
[*]Enable both with mods.txt lines: LivingBase : 1 and LivingBaseSpawnMenu : 1 (an empty enabled.txt in each mod's own folder also works).
[*]Load into a game world. Press '-' to open the GUI, or use the keyboard controls below directly.
[*]Hot reload: run the lbreload console command to reload LivingBase's scripts without restarting the game or the world (see Console Commands below). UE4SS's own Ctrl+R hot-reload keybind does NOT work in this game — Windrose's native Dodge action is bound to plain Ctrl and claims it before UE4SS's key-hook layer ever sees a Ctrl+X combo reach it, so lbreload exists specifically as the working replacement. Note it wipes the mod's in-memory tracking — despawn (Delete) before running it, or just reload the world; placement keys re-recover tracking from the ledger automatically. (lbreload only reloads LivingBase's Lua — LivingBaseSpawnMenu is a compiled DLL and needs a full game restart to pick up an update.)
[/list][/color]

[size=4][b]The GUI (LivingBaseSpawnMenu)[/b][/size]

[color=#D4D4D8][b]Opening it[/b]
'-' — Open/close the window. Starts closed each session. Works from anywhere while playing, regardless of the In-Game Keys toggle below.
'=' — Steal OS focus for the window, if it's already open — handy right after '-' opens it, so your next click lands there instead of needing an extra click just to switch windows first. Does nothing if the window is closed.

The window is a genuinely separate, always-on-top native window, not an overlay drawn on top of the game — you can drag it, resize it, and it stays put across sessions of use.[/color]

[color=#D4D4D8][b]Tools tab[/b]
Spawn tree (left) — click any entry to select it (highlights), then:
[list]
[*]Spawn — places a new copy of the selected look in front of you, same result as pressing that roster's numpad key enough times to cycle to it.
[*]Replace — swaps whatever's currently target-locked (see below) for the selected look, in the exact same spot. Needs a target lock first — more precise than the old ]/[ cycle keys, since you jump straight to any specific look instead of stepping through the roster.
[*]Refresh — re-reads spawn_menu.ini from disk (see Customizing the spawn tree below).
[/list]

Move/edit panel (right):
[list]
[*]Selected Target — shows whatever's currently target-locked. Hover if the name is truncated.
[*]In-Game Keys — mirrors the in-game Insert key, but ONLY turns LivingBase's own keyboard keys on/off (placement, live-edit, cycle, clear) — it does NOT affect this panel's own buttons, which work regardless. Off by default each session (see Configuration).
[*]Forward / Left / Right / Backward / Up / Down — slide/raise/lower the target-locked object. Real held-repeat buttons (hold to keep moving) — unlike the same in-game keys, which this UE4SS build drops most rapid repeat presses for.
[*]Rotate X / Y / Z (Roll / Pitch / Yaw) — three full rows, each with its own Left/Right button, so a placed prop can rest at any angle, not just spin around its vertical axis.
[*]Coords — opens the precise coordinate editor (below). Only enabled with something target-locked.
[*]Precision — scales how far Up/Down/slide/rotate move per press (1/8 through 4x).
[*]Despawn / Undo — same as Num9/Num0, acting on the target-locked object.
[*]Delete All — despawns EVERYTHING LivingBase has placed. Confirmation popup first.
[*]All of the above (except In-Game Keys itself) require a target lock first and are greyed out until you have one — and, like every keyboard key, stay disabled until your base has finished restoring on world load.
[/list][/color]

[color=#D4D4D8][b]Coords window[/b]
Opens a small editor with the target's exact X, Y, Z position and X, Y, Z rotation (Roll, Pitch, Yaw — 0–359° each, not Unreal's native −180 to 180) as editable numbers. Typing doesn't move anything by itself — only these:
[list]
[*]Preview — moves the object to whatever you've typed, without closing. Adjust and preview as many times as you like.
[*]Apply — same as Preview, but closes the window — the "I'm done" button.
[*]Reset — moves the object back to wherever it was when the window opened, fields included. Stays open.
[*]Cancel (or the window's own close button) — same as Reset, but closes.
[/list]

If you lock onto a different object — or release the lock entirely — while this window is open, it closes itself without moving anything. While it's open, the target-lock's normal "walked too far away, release the lock" check is suspended, so a typo in a coordinate can't strand you locked onto something that just flew off into the distance.[/color]

[color=#D4D4D8][b]Instructions & History tabs[/b]
Instructions renders this same reference from inside the game (so it can be edited without a rebuild). History shows every message that's appeared as an on-screen toast this session — handy for catching something you missed.[/color]

[color=#D4D4D8][b]Customizing the spawn tree[/b]
The tree's category structure comes from spawn_menu.ini, auto-generated on first load and never overwritten after that — reorganize it, rename categories, regroup entries, however you like; re-running the generator only ADDS anything new, it never touches or removes your edits.[/color]

[size=4][b]Keyboard controls (still fully available)[/b][/size]
[color=#D4D4D8]Everything below works exactly as it always has — the GUI is an additional way to reach it, not a replacement. NumLock must be ON for the numpad keys to register.[/color]

[color=#D4D4D8][b]Numpad[/b] — place NPCs, statues & animals (one per press, ~3m ahead in your camera direction; statues face you):
Num 1 — Crew pawn (wanders; fights hostiles as a combat ally; cycles 14 looks — default crew, plus 12 walking faction-visitor re-skins across Buccaneers/Smugglers/People of Tortuga/Brethren of the Coast, plus a Brethren of the Coast woman)
Num 2 — Townsman (wanders; sits on chairs/benches/beds)
Num 3 — Standing statue (merchants, chatting, cross-arms, women, quest folk, named faction leaders — cycles)
Num 4 — Floor sitter (cycles)
Num 5 — Chair/stool sitter: place your own stool (cycles)
Num 6 — Interactive statue: rummaging a chest/table, warming by a fire (cycles)
Num 7 — Friendly Senkamati tribal human: Warrior, Hunter, and female Caster (with/without helmet, original mob body vs. re-skinned where applicable — the female Caster's re-skin comes in two base bodies, Gatherer and Herbalist, each with distinct figure/hair-color/palette — plus each one's original corrupted look. Every look also has a frozen/idle counterpart, including the Herbalist-base Caster — cycles)
Num 8 — Friendly wildlife: boar family / goats / dodos / wolves / crocodile (cycles)
Num 9 — Despawn the object in front of you, on your floor
Num 0 — Undo: restore the last despawn (or a whole Delete wipe) at its exact spot, appearance included; names what it restored
Num . (decimal) — Walking female NPC: cycles 8 looks — Woman, the Buccaneers Merchant, Letty, and Marita, each in two base bodies (Base 1 = Gatherer, Base 2 = Herbalist, two different NPC classes with genuinely different figure/hair-color/outfit palette). Letty/Marita/Merchant each wear their own real, distinct outfit; Woman's outfit, hat presence, and hair vary naturally on their own. Every placement also rolls a random skin tone.
Backslash (\) — Flip statue facing 180° for future spawns only[/color]

[color=#D4D4D8][b]Cycle a placed statue/decoration[/b] (not numpad — reticle-targeted, same as despawn):
] — Cycle the targeted statue or decoration forward through its own roster, in place (undo-able)
[ — Cycle it backward instead[/color]

[color=#D4D4D8][b]Decorations[/b]:
' (apostrophe) — Change the active decoration category: nature, boats, wrecks, tents, storage, furniture, plus 18 themed Drops categories (Animal Parts, Artifacts, Clothes, Currency, Ingredients, Keys, Meals, Mined, Misc, Potions/Bottles/Healing, Seeds, Tailoring, Tools, Treasure, Trophies, Weapons, Wood, Writings) — announces which one on-screen; doesn't place anything
; (semicolon) — Place one decoration from the active category (cycles its own list, same as the other placement keys)[/color]

[color=#D4D4D8][b]Live-edit[/b] — tunes the nearest placed piece; persists:
PageUp / PageDown — Raise / lower
Comma / Period — Rotate the currently-selected axis left / right (X/Y/Z = Roll/Pitch/Yaw; starts on Z, so these behave exactly like a plain yaw rotate until / is pressed at least once)
/ (plain, not Num /) — Cycle which axis Comma/Period rotate (X -> Y -> Z -> X), toast-confirmed, shared with the GUI's own '/' shortcut
Num / — Rotate a fixed 45° (Yaw)
Num * — Rotate a fixed 180° (flip in place, Yaw)
Arrow keys — Slide forward / back / left / right, along a fixed world direction for decorations/objects (the same press always moves it the same way regardless of which way you're facing) — statues and NPCs still slide along their own facing instead
Num - — Cycle precision: 1/8 -> 1/4 -> 1/2 -> 1x (normal) -> 2x -> 4x -> back to 1/8, for the slide/height keys AND rotation together
Num + — Toggle target lock: pin despawn (Num 9), ]/[ cycle, and every live-edit key above — plus the GUI's move panel/Despawn/Coords/Replace — to the object in front of you, so they keep hitting it even after you walk away or look elsewhere. Press again to release; auto-releases if the locked object gets despawned, or if you walk more than ~15m away from it. Always active regardless of the In-Game Keys toggle, since the GUI depends on it. Placing anything new locks it automatically.

Reliability note: arrows, PageUp/PageDown, and the numpad operator keys (/ * -) aren't in this UE4SS build's normal key table and only work via a raw-key-code fallback. In practice this means the game drops most rapid repeat presses for these specific keys before UE4SS ever sees them — holding or mashing won't give you smooth continuous movement. The GUI's move panel buttons don't have this problem — they're real held-repeat UI buttons, not raw key hooks.[/color]

[color=#D4D4D8][b]Placement preview & relocate[/b] — decor and statues both:
F5 — Confirm the object currently following your camera (a fresh spawn, or something grabbed with F7) in its current spot.
F6 — Cancel: a fresh spawn is removed entirely; a grabbed object reverts to exactly where it was before you grabbed it.
F7 — Grab the target-locked object and carry it the same way a fresh spawn follows your camera, from its actual current distance (no snap-pop).
F8 — Toggle Free-build. OFF (default) snaps placement/relocation to the real floor/surface under your reticle (a forward raycast along your camera). ON uses open placement at a fixed distance instead, for spots the floor-lock doesn't suit. Blocked while something is actively following your camera — switch before you start, not mid-drag.
Home / Pause — Zoom the followed object closer / farther while it's following your camera.
Whatever's under your reticle also highlights automatically the moment the GUI window is open, independent of target lock, so it's always clear what Num+/F7 would act on before you commit.[/color]

[color=#D4D4D8][b]Housekeeping[/b]:
Delete (x2) — Clean house: despawn everything (press twice within a few seconds to confirm)
Insert — Toggle LivingBase's own keyboard keys on/off — does NOT affect the GUI window or its buttons, which work independently by design. Starting state controlled by config.txt's KEYS_ENABLED_ONSTART, off by default (set true for an always-on start instead).[/color]

[color=#D4D4D8]Remap anything by editing Config.KEYS in Scripts\config.lua.[/color]

[size=4][b]Main Features[/b][/size]

[color=#D4D4D8][b]GUI window (LivingBaseSpawnMenu)[/b]
A categorized, clickable spawn tree; a held-repeat move/edit panel with full X/Y/Z rotation that doesn't suffer the keyboard's dropped-repeat-press problem; a precise typed coordinate editor (X/Y/Z position and X/Y/Z rotation); and an in-window Instructions/History reference.[/color]

[color=#D4D4D8][b]Placement toolkit + live-edit[/b]
Drop NPCs, animals, posed statues, and decorations, then nudge each one into place — via the GUI or the keyboard live-edit keys (height, rotation, slide, a 6-level precision cycle, and a target lock to pin your edits to one object). Everything you place is saved and restored on the next world load.[/color]

[color=#D4D4D8][b]Live placement preview, relocate, and hover-highlight (F5/F6/F7/F8)[/b]
Decor and statues both: a fresh spawn follows your camera in real time before it's placed (F5 to confirm, F6 to cancel, Home/Pause to zoom), and F7 grabs anything already placed to carry it the same way. Placement snaps to the real floor/surface under your reticle by default — F8 toggles Free-build for open placement instead. Whatever your reticle is over lights up automatically so it's always clear what you're about to target or grab.[/color]

[color=#D4D4D8][b]Unique per-placement names[/b]
Every placed object gets its own distinguishable name (e.g. "Brethren Woman 1", "Brethren Woman 2") instead of every copy of the same look sharing one identical label. Stored in persist.txt, so names stay stable across reloads; an older save gets names assigned automatically the first time it restores.[/color]

[color=#D4D4D8][b]Console commands[/b]
Type these into UE4SS's console (the same input used for the game's own dev/cheat commands) for spawning by name instead of cycling a numpad key. All three print their response both on-screen and to ue4ss.log (look for [LivingBase] lines).

lblook <name> — Spawns one of LivingBase's own named looks — a base class plus its full reskin/de-corrupt/pacify recipe (e.g. lblook Letty, lblook Buccaneers Musketeer, lblook Warrior_crew_Mask, lblook Boar). This is what every numpad placement key (and the GUI's Spawn button) uses internally, by name.
lblook list / lblook list <category> / lblook list all — Lists categories (crew, townsman, standing, seated, chair, interactive, senka, animals, women, decor), or every name within one, or everything at once.

lbspawn <ShortName|full /Game/... path> — Spawns a raw engine class, with none of this mod's re-skin/de-corrupt/pacify recipe applied — just the game's own default look/behavior. Short names resolve through a generated index of ~2,500 known BP_ classes; anything not in that index needs the full path (e.g. lbspawn BP_Mob_Wolf).
lbspawn list / lbspawn list <category> / lbspawn list all — Same idea, for LivingBase's own statue/decor rosters specifically — reference only, not a guarantee those exact names resolve as short-name input.

lbreload — Reloads LivingBase's Lua from disk without restarting the game or reloading the world — picks up script edits immediately. Doesn't affect content-pak changes or the GUI's own compiled DLL (both need a full relaunch); tracked spawns recover automatically afterward.

lbunlockclothes — Toggles the Custom > Clothes fit-safety net on/off (see the Custom category section above) — off by default. Prints a one-time caveat when turned on: an unlocked piece/body combination hasn't been visually reviewed and may clip.

When to use which: if you want the mod's actual recipe (correct faction, posture, gear, etc.) use lblook. If you want to spawn something completely untouched — including things this mod doesn't otherwise place — use lbspawn. You'll see an occasional "Error: A custom console command handle must return true or false" line after running any of these — that's harmless UE4SS noise, not a real failure.[/color]

[color=#D4D4D8][b]Cycle (] / [)[/b]
Swaps the statue OR decoration in front of you for the next (or previous) entry in its own roster (the Num 3–6 statue lists, or its own decoration category) — same spot, facing preserved for statues. One key pair auto-detects which kind of roster the targeted actor's class belongs to. Undo-able with Num 0. The GUI's Replace button does the same job with a direct pick instead of stepping through the roster.[/color]

[color=#D4D4D8][b]Walking Women (Num . / decimal, or the GUI's "Walking Women" category)[/b]
A real, walking female NPC, spawnable as one of four looks instead of only being available as a frozen statue: Letty, Marita Suares, and the Buccaneers Merchant each wear their own real, distinct outfit — not a shared generic look with pieces patched onto it. A fourth, plain "Woman" entry rounds out the roster with an outfit, hat presence, and hair that all vary naturally on their own for general crowd variety. Every placement also rolls a random skin tone — this re-rolls on every placement and every reload, on purpose. Reloading correctly restores which look/character each placed NPC was standing in for (and upgrades anyone placed before v3.0.0 to her real outfit automatically).[/color]

[color=#D4D4D8][b]Custom category (GUI only — Poses, Skin Tones, Hair, Clothes)[/b]
A fourth GUI branch, "Custom," works differently from every other spawn-tree category: its entries don't place a new actor at all — they modify whatever's currently target-locked (Numpad +), in place. Select an entry and press Spawn (Replace also works identically here, since there's nothing to destroy-and-recreate).

• [b]Poses[/b] (221 entries) — plays a specific real animation on the targeted actor (an idle stance, a sitting pose, a work-bench activity, a combat animation, etc.), organized by category/subcategory. Works on any actor this mod places — walking crew/NPCs, posed statues, even the raw native mob skeletons. A small number of combat/ability-themed poses carry real gameplay damage baked into their own animation notifies regardless of who's playing them — test those from a safe distance.
• [b]Skin Tones[/b] (9 entries) — swaps the targeted actor's skin material to one of the game's 7 ethnicity families, plus two "Corrupted" (Senkamati) variants. Sex-detected automatically.
• [b]Hair[/b] (109 entries) — swaps the targeted actor's hairstyle, organized by style then by headwear-compatible variant (Default / Hat / Headband / Bandana) and, for styles with multiple distinct cuts, by number. Sex-detected automatically.
• [b]Clothes[/b] (304 entries) — swaps one clothing/armor slot at a time (Torso, Legs, Headgear, etc.), organized by family then slot then piece name, spanning the ordinary armor catalog plus the tribal Senkamati sets. A built-in fit-safety net applies automatically: a piece known not to fit a given body substitutes plain underwear instead of clipping, and several male-cut families are held back from female targets unless unlocked — both cases say clearly on-screen when a substitution happened. "Clothes > Remove" (16 entries: one per slot, plus "All") removes a piece instead of swapping it — Torso/Legs on an unlocked-off target become underwear rather than true nudity; every other slot just hides outright.
• The clothing fit restrictions above are OFF by default; the "lbunlockclothes" console command toggles them, printing a one-time caveat that an unlocked combination hasn't been visually reviewed and may clip.

None of this needs a numpad key or a roster to cycle through — browse and click, same as every other GUI category.[/color]

[color=#D4D4D8][b]Undo (Num 0, or the GUI's Undo button)[/b]
Restores whatever was most recently despawned — a single Num 9 despawn, an entire Delete clean-house wipe (restored as one batch, in one press), or a ]/[ cycle (removes the new pick and brings back the old one). This respawns a fresh copy of the same class at the exact same position/rotation, using data cross-checked against persist.txt — for actors with a recorded composite look (e.g. a re-skinned crew member), that appearance is restored too, not just a default look. Steps back through your last 20 despawn actions if pressed repeatedly. Names what it restored on-screen (up to 5 by name, "+N more" beyond that).[/color]

[color=#D4D4D8][b]On-screen feedback (toasts)[/b]
Despawn, undo, cycle, spawn, and the mod on/off toggle all confirm on-screen — not just in ue4ss.log — by splicing a message into the game's own native side-notification widget, so it looks and behaves like a normal game notification rather than a custom overlay. Deliberately quiet for the cases that would otherwise spam: live-edit nudges don't toast per press, and neither does pressing a targeted key at nothing. Every toast is also logged to the GUI's History tab.[/color]

[color=#D4D4D8][b]Persistence & clean-house[/b]
Windrose doesn't save mod-spawned actors, so LivingBase records every placement to persist.txt (class, full position/rotation, look, and its unique display name) and re-spawns it on world load.
[list]
[*]If you play multiple Windrose worlds, each one gets its own save automatically — persist_<world id>.txt/spawn_ledger_<world id>.txt, keyed off that world's own internal ID. Upgrading from a version before this existed: the first world you load inherits the old shared persist.txt/spawn_ledger.txt (renamed to .bak once claimed, so no other world can also inherit it), and every world after that starts clean.
[*]Config.RESTORE_ON_LOAD = true (default) repopulates on load (not on lbreload, so no duplicates while tinkering). false = place fresh each session.
[*]Delete (twice), or the GUI's Delete All, despawns everything and clears the save file for the current world.
[/list][/color]

[color=#D4D4D8][b]Whistle crew escort (WHISTLE_CREW)[/b]
Use the boar whistle and instead of a boar you get a small crew escort that follows you and fights at your side. Transient (never persisted).[/color]

[color=#D4D4D8][b]Unlock hidden build pieces (UNLOCK_HIDDEN_BUILDING)[/b]
Surfaces build-menu pieces that are hidden from standard play (cut/dev content) while leaving normal progression intact — it never unlocks pieces you're meant to earn. Runtime-only; open the build menu once after loading so the catalog is present.[/color]

[size=4][b]Configuration[/b][/size]
[color=#D4D4D8]There are two files:

config.txt — plain-text overrides you can edit without touching Lua. Lines are NAME = value (true/false or numbers). This is the one file you normally edit; it overrides the defaults. Current toggles include WHISTLE_CREW, UNLOCK_HIDDEN_BUILDING, KEYS_ENABLED_ONSTART (off by default), LIVE_EDIT.

Scripts/config.lua — the shipped defaults and all class paths. Highlights: Config.KEYS (the keymap, including toggleWindow "-", releaseMouse "=", and toggleRotateAxis "/"), Config.VERBOSE (per-spawn debug logging), Config.LIVE_EDIT_MOVE_STEP/LIVE_EDIT_HEIGHT_STEP/LIVE_EDIT_ROTATE_STEP (per-press step sizes, shared with the GUI's move panel), Config.TARGET_LOCK_MAX_DIST (how far you can walk from a locked target before it auto-releases), Config.TARGET_MIN_VIEW_DOT (how directly your camera needs to be looking at an object to target it), Config.DECOR_CATEGORIES (in Scripts/fkeys.lua, the six base decoration lists plus 18 themed Drops categories), Config.DECOR_COLLISION (placed decorations are solid by default), statue rosters (STANDING_STATUES/SEATED_STATUES/CHAIR_STATUES/INTERACTIVE_STATUES), Config.HANDYMAN_FOR_TOWNSFOLK, Config.HIDE_NAMEPLATES.[/color]

[size=4][b]Known Limitations[/b][/size]
[color=#D4D4D8][list]
[*]The GUI's mouse cursor stays confined to the game window until one click inside it, after =/- releases it. To fully return to normal camera control: click once in the game window, press = (or -) again if needed, then click once more. Alt+Tab or the Windows key also fully frees the OS cursor as a side effect.
[*]Live-edit/despawn keyboard keys don't support hold-to-repeat. Arrows, PageUp/PageDown, and the numpad operator keys only bind via a raw-key-code fallback — the game drops most rapid repeat presses for them before UE4SS sees them. Tap deliberately rather than holding or mashing; the GUI's move panel buttons don't have this problem.
[*]A Shift-modifier alternative for half-step precision was tried and doesn't work in this build (UE4SS's modifier-key bind overload never fires here) — use the Num - precision cycle (or the GUI's Precision slider) instead.
[*]The Brethren of the Coast "woman" crew re-skin (Num 1) currently has a male body under the female clothing — known, not yet fixed.
[*]Outfit and hair COLOR can't be changed on any NPC placed by this mod, for any feature — confirmed to be a hard engine limitation (the game only sets color once, when a character is first created behind the scenes) rather than something not yet implemented. This also covers the walking faction-visitor re-skins' uniform colors (generic rather than faction-matched). Skin tone and hairstyle are unaffected and both work fine.
[*]] and [ (the statue/decoration cycle keys) share a bind with the game's own "Change Target" combat key. Low-risk in practice, and Insert disables every key this mod uses instantly if it's ever in the way.
[/list]
Note on townsfolk: the townsman key (Num 2) spawns a mixed-sex crowd of dressed, wandering NPCs (men and women) that also use nearby furniture. The statue keys (Num 3–6) are intentionally static posed actors — that's the feature, not a limitation.[/color]

[size=4][b]Permissions / License[/b][/size]
[color=#D4D4D8]All rights reserved by default, except for the specific permissions below — nothing here is implied beyond what's listed.

Permitted, without needing to ask:
[list=1]
[*]Modify this mod for your own personal use.
[*]Reuse this mod's code or assets in your own separate mod, with credit.
[*]Convert or port this mod to other games, with credit.
[/list]

Not permitted: reuploading or rehosting this mod — modified or unmodified — anywhere other than this page; selling this mod, or using it in anything sold or monetized, in whole or in part. (Nexus's own Donation Points system is fine — that's Nexus's own charity-linked mechanism, not third-party monetization.)

This covers this fork's own code and content. The original Living Base toolkit this project builds on remains public domain under its own author's terms (see Credits below). Windrose and its game assets, class names, and intellectual property belong to Kraken Express — this is an unofficial, unaffiliated mod.[/color]

[size=4][b]Credits[/b][/size]
[color=#D4D4D8]This project started as a fork of [url=https://www.nexusmods.com/windrose/mods/519][b]Living Base[/b][/url] by [url=https://www.nexusmods.com/profile/me123420][b]me123420[/b][/url] — thank you to them for the original concept and toolkit, and for open-sourcing it into the public domain in the first place.

Thanks also to [url=https://www.nexusmods.com/windrose/users/77413713][b]IceBoxStudio[/b][/url] for [url=https://www.nexusmods.com/windrose/mods/442][b]Windrose Mod Settings[/b][/url], which this mod optionally integrates with for in-game keybind/toggle configuration.

Thanks also to [url=https://www.nexusmods.com/profile/irecode][b]irecode[/b][/url] for a resource this mod relies on.

Built iteratively with Claude.[/color]
