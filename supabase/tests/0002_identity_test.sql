select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('clinics','profiles','patient_profiles','doctor_profiles','pharmacist_profiles');

-- Every one of those tables must have RLS enabled.
select case when count(*) = 0 then 'PASS' else 'FAIL: ' || string_agg(relname, ', ') || ' lack RLS' end as status
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
  and c.relname in ('clinics','profiles','patient_profiles','doctor_profiles','pharmacist_profiles');

select case when count(*) = 1 then 'PASS' else 'FAIL: doctor_directory missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'doctor_directory';

-- The two policy helpers land here, not in Task 1: a `language sql` body is
-- validated at CREATE FUNCTION time, so they cannot exist before `profiles`.
select case when count(*) = 3 then 'PASS' else 'FAIL: ' || count(*) || ' of 3 helpers' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('set_updated_at','auth_role','auth_clinic');
