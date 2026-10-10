import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Full-screen session screen: lock, sleep, log out, restart, and shut down,
// modelled on end-4's session screen. Arrow keys or the letter on each button
// pick an action; actions that end the session need a second press.
// Everything it runs goes through hypr/scripts/session.sh.
PanelWindow {
    id: root

    property bool shown: false
    signal closeRequested()

    visible: shown
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
            || Quickshell.screens[0]

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "dotfiles-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/session.sh"

    property var status: ({ available: {}, warnings: [] })
    property int focusIndex: 0
    property string armed: ""

    // Hover only moves focus once the pointer has actually moved since the
    // screen opened, so a pointer resting on a button cannot pick it for Enter.
    property bool pointerMoved: false
    property point pointerOrigin: Qt.point(-1, -1)

    readonly property var allActions: [
        { id: "lock", icon: "󰌾", label: "Lock", key: "L" },
        { id: "suspend", icon: "󰤄", label: "Suspend", key: "S" },
        { id: "hibernate", icon: "󰒲", label: "Hibernate", key: "H", needs: "hibernate" },
        { id: "logout", icon: "󰍃", label: "Log out", key: "E", confirm: true },
        { id: "reboot", icon: "󰜉", label: "Restart", key: "R", confirm: true },
        { id: "windows", icon: "󰖳", label: "Windows", key: "W", confirm: true, needs: "windows" },
        { id: "firmware", icon: "󰍛", label: "Firmware", key: "F", confirm: true, needs: "firmware" },
        { id: "poweroff", icon: "󰐥", label: "Shut down", key: "P", confirm: true },
    ]

    readonly property var actions: allActions.filter(a => !a.needs || (status.available && status.available[a.needs]))
    readonly property int columns: Math.min(4, actions.length)
    readonly property var focused: actions[Math.max(0, Math.min(focusIndex, actions.length - 1))]

    function activate(action) {
        if (!action)
            return
        if (action.confirm && armed !== action.id) {
            armed = action.id
            focusIndex = actions.indexOf(action)
            disarm.restart()
            return
        }
        root.closeRequested()
        Quickshell.execDetached([script, "run", action.id])
    }

    function move(dx, dy) {
        armed = ""
        const count = actions.length
        let next = focusIndex + dx + dy * columns
        if (dx !== 0)
            next = (next + count) % count
        if (next >= 0 && next < count)
            focusIndex = next
    }

    onShownChanged: {
        if (!shown)
            return
        armed = ""
        focusIndex = 0
        pointerMoved = false
        pointerOrigin = Qt.point(-1, -1)
        statusProc.running = true
        keys.forceActiveFocus()
    }

    Process {
        id: statusProc
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.status = JSON.parse(text) } catch (e) {}
            }
        }
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = ""
    }

    // Dimmed backdrop (Hyprland blurs the "dotfiles-overlay" layer behind it).
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.background, 0.8)
        opacity: root.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 160 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const key = event.key
            if (key === Qt.Key_Escape) {
                if (root.armed !== "") root.armed = ""
                else root.closeRequested()
            } else if (key === Qt.Key_Left) {
                root.move(-1, 0)
            } else if (key === Qt.Key_Right || key === Qt.Key_Tab) {
                root.move(1, 0)
            } else if (key === Qt.Key_Up) {
                root.move(0, -1)
            } else if (key === Qt.Key_Down) {
                root.move(0, 1)
            } else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) {
                root.activate(root.focused)
            } else {
                const letter = event.text.toUpperCase()
                const match = root.actions.find(a => a.key === letter)
                if (match)
                    root.activate(match)
                else
                    return
            }
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 26
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.97

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        // ---- header ----------------------------------------------------------

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Session"
                color: Theme.foreground
                font.pixelSize: 30
                font.weight: Font.DemiBold
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: [
                    (root.status.user || "") + (root.status.host ? "@" + root.status.host : ""),
                    root.status.uptime ? "up " + root.status.uptime : "",
                    root.status.battery ? "󰁹 " + root.status.battery : "",
                ].filter(s => s !== "").join("   ·   ")
                font.family: Theme.iconFont
                color: Theme.muted
                font.pixelSize: 13
            }
        }

        // ---- actions ---------------------------------------------------------

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: root.columns
            rowSpacing: 16
            columnSpacing: 16

            Repeater {
                model: root.actions

                Rectangle {
                    id: button

                    required property var modelData
                    required property int index
                    readonly property bool isFocused: root.focusIndex === index
                    readonly property bool isArmed: root.armed === modelData.id

                    implicitWidth: 118
                    implicitHeight: 118
                    radius: isFocused ? 59 : 28
                    color: isArmed ? Theme.error
                         : isFocused ? Theme.primary
                         : hover.hovered ? Theme.alpha(Theme.foreground, 0.14)
                         : Theme.alpha(Theme.foreground, 0.07)
                    border.width: 1
                    border.color: isFocused || isArmed ? "transparent" : Theme.alpha(Theme.outline, 0.25)

                    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    readonly property color ink: isArmed ? Theme.background
                                               : isFocused ? Theme.primaryText
                                               : Theme.foreground

                    HoverHandler {
                        id: hover
                        onHoveredChanged: if (hovered && root.pointerMoved && root.armed === "") root.focusIndex = button.index
                        onPointChanged: {
                            if (!hovered) return
                            const p = button.mapToItem(null, point.position.x, point.position.y)
                            if (root.pointerOrigin.x < 0) {
                                root.pointerOrigin = p
                            } else if (!root.pointerMoved && Math.abs(p.x - root.pointerOrigin.x) + Math.abs(p.y - root.pointerOrigin.y) > 4) {
                                root.pointerMoved = true
                                if (root.armed === "") root.focusIndex = button.index
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.focusIndex = button.index
                            root.activate(button.modelData)
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: button.modelData.icon
                            font.family: Theme.iconFont
                            font.pixelSize: 36
                            color: button.ink
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: button.modelData.label
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: button.ink
                        }
                    }
                }
            }
        }

        // ---- confirmation ----------------------------------------------

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                const action = root.focused
                if (!action) return ""
                if (root.armed === action.id)
                    return "Press again to " + action.label.toLowerCase()
                return ""
            }
            color: root.armed !== "" ? Theme.error : Theme.foreground
            font.pixelSize: 15
            font.weight: Font.Medium
        }

        // ---- warnings --------------------------------------------------------

        ColumnLayout {
            visible: (root.status.warnings || []).length > 0
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Repeater {
                model: root.status.warnings || []

                Rectangle {
                    required property string modelData

                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: warning.implicitWidth + 28
                    implicitHeight: 30
                    radius: 15
                    color: Theme.alpha(Theme.error, 0.16)

                    Text {
                        id: warning
                        anchors.centerIn: parent
                        text: "󰀪  " + parent.modelData
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: Theme.error
                    }
                }
            }
        }
    }
}
