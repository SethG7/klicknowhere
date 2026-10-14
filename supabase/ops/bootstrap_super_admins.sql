-- À exécuter dans Supabase SQL Editor APRÈS création et confirmation des deux comptes.
-- Vérifier le projet sélectionné avant d'exécuter. Ne jamais ajouter de mot de passe ici.
begin;

-- Le trigger de garde empêche normalement les changements de rôle via l'application.
-- Désactivation temporaire limitée à cette transaction administrative.
alter table public.profiles disable trigger trg_guard_profiles_role;

insert into public.profiles (id, email, role, status)
select u.id, u.email::citext, 'super_admin'::user_role, 'active'
from auth.users u
where lower(u.email) in ('nkolaguni@gmail.com', 'giuninkola99@gmail.com')
  and u.email_confirmed_at is not null
on conflict (id) do update
set email = excluded.email,
    role = excluded.role,
    status = excluded.status;

alter table public.profiles enable trigger trg_guard_profiles_role;
commit;

-- Vérification : doit retourner uniquement les comptes confirmés ciblés.
select p.email, p.role, p.status, u.email_confirmed_at
from public.profiles p
join auth.users u on u.id = p.id
where lower(p.email::text) in ('nkolaguni@gmail.com', 'giuninkola99@gmail.com')
order by p.email;
