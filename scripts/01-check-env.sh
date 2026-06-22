#!/usr/bin/env bash
# Module 1 preflight: verify tooling + authenticated pre-configured org.
# Licenses are confirm/warn only (orgs are pre-provisioned). Never creates a scratch org.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$DIR/lib/common.sh"

ORG="$(resolve_org "$@")"

command -v sf >/dev/null 2>&1 || die "sf CLI not found." "Module 1 — install Salesforce CLI"
pass "sf CLI present ($(sf --version | head -1))"

command -v node >/dev/null 2>&1 || warn "node not found (only needed for optional worker work)."
[ -n "$ORG" ] && command -v node >/dev/null 2>&1 && pass "node present"

# Confirm an authenticated org we can talk to.
# shellcheck disable=SC2046
if ! sf org display $(org_arg "$ORG") >/dev/null 2>&1; then
  die "No authenticated org (alias='${ORG:-<default>}'). Log in with: sf org login web --alias <alias>" "Module 1 — authenticate your assigned org"
fi
pass "Authenticated to org '${ORG:-<default>}'"

warn "Reminder: your org is pre-provisioned with Agentforce, Data Cloud, FSC, and the nCino package."
warn "If a later step fails on a missing feature, flag your facilitator — do not create a scratch org."
pass "Environment check complete."
