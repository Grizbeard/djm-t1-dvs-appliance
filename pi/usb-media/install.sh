#!/bin/bash
# Install automatic read-only mounting of USB drives for Mixxx. Safe to re-run.
#
# Run it from this directory, on the Pi, as the appliance user (sudo is used
# where needed). Mixxx can keep running.
set -euo pipefail
cd "$(dirname "$0")"
USER_NAME=$(id -un)

echo "==> usb-media: script, unit, udev rule"
sudo install -m 0755 usb-media /usr/local/sbin/usb-media
sudo install -m 0644 usb-media@.service /etc/systemd/system/usb-media@.service
sudo install -m 0644 99-usb-media.rules /etc/udev/rules.d/99-usb-media.rules
printf 'MEDIA_USER=%s\n' "$USER_NAME" | sudo tee /etc/default/usb-media >/dev/null

echo "==> /run/media/$USER_NAME at every boot"
# Mixxx watches this directory to notice drives coming and going, and it can
# only watch one that exists: created here rather than on the first mount, a
# boot with no drive in would miss the first one plugged in.
printf 'd /run/media 0755 root root -\nd /run/media/%s 0755 root root -\n' "$USER_NAME" |
    sudo tee /etc/tmpfiles.d/usb-media.conf >/dev/null
sudo systemd-tmpfiles --create /etc/tmpfiles.d/usb-media.conf

echo "==> reloading systemd and udev"
sudo systemctl daemon-reload
sudo udevadm control --reload

echo "==> mounting drives that are already plugged in"
sudo udevadm trigger --action=add --subsystem-match=block --property-match=ID_BUS=usb
sudo udevadm settle
sleep 1
findmnt -rn -o SOURCE,TARGET,FSTYPE,OPTIONS | grep " /run/media/$USER_NAME/" || echo "    (no USB drives mounted)"
