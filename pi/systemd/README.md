# System services

Upstream ships **user** services, which need a live login session. The two
options were `loginctl enable-linger` or converting them to system units.

**Decision (2026-09-25): neither. Keep them as user services and rely on
autologin.** The box always autologins `griz` into the desktop, because Mixxx
needs a Wayland display anyway. That login starts the user manager, so user
services run on every boot with no linger. A system unit would buy nothing, and
it would put `djm_midi` outside the session that Mixxx runs in.

What runs, and where it lives:

- **Audio:** the `djmt1_audio` kernel module, installed through DKMS and loaded
  by udev when the mixer appears. It is not a service at all. See
  `external/djm-t1-linux/kernel/README.md` (branch `kernel/duplex-streams`).
- **MIDI bridge:** `djm-midi-kernel.service`, a user service running
  `djm_midi --no-audio` with `Restart=always`, so it re-arms the mixer after a
  replug. Its unit file is in `external/djm-t1-linux/midi/systemd/` on the same
  branch.
- **Mixxx:** desktop autostart, not systemd. See [`../autostart/`](../autostart/).

Revisit this if the box ever has to run headless, with no display login.
