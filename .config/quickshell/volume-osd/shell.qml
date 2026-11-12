// hl.dsp.exec_cmd("qs -d -c volume-osd")
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    Theme {
        id: theme
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 120
    color: "transparent"

    // Respect waybar's exclusive zone so the OSD always sits below the bar
    exclusionMode: ExclusionMode.Normal

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? flyout : null
    }

    // -------------------------
    // PipeWire
    // -------------------------

    PwObjectTracker {
        id: audioTracker

        objects: [Pipewire.defaultAudioSink]
    }

    property var sink: Pipewire.defaultAudioSink

    property real volume: {
        if (!sink || !sink.audio)
            return 0

        return sink.audio.volume
    }

    property bool muted: {
        if (!sink || !sink.audio)
            return false

        return sink.audio.muted
    }

    // -------------------------
    // OSD state
    // -------------------------

    property bool showing: false

    function showOsd() {
        showing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer

        interval: 1200
        repeat: false

        onTriggered: root.showing = false
    }

    // -------------------------
    // Detect changes
    // -------------------------

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            root.showOsd()
        }

        function onMutedChanged() {
            root.showOsd()
        }
    }

    // -------------------------
    // OSD
    // -------------------------

    Rectangle {
        id: flyout

        width: 300
        height: 34

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.showing ? 8 : 0

        // Match waybar's pill styling
        radius: 11
        color: theme.surface
        border.width: 1
        border.color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.10)

        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Text {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (root.muted)
                    return "󰖁"

                if (root.volume <= 0)
                    return "󰕿"

                if (root.volume < 0.5)
                    return "󰖀"

                return "󰕾"
            }

            font.family: "Symbols Nerd Font"
            font.pixelSize: 17

            color: root.muted ? theme.muted : theme.primary
        }

        Text {
            id: label

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter

            text: root.muted
                ? "Muted"
                : Math.round(root.volume * 100) + "%"

            width: 38
            horizontalAlignment: Text.AlignRight

            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            font.weight: Font.DemiBold

            color: theme.foreground
        }

        Rectangle {
            anchors.left: icon.right
            anchors.leftMargin: 12

            anchors.right: label.left
            anchors.rightMargin: 10

            anchors.verticalCenter: parent.verticalCenter

            height: 4
            radius: 2

            color: theme.surfaceVariant

            Rectangle {
                width: root.muted
                    ? 0
                    : parent.width * Math.min(root.volume, 1)

                height: parent.height
                radius: 2

                color: theme.primary

                Behavior on width {
                    NumberAnimation {
                        duration: 100
                    }
                }
            }
        }
    }
}
