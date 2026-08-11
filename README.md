# OmaConnect

OmaConnect is a native Omarchy plugin that exposes KDE Connect device state in
the existing Quickshell bar. It has one manifest, one shared `Service.qml`,
one `KdeConnectController`, and one per-monitor `BarWidget.qml`.

## Runtime

The controller enumerates devices through KDE Connect's session-bus daemon and
reads device, plugin, and battery properties with D-Bus `Properties.Get`.
Snapshots are keyed by the authoritative device ID. Reachability, pairing,
type, battery, charging state, and supported capabilities are kept separate
from operation state. Remote command listing and supported actions use
`kdeconnect-cli` only where it is the reliable current operation path. Native
actions are ping, text, ring, clipboard, file transfer, pairing, and remote
commands; command support is advertised by the live plugin list.

The bar uses Omarchy's `BarIconButton`, `KeyboardPanel`, `PanelKeyCatcher`,
`CursorSurface`, `Button`, separators, and tokenized `Color`/`Style`/`Border`
primitives. The shell owns focus, popout coordination, and multi-monitor
dismissal. OmaConnect never starts another Quickshell process.

## Safety

All asynchronous work is single-flight or generation-guarded and retains its
target device ID. Stale completions are ignored. User-facing failures are
categorized rather than displaying command stderr. Successful remote calls
say that the request was accepted; they do not claim remote completion.

Notification and SMS content is intentionally not part of this plugin. No data
is sent anywhere except to KDE Connect on the local session bus or via its CLI.
Success messages mean the local request was accepted, not that the remote
device completed it.

## Dependencies

The host must provide Omarchy's current Quickshell shell, `gdbus`, `sed`,
`grep`, `tr`, `kdeconnect-cli`, and a running KDE Connect session daemon.
Without the daemon or session bus the UI reports unavailable, rather than
claiming that there are zero devices. File transfer uses the native picker and
argument arrays; cancellation performs no operation.

## Install and operate

Place this directory at `~/.config/omarchy/plugins/omaconnect`, add the widget
to the Omarchy bar layout, and run `omarchy-restart-shell`. The shell IPC target
is `omaconnect` and supports `open`, `close`, `show`, `hide`, and `toggle`.

## Verification

Run `bash scripts/validate.sh`. It runs deterministic state tests, shell syntax
checks, the exact installed Omarchy plugin validator, and QML checks with the
Omarchy import path. Host-only `qmllint` import warnings are reported as such;
loader/runtime failures remain validation errors.
