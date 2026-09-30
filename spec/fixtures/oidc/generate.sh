#!/usr/bin/env bash
# Regenerates the Sign in with Slack test fixtures in this directory.
#
# The OpenSSL CLI does all cryptography: key generation, SHA-256, and RS256
# signatures. The library has no signing code, so these files are an
# independent oracle for its verifier. Every value is synthetic.
#
# The script keeps signing_key.pem when it exists, so a rerun changes only the
# files whose inputs changed. Delete signing_key.pem to make a new key; then
# every token and jwks.json change.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

[[ -f signing_key.pem ]] || openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out signing_key.pem 2>/dev/null
openssl pkey -in signing_key.pem -pubout -outform DER -out public_key.der

modulus_hex=$(openssl rsa -in signing_key.pem -noout -modulus | cut -d= -f2)
modulus=$(printf '%s' "$modulus_hex" | xxd -r -p | b64url)
cat > jwks.json <<JSON
{
  "keys": [
    {
      "kty": "EC",
      "crv": "P-256",
      "kid": "synthetic-ec-kid",
      "use": "sig",
      "alg": "ES256",
      "x": "c3ludGhldGljLWVjLXgtY29vcmRpbmF0ZS1ub3QtYS1rZXk",
      "y": "c3ludGhldGljLWVjLXktY29vcmRpbmF0ZS1ub3QtYS1rZXk"
    },
    {
      "kty": "RSA",
      "kid": "synthetic-kid",
      "use": "sig",
      "alg": "RS256",
      "n": "$modulus",
      "e": "AQAB"
    }
  ]
}
JSON

# at_hash: base64url of the left half of SHA-256 of the access token (OIDC Core 3.1.3.6).
at_hash=$(printf '%s' "xoxp-synthetic-sign-in" | openssl dgst -sha256 -binary | head -c 16 | b64url)
other_at_hash=$(printf '%s' "xoxp-another-token" | openssl dgst -sha256 -binary | head -c 16 | b64url)

header='{"alg":"RS256","kid":"synthetic-kid","typ":"JWT"}'

# Claims shaped like the example in https://docs.slack.dev/authentication/sign-in-with-slack.
# iat is 1760000000 and exp is iat + 300, as in the documented example.
claims() {
  local iss=$1 aud=$2 nonce=$3 hash_field=$4 extra=$5
  printf '{"iss":"%s","sub":"U-SYNTHETIC","aud":%s,"exp":1760000300,"iat":1760000000,' "$iss" "$aud"
  printf '"auth_time":1760000000,"nonce":"%s"%s,' "$nonce" "$hash_field"
  printf '"https://slack.com/team_id":"T-SYNTHETIC","https://slack.com/user_id":"U-SYNTHETIC",'
  printf '"email":"alice@example.test","email_verified":true,"date_email_verified":1622128723,'
  printf '"locale":"en-US","name":"Alice Example","given_name":"Alice","family_name":"Example"%s}' "$extra"
}

# sign <file> <header JSON> <payload bytes>
sign() {
  local signing_input
  signing_input="$(printf '%s' "$2" | b64url).$(printf '%s' "$3" | b64url)"
  local signature
  signature=$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign signing_key.pem -binary | b64url)
  printf '%s.%s' "$signing_input" "$signature" > "$1"
}

hash=",\"at_hash\":\"$at_hash\""
sign id_token_valid.txt "$header" "$(claims https://slack.com '"1234.5678"' synthetic-nonce "$hash" '')"
sign id_token_wrong_nonce.txt "$header" "$(claims https://slack.com '"1234.5678"' another-nonce "$hash" '')"
sign id_token_wrong_audience.txt "$header" "$(claims https://slack.com '"8765.4321"' synthetic-nonce "$hash" '')"
sign id_token_wrong_issuer.txt "$header" "$(claims https://slack.example.test '"1234.5678"' synthetic-nonce "$hash" '')"
sign id_token_audience_array_with_azp.txt "$header" \
  "$(claims https://slack.com '["1234.5678","8765.4321"]' synthetic-nonce "$hash" ',"azp":"1234.5678"')"
sign id_token_audience_array_without_azp.txt "$header" \
  "$(claims https://slack.com '["1234.5678","8765.4321"]' synthetic-nonce "$hash" '')"
sign id_token_missing_at_hash.txt "$header" "$(claims https://slack.com '"1234.5678"' synthetic-nonce '' '')"
sign id_token_other_at_hash.txt "$header" \
  "$(claims https://slack.com '"1234.5678"' synthetic-nonce ",\"at_hash\":\"$other_at_hash\"" '')"
sign id_token_unknown_kid.txt '{"alg":"RS256","kid":"rotated-kid","typ":"JWT"}' \
  "$(claims https://slack.com '"1234.5678"' synthetic-nonce "$hash" '')"
sign id_token_missing_kid.txt '{"alg":"RS256","typ":"JWT"}' \
  "$(claims https://slack.com '"1234.5678"' synthetic-nonce "$hash" '')"
sign id_token_crit_header.txt '{"alg":"RS256","kid":"synthetic-kid","crit":["exp"],"exp":1760000300}' \
  "$(claims https://slack.com '"1234.5678"' synthetic-nonce "$hash" '')"
sign id_token_missing_team_id.txt "$header" \
  "$(claims https://slack.com '"1234.5678"' synthetic-nonce "$hash" '' | sed 's|"https://slack.com/team_id":"T-SYNTHETIC",||')"
sign id_token_payload_not_json.txt "$header" '["not","an","object"]'
