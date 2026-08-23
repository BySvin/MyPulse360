-- Demo passwords match lib/shared/mock/fixtures/seed_credentials.dart.
insert into public.clinics (id, name, address, phone) values
  ('11111111-1111-1111-1111-111111111111', 'MyPulse360 Clinic',   '12 Wellness Ave', '+1 555-0100'),
  ('11111111-1111-1111-1111-111111111112', 'MyPulse360 Downtown', '48 Market St',    '+1 555-0177')
on conflict (id) do nothing;

create or replace function pg_temp.seed_user(
  p_id uuid, p_email text, p_password text
) returns void language plpgsql as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    p_email, extensions.crypt(p_password, extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
  ) on conflict (id) do nothing;

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    p_id::text, p_id,
    jsonb_build_object('sub', p_id::text, 'email', p_email),
    'email', now(), now(), now()
  ) on conflict (provider, provider_id) do nothing;
end;
$$;

select pg_temp.seed_user('22222222-2222-2222-2222-222222222221', 'ahmed.rashid@mypulse360.test',  'Doctor123!');
select pg_temp.seed_user('22222222-2222-2222-2222-222222222222', 'lina.fernandez@mypulse360.test','Doctor123!');
select pg_temp.seed_user('33333333-3333-3333-3333-333333333331', 'nur.hakim@mypulse360.test',     'Pharma123!');
select pg_temp.seed_user('44444444-4444-4444-4444-444444444441', 'aisha.rahman@mypulse360.test',  'Patient123!');
select pg_temp.seed_user('44444444-4444-4444-4444-444444444442', 'daniel.okafor@mypulse360.test', 'Patient123!');

insert into public.profiles (id, email, full_name, role, clinic_id, phone) values
  ('22222222-2222-2222-2222-222222222221','ahmed.rashid@mypulse360.test',  'Dr. Ahmed Rashid',   'doctor',    '11111111-1111-1111-1111-111111111111','+1 555-0111'),
  ('22222222-2222-2222-2222-222222222222','lina.fernandez@mypulse360.test','Dr. Lina Fernandez', 'doctor',    '11111111-1111-1111-1111-111111111111','+1 555-0112'),
  ('33333333-3333-3333-3333-333333333331','nur.hakim@mypulse360.test',     'Nur Hakim',          'pharmacist','11111111-1111-1111-1111-111111111111','+1 555-0131'),
  ('44444444-4444-4444-4444-444444444441','aisha.rahman@mypulse360.test',  'Aisha Rahman',       'patient',   '11111111-1111-1111-1111-111111111111','+1 555-0141'),
  ('44444444-4444-4444-4444-444444444442','daniel.okafor@mypulse360.test', 'Daniel Okafor',      'patient',   '11111111-1111-1111-1111-111111111111','+1 555-0142')
on conflict (id) do nothing;

insert into public.doctor_profiles (id, license_number, specialization, clinic_id, bio, average_rating) values
  ('22222222-2222-2222-2222-222222222221','MD-10021','General practice','11111111-1111-1111-1111-111111111111',
   'Dr. Rashid has practised family and general medicine for twelve years and has been with MyPulse360 Clinic since 2019.', 4.9),
  ('22222222-2222-2222-2222-222222222222','MD-10022','Family medicine','11111111-1111-1111-1111-111111111111',
   'Dr. Fernandez focuses on preventive care and chronic condition management.', 4.8)
on conflict (id) do nothing;

insert into public.pharmacist_profiles (id, license_number, pharmacy_name, clinic_id) values
  ('33333333-3333-3333-3333-333333333331','RP-30011','MyPulse360 Pharmacy','11111111-1111-1111-1111-111111111111')
on conflict (id) do nothing;

insert into public.patient_profiles
  (id, date_of_birth, gender, blood_type, height_cm, weight_kg, allergies, chronic_conditions,
   current_medications, assigned_doctor_id, preferred_clinic_id) values
  ('44444444-4444-4444-4444-444444444441','1996-04-12','Female','O+',165.0,61.0,
   '{Penicillin}','{}','{}','22222222-2222-2222-2222-222222222221','11111111-1111-1111-1111-111111111111'),
  ('44444444-4444-4444-4444-444444444442','1988-11-03','Male','A-',178.0,84.5,
   '{}','{Type 2 diabetes}','{Metformin}','22222222-2222-2222-2222-222222222221','11111111-1111-1111-1111-111111111111')
on conflict (id) do nothing;

