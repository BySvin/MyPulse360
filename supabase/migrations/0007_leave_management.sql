-- Migration 0007: Doctor Leave Management (Text IDs)
-- Handles doctor leave requests and cancellation using text IDs.

create table public.leave_requests (
  id         text primary key,
  doctor_id  text not null references public.profiles(id) on delete cascade,
  start_date date not null,
  end_date   date not null,
  reason     text,
  status     text not null check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger leave_requests_touch before update on public.leave_requests for each row execute function public.set_updated_at();

alter table public.leave_requests enable row level security;

create policy leave_requests_doctor_self on public.leave_requests for all to authenticated
  using (doctor_id = auth.uid()::text or public.auth_role() = 'doctor')
  with check (doctor_id = auth.uid()::text and public.auth_role() = 'doctor');

-- Function to cancel a leave request
create or replace function public.cancel_leave(p_leave_id text)
returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if public.auth_role() <> 'doctor' then
    raise exception 'only doctors can cancel leave' using errcode = '42501';
  end if;

  update public.leave_requests
  set status = 'rejected'
  where id = p_leave_id and doctor_id = auth.uid()::text;
end;
$$;

revoke all on function public.cancel_leave(text) from public, anon;
grant execute on function public.cancel_leave(text) to authenticated;
