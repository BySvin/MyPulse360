select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('shifts','leave_requests','staff_unavailability','attendance_records','staff_notifications');

-- One open clock-in per person, matching mock_scheduling_datasource_test.dart.
select case when count(*) = 1 then 'PASS' else 'FAIL: open-attendance index missing' end as status
from pg_indexes where schemaname = 'public' and indexname = 'attendance_one_open_per_staff';

select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 functions' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('apply_leave','decide_leave','clock_in','clock_out','available_slots');

-- available_slots must return the four columns Dart's TimeSlot maps from.
-- NB: RETURNS TABLE(...) columns surface in information_schema.parameters as
-- parameter_mode = 'OUT', never 'TABLE'. An earlier draft asserted 'TABLE' and
-- was therefore unwinnable — it reported FAIL regardless of correctness.
select case when count(*) = 4 then 'PASS' else 'FAIL: wrong column set' end as status
from information_schema.routines r
join information_schema.parameters pa on pa.specific_name = r.specific_name
where r.routine_schema = 'public' and r.routine_name = 'available_slots'
  and pa.parameter_mode = 'OUT'
  and pa.parameter_name in ('slot_at','is_booked','is_doctor_on_leave','is_past');
