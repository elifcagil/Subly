-- Recap cadence anchor: when the device first registered (not personal data).
-- Mirrored best-effort from the app's Keychain copy.
alter table public.devices
  add column if not exists registered_at timestamptz;
