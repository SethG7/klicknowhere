-- KLICK LOT 16
-- Hardens candidate submissions and reliably bootstraps the two authorized Super Admins.
-- Review and run in Supabase staging before production.

-- Applicants may submit applications, but may never submit a pre-approved application
-- or impersonate the reviewer. Review actions remain controlled by existing admin RPC/RLS.
create or replace function public.fn_lock_new_restaurant_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.status := 'pending';
  new.reviewed_by := null;
  new.reviewed_at := null;
  new.rejection_reason := null;
  return new;
end;
$$;

create or replace function public.fn_lock_new_driver_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.status := 'pending';
  new.reviewed_by := null;
  new.reviewed_at := null;
  new.rejection_reason := null;
  return new;
end;
$$;

drop trigger if exists trg_lock_new_restaurant_application on public.restaurant_applications;
create trigger trg_lock_new_restaurant_application
before insert on public.restaurant_applications
for each row execute function public.fn_lock_new_restaurant_application();

drop trigger if exists trg_lock_new_driver_application on public.driver_applications;
create trigger trg_lock_new_driver_application
before insert on public.driver_applications
for each row execute function public.fn_lock_new_driver_application();

revoke all on function public.fn_lock_new_restaurant_application() from public, anon, authenticated;
revoke all on function public.fn_lock_new_driver_application() from public, anon, authenticated;

-- The earlier profile trigger only runs when a profile row is inserted/updated. This
-- auth.users trigger also handles the case where the account becomes email-confirmed
-- after its profile was created. Only the two exact, confirmed email addresses qualify.
create or replace function public.fn_sync_klick_super_admin_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text;
  v_is_authorized boolean;
  v_was_authorized boolean := false;
begin
  v_email := lower(coalesce(new.email, ''));
  v_is_authorized := new.email_confirmed_at is not null
    and v_email in ('nkolaguni@gmail.com', 'giuninkola99@gmail.com');

  if tg_op = 'UPDATE' then
    v_was_authorized := lower(coalesce(old.email, '')) in ('nkolaguni@gmail.com', 'giuninkola99@gmail.com');
  end if;

  if v_is_authorized then
    insert into public.profiles (id, email, role)
    values (new.id, new.email, 'super_admin'::user_role)
    on conflict (id) do update
      set email = excluded.email,
          role = 'super_admin'::user_role;
  elsif tg_op = 'UPDATE' and v_was_authorized then
    -- If an allowlisted account changes to a different address, remove its reserved role.
    update public.profiles
       set email = new.email,
           role = 'customer'::user_role
     where id = new.id and role = 'super_admin'::user_role;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_klick_super_admin_from_auth on auth.users;
create trigger trg_sync_klick_super_admin_from_auth
after insert or update of email, email_confirmed_at on auth.users
for each row execute function public.fn_sync_klick_super_admin_from_auth();

revoke all on function public.fn_sync_klick_super_admin_from_auth() from public, anon, authenticated;

-- Backfill accounts already confirmed before this migration. Does not create Auth users.
insert into public.profiles (id, email, role)
select u.id, u.email, 'super_admin'::user_role
from auth.users u
where u.email_confirmed_at is not null
  and lower(u.email) in ('nkolaguni@gmail.com', 'giuninkola99@gmail.com')
on conflict (id) do update
  set email = excluded.email,
      role = 'super_admin'::user_role;

-- Deliberately do not grant broad table permissions here: existing grants and RLS policies
-- remain authoritative. This migration only normalizes applicant-submitted review fields.
