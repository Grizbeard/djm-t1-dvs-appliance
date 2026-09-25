# Mixxx autostart

The Pi autologins `griz` into the labwc desktop (lightdm `autologin-user`), and
that session runs `~/.config/autostart/*.desktop` through
`lxsession-xdg-autostart`. `mixxx.desktop` starts Mixxx there.

Don't use `~/.config/labwc/autostart` for this. A user copy *replaces*
`/etc/xdg/labwc/autostart`, which is what starts the panel, the desktop and the
XDG autostart runner itself.

## Install

```sh
install -Dm755 mixxx-autostart ~/.local/bin/mixxx-autostart
install -Dm644 mixxx.desktop   ~/.config/autostart/mixxx.desktop
```

`mixxx.desktop` names `/home/griz` explicitly, because a desktop file's `Exec=`
does not expand `~` or `$HOME`.

## Why the launcher waits

Mixxx opens its sound card and MIDI ports once, at startup, and never retries.
At login it races the `djm-midi-kernel` user service, which creates the MIDI
port only after arming the mixer. Started first, Mixxx has audio but deaf
controls. `mixxx-autostart` waits up to 30 s for both `/proc/asound/DJMT1Audio`
and the bridge's `Pioneer DJM-T1` sequencer port. If the mixer is unplugged it
gives up and starts Mixxx anyway. Either way it logs the outcome:
`journalctl -b -t mixxx-autostart`.

Verified 2026-09-25 on a cold boot: the bridge armed at login, the launcher saw
the port within 1 s, and Mixxx came up about 25 s after power-on with audio
running and the controller connected in both directions.

Not yet tested: booting with the mixer unplugged, then plugging it in. Mixxx
will be running without it by then and will not pick it up until restarted.
