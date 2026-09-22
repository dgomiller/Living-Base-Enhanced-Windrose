# gen_socketitems_lua.py -- (2026-09-07, extended 2026-09-15, 2026-09-21) regenerates the
# Config.SOCKETITEMS_* and Config.BELTSTRAPS_PIECES blocks in config.lua from RedFalcon's own
# Other/SocketItems.xlsx (Belts and Straps, Sockets, Item Ratios, Rarity Ratios, Items, Weapons,
# Tools, plus a "Socket List" tab that's just RedFalcon's own UI mockup, not real data, and
# "additional poses"/"Sheet2" which this script doesn't touch -- see WINDROSE_MODDING_NOTES.md
# 19u for the full design/rules this data drives, and the Custom-tab "Belts and Straps"/"Poses and
# Actions" sections for the GUI work built on top of it).
#
# 2026-09-15: Items/Weapons/Sockets tabs each gained a real "Friendly Name" column (Sockets also
# gained "test command", ignored here -- it's just a copy/paste console-command helper for RedFalcon
# himself). Column layouts below match the CURRENT tabs; if RedFalcon reorders/adds columns again,
# re-check with `ws.iter_rows(min_row=1,max_row=1,values_only=True)` before assuming these indices
# still line up.
#
# Run this after ANY edit to SocketItems.xlsx, then paste the printed block over the existing
# Config.SOCKETITEMS_* section in config.lua (it starts right before the "OPTIONAL: ModSettings"
# trailer near the end of the file -- search for "Config.SOCKETITEMS_SOCKETS").
#
# Usage:  python gen_socketitems_lua.py
#
# If Excel has the workbook open, this script cannot read it directly (PermissionError) -- close
# Excel first, or this script will fall back to reading a same-folder copy named
# "SocketItems_copy.xlsx" if one exists.

import openpyxl, re, os, shutil, sys

XLSX_PATH = r"H:\OneDrive\Coding\WINDROSE MODS\Other\SocketItems.xlsx"

def open_workbook(path):
    try:
        return openpyxl.load_workbook(path, data_only=True)
    except PermissionError:
        fallback = os.path.join(os.path.dirname(path), "SocketItems_copy.xlsx")
        try:
            shutil.copy(path, fallback)
        except Exception:
            print(f"ERROR: '{path}' is locked (probably open in Excel) and no fallback copy "
                  f"could be made. Close Excel and re-run.", file=sys.stderr)
            raise
        print(f"NOTE: source was locked, read a fresh copy at '{fallback}' instead.")
        return openpyxl.load_workbook(fallback, data_only=True)

wb = open_workbook(XLSX_PATH)

def luastr(s):
    if s is None:
        return '""'
    s = str(s).replace("\\", "\\\\").replace('"', '\\"')
    return '"' + s + '"'

def split_list(s):
    if not s:
        return []
    parts = [p.strip() for p in str(s).split(",")]
    return [p for p in parts if p]

def luaarr(items):
    if not items:
        return "{}"
    return "{ " + ", ".join(luastr(i) for i in items) + " }"

out = []

# soc_Lantern RE-ENABLED (2026-09-17, RedFalcon: "some of them have an item in the lantern spot...
# it needs to be like the other slots... we have our own lantern item... both should be allowed at
# the same time") -- originally excluded 2026-09-14 to keep a random belt-misc roll from visually
# clashing with an intentionally-summoned lantern, but RedFalcon has since found real native NPCs
# using this exact socket for a genuine accessory, independent of our own lantern feature. The
# coexistence problem (our lantern's own 2 known meshes vs. a real accessory sharing the same
# socket) is handled entirely in spawner.lua now (CS.LANTERN_KNOWN_MESHES / filterOutLanternMeshes,
# threaded through TestReadSocketAccessories/RemoveSocketAttachment/ClearSocketAccessories/
# CaptureRawCustomBaseline) -- nothing left to exclude at the data-generation level. Only
# soc_LanternLight (the lantern's own separate light-source socket, never a real accessory point)
# stays excluded.
EXCLUDED_SOCKETS = {"soc_LanternLight"}

# ---- Belts and Straps ---- (2026-09-15, new tab: the real Belt/Sling/Strap/Frog MESH pieces
# themselves, distinct from the soc_*/weapon ACCESSORY sockets below. "Set" rows (Set 1/3/4) carry
# no mesh data -- they're just the valid Set-number markers the Custom tab's "Set" dropdown offers,
# each meaning "apply Belt N + Sling N + Strap N together". The "Shaman Necklace" row (Type=Sling)
# has NO male mesh -- RedFalcon: "the senkamati neck item can be applied to either sex, even though
# it is female only mesh" -- Lua applies the female mesh regardless of target sex for that one row.
ws = wb["Belts and Straps"]
out.append("Config.BELTSTRAPS_PIECES = {")
for row in ws.iter_rows(min_row=2, values_only=True):
    pieceType, friendly, maleMesh, femaleMesh = row[:4]
    if pieceType is None or friendly is None:
        continue
    maleLua = luastr(maleMesh) if maleMesh else "nil"
    femaleLua = luastr(femaleMesh) if femaleMesh else "nil"
    out.append(f"  {{ type={luastr(pieceType)}, friendlyName={luastr(friendly)}, maleMesh={maleLua}, femaleMesh={femaleLua} }},")
