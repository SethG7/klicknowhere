do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.sig);
  end loop;
end $$;

grant execute on function public.fn_current_role() to authenticated;
grant execute on function public.fn_is_super_admin() to authenticated;
grant execute on function public.fn_is_city_admin_of(uuid) to authenticated;
grant execute on function public.fn_is_restaurant_member(uuid) to anon, authenticated;
grant execute on function public.fn_is_restaurant_owner(uuid) to authenticated;
grant execute on function public.fn_current_driver_id() to authenticated;

grant execute on function public.rpc_create_order(uuid, text, text, text, text, text, uuid, uuid, payment_method, text, text, text, jsonb) to anon, authenticated;
grant execute on function public.rpc_track_guest_order(text, text) to anon, authenticated;
grant execute on function public.rpc_update_order_status(uuid, order_status, uuid, text) to authenticated;
grant execute on function public.rpc_assign_driver(uuid, uuid) to authenticated;
grant execute on function public.rpc_release_driver(uuid, uuid) to authenticated;
grant execute on function public.rpc_confirm_cash_payment(uuid, uuid) to authenticated;
grant execute on function public.rpc_approve_restaurant_application(uuid, text) to authenticated;
grant execute on function public.rpc_approve_driver_application(uuid) to authenticated;
grant execute on function public.rpc_reject_application(text, uuid, text) to authenticated;