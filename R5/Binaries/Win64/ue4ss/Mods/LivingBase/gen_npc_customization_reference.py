"""
gen_npc_customization_reference.py (2026-09-17, revised same day)

Generates the Config.NPC_LOOK_CLASSIFICATION / Config.NPC_CUSTOM_BASELINE block
(config_npc_customization_reference.lua, meant to be pasted/kept in sync inside config.lua)
from two sources:

  - Other/randomized.xlsx ("Randomized" / "ModifiedFromOthers" sheets) -- RedFalcon's own
    classification of which spawn-menu entries reroll their whole look at build time
    (Randomized) vs. are already assembled by redressing a different base class
    (ModifiedFromOthers). Anything NOT in either sheet is "normal": a single fixed look.
  - npc_preset_scan.txt (the live HOME-key roster probe file, LivingBase mod folder) --
    per-archetype DefaultParams asset path + RAW*:... lines (Spawner.CaptureRawCustomBaseline),
    only ever populated for "normal" archetypes scanned on a genuinely fresh/untouched actor
    (Randomized/Modified entries are deliberately never scanned this way).

REVISION NOTE: an earlier version of this generator emitted Config.NPC_CUSTOM_REFERENCE, a table
of CATEGORY fixed/customizable FLAGS (Customization.UID.*'s own bAllowCustomization). RedFalcon
corrected that design same day: bAllowCustomization=false does NOT mean this project's own tooling
can't edit a category (confirmed live -- clothes/colors on Letty, whose Armor category reports
fixed=true, apply fine) -- it almost certainly only governs the GAME's OWN native customization
station UI, which this whole Custom tab bypasses entirely. That flag data is gone; this version
instead captures the archetype's actual RAW baseline VALUES (mesh/material names, not friendly
names) so Save can diff the current read against them and only write what's genuinely different
("if I only changed her legs, the only thing it does on reload is update her legs").

Run from the LivingBase mod folder:
    python gen_npc_customization_reference.py

Reads:  Other/randomized.xlsx (repo root, ../../../../../../../../../Other relative to here --
        adjust ROOT below if this script moves), npc_preset_scan.txt (this folder, or the live
        install's copy if this one doesn't exist yet)
Writes: config_npc_customization_reference.lua (this folder) -- paste its contents into
        config.lua by hand (matching gen_clothes_lua.py/gen_socketitems_lua.py's own convention
        of generating a block to review before merging, not overwriting config.lua directly).
"""
import re
import os
import openpyxl

HERE = os.path.dirname(os.path.abspath(__file__))
XLSX_PATH = os.path.join(HERE, "..", "..", "..", "..", "..", "..", "..", "..", "Other", "randomized.xlsx")
SCAN_PATH = os.path.join(HERE, "npc_preset_scan.txt")

# VARIABLE_CATEGORIES_BY_DEFAULTPARAMS_SUBSTRING (2026-09-17, RedFalcon: "I actually realized that
# the clothes and physique of the senkamati actually do vary" -- but NOT their hair/eye
# color/skin tone). Blanket-classifying the whole archetype as "randomized" (like the earlier,
# reverted attempt did) would have wrongly stopped tracking those genuinely-stable categories too.
# Instead, ONLY the named categories are dropped from a matching archetype's baseline -- an
# excluded category then has no baseline entry at all, so BuildCustomStateLines' own "no baseline
# -> always write" fallback kicks in for JUST that category, exactly matching the treatment a
# "randomized" archetype's non-Color categories already get, while every other category on the
# SAME archetype still diffs normally. Matched by a plain substring against the DefaultParams
# path -- add more entries here if another archetype turns out to have the same partial-variance
# shape.
VARIABLE_CATEGORIES_BY_DEFAULTPARAMS_SUBSTRING = {
    "SenkamatiCorrupted": {"clothes", "physique"},
}


def VARIABLE_CATEGORIES_BY_DEFAULTPARAMS_SUBSTRING_match(default_params_path):
    skip = set()
    for substr, cats in VARIABLE_CATEGORIES_BY_DEFAULTPARAMS_SUBSTRING.items():
        if substr in default_params_path:
            skip |= cats
    return skip


def norm(s):
    return re.sub(r"\s+", " ", s.strip())


def lua_str(s):
    escaped = s.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + escaped + '"'


