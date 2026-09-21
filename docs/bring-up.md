# Bring-up: getting this onto the Pi 5

Ordered plan for moving the project from the development machine onto real hardware.

Ordering principle: **cheapest test that could invalidate the most work goes first**, and
the Pi stays *outside* the mixer chassis until everything software is proven. Physical
integration is the last step, not the first, because every fault is harder to diagnose
through a screwed-down lid.

Status key: ⬜ not started · 🔶 in progress · ✅ done

---

## Phase 0 — Before the Pi boots

### 0.1 ⬜ Get the code somewhere the Pi can reach

Two things are not on any remote right now:

| What | Where | State |
|---|---|---|
| Appliance repo `main` | this repo | **10 commits unpushed** |
| `tools/mapping-studio` | driver fork | **21 commits, local only, never pushed** |

The driver fork's remote is **public**. Mapping Studio has never been pushed, and that
was deliberate — decide consciously rather than by reflex:

- **Push** — simplest, and the Pi just clones. Makes Mapping Studio public.
- **Sneakernet** — `git bundle` or `rsync` over SSH to the Pi, nothing published.

```bash
# push route
cd ~/projects/djm-t1-dvs-appliance && git push origin main
cd ~/projects/djm-t1-linux && git push origin tools/mapping-studio

# or bundle route (no publishing)
git -C ~/projects/djm-t1-linux bundle create /tmp/mapping-studio.bundle tools/mapping-studio
```

### 0.2 ⬜ Decide the Mixxx version, and accept the consequence

The skins and mapping were developed against Mixxx **`main` (2.6-dev)** on Windows.
Raspberry Pi OS trixie ships **2.5.x**. Skin XML schemas drift between releases, and
`Terminal-wide` is a large generated skin with a lot of surface to drift against.

- **apt install Mixxx 2.5** — minutes, but the skins are untested against it. Expect to
  fix skin parse warnings.
- **Build 2.6-dev from source on the Pi** — hours on first build, but matches exactly what
  the skins were rendered against.

Recommendation: **apt first**, purely to get moving, and treat skin breakage as
information. Building from source is a fallback, not the opening move.

---

## Phase 1 — Pi OS base

- ⬜ 64-bit Raspberry Pi OS **trixie**. Matches what the marcosseris Pioneered fork
  targets, so its prebuilt arm64 packages and Pi scripts stay usable as reference.
- ⬜ Storage decision — NVMe HAT is worth it for library and waveform cache (see
  [hardware.md](hardware.md)).
- ⬜ **Enable SSH.** Everything from here is faster driven remotely from the dev machine
  than typed at the panel.
- ⬜ Add the user to `audio`; log out and back in.
- ⬜ Pin the `performance` CPU governor.

---

## Phase 2 — The panel: Waveshare 8.8-DSI-TOUCH-A

**DSI, not HDMI.** 8.8" IPS, 10-point capacitive touch, display IC OTA7290B, touch IC
GT9271. Native resolution is **480×1920 portrait** — the 1920×480 the skin targets is the
*rotated* orientation, so rotation is mandatory, not optional.

Source: the vendor wiki (`8.8-DSI-TOUCH-A`, oldid 110243).

### 2.1 ⬜ Physical connection (Pi 5)

- **22-pin, 200 mm, _reversed_ FFC cable** into the Pi 5's 22-pin DSI port. Pi 4 and
  earlier use the 15-pin cable instead — different part, easy to order wrong.
- **Power is separate.** The DSI cable does not carry it: run 5V and GND from the GPIO
  header to the display's power connector.
- **The panel needs ≥ 0.43 A.** Below that it fails to start or displays abnormally, and
  running it in that state can damage it permanently. Budget PSU headroom accordingly —
  a Pi 5 plus NVMe plus this panel wants the 5 A supply, not a spare phone charger.
- Pi mounts to the display with M2.5 screws, which is worth knowing before designing the
  enclosure (Phase 10).

### 2.2 ⬜ Enable it

Trixie or Bookworm. Append to `/boot/firmware/config.txt`:

```
dtoverlay=vc4-kms-v3d
dtoverlay=vc4-kms-dsi-waveshare-panel-v2,8_8_inch_a
```

Add `,dsi0` to the second line to use DSI0 instead; DSI1 is the vendor default.

> **Use the `-v2` overlay.** A web search will offer
> `dtoverlay=vc4-kms-dsi-waveshare-panel,8_8_inch` — that is the *older* "8.8inch DSI
> LCD" product, a different panel with the same diagonal. The DSI-TOUCH-A series is the
> v2 overlay with the `_a` suffix. Both exist in the mainline Pi overlay tree and both
> claim 8.8"/480×1920, so the wrong one looks plausible right up until it doesn't work.

Allow ~30 s on first boot before the display comes up.

### 2.3 ⬜ Rotate to landscape

Needed to get 1920×480. **On Pi 5 the connector enumerates as `DSI-2`, not `DSI-1`** —
confirm the actual name on the system before writing it anywhere (the vendor's own page
is inconsistent about this).

