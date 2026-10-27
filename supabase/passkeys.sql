-- Guardiões da 354 — base segura para credenciais Passkeys.
-- Execute no SQL Editor do projeto Supabase do motoclube.
-- As chaves privadas ficam no autenticador do aparelho; o banco guarda somente a chave pública.
create table if not exists public.member_passkeys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  credential_id text not null unique,
  public_key text not null,
  counter bigint not null default 0,
  transports text[] not null default '{}',
  device_name text,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

alter table public.member_passkeys enable row level security;
revoke all on public.member_passkeys from anon, authenticated;
grant select, insert, update, delete on public.member_passkeys to service_role;

create table if not exists public.passkey_challenges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  challenge text not null,
  purpose text not null check (purpose in ('registration','authentication')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '5 minutes')
);
alter table public.passkey_challenges enable row level security;
revoke all on public.passkey_challenges from anon, authenticated;
grant select, insert, update, delete on public.passkey_challenges to service_role;

create index if not exists member_passkeys_user_id_idx on public.member_passkeys(user_id);
create index if not exists passkey_challenges_expiry_idx on public.passkey_challenges(expires_at);

-- Limpa desafios expirados; pode ser chamado pelas Edge Functions.
create or replace function public.cleanup_expired_passkey_challenges()
returns void language sql security definer set search_path = public
as $$ delete from public.passkey_challenges where expires_at < now(); $$;
revoke all on function public.cleanup_expired_passkey_challenges() from public, anon, authenticated;
grant execute on function public.cleanup_expired_passkey_challenges() to service_role;
