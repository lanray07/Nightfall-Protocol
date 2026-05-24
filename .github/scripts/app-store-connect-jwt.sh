#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" || -z "${ASC_KEY_PATH:-}" ]]; then
  echo "ASC_KEY_ID, ASC_ISSUER_ID, and ASC_KEY_PATH must be set." >&2
  exit 1
fi

bundle exec ruby <<'RUBY'
require "jwt"
require "openssl"

private_key = OpenSSL::PKey::EC.new(File.read(ENV.fetch("ASC_KEY_PATH")))
payload = {
  iss: ENV.fetch("ASC_ISSUER_ID"),
  iat: Time.now.to_i,
  exp: Time.now.to_i + 1200,
  aud: "appstoreconnect-v1"
}
headers = {
  kid: ENV.fetch("ASC_KEY_ID"),
  typ: "JWT"
}

puts JWT.encode(payload, private_key, "ES256", headers)
RUBY
