# 10 — Surface Incoming Phone Notifications

**What to build:** Incoming KDE Connect phone notifications, including SMS notifications when exposed by the daemon, appear in a bounded privacy-conscious feed and update in real time.

**Blocked by:** 03 — Keep Device Presence Live.

**Status:** completed

- [x] Incoming notification events are parsed from the live KDE Connect signal stream.
- [x] Notifications identify their source device and present enough title/body context to be useful.
- [x] The feed is bounded, dismissible, and does not expose notification contents in the topbar by default.
- [x] Malformed events and monitor interruptions do not crash the plugin.
- [x] The UI does not claim SMS reply or conversation features that the supported KDE Connect interface does not provide.

