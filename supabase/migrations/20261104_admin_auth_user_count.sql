-- Contagem segura de todas as contas cadastradas no Supabase Auth.
-- A função só pode ser executada pelo administrador do aplicativo.

create or replace function public.club_admin_user_count()
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'gui.00sg@gmail.com' then
    raise exception 'Acesso não autorizado';
  end if;

  return (select count(*) from auth.users);
end;
$$;

revoke all on function public.club_admin_user_count() from public, anon;
grant execute on function public.club_admin_user_count() to authenticated;

