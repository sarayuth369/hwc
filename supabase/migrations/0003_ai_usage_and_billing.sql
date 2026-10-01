-- HWC AI usage telemetry + billing/subscription state model
--
-- Two independent, real tables added together because both back the same
-- one-shot's Admin Manager work:
--
-- 1. ai_usage_events: one row per AI call (chat/insight/image analyze),
--    written by the Worker on every request (success AND failure) --
--    previously nothing was logged anywhere but the Worker's own ephemeral
--    console output, so the Admin Manager's "AI / Usage" page had no real
--    data to show at all.
--
-- 2. subscriptions: a real schema for subscription/billing state, ready
--    for a real payment provider (Google Play Billing) to write into via
--    webhook once M configures one. Every row today would honestly show
--    'free'/'none' for every user, because no provider is connected yet --
--    this is the "production-ready, waiting only on provider connection"
--    state the one-shot asked for, not a simulation.
--
-- Run this once in the Supabase SQL Editor for the HWC project
-- (yqnzaapmznfeqdsevpyh). Idempotent: safe to run more than once.

create table if not exists public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  route text not null
    check (route in ('chat', 'insight', 'image_analyze', 'voice_transcribe', 'voice_synthesize')),
  provider text not null,
  model text,
  success boolean not null,
  error_code text,
  latency_ms integer,
  created_at timestamptz not null default now()
);

create index if not exists ai_usage_events_created_at_idx
  on public.ai_usage_events (created_at desc);
create index if not exists ai_usage_events_route_created_at_idx
  on public.ai_usage_events (route, created_at desc);
create index if not exists ai_usage_events_user_id_idx
  on public.ai_usage_events (user_id);

alter table public.ai_usage_events enable row level security;
-- No policies: every write is the Worker inserting with its service-role
-- key (bypasses RLS), and the only reader is the Worker's admin routes
-- (also service-role). No app screen shows a user their own usage today,
-- so there is deliberately no user-facing select policy yet.

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tier text not null default 'free' check (tier in ('free', 'premium')),
  status text not null default 'none'
    check (status in ('none', 'active', 'pending_provider', 'cancelled', 'expired')),
  provider text not null default 'none'
    check (provider in ('none', 'google_play')),
  external_customer_id text,
  external_subscription_id text,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create index if not exists subscriptions_status_idx on public.subscriptions (status);

alter table public.subscriptions enable row level security;

-- Forward-compatible: once a real provider is wired up, the app can show a
-- user their own real subscription row directly. Only the Worker
-- (service-role) can ever write one.
drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own
  on public.subscriptions for select
  using (auth.uid() = user_id);

create or replace function public.touch_subscriptions_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_touch_subscriptions_updated_at on public.subscriptions;
create trigger trg_touch_subscriptions_updated_at
  before update on public.subscriptions
  for each row
  execute function public.touch_subscriptions_updated_at();
