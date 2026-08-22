-- anon is the role the publishable key maps to before login. It needs to read
-- nothing here today and write nothing ever; RLS already denies it, this makes
-- the grant match the intent.
revoke insert, update, delete, truncate on all tables in schema public from anon;

-- TRUNCATE is not governed by row security, so no client role should hold it.
-- Note DELETE is deliberately NOT revoked from authenticated: goal_progress,
-- chat_conversations and chat_messages all carry `for all` policies where
-- deleting your own row is legitimate.
revoke truncate on all tables in schema public from authenticated;

-- Tables created later must not silently reacquire these.
alter default privileges in schema public
  revoke insert, update, delete, truncate on tables from anon;
alter default privileges in schema public
  revoke truncate on tables from authenticated;
