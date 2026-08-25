-- watchNextUpcoming and watchTodaysQueue (Task 5) subscribe via
-- `.stream(primaryKey: ['id'])`, which rides Postgres logical replication
-- through the supabase_realtime publication. Without the table in that
-- publication both streams emit only their initial snapshot and then never
-- update again -- confirmed empty for `appointments` via pg_publication_tables
-- before this migration.
alter publication supabase_realtime add table public.appointments;
