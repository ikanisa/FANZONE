# Secret Rotation Runbook

Credentials were shared in chat during the refactor. Treat every shared Supabase key, database password, and access token as compromised until rotated.

## Required Rotation

Rotate before production use:

- Supabase anon key
- Supabase service role key
- Supabase database password and connection strings
- Supabase personal access token
- GitHub Actions secrets that referenced any old Supabase credential
- Local `.env`, `env/*.json`, shell history, and deployment provider variables containing old values

## Supabase Steps

1. Open the Supabase project dashboard.
2. Rotate API keys and database credentials from project settings.
3. Update deployment secrets and local secure env files with the new values.
4. Redeploy Edge Functions after updating secrets.
5. Re-run the smoke checks in `docs/pool-operations.md`.

## Repository Guardrails

- Never commit live Supabase keys, database URLs, personal access tokens, or service role keys.
- Only tracked example files may contain placeholder values.
- Prefer provider secret stores for CI/CD and local ignored env files for development.
- If a credential appears in logs, chat, issue text, or a PR, rotate it again.

## Verification

Run before release:

```bash
git grep -nE '(service_role|postgresql://|sbp_|SUPABASE_SERVICE_ROLE|SUPABASE_DB_PASSWORD)' -- .
git diff --check
```

Manually review any hits. Historical docs may mention placeholder names; live values must not be present.
