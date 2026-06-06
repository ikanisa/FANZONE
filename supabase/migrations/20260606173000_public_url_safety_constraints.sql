-- Additive public URL hardening for externally sourced and generated media/link
-- fields. Constraints are NOT VALID so existing rows can be audited separately,
-- while new writes and updates are protected immediately.

CREATE OR REPLACE FUNCTION public.is_safe_public_url(
  p_value text,
  p_allow_relative boolean DEFAULT false,
  p_allow_deep_link boolean DEFAULT false
) RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_value text := btrim(coalesce(p_value, ''));
BEGIN
  IF v_value = '' THEN
    RETURN true;
  END IF;

  IF length(v_value) > 2048 THEN
    RETURN false;
  END IF;

  IF v_value ~ '[[:cntrl:][:space:]\\]' THEN
    RETURN false;
  END IF;

  IF p_allow_relative
     AND v_value LIKE '/%'
     AND v_value NOT LIKE '//%' THEN
    RETURN true;
  END IF;

  IF p_allow_deep_link
     AND v_value ~* '^fanzone://[A-Za-z0-9][A-Za-z0-9._~:/?#[\]@!$&''()*+,;=%-]*$' THEN
    RETURN true;
  END IF;

  RETURN v_value ~* '^https://[A-Za-z0-9][A-Za-z0-9.-]*(?::[0-9]{1,5})?(?:[/?#].*)?$';
END;
$$;

COMMENT ON FUNCTION public.is_safe_public_url(text, boolean, boolean) IS
  'Allows blank/null, HTTPS public URLs, optional app-relative paths, and optional fanzone:// deep links. Rejects raw whitespace, control characters, backslashes, protocol-relative URLs, and non-public schemes.';

DO $$
BEGIN
  IF to_regclass('public.teams') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'teams_logo_url_safe_public_url') THEN
      ALTER TABLE public.teams
        ADD CONSTRAINT teams_logo_url_safe_public_url
        CHECK (public.is_safe_public_url(logo_url, false, false)) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'teams_crest_url_safe_public_url') THEN
      ALTER TABLE public.teams
        ADD CONSTRAINT teams_crest_url_safe_public_url
        CHECK (public.is_safe_public_url(crest_url, false, false)) NOT VALID;
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'teams'
        AND column_name = 'cover_image_url'
    ) AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'teams_cover_image_url_safe_public_url') THEN
      ALTER TABLE public.teams
        ADD CONSTRAINT teams_cover_image_url_safe_public_url
        CHECK (public.is_safe_public_url(cover_image_url, false, false)) NOT VALID;
    END IF;
  END IF;

  IF to_regclass('public.matches') IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'matches_source_url_safe_public_url') THEN
    ALTER TABLE public.matches
      ADD CONSTRAINT matches_source_url_safe_public_url
      CHECK (public.is_safe_public_url(source_url, false, false)) NOT VALID;
  END IF;

  IF to_regclass('public.featured_events') IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'featured_events_logo_url_safe_public_url') THEN
    ALTER TABLE public.featured_events
      ADD CONSTRAINT featured_events_logo_url_safe_public_url
      CHECK (public.is_safe_public_url(logo_url, false, false)) NOT VALID;
  END IF;

  IF to_regclass('public.menu_items') IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'menu_items_image_url_safe_public_url') THEN
    ALTER TABLE public.menu_items
      ADD CONSTRAINT menu_items_image_url_safe_public_url
      CHECK (public.is_safe_public_url(image_url, false, false)) NOT VALID;
  END IF;

  IF to_regclass('public.venues') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'venues_website_url_safe_public_url') THEN
      ALTER TABLE public.venues
        ADD CONSTRAINT venues_website_url_safe_public_url
        CHECK (public.is_safe_public_url(website_url, false, false)) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'venues_logo_url_safe_public_url') THEN
      ALTER TABLE public.venues
        ADD CONSTRAINT venues_logo_url_safe_public_url
        CHECK (public.is_safe_public_url(logo_url, false, false)) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'venues_cover_url_safe_public_url') THEN
      ALTER TABLE public.venues
        ADD CONSTRAINT venues_cover_url_safe_public_url
        CHECK (public.is_safe_public_url(cover_url, false, false)) NOT VALID;
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'venues'
        AND column_name = 'revolut_link'
    ) AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'venues_revolut_link_safe_public_url') THEN
      ALTER TABLE public.venues
        ADD CONSTRAINT venues_revolut_link_safe_public_url
        CHECK (public.is_safe_public_url(revolut_link, false, false)) NOT VALID;
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'venues'
        AND column_name = 'ai_image_url'
    ) AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'venues_ai_image_url_safe_public_url') THEN
      ALTER TABLE public.venues
        ADD CONSTRAINT venues_ai_image_url_safe_public_url
        CHECK (public.is_safe_public_url(ai_image_url, false, false)) NOT VALID;
    END IF;
  END IF;

  IF to_regclass('public.match_pools') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'match_pools_share_url_safe_public_url') THEN
      ALTER TABLE public.match_pools
        ADD CONSTRAINT match_pools_share_url_safe_public_url
        CHECK (public.is_safe_public_url(share_url, true, false)) NOT VALID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'match_pools_social_card_url_safe_public_url') THEN
      ALTER TABLE public.match_pools
        ADD CONSTRAINT match_pools_social_card_url_safe_public_url
        CHECK (public.is_safe_public_url(social_card_url, false, false)) NOT VALID;
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'match_pools'
        AND column_name = 'deep_link_url'
    ) AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'match_pools_deep_link_url_safe_public_url') THEN
      ALTER TABLE public.match_pools
        ADD CONSTRAINT match_pools_deep_link_url_safe_public_url
        CHECK (public.is_safe_public_url(deep_link_url, false, true)) NOT VALID;
    END IF;
  END IF;

  IF to_regclass('public.app_review_feedback') IS NOT NULL
     AND EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'app_review_feedback'
        AND column_name = 'screenshot_url'
    ) AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_review_feedback_screenshot_url_safe_public_url') THEN
    ALTER TABLE public.app_review_feedback
      ADD CONSTRAINT app_review_feedback_screenshot_url_safe_public_url
      CHECK (public.is_safe_public_url(screenshot_url, false, false)) NOT VALID;
  END IF;
END;
$$;
