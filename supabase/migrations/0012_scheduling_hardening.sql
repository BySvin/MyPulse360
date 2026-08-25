-- (a) Scope unavailability reads. `using (true)` exposed every staff member's
-- leave reasons to every authenticated user, patients included. available_slots
-- is SECURITY DEFINER and bypasses RLS, so slot generation is unaffected.
drop policy if exists staff_unavailability_read on public.staff_unavailability;

create policy staff_unavailability_read on public.staff_unavailability
  for select to authenticated
  using (
    staff_id = auth.uid()
    or (public.auth_role() = 'doctor'
        and exists (select 1 from public.profiles p
                     where p.id = public.staff_unavailability.staff_id
                       and p.clinic_id = public.auth_clinic()))
  );

-- (b) Anchor the leave-window comparison to UTC, matching available_slots.
-- `scheduled_at::date` resolved through the session TimeZone; an appointment
-- near a window boundary could be missed or wrongly cancelled.
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
       and (scheduled_at at time zone 'UTC')::date
           between v_row.start_date and v_row.end_date;

    get diagnostics v_cancelled = row_count;
  end if;

  -- Notify the requester, matching the tested mock behaviour
  -- ("decideLeave stamps who decided and notifies the requester").
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
