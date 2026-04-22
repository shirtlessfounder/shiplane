#!/usr/bin/env bash
# exe.dev — long-running VM host with `share port` auto-HTTPS.
# No native CLI. Auth is SSH-key-based; user pastes pubkey into dashboard.

set -euo pipefail

_SHIPLANE_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_SHIPLANE_SCRIPTS_DIR/lib/creds.sh"

shiplane_service_exe_status() {
  local key_path
  key_path="$(shiplane_get .exe.ssh_key_path)"
  [ -n "$key_path" ] && [ -f "${key_path/#\~/$HOME}" ]
}

shiplane_service_exe_onboard() {
  echo "   exe.dev uses SSH-key auth — no API token to paste."

  local key_path="$HOME/.ssh/id_shiplane_exe"
  if [ -f "$key_path" ]; then
    echo "   ✓ keypair already exists at $key_path"
  else
    read -r -p "   generate a fresh ed25519 keypair at $key_path? [Y/n] " ans
    ans="${ans:-y}"
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      ssh-keygen -t ed25519 -C "shiplane" -f "$key_path" -N ""
      echo "   ✓ keypair generated"
    else
      read -r -p "   path to existing SSH private key: " key_path
      if [ ! -f "$key_path" ]; then
        echo "   ✗ no file at $key_path"
        return 1
      fi
    fi
  fi

  local pubkey
  pubkey="$(cat "${key_path}.pub")"

  echo
  echo "   add this public key to your exe.dev account:"
  echo "     https://exe.dev/settings/ssh-keys"
  echo
  echo "   ---8<---"
  echo "$pubkey"
  echo "   ---8<---"
  echo
  read -r -p "   press enter once you've added it" _

  local default_host=""
  read -r -p "   default exe.dev host (blank to skip, e.g. innies-api.exe.xyz): " default_host

  shiplane_save_creds "$(jq -n --arg p "$key_path" --arg pk "$pubkey" --arg h "$default_host" \
    '{exe:{ssh_key_path:$p,ssh_pubkey:$pk,default_host:$h}}')"
  echo "   ✓ exe.dev ssh key saved${default_host:+ + default host}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shiplane_service_exe_onboard
fi
