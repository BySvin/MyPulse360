BEGIN;
SELECT plan(2);

SELECT has_table('prescriptions', 'prescriptions table exists');
SELECT has_table('prescription_items', 'prescription_items table exists');

SELECT * FROM finish();
ROLLBACK;
