# Secret Rotation Runbook

Credentials were shared in chat during the refactor. Treat every shared Supabase key, database password, and access token as compromised until rotated.

Release status: not complete until the release owner attaches provider evidence
for every required credential and confirms old values no longer authenticate.

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
5. Re-run `tool/supabase_live_validation.sh`.
6. Re-run `tool/verify_production_envs.sh .env.production`.
7. Re-run `tool/full_history_secret_scan.sh`.

## Provider Evidence Required

Store the evidence outside tracked source unless it is fully redacted. The
release owner must record:

- Supabase project ref and rotation timestamp.
- Supabase anon key rotation confirmation.
- Supabase service-role key rotation confirmation.
- Database password or connection-string rotation confirmation.
- Supabase personal access token revocation and replacement confirmation.
- Cloudflare Pages environment variable update timestamps for website, admin,
  venue portal, and TV display where applicable.
- CI/CD secret update timestamps.
- Local operator confirmation that old ignored env files and shell exports were
  replaced.
- Negative check proving at least one old credential no longer authenticates.

Recommended local evidence folder:

```text
output/release-evidence/<timestamp>/secret-rotation/
```

Recommended files:

```text
provider-inventory-redacted.txt
rotation-timestamps-redacted.txt
old-key-negative-check-redacted.txt
post-rotation-smoke-summary.txt
```

Record the launch evidence in:

```text
release/security/secret-rotation-evidence.json
```

Then validate it with:

```bash
node tool/validate_secret_rotation_evidence.mjs
```

## Repository Guardrails

- Never commit live Supabase keys, database URLs, personal access tokens, or service role keys.
- Only tracked example files may contain placeholder values.
- Prefer provider secret stores for CI/CD and local ignored env files for development.
- If a credential appears in logs, chat, issue text, or a PR, rotate it again.

## Verification

Run before release:

```bash
git grep -nE '(service[_-]?role|postgresql:/{2}|sbp[_-]|SUPABASE_(SERVICE_ROLE|DB_PASSWORD))' -- .
git diff --check
tool/full_history_secret_scan.sh
tool/verify_production_envs.sh .env.production
```

Manually review any hits. Historical docs may mention placeholder names; live values must not be present.

## Release Sign-Off

Do not mark `Credential rotation and secret inventory` as `PASS` in
`docs/release/world-class-evidence-matrix.md` until this block is complete:

```text
release_owner:
security_owner:
rotation_completed_at_utc:
evidence_folder:
old_credentials_revoked: yes/no
post_rotation_secret_scan_passed: yes/no
post_rotation_prod_smoke_passed: yes/no
notes:
```
