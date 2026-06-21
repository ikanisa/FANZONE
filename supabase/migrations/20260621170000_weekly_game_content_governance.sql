-- Weekly AI game content governance and venue assignment controls.
-- Content is generated into review-only packs; only approved packs can be
-- assigned to venues.

CREATE TABLE IF NOT EXISTS public.game_content_generation_runs (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  week_start date NOT NULL,
  market_codes text[] NOT NULL DEFAULT ARRAY['MT', 'RW']::text[],
  target_pack_count integer NOT NULL DEFAULT 100,
  questions_per_pack integer NOT NULL DEFAULT 20,
  generation_model text,
  prompt text,
  status text NOT NULL DEFAULT 'draft',
  requested_by_admin_id uuid REFERENCES public.admin_users(id) ON DELETE SET NULL,
  approved_pack_count integer NOT NULL DEFAULT 0,
  generated_pack_count integer NOT NULL DEFAULT 0,
  error_message text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT game_content_generation_runs_markets_check
    CHECK (market_codes <@ ARRAY['MT', 'RW']::text[] AND cardinality(market_codes) > 0),
  CONSTRAINT game_content_generation_runs_target_check
    CHECK (target_pack_count BETWEEN 1 AND 100),
  CONSTRAINT game_content_generation_runs_questions_check
    CHECK (questions_per_pack = 20),
  CONSTRAINT game_content_generation_runs_status_check
    CHECK (status IN ('draft', 'queued', 'running', 'generated', 'partially_generated', 'failed', 'reviewed', 'retired'))
);

CREATE TABLE IF NOT EXISTS public.game_content_packs (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  generation_run_id uuid REFERENCES public.game_content_generation_runs(id) ON DELETE SET NULL,
  week_start date NOT NULL,
  template_id text NOT NULL REFERENCES public.game_templates(id) ON DELETE RESTRICT,
  market_code text NOT NULL,
  title text NOT NULL,
  questions jsonb NOT NULL,
  safety_labels text[] NOT NULL DEFAULT ARRAY[]::text[],
  status text NOT NULL DEFAULT 'generated_pending_review',
  review_notes text,
  reviewed_by_admin_id uuid REFERENCES public.admin_users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  approved_at timestamptz,
  retired_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT game_content_packs_market_check CHECK (market_code IN ('MT', 'RW')),
  CONSTRAINT game_content_packs_title_check CHECK (char_length(trim(title)) BETWEEN 4 AND 160),
  CONSTRAINT game_content_packs_questions_array_check CHECK (jsonb_typeof(questions) = 'array'),
  CONSTRAINT game_content_packs_questions_count_check CHECK (jsonb_array_length(questions) = 20),
  CONSTRAINT game_content_packs_status_check
    CHECK (status IN ('draft', 'generated_pending_review', 'approved', 'rejected', 'retired'))
);

CREATE INDEX IF NOT EXISTS game_content_packs_week_status_idx
  ON public.game_content_packs (week_start, market_code, template_id, status);

CREATE INDEX IF NOT EXISTS game_content_packs_run_idx
  ON public.game_content_packs (generation_run_id);

CREATE TABLE IF NOT EXISTS public.venue_game_assignments (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  venue_id uuid NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  pack_id uuid NOT NULL REFERENCES public.game_content_packs(id) ON DELETE RESTRICT,
  week_start date NOT NULL,
  assignment_seed text NOT NULL,
  assignment_rank integer NOT NULL,
  status text NOT NULL DEFAULT 'scheduled',
  overridden_by_admin_id uuid REFERENCES public.admin_users(id) ON DELETE SET NULL,
  override_reason text,
  published_at timestamptz,
  retired_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT venue_game_assignments_rank_check CHECK (assignment_rank > 0),
  CONSTRAINT venue_game_assignments_status_check
    CHECK (status IN ('scheduled', 'published', 'overridden', 'retired')),
  CONSTRAINT venue_game_assignments_unique_pack UNIQUE (venue_id, week_start, pack_id),
  CONSTRAINT venue_game_assignments_unique_rank UNIQUE (venue_id, week_start, assignment_rank)
);

CREATE INDEX IF NOT EXISTS venue_game_assignments_venue_week_idx
  ON public.venue_game_assignments (venue_id, week_start, status);

ALTER TABLE public.game_content_generation_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_content_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_game_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS game_content_generation_runs_admin_read ON public.game_content_generation_runs;
CREATE POLICY game_content_generation_runs_admin_read
ON public.game_content_generation_runs
FOR SELECT
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']));

