# LiveScore Football Ingest

FANZONE uses LiveScore as the authoritative provider feed for football fixture, match status, score, team, and crest/logo enrichment. Provider data is still staged before it becomes public app data.

The import flow is:

1. Fetch LiveScore fixtures and team image paths.
2. Stage rows in `football_official_fixture_staging`.
3. Resolve teams and write crest/logo source records in `football_team_asset_sources`.
4. Apply safe rows into the raw `matches` catalog.
5. Apply LiveScore status, score, minute, and phase into raw matches.
6. Keep placeholder knockout fixtures as `needs_review`.
7. Admin curation still decides which matches appear publicly or become pool-eligible.

Run a dry export:

```bash
python3 tool/livescore_ingest.py \
  --limit 200 \
  --include-details \
  --include-scoreboard \
  --output /tmp/livescore_world_cup_2026.json
```

Stage and apply to the linked Supabase project:

```bash
SUPABASE_URL="https://<project-ref>.supabase.co" \
SUPABASE_SERVICE_ROLE_KEY="<service-role-key>" \
python3 tool/livescore_ingest.py \
  --limit 200 \
  --include-details \
  --include-scoreboard \
  --push-rest \
  --apply \
  --output /tmp/livescore_world_cup_2026.json
```

Run as a continuous synchronizer:

```bash
SUPABASE_URL="https://<project-ref>.supabase.co" \
SUPABASE_SERVICE_ROLE_KEY="<service-role-key>" \
python3 tool/livescore_ingest.py \
  --limit 200 \
  --include-scoreboard \
  --push-rest \
  --apply \
  --watch \
  --interval-seconds 300
```

Run the deployed Supabase Edge synchronizer continuously without exposing any
secret to Flutter:

```bash
CRON_SECRET="<cron-secret>" \
python3 tool/livescore_ingest.py \
  --post-edge-url "https://<project-ref>.supabase.co/functions/v1/sync-livescore-football" \
  --resource-id livescore_world_cup_2026 \
  --include-scoreboard \
  --apply \
  --watch \
  --interval-seconds 300
```

The interval must respect the configured provider delay/rate limit. For UAT, use `--max-runs 1` or omit `--watch`.

LiveScore `Esd` fixture timestamps are interpreted in the configured resource
timezone, then stored as UTC `starts_at` values while preserving
`timezone_name`, `local_date`, and `local_time` for review. Keep the resource
timezone explicit when adding competitions outside the World Cup 2026 UTC feed.

Trigger the Supabase Edge synchronizer:

```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/sync-livescore-football" \
  -H "x-cron-secret: <cron-secret>" \
  -H "Content-Type: application/json" \
  -d '{"resource_id":"livescore_world_cup_2026","apply":true,"include_scoreboard":false}'
```

Trigger it through the standard scheduler runner:

```bash
tool/run_supabase_cron_job.sh sync-livescore-football
```

Validate the scheduler payload without credentials:

```bash
tool/run_supabase_cron_job.sh --dry-run sync-livescore-football
```

Check status:

```sql
select *
from public.get_football_official_resource_status()
where id = 'livescore_world_cup_2026';
```

Review placeholders:

```sql
select source_match_id, home_team_name, away_team_name, review_reason
from public.football_official_fixture_staging
where resource_id = 'livescore_world_cup_2026'
  and status = 'needs_review'
order by starts_at;
```

Do not curate all imported matches automatically. Only admin-selected fixtures should be activated for home display and pool eligibility.

Client apps must not call LiveScore directly and must not receive service-role keys. Flutter reads Supabase match views/RPCs; the sync jobs are server-side only.
