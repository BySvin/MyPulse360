-- Migration 0005: Health Metrics & Personalization (Text IDs)
-- Tables for patient vitals, health integrations, wellness goals, and progress.

-- 1. Health Metrics Table
create table public.health_metrics (
  id          text primary key,
  patient_id  text not null references public.profiles(id) on delete cascade,
  metric_type text not null,
  value       numeric(10,2) not null,
  unit        text not null,
  recorded_at timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

-- 2. Health Platform Connections
create table public.health_platform_connections (
  id             text primary key,
  patient_id     text not null references public.profiles(id) on delete cascade,
  platform       text not null,
  is_connected   boolean not null default true,
  last_synced_at timestamptz,
  created_at     timestamptz not null default now()
);

-- 3. Wellness Goals Table
create table public.wellness_goals (
  id           text primary key,
  patient_id   text not null references public.profiles(id) on delete cascade,
  goal_type    text not null,
  target_value numeric(10,2) not null,
  unit         text not null,
  target_date  date,
  is_completed boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- 4. Goal Progress Table
create table public.goal_progress (
  id            text primary key,
  goal_id       text not null references public.wellness_goals(id) on delete cascade,
  current_value numeric(10,2) not null,
  logged_at     timestamptz not null default now()
);

-- Triggers
create trigger wellness_goals_touch before update on public.wellness_goals for each row execute function public.set_updated_at();

-- RLS
alter table public.health_metrics              enable row level security;
alter table public.health_platform_connections enable row level security;
alter table public.wellness_goals              enable row level security;
alter table public.goal_progress               enable row level security;

-- Policies
create policy health_metrics_patient_self on public.health_metrics for all to authenticated
  using (patient_id = auth.uid()::text) with check (patient_id = auth.uid()::text);

create policy health_metrics_doctor_read on public.health_metrics for select to authenticated
  using (public.auth_role() = 'doctor');

create policy health_platform_patient_self on public.health_platform_connections for all to authenticated
  using (patient_id = auth.uid()::text) with check (patient_id = auth.uid()::text);

create policy wellness_goals_patient_self on public.wellness_goals for all to authenticated
  using (patient_id = auth.uid()::text) with check (patient_id = auth.uid()::text);

create policy goal_progress_patient_self on public.goal_progress for all to authenticated
  using (exists (select 1 from public.wellness_goals g where g.id = goal_id and g.patient_id = auth.uid()::text));
