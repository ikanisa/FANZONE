-- Keep production discovery free of UAT prediction pools.
-- Historical entries remain for audit/reconciliation, but open UAT pools must
-- not render in user-facing Arena/Home cards.

UPDATE public.match_pools
SET status = 'cancelled',
    updated_at = timezone('utc', now()),
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'disabled_reason', 'uat_pool_removed_from_production_discovery'
    )
WHERE status IN ('open', 'locked')
  AND (
    match_id LIKE 'uat-%'
    OR lower(coalesce(title, '')) LIKE '%uat%'
    OR coalesce(metadata ->> 'uat_fixture', 'false') = 'true'
  );

UPDATE public.venues
SET is_open = false,
    is_active = false,
    status = 'suspended',
    onboarding_status = 'draft',
    updated_at = timezone('utc', now()),
    features_json = coalesce(features_json, '{}'::jsonb) || jsonb_build_object(
      'disabled_reason', 'uat_venue_removed_from_production_discovery'
    )
WHERE id = '00000000-0000-4000-8000-000000000301'::uuid
   OR lower(coalesce(name, '')) LIKE '%uat%';

UPDATE public.tables
SET is_active = false,
    updated_at = timezone('utc', now())
WHERE venue_id IN (
  SELECT id
  FROM public.venues
  WHERE id = '00000000-0000-4000-8000-000000000301'::uuid
     OR lower(coalesce(name, '')) LIKE '%uat%'
);
