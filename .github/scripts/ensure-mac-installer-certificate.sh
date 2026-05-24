#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${BUILD_CERTIFICATE_PATH:-}" || -z "${P12_PASSWORD:-}" || -z "${KEYCHAIN_PATH:-}" ]]; then
  echo "BUILD_CERTIFICATE_PATH, P12_PASSWORD, and KEYCHAIN_PATH must be set." >&2
  exit 1
fi

work_dir="${RUNNER_TEMP:-/tmp}/nightfall-mac-installer"
private_key_path="${work_dir}/nightfall-signing.key"
csr_path="${work_dir}/nightfall-mac-installer.csr"
cert_path="${work_dir}/mac-installer.cer"
mkdir -p "$work_dir"

openssl pkcs12 \
  -in "$BUILD_CERTIFICATE_PATH" \
  -nocerts \
  -nodes \
  -passin "pass:${P12_PASSWORD}" \
  -out "$private_key_path"

openssl req \
  -new \
  -key "$private_key_path" \
  -subj "/CN=Nightfall Protocol Mac Installer/" \
  -out "$csr_path"

jwt="$(bash .github/scripts/app-store-connect-jwt.sh)"
list_url="https://api.appstoreconnect.apple.com/v1/certificates?filter[certificateType]=MAC_INSTALLER_DISTRIBUTION&fields[certificates]=certificateType,displayName,certificateContent,expirationDate"
response="$(curl -fsS -H "Authorization: Bearer ${jwt}" "$list_url")"
certificate_content="$(printf '%s' "$response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
items = payload.get("data", [])
print(items[0]["attributes"].get("certificateContent", "") if items else "")')"

if [[ -z "$certificate_content" ]]; then
  body="$(python3 - "$csr_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    csr = handle.read()

print(json.dumps({
    "data": {
        "type": "certificates",
        "attributes": {
            "certificateType": "MAC_INSTALLER_DISTRIBUTION",
            "csrContent": csr
        }
    }
}))
PY
)"
  response="$(curl -fsS \
    -X POST \
    -H "Authorization: Bearer ${jwt}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "https://api.appstoreconnect.apple.com/v1/certificates")"
  certificate_content="$(printf '%s' "$response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
print(payload["data"]["attributes"]["certificateContent"])')"
fi

printf '%s' "$certificate_content" | base64 --decode > "$cert_path"
security import "$cert_path" -A -t cert -k "$KEYCHAIN_PATH"

cert_name="$(openssl x509 -inform DER -in "$cert_path" -noout -subject -nameopt multiline | awk -F'= ' '/commonName/ { print $2; exit }')"
if [[ -z "$cert_name" ]]; then
  echo "Unable to resolve Mac installer certificate name." >&2
  exit 1
fi

echo "MAC_INSTALLER_CERT_NAME=${cert_name}" >> "$GITHUB_ENV"
echo "Prepared Mac installer certificate ${cert_name}."
