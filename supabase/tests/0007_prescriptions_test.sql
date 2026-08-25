select case when count(*) = 3 then 'PASS' else 'FAIL: ' || count(*) || ' of 3 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('prescriptions','prescription_items','drug_interactions');

select case when count(*) = 1 then 'PASS' else 'FAIL: prescription_safety missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'prescription_safety';

-- An external scanned prescription has no doctor_id, so the prescriber check must exist.
select case when count(*) = 1 then 'PASS' else 'FAIL: prescriber check missing' end as status
from pg_constraint where conname = 'prescriptions_has_prescriber';
