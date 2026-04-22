#!/usr/bin/env bash
# Validates each configured service plugin's auth state against the live
# service. Exits 0 if all found-services are authed; non-zero if any failed.
#
#   check-auth.sh                   # check every service
#   check-auth.sh <name> [name ...] # check just the named ones
#   check-auth.sh --list            # list available services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$SCRIPT_DIR/services"
source "$SCRIPT_DIR/lib/creds.sh"

green() { printf "\033[32m%s\033[0m" "$1"; }
red()   { printf "\033[31m%s\033[0m" "$1"; }
dim()   { printf "\033[2m%s\033[0m" "$1"; }

available_services() {
  local f name
  for f in "$SERVICES_DIR"/*.sh; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .sh)"
    echo "$name"
  done
}

check_one() {
  local name="$1"
  local file="$SERVICES_DIR/${name}.sh"
  if [ ! -f "$file" ]; then
    echo "  $(red '✗') $name — no plugin file"
    return 1
  fi
  (
    source "$file"
    if "shiplane_service_${name}_status"; then
      exit 0
    else
      exit 1
    fi
  )
}

main() {
  if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
    available_services
    return 0
  fi

  local selected=()
  if [ "$#" -eq 0 ]; then
    while IFS= read -r name; do
      selected+=("$name")
    done < <(available_services)
  else
    selected=("$@")
  fi

  echo
  echo "shiplane: checking auth state against live services"
  echo
  dim "$SHIPLANE_CREDS_FILE"
  echo
  echo

  local exit_code=0
  for name in "${selected[@]}"; do
    if check_one "$name"; then
      echo "  $(green '✓') $name"
    else
      echo "  $(red '✗') $name — re-run onboarding: $SCRIPT_DIR/onboard.sh $name"
      exit_code=1
    fi
  done

  echo
  if [ $exit_code -eq 0 ]; then
    echo "$(green 'all checked services authed')"
  else
    echo "$(red 'one or more services need attention')"
  fi
  echo
  return $exit_code
}

main "$@"