def load_classification(xlsx_path):
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    classification = {}
    for label in (norm(r[0]) for r in wb["Randomized"].iter_rows(values_only=True) if r[0]):
        classification[label] = "randomized"
    for label in (norm(r[0]) for r in wb["ModifiedFromOthers"].iter_rows(values_only=True) if r[0]):
        classification[label] = "modified"
    return classification


def load_scan(scan_path):
    content = open(scan_path, encoding="utf-8").read()
    blocks = {}
    cur = None
    for line in content.splitlines():
        line = line.strip()
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            cur = {
                "defaultParams": None,
                "colors": {}, "physique": None, "hairColors": {}, "hair": {},
                "eyeColor": None, "clothes": {}, "skinTone": None, "belts": {}, "accessories": {},
                "pose": None, "lantern": None, "scale": None,
            }
            blocks[m.group(1)] = cur
            continue
        if cur is None or not line or line.startswith(";"):
            continue
        if line.startswith("DEFAULTPARAMS:"):
            cur["defaultParams"] = line[len("DEFAULTPARAMS:"):].split(" ", 1)[-1]
        elif line.startswith("RAWCOLOR:"):
            key, c1, c2, c3 = line[len("RAWCOLOR:"):].split(":")
            cur["colors"][key] = (c1, c2, c3)
        elif line.startswith("RAWPHYSIQUE:"):
            cur["physique"] = line[len("RAWPHYSIQUE:"):]
        elif line.startswith("RAWHAIRCOLOR:"):
            cat, idx = line[len("RAWHAIRCOLOR:"):].rsplit(":", 1)
            cur["hairColors"][cat] = int(idx)
        elif line.startswith("RAWHAIR:"):
            cat, mesh = line[len("RAWHAIR:"):].split(":", 1)
            cur["hair"][cat] = mesh
        elif line.startswith("RAWEYECOLOR:"):
            cur["eyeColor"] = line[len("RAWEYECOLOR:"):]
        elif line.startswith("RAWCLOTHES:"):
            bp, mesh = line[len("RAWCLOTHES:"):].split(":", 1)
            cur["clothes"][bp] = mesh
        elif line.startswith("RAWSKINTONE:"):
            cur["skinTone"] = line[len("RAWSKINTONE:"):]
        elif line.startswith("RAWBELT:"):
            piece, mesh = line[len("RAWBELT:"):].split(":", 1)
            cur["belts"][piece] = mesh
        elif line.startswith("RAWACC:"):
            socket, mesh = line[len("RAWACC:"):].split(":", 1)
            cur["accessories"][socket] = mesh
        elif line.startswith("RAWPOSE:"):
            cur["pose"] = line[len("RAWPOSE:"):]
        elif line.startswith("RAWLANTERN:"):
            cur["lantern"] = line[len("RAWLANTERN:"):]
        elif line.startswith("RAWSCALE:"):
            cur["scale"] = line[len("RAWSCALE:"):]

    baseline = {}
    for label, b in blocks.items():
        if b["defaultParams"]:
            baseline[b["defaultParams"]] = b
    return baseline


def lua_str_map(d, quote_value=True):
    parts = []
    for k in sorted(d.keys()):
        v = d[k]
        vs = lua_str(v) if quote_value else str(v)
        parts.append("[%s]=%s" % (lua_str(k), vs))
    return "{" + ", ".join(parts) + "}"


