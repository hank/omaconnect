# 06 — Ring and Ping the Active Device

**What to build:** Users can trigger Find My Phone ringing or send a short notification ping to the selected reachable device from the popover.

**Blocked by:** 02 — Discover and Select Mobile Devices.

**Status:** completed

- [x] Ring Phone is available only for a reachable selected device and launches the supported KDE Connect action.
- [x] Send Ping lets the user provide or confirm the message before sending it.
- [x] Each action has disabled, in-progress, success, and failure states.
- [x] Repeated clicks cannot launch duplicate concurrent actions for the same operation.
- [x] Command failures are surfaced in the popover without terminating the plugin.
