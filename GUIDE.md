# nCino Banking Advisor Workshop — Build Guide

You will stand up the **Banking Advisor** Agentforce agent in your assigned org, connect it to the
shared **mock MCP server**, and iterate on its behavior. Automated steps run a script; **🔴 checkpoints
are manual** — they're the steps that silently break a build if rushed, so we teach each one before you
hit it.

**Prereqs:** the `sf` CLI, an assigned pre-configured org, and the client id/secret your facilitator
hands out. Copy `.env.example` to `.env` and set `ORG_ALIAS` to your org alias. All scripts accept
`--org <alias>` if you prefer.

---

## Module 0 — Comprehend (Claude Code)

Open Claude Code inside this repo. First, install the two workshop plugins, then use them to
reverse-engineer the agent.

### 0a — Install the plugins

In Claude Code, install both plugins. The exact marketplace commands:

- **`agentforce-adlc`** — the Agent Development Life Cycle toolkit. Provides the skills you'll use to
  build, iterate on, and test the agent.
  ```
  /plugin marketplace add SalesforceAIResearch/agentforce-adlc
  /plugin install agentforce-adlc@agentforce-adlc
  ```
- **`sf-mcp-partner-toolkit`** — the Salesforce MCP integration toolkit. Provides the skills you'll use
  to wire and troubleshoot the connection to the mock MCP server.
  ```
  /plugin marketplace add mvogelgesang/sf-mcp-partner-toolkit
  /plugin install sf-mcp-partner-toolkit@mvogelgesang-plugins
  ```
  > Provenance note: `sf-mcp-partner-toolkit` is a public community repo
  > (`github.com/mvogelgesang/sf-mcp-partner-toolkit`), not an official Salesforce marketplace.

After install, confirm a skill is available: `/developing-agentforce`.

### The skills, and when to use each

| Skill | Plugin | What it does | Use it in |
|---|---|---|---|
| **`developing-agentforce`** | agentforce-adlc | Build, edit, debug, preview, and publish `.agent` bundles; the core authoring loop. | Modules 0, 4, 5 |
| **`testing-agentforce`** | agentforce-adlc | Write and run structured agent test specs (AiEvaluationDefinition); interpret results. | Module 7 (optional) |
| **`diagnose-connection`** | sf-mcp-partner-toolkit | Troubleshoot MCP connectivity — installs MCP Workbench and walks an error taxonomy. | Module 2, if the smoke test fails |
| **`validate-end-to-end`** | sf-mcp-partner-toolkit | Confirm the MCP integration works from Agentforce: discovery → schema → agent invocation. | Module 6 |

> The other skills in these plugins (`scaffold-mcp-integration`, `deploy-and-configure`,
> `observing-agentforce`, etc.) generate or deploy MCP metadata that this repo **already ships** — you
> don't need them for the workshop build. Stick to the four above.

### 0b — Reverse-engineer the agent

With `developing-agentforce` available, run these prompts:

- "Locate the AiAuthoringBundle directory. Read the .agent file and produce an Agent Spec in plain English."
- "Generate a Mermaid Subagent Map diagram for this agent."
- "What does the client_advisory subagent protect, and what gating conditions guard it?"

---

## Module 1 — Deploy

```bash
./scripts/01-check-env.sh          # tooling + authenticated org
./scripts/02-deploy.sh             # deploys all source (incl. the agent bundle)
./scripts/03-assign-perms.sh       # assigns BOTH permission sets to you
```

Then: `sf org open` → Setup → Object Manager → confirm **Covenant_Monitor__c** appears.

> **Troubleshooting — deploy fails on retry with "DeveloperName 'BankingAdvisorAgent' is already in use by a
> Bot Definition."** A previous partial deploy left an orphaned authoring bundle that reserved the agent's
> name, even though no agent shows up in the org. It is invisible to a normal Bot query — find it with
> `sf org list metadata -m AiAuthoringBundle -o <org> --json` (look for `BankingAdvisorAgent_1` or similar).
> Confirm no real agent exists (`SELECT DeveloperName FROM BotDefinition` and `… FROM GenAiPlannerDefinition`
> both return 0 rows), then remove the orphan and redeploy:
> ```bash
> sf project delete source --metadata "AiAuthoringBundle:BankingAdvisorAgent_1" -o <org> --no-prompt
> ./scripts/02-deploy.sh
> ```
> See `LESSONS-LEARNED.md` for the full diagnosis.

---

## Module 2 — Connect (🔴 the credential, then verify)

