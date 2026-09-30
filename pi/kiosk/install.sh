#!/bin/bash
# Install the kiosk boot experience on the appliance Pi. Safe to re-run.
#
#   - verbose boot: kernel and systemd messages on the console instead of the
#     splash, rotated to match the panel, in Terminus 16x32
#   - lightdm autologins into a labwc session that shows only Mixxx
#   - Mixxx starts fullscreen under the mixxx-kiosk supervisor
#
# Run it from this directory, on the Pi, as the appliance user (sudo is used
# where needed). Stop Mixxx first; the last step edits its config.
set -euo pipefail
cd "$(dirname "$0")"
STAMP=$(date +%Y%m%d-%H%M%S)
BOOT=/boot/firmware

if pgrep -x mixxx >/dev/null; then
    echo "Mixxx is running; stop it first (it rewrites mixxx.cfg on exit)" >&2
    exit 1
fi

echo "==> Kernel command line: verbose, console rotated for the panel"
# The panel is a native 480x1920 portrait DSI panel; the desktop turns it to
# landscape with kanshi's transform 90, which draws the image rotated 90 degrees
# counter-clockwise onto the panel. fbcon=rotate:3 does the same for the console.
# logo.nologo drops the Raspberry Pi logos from the top of the boot log.
sudo cp "$BOOT/cmdline.txt" "$BOOT/cmdline.txt.bak-$STAMP"
new=$(python3 - "$BOOT/cmdline.txt" <<'EOF'
import sys
toks = open(sys.argv[1]).read().split()
drop = {"quiet", "splash"}
add = ["fbcon=rotate:3", "logo.nologo"]
toks = [t for t in toks if t not in drop and not t.startswith("fbcon=rotate:")]
toks += [a for a in add if a not in toks]
print(" ".join(toks))
EOF
)
# One line, still pointing at the root filesystem, or nothing is written.
if [ "$(printf '%s\n' "$new" | wc -l)" != 1 ] || ! grep -q 'root=' <<<"$new"; then
    echo "refusing to write a malformed cmdline.txt: $new" >&2
    exit 1
fi
printf '%s\n' "$new" | sudo tee "$BOOT/cmdline.txt" >/dev/null
echo "    $new"

echo "==> Firmware: no rainbow splash"
sudo cp "$BOOT/config.txt" "$BOOT/config.txt.bak-$STAMP"
if ! grep -q '^disable_splash=1' "$BOOT/config.txt"; then
    printf '\n[all]\ndisable_splash=1\n' | sudo tee -a "$BOOT/config.txt" >/dev/null
fi

echo "==> Console font: Terminus 16x32 (120 x 15 on this panel)"
sudo cp /etc/default/console-setup "/etc/default/console-setup.bak-$STAMP"
sudo sed -i -e 's/^FONTFACE=.*/FONTFACE="Terminus"/' \
            -e 's/^FONTSIZE=.*/FONTSIZE="16x32"/' /etc/default/console-setup

echo "==> tty1: no automatic shell login"
# raspi-config's desktop-autologin option also autologins a shell on tty1. That
# puts the MOTD and a prompt on screen as the last thing before Mixxx, and
# leaves a sudo-capable shell open to anyone with a keyboard. Without it, the
# boot log ends on the hostname, IP address and a login prompt.
AUTOLOGIN=/etc/systemd/system/getty@tty1.service.d/autologin.conf
if [ -f "$AUTOLOGIN" ]; then
    sudo mv "$AUTOLOGIN" "$AUTOLOGIN.bak-$STAMP"   # not *.conf, so systemd ignores it
fi
# Debian's getty@ unit sets TTYVTDisallocate=yes, which wipes tty1 as the login
# prompt starts -- agetty's --noclear cannot help, the VT is gone by then. Keep
# the boot log on screen instead.
printf '[Service]\nTTYVTDisallocate=no\n' |
    sudo install -Dm644 /dev/stdin /etc/systemd/system/getty@tty1.service.d/keep-boot-log.conf
sudo systemctl daemon-reload

