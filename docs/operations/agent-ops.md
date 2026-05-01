# Agent Operations

No production in-repo agent workspace is active today. This guide defines how agents must be operated if introduced.

## Pre-Launch Gate For Any Agent

- Written operating file exists.
- Tool list is explicit and least privilege.
- Data scopes are tenant-bound.
- Secrets are inaccessible to prompts and user-provided content.
- Structured output schemas are validated server-side.
- Human approval is required for destructive or financial actions.
- Agent actions are audit logged.
- Prompt-injection tests exist.
- Rollback/disable switch exists.

## Prohibited Agent Actions

- Direct database writes using service role without a backend authorization layer.
- Wallet ledger mutations outside approved wallet RPCs.
- Pool settlement outside approved settlement functions.
- Payment provider execution.
- Admin role grants/revokes without human approval.
- Cross-tenant data summarization unless explicitly authorized by admin policy.

## Monitoring

If agents are added, monitor:

- tool call volume by agent and tenant;
- rejected tool calls;
- schema validation failures;
- prompt-injection indicators;
- human escalation volume;
- audit log gaps;
- latency and cost.

## Incident Handling

1. Disable the agent or revoke tool credentials.
2. Preserve prompts, tool call logs, and outputs.
3. Identify affected tenants and entities.
4. Reconcile any data changes through audited admin tools.
5. Add regression tests before re-enabling.