Desktop route — also rotates touch in one step:

> Preferences → Control Center → Screens → `DSI-2` → Orientation → Apply,
> with "Touchscreen" ticked under the same menu.

Lite/headless route — at the **beginning** of `/boot/firmware/cmdline.txt`:

```
video=DSI-2:480x1920e,rotate=90
```

Then touch needs rotating separately, via `/etc/udev/rules.d/99-waveshare-touch.rules`:

```
ENV{ID_INPUT_TOUCHSCREEN}=="1", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 -1 1 1 0 0"
```

(That matrix is the 90° one; the wiki gives 180° and 270° variants.)

Caveat worth remembering: **cmdline.txt rotation applies to DSI and HDMI together** —
they share one value and cannot be rotated independently. That bites the moment you
attach HDMI to debug something.

### 2.4 ⬜ Choose the touch mode — this interacts with the mapping

Trixie/Bookworm offer two, under Screen Configuration → Touchscreen:

| Mode | Gives you | Costs you |
|---|---|---|
| **Mouse Emulation** (default) | click, double-click, **long-press = right-click** | no swipe, no multitouch |
| **Multitouch** | swipe, multitouch | **no long-press right-click**, no double-click |

Scrolling a long library wants Multitouch. But Multitouch removes right-click entirely,
and Mixxx puts a great deal behind the track context menu.

This is exactly why SNAP/QUANTIZE is bound to `[Library] show_track_menu` in the mapping.
That binding stops being a nicety and becomes load-bearing the moment Multitouch is
selected. Decide the touch mode and the mapping together, not separately.

### 2.5 ⬜ Backlight

Software-controllable, which is useful in a dark booth:

```bash
echo 128 | sudo tee /sys/class/backlight/*/brightness   # 0-255
```

This phase can run in parallel with Phase 3; neither blocks the other.

---

## Phase 3 — The mixer talks to the Pi (no Mixxx yet)

The real "does this hardware work" gate, and it tests the assumption flagged in
[hardware.md](hardware.md): **high-speed isochronous on the Pi 5's xHCI is unverified.**
Everything downstream assumes it works.

- ⬜ Install build deps: `libusb-1.0-0-dev`, `libasound2-dev`, `libpipewire-0.3-dev`.
- ⬜ Build the bridge and the audio driver:

  ```bash
  cd external/djm-t1-linux
  make -C midi
  make -C audio djmt1-pipewire
  sudo install -Dm644 udev/99-djm-t1.rules /etc/udev/rules.d/99-djm-t1.rules
  sudo udevadm control --reload && sudo udevadm trigger
  ```

- ⬜ **MIDI flows.** This exercises the vendor arm *and* the HID-poll interlock:

  ```bash
  ./midi/djm_midi -v          # leave running
  aseqdump -p "Pioneer DJM-T1"   # other terminal; move a fader
  ```

  Nothing? The interlock needs a live audio session too — see the interface spec §4.2.
- ⬜ **Audio streams.** `./audio/djmt1-capture 5` — watch for 864-byte framing and
  **zero USB transfer errors**. Transfer errors here are the xHCI answer.
- ⬜ Use a short, known-good USB 2.0 cable. A marginal cable re-enumerates the device,
  and re-enumeration clears the armed state.

**If iso misbehaves on xHCI:** try an intermediate USB 2.0 hub before concluding
anything. That is the standard workaround and it is cheap to test.

---

## Phase 4 — The channel map bench test ⚠️ blocking

**[docs/bench/channel-map.md](bench/channel-map.md).** Needs the mixer *and* both
turntables.

This is the highest value per minute of anything on this list. It blocks:

- Mixxx's Sound Hardware configuration, on both the input and output side
- therefore all DVS configuration
- therefore the timecode status indicator ever showing anything but `OFF`

It is also the single most valuable thing the upstream project is missing, so the result
is a PR whether or not the rest of this build proceeds.

Do this the day the turntables and mixer are both on the bench.

---

## Phase 5 — Mixxx

- ⬜ Install Mixxx per the Phase 0.2 decision.
- ⬜ Install the skin and mapping:

  ```bash
  mkdir -p ~/.mixxx/skins ~/.mixxx/controllers
  ln -s "$PWD/mixxx/skins/Terminal-wide"      ~/.mixxx/skins/Terminal-wide
  ln -s "$PWD/mixxx/skins/Pioneered-DVS"      ~/.mixxx/skins/Pioneered-DVS
  cp mixxx/controllers/Pioneer-DJM-T1-DVS.*   ~/.mixxx/controllers/
  ```

- ⬜ Launch and **read the log**, not just the window. Skin parse warnings are the
  version-drift signal:

  ```bash
  mixxx --controller-debug 2>&1 | grep -iE "skin|controller|warning"
  ```

- ⬜ Preferences → Interface → pick the skin. Confirm it lays out at 1920×480 — this is
  the first time it renders anywhere but the Windows screenshot harness.
