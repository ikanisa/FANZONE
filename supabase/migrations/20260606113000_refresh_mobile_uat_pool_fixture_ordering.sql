-- Keep the deterministic mobile UAT pool visible in the app's normal
-- newest-first pool listing after idempotent fixture refreshes.

UPDATE public.match_pools
SET created_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
WHERE id = '00000000-0000-4000-8000-000000000401'
  AND metadata ->> 'mobile_smoke' = 'true';
