BEGIN;
SELECT plan(2);

SELECT has_table('chat_conversations', 'chat_conversations table exists');
SELECT has_table('chat_messages', 'chat_messages table exists');

SELECT * FROM finish();
ROLLBACK;
