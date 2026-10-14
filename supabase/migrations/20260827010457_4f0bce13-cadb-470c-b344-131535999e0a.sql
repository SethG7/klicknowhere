-- GRANTS
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
  END LOOP;
END $$;

GRANT SELECT ON public.countries TO anon;
GRANT SELECT ON public.cities TO anon;
GRANT SELECT ON public.delivery_zones TO anon;
GRANT SELECT ON public.restaurants TO anon;
GRANT SELECT ON public.menu_categories TO anon;
GRANT SELECT ON public.products TO anon;
GRANT SELECT ON public.product_options TO anon;
GRANT SELECT ON public.product_option_values TO anon;
GRANT SELECT ON public.reviews TO anon;
GRANT SELECT ON public.promotions TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.order_number_seq TO anon, authenticated, service_role;

-- SEED
insert into countries (id, name, code, phone_code, currency_code, currency_symbol) values
  ('a0000000-0000-0000-0000-000000000001', 'RDC',   'CD', '+243', 'CDF', 'FC'),
  ('a0000000-0000-0000-0000-000000000002', 'Congo', 'CG', '+242', 'XAF', 'FCFA')
on conflict (id) do nothing;

insert into cities (id, country_id, name, slug, is_hq) values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Kinshasa',    'kinshasa',    true),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'Brazzaville', 'brazzaville', false)
on conflict (id) do nothing;

insert into delivery_zones (id, city_id, name, delivery_fee, estimated_delivery_minutes) values
  ('c0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001', 'Gombe',        6000, 30),
  ('c0000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000001', 'Lingwala',     5500, 25),
  ('c0000000-0000-0000-0000-000000000003','b0000000-0000-0000-0000-000000000001', 'Matonge',      6000, 30),
  ('c0000000-0000-0000-0000-000000000004','b0000000-0000-0000-0000-000000000002', 'Centre-ville', 1500, 30),
  ('c0000000-0000-0000-0000-000000000005','b0000000-0000-0000-0000-000000000002', 'Poto-Poto',    2000, 35),
  ('c0000000-0000-0000-0000-000000000006','b0000000-0000-0000-0000-000000000002', 'Bacongo',      1800, 30)
on conflict (id) do nothing;

insert into restaurants (id, city_id, zone_id, name, slug, cuisine_summary, status, is_open, rating, reviews_count, commission_rate, eta_min_minutes, eta_max_minutes) values
  ('20000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','Gombe Grill','gombe-grill','Grillades • Poulet • Congolais','approved',true,4.7,128,0.15,25,35),
  ('20000000-0000-0000-0000-000000000002','b0000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','Kin Burger House','kin-burger-house','Burgers • Fast Food','approved',true,4.6,94,0.15,20,30),
  ('20000000-0000-0000-0000-000000000003','b0000000-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000003','Chez Tantine Kinshasa','chez-tantine-kinshasa','Cuisine congolaise • Maison','approved',true,4.5,61,0.15,30,40),
  ('20000000-0000-0000-0000-000000000004','b0000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000004','Chez Fast Burger','chez-fast-burger','Burgers • Fast Food','approved',true,4.8,152,0.15,25,35),
  ('20000000-0000-0000-0000-000000000005','b0000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000004','Bella Pizza','bella-pizza','Pizza • Desserts','approved',true,4.7,110,0.15,30,45),
  ('20000000-0000-0000-0000-000000000006','b0000000-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000005','Le Grill de Poto-Poto','le-grill-de-poto-poto','Grillades • Poulet • Congolais','approved',true,4.6,73,0.15,30,40)
on conflict (id) do nothing;

insert into menu_categories (id, restaurant_id, name, sort_order) values
  ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Grillades',1),
  ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Burgers',1),
  ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003','Plats congolais',1),
  ('30000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000004','Burgers',1),
  ('30000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000005','Pizzas',1),
  ('30000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000006','Grillades',1)
on conflict (id) do nothing;

insert into products (id, restaurant_id, category_id, name, description, price, is_available, sort_order) values
  ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Poulet moambe','Sauce noix de palme, riz',18000,true,1),
  ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Brochettes bœuf','x4, sauce pili-pili',15000,true,2),
  ('40000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','Tilapia braisé','Poisson entier, plantain',22000,true,3),
  ('40000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','Kin Burger Classic','Steak, cheddar, salade',16000,true,1),
  ('40000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','Double Kin Burger','Double steak, bacon',21000,true,2),
  ('40000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003','Pondu na madesu','Feuilles de manioc, haricots',12000,true,1),
  ('40000000-0000-0000-0000-000000000007','20000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000003','Liboke de poisson','Poisson en papillote, chikwangue',17000,true,2),
  ('40000000-0000-0000-0000-000000000008','20000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000004','Burger Classic','Steak, fromage, salade',4500,true,1),
  ('40000000-0000-0000-0000-000000000009','20000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000004','Double Burger','Double steak, fromage',6000,true,2),
  ('40000000-0000-0000-0000-00000000000a','20000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000005','Pizza Margherita','Tomate, mozzarella, basilic',6000,true,1),
  ('40000000-0000-0000-0000-00000000000b','20000000-0000-0000-0000-000000000005','30000000-0000-0000-0000-000000000005','Pizza Pepperoni','Mozzarella, pepperoni',7000,true,2),
  ('40000000-0000-0000-0000-00000000000c','20000000-0000-0000-0000-000000000006','30000000-0000-0000-0000-000000000006','Poulet braisé (1/2)','Épices maison, piment',5500,true,1)
on conflict (id) do nothing;