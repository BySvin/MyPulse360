-- The doctor branch must be clinic-scoped, not merely role-gated.
select case when count(*) = 1 then 'PASS' else 'FAIL: no clinic scoping on the doctor branch' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'assign_default_doctor'
  and pg_get_functiondef(p.oid) like '%auth_clinic()%';

-- Refusal must not distinguish "no such patient" from "other clinic", or a
-- doctor can probe for the existence of patients elsewhere.
select case when count(*) = 1 then 'PASS' else 'FAIL: refusal messages leak existence' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'assign_default_doctor'
  and pg_get_functiondef(p.oid) like '%not at your clinic%';
