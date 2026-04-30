-- Fix find_auth_user_by_phone to handle phone format variations.
-- The auth.users table may store phones with or without the '+' prefix.
-- This migration makes the lookup tolerant of both formats.

CREATE OR REPLACE FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'auth', 'public'
    AS $$
DECLARE
  v_id uuid;
  v_normalized text;
  v_without_plus text;
BEGIN
  -- Normalize: strip spaces, dashes, parens
  v_normalized := regexp_replace(trim(coalesce(p_phone, '')), '[\s\-\(\)]', '', 'g');

  -- Try exact match first
  SELECT id INTO v_id
  FROM auth.users
  WHERE phone = v_normalized
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  -- Try with '+' prefix removed
  v_without_plus := ltrim(v_normalized, '+');
  SELECT id INTO v_id
  FROM auth.users
  WHERE phone = v_without_plus
     OR phone = '+' || v_without_plus
  LIMIT 1;

  RETURN v_id;
END;
$$;

ALTER FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_auth_user_by_phone"("p_phone" "text") TO "service_role";
