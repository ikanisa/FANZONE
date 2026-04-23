\pset tuples_only on
\pset pager off

\echo 'Verifying platform feature registry objects...'

DO $$
DECLARE
  missing_relations text[];
  missing_functions text[];
BEGIN
  SELECT array_agg(required_name ORDER BY required_name)
  INTO missing_relations
  FROM (
    VALUES
      ('public.platform_features'),
      ('public.platform_feature_rules'),
      ('public.platform_feature_channels'),
      ('public.platform_content_blocks'),
      ('public.admin_platform_features'),
      ('public.admin_platform_content_blocks'),
      ('public.platform_feature_audit_logs')
  ) AS expected(required_name)
  WHERE to_regclass(expected.required_name) IS NULL;

  IF missing_relations IS NOT NULL THEN
    RAISE EXCEPTION 'Missing platform registry relations: %', array_to_string(missing_relations, ', ');
  END IF;

  SELECT array_agg(required_signature ORDER BY required_signature)
  INTO missing_functions
  FROM (
    VALUES
      ('public.get_app_bootstrap_config(text,text)'),
      ('public.platform_feature_status_is_live(text,timestamp with time zone,timestamp with time zone,timestamp with time zone)'),
      ('public.request_platform_channel()'),
      ('public.resolve_platform_feature(text,text,boolean,timestamp with time zone)'),
      ('public.assert_platform_feature_available(text,text)')
  ) AS expected(required_signature)
  WHERE to_regprocedure(expected.required_signature) IS NULL;

  IF missing_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Missing platform registry functions: %', array_to_string(missing_functions, ', ');
  END IF;
END;
$$;

\echo 'Platform feature registry verified'
