**Title suggestion:** [Mod] Living Base Enhanced — populate your base with NPCs, animals, posed statues, and decorations (now with a real GUI)

---

Hey folks — sharing **Living Base Enhanced**, a base-population toolkit for Windrose. It's a fork of [Living Base](https://www.nexusmods.com/windrose/mods/519) by me123420 (full credit to them for the original toolkit and concept), built out with a lot of fixes, quality-of-life, and new content on top. Like the original, this was built with AI assistance — I'm not a developer.

**[Living Base Enhanced on Nexus](https://www.nexusmods.com/windrose/mods/535)**

## What it does

Hand-drop ambient **NPCs, animals, posed statues, and decorations** anywhere around your base, fine-tune each one in place, and it all **persists across reloads**. Plus a few base-life extras: a summonable **crew escort** and an **unlock for hidden build-menu pieces**.

## The primary way to use it now: a real GUI window

Bundled with the download is **LivingBaseSpawnMenu**, a second, compiled companion mod that adds a genuinely separate, always-on-top window — not an overlay drawn on the game. Press `-` in-game to open it:

- A **categorized, clickable spawn tree** — every roster (crew, statues, Senkamati, decor, animals, walking women, and more) laid out for browsing instead of "press a key and cycle." Click a look, then **Spawn** a new copy or **Replace** whatever's currently target-locked with it.
- A **held-repeat move/edit panel** — Forward/Left/Right/Backward/Up/Down and full X/Y/Z rotate as real UI buttons you can hold down, sidestepping a UE4SS engine limitation where rapid keyboard repeat-presses get dropped before the mod ever sees them.
- A **precise coordinate editor** — type exact X/Y/Z position and rotation, with Preview/Apply/Reset/Cancel.
- In-window **Instructions and History** tabs, so the control reference and a running log of every on-screen confirmation are both readable without alt-tabbing out.

Every keyboard control below still works exactly as it always has — the GUI doesn't replace anything, it's just the faster way to reach the same rosters.

## Placement — one key per press, numpad-driven

Each numbered key drops one actor a few meters ahead, in the direction your camera is looking. Most keys cycle through a whole roster — press again for the next look.

- **Num 1** — Crew pawn that wanders and fights hostiles alongside you. Cycles 14 looks: the default crew look, plus 12 walking faction-visitor re-skins (Buccaneers, Smugglers, People of Tortuga, Brethren of the Coast — Musketeer/Sailor/Sergeant variants), plus a Brethren of the Coast woman.
- **Num 2** — Townsman: wanders, sits on nearby furniture, mixed-sex crowd.
- **Num 3** — Standing statue (merchants, chatting poses, named faction leaders, quest folk — cycles).
- **Num 4** — Floor sitter.
- **Num 5** — Chair/stool sitter (bring your own stool).
- **Num 6** — Interactive statue (rummaging a chest/table).
- **Num 7** — Friendly Senkamati tribal human: Warrior, Hunter, and a female Caster, each walking with normal human posture instead of their native mob's lumbering gait. 30+ looks total — original mob body vs. re-skinned, with/without the tribal helmet, each one's untouched corrupted look, and a frozen/idle counterpart for every look. The female Caster's re-skin comes in two distinct base bodies (Gatherer/Herbalist) for real figure and hair-color variety.
- **Num 8** — Friendly wildlife — boar family, goats, dodos, wolves, crocodile — 13 entries.
- **Num .** (decimal) — A real, walking female NPC. Letty, Marita Suares, and the Buccaneers Merchant each wear their own real, distinct outfit (not a shared generic look with pieces patched on); a fourth, plain "Woman" entry rounds things out with an outfit, hat presence, and hair that all vary naturally on their own. Every look comes in two different base bodies for genuinely different figures/hair color — 8 stops total. Every placement also rolls a random skin tone.
- **Num 9** — Despawn whatever's targeted in front of you.
- **Num 0** — **Undo.** Restores the last despawn — single, whole clean-house wipe, or a cycle swap — at its exact spot, appearance included. Steps back through your last 20 actions.

## Cycle a placed statue or decoration in place

`]` / `[` swap whatever you're looking at for the next/previous entry in its own roster, right where it's standing — no despawn-and-replace needed. Auto-detects statue vs. decoration. Undo-able.

## Decorations, on just two keys

Doesn't touch the F-row at all, for compatibility with other mods that use F-keys. `'` (apostrophe) cycles the active category — nature, boats, wrecks, tents, storage, furniture, plus **18 themed "Drops" categories** (Animal Parts, Artifacts, Clothes, Currency, Ingredients, Keys, Meals, Mined, Misc, Potions, Seeds, Tailoring, Tools, Treasure, Trophies, Weapons, Wood, Writings) — and announces the new category on-screen. `;` (semicolon) places one from whichever category is active. Every entry has a real display name (e.g. "Bezoar," not an internal asset ID) in both the GUI tree and its toast.

## Live-edit — nudge anything into place

With `LIVE_EDIT` on: PageUp/PageDown raise/lower, `,`/`.` rotate, Num `/` snaps 45°, Num `*` flips 180°, arrow keys slide in a fixed world direction, Num `-` cycles a 5-level precision mode (1/8 → 1/4 → 1/2 → full → 2x) for the slide/height/rotate keys, and Num `+` toggles a **target lock** — pin despawn/cycle/live-edit (and the GUI's move panel/Replace/Coords) to one object so they keep hitting it even after you walk away or look elsewhere. Placing anything new locks it automatically, so you can start adjusting it immediately. Every edit persists through reloads.

## One key freezes the mod's keyboard keys

`Insert` toggles LivingBase's own keyboard keys (numpad, `;`/`'`, Delete, `\`, live-edit) on/off at runtime — the GUI keeps working independently either way, since it's the primary workflow now. Off by default each session.

## Real on-screen feedback

Despawn, undo, cycle, and spawn actions confirm with an actual on-screen toast — by reusing the game's own native notification widget, not a custom overlay. World load shows staged progress too. Kept quiet where it'd just be spam (live-edit nudges, "nothing there" misses stay log-only).

## Each world keeps its own base

If you play more than one Windrose world/save, each one gets its own separate save automatically, keyed off that world's internal ID.

## Quest NPCs actually stop being quest NPCs

Named quest NPCs (Letty, Francois Arno, etc.) used to keep their live quest dialogue and interact prompt when placed as ambient set-dressing. Fixed — they behave like any other statue now.

## Bigger rosters, across the board

- 5 new named NPCs on the standing statue list: Benjamin Hornigold, Henri Boucher, Marita Suares, Long Ben, and Charlie Sharp — plus 15 more standing/seated/interactive poses that shipped with the game but were never wired in.
- Crew (Num 1) cycles 14 looks instead of always spawning the same pawn.
- Senkamati Hunter and Caster (Num 7) walk with normal human posture, matching the Warrior — 30+ looks total including two base bodies for the Caster.
- Farm animals (Num 8) expanded from 5 to 13.
- Walking Women (Num .) — real walking NPCs instead of frozen statues, each with her own outfit, 8 looks total across two base bodies.

## Optional: Windrose Mod Settings support

If you also have [Windrose Mod Settings](https://www.nexusmods.com/windrose/mods/442) by IceBoxStudio installed, Living Base Enhanced registers itself with it automatically — every key this mod binds, plus several feature toggles, become editable from the game's native Settings > Mods screen. Entirely optional both directions.

## Known limitations (being upfront about these)

- Live-edit/despawn keys (arrows, PageUp/PageDown, numpad operators) don't support hold-to-repeat — the game drops most rapid repeat presses for these specific keys before UE4SS ever sees them. Tap deliberately; the GUI's move panel buttons don't have this problem.
- The Brethren of the Coast "woman" crew re-skin (Num 1) currently has a male body under the female clothing — known, not yet fixed.
- Outfit and hair color can't be changed on any NPC placed by this mod — confirmed to be a hard engine limitation, not something unimplemented. Skin tone and hairstyle both work fine.
- `]`/`[` share a bind with the game's own "Change Target" combat key. Low-risk in practice, and `Insert` disables every mod key instantly if it's ever a problem.
- The GUI's mouse cursor stays confined to the game window until one click inside it — a small extra click the first time you switch over, documented in the README.

---

Everything's open, nothing's locked down — if you want to fix something or take it in a different direction yourself, the files are all right there in the download.
