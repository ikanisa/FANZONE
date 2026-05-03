# Free-Account Release Model

FANZONE does not depend on paid GitHub Actions minutes for release.

## GitHub

- Workflows in `.github/workflows/` are manual-only fallbacks.
- Push, pull request, and scheduled triggers are intentionally disabled.
- A red GitHub Actions status caused by account billing does not block local release verification.

## Local Verification

Run checks from a release machine:

```bash
git grep -nE '(eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9_-]{20,}|postgresql://[^[:space:]]+:[^[:space:]]+@)' -- ':!.github/workflows/secret-regex-scan.yml' ':!docs/secret-rotation-runbook.md' ':!**/package-lock.json'
bash -n tool/*.sh
flutter analyze
flutter test
npm run typecheck --workspaces --if-present
npm run lint --workspaces --if-present
npm run build --workspaces --if-present
supabase db push --dry-run
```

## Web Deploys

Deploy Cloudflare Pages directly from a local/free release machine:

```bash
tool/deploy_cloudflare_pages.sh all
```

## Scheduled Jobs

Use Supabase cron, another free scheduler, or local cron to call:

```bash
tool/run_supabase_cron_job.sh settle-match-pools
tool/run_supabase_cron_job.sh dispatch-match-alerts
```

