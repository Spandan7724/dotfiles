import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Brightness, monitor scale, and desktop text size. All changes go through
// hypr/scripts/display.sh, which also persists them.
ColumnLayout {
    id: root

    property bool opened: false
    signal closeRequested()

    spacing: 10

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/display.sh"
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2, 2.5]

    property string monitor: ""
    property int modeWidth: 0
    property int modeHeight: 0
    property real monitorScale: 1
    property int textSize: 100
    property var brightness: null

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true
    }

    function run(args) {
        Quickshell.execDetached([script].concat(args))
        refreshSoon.restart()
    }

    function setScale(value) {
        monitorScale = value
        run(["scale", String(value)])
    }

    onOpenedChanged: if (opened) refresh()

    Process {
        id: statusProc
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.monitor = d.monitor
                    root.modeWidth = d.width
                    root.modeHeight = d.height
                    root.monitorScale = d.scale
                    root.textSize = d.text
                    if (!brightnessSlider.pressed)
                        root.brightness = d.brightness
                } catch (e) {}
            }
        }
    }

    Timer {
        id: refreshSoon
        interval: 600
        onTriggered: root.refresh()
    }

    PanelHeader {
        Layout.fillWidth: true
        icon: "󰍹"
        title: "Display"
        status: root.monitor === "" ? "" : root.monitor + " · "
            + Math.round(root.modeWidth / root.monitorScale) + "×" + Math.round(root.modeHeight / root.monitorScale) + " effective"
        showSwitch: false
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.alpha(Theme.outline, 0.25)
    }

    // ---- brightness ---------------------------------------------------------

    ColumnLayout {
        visible: root.brightness !== null
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "󰃠  Brightness"
                font.family: Theme.iconFont
                color: Theme.foreground
                font.pixelSize: 13
                Layout.fillWidth: true
            }

            Text {
                text: Math.round(brightnessSlider.value) + "%"
                color: Theme.muted
                font.pixelSize: 12
            }
        }

        Slider {
            id: brightnessSlider

            Layout.fillWidth: true
            from: 1
            to: 100
            stepSize: 1
            value: root.brightness === null ? 50 : root.brightness
            onMoved: v => root.run(["brightness", String(v)])
        }
    }

    // ---- scale --------------------------------------------------------------

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "󰩨  Scale"
                font.family: Theme.iconFont
                color: Theme.foreground
                font.pixelSize: 13
                Layout.fillWidth: true
            }

            Text {
                text: Math.round(root.monitorScale * 100) + "%"
                color: Theme.muted
                font.pixelSize: 12
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: root.scales

                Rectangle {
                    required property var modelData
                    // Hyprland may round a preset to the nearest scale the
                    // mode allows, so "selected" tolerates a small difference.
                    readonly property bool selected: Math.abs(root.monitorScale - modelData) < 0.04

                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 9
                    color: selected ? Theme.primary
                         : chipHover.hovered ? Theme.alpha(Theme.foreground, 0.12)
                         : Theme.alpha(Theme.foreground, 0.06)

                    HoverHandler { id: chipHover }

                    Text {
                        anchors.centerIn: parent
                        text: Math.round(modelData * 100) + "%"
                        color: parent.selected ? Theme.primaryText : Theme.foreground
                        font.pixelSize: 12
                        font.weight: parent.selected ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setScale(modelData)
                    }
                }
            }
        }
    }

    // ---- text size ----------------------------------------------------------

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "󰛖  Text size"
                font.family: Theme.iconFont
                color: Theme.foreground
                font.pixelSize: 13
                Layout.fillWidth: true
            }

            Text {
                text: Math.round(textSlider.value) + "%"
                color: Theme.muted
                font.pixelSize: 12
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "A"
                color: Theme.muted
                font.pixelSize: 11
            }

            Slider {
                id: textSlider

                Layout.fillWidth: true
                from: 80
                to: 150
                stepSize: 5
                value: root.textSize
                onReleased: v => {
                    root.textSize = v
                    root.run(["text", String(v)])
                }
            }

            Text {
                text: "A"
                color: Theme.muted
                font.pixelSize: 17
            }
        }

        Text {
            text: "Applies to GTK apps and Kitty"
            color: Theme.muted
            font.pixelSize: 11
            opacity: 0.8
        }
    }

    FooterLink {
        text: "Reset text size"
        visible: root.textSize !== 100
        onClicked: {
            root.textSize = 100
            root.run(["text", "100"])
        }
    }
}
