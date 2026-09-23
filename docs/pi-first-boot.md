# Pi 5 first boot: from blank SD card to a driver bench

Turn-by-turn for the first leg of [bring-up.md](bring-up.md) — Phases 0 through 3 —
written for a 32 GB SD card and an SSH-first workflow from the Windows dev machine.

**Goal of this document:** a Pi you can SSH into, with the DJM-T1 driver stack built and
the mixer transmitting MIDI. Mixxx comes at the end, deliberately.

## Why Mixxx is last

Mixxx on a Pi is a solved problem. The DJM-T1 on Linux is not. Installing Mixxx first
means debugging two unknowns at once — so this gets the mixer talking to the Pi with no
Mixxx involved, then adds it.

The 32 GB card is plenty for that. It only becomes tight if you later build Mixxx from
source, which is a Phase 5 decision, not a today decision.

---

## 0. On the Windows machine, before flashing

### 0.1 Make an SSH key

There isn't one on this machine yet:

```bash
ssh-keygen -t ed25519 -C "djm-t1-appliance"
cat ~/.ssh/id_ed25519.pub
```

Keep that public key on the clipboard — the Imager wants it in a moment.

### 0.2 Unplug the mixer from Windows

Only one host should own the device. Close Mixxx and anything else holding the MIDI port
before moving the cable to the Pi.

The mixer's armed state is cleared by re-enumeration anyway, so the move itself is
harmless — `djm_midi` re-arms on the Pi side.

---

## 1. Flash the card

**Raspberry Pi Imager** → Raspberry Pi OS (64-bit), the **Desktop** image, trixie.

Desktop rather than Lite, for three reasons that all show up later: the graphical screen
tool rotates display *and* touch together in one step, Squeekboard ships for the
on-screen keyboard, and Mixxx needs a GUI regardless.

### 1.1 Set the Imager's advanced options before writing

Gear icon, or `Ctrl+Shift+X`. This is what makes the box headless from first boot:

| Setting | Value |
|---|---|
| Hostname | `djm-t1` → reachable as `djm-t1.local` |
| Username | your usual one |
| Enable SSH | **yes**, "Allow public-key authentication only" |
| Public key | paste from 0.1 |
| Wi-Fi | SSID + password + country |
| Locale | timezone and keyboard |

Skip this and you need a keyboard and monitor on the Pi to get started.

---

## 2. Before ejecting the card: enable the panel

The boot partition is FAT32, so Windows can see it as a drive letter. Open `config.txt`
in its root and append:

```
dtoverlay=vc4-kms-v3d
dtoverlay=vc4-kms-dsi-waveshare-panel-v2,8_8_inch_a
```

Doing it now means the display works on boot #1 rather than after a round trip. See
[bring-up.md](bring-up.md) Phase 2 for why it's the `-v2` overlay and not the one a web
search offers, plus rotation and the ≥ 0.43 A power requirement.

If the panel isn't wired up yet, add the lines anyway — they're inert without it.

---

## 3. First boot and SSH in

Give it a minute or two on first boot (it resizes the filesystem and reboots).

```bash
ssh <user>@djm-t1.local
```

If mDNS doesn't resolve, find the Pi's address from your router and use the IP.

---

## 4. Base setup

```bash
sudo apt update && sudo apt full-upgrade -y
sudo usermod -aG audio "$USER"        # log out and back in for this to take
```

Pin the governor — DJ work plus thermal throttling is a bad combination:

```bash
sudo apt install -y cpufrequtils
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
sudo systemctl restart cpufrequtils
```

---

## 5. Build the driver stack

This is the actual objective, and **nothing here is blocked on the unpushed work** — the
driver fork's `main` is already on GitHub.

```bash
sudo apt install -y git build-essential pkg-config \
    libusb-1.0-0-dev libasound2-dev libpipewire-0.3-dev alsa-utils

git clone https://github.com/Grizbeard/djm-t1-linux.git
cd djm-t1-linux

make -C midi
make -C audio djmt1-pipewire

sudo install -Dm644 udev/99-djm-t1.rules /etc/udev/rules.d/99-djm-t1.rules
sudo udevadm control --reload && sudo udevadm trigger
```

The udev rule is what lets the bridge claim the device without root.

---

## 6. The moment of truth

Plug the mixer into the Pi with a **short, known-good USB 2.0 cable**. A marginal cable
re-enumerates the device and re-enumeration clears the armed state, which looks exactly
like a driver bug.

```bash
lsusb | grep 08e4                 # expect 08e4:015e Pioneer DJM-T1
```

You need two shells — the bridge must keep running while you watch. `tmux` or a second
SSH session:

```bash
# shell 1
./midi/djm_midi -v

# shell 2
aseqdump -p "Pioneer DJM-T1"      # now move a fader
```

If nothing arrives: the mixer gates MIDI on its HID pipe being polled **alongside a live
audio session**. `djm_midi` without `--no-audio` keeps its own session up internally, so
that should be covered — if it isn't, that's a real finding, not a mistake. See the
interface spec §4.2.

### Then the audio path

```bash
./audio/djmt1-capture 5
```

Watch for 864-byte framing and **zero USB transfer errors**.

> This is the single most important number of the day. It answers the one hardware
> assumption the whole project rests on: **does high-speed isochronous work on the Pi 5's
> xHCI?** Nothing in this build has ever tested it. Transfer errors here mean trying an
> intermediate USB 2.0 hub before concluding anything.

Record the result in [hardware.md](hardware.md).

---

## 7. Only now, Mixxx

```bash
sudo apt install -y mixxx
apt-cache policy mixxx            # confirm what you actually got
```

Raspberry Pi OS trixie tracks Debian stable, so expect **Mixxx 2.5.0**. The skins and
mapping in this repo were developed against `main` (2.6-dev) on Windows, so treat skin
parse warnings as expected information rather than a fault:

```bash
mixxx 2>&1 | grep -iE "skin|controller|warning"
```

Getting the skins and mapping across *does* need the unpushed work — see
[bring-up.md](bring-up.md) Phase 0.1 for the publish-or-bundle decision. The mapping
itself is now in better shape than that document assumes: it has been exercised against
the real mixer on Windows, so what remains is confirming it behaves the same through
`djm_midi` rather than the vendor driver.

---

## 8. What not to do yet

- **Don't put the Pi in the chassis.** Every fault is harder to find through a lid.
- **Don't build Mixxx from source** until apt's 2.5.0 has actually failed you.
- **Don't touch the kernel driver** ([bring-up.md](bring-up.md) Phase 8) until the
  userspace path is measured. It has never been loaded on any machine, and it can oops or
  wedge the device.

---

## Where this leaves you

With sections 1–6 done you have a driver bench: a Pi you can work on entirely over SSH,
with the mixer's MIDI and audio paths both proven or both disproven. That is the platform
the rest of [bring-up.md](bring-up.md) assumes.

The next thing that needs the physical world is the channel-map bench test
([bench/channel-map.md](bench/channel-map.md)) — which needs both turntables, and which
still blocks all audio routing.
