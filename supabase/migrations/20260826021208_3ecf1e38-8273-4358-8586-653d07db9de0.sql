create extension if not exists pgcrypto;
create extension if not exists citext;

create type user_role as enum ('customer','restaurant_owner','restaurant_manager','driver','city_admin','super_admin');
create type application_status as enum ('pending','approved','rejected');
create type restaurant_status as enum ('pending','approved','suspended','rejected');
create type restaurant_member_role as enum ('owner','manager');
create type order_status as enum ('pending','confirmed','preparing','ready','driver_assigned','picked_up','on_the_way','delivered','cancelled');
create type payment_method as enum ('cash','mobile_money','card');
create type payment_status as enum ('pending','paid','failed','refunded','cash_pending','cash_collected');
create type delivery_status as enum ('assigned','picked_up','on_the_way','delivered','failed');
create type driver_status as enum ('pending','approved','suspended','rejected');
create type vehicle_type as enum ('motorbike','bicycle','car','on_foot');
create type earning_status as enum ('pending','paid');
create type discount_type as enum ('percent','fixed');

create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  full_name     text,
  phone         text unique,
  email         citext unique,
  avatar_url    text,
  role          user_role not null default 'customer',
  status        text not null default 'active' check (status in ('active','suspended')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index idx_profiles_role on public.profiles(role);
create index idx_profiles_phone on public.profiles(phone);

create table public.countries (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  code            text not null unique,
  phone_code      text not null,
  currency_code   text not null,
  currency_symbol text not null,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.cities (
  id           uuid primary key default gen_random_uuid(),
  country_id   uuid not null references public.countries(id) on delete restrict,
  name         text not null,
  slug         text not null unique,
  is_active    boolean not null default true,
  is_hq        boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (country_id, name)
);
create index idx_cities_active on public.cities(is_active);

create table public.delivery_zones (
  id                          uuid primary key default gen_random_uuid(),
  city_id                     uuid not null references public.cities(id) on delete cascade,
  name                        text not null,
  description                 text,
  delivery_fee                numeric(12,2) not null default 0 check (delivery_fee >= 0),
  estimated_delivery_minutes  int not null default 30 check (estimated_delivery_minutes > 0),
  is_active                   boolean not null default true,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  unique (city_id, name)
);
create index idx_zones_city on public.delivery_zones(city_id);

create table public.city_admins (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  city_id     uuid not null references public.cities(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (user_id, city_id)
);
create index idx_city_admins_user on public.city_admins(user_id);
create index idx_city_admins_city on public.city_admins(city_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger trg_countries_updated_at before update on public.countries for each row execute function public.set_updated_at();
create trigger trg_cities_updated_at before update on public.cities for each row execute function public.set_updated_at();
create trigger trg_zones_updated_at before update on public.delivery_zones for each row execute function public.set_updated_at();

create table public.restaurant_applications (
  id                  uuid primary key default gen_random_uuid(),
  applicant_user_id   uuid not null references public.profiles(id) on delete cascade,
  city_id             uuid not null references public.cities(id) on delete restrict,
  name                text not null,
  phone               text not null,
  address             text,
  description         text,
  status              application_status not null default 'pending',
  reviewed_by         uuid references public.profiles(id),
  reviewed_at         timestamptz,
  rejection_reason    text,
  created_at          timestamptz not null default now()
);
create index idx_rest_app_status on public.restaurant_applications(status);
create index idx_rest_app_city on public.restaurant_applications(city_id);

create table public.restaurants (
  id                uuid primary key default gen_random_uuid(),
  application_id    uuid references public.restaurant_applications(id),
  city_id           uuid not null references public.cities(id) on delete restrict,
  zone_id           uuid references public.delivery_zones(id),
  name              text not null,
  slug              text not null unique,
  description       text,
  cuisine_summary   text,
  logo_url          text,
  cover_url         text,
  phone             text,
  address           text,
  latitude          numeric(10,7),
  longitude         numeric(10,7),
  status            restaurant_status not null default 'pending',
  is_open           boolean not null default true,
  rating            numeric(2,1) not null default 0 check (rating between 0 and 5),
  reviews_count     int not null default 0,
  commission_rate   numeric(5,4) not null default 0.1500,
  eta_min_minutes   int not null default 20,
  eta_max_minutes   int not null default 40,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index idx_restaurants_city on public.restaurants(city_id);
create index idx_restaurants_status on public.restaurants(status);
create index idx_restaurants_open on public.restaurants(is_open);
create index idx_restaurants_city_visible on public.restaurants(city_id, status, is_open);
create trigger trg_restaurants_updated_at before update on public.restaurants for each row execute function public.set_updated_at();

create table public.restaurant_users (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references public.restaurants(id) on delete cascade,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  member_role    restaurant_member_role not null default 'owner',
  created_at     timestamptz not null default now(),
  unique (restaurant_id, user_id)
);
create index idx_rest_users_restaurant on public.restaurant_users(restaurant_id);
create index idx_rest_users_user on public.restaurant_users(user_id);

create table public.menu_categories (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references public.restaurants(id) on delete cascade,
  name           text not null,
  sort_order     int not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  unique (restaurant_id, name)
);
create index idx_menu_cat_restaurant on public.menu_categories(restaurant_id);

create table public.products (
  id                 uuid primary key default gen_random_uuid(),
  restaurant_id      uuid not null references public.restaurants(id) on delete cascade,
  category_id        uuid references public.menu_categories(id) on delete set null,
  name               text not null,
  description        text,
  price              numeric(12,2) not null check (price >= 0),
  image_url          text,
  is_available       boolean not null default true,
  prep_time_minutes  int,
  sort_order         int not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index idx_products_restaurant on public.products(restaurant_id);
create index idx_products_category on public.products(category_id);
create index idx_products_available on public.products(restaurant_id, is_available);
create trigger trg_products_updated_at before update on public.products for each row execute function public.set_updated_at();

create table public.product_options (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references public.products(id) on delete cascade,
  name          text not null,
  is_required   boolean not null default false,
  min_select    int not null default 0,
  max_select    int not null default 1,
  sort_order    int not null default 0
);
create index idx_product_options_product on public.product_options(product_id);

create table public.product_option_values (
  id          uuid primary key default gen_random_uuid(),
  option_id   uuid not null references public.product_options(id) on delete cascade,
  label       text not null,
  price_delta numeric(12,2) not null default 0,
  sort_order  int not null default 0
);
create index idx_option_values_option on public.product_option_values(option_id);

grant select on public.countries, public.cities, public.delivery_zones, public.restaurants, public.menu_categories, public.products, public.product_options, public.product_option_values to anon, authenticated;
grant select, insert, update, delete on public.profiles, public.restaurant_applications, public.restaurants, public.restaurant_users, public.menu_categories, public.products, public.product_options, public.product_option_values, public.city_admins, public.countries, public.cities, public.delivery_zones to authenticated;
grant all on public.profiles, public.countries, public.cities, public.delivery_zones, public.city_admins, public.restaurant_applications, public.restaurants, public.restaurant_users, public.menu_categories, public.products, public.product_options, public.product_option_values to service_role;