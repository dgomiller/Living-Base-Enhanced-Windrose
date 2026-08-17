# LivingBase — Base Building & Population Mod for Windrose

A placement toolkit for your base. Hand-drop ambient **NPCs, animals, posed statues,
and decorations** wherever you want them, fine-tune each piece in place, and let it all
**persist across reloads**. Plus a few base-life extras: a summonable **crew escort**,
**invulnerable structures**, and an **unlock for hidden build-menu pieces**.

**As of 2.0.0, the primary way to use this mod is a real clickable GUI window** —
**LivingBaseSpawnMenu**, a companion mod bundled with this download. Press **`-`** in-game to
open it: a categorized spawn tree, held-repeat movement buttons, and a precise coordinate editor,
instead of cycling numpad keys one press at a time. **Every keyboard control from earlier
versions still works exactly as before** and is fully documented further down — the GUI doesn't
replace anything, it's just the faster, easier way to reach the same rosters.

A UE4SS Lua mod (plus one compiled C++ companion) for **Windrose** (Kraken Express, UE 5.6,
single-player). Modding is unofficial — **keep save backups**; a game patch may change class
paths (all centralized in `Scripts/config.lua`).

---

## Requirements / install

- **UE4SS** (latest experimental / GitHub RE-UE4SS build) with
  `[EngineVersionOverride] MajorVersion=5, MinorVersion=6` in `UE4SS-settings.ini`.
