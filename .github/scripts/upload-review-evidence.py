#!/usr/bin/env python3
import argparse
from datetime import datetime
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import time


def upload(client, resource_type, relationship, parent_type, parent_id, path, existing=None):
    data = path.read_bytes()
    if existing:
        attrs = existing["attributes"]
        if attrs.get("fileName") != path.name or attrs.get("fileSize") != len(data):
            raise RuntimeError("Existing review image differs from the selected capture; unlock replacement in App Store Connect first.")
        reservation = {"data": existing}
        if attrs.get("assetDeliveryState", {}).get("state") == "COMPLETE":
            print(f"Review asset already complete: {path.name}")
            return
    else:
        reservation = client.request("POST", f"/v1/{resource_type}", {
            "data": {
                "type": resource_type,
                "attributes": {"fileName": path.name, "fileSize": len(data)},
                "relationships": {relationship: {"data": {"type": parent_type, "id": parent_id}}},
            }
        }, expected=(201,))
    module.upload_image_bytes(reservation, data)
    asset_id = reservation["data"]["id"]
    client.request("PATCH", f"/v1/{resource_type}/{asset_id}", {
        "data": {
            "type": resource_type,
            "id": asset_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
        }
    })
    for _ in range(20):
        asset = client.request("GET", f"/v1/{resource_type}/{asset_id}")["data"]
        delivery = asset["attributes"].get("assetDeliveryState", {})
        if delivery.get("state") == "COMPLETE":
            print(f"Review asset complete: {path.name}")
            return
        if delivery.get("errors") or delivery.get("state") == "FAILED":
            raise RuntimeError(f"Review asset rejected: {delivery}")
        time.sleep(3)
    raise RuntimeError("Review asset processing has not completed; inspect before submitting.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--folder", type=Path, required=True)
    parser.add_argument("--version-id", required=True)
    parser.add_argument("--subscription-id", required=True)
    parser.add_argument("--assets", choices=("screenshot", "recording", "both"), default="both")
    args = parser.parse_args()
    token = subprocess.check_output(["bash", ".github/scripts/app-store-connect-jwt.sh"], text=True).strip()
    client = module.AppStoreConnectClient(token)
    version = client.request("GET", f"/v1/appStoreVersions/{args.version_id}")["data"]
    if version["attributes"]["platform"] != "IOS":
        raise RuntimeError("Review evidence upload is restricted to the iOS release.")
    folder = args.folder / "attachments"
    manifest = json.loads((folder / "manifest.json").read_text())
    captures = [attachment for test in manifest for attachment in test["attachments"]]
    if args.assets != "recording":
        screenshot = next(a for a in captures if a["suggestedHumanReadableName"].startswith("premium-pass-live-storekit-test"))
        existing = client.request("GET", f"/v1/subscriptions/{args.subscription_id}/appStoreReviewScreenshot").get("data")
        upload(client, "subscriptionAppStoreReviewScreenshots", "subscription", "subscriptions", args.subscription_id,
               folder / screenshot["exportedFileName"], existing)
    if args.assets == "screenshot":
        return
    detail = client.request("GET", f"/v1/appStoreVersions/{args.version_id}/appStoreReviewDetail")["data"]
    for test in manifest:
        if "testLegalLinksOpenTheirDestinations" not in test["testIdentifier"]:
            continue
        records = [a for a in test["attachments"] if a["exportedFileName"].endswith(".mp4")]
        if records:
            video = folder / records[0]["exportedFileName"]
        else:
            images = {a["suggestedHumanReadableName"].split("_0_")[0]: a for a in test["attachments"] if a["exportedFileName"].endswith(".png")}
            names = ("legal-links-from-settings", "privacy-policy-opened-in-browser", "apple-eula-opened-in-browser")
            if not all(name in images for name in names):
                raise RuntimeError("Recording requires captures of Settings and both verified legal pages.")
            source = args.folder / "review.mp4"
            metadata = json.loads(subprocess.check_output(["ffprobe", "-v", "quiet", "-show_format", "-of", "json", str(source)], text=True))
            created = datetime.fromisoformat(metadata["format"]["tags"]["creation_time"]).timestamp()
            start = max(0, images[names[0]]["timestamp"] - created - 8)
            duration = images[names[-1]]["timestamp"] - created + 8 - start
            video = args.folder / "Nightfall-Protocol-verified-legal-links.mp4"
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(start), "-i", str(source), "-t", str(duration),
                            "-c:v", "libx264", "-preset", "veryfast", "-crf", "24", "-pix_fmt", "yuv420p", "-an", str(video)], check=True)
        upload(client, "appStoreReviewAttachments", "appStoreReviewDetail", "appStoreReviewDetails", detail["id"],
               video)
        break
    else:
        raise RuntimeError("No legal-link test recording found in the evidence artifact.")


spec = importlib.util.spec_from_file_location("asc_upload", Path(__file__).with_name("upload-iap-promotional-image.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

if __name__ == "__main__":
    main()
