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

In Claude Code, inside this repo:

1. Confirm the skill is available: `/developing-agentforce`
2. Run these prompts:
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

### Optional — enable the Slack push

The agent can push a summary to Slack one-way. To make it work:

1. Create a Slack **Incoming Webhook** bound to your target channel.
2. Setup → Named Credentials → edit **`Slack_Banking_Alerts`** → set the **URL** to the real webhook
   URL (the webhook URL *is* the secret — enter it per org, never commit it). Leave it Anonymous / no
   auth header.
3. Re-ask the agent for a summary, then "send that to Slack" (two-step — single-shot is unreliable).
