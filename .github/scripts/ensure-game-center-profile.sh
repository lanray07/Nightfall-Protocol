#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 <profile-name> <profile-type>" >&2
  exit 2
fi

profile_name="$1"
profile_type="$2"
jwt="$(bash .github/scripts/app-store-connect-jwt.sh)"
api_base="https://api.appstoreconnect.apple.com/v1"

encode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

api_request() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local response_file status
  response_file="$(mktemp)"

  if [[ -n "$body" ]]; then
    status="$(curl -sS --globoff -o "$response_file" -w "%{http_code}" \
      -X "$method" \
      -H "Authorization: Bearer ${jwt}" \
      -H "Content-Type: application/json" \
      --data "$body" \
      "$url")"
  else
    status="$(curl -sS --globoff -o "$response_file" -w "%{http_code}" \
      -X "$method" \
      -H "Authorization: Bearer ${jwt}" \
      "$url")"
  fi

  if [[ ! "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "App Store Connect API request failed: ${method} ${url} (${status})" >&2
    cat "$response_file" >&2
    rm -f "$response_file"
    exit 1
  fi

  cat "$response_file"
  rm -f "$response_file"
}

profile_url="${api_base}/profiles?filter[name]=$(encode "$profile_name")&filter[profileType]=$(encode "$profile_type")&limit=10&fields[profiles]=name,profileType,profileState"
profile_response="$(api_request GET "$profile_url")"
profile_id="$(printf '%s' "$profile_response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
items = payload.get("data", [])
active = [item for item in items if item.get("attributes", {}).get("profileState") == "ACTIVE"]
print((active or items)[0]["id"] if items else "")')"

if [[ -n "$profile_id" ]]; then
  bundle_response="$(api_request GET "${api_base}/profiles/${profile_id}/relationships/bundleId")"
  bundle_id="$(printf '%s' "$bundle_response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
data = payload.get("data")
if not data:
    raise SystemExit("Provisioning profile has no linked Bundle ID.")
print(data["id"])')"

  certificates_response="$(api_request GET "${api_base}/profiles/${profile_id}/relationships/certificates")"
  certificates_data="$(printf '%s' "$certificates_response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
items = payload.get("data", [])
if not items:
    raise SystemExit("Provisioning profile has no linked certificates.")
print(json.dumps([{"type": "certificates", "id": item["id"]} for item in items], separators=(",", ":")))')"
else
  bundle_identifier="${APP_IDENTIFIER:-com.nightfallprotocol.prototype}"
  bundle_response="$(api_request GET "${api_base}/bundleIds?filter[identifier]=$(encode "$bundle_identifier")&limit=1&fields[bundleIds]=identifier")"
  bundle_id="$(printf '%s' "$bundle_response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
items = payload.get("data", [])
if not items:
    raise SystemExit("No Bundle ID matched APP_IDENTIFIER.")
print(items[0]["id"])')"

  certificate_work_dir="$(mktemp -d)"
  certificate_private_key_path="${certificate_work_dir}/distribution-signing.key"
  certificate_public_key_path="${certificate_work_dir}/distribution-signing-public.pem"
  certificate_csr_path="${certificate_work_dir}/distribution-signing.csr"
  selected_certificate_path=""
  matching_certificate_id=""
  matching_certificate_path=""
  first_certificate_id=""
  first_certificate_path=""

  if [[ -n "${BUILD_CERTIFICATE_PATH:-}" && -n "${P12_PASSWORD:-}" ]]; then
    openssl pkcs12 \
      -in "$BUILD_CERTIFICATE_PATH" \
      -nocerts \
      -nodes \
      -passin "pass:${P12_PASSWORD}" \
      -out "$certificate_private_key_path" >/dev/null 2>&1 || true

    if [[ -s "$certificate_private_key_path" ]]; then
      openssl pkey \
        -in "$certificate_private_key_path" \
        -pubout \
        -out "$certificate_public_key_path" >/dev/null 2>&1 || true
    fi
  fi

  case "$profile_type" in
    MAC_CATALYST_APP_STORE)
      compatible_certificate_types="MAC_APP_DISTRIBUTION"
      ;;
    MAC_APP_STORE)
      compatible_certificate_types="MAC_APP_DISTRIBUTION"
      ;;
    *)
      compatible_certificate_types="IOS_DISTRIBUTION"
      ;;
  esac

  certificates_response="$(api_request GET "${api_base}/certificates?limit=200&fields[certificates]=certificateType,displayName,expirationDate,certificateContent")"
  CERTIFICATES_RESPONSE="$certificates_response" COMPATIBLE_CERTIFICATE_TYPES="$compatible_certificate_types" python3 - "$certificate_work_dir" <<'PY' > "${certificate_work_dir}/candidates.tsv"
