-- Subly: bekleyen üç migration, tek seferde çalıştırılabilir (idempotent).

-- >>> 20261012_device_notifications.sql
-- Per-device notification state, mirrored from the app whenever the user
-- grants/denies the OS permission or flips the in-app "Notifications" switch.
-- `true` means: the user wants renewal reminders AND iOS allows them.

alter table public.devices
  add column if not exists notifications_enabled boolean not null default false,
  add column if not exists notifications_updated_at timestamptz;

-- The app updates its own row (anonymous session → auth.uid() = user_id).
drop policy if exists "Devices update own row" on public.devices;
create policy "Devices update own row"
  on public.devices
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- >>> 20261012_device_registered_at.sql
-- Recap cadence anchor: when the device first registered (not personal data).
-- Mirrored best-effort from the app's Keychain copy.
alter table public.devices
  add column if not exists registered_at timestamptz;

-- >>> 20261012_device_quiet_hours.sql
-- Quiet hours mirrored from the device so a future remote push can apply the
-- same rule: deliver on time, silently (interruption-level "passive", no
-- "sound") inside the window, evaluated in the device's time zone.
alter table public.devices
  add column if not exists quiet_hours jsonb,
  add column if not exists time_zone text;

-- Kontrol: eklenen sütunlar listelenmeli.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'devices'
  and column_name in ('notifications_enabled','notifications_updated_at','registered_at','quiet_hours','time_zone')
order by column_name;
