-- KLICK: bootstrap the designated super administrator only after email verification.
-- Safe to run for an account that already exists or one created later.

create or replace function public.fn_guard_profiles_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller_is_super_admin boolean := false;
  v_is_designated_verified_admin boolean := false;
begin
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'super_admin'
  ) into v_caller_is_super_admin;

  select exists (
    select 1 from auth.users u
    where u.id = new.id
      and lower(u.email) = 'nkolaguni@gmail.com'
      and u.email_confirmed_at is not null
  ) into v_is_designated_verified_admin;

  if not v_caller_is_super_admin
     and auth.role() is distinct from 'service_role'
     and not (new.role = 'super_admin' and v_is_designated_verified_admin) then
    new.role := old.role;
    new.status := old.status;
  end if;
  return new;
end;
$$;

create or replace function public.fn_promote_designated_klick_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(new.email, '')) = 'nkolaguni@gmail.com'
     and new.email_confirmed_at is not null then
    update public.profiles
       set role = 'super_admin', status = 'active'
     where id = new.id
       and role is distinct from 'super_admin';
  end if;
  return new;
end;
$$;

revoke all on function public.fn_promote_designated_klick_admin() from public, anon, authenticated;

drop trigger if exists trg_promote_designated_klick_admin on auth.users;
create trigger trg_promote_designated_klick_admin
after insert or update of email, email_confirmed_at on auth.users
for each row execute function public.fn_promote_designated_klick_admin();

-- Promote the account now if it already exists and its email is confirmed.
update public.profiles p
   set role = 'super_admin', status = 'active'
  from auth.users u
 where p.id = u.id
   and lower(u.email) = 'nkolaguni@gmail.com'
   and u.email_confirmed_at is not null;
