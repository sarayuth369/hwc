-- HWC Admin Manager schema
--
-- Adds the minimum columns/tables the admin backend needs, plus the
-- database-level controls that keep "is this user an admin" a fact only a
-- privileged service can set -- never something a client request can grant
-- itself, no matter what the request claims.
--
-- Run this once in the Supabase SQL Editor for the HWC project
-- (yqnzaapmznfeqdsevpyh). Idempotent: safe to run more than once.

-- 1. Admin flag + display status on the existing profiles table.
-- `status` is a display/UX mirror of the real enforcement mechanism
-- (Supabase Auth's own ban_duration, set via the Admin API -- see
-- src/admin/adminUsers.ts in the Worker). It is NOT itself what blocks
-- sign-in; it exists so the admin UI can show/filter/sort by status without
-- an extra GoTrue Admin API round trip per row.
alter table public.profiles
  add column if not exists is_admin boolean not null default false;

alter table public.profiles
  add column if not exists status text not null default 'active';

alter table public.profiles
  drop constraint if exists profiles_status_check;

alter table public.profiles
  add constraint profiles_status_check
  check (status in ('active', 'suspended', 'deleted'));

-- 2. Prevent privilege self-escalation.
-- profiles' existing RLS UPDATE policy (created before this migration,
-- typically "user_id = auth.uid()") is row-scoped, not column-scoped -- it
-- does not by itself stop a signed-in user from PATCHing their own
-- is_admin/status. This trigger closes that gap: only a request executing
-- as the `service_role` (the Worker's admin routes, never the browser) may
-- change these two columns, regardless of which RLS UPDATE policy exists on
-- this table now or is added later.
create or replace function public.prevent_privileged_profile_self_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (new.is_admin is distinct from old.is_admin
      or new.status is distinct from old.status)
     and auth.role() <> 'service_role' then
    raise exception 'is_admin and status can only be changed by a privileged service';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_privileged_profile_self_edit on public.profiles;
create trigger trg_prevent_privileged_profile_self_edit
  before update on public.profiles
  for each row
  execute function public.prevent_privileged_profile_self_edit();

-- 3. Audit log for privileged admin actions.
-- RLS is enabled with NO policies defined, which denies all access to
-- every client role (anon, authenticated) by default -- the only way to
-- read or write this table is the service_role key, which never reaches
-- the browser (it lives only as a Cloudflare Worker secret). Defense in
-- depth alongside the Worker-side admin check: even if the Worker's own
-- authorization check had a bug, the database itself still refuses any
-- non-service-role client.
create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references auth.users(id) on delete restrict,
  action text not null,
  target_type text not null,
  target_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_created_at_idx
  on public.admin_audit_log (created_at desc);

create index if not exists admin_audit_log_admin_user_id_idx
  on public.admin_audit_log (admin_user_id);

alter table public.admin_audit_log enable row level security;
-- Deliberately no policies: RLS with zero policies = deny-all for anon and
-- authenticated. Only service_role (used exclusively by the Worker's admin
-- routes) can read or write this table.

-- 4. Grant yourself the first admin.
-- This migration cannot know which auth user M wants as the first admin,
-- so it does not set is_admin for anyone. After creating the admin's login
-- (Supabase Dashboard -> Authentication -> Add user, or having them sign up
-- normally and confirming their email), run this once, replacing the
-- email:
--
--   update public.profiles
--   set is_admin = true
--   where user_id = (select id from auth.users where email = 'admin@example.com');
--
-- This UPDATE runs as the SQL Editor's own elevated role, which bypasses
-- the trigger above the same way service_role does -- it is the one
-- legitimate way to grant the very first admin before any admin session
-- exists to do it through the app.
