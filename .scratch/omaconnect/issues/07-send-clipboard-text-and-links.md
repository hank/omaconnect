# 07 — Send Clipboard Text and Links

**What to build:** Users can explicitly send current Wayland clipboard text or entered text and links to the selected reachable device.

**Blocked by:** 02 — Discover and Select Mobile Devices.

**Status:** completed

- [x] The user must explicitly trigger clipboard sharing; clipboard contents are not sent automatically.
- [x] Current clipboard text can be read through the supported Wayland clipboard tool and sent to the active device.
- [x] A user can enter text or a link when clipboard sharing is not appropriate.
- [x] Empty clipboard content, unavailable clipboard tooling, disconnected devices, and transfer failures have clear feedback.
- [x] Text and link arguments are passed without shell interpolation or truncation caused by quoting errors.
