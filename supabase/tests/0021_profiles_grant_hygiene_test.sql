select case when count(*) = 0 then 'PASS'
            else 'FAIL: authenticated may ' || string_agg(distinct privilege_type, ', ') || ' on profiles' end as status
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'profiles'
  and grantee = 'authenticated' and privilege_type in ('INSERT','DELETE');

-- ...but the self-service column updates must survive.
select case when count(*) = 3 then 'PASS' else 'FAIL: only ' || count(*) || ' of 3 editable columns' end as status
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles'
  and grantee = 'authenticated' and privilege_type = 'UPDATE'
  and column_name in ('full_name','phone','avatar_url');
