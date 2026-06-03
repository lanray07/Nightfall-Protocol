#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${BUILD_CERTIFICATE_PATH:-}" || -z "${P12_PASSWORD:-}" || -z "${KEYCHAIN_PATH:-}" ]]; then
  echo "BUILD_CERTIFICATE_PATH, P12_PASSWORD, and KEYCHAIN_PATH must be set." >&2
  exit 1
fi

work_dir="${RUNNER_TEMP:-/tmp}/nightfall-mac-installer"
private_key_path="${work_dir}/nightfall-signing.key"
private_public_key_path="${work_dir}/nightfall-signing-public.pem"
csr_path="${work_dir}/nightfall-mac-installer.csr"
cert_path="${work_dir}/mac-installer.cer"
candidate_dir="${work_dir}/candidates"
mkdir -p "$work_dir"
mkdir -p "$candidate_dir"

openssl pkcs12 \
  -in "$BUILD_CERTIFICATE_PATH" \
  -nocerts \
  -nodes \
  -passin "pass:${P12_PASSWORD}" \
  -out "$private_key_path"

openssl pkey \
  -in "$private_key_path" \
  -pubout \
  -out "$private_public_key_path"

openssl req \
  -new \
  -key "$private_key_path" \
  -subj "/CN=Nightfall Protocol Mac Installer/" \
  -out "$csr_path"

jwt="$(bash .github/scripts/app-store-connect-jwt.sh)"
list_url="https://api.appstoreconnect.apple.com/v1/certificates?filter[certificateType]=MAC_INSTALLER_DISTRIBUTION&fields[certificates]=certificateType,displayName,certificateContent,expirationDate"
response="$(curl -fsS --globoff -H "Authorization: Bearer ${jwt}" "$list_url")"
CERTIFICATES_RESPONSE="$response" python3 - "$candidate_dir" <<'PY'
import base64
import json
import os
import sys

candidate_dir = sys.argv[1]
payload = json.loads(os.environ.get("CERTIFICATES_RESPONSE", "{}"))
for index, item in enumerate(payload.get("data", []), start=1):
    content = item.get("attributes", {}).get("certificateContent")
    if not content:
        continue
    path = os.path.join(candidate_dir, f"mac-installer-{index}.cer")
    with open(path, "wb") as handle:
        handle.write(base64.b64decode(content))
    print(path)
PY

matching_cert_path=""
while IFS= read -r candidate_path; do
  [[ -n "$candidate_path" ]] || continue
  candidate_public_key_path="${candidate_path}.pub.pem"
  if ! openssl x509 -inform DER -in "$candidate_path" -pubkey -noout > "$candidate_public_key_path"; then
    continue
  fi

  if cmp -s "$private_public_key_path" "$candidate_public_key_path"; then
    matching_cert_path="$candidate_path"
    break
  fi
done < <(find "$candidate_dir" -type f -name "mac-installer-*.cer" | sort)

if [[ -n "$matching_cert_path" ]]; then
  cp "$matching_cert_path" "$cert_path"
else
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
  response="$(curl -fsS --globoff \
    -X POST \
    -H "Authorization: Bearer ${jwt}" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "https://api.appstoreconnect.apple.com/v1/certificates")"
  certificate_content="$(printf '%s' "$response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
print(payload["data"]["attributes"]["certificateContent"])')"
  printf '%s' "$certificate_content" | base64 --decode > "$cert_path"
fi

security import "$cert_path" -A -t cert -k "$KEYCHAIN_PATH"

cert_name="$(openssl x509 -inform DER -in "$cert_path" -noout -subject -nameopt multiline | awk -F'= ' '/commonName/ { print $2; exit }')"
if [[ -z "$cert_name" ]]; then
  echo "Unable to resolve Mac installer certificate name." >&2
  exit 1
fi

echo "MAC_INSTALLER_CERT_NAME=${cert_name}" >> "$GITHUB_ENV"
echo "Prepared Mac installer certificate ${cert_name}."
