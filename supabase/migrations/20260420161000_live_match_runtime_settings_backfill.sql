BEGIN;

ALTER TABLE public.match_sync_runtime_settings
  ADD COLUMN IF NOT EXISTS low_confidence_backoff_seconds integer NOT NULL DEFAULT 180
    CHECK (low_confidence_backoff_seconds BETWEEN 30 AND 7200),
  ADD COLUMN IF NOT EXISTS failed_backoff_seconds integer NOT NULL DEFAULT 300
    CHECK (failed_backoff_seconds BETWEEN 30 AND 14400),
  ADD COLUMN IF NOT EXISTS pending_request_timeout_seconds integer NOT NULL DEFAULT 180
    CHECK (pending_request_timeout_seconds BETWEEN 30 AND 3600);

UPDATE public.match_sync_runtime_settings
SET
  low_confidence_backoff_seconds = coalesce(low_confidence_backoff_seconds, 180),
  failed_backoff_seconds = coalesce(failed_backoff_seconds, 300),
  pending_request_timeout_seconds = coalesce(pending_request_timeout_seconds, 180),
  updated_at = timezone('utc', now());

COMMIT;
