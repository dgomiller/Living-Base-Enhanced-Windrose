#!/usr/bin/env python
"""
LivingBase pre-flight check.  Run before handing any edit to Luke.

`lupa` only proves the Lua PARSES. It happily compiles a call to a function that does not exist —
that's a runtime error, not a syntax one. v2.19 shipped `always(...)` with no definition; every
call raised "attempt to call a nil value" and silently killed the restore chain, and the compile
check said OK. This lint exists so that class of bug cannot ship again.

Checks:
  1. every script compiles (lupa)
  2. every bare `name(...)` call resolves to something defined in that file, or a known API
  3. every Config.X a runtime script references exists in config.lua (config_local applied)
"""
import glob
import os
import re
import sys

import lupa

SCRIPTS = ["main", "spawner", "testbed", "whistle", "unlockbuild"]

KNOWN = {
    # lua stdlib
    "print", "pcall", "xpcall", "error", "assert", "type", "tostring", "tonumber",
    "ipairs", "pairs", "next", "select", "require", "setmetatable", "getmetatable",
    "rawget", "rawset", "unpack", "load", "loadstring", "collectgarbage",
    # UE4SS API
    "FindAllOf", "FindFirstOf", "FindObject", "StaticFindObject", "LoadAsset", "FName", "FText",
    "RegisterKeyBind", "RegisterHook", "NotifyOnNewObject", "LoopAsync",
    "ExecuteInGameThread", "ExecuteWithDelay", "RegisterInitGameStatePostHook",
    "RegisterBeginPlayPostHook", "CreateInvalidObject", "IsValid",
    "RegisterConsoleCommandHandler", "DumpAllObjects", "DumpAllActors", "DumpStaticMeshes",
    "RestartMod",
    # lua keywords CALL_RE can pick up right before a paren
    "if", "while", "for", "return", "and", "or", "not", "then", "do", "end",
    "function", "in", "local", "else", "elseif", "repeat", "until", "break",
    "nil", "true", "false", "goto",
}

# a bare call: not preceded by '.' or ':' (those are method/field calls we can't resolve statically)
CALL_RE = re.compile(r"(?<![\w.:])([A-Za-z_]\w*)\s*\(")


def blank_keep_lines(text: str) -> str:
    return "\n" * text.count("\n")


def strip_noise(src: str) -> str:
    """Blank comments and strings WITHOUT changing line numbers (wrong line refs are worse than none)."""
    src = re.sub(r"--\[\[.*?\]\]", lambda m: blank_keep_lines(m.group(0)), src, flags=re.S)
    src = re.sub(r"--[^\n]*", "", src)
    src = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', src)
    src = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", src)
    return src


def defined_names(src: str) -> set:
    """Every name this file may legally call: locals, functions, and function PARAMETERS."""
    names = set()
    names |= set(re.findall(r"local\s+function\s+([A-Za-z_]\w*)", src))
    names |= set(re.findall(r"function\s+([A-Za-z_]\w*)\s*[.:]?\w*\s*\(", src))
    # `local a, b = ...`
    for m in re.findall(r"local\s+([A-Za-z_][\w\s,]*?)\s*=", src):
        for n in m.split(","):
            names.add(n.strip())
    # bare forward declaration: `local foo`
    names |= set(re.findall(r"local\s+([A-Za-z_]\w*)\s*$", src, re.M))
    # PARAMETERS: a callback named `onDone` is defined, just not by `local`.
    for params in re.findall(r"function\s*[\w.:]*\s*\(([^)]*)\)", src):
        for n in params.split(","):
            n = n.strip()
            if n and n != "...":
                names.add(n)
    # `for k, v in pairs(...)` loop variables
    for m in re.findall(r"for\s+([A-Za-z_][\w\s,]*?)\s+in\b", src):
        for n in m.split(","):
            names.add(n.strip())
    # numeric for: `for i = 1, n do`
    names |= set(re.findall(r"for\s+([A-Za-z_]\w*)\s*=", src))
    return {n for n in names if n}


def check_compile() -> list:
    fails = []
    L = lupa.LuaRuntime()
    for f in sorted(glob.glob("Scripts/*.lua")):
        try:
            L.compile(open(f, encoding="utf-8").read())
        except Exception as e:  # noqa: BLE001
            fails.append(f"COMPILE {f}: {e}")
    return fails


