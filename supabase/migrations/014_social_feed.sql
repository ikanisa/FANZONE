-- ============================================================
-- 014_social_feed.sql
-- Social feed / chat with rate limiting and moderation
-- Phase 4: Social & Marketplace
-- ============================================================

BEGIN;

-- ======================
-- 1) Feed messages
-- ======================

CREATE TABLE IF NOT EXISTS public.feed_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_type TEXT NOT NULL
    CHECK (channel_type IN ('pool', 'match', 'team', 'global')),
  channel_id TEXT NOT NULL,  -- pool_id, match_id, team_id, or 'global'
  user_id UUID NOT NULL REFERENCES auth.users(id),
  message_type TEXT DEFAULT 'text'
    CHECK (message_type IN ('text', 'prediction', 'reaction', 'system')),
  content TEXT NOT NULL CHECK (length(content) <= 500),
  reply_to UUID REFERENCES public.feed_messages(id),
  reactions JSONB DEFAULT '{}', -- {"🔥": 3, "⚽": 1}
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feed_channel
  ON public.feed_messages(channel_type, channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_user
  ON public.feed_messages(user_id);

-- ======================
-- 2) Rate limiting
-- ======================

CREATE TABLE IF NOT EXISTS public.feed_rate_limits (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  messages_today INT DEFAULT 0,
  last_message_at TIMESTAMPTZ,
  is_muted BOOLEAN DEFAULT false,
  muted_until TIMESTAMPTZ
);

-- ======================
-- 3) RLS — channel-scoped read access
-- ======================

ALTER TABLE public.feed_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feed_rate_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read messages in accessible channels"
  ON public.feed_messages FOR SELECT USING (
    is_deleted = false AND (
      channel_type = 'global'
      OR channel_type = 'match'  -- All match chats are public
      OR (channel_type = 'pool' AND EXISTS (
        SELECT 1 FROM public.prediction_challenge_entries
        WHERE challenge_id = feed_messages.channel_id::uuid
          AND user_id = auth.uid()
      ))
      OR (channel_type = 'team' AND EXISTS (
        SELECT 1 FROM public.team_supporters
        WHERE team_id = feed_messages.channel_id
          AND user_id = auth.uid()
          AND is_active = true
      ))
    )
  );

CREATE POLICY "Users read own rate limits"
  ON public.feed_rate_limits FOR SELECT USING (auth.uid() = user_id);

-- ======================
-- 4) RPC: send_feed_message (rate-limited)
-- ======================

CREATE OR REPLACE FUNCTION send_feed_message(
  p_channel_type TEXT,
  p_channel_id TEXT,
  p_content TEXT,
  p_reply_to UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_rate RECORD;
  v_message_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  -- Check rate limit (50 messages/day)
  SELECT * INTO v_rate FROM public.feed_rate_limits WHERE user_id = v_user_id;
  IF v_rate IS NOT NULL THEN
    IF v_rate.is_muted AND v_rate.muted_until > now() THEN
      RAISE EXCEPTION 'You are temporarily muted';
    END IF;
    IF v_rate.messages_today >= 50
       AND v_rate.last_message_at::date = CURRENT_DATE THEN
      RAISE EXCEPTION 'Daily message limit reached';
    END IF;
  END IF;

  -- Content validation
  IF length(trim(p_content)) < 1 OR length(p_content) > 500 THEN
    RAISE EXCEPTION 'Message must be 1-500 characters';
  END IF;

  -- Insert message
  INSERT INTO public.feed_messages (channel_type, channel_id, user_id, content, reply_to)
  VALUES (p_channel_type, p_channel_id, v_user_id, trim(p_content), p_reply_to)
  RETURNING id INTO v_message_id;

  -- Update rate limit
  INSERT INTO public.feed_rate_limits (user_id, messages_today, last_message_at)
  VALUES (v_user_id, 1, now())
  ON CONFLICT (user_id) DO UPDATE SET
    messages_today = CASE
      WHEN feed_rate_limits.last_message_at::date < CURRENT_DATE THEN 1
      ELSE feed_rate_limits.messages_today + 1
    END,
    last_message_at = now();

  RETURN jsonb_build_object('status', 'sent', 'message_id', v_message_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ======================
-- 5) RPC: react_to_message
-- ======================

CREATE OR REPLACE FUNCTION react_to_message(
  p_message_id UUID,
  p_emoji TEXT
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_reactions JSONB;
  v_count INT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT reactions INTO v_reactions
  FROM public.feed_messages WHERE id = p_message_id;

  IF v_reactions IS NULL THEN
    RAISE EXCEPTION 'Message not found';
  END IF;

  v_count := COALESCE((v_reactions->>p_emoji)::int, 0) + 1;

  UPDATE public.feed_messages
  SET reactions = jsonb_set(COALESCE(reactions, '{}'), ARRAY[p_emoji], to_jsonb(v_count)),
      updated_at = now()
  WHERE id = p_message_id;

  RETURN jsonb_build_object('status', 'reacted', 'emoji', p_emoji, 'count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
