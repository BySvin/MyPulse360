create table public.clinics (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  address    text not null,
  phone      text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id                   uuid primary key references auth.users(id) on delete cascade,
  email                citext not null unique,
  full_name            text not null,
  role                 public.user_role not null,
  clinic_id            uuid not null references public.clinics(id),
  phone                text,
  avatar_url           text,
  is_active            boolean not null default true,
  must_change_password boolean not null default false,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index profiles_clinic_role_idx on public.profiles (clinic_id, role);

create table public.patient_profiles (
  id                      uuid primary key references public.profiles(id) on delete cascade,
  date_of_birth           date,
  gender                  text,
  blood_type              text,
  height_cm               numeric(5,2) not null,
  weight_kg               numeric(5,2) not null,
  allergies               text[] not null default '{}',
  chronic_conditions      text[] not null default '{}',
  current_medications     text[] not null default '{}',
  assigned_doctor_id      uuid references public.profiles(id),
  insurance_provider      text,
  emergency_contact_name  text,
  emergency_contact_phone text,
  preferred_clinic_id     uuid references public.clinics(id),
  preferred_language      text,
  notify_appointments     boolean not null default true,
  notify_prescriptions    boolean not null default true,
  notify_health_tips      boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create table public.doctor_profiles (
  id             uuid primary key references public.profiles(id) on delete cascade,
  license_number text not null unique,
  specialization text not null,
  clinic_id      uuid not null references public.clinics(id),
  bio            text,
  average_rating numeric(2,1) check (average_rating between 0 and 5),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table public.pharmacist_profiles (
  id             uuid primary key references public.profiles(id) on delete cascade,
  license_number text not null unique,
  pharmacy_name  text not null,
  clinic_id      uuid not null references public.clinics(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create trigger clinics_touch             before update on public.clinics             for each row execute function public.set_updated_at();
create trigger profiles_touch            before update on public.profiles            for each row execute function public.set_updated_at();
create trigger patient_profiles_touch    before update on public.patient_profiles    for each row execute function public.set_updated_at();
create trigger doctor_profiles_touch     before update on public.doctor_profiles     for each row execute function public.set_updated_at();
create trigger pharmacist_profiles_touch before update on public.pharmacist_profiles for each row execute function public.set_updated_at();

-- Created here, not in Task 1: these read `profiles`, and a `language sql`
-- body is validated against the catalog at CREATE FUNCTION time. They must also
-- exist before any policy below calls them. Definer rights are what stop the
-- policies on `profiles` from recursing.
create or replace function public.auth_role()
returns public.user_role
language sql stable security definer set search_path = public, pg_temp as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.auth_clinic()
returns uuid
language sql stable security definer set search_path = public, pg_temp as $$
  select clinic_id from public.profiles where id = auth.uid()
$$;

revoke all on function public.auth_role()   from public, anon;
revoke all on function public.auth_clinic() from public, anon;
grant execute on function public.auth_role()   to authenticated;
grant execute on function public.auth_clinic() to authenticated;

alter table public.clinics             enable row level security;
alter table public.profiles            enable row level security;
alter table public.patient_profiles    enable row level security;
alter table public.doctor_profiles     enable row level security;
alter table public.pharmacist_profiles enable row level security;

-- clinics: any signed-in user may read clinics; nobody writes from a client.
create policy clinics_read on public.clinics
  for select to authenticated using (true);

-- profiles: own row always; staff may read profiles within their own clinic.
create policy profiles_read_self on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_read_clinic_staff on public.profiles
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist') and clinic_id = public.auth_clinic());
create policy profiles_update_self on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- patient_profiles: the patient, or a doctor who is assigned or has an appointment.
create policy patient_profiles_read_self on public.patient_profiles
  for select to authenticated using (id = auth.uid());
create policy patient_profiles_read_assigned_doctor on public.patient_profiles
  for select to authenticated
  using (public.auth_role() = 'doctor' and assigned_doctor_id = auth.uid());
create policy patient_profiles_write_self on public.patient_profiles
  for all to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- doctor_profiles / pharmacist_profiles: own row, plus same-clinic staff visibility.
create policy doctor_profiles_read on public.doctor_profiles
  for select to authenticated
  using (id = auth.uid() or clinic_id = public.auth_clinic());
create policy doctor_profiles_update_self on public.doctor_profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy pharmacist_profiles_read on public.pharmacist_profiles
  for select to authenticated
  using (id = auth.uid() or clinic_id = public.auth_clinic());
create policy pharmacist_profiles_update_self on public.pharmacist_profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Doctor discovery. A definer function, not a view: it exposes exactly the
-- columns the "Find a doctor" screen needs and never email or phone.
create or replace function public.doctor_directory(
  p_search         text default null,
  p_specialization text default null
)
returns table (
  id uuid, full_name text, avatar_url text,
  specialization text, bio text, average_rating numeric, clinic_id uuid
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
