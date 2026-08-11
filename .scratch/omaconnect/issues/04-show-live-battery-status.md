# 04 — Show Live Battery Status

**What to build:** Users can see each selected phone's current charge and charging state in the topbar and popover, with meaningful visual thresholds.

**Blocked by:** 02 — Discover and Select Mobile Devices.

**Status:** completed

- [x] The active device card displays a 0–100 charge percentage and charging indicator.
- [x] The topbar preview reflects the lowest known battery among reachable devices.
- [x] Battery updates arrive from KDE Connect events without polling loops.
- [x] Battery colors follow the documented danger, warning, success, and charging rules.
- [x] Unknown, stale, or unavailable battery data is shown safely and never renders an invalid percentage.
