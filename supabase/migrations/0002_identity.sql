-- Migration 0002: Identity & User Profiles (Text IDs)
-- Defines separate profile tables for Patient, Doctor, and Pharmacist using simple text IDs.

-- 1. Clinics Table
create table public.clinics (
  id         text primary key,
  name       text not null,
  address    text not null,
  phone      text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Base User Profiles
create table public.profiles (
  id                   text primary key,
  email                citext not null unique,
  full_name            text not null,
  role                 public.user_role not null,
  clinic_id            text not null references public.clinics(id),
  phone                text,
  avatar_url           text,
  is_active            boolean not null default true,
  must_change_password boolean not null default false,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index profiles_clinic_role_idx on public.profiles (clinic_id, role);

-- 3. 🤒 Patient Role Table
create table public.patient_profiles (
  id                      text primary key references public.profiles(id) on delete cascade,
  date_of_birth           date,
  gender                  text,
  blood_type              text,
  height_cm               numeric(5,2) not null,
  weight_kg               numeric(5,2) not null,
  allergies               text[] not null default '{}',
  chronic_conditions      text[] not null default '{}',
  current_medications     text[] not null default '{}',
  assigned_doctor_id      text references public.profiles(id),
  insurance_provider      text,
  emergency_contact_name  text,
  emergency_contact_phone text,
  preferred_clinic_id     text references public.clinics(id),
  preferred_language      text,
  notify_appointments     boolean not null default true,
  notify_prescriptions    boolean not null default true,
  notify_health_tips      boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- 4. 🧑‍⚕️ Doctor Role Table
create table public.doctor_profiles (
  id             text primary key references public.profiles(id) on delete cascade,
  license_number text not null unique,
  specialization text not null,
  clinic_id      text not null references public.clinics(id),
  bio            text,
  average_rating numeric(2,1) check (average_rating between 0 and 5),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- 5. 💊 Pharmacist Role Table
create table public.pharmacist_profiles (
  id             text primary key references public.profiles(id) on delete cascade,
  license_number text not null unique,
  clinic_id      text not null references public.clinics(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Triggers for updated_at
create trigger clinics_touch             before update on public.clinics             for each row execute function public.set_updated_at();
create trigger profiles_touch            before update on public.profiles            for each row execute function public.set_updated_at();
create trigger patient_profiles_touch    before update on public.patient_profiles    for each row execute function public.set_updated_at();
create trigger doctor_profiles_touch     before update on public.doctor_profiles     for each row execute function public.set_updated_at();
create trigger pharmacist_profiles_touch before update on public.pharmacist_profiles for each row execute function public.set_updated_at();

-- Helper functions for RLS
create or replace function public.auth_role()
returns public.user_role
language sql stable security definer set search_path = public, pg_temp as $$
  select role from public.profiles where id = auth.uid()::text
$$;

create or replace function public.auth_clinic()
returns text
language sql stable security definer set search_path = public, pg_temp as $$
  select clinic_id from public.profiles where id = auth.uid()::text
$$;

revoke all on function public.auth_role()   from public, anon;
revoke all on function public.auth_clinic() from public, anon;
grant execute on function public.auth_role()   to authenticated;
grant execute on function public.auth_clinic() to authenticated;

-- RLS Enablement
alter table public.clinics             enable row level security;
alter table public.profiles            enable row level security;
alter table public.patient_profiles    enable row level security;
alter table public.doctor_profiles     enable row level security;
alter table public.pharmacist_profiles enable row level security;

-- RLS Policies
create policy clinics_read on public.clinics for select to authenticated using (true);

create policy profiles_read_self on public.profiles for select to authenticated using (id = auth.uid()::text);
create policy profiles_read_clinic_staff on public.profiles for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist') and clinic_id = public.auth_clinic());
create policy profiles_update_self on public.profiles for update to authenticated using (id = auth.uid()::text) with check (id = auth.uid()::text);

create policy patient_profiles_read_self on public.patient_profiles for select to authenticated using (id = auth.uid()::text);
create policy patient_profiles_read_assigned_doctor on public.patient_profiles for select to authenticated
  using (public.auth_role() = 'doctor' and assigned_doctor_id = auth.uid()::text);
create policy patient_profiles_write_self on public.patient_profiles for all to authenticated using (id = auth.uid()::text) with check (id = auth.uid()::text);

create policy doctor_profiles_read on public.doctor_profiles for select to authenticated using (id = auth.uid()::text or clinic_id = public.auth_clinic());
create policy doctor_profiles_update_self on public.doctor_profiles for update to authenticated using (id = auth.uid()::text) with check (id = auth.uid()::text);

create policy pharmacist_profiles_read on public.pharmacist_profiles for select to authenticated using (id = auth.uid()::text or clinic_id = public.auth_clinic());
create policy pharmacist_profiles_update_self on public.pharmacist_profiles for update to authenticated using (id = auth.uid()::text) with check (id = auth.uid()::text);

-- Doctor Directory Search Function
create or replace function public.doctor_directory(
  p_search         text default null,
  p_specialization text default null
)
returns table (
  id text, full_name text, avatar_url text,
  specialization text, bio text, average_rating numeric, clinic_id text
)
language sql stable security definer set search_path = public, pg_temp as $$
  select p.id, p.full_name, p.avatar_url,
         d.specialization, d.bio, d.average_rating, p.clinic_id
  from public.profiles p
  join public.doctor_profiles d on d.id = p.id
  where p.role = 'doctor'
    and p.is_active
    and (p_search is null or p.full_name ilike '%' || p_search || '%'
                          or d.specialization ilike '%' || p_search || '%')
    and (p_specialization is null or d.specialization = p_specialization)
  order by d.average_rating desc nulls last, p.full_name
$$;

revoke all on function public.doctor_directory(text, text) from public, anon;
grant execute on function public.doctor_directory(text, text) to authenticated;
