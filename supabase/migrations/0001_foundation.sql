create extension if not exists citext;

create type public.user_role            as enum ('patient','doctor','pharmacist');
create type public.appointment_status   as enum ('scheduled','confirmed','in_progress','completed','cancelled','rescheduled');
create type public.consultation_status  as enum ('in_progress','completed');
create type public.prescription_status  as enum ('active','expiring','expired','dispensed','cancelled');
create type public.prescription_source  as enum ('in_app','scanned_external');
create type public.metric_type          as enum ('weight','blood_pressure','blood_sugar','heart_rate',
                                                 'steps','sleep_hours','calories_burned','exercise_minutes');
create type public.wellness_goal_type   as enum ('exercise','hydration','sleep','diet','custom');
create type public.goal_status          as enum ('on_track','at_risk','excellent','behind');
create type public.wastage_reason       as enum ('expired','damaged','recalled','other');
create type public.shift_status         as enum ('scheduled','completed','missed','cancelled');
create type public.leave_status         as enum ('pending','approved','denied');
create type public.chat_sender          as enum ('user','assistant');
create type public.health_platform      as enum ('apple_health','google_fit');
create type public.interaction_severity as enum ('low','moderate','severe');

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
