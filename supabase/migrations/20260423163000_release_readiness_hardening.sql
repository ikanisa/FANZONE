begin;

create or replace function public.auth_user_is_anonymous(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path to public, auth
as $$
  select coalesce(
    (
      select case
        when nullif(u.raw_app_meta_data ->> 'provider', '') = 'anonymous'
          then true
        else false
      end
      from auth.users u
      where u.id = p_user_id
    ),
    false
  );
$$;

create or replace function public.auth_user_auth_method(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path to public, auth
as $$
  select coalesce(
    (
      select case
        when nullif(u.raw_app_meta_data ->> 'provider', '') = 'anonymous'
          then 'anonymous'
        when nullif(u.phone, '') is not null
          then 'phone'
        when nullif(u.email, '') is not null
          then coalesce(nullif(u.raw_app_meta_data ->> 'provider', ''), 'email')
        else nullif(u.raw_app_meta_data ->> 'provider', '')
      end
      from auth.users u
      where u.id = p_user_id
    ),
    'phone'
  );
$$;

create or replace function public.current_session_is_anonymous()
returns boolean
language sql
stable
as $$
  select coalesce(
    nullif(auth.jwt() ->> 'is_anonymous', '')::boolean,
    case
      when auth.jwt() -> 'app_metadata' ->> 'provider' = 'anonymous'
        then true
      else null
    end,
    public.auth_user_is_anonymous(auth.uid()),
    false
  );
$$;

create or replace function public.sync_profile_auth_state(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path to public, auth
as $$
declare
  v_auth_method text;
  v_is_anonymous boolean;
  v_phone text;
begin
  if p_user_id is null then
    raise exception 'User ID is required';
  end if;

  v_auth_method := public.auth_user_auth_method(p_user_id);
  v_is_anonymous := public.auth_user_is_anonymous(p_user_id);
  v_phone := public.resolve_auth_user_phone(p_user_id);

  insert into public.profiles (
    id,
    user_id,
    phone_number,
    is_anonymous,
    auth_method,
    created_at,
    updated_at
  )
  values (
    p_user_id,
    p_user_id,
    case when v_is_anonymous then null else v_phone end,
    v_is_anonymous,
    v_auth_method,
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (id) do update
  set user_id = excluded.user_id,
      phone_number = case
        when excluded.is_anonymous then profiles.phone_number
        else coalesce(excluded.phone_number, profiles.phone_number)
      end,
      is_anonymous = excluded.is_anonymous,
      auth_method = coalesce(nullif(excluded.auth_method, ''), profiles.auth_method),
      updated_at = timezone('utc', now());
end;
$$;

create or replace function public.assert_verified_account_required(
  p_message text default 'Phone verification required'
) returns void
language plpgsql
security definer
set search_path to public
as $$
declare
  v_message text := coalesce(
    nullif(btrim(p_message), ''),
    'Phone verification required'
  );
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if public.current_session_is_anonymous() then
    raise exception '%', v_message;
  end if;
end;
$$;

create or replace function public.ensure_user_foundation(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path to public
as $$
declare
  v_foundation_grant bigint := greatest(
    coalesce(public.app_config_bigint('foundation_grant_fet', 50), 50),
    0
  );
  v_current_supply bigint := 0;
  v_wallet_created boolean := false;
begin
  perform public.sync_profile_auth_state(p_user_id);

  if public.auth_user_is_anonymous(p_user_id) then
    return;
  end if;

  perform public.lock_fet_supply_cap();

  if not exists (
    select 1
    from public.fet_wallets
    where user_id = p_user_id
  ) then
    select coalesce(sum(available_balance_fet + locked_balance_fet), 0)::bigint
    into v_current_supply
    from public.fet_wallets;

    if v_current_supply + v_foundation_grant > public.fet_supply_cap() then
      raise exception 'ensure_user_foundation would exceed FET supply cap (% + % > %)',
        v_current_supply,
        v_foundation_grant,
        public.fet_supply_cap();
    end if;

    insert into public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
    values (p_user_id, v_foundation_grant, 0)
    on conflict (user_id) do nothing
    returning true into v_wallet_created;

    if coalesce(v_wallet_created, false) then
      insert into public.fet_wallet_transactions (
        user_id,
        tx_type,
        direction,
        amount_fet,
        balance_before_fet,
        balance_after_fet,
        reference_type,
        reference_id,
        title
      )
      values (
        p_user_id,
        'foundation_grant',
        'credit',
        v_foundation_grant,
        0,
        v_foundation_grant,
        'foundation_grant',
        p_user_id::text,
        'Foundation grant - welcome balance'
      );
    end if;
  end if;
end;
$$;

create or replace function public.issue_anonymous_upgrade_claim()
returns text
language plpgsql
security definer
set search_path to public, auth
as $$
declare
  v_anon_id uuid := auth.uid();
  v_claim_token text;
begin
  if v_anon_id is null then
    raise exception 'Authentication required';
  end if;

  perform public.sync_profile_auth_state(v_anon_id);

  if public.current_session_is_anonymous() is distinct from true then
    raise exception 'Anonymous session required';
  end if;

  v_claim_token := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');

  insert into public.anonymous_upgrade_claims (
    anon_user_id,
    claim_token,
    issued_at,
    expires_at,
    consumed_at,
    consumed_by_user_id
  ) values (
    v_anon_id,
    v_claim_token,
    timezone('utc', now()),
    timezone('utc', now()) + interval '30 minutes',
    null,
    null
  )
  on conflict (anon_user_id) do update
  set claim_token = excluded.claim_token,
      issued_at = excluded.issued_at,
      expires_at = excluded.expires_at,
      consumed_at = null,
      consumed_by_user_id = null;

  return v_claim_token;
end;
$$;

create or replace function public.merge_anonymous_to_authenticated_secure(
  p_anon_id uuid,
  p_claim_token text
) returns void
language plpgsql
security definer
set search_path to public, auth
as $$
declare
  v_auth_id uuid := auth.uid();
  v_claim public.anonymous_upgrade_claims%rowtype;
  v_auth_is_anonymous boolean := false;
begin
  if v_auth_id is null then
    raise exception 'Authentication required';
  end if;

  if p_anon_id is null or nullif(btrim(p_claim_token), '') is null then
    raise exception 'Anonymous user ID and claim token are required';
  end if;

  if p_anon_id = v_auth_id then
    raise exception 'Anonymous and authenticated user IDs must be different';
  end if;

  perform public.sync_profile_auth_state(v_auth_id);
  perform public.sync_profile_auth_state(p_anon_id);

  select *
  into v_claim
  from public.anonymous_upgrade_claims
  where anon_user_id = p_anon_id
    and claim_token = p_claim_token
    and consumed_at is null
    and expires_at > timezone('utc', now());

  if v_claim.anon_user_id is null then
    raise exception 'Invalid or expired upgrade claim';
  end if;

  v_auth_is_anonymous := public.current_session_is_anonymous();
  if v_auth_is_anonymous = true then
    raise exception 'Authenticated account required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.user_id = p_anon_id
      and coalesce(p.is_anonymous, false) = true
  ) then
    raise exception 'Anonymous profile not found';
  end if;

  insert into public.profiles (
    id,
    user_id,
    is_anonymous,
    auth_method,
    created_at,
    updated_at
  )
  select
    v_auth_id,
    v_auth_id,
    false,
    'phone',
    timezone('utc', now()),
    timezone('utc', now())
  where not exists (
    select 1 from public.profiles p where p.user_id = v_auth_id
  );

  insert into public.user_favorite_teams (
    user_id,
    team_id,
    team_name,
    team_short_name,
    team_country,
    team_country_code,
    team_league,
    team_crest_url,
    source,
    sort_order,
    created_at,
    updated_at
  )
  select
    v_auth_id,
    uft.team_id,
    uft.team_name,
    uft.team_short_name,
    uft.team_country,
    uft.team_country_code,
    uft.team_league,
    uft.team_crest_url,
    uft.source,
    uft.sort_order,
    uft.created_at,
    timezone('utc', now())
  from public.user_favorite_teams uft
  where uft.user_id = p_anon_id
    and not exists (
      select 1
      from public.user_favorite_teams existing
      where existing.user_id = v_auth_id
        and existing.team_id = uft.team_id
    );

  insert into public.user_followed_competitions (
    user_id,
    competition_id,
    created_at
  )
  select
    v_auth_id,
    ufc.competition_id,
    ufc.created_at
  from public.user_followed_competitions ufc
  where ufc.user_id = p_anon_id
    and not exists (
      select 1
      from public.user_followed_competitions existing
      where existing.user_id = v_auth_id
        and existing.competition_id = ufc.competition_id
    );

  update public.profiles auth_p
  set favorite_team_id = coalesce(auth_p.favorite_team_id, anon_p.favorite_team_id),
      favorite_team_name = coalesce(auth_p.favorite_team_name, anon_p.favorite_team_name),
      active_country = coalesce(auth_p.active_country, anon_p.active_country),
      country_code = coalesce(auth_p.country_code, anon_p.country_code),
      onboarding_completed = true,
      upgraded_from_anonymous_id = p_anon_id,
      is_anonymous = false,
      auth_method = coalesce(nullif(auth_p.auth_method, ''), 'phone'),
      updated_at = timezone('utc', now())
  from public.profiles anon_p
  where auth_p.user_id = v_auth_id
    and anon_p.user_id = p_anon_id;

  update public.anonymous_upgrade_claims
  set consumed_at = timezone('utc', now()),
      consumed_by_user_id = v_auth_id
  where anon_user_id = p_anon_id;

  delete from public.user_favorite_teams where user_id = p_anon_id;
  delete from public.user_followed_competitions where user_id = p_anon_id;
  delete from public.profiles where user_id = p_anon_id;
end;
$$;

create or replace function public.submit_user_prediction(
  p_match_id text,
  p_predicted_result_code text default null::text,
  p_predicted_over25 boolean default null::boolean,
  p_predicted_btts boolean default null::boolean,
  p_predicted_home_goals integer default null::integer,
  p_predicted_away_goals integer default null::integer
) returns uuid
language plpgsql
security definer
set search_path to public
as $$
declare
  v_user_id uuid;
  v_match record;
  v_prediction_id uuid;
  v_result_code text;
  v_score_result_code text;
begin
  perform public.assert_platform_feature_available(
    'predictions',
    public.request_platform_channel()
  );

  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  perform public.assert_verified_account_required(
    'Verify your WhatsApp number to submit predictions'
  );

  select id, match_date, match_status
  into v_match
  from public.matches
  where id = p_match_id;

  if not found then
    raise exception 'Match % not found', p_match_id;
  end if;

  if v_match.match_date <= now() or v_match.match_status <> 'scheduled' then
    raise exception 'Predictions are closed for this match';
  end if;

  v_result_code := case
    when p_predicted_result_code is null or trim(p_predicted_result_code) = '' then null
    else upper(trim(p_predicted_result_code))
  end;

  if v_result_code is not null and v_result_code not in ('H', 'D', 'A') then
    raise exception 'predicted_result_code must be H, D, or A';
  end if;

  if (p_predicted_home_goals is null) <> (p_predicted_away_goals is null) then
    raise exception 'predicted_home_goals and predicted_away_goals must be provided together';
  end if;

  if p_predicted_home_goals is not null and p_predicted_home_goals < 0 then
    raise exception 'predicted_home_goals must be non-negative';
  end if;

  if p_predicted_away_goals is not null and p_predicted_away_goals < 0 then
    raise exception 'predicted_away_goals must be non-negative';
  end if;

  if p_predicted_home_goals is not null and p_predicted_away_goals is not null then
    v_score_result_code := public.compute_result_code(
      p_predicted_home_goals,
      p_predicted_away_goals
    );

    if v_result_code is null then
      v_result_code := v_score_result_code;
    elsif v_result_code <> v_score_result_code then
      raise exception 'predicted_result_code must match the supplied exact score';
    end if;
  end if;

  if v_result_code is null
    and p_predicted_over25 is null
    and p_predicted_btts is null
    and p_predicted_home_goals is null
    and p_predicted_away_goals is null
  then
    raise exception 'At least one prediction input is required';
  end if;

  insert into public.user_predictions (
    user_id,
    match_id,
    predicted_result_code,
    predicted_over25,
    predicted_btts,
    predicted_home_goals,
    predicted_away_goals,
    points_awarded,
    reward_status,
    created_at,
    updated_at
  )
  values (
    v_user_id,
    p_match_id,
    v_result_code,
    p_predicted_over25,
    p_predicted_btts,
    p_predicted_home_goals,
    p_predicted_away_goals,
    0,
    'pending',
    now(),
    now()
  )
  on conflict (user_id, match_id) do update set
    predicted_result_code = excluded.predicted_result_code,
    predicted_over25 = excluded.predicted_over25,
    predicted_btts = excluded.predicted_btts,
    predicted_home_goals = excluded.predicted_home_goals,
    predicted_away_goals = excluded.predicted_away_goals,
    points_awarded = 0,
    reward_status = 'pending',
    updated_at = now()
  returning id into v_prediction_id;

  return v_prediction_id;
end;
$$;

create or replace function public.transfer_fet_by_fan_id(
  p_recipient_fan_id text,
  p_amount_fet bigint
) returns jsonb
language plpgsql
security definer
set search_path to public
as $_$
declare
  v_sender_id uuid := auth.uid();
  v_sender_fan_id text;
  v_recipient_id uuid;
  v_sender_balance bigint;
  v_recipient_balance_before bigint := 0;
  v_daily_limit integer := greatest(
    least(
      coalesce(public.app_config_bigint('wallet_transfer_daily_limit', 10), 10),
      2147483647
    )::integer,
    1
  );
  v_clean_fan_id text := regexp_replace(coalesce(p_recipient_fan_id, ''), '[^0-9]', '', 'g');
begin
  perform public.assert_platform_feature_available(
    'wallet',
    public.request_platform_channel()
  );

  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  perform public.assert_verified_account_required(
    'Verify your WhatsApp number before sending FET'
  );
  perform public.assert_wallet_available(v_sender_id);

  if not public.check_rate_limit(v_sender_id, 'transfer_fet', v_daily_limit, interval '1 day') then
    raise exception 'Rate limit exceeded — max % transfers per day', v_daily_limit;
  end if;

  if p_amount_fet is null or p_amount_fet <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  if v_clean_fan_id !~ '^\d{6}$' then
    raise exception 'Recipient Fan ID must be exactly 6 digits';
  end if;

  select fan_id
  into v_sender_fan_id
  from public.profiles
  where id = v_sender_id or user_id = v_sender_id
  limit 1;

  if v_sender_fan_id is null then
    update public.profiles
    set fan_id = public.generate_profile_fan_id(v_sender_id::text, 0, id)
    where id = v_sender_id or user_id = v_sender_id;

    select fan_id
    into v_sender_fan_id
    from public.profiles
    where id = v_sender_id or user_id = v_sender_id
    limit 1;
  end if;

  if v_sender_fan_id = v_clean_fan_id then
    raise exception 'You cannot transfer tokens to yourself.';
  end if;

  select coalesce(user_id, id)
  into v_recipient_id
  from public.profiles
  where fan_id = v_clean_fan_id
  limit 1;

  if v_recipient_id is null then
    raise exception 'Fan ID not found. Please check the number and try again.';
  end if;

  select available_balance_fet
  into v_sender_balance
  from public.fet_wallets
  where user_id = v_sender_id
  for update;

  if v_sender_balance is null or v_sender_balance < p_amount_fet then
    raise exception 'Insufficient balance';
  end if;

  insert into public.fet_wallets (user_id, available_balance_fet, locked_balance_fet)
  values (v_recipient_id, 0, 0)
  on conflict (user_id) do nothing;

  select available_balance_fet
  into v_recipient_balance_before
  from public.fet_wallets
  where user_id = v_recipient_id
  for update;

  update public.fet_wallets
  set available_balance_fet = available_balance_fet - p_amount_fet,
      updated_at = now()
  where user_id = v_sender_id;

  update public.fet_wallets
  set available_balance_fet = available_balance_fet + p_amount_fet,
      updated_at = now()
  where user_id = v_recipient_id;

  insert into public.fet_wallet_transactions (
    user_id,
    tx_type,
    direction,
    amount_fet,
    balance_before_fet,
    balance_after_fet,
    reference_type,
    reference_id,
    title
  ) values
    (
      v_sender_id,
      'transfer',
      'debit',
      p_amount_fet,
      v_sender_balance,
      v_sender_balance - p_amount_fet,
      'transfer',
      v_clean_fan_id,
      'Transfer to Fan #' || v_clean_fan_id
    ),
    (
      v_recipient_id,
      'transfer',
      'credit',
      p_amount_fet,
      coalesce(v_recipient_balance_before, 0),
      coalesce(v_recipient_balance_before, 0) + p_amount_fet,
      'transfer',
      v_sender_fan_id,
      'Transfer from Fan #' || coalesce(v_sender_fan_id, '000000')
    );

  return jsonb_build_object(
    'ok', true,
    'recipient_fan_id', v_clean_fan_id,
    'amount_fet', p_amount_fet,
    'remaining_balance_fet', v_sender_balance - p_amount_fet
  );
end;
$_$;

create or replace view public.prediction_leaderboard as
 select up.user_id,
    coalesce(
      case
        when coalesce(p.show_name_on_leaderboards, false)
          then nullif(trim(both from p.display_name), '')
        else null
      end,
      nullif(trim(both from p.fan_id), ''),
      'Fan'
    ) as display_name,
    count(*) as prediction_count,
    coalesce(sum(up.points_awarded), 0::bigint) as total_points,
    coalesce(sum(tr.token_amount) filter (where tr.status = 'awarded'), 0::numeric) as total_fet,
    count(*) filter (
      where up.predicted_result_code is not null
        and up.predicted_result_code = m.result_code
    ) as correct_results,
    count(*) filter (
      where up.predicted_home_goals is not null
        and up.predicted_away_goals is not null
        and up.predicted_home_goals = m.home_goals
        and up.predicted_away_goals = m.away_goals
    ) as exact_scores
 from public.user_predictions up
 left join public.profiles p on p.user_id = up.user_id
 left join public.matches m on m.id = up.match_id
 left join public.token_rewards tr on tr.user_prediction_id = up.id
 group by
   up.user_id,
   coalesce(
     case
       when coalesce(p.show_name_on_leaderboards, false)
         then nullif(trim(both from p.display_name), '')
       else null
     end,
     nullif(trim(both from p.fan_id), ''),
     'Fan'
   );

create or replace function public.get_public_leaderboard_rank(
  p_user_id uuid default auth.uid()
) returns integer
language sql
stable
security definer
set search_path to public
as $$
  with ranked as (
    select
      user_id,
      dense_rank() over (
        order by total_fet desc, total_points desc, prediction_count desc, user_id
      )::integer as rank
    from public.public_leaderboard
  )
  select rank
  from ranked
  where user_id = p_user_id
  limit 1;
$$;

update public.match_alert_subscriptions
set alert_goals = false
where alert_goals is distinct from false;

revoke all on function public.assert_verified_account_required(text) from public;
revoke all on function public.assert_verified_account_required(text) from anon;
grant all on function public.assert_verified_account_required(text) to service_role;

revoke all on function public.get_public_leaderboard_rank(uuid) from public;
revoke all on function public.get_public_leaderboard_rank(uuid) from anon;
grant all on function public.get_public_leaderboard_rank(uuid) to authenticated, service_role;

commit;
