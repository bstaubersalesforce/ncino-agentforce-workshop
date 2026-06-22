#!/usr/bin/env bash
# Module 7 (optional): seed the Lakeside Covenant Monitor hero record.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$DIR/lib/common.sh"
ORG="$(resolve_org "$@")"
ROOT="$(cd "$DIR/.." && pwd)"

OUT="$(mktemp)"
# shellcheck disable=SC2046
sf apex run --file "$ROOT/data/covenant-monitors.apex" $(org_arg "$ORG") > "$OUT" 2>&1 || true
if grep -q "SEED_RESULT=✔\|SEED_RESULT=ℹ" "$OUT"; then
  grep "SEED_RESULT=" "$OUT" | sed 's/.*SEED_RESULT=/  /'
  pass "Seed step complete."
  rm -f "$OUT"; exit 0
fi
fail "Seed failed."; cat "$OUT"; rm -f "$OUT"
die "Seed did not complete — is the Lakeside Account present in the org?" "Module 7 — Seed data"
