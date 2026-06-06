DO $$
DECLARE
  v_expectation record;
  v_rejected boolean := false;
BEGIN
  IF to_regprocedure('public.is_safe_public_url(text,boolean,boolean)') IS NULL THEN
    RAISE EXCEPTION 'Missing public URL safety helper';
  END IF;

  IF NOT public.is_safe_public_url('https://cdn.fanzone.example/crest.png', false, false) THEN
    RAISE EXCEPTION 'HTTPS public URL should be accepted';
  END IF;

  IF NOT public.is_safe_public_url('/pools/abc123', true, false) THEN
    RAISE EXCEPTION 'App-relative share URL should be accepted when explicitly allowed';
  END IF;

  IF NOT public.is_safe_public_url('fanzone://pools/abc123?source=share', false, true) THEN
    RAISE EXCEPTION 'FANZONE deep link should be accepted when explicitly allowed';
  END IF;

  IF public.is_safe_public_url('//cdn.example/image.png', true, false) THEN
    RAISE EXCEPTION 'Protocol-relative URL must be rejected';
  END IF;

  IF public.is_safe_public_url('javascript:alert(1)', false, false) THEN
    RAISE EXCEPTION 'JavaScript URL must be rejected';
  END IF;

  IF public.is_safe_public_url('https://cdn.example/bad image.png', false, false) THEN
    RAISE EXCEPTION 'Raw whitespace in URL must be rejected';
  END IF;

  FOR v_expectation IN
    SELECT *
    FROM (
      VALUES
        ('teams'::text, 'logo_url'::text, 'teams_logo_url_safe_public_url'::text),
        ('teams', 'crest_url', 'teams_crest_url_safe_public_url'),
        ('teams', 'cover_image_url', 'teams_cover_image_url_safe_public_url'),
        ('matches', 'source_url', 'matches_source_url_safe_public_url'),
        ('featured_events', 'logo_url', 'featured_events_logo_url_safe_public_url'),
        ('menu_items', 'image_url', 'menu_items_image_url_safe_public_url'),
        ('venues', 'website_url', 'venues_website_url_safe_public_url'),
        ('venues', 'logo_url', 'venues_logo_url_safe_public_url'),
        ('venues', 'cover_url', 'venues_cover_url_safe_public_url'),
        ('venues', 'revolut_link', 'venues_revolut_link_safe_public_url'),
        ('venues', 'ai_image_url', 'venues_ai_image_url_safe_public_url'),
        ('match_pools', 'share_url', 'match_pools_share_url_safe_public_url'),
        ('match_pools', 'social_card_url', 'match_pools_social_card_url_safe_public_url'),
        ('match_pools', 'deep_link_url', 'match_pools_deep_link_url_safe_public_url'),
        ('app_review_feedback', 'screenshot_url', 'app_review_feedback_screenshot_url_safe_public_url')
    ) AS expected(table_name, column_name, constraint_name)
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = v_expectation.table_name
        AND column_name = v_expectation.column_name
    ) THEN
      CONTINUE;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE connamespace = 'public'::regnamespace
        AND conname = v_expectation.constraint_name
    ) THEN
      RAISE EXCEPTION 'Missing public URL safety constraint: %', v_expectation.constraint_name;
    END IF;
  END LOOP;

  BEGIN
    INSERT INTO public.teams (id, name, logo_url)
    VALUES ('url-contract-invalid-team', 'URL Contract Invalid Team', 'javascript:alert(1)');
  EXCEPTION
    WHEN check_violation THEN
      v_rejected := true;
  END;

  IF NOT v_rejected THEN
    DELETE FROM public.teams WHERE id = 'url-contract-invalid-team';
    RAISE EXCEPTION 'teams.logo_url accepted an unsafe URL';
  END IF;
END;
$$;
