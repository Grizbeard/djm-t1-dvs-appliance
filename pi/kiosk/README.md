# Kiosk boot

Power on and you get a scrolling boot log, then Mixxx's loading screen, then
Mixxx, fullscreen. The desktop never appears. Quitting Mixxx powers the Pi off.

```sh
./install.sh      # on the Pi, from this directory, with Mixxx stopped; then reboot
```

`install.sh` is safe to re-run. Every system file it edits gets a `.bak-<stamp>`
copy next to it.

## What happens at boot

1. **Verbose console.** `quiet splash` come off the kernel command line and the
   rainbow splash is disabled, so the kernel and systemd log scrolls on tty1.
   Two things make it readable on this panel:
   - The panel is natively portrait (480x1920), and only the desktop turns it
     to landscape (kanshi, `transform 90`, which draws rotated 90 degrees
     counter-clockwise onto the panel). `fbcon=rotate:3` does the same for the
     console. This was measured, not guessed: a KMS grab of the running desktop
     and a framebuffer dump of the console text both come out reading
     bottom-to-top on the raw panel.
   - The console font is Terminus 16x32, giving 120 x 15. The kernel's built-in
     8x16 gives 240 x 30, which is too small to read at 0.11 mm per pixel.
     `console-setup` switches fonts a few seconds into userspace.
2. **The log ends on a login prompt, not a shell.** raspi-config's desktop
   autologin also autologins a shell on tty1, which put the MOTD and a prompt on
   screen last and left a sudo-capable shell open to any keyboard. That is
   removed. Debian's getty unit also wipes tty1 as it starts
   (`TTYVTDisallocate=yes`), so a drop-in turns that off. The last lines on
   screen are the hostname, the IP address and `login:`.
3. **lightdm autologins into `mixxx-kiosk`**, a labwc session with its own config
   (`~/.config/labwc-kiosk`) that runs only a black background, kanshi and the
   Mixxx supervisor. There is no panel, no desktop and no XDG autostart. labwc
   runs without `-m`: with it, it would also run the system autostart, which is
   what brings up the desktop.
4. **Mixxx starts fullscreen.** `[Config] StartInFullscreen` makes Mixxx save its
   geometry as fullscreen and restore it before its first frame, so the loading
   screen is fullscreen too, not a window that grows part-way through.

Measured 2026-09-25: Mixxx starts 11.4 s after the kernel boots, with the bridge
armed 1.7 s before it.

## The supervisor, `mixxx-kiosk`

| Event | What it does |
|---|---|
| Mixxx quits (exit status 0) | powers the Pi off. A skin button bound to Mixxx's exit command is a touchscreen power switch. |
| Mixxx crashes, or is killed | restarts it. Three crashes in 2 minutes bring up the desktop instead. |
| The system is shutting down, or the session ends | nothing. A reboot over SSH stays a reboot. |
| The mixer is plugged in late, or replugged | restarts Mixxx cleanly, about 15-20 s later, with sound and controls working. |

Mixxx opens its sound card and MIDI ports once, at startup, and never retries,
which is why a replug means a restart. The supervisor spots one because the
`djm_midi` bridge's sequencer client gets a new pid every time it re-arms the
mixer. Before the first start it also waits for the card and the bridge port,
because at login it otherwise races the bridge and comes up with deaf controls.

Restarts close Mixxx's window through the compositor (`wlrctl`), so Mixxx
saves its settings as usual. It has no SIGTERM handler, so a signal would kill
it without saving. A modal dialog blocks a close request, so after a grace
period (30 s, or 5 s if Mixxx started without the mixer and is sitting in its
"No Output Devices" dialog) it falls back to SIGTERM.

Logs: `journalctl -b -t mixxx-kiosk`.

## Maintenance

- **Restart Mixxx:** `mixxx-kiosk restart`. It closes Mixxx cleanly and the
  supervisor starts it again. A plain `pkill mixxx` also restarts it, counted
  as a crash, but loses unsaved settings.
- **Get the desktop back:** `appliance-mode desktop now`, and later
  `appliance-mode kiosk now`. Without `now`, the change takes effect at the next
  boot. The stock desktop session is untouched; it just isn't the autologin.
- **Remote screen:** rpi-connect's wayvnc keeps working in the kiosk session.

## Not done

- The mouse cursor is still drawn. That's right with a mouse, but noise on a
  touch-only setup.
- Power-off on quit was built and checked for its guards (a reboot over SSH did
  not power off), but it has not yet been triggered from the panel.
