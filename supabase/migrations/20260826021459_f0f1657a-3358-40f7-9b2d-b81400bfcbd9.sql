create or replace function public.fn_current_role() returns user_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid();
$$;

create or replace function public.fn_is_super_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from profiles where id = auth.uid() and role = 'super_admin');
$$;

create or replace function public.fn_is_city_admin_of(p_city_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select fn_is_super_admin() or exists(
    select 1 from city_admins ca
    join profiles p on p.id = ca.user_id
    where ca.user_id = auth.uid() and ca.city_id = p_city_id and p.role = 'city_admin'
  );
$$;

create or replace function public.fn_is_restaurant_member(p_restaurant_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from restaurant_users where restaurant_id = p_restaurant_id and user_id = auth.uid());
$$;

create or replace function public.fn_is_restaurant_owner(p_restaurant_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from restaurant_users where restaurant_id = p_restaurant_id and user_id = auth.uid() and member_role = 'owner');
$$;

create or replace function public.fn_current_driver_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from drivers where user_id = auth.uid();
$$;

alter table public.profiles enable row level security;
create policy profiles_select_own on public.profiles for select using (id = auth.uid() or fn_is_super_admin());
create policy profiles_select_city_admin on public.profiles for select using (fn_current_role() = 'city_admin');
create policy profiles_insert_own on public.profiles for insert with check (id = auth.uid());
create policy profiles_update_own on public.profiles for update using (id = auth.uid() or fn_is_super_admin());

alter table public.countries enable row level security;
alter table public.cities enable row level security;
alter table public.delivery_zones enable row level security;
create policy countries_select_all on public.countries for select using (true);
create policy countries_write_super_admin on public.countries for all using (fn_is_super_admin()) with check (fn_is_super_admin());
create policy cities_select_all on public.cities for select using (true);
create policy cities_write_super_admin on public.cities for all using (fn_is_super_admin()) with check (fn_is_super_admin());
create policy zones_select_all on public.delivery_zones for select using (true);
create policy zones_write_admin on public.delivery_zones for all using (fn_is_city_admin_of(city_id)) with check (fn_is_city_admin_of(city_id));

alter table public.city_admins enable row level security;
create policy city_admins_select on public.city_admins for select using (user_id = auth.uid() or fn_is_super_admin());
create policy city_admins_write on public.city_admins for all using (fn_is_super_admin()) with check (fn_is_super_admin());

alter table public.restaurant_applications enable row level security;
create policy rest_app_select on public.restaurant_applications for select using (applicant_user_id = auth.uid() or fn_is_city_admin_of(city_id));
create policy rest_app_insert on public.restaurant_applications for insert with check (applicant_user_id = auth.uid());
create policy rest_app_update_admin on public.restaurant_applications for update using (fn_is_city_admin_of(city_id)) with check (fn_is_city_admin_of(city_id));

alter table public.restaurants enable row level security;
create policy restaurants_select_public on public.restaurants for select using (status = 'approved');
create policy restaurants_select_own on public.restaurants for select using (fn_is_restaurant_member(id) or fn_is_city_admin_of(city_id));
create policy restaurants_update_team on public.restaurants for update using (fn_is_restaurant_member(id) or fn_is_city_admin_of(city_id)) with check (fn_is_restaurant_member(id) or fn_is_city_admin_of(city_id));

alter table public.restaurant_users enable row level security;
create policy rest_users_select on public.restaurant_users for select using (fn_is_restaurant_member(restaurant_id) or fn_is_city_admin_of((select city_id from restaurants where id = restaurant_id)));
create policy rest_users_write_owner on public.restaurant_users for all using (fn_is_restaurant_owner(restaurant_id) or fn_is_super_admin()) with check (fn_is_restaurant_owner(restaurant_id) or fn_is_super_admin());

alter table public.menu_categories enable row level security;
alter table public.products enable row level security;
alter table public.product_options enable row level security;
alter table public.product_option_values enable row level security;
create policy menu_cat_select_public on public.menu_categories for select using (exists(select 1 from restaurants r where r.id = restaurant_id and r.status = 'approved'));
create policy menu_cat_select_team on public.menu_categories for select using (fn_is_restaurant_member(restaurant_id) or fn_is_super_admin());
create policy menu_cat_write_team on public.menu_categories for all using (fn_is_restaurant_member(restaurant_id) or fn_is_super_admin()) with check (fn_is_restaurant_member(restaurant_id) or fn_is_super_admin());
create policy products_select_public on public.products for select using (exists(select 1 from restaurants r where r.id = restaurant_id and r.status = 'approved'));
create policy products_select_team on public.products for select using (fn_is_restaurant_member(restaurant_id) or fn_is_super_admin());
create policy products_write_team on public.products for all using (fn_is_restaurant_member(restaurant_id) or fn_is_super_admin()) with check (fn_is_restaurant_member(restaurant_id) or fn_is_super_admin());
create policy product_options_select on public.product_options for select using (exists(select 1 from products p where p.id = product_id));
create policy product_options_write on public.product_options for all using (fn_is_restaurant_member((select restaurant_id from products where id = product_id)) or fn_is_super_admin()) with check (fn_is_restaurant_member((select restaurant_id from products where id = product_id)) or fn_is_super_admin());
create policy option_values_select on public.product_option_values for select using (true);
create policy option_values_write on public.product_option_values for all using (fn_is_restaurant_member((select restaurant_id from products p join product_options po on po.product_id = p.id where po.id = option_id)) or fn_is_super_admin()) with check (fn_is_restaurant_member((select restaurant_id from products p join product_options po on po.product_id = p.id where po.id = option_id)) or fn_is_super_admin());

alter table public.addresses enable row level security;
create policy addresses_owner_all on public.addresses for all using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.driver_applications enable row level security;
alter table public.drivers enable row level security;
create policy driver_app_select on public.driver_applications for select using (applicant_user_id = auth.uid() or fn_is_city_admin_of(city_id));
create policy driver_app_insert on public.driver_applications for insert with check (applicant_user_id = auth.uid());
create policy driver_app_update_admin on public.driver_applications for update using (fn_is_city_admin_of(city_id)) with check (fn_is_city_admin_of(city_id));
create policy drivers_select_own on public.drivers for select using (user_id = auth.uid() or fn_is_city_admin_of(city_id));
create policy drivers_update_own on public.drivers for update using (user_id = auth.uid() or fn_is_city_admin_of(city_id)) with check (user_id = auth.uid() or fn_is_city_admin_of(city_id));

alter table public.orders enable row level security;
create policy orders_select_customer on public.orders for select using (customer_id = auth.uid());
create policy orders_select_restaurant on public.orders for select using (fn_is_restaurant_member(restaurant_id));
create policy orders_select_driver on public.orders for select using (driver_id = fn_current_driver_id());
create policy orders_select_driver_available on public.orders for select using (
  status = 'ready' and driver_id is null
  and exists(select 1 from drivers d where d.user_id = auth.uid() and d.city_id = orders.city_id and d.status = 'approved')
);
create policy orders_select_admin on public.orders for select using (fn_is_city_admin_of(city_id));

alter table public.order_items enable row level security;
create policy order_items_select on public.order_items for select using (exists(
  select 1 from orders o where o.id = order_id and (o.customer_id = auth.uid() or fn_is_restaurant_member(o.restaurant_id) or o.driver_id = fn_current_driver_id() or fn_is_city_admin_of(o.city_id))
));

alter table public.order_status_history enable row level security;
create policy order_history_select on public.order_status_history for select using (exists(
  select 1 from orders o where o.id = order_id and (o.customer_id = auth.uid() or fn_is_restaurant_member(o.restaurant_id) or o.driver_id = fn_current_driver_id() or fn_is_city_admin_of(o.city_id))
));

alter table public.deliveries enable row level security;
create policy deliveries_select on public.deliveries for select using (
  driver_id = fn_current_driver_id()
  or exists(select 1 from orders o where o.id = order_id and (fn_is_restaurant_member(o.restaurant_id) or o.customer_id = auth.uid() or fn_is_city_admin_of(o.city_id)))
);

alter table public.payments enable row level security;
create policy payments_select on public.payments for select using (
  user_id = auth.uid()
  or exists(select 1 from orders o where o.id = order_id and (fn_is_restaurant_member(o.restaurant_id) or fn_is_city_admin_of(o.city_id)))
);

alter table public.restaurant_commissions enable row level security;
alter table public.driver_earnings enable row level security;
create policy commissions_select on public.restaurant_commissions for select using (fn_is_restaurant_member(restaurant_id) or fn_is_super_admin());
create policy earnings_select on public.driver_earnings for select using (driver_id = fn_current_driver_id() or fn_is_super_admin());

alter table public.reviews enable row level security;
create policy reviews_select_public on public.reviews for select using (true);
create policy reviews_insert_customer on public.reviews for insert with check (
  customer_id = auth.uid() and exists(select 1 from orders o where o.id = order_id and o.customer_id = auth.uid())
);

alter table public.favorites enable row level security;
create policy favorites_owner_all on public.favorites for all using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.notifications enable row level security;
create policy notifications_select_own on public.notifications for select using (user_id = auth.uid());
create policy notifications_update_own on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.promotions enable row level security;
create policy promotions_select_public on public.promotions for select using (is_active and (ends_at is null or ends_at > now()));
create policy promotions_write_admin on public.promotions for all using (fn_is_super_admin() or (city_id is not null and fn_is_city_admin_of(city_id))) with check (fn_is_super_admin() or (city_id is not null and fn_is_city_admin_of(city_id)));

alter table public.audit_logs enable row level security;
create policy audit_logs_select_super_admin on public.audit_logs for select using (fn_is_super_admin());

revoke execute on function public.fn_log_audit(uuid, text, text, text, uuid, jsonb, jsonb) from anon, authenticated;
revoke execute on function public.fn_after_order_insert() from anon, authenticated;
revoke execute on function public.fn_notify_on_status_change() from anon, authenticated;
revoke execute on function public.fn_notify_restaurant_new_order() from anon, authenticated;
revoke execute on function public.fn_guard_profiles_role() from anon, authenticated;
revoke execute on function public.fn_guard_restaurant_columns() from anon, authenticated;
revoke execute on function public.fn_guard_driver_columns() from anon, authenticated;
revoke execute on function public.rpc_update_order_status(uuid, order_status, uuid, text) from anon;
revoke execute on function public.rpc_assign_driver(uuid, uuid) from anon;
revoke execute on function public.rpc_release_driver(uuid, uuid) from anon;