#!/usr/bin/env python3
"""Capture eight captioned app screens per locale and device on a Mac simulator."""

import argparse
import json
import os
from pathlib import Path
import platform
import shlex
import signal
import subprocess
import time

from localize import ROOT, coverage, digest, read_json, save_json, validate_listing
from validate_screenshots import validate_screenshots

BUNDLE_ID = "com.nightfallprotocol.prototype"


def run(*args, env=None, check=True, timeout=120):
    command = shlex.join(args)
    print("Running: " + command, flush=True)
    started = time.monotonic()
    with subprocess.Popen(args, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          start_new_session=os.name == "posix") as process:
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            if os.name == "posix":
                os.killpg(process.pid, signal.SIGKILL)
            else:
                process.kill()
            stdout, stderr = process.communicate()
            message = "%s timed out after %ss:\n%s\n%s" % (command, timeout, stdout[-3000:], stderr[-3000:])
            if check:
                raise RuntimeError(message) from None
            print(message, flush=True)
            return ""
        if check and process.returncode:
            raise RuntimeError("%s failed:\n%s\n%s" % (command, stdout[-3000:], stderr[-3000:]))
    print("Finished in %.1fs" % (time.monotonic() - started), flush=True)
    return stdout.strip()


def wait_for_screen(marker, route, language):
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        if marker.exists():
            state = read_json(marker)
            if state["status"] != "ready":
                raise RuntimeError("The app could not prepare screenshot scene " + route)
            if state["scene"] == route and state["language"] == language:
                return
        time.sleep(0.5)
    raise RuntimeError("The app did not finish preparing screenshot scene " + route)


def capture(listing, codes, devices, output, derived):
    device_types = json.loads(run("xcrun", "simctl", "list", "devicetypes", "--json"))["devicetypes"]
    runtimes = json.loads(run("xcrun", "simctl", "list", "runtimes", "--json"))["runtimes"]
    available = [runtime for runtime in runtimes if runtime.get("isAvailable") and ".iOS-" in runtime["identifier"]]
    if not available:
        raise RuntimeError("Install an iOS simulator runtime in Xcode")
    # Use the same runtime as the release UI checks when installed. Newer
    # runner runtimes can spend several minutes in initial data migration.
    preferred = [item for item in available if item["version"] == "26.1"]
    runtime = max(preferred or available, key=lambda item: tuple(int(part) for part in item["version"].split(".")))
    run("xcodebuild", "-project", str(ROOT / "NightfallProtocol.xcodeproj"), "-scheme", "NightfallProtocol",
        "-configuration", "Debug", "-sdk", "iphonesimulator", "-destination", "generic/platform=iOS Simulator",
        "-derivedDataPath", str(derived), "CODE_SIGNING_ALLOWED=NO", "build", timeout=900)
    app = derived / "Build/Products/Debug-iphonesimulator/NightfallProtocol.app"
    manifest = {"listing_hash": digest(json.dumps(listing, ensure_ascii=False, sort_keys=True)), "locales": codes,
                "devices": devices, "screenshots": [], "source": "iOS simulator; actual SwiftUI and SpriteKit views"}
    for device_name in devices:
        device = listing["devices"][device_name]
        device_type = next((entry for entry in device_types if entry["name"] == device["simulator"]), None)
        if device_type is None:
            raise RuntimeError("Simulator device type is missing: " + device["simulator"])
        simulator = run("xcrun", "simctl", "create", "Nightfall Screenshot " + device_name,
                        device_type["identifier"], runtime["identifier"])
        try:
            run("xcrun", "simctl", "boot", simulator)
            run("xcrun", "simctl", "bootstatus", simulator, "-b", timeout=600)
            run("xcrun", "simctl", "ui", simulator, "appearance", "dark")
            run("xcrun", "simctl", "status_bar", simulator, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100")
            run("xcrun", "simctl", "install", simulator, str(app))
            container = Path(run("xcrun", "simctl", "get_app_container", simulator, BUNDLE_ID, "data"))
            marker = container / "Documents/screenshot-ready.json"
            for code in codes:
                locale = listing["locales"][code]
                for scene, caption in zip(listing["scenes"], locale["captions"]):
                    run("xcrun", "simctl", "terminate", simulator, BUNDLE_ID, check=False)
                    marker.unlink(missing_ok=True)
                    env = dict(os.environ)
                    env.update({"SIMCTL_CHILD_NF_SCREENSHOT_SCENE": scene["route"],
                                "SIMCTL_CHILD_NF_SCREENSHOT_LANGUAGE": locale["language"],
                                "SIMCTL_CHILD_NF_SCREENSHOT_HEADLINE": caption[0],
                                "SIMCTL_CHILD_NF_SCREENSHOT_SUBTITLE": caption[1]})
                    run("xcrun", "simctl", "launch", simulator, BUNDLE_ID, env=env)
                    wait_for_screen(marker, scene["route"], locale["language"])
                    time.sleep(scene["wait_seconds"])
                    path = output / code / (device_name + "-" + scene["id"] + ".png")
                    path.parent.mkdir(parents=True, exist_ok=True)
                    run("xcrun", "simctl", "io", simulator, "screenshot", "--type=png", str(path))
                    manifest["screenshots"].append(str(path.relative_to(output)).replace("\\", "/"))
                    print("Captured " + str(path.relative_to(output)), flush=True)
        finally:
            run("xcrun", "simctl", "shutdown", simulator, check=False, timeout=30)
            run("xcrun", "simctl", "delete", simulator, check=False, timeout=30)
    save_json(output / "capture-manifest.json", manifest)
    validate_screenshots(listing, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locales", default="en-GB", help="Comma-separated locales; app strings must be translated first")
    parser.add_argument("--output", type=Path, default=ROOT / "fastlane/screenshots")
    parser.add_argument("--derived-data", type=Path, default=ROOT / "build/ScreenshotDerivedData")
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("Screenshot capture requires macOS and Xcode. Use the App Store Screenshots GitHub Actions workflow.")
    listing = read_json(ROOT / "fastlane/localization/listing.json")
    validate_listing(listing)
    codes = args.locales.split(",")
    devices = list(listing["devices"])
    if any(code not in listing["locales"] for code in codes):
        parser.error("Unknown locale")
    if args.output.exists() and list(args.output.rglob("*.png")):
        parser.error("Use a fresh output directory to avoid mixing screenshot exports")
    catalog = read_json(ROOT / "NightfallProtocol/Resources/Localizable.xcstrings")
    counts = coverage(catalog, {code: listing["locales"][code] for code in codes})
    incomplete = [code for code, count in counts.items() if count["missing"]]
    if incomplete:
        parser.error("Translate the app before capture for " + ",".join(incomplete) + ": python scripts/localize.py --translate --locales " + ",".join(incomplete))
    capture(listing, codes, devices, args.output.resolve(), args.derived_data.resolve())


if __name__ == "__main__":
    main()
