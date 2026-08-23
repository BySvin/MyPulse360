-- Final review fix wave. Findings 1-7 from the whole-branch review of the
-- Supabase schema, applied verbatim from
-- .superpowers/sdd/2026-08-22-supabase-database-foundation/final-fix-brief.md.
--
-- Correcting a claim made elsewhere (finding 10): 0009_pharmacy.sql:125-127
-- says "stock decrements go through the RPC so batch quantity can never drift
-- from the dispense log." That guarantee only holds for dispense_records,
-- which is revoked from authenticated. inventory_batches itself remains
-- pharmacist-writable by this migration (see the insert/update policies
-- below) -- pharmacists need direct writes to receive stock and to correct a
-- stock-take. The spec's Section 6 write-discipline list overstates this as
-- if inventory_batches were RPC-only too; it is not, and that is by design.
-- This migration does not change that behaviour.

-- ============================================================================
-- 1. CRITICAL -- a patient can rewrite a doctor's prescription
-- ============================================================================
-- prescription_items_write's unqualified `pr.patient_id = auth.uid()` branch
-- let a patient UPDATE/INSERT medication items on a prescription their doctor
-- issued, while the parent prescriptions row still read as doctor-authored
-- (source = 'in_app'). A pharmacist would then dispense against the altered
-- items. The intent was "a patient may manage items on the scanned
-- prescription they filed themselves" -- prescriptions_insert_scanned
-- carries source = 'scanned_external'; the items policy never got the same
-- qualifier.
drop policy if exists prescription_items_write on public.prescription_items;

-- The issuing doctor owns the items on an in-app prescription.
create policy prescription_items_write_doctor on public.prescription_items
  for all to authenticated
  using (exists (select 1 from public.prescriptions pr
                  where pr.id = prescription_items.prescription_id
                    and pr.doctor_id = auth.uid()))
  with check (exists (select 1 from public.prescriptions pr
                       where pr.id = prescription_items.prescription_id
                         and pr.doctor_id = auth.uid()));

-- A patient may only manage items on a prescription they scanned in themselves.
-- Without the source check this is prescription forgery: the parent row still
-- reads as doctor-authored while its medications say whatever the patient likes.
create policy prescription_items_write_scanned on public.prescription_items
  for all to authenticated
  using (exists (select 1 from public.prescriptions pr
                  where pr.id = prescription_items.prescription_id
                    and pr.patient_id = auth.uid()
                    and pr.source = 'scanned_external'))
  with check (exists (select 1 from public.prescriptions pr
                       where pr.id = prescription_items.prescription_id
                         and pr.patient_id = auth.uid()
                         and pr.source = 'scanned_external'));

-- ============================================================================
-- 2. decide_leave has no clinic scoping
-- ============================================================================
-- decide_leave checked only auth_role() = 'doctor'. The function is SECURITY
-- DEFINER, so it bypasses the correctly clinic-scoped leave_requests_read. A
-- doctor at clinic B could approve leave for a doctor at clinic A and cancel
-- all their appointments. Every table policy enforces tenancy; this RPC never
-- consulted auth_clinic(). The deferred status = 'pending' guard is folded in
-- here with its own error path.
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

  select status into v_current from public.leave_requests where id = p_request;
  if v_current is null then
    raise exception 'leave request not found' using errcode = 'P0002';
  end if;

  -- Already decided. Re-deciding would send a second notification and re-run
  -- the cancellation sweep, so refuse with a message that says what happened
  -- rather than a misleading "not found".
  if v_current <> 'pending' then
    raise exception 'leave request was already %', v_current using errcode = '22023';
  end if;

  -- This RPC is SECURITY DEFINER and so bypasses leave_requests_read, which is
  -- clinic-scoped. Without this check a doctor could decide leave for staff at
  -- any clinic and cancel their appointments.
  if not exists (select 1 from public.profiles p
                  join public.leave_requests l on l.staff_id = p.id
                 where l.id = p_request and p.clinic_id = public.auth_clinic()) then
    raise exception 'that staff member is not at your clinic' using errcode = '42501';
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

-- ============================================================================
-- 3. clock_in has no role guard
-- ============================================================================
-- A patient could clock in and create attendance_records. apply_leave rejects
-- patients; clock_in did not. It also never checked that p_shift belongs to
-- the caller.
create or replace function public.clock_in(p_shift uuid default null)
returns public.attendance_records
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_row public.attendance_records;
begin
  if public.auth_role() = 'patient' then
    raise exception 'patients do not clock in' using errcode = '42501';
  end if;

  if p_shift is not null and not exists (
       select 1 from public.shifts s where s.id = p_shift and s.staff_id = auth.uid()) then
    raise exception 'that shift does not belong to you' using errcode = '42501';
  end if;

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

