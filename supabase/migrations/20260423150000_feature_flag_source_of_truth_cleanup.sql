begin;

create or replace view public.admin_feature_flags as
select
  (((ff.key || ':'::text) || ff.market) || ':'::text) || ff.platform as id,
  ff.key,
  initcap(replace(ff.key, '_'::text, ' '::text)) as label,
  ff.description,
  ff.enabled as is_enabled,
  ff.market,
  split_part(ff.key, '_'::text, 1) as module,
  jsonb_build_object(
    'platform',
    ff.platform,
    'rollout_pct',
    ff.rollout_pct
  ) as config,
  null::uuid as updated_by,
  ff.updated_at as created_at,
  ff.updated_at
from public.feature_flags ff
left join public.platform_features pf
  on pf.feature_key = ff.key
where pf.feature_key is null
  and public.is_active_admin_operator(auth.uid());

alter view public.admin_feature_flags owner to postgres;

create or replace function public.admin_set_feature_flag(
  p_flag_id text,
  p_is_enabled boolean
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_admin_record_id uuid;
  v_key text := split_part(coalesce(p_flag_id, ''), ':', 1);
  v_market text := coalesce(
    nullif(split_part(coalesce(p_flag_id, ''), ':', 2), ''),
    'global'
  );
  v_platform text := coalesce(
    nullif(split_part(coalesce(p_flag_id, ''), ':', 3), ''),
    'all'
  );
  v_before jsonb;
  v_after jsonb;
begin
  perform public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  if exists (
    select 1
    from public.platform_features
    where feature_key = v_key
  ) then
    select to_jsonb(feature_row)
    into v_before
    from public.admin_platform_features feature_row
    where feature_row.feature_key = v_key;

    if v_before is null then
      raise exception 'Platform feature not found';
    end if;

    if v_platform in ('android', 'ios') then
      update public.platform_feature_channels
      set
        is_enabled = p_is_enabled,
        updated_at = timezone('utc', now())
      where feature_key = v_key
        and channel = 'mobile';
    elsif v_platform = 'web' then
      update public.platform_feature_channels
      set
        is_enabled = p_is_enabled,
        updated_at = timezone('utc', now())
      where feature_key = v_key
        and channel = 'web';
    else
      update public.platform_features
      set
        is_enabled = p_is_enabled,
        updated_at = timezone('utc', now())
      where feature_key = v_key;
    end if;

    if not found then
      raise exception 'Platform feature flag target not found';
    end if;

    select to_jsonb(feature_row)
    into v_after
    from public.admin_platform_features feature_row
    where feature_row.feature_key = v_key;

    insert into public.admin_audit_logs (
      admin_user_id,
      action,
      module,
      target_type,
      target_id,
      before_state,
      after_state,
      metadata
    ) values (
      v_admin_record_id,
      'toggle_platform_feature_flag',
      'platform-control',
      'platform_feature',
      p_flag_id,
      v_before,
      v_after,
      jsonb_build_object(
        'feature_key',
        v_key,
        'market',
        v_market,
        'platform',
        v_platform,
        'is_enabled',
        p_is_enabled
      )
    );

    return jsonb_build_object(
      'id',
      p_flag_id,
      'feature_key',
      v_key,
      'market',
      v_market,
      'platform',
      v_platform,
      'is_enabled',
      p_is_enabled,
      'source',
      'platform_features'
    );
  end if;

  select to_jsonb(flag_row)
  into v_before
  from public.admin_feature_flags flag_row
  where flag_row.id = p_flag_id;

  if v_before is null then
    raise exception 'Feature flag not found';
  end if;

  update public.feature_flags
  set
    enabled = p_is_enabled,
    updated_at = timezone('utc', now())
  where key = v_key
    and market = v_market
    and platform = v_platform;

  select to_jsonb(flag_row)
  into v_after
  from public.admin_feature_flags flag_row
  where flag_row.id = p_flag_id;

  insert into public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) values (
    v_admin_record_id,
    'toggle_feature_flag',
    'settings',
    'feature_flag',
    p_flag_id,
    v_before,
    v_after,
    jsonb_build_object(
      'feature_key',
      v_key,
      'market',
      v_market,
      'platform',
      v_platform,
      'is_enabled',
      p_is_enabled
    )
  );

  return jsonb_build_object(
    'id',
    p_flag_id,
    'feature_key',
    v_key,
    'market',
    v_market,
    'platform',
    v_platform,
    'is_enabled',
    p_is_enabled,
    'source',
    'feature_flags'
  );
