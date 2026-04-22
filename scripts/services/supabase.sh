#!/usr/bin/env bash
# Supabase — managed Postgres + auth + realtime.
# Uses personal access tokens (PATs) rather than browser OAuth for scripted ops.

set -euo pipefail

_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

_shiplane_supabase_validate_token() {
  local token="$1"
  # Prefer the CLI if installed (cheap + offline-robust), but fall back to the
  # management API so users who only interact via `psql` + dashboard don't need
  # the Supabase CLI installed for shiplane to validate their token.
  if command -v supabase >/dev/null 2>&1; then
    SUPABASE_ACCESS_TOKEN="$token" supabase projects list >/dev/null 2>&1
  else
    curl -sf "https://api.supabase.com/v1/projects" \
      -H "Authorization: Bearer $token" >/dev/null 2>&1
  fi
}

shiplane_service_supabase_status() {
  local token
  token="$(shiplane_get .supabase.access_token)"
  [ -z "$token" ] && return 1
  _shiplane_supabase_validate_token "$token"
}

shiplane_service_supabase_onboard() {
  echo "   mint a personal access token at: https://supabase.com/dashboard/account/tokens"
  echo "   name suggestion: 'shiplane on $(hostname -s)'"
  if ! command -v supabase >/dev/null 2>&1; then
    echo "   (supabase CLI not installed — token will still be validated via management API)"
    echo "   install CLI later with: brew install supabase/tap/supabase"
  fi
  echo
  read -r -s -p "   paste your Supabase access token (sbp_...): " token
  echo

  if [[ ! "$token" =~ ^sbp_ ]]; then
    echo "   ✗ that doesn't look like a supabase access token (expected sbp_...)"
    return 1
  fi

  if ! _shiplane_supabase_validate_token "$token"; then
    echo "   ✗ token rejected by supabase API"
    return 1
  fi

  local default_ref=""
  read -r -p "   default project ref (blank to skip, e.g. rcxokzsblffykipiljqv): " default_ref

  shiplane_save_creds "$(jq -n --arg t "$token" --arg r "$default_ref" \
    '{supabase:{access_token:$t,default_project_ref:$r}}')"
  echo "   ✓ supabase authed${default_ref:+ + default project ref}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_supabase_onboard
fi
