create table public.doctor_availability (
  id           uuid primary key default gen_random_uuid(),
  doctor_id    uuid not null references public.profiles(id) on delete cascade,
  weekday      smallint not null check (weekday between 0 and 6),
  start_time   time not null,
  end_time     time not null,
  slot_minutes smallint not null default 30 check (slot_minutes > 0),
  created_at   timestamptz not null default now(),
  constraint doctor_availability_window check (end_time > start_time),
  unique (doctor_id, weekday, start_time)
);

create table public.appointments (
  id               uuid primary key default gen_random_uuid(),
  patient_id       uuid not null references public.profiles(id),
  doctor_id        uuid not null references public.profiles(id),
  clinic_id        uuid not null references public.clinics(id),
  scheduled_at     timestamptz not null,
  duration_minutes int not null default 30 check (duration_minutes > 0),
  appointment_type text not null,
  status           public.appointment_status not null default 'scheduled',
  reason_for_visit text,
  room_label       text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Two patients racing for the same slot: exactly one wins.
create unique index appointments_no_double_booking
  on public.appointments (doctor_id, scheduled_at)
  where status <> 'cancelled';

create index appointments_patient_idx on public.appointments (patient_id, scheduled_at desc);
create index appointments_doctor_day_idx on public.appointments (doctor_id, scheduled_at);

create table public.consultations (
  id                  uuid primary key default gen_random_uuid(),
  appointment_id      uuid not null unique references public.appointments(id) on delete cascade,
  patient_id          uuid not null references public.profiles(id),
  doctor_id           uuid not null references public.profiles(id),
  status              public.consultation_status not null default 'in_progress',
  systolic_bp         int,
  diastolic_bp        int,
  heart_rate          int,
  temperature_celsius numeric(4,1),
  blood_sugar         int,
  weight_kg           numeric(5,2),
  diagnosis           text,
  notes               text,
  recommendations     text,
  completed_at        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create trigger appointments_touch  before update on public.appointments  for each row execute function public.set_updated_at();
create trigger consultations_touch before update on public.consultations for each row execute function public.set_updated_at();

alter table public.doctor_availability enable row level security;
alter table public.appointments        enable row level security;
alter table public.consultations       enable row level security;

create policy doctor_availability_read on public.doctor_availability
  for select to authenticated using (true);

create policy appointments_read_own on public.appointments
  for select to authenticated
  using (patient_id = auth.uid() or doctor_id = auth.uid());

create policy consultations_read_own on public.consultations
  for select to authenticated
  using (patient_id = auth.uid() or doctor_id = auth.uid());
create policy consultations_write_doctor on public.consultations
  for all to authenticated
  using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

-- Writes to appointments go through book_appointment / reschedule / status RPCs
-- only (Task 4). Without this revoke the collision and leave checks are advisory.
revoke insert, update, delete on public.appointments from authenticated;

-- A doctor may read a patient's profile when they share an appointment.
create policy patient_profiles_read_by_appointment on public.patient_profiles
  for select to authenticated
  using (
    public.auth_role() = 'doctor'
    and exists (
      select 1 from public.appointments a
      where a.patient_id = public.patient_profiles.id
        and a.doctor_id = auth.uid()
    )
  );
