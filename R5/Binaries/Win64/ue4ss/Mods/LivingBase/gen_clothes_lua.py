# gen_clothes_lua.py -- (2026-09-14) regenerates the Config.CLOTHES_ITEMS / Config.CLOTHES_OUTFITS
# blocks in config.lua from RedFalcon's own Other/Hair_And_Clothes_Export.xlsx ("Clothes Adjusted"
# and "Clothing Outfits" sheets -- RedFalcon personally validated which clothes work on which
# bodies in "Clothes Adjusted", including several items originally tagged sex-specific that turned
# out to work fine on both -- those show up here as a "BOTH"/"Both (...)" row with only ONE of
# malePath/femalePath/unisexPath populated, meaning "use this one mesh for both sexes").
#
# Mirrors the exact shape of the existing Config.HAIR_CATEGORY_ITEMS block (same field names:
# bodyPart/name/friendlyName/availability/malePath/femalePath/unisexPath, plus a new setName field)
# so Spawner.ApplyHairCategoryMesh's own sex-fallback-chain pattern
# (isFemale and (femalePath or unisexPath or malePath) or (malePath or unisexPath or femalePath))
# reads correctly for clothes too without any new resolution logic.
#
# Run this after ANY edit to Hair_And_Clothes_Export.xlsx, then paste the printed block over the
# existing Config.CLOTHES_ITEMS / Config.CLOTHES_OUTFITS section in config.lua (search for
# "Config.CLOTHES_ITEMS =").
#
# Usage:  python gen_clothes_lua.py
#
# If Excel has the workbook open, this script cannot read it directly (PermissionError) -- close
# Excel first, or this script will fall back to reading a same-folder copy named
# "Hair_And_Clothes_Export_copy.xlsx" if one exists.

import openpyxl, os, re, shutil, sys
from collections import defaultdict

XLSX_PATH = os.environ.get("CLOTHES_XLSX_OVERRIDE") or r"H:\OneDrive\Coding\WINDROSE MODS\Other\Hair_And_Clothes_Export.xlsx"

# The 8 real clothing slots this feature covers (matches BODY_PART_ENUM_BY_NAME's own spelling in
# spawner.lua exactly -- "Feets"/"Headgear", not "Feet"/"Hat" -- those friendlier names are a
# UI-only relabeling done in CustomMenu.cpp, not used anywhere in this data). "Outfit" is also a
# real Body Part value in "Clothes Adjusted" but only ever a placeholder row (Friendly Name = a Set
# Name, every other column blank) -- the actual Outfit list comes from grouping "Clothing Outfits"
# by Set Name instead, not from these placeholder rows.
#
# Mask ADDED BACK (2026-09-16, RedFalcon: "add it back in, as some of the pregen NPCs have it, same
# as waist already being there despite not being able to use it") -- REVERSES the original 2026-09-14
# exclusion (project_sdk_stub_ue_editor memory: the only real Mask asset permanently suspends facial
# hair with no alternative, so it was left out of the OUTFIT-BUILD feature on the LivingBaseExtended
# side). That reasoning was specific to building a NEW Barbie outfit from scratch, where losing
# default facial hair for every Male spawn was too costly to accept for one niche asset -- it does
# NOT apply here: this is a pure per-target READ/APPLY row on an EXISTING pregen NPC (same as Waist,
# which is already in this same list "despite not being able to use it" per RedFalcon's own words --
# real Torso pieces always suspend Waist, but the row stays so Waist can still be READ/displayed).
# Mask has no rows in "Clothes Adjusted" (RedFalcon's own curated pass never covered it, since it was
# excluded when that sheet was built) -- its 3 real rows are pulled from the raw "Clothes" sheet
# instead, just below, and merged into the same items_by_part dict Mask never has a Set Name (not
# part of any Clothing Outfit -- "only the blackbeard pirate has a scarf," never bundled).
REAL_BODY_PARTS = {"Torso", "Legs", "Waist", "Hands", "Feets", "Headgear", "Cape", "Mask"}

# An outfit must define at least these 3 slots to be offered at all (RedFalcon, 2026-09-14: "Any
# outfit should contain at least feet, torso and legs. If it doesn't, dont create that outfit").
REQUIRED_OUTFIT_PARTS = {"Feets", "Torso", "Legs"}


