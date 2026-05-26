#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


API_BASE = "https://api.appstoreconnect.apple.com"
SUBMITTED_STATES = {
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "PENDING_APPLE_RELEASE",
    "PENDING_DEVELOPER_RELEASE",
    "PROCESSING_FOR_APP_STORE",
    "READY_FOR_SALE",
}
KNOWN_REVIEW_SUBMISSIONS = {
    "TV_OS": "49ef16d4-7044-443b-abe7-e3fe55054b2b",
    "VISION_OS": "9b1b9d48-4705-41c8-975b-6a3495f3bf97",
}


class AppStoreConnectError(RuntimeError):
    def __init__(self, message: str, status: int | None = None) -> None:
        super().__init__(message)
        self.status = status


class AppStoreConnectClient:
    def __init__(self, jwt: str) -> None:
        self.jwt = jwt

    def request(
        self,
        method: str,
        path: str,
        body: dict[str, Any] | None = None,
        expected: tuple[int, ...] = (200,),
    ) -> dict[str, Any]:
        url = f"{API_BASE}{path}"
        data = None
        headers = {"Authorization": f"Bearer {self.jwt}"}
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"

        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                payload = response.read().decode("utf-8")
                status = response.status
        except urllib.error.HTTPError as error:
            details = error.read().decode("utf-8", errors="replace")
            raise AppStoreConnectError(
                f"{method} {url} failed ({error.code}): {details}", error.code
            ) from error

        if status not in expected:
            raise AppStoreConnectError(f"{method} {url} returned {status}: {payload}", status)
        return json.loads(payload) if payload else {}


def main() -> int:
    parser = argparse.ArgumentParser(description="Attach App Store builds and submit app versions for review.")
    parser.add_argument("--app-id", default=os.environ.get("APP_STORE_APP_ID", "6772583753"))
    parser.add_argument("--version", default="1.0")
    parser.add_argument("--build-number", required=True)
    parser.add_argument(
        "--platforms",
        default="IOS,TV_OS,VISION_OS,MAC_OS",
        help="Comma-separated App Store Connect platforms.",
    )
    args = parser.parse_args()

    jwt = subprocess.check_output(["bash", ".github/scripts/app-store-connect-jwt.sh"], text=True).strip()
    client = AppStoreConnectClient(jwt)
    platforms = [platform.strip() for platform in args.platforms.split(",") if platform.strip()]

    print(f"Preparing app {args.app_id} version {args.version} build {args.build_number}.")
    versions = find_app_store_versions(client, args.app_id, args.version)
    builds = find_builds(client, args.app_id, args.version, args.build_number)
    had_failure = False

    for platform in platforms:
        print(f"\n== {platform} ==")
        version = versions.get(platform)
        if version is None:
            print(f"Skipping {platform}: no App Store version {args.version} exists.")
            continue

        state = version.get("attributes", {}).get("appStoreState") or version.get("attributes", {}).get("appVersionState")
        print(f"Version id: {version['id']} state: {state}")
        if state in SUBMITTED_STATES:
            print(f"Skipping {platform}: version is already submitted or beyond review queue.")
            continue

        build = builds.get(platform)
        if build is None:
            print(f"ERROR: no valid build {args.build_number} found for {platform}.")
            print_build_candidates(builds)
            had_failure = True
            continue

        try:
            attach_build(client, version["id"], build["id"])
            print(f"Attached build {args.build_number} ({build['id']}) to {platform}.")
            print("Waiting for App Store Connect to make the version reviewable.")
            time.sleep(60)
            submission_id = find_review_submission_for_version(
                client, args.app_id, platform, version["id"]
            )
            if submission_id:
                print(f"Reusing existing review submission {submission_id} for {platform}.")
            else:
                submission = create_review_submission(client, args.app_id, platform)
                submission_id = submission["id"]
                print(f"Created review submission {submission_id} for {platform}.")
                try:
                    create_review_submission_item(client, submission_id, version["id"])
                    print(f"Added App Store version {version['id']} to review submission.")
                except AppStoreConnectError as error:
                    existing_id = extract_existing_submission_id(str(error))
                    if not existing_id:
                        raise
                    submission_id = existing_id
                    print(f"App Store version is already in review submission {submission_id}.")

            submit_review_submission(client, submission_id, version["id"])
            print(f"Submitted {platform} {args.version} build {args.build_number} for review.")
        except AppStoreConnectError as error:
            had_failure = True
            print(f"ERROR: {error}")

    return 1 if had_failure else 0


