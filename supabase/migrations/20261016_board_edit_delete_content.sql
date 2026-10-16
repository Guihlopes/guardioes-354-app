-- Guardiões da 354: permissões para diretoria editar/excluir agenda, comunicados e votações
-- Execute no SQL Editor do projeto Supabase do aplicativo.

create or replace function public.club_is_board_member(p_user_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.member_profiles p
    where p.id = p_user_id and p.active = true
      and (
        p.role = 'admin'
        or p.club_position in (
          'Fundador','Fundador/Vice-Presidente','Presidente',
          'Vice-Presidente','Diretor Geral','Diretor Social'
        )
      )
  );
$$;

grant execute on function public.club_is_board_member(uuid) to authenticated;

-- Agenda
drop policy if exists "Diretoria edita atividades da agenda" on public.club_events;
create policy "Diretoria edita atividades da agenda"
on public.club_events for update to authenticated
using (public.club_is_board_member(auth.uid()))
with check (public.club_is_board_member(auth.uid()));

drop policy if exists "Diretoria exclui atividades da agenda" on public.club_events;
create policy "Diretoria exclui atividades da agenda"
on public.club_events for delete to authenticated
using (public.club_is_board_member(auth.uid()));

-- Comunicados
drop policy if exists "Diretoria edita comunicados" on public.club_announcements;
create policy "Diretoria edita comunicados"
on public.club_announcements for update to authenticated
using (public.club_is_board_member(auth.uid()))
with check (public.club_is_board_member(auth.uid()));

drop policy if exists "Diretoria exclui comunicados" on public.club_announcements;
create policy "Diretoria exclui comunicados"
on public.club_announcements for delete to authenticated
using (public.club_is_board_member(auth.uid()));

-- Votações e votos vinculados
drop policy if exists "Diretoria edita votações" on public.club_votes;
create policy "Diretoria edita votações"
on public.club_votes for update to authenticated
using (public.club_is_board_member(auth.uid()))
with check (public.club_is_board_member(auth.uid()));

drop policy if exists "Diretoria exclui votações" on public.club_votes;
create policy "Diretoria exclui votações"
on public.club_votes for delete to authenticated
using (public.club_is_board_member(auth.uid()));

drop policy if exists "Diretoria exclui registros de votação" on public.club_vote_ballots;
create policy "Diretoria exclui registros de votação"
on public.club_vote_ballots for delete to authenticated
using (public.club_is_board_member(auth.uid()));

grant update, delete on public.club_events to authenticated;
grant update, delete on public.club_announcements to authenticated;
grant update, delete on public.club_votes to authenticated;
grant delete on public.club_vote_ballots to authenticated;
