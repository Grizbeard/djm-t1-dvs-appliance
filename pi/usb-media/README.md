# USB drives

Plug in a USB drive with music on it and it appears in Mixxx under
**Computer > Removable Devices**, at boot or while Mixxx is running. Pull it and
it goes away. Nothing is written to it.

```sh
./install.sh      # on the Pi, from this directory; Mixxx can keep running
```

`install.sh` is safe to re-run, and mounts any drive already plugged in.

## How it works

The kiosk session has no desktop, so nothing automounts drives the way the Pi
desktop's file manager does. This replaces that at the system level, which works
at boot, before anyone logs in, and whichever session is running:

1. **`99-usb-media.rules`** matches a filesystem on a USB drive - on a partition,
   or on the whole disk if the drive has no partition table - and asks systemd
   to start `usb-media@<kernel name>.service`. udev cannot mount anything
   itself: it runs its programs in a private mount namespace and kills them
   after a few seconds.
2. **`usb-media@.service`** is bound to the device. It runs the script to mount
   when the drive appears, and stopping it - which systemd does by itself when
   the drive is pulled - unmounts.
3. **`usb-media`** mounts the drive at `/run/media/<user>/<label>-<serial>`.
4. **`/etc/tmpfiles.d/usb-media.conf`** creates `/run/media/<user>` at every
   boot. With Mixxx patch 0013 (Terminal-wide repository), Mixxx watches that
   directory and updates Removable Devices, Rekordbox and Serato as drives come
   and go, which it can only do if the directory is there before the first
   drive is.

## Why it mounts the way it does

- **Read-only, always.** These are other people's drives. A read-only drive can
  be pulled mid-set without damage, and Mixxx never writes to it. ext2/3/4 also
  get `noload`, so a journal left dirty by another machine is not replayed.
- **`/run/media/<user>/`**, because that is one of the places Mixxx looks for
  removable devices (with `/media` and `/media/<user>`), for Computer >
  Removable Devices and for exported Rekordbox (`PIONEER`) and Serato
  (`_Serato_`) libraries. `/run` is emptied every boot, so a power cut leaves no
  stale folders.
- **`<label>-<serial>`**, not just the label. Mixxx remembers beatgrids, cues
  and analysis by file path. Two drives both labelled `MUSIC` with the same
  folder layout would otherwise share one set, and the second DJ would get the
  first DJ's cue points. The serial is the filesystem's own UUID, up to 8
  characters.
- **Owned by the appliance user** (`MEDIA_USER` in `/etc/default/usb-media`),
  because FAT, exFAT, NTFS and HFS+ carry no usable Unix ownership.
- **`noexec,nosuid,nodev`**: nothing on a drive can run.

| Filesystem | |
|---|---|
| exFAT, FAT32 | yes |
| NTFS | yes (`ntfs3`, falling back to `ntfs-3g`) |
| ext2/3/4 | yes |
| HFS+ (older Mac drives) | yes, read-only |
| ISO 9660, UDF | yes |
| **APFS** (Mac drives formatted since 2017) | **no**: Linux cannot read it. Logged and skipped |

`journalctl -t usb-media` shows every mount, unmount and skipped drive.

## Things to know

- **Drives appear and disappear by themselves** in Computer > Removable
  Devices, Rekordbox and Serato, with Mixxx patch 0013. Without it, the list
  only updates when Removable Devices is collapsed and expanded again.
- **Pulling a drive stops anything playing from it.** Mixxx streams tracks from
  the drive as they play. Read-only mounting protects the drive, not the set.
- **Loading a track from a drive adds it to Mixxx's library**, and it stays
  there (shown as missing) after the drive leaves.
- **Mixxx's library root should not be the home directory**, or it scans source
  trees and build output. On the bench Pi it is `~/Music`, set in the
  `directories` table and in `[Playlist] Directory`.
- **`[Library] RescanOnStartup` stays 0.** Drives are browsed, not scanned, so
  a rescan only ever covers `~/Music`, and a startup rescan ends in a "Library
  scan finished" dialog that waits for OK on the touchscreen at every boot.
  Rescan from the library after adding music instead.
- **Moving an existing drive to these paths** (for example, from the desktop's
  `/media/<user>/<label>`) leaves its tracks in Mixxx's library pointing at the
  old path. With Mixxx stopped, rewriting `track_locations.location` and
  `.directory` from the old prefix to the new one keeps their cues, analysis and
  playlist entries. That was done once on the bench Pi.
