-- available_slots returns 16 half-hour slots for a Wednesday (09:00-17:00).
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select case when count(*) = 16 then 'PASS' else 'FAIL: ' || count(*) || ' slots' end as status
from public.available_slots('22222222-2222-2222-2222-222222222221'::uuid, date '2026-08-26');
rollback;

-- Booking the same slot twice: the second attempt is refused.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select public.book_appointment('22222222-2222-2222-2222-222222222221'::uuid,
                               timestamptz '2026-08-26 10:30+00', 'General checkup', null);
do $$
begin
  perform public.book_appointment('22222222-2222-2222-2222-222222222221'::uuid,
                                  timestamptz '2026-08-26 10:30+00', 'General checkup', null);
  raise exception 'FAIL: double booking succeeded';
exception
  when unique_violation then raise notice 'PASS: double booking refused';
end;
$$;
rollback;

-- Approved leave cancels the appointments it collides with.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','44444444-4444-4444-4444-444444444441','role','authenticated')::text, true);
set local role authenticated;
select public.book_appointment('22222222-2222-2222-2222-222222222221'::uuid,
                               timestamptz '2026-08-27 09:00+00', 'General checkup', null);
set local role postgres;
select set_config('request.jwt.claims',
  json_build_object('sub','22222222-2222-2222-2222-222222222221','role','authenticated')::text, true);
set local role authenticated;
select public.decide_leave(
  (select id from public.apply_leave(date '2026-08-27', date '2026-08-28', 'Conference')),
  'approved');
select case when count(*) = 0 then 'PASS' else 'FAIL: ' || count(*) || ' survived' end as status
from public.appointments
where doctor_id = '22222222-2222-2222-2222-222222222221'
  and scheduled_at::date = date '2026-08-27'
  and status <> 'cancelled';
rollback;

-- FEFO consumes the earliest-expiry batch first.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','33333333-3333-3333-3333-333333333331','role','authenticated')::text, true);
set local role authenticated;
select public.dispense_fefo('55555555-5555-5555-5555-555555555551'::uuid, 10, null);
select case when b.quantity = 110 then 'PASS'
            else 'FAIL: MET-2025-A at ' || b.quantity || ', expected 110' end as status
from public.inventory_batches b
where b.item_id = '55555555-5555-5555-5555-555555555551' and b.batch_number = 'MET-2025-A';
rollback;

-- FEFO refuses when stock is short.
begin;
select set_config('request.jwt.claims',
  json_build_object('sub','33333333-3333-3333-3333-333333333331','role','authenticated')::text, true);
set local role authenticated;
do $$
begin
  perform public.dispense_fefo('55555555-5555-5555-5555-555555555552'::uuid, 99999, null);
  raise exception 'FAIL: oversized dispense succeeded';
exception
  when check_violation then raise notice 'PASS: insufficient stock refused';
end;
$$;
rollback;
