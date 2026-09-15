# Skin survey: Mixxx on a small touchscreen

Survey of candidate skins for the appliance's display, bundled and community.
Examined 2026-09-14.

## What this build actually needs on screen

External mixing ([ADR-003](decisions.md)) plus turntables driving playback removes most
of what a normal skin spends its pixels on. The mixer does EQ, faders, crossfader and
headphone cueing in analogue; the turntables do transport. What is left:

| Need | Why |
|---|---|
| Library browse + load | The dominant touch interaction. Wants large row targets. |
| Waveform + position | Glanceable, read-only. |
| **Vinyl control status** | Signal quality, lock state, timecode mode. The DVS troubleshooting surface. |
| Track metadata | BPM, key, time remaining. |
| Hotcues / loops | Optional. |

So the work is mostly **deletion, then enlargement** — not building new widgets.

## Bundled skins

| Skin | Minimum size | Hide toggles | Centralised sizes |
|---|---|---|---|
| Deere | `1008×550` preferred, no hard floor | 25 | **Yes, ~15 variables** |
| Tango | `1008×500` hard | 25, best coverage | No |
| LateNight | `1280×668` hard | 25 | No |
| Shade | none declared | few | No |
| LateNightQML | n/a | n/a | n/a |

Deere centralises every button dimension in variables at the top of `skin.xml`
(`SmallSquareButtonMinimumSize` `15,15`, `SquareButtonMinimumSize` `22,22`,
`WideButtonMinimumSize` `40,22`, and about a dozen more), so enlarging every touch
target is one edit. Tango has the better philosophy for this build — its header
describes it as "an extension for your controller, in a way that almost all duplicate
controls can be removed from screen" — but sizes widgets per-widget in QSS.

`LateNightQML` is gated behind both a `MIXXX_USE_QML` build flag and `--developer` at
runtime (`src/skin/skinloader.cpp:270`), and its C++→QML proxy surface is incomplete.
Strategically where Mixxx is heading, and hot-reloadable, but not a first pass.

**1008 px wide is the floor for bundled skins.** It is *not* a floor in general — see
below.

## Community skins

