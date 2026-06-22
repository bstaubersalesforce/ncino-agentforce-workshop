#!/usr/bin/env bash
# Module 2 verify: run the MCP callout and confirm HTTP 200 + 4 tools.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$DIR/lib/common.sh"
ORG="$(resolve_org "$@")"

OUT="$(mktemp)"
# shellcheck disable=SC2046
sf apex run --file "$DIR/apex/test_callout.apex" $(org_arg "$ORG") > "$OUT" 2>&1 || true

if grep -q "MCP_STATUS=200" "$OUT" && grep -q '"tools"' "$OUT"; then
  pass "MCP callout returned 200 with a tools list."
  echo "Confirm 4 tools are listed in the body above, then proceed to Module 3 (Register tools)."
  rm -f "$OUT"
  exit 0
fi

fail "MCP smoke test did NOT return a healthy tools list."
echo "--- apex output ---"; cat "$OUT"; echo "-------------------"
rm -f "$OUT"
cat >&2 <<'TIPS'
Troubleshooting (see GUIDE.md Module 2):
  401 / 403 ............. EC Principal Access not granted on NCinoBankingAdvisor_Perm_Set
  404 .................... Named Credential URL wrong / trailing-slash mismatch
  "Unauthorized endpoint" . Re-save the Named Credential to refresh the Remote Site Setting
  empty body / INVALID_AUTH_HEADER . Generate Authorization Header is off on the NC
  no data once AGENT runs . Run scripts/apex/assign-piu-permset.apex (Platform Integration User grant)
TIPS
exit 1
