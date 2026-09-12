-- Migration 0004: Prescriptions & Items (Text IDs)
-- Handles e-prescriptions and prescription line items using text IDs.

-- 1. Prescriptions Table
create table public.prescriptions (
  id              text primary key,
  patient_id      text not null references public.profiles(id),
  doctor_id       text not null references public.profiles(id),
  pharmacist_id   text references public.profiles(id),
  consultation_id text references public.consultations(id),
  status          text not null check (status in ('pending', 'verified', 'dispensed', 'cancelled')),
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- 2. Prescription Items Table
create table public.prescription_items (
  id              text primary key,
  prescription_id text not null references public.prescriptions(id) on delete cascade,
  medication_name text not null,
  dosage          text not null,
  frequency       text not null,
  duration_days   int not null,
  instructions    text,
  created_at      timestamptz not null default now()
);

-- Triggers
create trigger prescriptions_touch before update on public.prescriptions for each row execute function public.set_updated_at();

-- RLS
alter table public.prescriptions      enable row level security;
alter table public.prescription_items enable row level security;

-- Policies
create policy prescriptions_read_parties on public.prescriptions for select to authenticated
  using (patient_id = auth.uid()::text or doctor_id = auth.uid()::text or pharmacist_id = auth.uid()::text or public.auth_role() = 'pharmacist');

create policy prescriptions_doctor_insert on public.prescriptions for insert to authenticated
  with check (doctor_id = auth.uid()::text and public.auth_role() = 'doctor');

create policy prescriptions_pharmacist_update on public.prescriptions for update to authenticated
  using (public.auth_role() = 'pharmacist') with check (public.auth_role() = 'pharmacist');

create policy prescription_items_read_parties on public.prescription_items for select to authenticated
  using (exists (
    select 1 from public.prescriptions p
    where p.id = prescription_id
      and (p.patient_id = auth.uid()::text or p.doctor_id = auth.uid()::text or p.pharmacist_id = auth.uid()::text or public.auth_role() = 'pharmacist')
  ));

create policy prescription_items_staff_write on public.prescription_items for all to authenticated
  using (public.auth_role() in ('doctor', 'pharmacist'));
