-- Customer-to-venue chat threads.
-- Clients read venue-scoped threads/messages through RLS and write only through
-- audited RPCs so multi-row chat mutations stay server-validated.

CREATE TABLE IF NOT EXISTS public.venue_chat_threads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id uuid NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  customer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  support_request_id uuid REFERENCES public.venue_support_requests(id) ON DELETE SET NULL,
  topic text NOT NULL DEFAULT 'general',
  subject text,
  status text NOT NULL DEFAULT 'open',
  assigned_to uuid REFERENCES auth.users(id),
  resolution_notes text,
  last_message_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  closed_at timestamptz,
  closed_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT venue_chat_threads_topic_check CHECK (
    topic IN ('general', 'accessibility', 'venue', 'order', 'payment', 'safety')
  ),
  CONSTRAINT venue_chat_threads_status_check CHECK (
    status IN ('open', 'in_review', 'resolved', 'closed', 'cancelled')
  ),
  CONSTRAINT venue_chat_threads_resolution_check CHECK (
    (status IN ('open', 'in_review') AND closed_at IS NULL)
    OR (status IN ('resolved', 'closed', 'cancelled'))
  )
);

CREATE TABLE IF NOT EXISTS public.venue_chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES public.venue_chat_threads(id) ON DELETE CASCADE,
  venue_id uuid NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  sender_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  sender_role text NOT NULL,
  body text NOT NULL,
  message_type text NOT NULL DEFAULT 'text',
  moderation_status text NOT NULL DEFAULT 'visible',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT venue_chat_messages_sender_role_check CHECK (
    sender_role IN ('customer', 'venue_staff', 'admin', 'system')
  ),
  CONSTRAINT venue_chat_messages_type_check CHECK (
    message_type IN ('text', 'system')
  ),
  CONSTRAINT venue_chat_messages_moderation_check CHECK (
    moderation_status IN ('visible', 'hidden', 'flagged')
  ),
  CONSTRAINT venue_chat_messages_body_length_check CHECK (
    char_length(trim(body)) BETWEEN 1 AND 2000
  )
);

CREATE INDEX IF NOT EXISTS idx_venue_chat_threads_customer
  ON public.venue_chat_threads (customer_user_id, last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_venue_chat_threads_venue_status
  ON public.venue_chat_threads (venue_id, status, last_message_at DESC);

CREATE INDEX IF NOT EXISTS idx_venue_chat_threads_order
  ON public.venue_chat_threads (order_id)
  WHERE order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_venue_chat_threads_support_request
  ON public.venue_chat_threads (support_request_id)
  WHERE support_request_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_venue_chat_messages_thread
  ON public.venue_chat_messages (thread_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_venue_chat_messages_venue
  ON public.venue_chat_messages (venue_id, created_at DESC);

ALTER TABLE public.venue_chat_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Customers and venue operators read chat threads"
  ON public.venue_chat_threads;
CREATE POLICY "Customers and venue operators read chat threads"
  ON public.venue_chat_threads
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = customer_user_id
    OR public.is_admin_manager(auth.uid())
    OR public.venue_user_has_role(venue_id)
  );

DROP POLICY IF EXISTS "Customers and venue operators read chat messages"
  ON public.venue_chat_messages;
CREATE POLICY "Customers and venue operators read chat messages"
  ON public.venue_chat_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.venue_chat_threads t
      WHERE t.id = venue_chat_messages.thread_id
        AND (
          t.customer_user_id = auth.uid()
          OR public.is_admin_manager(auth.uid())
          OR public.venue_user_has_role(t.venue_id)
        )
    )
  );

