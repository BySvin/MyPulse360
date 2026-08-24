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

-- GoTrue scans confirmation_token, recovery_token, email_change_token_new and
-- email_change into non-nullable Go strings; a NULL in any of these makes
-- "Database error querying schema" fail every seeded login even though the
-- bcrypt hash itself verifies. A passing hash check alone would not have
-- caught this, so assert directly on the columns GoTrue actually scans.
select case when count(*) = 0 then 'PASS'
       else 'FAIL: ' || count(*) || ' seeded auth users with a NULL GoTrue-scanned token column'
       end as status
from auth.users
where email like '%@mypulse360.test'
  and (confirmation_token is null
    or recovery_token is null
    or email_change_token_new is null
    or email_change is null);
