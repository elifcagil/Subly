-- Remote switches the app reads at launch (no new build needed to flip them).
-- Public, read-only reference data like catalog_prices; edit values from the
-- dashboard: Table Editor → app_config → value.
--
--   whats_new_enabled  true/false  Show the What's New story for the running
--                                  app version (each user still sees it once;
--                                  the app remembers the last seen version).

create table if not exists public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

drop policy if exists "App config is public" on public.app_config;
create policy "App config is public"
  on public.app_config
  for select
  to anon, authenticated
  using (true);

insert into public.app_config (key, value) values
  ('whats_new_enabled', 'true'::jsonb)
on conflict (key) do nothing;
