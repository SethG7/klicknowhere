-- KLICK LOT 10 prerequisite: storage for restaurant logos, covers and dish photos.
-- Object path convention: <restaurant-uuid>/<kind>/<filename>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('klick-restaurant-media', 'klick-restaurant-media', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "klick restaurant media public read" on storage.objects for select to anon, authenticated
using (bucket_id = 'klick-restaurant-media');

create policy "klick restaurant media team insert" on storage.objects for insert to authenticated
with check (
  bucket_id = 'klick-restaurant-media'
  and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and public.fn_is_restaurant_member(((storage.foldername(name))[1])::uuid)
  and (storage.foldername(name))[2] in ('logo','cover','dishes')
);

create policy "klick restaurant media team update" on storage.objects for update to authenticated
using (bucket_id = 'klick-restaurant-media' and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and public.fn_is_restaurant_member(((storage.foldername(name))[1])::uuid))
with check (bucket_id = 'klick-restaurant-media' and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and public.fn_is_restaurant_member(((storage.foldername(name))[1])::uuid) and (storage.foldername(name))[2] in ('logo','cover','dishes'));

create policy "klick restaurant media team delete" on storage.objects for delete to authenticated
using (bucket_id = 'klick-restaurant-media' and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and public.fn_is_restaurant_member(((storage.foldername(name))[1])::uuid));
