#!/usr/bin/env python3
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_BASE = "https://api.appstoreconnect.apple.com"


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: upload-iap-promotional-image.py <product-id> <image-path>", file=sys.stderr)
        return 2

    product_id = sys.argv[1]
    image_path = sys.argv[2]
    app_id = os.environ.get("APP_STORE_APP_ID")
    if not app_id:
        print("APP_STORE_APP_ID must be set.", file=sys.stderr)
        return 1

    with open(image_path, "rb") as handle:
        image_bytes = handle.read()

    jwt = subprocess.check_output(["bash", ".github/scripts/app-store-connect-jwt.sh"], text=True).strip()
    client = AppStoreConnectClient(jwt)

    iap = find_iap(client, app_id, product_id)
    replace_existing_images(client, iap["id"])
    image = create_image_reservation(client, iap["id"], os.path.basename(image_path), len(image_bytes))
    upload_image_bytes(image, image_bytes)
    commit_image(client, image["data"]["id"], image_bytes)
    print(f"Uploaded promoted IAP image for {product_id}.")
    return 0


class AppStoreConnectClient:
    def __init__(self, jwt: str) -> None:
        self.jwt = jwt

    def request(self, method: str, path: str, body: dict | None = None, expected: tuple[int, ...] = (200,)) -> dict:
        url = f"{API_BASE}{path}"
        data = None
        headers = {"Authorization": f"Bearer {self.jwt}"}
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"

        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = response.read().decode("utf-8")
                status = response.status
        except urllib.error.HTTPError as error:
            details = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"{method} {url} failed ({error.code}): {details}") from error

        if status not in expected:
            raise RuntimeError(f"{method} {url} returned unexpected status {status}: {payload}")
        return json.loads(payload) if payload else {}


def find_iap(client: AppStoreConnectClient, app_id: str, product_id: str) -> dict:
    query = urllib.parse.urlencode({
        "filter[productId]": product_id,
        "fields[inAppPurchases]": "productId,name,inAppPurchaseType,state",
        "limit": "1",
    })
    payload = client.request("GET", f"/v1/apps/{app_id}/inAppPurchasesV2?{query}")
    items = payload.get("data", [])
    if not items:
        available = list_iaps(client, app_id)
        raise RuntimeError(
            f"No in-app purchase found for product ID {product_id}. "
            f"Available product IDs: {', '.join(available) if available else 'none'}."
        )
    return items[0]


def list_iaps(client: AppStoreConnectClient, app_id: str) -> list[str]:
    query = urllib.parse.urlencode({
        "fields[inAppPurchases]": "productId,name,inAppPurchaseType,state",
        "limit": "200",
    })
    payload = client.request("GET", f"/v1/apps/{app_id}/inAppPurchasesV2?{query}")
    product_ids = []
    for item in payload.get("data", []):
        product_id = item.get("attributes", {}).get("productId")
        if product_id:
            product_ids.append(product_id)
    return product_ids


def replace_existing_images(client: AppStoreConnectClient, iap_id: str) -> None:
    payload = client.request(
        "GET",
        f"/v2/inAppPurchases/{iap_id}/images?limit=200&fields[inAppPurchaseImages]=fileName,state",
    )
    for item in payload.get("data", []):
        image_id = item["id"]
        client.request("DELETE", f"/v1/inAppPurchaseImages/{image_id}", expected=(204,))
        print(f"Deleted existing promoted IAP image {image_id}.")
        time.sleep(1)


def create_image_reservation(client: AppStoreConnectClient, iap_id: str, file_name: str, file_size: int) -> dict:
    body = {
        "data": {
            "type": "inAppPurchaseImages",
            "attributes": {
                "fileName": file_name,
                "fileSize": file_size,
            },
            "relationships": {
                "inAppPurchase": {
                    "data": {
                        "type": "inAppPurchases",
                        "id": iap_id,
                    }
                }
            },
        }
    }
    return client.request("POST", "/v1/inAppPurchaseImages", body, expected=(201,))


def upload_image_bytes(image: dict, image_bytes: bytes) -> None:
    operations = image["data"]["attributes"].get("uploadOperations", [])
    if not operations:
        raise RuntimeError("Image reservation did not include upload operations.")

    for operation in operations:
        method = operation["method"]
        url = operation["url"]
        offset = int(operation.get("offset", 0))
        length = int(operation.get("length", len(image_bytes) - offset))
        chunk = image_bytes[offset:offset + length]
        headers = {header["name"]: header["value"] for header in operation.get("requestHeaders", [])}

        request = urllib.request.Request(url, data=chunk, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                response.read()
        except urllib.error.HTTPError as error:
            details = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Uploading IAP image bytes failed ({error.code}): {details}") from error


def commit_image(client: AppStoreConnectClient, image_id: str, image_bytes: bytes) -> None:
    checksum = hashlib.md5(image_bytes).hexdigest()
    body = {
        "data": {
            "type": "inAppPurchaseImages",
            "id": image_id,
            "attributes": {
                "sourceFileChecksum": checksum,
                "uploaded": True,
            },
        }
    }
    client.request("PATCH", f"/v1/inAppPurchaseImages/{image_id}", body)


if __name__ == "__main__":
    raise SystemExit(main())
