# Team Crest Ingestion

## Purpose

`supabase/functions/gemini-team-crests` resolves the most likely official crest or logo for a football team by using Gemini with:

- Grounding with Google Search
- URL Context
- Structured JSON output

The function prefers official club and federation sources, mirrors accepted images into Supabase Storage, stores the current metadata in Postgres, and logs every fetch run for audit and manual review.

## Inputs

Single-team request:

```json
{
  "team_id": "arsenal",
  "team_name": "Arsenal FC",
  "competition": "Premier League",
  "country": "England",
  "aliases": ["Arsenal", "The Gunners"]
}
```

Batch request:

```json
{
  "teams": [
    {
      "team_id": "arsenal",
      "team_name": "Arsenal FC",
      "competition": "Premier League",
      "country": "England",
      "aliases": ["Arsenal", "The Gunners"]
    },
    {
      "team_id": "juventus",
      "team_name": "Juventus",
      "competition": "Serie A",
      "country": "Italy",
      "aliases": ["Juve"]
    }
  ],
  "force": false,
  "apply_to_team": true,
  "refresh_if_older_than_hours": 720,
  "delay_ms": 500
}
```

## Output

Each result returns:

- `team_id`
- `team_name`
- `source_url`
- `image_url`
- `source_domain`
- `confidence_score`
- `fetched_at`
- `status`

## Storage layout

- Metadata table: `public.team_crest_metadata`
- Run log table: `public.team_crest_fetch_runs`
- Manual review view: `public.team_crest_review_queue`
- Storage bucket: `team-crests`
- Storage object path: `teams/<team_id>/crest-<sha256>.<ext>`

## Confidence rules

- Official club sources start with the highest base confidence.
- Federation and competition sources are next.
- Trusted reference sources are accepted only as fallback.
- Confidence increases when:
  - the matched team name strongly overlaps with the requested team or aliases
  - the competition/country are confirmed
  - the source and image URLs appear in Gemini grounding metadata
  - the image is a valid retrievable asset
- Confidence drops when:
  - the name match is weak
  - the source is not grounded
  - the domain is an untrusted fallback
  - the asset is suspiciously small or looks like the wrong type of page

Thresholds:

- `>= 0.85`: `fetched`
- `0.65 - 0.8499`: `low_confidence`
- `< 0.65`: `manual_review`
- hard validation failures: `failed`

## Update rules

- The function is idempotent for repeated fetches of the same image content.
- Images are hashed with SHA-256.
- If the same image hash is already stored for the team, the existing stored asset is reused.
- `teams.crest_url` and `teams.logo_url` are only updated automatically when:
  - the new result is `fetched`
  - the team row is currently blank, or
  - the current value matches the previous automated crest URL, or
  - `force=true`

This avoids overwriting manual or externally managed crest URLs by accident.

## Retry strategy

- `failed` results use exponential backoff starting at 6 hours and capped at 7 days.
- `low_confidence` and `manual_review` results are retried after 7 days unless manually forced sooner.
- `fetched` results are refreshed based on source quality:
  - official club: 90 days
  - official federation/competition: 60 days
  - trusted reference: 30 days

## Auth

The function accepts either:

- service-role bearer auth
- `x-team-crest-sync-secret`

## Required environment variables

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`

Optional:

- `GEMINI_MODEL`
- `TEAM_CREST_SYNC_SECRET`
- `TEAM_CREST_BUCKET`

