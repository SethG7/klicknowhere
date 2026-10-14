-- KLICK LOT 15: richer initial applications + controlled Super Admin bootstrap.
-- Apply only after reviewing against the live schema and testing in staging.

alter table public.restaurant_applications
  add column if not exists domicile_address text,
  add column if not exists contact_email citext,
  add column if not exists years_active integer;

alter table public.restaurant_applications
  add constraint restaurant_applications_domicile_address_required
  check (domicile_address is not null and length(trim(domicile_address)) > 0) not valid;

alter table public.restaurant_applications
  add constraint restaurant_applications_years_active_valid
  check (years_active is null or years_active between 0 and 150) not valid;

alter table public.driver_applications
  add column if not exists full_name text,
  add column if not exists contact_email citext,
  add column if not exists home_address text,
  add column if not exists applicant_type text not null default 'individual',
  add column if not exists company_name text,
  add column if not exists business_address text,
  add column if not exists years_active integer;

alter table public.driver_applications
  add constraint driver_applications_type_valid
  check (applicant_type in ('individual','company')) not valid;

alter table public.driver_applications
  add constraint driver_applications_home_address_required
  check (home_address is not null and length(trim(home_address)) > 0) not valid;

alter table public.driver_applications
  add constraint driver_applications_company_details_required
  check (applicant_type <> 'company' or (length(trim(coalesce(company_name,''))) > 0 and length(trim(coalesce(business_address,''))) > 0)) not valid;

alter table public.driver_applications
  add constraint driver_applications_years_active_valid
  check (years_active is null or years_active between 0 and 150) not valid;

-- Promote only the two explicitly authorized addresses, only after Supabase confirms them.
create or replace function public.fn_promote_klick_super_admin()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text;
  v_confirmed boolean;
begin
  select lower(u.email), (u.email_confirmed_at is not null)
    into v_email, v_confirmed
  from auth.users u where u.id = new.id;

  if v_confirmed and v_email in ('nkolaguni@gmail.com','giuninkola99@gmail.com') then
    new.role := 'super_admin';
  elsif new.role = 'super_admin' and (not v_confirmed or v_email not in ('nkolaguni@gmail.com','giuninkola99@gmail.com')) then
    -- Do not allow profile self-escalation through this trigger.
    new.role := 'customer';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_promote_klick_super_admin on public.profiles;
create trigger trg_promote_klick_super_admin
before insert or update of email, role on public.profiles
for each row execute function public.fn_promote_klick_super_admin();

-- Backfill existing confirmed authorized profiles. Never promote an unconfirmed email.
update public.profiles p
set role = 'super_admin'
from auth.users u
where u.id = p.id
  and lower(u.email) in ('nkolaguni@gmail.com','giuninkola99@gmail.com')
  and u.email_confirmed_at is not null;

revoke all on function public.fn_promote_klick_super_admin() from public, anon, authenticated;
