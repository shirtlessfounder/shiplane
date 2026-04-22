#!/usr/bin/env bash
# Validates each stored credential against the live service. Exits 0 if all
# four services are authed; non-zero if any failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/creds.sh"

green() { printf "\033[32m%s\033[0m" "$1"; }
red()   { printf "\033[31m%s\033[0m" "$1"; }
dim()   { printf "\033[2m%s\033[0m" "$1"; }

ok()   { echo "  $(green '✓') $1"; }
fail() { echo "  $(red '✗') $1"; }

exit_code=0

echo
echo "shiplane: checking stored credentials against live services"
echo
dim "$SHIPLANE_CREDS_FILE"
echo
echo

# ---- github ----
if shiplane_has .github.token; then
  token="$(shiplane_get .github.token)"
  if curl -sf -H "Authorization: Bearer $token" https://api.github.com/user >/dev/null; then
    login="$(curl -sf -H "Authorization: Bearer $token" https://api.github.com/user | jq -r .login)"
    ok "github — authed as $login"
  else
    fail "github — stored token rejected by github api"
    exit_code=1
  fi
else
  fail "github — no token stored (run onboard.sh)"
  exit_code=1
fi

# ---- supabase ----
if shiplane_has .supabase.access_token; then
  token="$(shiplane_get .supabase.access_token)"
  if SUPABASE_ACCESS_TOKEN="$token" supabase projects list >/dev/null 2>&1; then
    ok "supabase — access token valid"
  else
    fail "supabase — stored token rejected by supabase api"
    exit_code=1
  fi
else
  fail "supabase — no token stored (run onboard.sh)"
  exit_code=1
fi

# ---- vercel ----
if shiplane_has .vercel.token; then
  token="$(shiplane_get .vercel.token)"
  if curl -sf -H "Authorization: Bearer $token" https://api.vercel.com/v2/user >/dev/null; then
    user="$(curl -sf -H "Authorization: Bearer $token" https://api.vercel.com/v2/user | jq -r .user.username)"
    ok "vercel — authed as $user"
  else
    fail "vercel — stored token rejected by vercel api"
    exit_code=1
  fi
else
  fail "vercel — no token stored (run onboard.sh)"
  exit_code=1
fi

# ---- exe.dev ----
if shiplane_has .exe.ssh_key_path; then
  key_path="$(shiplane_get .exe.ssh_key_path)"
  key_path="${key_path/#\~/$HOME}"
  default_host="$(shiplane_get .exe.default_host)"
  if [ ! -f "$key_path" ]; then
    fail "exe.dev — ssh key file missing at $key_path"
    exit_code=1
  elif [ -z "$default_host" ]; then
    ok "exe.dev — ssh key exists at $key_path (no default host to verify against)"
  else
    if ssh -i "$key_path" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
         "$default_host" 'true' >/dev/null 2>&1; then
      ok "exe.dev — ssh to $default_host succeeded"
    else
      fail "exe.dev — ssh to $default_host failed (key not accepted, or host unreachable)"
      exit_code=1
    fi
  fi
else
  fail "exe.dev — no ssh key stored (run onboard.sh)"
  exit_code=1
fi

echo
if [ $exit_code -eq 0 ]; then
  echo "$(green 'all four services authed')"
else
  echo "$(red 'one or more services need attention') — re-run onboard.sh for the failing ones"
fi
echo
exit $exit_code
