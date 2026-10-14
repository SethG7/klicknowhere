ALTER TABLE public.drivers ADD COLUMN IF NOT EXISTS commission_rate numeric(5,4) NOT NULL DEFAULT 0.10 CHECK (commission_rate >= 0 AND commission_rate <= 0.5);
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS commission_rate numeric(5,4) NOT NULL DEFAULT 0;
ALTER TABLE public.deliveries ADD COLUMN IF NOT EXISTS commission_amount numeric(12,2) NOT NULL DEFAULT 0;
ALTER TABLE public.restaurants ADD COLUMN IF NOT EXISTS opening_hours jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.deals ADD COLUMN IF NOT EXISTS days_of_week smallint[];
ALTER TABLE public.deals ADD COLUMN IF NOT EXISTS daily_start time;
ALTER TABLE public.deals ADD COLUMN IF NOT EXISTS daily_end time;

CREATE OR REPLACE FUNCTION public.fn_guard_driver_columns()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $f$
declare v_caller_is_admin boolean;
begin
  select exists(select 1 from profiles where id = auth.uid() and role in ('super_admin','city_admin')) into v_caller_is_admin;
  if not v_caller_is_admin and auth.role() <> 'service_role' then
    new.status := old.status; new.city_id := old.city_id; new.commission_rate := old.commission_rate;
  end if;
  return new;
end; $f$;

CREATE POLICY deals_restaurant_select ON public.deals FOR SELECT TO authenticated USING (restaurant_id IS NOT NULL AND public.fn_is_restaurant_member(restaurant_id));
CREATE POLICY deals_restaurant_insert ON public.deals FOR INSERT TO authenticated WITH CHECK (restaurant_id IS NOT NULL AND public.fn_is_restaurant_member(restaurant_id) AND city_id = (SELECT r.city_id FROM public.restaurants r WHERE r.id = restaurant_id));
CREATE POLICY deals_restaurant_update ON public.deals FOR UPDATE TO authenticated USING (restaurant_id IS NOT NULL AND public.fn_is_restaurant_member(restaurant_id)) WITH CHECK (restaurant_id IS NOT NULL AND public.fn_is_restaurant_member(restaurant_id));
CREATE POLICY deliveries_super_admin_select ON public.deliveries FOR SELECT TO authenticated USING (public.fn_is_super_admin());

CREATE OR REPLACE FUNCTION public.fn_refresh_ratings() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $f$
begin
  update restaurants r set rating = coalesce((select round(avg(restaurant_rating)::numeric,1) from reviews where restaurant_id = r.id and restaurant_rating is not null),0),
    reviews_count = (select count(*) from reviews where restaurant_id = r.id and restaurant_rating is not null) where r.id = new.restaurant_id;
  if new.driver_id is not null then
    update drivers d set rating = coalesce((select round(avg(delivery_rating)::numeric,1) from reviews where driver_id = d.id and delivery_rating is not null),0) where d.id = new.driver_id;
  end if;
  return new;
end; $f$;
DROP TRIGGER IF EXISTS trg_reviews_refresh_ratings ON public.reviews;
CREATE TRIGGER trg_reviews_refresh_ratings AFTER INSERT ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.fn_refresh_ratings();

CREATE OR REPLACE FUNCTION public.rpc_assign_driver(p_order_id uuid, p_driver_id uuid)
 RETURNS orders LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
declare
  v_order orders%rowtype;
  v_driver drivers%rowtype;
  v_uid uuid := auth.uid();
  v_rate numeric;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then raise exception 'Commande % introuvable', p_order_id; end if;
  if v_order.status <> 'ready' then raise exception 'La commande n''est pas au statut ready'; end if;
  if v_order.driver_id is not null then raise exception 'Commande deja attribuee a un livreur'; end if;
  select * into v_driver from drivers where id = p_driver_id for update;
  if not found or v_driver.status <> 'approved' then raise exception 'Livreur invalide ou non approuve'; end if;
  if v_uid is not null and v_driver.user_id <> v_uid and not (fn_is_super_admin() or fn_is_city_admin_of(v_order.city_id)) then
    raise exception 'Acces refuse : ce livreur ne vous appartient pas';
  end if;
  if not v_driver.is_available then raise exception 'Livreur indisponible'; end if;
  if v_driver.city_id <> v_order.city_id then raise exception 'Le livreur n''opere pas dans la ville de la commande'; end if;
  v_rate := coalesce(v_driver.commission_rate, 0);
  update orders set status = 'driver_assigned', driver_id = p_driver_id where id = p_order_id;
  insert into deliveries(order_id, driver_id, status, delivery_fee, driver_earnings, commission_rate, commission_amount)
  values (p_order_id, p_driver_id, 'assigned', v_order.delivery_fee, round(v_order.delivery_fee * (1 - v_rate), 2), v_rate, round(v_order.delivery_fee * v_rate, 2))
  on conflict (order_id) do update set driver_id = excluded.driver_id, status = 'assigned', driver_earnings = excluded.driver_earnings, commission_rate = excluded.commission_rate, commission_amount = excluded.commission_amount;
  insert into order_status_history(order_id, from_status, to_status, changed_by)
  values (p_order_id, 'ready', 'driver_assigned', v_driver.user_id);
  perform fn_log_audit(v_driver.user_id, 'driver', 'delivery.assigned', 'order', p_order_id, null, jsonb_build_object('driver_id', p_driver_id));
  select * into v_order from orders where id = p_order_id;
  return v_order;
end;
$function$;