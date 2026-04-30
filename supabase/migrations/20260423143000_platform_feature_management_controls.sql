begin;

create or replace function public.current_user_platform_roles()
returns jsonb
language plpgsql
stable
security definer
set search_path to public
as $$
declare
  v_user_id uuid := auth.uid();
  v_claims_raw text := nullif(current_setting('request.jwt.claims', true), '');
  v_claims jsonb := '{}'::jsonb;
  v_roles text[] := array[]::text[];
  v_role text;
begin
  if v_claims_raw is not null then
    begin
      v_claims := v_claims_raw::jsonb;
    exception
      when others then
        v_claims := '{}'::jsonb;
    end;
  end if;

  if v_user_id is null then
    v_roles := array_append(v_roles, 'anonymous');
  else
    v_roles := array_append(v_roles, 'authenticated');
  end if;

  v_role := nullif(lower(trim(coalesce(v_claims ->> 'role', ''))), '');
  if v_role is not null then
    v_roles := array_append(v_roles, v_role);
  end if;

  if jsonb_typeof(v_claims -> 'roles') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims -> 'roles') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if jsonb_typeof(v_claims #> '{app_metadata,roles}') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims #> '{app_metadata,roles}') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if jsonb_typeof(v_claims #> '{user_metadata,roles}') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims #> '{user_metadata,roles}') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if jsonb_typeof(v_claims #> '{app_metadata,platform_roles}') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims #> '{app_metadata,platform_roles}') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if jsonb_typeof(v_claims #> '{user_metadata,platform_roles}') = 'array' then
    for v_role in
      select lower(trim(value))
      from jsonb_array_elements_text(v_claims #> '{user_metadata,platform_roles}') as value
      where trim(value) <> ''
    loop
      v_roles := array_append(v_roles, v_role);
    end loop;
  end if;

  if v_user_id is not null and exists (
    select 1
    from public.admin_users
    where user_id = v_user_id
      and is_active = true
  ) then
    v_roles := array_append(v_roles, 'admin_operator');

    select lower(role)
    into v_role
    from public.admin_users
    where user_id = v_user_id
      and is_active = true
    limit 1;

    if v_role is not null then
      v_roles := array_append(v_roles, v_role);
    end if;
  end if;

  return (
    select coalesce(
      jsonb_agg(role_name order by role_name),
      '[]'::jsonb
    )
    from (
      select distinct role_name
      from unnest(v_roles) as role_name
      where role_name is not null
        and role_name <> ''
    ) deduped
  );
end;
$$;

create or replace function public.platform_roles_allow_access(
  p_role_restrictions jsonb,
  p_user_roles jsonb default public.current_user_platform_roles()
) returns boolean
language plpgsql
stable
security definer
set search_path to public
as $$
declare
  v_any text[];
  v_all text[];
  v_none text[];
begin
  if p_role_restrictions is null
    or p_role_restrictions = 'null'::jsonb
    or p_role_restrictions = '{}'::jsonb
    or p_role_restrictions = '[]'::jsonb
  then
    return true;
  end if;

  if jsonb_typeof(p_role_restrictions) = 'array' then
    return exists (
      select 1
      from jsonb_array_elements_text(p_role_restrictions) as required_role(value)
      join jsonb_array_elements_text(coalesce(p_user_roles, '[]'::jsonb)) as user_role(value)
        on lower(trim(required_role.value)) = lower(trim(user_role.value))
      where trim(required_role.value) <> ''
    );
  end if;

  if jsonb_typeof(p_role_restrictions) <> 'object' then
    return false;
  end if;

  select coalesce(array_agg(lower(trim(value))), array[]::text[])
  into v_any
  from jsonb_array_elements_text(coalesce(p_role_restrictions -> 'any_of', '[]'::jsonb)) as value
  where trim(value) <> '';

  select coalesce(array_agg(lower(trim(value))), array[]::text[])
  into v_all
  from jsonb_array_elements_text(coalesce(p_role_restrictions -> 'all_of', '[]'::jsonb)) as value
  where trim(value) <> '';

  select coalesce(array_agg(lower(trim(value))), array[]::text[])
  into v_none
  from jsonb_array_elements_text(coalesce(p_role_restrictions -> 'none_of', '[]'::jsonb)) as value
  where trim(value) <> '';

  if cardinality(v_any) > 0 and not exists (
    select 1
    from unnest(v_any) as required_role
    where required_role = any (
      array(
        select lower(trim(value))
        from jsonb_array_elements_text(coalesce(p_user_roles, '[]'::jsonb)) as value
      )
    )
  ) then
    return false;
  end if;

  if cardinality(v_all) > 0 and exists (
    select 1
    from unnest(v_all) as required_role
    where required_role <> all (
      array(
        select lower(trim(value))
        from jsonb_array_elements_text(coalesce(p_user_roles, '[]'::jsonb)) as value
      )
    )
  ) then
    return false;
  end if;

  if cardinality(v_none) > 0 and exists (
    select 1
    from unnest(v_none) as denied_role
    where denied_role = any (
      array(
        select lower(trim(value))
        from jsonb_array_elements_text(coalesce(p_user_roles, '[]'::jsonb)) as value
      )
    )
  ) then
    return false;
  end if;

  return true;
end;
$$;

create or replace function public.platform_feature_config_version()
returns text
language sql
stable
security definer
set search_path to public
as $$
  select md5(
    concat_ws(
      '|',
      coalesce((select max(updated_at)::text from public.platform_features), '0'),
      coalesce((select max(updated_at)::text from public.platform_feature_rules), '0'),
      coalesce((select max(updated_at)::text from public.platform_feature_channels), '0'),
      coalesce((select max(updated_at)::text from public.platform_content_blocks), '0')
    )
  );
$$;

create or replace function public.resolve_platform_feature(
  p_feature_key text,
  p_channel text,
  p_is_authenticated boolean default (auth.uid() is not null),
  p_now timestamptz default timezone('utc', now())
) returns jsonb
language plpgsql
stable
security definer
set search_path to public
as $$
declare
  v_feature public.platform_features%rowtype;
  v_rules public.platform_feature_rules%rowtype;
  v_channel public.platform_feature_channels%rowtype;
  v_dependency_blocker text;
  v_is_live boolean := false;
  v_is_operational boolean := false;
  v_is_visible boolean := false;
  v_is_available boolean := false;
  v_roles_allowed boolean := true;
  v_auth_satisfied boolean := true;
  v_configured_visible boolean := false;
  v_visibility_reason text := 'visible';
  v_feature_channel text := case
    when lower(coalesce(p_channel, 'web')) in ('android', 'ios', 'mobile')
      then 'mobile'
    else 'web'
  end;
  v_user_roles jsonb := public.current_user_platform_roles();
begin
  select *
  into v_feature
  from public.platform_features
  where feature_key = coalesce(trim(p_feature_key), '');

  if not found then
    return jsonb_build_object(
      'feature_key', p_feature_key,
      'exists', false,
      'is_operational', false,
      'is_visible', false,
      'is_available', false,
      'visibility_reason', 'missing',
      'user_roles', v_user_roles,
      'config_version', public.platform_feature_config_version()
    );
  end if;

  select *
  into v_rules
  from public.platform_feature_rules
  where feature_key = v_feature.feature_key;

  select *
  into v_channel
  from public.platform_feature_channels
  where feature_key = v_feature.feature_key
    and channel = v_feature_channel;

  v_is_live := public.platform_feature_status_is_live(
    v_feature.status,
    v_rules.schedule_start_at,
    v_rules.schedule_end_at,
    p_now
  );

  if coalesce(v_rules.dependency_config, '{}'::jsonb) ? 'requires_all' then
    select dependency.feature_key
    into v_dependency_blocker
    from (
      select value::text as feature_key
      from jsonb_array_elements_text(
        coalesce(v_rules.dependency_config -> 'requires_all', '[]'::jsonb)
      )
    ) as dependency
    where coalesce(
      (
        public.resolve_platform_feature(
          dependency.feature_key,
          v_feature_channel,
          p_is_authenticated,
          p_now
        ) ->> 'is_operational'
      )::boolean,
      false
    ) = false
    limit 1;
  end if;

  v_roles_allowed := public.platform_roles_allow_access(
    coalesce(v_rules.role_restrictions, '[]'::jsonb),
    v_user_roles
  );

  v_auth_satisfied :=
    coalesce(v_rules.auth_required, false) = false
    or coalesce(p_is_authenticated, false);

  v_is_operational :=
    coalesce(v_feature.is_enabled, false)
    and coalesce(v_channel.is_enabled, false)
    and v_is_live
    and v_dependency_blocker is null;

  v_configured_visible :=
    coalesce(v_channel.is_visible, false)
    and coalesce(v_feature.status, 'inactive') <> 'hidden';

  v_is_visible := v_is_operational and v_configured_visible;
  v_is_available := v_is_operational and v_roles_allowed and v_auth_satisfied;

  v_visibility_reason := case
    when coalesce(v_feature.is_enabled, false) = false then 'globally_disabled'
    when coalesce(v_channel.is_enabled, false) = false then 'channel_disabled'
    when coalesce(v_feature.status, 'inactive') = 'hidden' then 'hidden'
    when coalesce(v_channel.is_visible, false) = false then 'channel_hidden'
    when not v_is_live then 'scheduled'
    when v_dependency_blocker is not null then 'dependency_blocked'
    when not v_roles_allowed then 'role_restricted'
    when not v_auth_satisfied then 'auth_required'
    else 'visible'
  end;

  return jsonb_build_object(
    'feature_key', v_feature.feature_key,
    'display_name', v_feature.display_name,
    'description', v_feature.description,
    'status', v_feature.status,
    'exists', true,
    'is_enabled', v_feature.is_enabled,
    'is_operational', v_is_operational,
    'is_visible', v_is_visible,
    'is_available', v_is_available,
    'is_configured_visible', v_configured_visible,
    'auth_required', coalesce(v_rules.auth_required, false),
    'auth_satisfied', v_auth_satisfied,
    'roles_allowed', v_roles_allowed,
    'dependency_blocker', v_dependency_blocker,
    'channel', v_feature_channel,
    'show_in_navigation', coalesce(v_channel.show_in_navigation, false),
    'show_on_home', coalesce(v_channel.show_on_home, false),
    'route_key', v_channel.route_key,
    'entry_key', v_channel.entry_key,
    'sort_order', coalesce(v_channel.sort_order, 100),
    'role_restrictions', coalesce(v_rules.role_restrictions, '[]'::jsonb),
    'rollout_config', coalesce(v_rules.rollout_config, '{}'::jsonb),
    'schedule_start_at', v_rules.schedule_start_at,
    'schedule_end_at', v_rules.schedule_end_at,
    'is_schedule_live', v_is_live,
    'visibility_reason', v_visibility_reason,
    'user_roles', v_user_roles,
    'config_version', public.platform_feature_config_version(),
    'metadata',
      coalesce(v_feature.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'channel_metadata',
        coalesce(v_channel.metadata, '{}'::jsonb)
      )
  );
end;
$$;

create or replace function public.assert_platform_feature_available(
  p_feature_key text,
  p_channel text default 'web'
) returns void
language plpgsql
security definer
set search_path to public
as $$
declare
  v_state jsonb;
begin
  v_state := public.resolve_platform_feature(
    p_feature_key,
    p_channel,
    auth.uid() is not null
  );

  if coalesce((v_state ->> 'exists')::boolean, false) = false then
    raise exception 'Unknown feature %', p_feature_key;
  end if;

  if coalesce((v_state ->> 'is_operational')::boolean, false) = false then
    raise exception 'Feature % is currently disabled', p_feature_key;
  end if;

  if coalesce((v_state ->> 'roles_allowed')::boolean, true) = false then
    raise exception 'Feature % is not allowed for the current role', p_feature_key;
  end if;

  if coalesce((v_state ->> 'auth_required')::boolean, false) = true
    and auth.uid() is null
  then
    raise exception 'Authentication required for feature %', p_feature_key;
  end if;
end;
$$;

create or replace function public.admin_upsert_platform_feature(
  p_payload jsonb
) returns text
language plpgsql
security definer
set search_path to public
as $$
declare
  v_feature_key text := lower(trim(coalesce(p_payload ->> 'feature_key', '')));
  v_now timestamptz := timezone('utc', now());
  v_mobile jsonb := coalesce(p_payload -> 'mobile_channel', '{}'::jsonb);
  v_web jsonb := coalesce(p_payload -> 'web_channel', '{}'::jsonb);
begin
  if not public.is_admin_manager(auth.uid()) then
    raise exception 'Admin privileges required';
  end if;

  if v_feature_key = '' then
    raise exception 'feature_key is required';
  end if;

  if nullif(trim(coalesce(p_payload ->> 'display_name', '')), '') is null then
    raise exception 'display_name is required';
  end if;

  if (p_payload ->> 'schedule_start_at') is not null
    and trim(p_payload ->> 'schedule_start_at') <> ''
    and (p_payload ->> 'schedule_end_at') is not null
    and trim(p_payload ->> 'schedule_end_at') <> ''
    and (p_payload ->> 'schedule_end_at')::timestamptz <= (p_payload ->> 'schedule_start_at')::timestamptz
  then
    raise exception 'schedule_end_at must be later than schedule_start_at';
  end if;

  insert into public.platform_features (
    feature_key,
    display_name,
    description,
    status,
    is_enabled,
    navigation_group,
    default_route_key,
    admin_notes,
    metadata,
    updated_at
  )
  values (
    v_feature_key,
    trim(p_payload ->> 'display_name'),
    nullif(trim(coalesce(p_payload ->> 'description', '')), ''),
    lower(trim(coalesce(p_payload ->> 'status', 'active'))),
    coalesce((p_payload ->> 'is_enabled')::boolean, true),
    nullif(trim(coalesce(p_payload ->> 'navigation_group', '')), ''),
    nullif(trim(coalesce(p_payload ->> 'default_route_key', '')), ''),
    nullif(trim(coalesce(p_payload ->> 'admin_notes', '')), ''),
    coalesce(p_payload -> 'metadata', '{}'::jsonb),
    v_now
  )
  on conflict (feature_key) do update
  set display_name = excluded.display_name,
      description = excluded.description,
      status = excluded.status,
      is_enabled = excluded.is_enabled,
      navigation_group = excluded.navigation_group,
      default_route_key = excluded.default_route_key,
      admin_notes = excluded.admin_notes,
      metadata = excluded.metadata,
      updated_at = excluded.updated_at;

  insert into public.platform_feature_rules (
    feature_key,
    auth_required,
    role_restrictions,
    dependency_config,
    rollout_config,
    schedule_start_at,
    schedule_end_at,
    metadata,
    updated_at
  )
  values (
    v_feature_key,
    coalesce((p_payload ->> 'auth_required')::boolean, false),
    coalesce(p_payload -> 'role_restrictions', '[]'::jsonb),
    coalesce(p_payload -> 'dependency_config', '{}'::jsonb),
    coalesce(p_payload -> 'rollout_config', '{}'::jsonb),
    nullif(trim(coalesce(p_payload ->> 'schedule_start_at', '')), '')::timestamptz,
    nullif(trim(coalesce(p_payload ->> 'schedule_end_at', '')), '')::timestamptz,
    coalesce(p_payload -> 'rules_metadata', '{}'::jsonb),
    v_now
  )
  on conflict (feature_key) do update
  set auth_required = excluded.auth_required,
      role_restrictions = excluded.role_restrictions,
      dependency_config = excluded.dependency_config,
      rollout_config = excluded.rollout_config,
      schedule_start_at = excluded.schedule_start_at,
      schedule_end_at = excluded.schedule_end_at,
      metadata = excluded.metadata,
      updated_at = excluded.updated_at;

  insert into public.platform_feature_channels (
    feature_key,
    channel,
    is_visible,
    is_enabled,
    show_in_navigation,
    show_on_home,
    sort_order,
    route_key,
    entry_key,
    navigation_label,
    placement_key,
    metadata,
    updated_at
  )
  values
    (
      v_feature_key,
      'mobile',
      coalesce((v_mobile ->> 'is_visible')::boolean, true),
      coalesce((v_mobile ->> 'is_enabled')::boolean, true),
      coalesce((v_mobile ->> 'show_in_navigation')::boolean, false),
      coalesce((v_mobile ->> 'show_on_home')::boolean, false),
      coalesce((v_mobile ->> 'sort_order')::integer, 100),
      nullif(trim(coalesce(v_mobile ->> 'route_key', '')), ''),
      nullif(trim(coalesce(v_mobile ->> 'entry_key', '')), ''),
      nullif(trim(coalesce(v_mobile ->> 'navigation_label', '')), ''),
      nullif(trim(coalesce(v_mobile ->> 'placement_key', '')), ''),
      coalesce(v_mobile -> 'metadata', '{}'::jsonb),
      v_now
    ),
    (
      v_feature_key,
      'web',
      coalesce((v_web ->> 'is_visible')::boolean, true),
      coalesce((v_web ->> 'is_enabled')::boolean, true),
      coalesce((v_web ->> 'show_in_navigation')::boolean, false),
      coalesce((v_web ->> 'show_on_home')::boolean, false),
      coalesce((v_web ->> 'sort_order')::integer, 100),
      nullif(trim(coalesce(v_web ->> 'route_key', '')), ''),
      nullif(trim(coalesce(v_web ->> 'entry_key', '')), ''),
      nullif(trim(coalesce(v_web ->> 'navigation_label', '')), ''),
      nullif(trim(coalesce(v_web ->> 'placement_key', '')), ''),
      coalesce(v_web -> 'metadata', '{}'::jsonb),
      v_now
    )
  on conflict (feature_key, channel) do update
  set is_visible = excluded.is_visible,
      is_enabled = excluded.is_enabled,
      show_in_navigation = excluded.show_in_navigation,
      show_on_home = excluded.show_on_home,
      sort_order = excluded.sort_order,
      route_key = excluded.route_key,
      entry_key = excluded.entry_key,
      navigation_label = excluded.navigation_label,
      placement_key = excluded.placement_key,
      metadata = excluded.metadata,
      updated_at = excluded.updated_at;

  return v_feature_key;
end;
$$;

create or replace function public.admin_upsert_platform_content_block(
  p_payload jsonb
) returns text
language plpgsql
security definer
set search_path to public
as $$
declare
  v_block_key text := lower(trim(coalesce(p_payload ->> 'block_key', '')));
  v_now timestamptz := timezone('utc', now());
begin
  if not public.is_admin_manager(auth.uid()) then
    raise exception 'Admin privileges required';
  end if;

  if v_block_key = '' then
    raise exception 'block_key is required';
  end if;

  if nullif(trim(coalesce(p_payload ->> 'title', '')), '') is null then
    raise exception 'title is required';
  end if;

  if nullif(trim(coalesce(p_payload ->> 'placement_key', '')), '') is null then
    raise exception 'placement_key is required';
  end if;

  insert into public.platform_content_blocks (
    block_key,
    block_type,
    title,
    content,
    target_channel,
    is_active,
    sort_order,
    feature_key,
    placement_key,
    metadata,
    updated_at
  )
  values (
    v_block_key,
    lower(trim(coalesce(p_payload ->> 'block_type', 'content'))),
    trim(p_payload ->> 'title'),
    coalesce(p_payload -> 'content', '{}'::jsonb),
    case lower(trim(coalesce(p_payload ->> 'target_channel', 'both')))
      when 'mobile' then 'mobile'
      when 'web' then 'web'
      else 'both'
    end,
    coalesce((p_payload ->> 'is_active')::boolean, true),
    coalesce((p_payload ->> 'sort_order')::integer, 100),
    nullif(trim(coalesce(p_payload ->> 'feature_key', '')), ''),
    lower(trim(p_payload ->> 'placement_key')),
    coalesce(p_payload -> 'metadata', '{}'::jsonb),
    v_now
  )
  on conflict (block_key) do update
  set block_type = excluded.block_type,
      title = excluded.title,
      content = excluded.content,
      target_channel = excluded.target_channel,
      is_active = excluded.is_active,
      sort_order = excluded.sort_order,
      feature_key = excluded.feature_key,
      placement_key = excluded.placement_key,
      metadata = excluded.metadata,
      updated_at = excluded.updated_at;

  return v_block_key;
end;
$$;

create or replace function public.get_app_bootstrap_config(
  p_market text default 'global'::text,
  p_platform text default 'all'::text
) returns jsonb
language plpgsql
stable
security definer
set search_path to public
as $$
declare
  v_channel text := case
    when p_platform in ('android', 'ios') then 'mobile'
    when p_platform = 'web' then 'web'
    else 'web'
  end;
  v_result jsonb;
begin
  select jsonb_build_object(
    'platform_config_version', public.platform_feature_config_version(),
    'regions', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'country_code', crm.country_code,
            'region', crm.region,
            'country_name', crm.country_name,
            'flag_emoji', crm.flag_emoji
          )
          order by crm.country_name
        ),
        '[]'::jsonb
      )
      from public.country_region_map crm
    ),
    'phone_presets', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'country_code', pp.country_code,
            'dial_code', pp.dial_code,
            'hint', pp.hint,
            'min_digits', pp.min_digits
          )
          order by pp.country_code
        ),
        '[]'::jsonb
      )
      from public.phone_presets pp
    ),
    'currency_display', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'currency_code', cdm.currency_code,
            'symbol', cdm.symbol,
            'decimals', cdm.decimals,
            'space_separated', cdm.space_separated
          )
          order by cdm.currency_code
        ),
        '[]'::jsonb
      )
      from public.currency_display_metadata cdm
    ),
    'country_currency_map', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'country_code', ccm.country_code,
            'currency_code', ccm.currency_code,
            'country_name', ccm.country_name
          )
          order by ccm.country_code
        ),
        '[]'::jsonb
      )
      from public.country_currency_map ccm
    ),
    'feature_flags', (
      select coalesce(
        jsonb_object_agg(resolved.key, resolved.enabled),
        '{}'::jsonb
      )
      from (
        select distinct on (ff.key)
          ff.key,
          ff.enabled
        from public.feature_flags ff
        where (ff.market = p_market or ff.market = 'global')
          and (ff.platform = p_platform or ff.platform = 'all')
        order by
          ff.key,
          case when ff.market = p_market then 1 else 0 end desc,
          case when ff.platform = p_platform then 1 else 0 end desc,
          ff.updated_at desc
      ) as resolved
    ),
    'app_config', (
      select coalesce(
        jsonb_object_agg(acr.key, acr.value),
        '{}'::jsonb
      )
      from public.app_config_remote acr
    ),
    'launch_moments', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'tag', lm.tag,
            'title', lm.title,
            'subtitle', lm.subtitle,
            'kicker', lm.kicker,
            'region_key', lm.region_key
          )
          order by lm.sort_order
        ),
        '[]'::jsonb
      )
      from public.launch_moments lm
      where lm.is_active = true
    ),
    'platform_features', (
      select coalesce(
        jsonb_agg(feature_row.feature_json order by feature_row.sort_order, feature_row.display_name),
        '[]'::jsonb
      )
      from (
        select
          pf.display_name,
          least(
            coalesce(pfc_mobile.sort_order, 999),
            coalesce(pfc_web.sort_order, 999)
          ) as sort_order,
          jsonb_build_object(
            'feature_key', pf.feature_key,
            'display_name', pf.display_name,
            'description', pf.description,
            'status', pf.status,
            'is_enabled', pf.is_enabled,
            'navigation_group', pf.navigation_group,
            'default_route_key', pf.default_route_key,
            'admin_notes', pf.admin_notes,
            'metadata', coalesce(pf.metadata, '{}'::jsonb),
            'auth_required', coalesce(pfr.auth_required, false),
            'role_restrictions', coalesce(pfr.role_restrictions, '[]'::jsonb),
            'dependency_config', coalesce(pfr.dependency_config, '{}'::jsonb),
            'rollout_config', coalesce(pfr.rollout_config, '{}'::jsonb),
            'schedule_start_at', pfr.schedule_start_at,
            'schedule_end_at', pfr.schedule_end_at,
            'channels', jsonb_build_object(
              'mobile', jsonb_build_object(
                'channel', 'mobile',
                'is_visible', coalesce(pfc_mobile.is_visible, false),
                'is_enabled', coalesce(pfc_mobile.is_enabled, false),
                'show_in_navigation', coalesce(pfc_mobile.show_in_navigation, false),
                'show_on_home', coalesce(pfc_mobile.show_on_home, false),
                'sort_order', coalesce(pfc_mobile.sort_order, 100),
                'route_key', pfc_mobile.route_key,
                'entry_key', pfc_mobile.entry_key,
                'navigation_label', pfc_mobile.navigation_label,
                'placement_key', pfc_mobile.placement_key,
                'metadata', coalesce(pfc_mobile.metadata, '{}'::jsonb)
              ),
              'web', jsonb_build_object(
                'channel', 'web',
                'is_visible', coalesce(pfc_web.is_visible, false),
                'is_enabled', coalesce(pfc_web.is_enabled, false),
                'show_in_navigation', coalesce(pfc_web.show_in_navigation, false),
                'show_on_home', coalesce(pfc_web.show_on_home, false),
                'sort_order', coalesce(pfc_web.sort_order, 100),
                'route_key', pfc_web.route_key,
                'entry_key', pfc_web.entry_key,
                'navigation_label', pfc_web.navigation_label,
                'placement_key', pfc_web.placement_key,
                'metadata', coalesce(pfc_web.metadata, '{}'::jsonb)
              )
            ),
            'resolved_state', public.resolve_platform_feature(
              pf.feature_key,
              v_channel,
              auth.uid() is not null
            )
          ) as feature_json
        from public.platform_features pf
        left join public.platform_feature_rules pfr
          on pfr.feature_key = pf.feature_key
        left join public.platform_feature_channels pfc_mobile
          on pfc_mobile.feature_key = pf.feature_key
         and pfc_mobile.channel = 'mobile'
        left join public.platform_feature_channels pfc_web
          on pfc_web.feature_key = pf.feature_key
         and pfc_web.channel = 'web'
      ) as feature_row
    ),
    'platform_content_blocks', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'block_key', pcb.block_key,
            'block_type', pcb.block_type,
            'title', pcb.title,
            'content', pcb.content,
            'target_channel', pcb.target_channel,
            'is_active', pcb.is_active,
            'sort_order', pcb.sort_order,
            'feature_key', pcb.feature_key,
            'placement_key', pcb.placement_key,
            'metadata', pcb.metadata
          )
          order by pcb.sort_order, pcb.block_key
        ),
        '[]'::jsonb
      )
      from public.platform_content_blocks pcb
      where pcb.is_active = true
        and (pcb.target_channel = v_channel or pcb.target_channel = 'both')
        and (
          pcb.feature_key is null
          or coalesce(
            (
              public.resolve_platform_feature(
                pcb.feature_key,
                v_channel,
                auth.uid() is not null
              ) ->> 'is_visible'
            )::boolean,
            false
          )
        )
    )
  )
  into v_result;

  return v_result;