def main():
    classification = load_classification(XLSX_PATH)
    baseline = load_scan(SCAN_PATH)

    lines = []
    lines.append("-- Config.NPC_LOOK_CLASSIFICATION (2026-09-17) -- generated from Other/randomized.xlsx via")
    lines.append("-- gen_npc_customization_reference.py. Keyed by a spawn menu DISPLAY LABEL (the label BEFORE")
    lines.append("-- Spawner.NextInstanceLabel appends its own trailing instance number, e.g. \"BotC Merchant 4\"")
    lines.append("-- not \"BotC Merchant 4 1\") -- \"randomized\" means every customization category on this")
    lines.append("-- archetype rerolls at build time (only Color is a real, worth-saving edit); \"modified\" means")
    lines.append("-- this look is already assembled by redressing a different base class (Letty/Marita/the")
    lines.append("-- walking women, Senkamati Upright/Wild mask variants, etc.) -- RedFalcon: \"already being")
    lines.append("-- processed so the detect doesn't make sense\", better alternatives still TBD, not yet gated.")
    lines.append("-- Absent from this table = \"normal\": a single fixed look, safe to diff/save/restore")
    lines.append("-- per-category using Config.NPC_CUSTOM_BASELINE below.")
    lines.append("Config.NPC_LOOK_CLASSIFICATION = {")
    for label in sorted(classification.keys()):
        lines.append("  [%s] = %s," % (lua_str(label), lua_str(classification[label])))
    lines.append("}")
    lines.append("")
    lines.append("-- Config.NPC_CUSTOM_BASELINE (2026-09-17, revised) -- generated from npc_preset_scan.txt's")
    lines.append("-- RAW*:... lines (Spawner.CaptureRawCustomBaseline) via gen_npc_customization_reference.py.")
    lines.append("-- Keyed by the FULL DefaultParams asset path (readable off any live actor via")
    lines.append("-- Spawner.ReadDefaultParamsSummary). Each entry is the archetype's REAL default state --")
    lines.append("-- raw mesh/material names, not friendly names, so a Config.*_ITEMS catalog rename never")
    lines.append("-- breaks this comparison -- captured on a genuinely fresh/untouched HOME-scanned actor.")
    lines.append("-- BuildCustomStateLines diffs the current read against this per-category so Save only")
    lines.append("-- writes a line for what ACTUALLY changed. Only covers archetypes RedFalcon has actually")
    lines.append("-- HOME-scanned -- an actor whose DefaultParams isn't a key here just skips this diff")
    lines.append("-- entirely (falls back to always-write, current unrestricted behavior).")
    lines.append("Config.NPC_CUSTOM_BASELINE = {")
    for dp in sorted(baseline.keys()):
        b = baseline[dp]
        skip = VARIABLE_CATEGORIES_BY_DEFAULTPARAMS_SUBSTRING_match(dp)
        fields = []
        if b["colors"]:
            color_parts = []
            for k in sorted(b["colors"].keys()):
                c1, c2, c3 = b["colors"][k]
                color_parts.append("[%s]={%s,%s,%s}" % (lua_str(k), lua_str(c1), lua_str(c2), lua_str(c3)))
            fields.append("colors={%s}" % ", ".join(color_parts))
        if b["physique"] and "physique" not in skip:
            fields.append("physique=%s" % lua_str(b["physique"]))
        if b["hairColors"]:
            fields.append("hairColors=%s" % lua_str_map(b["hairColors"], quote_value=False))
        if b["hair"]:
            fields.append("hair=%s" % lua_str_map(b["hair"]))
        if b["eyeColor"]:
            fields.append("eyeColor=%s" % lua_str(b["eyeColor"]))
        if b["clothes"] and "clothes" not in skip:
            fields.append("clothes=%s" % lua_str_map(b["clothes"]))
        if b["skinTone"]:
            fields.append("skinTone=%s" % lua_str(b["skinTone"]))
        if b["belts"]:
            fields.append("belts=%s" % lua_str_map(b["belts"]))
        if b["accessories"]:
            fields.append("accessories=%s" % lua_str_map(b["accessories"]))
        if b["pose"]:
            fields.append("pose=%s" % lua_str(b["pose"]))
        if b["lantern"]:
            fields.append("lantern=%s" % lua_str(b["lantern"]))
        if b["scale"]:
            fields.append("scale=%s" % lua_str(b["scale"]))
        lines.append("  [%s] = { %s }," % (lua_str(dp), ", ".join(fields)))
    lines.append("}")

    out_path = os.path.join(HERE, "config_npc_customization_reference.lua")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("Classification entries: %d" % len(classification))
    print("Baseline entries: %d" % len(baseline))
    missing_raw = [dp for dp, b in baseline.items() if not any([
        b["colors"], b["physique"], b["hairColors"], b["hair"], b["eyeColor"],
        b["clothes"], b["skinTone"], b["belts"], b["accessories"],
    ])]
    if missing_raw:
        print("WARNING: %d entries have DEFAULTPARAMS but no RAW*: data at all -- re-scan needed:" % len(missing_raw))
        for dp in missing_raw:
            print("  -", dp)
    print("Wrote %s" % out_path)


if __name__ == "__main__":
    main()