end;
$$;

alter function public.admin_set_feature_flag(text, boolean) owner to postgres;

create or replace function public.admin_upsert_feature_flag(
  p_key text,
  p_market text default 'global',
  p_platform text default 'all',
  p_enabled boolean default true,
  p_description text default null,
  p_rollout_pct integer default 100
) returns jsonb
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_admin_record_id uuid;
  v_key text := lower(trim(coalesce(p_key, '')));
  v_market text := coalesce(nullif(lower(trim(coalesce(p_market, 'global'))), ''), 'global');
  v_platform text := coalesce(nullif(lower(trim(coalesce(p_platform, 'all'))), ''), 'all');
  v_rollout_pct integer := greatest(0, least(coalesce(p_rollout_pct, 100), 100));
  v_flag_id text;
  v_before jsonb;
  v_after jsonb;
begin
  perform public.require_admin_manager_user();
  v_admin_record_id := public.active_admin_record_id();

  if v_key = '' or v_key !~ '^[a-z0-9_]+$' then
    raise exception 'Feature flag key must use lowercase snake_case';
  end if;

  if v_market = '' or v_market !~ '^[a-z_]+$' then
    raise exception 'Feature flag market must use lowercase snake_case';
  end if;

  if v_platform not in ('all', 'android', 'ios', 'web') then
    raise exception 'Invalid feature flag platform';
  end if;

  if exists (
    select 1
    from public.platform_features
    where feature_key = v_key
  ) then
    raise exception 'Feature % is managed through Platform Control', v_key;
  end if;

  v_flag_id := ((v_key || ':'::text) || v_market) || ':'::text || v_platform;

  select to_jsonb(flag_row)
  into v_before
  from public.admin_feature_flags flag_row
  where flag_row.id = v_flag_id;

  insert into public.feature_flags (
    key,
    market,
    platform,
    enabled,
    description,
    rollout_pct,
    updated_at
  ) values (
    v_key,
    v_market,
    v_platform,
    coalesce(p_enabled, true),
    nullif(trim(coalesce(p_description, '')), ''),
    v_rollout_pct,
    timezone('utc', now())
  )
  on conflict (key, market, platform) do update
  set
    enabled = excluded.enabled,
    description = excluded.description,
    rollout_pct = excluded.rollout_pct,
    updated_at = excluded.updated_at;

  select to_jsonb(flag_row)
  into v_after
  from public.admin_feature_flags flag_row
  where flag_row.id = v_flag_id;

  insert into public.admin_audit_logs (
    admin_user_id,
    action,
    module,
    target_type,
    target_id,
    before_state,
    after_state,
    metadata
  ) values (
    v_admin_record_id,
    'upsert_feature_flag',
    'settings',
    'feature_flag',
    v_flag_id,
    v_before,
    v_after,
    jsonb_build_object(
      'feature_key',
      v_key,
      'market',
      v_market,
      'platform',
      v_platform,
      'is_enabled',
      coalesce(p_enabled, true),
      'rollout_pct',
      v_rollout_pct
    )
  );

  return coalesce(
    v_after,
    jsonb_build_object(
      'id',
      v_flag_id,
      'key',
      v_key,
      'market',
      v_market,
      'platform',
      v_platform,
      'is_enabled',
      coalesce(p_enabled, true)
    )
  );
end;
$$;

alter function public.admin_upsert_feature_flag(
  text,
  text,
  text,
  boolean,
  text,
  integer
) owner to postgres;

revoke all on function public.admin_set_feature_flag(text, boolean) from public;
revoke all on function public.admin_set_feature_flag(text, boolean) from anon;
grant execute on function public.admin_set_feature_flag(text, boolean) to authenticated, service_role;

revoke all on function public.admin_upsert_feature_flag(text, text, text, boolean, text, integer) from public;
revoke all on function public.admin_upsert_feature_flag(text, text, text, boolean, text, integer) from anon;
grant execute on function public.admin_upsert_feature_flag(text, text, text, boolean, text, integer) to authenticated, service_role;

revoke all on table public.feature_flags from public;
revoke all on table public.feature_flags from anon;
revoke all on table public.feature_flags from authenticated;
grant select on table public.feature_flags to anon, authenticated;
grant all on table public.feature_flags to service_role;

revoke all on table public.admin_feature_flags from public;
revoke all on table public.admin_feature_flags from anon;
revoke all on table public.admin_feature_flags from authenticated;
grant select on table public.admin_feature_flags to authenticated, service_role;

commit;
