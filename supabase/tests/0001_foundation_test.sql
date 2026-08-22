-- Expect 14 enum types and the one trigger helper.
select case when count(*) = 14 then 'PASS' else 'FAIL: ' || count(*) || ' enums' end as status
from pg_type t join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public' and t.typtype = 'e';

select case when count(*) = 1 then 'PASS' else 'FAIL: ' || count(*) || ' helpers' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'set_updated_at';
