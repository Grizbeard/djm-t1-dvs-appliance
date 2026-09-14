# Architecture decision log

Short records of decisions that are expensive to reverse. Each says what was decided,
why, and what would change the answer.

---

## ADR-001: Kernel ALSA driver, not the userspace PipeWire bridge

**Status:** decided, not yet implemented. The userspace path is the bring-up route.

**Context.** Upstream ships a working userspace driver (`audio/djmt1-pipewire`) that
streams the mixer with libusb and presents it to PipeWire, plus a drafted in-kernel ALSA
driver (`kernel/djmt1_audio.c`) that compiles but has never been loaded.

**Decision.** Target the kernel driver. Use the userspace path only to prove the USB
path works on the Pi 5's xHCI.

**Why.** The device free-runs at 48 kHz and has **no feedback endpoint** — confirmed from
the vendor's own macOS driver, which reports no sync type and has feedback discovery
disabled. There is therefore no mechanism to rate-correct it. The userspace bridge hands
that free-running stream to a PipeWire graph clocked by something else, across rings with
no resampling and no drift compensation: on over/underrun it drops or pads and increments
a counter. Every such event is a discontinuity in the timecode stream, and xwax loses
lock. Latency is also unregulated — ring residency is whatever it settles at — and DVS is
latency-sensitive in a way general playback is not.

A kernel driver puts Mixxx on `hw:` through PortAudio/ALSA with both substreams advancing
on the same SOF clock, which is exactly the model the vendor driver assumes.

**Consequences.**

- The kernel driver must be validated on hardware first. It has never been loaded.
- Its `usb_device_id` is interface-scoped to interface 0, so it coexists with the MIDI
  bridge owning interfaces 2 and 3. No conflict.
- **New problem:** with a kernel driver, isochronous streaming only runs while a PCM
  client is open, so the MIDI interlock's "live audio session" precondition comes and
  goes. The userspace bridge held it open permanently. See ADR-002.

**What would change this.** If the kernel driver proves unstable on the Pi's xHCI *and*
the userspace path measures acceptable timecode lock quality, revisit. Measure, don't
assume.

---

## ADR-002: Re-arm strategy for the MIDI interlock

**Status:** open. Needs a hardware answer.

**Context.** The mixer transmits its control surface only while armed *and* its HID pipe
is polled *and* an audio session is live. `djm_midi` arms once, roughly 500 ms after
start. The current service papers over ordering with a fixed sleep and a dependency on
the audio service, which works because the userspace audio driver runs permanently.

Under ADR-001 that no longer holds: the audio session appears when Mixxx opens the PCM
and disappears when it closes.

**The unknown.** When an audio session stops and restarts, does transmission simply
resume, or is a re-arm required? Untested, and nobody knows.

**Options.**

1. Patch `djm_midi` to re-arm periodically, or on detecting an idle HID pipe.
   Upstreamable, and the right fix.
2. Hold a permanent silent PCM stream open so the session never drops. Crude, reliable.
3. Rely on Mixxx running continuously — true for a kiosk appliance, but fragile across
   restarts and useless while debugging.

**Decision.** Resolve the unknown on the bench first. Then prefer option 1, with option 2
as a backstop.

---

## ADR-003: External mixing

**Status:** decided.

**Context.** The DJM-T1 is an analogue mixer with a built-in soundcard. Mixxx can either
mix in software and send a single master out (internal mixing), or send each deck
separately and let the mixer do it (external mixing).

**Decision.** External mixing. Mixxx sends deck 1 and deck 2 to separate USB output
pairs; the DJM does EQ, faders, crossfader and headphone cueing in analogue.

**Why.** It is the point of owning the mixer, it is what the hardware was built for, and
it keeps the analogue signal path the DJM was designed around.

**Consequences.**

- **The upstream Mixxx mapping is wrong for this build.** It maps trim, 3-band EQ, volume
  faders and crossfader to Mixxx's software mixer. Layering those on top of the analogue
  controls double-attenuates. Upstream's own `docs/midi-map.md` flags the trap.
- The mapping variant in `mixxx/` keeps the browse encoder, load buttons and deck
  transport, and drops the entire mixer section.
- Headphone cueing is analogue and local to the mixer, so the CUE buttons should not
  drive Mixxx's PFL either.
- The 10-bit HID resolution upgrade upstream is planning is largely irrelevant here —
  those are the analogue controls this build does not map.
