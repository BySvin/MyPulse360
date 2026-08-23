-- assign_default_doctor's doctor branch was role-gated only ("is a doctor?")
-- and never clinic-scoped ("is a doctor at this patient's clinic?"). Any
-- authenticated doctor holding a patient's UUID could rewrite that patient's
-- assigned_doctor_id regardless of clinic. decide_leave already gates on
-- auth_clinic(); this brings assign_default_doctor's authorization block in
-- line with that pattern. Everything else in the function is unchanged.
create or replace function public.assign_default_doctor(p_patient uuid)
returns uuid
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_clinic uuid;
  v_doctor uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  -- A patient assigns their own. A doctor may act for someone else, but only
  -- within their own clinic: role alone let any doctor anywhere rewrite any
  -- patient's care team.
  if p_patient <> auth.uid() then
    if public.auth_role() <> 'doctor' then
      raise exception 'may only assign a doctor to your own profile'
        using errcode = '42501';
    end if;
    -- One `exists` covering both conditions, so an absent profile and a
    -- profile at another clinic give the same refusal — a doctor cannot use
    -- this to probe for patients elsewhere.
    if not exists (select 1 from public.profiles p
                    where p.id = p_patient and p.clinic_id = public.auth_clinic()) then
      raise exception 'that patient is not at your clinic' using errcode = '42501';
    end if;
  end if;

  select clinic_id into v_clinic from public.profiles where id = p_patient;
  if v_clinic is null then
    raise exception 'no profile for that patient' using errcode = 'P0002';
  end if;

  -- Fewest current patients first, so sign-ups spread across the clinic
  -- instead of all landing on whichever doctor sorts first.
  select d.id into v_doctor
  from public.doctor_profiles d
  join public.profiles p on p.id = d.id
  left join public.patient_profiles pp on pp.assigned_doctor_id = d.id
  where d.clinic_id = v_clinic and p.is_active
  group by d.id
  order by count(pp.id), d.id
  limit 1;

  if v_doctor is null then
    raise exception 'that clinic has no active doctor' using errcode = 'P0002';
  end if;

  update public.patient_profiles set assigned_doctor_id = v_doctor where id = p_patient;
  return v_doctor;
end;
$$;

revoke all on function public.assign_default_doctor(uuid) from public, anon;
grant execute on function public.assign_default_doctor(uuid) to authenticated;
