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
