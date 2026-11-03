-- Confirmação de leitura de comunicados e votações.
-- Cada integrante registra a própria abertura; somente gui.00sg@gmail.com pode consultar o relatório.

create table if not exists public.club_content_reads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_type text not null check (source_type in ('announcement','vote')),
  source_id uuid not null,
  read_at timestamptz not null default now(),
  unique (user_id, source_type, source_id)
);

create index if not exists club_content_reads_source_idx
  on public.club_content_reads (source_type, source_id, read_at desc);

alter table public.club_content_reads enable row level security;
revoke all on public.club_content_reads from anon;
grant select, insert, update on public.club_content_reads to authenticated;

drop policy if exists "Integrante registra a própria leitura" on public.club_content_reads;
create policy "Integrante registra a própria leitura"
on public.club_content_reads for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists "Integrante atualiza a própria leitura" on public.club_content_reads;
create policy "Integrante atualiza a própria leitura"
on public.club_content_reads for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Integrante consulta as próprias leituras" on public.club_content_reads;
create policy "Integrante consulta as próprias leituras"
on public.club_content_reads for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Gui consulta todas as leituras" on public.club_content_reads;
create policy "Gui consulta todas as leituras"
on public.club_content_reads for select to authenticated
using (lower(coalesce(auth.jwt()->>'email','')) = 'gui.00sg@gmail.com');

notify pgrst, 'reload schema';