DROP POLICY IF EXISTS game_content_generation_runs_admin_write ON public.game_content_generation_runs;
CREATE POLICY game_content_generation_runs_admin_write
ON public.game_content_generation_runs
FOR ALL
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['admin', 'super_admin']))
WITH CHECK (public.current_user_has_admin_role(ARRAY['admin', 'super_admin']));

DROP POLICY IF EXISTS game_content_packs_admin_read ON public.game_content_packs;
CREATE POLICY game_content_packs_admin_read
ON public.game_content_packs
FOR SELECT
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']));

DROP POLICY IF EXISTS game_content_packs_admin_write ON public.game_content_packs;
CREATE POLICY game_content_packs_admin_write
ON public.game_content_packs
FOR ALL
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['admin', 'super_admin']))
WITH CHECK (public.current_user_has_admin_role(ARRAY['admin', 'super_admin']));

DROP POLICY IF EXISTS game_content_packs_venue_read_approved ON public.game_content_packs;
CREATE POLICY game_content_packs_venue_read_approved
ON public.game_content_packs
FOR SELECT
TO authenticated
USING (
  status = 'approved'
  AND EXISTS (
    SELECT 1
    FROM public.venue_game_assignments vga
    WHERE vga.pack_id = game_content_packs.id
      AND public.venue_user_has_role(vga.venue_id)
  )
);

DROP POLICY IF EXISTS venue_game_assignments_admin_read ON public.venue_game_assignments;
CREATE POLICY venue_game_assignments_admin_read
ON public.venue_game_assignments
FOR SELECT
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']));

DROP POLICY IF EXISTS venue_game_assignments_admin_write ON public.venue_game_assignments;
CREATE POLICY venue_game_assignments_admin_write
ON public.venue_game_assignments
FOR ALL
TO authenticated
USING (public.current_user_has_admin_role(ARRAY['admin', 'super_admin']))
WITH CHECK (public.current_user_has_admin_role(ARRAY['admin', 'super_admin']));

DROP POLICY IF EXISTS venue_game_assignments_venue_read ON public.venue_game_assignments;
CREATE POLICY venue_game_assignments_venue_read
ON public.venue_game_assignments
FOR SELECT
TO authenticated
USING (public.venue_user_has_role(venue_id));

CREATE OR REPLACE VIEW public.admin_game_content_pack_summary AS
SELECT
  p.id,
  p.generation_run_id,
  p.week_start,
  p.template_id,
  gt.name AS template_name,
  p.market_code,
  p.title,
  p.status,
  jsonb_array_length(p.questions) AS question_count,
  p.safety_labels,
  p.review_notes,
  p.reviewed_at,
  p.approved_at,
  p.created_at,
  p.updated_at,
  COALESCE(assignments.assignment_count, 0) AS assignment_count
FROM public.game_content_packs p
JOIN public.game_templates gt ON gt.id = p.template_id
LEFT JOIN (
  SELECT pack_id, count(*)::integer AS assignment_count
  FROM public.venue_game_assignments
  GROUP BY pack_id
) assignments ON assignments.pack_id = p.id
WHERE public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin']);

CREATE OR REPLACE VIEW public.admin_venue_game_assignment_summary AS
SELECT
  a.id,
  a.venue_id,
  v.name AS venue_name,
  v.country_code AS market_code,
  a.pack_id,
  p.title AS pack_title,
  p.template_id,
  gt.name AS template_name,
  a.week_start,
  a.assignment_rank,
  a.status,
  a.assignment_seed,
  a.override_reason,
  a.published_at,
  a.created_at,
  a.updated_at
FROM public.venue_game_assignments a
JOIN public.venues v ON v.id = a.venue_id
JOIN public.game_content_packs p ON p.id = a.pack_id
JOIN public.game_templates gt ON gt.id = p.template_id
WHERE public.current_user_has_admin_role(ARRAY['moderator', 'admin', 'super_admin'])
   OR public.venue_user_has_role(a.venue_id);