def open_workbook(path):
    try:
        return openpyxl.load_workbook(path, data_only=True)
    except PermissionError:
        fallback = os.path.join(os.path.dirname(path), "Hair_And_Clothes_Export_copy.xlsx")
        try:
            shutil.copy(path, fallback)
        except Exception:
            print(f"ERROR: '{path}' is locked (probably open in Excel) and no fallback copy "
                  f"could be made. Close Excel and re-run.", file=sys.stderr)
            raise
        print(f"NOTE: source was locked, read a fresh copy at '{fallback}' instead.")
        return openpyxl.load_workbook(fallback, data_only=True)


def fix_source_asset_path(s):
    """The sheet's own 'Source asset' column exports paths as '/Game/R5/Content/Gameplay/...' --
    an Editor-project-relative spelling, not the real in-game virtual mount path, which is always
    just '/Game/Gameplay/...' (confirmed: every other hardcoded DataAsset path elsewhere in
    spawner.lua, e.g. TORSO_PIECES/HEADGEAR_PIECES, uses '/Game/Gameplay/...' with no 'R5/Content'
    segment -- and resolveAsset live-failed on the unfixed path, 2026-09-14 live test). Strip it."""
    if s is None:
        return None
    return s.replace("/Game/R5/Content/", "/Game/", 1)


def norm_ws(s):
    """Collapse repeated whitespace and strip -- fixes real spreadsheet typos found in this
    workbook ('Mercenary Head  1' double space, 'Blackbeard Musketeer 1 ' trailing space on the
    Set Name that would otherwise silently split one outfit into two)."""
    if s is None:
        return None
    return re.sub(r"\s+", " ", str(s)).strip()


def luastr(s):
    if s is None:
        return "nil"
    s = str(s).replace("\\", "\\\\").replace('"', '\\"')
    return '"' + s + '"'


wb = open_workbook(XLSX_PATH)

# ---- Clothes Adjusted -> Config.CLOTHES_ITEMS ----
ws = wb["Clothes Adjusted"]
header = [c.value for c in ws[1]]
assert header[:9] == ["Body Part", "Name", "Friendly Name", "Set Name", "Availability",
                       "Male mesh", "Female mesh", "Unisex mesh", "Source asset"], \
    f"Clothes Adjusted header changed, update this script: {header}"

items_by_part = defaultdict(list)
seen_friendly = defaultdict(int)  # (bodyPart, friendlyName) -> count seen so far, for disambiguation
name_to_part_key = {}  # (bodyPart, rawName) -> the final friendlyName actually used (for outfit lookup)

for row in ws.iter_rows(min_row=2, values_only=True):
    bodyPart, name, friendlyName, setName, availability, maleMesh, femaleMesh, unisexMesh, srcAsset = row[:9]
    bodyPart = norm_ws(bodyPart)
    if not bodyPart or bodyPart not in REAL_BODY_PARTS:
        continue  # skips "Outfit" placeholder rows and any stray/blank rows
    if not (maleMesh or femaleMesh or unisexMesh):
        continue  # no usable mesh at all -- nothing to add to a dropdown
    name = norm_ws(name)
    friendlyName = norm_ws(friendlyName)
    setName = norm_ws(setName)
    availability = norm_ws(availability)
    srcAsset = fix_source_asset_path(norm_ws(srcAsset))

    key = (bodyPart, friendlyName)
    seen_friendly[key] += 1
    finalFriendly = friendlyName
    if seen_friendly[key] > 1:
        # Real duplicate friendly name within the same slot (2 confirmed: "Mercenary Head 1" used
        # by both the Bandana and Headband headgear pieces) -- disambiguate rather than silently
        # collide in the dropdown. Generic counter suffix, not a guessed semantic label.
        finalFriendly = f"{friendlyName} ({seen_friendly[key]})"

    items_by_part[bodyPart].append({
        "name": name, "friendlyName": finalFriendly, "setName": setName,
        "availability": availability, "maleMesh": maleMesh, "femaleMesh": femaleMesh,
        "unisexMesh": unisexMesh, "sourceAsset": srcAsset,
    })
    if name is not None:
        name_to_part_key[(bodyPart, name)] = finalFriendly

