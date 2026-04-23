# Lean Prediction Import Workflow

## Supported Datasets

- `competitions.csv`
- `seasons.csv`
- `teams.csv`
- `team_aliases.csv`
- `matches.csv`
- `standings.csv`

## Expected Import Path

1. Prepare public-data extracts into CSV.
2. Normalize names as much as possible before import.
3. Import catalog datasets first:
   - competitions
   - seasons
   - teams
   - team aliases
4. Import matches.
5. Import standings snapshots.
6. Trigger feature refresh and prediction generation as needed.

## Preferred Loader For `Matches - ALL.csv`

For the consolidated historical fixtures file, use the repo ETL instead of raw row pushes:

```bash
python3 tool/import_matches_all_csv.py \
  --csv "/path/to/Matches - ALL.csv" \
  --db-url "$SUPABASE_DB_URL" \
  --apply
```

What this loader does:

- applies the seeded competition, season, team, and alias references used by the app
- repairs known competition ID aliases and season-key collisions
- collapses duplicate team-perspective match rows into one canonical match
- skips blank-team placeholders and stale scheduled rows that cannot drive predictions
- rebuilds `matches`, `standings`, `team_form_features`, and `predictions_engine_outputs`
- refreshes active competition and team catalog rows without touching unrelated user tables

Current `Matches - ALL.csv` normalization results:

- `12,992` source rows inspected
- `13` blank-team placeholders skipped
- `6` stale scheduled rows skipped
- `359` duplicate match groups collapsed
- `12,609` canonical matches loaded

## Edge Function

Use `supabase/functions/import-football-data`.

Keep the Edge Function for generic dataset imports. Use the local loader above when the source file is the consolidated `Matches - ALL.csv` export and you need seeded ID normalization.

Accepted payloads:

- `datasetType`
- `csv` or `rows`
- optional prediction-generation flag for relevant imports

Supported dataset types:

- `competitions`
- `seasons`
- `teams`
- `team_aliases`
- `matches`
- `standings`

## Validation Rules

- required fields must be present for the dataset type
- duplicate natural keys are prevented through upsert constraints
- team aliases are resolved before match and standings writes
- season references are created or reused through lean helpers
- import errors return actionable row-level feedback where possible

## Match Import Notes

Matches should carry:

- competition
- season
- stage
- round or matchday
- date
- home team
- away team
- scores where known
- status
- source attribution

`result_code` is derived from final scores and should not be treated as an operator-owned field.

## Standings Import Notes

Standings are snapshot-based. Each row should provide:

- competition
- season
- snapshot type
- snapshot date
- team
- position
- played / wins / draws / losses
- goals for / against
- points

## Recommended Operator Process

- keep raw source CSVs under internal archival storage
- preserve `source_name` and `source_url` on imported rows
- use aliases aggressively for clubs with common naming variants
- import small batches first when onboarding a new competition
- review `team_aliases` and `matches` after each new source is introduced
