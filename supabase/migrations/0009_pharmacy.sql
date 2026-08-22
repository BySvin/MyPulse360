create table public.suppliers (
  id           uuid primary key default gen_random_uuid(),
  clinic_id    uuid not null references public.clinics(id),
  name         text not null,
  contact_name text,
  phone        text,
  email        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table public.inventory_items (
  id              uuid primary key default gen_random_uuid(),
  location_id     uuid not null references public.clinics(id),
  medication_name text not null,
  strength        text not null,
  form            text not null,
  reorder_level   int  not null default 0 check (reorder_level >= 0),
  unit_cost       numeric(10,2) not null check (unit_cost >= 0),
  barcode         text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (location_id, medication_name, strength, form)
);

create table public.inventory_batches (
  id               uuid primary key default gen_random_uuid(),
  item_id          uuid not null references public.inventory_items(id) on delete cascade,
  batch_number     text not null,
  quantity         int  not null check (quantity >= 0),
  initial_quantity int  not null check (initial_quantity >= 0),
  expiry_date      date not null,
  unit_cost        numeric(10,2) not null check (unit_cost >= 0),
  received_date    date not null,
  supplier_id      uuid references public.suppliers(id),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (item_id, batch_number)
);
-- FEFO reads earliest expiry first.
create index inventory_batches_fefo_idx on public.inventory_batches (item_id, expiry_date);

create table public.wastage_records (
  id          uuid primary key default gen_random_uuid(),
  batch_id    uuid not null references public.inventory_batches(id),
  item_id     uuid not null references public.inventory_items(id),
  quantity    int  not null check (quantity > 0),
  reason      public.wastage_reason not null,
  recorded_at timestamptz not null default now(),
  recorded_by uuid not null references public.profiles(id),
  note        text
);

create table public.dispense_records (
  id              uuid primary key default gen_random_uuid(),
  item_id         uuid not null references public.inventory_items(id),
  quantity        int  not null check (quantity > 0),
  dispensed_at    timestamptz not null default now(),
  batch_id        uuid references public.inventory_batches(id),
  prescription_id uuid references public.prescriptions(id),
  dispensed_by    uuid references public.profiles(id)
);

create trigger suppliers_touch         before update on public.suppliers         for each row execute function public.set_updated_at();
create trigger inventory_items_touch   before update on public.inventory_items   for each row execute function public.set_updated_at();
create trigger inventory_batches_touch before update on public.inventory_batches for each row execute function public.set_updated_at();

alter table public.suppliers         enable row level security;
alter table public.inventory_items   enable row level security;
alter table public.inventory_batches enable row level security;
alter table public.wastage_records   enable row level security;
alter table public.dispense_records  enable row level security;

-- Staff read their own clinic's stock; only pharmacists write it.
create policy suppliers_read on public.suppliers
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist') and clinic_id = public.auth_clinic());
create policy suppliers_write on public.suppliers
  for all to authenticated
  using (public.auth_role() = 'pharmacist' and clinic_id = public.auth_clinic())
  with check (public.auth_role() = 'pharmacist' and clinic_id = public.auth_clinic());

create policy inventory_items_read on public.inventory_items
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist') and location_id = public.auth_clinic());
create policy inventory_items_write on public.inventory_items
  for all to authenticated
  using (public.auth_role() = 'pharmacist' and location_id = public.auth_clinic())
  with check (public.auth_role() = 'pharmacist' and location_id = public.auth_clinic());

create policy inventory_batches_read on public.inventory_batches
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist')
         and exists (select 1 from public.inventory_items i
                      where i.id = public.inventory_batches.item_id
                        and i.location_id = public.auth_clinic()));
create policy inventory_batches_write on public.inventory_batches
  for all to authenticated
  using (public.auth_role() = 'pharmacist'
         and exists (select 1 from public.inventory_items i
                      where i.id = public.inventory_batches.item_id
                        and i.location_id = public.auth_clinic()))
  with check (public.auth_role() = 'pharmacist'
         and exists (select 1 from public.inventory_items i
                      where i.id = public.inventory_batches.item_id
                        and i.location_id = public.auth_clinic()));

create policy wastage_records_read on public.wastage_records
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist')
         and exists (select 1 from public.inventory_items i
                      where i.id = public.wastage_records.item_id
                        and i.location_id = public.auth_clinic()));
create policy wastage_records_insert on public.wastage_records
  for insert to authenticated
  with check (public.auth_role() = 'pharmacist' and recorded_by = auth.uid());

create policy dispense_records_read on public.dispense_records
  for select to authenticated
  using (public.auth_role() in ('doctor','pharmacist')
         and exists (select 1 from public.inventory_items i
                      where i.id = public.dispense_records.item_id
                        and i.location_id = public.auth_clinic()));

-- Stock decrements go through the RPC so batch quantity can never drift from
-- the dispense log.
revoke insert, update, delete on public.dispense_records from authenticated;

create or replace function public.dispense_fefo(
  p_item         uuid,
  p_qty          int,
  p_prescription uuid default null
)
returns setof public.dispense_records
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_remaining int := p_qty;
  v_take      int;
  v_batch     record;
  v_total     int;
begin
  if public.auth_role() <> 'pharmacist' then
    raise exception 'only pharmacists may dispense' using errcode = '42501';
  end if;
  if p_qty <= 0 then
    raise exception 'quantity must be positive' using errcode = '22023';
  end if;

  select coalesce(sum(b.quantity), 0) into v_total
  from public.inventory_batches b
  join public.inventory_items i on i.id = b.item_id
  where b.item_id = p_item
    and i.location_id = public.auth_clinic()
    and b.expiry_date >= current_date;

  if v_total < p_qty then
    raise exception 'insufficient stock: % available, % requested', v_total, p_qty
      using errcode = '23514';
  end if;

  for v_batch in
    select b.id, b.quantity
    from public.inventory_batches b
    join public.inventory_items i on i.id = b.item_id
    where b.item_id = p_item
      and i.location_id = public.auth_clinic()
      and b.expiry_date >= current_date
      and b.quantity > 0
    order by b.expiry_date, b.received_date
    for update
  loop
    exit when v_remaining <= 0;
    v_take := least(v_batch.quantity, v_remaining);

    update public.inventory_batches
       set quantity = quantity - v_take
     where id = v_batch.id;

    return query
      insert into public.dispense_records
        (item_id, quantity, batch_id, prescription_id, dispensed_by)
      values (p_item, v_take, v_batch.id, p_prescription, auth.uid())
      returning *;

    v_remaining := v_remaining - v_take;
  end loop;

  return;
end;
$$;

revoke all on function public.dispense_fefo(uuid, int, uuid) from public, anon;
grant execute on function public.dispense_fefo(uuid, int, uuid) to authenticated;
