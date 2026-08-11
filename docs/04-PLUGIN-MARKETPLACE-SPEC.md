# 04. Omarchy Plugin Marketplace Specification

This document details the metadata schema, repository layout, and publishing workflow required for publishing OmaConnect on the official **Omarchy Plugin Marketplace** ([omarchyplugins.com](https://omarchyplugins.com/publish.html) / `HANCORE-linux/omarchy-plugin-marketplace`).

---

## 1. `plugin.json` Schema Specification

Every Omarchy plugin MUST include a valid `plugin.json` file in its root directory.

### Mandatory Fields:
```json
{
  "id": "omaconnect",
  "name": "OmaConnect",
  "version": "1.0.0",
  "description": "Native KDE Connect integration plugin for Omarchy topbar & Quickshell",
  "author": "User",
  "repository": "https://github.com/user/omaconnect",
  "license": "MIT",
  "category": "system",
  "entry": "main.qml",
  "icon": "phone-symbolic",
  "keywords": [
    "kdeconnect",
    "mobile",
    "phone",
    "battery",
    "clipboard",
    "quickshell",
    "omarchy"
  ],
  "dependencies": {
    "system": [
      "kdeconnect",
      "wl-clipboard"
    ],
    "quickshell": ">=0.1.0"
  },
  "minOmarchyVersion": "4.0.0"
}
```

---

## 2. Directory Layout Requirement for Marketplace

The marketplace installer clones and loads plugins from `~/.config/omarchy/plugins/`:

```
~/.config/omarchy/plugins/omaconnect/
├── plugin.json                 # Required: Manifest
├── main.qml                    # Required: QML Entry point
├── components/                 # QML subcomponents
│   ├── BarButton.qml
│   ├── PopoverWindow.qml
│   ├── DeviceCard.qml
│   ├── BatteryBar.qml
│   ├── ActionGrid.qml
│   └── CommandRunner.qml
├── scripts/                    # Subprocess helper scripts
│   ├── kdeconnect_bridge.sh
│   └── share_file.sh
├── assets/                     # Icons & screenshots
│   ├── icon.svg
│   └── screenshot.png
└── README.md                   # Plugin user manual
```

---

## 3. Marketplace Publishing Checklist

Follow these steps to submit OmaConnect to `omarchyplugins.com`:

1. **Local Validation**:
   - Ensure `plugin.json` validates against the schema above.
   - Verify `qs -p main.qml` loads without QML syntax warnings or missing module errors.
2. **Push to Public GitHub**:
   - Commit code and tag release version `v1.0.0`.
   - Add a high-quality screenshot (`assets/screenshot.png`) showcasing the top bar item and open popover.
3. **Submit Plugin Issue**:
   - Navigate to [omarchy-plugin-marketplace issues](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).
   - Fill out the submission form with:
     - Plugin ID: `omaconnect`
     - Repository URL: `https://github.com/user/omaconnect`
     - Description: KDE Connect topbar widget & popup for Omarchy.
     - Category: System / Utilities.
4. **Verification by Marketplace Maintainers**:
   - Automated GitHub Action verifies `plugin.json` metadata.
   - Upon PR merge, OmaConnect becomes discoverable on `omarchyplugins.com` and installable via `omarchy-plugin install omaconnect`.
