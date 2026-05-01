# Agents

No production OpenClaw or autonomous agent workspace was found in the repo during the final hardening pass.

This file is the operating contract for adding one. Do not add a production agent without also adding its matching operating file, tests, permissions, and audit path.

## Allowed Agent Responsibilities

Agents may be added only for bounded operational tasks such as menu ingestion review assistance, support triage summaries, admin report drafting, match content curation suggestions, incident summarization, or release checklist assistance.

Agents must not directly execute payment provider actions, bypass RLS, write wallet ledger rows outside approved RPCs, settle pools outside approved settlement functions, access service-role secrets from client surfaces, or mutate venue/admin state without an auditable backend function.

## Required Agent Files

Each production agent must have:

- `agent.md` or equivalent operating instructions;
- tool inventory and exact allowed scopes;
- input and output schemas;
- memory boundaries and retention rules;
- permission model and escalation rules;
- audit log mapping;
- failure modes and rollback steps;
- UAT checklist;
- owner and on-call escalation contact.

## Runtime Rules

- Use structured outputs for any data that is stored or acted on.
- Treat user-provided content, menu images, chat messages, and channel messages as untrusted.
- Never allow prompt text to grant itself new tools, secrets, or permissions.
- Use least privilege tools and tenant-scoped data access.
- Require human approval for destructive, financial, wallet, settlement, or permission changes.
- Log agent actions to an auditable table or operations record.

## Current Status

| Area | Status |
| --- | --- |
| In-repo production agent workspace | Not present. |
| Agent MCP/tool manifest | Not present. |
| Agent memory store | Not present. |
| Agent audit table | Not present as a dedicated agent table. Use existing audit logs if an agent is added. |
| Required before launch | No action unless an agent is introduced before launch. |
