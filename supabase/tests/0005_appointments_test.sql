select case when count(*) = 3 then 'PASS' else 'FAIL: ' || count(*) || ' of 3 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('doctor_availability','appointments','consultations');

select case when count(*) = 1 then 'PASS' else 'FAIL: double-booking index missing' end as status
from pg_indexes where schemaname = 'public' and indexname = 'appointments_no_double_booking';

-- authenticated must NOT hold direct write grants on appointments.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: authenticated holds ' || string_agg(privilege_type, ', ') end as status
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'appointments'
  and grantee = 'authenticated' and privilege_type in ('INSERT','UPDATE','DELETE');
