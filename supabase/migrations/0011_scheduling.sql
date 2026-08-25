create table public.shifts (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references public.profiles(id) on delete cascade,
  clinic_id  uuid not null references public.clinics(id),
  start_at   timestamptz not null,
  end_at     timestamptz not null,
  status     public.shift_status not null default 'scheduled',
  notes      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shifts_window check (end_at > start_at)
);
create index shifts_staff_idx on public.shifts (staff_id, start_at);

create table public.leave_requests (
  id           uuid primary key default gen_random_uuid(),
  staff_id     uuid not null references public.profiles(id) on delete cascade,
  start_date   date not null,
  end_date     date not null,
  reason       text not null,
  status       public.leave_status not null default 'pending',
  requested_at timestamptz not null default now(),
  decided_by   uuid references public.profiles(id),
  decided_at   timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint leave_window check (end_date >= start_date)
);
create index leave_requests_staff_idx on public.leave_requests (staff_id, start_date);

create table public.staff_unavailability (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references public.profiles(id) on delete cascade,
  date       date not null,
  reason     text,
  created_at timestamptz not null default now(),
  unique (staff_id, date)
);

create table public.attendance_records (
  id           uuid primary key default gen_random_uuid(),
  staff_id     uuid not null references public.profiles(id) on delete cascade,
  shift_id     uuid references public.shifts(id),
  clock_in_at  timestamptz not null default now(),
  clock_out_at timestamptz,
  created_at   timestamptz not null default now(),
  constraint attendance_window check (clock_out_at is null or clock_out_at > clock_in_at)
);
-- A second clock-in while one is open must be impossible.
create unique index attendance_one_open_per_staff
  on public.attendance_records (staff_id) where clock_out_at is null;

create table public.staff_notifications (
  id         uuid primary key default gen_random_uuid(),
  staff_id   uuid not null references public.profiles(id) on delete cascade,
  message    text not null,
  sent_at    timestamptz not null default now(),
  read_at    timestamptz
);
create index staff_notifications_staff_idx on public.staff_notifications (staff_id, sent_at desc);

create trigger shifts_touch         before update on public.shifts         for each row execute function public.set_updated_at();
create trigger leave_requests_touch before update on public.leave_requests for each row execute function public.set_updated_at();

alter table public.shifts               enable row level security;
alter table public.leave_requests       enable row level security;
alter table public.staff_unavailability enable row level security;
alter table public.attendance_records   enable row level security;
alter table public.staff_notifications  enable row level security;

-- Staff see their own rows; doctors act as managers for their clinic.
create policy shifts_read on public.shifts
  for select to authenticated
  using (staff_id = auth.uid()
         or (public.auth_role() = 'doctor' and clinic_id = public.auth_clinic()));
create policy shifts_write_manager on public.shifts
  for all to authenticated
  using (public.auth_role() = 'doctor' and clinic_id = public.auth_clinic())
  with check (public.auth_role() = 'doctor' and clinic_id = public.auth_clinic());

create policy leave_requests_read on public.leave_requests
  for select to authenticated
  using (staff_id = auth.uid()
         or (public.auth_role() = 'doctor'
             and exists (select 1 from public.profiles p
                          where p.id = public.leave_requests.staff_id
                            and p.clinic_id = public.auth_clinic())));

-- Filing and deciding leave both go through RPCs, because approving leave has
-- to cancel appointments in the same transaction.
revoke insert, update, delete on public.leave_requests from authenticated;

create policy staff_unavailability_read on public.staff_unavailability
  for select to authenticated using (true);
create policy staff_unavailability_write_own on public.staff_unavailability
  for all to authenticated
  using (staff_id = auth.uid()) with check (staff_id = auth.uid());

create policy attendance_read on public.attendance_records
  for select to authenticated
  using (staff_id = auth.uid()
         or (public.auth_role() = 'doctor'
             and exists (select 1 from public.profiles p
                          where p.id = public.attendance_records.staff_id
                            and p.clinic_id = public.auth_clinic())));
revoke insert, update, delete on public.attendance_records from authenticated;

create policy staff_notifications_read_own on public.staff_notifications
  for select to authenticated using (staff_id = auth.uid());
create policy staff_notifications_mark_read on public.staff_notifications
  for update to authenticated
  using (staff_id = auth.uid()) with check (staff_id = auth.uid());

