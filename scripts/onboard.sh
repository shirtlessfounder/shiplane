#!/usr/bin/env bash
# shiplane onboarding — auto-discovers every service plugin under
# scripts/services/*.sh and runs each one interactively.
#
# Three ways to invoke:
#   onboard.sh                      # run every service
#   onboard.sh <name> [name ...]    # run just the named service(s), e.g. `onboard.sh aws`
#   onboard.sh --list               # print available service names
#
# This script does NOT create new projects / repos / VMs on any platform —
# it only collects auth for resources you've already created yourself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$SCRIPT_DIR/services"
source "$SCRIPT_DIR/lib/creds.sh"

bold()   { printf "\033[1m%s\033[0m" "$1"; }
dim()    { printf "\033[2m%s\033[0m" "$1"; }
green()  { printf "\033[32m%s\033[0m" "$1"; }
yellow() { printf "\033[33m%s\033[0m" "$1"; }

available_services() {
  local f name
  for f in "$SERVICES_DIR"/*.sh; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .sh)"
    echo "$name"
  done
}

usage() {
  echo "Usage:"
  echo "  $0                         # run every service"
  echo "  $0 <name> [name ...]       # run just the named service(s)"
  echo "  $0 --list                  # list available services"
  echo
  echo "Available services:"
  available_services | sed 's/^/  /'
  exit 1
}

preflight_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "shiplane: 'jq' is required. install with: brew install jq" >&2
    exit 1
  fi
}

run_service() {
  local name="$1"
  local file="$SERVICES_DIR/${name}.sh"
  if [ ! -f "$file" ]; then
    echo "  ✗ unknown service: $name"
    echo "    run '$0 --list' to see available services"
    return 1
  fi

  echo
  bold "==> $name"
  echo
  # Source the plugin and invoke its onboard function. Wrap in a subshell so a
  # failing service doesn't kill the rest of the run.
  (
    source "$file"
    "shiplane_service_${name}_onboard"
  ) || echo "  $(yellow '!') $name onboarding failed — you can re-run just this service later: $0 $name"
}

main() {
  preflight_jq

  local selected=()

  if [ "$#" -eq 0 ]; then
    # run all
    while IFS= read -r name; do
      selected+=("$name")
    done < <(available_services)
  else
    case "${1:-}" in
      --list|-l)
        available_services
        return 0
        ;;
      -h|--help)
        usage
        ;;
      *)
        selected=("$@")
        ;;
    esac
  fi

  echo
  bold "shiplane onboarding"
  echo
  dim "Collects auth into $SHIPLANE_CREDS_FILE (mode 0600)"
  echo
  dim "Services: ${selected[*]}"
  echo

  for name in "${selected[@]}"; do
    run_service "$name"
  done

  echo
  bold "Done."
  echo
  echo "Verify with: $SCRIPT_DIR/check-auth.sh"
  echo
}

main "$@"
