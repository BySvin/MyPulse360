-- The booking calendar needs two facts per day: are there any open slots, and
-- is the doctor on leave. Deriving that from available_slots() one day at a
-- time costs 31 round trips per month view. This answers the whole month in
-- one call.
create or replace function public.month_availability(
  p_doctor uuid, p_month date
)
returns table (day date, open_slots int, is_on_leave boolean)
language sql stable security definer set search_path = public, pg_temp as $$
  with days as (
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
               (d.day + a.start_time) at time zone 'UTC',
               (d.day + a.end_time) at time zone 'UTC' - make_interval(mins => a.slot_minutes),
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

revoke all on function public.month_availability(uuid, date) from public, anon;
grant execute on function public.month_availability(uuid, date) to authenticated;
