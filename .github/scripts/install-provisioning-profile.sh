#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "usage: $0 <profile-name> <profile-type> <output-path> <env-var-name>" >&2
  exit 2
fi

profile_name="$1"
profile_type="$2"
output_path="$3"
env_var_name="$4"

jwt="$(bash .github/scripts/app-store-connect-jwt.sh)"
encoded_name="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$profile_name")"
encoded_type="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$profile_type")"
url="https://api.appstoreconnect.apple.com/v1/profiles?filter[name]=${encoded_name}&filter[profileType]=${encoded_type}&filter[profileState]=ACTIVE&fields[profiles]=name,uuid,profileType,profileContent"

response="$(curl -fsS --globoff -H "Authorization: Bearer ${jwt}" "$url")"
profile_content="$(printf '%s' "$response" | python3 -c 'import json, sys
payload = json.load(sys.stdin)
items = payload.get("data", [])
if not items:
    raise SystemExit("No active provisioning profile matched the requested name and type.")
print(items[0]["attributes"]["profileContent"])')"

mkdir -p "$(dirname "$output_path")"
printf '%s' "$profile_content" | base64 --decode > "$output_path"

profile_plist="${output_path}.plist"
security cms -D -i "$output_path" > "$profile_plist"
profile_uuid="$(/usr/libexec/PlistBuddy -c "Print UUID" "$profile_plist")"
installed_name="$(/usr/libexec/PlistBuddy -c "Print Name" "$profile_plist")"

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$output_path" "$HOME/Library/MobileDevice/Provisioning Profiles/${profile_uuid}.mobileprovision"

echo "${env_var_name}=${installed_name}" >> "$GITHUB_ENV"
echo "Installed provisioning profile ${installed_name} (${profile_type})."
