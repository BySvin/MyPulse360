-- A patient must not choose their own doctor at INSERT time either.
select case when count(*) = 0 then 'PASS' else 'FAIL: assigned_doctor_id is self-insertable' end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'patient_profiles'
  and grantee = 'authenticated' and privilege_type = 'INSERT'
  and column_name = 'assigned_doctor_id';

-- ...but the patient must still be able to create their own row.
select case when count(*) >= 3 then 'PASS' else 'FAIL: only ' || count(*) || ' insertable columns' end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'patient_profiles'
  and grantee = 'authenticated' and privilege_type = 'INSERT'
  and column_name in ('id','height_cm','weight_kg');

-- The FK must guarantee the referenced row is actually a doctor.
select case when count(*) = 1 then 'PASS' else 'FAIL: FK does not point at doctor_profiles' end as status
from information_schema.referential_constraints rc
join information_schema.constraint_column_usage ccu on ccu.constraint_name = rc.constraint_name
where rc.constraint_schema = 'public'
  and ccu.table_name = 'doctor_profiles'
  and rc.constraint_name like 'patient_profiles_assigned_doctor%';
