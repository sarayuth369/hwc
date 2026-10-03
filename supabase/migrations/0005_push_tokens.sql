-- HWC push (FCM) device tokens
--
-- One row per device FCM token. Push is only a *delivery* channel for the
-- existing in-app inbox (`public.notifications`, 0002) -- this migration does
-- not create a second inbox.
--
-- Run once in the Supabase SQL Editor for the HWC project. Idempotent.
-- Prerequisite: 0002_notifications.sql (independent, but both are needed
-- for the full push + inbox flow).
--
-- Security model
-- --------------
-- * A token is a bearer capability for pushing to a device, so the table is
--   never writable directly by clients: NO insert/update/delete policy
--   exists for authenticated/anon. Clients can only SELECT their own rows.
-- * Writes go through two SECURITY DEFINER functions that always act as
--   auth.uid() -- a caller can only register/deactivate tokens for
--   themselves, and cannot touch another user's rows.
-- * The Worker (service_role, bypasses RLS) reads active tokens to send
--   pushes and marks tokens inactive when FCM reports them invalid.

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null,
  platform text not null default 'android'
    check (platform in ('android', 'ios', 'web')),
  -- App-generated random install id (NOT a hardware identifier). Lets one
  -- device keep a single active token across FCM token refreshes.
  device_id text,
  app_version text,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- An FCM token identifies exactly one app install, so it can belong to at
  -- most one user at a time (see register_push_token for hand-over).
  constraint push_tokens_fcm_token_key unique (fcm_token),
  constraint push_tokens_token_length check (char_length(fcm_token) between 20 and 4096)
);

create index if not exists push_tokens_user_active_idx
  on public.push_tokens (user_id) where is_active;
create index if not exists push_tokens_user_device_idx
  on public.push_tokens (user_id, device_id);

alter table public.push_tokens enable row level security;

drop policy if exists push_tokens_select_own on public.push_tokens;
create policy push_tokens_select_own
  on public.push_tokens for select
  using (auth.uid() = user_id);
-- Deliberately no INSERT / UPDATE / DELETE policies. See header.

create or replace function public.touch_push_tokens_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_touch_push_tokens_updated_at on public.push_tokens;
create trigger trg_touch_push_tokens_updated_at
  before update on public.push_tokens
  for each row
  execute function public.touch_push_tokens_updated_at();

-- Registers (or refreshes) the calling user's device token.
--  * Duplicate-token protection: the same token upserts one row.
--  * Hand-over: if this exact token was previously registered to a
--    *different* user (shared/handed-down device), ownership moves to the
--    caller so the previous user stops receiving this device's pushes.
--  * One active token per (user, device): when a device's token rotates,
--    older tokens for the same user+device are deactivated.
create or replace function public.register_push_token(
  p_token text,
  p_platform text default 'android',
  p_device_id text default null,
  p_app_version text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_token is null or char_length(p_token) < 20 or char_length(p_token) > 4096 then
    raise exception 'invalid token' using errcode = '22023';
  end if;
  if p_platform not in ('android', 'ios', 'web') then
    raise exception 'invalid platform' using errcode = '22023';
  end if;

  insert into public.push_tokens
    (user_id, fcm_token, platform, device_id, app_version, is_active, last_seen_at)
  values
    (v_user, p_token, p_platform, p_device_id, p_app_version, true, now())
  on conflict (fcm_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        device_id = excluded.device_id,
        app_version = excluded.app_version,
        is_active = true,
        last_seen_at = now();

  if p_device_id is not null then
    update public.push_tokens
      set is_active = false
      where user_id = v_user
        and device_id = p_device_id
        and fcm_token <> p_token
        and is_active;
  end if;
end;
$$;

-- Deactivates the calling user's own row for this token (sign-out). A
-- no-op for a token the caller does not own.
create or replace function public.deactivate_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  update public.push_tokens
    set is_active = false
    where fcm_token = p_token
      and user_id = auth.uid();
end;
$$;

revoke all on function public.register_push_token(text, text, text, text) from public;
revoke all on function public.deactivate_push_token(text) from public;
grant execute on function public.register_push_token(text, text, text, text) to authenticated;
grant execute on function public.deactivate_push_token(text) to authenticated;
