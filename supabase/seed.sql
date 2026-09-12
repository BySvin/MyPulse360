-- Seed data for MyPulse360 local development and demo testing (Short Text IDs).

-- 1. Single Main Clinic
insert into public.clinics (id, name, address, phone) values
  ('c01', 'MyPulse360 Main Clinic', '12 Wellness Ave', '+1 555-0100')
on conflict (id) do nothing;

-- 2. Base User Profiles
insert into public.profiles (id, email, full_name, role, clinic_id, phone) values
  ('d01', 'ahmed.rashid@mypulse360.test',  'Dr. Ahmed Rashid',   'doctor',    'c01', '+1 555-0111'),
  ('d02', 'lina.fernandez@mypulse360.test','Dr. Lina Fernandez', 'doctor',    'c01', '+1 555-0112'),
  ('ph01','nur.hakim@mypulse360.test',     'Nur Hakim',          'pharmacist','c01', '+1 555-0131'),
  ('p01', 'aisha.rahman@mypulse360.test',  'Aisha Rahman',       'patient',   'c01', '+1 555-0141'),
  ('p02', 'daniel.okafor@mypulse360.test', 'Daniel Okafor',      'patient',   'c01', '+1 555-0142')
on conflict (id) do nothing;

-- 3. Doctor Profiles
insert into public.doctor_profiles (id, license_number, specialization, clinic_id, bio, average_rating) values
  ('d01', 'MD-10001', 'General practice', 'c01', 'Dr. Rashid has practised family and general medicine for twelve years.', 4.9),
  ('d02', 'MD-10002', 'Family medicine',   'c01', 'Dr. Fernandez focuses on preventive care and chronic condition management.', 4.8)
on conflict (id) do nothing;

-- 4. Pharmacist Profiles
insert into public.pharmacist_profiles (id, license_number, clinic_id) values
  ('ph01', 'RP-20001', 'c01')
on conflict (id) do nothing;

-- 5. Patient Profiles
insert into public.patient_profiles
  (id, date_of_birth, gender, blood_type, height_cm, weight_kg, allergies, chronic_conditions,
   current_medications, assigned_doctor_id, preferred_clinic_id) values
  ('p01', '1996-04-12', 'Female', 'O+', 165.0, 61.0, '{Penicillin}', '{}', '{}', 'd01', 'c01'),
  ('p02', '1988-11-03', 'Male',   'A-', 178.0, 84.5, '{}', '{Type 2 diabetes}', '{Metformin}', 'd01', 'c01')
on conflict (id) do nothing;

-- 6. Doctor Availability (Monday=1 through Friday=5)
insert into public.doctor_availability (id, doctor_id, day_of_week, start_time, end_time) values
  ('avail01', 'd01', 1, '09:00', '17:00'),
  ('avail02', 'd01', 2, '09:00', '17:00'),
  ('avail03', 'd01', 3, '09:00', '17:00'),
  ('avail04', 'd01', 4, '09:00', '17:00'),
  ('avail05', 'd01', 5, '09:00', '17:00'),
  ('avail06', 'd02', 1, '09:00', '17:00'),
  ('avail07', 'd02', 2, '09:00', '17:00'),
  ('avail08', 'd02', 3, '09:00', '17:00'),
  ('avail09', 'd02', 4, '09:00', '17:00'),
  ('avail10', 'd02', 5, '09:00', '17:00')
on conflict (id) do nothing;

-- 7. Sample Appointments
insert into public.appointments
  (id, patient_id, doctor_id, clinic_id, scheduled_at, appointment_type, status, reason_for_visit)
values
  ('apt01', 'p02', 'd01', 'c01', now() + interval '1 day', 'Diabetes Follow-up', 'pending', 'Regular checkup'),
  ('apt02', 'p01', 'd01', 'c01', now() - interval '2 hours', 'General checkup', 'completed', 'Annual physical')
on conflict (id) do nothing;

-- 8. Health Metrics
insert into public.health_metrics (id, patient_id, metric_type, value, unit)
values ('hm01', 'p02', 'blood_sugar', 7.4, 'mmol/L')
on conflict (id) do nothing;

-- 9. Wellness Goals
insert into public.wellness_goals
  (id, patient_id, goal_type, target_value, unit, target_date)
values ('wg01', 'p02', 'Exercise', 8000, 'steps', date '2026-12-31')
on conflict (id) do nothing;

-- 10. Chat System
insert into public.chat_conversations (id, patient_id, doctor_id)
values ('chat01', 'p02', 'd01')
on conflict (id) do nothing;

insert into public.chat_messages (id, conversation_id, sender_id, message)
values ('msg01', 'chat01', 'p02', 'Is my blood sugar reading normal?')
on conflict (id) do nothing;