| Skin | Min size | Base | Last activity | ★ | License |
|---|---|---|---|---|---|
| [Pioneered](https://github.com/timewasternl/Pioneered) | **480×420** | scratch | 2024-11-21 (`b1b6186`) | 139 | GPL-3.0 |
| [Pioneered — marcosseris fork](https://github.com/marcosseris/Pioneered) | 480×420 | fork | **2026-09-14** (`7b14b6e`) | 1 | GPL-3.0 |
| [Pioneered-Plus](https://github.com/bencejuhaasz/Pioneered-Plus) | — | extension | 2024-02-19 | 33 | GPL-3.0 |
| [Mobile Deere](https://mixxx.discourse.group/t/mobile-deere-skin-for-8-touch-screen/27917) | ~800×480 | Deere | 2026-09-13 | forum | — |
| [LateNight-RPI](https://mixxx.discourse.group/t/compact-skin-for-raspberry-pi-10-1-touch-display/28955) | `640×319` | LateNight | 2024-08 | forum | — |
| [threere](https://github.com/jasalt/mixxx-threere-theme) | small laptop | — | 2017 | 2 | none |

GPL-3.0 is compatible with Mixxx's GPL-2.0-**or-later**, and skins are data rather than
linked code in any case.

No skin named "MixxxBerry" exists on GitHub, the Mixxx forums, or gnome-look. The
closest matches are Mobile Deere and LateNight-RPI.

### The distinction that matters: shrinking vs. touch-sizing

Two different things get called "small screen support":

- **Mobile Deere** and **LateNight-RPI** *shrink the layout*. Mobile Deere still carries
  Deere's fixed `15,15` button variables unchanged, so on a small panel the targets are
  the same mouse-sized 15 px they always were — arguably worse for touch, not better.
- **Pioneered** was *designed at* 480×420. Its widgets use expanding size policies
  (`0me`) with row heights of 25–50 px rather than fixed small squares, so elements grow
  with the window instead of staying pinned at mouse size.

That difference is why the headline minimum resolution is a poor way to choose.

### The marcosseris fork

Actively developed — pushed the same day this survey was written. Targets Mixxx 2.5.0 on
Raspberry Pi 4B+ with 64-bit RPi OS trixie, and ships prebuilt arm64 packages. Adds over
the original: an on-screen keyboard, a system/settings menu, a wifi page, an update page,
a touch-optimised library table, USB automount (`pi/`), and **nineteen Mixxx source
patches** (`mixxx-patch/`).

Those patches split cleanly for our purposes:

| Generally useful to any Pi appliance | DDJ-400 / rekordbox specific |
|---|---|
| `search-osk` — on-screen keyboard for search | `rekordbox-*` (5 patches) |
| `perf-render-repaint` — Pi rendering performance | `jog-nudge` |
| `library-ui` — touch library | `hold-to-restart` |
| `system-menu`, `update-page` — appliance shell | `usb-browse*`, `usb-force-eject` |
| `pdb-corruption-hardening` | `beatgrid-ticks` (XDJ-style markers) |

It is a **patched Mixxx**, not just a skin. Treat the skin and the patches as separate
decisions — the skin can be adopted without the patches.

## Recommendation

**Start from Pioneered.** It is purpose-built for a Pi standalone setup, its stated goal
("extend a MIDI controller") is the external-mixing philosophy this build needs, its
480×420 floor leaves large headroom to enlarge touch targets at any panel, and 139 stars
means real users have shaken out the bugs.

Caveats:

- The popular original is ~2 years stale and skin schemas drift across Mixxx releases.
  Test it against the Mixxx version actually being shipped before committing.
- It is styled after a Pioneer *controller* — jog wheels, performance pads. For DVS with
  turntables much of that is dead weight, so expect deletion work regardless.
- Evaluate the marcosseris fork for the appliance-generic pieces (on-screen keyboard
  especially — a headless touch box has no other way to type a search).

## Touch findings from the community

Worth more than the skin list itself.

- **Mixxx has no touchscreen mode.** Stated outright by several Pi builders.
- **Right-click context menus are the sore point.** The Pi's long-press timing "times out
  too fast", and Mixxx puts a lot behind context menus (track menu especially). One
  builder mapped MIDI buttons to invoke the context menu as a workaround. **We have spare
  DJM-T1 buttons and unmapped performance pads** — a concrete use for them, and it
  should be designed into the mapping rather than bolted on.
- The skin settings menu misbehaves on Pi (reported by the Mobile Deere author).
- A Pi 4 takes up to 2 s to execute two MIDI functions bound to one button. A Pi 5 should
  do better, but prefer one action per button.
- Upstream [issue #11846](https://github.com/mixxxdj/mixxx/issues/11846) tracks wanting a
  small-screen default skin, so this is a recognised gap rather than a solved problem.

## The gap for this build

Every community skin surveyed is a **controller companion**, built for jog wheels and
pads. None was built for DVS, so none surfaces vinyl control status — signal quality,
lock state, timecode mode.

That is the one thing on screen that cannot be read off the mixer or the turntables, and
it is the genuine delta between any of these skins and what this appliance needs.

## Display choice

Still open in [hardware.md](hardware.md). Now that community skins go to 480×420, a small
panel is viable and the earlier "buy at least 1280×800" conclusion no longer holds. The
remaining argument for a larger panel is touch-target size rather than whether a skin
fits: at 7"/1024×600, a 48 px target is about 7 mm, below the ~9 mm that finger targets
generally want.

## Local copies

Cloned/downloaded to the session scratchpad for comparison, not vendored here (GPL-3,
and better referenced by URL than copied):

```
pioneered-upstream      b1b6186  2024-11-21   635K
pioneered-marcosseris   7b14b6e  2026-09-14   1.6M
mobile-deere            +QEffect v10          1.5M
latenight-rpi           2024-08               4.4M
```

Skins are pure data, so `_localbuild/skinshot.ps1` in the Mixxx tree captures a skin
with no rebuild — the fast way to compare these side by side.