def find_app_store_versions(
    client: AppStoreConnectClient, app_id: str, version_string: str
) -> dict[str, dict[str, Any]]:
    query = urllib.parse.urlencode(
        {
            "limit": "200",
            "include": "build",
            "fields[appStoreVersions]": "platform,versionString,appStoreState,appVersionState,build",
        }
    )
    payload = client.request("GET", f"/v1/apps/{app_id}/appStoreVersions?{query}")
    versions: dict[str, dict[str, Any]] = {}
    for item in payload.get("data", []):
        attributes = item.get("attributes", {})
        if attributes.get("versionString") != version_string:
            continue
        platform = attributes.get("platform")
        if platform:
            versions[platform] = item
            print(f"Found {platform} App Store version {item['id']}.")
    return versions


def find_builds(
    client: AppStoreConnectClient, app_id: str, version_string: str, build_number: str
) -> dict[str, dict[str, Any]]:
    query = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "filter[version]": build_number,
            "filter[processingState]": "VALID",
            "include": "preReleaseVersion",
            "fields[builds]": "version,processingState,uploadedDate,expired,preReleaseVersion",
            "fields[preReleaseVersions]": "version,platform",
            "limit": "200",
        }
    )
    try:
        payload = client.request("GET", f"/v1/builds?{query}")
    except AppStoreConnectError as error:
        if error.status != 400:
            raise
        fallback = urllib.parse.urlencode(
            {
                "filter[app]": app_id,
                "include": "preReleaseVersion",
                "fields[builds]": "version,processingState,uploadedDate,expired,preReleaseVersion",
                "fields[preReleaseVersions]": "version,platform",
                "limit": "200",
            }
        )
        payload = client.request("GET", f"/v1/builds?{fallback}")

    prereleases = {
        item["id"]: item
        for item in payload.get("included", [])
        if item.get("type") == "preReleaseVersions"
    }

    builds: dict[str, dict[str, Any]] = {}
    for item in payload.get("data", []):
        attributes = item.get("attributes", {})
        if attributes.get("version") != build_number:
            continue
        if attributes.get("processingState") != "VALID" or attributes.get("expired") is True:
            continue

        prerelease_id = (
            item.get("relationships", {})
            .get("preReleaseVersion", {})
            .get("data", {})
            .get("id")
        )
        prerelease = prereleases.get(prerelease_id or "")
        prerelease_attributes = prerelease.get("attributes", {}) if prerelease else {}
        if prerelease_attributes.get("version") != version_string:
            continue

        platform = prerelease_attributes.get("platform")
        if not platform:
            continue
        previous = builds.get(platform)
        if previous is None or (attributes.get("uploadedDate") or "") > (
            previous.get("attributes", {}).get("uploadedDate") or ""
        ):
            builds[platform] = item
            print(f"Found {platform} build {build_number} ({item['id']}).")
    return builds


def print_build_candidates(builds: dict[str, dict[str, Any]]) -> None:
    if not builds:
        print("No matching build candidates were found.")
        return
    for platform, build in builds.items():
        print(f"Candidate {platform}: {build['id']}")


def attach_build(client: AppStoreConnectClient, version_id: str, build_id: str) -> None:
    current_build_id = get_attached_build_id(client, version_id)
    if current_build_id == build_id:
        print(f"Build {build_id} is already attached.")
        return

    body = {"data": {"type": "builds", "id": build_id}}
    retry_request(
        lambda: client.request(
            "PATCH",
            f"/v1/appStoreVersions/{version_id}/relationships/build",
            body,
            expected=(200, 204),
        ),
        "Attach build",
    )


def get_attached_build_id(client: AppStoreConnectClient, version_id: str) -> str | None:
    payload = client.request(
        "GET",
        f"/v1/appStoreVersions/{version_id}/relationships/build",
        expected=(200,),
    )
    data = payload.get("data")
    return data.get("id") if isinstance(data, dict) else None