- This download contains **two mod folders** — install both:
  - `…\R5\Binaries\Win64\ue4ss\Mods\LivingBase\` — the mod itself (Lua).
  - `…\R5\Binaries\Win64\ue4ss\Mods\LivingBaseSpawnMenu\` — the GUI window (compiled). Optional in
    principle (LivingBase works fine with only keyboard controls if you skip it), but it's the
    intended way to use the mod now, so install it too unless you have a specific reason not to.
- Enable both with `mods.txt` lines:
  ```
  LivingBase : 1
  LivingBaseSpawnMenu : 1
  ```
  (an empty `enabled.txt` in each mod's own folder also works).
- Load into a game world. Press **`-`** to open the GUI, or use the keyboard controls below directly.
- **Hot reload:** run the **`lbreload`** console command to reload LivingBase's scripts without
  restarting the game or the world (see *Console commands* below). UE4SS's own Ctrl+R
  hot-reload keybind does **not** work in this game — Windrose's native Dodge action is bound
  to plain `Ctrl` and claims it before UE4SS's key-hook layer ever sees a `Ctrl+X` combo reach
  it, so `lbreload` exists specifically as the working replacement. Note it wipes the mod's
  in-memory tracking — despawn (Delete) before running it, or just reload the world; placement
  keys re-recover tracking from the ledger automatically. (`lbreload` only reloads LivingBase's
  Lua — LivingBaseSpawnMenu is a compiled DLL and needs a full game restart to pick up an update.)

---

## The GUI (LivingBaseSpawnMenu)

### Opening it

| Key | Does |
|-----|------|
| **`-`** | Open/close the window. Starts **closed** each session. Works from anywhere while playing, regardless of the In-Game Keys toggle below. |
| **`=`** | Steal OS focus for the window, if it's already open — handy right after `-` opens it, so your next click lands there instead of needing an extra click just to switch windows first. Does nothing if the window is closed. |

The window is a genuinely separate, always-on-top native window, not an overlay drawn on top of
the game — you can drag it, resize it, and it stays put across sessions of use. While it or the
game has input focus, clicking back into the other one works exactly like switching between any
two normal Windows applications.

### Tools tab

- **Spawn tree** (left) — click any entry to select it (highlights), then:
  - **Spawn** — places a new copy of the selected look in front of you, same result as pressing
    that roster's numpad key enough times to cycle to it.
  - **Replace** — swaps whatever's currently **target-locked** (see below) for the selected look,
    in the exact same spot. Needs a target lock first — more precise than the old `]`/`[` cycle
    keys, since you jump straight to any specific look instead of stepping through the roster.
  - **Refresh** — re-reads `spawn_menu.ini` from disk (see *Customizing the spawn tree* below).
- **Move/edit panel** (right):
  - **Selected Target** — shows whatever's currently target-locked. Hover if the name is truncated.
  - **In-Game Keys** — mirrors the in-game Insert key, but **only** turns LivingBase's own
    keyboard keys on/off (placement, live-edit, cycle, clear) — it does **not** affect this
    panel's own buttons, which work regardless. Off by default each session (see *Configuration*).
  - **Forward / Left / Right / Backward / Up / Down** — slide/raise/lower the target-locked
    object. Real held-repeat buttons (hold to keep moving) — unlike the same in-game keys, which
    this UE4SS build drops most rapid repeat presses for.
  - **Flip 180 / Rot L / Rot R** — rotate the target in place.
  - **Coords** — opens the precise coordinate editor (below). Only enabled with something
    target-locked.
  - **Precision** — scales how far Up/Down/slide move per press (1/8 through 4x; rotation is
    unaffected).
  - **Despawn / Undo** — same as Num9/Num0, acting on the target-locked object.
  - **Delete All** — despawns **everything** LivingBase has placed. Confirmation popup first.
  - All of the above (except In-Game Keys itself) require a **target lock** first (see below) and
    are greyed out until you have one — and, like every keyboard key, stay disabled until your
    base has finished restoring on world load.

### Coords window

Opens a small editor with the target's exact **X, Y, Z, and Rotation** (0–359°, not Unreal's
native −180 to 180) as editable numbers. Typing doesn't move anything by itself — only these:

- **Preview** — moves the object to whatever you've typed, without closing. Adjust and preview
  as many times as you like.
- **Apply** — same as Preview, but closes the window — the "I'm done" button.
- **Reset** — moves the object back to wherever it was when the window opened, fields included.
  Stays open.
- **Cancel** (or the window's own close button) — same as Reset, but closes.

If you lock onto a different object — or release the lock entirely — while this window is open,
it closes itself without moving anything. While it's open, the target-lock's normal "walked too
far away, release the lock" check is suspended, so a typo in a coordinate can't strand you locked
onto something that just flew off into the distance.

### Instructions & History tabs

**Instructions** renders this same reference from inside the game (reads from `help.txt`, so it
can be edited without a rebuild). **History** shows every message that's appeared as an on-screen
toast this session — handy for catching something you missed.

### Customizing the spawn tree

The tree's category structure comes from `spawn_menu.ini`, auto-generated on first load (one
section per look, pointing back at the real roster + index) and never overwritten after that —
reorganize it, rename categories, regroup entries, however you like; re-running the generator only
**adds** anything new, it never touches or removes your edits.

---

## Keyboard controls (still fully available)

Everything below works exactly as it always has — the GUI is an additional way to reach it, not
a replacement.

### Numpad — place NPCs, statues & animals
Each key drops **one** actor ~3 m ahead **in the direction your camera is looking** (horizontal
only — looking up/down doesn't change where it lands; height always comes from the ground under
that spot). Placed statues face **toward** you.

| Key | Places |
|-----|--------|
| **Num 1** | Crew pawn (wanders; fights hostiles as a combat ally; cycles 14 looks — default crew, plus 12 walking faction-visitor re-skins across Buccaneers/Smugglers/People of Tortuga/Brethren of the Coast, plus a Brethren of the Coast woman) |
| **Num 2** | Townsman (wanders; sits on nearby chairs/benches/beds) |
| **Num 3** | Standing statue (merchants, chatting, cross-arms, women, quest folk, named faction leaders — cycles) |
| **Num 4** | Floor sitter (sits / lies on the ground — cycles) |
| **Num 5** | Chair/stool sitter (place your own stool; cycles) |
| **Num 6** | Interactive statue (rummaging a chest/table — cycles) |
| **Num 7** | Friendly Senkamati tribal human — Warrior, Hunter, and female Caster (with/without helmet, original mob body vs. re-skinned where applicable — the female Caster's re-skin comes in TWO base bodies, Gatherer and Herbalist, each with distinct figure/hair-color/palette — plus each one's original corrupted look. Every look also has a frozen/idle counterpart, including the Herbalist-base Caster — cycles) |
| **Num 8** | Friendly wildlife (boar family / goats / dodos / wolves / crocodile — 13 entries, cycles) |
| **Num .** (decimal) | Walking female NPC — cycles 10 looks: Woman With Hat, Woman With Hair, the Buccaneers Merchant, Letty, and Marita, each in **two base bodies** (Base 1 = Gatherer, Base 2 = Herbalist — two different NPC classes with genuinely different figure/hair-color/outfit palette, not just a different outfit). Every placement also rolls a random skin tone (and, for the two plain looks, hairstyle). Since a pawn's color/palette can't be changed after it's built, Base 1/Base 2 is the only way to get real figure/palette variety in this game — outfit/hair-style rules stay the same per character either way (Letty keeps her ponytail on both bases, etc.). |
| **Num 9** | Despawn the spawn **in front of you on your floor** |
| **Num 0** | **Undo** — restore the last despawn (Num 9, a whole Delete clean-house, or a `]`/`[` cycle) at its exact spot, including appearance where recorded. Names what it restored on-screen. |
| **`\`** | Flip statue facing 180° for **future spawns** (toggle: statues face away / riflers face you) — does **not** affect anything already placed; use the live-edit rotate keys for that |

### Cycle a placed statue/decoration — not numpad, reticle-targeted (same as despawn)

| Key | Action |
|-----|--------|
| **`]`** | Cycle the targeted statue or decoration **forward** through its own roster (the Num 3–6 statue lists, or its own decoration category), in place |
| **`[`** | Cycle it **backward** instead |

One key pair auto-detects which kind of roster the targeted actor belongs to. Works any time
(not gated by `LIVE_EDIT`). Undo-able with Num 0. Shares a bind with the game's own "Change
Target" combat key — low-risk in practice, and `Insert` disables every key this mod uses
instantly if it's ever in the way.

### Decorations — active-category placement
To ensure compatibility with other mods that use F-Keys, decoration placement doesn't use the
F-row at all. One key changes which category is active, the other places from it.

| Key | Action |
|-----|--------|
| **`'`** (apostrophe) | Change the **active** decoration category — cycles nature → boats → wrecks → tents → storage → furniture → back to nature. Announces the new category on-screen. Doesn't place anything. |
| **`;`** (semicolon) | Place one decoration from the **active** category (cycles that category's own list, same as every other placement key) |

### Live-edit — fine-tune the object in front of you (needs `LIVE_EDIT` on)
Adjustments **persist** through reloads. Only affects the nearest placed piece on your floor
(within `Config.LIVE_EDIT_MAX_DIST`, default 200uu — separate from Num9's own reach).

| Key | Action |
|-----|--------|
| **PageUp / PageDown** | Raise / lower |
| **`,` / `.`** | Rotate left / right (step = `Config.LIVE_EDIT_ROTATE_STEP`) |
| **Num `/`** | Rotate a fixed 45° |
| **Num `*`** | Rotate a fixed 180° (flip in place) |
| **↑ ↓ ← →** (arrows) | Slide forward / back / left / right (in **your** facing frame — for statues, in the statue's own facing frame instead) |
| **Num `-`** | **Cycle precision**: full → 1/2 → 1/4 → 1/8 → 2x → back to full, for the slide/height keys (arrows + PageUp/PageDown only; doesn't affect rotate). Toast confirms which level you're on. |
| **Num `+`** | **Toggle target lock**: pin Num9 despawn, `]`/`[` cycle, and every live-edit key above — plus the GUI's move panel/Despawn/Coords/Replace — to the object currently in front of you, so they keep acting on it even after you walk away or turn to look elsewhere. Press again to release. Toast confirms lock on/off, naming the target; auto-releases (with its own toast, and a reason) if the locked object gets despawned, or if you walk more than `Config.TARGET_LOCK_MAX_DIST` (default 1500uu, ~15m) away from it. Always active regardless of the In-Game Keys toggle, since the GUI depends on it. |

Every successful edit logs a `persist.txt` cross-check to `ue4ss.log` — check there for lines
starting `[LivingBase]` if something seems off, they'll show exactly what was targeted and why
a press did or didn't land. (Live-edit nudges themselves are deliberately quiet on-screen — no
toast per press, since the keys are often tapped rapidly in a row; despawn/undo/cycle/spawn
confirmations still show on-screen.)

> **Reliability note:** arrows, PageUp/PageDown, and the numpad operator keys (`/` `*` `-`)
> aren't in this UE4SS build's normal key table and only work via a raw-key-code fallback.
> In practice this means **the game drops most rapid repeat presses** for these specific
> keys before UE4SS ever sees them — holding or mashing won't give you smooth continuous
> movement. Individual, deliberate taps land reliably; expect a real gap (sometimes several
> seconds) between presses actually registering. This is an engine-level limitation, not a
> mod bug. **The GUI's move panel buttons don't have this problem** — they're real held-repeat
> UI buttons, not raw key hooks — so if held-to-repeat movement matters to you, that's the
> more reliable path. See `WINDROSE_MODDING_NOTES.md` §9 for the full investigation.

### Housekeeping

| Key | Action |
|-----|--------|
| **Delete** (×2) | Clean house — despawn **everything** the mod placed. **Press twice** within 3 s to confirm. |
| **Insert** | Toggle **LivingBase's own keyboard keys** (numpad, `;`/`'`, Delete, `\`, live-edit) on/off — it does **not** affect the GUI window or its buttons, which work independently by design (see *In-Game Keys* above). Kept off the F-row deliberately — F-keys are the ones most likely to collide with another mod or overlay. Insert itself always works, or there'd be no way back on. Toast confirms the new state. Starting state controlled by `Config.KEYS_ENABLED_ONSTART` — **`false` by default as of 2.0.0** (the GUI is the primary workflow now, so keyboard keys start opted-out rather than opted-in; set it `true` in `config.txt` for the old always-on behavior). |

**Remap anything:** edit `Config.KEYS` in `Scripts/config.lua` (decoration keys are set
in `Scripts/fkeys.lua`, merged into `Config.KEYS` at load — edit there instead for those).
Values are UE4SS key names (`"F1"`, `"NUM_ONE"`, `"DEL"`, …). An unrecognized name is skipped
with a note in the log (it can't crash the mod). If a remapped key doesn't respond at all, the game may
be consuming it before the mod sees it — just pick another key.

---

## Features

### GUI window (LivingBaseSpawnMenu)
A categorized, clickable spawn tree; a held-repeat move/edit panel that doesn't suffer the
keyboard's dropped-repeat-press problem; a precise typed X/Y/Z/Rotation coordinate editor; and
an in-window Instructions/History reference. See *The GUI* above for the full breakdown.

### Placement toolkit + live-edit
Drop NPCs, animals, posed statues, and decorations, then nudge each one into place — via the GUI
or the keyboard live-edit keys (height, rotation, slide, a 6-level precision cycle, and a target
lock to pin your edits to one object). Everything you place is **saved and restored** on the
next world load.

### Unique per-placement names
As of 2.0.0, every placed object gets its own distinguishable name (e.g. "Brethren Woman 1",
"Brethren Woman 2") instead of every copy of the same look sharing one identical label — visible
wherever a target's name is shown (target-lock toasts, the GUI's Selected Target readout, the
Coords window). Stored in `persist.txt`, so names stay stable across reloads; a save from before
this existed gets names assigned automatically the first time it restores.

### Console commands
Type these into UE4SS's console (the same input used for the game's own dev/cheat commands)
for spawning by name instead of cycling a numpad key. All three print their response both
on-screen and to `ue4ss.log` (look for `[LivingBase]` lines).

| Command | Syntax | What it does |
|---|---|---|
| **`lblook`** | `lblook <name>` | Spawns one of LivingBase's own **named looks** — a base class plus its full reskin/de-corrupt/pacify recipe (e.g. `lblook Letty`, `lblook Buccaneers Musketeer`, `lblook Warrior_crew_Mask`, `lblook Boar`). This is what every numpad placement key (and the GUI's Spawn button) uses internally, by name. |
| | `lblook list` | Lists every category (crew, townsman, standing, seated, chair, interactive, senka, animals, women, decor) with a count. |
| | `lblook list <category>` | Lists every name in one category, e.g. `lblook list crew` or `lblook list senka`. |
| | `lblook list all` | Dumps every name in every category at once. |
| **`lbspawn`** | `lbspawn <ShortName>` or `lbspawn <full /Game/... path>` | Spawns a **raw engine class**, with none of this mod's re-skin/de-corrupt/pacify recipe applied — just the game's own default look/behavior. Short names resolve through a generated index of ~2,500 known `BP_` classes; anything not in that index needs the full path (e.g. `lbspawn BP_Mob_Wolf` or `lbspawn /Game/Gameplay/Character/AI/Mob/Wolf/BP_Mob_Wolf.BP_Mob_Wolf_C`). |
| | `lbspawn list` / `lbspawn list <category>` / `lbspawn list all` | Same idea as `lblook`'s listing, but for LivingBase's own statue/decor rosters specifically (standing/seated/chair/interactive/6 decor categories) — reference only, not a guarantee those exact names resolve as short-name input. |
| **`lbreload`** | `lbreload` (no arguments) | Reloads LivingBase's Lua from disk **without restarting the game or reloading the world** — picks up script edits immediately. Doesn't affect content-pak changes or the GUI's own compiled DLL (both need a full relaunch); tracked spawns recover automatically afterward. |

**When to use which:** if you want the mod's actual recipe (correct faction, posture, gear, etc.) use `lblook`. If you want to spawn something completely untouched — including things this mod doesn't otherwise place — use `lbspawn`. You'll see an occasional `Error: A custom console command handle must return true or false` line after running any of these — that's harmless UE4SS noise tied to how this build checks a console command's return value, not a real failure.

### Cycle (`]` / `[`)
Swaps the statue OR decoration in front of you for the next (or previous) entry in its own
roster (the Num 3–6 statue lists, or its own decoration category) — same spot, facing
preserved for statues. One key pair auto-detects which kind of roster the targeted actor's
class belongs to. Works because each roster entry is a genuinely different asset; it can't
cycle face/body/skin variety within one statue class (the game re-randomizes that on
`BeginPlay` no matter what's set beforehand). Undo-able with Num 0. The GUI's **Replace**
button does the same job with a direct pick instead of stepping through the roster.

### Walking Women (Num . / decimal, or the GUI's "Walking Women" category)
A real, walking female NPC that can be re-skinned to look like Letty, Marita Suares, or the
Buccaneers Merchant, instead of only being available as a frozen statue. Two extra plain
looks, "Woman With Hat" and "Woman With Hair", round out the roster for general crowd
variety. Every placement also rolls a random skin tone (and, for the two plain looks, a
random hairstyle) — this re-rolls on every placement and every reload, on purpose, rather
than being locked in permanently. Reloading correctly restores which look/character each
placed NPC was standing in for.

### Undo (Num 0, or the GUI's Undo button)
Restores whatever was most recently despawned — a single Num 9 despawn, an entire Delete
clean-house wipe (restored as one batch, in one press), or a `]`/`[` cycle (removes the new
pick and brings back the old one). Since a destroyed actor can't literally come back,
this respawns a fresh copy of the same class at the exact same position/rotation, using
data cross-checked against `persist.txt` — for actors with a recorded composite look (e.g.
a re-skinned crew member), that appearance is restored too, not just a default look.
Steps back through your last 20 despawn actions if pressed repeatedly. Names what it
restored on-screen (up to 5 by name, "+N more" beyond that).

### On-screen feedback (toasts)
Despawn, undo, cycle, spawn, and the mod on/off toggle all confirm on-screen — not just in
`ue4ss.log` — by splicing a message into the game's own native side-notification widget
(the same one used for its pickup/threat popups), so it looks and behaves like a normal
game notification rather than a custom overlay. Deliberately quiet for the cases that would
otherwise spam: live-edit nudges (arrows/PageUp/PageDown/rotate) don't toast per press, and
neither does pressing a targeted key at nothing (despawn/live-edit/cycle) — Undo's own
"nothing to restore" is the one exception, since an empty undo stack is a real, useful thing
to know. Every toast is also logged to the GUI's History tab. On world load with
`RESTORE_ON_LOAD` on, you'll see up to four staged messages: waiting for you to move,
restoring your base (N saved entries), base restored (counts), and your current
key-enabled/disabled status.

### Persistence & clean-house
Windrose doesn't save mod-spawned actors, so LivingBase records every placement to
**`persist.txt`** (class, position, facing, look, and — as of 2.0.0 — its unique display name)
and re-spawns it on world load.
- If you play multiple Windrose worlds, each one gets its own save automatically —
  `persist_<world id>.txt`/`spawn_ledger_<world id>.txt`, keyed off that world's own internal
  ID. Upgrading from a version before this existed: the first world you load inherits the old
  shared `persist.txt`/`spawn_ledger.txt` (renamed to `.bak` once claimed, so no other world
  can also inherit it), and every world after that starts clean.
- `Config.RESTORE_ON_LOAD = true` (default) repopulates on load (not on `lbreload`, so no
  duplicates while tinkering). `false` = place fresh each session.
- **Delete** (twice), or the GUI's **Delete All**, despawns everything and clears the save file
  for the current world.
- `persist.txt` is also read (not just written) by **Undo** (Num 0/GUI) — it's the source for a
  despawned actor's AI-controller/composite-look/name fields, since the live actor's transform
  alone doesn't carry that.
- **Every mod key AND the GUI's buttons are locked** from the moment a world load is detected
  until the restore genuinely finishes (or determines there's nothing to restore) — placing
  something manually in that window used to get written to `persist.txt` immediately and then
  restored a SECOND time once the real restore ran, producing a duplicate. Everything unlocks
  automatically; `Insert`, `-`, and `=` still work throughout in case you need to override it.

### Whistle crew escort (`WHISTLE_CREW`)
Use the boar whistle and instead of a boar you get a small **crew escort** that follows
you and fights at your side. Transient (never persisted).

### Invulnerable structures (`PROTECT_STRUCTURES`)
Your building blocks are made **invulnerable** so raiders (and anything else) can't damage
the base. Applied just after load and again the instant a raid starts. Runtime-only —
resets on reload, never touches your save, and never blocks your own deconstruct.

### Unlock hidden build pieces (`UNLOCK_HIDDEN_BUILDING`)
Surfaces build-menu pieces that are **hidden from standard play** (cut/dev content) while
leaving normal progression intact — it never unlocks pieces you're meant to earn. Runtime-
only; open the build menu once after loading so the catalog is present.

### Blackbeard raid — removed
The original mod's Blackbeard raid (drop a flag, trigger a pirate wave) has been removed as
a supported feature since v1.3.7, due to lack of interest and the ongoing maintenance burden of
keeping it stable. The code and its `BBRAID_ENABLED` toggle are still present in
`config.txt`/`Scripts/config.lua`/`Scripts/bbraid.lua` for anyone who wants to re-enable it
themselves — see `CHANGELOG.txt` v1.3.7 for details — but it's off by default and not part of
the mod's supported feature set going forward.

---

## Configuration

There are two files:

- **`config.txt`** — plain-text overrides you can edit without touching Lua. Lines are
  `NAME = value` (`true`/`false` or numbers). This is the one file you normally edit; it
  overrides the defaults. Current toggles include `WHISTLE_CREW`,
  `UNLOCK_HIDDEN_BUILDING`, `PROTECT_STRUCTURES`, `KEYS_ENABLED_ONSTART` (default `false` as
  of 2.0.0), `LIVE_EDIT`.
  (`BBRAID_ENABLED` also still exists, off by default — see *Blackbeard raid — removed* above.)
- **`Scripts/config.lua`** — the shipped defaults and all class paths. Highlights:
  - `Config.KEYS` — the keymap, including `toggleWindow` (`-`, opens/closes the GUI) and
    `releaseMouse` (`=`, steals focus for it) as of 2.0.0.
  - `Config.VERBOSE` — `false` (quiet); `true` for per-spawn debug logging. (Live-edit and
    despawn/undo diagnostics print unconditionally, regardless of this setting, since they're
    needed for in-the-moment troubleshooting.)
  - `Config.LIVE_EDIT_MOVE_STEP` / `LIVE_EDIT_HEIGHT_STEP` / `LIVE_EDIT_ROTATE_STEP` — per-press
    step sizes for the slide/height/rotate keys (shared with the GUI's move panel, so both stay
    in sync). `Config.LIVE_EDIT_MAX_DIST` (200uu) — how close you need to be for a live-edit key
    to pick up the object in front of you (separate from `Config.DESPAWN_FRONT_UU`, 250uu, used
    only by Num 9).
  - `Config.TARGET_MIN_VIEW_DOT` (`0.90`) — how directly your **camera** needs to be looking at
    an object (tracks your reticle, including up/down — you can pick between two things stacked
    vertically) for Num 9 despawn, live-edit, or `]`/`[` cycle to pick it as the target — all
    three share this one check. Lower = more forgiving/wider; higher = you have to look more
    squarely at it, which matters most when two placed things sit close together and only one
    should be picked. (This only affects which object gets TARGETED — the live-edit arrow keys
    still slide things relative to your character's body facing, not the camera.)
  - `Config.TARGET_LOCK_MAX_DIST` (`1500.0`, ~15m — this mod's own convention is 100uu ≈ 1m) — how
    far you can walk from a target-locked object (Num `+`) before the lock auto-releases. Only
    applies while locked; the normal unlocked pick still uses `LIVE_EDIT_MAX_DIST` above.
    Suspended entirely while the GUI's Coords window is open.
  - `Config.DECOR_CATEGORIES` (in `Scripts/fkeys.lua`) — the six decoration lists, cycled
    via `'`/`;` (see *Decorations — active-category placement* above; add/remove entries here).
  - `Config.DECOR_COLLISION` (`true`) — placed decorations are solid (physics frozen so
    they can't drift). `false` = pass-through.
  - Statue rosters: `STANDING_STATUES` (includes the women and quest-folk actors),
    `SEATED_STATUES`, `CHAIR_STATUES`, `INTERACTIVE_STATUES`.
  - `Config.HANDYMAN_FOR_TOWNSFOLK` (`true`) — townsmen wander **and** use furniture.
  - `Config.HIDE_NAMEPLATES` (`true`) — hide floating name/role tags on placed NPCs.
  - Raid tuning (removed feature, kept for anyone reviving it): `BBRAID_REGULARS`,
    `BBRAID_OFFICERS`, `BBRAID_RUN_SPEED`, `BBRAID_DESPAWN_MS`, `BBRAID_CHARGE_MS`.

---

## Known limitations

- **The GUI's mouse cursor stays confined to the game window until one click inside it**, after
  `=`/`-` releases it. To fully return to normal camera control from a released state: click once
  in the game window, press `=` (or `-`) again if needed, then click once more. (Alt+Tab or the
  Windows key also fully frees the OS cursor as a side effect, letting you click the GUI window
  directly without any of the above.) A deeper engine-level fix for this was investigated and
  intentionally not pursued — see the GUI companion mod's own repo for the technical writeup.
- **Live-edit/despawn keyboard keys don't support hold-to-repeat.** Arrows, PageUp/PageDown, and
  the numpad operator keys aren't in this UE4SS build's key table and only bind via a
  raw-key-code fallback — the game drops most rapid repeat presses for them before UE4SS
  sees them. Tap deliberately rather than holding or mashing; the GUI's move panel buttons
  don't have this problem, see *Live-edit* above.
- A Shift-modifier alternative for half-step precision was tried and doesn't work in this
  build (UE4SS's modifier-key bind overload never fires here) — use the **Num `-`** precision
  cycle (or the GUI's Precision slider) instead.
- The Brethren of the Coast "woman" crew re-skin (Num 1) currently has a male body under the
  female clothing — known, not yet fixed.
- **Outfit and hair COLOR can't be changed** on any NPC placed by this mod, for any feature —
  confirmed to be a hard engine limitation (the game only sets color once, when a character is
  first created behind the scenes) rather than something not yet implemented. This also covers
  the walking faction-visitor re-skins' uniform colors (generic rather than faction-matched).
  Skin tone and hairstyle are unaffected and both work fine.
- `]` and `[` (the statue/decoration cycle keys) share a bind with the game's own "Change
  Target" combat key. Low-risk in practice, and `Insert` disables every key this mod uses
  instantly if it's ever in the way.

> **Note on townsfolk:** the townsman key (Num 2) spawns a **mixed-sex** crowd of
> dressed, wandering NPCs (men and women) that also use nearby furniture. The statue
> keys (Num 3–6) are intentionally **static posed** actors — that's the feature, not a
> limitation.

---

## License / ownership

**No rights reserved.** I don't claim ownership of, or any license over, this mod — treat it
as public domain. Do whatever you want with it: use it, modify it, redistribute it, fork it,
bundle it into something else. No credit needed, no permission needed. If you make it better,
that's great.

(This waiver covers the mod's own code. **Windrose** and its game assets, class names, and
intellectual property belong to Kraken Express — this is an unofficial, unaffiliated mod.)

---

*Built iteratively with Claude. See `CLAUDE.md` for the full technical history and engine
findings, and `ASSET_CATALOG.md` for the spawnable-asset database.*
