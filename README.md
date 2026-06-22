# nCino Banking Advisor Workshop

Clone this repo to build the **Banking Advisor** Agentforce agent in your assigned org and connect it
to a shared mock **MCP server**.

## 👉 Start here: [**GUIDE.md** — the full step-by-step build guide](./GUIDE.md)

Everything below is orientation. The detailed, module-by-module instructions live in
**[GUIDE.md](./GUIDE.md)** — open it and follow it top to bottom.

## What you're building

An Agentforce agent that answers banker questions (financial summaries, product recommendations, loan
status, rates) by calling a Banking Advisor service over the **Model Context Protocol (MCP)**, with an
optional one-way Slack push. The MCP server is **shared and hosted** — you do not deploy it.

## Prerequisites

- **Salesforce CLI** (`sf`) — https://developer.salesforce.com/tools/salesforcecli
- An **assigned, pre-configured org** (Agentforce, Data Cloud, FSC, and the nCino package are already
  enabled). Log in: `sf org login web --alias <your-alias>`
- **Client ID / Client Secret** for the MCP credential — provided by your facilitator.
- (Optional) Node.js, only if you explore the worker source separately.

## Quick start

```bash
cp .env.example .env          # set ORG_ALIAS to your org alias
./scripts/01-check-env.sh
./scripts/02-deploy.sh
./scripts/03-assign-perms.sh
# then follow GUIDE.md from Module 2 (the credential is a manual step)
```

All scripts accept `--org <alias>` if you don't use `.env`.

## The happy path (8 modules)

0. **Comprehend** — use Claude Code to reverse-engineer the agent.
1. **Deploy** — push source, assign permission sets.
2. **Connect** 🔴 — add the MCP credential principal, grant access, verify the callout.
3. **Register** 🔴 — register the 4 MCP tools.
4. **Wire & iterate** — the inner loop: edit `.agent` → validate → preview (no publish).
5. **Publish & Activate** 🔴 — publish *then* wire actions *then* activate (order matters).
6. **Verify** — Conversation Preview returns real data.
7. **Extend** — seed data, add instructions, score the bundle.

🔴 = manual checkpoint (the steps that silently break a build — GUIDE.md explains each).

## Repo layout

```
force-app/   the agent bundle, Apex, LWC, credential shells, permission sets
scripts/     numbered helpers (01-check-env, 02-deploy, 03-assign-perms, 05-seed-data, 06-smoke-test)
  apex/      test_callout.apex, assign-piu-permset.apex
  lib/       common.sh (shared bash helpers)
data/        covenant-monitors.apex (seed payload)
config/      OPTIONAL scratch-org def (self-service rebuild only — not the workshop path)
GUIDE.md     the full build guide — start here
```

## The mock MCP server

The Banking Advisor data is served by a small **Cloudflare Worker** that speaks MCP. It's **shared and
hosted** — you do not deploy or run it. Source and protocol docs:
**[github.com/bstaubersalesforce/ncino-banking-advisor-mock](https://github.com/bstaubersalesforce/ncino-banking-advisor-mock)**

The credential shells in this repo already point at it; these are the values you'll confirm/enter when
you wire the credential in **GUIDE.md Module 2**:

| What | Value |
|---|---|
| Named Credential URL (MCP endpoint) | `https://ncino-banking-advisor-mock.bstauber.workers.dev/banking-advisor` |
| External Credential auth protocol | OAuth 2.0 — Client Credentials |
| Token endpoint | `https://ncino-banking-advisor-mock.bstauber.workers.dev/oauth/token` |
| Scope | `read` |
| Client ID / Secret | provided by your facilitator (entered in the UI; never in this repo) |

> **Facilitators / maintainers only:** the Worker is managed in Cloudflare (service
> `ncino-banking-advisor-mock`, production). The dashboard URL will be provided by the workshop
> mediator; participants don't need it.

## Notes

- **Secrets never live in this repo** — the client id/secret and any Slack webhook are entered in the
  Salesforce UI only.
- The optional `config/` scratch-org def does **not** enable Agentforce/Data Cloud/FSC/nCino; it's only
  a starting point for rebuilding in your own org after the workshop.
