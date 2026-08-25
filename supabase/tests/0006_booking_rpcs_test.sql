select case when count(*) = 4 then 'PASS' else 'FAIL: ' || count(*) || ' of 4 functions' end as status
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('book_appointment','reschedule_appointment',
                    'set_appointment_status','queue_position');
