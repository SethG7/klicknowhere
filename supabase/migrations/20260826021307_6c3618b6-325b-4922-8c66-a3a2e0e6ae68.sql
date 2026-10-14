create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  city_id uuid not null references public.cities(id),
  label text,
  quartier text not null,
  avenue text,
  repere text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_addresses_user on public.addresses(user_id);

create table public.driver_applications (
  id uuid primary key default gen_random_uuid(),
  applicant_user_id uuid not null references public.profiles(id) on delete cascade,
  city_id uuid not null references public.cities(id),
  vehicle_type vehicle_type not null,
  phone text not null,
  status application_status not null default 'pending',
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now()
);
create index idx_driver_app_status on public.driver_applications(status);

create table public.drivers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  application_id uuid references public.driver_applications(id),
  city_id uuid not null references public.cities(id),
  status driver_status not null default 'pending',
  vehicle_type vehicle_type not null,
  is_available boolean not null default false,
  current_latitude numeric(10,7),
  current_longitude numeric(10,7),
  rating numeric(2,1) not null default 0 check (rating between 0 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_drivers_city on public.drivers(city_id);
create index idx_drivers_available on public.drivers(city_id, status, is_available);
create trigger trg_drivers_updated_at before update on public.drivers for each row execute function public.set_updated_at();

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_id uuid references public.profiles(id),
  guest_name text,
  guest_phone text,
  customer_phone text not null,
  customer_notes text,
  recipient_name text,
  recipient_phone text,
  restaurant_id uuid not null references public.restaurants(id),
  city_id uuid not null references public.cities(id),
  delivery_zone_id uuid references public.delivery_zones(id),
  driver_id uuid references public.drivers(id),
  status order_status not null default 'pending',
  subtotal numeric(12,2) not null check (subtotal >= 0),
  delivery_fee numeric(12,2) not null default 0 check (delivery_fee >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  total numeric(12,2) not null check (total >= 0),
  currency_code text not null,
  commission_rate numeric(5,4) not null,
  commission_amount numeric(12,2) not null,
  restaurant_amount numeric(12,2) not null,
  payment_method payment_method not null,
  payment_status payment_status not null default 'pending',
  delivery_quartier text not null,
  delivery_avenue text,
  delivery_repere text,
  delivery_latitude numeric(10,7),
  delivery_longitude numeric(10,7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_customer_or_guest check (customer_id is not null or guest_phone is not null)
);
create index idx_orders_customer on public.orders(customer_id);
create index idx_orders_restaurant on public.orders(restaurant_id);
create index idx_orders_driver on public.orders(driver_id);
create index idx_orders_city on public.orders(city_id);
create index idx_orders_status on public.orders(status);
create index idx_orders_created_at on public.orders(created_at desc);
create index idx_orders_restaurant_status on public.orders(restaurant_id, status);
create index idx_orders_customer_created on public.orders(customer_id, created_at desc);
create trigger trg_orders_updated_at before update on public.orders for each row execute function public.set_updated_at();

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity int not null check (quantity > 0),
  options_snapshot jsonb not null default '[]'::jsonb,
  subtotal numeric(12,2) not null check (subtotal >= 0),
  created_at timestamptz not null default now()
);
create index idx_order_items_order on public.order_items(order_id);
create index idx_order_items_product on public.order_items(product_id);

create table public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  from_status order_status,
  to_status order_status not null,
  changed_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index idx_order_status_history_order on public.order_status_history(order_id);

create table public.deliveries (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  driver_id uuid references public.drivers(id),
  status delivery_status not null default 'assigned',
  assigned_at timestamptz not null default now(),
  picked_up_at timestamptz,
  delivered_at timestamptz,
  delivery_fee numeric(12,2) not null default 0,
  driver_earnings numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_deliveries_driver on public.deliveries(driver_id);
create index idx_deliveries_status on public.deliveries(status);
create trigger trg_deliveries_updated_at before update on public.deliveries for each row execute function public.set_updated_at();

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  user_id uuid references public.profiles(id),
  method payment_method not null,
  provider text,
  amount numeric(12,2) not null check (amount >= 0),
  currency_code text not null,
  status payment_status not null default 'pending',
  transaction_reference text,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
create index idx_payments_order on public.payments(order_id);
create index idx_payments_status on public.payments(status);

create table public.restaurant_commissions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id),
  restaurant_id uuid not null references public.restaurants(id),
  commission_rate numeric(5,4) not null,
  commission_amount numeric(12,2) not null,
  restaurant_amount numeric(12,2) not null,
  created_at timestamptz not null default now()
);
create index idx_commissions_restaurant on public.restaurant_commissions(restaurant_id, created_at desc);

create table public.driver_earnings (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.drivers(id),
  delivery_id uuid not null unique references public.deliveries(id),
  amount numeric(12,2) not null check (amount >= 0),
  currency_code text not null,
  status earning_status not null default 'pending',
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
create index idx_driver_earnings_driver on public.driver_earnings(driver_id, created_at desc);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id),
  customer_id uuid references public.profiles(id),
  restaurant_id uuid not null references public.restaurants(id),
  driver_id uuid references public.drivers(id),
  restaurant_rating int check (restaurant_rating between 1 and 5),
  delivery_rating int check (delivery_rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);
create index idx_reviews_restaurant on public.reviews(restaurant_id);
create index idx_reviews_driver on public.reviews(driver_id);

create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, restaurant_id)
);
create index idx_favorites_user on public.favorites(user_id);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text,
  type text not null,
  related_order_id uuid references public.orders(id),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_notifications_user on public.notifications(user_id, is_read);

create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  city_id uuid references public.cities(id),
  code text not null unique,
  description text,
  discount_type discount_type not null,
  discount_value numeric(12,2) not null check (discount_value >= 0),
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);
create index idx_promotions_active on public.promotions(is_active);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id),
  actor_role text,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz not null default now()
);
create index idx_audit_entity on public.audit_logs(entity_type, entity_id);
create index idx_audit_actor on public.audit_logs(actor_id);
create index idx_audit_created on public.audit_logs(created_at desc);

grant select on public.promotions to anon, authenticated;
grant select on public.reviews to anon, authenticated;
grant select, insert, update, delete on public.addresses, public.favorites to authenticated;
grant select, insert on public.driver_applications, public.reviews to authenticated;
grant select, update on public.drivers, public.orders, public.deliveries, public.notifications to authenticated;
grant select on public.order_items, public.order_status_history, public.payments, public.restaurant_commissions, public.driver_earnings, public.audit_logs to authenticated;
grant all on public.addresses, public.driver_applications, public.drivers, public.orders, public.order_items, public.order_status_history, public.deliveries, public.payments, public.restaurant_commissions, public.driver_earnings, public.reviews, public.favorites, public.notifications, public.promotions, public.audit_logs to service_role;