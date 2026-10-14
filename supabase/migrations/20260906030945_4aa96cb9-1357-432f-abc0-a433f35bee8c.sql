-- Durcissement production : autorisation réelle dans les fonctions sensibles

create or replace function public.rpc_update_order_status(
  p_order_id uuid, p_new_status order_status, p_actor_id uuid, p_actor_role text
) returns public.orders language plpgsql security definer set search_path = public as $$
declare
  v_order orders%rowtype;
  v_uid uuid := auth.uid();
  v_actor_id uuid;
  v_actor_role text;
  v_driver drivers%rowtype;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'Commande % introuvable', p_order_id;
  end if;

  if v_uid is null then
    -- Contexte interne / service role
    v_actor_id := p_actor_id;
    v_actor_role := coalesce(p_actor_role, 'system');
  else
    v_actor_id := v_uid;
    select * into v_driver from drivers where user_id = v_uid;

    if exists (select 1 from restaurant_users ru where ru.user_id = v_uid and ru.restaurant_id = v_order.restaurant_id) then
      v_actor_role := 'restaurant';
      if p_new_status not in ('confirmed','preparing','ready','cancelled') then
        raise exception 'Transition non autorisee pour un restaurant';
      end if;
    elsif found and v_driver.id = v_order.driver_id then
      v_actor_role := 'driver';
      if p_new_status not in ('picked_up','on_the_way','delivered') then
        raise exception 'Transition non autorisee pour un livreur';
      end if;
    elsif fn_is_super_admin() or fn_is_city_admin_of(v_order.city_id) then
      v_actor_role := 'admin';
    else
      raise exception 'Acces refuse a cette commande';
    end if;
  end if;

  if not fn_is_valid_order_transition(v_order.status, p_new_status) then
    raise exception 'Transition interdite : % -> %', v_order.status, p_new_status;
  end if;

  update orders set status = p_new_status where id = p_order_id;
  insert into order_status_history(order_id, from_status, to_status, changed_by)
  values (p_order_id, v_order.status, p_new_status, v_actor_id);
  perform fn_log_audit(v_actor_id, v_actor_role, 'order.status_changed', 'order', p_order_id,
    jsonb_build_object('status', v_order.status), jsonb_build_object('status', p_new_status));

  if p_new_status = 'delivered' then
    update deliveries set status = 'delivered', delivered_at = now() where order_id = p_order_id;
    insert into driver_earnings(driver_id, delivery_id, amount, currency_code, status)
    select d.driver_id, d.id, d.driver_earnings, v_order.currency_code, 'pending'
    from deliveries d where d.order_id = p_order_id
    on conflict (delivery_id) do nothing;
  end if;

  select * into v_order from orders where id = p_order_id;
  return v_order;
end;
$$;

create or replace function public.rpc_assign_driver(p_order_id uuid, p_driver_id uuid)
returns public.orders language plpgsql security definer set search_path = public as $$
declare
  v_order orders%rowtype;
  v_driver drivers%rowtype;
  v_uid uuid := auth.uid();
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'Commande % introuvable', p_order_id;
  end if;
  if v_order.status <> 'ready' then
    raise exception 'La commande n''est pas au statut ready';
  end if;
  if v_order.driver_id is not null then
    raise exception 'Commande deja attribuee a un livreur';
  end if;
  select * into v_driver from drivers where id = p_driver_id for update;
  if not found or v_driver.status <> 'approved' then
    raise exception 'Livreur invalide ou non approuve';
  end if;
  if v_uid is not null and v_driver.user_id <> v_uid and not (fn_is_super_admin() or fn_is_city_admin_of(v_order.city_id)) then
    raise exception 'Acces refuse : ce livreur ne vous appartient pas';
  end if;
  if not v_driver.is_available then
    raise exception 'Livreur indisponible';
  end if;
  if v_driver.city_id <> v_order.city_id then
    raise exception 'Le livreur n''opere pas dans la ville de la commande';
  end if;
  update orders set status = 'driver_assigned', driver_id = p_driver_id where id = p_order_id;
  insert into deliveries(order_id, driver_id, status, delivery_fee, driver_earnings)
  values (p_order_id, p_driver_id, 'assigned', v_order.delivery_fee, v_order.delivery_fee)
  on conflict (order_id) do update set driver_id = excluded.driver_id, status = 'assigned';
  insert into order_status_history(order_id, from_status, to_status, changed_by)
  values (p_order_id, 'ready', 'driver_assigned', v_driver.user_id);
  perform fn_log_audit(v_driver.user_id, 'driver', 'delivery.assigned', 'order', p_order_id,
    null, jsonb_build_object('driver_id', p_driver_id));
  select * into v_order from orders where id = p_order_id;
  return v_order;
end;
$$;

create or replace function public.rpc_release_driver(p_order_id uuid, p_driver_id uuid)
returns public.orders language plpgsql security definer set search_path = public as $$
declare
  v_order orders%rowtype;
  v_driver drivers%rowtype;
  v_uid uuid := auth.uid();
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found or v_order.driver_id is distinct from p_driver_id then
    raise exception 'Livreur non assigne a cette commande';
  end if;
  select * into v_driver from drivers where id = p_driver_id;
  if v_uid is not null and (v_driver.user_id is distinct from v_uid)
     and not (fn_is_super_admin() or fn_is_city_admin_of(v_order.city_id)) then
    raise exception 'Acces refuse';
  end if;
  update orders set status = 'ready', driver_id = null where id = p_order_id;
  delete from deliveries where order_id = p_order_id;
  insert into order_status_history(order_id, from_status, to_status, changed_by)
  values (p_order_id, 'driver_assigned', 'ready', v_driver.user_id);
  perform fn_log_audit(v_driver.user_id, 'driver', 'delivery.released', 'order', p_order_id, null, null);
  select * into v_order from orders where id = p_order_id;
  return v_order;
end;
$$;

-- Les administrateurs de ville ne lisent que les profils de leur perimetre
drop policy if exists profiles_select_city_admin on public.profiles;
create policy profiles_select_city_admin on public.profiles
for select to authenticated
using (
  fn_is_super_admin()
  or exists (
    select 1 from public.city_admins ca
    where ca.user_id = auth.uid()
      and (
        exists (select 1 from public.orders o where o.customer_id = profiles.id and o.city_id = ca.city_id)
        or exists (select 1 from public.restaurant_users ru join public.restaurants r on r.id = ru.restaurant_id
                   where ru.user_id = profiles.id and r.city_id = ca.city_id)
        or exists (select 1 from public.drivers d where d.user_id = profiles.id and d.city_id = ca.city_id)
        or exists (select 1 from public.restaurant_applications ra where ra.applicant_user_id = profiles.id and ra.city_id = ca.city_id)
        or exists (select 1 from public.driver_applications da where da.applicant_user_id = profiles.id and da.city_id = ca.city_id)
      )
  )
);