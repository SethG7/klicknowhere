-- KLICK LOT 08: prevent one driver from receiving multiple active deliveries.
-- Existing RPC is replaced in-place; the application flow and city scope stay unchanged.

create or replace function public.rpc_assign_driver(p_order_id uuid, p_driver_id uuid)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_driver public.drivers%rowtype;
  v_uid uuid := auth.uid();
begin
  -- Serialize competing attempts on the same order.
  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Commande % introuvable', p_order_id;
  end if;
  if v_order.status <> 'ready' then
    raise exception 'La commande n''est pas au statut ready';
  end if;
  if v_order.driver_id is not null then
    raise exception 'Commande deja attribuee a un livreur';
  end if;

  -- Serialize competing assignments to the same driver.
  select * into v_driver
  from public.drivers
  where id = p_driver_id
  for update;

  if not found or v_driver.status <> 'approved' then
    raise exception 'Livreur invalide ou non approuve';
  end if;
  if not v_driver.is_available then
    raise exception 'Livreur indisponible';
  end if;
  if v_driver.city_id <> v_order.city_id then
    raise exception 'Le livreur n''opere pas dans la ville de la commande';
  end if;
  if v_uid is not null
     and v_driver.user_id <> v_uid
     and not (public.fn_is_super_admin() or public.fn_is_city_admin_of(v_order.city_id)) then
    raise exception 'Acces refuse : ce livreur ne vous appartient pas';
  end if;

  -- Because the driver row is locked above, concurrent calls for this driver
  -- cannot both pass this active-order check before either assignment commits.
  if exists (
    select 1
    from public.orders o
    where o.driver_id = p_driver_id
      and o.status in ('driver_assigned', 'picked_up', 'on_the_way')
  ) then
    raise exception 'Ce livreur possède déjà une livraison en cours';
  end if;

  update public.orders
  set status = 'driver_assigned', driver_id = p_driver_id
  where id = p_order_id;

  insert into public.deliveries(order_id, driver_id, status, delivery_fee, driver_earnings)
  values (p_order_id, p_driver_id, 'assigned', v_order.delivery_fee, v_order.delivery_fee)
  on conflict (order_id) do update
    set driver_id = excluded.driver_id,
        status = 'assigned',
        assigned_at = now();

  -- Keep the driver's visible availability consistent with the active assignment.
  update public.drivers
  set is_available = false
  where id = p_driver_id;

  insert into public.order_status_history(order_id, from_status, to_status, changed_by)
  values (p_order_id, 'ready', 'driver_assigned', v_driver.user_id);

  perform public.fn_log_audit(
    v_driver.user_id,
    'driver',
    'delivery.assigned',
    'order',
    p_order_id,
    null,
    jsonb_build_object('driver_id', p_driver_id)
  );

  select * into v_order from public.orders where id = p_order_id;
  return v_order;
end;
$$;

revoke execute on function public.rpc_assign_driver(uuid, uuid) from anon;
grant execute on function public.rpc_assign_driver(uuid, uuid) to authenticated;