import base64
import json
import os
import sys

candidate_dir = sys.argv[1]
payload = json.loads(os.environ.get("CERTIFICATES_RESPONSE", "{}"))
allowed_types = set(os.environ.get("COMPATIBLE_CERTIFICATE_TYPES", "").split(","))
for index, item in enumerate(payload.get("data", []), start=1):
    certificate_type = item.get("attributes", {}).get("certificateType")
    if certificate_type not in allowed_types:
        continue
    content = item.get("attributes", {}).get("certificateContent")
    if not content:
        continue
    path = os.path.join(candidate_dir, f"distribution-{index}.cer")
    with open(path, "wb") as handle:
        handle.write(base64.b64decode(content))
    print(f"{item['id']}\t{path}\t{certificate_type}")
PY

  while IFS=$'\t' read -r certificate_id certificate_path certificate_type; do
    [[ -n "$certificate_id" ]] || continue
    if [[ -z "$first_certificate_id" ]]; then
      first_certificate_id="$certificate_id"
      first_certificate_path="$certificate_path"
    fi

    if [[ -s "$certificate_public_key_path" && -f "$certificate_path" ]]; then
      candidate_public_key_path="${certificate_path}.pub.pem"
      if openssl x509 -inform DER -in "$certificate_path" -pubkey -noout > "$candidate_public_key_path" 2>/dev/null && \
        cmp -s "$certificate_public_key_path" "$candidate_public_key_path"; then
        matching_certificate_id="$certificate_id"
        matching_certificate_path="$certificate_path"
        break
      fi
    fi
  done < "${certificate_work_dir}/candidates.tsv"

  selected_certificate_id="${matching_certificate_id:-$first_certificate_id}"
  selected_certificate_path="${matching_certificate_path:-$first_certificate_path}"

  if [[ -z "$matching_certificate_id" && -s "$certificate_private_key_path" ]]; then
    create_certificate_type="${compatible_certificate_types%%,*}"
    openssl req \
      -new \
      -key "$certificate_private_key_path" \
      -subj "/CN=Nightfall Protocol Distribution/" \
      -out "$certificate_csr_path"

    create_certificate_body="$(python3 - "$create_certificate_type" "$certificate_csr_path" <<'PY'
import json
import sys

certificate_type, csr_path = sys.argv[1:3]
with open(csr_path, "r", encoding="utf-8") as handle:
    csr = handle.read()

print(json.dumps({
    "data": {
        "type": "certificates",
        "attributes": {
            "certificateType": certificate_type,
            "csrContent": csr
        }
    }
}, separators=(",", ":")))
PY
)"
    create_certificate_response="$(api_request POST "${api_base}/certificates" "$create_certificate_body")"
    selected_certificate_id="$(printf '%s' "$create_certificate_response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
print(payload["data"]["id"])')"
    selected_certificate_path="${certificate_work_dir}/created-distribution.cer"
    printf '%s' "$create_certificate_response" | python3 -c 'import base64, json, sys
