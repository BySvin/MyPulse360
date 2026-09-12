-- Migration 0003: Appointments & Consultations (Text IDs)
-- Defines doctor availability, appointments lifecycle, consultations, and booking RPCs.

-- 1. Doctor Availability
create table public.doctor_availability (
  id           text primary key,
  doctor_id    text not null references public.profiles(id) on delete cascade,
  day_of_week  int not null check (day_of_week between 0 and 6),
  start_time   time not null,
  end_time     time not null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- 2. Appointments
create table public.appointments (
  id               text primary key,
  patient_id       text not null references public.profiles(id),
  doctor_id        text not null references public.profiles(id),
  clinic_id        text not null references public.clinics(id),
  scheduled_at     timestamptz not null,
  status           text not null check (status in ('pending', 'confirmed', 'completed', 'cancelled')),
  appointment_type text not null default 'Standard',
  reason_for_visit text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- 3. Consultations
create table public.consultations (
  id             text primary key,
  appointment_id text not null references public.appointments(id) on delete cascade,
  patient_id     text not null references public.profiles(id),
  doctor_id      text not null references public.profiles(id),
  status         text not null check (status in ('in_progress', 'completed', 'sent_to_pharmacy')),
  notes          text,
  diagnosis      text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Triggers
create trigger doctor_availability_touch before update on public.doctor_availability for each row execute function public.set_updated_at();
create trigger appointments_touch        before update on public.appointments        for each row execute function public.set_updated_at();
create trigger consultations_touch       before update on public.consultations       for each row execute function public.set_updated_at();

-- RLS
alter table public.doctor_availability enable row level security;
alter table public.appointments        enable row level security;
alter table public.consultations       enable row level security;

-- Policies
create policy doctor_availability_read on public.doctor_availability for select to authenticated using (true);
create policy doctor_availability_write_self on public.doctor_availability for all to authenticated using (doctor_id = auth.uid()::text) with check (doctor_id = auth.uid()::text);

create policy appointments_read_self on public.appointments for select to authenticated using (patient_id = auth.uid()::text or doctor_id = auth.uid()::text or public.auth_clinic() = clinic_id);
create policy appointments_patient_insert on public.appointments for insert to authenticated with check (patient_id = auth.uid()::text and public.auth_role() = 'patient');
create policy appointments_update_parties on public.appointments for update to authenticated using (patient_id = auth.uid()::text or doctor_id = auth.uid()::text);

create policy consultations_read_parties on public.consultations for select to authenticated using (patient_id = auth.uid()::text or doctor_id = auth.uid()::text or public.auth_role() = 'pharmacist');
create policy consultations_doctor_write on public.consultations for all to authenticated using (doctor_id = auth.uid()::text and public.auth_role() = 'doctor') with check (doctor_id = auth.uid()::text and public.auth_role() = 'doctor');
