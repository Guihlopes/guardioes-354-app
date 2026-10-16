-- Guardiões da 354: notificar integrantes sobre novas votações
-- Execute no SQL Editor do projeto Supabase do aplicativo.

-- Permite que a tabela de notificações registre avisos de votação.
alter table public.club_notifications
  drop constraint if exists club_notifications_source_type_check;

alter table public.club_notifications
  add constraint club_notifications_source_type_check
  check (source_type in ('event', 'announcement', 'vote'));

-- Estende a função usada pelas notificações de agenda/comunicados para tratar votações.
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
  elsif tg_table_name = 'club_announcements' then
    v_type := 'announcement';
    v_title := new.title;
    v_body := coalesce(new.body, '');
    v_groups := coalesce(new.notify_to_groups, array['all']::text[]);
    v_emails := coalesce(new.notify_to_emails, array[]::text[]);
    v_id := new.id;
  else
    v_type := 'vote';
    v_title := 'Nova votação: ' || new.title;
    v_body := coalesce(new.description, 'Uma nova votação está disponível no aplicativo.');
    v_groups := coalesce(new.visible_to_groups, array['all']::text[]);
    v_emails := coalesce(new.visible_to_emails, array[]::text[]);
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

drop trigger if exists club_votes_notify_on_insert on public.club_votes;
create trigger club_votes_notify_on_insert
after insert on public.club_votes
for each row execute function public.club_create_notifications();
