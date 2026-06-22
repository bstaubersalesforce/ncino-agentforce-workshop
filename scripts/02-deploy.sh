#!/usr/bin/env bash
# Module 1: deploy all source into the pre-configured org.
# Uses --source-dir (NOT a manifest): the manifest in ncino-poc intentionally excluded
# the AiAuthoringBundle, which we DO need in-org for Agent Builder.
# --test-level NoTestRun: workshop orgs carry pre-existing failing nFORCE/nCino managed
# tests that trip the 75% gate on a default deploy (confirmed on ncino-agentforce-poc).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$DIR/lib/common.sh"
ORG="$(resolve_org "$@")"
ROOT="$(cd "$DIR/.." && pwd)"

echo "Deploying force-app into org '${ORG:-<default>}' ..."
# shellcheck disable=SC2046
sf project deploy start --source-dir "$ROOT/force-app" --test-level NoTestRun $(org_arg "$ORG") \
  || die "Deploy failed. Read the component errors above." "Module 1 — Deploy"
pass "Deploy complete. Next: assign permission sets (03-assign-perms.sh)."
