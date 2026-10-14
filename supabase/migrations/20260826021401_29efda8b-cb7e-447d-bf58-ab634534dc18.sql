create sequence public.order_number_seq start 1;

create or replace function public.fn_set_order_number()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.order_number is null then
    new.order_number := 'KLC-' || lpad(nextval('public.order_number_seq')::text, 6, '0');
  end if;
  return new;
end;
$$;

create or replace function public.fn_set_order_financials()
returns trigger language plpgsql set search_path = public as $$
declare
  v_rate numeric(5,4);
begin
  select commission_rate into v_rate from restaurants where id = new.restaurant_id;
  if v_rate is null then
    raise exception 'Restaurant % introuvable pour le calcul de commission', new.restaurant_id;
  end if;
  new.commission_rate := v_rate;
  new.commission_amount := round(new.subtotal * v_rate, 2);
  new.restaurant_amount := new.subtotal - new.commission_amount;
  if new.total <> (new.subtotal + new.delivery_fee - new.discount) then
    raise exception 'Incoherence de total';
  end if;
  return new;
end;
$$;

create trigger trg_order_number before insert on public.orders for each row execute function public.fn_set_order_number();
create trigger trg_order_financials before insert on public.orders for each row execute function public.fn_set_order_financials();

create or replace function public.fn_log_audit(
  p_actor_id uuid, p_actor_role text, p_action text,
  p_entity_type text, p_entity_id uuid, p_old_value jsonb, p_new_value jsonb
) returns void language sql security definer set search_path = public as $$
  insert into audit_logs(actor_id, actor_role, action, entity_type, entity_id, old_value, new_value)
  values (p_actor_id, p_actor_role, p_action, p_entity_type, p_entity_id, p_old_value, p_new_value);
$$;

create or replace function public.fn_after_order_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into order_status_history(order_id, from_status, to_status, changed_by)
  values (new.id, null, new.status, new.customer_id);
  insert into restaurant_commissions(order_id, restaurant_id, commission_rate, commission_amount, restaurant_amount)
  values (new.id, new.restaurant_id, new.commission_rate, new.commission_amount, new.restaurant_amount);
  perform fn_log_audit(new.customer_id, 'customer', 'order.created', 'order', new.id, null,
    jsonb_build_object('order_number', new.order_number, 'total', new.total, 'status', new.status));
  return new;
end;
$$;

create trigger trg_after_order_insert after insert on public.orders for each row execute function public.fn_after_order_insert();

create or replace function public.fn_is_valid_order_transition(p_from order_status, p_to order_status)
returns boolean language sql immutable set search_path = public as $$
  select case
    when p_from = 'pending' and p_to in ('confirmed','cancelled') then true
    when p_from = 'confirmed' and p_to in ('preparing','cancelled') then true
    when p_from = 'preparing' and p_to in ('ready','cancelled') then true
    when p_from = 'ready' and p_to in ('driver_assigned','cancelled') then true
    when p_from = 'driver_assigned' and p_to in ('picked_up','ready','cancelled') then true
    when p_from = 'picked_up' and p_to in ('on_the_way','cancelled') then true
    when p_from = 'on_the_way' and p_to in ('delivered','cancelled') then true
    else false
  end;
$$;

