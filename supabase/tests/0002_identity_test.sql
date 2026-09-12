BEGIN;
SELECT plan(4);

SELECT has_table('patient_profiles', 'patient_profiles table exists');
SELECT has_table('doctor_profiles', 'doctor_profiles table exists');
SELECT has_table('pharmacist_profiles', 'pharmacist_profiles table exists');
SELECT has_function('doctor_directory', ARRAY['text', 'text'], 'doctor_directory search function exists');

SELECT * FROM finish();
ROLLBACK;
