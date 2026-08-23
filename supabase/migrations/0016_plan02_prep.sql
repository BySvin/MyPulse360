-- Plan 01 removed the DELETE policies on these five but not the table grants,
-- leaving the grant and policy layers disagreeing. RLS already denies, so this
-- closes an inconsistency rather than a hole.
revoke delete on public.consultations     from authenticated;
revoke delete on public.prescriptions     from authenticated;
revoke delete on public.health_metrics    from authenticated;
revoke delete on public.inventory_items   from authenticated;
revoke delete on public.inventory_batches from authenticated;

-- Nothing client-side can set patient_profiles.assigned_doctor_id — Plan 01
-- revoked that column deliberately, so a patient cannot pick their own doctor.
-- Sign-up still has to assign one, so it happens here with definer rights.
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
  if p_patient <> auth.uid() and public.auth_role() <> 'doctor' then
    raise exception 'may only assign a doctor to your own profile'
      using errcode = '42501';
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

-- decide_leave raised "not found" / "already decided" before its clinic check,
-- so a doctor holding a request UUID could distinguish states at other clinics.
-- Same body, clinic check moved above the status checks.
create or replace function public.decide_leave(
  p_request uuid, p_status public.leave_status
)
returns public.leave_requests
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_row       public.leave_requests;
  v_cancelled int := 0;
  v_current   public.leave_status;
begin
  if public.auth_role() <> 'doctor' then
    raise exception 'only doctors decide leave' using errcode = '42501';
  end if;
  if p_status = 'pending' then
    raise exception 'decision must be approved or denied' using errcode = '22023';
  end if;

  -- Clinic first: a caller outside the clinic learns nothing about whether the
  -- request exists or what state it is in.
  if not exists (select 1 from public.profiles p
                  join public.leave_requests l on l.staff_id = p.id
                 where l.id = p_request and p.clinic_id = public.auth_clinic()) then
    raise exception 'that staff member is not at your clinic' using errcode = '42501';
  end if;

  select status into v_current from public.leave_requests where id = p_request;
  if v_current is null then
    raise exception 'leave request not found' using errcode = 'P0002';
  end if;
  if v_current <> 'pending' then
    raise exception 'leave request was already %', v_current using errcode = '22023';
  end if;

  update public.leave_requests
     set status = p_status, decided_by = auth.uid(), decided_at = now()
   where id = p_request
   returning * into v_row;

  if p_status = 'approved' then
    update public.appointments
       set status = 'cancelled'
     where doctor_id = v_row.staff_id
       and status <> 'cancelled'
       and (scheduled_at at time zone 'UTC')::date
           between v_row.start_date and v_row.end_date;

    get diagnostics v_cancelled = row_count;
  end if;

  insert into public.staff_notifications (staff_id, message)
  values (v_row.staff_id,
          'Your leave request for '
          || to_char(v_row.start_date, 'DD Mon YYYY') || ' to '
          || to_char(v_row.end_date, 'DD Mon YYYY')
          || ' was ' || p_status::text
          || case when p_status = 'approved'
                  then '. ' || v_cancelled || ' appointment(s) were cancelled.'
                  else '.' end);

  return v_row;
end;
$$;
