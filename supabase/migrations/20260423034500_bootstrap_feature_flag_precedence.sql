CREATE OR REPLACE FUNCTION public.get_app_bootstrap_config(
  p_market text DEFAULT 'global'::text,
  p_platform text DEFAULT 'all'::text
) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'regions', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'country_code', crm.country_code,
            'region', crm.region,
            'country_name', crm.country_name,
            'flag_emoji', crm.flag_emoji
          )
          ORDER BY crm.country_name
        ),
        '[]'::jsonb
      )
      FROM public.country_region_map crm
    ),
    'phone_presets', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'country_code', pp.country_code,
            'dial_code', pp.dial_code,
            'hint', pp.hint,
            'min_digits', pp.min_digits
          )
          ORDER BY pp.country_code
        ),
        '[]'::jsonb
      )
      FROM public.phone_presets pp
    ),
    'currency_display', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'currency_code', cdm.currency_code,
            'symbol', cdm.symbol,
            'decimals', cdm.decimals,
            'space_separated', cdm.space_separated
          )
          ORDER BY cdm.currency_code
        ),
        '[]'::jsonb
      )
      FROM public.currency_display_metadata cdm
    ),
    'feature_flags', (
      SELECT COALESCE(
        jsonb_object_agg(resolved.key, resolved.enabled),
        '{}'::jsonb
      )
      FROM (
        SELECT DISTINCT ON (ff.key)
          ff.key,
          ff.enabled
        FROM public.feature_flags ff
        WHERE (ff.market = p_market OR ff.market = 'global')
          AND (ff.platform = p_platform OR ff.platform = 'all')
        ORDER BY
          ff.key,
          CASE WHEN ff.market = p_market THEN 1 ELSE 0 END DESC,
          CASE WHEN ff.platform = p_platform THEN 1 ELSE 0 END DESC,
          ff.updated_at DESC
      ) AS resolved
    ),
    'app_config', (
      SELECT COALESCE(
        jsonb_object_agg(acr.key, acr.value),
        '{}'::jsonb
      )
      FROM public.app_config_remote acr
    ),
    'launch_moments', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'tag', lm.tag,
            'title', lm.title,
            'subtitle', lm.subtitle,
            'kicker', lm.kicker,
            'region_key', lm.region_key
          )
          ORDER BY lm.sort_order
        ),
        '[]'::jsonb
      )
      FROM public.launch_moments lm
      WHERE lm.is_active = true
    )
  )
  INTO v_result;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;
