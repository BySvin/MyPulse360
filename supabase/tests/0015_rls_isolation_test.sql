-- anon must hold no write privilege on any table.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: anon may write ' || string_agg(distinct table_name, ', ') end as status
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'anon'
  and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE');

-- No client role may TRUNCATE, since RLS does not govern it.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: authenticated may truncate ' || string_agg(distinct table_name, ', ') end as status
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'TRUNCATE';

-- ...but the legitimate self-service deletes must survive. A patient owns their
-- own progress logs and chat history.
select case when count(*) = 3 then 'PASS'
            else 'FAIL: only ' || count(*) || ' of 3 self-delete paths remain' end as status
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'DELETE'
  and table_name in ('goal_progress','chat_conversations','chat_messages');

-- Aisha must not see Daniel's medical row.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select case when count(*) = 0 then 'PASS' else 'FAIL: patient_profiles leaked ' || count(*) end as status
from public.patient_profiles where id <> '44444444-4444-4444-4444-444444444441';
rollback;

-- Aisha must not see Daniel's appointments.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select case when count(*) = 0 then 'PASS' else 'FAIL: appointments leaked ' || count(*) end as status
from public.appointments
where patient_id <> '44444444-4444-4444-4444-444444444441'
  and doctor_id  <> '44444444-4444-4444-4444-444444444441';
rollback;

-- Aisha must not see Daniel's health metrics, goals or chats.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select case when (select count(*) from public.health_metrics where patient_id <> '44444444-4444-4444-4444-444444444441') = 0
             and (select count(*) from public.wellness_goals where patient_id <> '44444444-4444-4444-4444-444444444441') = 0
             and (select count(*) from public.chat_conversations where patient_id <> '44444444-4444-4444-4444-444444444441') = 0
        then 'PASS' else 'FAIL: patient-owned data leaked' end as status;
rollback;

-- A pharmacist must not read medical history directly.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','33333333-3333-3333-3333-333333333331','role','authenticated')::text, true);
set local role authenticated;
select case when count(*) = 0 then 'PASS' else 'FAIL: pharmacist read ' || count(*) || ' patient rows' end as status
from public.patient_profiles;
rollback;

-- A patient must not write appointments directly, bypassing book_appointment.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
do $$
begin
  insert into public.appointments
    (patient_id, doctor_id, clinic_id, scheduled_at, appointment_type)
  values ('44444444-4444-4444-4444-444444444441','22222222-2222-2222-2222-222222222221',
          '11111111-1111-1111-1111-111111111111', now() + interval '1 day', 'Sneaky');
  raise exception 'FAIL: direct insert succeeded';
exception
  when insufficient_privilege then raise notice 'PASS: direct insert refused';
end;
$$;
rollback;

-- A patient must not be able to promote themselves to doctor. This is the
-- behavioural proof for the column grants added in Task 2 Step 8: without them
-- this UPDATE succeeds and hands the patient staff-level read access.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
do $$
begin
  update public.profiles set role = 'doctor' where id = auth.uid();
  raise exception 'FAIL: role self-escalation succeeded';
exception
  when insufficient_privilege then raise notice 'PASS: role self-escalation refused';
end;
$$;
rollback;

-- A patient must not be able to move themselves into another clinic.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
do $$
begin
  update public.profiles set clinic_id = '11111111-1111-1111-1111-111111111112' where id = auth.uid();
  raise exception 'FAIL: clinic self-reassignment succeeded';
exception
  when insufficient_privilege then raise notice 'PASS: clinic self-reassignment refused';
end;
$$;
rollback;

-- Every table in public must have RLS enabled. Catches a table added later
-- without a policy.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: ' || string_agg(relname, ', ') || ' lack RLS' end as status
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

-- Daniel must see exactly the rows Aisha cannot. This is the counter-check
-- that proves the two assertions above are not vacuous: without the seed rows
-- appended in supabase/seed.sql (Step 7), "Aisha sees zero of Daniel's rows"
-- would pass whether or not RLS is even enabled, because Daniel would own no
-- such rows to leak. This block confirms the rows genuinely exist and are
-- visible to their owner.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444442','role','authenticated')::text, true);
set local role authenticated;
select case when (select count(*) from public.appointments) = 1
             and (select count(*) from public.health_metrics) = 1
             and (select count(*) from public.wellness_goals) = 1
             and (select count(*) from public.chat_conversations) = 1
        then 'PASS' else 'FAIL: owner cannot see their own seeded rows' end as status;
rollback;

-- A patient must not be able to rewrite the medications on a prescription
-- their doctor issued. This is the finding the whole-branch review caught.
--
-- NOTE: this is deliberately NOT a plain SELECT count over prescription_items
-- joined to prescriptions where source = 'in_app'. That was the brief's first
-- draft, and it does not detect the bug: SELECT visibility on
-- prescription_items is governed by prescription_items_read, which delegates
-- to prescriptions_read (patient_id = auth.uid() OR doctor_id = auth.uid() OR
-- pharmacist-in-clinic) via its own subquery. A patient legitimately reading
-- their own doctor-issued prescription is not a bug, so that count is
-- non-zero (or vacuously zero with no fixture data) whether or not the write
-- policy is fixed -- verified empirically against the live project both
-- before and after 0015_final_hardening.sql, it read PASS in both states.
-- The actual defect is a write hole, so this proves it with a real UPDATE
-- attempt: seed a doctor-issued item as postgres (RLS-exempt table owner),
-- then try to rewrite it as the patient. Before the fix, prescription_items_
-- write's unqualified `pr.patient_id = auth.uid()` branch lets the UPDATE
-- through; after the fix, prescription_items_write_scanned requires
-- `pr.source = 'scanned_external'`, which an in-app prescription never has,
-- so the UPDATE's RLS-filtered WHERE matches zero rows and the medication
-- name is left untouched.
begin;
set local role postgres;
insert into public.prescriptions (id, patient_id, doctor_id, issued_date, expiry_date, source)
values ('99999999-9999-9999-9999-999999999991', '44444444-4444-4444-4444-444444444441',
        '22222222-2222-2222-2222-222222222221', current_date, current_date + 30, 'in_app');
insert into public.prescription_items
  (id, prescription_id, medication_name, strength, form, quantity, unit, frequency, duration_days, instructions)
values ('99999999-9999-9999-9999-999999999992', '99999999-9999-9999-9999-999999999991',
        'Amoxicillin', '500mg', 'tablet', 21, 'tablet', 'TID', 7, 'Take with food');
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
update public.prescription_items
   set medication_name = 'Forged medication'
 where id = '99999999-9999-9999-9999-999999999992';
select case when (select medication_name from public.prescription_items
                    where id = '99999999-9999-9999-9999-999999999992') = 'Amoxicillin'
            then 'PASS'
            else 'FAIL: patient rewrote a doctor-issued item to '''
                 || (select medication_name from public.prescription_items
                      where id = '99999999-9999-9999-9999-999999999992') || ''''
       end as status;
rollback;

-- Clinical records must not be client-deletable.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: DELETE reachable on ' || string_agg(distinct tablename, ', ') end as status
from pg_policies
where schemaname = 'public' and cmd = 'ALL'
  and tablename in ('consultations','prescriptions','health_metrics',
                    'inventory_items','inventory_batches');

-- chat_messages needs its own cross-tenant assertion, not just its parent's.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select case when count(*) = 0 then 'PASS' else 'FAIL: chat_messages leaked ' || count(*) end as status
from public.chat_messages;
rollback;
