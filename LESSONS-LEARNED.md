# Lessons Learned — nCino Hands-On Workshop (2026-06-24)

Captured from running the workshop live with 3 teams. All three teams completed the required build
steps and moved on to their own use cases. These are the in-room findings worth folding into the kit.

> **Status:** documentation pass only. Script hardening (item 1) is noted but **not yet implemented** —
> needs an org test before changing `02-deploy.sh` behavior.

---

## 1. Partial-deploy orphan collision on retry (highest-value fix)

**What happened.** On one org, the first `02-deploy.sh` partially landed. It left an orphaned
`AiAuthoringBundle` named `BankingAdvisorAgent_1` (auto-incremented suffix) that **reserved the
`BankingAdvisorAgent` DeveloperName for a Bot Definition** — but the Bot/planner records never
materialized. The team's retry then failed with:

> `The DeveloperName 'BankingAdvisorAgent' is already in use by a Bot Definition. Please choose a unique name.`

**Why it's nasty (the diagnostic trap).** The reserved name is **invisible to every standard discovery path**:
- `SELECT … FROM BotDefinition` (SObject query) → 0 rows
- `BotDefinition` is **not supported** in the Tooling API → query errors
- `queryAll` (includes soft-deleted) → 0 rows
- `sf org list metadata -m Bot` → empty

Only **`sf org list metadata -m AiAuthoringBundle`** reveals the squatting bundle. Without that, the error
("already in use by a Bot Definition") sends you hunting for a Bot that the org claims doesn't exist.

**The fix that works.** Remove the orphan bundle, then redeploy:

```bash
# 1. Confirm the orphan exists and no real agent is present (all of these should be empty/just the orphan):
sf org list metadata -m AiAuthoringBundle -o <org> --json
sf data query -o <org> -q "SELECT DeveloperName FROM BotDefinition"
sf data query -o <org> -q "SELECT DeveloperName FROM GenAiPlannerDefinition"

# 2. Delete the orphan bundle (safe: it's the failed-attempt leftover, no working agent to damage):
sf project delete source --metadata "AiAuthoringBundle:BankingAdvisorAgent_1" -o <org> --no-prompt

# 3. Redeploy:
./scripts/02-deploy.sh
```

**Root cause.** `sf project deploy` is atomic, but an interrupted/partial agent deploy can still leave the
authoring bundle behind, and the bundle reserves the Bot DeveloperName. This will recur for **any** team
whose first deploy fails midway — it is a kit-level gap, not a one-off.

**Follow-ups for the cleanup run:**
- ✅ (this doc) Add the symptom + discovery command + recovery to GUIDE Module 1 troubleshooting. *(Done.)*
- ⏳ (deferred — needs org test) Harden `02-deploy.sh` to detect a prior partial `BankingAdvisorAgent*`
  bundle and offer to clean it before deploying.

---

## 2. Plugin marketplace slug was unpinned in GUIDE Module 0

**What happened.** Module 0 told participants to install `sf-mcp-partner-toolkit` via `/plugin` but didn't
pin the exact marketplace/repo, so install relied on the facilitator's link.

**Confirmed exact values (now pinned in GUIDE Module 0):**
- Source repo: `github.com/mvogelgesang/sf-mcp-partner-toolkit` — **public, individual repo** (not an
  official Salesforce marketplace; note provenance to participants).
- Commands:
  - `/plugin marketplace add mvogelgesang/sf-mcp-partner-toolkit`
  - `/plugin install sf-mcp-partner-toolkit@mvogelgesang-plugins`
- Marketplace registers as `mvogelgesang-plugins`; plugin id `sf-mcp-partner-toolkit@mvogelgesang-plugins`
  (v1.0.0). Brings: setup-workspace, scaffold-mcp-integration, deploy-and-configure, diagnose-connection,
  validate-end-to-end.

---

## 3. "Mock MCP server is down (503)" — usually isn't the server

**What happened.** A team reported a 503 from the mock MCP server. On investigation the server was healthy:
root `200`, `/oauth/token` `200`, and the MCP endpoint correctly returned `401 Missing Bearer token`
unauthenticated (i.e., OAuth is enforcing as designed).

**Takeaway.** A 503/"service unavailable" surfaced to the agent is far more likely an **org-side credential
issue** (the 🔴 Module 2 principal/permset path) or a transient edge blip than a server outage. Before
assuming the shared server is down, verify it directly:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://ncino-banking-advisor-mock.bstauber.workers.dev
curl -s -X POST https://ncino-banking-advisor-mock.bstauber.workers.dev/banking-advisor \
  -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
# Expect: 401 "Missing Bearer token"  → server healthy, look at org-side credentials.
```

Consider adding this 3-line server-health check to the Module 2 troubleshooting block.

---

## 4. What worked (keep)

- **The hands-on MCP-wiring portion is what drew the engineers in.** Engagement broadened from architect →
  product → engineering precisely at the build modules. The "scaffold + guided 🔴 manual checkpoint" design
  held up — keep it.
- **All 3 teams self-directed into their own use cases at the end.** The agency KPI was met.
- **Common build question to pre-empt:** "greet the current user by name" (running-user identity vs. query
  subject). A copy-ready how-to was produced (`greet-by-current-user-name.md`) — candidate to fold into
  Module 7 (Extend) as a worked example. Note the running-user gotcha: a service agent on a shared Einstein
  Agent User returns the *bot's* name, not the end user's.
