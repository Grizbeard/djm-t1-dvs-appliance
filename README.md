# DJM-T1 DVS Appliance

A Pioneer DJM-T1 with a Raspberry Pi 5 embedded in the chassis, running Mixxx as a
standalone digital-vinyl system. Plug in two turntables with control vinyl and it is a
self-contained DVS rig — no laptop.

This repository is the **appliance**: the Pi image, boot and service configuration,
Mixxx configuration and mapping, and the bench notes for this specific build.

The **driver** work — the ALSA/audio driver, the MIDI bridge, the USB interface
specification — lives upstream in [`tek-cat/djm-t1-linux`][upstream], consumed here as a
submodule at `external/djm-t1-linux`. Anything another DJM-T1 owner would want belongs
there, not here. Keeping the split clean is what makes the driver work upstreamable.

[upstream]: https://github.com/tek-cat/djm-t1-linux

## Status

Nothing is built yet. This is the project skeleton and the plan.

| Milestone | State |
|---|---|
| Channel-to-deck map measured | ⬜ **blocks everything** — see [docs/bench/channel-map.md](docs/bench/channel-map.md) |
| Userspace path running on the Pi 5 (USB/iso sanity check) | ⬜ |
| Kernel ALSA driver validated on hardware | ⬜ |
| Re-arm behaviour across PCM open/close resolved | ⬜ |
| External-mixing Mixxx mapping | ⬜ |
| Mixxx built for aarch64 | ⬜ |
| Headless boot / kiosk autostart | ⬜ |
| Enclosure, power and thermal | ⬜ |

## Architecture

Two decisions shape the whole build. Both are recorded with their reasoning in
[docs/decisions.md](docs/decisions.md).

**Kernel ALSA driver, not the userspace PipeWire bridge.** The DJM-T1 free-runs at
48 kHz with no feedback endpoint, so there is no mechanism to correct clock drift.
Bridging it into a separately-clocked sound-server graph reintroduces a drift problem
the vendor's own driver does not have, and every drift reconciliation is a
discontinuity that costs timecode lock. A kernel driver puts Mixxx on `hw:` directly.
The userspace path is still the bring-up route — it works today and proves the USB
path — but it is not the end state.

**External mixing.** The DJM-T1 does EQ, faders and crossfader in analogue. Mixxx sends
each deck to its own USB output pair and does not touch its software mixer. This means
the upstream Mixxx mapping is wrong for this build — mapping EQ and faders on top of
analogue ones double-attenuates. The variant in [`mixxx/`](mixxx/) keeps browse, load
and transport and drops the mixer section.

```
 control vinyl ──> turntable ──> DJM-T1 phono in ──> ADC ──> USB in ──┐
                                                                      │
                                      Mixxx vinyl control (xwax) <────┘
                                      decodes timecode -> deck position

 Mixxx deck 1 audio ──> USB out pair A ──> DJM-T1 ch1 (source: USB) ──┐
 Mixxx deck 2 audio ──> USB out pair B ──> DJM-T1 ch2 (source: USB) ──┴─> analogue mix
                                                                          -> master out
```

Which USB pair is which is **not yet known** — that is the channel-map bench test, and
it blocks the audio routing on both sides.

## Layout

| Path | Contents |
|---|---|
| `external/djm-t1-linux` | Submodule: the driver, MIDI bridge and interface spec |
| `docs/decisions.md` | Architecture decision log — why kernel driver, why external mixing |
| `docs/bench/` | Bench procedures and their results |
| `docs/hardware.md` | Enclosure, power, USB wiring, thermal |
| `mixxx/` | External-mixing controller mapping and Mixxx config |
| `pi/config/` | Boot config, kernel cmdline, CPU governor, tuning |
| `pi/systemd/` | System-level units for a headless/kiosk box |
| `scripts/` | Build and provisioning scripts |

## Submodule

The submodule currently points at upstream. After forking, re-point it at your fork so
appliance changes and driver changes can be developed together:

```bash
git submodule set-url external/djm-t1-linux https://github.com/<you>/djm-t1-linux.git
git submodule sync
```

Clone this repo with its submodule:

```bash
git clone --recurse-submodules <this repo>
```

## Hardware notes

- The mixer is mains-powered, so the Pi does not draw from it over USB.
- The Pi 5 has no EHCI controller — all four ports are on the RP1's xHCI. Upstream's
  "use a rear USB 2.0 port" advice reflects EHCI-era testing and does not translate.
  High-speed isochronous on xHCI needs verifying early, not at integration time.
- Any USB re-enumeration clears the mixer's armed state. A short, strain-relieved
  internal cable removes the failure mode that upstream hit repeatedly with a marginal
  external one.
- A Pi 5 sealed in a mixer chassis will thermally throttle. Airflow or a heatsink-to-
  chassis path is required, not optional.

## License

MIT, matching upstream. Copyright (c) 2026 Justin Morken. See [LICENSE](LICENSE).
