#!/usr/bin/env python3
"""Writes the DEFLATE streams and ZIP archives in Fixtures/archives that the reader tests use.

The tests check the Swift decoder against zlib, the reference implementation: each stream here is
zlib's output for a known input, with every block type DEFLATE has (stored, fixed Huffman,
dynamic Huffman). Run it again only to add a case; the outputs are committed.

    python3 Fixtures/scripts/make-archive-fixtures.py
"""

import json
import os
import random
import stat
import zipfile
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "archives")


def words(seed, count):
    """Repetitive English-like text: compresses well and produces long back-references."""
    rng = random.Random(seed)
    vocabulary = "size ledger frame work asset catalog binary slice segment locale bundle app clip install archive estimate".split()
    return " ".join(rng.choice(vocabulary) for _ in range(count)).encode()


def noise(seed, count):
    """Incompressible bytes: zlib falls back to stored blocks."""
    rng = random.Random(seed)
    return bytes(rng.getrandbits(8) for _ in range(count))


def raw_deflate(data, level=9, strategy=zlib.Z_DEFAULT_STRATEGY):
    compressor = zlib.compressobj(level, zlib.DEFLATED, -15, 9, strategy)
    return compressor.compress(data) + compressor.flush()


def main():
    os.makedirs(ROOT, exist_ok=True)
    text = words(1, 60_000)
    binary = noise(2, 70_000)
    mixed = text[:20_000] + binary[:20_000] + text[20_000:40_000]
    cases = {
        # Level 0 writes only stored blocks (several, since one holds at most 65,535 bytes).
        "stored": (binary, raw_deflate(binary, level=0)),
        # Z_FIXED forces the fixed Huffman code of block type 1.
        "fixed": (text[:30_000], raw_deflate(text[:30_000], strategy=zlib.Z_FIXED)),
        "dynamic": (text, raw_deflate(text)),
        # Text, noise and text again: dynamic and stored blocks in one stream.
        "mixed": (mixed, raw_deflate(mixed, level=6)),
        "empty": (b"", raw_deflate(b"")),
    }
    manifest = {}
    for name, (original, stream) in sorted(cases.items()):
        with open(os.path.join(ROOT, f"{name}.deflate"), "wb") as handle:
            handle.write(stream)
        manifest[name] = {
            "size": len(original),
            "crc32": zlib.crc32(original),
        }
    with open(os.path.join(ROOT, "deflate-manifest.json"), "w") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")

    # A small archive with a deflated file, a stored file, a directory and a symbolic link, the
    # entry kinds an .ipa contains. Timestamps are fixed so the file is the same on every run.
    stamp = (2026, 10, 15, 12, 0, 0)
    with zipfile.ZipFile(os.path.join(ROOT, "kinds.zip"), "w") as archive:

        def add(name, data, mode, compress):
            info = zipfile.ZipInfo(name, date_time=stamp)
            info.create_system = 3
            info.external_attr = mode << 16
            info.compress_type = (
                zipfile.ZIP_DEFLATED if compress else zipfile.ZIP_STORED
            )
            archive.writestr(info, data)

        add("Payload/", b"", stat.S_IFDIR | 0o755, False)
        add("Payload/Text.txt", text[:5_000], stat.S_IFREG | 0o644, True)
        add("Payload/Noise.bin", binary[:3_000], stat.S_IFREG | 0o644, False)
        add("Payload/Link", b"Text.txt", stat.S_IFLNK | 0o777, False)


if __name__ == "__main__":
    main()
