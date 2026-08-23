-- is_active is an authority column: an earlier migration revoked UPDATE on it
-- from clients on purpose. Staff activation therefore goes through a definer
-- RPC, doctor-only and clinic-scoped, rather than a direct table write.
create or replace function public.set_account_active(
  p_user uuid, p_active boolean
)
returns public.profiles
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.profiles;
begin
  if public.auth_role() <> 'doctor' then
    raise exception 'only doctors manage staff accounts' using errcode = '42501';
  end if;

  -- Deactivating yourself would lock you out with no way back in.
  if p_user = auth.uid() then
    raise exception 'you cannot deactivate your own account' using errcode = '42501';
  end if;

  -- One `exists` covering staff-ness and clinic, so a doctor cannot use the
  -- refusal message to probe for accounts elsewhere. Patients are excluded:
  -- this is staff management, not a general account switch.
  if not exists (select 1 from public.profiles p
                  where p.id = p_user
                    and p.clinic_id = public.auth_clinic()
                    and p.role <> 'patient') then
    raise exception 'that staff member is not at your clinic' using errcode = '42501';
  end if;

  update public.profiles set is_active = p_active where id = p_user
  returning * into v_row;
  return v_row;
end;
$$;

revoke all on function public.set_account_active(uuid, boolean) from public, anon;
grant execute on function public.set_account_active(uuid, boolean) to authenticated;
