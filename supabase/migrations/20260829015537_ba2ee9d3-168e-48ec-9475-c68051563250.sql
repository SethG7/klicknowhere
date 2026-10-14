GRANT EXECUTE ON FUNCTION public.fn_is_city_admin_of(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_is_super_admin() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_is_restaurant_member(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_is_restaurant_owner(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_current_role() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_current_driver_id() TO anon, authenticated;