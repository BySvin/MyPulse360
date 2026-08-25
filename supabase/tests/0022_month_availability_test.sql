select case when count(*) = 1 then 'PASS' else 'FAIL: month_availability missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'month_availability';

-- It must be SECURITY DEFINER with a pinned search_path, like every other RPC.
select case when count(*) = 1 then 'PASS' else 'FAIL: not definer with pinned search_path' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'month_availability'
  and p.prosecdef and array_to_string(p.proconfig, ',') like '%search_path=public, pg_temp%';

-- role_routine_grants reports a PUBLIC-granted function as grantee 'PUBLIC',
-- never 'anon', so a catalog lookup cannot see anon regaining execute through
-- Postgres's implicit grant-to-PUBLIC on function creation. Ask the privilege
-- system directly instead.
select case when not has_function_privilege('anon', 'public.month_availability(uuid,date)', 'execute')
            then 'PASS' else 'FAIL: anon can execute month_availability' end as status;

-- A bug that dropped weekends would still return ~22 rows and satisfy `>= 20`.
-- Assert the true days-in-month so a missing-grid regression fails.
-- (`count(*)` alongside a bare `m.d` makes this an aggregate query, so the two
-- numbers are computed in separate lateral subqueries rather than compared
-- inline; a direct `count(*) = extract(day from (date_trunc('month', d) ...`
-- fails to compile with "column m.d must appear in the GROUP BY clause".)
select case when actual.rows = expected.days
            then 'PASS' else 'FAIL: ' || actual.rows || ' rows for a month of ' || expected.days || ' days' end as status
from (select date_trunc('month', current_date + interval '1 month')::date as d) m,
     lateral (select count(*) as rows from public.month_availability('22222222-2222-2222-2222-222222222221'::uuid, m.d)) actual,
     lateral (select extract(day from (date_trunc('month', m.d) + interval '1 month - 1 day'))::int as days) expected;
