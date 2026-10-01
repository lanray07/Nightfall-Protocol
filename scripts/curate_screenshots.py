#!/usr/bin/env python3
"""Package verified captures for upload, excluding unfinished-feature previews."""

import argparse
from pathlib import Path
import shutil

from localize import ROOT, read_json, save_json
from validate_screenshots import PREVIEW_ONLY_SCENES, validate_screenshots


def curate(listing, source, output):
    source, output = source.resolve(), output.resolve()
    if output.exists() or source == output or source in output.parents:
        raise ValueError("Use a fresh output directory outside the source export")
    validate_screenshots(listing, source)
    manifest = read_json(source / "capture-manifest.json")
    source_scenes = manifest.get("scenes", [scene["id"] for scene in listing["scenes"]])
    scenes = [scene for scene in source_scenes if scene not in PREVIEW_ONLY_SCENES]
    if not scenes:
        raise ValueError("No uploadable screenshot scenes remain")
    selected = {code + "/" + device + "-" + scene + ".png"
                for code in manifest["locales"] for device in manifest["devices"] for scene in scenes}
    files = [name for name in manifest["screenshots"] if name in selected]
    for name in files:
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / name, target)
    manifest["scenes"] = scenes
    manifest["screenshots"] = files
    manifest["excluded_preview_scenes"] = sorted(PREVIEW_ONLY_SCENES.intersection(source_scenes))
    save_json(output / "capture-manifest.json", manifest)
    validate_screenshots(listing, output, store_ready=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    curate(read_json(ROOT / "fastlane/localization/listing.json"), args.input, args.output)
