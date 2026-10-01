#!/usr/bin/env python3
"""Report release readiness without exporting credentials or review contact details."""
import json
import os
import runpy
from pathlib import Path


def main() -> None:
    submit = runpy.run_path(str(Path(__file__).with_name("submit-app-review.py")))
    client = submit["AppStoreConnectClient"](submit["generate_jwt"]())
    app_id = os.environ.get("APP_STORE_APP_ID", "6772583753")
    report = {"app_id": app_id, "versions": [], "subscriptions": [], "in_app_purchases": [], "errors": []}

    def get(path):
        try:
            return client.request("GET", path).get("data")
        except submit["AppStoreConnectError"] as error:
            report["errors"].append({"path": path, "error": str(error)})
            return None

    app = get(f"/v1/apps/{app_id}")
    if app:
        attrs = app.get("attributes", {})
        report["app"] = {key: attrs.get(key) for key in ("name", "bundleId", "primaryLocale")}
    for version in get(f"/v1/apps/{app_id}/appStoreVersions?limit=200&include=build") or []:
        attrs = version.get("attributes", {})
        entry = {"id": version["id"], **{key: attrs.get(key) for key in ("platform", "versionString", "appStoreState", "appVersionState")}}
        entry["build"] = version.get("relationships", {}).get("build", {}).get("data")
        if attrs.get("platform") == "IOS":
            review = get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")
            review_attrs = (review or {}).get("attributes", {})
            entry["review_contact_complete"] = all(review_attrs.get(key) for key in ("contactFirstName", "contactLastName", "contactEmail", "contactPhone"))
            entry["review_notes_present"] = bool(review_attrs.get("notes"))
            entry["localizations"] = [
                {"locale": item["attributes"].get("locale"), "description_present": bool(item["attributes"].get("description")), "support_url": item["attributes"].get("supportUrl")}
                for item in get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations") or []
            ]
        report["versions"].append(entry)

    groups = get(f"/v1/apps/{app_id}/subscriptionGroups?limit=200") or []
    report["subscription_groups"] = []
    for group in groups:
        group_entry = {"id": group["id"], "attributes": group.get("attributes", {}), "versions": get(f"/v1/subscriptionGroups/{group['id']}/versions?limit=200"), "localizations": get(f"/v1/subscriptionGroups/{group['id']}/subscriptionGroupLocalizations?limit=200")}
        report["subscription_groups"].append(group_entry)
        for item in get(f"/v1/subscriptionGroups/{group['id']}/subscriptions?limit=200") or []:
            attrs = item.get("attributes", {})
            entry = {"id": item["id"], "group_id": group["id"], **{key: attrs.get(key) for key in ("name", "productId", "state", "subscriptionPeriod")}}
            entry["localizations"] = [i.get("attributes", {}) for i in get(f"/v1/subscriptions/{item['id']}/subscriptionLocalizations") or []]
            screenshot = get(f"/v1/subscriptions/{item['id']}/appStoreReviewScreenshot")
            entry["review_screenshot"] = (screenshot or {}).get("attributes", {}).get("assetDeliveryState")
            entry["promotional_images"] = get(f"/v1/subscriptions/{item['id']}/images?limit=200")
            entry["versions"] = get(f"/v1/subscriptions/{item['id']}/versions?limit=200")
            for version in entry["versions"] or []:
                version["localizations"] = get(f"/v1/subscriptionVersions/{version['id']}/localizations?limit=200")
                version["images"] = get(f"/v1/subscriptionVersions/{version['id']}/images?limit=200")
            report["subscriptions"].append(entry)
    for item in get(f"/v1/apps/{app_id}/inAppPurchasesV2?limit=200") or []:
        attrs = item.get("attributes", {})
        report["in_app_purchases"].append({"id": item["id"], **{key: attrs.get(key) for key in ("name", "productId", "state", "inAppPurchaseType")}})
    certificates = get("/v1/certificates?limit=200&fields[certificates]=certificateType,expirationDate,displayName") or []
    report["certificates"] = [{"id": item["id"], **item.get("attributes", {})} for item in certificates]
    report["review_submissions"] = [
        {"id": item["id"], **{key: item.get("attributes", {}).get(key) for key in ("platform", "state", "submittedDate")}}
        for item in get(f"/v1/apps/{app_id}/reviewSubmissions?limit=200") or []
    ]
    for submission in report["review_submissions"]:
        if submission["platform"] == "IOS":
            submission["items"] = get(f"/v1/reviewSubmissions/{submission['id']}/items?limit=200")
    report["builds"] = [{"id": item["id"], **{key: item.get("attributes", {}).get(key) for key in ("version", "processingState", "expired", "uploadedDate")}} for item in get(f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10") or []]
    destination = Path("build/logs/app-store-audit.json")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(destination.read_text(encoding="utf-8"))
    if app is None:
        raise SystemExit("App Store Connect credentials could not read the app. See audit errors.")


if __name__ == "__main__":
    main()
