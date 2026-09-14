# Bench test: channel-to-deck map

**Status: NOT DONE. This blocks all audio routing, on both the input and output side.**

Six USB channels in each direction is confirmed from two independent sources. Which
physical signal each channel carries is unknown, and cannot be determined from any
available source — the vendor's macOS driver exposes six anonymous channels per
direction with no terminal or channel-name information. Only a measurement answers it.

Full context: `external/djm-t1-linux/docs/INTERFACE-SPEC.md` section 6.

## Prior observations (upstream's capture, one turntable connected)

- Capture channels 0/1 and 4/5 carried signal.
- Capture channels 2/3 read near-silent with nothing connected.
- Host playback appeared to loop back onto capture channels 4/5.

## Working hypothesis (unverified)

| Capture pair | Guess |
|---|---|
| 0/1 | Channel 1 phono/line input |
| 2/3 | Channel 2 phono/line input — silent in the capture because only one deck was connected |
| 4/5 | Master or monitor return, fed from the analogue mix |

Consistent with both observations and with how a two-deck DVS mixer is laid out. Still a
guess.

## Equipment

- Both turntables connected, each with a record that plays.
- A distinct test tone for the output test.

## Procedure — inputs

Stream capture with per-channel level metering.
`external/djm-t1-linux/audio/djmt1-capture` prints per-channel levels.

1. Both decks stopped. Record the idle level of all six channels.
2. Play on **deck 1 only**. Record which pair moves.
3. Stop. Play on **deck 2 only**. Record which pair moves.
4. Both decks silent, raise the mixer's channel faders. Record whether any pair follows
   the analogue mix — that identifies the master/monitor return.
5. Repeat step 2 with the channel source selector set to PHONO, then LINE, then USB.
   Determine whether the USB capture feed is pre- or post-selector.

Step 5 matters more than it looks: in normal DVS use the mixer channel is set to USB so
it plays Mixxx's output, while the turntable still needs to reach the host as timecode.
If the capture feed is post-selector, that does not work and the routing has to change.

## Procedure — outputs

6. Emit a distinct tone on **one host playback pair at a time** (0/1, then 2/3, then 4/5).
7. For each, set each mixer channel's source selector to USB in turn, and record which
   mixer channel reproduces the tone.

## Results

Fill in, then delete the hypothesis section above.

### Capture (device to host)

| Pair | Signal | Confirmed by |
|---|---|---|
| 0/1 | | |
| 2/3 | | |
| 4/5 | | |

### Playback (host to device)

| Pair | Destination | Confirmed by |
|---|---|---|
| 0/1 | | |
| 2/3 | | |
| 4/5 | | |

### Selector dependency

- Is the USB capture feed pre- or post-source-selector?
- Does timecode reach the host while the channel source is set to USB?

## Follow-up

Once complete:

1. Record the result in `external/djm-t1-linux/docs/INTERFACE-SPEC.md` section 6 and
   delete its bench procedure.
2. Update `docs/dvs-timecode.md` and `audio/README.md` upstream.
3. Open the PR. This is the single most valuable thing that repository is missing.
4. Set Mixxx's Vinyl Control In 1/2 and Deck 1/2 outputs accordingly.
