#!/usr/bin/env bash
# Resend — transactional email API.
# No native CLI. Auth is a single API token; store it and validate via API.

set -euo pipefail

_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

shiplane_service_resend_status() {
  local token
  token="$(shiplane_get .resend.api_token)"
  [ -z "$token" ] && return 1
  curl -sf "https://api.resend.com/domains" \
    -H "Authorization: Bearer $token" >/dev/null 2>&1
}

shiplane_service_resend_onboard() {
  echo "   mint an API token at: https://resend.com/api-keys"
  echo "   scope: 'Full access' for day-to-day; 'Sending access' for prod deploys"
  echo
  read -r -s -p "   paste your resend API token (re_...): " token
  echo

  if [[ ! "$token" =~ ^re_ ]]; then
    echo "   ✗ that doesn't look like a resend token (expected re_...)"
    return 1
  fi

  if ! curl -sf "https://api.resend.com/domains" \
      -H "Authorization: Bearer $token" >/dev/null; then
    echo "   ✗ token rejected by resend API"
    return 1
  fi

  # Peek at the user's configured sending domains as a sanity check.
  local domains
  domains="$(curl -sf "https://api.resend.com/domains" \
    -H "Authorization: Bearer $token" | jq -r '.data[]?.name' 2>/dev/null || true)"
  if [ -z "$domains" ]; then
    echo "   ⚠ no verified sending domains yet — add one at https://resend.com/domains"
  else
    echo "   verified domains: $(echo "$domains" | tr '\n' ' ')"
  fi

  shiplane_save_creds "$(jq -n --arg t "$token" \
    '{resend:{api_token:$t}}')"
  echo "   ✓ resend API token saved"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_resend_onboard
fi
