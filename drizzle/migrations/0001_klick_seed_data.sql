insert into public.countries (name, code, phone_code, currency_code, currency_symbol) values
  ('République démocratique du Congo', 'CD', '+243', 'CDF', 'FC'),
  ('République du Congo', 'CG', '+242', 'XAF', 'FCFA');

insert into public.cities (country_id, name, slug, is_active, is_hq)
select id, 'Kinshasa', 'kinshasa', true, true from public.countries where code = 'CD';

insert into public.cities (country_id, name, slug, is_active, is_hq)
select id, 'Brazzaville', 'brazzaville', false, false from public.countries where code = 'CG';

insert into public.delivery_zones (city_id, name, description, delivery_fee, estimated_delivery_minutes)
select c.id, z.name, z.description, z.fee, z.eta from public.cities c
join (values
  ('Gombe', 'Centre-ville, ambassades et bureaux', 1500, 25),
  ('Ngaliema', 'Ma Campagne, Binza, Macampagne', 2000, 35),
  ('Lingwala', 'Lingwala, Kintambo, Bandalungwa', 2000, 35),
  ('Kalamu', 'Kalamu, Matonge, Victoire', 2000, 35),
  ('Limete', 'Limete, Résidentiel, Industriel', 2500, 45),
  ('Masina', 'Masina, Ndjili, Kimbanseke', 3000, 55)
) as z(name, description, fee, eta) on true
where c.slug = 'kinshasa';

insert into public.food_categories (name, slug, keywords, sort_order) values
  ('Grillades', 'grillades', array['poulet','grill','broche','barbecue','viande'], 1),
  ('Cuisine congolaise', 'cuisine-congolaise', array['fufu','pondu','moambe','mwamba','saka','congolais'], 2),
  ('Fast-food', 'fast-food', array['burger','pizza','frites','sandwich','shawarma'], 3),
  ('Poissons', 'poissons', array['poisson','capitaine','tilapia','mbisi','makayabu'], 4),
  ('Boissons & desserts', 'boissons-desserts', array['jus','boisson','dessert','glace','gâteau'], 5),
  ('Petit-déjeuner', 'petit-dejeuner', array['café','thé','croissant','omelette','matin'], 6);

do $$
declare
  v_city uuid; v_zone uuid;
begin
  select id into v_city from public.cities where slug = 'kinshasa';
  select id into v_zone from public.delivery_zones where name = 'Gombe' and city_id = v_city;

  insert into public.restaurants (city_id, zone_id, name, slug, description, cuisine_summary, status, is_open, rating, reviews_count, eta_min_minutes, eta_max_minutes, address, phone)
  values
    (v_city, v_zone, 'Gombe Grill', 'gombe-grill', 'Grillades et poulet braisé au cœur de Gombe.', 'Grillades, poulet, braises', 'approved', true, 4.5, 32, 20, 35, 'Avenue de la Nation, Gombe', '+243 810 000 001'),
    (v_city, v_zone, 'Chez Maman Ngoie', 'chez-maman-ngoie', 'Cuisine congolaise authentique, faite maison.', 'Congolais, fufu, pondu, moambe', 'approved', true, 4.7, 58, 25, 40, 'Boulevard du 30 Juin, Gombe', '+243 810 000 002'),
    (v_city, v_zone, 'Kin Fast Bites', 'kin-fast-bites', 'Burgers, frites et shawarmas livrés chauds.', 'Fast-food, burgers, shawarma', 'approved', true, 4.2, 21, 15, 30, 'Avenue Tombalbaye, Gombe', '+243 810 000 003'),
    (v_city, v_zone, 'Le Capitaine', 'le-capitaine', 'Poissons frais du fleuve, grillés ou en sauce.', 'Poissons, capitaine, tilapia', 'approved', true, 4.6, 44, 25, 45, 'Avenue du Port, Gombe', '+243 810 000 004'),
    (v_city, v_zone, 'Douceurs de Kin', 'douceurs-de-kin', 'Jus naturels, glaces et pâtisseries.', 'Boissons, desserts, glaces', 'approved', true, 4.4, 17, 15, 25, 'Avenue Kasa-Vubu, Gombe', '+243 810 000 005'),
    (v_city, v_zone, 'Café Matadi', 'cafe-matadi', 'Petit-déjeuner, café et brunch toute la journée.', 'Café, brunch, petit-déjeuner', 'approved', true, 4.3, 12, 15, 30, 'Avenue Wagenia, Gombe', '+243 810 000 006');

  insert into public.restaurant_food_categories (restaurant_id, category_id)
  select r.id, fc.id from public.restaurants r join public.food_categories fc on fc.slug =
    case r.slug
      when 'gombe-grill' then 'grillades'
      when 'chez-maman-ngoie' then 'cuisine-congolaise'
      when 'kin-fast-bites' then 'fast-food'
      when 'le-capitaine' then 'poissons'
      when 'douceurs-de-kin' then 'boissons-desserts'
      when 'cafe-matadi' then 'petit-dejeuner'
    end;

  insert into public.menu_categories (restaurant_id, name, sort_order)
  select id, 'Plats principaux', 1 from public.restaurants where city_id = v_city
  union all select id, 'Accompagnements', 2 from public.restaurants where city_id = v_city;

  insert into public.products (restaurant_id, category_id, name, description, price, sort_order)
  select r.id, mc.id, p.name, p.description, p.price, p.sort_order
  from public.restaurants r
  join public.menu_categories mc on mc.restaurant_id = r.id and mc.name = 'Plats principaux'
  join lateral (
    select * from (values
      ('gombe-grill', 'Poulet braisé entier', 'Poulet mariné grillé au feu de bois, servi avec frites.', 18000, 1),
      ('gombe-grill', 'Brochettes de bœuf (x5)', 'Brochettes assaisonnées, sauce piment maison.', 12000, 2),
      ('chez-maman-ngoie', 'Poulet moambe', 'Poulet à la sauce moambe, servi avec fufu ou riz.', 15000, 1),
      ('chez-maman-ngoie', 'Pondu & saka-saka', 'Feuilles de manioc et patate, accompagnement au choix.', 10000, 2),
      ('kin-fast-bites', 'Burger Kin Classic', 'Steak, fromage, crudités, sauce maison, frites incluses.', 9000, 1),
      ('kin-fast-bites', 'Shawarma poulet', 'Galette, poulet mariné, crudités, sauce blanche.', 8000, 2),
      ('le-capitaine', 'Capitaine grillé', 'Capitaine entier grillé, sauce tomate épicée, bananes plantain.', 25000, 1),
      ('le-capitaine', 'Tilapia en sauce', 'Tilapia mijoté, légumes frais, riz ou fufu.', 14000, 2),
      ('douceurs-de-kin', 'Jus de mangue naturel 50cl', 'Mangues fraîches pressées, sans sucre ajouté.', 4000, 1),
      ('douceurs-de-kin', 'Glace vanille-chocolat', 'Deux boules, coulis au choix.', 5000, 2),
      ('cafe-matadi', 'Brunch kinois', 'Omelette, pain grillé, fruits, café ou thé.', 11000, 1),
      ('cafe-matadi', 'Café arabica local', 'Café du Kivu, torréfaction artisanale.', 3000, 2)
    ) as v(rslug, name, description, price, sort_order)
    where v.rslug = r.slug
  ) p on true;
end $$;