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
