#!/usr/bin/env bash
# shiplane onboarding — collects auth for GitHub, exe.dev, Supabase, Vercel
# into ~/.config/shiplane/credentials.json (0600).
#
# This script does NOT create new projects / repos / VMs on any platform.
# It only wires up credentials for resources you've already created yourself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/creds.sh"

# ---------- terminal helpers ----------

bold()   { printf "\033[1m%s\033[0m" "$1"; }
dim()    { printf "\033[2m%s\033[0m" "$1"; }
green()  { printf "\033[32m%s\033[0m" "$1"; }
yellow() { printf "\033[33m%s\033[0m" "$1"; }
red()    { printf "\033[31m%s\033[0m" "$1"; }

step() {
  echo
  bold "==> $1"
  echo
}

ok()   { echo "   $(green '✓') $1"; }
warn() { echo "   $(yellow '!') $1"; }
fail() { echo "   $(red '✗') $1" >&2; }

prompt_yn() {
  local question="$1"
  local default="${2:-y}"
  local hint
  if [ "$default" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  read -r -p "   $question $hint " answer || answer=""
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ---------- preflight: required CLIs ----------

preflight() {
  step "Checking required CLIs"
  local missing=()
  for bin in gh supabase vercel ssh ssh-keygen jq; do
    if command -v "$bin" >/dev/null 2>&1; then
      ok "$bin"
    else
      fail "$bin not found"
      missing+=("$bin")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo
    echo "install the missing CLIs, then re-run this script:"
    echo "  gh       → brew install gh"
    echo "  supabase → brew install supabase/tap/supabase"
    echo "  vercel   → npm i -g vercel"
    echo "  jq       → brew install jq"
    exit 1
  fi
}

# ---------- github ----------

onboard_github() {
  step "GitHub"
  if ! gh auth status >/dev/null 2>&1; then
    echo "   Not logged in to gh. Launching browser-based login."
    gh auth login --web --git-protocol https
  else
    ok "already logged in as $(gh api user -q .login 2>/dev/null)"
  fi

  local token username
  token="$(gh auth token 2>/dev/null || true)"
  username="$(gh api user -q .login 2>/dev/null || true)"

  if [ -z "$token" ] || [ -z "$username" ]; then
    fail "could not resolve github token/username after login"
    return 1
  fi

  shiplane_save_creds "$(jq -n --arg t "$token" --arg u "$username" \
    '{github:{token:$t,username:$u}}')"
  ok "saved github.token + github.username"
}

# ---------- supabase ----------

onboard_supabase() {
  step "Supabase"
  echo "   Supabase access tokens are minted at https://supabase.com/dashboard/account/tokens"
  echo "   Name it something like 'shiplane on $(hostname -s)'."
  echo
  read -r -s -p "   Paste your Supabase access token (starts with sbp_): " token
  echo

  if [[ ! "$token" =~ ^sbp_ ]]; then
    fail "that doesn't look like a supabase access token (expected sbp_...)"
    return 1
  fi

  # exchange to validate
  if ! SUPABASE_ACCESS_TOKEN="$token" supabase projects list >/dev/null 2>&1; then
    fail "token rejected by supabase API"
    return 1
  fi

  local default_ref=""
  if prompt_yn "set a default project ref?"; then
    read -r -p "   project ref (e.g. rcxokzsblffykipiljqv): " default_ref
  fi

  shiplane_save_creds "$(jq -n --arg t "$token" --arg r "$default_ref" \
    '{supabase:{access_token:$t,default_project_ref:$r}}')"
  ok "saved supabase.access_token${default_ref:+ + default_project_ref}"
}

# ---------- vercel ----------

onboard_vercel() {
  step "Vercel"
  if ! vercel whoami >/dev/null 2>&1; then
    echo "   Not logged in to vercel. Launching browser-based login."
    vercel login
  else
    ok "already logged in as $(vercel whoami 2>/dev/null)"
  fi

  # vercel stores its auth under ~/.local/share/com.vercel.cli/auth.json on mac.
  # We also want a long-lived API token for scripted ops — user mints this at
  # https://vercel.com/account/tokens
  echo
  echo "   For scripted deploys we also want an API token."
  echo "   Mint one at: https://vercel.com/account/tokens"
  echo "   Scope: 'Full Account', expiration: your preference."
  echo
  read -r -s -p "   Paste your Vercel API token: " token
  echo

  if [ -z "$token" ]; then
    warn "skipping vercel token (browser login still works, but scripted ops won't)"
    return 0
  fi

  if ! curl -sf "https://api.vercel.com/v2/user" -H "Authorization: Bearer $token" >/dev/null; then
    fail "token rejected by vercel API"
    return 1
  fi

  local default_team=""
  if prompt_yn "set a default team slug?"; then
    read -r -p "   team slug (blank for personal account): " default_team
  fi

  shiplane_save_creds "$(jq -n --arg t "$token" --arg team "$default_team" \
    '{vercel:{token:$t,default_team:$team}}')"
  ok "saved vercel.token${default_team:+ + default_team}"
}

# ---------- exe.dev ----------

onboard_exe() {
  step "exe.dev"
  echo "   exe.dev uses SSH-key auth — no API token to paste."
  echo

  local key_path="$HOME/.ssh/id_shiplane_exe"
  if [ -f "$key_path" ]; then
    ok "keypair already exists at $key_path"
  else
    if prompt_yn "generate a fresh ed25519 keypair at $key_path?"; then
      ssh-keygen -t ed25519 -C "shiplane" -f "$key_path" -N ""
      ok "keypair generated"
    else
      read -r -p "   path to existing SSH private key: " key_path
      if [ ! -f "$key_path" ]; then
        fail "no file at $key_path"
        return 1
      fi
    fi
  fi

  local pubkey
  pubkey="$(cat "${key_path}.pub")"

  echo
  echo "   Add this public key to your exe.dev account:"
  echo "     https://exe.dev/settings/ssh-keys"
  echo
  echo "   ---8<--- copy below ---8<---"
  echo "$pubkey"
  echo "   ---8<--- copy above ---8<---"
  echo
  read -r -p "   press enter once you've added it"

  local default_host=""
  if prompt_yn "set a default exe.dev host (VM name)?"; then
    read -r -p "   host (e.g. innies-api.exe.xyz): " default_host
  fi

  shiplane_save_creds "$(jq -n --arg p "$key_path" --arg pk "$pubkey" --arg h "$default_host" \
    '{exe:{ssh_key_path:$p,ssh_pubkey:$pk,default_host:$h}}')"
  ok "saved exe.ssh_key_path + exe.ssh_pubkey${default_host:+ + default_host}"
}

# ---------- main ----------

main() {
  echo
  bold "shiplane onboarding"
  echo
  dim "Collects auth for GitHub + exe.dev + Supabase + Vercel into"
  echo
  dim "$SHIPLANE_CREDS_FILE (mode 0600)"
  echo
  dim "This script will NOT create new repos/projects/VMs on any platform."
  echo

  preflight

  onboard_github  || warn "github step failed — you can re-run later"
  onboard_supabase || warn "supabase step failed — you can re-run later"
  onboard_vercel  || warn "vercel step failed — you can re-run later"
  onboard_exe     || warn "exe.dev step failed — you can re-run later"

  echo
  bold "Done."
  echo
  echo "Credentials saved to $SHIPLANE_CREDS_FILE"
  echo "Verify with: $SCRIPT_DIR/check-auth.sh"
  echo
}

main "$@"
