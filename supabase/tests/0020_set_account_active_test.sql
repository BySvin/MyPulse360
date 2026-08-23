select case when count(*) = 1 then 'PASS' else 'FAIL: set_account_active missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'set_account_active';

-- is_active must stay un-writable from a client.
select case when count(*) = 0 then 'PASS' else 'FAIL: is_active became client-writable' end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE' and column_name = 'is_active';
