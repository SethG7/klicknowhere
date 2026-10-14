create or replace function public.rpc_create_order(
  p_customer_id uuid, p_guest_phone text, p_customer_phone text, p_customer_notes text,
  p_recipient_name text, p_recipient_phone text, p_restaurant_id uuid, p_delivery_zone_id uuid,
  p_payment_method payment_method, p_delivery_quartier text, p_delivery_avenue text,
  p_delivery_repere text, p_items jsonb
) returns public.orders language plpgsql security definer set search_path = public as $$
declare
  v_restaurant restaurants%rowtype;
  v_zone delivery_zones%rowtype;
  v_order orders%rowtype;
  v_item jsonb;
  v_product products%rowtype;
  v_qty int;
  v_line_subtotal numeric(12,2);
  v_subtotal numeric(12,2) := 0;
  v_currency text;
begin
  if p_customer_id is not null and p_customer_id <> auth.uid() then
    raise exception 'Client invalide';
  end if;
  if p_customer_id is null and (p_guest_phone is null or length(trim(p_guest_phone)) = 0) then
    raise exception 'Une commande invite doit renseigner un numero de telephone';
  end if;

  select * into v_restaurant from restaurants where id = p_restaurant_id and status = 'approved' and is_open = true;
  if not found then
    raise exception 'Restaurant introuvable, non approuve, ou ferme';
  end if;

  select * into v_zone from delivery_zones where id = p_delivery_zone_id and city_id = v_restaurant.city_id;
  if not found then
    raise exception 'Zone de livraison invalide pour ce restaurant';
  end if;

  select currency_code into v_currency from countries co join cities ci on ci.country_id = co.id where ci.id = v_restaurant.city_id;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'Une commande doit contenir au moins un article';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_product from products
      where id = (v_item->>'product_id')::uuid and restaurant_id = p_restaurant_id and is_available = true;
    if not found then
      raise exception 'Produit indisponible ou n''appartient pas a ce restaurant';
    end if;
    v_qty := coalesce((v_item->>'quantity')::int, 0);
    if v_qty <= 0 then
      raise exception 'Quantite invalide pour le produit %', v_product.name;
    end if;
    v_line_subtotal := v_product.price * v_qty;
    v_subtotal := v_subtotal + v_line_subtotal;
  end loop;

  insert into orders (
    customer_id, guest_phone, customer_phone, customer_notes,
    recipient_name, recipient_phone, restaurant_id, city_id, delivery_zone_id,
    subtotal, delivery_fee, discount, total, currency_code,
    payment_method, delivery_quartier, delivery_avenue, delivery_repere
  ) values (
    p_customer_id, p_guest_phone, p_customer_phone, p_customer_notes,
    p_recipient_name, p_recipient_phone, p_restaurant_id, v_restaurant.city_id, p_delivery_zone_id,
    v_subtotal, v_zone.delivery_fee, 0, v_subtotal + v_zone.delivery_fee, v_currency,
    p_payment_method, p_delivery_quartier, p_delivery_avenue, p_delivery_repere
  ) returning * into v_order;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_product from products where id = (v_item->>'product_id')::uuid;
    v_qty := (v_item->>'quantity')::int;
    insert into order_items(order_id, product_id, product_name, unit_price, quantity, options_snapshot, subtotal)
    values (v_order.id, v_product.id, v_product.name, v_product.price, v_qty,
      coalesce(v_item->'options_snapshot', '[]'::jsonb), v_product.price * v_qty);
  end loop;

  insert into payments(order_id, user_id, method, amount, currency_code, status)
  values (v_order.id, p_customer_id, p_payment_method, v_order.total, v_currency,
    (case p_payment_method when 'cash' then 'cash_pending' else 'pending' end)::payment_status);

  return v_order;
end;
$$;

create or replace function public.rpc_confirm_cash_payment(p_order_id uuid, p_driver_id uuid)
returns public.payments language plpgsql security definer set search_path = public as $$
declare
  v_order orders%rowtype;
  v_payment payments%rowtype;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'Commande introuvable';
  end if;
  if v_order.driver_id is distinct from p_driver_id then
    raise exception 'Le livreur n''est pas assigne a cette commande';
  end if;
  if not exists(select 1 from drivers d where d.id = p_driver_id and d.user_id = auth.uid()) then
    raise exception 'Appelant non autorise';
  end if;
  if v_order.payment_method <> 'cash' then
    raise exception 'Cette commande n''est pas payee en especes';
  end if;
  update payments set status = 'cash_collected', paid_at = now()
  where order_id = p_order_id and method = 'cash' returning * into v_payment;
  if not found then
    raise exception 'Aucun paiement especes trouve';
  end if;
  update orders set payment_status = 'cash_collected' where id = p_order_id;
  perform fn_log_audit((select user_id from drivers where id = p_driver_id), 'driver', 'payment.cash_collected',
    'payment', v_payment.id, null, jsonb_build_object('order_id', p_order_id, 'amount', v_payment.amount));
  return v_payment;
end;
$$;

create or replace function public.rpc_confirm_mobile_money_payment(
  p_order_id uuid, p_transaction_reference text, p_provider text
) returns public.payments language plpgsql security definer set search_path = public as $$
declare
  v_payment payments%rowtype;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Cette fonction ne peut etre appelee que par le webhook de paiement';
  end if;
  update payments
  set status = 'paid', paid_at = now(), transaction_reference = p_transaction_reference, provider = p_provider
  where order_id = p_order_id and method = 'mobile_money' returning * into v_payment;
  if not found then
    raise exception 'Aucun paiement Mobile Money en attente';
  end if;
  update orders set payment_status = 'paid' where id = p_order_id;
  perform fn_log_audit(null, 'service_role', 'payment.mobile_money_confirmed',
    'payment', v_payment.id, null, jsonb_build_object('order_id', p_order_id, 'reference', p_transaction_reference));
  return v_payment;
