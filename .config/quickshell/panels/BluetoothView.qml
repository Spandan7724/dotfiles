import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

// Bluetooth devices through BlueZ (Quickshell.Bluetooth). Scans while open.
// PIN and passkey confirmations are answered by blueman-applet's agent.
ColumnLayout {
    id: root

    property bool opened: false
    signal closeRequested()

    spacing: 10

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter !== null && adapter.enabled
    readonly property var devices: adapter && adapter.devices ? adapter.devices.values : []

    function isSaved(d) { return d.paired || d.bonded || d.trusted }

    readonly property var savedDevices: devices
        .filter(d => d && isSaved(d))
        .slice()
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))

    // Unnamed devices only report their address; they are rarely what anyone
    // is trying to pair, so they stay hidden.
    readonly property var nearbyDevices: devices
        .filter(d => d && !isSaved(d) && d.deviceName && d.deviceName !== d.address.replace(/:/g, "-"))
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name))

    // Address of a device being paired from this panel. Once BlueZ reports it
    // paired it moves to "My devices", whose row trusts and connects it.
    property string pendingPair: ""

    readonly property int connectedCount: savedDevices.filter(d => d.connected).length

    function deviceIcon(icon) {
        const name = icon || ""
        if (name.indexOf("headset") !== -1) return "󰋋"
        if (name.indexOf("headphone") !== -1 || name.indexOf("audio") !== -1) return "󰋋"
        if (name.indexOf("mouse") !== -1) return "󰍽"
        if (name.indexOf("keyboard") !== -1) return "󰌌"
        if (name.indexOf("phone") !== -1) return "󰏲"
        if (name.indexOf("computer") !== -1) return "󰟀"
        if (name.indexOf("gaming") !== -1 || name.indexOf("joystick") !== -1) return "󰊴"
        if (name.indexOf("watch") !== -1) return "󰖉"
        return "󰂯"
    }

    function subtitle(d) {
        if (d.pairing) return "Pairing…"
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…"
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
        if (d.connected)
            return d.batteryAvailable ? "Connected · " + Math.round(d.battery * 100) + "% battery" : "Connected"
        return isSaved(d) ? "Saved" : ""
    }

    function activate(d) {
        if (d.connected) {
            d.disconnect()
        } else if (isSaved(d)) {
            d.connect()
        } else {
            pendingPair = d.address
            d.pair()
        }
    }

    function status() {
        if (!adapter) return "No Bluetooth adapter found"
        if (!enabled) return "Turned off"
        if (connectedCount === 1) return "Connected to " + savedDevices.find(d => d.connected).name
        if (connectedCount > 1) return connectedCount + " devices connected"
        return adapter.discovering ? "Searching for devices…" : "On"
    }

    // Discover only while the panel is showing.
    Binding {
        when: root.adapter !== null
        target: root.adapter
        property: "discovering"
        value: root.opened && root.enabled
    }

    PanelHeader {
        Layout.fillWidth: true
        icon: root.enabled ? "󰂯" : "󰂲"
        title: "Bluetooth"
        status: root.status()
        checked: root.enabled
        onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.alpha(Theme.outline, 0.25)
    }

    Text {
        visible: !root.enabled
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        horizontalAlignment: Text.AlignHCenter
        text: root.adapter ? "Turn Bluetooth on to see devices" : "No Bluetooth adapter found"
        color: Theme.muted
        font.pixelSize: 12
    }

    Flickable {
        visible: root.enabled
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 380)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list

            width: parent.width
            spacing: 2

            Text {
                visible: root.savedDevices.length > 0
                text: "My devices"
                color: Theme.muted
                font.pixelSize: 11
                font.weight: Font.DemiBold
                Layout.leftMargin: 10
                Layout.bottomMargin: 2
            }

            Repeater {
                model: root.savedDevices

                ListRow {
                    required property var modelData

                    Layout.fillWidth: true
                    icon: root.deviceIcon(modelData.icon)
                    title: modelData.name
                    subtitle: root.subtitle(modelData)
                    active: modelData.connected
                    actionText: "Forget"
                    onClicked: root.activate(modelData)
                    onActionClicked: modelData.forget()

                    Component.onCompleted: {
                        if (modelData.address !== root.pendingPair)
                            return
                        root.pendingPair = ""
                        modelData.trusted = true
                        if (!modelData.connected)
                            modelData.connect()
                    }
                }
            }

            Text {
                text: root.nearbyDevices.length > 0 ? "Available" : "Looking for devices…"
                color: Theme.muted
                font.pixelSize: 11
                font.weight: Font.DemiBold
                Layout.leftMargin: 10
                Layout.topMargin: root.savedDevices.length > 0 ? 8 : 0
                Layout.bottomMargin: 2
            }

            Repeater {
                model: root.nearbyDevices

                ListRow {
                    required property var modelData

                    Layout.fillWidth: true
                    icon: root.deviceIcon(modelData.icon)
                    title: modelData.name
                    subtitle: root.subtitle(modelData) || "Click to pair"
                    busy: modelData.pairing
                    onClicked: root.activate(modelData)
                }
            }
        }
    }

    FooterLink {
        text: "Bluetooth settings"
        onClicked: {
            Quickshell.execDetached(["blueman-manager"])
            root.closeRequested()
        }
    }
}
