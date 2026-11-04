-- Histórico privado de acompanhamento de prospects e garupas.
create table if not exists public.club_prospect_notes (
  id uuid primary key default gen_random_uuid(),
  person_name text not null,
  comment text not null check (length(trim(comment)) > 0),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists club_prospect_notes_person_created_idx
  on public.club_prospect_notes (person_name, created_at desc);
alter table public.club_prospect_notes enable row level security;
revoke all on public.club_prospect_notes from anon, authenticated;
grant select, insert, update, delete on public.club_prospect_notes to authenticated;
drop policy if exists "Gui manages prospect notes" on public.club_prospect_notes;
create policy "Gui manages prospect notes"
on public.club_prospect_notes for all to authenticated
using (lower(coalesce(auth.jwt()->>'email','')) = 'gui.00sg@gmail.com')
with check (lower(coalesce(auth.jwt()->>'email','')) = 'gui.00sg@gmail.com');
notify pgrst, 'reload schema';
