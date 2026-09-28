# Fan: power light and temperature control

The case fan (40 mm, 5 V, 4-wire, two WS2812 LEDs) doubles as the appliance's
power light, and its speed follows the CPU temperature the way the Pi 5's own
Active Cooler does.

```sh
./install.sh      # on the Pi 5, from this directory; Mixxx can keep running
```

`install.sh` is safe to re-run. It loads everything live, so no reboot is
needed, and adds two lines to `/boot/firmware/config.txt` (between
`# >>> pi/status-light >>>` markers, previous file kept as
`config.txt.pre-status-light`) so that it all comes back at boot.

## Wiring

Everything goes on the outer row of the 40-pin header, the row with the 5 V
pins:

| Fan wire | Signal | Header pin | Pi 5 |
|---|---|---|---|
| Red | +5 V | **4** | 5 V (pin 2 is also 5 V) |
| Black | GND | **6** | ground (also 9, 14, 20, 25, 30, 34, 39) |
| Blue | PWM speed | **12** | GPIO18, RP1 PWM0 channel 2 |
| Green | WS2812 data | **16** | GPIO23, RP1 PIO |

The outer row is the one along the board's edge. Count from the end of the
header away from the USB and Ethernet ports: pin 2 is the first pin in that
row, so red goes on the 2nd pin, black the 3rd, blue the 6th and green the 8th.

```
  edge row:   2   4   6   8  10  12  14  16  ...  (towards USB/Ethernet)
                 Red Blk         Blue     Green
  inner row:  1   3   5   7   9  11  13  15  ...
```

Two things to check with a meter before trusting it long-term:

- **Blue (PWM).** Power the fan with the blue wire unconnected and measure it
  against ground. Most fans pull their PWM input up internally. If it reads
  3.3 V or less, connect it straight to pin 12. If it reads nearer 5 V, put a
  1 kΩ resistor in series, so the pull-up cannot push much current into the
  Pi's 3.3 V pin.
- **Green (LED data).** The WS2812s run from 5 V and, on paper, want a data
  signal above 3.5 V; the Pi sends 3.3 V. That almost always works over a short
  wire. If the colours come out wrong or flicker, add a 3.3→5 V buffer (a
  74AHCT125 or 74HCT14 section) in the green wire.

The fan draws up to 0.25 A from the 5 V pin, which the Pi's supply covers.

## What the light says

| Light | Meaning |
|---|---|
| amber, breathing | booting, until Mixxx is on screen; also while Mixxx restarts |
| white, steady | on: Mixxx is up and the DJM-T1 is connected |
| blue, breathing | Mixxx is up, but the DJM-T1 is not connected |
| red, blinking | Mixxx has not come up for a minute: it keeps crashing, or the desktop is shown for maintenance |
| amber, fast | rebooting |
| red, fast | shutting down (Quit in Mixxx, or `poweroff`) |
| dim red, steady | off, still plugged in |
| dark | unplugged, or the first second or two after plugging in |

Colours, overall brightness and the kiosk user are in
`/etc/default/status-light`; `sudo systemctl restart status-light` after
editing. `install.sh` never overwrites that file once it exists.

To check the wiring and see every state in turn:

```sh
sudo systemctl stop status-light
sudo status-light test          # red, green, blue, then each state for 4 s
sudo systemctl start status-light
```

If "red" shows green, the fan's LEDs are not the usual WS2812 GRB order; say
so, and the byte order can be swapped in the program.

`journalctl -u status-light` logs each change of state.

## How it works

- **`ws2812-pio` overlay** (ships with Pi 5 kernels): RP1's PIO drives the
  LEDs on GPIO23 and makes `/dev/leds0`. `brightness=0` is its pass-through
  mode, so the program applies its own brightness and gamma curve; with the
  driver's curve, the dim standby red would round down to nothing.
- **`status-light`** (`/usr/local/sbin`, run by `status-light.service`,
  started early in boot): once a second it looks at whether systemd is going
  down (and whether to a reboot or a power-off), whether Mixxx is running and
  its window is up, and whether the DJM-T1's sound card is there; 25 times a
  second it draws the breathing. About 0.5 % of one core while animating,
  nothing between checks when steady.
- **The service has no default dependencies**, so the shutdown transaction
  never stops it: it shows the shutdown until the very end.
- **`status-light.shutdown`** (installed as
  `/usr/lib/systemd/system-shutdown/status-light`): systemd runs it last, after
  every process has gone. It writes dim red for a power-off, or steady amber
  for a reboot. WS2812s keep their last colour for as long as they have power,
  so that colour stays up through the firmware, or while the Pi is off.
  Standby needs the 5 V pins to stay powered after shutdown, which is the Pi 5
  default (`POWER_OFF_ON_HALT=0` in the EEPROM config). With
  `POWER_OFF_ON_HALT=1` the light goes dark instead.
- **`djm-fan` overlay** (`djm-fan.dts`, compiled by `install.sh` into
  `/boot/firmware/overlays/`): the Pi 5 already has a temperature-driven fan
  device for its fan connector, disabled when nothing is plugged in there. This
  enables it and moves its output to GPIO18. It keeps the stock curve: off
  below 50 °C, then 29 % at 50 °C, 49 % at 60, 69 % at 67.5 and 98 % at 75,
  each with 5 °C of hysteresis. `cat /sys/class/hwmon/hwmon*/pwm1` shows the
  current setting (0-255). The fan connector's output is inverted; a fan wired
  to a GPIO wants normal polarity, which was checked by sampling the pin (28 %
  high at a setting of 75/255).

## Not checked yet

Verified from software only: the service's states, the boot order (light up
3.7 s after power-on, "on" when Mixxx's window appears), the shutdown hook's
output, and the PWM on the pin. Still to see on the real fan:

- the colours are right (`status-light test`);
- the fan starts at the lowest step, 29 %; some fans need more to start. If it
  does not, the steps can be raised;
- after a shutdown, the light holds dim red, and whether the fan keeps spinning
  in standby. That depends on what RP1's pins do once the Pi is off.