CREATE OR REPLACE FUNCTION public.admin_create_game_content_run(
  p_week_start date,
  p_market_codes text[] DEFAULT ARRAY['MT', 'RW']::text[],
  p_target_pack_count integer DEFAULT 100,
  p_questions_per_pack integer DEFAULT 20,
  p_generation_model text DEFAULT NULL,
  p_prompt text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS public.game_content_generation_runs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_run public.game_content_generation_runs%ROWTYPE;
  v_markets text[] := COALESCE(p_market_codes, ARRAY['MT', 'RW']::text[]);
BEGIN
  SELECT id INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF p_week_start IS NULL THEN
    RAISE EXCEPTION 'Week start is required';
  END IF;

  IF NOT (v_markets <@ ARRAY['MT', 'RW']::text[]) OR cardinality(v_markets) = 0 THEN
    RAISE EXCEPTION 'Only Malta (MT) and Rwanda (RW) markets are supported';
  END IF;

  INSERT INTO public.game_content_generation_runs (
    week_start,
    market_codes,
    target_pack_count,
    questions_per_pack,
    generation_model,
    prompt,
    status,
    requested_by_admin_id,
    metadata
  )
  VALUES (
    p_week_start,
    v_markets,
    COALESCE(p_target_pack_count, 100),
    COALESCE(p_questions_per_pack, 20),
    NULLIF(trim(COALESCE(p_generation_model, '')), ''),
    NULLIF(trim(COALESCE(p_prompt, '')), ''),
    'queued',
    v_actor_admin_id,
    COALESCE(p_metadata, '{}'::jsonb)
  )
  RETURNING * INTO v_run;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    after_state,
    metadata
  )
  VALUES (
    v_actor_admin_id,
    'create_game_content_run',
    'games',
    'game_content_generation_run',
    v_run.id::text,
    to_jsonb(v_run),
    jsonb_build_object('week_start', p_week_start, 'market_codes', v_markets)
  );

  RETURN v_run;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_upsert_game_content_pack(
  p_run_id uuid,
  p_template_id text,
  p_market_code text,
  p_title text,
  p_questions jsonb,
  p_status text DEFAULT 'generated_pending_review',
  p_safety_labels text[] DEFAULT ARRAY[]::text[],
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS public.game_content_packs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_run public.game_content_generation_runs%ROWTYPE;
  v_pack public.game_content_packs%ROWTYPE;
  v_status text := COALESCE(NULLIF(trim(p_status), ''), 'generated_pending_review');
BEGIN
  SELECT id INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  SELECT * INTO v_run
  FROM public.game_content_generation_runs
  WHERE id = p_run_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Generation run not found';
  END IF;

  IF v_status NOT IN ('draft', 'generated_pending_review', 'rejected') THEN
    RAISE EXCEPTION 'Packs must be reviewed before approval';
  END IF;

  IF p_market_code NOT IN ('MT', 'RW') THEN
    RAISE EXCEPTION 'Only Malta (MT) and Rwanda (RW) markets are supported';
  END IF;

  IF jsonb_typeof(p_questions) <> 'array' OR jsonb_array_length(p_questions) <> v_run.questions_per_pack THEN
    RAISE EXCEPTION 'A generated pack must contain exactly % questions', v_run.questions_per_pack;
  END IF;

  INSERT INTO public.game_content_packs (
    generation_run_id,
    week_start,
    template_id,
    market_code,
    title,
    questions,
    safety_labels,
    status,
    metadata
  )
  VALUES (
    p_run_id,
    v_run.week_start,
    p_template_id,
    upper(trim(p_market_code)),
    trim(p_title),
    p_questions,
    COALESCE(p_safety_labels, ARRAY[]::text[]),
    v_status,
    COALESCE(p_metadata, '{}'::jsonb)
  )
  RETURNING * INTO v_pack;

  UPDATE public.game_content_generation_runs
  SET generated_pack_count = (
        SELECT count(*)::integer
        FROM public.game_content_packs
        WHERE generation_run_id = p_run_id
      ),
      status = 'generated',
      updated_at = timezone('utc', now())
  WHERE id = p_run_id;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    after_state,
    metadata
  )
  VALUES (
    v_actor_admin_id,
    'upsert_game_content_pack',
    'games',
    'game_content_pack',
    v_pack.id::text,
    to_jsonb(v_pack),
    jsonb_build_object('run_id', p_run_id)
  );

  RETURN v_pack;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_game_content_pack_status(
  p_pack_id uuid,
  p_status text,
  p_review_notes text DEFAULT NULL
) RETURNS public.game_content_packs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_before public.game_content_packs%ROWTYPE;
  v_pack public.game_content_packs%ROWTYPE;
  v_status text := lower(trim(COALESCE(p_status, '')));
