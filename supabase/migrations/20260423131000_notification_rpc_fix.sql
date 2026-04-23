begin;

create or replace function public.mark_all_notifications_read()
returns void
language plpgsql
security definer
set search_path to public
as $$
begin
  perform public.assert_platform_feature_available(
    'notifications',
    public.request_platform_channel()
  );

  update public.notification_log
  set read_at = coalesce(read_at, now())
  where user_id = auth.uid()
    and read_at is null;
end;
$$;

create or replace function public.mark_notification_read(
  p_notification_id uuid
) returns void
language plpgsql
security definer
set search_path to public
as $$
begin
  perform public.assert_platform_feature_available(
    'notifications',
    public.request_platform_channel()
  );

  update public.notification_log
  set read_at = coalesce(read_at, now())
  where id = p_notification_id
    and user_id = auth.uid();
end;
$$;

revoke all on function public.mark_all_notifications_read() from public;
revoke all on function public.mark_all_notifications_read() from anon;
grant all on function public.mark_all_notifications_read() to authenticated, service_role;

revoke all on function public.mark_notification_read(uuid) from public;
revoke all on function public.mark_notification_read(uuid) from anon;
grant all on function public.mark_notification_read(uuid) to authenticated, service_role;

commit;
