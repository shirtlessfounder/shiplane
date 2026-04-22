#!/usr/bin/env bash
# GitHub — repo hosting, issues, PRs, CI.
# Native CLI: `gh`. Caches auth at ~/.config/gh/hosts.yml (or macOS keychain).

set -euo pipefail

# Locate shiplane scripts dir relative to this file.
_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

shiplane_service_github_status() {
  gh auth status >/dev/null 2>&1
}

shiplane_service_github_onboard() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "   gh CLI not installed — install with: brew install gh"
    return 1
  fi

  if shiplane_service_github_status; then
    echo "   ✓ already logged in as $(gh api user -q .login 2>/dev/null)"
  else
    echo "   launching browser-based gh login"
    gh auth login --web --git-protocol https
  fi

  local token username
  token="$(gh auth token 2>/dev/null || true)"
  username="$(gh api user -q .login 2>/dev/null || true)"

  if [ -z "$token" ] || [ -z "$username" ]; then
    echo "   ✗ could not resolve gh token/username after login"
    return 1
  fi

  shiplane_save_creds "$(jq -n --arg t "$token" --arg u "$username" \
    '{github:{token:$t,username:$u}}')"
  echo "   ✓ github authed as $username"
}

# Allow running directly: `bash scripts/services/github.sh`
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_github_onboard
fi
