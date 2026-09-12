BEGIN;
SELECT plan(2);

SELECT has_table('leave_requests', 'leave_requests table exists');
SELECT has_function('cancel_leave', ARRAY['text'], 'cancel_leave function exists');

SELECT * FROM finish();
ROLLBACK;