-- ============================================================================
-- 4. Policies that let a client delete clinical records
-- ============================================================================
-- 0003_identity_hardening.sql already established the lesson -- `for all`
-- also grants DELETE -- and fixed it for patient_profiles. Six later
-- migrations reintroduced the pattern. A doctor could delete a completed
-- consultation with its diagnosis and vitals; a pharmacist could delete an
-- inventory_item, which cascades and destroys the entire batch and stock
-- history.
--
-- Replace `for all` with explicit insert+update on the clinical/ledger
-- tables. goal_progress, wellness_goals, chat_conversations and
-- chat_messages keep `for all` deliberately -- deleting your own goal or
-- chat is legitimate self-service.

-- consultations
drop policy if exists consultations_write_doctor on public.consultations;
create policy consultations_insert_doctor on public.consultations
  for insert to authenticated with check (doctor_id = auth.uid());
create policy consultations_update_doctor on public.consultations
  for update to authenticated
  using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

-- prescriptions
drop policy if exists prescriptions_write_doctor on public.prescriptions;
create policy prescriptions_insert_doctor on public.prescriptions
  for insert to authenticated with check (doctor_id = auth.uid());
create policy prescriptions_update_doctor on public.prescriptions
  for update to authenticated
  using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

-- health_metrics: a patient may correct their own readings but not erase history
drop policy if exists health_metrics_write_own on public.health_metrics;
create policy health_metrics_insert_own on public.health_metrics
  for insert to authenticated with check (patient_id = auth.uid());
create policy health_metrics_update_own on public.health_metrics
  for update to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());

-- inventory_items: deleting one cascades to its batches and wipes stock history
drop policy if exists inventory_items_write on public.inventory_items;
create policy inventory_items_insert on public.inventory_items
  for insert to authenticated
  with check (public.auth_role() = 'pharmacist' and location_id = public.auth_clinic());
create policy inventory_items_update on public.inventory_items
  for update to authenticated
  using (public.auth_role() = 'pharmacist' and location_id = public.auth_clinic())
  with check (public.auth_role() = 'pharmacist' and location_id = public.auth_clinic());

-- inventory_batches: stock is an append-and-amend ledger
drop policy if exists inventory_batches_write on public.inventory_batches;
create policy inventory_batches_insert on public.inventory_batches
  for insert to authenticated
  with check (public.auth_role() = 'pharmacist'
              and exists (select 1 from public.inventory_items i
                           where i.id = inventory_batches.item_id
                             and i.location_id = public.auth_clinic()));
create policy inventory_batches_update on public.inventory_batches
  for update to authenticated
  using (public.auth_role() = 'pharmacist'
         and exists (select 1 from public.inventory_items i
                      where i.id = inventory_batches.item_id
                        and i.location_id = public.auth_clinic()))
  with check (public.auth_role() = 'pharmacist'
              and exists (select 1 from public.inventory_items i
                           where i.id = inventory_batches.item_id
                             and i.location_id = public.auth_clinic()));

-- prescription_items inherits its shape from finding 1 above and is already
-- insert/update/delete-scoped by the two new policies; DELETE there is
-- legitimate for a patient correcting their own scanned prescription.

-- ============================================================================
-- 5. wastage_records_insert has no clinic check
-- ============================================================================
-- Required only pharmacist + recorded_by = auth.uid(). Every sibling policy
-- checks location_id = auth_clinic(). A pharmacist could log wastage against
-- another clinic's batch.
drop policy if exists wastage_records_insert on public.wastage_records;
create policy wastage_records_insert on public.wastage_records
  for insert to authenticated
  with check (public.auth_role() = 'pharmacist'
              and recorded_by = auth.uid()
              and exists (select 1 from public.inventory_items i
                           where i.id = wastage_records.item_id
                             and i.location_id = public.auth_clinic()));

-- ============================================================================
-- 6. shifts_write_manager validates the wrong clinic
-- ============================================================================
-- Checked clinic_id on the shift row, but nothing tied staff_id to that
-- clinic. A doctor could schedule a shift for another clinic's staff by
-- writing their own clinic_id.
drop policy if exists shifts_write_manager on public.shifts;
create policy shifts_write_manager on public.shifts
  for all to authenticated
  using (public.auth_role() = 'doctor'
         and clinic_id = public.auth_clinic()
         and exists (select 1 from public.profiles p
                      where p.id = shifts.staff_id and p.clinic_id = public.auth_clinic()))
  with check (public.auth_role() = 'doctor'
              and clinic_id = public.auth_clinic()
              and exists (select 1 from public.profiles p
                           where p.id = shifts.staff_id and p.clinic_id = public.auth_clinic()));

-- ============================================================================
-- 7. Grants and policies disagree on three read-only tables
-- ============================================================================
-- clinics, drug_interactions and doctor_availability each have a SELECT-only
-- policy while authenticated still held INSERT/UPDATE/DELETE. RLS denies the
-- writes so nothing was exploitable, but the two layers should agree.
revoke insert, update, delete on public.clinics             from authenticated;
revoke insert, update, delete on public.drug_interactions   from authenticated;
revoke insert, update, delete on public.doctor_availability from authenticated;