# ---- Mask supplement: pulled from the raw "Clothes" sheet, not "Clothes Adjusted" (2026-09-16) --
# see REAL_BODY_PARTS' own comment above for why. All 3 real rows verified present here: 2 MALE ONLY
# (Mask 1/2, femaleMesh blank) + 1 Both (Mask 3, RedFalcon's own single dual-sex variant -- same mesh
# path in both the Male and Female columns, not two distinct assets despite the "distinct Male +
# Female art" label text).
wsRaw = wb["Clothes"]
headerRaw = [c.value for c in wsRaw[1]]
assert headerRaw[:8] == ["Body Part", "Name", "Friendly Name", "Availability",
                         "Male mesh", "Female mesh", "Unisex mesh", "Source asset"], \
    f"Clothes header changed, update this script: {headerRaw}"
for row in wsRaw.iter_rows(min_row=2, values_only=True):
    bodyPart, name, friendlyName, availability, maleMesh, femaleMesh, unisexMesh, srcAsset = row[:8]
    bodyPart = norm_ws(bodyPart)
    if bodyPart != "Mask":
        continue
    if not (maleMesh or femaleMesh or unisexMesh):
        continue
    name = norm_ws(name)
    friendlyName = norm_ws(friendlyName)
    availability = norm_ws(availability)
    srcAsset = fix_source_asset_path(norm_ws(srcAsset))

    key = (bodyPart, friendlyName)
    seen_friendly[key] += 1
    finalFriendly = friendlyName
    if seen_friendly[key] > 1:
        finalFriendly = f"{friendlyName} ({seen_friendly[key]})"

    items_by_part[bodyPart].append({
        "name": name, "friendlyName": finalFriendly, "setName": None,
        "availability": availability, "maleMesh": maleMesh, "femaleMesh": femaleMesh,
        "unisexMesh": unisexMesh, "sourceAsset": srcAsset,
    })
    if name is not None:
        name_to_part_key[(bodyPart, name)] = finalFriendly

out = []
out.append("-- Config.CLOTHES_ITEMS -- generated by gen_clothes_lua.py from Other\\Hair_And_Clothes_Export.xlsx's")
out.append("-- \"Clothes Adjusted\" sheet (RedFalcon's own validated per-body-type pass). One row per real,")
out.append("-- pickable clothing item, keyed by bodyPart (Torso/Legs/Waist/Hands/Feets/Headgear/Cape -- the SAME")
out.append("-- spelling as spawner.lua's own BODY_PART_ENUM_BY_NAME), sorted alphabetically by friendlyName")
out.append("-- WITHIN each bodyPart -- this order IS the dropdown order, do not re-sort at runtime (same rule")
out.append("-- Config.HAIR_CATEGORY_ITEMS' own header already established). `availability` is the raw sheet")
out.append("-- string (e.g. \"MALE ONLY\", \"Both (single unisex mesh) - Only with Unlock\") -- a string containing")
out.append("-- \"Only with Unlock\" gates this item behind Config.CLOTHES_UNLOCK_ALL (lbunlockclothes), same flag")
out.append("-- as the existing women's-fit-rule bypass. Mesh resolution follows the EXACT same fallback chain")
out.append("-- Spawner.ApplyHairCategoryMesh already uses for non-Hairs rows: `unisexMesh or (isFemale and")
out.append("-- femaleMesh or maleMesh) or maleMesh or femaleMesh` -- this alone implements RedFalcon's \"where")
out.append("-- you see [a sex-flagged item] with a mesh only for one sex type, use it for both\" rule, since a")
out.append("-- row validated as BOTH-but-only-one-mesh-populated just falls through to that one mesh either way.")
out.append("-- `sourceAsset` (2026-09-14, RedFalcon: \"assigning headgear also needs to behave correctly with")
out.append("-- the hair\") is the item's own backing DA_Armor_..._CompositeMeshData path (the sheet's own")
out.append("-- \"Source asset\" column) -- for Headgear specifically, Spawner.ApplyClothesItem reads its real")
out.append("-- SlotsToSuspend property (the SAME proven mechanism lbdumpsuspend/DumpHeadgearSuspend already")
out.append("-- use) to decide exactly how the hair should react, rather than guessing a category from the")
out.append("-- mesh filename.")
out.append("Config.CLOTHES_ITEMS = {")
for bodyPart in sorted(items_by_part.keys()):
    rows = sorted(items_by_part[bodyPart], key=lambda r: r["friendlyName"].lower())
    out.append(f"  {bodyPart} = {{")
    for r in rows:
        out.append(
            "    { name=%s, friendlyName=%s, setName=%s, availability=%s, maleMesh=%s, femaleMesh=%s, unisexMesh=%s, sourceAsset=%s },"
            % (luastr(r["name"]), luastr(r["friendlyName"]), luastr(r["setName"]),
               luastr(r["availability"]), luastr(r["maleMesh"]), luastr(r["femaleMesh"]), luastr(r["unisexMesh"]),
               luastr(r["sourceAsset"]))
        )
    out.append("  },")