end;
$$;

create or replace function public.rpc_track_guest_order(p_order_number text, p_phone text)
returns table (
  order_number text, status order_status, restaurant_name text, total numeric,
  currency_code text, eta_min_minutes int, eta_max_minutes int,
  driver_name text, driver_phone text, created_at timestamptz
) language sql security definer set search_path = public stable as $$
  select o.order_number, o.status, r.name, o.total, o.currency_code,
    r.eta_min_minutes, r.eta_max_minutes, p.full_name, p.phone, o.created_at
  from orders o
  join restaurants r on r.id = o.restaurant_id
  left join drivers d on d.id = o.driver_id
  left join profiles p on p.id = d.user_id
  where o.order_number = p_order_number and o.guest_phone = p_phone;
$$;

create or replace function public.rpc_approve_restaurant_application(p_application_id uuid, p_slug text default null)
returns public.restaurants language plpgsql security definer set search_path = public as $$
declare
  v_app restaurant_applications%rowtype;
  v_rest restaurants%rowtype;
  v_slug text;
begin
  select * into v_app from restaurant_applications where id = p_application_id for update;
  if not found then
    raise exception 'Candidature introuvable';
  end if;
  if not fn_is_city_admin_of(v_app.city_id) then
    raise exception 'Reserve aux administrateurs de la ville';
  end if;
  if v_app.status <> 'pending' then
    raise exception 'Candidature deja traitee';
  end if;
  v_slug := coalesce(p_slug, regexp_replace(lower(v_app.name), '[^a-z0-9]+', '-', 'g') || '-' || substr(replace(v_app.id::text,'-',''), 1, 6));
  update restaurant_applications set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now() where id = p_application_id;
  insert into restaurants(application_id, city_id, name, slug, description, phone, address, status)
  values (v_app.id, v_app.city_id, v_app.name, v_slug, v_app.description, v_app.phone, v_app.address, 'approved')
  returning * into v_rest;
  insert into restaurant_users(restaurant_id, user_id, member_role) values (v_rest.id, v_app.applicant_user_id, 'owner')
  on conflict do nothing;
  update profiles set role = 'restaurant_owner' where id = v_app.applicant_user_id and role = 'customer';
  perform fn_log_audit(auth.uid(), 'city_admin', 'restaurant.approved', 'restaurant', v_rest.id, null,
    jsonb_build_object('application_id', v_app.id));
  return v_rest;
end;
$$;

create or replace function public.rpc_approve_driver_application(p_application_id uuid)
returns public.drivers language plpgsql security definer set search_path = public as $$
declare
  v_app driver_applications%rowtype;
  v_driver drivers%rowtype;
begin
  select * into v_app from driver_applications where id = p_application_id for update;
  if not found then
    raise exception 'Candidature introuvable';
  end if;
  if not fn_is_city_admin_of(v_app.city_id) then
    raise exception 'Reserve aux administrateurs de la ville';
  end if;
  if v_app.status <> 'pending' then
    raise exception 'Candidature deja traitee';
  end if;
  update driver_applications set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now() where id = p_application_id;
  insert into drivers(user_id, application_id, city_id, status, vehicle_type)
  values (v_app.applicant_user_id, v_app.id, v_app.city_id, 'approved', v_app.vehicle_type)
  on conflict (user_id) do update set status = 'approved', city_id = excluded.city_id
  returning * into v_driver;
  update profiles set role = 'driver' where id = v_app.applicant_user_id and role = 'customer';
  perform fn_log_audit(auth.uid(), 'city_admin', 'driver.approved', 'driver', v_driver.id, null,
    jsonb_build_object('application_id', v_app.id));
  return v_driver;
end;
$$;

create or replace function public.rpc_reject_application(p_type text, p_application_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_city uuid;
begin
  if p_type = 'restaurant' then
    select city_id into v_city from restaurant_applications where id = p_application_id;
    if not fn_is_city_admin_of(v_city) then raise exception 'Non autorise'; end if;
    update restaurant_applications set status = 'rejected', rejection_reason = p_reason, reviewed_by = auth.uid(), reviewed_at = now() where id = p_application_id;
  elsif p_type = 'driver' then
    select city_id into v_city from driver_applications where id = p_application_id;
    if not fn_is_city_admin_of(v_city) then raise exception 'Non autorise'; end if;
    update driver_applications set status = 'rejected', rejection_reason = p_reason, reviewed_by = auth.uid(), reviewed_at = now() where id = p_application_id;
  else
    raise exception 'Type inconnu';
  end if;
end;
$$;

revoke execute on function public.rpc_create_order(uuid, text, text, text, text, text, uuid, uuid, payment_method, text, text, text, jsonb) from public;
grant execute on function public.rpc_create_order(uuid, text, text, text, text, text, uuid, uuid, payment_method, text, text, text, jsonb) to anon, authenticated;
revoke execute on function public.rpc_confirm_cash_payment(uuid, uuid) from anon;
revoke execute on function public.rpc_confirm_mobile_money_payment(uuid, text, text) from anon, authenticated;
grant execute on function public.rpc_track_guest_order(text, text) to anon, authenticated;
revoke execute on function public.rpc_approve_restaurant_application(uuid, text) from anon;
revoke execute on function public.rpc_approve_driver_application(uuid) from anon;
revoke execute on function public.rpc_reject_application(text, uuid, text) from anon;

alter publication supabase_realtime add table public.orders;