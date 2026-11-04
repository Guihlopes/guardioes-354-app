-- Histórico privado dos integrantes: acesso exclusivo ao desenvolvedor e ao Presidente.
create table if not exists public.club_member_history (
  id uuid primary key default gen_random_uuid(),
  person_name text not null,
  note text not null check (length(trim(note)) > 0),
  created_by uuid references auth.users(id) on delete set null,
  author_email text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists club_member_history_person_created_idx
  on public.club_member_history (person_name, created_at desc);

alter table public.club_member_history enable row level security;
revoke all on public.club_member_history from anon, authenticated;
grant select, insert on public.club_member_history to authenticated;

drop policy if exists "Developer and president manage member history" on public.club_member_history;
create policy "Developer and president manage member history"
on public.club_member_history
for all
to authenticated
using (
  lower(coalesce(auth.jwt()->>'email','')) = 'gui.00sg@gmail.com'
  or exists (
    select 1
    from public.member_profiles mp
    where mp.id = auth.uid()
      and mp.active = true
      and lower(coalesce(mp.club_position,'')) like '%presidente%'
  )
)
with check (
  lower(coalesce(auth.jwt()->>'email','')) = 'gui.00sg@gmail.com'
  or exists (
    select 1
    from public.member_profiles mp
    where mp.id = auth.uid()
      and mp.active = true
      and lower(coalesce(mp.club_position,'')) like '%presidente%'
  )
);

notify pgrst, 'reload schema';