-- 09:00-17:00, 30-minute slots, Monday to Friday: reproduces the hardcoded
-- loop in mock_appointments_datasource.dart.
insert into public.doctor_availability (doctor_id, weekday, start_time, end_time, slot_minutes)
select d.id, w.weekday, time '09:00', time '17:00', 30
from (values ('22222222-2222-2222-2222-222222222221'::uuid),
             ('22222222-2222-2222-2222-222222222222'::uuid)) as d(id),
     generate_series(0, 4) as w(weekday)
on conflict (doctor_id, weekday, start_time) do nothing;

insert into public.drug_interactions (medication_a, medication_b, severity, description) values
  ('Warfarin','Aspirin','severe','Markedly increased bleeding risk when taken together.'),
  ('Metformin','Contrast dye','moderate','Withhold metformin around contrast imaging.'),
  ('Amoxicillin','Methotrexate','moderate','Reduced methotrexate clearance; monitor levels.')
on conflict (medication_a, medication_b) do nothing;

insert into public.inventory_items (id, location_id, medication_name, strength, form, reorder_level, unit_cost, barcode) values
  ('55555555-5555-5555-5555-555555555551','11111111-1111-1111-1111-111111111111','Metformin','500 mg','Tablet',50,0.12,'9551234500011'),
  ('55555555-5555-5555-5555-555555555552','11111111-1111-1111-1111-111111111111','Amoxicillin','250 mg','Capsule',40,0.31,'9551234500028')
on conflict (id) do nothing;

insert into public.suppliers (id, clinic_id, name, contact_name, phone, email) values
  ('66666666-6666-6666-6666-666666666661','11111111-1111-1111-1111-111111111111','Meridian Pharma','Sofia Lim','+1 555-0201','orders@meridian.test')
on conflict (id) do nothing;

-- Two batches per item with different expiries, so FEFO order is observable.
insert into public.inventory_batches
  (item_id, batch_number, quantity, initial_quantity, expiry_date, unit_cost, received_date, supplier_id) values
  ('55555555-5555-5555-5555-555555555551','MET-2025-A',120,200,'2027-03-31',0.12,'2026-06-01','66666666-6666-6666-6666-666666666661'),
  ('55555555-5555-5555-5555-555555555551','MET-2025-B',300,300,'2027-11-30',0.12,'2026-07-15','66666666-6666-6666-6666-666666666661'),
  ('55555555-5555-5555-5555-555555555552','AMX-2026-A',80,150,'2027-01-31',0.31,'2026-05-20','66666666-6666-6666-6666-666666666661')
on conflict (item_id, batch_number) do nothing;

-- Rows owned by the OTHER patient (Daniel), so the cross-tenant assertions in
-- 0015_rls_isolation_test.sql actually exercise RLS. Without these they pass
-- trivially. Dates are chosen not to collide with the RPC behaviour tests,
-- which use 2026-08-26 10:30 and 2026-08-27 09:00.
insert into public.appointments
  (id, patient_id, doctor_id, clinic_id, scheduled_at, appointment_type, status)
values ('77777777-7777-7777-7777-777777777771',
        '44444444-4444-4444-4444-444444444442',
        '22222222-2222-2222-2222-222222222221',
        '11111111-1111-1111-1111-111111111111',
        timestamptz '2026-09-02 09:00+00', 'Diabetes Follow-up', 'scheduled')
on conflict (id) do nothing;

insert into public.health_metrics (id, patient_id, type, value, measured_at)
values ('77777777-7777-7777-7777-777777777772',
        '44444444-4444-4444-4444-444444444442', 'blood_sugar', 7.4,
        timestamptz '2026-08-20 08:00+00')
on conflict (id) do nothing;

insert into public.wellness_goals
  (id, patient_id, type, name, target_value, current_value, unit, status, target_date)
values ('77777777-7777-7777-7777-777777777773',
        '44444444-4444-4444-4444-444444444442', 'exercise', 'Walk 8000 steps',
        8000, 5200, 'steps', 'at_risk', date '2026-12-31')
on conflict (id) do nothing;

insert into public.chat_conversations (id, patient_id)
values ('77777777-7777-7777-7777-777777777774',
        '44444444-4444-4444-4444-444444444442')
on conflict (id) do nothing;

insert into public.chat_messages (id, conversation_id, sender, body, sent_at)
values ('77777777-7777-7777-7777-777777777775',
        '77777777-7777-7777-7777-777777777774', 'user',
        'Is my blood sugar reading normal?', timestamptz '2026-08-20 08:05+00')
on conflict (id) do nothing;
