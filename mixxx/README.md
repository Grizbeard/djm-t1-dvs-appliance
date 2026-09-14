# Mixxx configuration

## Controller mapping — external mixing variant

Per [ADR-003](../docs/decisions.md), this build uses **external mixing**: the DJM-T1 does
EQ, faders, crossfader and headphone cueing in analogue.

The upstream mapping (`external/djm-t1-linux/mixxx/Pioneer-DJM-T1.midi.xml`) is built for
*internal* mixing and maps the mixer section to Mixxx's software mixer. Using it here
would double-attenuate every channel — once in Mixxx, once in the analogue path.

The variant that belongs here keeps:

- browse encoder (rotate + push)
- LOAD buttons
- deck transport: play, cue, sync
- optionally the FX and performance sections, once the SHIFT layer is mapped

and drops:

- trim, 3-band EQ, volume faders, crossfader — analogue
- CUE / PFL buttons — headphone cueing is analogue and local to the mixer

**Not written yet.** Derive it from the upstream mapping rather than from scratch; the
control numbers are verified and documented in
`external/djm-t1-linux/docs/midi-map.md`.

## Sound hardware

Blocked on the channel-map bench test ([docs/bench/channel-map.md](../docs/bench/channel-map.md)).
Once the map is known, set in Preferences → Sound Hardware:

| Mixxx assignment | DJM-T1 channel pair |
|---|---|
| Deck 1 output | TBD |
| Deck 2 output | TBD |
| Vinyl Control In 1 | TBD |
| Vinyl Control In 2 | TBD |

## Vinyl control

Preferences → Vinyl Control:

- **Timecode type:** the DJM-T1 is a Traktor Scratch-era mixer, so the control vinyl is
  most likely Traktor MK1 or MK2. Mixxx's xwax decodes `traktor_a`/`traktor_b`,
  `traktor_mk2_a`/`traktor_mk2_b`/`traktor_mk2_cd`, Serato 2nd Ed. A/B/CD, MixVibes, and
  Pioneer RekordBox side A.
- Set lead-in, and choose absolute (position) or relative (scratch-only) mode.
- Vinyl control is compiled in by default (`VINYLCONTROL` in Mixxx's CMake).

## Mixxx build

Building from source on the Pi for a current release. Record the configure line, the
version, and any aarch64-specific notes here once established.
