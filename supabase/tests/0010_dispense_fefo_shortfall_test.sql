-- The function must not be able to return having dispensed less than asked.
select case when count(*) = 1 then 'PASS' else 'FAIL: no post-loop shortfall guard' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'dispense_fefo'
  and pg_get_functiondef(p.oid) like '%v_remaining > 0%';

-- The guard must raise, not warn or silently correct.
select case when count(*) = 1 then 'PASS' else 'FAIL: shortfall does not raise 23514' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'dispense_fefo'
  and pg_get_functiondef(p.oid) like '%short by%';
