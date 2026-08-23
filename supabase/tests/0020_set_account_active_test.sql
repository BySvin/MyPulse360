select case when count(*) = 1 then 'PASS' else 'FAIL: set_account_active missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'set_account_active';

-- is_active must stay un-writable from a client.
select case when count(*) = 0 then 'PASS' else 'FAIL: is_active became client-writable' end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE' and column_name = 'is_active';

select case when count(*) = 1 then 'PASS' else 'FAIL: self-deactivation guard missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and p.proname='set_account_active'
  and pg_get_functiondef(p.oid) like '%p_user = auth.uid()%';

select case when count(*) = 1 then 'PASS' else 'FAIL: clinic scope missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and p.proname='set_account_active'
  and pg_get_functiondef(p.oid) like '%auth_clinic()%';

select case when count(*) = 1 then 'PASS' else 'FAIL: not security definer with pinned search_path' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public' and p.proname='set_account_active'
  and p.prosecdef and array_to_string(p.proconfig,',') like '%search_path=public, pg_temp%';
