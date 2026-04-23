begin;

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
    execute format('revoke all on function %s from public', routine);
    execute format('grant all on function %s to authenticated', routine);
    execute format('grant all on function %s to service_role', routine);
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
        'send_push_to_user'
      )
  loop
    execute format('revoke all on function %s from public', routine);
    execute format('grant all on function %s to service_role', routine);
  end loop;
end;
$$;

commit;
