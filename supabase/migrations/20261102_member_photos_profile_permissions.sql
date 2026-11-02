-- Correção de fotos e atualização dos dados pessoais dos integrantes.
-- Execute no Supabase SQL Editor. Pode ser executado novamente com segurança.

-- Bucket público exclusivo para fotos de perfil (não reutiliza o bucket privado de documentos).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('member-photos', 'member-photos', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public = true,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg','image/png','image/webp'];

-- Fotos são públicas para visualização no diretório; cada integrante só envia,
-- substitui ou remove arquivos dentro da própria pasta (UUID do usuário).
drop policy if exists "Member photos are publicly readable" on storage.objects;
create policy "Member photos are publicly readable"
on storage.objects for select
using (bucket_id = 'member-photos');

drop policy if exists "Members upload own profile photos" on storage.objects;
create policy "Members upload own profile photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'member-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Members update own profile photos" on storage.objects;
create policy "Members update own profile photos"
on storage.objects for update to authenticated
using (
  bucket_id = 'member-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'member-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Members delete own profile photos" on storage.objects;
create policy "Members delete own profile photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'member-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Permite que o integrante atualize os próprios dados de contato e vínculo.
drop policy if exists "Members update own profile" on public.member_profiles;
create policy "Members update own profile"
on public.member_profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

grant update (phone, motorcycle, pilot_id, photo_url)
on public.member_profiles to authenticated;

-- O diretório do clube precisa ler esses campos para mostrar telefone, moto e foto.
grant select (id, full_name, club_position, member_status, rider_type, phone, motorcycle, pilot_id, active, photo_url)
on public.member_profiles to authenticated;

notify pgrst, 'reload schema';
