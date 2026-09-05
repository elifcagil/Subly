-- Current starting prices for the Add-Subscription catalog templates.
-- The app fetches this table once per launch and caches it locally
-- (SupabaseCatalogPriceService); rows here override the prices bundled in
-- CatalogEntry.defaults, matched by name (case-insensitive).

create table if not exists public.catalog_prices (
  name          text primary key,
  amount        numeric(10, 2) not null check (amount >= 0),
  currency_code text not null default 'USD',
  billing_cycle text not null default 'monthly'
                check (billing_cycle in ('weekly', 'monthly', 'quarterly', 'yearly', 'custom')),
  updated_at    timestamptz not null default now()
);

alter table public.catalog_prices enable row level security;

-- Public, read-only reference data: readable before the anonymous sign-in
-- completes (the price refresh fires at launch) and never writable from the
-- app — edit rows from the dashboard or a migration.
drop policy if exists "Catalog prices are public" on public.catalog_prices;
create policy "Catalog prices are public"
  on public.catalog_prices
  for select
  to anon, authenticated
  using (true);

insert into public.catalog_prices (name, amount, currency_code, billing_cycle) values
  ('Netflix',            15.99, 'USD', 'monthly'),
  ('Spotify',            10.99, 'USD', 'monthly'),
  ('Apple Music',        10.99, 'USD', 'monthly'),
  ('YouTube Premium',    13.99, 'USD', 'monthly'),
  ('Disney+',            10.99, 'USD', 'monthly'),
  ('Amazon Prime',       14.99, 'USD', 'monthly'),
  ('iCloud+',             2.99, 'USD', 'monthly'),
  ('Apple One',          19.95, 'USD', 'monthly'),
  ('ChatGPT Plus',       20.00, 'USD', 'monthly'),
  ('Claude Pro',         20.00, 'USD', 'monthly'),
  ('LinkedIn Premium',   29.99, 'USD', 'monthly'),
  ('Notion',             10.00, 'USD', 'monthly'),
  ('GitHub Copilot',     10.00, 'USD', 'monthly'),
  ('Dropbox',            11.99, 'USD', 'monthly'),
  ('Google One',          1.99, 'USD', 'monthly'),
  ('Strava',             11.99, 'USD', 'monthly'),
  ('Peloton',            12.99, 'USD', 'monthly'),
  ('Calm',               14.99, 'USD', 'monthly'),
  ('The New York Times', 17.00, 'USD', 'monthly'),
  ('Medium',              5.00, 'USD', 'monthly')
on conflict (name) do update
  set amount = excluded.amount,
      currency_code = excluded.currency_code,
      billing_cycle = excluded.billing_cycle,
      updated_at = now();
