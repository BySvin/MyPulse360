select case when count(*) = 4 then 'PASS' else 'FAIL: ' || count(*) || ' of 4 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('health_metrics','health_platform_connections','wellness_goals','goal_progress');

select case when count(*) = 1 then 'PASS' else 'FAIL: dashboard index missing' end as status
from pg_indexes where schemaname = 'public' and indexname = 'health_metrics_patient_type_idx';

select case when count(*) = 0 then 'PASS' else 'FAIL: ' || string_agg(relname, ', ') || ' lack RLS' end as status
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
  and c.relname in ('health_metrics','health_platform_connections','wellness_goals','goal_progress');
