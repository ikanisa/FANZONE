CREATE TABLE IF NOT EXISTS public.match_alert_subscriptions (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  match_id TEXT NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  alert_kickoff BOOLEAN NOT NULL DEFAULT true,
  alert_goals BOOLEAN NOT NULL DEFAULT true,
  alert_result BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, match_id)
);

CREATE INDEX IF NOT EXISTS idx_match_alert_subscriptions_match
ON public.match_alert_subscriptions (match_id);

ALTER TABLE public.match_alert_subscriptions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'match_alert_subscriptions'
      AND policyname = 'Users manage own match alerts'
  ) THEN
    CREATE POLICY "Users manage own match alerts"
      ON public.match_alert_subscriptions
      FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;