out.append("}")
out.append("")

# ---- Sockets ----
ws = wb["Sockets"]
out.append("Config.SOCKETITEMS_SOCKETS = {")
for row in ws.iter_rows(min_row=2, values_only=True):
    socket, locDesc, socType, beltpiece, locTag, friendly = row[:6]
    if socket is None or socket in EXCLUDED_SOCKETS:
        continue
    bp = split_list(beltpiece)
    out.append(f"  {{ socket={luastr(socket)}, location={luastr(locDesc)}, socType={luastr(socType)}, beltpiece={luaarr(bp)}, locationTag={luastr(locTag)}, friendlyName={luastr(friendly)} }},")
out.append("}")
out.append("")

# ---- Item Ratios ----
ws = wb["Item Ratios"]
out.append("Config.SOCKETITEMS_RATIOS = {")
for row in ws.iter_rows(min_row=2, values_only=True):
    location, type_, count, notes = row[:4]
    if location is None:
        continue
    mandatory = "true" if (notes and "always" in str(notes).lower()) else "false"
    out.append(f"  {{ location={luastr(location)}, type={luastr(type_)}, count={int(count)}, mandatory={mandatory} }},{'  -- ' + str(notes) if notes else ''}")
out.append("}")
out.append("")

# ---- Rarity Ratios ----
ws = wb["Rarity Ratios"]
out.append("Config.SOCKETITEMS_RARITY_WEIGHTS = {")
for row in ws.iter_rows(min_row=2, values_only=True):
    rarity, chance = row[:2]
    if rarity is None:
        continue
    out.append(f"  [{luastr(rarity)}] = {chance},")
out.append("}")
out.append("")

# ---- Items ---- (columns as of 2026-09-15: Asset, Test Command, Short Name, Friendly Name,
# Available Socket, Limit, Tag, Rarity -- Test Command ignored)
ws = wb["Items"]
out.append("Config.SOCKETITEMS_ITEMS = {")
for row in ws.iter_rows(min_row=2, values_only=True):
    asset, _testCmd, shortName, friendly, availSocket, limit, tag, rarity = row[:8]
    if asset is None:
        continue
    socks = [s for s in split_list(availSocket) if s not in EXCLUDED_SOCKETS]
    tags = split_list(tag)
    # Defensive Limit parse -- one real row has had a stray string like "1_L" instead of a number.
    if isinstance(limit, (int, float)):
        limitNum = int(limit)
    else:
        m = re.match(r"^\s*(\d+)", str(limit or ""))
        limitNum = int(m.group(1)) if m else 1
    out.append(f"  {{ asset={luastr(asset)}, shortName={luastr(shortName)}, friendlyName={luastr(friendly)}, sockets={luaarr(socks)}, limit={limitNum}, tags={luaarr(tags)}, rarity={luastr(rarity)} }},")
out.append("}")
out.append("")

# ---- Weapons ---- (columns as of 2026-09-15: Asset, Short Name, Friendly Name, Available Socket,
# Tag, Location, Rarity)
ws = wb["Weapons"]
out.append("Config.SOCKETITEMS_WEAPONS = {")
for row in ws.iter_rows(min_row=2, values_only=True):
    asset, shortName, friendly, availSocket, tag, location, rarity = row[:7]
    if asset is None:
        continue
    socks = [s for s in split_list(availSocket) if s not in EXCLUDED_SOCKETS]
    tags = split_list(tag)
    out.append(f"  {{ asset={luastr(asset)}, shortName={luastr(shortName)}, friendlyName={luastr(friendly)}, sockets={luaarr(socks)}, tags={luaarr(tags)}, location={luastr(location)}, rarity={luastr(rarity)} }},")
out.append("}")
out.append("")

# ---- Tools ---- (2026-09-21, new tab: the flat item list backing the Custom tab's Left/Right
# Hand item dropdowns -- Friendly Name, Type, Mesh, Test Command (ignored). `type` is one of
# Weapons/Tools/Bottles/Other, matching the 4 hand dropdowns exactly.
ws = wb["Tools"]
out.append("Config.SOCKETITEMS_TOOLS = {")
for row in ws.iter_rows(min_row=2, values_only=True):
    friendly, type_, mesh = row[:3]
    if not friendly or not mesh:
        continue
    out.append(f"  {{ friendlyName = {luastr(friendly)}, type = {luastr(type_)}, asset = {luastr(mesh)} }},")
out.append("}")

result = "\n".join(out)
OUT_PATH = os.path.join(os.path.dirname(__file__), "socketitems_generated.lua")
with open(OUT_PATH, "w", encoding="utf-8") as f:
    f.write(result)
print(f"wrote {OUT_PATH}, {len(result)} chars -- paste this over the existing Config.SOCKETITEMS_* block in config.lua")