create or replace function public.rpc_update_order_status(
  p_order_id uuid, p_new_status order_status, p_actor_id uuid, p_actor_role text
) returns public.orders language plpgsql security definer set search_path = public as $$
declare
  v_order orders%rowtype;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'Commande % introuvable', p_order_id;
  end if;
  if not fn_is_valid_order_transition(v_order.status, p_new_status) then
    raise exception 'Transition interdite : % -> %', v_order.status, p_new_status;
  end if;
  update orders set status = p_new_status where id = p_order_id;
  insert into order_status_history(order_id, from_status, to_status, changed_by)
  values (p_order_id, v_order.status, p_new_status, p_actor_id);
  perform fn_log_audit(p_actor_id, p_actor_role, 'order.status_changed', 'order', p_order_id,
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
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found or v_order.driver_id is distinct from p_driver_id then
    raise exception 'Livreur non assigne a cette commande';
  end if;
  update orders set status = 'ready', driver_id = null where id = p_order_id;
  delete from deliveries where order_id = p_order_id;
  insert into order_status_history(order_id, from_status, to_status, changed_by)
  values (p_order_id, 'driver_assigned', 'ready', p_driver_id);
  select * into v_order from orders where id = p_order_id;
  return v_order;
end;
$$;

create or replace function public.fn_notify_on_status_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_restaurant_owner uuid;
begin
  if new.status = old.status then
    return new;
  end if;
  if new.customer_id is not null then
    insert into notifications(user_id, title, body, type, related_order_id)
    values (new.customer_id,
      case new.status
        when 'confirmed' then 'Commande confirmée'
        when 'preparing' then 'Votre commande est en préparation'
        when 'driver_assigned' then 'Un livreur a été assigné'
        when 'on_the_way' then 'Votre livreur est en route'
        when 'delivered' then 'Commande livrée'
        when 'cancelled' then 'Commande annulée'
        else 'Mise à jour de votre commande'
      end,
      'Commande ' || new.order_number, 'order_status_changed', new.id);
  end if;
  return new;
end;
$$;

create trigger trg_notify_on_status_change after update of status on public.orders
  for each row execute function public.fn_notify_on_status_change();

create or replace function public.fn_notify_restaurant_new_order()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_restaurant_owner uuid;
begin
  select user_id into v_restaurant_owner from restaurant_users
  where restaurant_id = new.restaurant_id and member_role = 'owner' limit 1;
  if v_restaurant_owner is not null then
    insert into notifications(user_id, title, body, type, related_order_id)
    values (v_restaurant_owner, 'Nouvelle commande', 'Commande ' || new.order_number, 'new_order', new.id);
  end if;
  return new;
end;
$$;

create trigger trg_notify_restaurant_new_order after insert on public.orders
  for each row execute function public.fn_notify_restaurant_new_order();

create or replace function public.fn_guard_profiles_role()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_caller_is_super_admin boolean;
begin
  select exists(select 1 from profiles where id = auth.uid() and role = 'super_admin')
    into v_caller_is_super_admin;
  if not v_caller_is_super_admin and auth.role() <> 'service_role' then
    new.role := old.role;
    new.status := old.status;
  end if;
  return new;
end;
$$;

create trigger trg_guard_profiles_role before update on public.profiles
  for each row execute function public.fn_guard_profiles_role();

create or replace function public.fn_guard_restaurant_columns()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_caller_is_admin boolean;
begin
  select exists(select 1 from profiles where id = auth.uid() and role in ('super_admin','city_admin'))
    into v_caller_is_admin;
  if not v_caller_is_admin and auth.role() <> 'service_role' then
    new.status := old.status;
    new.city_id := old.city_id;
    new.commission_rate := old.commission_rate;
  end if;
  return new;
end;
$$;

create trigger trg_guard_restaurant_columns before update on public.restaurants
  for each row execute function public.fn_guard_restaurant_columns();

create or replace function public.fn_guard_driver_columns()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_caller_is_admin boolean;
begin
  select exists(select 1 from profiles where id = auth.uid() and role in ('super_admin','city_admin'))
    into v_caller_is_admin;
  if not v_caller_is_admin and auth.role() <> 'service_role' then
    new.status := old.status;
    new.city_id := old.city_id;
  end if;
  return new;
end;
$$;

create trigger trg_guard_driver_columns before update on public.drivers
  for each row execute function public.fn_guard_driver_columns();

create or replace function public.fn_guard_review_requires_delivered()
returns trigger language plpgsql set search_path = public as $$
declare
  v_status order_status;
begin
  select status into v_status from orders where id = new.order_id;
  if v_status is distinct from 'delivered' then
    raise exception 'Impossible de laisser un avis : la commande n''est pas encore livree';
  end if;
  return new;
end;
$$;

create trigger trg_review_requires_delivered before insert on public.reviews
  for each row execute function public.fn_guard_review_requires_delivered();