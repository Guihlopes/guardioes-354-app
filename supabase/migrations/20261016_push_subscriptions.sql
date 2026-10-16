-- Guardiões da 354: inscrições para notificações push no celular
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  subscription jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;

drop policy if exists "Integrante gerencia suas inscrições push" on public.push_subscriptions;
create policy "Integrante gerencia suas inscrições push"
on public.push_subscriptions for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

grant select, insert, update, delete on public.push_subscriptions to authenticated;

-- Remove inscrições expiradas/inválidas manualmente quando necessário.
