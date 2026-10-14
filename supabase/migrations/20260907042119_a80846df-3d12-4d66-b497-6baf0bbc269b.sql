create table if not exists public.staff_invitations (
  id uuid primary key default gen_random_uuid(),
  email citext not null,
  role user_role not null,
  city_id uuid references public.cities(id) on delete set null,
  invited_by uuid references public.profiles(id),
  status text not null default 'pending',
  accepted_at timestamptz,
  accepted_user_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists staff_invitations_pending_email
  on public.staff_invitations(email) where status = 'pending';

grant select, insert, update on public.staff_invitations to authenticated;
grant all on public.staff_invitations to service_role;

alter table public.staff_invitations enable row level security;

create policy "staff_invitations_select_admin" on public.staff_invitations
  for select to authenticated
  using (fn_is_super_admin() or (city_id is not null and fn_is_city_admin_of(city_id)) or email = (select p.email from public.profiles p where p.id = auth.uid()));

create trigger trg_staff_invitations_updated_at
  before update on public.staff_invitations
  for each row execute function public.set_updated_at();

create or replace function public.rpc_invite_staff(p_email text, p_role user_role, p_city_id uuid)
returns public.staff_invitations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row staff_invitations%rowtype;
  v_user uuid;
begin
  if p_role not in ('city_admin','restaurant_owner','restaurant_manager','driver','super_admin') then
    raise exception 'Role non autorise pour une invitation';
  end if;
  if p_role = 'super_admin' then
    if not fn_is_super_admin() then raise exception 'Reserve a la direction'; end if;
  elsif p_role = 'city_admin' then
    if not (fn_is_super_admin() or fn_is_city_admin_of(p_city_id)) then raise exception 'Acces refuse'; end if;
    if p_city_id is null then raise exception 'Ville obligatoire pour un administrateur de ville'; end if;
  else
    if not (fn_is_super_admin() or (p_city_id is not null and fn_is_city_admin_of(p_city_id))) then
      raise exception 'Acces refuse';
    end if;
  end if;

  delete from staff_invitations where lower(email) = lower(p_email) and status = 'pending';

  insert into staff_invitations(email, role, city_id, invited_by)
  values (p_email::citext, p_role, p_city_id, auth.uid())
  returning * into v_row;

  -- Si l'utilisateur existe deja, on applique immediatement le role.
  select id into v_user from profiles where email = p_email::citext;
  if v_user is not null then
    update profiles set role = p_role where id = v_user;
    if p_role = 'city_admin' and p_city_id is not null then
      insert into city_admins(user_id, city_id) values (v_user, p_city_id) on conflict do nothing;
    end if;
    update staff_invitations set status = 'accepted', accepted_at = now(), accepted_user_id = v_user where id = v_row.id
    returning * into v_row;
  end if;

  perform fn_log_audit(auth.uid(), 'admin', 'staff.invited', 'staff_invitation', v_row.id, null,
    jsonb_build_object('email', p_email, 'role', p_role, 'city_id', p_city_id));
  return v_row;
end;
$$;

create or replace function public.rpc_revoke_staff_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row staff_invitations%rowtype;
begin
  select * into v_row from staff_invitations where id = p_invitation_id;
  if not found then raise exception 'Invitation introuvable'; end if;
  if not (fn_is_super_admin() or (v_row.city_id is not null and fn_is_city_admin_of(v_row.city_id))) then
    raise exception 'Acces refuse';
  end if;
  update staff_invitations set status = 'revoked' where id = p_invitation_id and status = 'pending';
  perform fn_log_audit(auth.uid(), 'admin', 'staff.invitation_revoked', 'staff_invitation', p_invitation_id, null, null);
end;
$$;

create or replace function public.rpc_set_user_role(p_user_id uuid, p_role user_role, p_city_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old user_role;
begin
  if not fn_is_super_admin() then raise exception 'Reserve a la direction'; end if;
  if p_user_id = auth.uid() then raise exception 'Impossible de modifier son propre role'; end if;
  select role into v_old from profiles where id = p_user_id;
  if v_old is null then raise exception 'Utilisateur introuvable'; end if;
  update profiles set role = p_role where id = p_user_id;
  if p_role = 'city_admin' and p_city_id is not null then
    insert into city_admins(user_id, city_id) values (p_user_id, p_city_id) on conflict do nothing;
  elsif p_role <> 'city_admin' then
    delete from city_admins where user_id = p_user_id;
  end if;
  perform fn_log_audit(auth.uid(), 'super_admin', 'staff.role_changed', 'profile', p_user_id,
    jsonb_build_object('role', v_old), jsonb_build_object('role', p_role, 'city_id', p_city_id));
end;
$$;

create or replace function public.rpc_set_user_status(p_user_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not fn_is_super_admin() then raise exception 'Reserve a la direction'; end if;
  if p_status not in ('active','suspended') then raise exception 'Statut invalide'; end if;
  if p_user_id = auth.uid() then raise exception 'Impossible de suspendre son propre compte'; end if;
  update profiles set status = p_status where id = p_user_id;
  perform fn_log_audit(auth.uid(), 'super_admin', 'staff.status_changed', 'profile', p_user_id, null,
    jsonb_build_object('status', p_status));
end;
$$;

create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv staff_invitations%rowtype;
  v_role user_role := 'customer';
begin
  select * into v_inv from public.staff_invitations
    where email = new.email::citext and status = 'pending' limit 1;
  if found then
    v_role := v_inv.role;
  end if;

  insert into public.profiles (id, full_name, phone, email, role)
  values (
    new.id,
    nullif(new.raw_user_meta_data->>'full_name', ''),
    nullif(new.raw_user_meta_data->>'phone', ''),
    new.email::citext,
    v_role
  )
  on conflict (id) do nothing;

  if v_inv.id is not null then
    if v_inv.role = 'city_admin' and v_inv.city_id is not null then
      insert into public.city_admins(user_id, city_id) values (new.id, v_inv.city_id) on conflict do nothing;
    end if;
    update public.staff_invitations
      set status = 'accepted', accepted_at = now(), accepted_user_id = new.id
      where id = v_inv.id;
  end if;
  return new;
end;
$$;

revoke execute on function public.rpc_invite_staff(text, user_role, uuid) from public, anon;
revoke execute on function public.rpc_revoke_staff_invitation(uuid) from public, anon;
revoke execute on function public.rpc_set_user_role(uuid, user_role, uuid) from public, anon;
revoke execute on function public.rpc_set_user_status(uuid, text) from public, anon;
grant execute on function public.rpc_invite_staff(text, user_role, uuid) to authenticated;
grant execute on function public.rpc_revoke_staff_invitation(uuid) to authenticated;
grant execute on function public.rpc_set_user_role(uuid, user_role, uuid) to authenticated;
grant execute on function public.rpc_set_user_status(uuid, text) to authenticated;