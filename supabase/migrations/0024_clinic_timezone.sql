-- Slot generation was anchored to UTC, so a clinic whose `doctor_availability`
-- says 09:00-17:00 was actually open 09:00-17:00 *UTC* — 5pm to 1am in Kuala
-- Lumpur. The system was self-consistent (a patient picked "9:00" and saw
-- "9:00" everywhere) which is exactly why it was easy to miss: nothing
-- contradicted anything, the whole clinic was simply running in the wrong zone.
--
-- `doctor_availability.start_time` / `end_time` are `time without time zone`.
-- They always meant clinic wall-clock time. This migration makes the database
-- read them that way.
--
-- Anchoring to UTC was a deliberate choice, not an accident: the original
-- comment explains that leaving the cast implicit would resolve against the
-- *connection's* TimeZone, so two clients in different zones would compute
-- different absolute slots. That reasoning was right. The fix is to anchor to
-- the clinic's zone — still a fixed, server-side value — rather than to UTC.

-- ---------------------------------------------------------------------------
-- 1. Where the clinic's zone lives
-- ---------------------------------------------------------------------------

alter table public.clinics
  add column if not exists timezone text not null default 'Asia/Kuala_Lumpur';

comment on column public.clinics.timezone is
  'IANA zone the clinic''s opening hours are expressed in. Server-managed: '
  'clients hold SELECT on clinics and nothing else, so this is not writable '
  'by any client. Changing it moves every future slot for that clinic.';

-- ---------------------------------------------------------------------------
-- 2. Resolving a doctor's clinic zone
-- ---------------------------------------------------------------------------
--
-- Created before the functions below because a `language sql` body is
-- validated at CREATE FUNCTION time, not at call time — a function that
-- referenced this one before it existed would fail to create.
--
-- Falls back to UTC rather than raising: a doctor with no clinic row is a data
-- problem, and returning no slots is a better failure than an exception in the
-- middle of a calendar render.
create or replace function public.clinic_tz(p_doctor uuid)
returns text
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(c.timezone, 'UTC')
  from public.profiles p
  left join public.clinics c on c.id = p.clinic_id
  where p.id = p_doctor
$$;

revoke all on function public.clinic_tz(uuid) from public, anon;
grant execute on function public.clinic_tz(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Slot generation, in clinic time
-- ---------------------------------------------------------------------------

create or replace function public.available_slots(p_doctor uuid, p_date date)
returns table(slot_at timestamptz, is_booked boolean,
              is_doctor_on_leave boolean, is_past boolean)
language sql stable security definer set search_path = public, pg_temp as $$
  with tz as (
    select public.clinic_tz(p_doctor) as zone
  ),
  avail as (
    select start_time, end_time, slot_minutes
    from public.doctor_availability
    where doctor_id = p_doctor
      and weekday = extract(isodow from p_date)::smallint - 1
  ),
  on_leave as (
    select exists (
      select 1 from public.leave_requests l
      where l.staff_id = p_doctor and l.status = 'approved'
        and p_date between l.start_date and l.end_date
    ) or exists (
      select 1 from public.staff_unavailability u
      where u.staff_id = p_doctor and u.date = p_date
    ) as flag
  ),
  slots as (
    -- `p_date + start_time` is a timestamp WITHOUT time zone holding the
    -- clinic's wall-clock time. `at time zone <clinic zone>` reads it as a
    -- local time in that zone and yields the correct absolute instant,
    -- independently of the connection's TimeZone setting.
    select generate_series(
             (p_date + a.start_time) at time zone (select zone from tz),
             (p_date + a.end_time)   at time zone (select zone from tz)
               - make_interval(mins => a.slot_minutes),
             make_interval(mins => a.slot_minutes)
           ) as slot_at
    from avail a
  )
  select s.slot_at,
         exists (
           select 1 from public.appointments ap
           where ap.doctor_id = p_doctor
             and ap.scheduled_at = s.slot_at
             and ap.status <> 'cancelled'
         ) as is_booked,
         (select flag from on_leave) as is_doctor_on_leave,
         s.slot_at < now() as is_past
  from slots s
  order by s.slot_at
$$;

create or replace function public.month_availability(p_doctor uuid, p_month date)
returns table(day date, open_slots integer, is_on_leave boolean)
language sql stable security definer set search_path = public, pg_temp as $$
  with tz as (
    select public.clinic_tz(p_doctor) as zone
  ),
  days as (
    select generate_series(
             date_trunc('month', p_month)::date,
             (date_trunc('month', p_month) + interval '1 month - 1 day')::date,
             interval '1 day'
           )::date as day
  ),
  leave as (
    select d.day,
           exists (select 1 from public.leave_requests l
                    where l.staff_id = p_doctor and l.status = 'approved'
                      and d.day between l.start_date and l.end_date)
        or exists (select 1 from public.staff_unavailability u
                    where u.staff_id = p_doctor and u.date = d.day) as flag
    from days d
  ),
  slots as (
    select d.day,
           count(*) filter (
             where not exists (
               select 1 from public.appointments ap
               where ap.doctor_id = p_doctor
                 and ap.scheduled_at = s.slot_at
                 and ap.status <> 'cancelled'
             ) and s.slot_at > now()
           )::int as open_slots
    from days d
    join public.doctor_availability a
      on a.doctor_id = p_doctor
     and a.weekday = extract(isodow from d.day)::smallint - 1
    cross join lateral (
      select generate_series(
               (d.day + a.start_time) at time zone (select zone from tz),
               (d.day + a.end_time)   at time zone (select zone from tz)
                 - make_interval(mins => a.slot_minutes),
               make_interval(mins => a.slot_minutes)
             ) as slot_at
    ) s
    group by d.day
  )
  select d.day,
         coalesce(sl.open_slots, 0) as open_slots,
         l.flag as is_on_leave
  from days d
  left join slots sl on sl.day = d.day
  join leave l on l.day = d.day
  order by d.day
$$;

-- ---------------------------------------------------------------------------
-- 4. The write paths must ask for the right day
-- ---------------------------------------------------------------------------
--
-- Both of these looked up candidate slots with `p_at::date`, which resolves in
-- the *server's* TimeZone (UTC). For a UTC+8 clinic open 09:00-17:00 the UTC
-- date happens to match, so this was invisible — but for any clinic whose
-- opening hours straddle midnight UTC it would look up the wrong day and
-- refuse a slot that exists. Ask in clinic time instead.

create or replace function public.book_appointment(
  p_doctor uuid, p_at timestamptz, p_type text, p_reason text default null
) returns public.appointments
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_patient uuid := auth.uid();
  v_clinic  uuid;
  v_day     date;
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

  v_day := (p_at at time zone public.clinic_tz(p_doctor))::date;

  if not exists (select 1 from public.available_slots(p_doctor, v_day) s
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
) returns public.appointments
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_row public.appointments;
  v_day date;
begin
  select * into v_row from public.appointments where id = p_appointment;
  if v_row.id is null then
    raise exception 'appointment not found' using errcode = 'P0002';
  end if;
  if v_row.patient_id <> auth.uid() and v_row.doctor_id <> auth.uid() then
    raise exception 'not your appointment' using errcode = '42501';
  end if;

  v_day := (p_new_at at time zone public.clinic_tz(v_row.doctor_id))::date;

  if not exists (select 1 from public.available_slots(v_row.doctor_id, v_day) s
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
