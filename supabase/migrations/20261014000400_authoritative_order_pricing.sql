-- KLICK LOT 13: authoritative pricing on the database side.
-- Delivery fee is sourced from an ACTIVE delivery zone; commission is sourced
-- from the restaurant's configured rate. Client-supplied totals are not trusted.

create or replace function public.fn_set_order_financials()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rate numeric(5,4);
  v_zone public.delivery_zones%rowtype;
  v_restaurant_city uuid;
begin
  select r.commission_rate, r.city_id
    into v_rate, v_restaurant_city
  from public.restaurants r
  where r.id = new.restaurant_id
    and r.status = 'approved';

  if not found then
    raise exception 'Restaurant introuvable ou non approuve';
  end if;

  if v_rate is null or v_rate < 0 or v_rate > 1 then
    raise exception 'Taux de commission invalide pour ce restaurant';
  end if;

  if new.city_id is distinct from v_restaurant_city then
    raise exception 'La ville de commande ne correspond pas au restaurant';
  end if;

  if new.delivery_zone_id is null then
    raise exception 'Une zone de livraison est obligatoire';
  end if;

  select * into v_zone
  from public.delivery_zones z
  where z.id = new.delivery_zone_id
    and z.city_id = v_restaurant_city
    and z.is_active = true;

  if not found then
    raise exception 'Zone de livraison inactive ou invalide pour ce restaurant';
  end if;

  -- The database is the source of truth for delivery fees and totals.
  new.delivery_fee := v_zone.delivery_fee;
  if new.discount is null or new.discount < 0 then
    raise exception 'Remise invalide';
  end if;
  if new.subtotal is null or new.subtotal < 0 then
    raise exception 'Sous-total invalide';
  end if;
  if new.discount > new.subtotal + new.delivery_fee then
    raise exception 'La remise depasse le montant de la commande';
  end if;
  new.total := new.subtotal + new.delivery_fee - new.discount;

  -- Commission applies to food subtotal, not delivery fees.
  new.commission_rate := v_rate;
  new.commission_amount := round(new.subtotal * v_rate, 2);
  new.restaurant_amount := new.subtotal - new.commission_amount;
  return new;
end;
$$;

-- Keep the trigger attached and ensure normal app roles cannot call this trigger function directly.
revoke all on function public.fn_set_order_financials() from public, anon, authenticated;