BEGIN
  SELECT id INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF v_status NOT IN ('generated_pending_review', 'approved', 'rejected', 'retired') THEN
    RAISE EXCEPTION 'Invalid pack status';
  END IF;

  SELECT * INTO v_before
  FROM public.game_content_packs
  WHERE id = p_pack_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Game content pack not found';
  END IF;

  UPDATE public.game_content_packs
  SET status = v_status,
      review_notes = NULLIF(trim(COALESCE(p_review_notes, '')), ''),
      reviewed_by_admin_id = v_actor_admin_id,
      reviewed_at = timezone('utc', now()),
      approved_at = CASE WHEN v_status = 'approved' THEN timezone('utc', now()) ELSE approved_at END,
      retired_at = CASE WHEN v_status = 'retired' THEN timezone('utc', now()) ELSE retired_at END,
      updated_at = timezone('utc', now())
  WHERE id = p_pack_id
  RETURNING * INTO v_pack;

  IF v_pack.generation_run_id IS NOT NULL THEN
    UPDATE public.game_content_generation_runs
    SET approved_pack_count = (
          SELECT count(*)::integer
          FROM public.game_content_packs
          WHERE generation_run_id = v_pack.generation_run_id
            AND status = 'approved'
        ),
        status = CASE
          WHEN EXISTS (
            SELECT 1
            FROM public.game_content_packs
            WHERE generation_run_id = v_pack.generation_run_id
              AND status IN ('generated_pending_review', 'draft')
          ) THEN status
          ELSE 'reviewed'
        END,
        updated_at = timezone('utc', now())
    WHERE id = v_pack.generation_run_id;
  END IF;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  )
  VALUES (
    v_actor_admin_id,
    'set_game_content_pack_status',
    'games',
    'game_content_pack',
    p_pack_id::text,
    to_jsonb(v_before),
    to_jsonb(v_pack),
    jsonb_build_object('status', v_status)
  );

  RETURN v_pack;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_assign_weekly_game_packs(
  p_week_start date,
  p_market_codes text[] DEFAULT ARRAY['MT', 'RW']::text[],
  p_packs_per_venue integer DEFAULT 3,
  p_seed text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_seed text := COALESCE(NULLIF(trim(p_seed), ''), 'weekly-games-' || p_week_start::text);
  v_markets text[] := COALESCE(p_market_codes, ARRAY['MT', 'RW']::text[]);
  v_inserted integer := 0;
  v_replaced integer := 0;
BEGIN
  SELECT id INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF p_week_start IS NULL THEN
    RAISE EXCEPTION 'Week start is required';
  END IF;

  IF COALESCE(p_packs_per_venue, 0) < 1 OR p_packs_per_venue > 10 THEN
    RAISE EXCEPTION 'Packs per venue must be between 1 and 10';
  END IF;

  IF NOT (v_markets <@ ARRAY['MT', 'RW']::text[]) OR cardinality(v_markets) = 0 THEN
    RAISE EXCEPTION 'Only Malta (MT) and Rwanda (RW) markets are supported';
  END IF;

  UPDATE public.venue_game_assignments
  SET status = 'overridden',
      overridden_by_admin_id = v_actor_admin_id,
      override_reason = 'Replaced by weekly random assignment run',
      retired_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  WHERE week_start = p_week_start
    AND status IN ('scheduled', 'published')
    AND venue_id IN (
      SELECT id
      FROM public.venues
      WHERE country_code = ANY(v_markets)
        AND is_active = true
    );

  GET DIAGNOSTICS v_replaced = ROW_COUNT;

  WITH eligible_venues AS (
    SELECT id, country_code
    FROM public.venues
    WHERE is_active = true
      AND country_code = ANY(v_markets)
  ),
  ranked_packs AS (
    SELECT
      v.id AS venue_id,
      p.id AS pack_id,
      row_number() OVER (
        PARTITION BY v.id
        ORDER BY md5(v_seed || ':' || v.id::text || ':' || p.id::text)
      ) AS assignment_rank
    FROM eligible_venues v
    JOIN public.game_content_packs p
      ON p.week_start = p_week_start
     AND p.market_code = v.country_code
     AND p.status = 'approved'
  )
  INSERT INTO public.venue_game_assignments (
    venue_id,
    pack_id,
    week_start,
    assignment_seed,
    assignment_rank,
    status,
    metadata
  )
  SELECT
    venue_id,
    pack_id,
    p_week_start,
    v_seed,
    assignment_rank,
    'scheduled',
    jsonb_build_object('assigned_by', 'admin_assign_weekly_game_packs')
  FROM ranked_packs
  WHERE assignment_rank <= p_packs_per_venue
  ON CONFLICT (venue_id, week_start, pack_id) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    after_state,
    metadata
  )
  VALUES (
    v_actor_admin_id,
    'assign_weekly_game_packs',
    'games',
    'venue_game_assignments',
    p_week_start::text,
    jsonb_build_object('inserted', v_inserted, 'replaced', v_replaced),
    jsonb_build_object('market_codes', v_markets, 'packs_per_venue', p_packs_per_venue, 'seed', v_seed)
  );

  RETURN jsonb_build_object(
    'week_start', p_week_start,
    'market_codes', v_markets,
    'packs_per_venue', p_packs_per_venue,
    'seed', v_seed,
    'inserted', v_inserted,
    'replaced', v_replaced
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_override_venue_game_assignment(
  p_assignment_id uuid,
  p_status text,
  p_reason text DEFAULT NULL
) RETURNS public.venue_game_assignments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_actor_user_id uuid := public.require_active_admin_user();
  v_actor_admin_id uuid;
  v_before public.venue_game_assignments%ROWTYPE;
  v_assignment public.venue_game_assignments%ROWTYPE;
  v_status text := lower(trim(COALESCE(p_status, '')));
BEGIN
  SELECT id INTO v_actor_admin_id
  FROM public.admin_users
  WHERE user_id = v_actor_user_id
    AND is_active = true
  LIMIT 1;

  IF v_status NOT IN ('scheduled', 'published', 'overridden', 'retired') THEN
    RAISE EXCEPTION 'Invalid assignment status';
  END IF;

  SELECT * INTO v_before
  FROM public.venue_game_assignments
  WHERE id = p_assignment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assignment not found';
  END IF;

  UPDATE public.venue_game_assignments
  SET status = v_status,
      overridden_by_admin_id = CASE WHEN v_status IN ('overridden', 'retired') THEN v_actor_admin_id ELSE overridden_by_admin_id END,
      override_reason = NULLIF(trim(COALESCE(p_reason, '')), ''),
      published_at = CASE WHEN v_status = 'published' THEN timezone('utc', now()) ELSE published_at END,
      retired_at = CASE WHEN v_status = 'retired' THEN timezone('utc', now()) ELSE retired_at END,
      updated_at = timezone('utc', now())
  WHERE id = p_assignment_id
  RETURNING * INTO v_assignment;

  INSERT INTO public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  )
  VALUES (
    v_actor_admin_id,
    'override_venue_game_assignment',
    'games',
    'venue_game_assignment',
    p_assignment_id::text,
    to_jsonb(v_before),
    to_jsonb(v_assignment),
    jsonb_build_object('status', v_status)
  );

  RETURN v_assignment;
