create or replace function public.book_appointment(
  p_doctor uuid,
  p_at     timestamptz,
  p_type   text,
  p_reason text default null
)
returns public.appointments
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_patient uuid := auth.uid();
  v_clinic  uuid;
  v_row     public.appointments;
begin
  if v_patient is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select clinic_id into v_clinic from public.profiles
   where id = p_doctor and role = 'doctor' and is_active;
  if v_clinic is null then
    raise exception 'doctor % is not an active doctor', p_doctor using errcode = '22023';
  end if;

  if not exists (select 1 from public.available_slots(p_doctor, p_at::date) s
                  where s.slot_at = p_at and not s.is_booked
                    and not s.is_doctor_on_leave and not s.is_past) then
    raise exception 'slot unavailable' using errcode = '23505';
  end if;

  insert into public.appointments
    (patient_id, doctor_id, clinic_id, scheduled_at, appointment_type, reason_for_visit)
  values (v_patient, p_doctor, v_clinic, p_at, p_type, p_reason)
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.reschedule_appointment(
  p_appointment uuid, p_new_at timestamptz
)
returns public.appointments
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.appointments;
begin
  select * into v_row from public.appointments where id = p_appointment;
  if v_row.id is null then
    raise exception 'appointment not found' using errcode = 'P0002';
  end if;
  if v_row.patient_id <> auth.uid() and v_row.doctor_id <> auth.uid() then
    raise exception 'not your appointment' using errcode = '42501';
  end if;
  if not exists (select 1 from public.available_slots(v_row.doctor_id, p_new_at::date) s
                  where s.slot_at = p_new_at and not s.is_booked
                    and not s.is_doctor_on_leave and not s.is_past) then
    raise exception 'slot unavailable' using errcode = '23505';
  end if;

  update public.appointments
     set scheduled_at = p_new_at, status = 'rescheduled'
   where id = p_appointment
   returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.set_appointment_status(
  p_appointment uuid, p_status public.appointment_status
)
returns public.appointments
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.appointments;
begin
  select * into v_row from public.appointments where id = p_appointment;
  if v_row.id is null then
    raise exception 'appointment not found' using errcode = 'P0002';
  end if;
  -- Patients may only cancel; doctors may set any status on their own bookings.
  if v_row.doctor_id = auth.uid() then
    null;
  elsif v_row.patient_id = auth.uid() and p_status = 'cancelled' then
    null;
  else
    raise exception 'not permitted' using errcode = '42501';
  end if;

  update public.appointments set status = p_status
   where id = p_appointment returning * into v_row;
  return v_row;
end;
$$;

-- Queue number is ordinal position that day, never stored.
create or replace function public.queue_position(p_appointment uuid)
returns int
language sql stable security definer set search_path = public, pg_temp as $$
  with target as (
    select doctor_id, scheduled_at from public.appointments where id = p_appointment
  )
  select count(*)::int
  from public.appointments a, target t
  where a.doctor_id = t.doctor_id
    and a.scheduled_at::date = t.scheduled_at::date
    and a.status <> 'cancelled'
    and a.scheduled_at <= t.scheduled_at
$$;

revoke all on function public.book_appointment(uuid, timestamptz, text, text)      from public, anon;
revoke all on function public.reschedule_appointment(uuid, timestamptz)            from public, anon;
revoke all on function public.set_appointment_status(uuid, public.appointment_status) from public, anon;
revoke all on function public.queue_position(uuid)                                 from public, anon;

grant execute on function public.book_appointment(uuid, timestamptz, text, text)      to authenticated;
grant execute on function public.reschedule_appointment(uuid, timestamptz)            to authenticated;
grant execute on function public.set_appointment_status(uuid, public.appointment_status) to authenticated;
grant execute on function public.queue_position(uuid)                                 to authenticated;
