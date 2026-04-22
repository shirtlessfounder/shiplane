#!/usr/bin/env bash
# OpenAI — direct API access (for when you're not routing through a proxy).
# No native CLI. Auth is a single API token; store it and validate via API.

set -euo pipefail

_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

shiplane_service_openai_status() {
  local token
  token="$(shiplane_get .openai.api_token)"
  [ -z "$token" ] && return 1
  curl -sf "https://api.openai.com/v1/models" \
    -H "Authorization: Bearer $token" >/dev/null 2>&1
}

shiplane_service_openai_onboard() {
  echo "   mint an API token at: https://platform.openai.com/api-keys"
  echo
  read -r -s -p "   paste your openai API token (sk-...): " token
  echo

  if [[ ! "$token" =~ ^sk- ]]; then
    echo "   ✗ that doesn't look like an openai token (expected sk-...)"
    return 1
  fi

  if ! curl -sf "https://api.openai.com/v1/models" \
      -H "Authorization: Bearer $token" >/dev/null; then
    echo "   ✗ token rejected by openai API"
    return 1
  fi

  shiplane_save_creds "$(jq -n --arg t "$token" \
    '{openai:{api_token:$t}}')"
  echo "   ✓ openai API token saved"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_openai_onboard
fi
