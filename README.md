# LivingBaseEnhanced

Source for **LivingBase**, a UE4SS Lua mod for [Windrose](https://store.steampowered.com/) (Kraken Express,
UE 5.6, single-player) that lets you hand-place ambient NPCs, animals, posed statues, and decorations around
your base, fine-tune each one in place, and have it all persist across reloads.

This is an enhanced fork of [Living Base](https://www.nexusmods.com/windrose/mods/519) by
[me123420](https://www.nexusmods.com/profile/me123420) — full credit to them for the original concept and
toolkit, released into the public domain. This fork's own code and content are licensed separately (see
*License* below).

For what the mod actually **does** and how to **use** it, see the shipped, end-user-facing README at
[`R5/Binaries/Win64/ue4ss/Mods/LivingBase/README.md`](R5/Binaries/Win64/ue4ss/Mods/LivingBase/README.md) —
that's the one that travels with the mod itself and covers both the GUI and the full keyboard control
scheme. This top-level README is about the *codebase*, for anyone browsing the repo.

## Companion GUI mod

As of 2.0.0, LivingBase has a companion: **[LivingBaseSpawnMenu](https://github.com/dgomiller/Living-Base-Spawn-Menu-Windrose)** — a separately
built, compiled C++ UE4SS mod that adds a real clickable window (categorized spawn tree, a move/edit panel,
a precise coordinate editor) instead of the keyboard-only cycling system. It lives in its **own repo** (a
different language/toolchain entirely — CMake + a UE4SS C++ mod template, not Lua) and talks to this mod
purely through small text files it reads/writes on disk (`spawn_request.txt`, `move_request.txt`,
`spawn_menu_status.txt`, `spawn_menu.ini`) — see that repo's own README for its architecture.

The **distributed release** bundles both: this repo's `R5/...` tree ships with LivingBaseSpawnMenu's built
DLL already in place (`R5/Binaries/Win64/ue4ss/Mods/LivingBaseSpawnMenu/`), so a single download/zip
installs everything. Neither mod requires the other to load — LivingBaseSpawnMenu is inert without
LivingBase's Lua side to talk to, and LivingBase works exactly as it always has if you never open the GUI.

## Repo layout

```
R5/Binaries/Win64/ue4ss/Mods/
├── LivingBase/                  the Lua mod itself
│   ├── Scripts/                 all Lua source (main.lua, spawner.lua, testbed.lua, config.lua, ...)
│   ├── config.txt               plain-text user overrides (no Lua editing needed)
│   ├── mod.txt                  UE4SS mod name:version
│   ├── README.md                the shipped, end-user-facing doc (see above)
│   ├── CHANGELOG.txt            full version history
│   └── NEXUS_*.txt              BBCode mirrors of the README/changelog for the Nexus Mods page
└── LivingBaseSpawnMenu/         built output of the companion GUI mod (source lives in its own repo)
```

## Dev workflow

- **Working is source of truth.** Edit files directly under `R5/...` here; there's no separate build step
  for the Lua side.
- **Hot reload:** the `lbreload` console command (typed in-game) reloads every Lua script from disk without
  restarting the game or the world — the fast path for iterating. It wipes the mod's in-memory tracking of
  already-placed actors; placement/despawn keys re-recover that automatically from the persisted ledger.
- **Deploying to a live install:** copy this `R5/...` tree over the corresponding path in the actual game
  install directory. Confirm the game isn't running first if you're not going through `lbreload`.
- Full engine-quirk findings, dead ends, and the reasoning behind non-obvious code live in `CLAUDE.md`
  (technical history) and `ASSET_CATALOG.md` (the spawnable-asset database) inside the mod folder.

## License

Licensed under **[Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/)
(CC BY-SA 4.0)** — see [`LICENSE`](LICENSE). Use, modify, and redistribute freely, including commercially,
as long as you (1) credit the original author(s), and (2) release your own version under this same license.

This covers this fork's own code and content. The original *Living Base* toolkit it builds on remains
public domain under its own author's terms (me123420 — see above). **Windrose** and its game assets, class
names, and intellectual property belong to Kraken Express — this is an unofficial, unaffiliated mod.
