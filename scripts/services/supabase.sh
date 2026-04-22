#!/usr/bin/env bash
# Supabase — managed Postgres + auth + realtime.
# Uses personal access tokens (PATs) rather than browser OAuth for scripted ops.

set -euo pipefail

_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

shiplane_service_supabase_status() {
  local token
  token="$(shiplane_get .supabase.access_token)"
  [ -z "$token" ] && return 1
  SUPABASE_ACCESS_TOKEN="$token" supabase projects list >/dev/null 2>&1
}

shiplane_service_supabase_onboard() {
  if ! command -v supabase >/dev/null 2>&1; then
    echo "   supabase CLI not installed — install with: brew install supabase/tap/supabase"
    return 1
  fi

  echo "   mint a personal access token at: https://supabase.com/dashboard/account/tokens"
  echo "   name suggestion: 'shiplane on $(hostname -s)'"
  echo
  read -r -s -p "   paste your Supabase access token (sbp_...): " token
  echo

  if [[ ! "$token" =~ ^sbp_ ]]; then
    echo "   ✗ that doesn't look like a supabase access token (expected sbp_...)"
    return 1
  fi

  if ! SUPABASE_ACCESS_TOKEN="$token" supabase projects list >/dev/null 2>&1; then
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
