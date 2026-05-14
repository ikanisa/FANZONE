-- Browser-based Flutter review mirror feedback.
-- This is additive review tooling and does not alter product runtime tables.

CREATE TABLE IF NOT EXISTS public.app_review_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_slug text NOT NULL,
  environment text NOT NULL,
  git_branch text,
  git_commit text,
  reviewer_name text,
  device_preset text,
  started_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  completed_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.app_review_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_slug text NOT NULL,
  environment text NOT NULL DEFAULT 'staging',
  platform text NOT NULL DEFAULT 'web_review',
  route text NOT NULL,
  screen_name text,
  component_key text,
  viewport_width integer,
  viewport_height integer,
  device_preset text,
  x_position numeric,
  y_position numeric,
  comment text NOT NULL,
  severity text NOT NULL DEFAULT 'medium',
  status text NOT NULL DEFAULT 'open',
  reviewer_name text,
  reviewer_contact text,
  screenshot_url text,
  git_branch text,
  git_commit text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT app_review_comments_comment_not_blank
    CHECK (length(btrim(comment)) > 0),
  CONSTRAINT app_review_comments_severity_check
    CHECK (severity IN ('blocker', 'high', 'medium', 'low', 'polish')),
  CONSTRAINT app_review_comments_status_check
    CHECK (status IN ('open', 'accepted', 'fixed', 'rejected')),
  CONSTRAINT app_review_comments_platform_check
    CHECK (platform IN ('web_review')),
  CONSTRAINT app_review_comments_viewport_width_check
    CHECK (viewport_width IS NULL OR viewport_width > 0),
  CONSTRAINT app_review_comments_viewport_height_check
    CHECK (viewport_height IS NULL OR viewport_height > 0)
);

CREATE INDEX IF NOT EXISTS app_review_comments_app_env_status_idx
  ON public.app_review_comments (app_slug, environment, status, created_at DESC);

CREATE INDEX IF NOT EXISTS app_review_comments_route_idx
  ON public.app_review_comments (route, created_at DESC);

CREATE OR REPLACE FUNCTION public.set_app_review_comments_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_app_review_comments_updated_at
  ON public.app_review_comments;

CREATE TRIGGER set_app_review_comments_updated_at
BEFORE UPDATE ON public.app_review_comments
FOR EACH ROW
EXECUTE FUNCTION public.set_app_review_comments_updated_at();

ALTER TABLE public.app_review_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_review_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_review_sessions_insert_authenticated
  ON public.app_review_sessions;
CREATE POLICY app_review_sessions_insert_authenticated
  ON public.app_review_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (app_slug <> '' AND environment <> '');

DROP POLICY IF EXISTS app_review_sessions_select_authenticated
  ON public.app_review_sessions;
CREATE POLICY app_review_sessions_select_authenticated
  ON public.app_review_sessions
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS app_review_sessions_update_authenticated
  ON public.app_review_sessions;
CREATE POLICY app_review_sessions_update_authenticated
  ON public.app_review_sessions
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (app_slug <> '' AND environment <> '');

DROP POLICY IF EXISTS app_review_comments_insert_authenticated
  ON public.app_review_comments;
CREATE POLICY app_review_comments_insert_authenticated
  ON public.app_review_comments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    app_slug <> ''
    AND environment <> ''
    AND platform = 'web_review'
    AND length(btrim(comment)) > 0
  );

DROP POLICY IF EXISTS app_review_comments_select_authenticated
  ON public.app_review_comments;
CREATE POLICY app_review_comments_select_authenticated
  ON public.app_review_comments
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS app_review_comments_update_authenticated
  ON public.app_review_comments;
CREATE POLICY app_review_comments_update_authenticated
  ON public.app_review_comments
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (
    status IN ('open', 'accepted', 'fixed', 'rejected')
    AND severity IN ('blocker', 'high', 'medium', 'low', 'polish')
  );

REVOKE ALL ON public.app_review_sessions FROM PUBLIC, anon;
REVOKE ALL ON public.app_review_comments FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_app_review_comments_updated_at() FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE ON public.app_review_sessions
  TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.app_review_comments
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_app_review_comments_updated_at()
  TO service_role;

COMMENT ON TABLE public.app_review_comments IS
  'Review-only comments captured by the Flutter web review mirror. Deploy this surface against staging/review access control, not public production data.';

COMMENT ON TABLE public.app_review_sessions IS
  'Review-only browser sessions for the Flutter web review mirror.';
