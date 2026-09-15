// Pioneer DJM-T1 - DVS / external-mixing mapping for Mixxx
//
// Companion to Pioneer-DJM-T1-DVS.midi.xml. See that file's <description> and
// ../../docs/decisions.md ADR-003 for why the mixer section is deliberately
// unmapped.
//
// Every button on the DJM-T1 emits Note-On velocity 0x7F immediately followed by
// velocity 0x00 on a single press, so binding a toggle control directly would
// switch it on and straight back off. Everything here acts on the press (0x7F)
// edge only. Controls that want both edges (cue_default) are mapped directly in
// the XML instead.
//
// Requires the djm_midi bridge running: the mixer transmits no MIDI otherwise.

var DJMT1DVS = {};

DJMT1DVS.init = function(id, debugging) {};

DJMT1DVS.shutdown = function() {};

// Flip a binary control on the button-press edge.
DJMT1DVS.toggle = function(group, key, value) {
    if (value === 0x7F) {
        engine.setValue(group, key, engine.getValue(group, key) ? 0 : 1);
    }
};

// ---- transport ------------------------------------------------------------
// Kept even though the turntable drives playback in absolute mode: still wanted
// for cueing, for passthrough, and whenever a deck is running without timecode.

DJMT1DVS.togglePlay = function(channel, control, value, status, group) {
    DJMT1DVS.toggle(group, "play", value);
};

DJMT1DVS.toggleSync = function(channel, control, value, status, group) {
    DJMT1DVS.toggle(group, "sync_enabled", value);
};

// ---- digital vinyl --------------------------------------------------------
// These live on hardware rather than on screen. They are set-once mode switches,
// and the deck info row has no horizontal room for them at 1024px. The skin shows
// the resulting *state* instead (templates/dvs_status.xml).

// Enable/disable timecode control for a deck.
DJMT1DVS.toggleVinyl = function(channel, control, value, status, group) {
    DJMT1DVS.toggle(group, "vinylcontrol_enabled", value);
};

// Pass the deck's input straight through, bypassing the software deck. This is
// how you play the actual record on the platter rather than a file.
DJMT1DVS.togglePassthrough = function(channel, control, value, status, group) {
    DJMT1DVS.toggle(group, "passthrough", value);
};

// Cycle absolute -> relative -> constant. Mixxx defines these as 0/1/2.
DJMT1DVS.cycleVinylMode = function(channel, control, value, status, group) {
    if (value !== 0x7F) {
        return;
    }
    var mode = engine.getValue(group, "vinylcontrol_mode");
    engine.setValue(group, "vinylcontrol_mode", (mode + 1) % 3);
};

// ---- library --------------------------------------------------------------

// Open the track context menu from hardware.
//
// This exists because Mixxx has no touchscreen mode and a great deal of the
// library lives behind a right-click menu that a resistive/capacitive panel on a
// Pi cannot reliably summon - long-press timing times out first. Other Pi builders
// hit the same wall and solved it exactly this way. Binding it to a spare mixer
// button makes the menu reachable without a mouse.
DJMT1DVS.showTrackMenu = function(channel, control, value, status, group) {
    if (value === 0x7F) {
        engine.setValue("[Library]", "show_track_menu", 1);
    }
};

// Move keyboard focus between the sidebar, the track table and the search box,
// so the whole library is navigable from the mixer with nothing else attached.
DJMT1DVS.focusForward = function(channel, control, value, status, group) {
    if (value === 0x7F) {
        engine.setValue("[Library]", "MoveFocusForward", 1);
    }
};

DJMT1DVS.focusBackward = function(channel, control, value, status, group) {
    if (value === 0x7F) {
        engine.setValue("[Library]", "MoveFocusBackward", 1);
    }
};
