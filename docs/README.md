# OmaConnect Documentation Index

Welcome to the **OmaConnect** documentation repository. This directory contains complete technical specifications, architectural designs, QML patterns, D-Bus protocols, and component blueprints.

Any developer or AI coding agent with a fresh context window can read these documents to gain 100% complete context on how OmaConnect is structured, built, tested, and published.

---

## Document Map

| Document | Description | Key Topics |
| :--- | :--- | :--- |
| **[01-ARCHITECTURE-OVERVIEW.md](file:///home/sastauser/code/omaconnect/docs/01-ARCHITECTURE-OVERVIEW.md)** | System architecture & runtime model | Quickshell engine, Hyprland desktop, IPC data flow, dependencies |
| **[02-KDE-CONNECT-SPEC.md](file:///home/sastauser/code/omaconnect/docs/02-KDE-CONNECT-SPEC.md)** | KDE Connect API & Protocol Reference | D-Bus interfaces, `kdeconnect-cli` commands, signal handling |
| **[03-QUICKSHELL-QML-PATTERNS.md](file:///home/sastauser/code/omaconnect/docs/03-QUICKSHELL-QML-PATTERNS.md)** | Quickshell & QML UI standards | Scope, Process execution, Glassmorphic styling, HSL colors, animations |
| **[04-PLUGIN-MARKETPLACE-SPEC.md](file:///home/sastauser/code/omaconnect/docs/04-PLUGIN-MARKETPLACE-SPEC.md)** | Omarchy Plugin Marketplace Specs | `plugin.json` schema, directory structure, submission workflow |
| **[05-COMPONENT-BLUEPRINTS.md](file:///home/sastauser/code/omaconnect/docs/05-COMPONENT-BLUEPRINTS.md)** | Detailed implementation specs for components | QML file contracts, props, signals, child items |

---

## Quick Orientation for AI Agents & Developers

1. **What is OmaConnect?**
   OmaConnect is a native topbar widget and drop-down popover menu for **Omarchy 4 (Omarchy Quattro)**, which uses **Quickshell** for Hyprland/Wayland desktop shell management.
2. **What does it do?**
   It connects your Linux desktop to your Android or iOS phone via KDE Connect (`kdeconnectd`). It displays battery levels, rings your phone ("Find My Phone"), shares files and links, syncs Wayland clipboards, executes remote scripts, and shows SMS notifications.
3. **How does it talk to KDE Connect?**
   It uses a hybrid IPC model: `Quickshell.Io.Process` runs `kdeconnect-cli` for one-shot actions and device discovery, while listening to `org.kde.kdeconnect` D-Bus session events for real-time battery and notification updates.
4. **How do I run and test it locally?**
   Run `qs -p main.qml` from the repository root to launch the plugin in Quickshell test mode.
