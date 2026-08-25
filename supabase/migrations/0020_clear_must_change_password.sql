-- must_change_password is an authority flag, so it is not in the client UPDATE
-- grant and deliberately stays out of it. Clearing it goes through a definer
-- RPC scoped strictly to the caller's own row.
create or replace function public.clear_must_change_password()
returns void
language plpgsql volatile security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  update public.profiles set must_change_password = false where id = auth.uid();
end;
$$;

revoke all on function public.clear_must_change_password() from public, anon;
grant execute on function public.clear_must_change_password() to authenticated;
