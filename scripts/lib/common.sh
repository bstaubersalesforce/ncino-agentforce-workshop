#!/usr/bin/env bash
# Shared helpers for workshop scripts. Source this; do not execute directly.
set -euo pipefail

# Colors (no-op if not a TTY)
if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
fi

pass() { echo "${GREEN}✔ $*${RESET}"; }
warn() { echo "${YELLOW}! $*${RESET}"; }
fail() { echo "${RED}✗ $*${RESET}" >&2; }

# die <message> <guide-pointer>
die() {
  fail "$1"
  [ -n "${2:-}" ] && echo "${BOLD}→ See GUIDE.md: $2${RESET}" >&2
  exit 1
}

# Resolve the org alias: --org flag wins, else ORG_ALIAS env, else the CLI default.
resolve_org() {
  local org=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --org) org="${2:-}"; [ -n "$org" ] || { echo "--org needs a value" >&2; exit 1; }; shift 2;;
      *) shift;;
    esac
  done
  if [ -z "$org" ]; then org="${ORG_ALIAS:-}"; fi
  echo "$org"
}

# Build the --target-org argument (empty string if relying on CLI default).
org_arg() {
  local org="$1"
  if [ -n "$org" ]; then echo "--target-org $org"; fi
}
