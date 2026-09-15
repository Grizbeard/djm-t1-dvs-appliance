# Pioneered-DVS

A DVS-oriented variant of the **Pioneered** skin for the DJM-T1 appliance.

## Licensing — read this first

This directory is a derivative of [Pioneered](https://github.com/timewasternl/Pioneered)
by Sven Boekelder, which is **GPL-3.0**. It therefore remains GPL-3.0, *not* the MIT
licence that covers the rest of this repository. `LICENSE` in this directory is
Pioneered's and governs this subtree.

The upstream `README.md` here is Pioneered's own and has been left in place.

## What changed from Pioneered

Deliberately small. Pioneered was already built to extend a controller and already fits
480×420, so the DVS adaptation is additive rather than a redesign.

1. **Per-deck timecode status** — `templates/dvs_status.xml`, placed in each deck's info
   row, styled in `style.qss`.
2. **`[VinylControl],show_vinylcontrol` defaults to 1** in `skin.xml`, since the DVS
   strip is the point of the variant.
3. Manifest retitled and attributed.

## Why the status indicator exists

Every community small-screen Mixxx skin is a *controller companion* built for jog wheels
and performance pads, so none of them surfaces vinyl control state — the survey in
[../../docs/skins.md](../../docs/skins.md) covers this. On a DVS appliance that is the
one thing on screen you cannot read off the mixer or the turntables: whether Mixxx is
actually locked onto the timecode.

It binds to `[ChannelN],vinylcontrol_status`, whose values are defined in Mixxx's
`src/vinylcontrol/defs_vinylcontrol.h`:

| Value | Shown | Colour | Meaning |
|---|---|---|---|
| 0 | `OFF` | grey | Vinyl control disabled for this deck |
| 1 | `OK` | green | Timecode locked and tracking |
| 2 | `WARN` | amber | Signal degraded — stylus, level, worn record |
| 3 | `ERR` | red | No usable timecode |

Rendered as coloured text rather than pixmaps, so it needs no new image assets and stays
readable at arm's length.

It is read-only: there is no `ButtonState` connection, so the widget has no control to
write to and a stray touch does nothing.

## What is *not* here, and why

The vinyl on/off, mode (ABS/REL/CONST) and passthrough controls are **not** on screen.
They are on the DJM-T1's own buttons in
[`../../controllers/Pioneer-DJM-T1-DVS.midi.xml`](../../controllers/Pioneer-DJM-T1-DVS.midi.xml).

Two reasons. They are set-once mode switches rather than things touched mid-mix, so
hardware suits them better. And there is genuinely no room: an earlier revision put all
four widgets in the deck info row and at 1024×600 the labels clipped and the status field
disappeared entirely. Controls on hardware, state on screen.

## Verified / not verified

**Verified** by rendering at 1024×600 against Mixxx `main` with the screenshot harness:
the skin loads, the template parses, the indicator sits correctly in both decks' info
rows without disturbing the tempo/BPM block, and the `displayValue="0"` styling applies.

**Not verified:** the OK / WARN / ERR states and their colours. Those need a real
timecode signal, so they are confirmed by construction only — the QSS selectors follow
the same `displayValue` pattern the rest of the skin uses for `value`, but nothing has
exercised states 1–3.

The one pre-existing warning during load (`Invalid <TooltipId> ... track_number` at
`deck.xml:99`) is inherited from upstream Pioneered and is not caused by these changes.

## Installing

Copy this directory into Mixxx's skins path, or symlink it:

```bash
ln -s "$PWD/mixxx/skins/Pioneered-DVS" ~/.mixxx/skins/Pioneered-DVS
```

Then pick **Pioneered-DVS** in Preferences → Interface.
