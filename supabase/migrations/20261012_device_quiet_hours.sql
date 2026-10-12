-- Quiet hours mirrored from the device so a future remote push can apply the
-- same rule: deliver on time, silently (interruption-level "passive", no
-- "sound") inside the window, evaluated in the device's time zone.
alter table public.devices
  add column if not exists quiet_hours jsonb,
  add column if not exists time_zone text;
