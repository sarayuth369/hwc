-- Per-feature AI model routing configuration.
--
-- Today every AI call is hardcoded to one provider/model inside
-- bkknex-worker (Workers AI, picked via the `AI_PROVIDER` wrangler var).
-- This table lets the Admin Manager change which provider+model backs each
-- real Worker route (chat, insight, image_analyze) WITHOUT a code deploy --
-- the Worker reads this table per request (falling back to its existing
-- hardcoded defaults if a row is missing or the table itself doesn't
-- exist yet, so nothing breaks before this migration is run).
--
-- `feature` values match the Worker's own route names (see
-- `ai_usage_events.route` in 0003) rather than inventing a separate naming
-- scheme: 'chat' (AI Talk + the wellness Consult flow -- both are the same
-- `/api/ai/chat` endpoint today, there is no separate Consult backend
-- route), 'insight' (Today's Insight card), 'image_analyze' (Food Scanner
-- + Health Report Reader -- both the same `/api/ai/image/analyze` endpoint,
-- distinguished only by a `purpose` field, not separate routes).
--
-- Run this once in the Supabase SQL Editor for the HWC project. Idempotent.

create table if not exists public.model_routing_config (
  feature text primary key
    check (feature in ('chat', 'insight', 'image_analyze')),
  provider text not null
    check (provider in ('workers-ai', 'zai', 'gemini')),
  model text not null,
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

alter table public.model_routing_config enable row level security;
-- No policies: only the Worker's service-role admin routes ever read or
-- write this table (through `requireAdmin`'s own app-level admin check),
-- mirroring `ai_usage_events`'s access model in 0003.

create or replace function public.touch_model_routing_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_touch_model_routing_updated_at on public.model_routing_config;
create trigger trg_touch_model_routing_updated_at
  before update on public.model_routing_config
  for each row
  execute function public.touch_model_routing_updated_at();

-- Seed with today's real hardcoded defaults, so the Admin page shows the
-- actual current state from the moment this migration runs rather than an
-- empty table that looks unconfigured.
insert into public.model_routing_config (feature, provider, model, enabled)
values
  ('chat', 'workers-ai', '@cf/meta/llama-3.3-70b-instruct-fp8-fast', true),
  ('insight', 'workers-ai', '@cf/meta/llama-3.3-70b-instruct-fp8-fast', true),
  ('image_analyze', 'workers-ai', '@cf/meta/llama-3.2-11b-vision-instruct', true)
on conflict (feature) do nothing;
