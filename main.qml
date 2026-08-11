import QtQuick
import Quickshell
import Quickshell.Io
import "./components" as Components

Scope {
    id: root

    // --- State Properties ---
    property bool isPopoverOpen: false

    // --- KDE Connect Controller Instance ---
    Components.KdeConnectController {
        id: kdeController
    }

    // --- Topbar Bar Button ---
    Components.BarButton {
        id: barButton
        activeDeviceCount: kdeController.activeDeviceCount
        lowestBattery: kdeController.lowestBattery
        isConnected: kdeController.isConnected
        daemonAvailable: kdeController.daemonAvailable && kdeController.sessionBusAvailable
        isPopoverOpen: root.isPopoverOpen
        activeDevice: kdeController.activeDevice

        onClicked: {
            root.isPopoverOpen = !root.isPopoverOpen;
        }
    }

    // --- Interactive Popover Window Shell ---
    Components.PopoverWindow {
        id: popoverWindow
        isOpen: root.isPopoverOpen
        isConnected: kdeController.isConnected
        daemonAvailable: kdeController.daemonAvailable
        sessionBusAvailable: kdeController.sessionBusAvailable
        allDevices: kdeController.allDevices
        connectedDevices: kdeController.reachableDevices
        activeDevice: kdeController.activeDevice
        statusMessage: kdeController.statusMessage
        pairingStates: kdeController.pairingStates
        notifications: kdeController.notifications

        onCloseRequested: {
            root.isPopoverOpen = false;
        }

        onRefreshRequested: {
            kdeController.refresh();
        }

        onDeviceSelected: device => {
            if (device && device.id) {
                kdeController.selectDevice(device.id);
            }
        }

        onRingDeviceRequested: deviceId => {
            kdeController.ringDevice(deviceId);
        }

        onPingDeviceRequested: deviceId => {
            kdeController.pingDevice(deviceId);
        }

        onShareTextRequested: (deviceId, text) => {
            kdeController.shareText(deviceId, text);
        }

        onPairDeviceRequested: deviceId => {
            kdeController.pairDevice(deviceId);
        }

        onUnpairDeviceRequested: deviceId => {
            kdeController.unpairDevice(deviceId);
        }

        onDismissNotificationRequested: notificationId => {
            kdeController.dismissNotification(notificationId);
        }

        onClearAllNotificationsRequested: () => {
            kdeController.clearAllNotifications();
        }
    }
}


