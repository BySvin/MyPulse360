select case when count(*) = 2 then 'PASS' else 'FAIL: ' || count(*) || ' of 2 tables' end as status
from pg_tables where schemaname = 'public'
  and tablename in ('chat_conversations','chat_messages');

-- ChatMessage.text maps to a column named body; `text` is avoided as a name.
select case when count(*) = 1 then 'PASS' else 'FAIL: body column missing' end as status
from information_schema.columns
where table_schema = 'public' and table_name = 'chat_messages' and column_name = 'body';
