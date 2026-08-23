-- Registration writes profiles, patient_profiles and the doctor assignment.
-- profiles has no INSERT policy and deliberately never gets one: a client that
-- could insert its own profile row could name its own role. Definer rights let
-- this run without opening that door, and put all three writes in one
-- transaction so a failure cannot strand a half-created account.
create or replace function public.register_patient(
  p_full_name text, p_email text
)
returns public.profiles
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_clinic uuid;
  v_row    public.profiles;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'that account already has a profile' using errcode = '23505';
  end if;

  select id into v_clinic from public.clinics order by name limit 1;
  if v_clinic is null then
    raise exception 'no clinic is configured' using errcode = 'P0002';
  end if;

  -- Role is set here, never accepted from the caller. Self-service
  -- registration is always a patient.
  insert into public.profiles (id, email, full_name, role, clinic_id)
  values (auth.uid(), p_email, p_full_name, 'patient', v_clinic)
  returning * into v_row;

  -- height/weight are NOT NULL with no default; onboarding collects them at
  -- step 1 and overwrites these placeholders.
  insert into public.patient_profiles (id, height_cm, weight_kg)
  values (auth.uid(), 0, 0);

  -- A clinic with no active doctor must not block registration, so only the
  -- "no doctor available" case is swallowed. Anything else propagates.
  begin
    perform public.assign_default_doctor(auth.uid());
  exception when sqlstate 'P0002' then
    null;
  end;

  return v_row;
end;
$$;

revoke all on function public.register_patient(text, text) from public, anon;
grant execute on function public.register_patient(text, text) to authenticated;
