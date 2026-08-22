-- staff_unavailability must not be world-readable.
select case when count(*) = 0 then 'PASS' else 'FAIL: staff_unavailability_read is unscoped' end as status
from pg_policies
where schemaname = 'public' and tablename = 'staff_unavailability'
  and policyname = 'staff_unavailability_read' and qual = 'true';

-- ...but a staff member must still read their own rows.
select case when count(*) = 1 then 'PASS' else 'FAIL: staff_unavailability_read missing' end as status
from pg_policies
where schemaname = 'public' and tablename = 'staff_unavailability'
  and policyname = 'staff_unavailability_read' and qual like '%auth.uid()%';

-- decide_leave must anchor its date comparison to UTC.
select case when count(*) = 1 then 'PASS' else 'FAIL: decide_leave date cast not UTC-anchored' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'decide_leave'
  and pg_get_functiondef(p.oid) like '%at time zone ''UTC''%';
