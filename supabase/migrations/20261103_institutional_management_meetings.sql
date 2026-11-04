-- Módulos experimentais de gestão institucional, normas e reuniões.
-- Escrita e leitura restritas ao usuário Gui durante a fase de testes.

create table if not exists public.club_governance_documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null default 'Norma',
  description text not null default '',
  file_url text,
  version_label text not null default '1.0',
  status text not null default 'Vigente' check (status in ('Vigente','Em revisão','Arquivado')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.club_meetings (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  meeting_date timestamptz not null,
  location text not null default '',
  agenda text not null default '',
  minutes text not null default '',
  decisions text not null default '',
  status text not null default 'Agendada' check (status in ('Agendada','Realizada','Cancelada')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.club_governance_documents enable row level security;
alter table public.club_meetings enable row level security;

revoke all on public.club_governance_documents from anon, authenticated;
revoke all on public.club_meetings from anon, authenticated;
grant select, insert, update, delete on public.club_governance_documents to authenticated;
grant select, insert, update, delete on public.club_meetings to authenticated;

drop policy if exists "Gui manages governance documents" on public.club_governance_documents;
create policy "Gui manages governance documents"
on public.club_governance_documents for all to authenticated
using (lower(coalesce(auth.jwt()->>'email','')) = 'gui.00sg@gmail.com')
with check (lower(coalesce(auth.jwt()->>'email','')) = 'gui.00sg@gmail.com');

drop policy if exists "Gui manages club meetings" on public.club_meetings;
create policy "Gui manages club meetings"
on public.club_meetings for all to authenticated
using (lower(coalesce(auth.jwt()->>'email','')) = 'gui.00sg@gmail.com')
with check (lower(coalesce(auth.jwt()->>'email','')) = 'gui.00sg@gmail.com');

create index if not exists club_meetings_date_idx on public.club_meetings(meeting_date desc);
create index if not exists club_governance_documents_category_idx on public.club_governance_documents(category,status);

notify pgrst, 'reload schema';