echo "==> Kiosk session"
sudo install -m755 mixxx-kiosk-session /usr/local/bin/mixxx-kiosk-session
sudo install -m755 appliance-mode      /usr/local/bin/appliance-mode
sudo install -m644 mixxx-kiosk.desktop /usr/share/wayland-sessions/mixxx-kiosk.desktop
install -Dm755 mixxx-kiosk "$HOME/.local/bin/mixxx-kiosk"
install -d "$HOME/.config/labwc-kiosk"
install -m644 labwc/autostart labwc/rc.xml labwc/environment "$HOME/.config/labwc-kiosk/"

echo "==> Qt dialogs: the skin's Btop palette, 16pt text"
# Mixxx applies the skin's stylesheet to the skin and the menu bar only, so its
# dialogs take the palette from qt6ct, which Pi OS points at the light PiXtrix
# scheme. qt6ct has one config per user, so the desktop session's Qt apps get
# this too, and Appearance Settings rewrites the path if it is used there.
install -Dm644 qt6ct/btop.conf "$HOME/.config/qt6ct/colors/btop.conf"
QT6CT_CONF="$HOME/.config/qt6ct/qt6ct.conf"
[ -f "$QT6CT_CONF" ] && cp "$QT6CT_CONF" "$QT6CT_CONF.bak-$STAMP"
python3 - "$QT6CT_CONF" <<'EOF'
import configparser, sys
path = sys.argv[1]
cfg = configparser.RawConfigParser()
cfg.optionxform = str  # qt6ct's keys are case-sensitive
cfg.read(path)
if not cfg.has_section("Appearance"):
    cfg.add_section("Appearance")
cfg.set("Appearance", "color_scheme_path", "~/.config/qt6ct/colors/btop.conf")
cfg.set("Appearance", "custom_palette", "true")
# Pi OS sets style=gtk2, which has no Qt 6 plugin, so Qt falls back to the
# bevelled Windows style. Fusion is flat, like the skin.
cfg.set("Appearance", "style", "Fusion")
# 16pt rather than Pi OS's 12: the dialogs' text and, with it, their buttons,
# at the size the skin's own text is on this panel. The value is a QFont
# string, "family,pointsize,...", so only the size field changes.
if not cfg.has_section("Fonts"):
    cfg.add_section("Fonts")
for key in ("general", "fixed"):
    font = cfg.get("Fonts", key, fallback='"Nunito Sans,12,-1,5,300,0,0,0,0,0,0,0,0,0,0,1"')
    fields = font.strip('"').split(",")
    fields[1] = "16"
    cfg.set("Fonts", key, '"' + ",".join(fields) + '"')
with open(path, "w") as f:
    cfg.write(f, space_around_delimiters=False)
EOF

# Retired by this session: the desktop-autostart launcher it replaces.
rm -f "$HOME/.config/autostart/mixxx.desktop" "$HOME/.local/bin/mixxx-autostart"

sudo cp /etc/lightdm/lightdm.conf "/etc/lightdm/lightdm.conf.bak-$STAMP"
sudo sed -i 's/^autologin-session=.*/autologin-session=mixxx-kiosk/' /etc/lightdm/lightdm.conf
grep -q '^autologin-session=mixxx-kiosk' /etc/lightdm/lightdm.conf

echo "==> Mixxx: start fullscreen"
# Mixxx saves its geometry, fullscreen state included, only when this is set.
# With it, the launch image comes up fullscreen from the first frame rather
# than in a window that goes fullscreen part-way through loading.
python3 - "$HOME/.mixxx/mixxx.cfg" <<'EOF'
import sys
path = sys.argv[1]
lines = open(path).read().splitlines()
hdr, key = "[Config]", "StartInFullscreen"
if hdr not in lines:
    lines += ["", hdr]
i = lines.index(hdr) + 1
while i < len(lines) and lines[i].strip() and not lines[i].startswith("["):
    if lines[i].split(" ", 1)[0] == key:
        lines[i] = f"{key} 1"
        break
    i += 1
else:
    lines.insert(i, f"{key} 1")
open(path, "w").write("\n".join(lines) + "\n")
EOF

echo "done; backups carry the suffix .bak-$STAMP. Reboot to use it."
