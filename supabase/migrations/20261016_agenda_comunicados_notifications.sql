-- Guardiões da 354: público de agenda/comunicados e notificações
-- Execute no SQL Editor do projeto Supabase nlaywsguzsiwvexwnakp.

alter table public.club_events
  add column if not exists visible_to_groups text[] not null default array['all']::text[],
  add column if not exists notify_to_groups text[] not null default array['all']::text[],
  add column if not exists visible_to_emails text[] not null default array[]::text[],
  add column if not exists notify_to_emails text[] not null default array[]::text[];

alter table public.club_announcements
  add column if not exists visible_to_groups text[] not null default array['all']::text[],
  add column if not exists notify_to_groups text[] not null default array['all']::text[],
  add column if not exists visible_to_emails text[] not null default array[]::text[],
  add column if not exists notify_to_emails text[] not null default array[]::text[];

create table if not exists public.club_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null default '',
  source_type text not null check (source_type in ('event','announcement')),
  source_id uuid not null,
  created_at timestamptz not null default now(),
  read_at timestamptz null
);

create index if not exists club_notifications_recipient_unread_idx
  on public.club_notifications(recipient_id, created_at desc)
  where read_at is null;

alter table public.club_notifications enable row level security;
grant select, update on public.club_notifications to authenticated;

drop policy if exists "Membro vê próprias notificações" on public.club_notifications;
create policy "Membro vê próprias notificações"
on public.club_notifications for select to authenticated
using (recipient_id = auth.uid());

drop policy if exists "Membro marca próprias notificações como lidas" on public.club_notifications;
create policy "Membro marca próprias notificações como lidas"
on public.club_notifications for update to authenticated
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

create or replace function public.club_target_matches(
  p_user_id uuid,
  p_groups text[],
  p_emails text[]
) returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.member_profiles p
    join auth.users u on u.id = p.id
    where p.id = p_user_id
      and p.active = true
      and (
        coalesce(p_groups, array['all']::text[]) @> array['all']::text[]
        or (coalesce(p_groups, array[]::text[]) @> array['pilots']::text[] and p.rider_type = 'Piloto')
        or (coalesce(p_groups, array[]::text[]) @> array['pillion']::text[] and p.rider_type = 'Garupa')
        or (coalesce(p_groups, array[]::text[]) @> array['prospects']::text[] and p.member_status = 'Prospect')
      )
      or exists (
        select 1
        from public.member_profiles p2
        join auth.users u2 on u2.id = p2.id
        where p2.id = p_user_id and p2.active = true
          and lower(u2.email) = any(coalesce(p_emails, array[]::text[]))
      )
  );
$$;

create or replace function public.club_create_notifications()
returns trigger
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_type text;
  v_title text;
  v_body text;
  v_groups text[];
  v_emails text[];
  v_id uuid;
begin
  if tg_table_name = 'club_events' then
    if new.status <> 'published' then return new; end if;
    if tg_op = 'UPDATE' and old.status = 'published' then return new; end if;
    v_type := 'event';
    v_title := new.title;
    v_body := coalesce(new.description, '');
    v_groups := coalesce(new.notify_to_groups, array['all']::text[]);
    v_emails := coalesce(new.notify_to_emails, array[]::text[]);
    v_id := new.id;
  else
    v_type := 'announcement';
    v_title := new.title;
    v_body := coalesce(new.body, '');
    v_groups := coalesce(new.notify_to_groups, array['all']::text[]);
    v_emails := coalesce(new.notify_to_emails, array[]::text[]);
    v_id := new.id;
  end if;

  insert into public.club_notifications(recipient_id,title,body,source_type,source_id)
  select p.id, v_title, v_body, v_type, v_id
  from public.member_profiles p
  join auth.users u on u.id = p.id
  where p.active = true
    and p.id <> coalesce(new.created_by, p.id)
    and public.club_target_matches(p.id, v_groups, v_emails);

  return new;
end;
$$;

drop trigger if exists club_events_notify_on_publish on public.club_events;
create trigger club_events_notify_on_publish
after insert or update of status on public.club_events
for each row execute function public.club_create_notifications();

drop trigger if exists club_announcements_notify_on_insert on public.club_announcements;
create trigger club_announcements_notify_on_insert
after insert on public.club_announcements
for each row execute function public.club_create_notifications();
