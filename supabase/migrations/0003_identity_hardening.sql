-- RLS chooses rows; column grants choose columns. 0002 had only the first half,
-- so a self-update could rewrite the very columns auth_role()/auth_clinic()
-- read to decide authorization.
revoke update on public.profiles from authenticated;
grant  update (full_name, phone, avatar_url) on public.profiles to authenticated;

-- average_rating is system-derived; licence, specialisation and clinic are
-- administrative. Only the bio is the doctor's to edit.
revoke update on public.doctor_profiles from authenticated;
grant  update (bio) on public.doctor_profiles to authenticated;

-- A pharmacist has no self-editable fields at all.
drop policy if exists pharmacist_profiles_update_self on public.pharmacist_profiles;
revoke update on public.pharmacist_profiles from authenticated;

-- `for all` also granted DELETE, which would orphan the row while the parent
-- profiles row survived. Split it into explicit insert and update policies.
-- The read path is unaffected: patient_profiles_read_self already covers select.
drop policy if exists patient_profiles_write_self on public.patient_profiles;

create policy patient_profiles_insert_self on public.patient_profiles
  for insert to authenticated
  with check (id = auth.uid());

create policy patient_profiles_update_self on public.patient_profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Patients own their medical data, but not which doctor they are assigned to.
revoke update on public.patient_profiles from authenticated;
grant update (
  date_of_birth, gender, blood_type, height_cm, weight_kg,
  allergies, chronic_conditions, current_medications,
  insurance_provider, emergency_contact_name, emergency_contact_phone,
  preferred_clinic_id, preferred_language,
  notify_appointments, notify_prescriptions, notify_health_tips
) on public.patient_profiles to authenticated;
