BEGIN;
SELECT plan(4);

SELECT has_table('health_metrics', 'health_metrics table exists');
SELECT has_table('health_platform_connections', 'health_platform_connections table exists');
SELECT has_table('wellness_goals', 'wellness_goals table exists');
SELECT has_table('goal_progress', 'goal_progress table exists');

SELECT * FROM finish();
ROLLBACK;