payload = json.load(sys.stdin)
print(payload["data"]["attributes"].get("certificateContent", ""))' | base64 --decode > "$selected_certificate_path"
  fi

  if [[ -z "$selected_certificate_id" ]]; then
    echo "No distribution certificates were available to create a provisioning profile." >&2
    exit 1
  fi

  if [[ -n "${KEYCHAIN_PATH:-}" && -f "$selected_certificate_path" ]]; then
    security import "$selected_certificate_path" -A -t cert -k "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  fi

  selected_certificate_name=""
  selected_certificate_sha1=""
  if [[ -f "$selected_certificate_path" ]]; then
    selected_certificate_name="$(openssl x509 -inform DER -in "$selected_certificate_path" -noout -subject -nameopt multiline | awk -F'= ' '/commonName/ { print $2; exit }')"
    selected_certificate_sha1="$(openssl x509 -inform DER -in "$selected_certificate_path" -noout -fingerprint -sha1 | sed -E 's/^.*=//; s/://g')"
  fi

  if [[ -n "${GITHUB_ENV:-}" && "$profile_type" == MAC_APP_STORE ]]; then
    if [[ -n "$selected_certificate_sha1" ]]; then
      echo "MACCATALYST_SIGNING_CERT_NAME=${selected_certificate_sha1}" >> "$GITHUB_ENV"
    elif [[ -n "$selected_certificate_name" ]]; then
      echo "MACCATALYST_SIGNING_CERT_NAME=${selected_certificate_name}" >> "$GITHUB_ENV"
    fi
  fi

  certificates_data="[{\"type\":\"certificates\",\"id\":\"${selected_certificate_id}\"}]"
fi

capabilities_response="$(api_request GET "${api_base}/bundleIds/${bundle_id}/bundleIdCapabilities?fields[bundleIdCapabilities]=capabilityType")"
has_game_center="$(printf '%s' "$capabilities_response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
print("1" if any(item.get("attributes", {}).get("capabilityType") == "GAME_CENTER" for item in payload.get("data", [])) else "0")')"

if [[ "$has_game_center" != "1" ]]; then
  capability_body="$(python3 - "$bundle_id" <<'PY'
import json
import sys

bundle_id = sys.argv[1]
print(json.dumps({
    "data": {
        "type": "bundleIdCapabilities",
        "attributes": {
            "capabilityType": "GAME_CENTER"
        },
        "relationships": {
            "bundleId": {
                "data": {
                    "type": "bundleIds",
                    "id": bundle_id
                }
            }
        }
    }
}, separators=(",", ":")))
PY
)"
  api_request POST "${api_base}/bundleIdCapabilities" "$capability_body" >/dev/null
  echo "Enabled Game Center capability for Bundle ID ${bundle_id}."
fi

profile_state="$(printf '%s' "$profile_response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
items = payload.get("data", [])
active = [item for item in items if item.get("attributes", {}).get("profileState") == "ACTIVE"]
print("ACTIVE" if active else "")')"

if [[ "$profile_state" == "ACTIVE" ]]; then
  echo "Provisioning profile ${profile_name} (${profile_type}) is already active."
  exit 0
fi

create_profile_body="$(python3 - "$profile_name" "$profile_type" "$bundle_id" "$certificates_data" <<'PY'
import json
import sys

name, profile_type, bundle_id, certificates_json = sys.argv[1:5]
print(json.dumps({
    "data": {
        "type": "profiles",
        "attributes": {
            "name": name,
            "profileType": profile_type
        },
        "relationships": {
            "bundleId": {
                "data": {
                    "type": "bundleIds",
                    "id": bundle_id
                }
            },
            "certificates": {
                "data": json.loads(certificates_json)
            }
        }
    }
}, separators=(",", ":")))
PY
)"

api_request POST "${api_base}/profiles" "$create_profile_body" >/dev/null
echo "Refreshed provisioning profile ${profile_name} (${profile_type}) with Game Center capability."
