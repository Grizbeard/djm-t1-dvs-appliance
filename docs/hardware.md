# Hardware notes

A Raspberry Pi 5 mounted inside the DJM-T1 chassis, connected to the mixer's USB
interface by a short internal cable.

## Power

The DJM-T1 is mains-powered, so the Pi does not draw from it over USB and needs its own
supply. Decide whether to tap the mixer's internal supply or run a separate inlet, and
record the decision here.

## USB

- The Pi 5 has **no EHCI controller**. All four ports are on the RP1 southbridge's xHCI,
  reached over PCIe. Upstream's advice to "use a rear USB 2.0 port" reflects EHCI-era
  desktop testing and does not translate.
- High-speed isochronous under xHCI should be fine — 864 bytes/ms is nothing over the RP1
  link — but this is the hardware assumption most worth verifying early rather than at
  integration time. If it misbehaves, an intermediate USB 2.0 hub is the usual
  workaround.
- **Any USB re-enumeration clears the mixer's armed state**, and a marginal cable that
  keeps dropping the link keeps it gated shut. Upstream hit this repeatedly and it can
  wedge the device until a power cycle. A short, strain-relieved, internal cable turns
  their worst failure mode into a non-issue — one of the few ways this build is *easier*
  than a normal desktop setup.

## Thermal

A Pi 5 sealed in a mixer chassis will throttle. DVS plus USB isochronous plus thermal
throttling is a bad combination. Required:

- Airflow, or a conductive path from the Pi's heatsink to the chassis.
- `performance` CPU governor pinned (see `pi/config/`).
- Log `vcgencmd measure_temp` under sustained load before committing to an enclosure.

## Display and control

**Waveshare 8.8-DSI-TOUCH-A.** 8.8" IPS, native 480x1920 portrait, driven over DSI (not
HDMI) and mounted rotated 90 degrees to give the 1920x480 landscape the skin targets.
10-point capacitive touch; display IC OTA7290B, touch IC GT9271.

Three things it imposes on the rest of the build:

- **Its own 5V feed from the GPIO header**, at **>= 0.43 A**. The DSI ribbon carries no
  power, and under-feeding it fails to start or damages it. This is a PSU sizing input,
  not a detail.
- **A 22-pin reversed FFC cable** for Pi 5 - Pi 4 and earlier take the 15-pin part.
- **M2.5 mounting**, Pi to the back of the display, which largely settles how the two
  sit relative to each other inside the chassis.

Full setup, overlay lines and rotation in docs/bring-up.md Phase 2.

## To record here

- [ ] Pi 5 model and RAM
- [ ] Storage — SD vs NVMe HAT (NVMe is worth it for library and waveform cache)
- [ ] Power supply decision
- [x] Display decision — Waveshare 8.8-DSI-TOUCH-A (8.8" IPS, 480x1920 native, DSI, 10-point touch). See docs/bring-up.md Phase 2.
- [ ] Enclosure and mounting
- [ ] Measured temperatures under sustained load
- [ ] Whether xHCI isochronous streaming is stable (verify early)
