-- Migration 0006: Patient & Clinic Staff Chat (Text IDs)
-- Defines chat conversations and messages for internal messaging using text IDs.

-- 1. Chat Conversations Table
create table public.chat_conversations (
  id           text primary key,
  patient_id   text not null references public.profiles(id),
  doctor_id    text references public.profiles(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- 2. Chat Messages Table
create table public.chat_messages (
  id              text primary key,
  conversation_id text not null references public.chat_conversations(id) on delete cascade,
  sender_id       text not null references public.profiles(id),
  message         text not null,
  is_read         boolean not null default false,
  created_at      timestamptz not null default now()
);

-- Triggers
create trigger chat_conversations_touch before update on public.chat_conversations for each row execute function public.set_updated_at();

-- RLS
alter table public.chat_conversations enable row level security;
alter table public.chat_messages      enable row level security;

-- Policies
create policy chat_conversations_read_parties on public.chat_conversations for select to authenticated
  using (patient_id = auth.uid()::text or doctor_id = auth.uid()::text or public.auth_role() in ('doctor', 'pharmacist'));

create policy chat_messages_read_parties on public.chat_messages for select to authenticated
  using (exists (
    select 1 from public.chat_conversations c
    where c.id = conversation_id
      and (c.patient_id = auth.uid()::text or c.doctor_id = auth.uid()::text or public.auth_role() in ('doctor', 'pharmacist'))
  ));

create policy chat_messages_sender_insert on public.chat_messages for insert to authenticated
  with check (sender_id = auth.uid()::text);
