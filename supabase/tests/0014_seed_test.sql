select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 demo users' end as status
from public.profiles
where id in ('22222222-2222-2222-2222-222222222221','22222222-2222-2222-2222-222222222222',
             '33333333-3333-3333-3333-333333333331','44444444-4444-4444-4444-444444444441',
             '44444444-4444-4444-4444-444444444442');

-- Every demo profile needs a matching auth user or login fails.
select case when count(*) = 5 then 'PASS' else 'FAIL: ' || count(*) || ' of 5 auth users' end as status
from auth.users u join public.profiles p on p.id = u.id;

-- Weekday availability for both doctors: 5 days x 2 doctors.
select case when count(*) = 10 then 'PASS' else 'FAIL: ' || count(*) || ' availability rows' end as status
from public.doctor_availability;
