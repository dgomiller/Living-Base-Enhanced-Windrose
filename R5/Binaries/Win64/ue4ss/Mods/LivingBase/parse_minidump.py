"""
parse_minidump.py -- minimal crash-dump triage, no debugger required (2026-09-08).

When a Lua console command crashes Windrose natively, UE4SS writes a real .dmp file to
R5/Binaries/Win64/ue4ss/crash_<timestamp>.dmp for every single crash. No full debugger (cdb/WinDbg)
is installed on this machine -- Windows Kits\\10\\Debuggers only has the bare DLLs, not the actual
debugger exe -- but a minidump's own binary layout (Microsoft's documented MINIDUMP_HEADER/
MINIDUMP_DIRECTORY/MINIDUMP_EXCEPTION_STREAM/MINIDUMP_MODULE_LIST structures) is simple enough to
parse directly: read the stream directory, pull the exception code + faulting address from the
Exception stream, then find which loaded module's base/size range contains that address. No
symbols needed for this much -- just "which module."

This answers the one question that matters most for triage, cheaply: did the crash happen inside
the GAME's own compiled code (Windrose-Win64-Shipping.exe -- a content/asset-specific problem,
usually), or inside UE4SS.dll (or a compiled companion mod's own DLL) itself -- a sign that some
SPECIFIC property/function reflection shape isn't safe to touch this way, independent of whether
the Lua logic calling it is correct? Confirmed useful 2026-09-08: two new commands (lbphotoscene/
lbfreecam, see WINDROSE_MODDING_NOTES.md SS3s) both crashed inside UE4SS.dll at nearly identical
offsets, reframing what looked like two unrelated bugs into one shared reflection-bridge issue.

Usage: python parse_minidump.py "<path to .dmp>"
"""
import struct
import sys

def parse(path):
    with open(path, "rb") as f:
        data = f.read()

    sig, ver, nstreams, dir_rva, checksum, timestamp, flags = struct.unpack_from("<IIIIIIQ", data, 0)
    if sig != 0x504D444D:
        raise ValueError(f"not a minidump (sig={sig:#x})")

    streams = []
    for i in range(nstreams):
        off = dir_rva + i * 12
        stream_type, data_size, rva = struct.unpack_from("<III", data, off)
        streams.append((stream_type, data_size, rva))

    STREAM_NAMES = {3: "ThreadList", 4: "ModuleList", 6: "Exception", 7: "SystemInfo", 9: "MiscInfo"}
    exception_stream = None
    module_list_stream = None
    for stream_type, data_size, rva in streams:
        if stream_type == 6:
            exception_stream = (data_size, rva)
        elif stream_type == 4:
            module_list_stream = (data_size, rva)

    if exception_stream is None:
        print("No exception stream found in this dump.")
        return

    _, rva = exception_stream
    # MINIDUMP_EXCEPTION_STREAM: ThreadId(4) + __align(4) + MINIDUMP_EXCEPTION + ThreadContext(loc desc 8)
    thread_id, _align = struct.unpack_from("<II", data, rva)
    exc_off = rva + 8
    exc_code, exc_flags, exc_record, exc_address, num_params, _align2 = struct.unpack_from("<IIQQII", data, exc_off)
    print(f"Crashing Thread ID: {thread_id}")
    print(f"Exception Code:     {exc_code:#x}")
    print(f"Exception Address:  {exc_address:#x}")

    EXCEPTION_NAMES = {
        0xC0000005: "EXCEPTION_ACCESS_VIOLATION",
        0xC0000094: "EXCEPTION_INT_DIVIDE_BY_ZERO",
        0xC00000FD: "EXCEPTION_STACK_OVERFLOW",
        0x80000003: "EXCEPTION_BREAKPOINT",
        0xC0000409: "EXCEPTION_STACK_BUFFER_OVERRUN / FAST_FAIL",
        0xE06D7363: "MSVC C++ EXCEPTION (0xE06D7363, 'msc')",
    }
    print(f"Exception Name:     {EXCEPTION_NAMES.get(exc_code, '(unknown)')}")

    if module_list_stream is None:
        print("No module list stream found.")
        return

    _, mrva = module_list_stream
    (num_modules,) = struct.unpack_from("<I", data, mrva)
    mod_off = mrva + 4
    MODULE_SIZE = 108
    modules = []
    for i in range(num_modules):
        off = mod_off + i * MODULE_SIZE
        base_of_image, size_of_image, checksum2, timestamp2, name_rva = struct.unpack_from("<QIIII", data, off)
        (name_len,) = struct.unpack_from("<I", data, name_rva)
        name_bytes = data[name_rva + 4: name_rva + 4 + name_len]
        name = name_bytes.decode("utf-16le", errors="ignore")
        modules.append((base_of_image, size_of_image, name))

    modules.sort(key=lambda m: m[0])
    print(f"\n{num_modules} modules loaded. Locating faulting address {exc_address:#x}...")
    found = False
    for base, size, name in modules:
        if base <= exc_address < base + size:
            offset = exc_address - base
            print(f"\n*** CRASH IN MODULE: {name}")
            print(f"    Base: {base:#x}  Size: {size:#x}  Offset into module: {offset:#x}")
            found = True
            break
    if not found:
        print("Faulting address did not fall inside any loaded module's range (JIT'd/dynamic code, or bad address).")

if __name__ == "__main__":
    parse(sys.argv[1])
