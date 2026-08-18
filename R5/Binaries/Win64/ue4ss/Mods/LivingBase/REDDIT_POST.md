**Title suggestion:** [Mod] Living Base Enhanced — populate your base with NPCs, animals, posed statues, and decorations

---

Hey folks — sharing **Living Base Enhanced**, a base-population toolkit for Windrose. It's a fork of [Living Base](https://www.nexusmods.com/windrose/mods/519) by me123420 (full credit to them for the original toolkit and concept), built out with a lot of fixes, quality-of-life, and new content on top. Like the original, this was built with AI assistance — I'm not a developer.

**[Living Base Enhanced on Nexus](https://www.nexusmods.com/windrose/mods/535)**

## What it does

Hand-drop ambient **NPCs, animals, posed statues, and decorations** anywhere around your base, fine-tune each one in place, and it all **persists across reloads**. Plus a few base-life extras: a summonable **crew escort** and an **unlock for hidden build-menu pieces**.

## Placement — one key per press, numpad-driven

Each numbered key drops one actor a few meters ahead, in the direction your camera is looking. Most keys cycle through a whole roster — press again for the next look.

- **Num 1** — Crew pawn that wanders and fights hostiles alongside you. Cycles 14 looks: the default crew look, plus 12 walking faction-visitor re-skins (Buccaneers, Smugglers, People of Tortuga, Brethren of the Coast — Musketeer/Sailor/Sergeant variants), plus a Brethren of the Coast woman.
- **Num 2** — Townsman: wanders, sits on nearby furniture, mixed-sex crowd.
- **Num 3** — Standing statue (merchants, chatting poses, named faction leaders, quest folk — cycles).
- **Num 4** — Floor sitter.
- **Num 5** — Chair/stool sitter (bring your own stool).
- **Num 6** — Interactive statue (rummaging a chest/table).
- **Num 7** — Friendly Senkamati tribal human: Warrior, Hunter, and a female Caster, each walking with normal human posture instead of their native mob's lumbering gait. 13 looks total — original mob body vs. re-skinned, with/without the tribal helmet, plus each one's untouched corrupted look.
- **Num 8** — Friendly wildlife — boar family, goats, dodos, wolves, crocodile — 13 entries.
- **Num .** (decimal) — A real, walking female NPC re-skinned as Woman With Hat, Woman With Hair, the Buccaneers Merchant, Letty, or Marita Suares, each with a randomized skin tone (and hairstyle, for the two plain looks) on every placement.
- **Num 9** — Despawn whatever's targeted in front of you.
- **Num 0** — **Undo.** Restores the last despawn — single, whole clean-house wipe, or a cycle swap — at its exact spot, appearance included. Steps back through your last 20 actions.

## Cycle a placed statue or decoration in place

`]` / `[` swap whatever you're looking at for the next/previous entry in its own roster, right where it's standing — no despawn-and-replace needed. Auto-detects statue vs. decoration. Undo-able.

## Decorations, on just two keys

Doesn't touch the F-row at all, for compatibility with other mods that use F-keys. `'` (apostrophe) cycles the active category — nature, boats, wrecks, tents, storage, furniture — and announces it on-screen. `;` (semicolon) places one from whichever category is active.

## Live-edit — nudge anything into place

With `LIVE_EDIT` on: PageUp/PageDown raise/lower, `,`/`.` rotate, Num `/` snaps 45°, Num `*` flips 180°, arrow keys slide in your facing frame, Num `-` cycles a 5-level precision mode (full → 1/2 → 1/4 → 1/8 → 2x) for the slide/height keys, and Num `+` toggles a target lock — pin despawn/cycle/live-edit to one object so they keep hitting it even after you walk away or look elsewhere. Every edit persists through reloads.

## One key freezes the whole mod

`Insert` toggles every key this mod binds — numpad, `;`/`'`, Delete, `\`, live-edit — on/off at runtime, so all of it is free for another mod (or just free) without touching config files.

## Real on-screen feedback

Despawn, undo, cycle, and spawn actions confirm with an actual on-screen toast — by reusing the game's own native notification widget, not a custom overlay. World load shows staged progress too. Kept quiet where it'd just be spam (live-edit nudges, "nothing there" misses stay log-only).

## Each world keeps its own base

If you play more than one Windrose world/save, each one now gets its own separate save automatically, keyed off that world's internal ID. Previously every world shared one save file behind the scenes, so loading a different world could restore the wrong crew into it. Upgrading from an older version: the first world you load keeps everything it already had, and every other world starts clean.

## Quest NPCs actually stop being quest NPCs

Named quest NPCs (Letty, Francois Arno, etc.) used to keep their live quest dialogue and interact prompt when placed as ambient set-dressing. Fixed — they behave like any other statue now.

## Caster — improved body fit

Fixed a visible seam/gap that could show at the hips on the Senkamati Caster's re-skinned human body, using an improved body mesh bundled with the mod (used with permission).

## Bigger rosters, across the board

- 5 new named NPCs on the standing statue list: Benjamin Hornigold, Henri Boucher, Marita Suares, Long Ben, and Charlie Sharp.
- 15 more standing/seated/interactive poses that shipped with the game but were never wired in — found by diffing every faction's asset folder against what the mod actually used.
- Crew (Num 1) cycles 14 looks instead of always spawning the same pawn — see above.
- Senkamati Hunter and Caster (Num 7) walk with normal human posture, matching the Warrior.
- Farm animals (Num 8) expanded from 5 to 13.
- Walking Women (Num .) — a real walking NPC instead of a frozen statue, five looks.

## Known limitations (being upfront about these)

- Live-edit/despawn keys (arrows, PageUp/PageDown, numpad operators) don't support hold-to-repeat — the game drops most rapid repeat presses for these specific keys before UE4SS ever sees them. Tap deliberately.
- The Brethren of the Coast "woman" crew re-skin (Num 1) currently has a male body under the female clothing — known, not yet fixed.
- Outfit and hair color can't be changed on any NPC placed by this mod — confirmed to be a hard engine limitation, not something unimplemented. Skin tone and hairstyle both work fine.
- `]`/`[` share a bind with the game's own "Change Target" combat key. Low-risk in practice, and `Insert` disables every mod key instantly if it's ever a problem.

---

Everything's open, nothing's locked down — if you want to fix something or take it in a different direction yourself, the files are all right there in the download.