-- Lives here, not in Task 4: this is a `language sql` body, so Postgres
-- resolves `leave_requests` and `staff_unavailability` against the catalog at
-- CREATE FUNCTION time. It cannot be created before those tables exist.
-- Task 4's book_appointment already calls it; that is legal because plpgsql
-- bodies are not resolved until run time.
create or replace function public.available_slots(p_doctor uuid, p_date date)
returns table (
  slot_at timestamptz, is_booked boolean,
  is_doctor_on_leave boolean, is_past boolean
)
language sql stable security definer set search_path = public, pg_temp as $$
  with avail as (
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
    -- `p_date + start_time` is a timestamp WITHOUT time zone. Left implicit,
    -- the cast to timestamptz would use the connection's TimeZone setting, so
    -- two clients in different zones would compute different absolute slots.
    -- Anchor to UTC explicitly; `appointments.scheduled_at` is timestamptz.
    select generate_series(
             (p_date + a.start_time) at time zone 'UTC',
             (p_date + a.end_time) at time zone 'UTC' - make_interval(mins => a.slot_minutes),
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

create or replace function public.apply_leave(
  p_start date, p_end date, p_reason text
)
returns public.leave_requests
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.leave_requests;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if public.auth_role() = 'patient' then
    raise exception 'patients do not file leave' using errcode = '42501';
  end if;
  if p_end < p_start then
    raise exception 'end date precedes start date' using errcode = '22023';
  end if;

  insert into public.leave_requests (staff_id, start_date, end_date, reason)
  values (auth.uid(), p_start, p_end, p_reason)
  returning * into v_row;

  return v_row;
end;
$$;

-- Approving leave cancels the appointments it collides with and tells the
-- affected patients, in one transaction. This mirrors apply_leave_usecase.dart.
create or replace function public.decide_leave(
  p_request uuid, p_status public.leave_status
)
returns public.leave_requests
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_row       public.leave_requests;
  v_cancelled int := 0;
begin
  if public.auth_role() <> 'doctor' then
    raise exception 'only doctors decide leave' using errcode = '42501';
  end if;
  if p_status = 'pending' then
    raise exception 'decision must be approved or denied' using errcode = '22023';
  end if;

  update public.leave_requests
     set status = p_status, decided_by = auth.uid(), decided_at = now()
   where id = p_request
   returning * into v_row;

  if v_row.id is null then
    raise exception 'leave request not found' using errcode = 'P0002';
  end if;

  if p_status = 'approved' then
    update public.appointments
       set status = 'cancelled'
     where doctor_id = v_row.staff_id
       and status <> 'cancelled'
       and scheduled_at::date between v_row.start_date and v_row.end_date;

    get diagnostics v_cancelled = row_count;
  end if;

  -- Notify the requester, matching the tested mock behaviour
  -- ("decideLeave stamps who decided and notifies the requester").
  -- staff_notifications is keyed by staff_id; patient-facing notification is
  -- a separate concern with no entity in the app yet, so it is not done here.
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

create or replace function public.clock_in(p_shift uuid default null)
returns public.attendance_records
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.attendance_records;
begin
  -- An already-open record is returned as-is rather than raising, matching the
  -- tested mock behaviour.
  select * into v_row from public.attendance_records
   where staff_id = auth.uid() and clock_out_at is null;
  if v_row.id is not null then
    return v_row;
  end if;

  insert into public.attendance_records (staff_id, shift_id)
  values (auth.uid(), p_shift)
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.clock_out()
returns public.attendance_records
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.attendance_records;
begin
  update public.attendance_records
     set clock_out_at = now()
   where staff_id = auth.uid() and clock_out_at is null
   returning * into v_row;

  if v_row.id is null then
    raise exception 'no open attendance record' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

revoke all on function public.available_slots(uuid, date)                  from public, anon;
revoke all on function public.apply_leave(date, date, text)                from public, anon;
revoke all on function public.decide_leave(uuid, public.leave_status)      from public, anon;
revoke all on function public.clock_in(uuid)                               from public, anon;
revoke all on function public.clock_out()                                  from public, anon;

grant execute on function public.available_slots(uuid, date)               to authenticated;
grant execute on function public.apply_leave(date, date, text)             to authenticated;
grant execute on function public.decide_leave(uuid, public.leave_status)   to authenticated;
grant execute on function public.clock_in(uuid)                            to authenticated;
grant execute on function public.clock_out()                               to authenticated;
