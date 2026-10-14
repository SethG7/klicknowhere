-- LOT 09 — Cohérence du cycle de livraison, disponibilité et gains livreur.
-- Dépend de la migration de sécurisation rpc_update_order_status existante.

create or replace function public.rpc_update_order_status(
  p_order_id uuid,
  p_new_status public.order_status,
  p_actor_id uuid,
  p_actor_role text
) returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_uid uuid := auth.uid();
  v_actor_id uuid;
  v_actor_role text;
  v_driver public.drivers%rowtype;
  v_delivery public.deliveries%rowtype;
begin
  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Commande % introuvable', p_order_id;
  end if;

  -- Ne jamais faire confiance au rôle transmis par le client connecté.
  if v_uid is null then
    -- Appel interne/service role : conserve le mécanisme existant.
    v_actor_id := p_actor_id;
    v_actor_role := coalesce(p_actor_role, 'system');
  else
    v_actor_id := v_uid;
    select * into v_driver from public.drivers where user_id = v_uid;

    if exists (
      select 1 from public.restaurant_users ru
      where ru.user_id = v_uid and ru.restaurant_id = v_order.restaurant_id
    ) then
      v_actor_role := 'restaurant';
      if p_new_status not in ('confirmed','preparing','ready','cancelled') then
        raise exception 'Transition non autorisee pour un restaurant';
      end if;
    elsif found and v_driver.id = v_order.driver_id then
      v_actor_role := 'driver';
      if p_new_status not in ('picked_up','on_the_way','delivered') then
        raise exception 'Transition non autorisee pour un livreur';
      end if;
    elsif public.fn_is_super_admin() or public.fn_is_city_admin_of(v_order.city_id) then
      v_actor_role := 'admin';
    else
      raise exception 'Acces refuse a cette commande';
    end if;
  end if;

  if not public.fn_is_valid_order_transition(v_order.status, p_new_status) then
    raise exception 'Transition interdite : % -> %', v_order.status, p_new_status;
  end if;

  -- Une livraison ne peut être finalisée que si elle est réellement attribuée.
  if p_new_status in ('picked_up','on_the_way','delivered') then
    select * into v_delivery
    from public.deliveries
    where order_id = p_order_id
    for update;

    if not found or v_delivery.driver_id is distinct from v_order.driver_id then
      raise exception 'Livraison introuvable ou livreur incoherent pour la commande';
    end if;
  end if;

  update public.orders set status = p_new_status where id = p_order_id;

  insert into public.order_status_history(order_id, from_status, to_status, changed_by)
  values (p_order_id, v_order.status, p_new_status, v_actor_id);

  perform public.fn_log_audit(
    v_actor_id, v_actor_role, 'order.status_changed', 'order', p_order_id,
    jsonb_build_object('status', v_order.status),
    jsonb_build_object('status', p_new_status)
  );

  if p_new_status = 'picked_up' then
    update public.deliveries
    set status = 'picked_up', picked_up_at = coalesce(picked_up_at, now())
    where order_id = p_order_id;
  elsif p_new_status = 'on_the_way' then
    update public.deliveries
    set status = 'on_the_way', picked_up_at = coalesce(picked_up_at, now())
    where order_id = p_order_id;
  elsif p_new_status = 'delivered' then
    update public.deliveries
    set status = 'delivered', delivered_at = coalesce(delivered_at, now())
    where order_id = p_order_id;

    -- La contrainte UNIQUE(delivery_id) garantit une seule ligne de gains.
    insert into public.driver_earnings(driver_id, delivery_id, amount, currency_code, status)
    select d.driver_id, d.id, d.driver_earnings, v_order.currency_code, 'pending'
    from public.deliveries d
    where d.order_id = p_order_id
      and d.driver_id = v_order.driver_id
    on conflict (delivery_id) do nothing;

    update public.drivers
    set is_available = true
    where id = v_order.driver_id and status = 'approved';
  elsif p_new_status = 'cancelled' and v_order.driver_id is not null then
    -- L'enum delivery_status n'a pas de valeur "cancelled" : "failed" marque
    -- la livraison interrompue sans inventer une nouvelle valeur d'enum.
    update public.deliveries
    set status = 'failed'
    where order_id = p_order_id and status <> 'delivered';

    update public.drivers
    set is_available = true
    where id = v_order.driver_id and status = 'approved';
  end if;

  select * into v_order from public.orders where id = p_order_id;
  return v_order;
end;
$$;

revoke execute on function public.rpc_update_order_status(uuid, public.order_status, uuid, text) from anon;
grant execute on function public.rpc_update_order_status(uuid, public.order_status, uuid, text) to authenticated;
