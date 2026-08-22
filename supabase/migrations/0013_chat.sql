create table public.chat_conversations (
  id         uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index chat_conversations_patient_idx on public.chat_conversations (patient_id, updated_at desc);

create table public.chat_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  sender          public.chat_sender not null,
  body            text not null,
  sent_at         timestamptz not null default now(),
  quick_replies   text[] not null default '{}',
  seq             bigserial
);
create index chat_messages_conversation_idx on public.chat_messages (conversation_id, seq);

create trigger chat_conversations_touch before update on public.chat_conversations
  for each row execute function public.set_updated_at();

alter table public.chat_conversations enable row level security;
alter table public.chat_messages      enable row level security;

-- A patient's health conversation is theirs alone. No staff read path.
create policy chat_conversations_own on public.chat_conversations
  for all to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy chat_messages_own on public.chat_messages
  for all to authenticated
  using (exists (select 1 from public.chat_conversations c
                  where c.id = public.chat_messages.conversation_id
                    and c.patient_id = auth.uid()))
  with check (exists (select 1 from public.chat_conversations c
                       where c.id = public.chat_messages.conversation_id
                         and c.patient_id = auth.uid()));
