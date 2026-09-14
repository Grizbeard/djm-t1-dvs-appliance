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

Mixxx needs a GUI. Decide between a small HDMI panel mounted in the chassis and a
headless setup driven entirely from the mixer's controls. The mapping covers browse,
load and transport, so a small display is sufficient for track selection.

## To record here

- [ ] Pi 5 model and RAM
- [ ] Storage — SD vs NVMe HAT (NVMe is worth it for library and waveform cache)
- [ ] Power supply decision
- [ ] Display decision
- [ ] Enclosure and mounting
- [ ] Measured temperatures under sustained load
- [ ] Whether xHCI isochronous streaming is stable (verify early)
