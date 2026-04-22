#!/usr/bin/env bash
# Vercel — Next.js frontend hosting + serverless routes.
# Native CLI: `vercel`. Caches auth at ~/.local/share/com.vercel.cli/auth.json.
# We also prompt for a long-lived API token for scripted API calls.

set -euo pipefail

_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

_shiplane_vercel_validate_token() {
  local token="$1"
  curl -sf "https://api.vercel.com/v2/user" \
    -H "Authorization: Bearer $token" >/dev/null 2>&1
}

shiplane_service_vercel_status() {
  # Prefer the CLI if installed (uses its own cached OAuth session), but fall
  # back to the stored API token for users who interact with Vercel via the
  # dashboard + git-push deploys and never installed the CLI.
  if command -v vercel >/dev/null 2>&1 && vercel whoami >/dev/null 2>&1; then
    return 0
  fi
  local token
  token="$(shiplane_get .vercel.token)"
  [ -z "$token" ] && return 1
  _shiplane_vercel_validate_token "$token"
}

shiplane_service_vercel_onboard() {
  if command -v vercel >/dev/null 2>&1; then
    if vercel whoami >/dev/null 2>&1; then
      echo "   ✓ already logged in as $(vercel whoami 2>/dev/null)"
    else
      echo "   launching browser-based vercel login"
      vercel login
    fi
  else
    echo "   vercel CLI not installed — skipping CLI login"
    echo "   (install later with: npm i -g vercel — API-token flow still works)"
  fi

  echo
  echo "   for scripted API calls (+ CLI-less status checks) we want a long-lived token."
  echo "   mint one at: https://vercel.com/account/tokens"
  echo "   scope: full account | expiration: your preference"
  echo
  read -r -s -p "   paste your vercel API token (blank to skip): " token
  echo

  if [ -z "$token" ]; then
    echo "   ⚠ skipped vercel API token (CLI deploys still work if CLI is installed)"
    return 0
  fi

  if ! _shiplane_vercel_validate_token "$token"; then
    echo "   ✗ token rejected by vercel API"
    return 1
  fi

  local default_team=""
  read -r -p "   default team slug (blank for personal account): " default_team

  shiplane_save_creds "$(jq -n --arg t "$token" --arg team "$default_team" \
    '{vercel:{token:$t,default_team:$team}}')"
  echo "   ✓ vercel API token saved${default_team:+ + default team}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_vercel_onboard
fi
