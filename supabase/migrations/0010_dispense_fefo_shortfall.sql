-- Replaces dispense_fefo to close a silent short-fulfilment path. The
-- sufficiency check is unlocked, so a concurrent dispense can drain batches
-- between the check and the loop; the loser previously returned fewer rows
-- than requested and reported success. Raising here aborts the invocation, so
-- its partial decrements and dispense rows roll back with it.
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

  -- A concurrent dispense drained stock after the check above passed. Fail the
  -- whole call rather than quietly handing over less medication than asked for.
  if v_remaining > 0 then
    raise exception 'insufficient stock: short by % of % requested', v_remaining, p_qty
      using errcode = '23514';
  end if;

  return;
end;
$$;
