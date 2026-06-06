-- Validate public URL safety constraints after the linked-data audit proved the
-- existing rows are compatible. Keep each validation guarded so environments
-- with optional columns stay migration-compatible.

DO $$
DECLARE
  v_constraint text;
BEGIN
  FOR v_constraint IN
    SELECT conname
    FROM pg_constraint
    WHERE connamespace = 'public'::regnamespace
      AND conrelid = 'public.teams'::regclass
      AND conname IN (
        'teams_logo_url_safe_public_url',
        'teams_crest_url_safe_public_url',
        'teams_cover_image_url_safe_public_url'
      )
  LOOP
    EXECUTE format('ALTER TABLE public.teams VALIDATE CONSTRAINT %I', v_constraint);
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'matches_source_url_safe_public_url'
      AND conrelid = 'public.matches'::regclass
  ) THEN
    ALTER TABLE public.matches VALIDATE CONSTRAINT matches_source_url_safe_public_url;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'featured_events_logo_url_safe_public_url'
      AND conrelid = 'public.featured_events'::regclass
  ) THEN
    ALTER TABLE public.featured_events VALIDATE CONSTRAINT featured_events_logo_url_safe_public_url;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'menu_items_image_url_safe_public_url'
      AND conrelid = 'public.menu_items'::regclass
  ) THEN
    ALTER TABLE public.menu_items VALIDATE CONSTRAINT menu_items_image_url_safe_public_url;
  END IF;

  FOR v_constraint IN
    SELECT conname
    FROM pg_constraint
    WHERE connamespace = 'public'::regnamespace
      AND conrelid = 'public.venues'::regclass
      AND conname IN (
        'venues_website_url_safe_public_url',
        'venues_logo_url_safe_public_url',
        'venues_cover_url_safe_public_url',
        'venues_revolut_link_safe_public_url',
        'venues_ai_image_url_safe_public_url'
      )
  LOOP
    EXECUTE format('ALTER TABLE public.venues VALIDATE CONSTRAINT %I', v_constraint);
  END LOOP;

  FOR v_constraint IN
    SELECT conname
    FROM pg_constraint
    WHERE connamespace = 'public'::regnamespace
      AND conrelid = 'public.match_pools'::regclass
      AND conname IN (
        'match_pools_share_url_safe_public_url',
        'match_pools_social_card_url_safe_public_url',
        'match_pools_deep_link_url_safe_public_url'
      )
  LOOP
    EXECUTE format('ALTER TABLE public.match_pools VALIDATE CONSTRAINT %I', v_constraint);
  END LOOP;

  IF to_regclass('public.app_review_feedback') IS NOT NULL
     AND EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'app_review_feedback_screenshot_url_safe_public_url'
        AND conrelid = to_regclass('public.app_review_feedback')
    ) THEN
    ALTER TABLE public.app_review_feedback
      VALIDATE CONSTRAINT app_review_feedback_screenshot_url_safe_public_url;
  END IF;
END;
$$;
