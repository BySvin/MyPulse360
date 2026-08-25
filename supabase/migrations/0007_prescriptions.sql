create table public.prescriptions (
  id                   uuid primary key default gen_random_uuid(),
  patient_id           uuid not null references public.profiles(id),
  doctor_id            uuid references public.profiles(id),
  issued_date          date not null,
  expiry_date          date not null,
  status               public.prescription_status not null default 'active',
  consultation_id      uuid references public.consultations(id),
  source               public.prescription_source not null,
  external_doctor_name text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint prescriptions_has_prescriber
    check (doctor_id is not null or external_doctor_name is not null),
  constraint prescriptions_expiry_after_issue
    check (expiry_date >= issued_date)
);
create index prescriptions_patient_idx on public.prescriptions (patient_id, issued_date desc);

create table public.prescription_items (
  id              uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions(id) on delete cascade,
  medication_name text not null,
  strength        text not null,
  form            text not null,
  quantity        int  not null check (quantity > 0),
  unit            text not null,
  frequency       text not null,
  duration_days   int  not null check (duration_days > 0),
  instructions    text not null,
  refills_allowed int  not null default 0 check (refills_allowed >= 0),
  sort_order      smallint not null default 0,
  created_at      timestamptz not null default now()
);
create index prescription_items_parent_idx on public.prescription_items (prescription_id, sort_order);

create table public.drug_interactions (
  medication_a text not null,
  medication_b text not null,
  severity     public.interaction_severity not null,
  description  text not null,
  created_at   timestamptz not null default now(),
  primary key (medication_a, medication_b)
);

create trigger prescriptions_touch before update on public.prescriptions
  for each row execute function public.set_updated_at();

alter table public.prescriptions      enable row level security;
alter table public.prescription_items enable row level security;
alter table public.drug_interactions  enable row level security;

-- Patient sees their own; issuing doctor sees theirs; pharmacists see their clinic's.
create policy prescriptions_read on public.prescriptions
  for select to authenticated
  using (
    patient_id = auth.uid()
    or doctor_id = auth.uid()
    or (public.auth_role() = 'pharmacist'
        and exists (select 1 from public.profiles p
                     where p.id = public.prescriptions.patient_id
                       and p.clinic_id = public.auth_clinic()))
  );

create policy prescriptions_write_doctor on public.prescriptions
  for all to authenticated
  using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

-- A patient may file a scanned external prescription for themselves.
create policy prescriptions_insert_scanned on public.prescriptions
  for insert to authenticated
  with check (patient_id = auth.uid() and source = 'scanned_external');

-- Items inherit their parent's visibility through the parent's own policies.
create policy prescription_items_read on public.prescription_items
  for select to authenticated
  using (exists (select 1 from public.prescriptions pr
                  where pr.id = public.prescription_items.prescription_id));

create policy prescription_items_write on public.prescription_items
  for all to authenticated
  using (exists (select 1 from public.prescriptions pr
                  where pr.id = public.prescription_items.prescription_id
                    and (pr.doctor_id = auth.uid() or pr.patient_id = auth.uid())))
  with check (exists (select 1 from public.prescriptions pr
                       where pr.id = public.prescription_items.prescription_id
                         and (pr.doctor_id = auth.uid() or pr.patient_id = auth.uid())));

create policy drug_interactions_read on public.drug_interactions
  for select to authenticated using (true);

-- Dispensing safely needs allergies. It does not need medical history, so this
-- returns two arrays and nothing else, and only for a prescription belonging to
-- a patient at the calling pharmacist's clinic.
create or replace function public.prescription_safety(p_prescription uuid)
returns table (allergies text[], current_medications text[])
language sql stable security definer set search_path = public, pg_temp as $$
  select pp.allergies, pp.current_medications
  from public.prescriptions pr
  join public.patient_profiles pp on pp.id = pr.patient_id
  join public.profiles pat on pat.id = pr.patient_id
  where pr.id = p_prescription
    and public.auth_role() = 'pharmacist'
    and pat.clinic_id = public.auth_clinic()
$$;

revoke all on function public.prescription_safety(uuid) from public, anon;
grant execute on function public.prescription_safety(uuid) to authenticated;
