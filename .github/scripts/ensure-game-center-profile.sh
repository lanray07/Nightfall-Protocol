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

profile_url="${api_base}/profiles?filter[name]=$(encode "$profile_name")&filter[profileType]=$(encode "$profile_type")&filter[profileState]=ACTIVE&limit=1&fields[profiles]=name,profileType,profileState"
profile_response="$(api_request GET "$profile_url")"
profile_id="$(printf '%s' "$profile_response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
items = payload.get("data", [])
if not items:
    raise SystemExit("No active provisioning profile matched the requested name and type.")
print(items[0]["id"])')"

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

api_request DELETE "${api_base}/profiles/${profile_id}" >/dev/null
sleep 5

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
