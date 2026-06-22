#!/usr/bin/env bash
# Module 1: assign BOTH permission sets to the running user.
# Covenant_Monitor_PoC = objects + apex; NCinoBankingAdvisor_Perm_Set = EC principal access + SlackNotifier.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$DIR/lib/common.sh"
ORG="$(resolve_org "$@")"

assign() {
  local name="$1"
  # "Duplicate" / already-assigned is success, not failure (idempotent).
  # shellcheck disable=SC2046
  if sf org assign permset --name "$name" $(org_arg "$ORG") 2>&1 | tee /tmp/permset.$$ | grep -qiE "already|duplicate"; then
    pass "$name already assigned"
  elif grep -qiE "succe" /tmp/permset.$$; then
    pass "$name assigned"
  else
    rm -f /tmp/permset.$$
    die "Failed to assign $name" "Module 1 — Assign permission sets"
  fi
  rm -f /tmp/permset.$$
}

assign "Covenant_Monitor_PoC"
assign "NCinoBankingAdvisor_Perm_Set"
pass "Both permission sets assigned. Next: Module 2 — bind the MCP credential (manual checkpoint)."
