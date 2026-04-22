#!/usr/bin/env bash
# Shared credential read/write helpers. Source this from other shiplane
# scripts:  `source "$(dirname "$0")/lib/creds.sh"`

set -euo pipefail

SHIPLANE_DIR="${SHIPLANE_DIR:-$HOME/.config/shiplane}"
SHIPLANE_CREDS_FILE="${SHIPLANE_CREDS_FILE:-$SHIPLANE_DIR/credentials.json}"

shiplane_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "shiplane: 'jq' is required but not installed. install with: brew install jq" >&2
    exit 1
  fi
}

shiplane_ensure_dir() {
  mkdir -p "$SHIPLANE_DIR"
  chmod 700 "$SHIPLANE_DIR"
}

# Load the credentials file into a variable (empty JSON object if missing).
shiplane_load_creds() {
  shiplane_require_jq
  if [ -f "$SHIPLANE_CREDS_FILE" ]; then
    cat "$SHIPLANE_CREDS_FILE"
  else
    echo '{}'
  fi
}

# Merge a JSON patch into the creds file and persist at 0600.
# Usage: shiplane_save_creds '{"github":{"token":"ghp_..."}}'
shiplane_save_creds() {
  shiplane_require_jq
  shiplane_ensure_dir
  local patch="$1"
  local current
  current="$(shiplane_load_creds)"
  local merged
  merged="$(echo "$current" | jq --argjson patch "$patch" '. * $patch')"
  # atomic replace: write then move
  local tmp
  tmp="$(mktemp "${SHIPLANE_CREDS_FILE}.XXXX")"
  echo "$merged" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$SHIPLANE_CREDS_FILE"
}

# Read a value by jq path, returning empty string if missing.
# Usage: shiplane_get .github.token
shiplane_get() {
  shiplane_require_jq
  local path="$1"
  shiplane_load_creds | jq -r "$path // empty"
}

# Check whether a jq path resolves to a non-empty value.
# Usage: shiplane_has .github.token && echo yes
shiplane_has() {
  [ -n "$(shiplane_get "$1")" ]
}
