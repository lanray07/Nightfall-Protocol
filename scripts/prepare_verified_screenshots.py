"""Package unmodified XCTest captures from a verified release run for the store."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from localize import ROOT, digest, read_json, save_json
from validate_screenshots import validate_screenshots

CAPTURES = {
    "01-offline-survival-horror": "mission-start-real-gameplay",
    "02-nightmare-extraction-missions": "campaign-first-chapter-real-selection",
    "03-escape-reality-collapse": "memory-decoded-real-gameplay",
    "05-extraction-rewards-and-ranks": "mission-extracted-real-result",
    "08-play-in-your-language": "legal-links-from-settings",
}


def prepare(source, output, source_run):
    if output.exists():
        raise ValueError("Use a fresh output directory")
    listing = read_json(ROOT / "fastlane/localization/listing.json")
    manifest = {
        "listing_hash": digest(json.dumps(listing, ensure_ascii=False, sort_keys=True)),
        "locales": ["en-GB"], "devices": list(listing["devices"]),
        "scenes": list(CAPTURES), "screenshots": [],
        "source": "Unmodified XCTest simulator screenshots from real gameplay/legal-link checks",
        "source_evidence_run_id": source_run, "capture_provenance": {},
    }
    for family, device in (("iPhone", "iPhone-6.9"), ("iPad", "iPad-13")):
        folder = source / ("release-evidence-" + family)
        log = (folder / "tests.log").read_text(encoding="utf-8")
        for name in ("testPlayableMemoryMissionAndExtraction", "testLegalLinksOpenTheirDestinations"):
            if not any(name + "]' passed" in line for line in log.splitlines()):
                raise ValueError(f"Required {name} pass missing for {family}")
        tests = read_json(folder / "attachments/manifest.json")
        captures = [a for test in tests for a in test["attachments"]]
        for scene, capture in CAPTURES.items():
            found = [a for a in captures if a["suggestedHumanReadableName"].startswith(capture + "_0_")]
            if len(found) != 1 or found[0].get("isAssociatedWithFailure"):
                raise ValueError(f"Missing or ambiguous verified capture: {family}/{capture}")
            attachment = found[0]
            original = folder / "attachments" / attachment["exportedFileName"]
            relative = f"en-GB/{device}-{scene}.png"
            destination = output / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, destination)
            manifest["screenshots"].append(relative)
            manifest["capture_provenance"][relative] = {
                "original_file": attachment["exportedFileName"],
                "timestamp": attachment["timestamp"],
                "sha256": hashlib.sha256(original.read_bytes()).hexdigest(),
            }
    save_json(output / "capture-manifest.json", manifest)
    validate_screenshots(listing, output, store_ready=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-run", required=True)
    args = parser.parse_args()
    prepare(args.input, args.output, args.source_run)
