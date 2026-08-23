select case when count(*) = 1 then 'PASS' else 'FAIL: register_patient missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'register_patient';

-- profiles must still have no INSERT policy: registration is server-side only.
select case when count(*) = 0 then 'PASS' else 'FAIL: a client INSERT path was opened' end as status
from pg_policies where schemaname = 'public' and tablename = 'profiles' and cmd = 'INSERT';
