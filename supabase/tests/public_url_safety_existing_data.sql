DO $$
DECLARE
  v_unsafe jsonb;
  v_unvalidated jsonb;
BEGIN
  WITH checks AS (
    SELECT 'teams' AS table_name, 'logo_url' AS column_name,
      count(*) FILTER (WHERE NOT public.is_safe_public_url(logo_url, false, false)) AS unsafe_count
    FROM public.teams
    UNION ALL SELECT 'teams', 'crest_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(crest_url, false, false))
    FROM public.teams
    UNION ALL SELECT 'teams', 'cover_image_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(cover_image_url, false, false))
    FROM public.teams
    UNION ALL SELECT 'matches', 'source_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(source_url, false, false))
    FROM public.matches
    UNION ALL SELECT 'featured_events', 'logo_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(logo_url, false, false))
    FROM public.featured_events
    UNION ALL SELECT 'menu_items', 'image_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(image_url, false, false))
    FROM public.menu_items
    UNION ALL SELECT 'venues', 'website_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(website_url, false, false))
    FROM public.venues
    UNION ALL SELECT 'venues', 'logo_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(logo_url, false, false))
    FROM public.venues
    UNION ALL SELECT 'venues', 'cover_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(cover_url, false, false))
    FROM public.venues
    UNION ALL SELECT 'venues', 'revolut_link',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(revolut_link, false, false))
    FROM public.venues
    UNION ALL SELECT 'venues', 'ai_image_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(ai_image_url, false, false))
    FROM public.venues
    UNION ALL SELECT 'match_pools', 'share_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(share_url, true, false))
    FROM public.match_pools
    UNION ALL SELECT 'match_pools', 'social_card_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(social_card_url, false, false))
    FROM public.match_pools
    UNION ALL SELECT 'match_pools', 'deep_link_url',
      count(*) FILTER (WHERE NOT public.is_safe_public_url(deep_link_url, false, true))
    FROM public.match_pools
  )
  SELECT coalesce(jsonb_agg(to_jsonb(checks) ORDER BY table_name, column_name), '[]'::jsonb)
  INTO v_unsafe
  FROM checks
  WHERE unsafe_count > 0;

  IF jsonb_array_length(v_unsafe) > 0 THEN
    RAISE EXCEPTION 'Unsafe existing public URL rows found: %', v_unsafe;
  END IF;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'table_name', conrelid::regclass::text,
        'constraint_name', conname
      )
      ORDER BY conrelid::regclass::text, conname
    ),
    '[]'::jsonb
  )
  INTO v_unvalidated
  FROM pg_constraint
  WHERE connamespace = 'public'::regnamespace
    AND conname LIKE '%safe_public_url'
    AND NOT convalidated;

  IF jsonb_array_length(v_unvalidated) > 0 THEN
    RAISE EXCEPTION 'Public URL safety constraints are not validated: %', v_unvalidated;
  END IF;
END;
$$;
