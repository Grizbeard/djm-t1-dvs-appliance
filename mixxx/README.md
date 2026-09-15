# Mixxx configuration

## Controller mapping — external mixing variant

Per [ADR-003](../docs/decisions.md), this build uses **external mixing**: the DJM-T1 does
EQ, faders, crossfader and headphone cueing in analogue.

The upstream mapping (`external/djm-t1-linux/mixxx/Pioneer-DJM-T1.midi.xml`) is built for
*internal* mixing and maps the mixer section to Mixxx's software mixer. Using it here
would double-attenuate every channel — once in Mixxx, once in the analogue path.

`controllers/Pioneer-DJM-T1-DVS.midi.xml` is that variant. It keeps:

- browse encoder (rotate + push), plus the Deck A/C auto-loop encoder as a fast
  page-scroll
- LOAD buttons
- deck transport: play, cue, sync
- **digital-vinyl mode switching** — vinyl on/off, ABS/REL/CONST, passthrough
- **library focus cycling and the track context menu**, on hardware buttons

and drops:

- trim, 3-band EQ, volume faders, crossfader — analogue
- CUE / PFL buttons — headphone cueing is analogue and local to the mixer

Two design notes. The DVS controls are on hardware rather than on screen because they
are set-once mode switches and the deck info row has no horizontal room for them at
1024px; the skin shows the resulting *state* instead. And `[Library] show_track_menu`
is bound to SNAP/QUANTIZE because Mixxx has no touchscreen mode and much of the library
lives behind a right-click menu that a Pi touch panel cannot reliably summon — other Pi
builders hit the same wall and solved it the same way.

Control numbers come from the full-panel calibration in
`external/djm-t1-linux/docs/midi-map.md`. Button assignments for the DVS controls are
proposals — they use buttons that send MIDI but have no analogue function here, and can
be moved freely.

**Unverified on hardware:** the script has not been run in Mixxx, and the LED `<output>`
blocks are proposed rather than confirmed (only the CUE-button LEDs are known-good
upstream).

## Skin

`skins/Pioneered-DVS/` — see its [README](skins/Pioneered-DVS/README.DVS.md).

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
