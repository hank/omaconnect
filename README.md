# OmaConnect

Control your phone and other devices from the Omarchy bar with KDE Connect.

KDE Connect is the cross-device layer underneath: it pairs your Linux desktop with Android, iPhone, Windows, and macOS devices for everyday features such as clipboard sharing, files, messages, and notifications. OmaConnect puts the most useful controls in one quick bar panel instead of making you open a separate app. Available features depend on what each device supports.

![OmaConnect screenshot](preview.png)

## Install

```bash
omarchy plugin add https://github.com/jitendradara12/omaconnect.git --enable --yes
```

## What OmaConnect Adds

- **At-a-glance status**: Battery, charging, cellular network, reachability, and pairing state.
- **Fast actions**: Ring a device, sync the clipboard, send a file, share text, or send a ping.
- **SMS access**: Open `kdeconnect-sms` for a selected paired device.
- **Native file picking**: Choose recent files from `~/Downloads`, `~/Documents`, `~/Pictures`, and `~/Videos` with Omarchy's lightweight menu.
- **Remote commands**: Discover and run commands configured on a paired device.
- **Pairing controls**: Pair and unpair devices with confirmation and visible status feedback.

OmaConnect is the Omarchy interface, not a replacement for KDE Connect. KDE Connect handles pairing and communication; this plugin makes those capabilities fast to reach from the bar.

## Shortcuts

Add to `~/.config/omarchy/shortcuts.lua`:

```lua
o.bind("SUPER + SHIFT + C", "Toggle OmaConnect", "omarchy-shell shell toggle omaconnect")
```

## Dependencies

Requires `kdeconnect`, `glib2`, `dbus`, and Omarchy's `omarchy-menu-select` command for file sharing.

The optional **Install Dependencies** action runs:

```bash
sudo pacman -S kdeconnect glib2 dbus
```

This uses Arch's trusted package manager with fixed package names from your configured repositories. It does not download and pipe a script from the internet. You can run the command yourself instead.

### Firewall (UFW)

Omarchy blocks incoming ports by default. Allow KDE Connect discovery and transfer ports:

![OmaConnect screenshot of allow in firewall](preview1.png)

_You can just click **"Allow in Firewall"** directly inside the OmaConnect panel if no devices appear. Or you can do it manually..._

```bash
sudo ufw allow 1714:1764/tcp comment 'KDE Connect'
sudo ufw allow 1714:1764/udp comment 'KDE Connect'
sudo ufw reload
```

## Update

```bash
omarchy plugin update omaconnect
```

## Uninstall

```bash
omarchy plugin remove omaconnect
```
