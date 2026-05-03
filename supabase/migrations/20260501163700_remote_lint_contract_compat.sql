-- Additive fixes for older remote projects discovered by live schema lint.
-- These align pool entry tracking, settlement states, and vector search
-- search_path behavior with the simplified sports-bar backend contract.

ALTER TABLE public.match_pool_entries
  ADD COLUMN IF NOT EXISTS source text DEFAULT 'direct' NOT NULL,
  ADD COLUMN IF NOT EXISTS invited_by_user_id uuid;

UPDATE public.match_pool_entries
SET source = COALESCE(NULLIF(metadata ->> 'source', ''), 'direct')
WHERE source IS NULL OR trim(source) = '';

UPDATE public.match_pool_entries
SET invited_by_user_id = (metadata ->> 'invited_by_user_id')::uuid
WHERE invited_by_user_id IS NULL
  AND (metadata ->> 'invited_by_user_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'match_pool_entries_source_check'
      AND conrelid = 'public.match_pool_entries'::regclass
  ) THEN
    ALTER TABLE public.match_pool_entries
      ADD CONSTRAINT match_pool_entries_source_check
      CHECK (source = ANY (ARRAY['direct'::text, 'invite_link'::text, 'venue_qr'::text, 'social_share'::text]))
      NOT VALID;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS match_pool_entries_invited_by_idx
  ON public.match_pool_entries (invited_by_user_id, created_at DESC)
  WHERE invited_by_user_id IS NOT NULL;

ALTER TYPE public.match_pool_settlement_status
  ADD VALUE IF NOT EXISTS 'pending' BEFORE 'running';

CREATE OR REPLACE VIEW public.pool_entries
WITH (security_invoker='true') AS
SELECT
  e.id,
  e.pool_id,
  e.camp_id,
  e.user_id,
  e.amount_fet AS stake_amount,
  e.status::text AS status,
  COALESCE(NULLIF(e.source, ''), NULLIF(e.metadata ->> 'source', ''), 'direct') AS source,
  COALESCE(
    e.invited_by_user_id,
    CASE
      WHEN (e.metadata ->> 'invited_by_user_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        THEN (e.metadata ->> 'invited_by_user_id')::uuid
      ELSE NULL::uuid
    END
  ) AS invited_by_user_id,
  e.created_at,
  e.updated_at
FROM public.match_pool_entries e;

COMMENT ON VIEW public.pool_entries IS
  'Canonical pool entry API over public.match_pool_entries, including invite source tracking.';

DO $$
BEGIN
  IF to_regtype('extensions.vector') IS NOT NULL
     AND to_regclass('public.legal_documents') IS NOT NULL THEN
    EXECUTE $fn$
      CREATE OR REPLACE FUNCTION public.match_legal_documents(
        query_embedding extensions.vector,
        match_count integer DEFAULT 8,
        filter_jurisdiction text DEFAULT NULL::text,
        filter_corpus text DEFAULT NULL::text,
        match_threshold double precision DEFAULT 0.5
      ) RETURNS TABLE(
        id text,
        content text,
        jurisdiction text,
        corpus text,
        document_type text,
        title text,
        language text,
        section text,
        metadata jsonb,
        similarity double precision
      )
      LANGUAGE plpgsql
      STABLE
      SET search_path TO 'public', 'extensions'
      AS $body$
      BEGIN
        RETURN QUERY
        SELECT
          ld.id,
          ld.content,
          ld.jurisdiction,
          ld.corpus,
          ld.document_type,
          ld.title,
          ld.language,
          ld.section,
          ld.metadata,
          (1 - (ld.embedding <=> query_embedding))::double precision AS similarity
        FROM public.legal_documents ld
        WHERE (filter_jurisdiction IS NULL OR ld.jurisdiction = filter_jurisdiction)
          AND (filter_corpus IS NULL OR ld.corpus = filter_corpus)
          AND (1 - (ld.embedding <=> query_embedding))::double precision > match_threshold
        ORDER BY ld.embedding <=> query_embedding ASC
        LIMIT match_count;
      END;
      $body$;
    $fn$;

    COMMENT ON FUNCTION public.match_legal_documents(extensions.vector, integer, text, text, double precision) IS
      'Legacy legal document vector search with explicit extensions search_path for pgvector operators.';
  END IF;
END;
$$;
