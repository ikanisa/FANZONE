# LiveScore Football Ingest

FANZONE uses LiveScore as an authoritative provider feed for fixture, team, and crest/logo enrichment, but provider data is still staged before it becomes usable by the app.

The import flow is:

1. Fetch LiveScore fixtures and team image paths.
2. Stage rows in `football_official_fixture_staging`.
3. Resolve teams and write crest/logo source records in `football_team_asset_sources`.
4. Apply safe rows into the raw `matches` catalog.
5. Keep placeholder knockout fixtures as `needs_review`.
6. Admin curation still decides which matches appear publicly or become pool-eligible.

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
