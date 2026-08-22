-- authenticated must not hold UPDATE on any column that grants authority.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: authenticated may update ' || string_agg(column_name, ', ') end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
  and column_name in ('role','clinic_id','email','is_active','must_change_password');

-- ...but must still hold UPDATE on the presentational ones.
select case when count(*) = 3 then 'PASS' else 'FAIL: ' || count(*) || ' of 3 editable columns' end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
  and column_name in ('full_name','phone','avatar_url');

-- A doctor may edit only their bio.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: doctor may update ' || string_agg(column_name, ', ') end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'doctor_profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
  and column_name in ('license_number','specialization','clinic_id','average_rating');

-- A patient must not self-assign a doctor.
select case when count(*) = 0 then 'PASS' else 'FAIL: assigned_doctor_id is self-editable' end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'patient_profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
  and column_name = 'assigned_doctor_id';

-- The `for all` policy also permitted DELETE; it must be gone.
select case when count(*) = 0 then 'PASS' else 'FAIL: patient_profiles_write_self still present' end as status
from pg_policies where schemaname = 'public' and policyname = 'patient_profiles_write_self';
