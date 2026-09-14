# System services

System-level systemd units for a headless / kiosk appliance.

Upstream ships **user** services, which need a live login session. For an appliance,
either enable lingering (`loginctl enable-linger`) or convert them to system units.
Record which approach is used and why.

Units expected here:

- MIDI bridge (`djm_midi --no-audio`), with the re-arm strategy from ADR-002
- Mixxx autostart
- Health/watchdog, if needed

Nothing here yet.
