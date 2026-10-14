-- KLICK finalisation patch: partner application details + reserved admin accounts.
-- Apply after all existing migrations in a staging project first.

alter table public.restaurant_applications
  add column if not exists applicant_full_name text,
  add column if not exists applicant_email citext,
  add column if not exists home_address text,
  add column if not exists business_address text,
  add column if not exists years_active integer check (years_active is null or years_active between 0 and 150),
  add column if not exists legal_type text;

alter table public.driver_applications
  add column if not exists applicant_full_name text,
  add column if not exists applicant_email citext,
  add column if not exists home_address text,
  add column if not exists business_name text,
  add column if not exists business_address text,
  add column if not exists years_active integer check (years_active is null or years_active between 0 and 150),
  add column if not exists applicant_type text not null default 'individual'
    check (applicant_type in ('individual','delivery_company')),
  add column if not exists description text;

-- Promote only accounts whose e-mail is confirmed by Supabase. Never trust user metadata.
create or replace function public.fn_sync_klick_reserved_admin()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text;
  v_confirmed boolean;
begin
  v_email := lower(coalesce(new.email, ''));
  v_confirmed := new.email_confirmed_at is not null;

  if tg_op = 'UPDATE' and lower(coalesce(old.email, '')) in ('nkolaguni@gmail.com','giuninkola99@gmail.com')
     and (v_email not in ('nkolaguni@gmail.com','giuninkola99@gmail.com') or not v_confirmed) then
    update public.profiles set role = 'customer' where id = new.id and role = 'super_admin';
  end if;

  if v_email in ('nkolaguni@gmail.com','giuninkola99@gmail.com') and v_confirmed then
    insert into public.profiles (id, email, role, status)
    values (new.id, new.email::citext, 'super_admin', 'active')
    on conflict (id) do update set email = excluded.email, role = 'super_admin', status = 'active';
  end if;
  return new;
end;
$$;

revoke all on function public.fn_sync_klick_reserved_admin() from public, anon, authenticated;
drop trigger if exists trg_sync_klick_reserved_admin on auth.users;
create trigger trg_sync_klick_reserved_admin
  after insert or update of email, email_confirmed_at on auth.users
  for each row execute function public.fn_sync_klick_reserved_admin();

-- Apply to existing confirmed accounts only.
insert into public.profiles (id, email, role, status)
select u.id, u.email::citext, 'super_admin', 'active'
from auth.users u
where lower(u.email) in ('nkolaguni@gmail.com','giuninkola99@gmail.com')
  and u.email_confirmed_at is not null
on conflict (id) do update set email = excluded.email, role = 'super_admin', status = 'active';
