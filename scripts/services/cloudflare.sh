#!/usr/bin/env bash
# Cloudflare — Workers, R2, Pages, DNS.
# Native CLI: `wrangler` (Workers). Caches OAuth at ~/.config/.wrangler/.
# We also prompt for a long-lived API token for non-Workers API calls.

set -euo pipefail

_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

shiplane_service_cloudflare_status() {
  if command -v wrangler >/dev/null 2>&1 && wrangler whoami >/dev/null 2>&1; then
    return 0
  fi
  # Fall back to checking for a stored API token we can verify.
  local token
  token="$(shiplane_get .cloudflare.api_token)"
  [ -z "$token" ] && return 1
  curl -sf "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $token" >/dev/null 2>&1
}

shiplane_service_cloudflare_onboard() {
  if command -v wrangler >/dev/null 2>&1; then
    if wrangler whoami >/dev/null 2>&1; then
      echo "   ✓ wrangler already logged in"
    else
      echo "   launching wrangler OAuth login (browser-based)"
      wrangler login
    fi
  else
    echo "   wrangler not installed — install with: npm i -g wrangler"
    echo "   (proceeding with API-token-only flow)"
  fi

  echo
  echo "   for scripted API calls we also want an API token."
  echo "   mint one at: https://dash.cloudflare.com/profile/api-tokens"
  echo "   template: 'Edit Cloudflare Workers' is a reasonable starting scope"
  echo
  read -r -s -p "   paste your cloudflare API token (blank to skip): " token
  echo

  if [ -z "$token" ]; then
    echo "   ⚠ skipped cloudflare API token (wrangler still works)"
    return 0
  fi

  if ! curl -sf "https://api.cloudflare.com/client/v4/user/tokens/verify" \
      -H "Authorization: Bearer $token" >/dev/null; then
    echo "   ✗ token rejected by cloudflare API"
    return 1
  fi

  local default_account=""
  read -r -p "   default account id (blank to skip): " default_account

  shiplane_save_creds "$(jq -n --arg t "$token" --arg a "$default_account" \
    '{cloudflare:{api_token:$t,default_account_id:$a}}')"
  echo "   ✓ cloudflare API token saved${default_account:+ + default account}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_cloudflare_onboard
fi