- ⬜ Preferences → Sound Hardware: assign Deck 1/2 outputs and Vinyl Control In 1/2 from
  the Phase 4 results.
- ⬜ Preferences → Vinyl Control: timecode type (Traktor MK1/MK2 most likely for this
  mixer's era), lead-in, absolute vs relative.

---

## Phase 6 — DVS actually works

- ⬜ Drop the needle. Confirm Mixxx locks onto timecode.
- ⬜ **The status indicator finally gets exercised.** States 1–3 (`OK` / `WARN` / `ERR`)
  have never been rendered — they were confirmed by construction only. Verify each one
  really appears and is the right colour: lift the needle for `ERR`, and a dusty or worn
  section of record should give `WARN`.
- ⬜ Assess scratch feel and latency. This is the measurement that decides whether the
  userspace audio path is good enough or whether ADR-001's kernel driver is required.

---

## Phase 7 — Verify the mapping

The DJM-T1 mapping has **18 bindings, all `verified: false`**, and Mapping Studio's ALSA
backend has only ever run offline. This is what that tool was built for.

- ⬜ Run Mapping Studio on the Pi over SSH (stdlib only, so it needs nothing installed).
- ⬜ Walk the panel, verify each binding, capture what the seeded map got wrong.
- ⬜ Watch for the traps the Reloop work already surfaced: controls spread across several
  MIDI channels, releases arriving as note-off rather than note-on-zero, and one
  `<output>` naming a script function making Mixxx reject *every* LED.
- ⬜ Confirm the DVS bindings do what they claim — the ACTIVE / PLAY MODE / FX ON
  assignments were guesses about which spare buttons fall nicely under the hand, and this
  is the moment to move them.
- ⬜ Confirm SNAP/QUANTIZE opens the track context menu. That binding exists because the
  panel cannot right-click, so it matters more than it looks.

---

## Phase 8 — Kernel driver (ADR-001, ADR-002)

Only worth doing if Phase 6 says the userspace path is not good enough, or for its own
sake as an upstream contribution.

- ⬜ Install kernel headers, build `external/djm-t1-linux/kernel`.
- ⬜ Load it on the Pi — a machine you can freely reboot, which is exactly what the
  driver's README asks for. It has never been loaded anywhere.
- ⬜ Point Mixxx at the ALSA `hw:` device instead of PipeWire; re-measure Phase 6.
- ⬜ **Answer ADR-002.** With a kernel driver the audio session comes and goes with the
  PCM, so: when a session stops and restarts, does the control surface resume, or does
  the mixer need re-arming? Nobody knows. It is a five-minute test once the driver loads.

---

## Phase 9 — Appliance shell

- ⬜ Autostart Mixxx on boot, fullscreen, no desktop chrome.
- ⬜ systemd: upstream ships **user** services, which need a live session. Either
  `loginctl enable-linger` or convert to system units. Record which and why.
- ⬜ **On-screen keyboard — probably already solved.** Raspberry Pi OS Bookworm and later
  ship **Squeekboard** by default, auto-popping when text input is focused, with a
  taskbar toggle. That may remove the need for the marcosseris `search-osk` Mixxx patch
  entirely.

  Verify rather than assume: Squeekboard's auto-show relies on the app declaring intent
  through the Wayland text-input protocol, and Qt apps running under XWayland often do
  not. Test whether focusing Mixxx's search box raises it. If it does not, the taskbar
  toggle is the fallback and `search-osk` is the fix.
- ⬜ Boot time, and behaviour when the mixer is absent or unplugged at boot.

---

## Phase 10 — Physical integration

Last. Only once all of the above passes on the bench.

- ⬜ Short, strain-relieved internal USB cable — this turns upstream's worst failure mode
  (re-enumeration from a marginal cable) into a non-issue.
- ⬜ Power: the Pi needs its own supply; the mixer is mains-powered and the Pi does not
  draw from it over USB.
- ⬜ Thermal: a Pi 5 sealed in a chassis throttles. Log `vcgencmd measure_temp` under
  sustained load *before* committing to an enclosure.
- ⬜ Panel mounting and final cable dress.

---

## What is genuinely unknown

Honest list, so nothing here comes as a surprise:

| Unknown | Found out in |
|---|---|
| Does high-speed iso work on the Pi 5's xHCI? | Phase 3 |
| Does the `-v2` overlay bring the panel up on the Pi 5's DSI1? | Phase 2 |
| Does rotated touch line up with the rotated display? | Phase 2 |
| Which USB channel pair is which deck? | Phase 4 |
| Do the skins survive Mixxx 2.5 instead of 2.6-dev? | Phase 5 |
| Do the OK/WARN/ERR states render correctly? | Phase 6 |
| Does Squeekboard auto-raise for Mixxx's search box? | Phase 9 |
| Are the 18 seeded DJM-T1 bindings right? | Phase 7 |
| Does the kernel driver work at all? | Phase 8 |
| Does the interlock need re-arming across PCM open/close? | Phase 8 |
