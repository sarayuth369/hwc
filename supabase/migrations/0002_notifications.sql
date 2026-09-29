-- HWC notification inbox
--
-- Real, functional notification storage for the app's Notifications tab.
-- Delivery today is "open the app, the tab fetches your unread rows" --
-- genuinely real, not a push simulation. Push (FCM) can be added later as
-- a delivery mechanism for the *same* rows without changing this schema.
--
-- Run this once in the Supabase SQL Editor for the HWC project
-- (yqnzaapmznfeqdsevpyh). Idempotent: safe to run more than once.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null default 'general'
    check (category in ('general', 'reminder', 'insight', 'admin', 'system')),
  title text not null,
  body text not null,
  deep_link text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_id_created_at_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

-- Users can read and mark-read only their own rows. No INSERT/DELETE
-- policy for authenticated/anon at all -- creating a notification is a
-- privileged action, done only by the Worker's admin routes (service_role,
-- bypasses RLS) or by a future trusted server-side job (e.g. a reminder
-- cron). This is what "do not allow arbitrary users to send notifications"
-- means at the database layer, not just in application code.
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
  on public.notifications for select
  using (auth.uid() = user_id);

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- The UPDATE policy above is row-scoped, not column-scoped -- it would
-- otherwise let a user rewrite their own notification's title/body/
-- category, not just mark it read. This trigger closes that gap the same
-- way profiles.is_admin/status is protected (see 0001_admin_manager.sql):
-- only a service_role request (the Worker) may change anything other than
-- read_at.
create or replace function public.prevent_notification_content_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (new.title is distinct from old.title
      or new.body is distinct from old.body
      or new.category is distinct from old.category
      or new.deep_link is distinct from old.deep_link
      or new.user_id is distinct from old.user_id)
     and auth.role() <> 'service_role' then
    raise exception 'only read_at can be changed by the recipient';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_notification_content_edit on public.notifications;
create trigger trg_prevent_notification_content_edit
  before update on public.notifications
  for each row
  execute function public.prevent_notification_content_edit();
