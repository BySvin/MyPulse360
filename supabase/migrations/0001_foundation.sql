-- Migration 0001: Foundation
-- Setup required extensions, core enums, and utility functions.

create extension if not exists "uuid-ossp";
create extension if not exists "citext";

-- Core User Roles
do $$ begin
  create type public.user_role as enum ('patient', 'doctor', 'pharmacist');
exception
  when duplicate_object then null;
end $$;

-- Automatic updated_at timestamp trigger function
create or replace function public.set_updated_at()
returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
