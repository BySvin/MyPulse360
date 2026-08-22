-- Step 8 closed assigned_doctor_id for UPDATE but left INSERT table-wide, so
-- the self-assignment path simply moved to row creation.
revoke insert on public.patient_profiles from authenticated;
grant insert (
  id, date_of_birth, gender, blood_type, height_cm, weight_kg,
  allergies, chronic_conditions, current_medications,
  insurance_provider, emergency_contact_name, emergency_contact_phone,
  preferred_clinic_id, preferred_language,
  notify_appointments, notify_prescriptions, notify_health_tips
) on public.patient_profiles to authenticated;

-- The FK pointed at profiles, so any profile satisfied it — a patient could be
-- assigned another patient, or a pharmacist. doctor_profiles.id is itself a
-- profiles FK, so this is strictly narrower.
alter table public.patient_profiles
  drop constraint if exists patient_profiles_assigned_doctor_id_fkey;

alter table public.patient_profiles
  add constraint patient_profiles_assigned_doctor_id_fkey
  foreign key (assigned_doctor_id) references public.doctor_profiles(id);