def check_undefined_calls() -> list:
    bad = []
    for name in SCRIPTS:
        path = f"Scripts/{name}.lua"
        if not os.path.exists(path):
            continue
        raw = open(path, encoding="utf-8").read()
        src = strip_noise(raw)
        known = KNOWN | defined_names(src)
        for m in CALL_RE.finditer(src):
            fn = m.group(1)
            if fn in known:
                continue
            line = src[: m.start()].count("\n") + 1
            bad.append(f"{name}.lua:{line}  {fn}(...)")
    return bad


MODULES = {"Spawner": "spawner", "Testbed": "testbed", "Whistle": "whistle"}


def module_members(mod_file: str, table: str) -> set:
    """Names defined on a module table: `function Tbl.X(` and `Tbl.X = ...`."""
    src = strip_noise(open(f"Scripts/{mod_file}.lua", encoding="utf-8").read())
    names = set(re.findall(r"function\s+" + re.escape(table) + r"[.:](\w+)", src))
    names |= set(re.findall(r"(?<![\w.])" + re.escape(table) + r"\.(\w+)\s*=", src))
    return names


def check_module_members() -> list:
    """`Spawner.MoveTowards(...)` that doesn't exist is nil — and every call site here is inside a
    pcall, so it fails SILENTLY. That is exactly how the follow loop could do nothing at all."""
    bad = []
    defined = {}
    for table, mod in MODULES.items():
        if os.path.exists(f"Scripts/{mod}.lua"):
            defined[table] = module_members(mod, table)
    for name in SCRIPTS:
        path = f"Scripts/{name}.lua"
        if not os.path.exists(path):
            continue
        src = strip_noise(open(path, encoding="utf-8").read())
        for table, members in defined.items():
            # skip the module's own file (it may define members after use, which Lua allows)
            if MODULES[table] == name:
                continue
            # boundary: the negative-lookbehind stops "Foo.Spawner.X" matching table "Spawner"
            for m in re.finditer(r"(?<![\w.])" + re.escape(table) + r"\.(\w+)\s*\(", src):
                if m.group(1) not in members:
                    line = src[: m.start()].count("\n") + 1
                    bad.append(f"{name}.lua:{line}  {table}.{m.group(1)}(...) is not defined")
    return bad


def check_config_keys() -> list:
    lr = lupa.LuaRuntime(unpack_returned_tuples=True)
    local_src = ""
    if os.path.exists("Scripts/config_local.lua"):
        local_src = open("Scripts/config_local.lua", encoding="utf-8").read()
    lr.globals()["LOCAL_SRC"] = local_src
    lr.execute(
        "package={loaded={}}\n"
        'function require(n) if n=="config_local" and LOCAL_SRC~="" then return load(LOCAL_SRC)() end error("no") end'
    )
    cfg = lr.execute(open("Scripts/config.lua", encoding="utf-8").read())
    have = set(cfg.keys())
    missing = []
    for name in SCRIPTS:
        path = f"Scripts/{name}.lua"
        if not os.path.exists(path):
            continue
        raw = open(path, encoding="utf-8").read()
        for m in re.finditer(r"Config\.([A-Za-z_]\w*)", raw):
            ls = raw.rfind("\n", 0, m.start()) + 1
            if raw[ls: raw.find("\n", m.start())].strip().startswith("--"):
                continue
            if m.group(1) not in have:
                missing.append(f"{name}.lua: Config.{m.group(1)}")
    return sorted(set(missing)), len(have)


def main() -> int:
    fails = check_compile()
    if fails:
        for x in fails:
            print("  " + x)
        return 1
    print(f"  compile: {len(glob.glob('Scripts/*.lua'))} scripts OK")

    bad = check_undefined_calls()
    if bad:
        print("  UNDEFINED CALLS ('attempt to call a nil value' at runtime):")
        for b in bad:
            print("    " + b)
        return 1
    print("  undefined-call check: clean")

    badmod = check_module_members()
    if badmod:
        print("  MISSING MODULE MEMBERS (nil at runtime, swallowed by pcall):")
        for b in badmod:
            print("    " + b)
        return 1
    print("  module-member check: clean")

    missing, nkeys = check_config_keys()
    if missing:
        print("  MISSING CONFIG KEYS:")
        for x in missing:
            print("    " + x)
        return 1
    print(f"  config keys: {nkeys} defined, all references resolve")

    print("PRE-FLIGHT OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
