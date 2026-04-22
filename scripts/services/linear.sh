#!/usr/bin/env bash
# Linear — issue tracking + project management.
# No native CLI. Auth is a single API token; validate via the GraphQL viewer query.

set -euo pipefail

_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

_shiplane_linear_viewer_query() {
  local token="$1"
  curl -sf -X POST "https://api.linear.app/graphql" \
    -H "Authorization: $token" \
    -H "Content-Type: application/json" \
    -d '{"query":"{ viewer { id email name } }"}'
}

shiplane_service_linear_status() {
  local token
  token="$(shiplane_get .linear.api_token)"
  [ -z "$token" ] && return 1
  _shiplane_linear_viewer_query "$token" >/dev/null 2>&1
}

shiplane_service_linear_onboard() {
  echo "   mint an API token at: https://linear.app/settings/api"
  echo "   (Personal API keys → New API key)"
  echo
  read -r -s -p "   paste your linear API token (lin_api_...): " token
  echo

  if [[ ! "$token" =~ ^lin_api_ ]]; then
    echo "   ⚠ that doesn't match the usual linear prefix (lin_api_...) — trying anyway"
  fi

  local resp
  resp="$(_shiplane_linear_viewer_query "$token" || true)"
  if [ -z "$resp" ] || ! echo "$resp" | jq -e '.data.viewer.id' >/dev/null 2>&1; then
    echo "   ✗ token rejected by linear API"
    return 1
  fi

  local email
  email="$(echo "$resp" | jq -r '.data.viewer.email')"
  shiplane_save_creds "$(jq -n --arg t "$token" \
    '{linear:{api_token:$t}}')"
  echo "   ✓ linear authed as $email"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_linear_onboard
fi