out.append("}")
out.append("")

# ---- Clothing Outfits -> Config.CLOTHES_OUTFITS ----
ws2 = wb["Clothing Outfits"]
header2 = [c.value for c in ws2[1]]
assert header2[:4] == ["Body Part", "Name", "Friendly Name", "Set Name"], \
    f"Clothing Outfits header changed, update this script: {header2}"

# Mask is deliberately EXCLUDED from outfit-bundling specifically (2026-09-16) even though it's now
# a real standalone Config.CLOTHES_ITEMS category above -- the original 2026-09-14 exclusion reason
# (the only real Mask asset permanently suspends Mustache/Beard/Whiskers with no alternative) is
# STILL a real concern for a bulk multi-slot APPLY like an outfit selection, even though it's fine
# for a plain per-slot read/apply row. Without this, "Clothing Outfits" rows tag 3 real Mask pieces
# onto "Blackbeard Sailor 1/2/3" (confirmed present in the sheet) that would otherwise silently
# start suspending facial hair on anyone who picks that Outfit -- exactly what RedFalcon avoided
# building to in the first place ("only the blackbeard pirate has a scarf. i feel like we dont need
# to build to that exception").
OUTFIT_BODY_PARTS = REAL_BODY_PARTS - {"Mask"}

pieces_by_set = defaultdict(dict)  # setName -> { bodyPart: friendlyName }
set_order = []
for row in ws2.iter_rows(min_row=2, values_only=True):
    bodyPart, name, friendlyName, setName = row[:4]
    bodyPart = norm_ws(bodyPart)
    name = norm_ws(name)
    setName = norm_ws(setName)
    if not setName or not bodyPart or bodyPart not in OUTFIT_BODY_PARTS:
        continue  # drops Mask pieces (excluded from outfit-bundling, see OUTFIT_BODY_PARTS' own comment) and any blank rows
    resolved = name_to_part_key.get((bodyPart, name))
    if resolved is None:
        print(f"WARNING: Clothing Outfits piece ({bodyPart}, {name!r}) for set {setName!r} has no "
              f"matching row in Clothes Adjusted -- skipped.", file=sys.stderr)
        continue
    if setName not in pieces_by_set:
        set_order.append(setName)
    pieces_by_set[setName][bodyPart] = resolved

qualifying = [s for s in set_order if REQUIRED_OUTFIT_PARTS.issubset(pieces_by_set[s].keys())]
skipped = [s for s in set_order if s not in qualifying]
if skipped:
    print(f"NOTE: {len(skipped)} outfit(s) skipped (missing Feets/Torso/Legs), per RedFalcon's own rule:", file=sys.stderr)
    for s in skipped:
        print(f"       {s} -> has only {sorted(pieces_by_set[s].keys())}", file=sys.stderr)

out.append("-- Config.CLOTHES_OUTFITS -- generated by gen_clothes_lua.py from the same workbook's \"Clothing")
out.append("-- Outfits\" sheet, grouped by Set Name. Each entry's `pieces` maps a bodyPart to the exact")
out.append("-- friendlyName to look up in Config.CLOTHES_ITEMS[bodyPart] (no mesh data duplicated here --")
out.append("-- single source of truth). Applying an outfit only SETS the slots it defines and leaves every")
out.append("-- other slot untouched (RedFalcon, 2026-09-14: \"only set the items, but do not clear any others\").")
out.append("-- Sorted alphabetically by setName -- this order IS the Outfit dropdown order. Outfits missing")
out.append("-- Feets/Torso/Legs are DROPPED ENTIRELY (RedFalcon: \"Any outfit should contain at least feet,")
out.append("-- torso and legs. If it doesn't, dont create that outfit\") -- see this script's own stderr")
out.append("-- output for which sets were skipped and why, if re-run.")
out.append("Config.CLOTHES_OUTFITS = {")
for setName in sorted(qualifying, key=lambda s: s.lower()):
    pieces = pieces_by_set[setName]
    piece_strs = ", ".join(f"{bp}={luastr(pieces[bp])}" for bp in sorted(pieces.keys()))
    out.append(f"  {{ setName={luastr(setName)}, pieces = {{ {piece_strs} }} }},")
out.append("}")

print("\n".join(out))