The package deployed the credential **shells**. You add the secret-bearing principal by hand — that
part never ships in metadata.

### 🔴 Checkpoint 2a — add the Named Principal to the existing External Credential

Setup → Security → **Named Credentials** → **External Credentials** tab → open **`NCinoBankingAdvisor`**
(it already exists — do **not** create a new one).

In **Principals**, click **New**:
- **Parameter Name:** `MCPAuthentication`
- **Sequence Number:** `1`
- **Identity Type:** Named Principal
- **Client ID / Client Secret:** the values from your facilitator

Save.

> *Why:* the External Credential, Named Credential, and the OAuth protocol/token URL all deploy. The
> **principal (the secret) cannot be packaged.** The permset grant references the principal by the
> exact name `NCinoBankingAdvisor-MCPAuthentication`, so the principal name must be `MCPAuthentication`.

### 🔴 Checkpoint 2b — grant External Credential Principal Access on the permission set

Setup → Users → **Permission Sets** → open **`NCinoBankingAdvisor_Perm_Set`** (NOT
`Covenant_Monitor_PoC`) → **External Credential Principal Access** → **Edit** → enable
**`NCinoBankingAdvisor - MCPAuthentication`** → Save.

> *Why:* this grant **silently drops on deploy** if the principal didn't exist at deploy time, and a
> redeploy won't re-add it. The merge-field auth header resolves empty without it.

### Install the MCP Workbench (diagnostic)

Install the unmanaged package (replace `<org>` with your My Domain host, or paste the path into the
browser while logged in):

```
/packaging/installPackage.apexp?p0=04tHs000000iSjcIAE
```

It sends real JSON-RPC through the Named Credential and gives structured error diagnostics — keep it
handy if the next step fails.

### Grant the Platform Integration User (run after Workbench is installed)

```bash
sf apex run --file scripts/apex/assign-piu-permset.apex   # add --target-org <alias> if not default
```

Look for `PIU_RESULT=✔` (or `ℹ already assigned`).

> *Why:* the **agent's** runtime MCP callout runs as the Platform Integration User, which also needs
> `NCinoBankingAdvisor_Perm_Set`. Skip this and your admin callout test passes but the wired agent
> returns "no data."

### Verify the callout

```bash
./scripts/06-smoke-test.sh
```

Expected: `200` + a body listing **4 tools**. Troubleshooting:

| Symptom | Fix |
|---|---|
| 401 / 403 | EC Principal Access not granted on `NCinoBankingAdvisor_Perm_Set` (Checkpoint 2b) |
| 404 | Named Credential URL wrong / trailing-slash mismatch |
| "Unauthorized endpoint" | Re-save the Named Credential to refresh the Remote Site Setting |
| empty body / INVALID_AUTH_HEADER | "Generate Authorization Header" is off on the NC |

> **Stuck?** Run the **`diagnose-connection`** skill (sf-mcp-partner-toolkit) in Claude Code — it walks
> the MCP error taxonomy and confirms MCP Workbench is set up to pinpoint the failure.

---

## Module 3 — Register the MCP tools (🔴)

Setup → Quick Find **MCP Servers** → open **`NCinoBankingAdvisor`** → **Manage Tools** → **Add Tool**
for each of the 4 tools → confirm. All 4 should show **Active** with populated input/outputSchema.

> *Notes:* the tool list won't load until Checkpoint 2a is done. Salesforce **caches** the schema —
> after any server schema change, **Re-fetch schema** before re-adding.

Optionally validate conformance in Claude Code:
> "Read the 4 MCP tool schemas registered for NCinoBankingAdvisor. Validate each against: (1) outputSchema is a valid JSON Schema describing the response; (2) the server returns 202 on notifications; (3) all I/O fields use JSON primitives. Report violations and why each matters."

---

## Module 4 — Wire & iterate (the inner loop)

Find the agent's API name:

```bash
sf project list metadata --metadata-type AiAuthoringBundle   # add --target-org <alias> if not default
```

Validate, then preview with live actions **before** wiring:

```bash
sf agent validate authoring-bundle --api-name BankingAdvisorAgent
sf agent preview start --use-live-actions --authoring-bundle BankingAdvisorAgent
# capture the sessionId, then:
sf agent preview send --authoring-bundle BankingAdvisorAgent --session-id <sessionId> \
  -u "Give me the financial summary for David Okafor"
```

