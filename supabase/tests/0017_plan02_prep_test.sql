-- Follow-up 1: DELETE grants must match the policies that were removed.
select case when count(*) = 0 then 'PASS'
            else 'FAIL: authenticated may delete ' || string_agg(distinct table_name, ', ') end as status
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'DELETE'
  and table_name in ('consultations','prescriptions','health_metrics',
                     'inventory_items','inventory_batches');

-- ...but the legitimate self-service deletes must survive.
select case when count(*) = 3 then 'PASS'
            else 'FAIL: only ' || count(*) || ' of 3 self-delete paths remain' end as status
from information_schema.role_table_grants
where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'DELETE'
  and table_name in ('goal_progress','chat_conversations','chat_messages');

-- Follow-up: sign-up needs a server-side doctor assignment, because clients
-- cannot write assigned_doctor_id.
select case when count(*) = 1 then 'PASS' else 'FAIL: assign_default_doctor missing' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'assign_default_doctor';

-- Final-review follow-up 3: decide_leave must not leak a status oracle across
-- clinics — the clinic check has to precede the existence/status checks.
-- NOTE: the brief's assertion searched for 'not your clinic', which does not
-- occur anywhere in decide_leave's actual raise message ('...is not at your
-- clinic'). position() returned 0 (not found) and 0 < position('already')
-- was vacuously true regardless of check order. Corrected to the real
-- substring so the assertion can actually go RED before the fix.
select case when position('not at your clinic' in def) < position('already' in def) then 'PASS'
            else 'FAIL: clinic check still runs after the status check' end as status
from (select pg_get_functiondef(p.oid) as def
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = 'decide_leave') s;
