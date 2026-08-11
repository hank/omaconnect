Created At: 2026-08-11T18:36:50Z
Completed At: 2026-08-12T00:06:48Z
File Path: `file:///home/sastauser/code/omaconnect/.scratch/omaconnect/issues/03-keep-device-presence-live.md`

# 03 — Keep Device Presence Live

**What to build:** Device presence and reachability stay current while OmaConnect is running, including reconnects and monitor recovery.

**Blocked by:** 02 — Discover and Select Mobile Devices.

**Status:** completed

- [x] Device-added, device-removed, and reachability changes update the topbar and popover without restarting the plugin.
- [x] A disconnected active device is clearly marked and cannot receive actions until it is reachable again.
- [x] Reconnecting a device restores its available state without creating duplicate device entries.
- [x] The real-time event process is line-safe, reports malformed input without crashing, and can recover after unexpected exit.
- [x] The selected-device state remains valid when another device changes presence.
