#!/bin/bash
# Install the fan's power light and temperature-controlled fan speed. Safe to
# re-run.
#
# Run it from this directory, on the Pi 5, as the appliance user (sudo is used
# where needed). Mixxx can keep running. Both overlays are also loaded live, so
# no reboot is needed; config.txt carries them from the next boot on.
set -euo pipefail
cd "$(dirname "$0")"

LED_GPIO=23      # fan's green wire, header pin 16
BEGIN="# >>> pi/status-light >>>"
END="# <<< pi/status-light <<<"
CONFIG_TXT=/boot/firmware/config.txt
OVERLAYS=/boot/firmware/overlays

grep -q "Raspberry Pi 5" /proc/device-tree/model ||
    { echo "This needs a Raspberry Pi 5 (RP1's PIO and PWM)." >&2; exit 1; }

echo "==> fan overlay: the Pi 5's fan control on GPIO18"
dtc -@ -q -I dts -O dtb -o "$HOME/.cache/djm-fan.dtbo" djm-fan.dts
sudo install -m 0644 "$HOME/.cache/djm-fan.dtbo" "$OVERLAYS/djm-fan.dtbo"

echo "==> $CONFIG_TXT"
# Replace our block if it is there, then append it: at the end it is under the
# file's last [all], which applies on every board.
sudo cp "$CONFIG_TXT" "$CONFIG_TXT.pre-status-light"
sudo sed -i "\|^$BEGIN\$|,\|^$END\$|d" "$CONFIG_TXT"
sudo tee -a "$CONFIG_TXT" >/dev/null <<CFG
$BEGIN
[all]
# Fan LEDs (WS2812 x2) on GPIO$LED_GPIO, driven by RP1's PIO. brightness=0 is
# the driver's pass-through mode: status-light does its own gamma.
dtoverlay=ws2812-pio,gpio=$LED_GPIO,num_leds=2,brightness=0
# Fan PWM on GPIO18, following the CPU temperature.
dtoverlay=djm-fan
$END
CFG

echo "==> loading the overlays now"
grep -qx pwmfan /sys/class/hwmon/*/name 2>/dev/null || sudo dtoverlay djm-fan
[ -e /dev/leds0 ] || sudo dtoverlay ws2812-pio "gpio=$LED_GPIO" num_leds=2 brightness=0
for _ in $(seq 1 30); do [ -e /dev/leds0 ] && break; sleep 0.1; done

echo "==> status-light: program, unit, shutdown hook, settings"
sudo install -m 0755 status-light /usr/local/sbin/status-light
sudo install -m 0644 status-light.service /etc/systemd/system/status-light.service
sudo install -d /usr/lib/systemd/system-shutdown
sudo install -m 0755 status-light.shutdown /usr/lib/systemd/system-shutdown/status-light
if [ -e /etc/default/status-light ]; then
    echo "    keeping the existing /etc/default/status-light"
else
    sed "s/^KIOSK_USER=.*/KIOSK_USER=$(id -un)/" status-light.default |
        sudo tee /etc/default/status-light >/dev/null
fi

sudo systemctl daemon-reload
sudo systemctl enable status-light.service
sudo systemctl restart status-light.service
sleep 2
systemctl --no-pager --lines=0 status status-light.service | head -3
fan=$(grep -lx pwmfan /sys/class/hwmon/*/name | head -1 || true)
[ -z "$fan" ] || echo "    fan PWM $(cat "$(dirname "$fan")/pwm1")/255 at $(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 )) C"
