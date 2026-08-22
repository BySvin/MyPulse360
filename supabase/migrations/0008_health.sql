create table public.health_metrics (
  id              uuid primary key default gen_random_uuid(),
  patient_id      uuid not null references public.profiles(id) on delete cascade,
  type            public.metric_type not null,
  value           numeric not null,
  secondary_value numeric,
  measured_at     timestamptz not null,
  recorded_by     uuid references public.profiles(id),
  notes           text,
  created_at      timestamptz not null default now()
);
-- Every dashboard read is "latest N of this type for this patient".
create index health_metrics_patient_type_idx
  on public.health_metrics (patient_id, type, measured_at desc);

create table public.health_platform_connections (
  patient_id     uuid not null references public.profiles(id) on delete cascade,
  platform       public.health_platform not null,
  connected_at   timestamptz not null default now(),
  last_synced_at timestamptz,
  primary key (patient_id, platform)
);

create table public.wellness_goals (
  id            uuid primary key default gen_random_uuid(),
  patient_id    uuid not null references public.profiles(id) on delete cascade,
  type          public.wellness_goal_type not null,
  name          text not null,
  target_value  numeric not null,
  current_value numeric not null default 0,
  unit          text not null,
  status        public.goal_status not null default 'on_track',
  target_date   date not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index wellness_goals_patient_idx on public.wellness_goals (patient_id);

create table public.goal_progress (
  id         uuid primary key default gen_random_uuid(),
  goal_id    uuid not null references public.wellness_goals(id) on delete cascade,
  log_date   date not null,
  value      numeric not null,
  notes      text,
  created_at timestamptz not null default now(),
  unique (goal_id, log_date)
);

create trigger wellness_goals_touch before update on public.wellness_goals
  for each row execute function public.set_updated_at();

alter table public.health_metrics              enable row level security;
alter table public.health_platform_connections enable row level security;
alter table public.wellness_goals              enable row level security;
alter table public.goal_progress               enable row level security;

-- The caller owns the row, or is a doctor treating them.
create policy health_metrics_read on public.health_metrics
  for select to authenticated
  using (
    patient_id = auth.uid()
    or (public.auth_role() = 'doctor' and (
          exists (select 1 from public.patient_profiles pp
                   where pp.id = public.health_metrics.patient_id
                     and pp.assigned_doctor_id = auth.uid())
       or exists (select 1 from public.appointments a
                   where a.patient_id = public.health_metrics.patient_id
                     and a.doctor_id = auth.uid())))
  );
create policy health_metrics_write_own on public.health_metrics
  for all to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());
create policy health_metrics_insert_doctor on public.health_metrics
  for insert to authenticated
  with check (public.auth_role() = 'doctor' and recorded_by = auth.uid());

create policy health_platform_connections_own on public.health_platform_connections
  for all to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy wellness_goals_read on public.wellness_goals
  for select to authenticated
  using (
    patient_id = auth.uid()
    or (public.auth_role() = 'doctor'
        and exists (select 1 from public.patient_profiles pp
                     where pp.id = public.wellness_goals.patient_id
                       and pp.assigned_doctor_id = auth.uid()))
  );
create policy wellness_goals_write_own on public.wellness_goals
  for all to authenticated
  using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy goal_progress_all on public.goal_progress
  for all to authenticated
  using (exists (select 1 from public.wellness_goals g
                  where g.id = public.goal_progress.goal_id and g.patient_id = auth.uid()))
  with check (exists (select 1 from public.wellness_goals g
                       where g.id = public.goal_progress.goal_id and g.patient_id = auth.uid()));