Now the **inner loop** — edit behavior with NO publish:
1. Open `force-app/main/default/aiAuthoringBundles/BankingAdvisorAgent/BankingAdvisorAgent.agent`
2. Add an instruction to a subagent (e.g. "Always greet the user by name on financial summary requests.")
3. `sf agent validate authoring-bundle --api-name BankingAdvisorAgent`
4. `sf agent preview start --use-live-actions ...` and re-send the prompt to see the change.

> **This is the inner loop: edit `.agent` → validate → preview `--use-live-actions`. No publish needed.**
> Lean on the **`developing-agentforce`** skill here — it understands the `.agent` syntax and the
> validate/preview commands, and can diagnose validation errors.

---

## Module 5 — Publish & Activate (🔴 ORDER MATTERS)

> ## ⛔ Publish BEFORE wiring the MCP actions in the UI — never after.
> `sf agent publish` from source **reverts the in-org MCP tool bindings every time.** If you wire the
> actions first and then publish, the bindings are wiped (the "no data" regression). Always: **publish →
> wire/re-wire actions in Agent Builder → activate.**

1. Publish:
   ```bash
   sf agent publish authoring-bundle --api-name BankingAdvisorAgent
   ```
2. Wire the 4 MCP actions in Agent Builder: Setup → Agentforce → Agents → open the agent → for each
   topic → **This Topic's Actions → Add Action → MCP → NCinoBankingAdvisor**:
   - **Client Advisory:** `get_client_financial_summary` + `recommend_banking_products`
   - **Lending Status:** `get_loan_application_status`
   - **Rates & Eligibility:** `get_current_rates_and_eligibility`
3. Activate:
   ```bash
   sf agent activate --api-name BankingAdvisorAgent
   ```

---

## Module 6 — Verify

Agent Builder → **Conversation Preview** → "Give me the financial summary for David Okafor" → expect
**real data**.

If "no data," re-check in this order: EC grant (2b) → Platform Integration User grant → action wiring
(Module 5) — before suspecting the agent.

> **Confirm the full chain** with the **`validate-end-to-end`** skill (sf-mcp-partner-toolkit) — it
> checks tool discovery, schema correctness, and live agent invocation in one pass.

> **Note on the Slack offer.** After returning a summary, the agent may offer to "send it to Slack."
> That path calls `SlackNotifier` Apex through the `Slack_Banking_Alerts` Named Credential, which
> deploys as an **unconfigured shell** — so the send will fail until you configure it (optional;
> see Module 7). The MCP/advisory flow above does not depend on Slack.

---

## Module 7 — Extend (with remaining time)

> **The MCP personas are mock data, not org records.** The clients the agent returns over MCP
> (David Okafor, Lakeside, AgVantage, …) live in the hosted mock server — they do **not** correspond
> to Accounts in your org, and the agent does not need any Account to exist. The seed script below is
> only for the on-platform *Covenant Monitor* hero record; it is **self-contained** (it creates the
> Lakeside Account itself) so it works regardless of what's in your org.

```bash
./scripts/05-seed-data.sh          # seed the Lakeside covenant hero record (optional; creates its own Account)
```

- Add a second instruction to a different subagent and re-run the inner loop.
- Ask Claude Code to scan the org for other workflows that could become actions.
- "Score this AiAuthoringBundle against the Agentforce 100-point rubric and flag safety review issues."
- Use the **`testing-agentforce`** skill (agentforce-adlc) to write a structured test spec for the
  agent and run it — a glimpse of the regression-testing side of the ADLC.

### Optional — show the covenant alert on the record page

The repo ships a `covenantBreachAlert` Lightning Web Component (a hero-record visual for a
`Covenant_Monitor__c` record). There is **no packaged record page** — the Lightning record page that
hosts it can't be deployed reliably (a `flexipage:recordDetail` design-time quirk), so place the
component yourself:

1. Open a Covenant Monitor record (seed one first with `./scripts/05-seed-data.sh`).
2. Setup gear → **Edit Page** (Lightning App Builder).
3. Drag **`covenantBreachAlert`** from the Custom components list onto the page → **Save** → **Activate**.

> The component is a stub (the Interrogate button is a placeholder) — it's here as an extension
> starting point, not a finished feature.

### Optional — enable the Slack push

The agent can push a summary to Slack one-way. To make it work:

1. Create a Slack **Incoming Webhook** bound to your target channel.
2. Setup → Named Credentials → edit **`Slack_Banking_Alerts`** → set the **URL** to the real webhook
   URL (the webhook URL *is* the secret — enter it per org, never commit it). Leave it Anonymous / no
   auth header.
3. Re-ask the agent for a summary, then "send that to Slack" (two-step — single-shot is unreliable).
