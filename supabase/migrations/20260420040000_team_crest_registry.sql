BEGIN;

CREATE TABLE IF NOT EXISTS public.team_crest_metadata (
  team_id text PRIMARY KEY REFERENCES public.teams(id) ON DELETE CASCADE,
  team_name text NOT NULL,
  competition text,
  country text,
  aliases text[] NOT NULL DEFAULT '{}'::text[],
  source_url text,
  source_domain text,
  remote_image_url text,
  image_url text,
  storage_bucket text,
  storage_path text,
  image_sha256 text,
  source_type text NOT NULL DEFAULT 'unknown'
    CHECK (source_type IN (
      'official_club',
      'official_federation',
      'official_competition',
      'trusted_reference',
      'unknown'
    )),
  confidence_score numeric(5,4),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN (
      'pending',
      'processing',
      'fetched',
      'low_confidence',
      'manual_review',
      'failed'
    )),
  validation_flags text[] NOT NULL DEFAULT '{}'::text[],
  validation_notes text,
  matched_name text,
  matched_alias text,
  match_reason text,
  model_name text,
  fetch_count integer NOT NULL DEFAULT 0,
  retry_count integer NOT NULL DEFAULT 0,
  last_attempt_at timestamptz,
  next_retry_at timestamptz,
  fetched_at timestamptz,
  stale_after timestamptz,
  applied_to_team boolean NOT NULL DEFAULT false,
  applied_at timestamptz,
  last_error text,
  source_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_team_crest_metadata_status_retry
  ON public.team_crest_metadata(status, next_retry_at);

CREATE INDEX IF NOT EXISTS idx_team_crest_metadata_stale_after
  ON public.team_crest_metadata(stale_after);

CREATE INDEX IF NOT EXISTS idx_team_crest_metadata_source_domain
  ON public.team_crest_metadata(source_domain);

CREATE TABLE IF NOT EXISTS public.team_crest_fetch_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id text NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  request_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  response_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'running'
    CHECK (status IN (
      'running',
      'completed',
      'low_confidence',
      'manual_review',
      'failed',
      'skipped'
    )),
  confidence_score numeric(5,4),
  source_url text,
  source_domain text,
  image_url text,
  model_name text,
  validation_flags text[] NOT NULL DEFAULT '{}'::text[],
  error_message text,
  started_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  finished_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_team_crest_fetch_runs_team_started
  ON public.team_crest_fetch_runs(team_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_team_crest_fetch_runs_status_started
  ON public.team_crest_fetch_runs(status, started_at DESC);

ALTER TABLE public.team_crest_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_crest_fetch_runs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.team_crest_metadata FROM anon, authenticated;
REVOKE ALL ON public.team_crest_fetch_runs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.team_crest_metadata TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.team_crest_fetch_runs TO service_role;

CREATE OR REPLACE VIEW public.team_crest_review_queue AS
SELECT
  meta.team_id,
  meta.team_name,
  meta.status,
  meta.confidence_score,
  meta.source_domain,
  meta.source_url,
  meta.image_url,
  meta.validation_flags,
  meta.validation_notes,
  meta.last_error,
  meta.updated_at,
  teams.country,
  teams.league_name
FROM public.team_crest_metadata AS meta
JOIN public.teams ON teams.id = meta.team_id
WHERE meta.status IN ('low_confidence', 'manual_review', 'failed')
ORDER BY meta.updated_at DESC;

REVOKE ALL ON public.team_crest_review_queue FROM anon, authenticated;
GRANT SELECT ON public.team_crest_review_queue TO service_role;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'team-crests',
  'team-crests',
  true,
  5242880,
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Public read team crests'
  ) THEN
    CREATE POLICY "Public read team crests"
      ON storage.objects
      FOR SELECT
      USING (bucket_id = 'team-crests');
  END IF;
END;
$$;

COMMIT;
