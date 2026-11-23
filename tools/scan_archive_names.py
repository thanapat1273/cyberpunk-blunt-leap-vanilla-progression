"""Read-only: find game resources whose CR2W header names NPCIncapacitatedPrereq / PuppetIncapacitatedPrereq (2026-11-24 research for the unlootable-body fix).

usage: py -3.10 -I scan_prereq.py <oo2ext dll> <archive>...
For each file in each RDAR archive, decompresses only its first segment (the CR2W header with the
names table) with the game's own Oodle DLL and searches it for the class names. Prints hash, size and
which names it holds. Writes nothing.
"""
import ctypes
import struct
import sys

NAMES = [b"NPCIncapacitatedPrereq", b"PuppetIncapacitatedPrereq"]


def main(argv):
    dll = ctypes.WinDLL(argv[0])
    dec = dll.OodleLZ_Decompress
    dec.restype = ctypes.c_int64
    dec.argtypes = [ctypes.c_void_p, ctypes.c_int64, ctypes.c_void_p, ctypes.c_int64,
                    ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_int64,
                    ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64, ctypes.c_int]
    total_hits = 0
    for path in argv[1:]:
        with open(path, "rb") as f:
            head = f.read(40)
            if head[:4] != b"RDAR":
                print("skip (not RDAR):", path)
                continue
            index_pos = struct.unpack_from("<Q", head, 8)[0]
            f.seek(index_pos)
            _, _, _, n_files, n_segs, n_deps = struct.unpack("<IIQIII", f.read(28))
            entries = f.read(n_files * 56)
            segs = f.read(n_segs * 16)
            hits = 0
            for i in range(n_files):
                h, _ts, _ninline, s_start, s_end = struct.unpack_from("<QqIII", entries, i * 56)
                if s_start >= s_end:
                    continue
                off, zsize, size = struct.unpack_from("<QII", segs, s_start * 16)
                f.seek(off)
                data = f.read(zsize)
                if zsize != size and data[:4] == b"KARK":
                    raw_len = struct.unpack_from("<I", data, 4)[0]
                    out = ctypes.create_string_buffer(raw_len)
                    src = ctypes.create_string_buffer(data[8:], len(data) - 8)
                    n = dec(src, len(data) - 8, out, raw_len, 1, 0, 0, None, 0, None, None, None, 0, 3)
                    if n <= 0:
                        continue
                    raw = out.raw[:n]
                else:
                    raw = data
                found = [nm.decode() for nm in NAMES if nm in raw]
                if found:
                    hits += 1
                    print("%s | %016x | %d bytes | %s" % (path.split("\\")[-1].split("/")[-1], h, size, ", ".join(found)))
            print("== %s: %d files scanned, %d with the names" % (path.split("/")[-1], n_files, hits))
            total_hits += hits
    print("TOTAL", total_hits)


if __name__ == "__main__":
    main(sys.argv[1:])
