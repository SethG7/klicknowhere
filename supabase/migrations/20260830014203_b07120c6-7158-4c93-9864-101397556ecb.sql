create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, email, role)
  values (
    new.id,
    nullif(new.raw_user_meta_data->>'full_name', ''),
    nullif(new.raw_user_meta_data->>'phone', ''),
    new.email::citext,
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.fn_handle_new_user();

insert into public.profiles (id, full_name, phone, email, role)
select u.id,
       nullif(u.raw_user_meta_data->>'full_name', ''),
       nullif(u.raw_user_meta_data->>'phone', ''),
       u.email::citext,
       'customer'
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;