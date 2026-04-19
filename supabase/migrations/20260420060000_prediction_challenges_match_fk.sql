BEGIN;

DO $$
BEGIN
  IF to_regclass('public.prediction_challenges') IS NOT NULL
     AND to_regclass('public.matches') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM pg_constraint
       WHERE conname = 'prediction_challenges_match_id_fkey'
     ) THEN
    ALTER TABLE public.prediction_challenges
      ADD CONSTRAINT prediction_challenges_match_id_fkey
      FOREIGN KEY (match_id) REFERENCES public.matches(id)
      ON DELETE CASCADE
      NOT VALID;

    ALTER TABLE public.prediction_challenges
      VALIDATE CONSTRAINT prediction_challenges_match_id_fkey;
  END IF;
END $$;

COMMIT;
