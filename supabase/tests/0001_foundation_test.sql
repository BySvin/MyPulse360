BEGIN;
SELECT plan(2);

SELECT has_table('clinics', 'clinics table exists');
SELECT has_table('profiles', 'profiles table exists');

SELECT * FROM finish();
ROLLBACK;
