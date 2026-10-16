-- Guardiões da 354: votação identificada, públicos específicos e resultados parciais
-- Execute no SQL Editor do projeto Supabase do aplicativo.

alter table public.club_votes
  add column if not exists vote_type text not null default 'simple',
  add column if not exists visible_to_groups text[] not null default array['all']::text[],
  add column if not exists visible_to_emails text[] not null default array[]::text[];

alter table public.club_votes
  drop constraint if exists club_votes_vote_type_check;
alter table public.club_votes
  add constraint club_votes_vote_type_check
  check (vote_type in ('simple','approval'));

-- A coluna options permanece compatível com as votações já existentes.
-- Para aprovação, o aplicativo salva as opções Sim, Não e Abstenção.

alter table public.club_vote_ballots
  add column if not exists voter_name text,
  add column if not exists created_at timestamptz not null default now();

-- Evita votos duplicados por integrante na mesma votação.
create unique index if not exists club_vote_ballots_one_vote_per_member
  on public.club_vote_ballots(vote_id,user_id);

alter table public.club_votes enable row level security;
alter table public.club_vote_ballots enable row level security;
grant select, insert on public.club_votes to authenticated;
grant select, insert on public.club_vote_ballots to authenticated;

-- O integrante só pode consultar votações dirigidas ao seu grupo ou e-mail;
-- diretoria/fundadores mantêm acesso para administrar.
drop policy if exists "Votação visível conforme público" on public.club_votes;
create policy "Votação visível conforme público"
on public.club_votes as restrictive for select to authenticated
using (
  public.club_target_matches(auth.uid(), visible_to_groups, visible_to_emails)
  or exists (
    select 1 from public.member_profiles p
    where p.id=auth.uid() and p.active=true
      and (p.role='admin' or p.club_position in
      ('Fundador','Fundador/Vice-Presidente','Presidente','Vice-Presidente','Diretor Geral','Diretor Social'))
  )
);

drop policy if exists "Integrante pode registrar próprio voto" on public.club_vote_ballots;
create policy "Integrante pode registrar próprio voto"
on public.club_vote_ballots for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.club_votes v
    where v.id = vote_id
      and (v.closes_at is null or v.closes_at > now())
      and public.club_target_matches(auth.uid(), v.visible_to_groups, v.visible_to_emails)
  )
);

drop policy if exists "Integrante vê próprio voto" on public.club_vote_ballots;
create policy "Integrante vê próprio voto"
on public.club_vote_ballots for select to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.member_profiles p
    where p.id=auth.uid() and p.active=true
      and (p.role='admin' or p.club_position in
      ('Fundador','Fundador/Vice-Presidente','Presidente','Vice-Presidente','Diretor Geral','Diretor Social'))
  )
);

-- A votação é identificada: a diretoria pode consultar eleitor e opção.

-- Inclui o grupo Diretoria e fundadores no resolvedor de público.
create or replace function public.club_target_matches(
  p_user_id uuid,
  p_groups text[],
  p_emails text[]
) returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select
    exists (
      select 1 from public.member_profiles p
      where p.id = p_user_id and p.active = true
        and (
          coalesce(p_groups, array['all']::text[]) @> array['all']::text[]
          or (coalesce(p_groups, array[]::text[]) @> array['pilots']::text[] and p.rider_type = 'Piloto')
          or (coalesce(p_groups, array[]::text[]) @> array['pillion']::text[] and p.rider_type = 'Garupa')
          or (coalesce(p_groups, array[]::text[]) @> array['prospects']::text[] and p.member_status = 'Prospect')
          or (coalesce(p_groups, array[]::text[]) @> array['board']::text[] and
            (p.role='admin' or p.club_position in ('Fundador','Fundador/Vice-Presidente','Presidente','Vice-Presidente','Diretor Geral','Diretor Social')))
        )
    )
    or exists (
      select 1 from public.member_profiles p
      join auth.users u on u.id = p.id
      where p.id = p_user_id and p.active = true
        and lower(u.email) = any(coalesce(p_emails, array[]::text[]))
    );
$$;

-- Permite que cada integrante veja somente totais agregados; nomes/opções individuais
-- permanecem restritos à diretoria pela política da tabela de votos.
create or replace function public.get_club_vote_counts(vote_ids uuid[])
returns table(vote_id uuid, option_selected text, vote_count bigint)
language sql stable security definer
set search_path = public
as $$
  select b.vote_id, b.option_selected, count(*)::bigint
  from public.club_vote_ballots b
  join public.club_votes v on v.id = b.vote_id
  where b.vote_id = any(vote_ids)
    and public.club_target_matches(auth.uid(), v.visible_to_groups, v.visible_to_emails)
  group by b.vote_id, b.option_selected;
$$;

revoke all on function public.get_club_vote_counts(uuid[]) from public;
grant execute on function public.get_club_vote_counts(uuid[]) to authenticated;
