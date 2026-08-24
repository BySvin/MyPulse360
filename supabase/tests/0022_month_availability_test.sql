select case when count(*) = 1 then 'PASS' else 'FAIL: month_availability missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'month_availability';

-- It must be SECURITY DEFINER with a pinned search_path, like every other RPC.
select case when count(*) = 1 then 'PASS' else 'FAIL: not definer with pinned search_path' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'month_availability'
  and p.prosecdef and array_to_string(p.proconfig, ',') like '%search_path=public, pg_temp%';

-- anon must not be able to call it.
select case when count(*) = 0 then 'PASS' else 'FAIL: anon can execute month_availability' end as status
from information_schema.role_routine_grants
where routine_schema = 'public' and routine_name = 'month_availability' and grantee = 'anon';

-- A weekday in a seeded month must report open slots for Dr. Rashid.
select case when count(*) >= 20 then 'PASS' else 'FAIL: only ' || count(*) || ' days returned' end as status
from public.month_availability('22222222-2222-2222-2222-222222222221'::uuid, date_trunc('month', current_date + interval '1 month')::date);