end;
$$;

revoke all on table public.platform_features from authenticated;
revoke all on table public.platform_feature_rules from authenticated;
revoke all on table public.platform_feature_channels from authenticated;
revoke all on table public.platform_content_blocks from authenticated;

grant all on table public.platform_features to service_role;
grant all on table public.platform_feature_rules to service_role;
grant all on table public.platform_feature_channels to service_role;
grant all on table public.platform_content_blocks to service_role;

revoke all on function public.current_user_platform_roles() from public;
revoke all on function public.current_user_platform_roles() from anon;
grant all on function public.current_user_platform_roles() to authenticated, service_role;

revoke all on function public.platform_roles_allow_access(jsonb, jsonb) from public;
revoke all on function public.platform_roles_allow_access(jsonb, jsonb) from anon;
grant all on function public.platform_roles_allow_access(jsonb, jsonb) to authenticated, service_role;

revoke all on function public.platform_feature_config_version() from public;
revoke all on function public.platform_feature_config_version() from anon;
grant all on function public.platform_feature_config_version() to authenticated, service_role;
grant all on function public.platform_feature_config_version() to anon;

revoke all on function public.admin_upsert_platform_feature(jsonb) from public;
revoke all on function public.admin_upsert_platform_feature(jsonb) from anon;
grant all on function public.admin_upsert_platform_feature(jsonb) to authenticated, service_role;

revoke all on function public.admin_upsert_platform_content_block(jsonb) from public;
revoke all on function public.admin_upsert_platform_content_block(jsonb) from anon;
grant all on function public.admin_upsert_platform_content_block(jsonb) to authenticated, service_role;

commit;