def create_review_submission(
    client: AppStoreConnectClient, app_id: str, platform: str
) -> dict[str, Any]:
    body = {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": platform},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    try:
        payload = client.request("POST", "/v1/reviewSubmissions", body, expected=(201,))
    except AppStoreConnectError as error:
        if error.status != 400:
            raise
        body["data"].pop("attributes", None)
        payload = client.request("POST", "/v1/reviewSubmissions", body, expected=(201,))
    return payload["data"]


def find_review_submission_for_version(
    client: AppStoreConnectClient, app_id: str, platform: str, version_id: str
) -> str | None:
    for submission in list_review_submissions(client, app_id, platform):
        submission_id = submission["id"]
        if review_submission_contains_version(client, submission_id, version_id):
            return submission_id

    known_id = KNOWN_REVIEW_SUBMISSIONS.get(platform)
    if known_id:
        try:
            if review_submission_contains_version(client, known_id, version_id):
                return known_id
        except AppStoreConnectError as error:
            print(f"Known submission lookup for {platform} failed: {error}")
    return None


def list_review_submissions(
    client: AppStoreConnectClient, app_id: str, platform: str
) -> list[dict[str, Any]]:
    review_platform = "XROS" if platform == "VISION_OS" else platform
    queries = [
        urllib.parse.urlencode(
            {
                "filter[platform]": review_platform,
                "fields[reviewSubmissions]": "platform,state,submittedDate",
                "limit": "200",
            }
        ),
        urllib.parse.urlencode(
            {
                "fields[reviewSubmissions]": "platform,state,submittedDate",
                "limit": "200",
            }
        ),
    ]

    for query in queries:
        try:
            payload = client.request("GET", f"/v1/apps/{app_id}/reviewSubmissions?{query}")
            submissions = payload.get("data", [])
            if query == queries[0]:
                return submissions
            return [
                submission
                for submission in submissions
                if submission.get("attributes", {}).get("platform") in (platform, review_platform)
            ]
        except AppStoreConnectError as error:
            if error.status != 400:
                raise
    return []


def review_submission_contains_version(
    client: AppStoreConnectClient, submission_id: str, version_id: str
) -> bool:
    query = urllib.parse.urlencode(
        {
            "include": "appStoreVersion",
            "fields[reviewSubmissionItems]": "appStoreVersion",
            "fields[appStoreVersions]": "platform,versionString,appStoreState,appVersionState",
            "limit": "200",
        }
    )
    payload = client.request("GET", f"/v1/reviewSubmissions/{submission_id}/items?{query}")
    for item in payload.get("data", []):
        app_store_version = (
            item.get("relationships", {})
            .get("appStoreVersion", {})
            .get("data", {})
        )
        if app_store_version.get("id") == version_id:
            return True
    return False


def extract_existing_submission_id(message: str) -> str | None:
    match = re.search(r"reviewSubmission with id ([0-9a-fA-F-]{36})", message)
    return match.group(1) if match else None


def create_review_submission_item(
    client: AppStoreConnectClient, submission_id: str, version_id: str
) -> dict[str, Any]:
    body = {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {
                    "data": {"type": "reviewSubmissions", "id": submission_id}
                },
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                },
            },
        }
    }
    payload = client.request("POST", "/v1/reviewSubmissionItems", body, expected=(201,))
    return payload["data"]


def submit_review_submission(
    client: AppStoreConnectClient, submission_id: str, version_id: str
) -> None:
    body = {
        "data": {
            "type": "reviewSubmissions",
            "id": submission_id,
            "attributes": {"submitted": True},
        }
    }
    try:
        retry_request(
            lambda: client.request("PATCH", f"/v1/reviewSubmissions/{submission_id}", body),
            "Submit review submission",
            retry_on_not_ready=True,
        )
    except AppStoreConnectError as error:
        if "try again later" not in str(error).lower():
            raise
        print("Review submission API still reports not-ready; trying direct app version submission.")
        submit_app_store_version(client, version_id)
    time.sleep(2)


def submit_app_store_version(client: AppStoreConnectClient, version_id: str) -> None:
    body = {
        "data": {
            "type": "appStoreVersionSubmissions",
            "relationships": {
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                }
            },
        }
    }
    retry_request(
        lambda: client.request("POST", "/v1/appStoreVersionSubmissions", body, expected=(201,)),
        "Submit app store version",
        retry_on_not_ready=True,
    )


def retry_request(
    operation: Any,
    label: str,
    retry_on_not_ready: bool = False,
) -> dict[str, Any]:
    delays = [30, 60, 120]
    for attempt in range(len(delays) + 1):
        try:
            return operation()
        except AppStoreConnectError as error:
            message = str(error)
            is_retryable = error.status == 500 or (
                retry_on_not_ready and "try again later" in message.lower()
            )
            if not is_retryable or attempt == len(delays):
                raise
            delay = delays[attempt]
            print(f"{label} is not ready yet ({error.status}); retrying in {delay}s.")
            time.sleep(delay)
    raise RuntimeError(f"{label} retry loop exited unexpectedly.")


if __name__ == "__main__":
    raise SystemExit(main())
