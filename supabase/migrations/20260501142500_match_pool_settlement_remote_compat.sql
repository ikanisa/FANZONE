-- Remote compatibility shim for settlement rows created before the sports-bar
-- settlement/audit fields were added to the local clean baseline.

ALTER TABLE public.match_pool_settlements
  ADD COLUMN IF NOT EXISTS match_id text,
  ADD COLUMN IF NOT EXISTS error_message text,
  ADD COLUMN IF NOT EXISTS reversed_at timestamp with time zone;

UPDATE public.match_pool_settlements s
SET match_id = p.match_id
FROM public.match_pools p
WHERE s.pool_id = p.id
  AND s.match_id IS NULL;

CREATE INDEX IF NOT EXISTS match_pool_settlements_match_id_idx
ON public.match_pool_settlements (match_id);
