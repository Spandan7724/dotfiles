import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

// Wi-Fi list backed by NetworkManager through Quickshell.Networking. Secured
// networks that are not saved yet ask for the password inline.
ColumnLayout {
    id: root

    property bool opened: false
    signal closeRequested()

    spacing: 10

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: findDevice(DeviceType.Wifi)
    readonly property var wiredDevice: findDevice(DeviceType.Wired)
    readonly property var networks: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []

    // Connected first, then saved networks, then by signal strength.
    readonly property var sortedNetworks: networks
        .filter(n => n && n.name)
        .slice()
        .sort((a, b) => (b.connected - a.connected)
                     || (b.known - a.known)
                     || (b.signalStrength - a.signalStrength))

    readonly property var connectedNetwork: networks.find(n => n && n.connected) || null

    property string passwordFor: ""
    property string failedFor: ""
    // Network whose password was just entered; a failure means a wrong password.
    property string pskAttempt: ""

    function findDevice(type) {
        for (const device of devices)
            if (device && device.type === type)
                return device
        return null
    }

    function signalIcon(strength) {
        const s = strength || 0
        if (s > 0.8) return "󰤨"
        if (s > 0.6) return "󰤥"
        if (s > 0.4) return "󰤢"
        if (s > 0.2) return "󰤟"
        return "󰤯"
    }

    function secured(network) {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe
    }

    function activate(network) {
        failedFor = ""
        if (network.connected) {
            network.disconnect()
        } else if (secured(network) && !network.known) {
            passwordFor = passwordFor === network.name ? "" : network.name
        } else {
            passwordFor = ""
            network.connect()
        }
    }

    function status() {
        if (!Networking.wifiEnabled)
            return wiredDevice && wiredDevice.connected ? "Wi-Fi off · Ethernet connected" : "Turned off"
        if (connectedNetwork)
            return "Connected to " + connectedNetwork.name
        if (wiredDevice && wiredDevice.connected)
            return "Ethernet connected"
        return "Not connected"
    }

    // Scan only while the panel is showing.
    Binding {
        when: root.wifiDevice !== null
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.opened && Networking.wifiEnabled
    }

    onOpenedChanged: if (!opened) { passwordFor = ""; failedFor = "" }

    PanelHeader {
        Layout.fillWidth: true
        icon: Networking.wifiEnabled ? "󰤨" : "󰤮"
        title: "Wi-Fi"
        status: root.status()
        checked: Networking.wifiEnabled
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.alpha(Theme.outline, 0.25)
    }

    Text {
        visible: !Networking.wifiEnabled || root.sortedNetworks.length === 0
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        horizontalAlignment: Text.AlignHCenter
        text: !Networking.wifiEnabled ? "Turn Wi-Fi on to see networks"
            : root.wifiDevice ? "Searching for networks…"
            : "No Wi-Fi adapter found"
        color: Theme.muted
        font.pixelSize: 12
    }

    Flickable {
        visible: Networking.wifiEnabled && root.sortedNetworks.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(list.implicitHeight, 360)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list

            width: parent.width
            spacing: 2

            Repeater {
                model: root.sortedNetworks

                ColumnLayout {
                    id: entry

                    required property var modelData
                    readonly property var net: modelData

                    Layout.fillWidth: true
                    spacing: 4

                    ListRow {
                        Layout.fillWidth: true
                        icon: root.signalIcon(entry.net.signalStrength)
                        title: entry.net.name
                        active: entry.net.connected
                        busy: entry.net.stateChanging
                        subtitle: entry.net.connected ? "Connected"
                                : root.failedFor === entry.net.name ? "Could not connect"
                                : entry.net.known ? "Saved"
                                : ""
                        trailingIcon: root.secured(entry.net) ? "󰌾" : ""
                        actionText: entry.net.connected ? "Disconnect" : entry.net.known ? "Forget" : ""
                        onClicked: root.activate(entry.net)
                        onActionClicked: entry.net.connected ? entry.net.disconnect() : entry.net.forget()
                    }

                    Connections {
                        target: entry.net
                        function onConnectionFailed(reason) {
                            root.failedFor = entry.net.name
                            if (root.pskAttempt === entry.net.name) {
                                root.pskAttempt = ""
                                entry.net.forget()
                                root.passwordFor = entry.net.name
                            }
                        }
                        function onConnectedChanged() {
                            if (entry.net.connected) {
                                if (root.failedFor === entry.net.name) root.failedFor = ""
                                if (root.pskAttempt === entry.net.name) root.pskAttempt = ""
                            }
                        }
                    }

                    RowLayout {
                        visible: root.passwordFor === entry.net.name
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 4
                        Layout.bottomMargin: 6
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 9
                            color: Theme.alpha(Theme.foreground, 0.07)
                            border.width: 1
                            border.color: password.activeFocus ? Theme.primary : Theme.alpha(Theme.outline, 0.4)

                            TextInput {
                                id: password

                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: showPassword.checked ? TextInput.Normal : TextInput.Password
                                color: Theme.foreground
                                selectionColor: Theme.primary
                                selectedTextColor: Theme.primaryText
                                font.pixelSize: 13
                                clip: true

                                function submit() {
                                    if (text.length === 0)
                                        return
                                    root.failedFor = ""
                                    root.pskAttempt = entry.net.name
                                    entry.net.connectWithPsk(text)
                                    text = ""
                                    root.passwordFor = ""
                                }

                                onVisibleChanged: if (visible) forceActiveFocus()
                                Keys.onReturnPressed: submit()
                                Keys.onEnterPressed: submit()
                                Keys.onEscapePressed: root.passwordFor = ""

                                Text {
                                    visible: password.text.length === 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Password"
                                    color: Theme.muted
                                    font.pixelSize: 13
                                }
                            }
                        }

                        Rectangle {
                            id: showPassword

                            property bool checked: false

                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 9
                            color: Theme.alpha(Theme.foreground, 0.07)

                            Text {
                                anchors.centerIn: parent
                                text: showPassword.checked ? "󰈈" : "󰈉"
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                                color: Theme.muted
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: showPassword.checked = !showPassword.checked
                            }
                        }

                        Rectangle {
                            implicitWidth: connectLabel.implicitWidth + 22
                            implicitHeight: 34
                            radius: 9
                            color: Theme.primary

                            Text {
                                id: connectLabel
                                anchors.centerIn: parent
                                text: "Connect"
                                color: Theme.primaryText
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: password.submit()
                            }
                        }
                    }
                }
            }
        }
    }

    FooterLink {
        text: "Network settings"
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"])
            root.closeRequested()
        }
    }
}
