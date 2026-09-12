BEGIN;
SELECT plan(3);

SELECT has_table('doctor_availability', 'doctor_availability table exists');
SELECT has_table('appointments', 'appointments table exists');
SELECT has_table('consultations', 'consultations table exists');

SELECT * FROM finish();
ROLLBACK;
