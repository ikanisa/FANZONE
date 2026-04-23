begin;

-- Normalize legacy profile favorite-team references before adding a FK.
update public.profiles as p
set
  favorite_team_id = ta.team_id,
  updated_at = timezone('utc', now())
from public.team_aliases as ta
where p.favorite_team_id is not null
  and not exists (
    select 1
    from public.teams as t
    where t.id = p.favorite_team_id
  )
  and ta.alias_name = p.favorite_team_id
  and exists (
    select 1
    from public.teams as t
    where t.id = ta.team_id
  );

update public.profiles as p
set
  favorite_team_id = null,
  updated_at = timezone('utc', now())
where p.favorite_team_id is not null
  and not exists (
    select 1
    from public.teams as t
    where t.id = p.favorite_team_id
  );

drop trigger if exists trg_matches_set_updated_at on public.matches;

drop policy if exists "Admin write competitions" on public.competitions;
drop policy if exists "Public read access for competitions" on public.competitions;
drop policy if exists "Admin write matches" on public.matches;
drop policy if exists "Public read access for matches" on public.matches;
drop policy if exists "Public read access for teams" on public.teams;
drop policy if exists "Public read featured events" on public.featured_events;
drop policy if exists "Public read currency rates" on public.currency_rates;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.matches'::regclass
      and conname = 'matches_season_id_fkey'
  ) then
    alter table public.matches
      add constraint matches_season_id_fkey
      foreign key (season_id)
      references public.seasons(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_favorite_team_id_fkey'
  ) then
    alter table public.profiles
      add constraint profiles_favorite_team_id_fkey
      foreign key (favorite_team_id)
      references public.teams(id)
      on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.user_favorite_teams'::regclass
      and conname = 'user_favorite_teams_team_id_fkey'
  ) then
    alter table public.user_favorite_teams
      add constraint user_favorite_teams_team_id_fkey
      foreign key (team_id)
      references public.teams(id)
      on delete cascade;
  end if;
end;
$$;

do $$
declare
  routine regprocedure;
begin
  for routine in
    select p.oid::regprocedure
    from pg_proc as p
    join pg_namespace as n
      on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'admin_%'
  loop
    execute format('revoke all on function %s from anon', routine);
  end loop;

  for routine in
    select p.oid::regprocedure
    from pg_proc as p
    join pg_namespace as n
      on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'cleanup_expired_otps',
        'cleanup_rate_limits',
        'notify_wallet_credit',
        'refresh_materialized_views',
        'send_push_to_user'
      )
  loop
    execute format('revoke all on function %s from anon', routine);
    execute format('revoke all on function %s from authenticated', routine);
  end loop;
end;
$$;

do $$
declare
  job_name text;
  job_id bigint;
begin
  foreach job_name in array array[
    'market-sync-openfootball',
    'fanzone-currency-rates-daily',
    'fanzone-team-news-hourly',
    'cleanup-match-sync-log',
    'cleanup-old-update-runs',
    'daily-screenshot-odds'
  ]
  loop
    select jobid
    into job_id
    from cron.job
    where cron.job.jobname = job_name
    limit 1;

    if job_id is not null then
      perform cron.unschedule(job_id);
    end if;
  end loop;
end;
$$;

commit;
