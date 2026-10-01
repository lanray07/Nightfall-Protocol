#!/usr/bin/env python3
"""Verify complete, fresh, correctly sized simulator screenshot exports."""

import argparse
import json
from pathlib import Path
import struct
import zlib

from localize import ROOT, digest, read_json


def png_size(path):
    with path.open("rb") as handle:
        if handle.read(8) != b"\x89PNG\r\n\x1a\n":
            raise ValueError("Invalid PNG: " + str(path))
        size, pixels = None, False
        while True:
            header = handle.read(8)
            if len(header) != 8:
                raise ValueError("Incomplete PNG: " + str(path))
            length, kind = struct.unpack(">I4s", header)
            if length > 32 * 1024 * 1024:
                raise ValueError("Invalid PNG chunk: " + str(path))
            data, checksum = handle.read(length), handle.read(4)
            if len(data) != length or len(checksum) != 4 or struct.unpack(">I", checksum)[0] != zlib.crc32(kind + data):
                raise ValueError("Corrupt PNG: " + str(path))
            if kind == b"IHDR":
                if size is not None or length != 13:
                    raise ValueError("Invalid PNG header: " + str(path))
                size = struct.unpack(">II", data[:8])
            elif kind == b"IDAT":
                pixels = pixels or bool(data)
            elif kind == b"IEND":
                if size is None or not pixels or length != 0 or handle.read(1):
                    raise ValueError("Invalid PNG ending: " + str(path))
                return size


def validate_screenshots(listing, directory):
    manifest = read_json(directory / "capture-manifest.json")
    expected_hash = digest(json.dumps(listing, ensure_ascii=False, sort_keys=True))
    if manifest["listing_hash"] != expected_hash:
        raise ValueError("Screenshots are stale; recapture after changing listing copy or captions")
    if not manifest["locales"] or set(manifest["devices"]) != set(listing["devices"]):
        raise ValueError("Capture both required iPhone and iPad device sets")
    expected = set()
    for code in manifest["locales"]:
        if code not in listing["locales"]:
            raise ValueError("Unsupported screenshot locale " + code)
        for device, specification in listing["devices"].items():
            for scene in listing["scenes"]:
                name = code + "/" + device + "-" + scene["id"] + ".png"
                expected.add(name)
                path = directory / name
                if not path.exists():
                    raise ValueError("Missing screenshot " + name)
                if png_size(path) != (specification["width"], specification["height"]):
                    raise ValueError("Incorrect screenshot dimensions for " + name)
    actual = {str(path.relative_to(directory)).replace("\\", "/") for path in directory.rglob("*.png")}
    if actual != expected or set(manifest["screenshots"]) != expected:
        raise ValueError("Screenshot export contains missing, duplicate or unexpected files")
    print("Validated %d screenshots across %d locales" % (len(expected), len(manifest["locales"])))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=ROOT / "fastlane/screenshots")
    args = parser.parse_args()
    validate_screenshots(read_json(ROOT / "fastlane/localization/listing.json"), args.directory)
