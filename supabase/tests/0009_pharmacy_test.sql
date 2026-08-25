select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('suppliers','inventory_items','inventory_batches','wastage_records','dispense_records');

select case when count(*) = 1 then 'PASS' else 'FAIL: FEFO index missing' end as status
from pg_indexes where schemaname = 'public' and indexname = 'inventory_batches_fefo_idx';

select case when count(*) = 1 then 'PASS' else 'FAIL: dispense_fefo missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'dispense_fefo';