CREATE OR REPLACE FUNCTION public.create_venue_chat_thread(
  p_venue_id uuid,
  p_initial_message text,
  p_topic text DEFAULT 'general',
  p_subject text DEFAULT NULL::text,
  p_order_id uuid DEFAULT NULL::uuid,
  p_support_request_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_thread public.venue_chat_threads%ROWTYPE;
  v_message public.venue_chat_messages%ROWTYPE;
  v_order record;
  v_support record;
  v_body text := trim(coalesce(p_initial_message, ''));
  v_topic text := lower(trim(coalesce(p_topic, 'general')));
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Sign in to start venue chat';
  END IF;

  IF char_length(v_body) NOT BETWEEN 1 AND 2000 THEN
    RAISE EXCEPTION 'Chat message must be between 1 and 2000 characters';
  END IF;

  IF v_topic NOT IN ('general', 'accessibility', 'venue', 'order', 'payment', 'safety') THEN
    RAISE EXCEPTION 'Unsupported chat topic';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.venues v
    WHERE v.id = p_venue_id
      AND coalesce(v.is_active, true) = true
      AND coalesce(v.status, 'active') <> 'suspended'
  ) THEN
    RAISE EXCEPTION 'Venue is unavailable for chat';
  END IF;

  IF p_order_id IS NOT NULL THEN
    SELECT o.venue_id, o.user_id
    INTO v_order
    FROM public.orders o
    WHERE o.id = p_order_id;

    IF v_order IS NULL THEN
      RAISE EXCEPTION 'Order not found for chat';
    END IF;
    IF v_order.venue_id IS DISTINCT FROM p_venue_id
      OR v_order.user_id IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION 'Only the order customer can attach this order to chat';
    END IF;
  END IF;

  IF p_support_request_id IS NOT NULL THEN
    SELECT r.venue_id, r.user_id
    INTO v_support
    FROM public.venue_support_requests r
    WHERE r.id = p_support_request_id;

    IF v_support IS NULL THEN
      RAISE EXCEPTION 'Support request not found for chat';
    END IF;
    IF v_support.venue_id IS DISTINCT FROM p_venue_id
      OR v_support.user_id IS DISTINCT FROM v_actor THEN
      RAISE EXCEPTION 'Only the requester can attach this support request to chat';
    END IF;
  END IF;

  INSERT INTO public.venue_chat_threads (
    venue_id,
    customer_user_id,
    order_id,
    support_request_id,
    topic,
    subject,
    status
  )
  VALUES (
    p_venue_id,
    v_actor,
    p_order_id,
    p_support_request_id,
    v_topic,
    nullif(trim(coalesce(p_subject, '')), ''),
    'open'
  )
  RETURNING * INTO v_thread;

  INSERT INTO public.venue_chat_messages (
    thread_id,
    venue_id,
    sender_user_id,
    sender_role,
    body
  )
  VALUES (
    v_thread.id,
    p_venue_id,
    v_actor,
    'customer',
    v_body
  )
  RETURNING * INTO v_message;

  PERFORM public.sports_bar_write_audit(
    'venue_chat_thread_created',
    'venue_chat_thread',
    v_thread.id::text,
    NULL::jsonb,
    jsonb_build_object(
      'venue_id', v_thread.venue_id,
      'customer_user_id', v_thread.customer_user_id,
      'topic', v_thread.topic,
      'order_id', v_thread.order_id,
      'support_request_id', v_thread.support_request_id
    ),
    v_actor
  );

  RETURN jsonb_build_object(
    'thread', to_jsonb(v_thread),
    'message', to_jsonb(v_message)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.send_venue_chat_message(
  p_thread_id uuid,
  p_body text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_thread public.venue_chat_threads%ROWTYPE;
  v_message public.venue_chat_messages%ROWTYPE;
  v_body text := trim(coalesce(p_body, ''));
  v_sender_role text;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Sign in to send venue chat messages';
  END IF;

  IF char_length(v_body) NOT BETWEEN 1 AND 2000 THEN
    RAISE EXCEPTION 'Chat message must be between 1 and 2000 characters';
  END IF;

  SELECT *
  INTO v_thread
  FROM public.venue_chat_threads
  WHERE id = p_thread_id;

  IF v_thread.id IS NULL THEN
    RAISE EXCEPTION 'Chat thread not found';
  END IF;

  IF v_thread.status NOT IN ('open', 'in_review') THEN
    RAISE EXCEPTION 'Chat thread is closed';
  END IF;

  IF v_thread.customer_user_id = v_actor THEN
    v_sender_role := 'customer';
  ELSIF public.is_admin_manager(v_actor) THEN
    v_sender_role := 'admin';
  ELSIF public.venue_user_has_role(v_thread.venue_id) THEN
    v_sender_role := 'venue_staff';
  ELSE
    RAISE EXCEPTION 'Only the customer or venue operators can send chat messages';
  END IF;

  INSERT INTO public.venue_chat_messages (
    thread_id,
    venue_id,
    sender_user_id,
    sender_role,
    body
  )
  VALUES (
    p_thread_id,
    v_thread.venue_id,
    v_actor,
    v_sender_role,
    v_body
  )
  RETURNING * INTO v_message;

  UPDATE public.venue_chat_threads
  SET status = CASE WHEN status = 'open' THEN 'in_review' ELSE status END,
      last_message_at = v_message.created_at,
      updated_at = timezone('utc', now())
  WHERE id = p_thread_id
  RETURNING * INTO v_thread;

  PERFORM public.sports_bar_write_audit(
    'venue_chat_message_sent',
    'venue_chat_thread',
    v_thread.id::text,
    NULL::jsonb,
    jsonb_build_object(
      'venue_id', v_thread.venue_id,
      'sender_role', v_sender_role,
      'message_id', v_message.id
    ),
    v_actor
  );

  RETURN jsonb_build_object(
    'thread', to_jsonb(v_thread),
    'message', to_jsonb(v_message)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.close_venue_chat_thread(
  p_thread_id uuid,
  p_status text DEFAULT 'resolved',
  p_resolution_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_thread_before public.venue_chat_threads%ROWTYPE;
  v_thread_after public.venue_chat_threads%ROWTYPE;
  v_status text := lower(trim(coalesce(p_status, 'resolved')));
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Sign in to close venue chat';
  END IF;

  IF v_status NOT IN ('resolved', 'closed', 'cancelled') THEN
    RAISE EXCEPTION 'Unsupported chat close status';
  END IF;

  SELECT *
  INTO v_thread_before
  FROM public.venue_chat_threads
  WHERE id = p_thread_id;

  IF v_thread_before.id IS NULL THEN
    RAISE EXCEPTION 'Chat thread not found';
  END IF;

  IF NOT (
    public.is_admin_manager(v_actor)
    OR public.venue_user_has_role(v_thread_before.venue_id)
  ) THEN
    RAISE EXCEPTION 'Only venue operators can close chat threads';
  END IF;

  UPDATE public.venue_chat_threads
  SET status = v_status,
      resolution_notes = nullif(trim(coalesce(p_resolution_notes, '')), ''),
      closed_at = timezone('utc', now()),
      closed_by = v_actor,
      updated_at = timezone('utc', now())
  WHERE id = p_thread_id
  RETURNING * INTO v_thread_after;

  INSERT INTO public.venue_chat_messages (
    thread_id,
    venue_id,
    sender_user_id,
    sender_role,
    body,
    message_type
  )
  VALUES (
    p_thread_id,
    v_thread_after.venue_id,
    v_actor,
    CASE WHEN public.is_admin_manager(v_actor) THEN 'admin' ELSE 'venue_staff' END,
    'Chat marked ' || v_status || '.',
    'system'
  );

  PERFORM public.sports_bar_write_audit(
    'venue_chat_thread_closed',
    'venue_chat_thread',
    v_thread_after.id::text,
    to_jsonb(v_thread_before),
    to_jsonb(v_thread_after),
    v_actor
  );

  RETURN to_jsonb(v_thread_after);
END;
$$;

REVOKE ALL ON public.venue_chat_threads FROM anon;
REVOKE ALL ON public.venue_chat_messages FROM anon;
GRANT SELECT ON public.venue_chat_threads TO authenticated;
GRANT SELECT ON public.venue_chat_messages TO authenticated;
GRANT ALL ON public.venue_chat_threads TO service_role;
GRANT ALL ON public.venue_chat_messages TO service_role;

GRANT EXECUTE ON FUNCTION public.create_venue_chat_thread(uuid, text, text, text, uuid, uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_venue_chat_message(uuid, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.close_venue_chat_thread(uuid, text, text)
  TO authenticated, service_role;

COMMENT ON TABLE public.venue_chat_threads IS
  'Venue-scoped customer-to-bar chat threads. Client writes go through audited RPCs.';
COMMENT ON TABLE public.venue_chat_messages IS
  'Messages for venue chat threads. RLS allows reads only for the customer, venue operators, or platform admins.';