END;
$$;

REVOKE ALL ON TABLE public.game_content_generation_runs FROM PUBLIC;
REVOKE ALL ON TABLE public.game_content_packs FROM PUBLIC;
REVOKE ALL ON TABLE public.venue_game_assignments FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE ON public.game_content_generation_runs TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.game_content_packs TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.venue_game_assignments TO authenticated, service_role;
GRANT SELECT ON public.admin_game_content_pack_summary TO authenticated, service_role;
GRANT SELECT ON public.admin_venue_game_assignment_summary TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_create_game_content_run(date, text[], integer, integer, text, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_upsert_game_content_pack(uuid, text, text, text, jsonb, text, text[], jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_game_content_pack_status(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_assign_weekly_game_packs(date, text[], integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_override_venue_game_assignment(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_game_content_run(date, text[], integer, integer, text, text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_game_content_pack(uuid, text, text, text, jsonb, text, text[], jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_game_content_pack_status(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_assign_weekly_game_packs(date, text[], integer, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_override_venue_game_assignment(uuid, text, text) TO authenticated, service_role;

COMMENT ON TABLE public.game_content_generation_runs IS
  'Weekly AI game pack generation runs. Target release volume is 100 packs per week with 20 questions each.';
COMMENT ON TABLE public.game_content_packs IS
  'Review-gated generated game packs for Malta and Rwanda. Approved packs can be assigned to venues.';
COMMENT ON TABLE public.venue_game_assignments IS
  'Deterministic random weekly game pack assignments per venue/bar, with admin override and audit state.';
