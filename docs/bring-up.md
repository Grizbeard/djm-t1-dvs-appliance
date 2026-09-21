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

## Phase 2 — The 1920×480 panel

The skin now targets an **8.8" 1920×480 ultrawide**. That is a non-standard mode and the
most likely place to lose an afternoon.

- ⬜ Confirm the panel drives at native resolution at all.
- ⬜ If EDID is not honoured (common on these automotive-style panels), force it. Pi 5 is
  KMS/vc4, so the modern route is a kernel cmdline video mode rather than legacy
  `hdmi_*` settings:

  ```
  video=HDMI-A-1:1920x480@60
  ```

  in `/boot/firmware/cmdline.txt`. If that is not enough the panel needs explicit
  `hdmi_timings`, which means getting the timings from its datasheet.
- ⬜ Check rotation. Many 8.8" ultrawides are physically a portrait panel mounted
  sideways and report as such; if so, set `video=HDMI-A-1:...,rotate=90` or handle it in
  the compositor.
- ⬜ Verify touch maps to the right axes after any rotation — a rotated display with an
  unrotated touch matrix is the classic symptom.

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
- ⬜ **On-screen keyboard.** A headless touch box has no other way to type a search. The
  marcosseris fork's `search-osk` patch is the known solution; evaluate it against
  `squeekboard`/`wvkbd` before patching Mixxx.
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
| Does the 1920×480 panel drive at native res without custom timings? | Phase 2 |
| Which USB channel pair is which deck? | Phase 4 |
| Do the skins survive Mixxx 2.5 instead of 2.6-dev? | Phase 5 |
| Do the OK/WARN/ERR states render correctly? | Phase 6 |
| Are the 18 seeded DJM-T1 bindings right? | Phase 7 |
| Does the kernel driver work at all? | Phase 8 |
| Does the interlock need re-arming across PCM open/close? | Phase 8 |
