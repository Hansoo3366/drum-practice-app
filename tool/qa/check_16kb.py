"""Says whether the native libraries of an APK can run with 16 KB pages.

  check_16kb.py APK [ABI]

For every lib/<abi>/*.so: the smallest alignment of its LOAD segments (must
be 16384 or more) and, for a library stored uncompressed, whether it starts
on a 16 KB boundary in the APK. Exit code 1 when something does not fit.
Without ABI only the 64-bit ones are checked: 32-bit devices have 4 KB pages.
"""
import struct
import sys
import zipfile

PAGE = 16384


def load_alignment(data):
    """Smallest p_align of the PT_LOAD segments of an ELF file, or None."""
    if data[:4] != b"\x7fELF":
        return None
    wide = data[4] == 2
    order = "<" if data[5] == 1 else ">"
    if wide:
        offset, = struct.unpack_from(order + "Q", data, 0x20)
        size, count = struct.unpack_from(order + "HH", data, 0x36)
    else:
        offset, = struct.unpack_from(order + "I", data, 0x1C)
        size, count = struct.unpack_from(order + "HH", data, 0x2A)
    smallest = None
    for index in range(count):
        at = offset + index * size
        kind, = struct.unpack_from(order + "I", data, at)
        if kind != 1:
            continue
        align, = struct.unpack_from(order + ("Q" if wide else "I"), data, at + (0x30 if wide else 0x1C))
        smallest = align if smallest is None else min(smallest, align)
    return smallest


def main():
    apk = zipfile.ZipFile(sys.argv[1])
    only = sys.argv[2] if len(sys.argv) > 2 else None
    raw = open(sys.argv[1], "rb")
    bad = 0
    for info in sorted(apk.infolist(), key=lambda item: item.filename):
        name = info.filename
        if not (name.startswith("lib/") and name.endswith(".so")):
            continue
        abi = name.split("/")[1]
        if abi != only if only else abi not in ("arm64-v8a", "x86_64", "riscv64"):
            continue
        align = load_alignment(apk.read(name))
        notes = []
        if align is None or align < PAGE:
            notes.append(f"LOAD align {align}")
        if info.compress_type == zipfile.ZIP_STORED:
            raw.seek(info.header_offset + 26)
            name_length, extra_length = struct.unpack("<HH", raw.read(4))
            start = info.header_offset + 30 + name_length + extra_length
            if start % PAGE:
                notes.append(f"starts at {start} (not on a 16 KB boundary)")
        else:
            notes.append("compressed")
        if any(not note == "compressed" for note in notes):
            bad += 1
        print(("BAD " if any(note != "compressed" for note in notes) else "ok  ") + name
              + ("  " + "; ".join(notes) if notes else ""))
    print(f"{bad} librar{'y' if bad == 1 else 'ies'} not ready for 16 KB pages")
    sys.exit(1 if bad else 0)


main()
