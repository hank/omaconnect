# 08 — Choose and Send a File

**What to build:** Users can choose a local file through a native Wayland-compatible picker and explicitly send it to the selected device.

**Blocked by:** 02 — Discover and Select Mobile Devices.

**Status:** completed

- [x] Send File opens an available native file chooser only when the user activates it.
- [x] Cancelling the chooser leaves the popover usable and does not start a transfer.
- [x] A selected file is sent to the active device through KDE Connect.
- [x] Check missing picker tools, unreadable files, disconnected devices, and transfer launch failures are reported clearly.
- [x] File paths are passed safely without shell interpolation.
