import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Now playing: artwork, track details, a seekable progress bar, and transport
// controls for any MPRIS player. With several players, chips pick which one.
ColumnLayout {
    id: root

    property bool opened: false
    signal closeRequested()

    spacing: 12

    readonly property var players: Mpris.players ? Mpris.players.values : []

    // The chosen player if it is still around, else a playing one, else any.
    property string chosenId: ""
    readonly property var player: {
        const list = players
        return list.find(p => p.uniqueId === chosenId)
            || list.find(p => p.isPlaying)
            || list[0]
            || null
    }

    readonly property bool hasLength: player !== null && player.lengthSupported && player.length > 0

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0))
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = String(s % 60).padStart(2, "0")
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + sec : m + ":" + sec
    }

    // MPRIS does not push position updates; ask for a fresh value each second.
    Timer {
        interval: 1000
        repeat: true
        running: root.opened && root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    onOpenedChanged: if (opened && player) player.positionChanged()

    // ---- player chips (only with more than one player) -------------------------

    Flow {
        visible: root.players.length > 1
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: root.players

            Rectangle {
                required property var modelData
                readonly property bool selected: root.player === modelData

                implicitWidth: chipLabel.implicitWidth + 20
                implicitHeight: 26
                radius: 13
                color: selected ? Theme.alpha(Theme.primary, 0.2)
                     : chipHover.hovered ? Theme.alpha(Theme.foreground, 0.1)
                     : Theme.alpha(Theme.foreground, 0.05)

                HoverHandler { id: chipHover }

                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: (modelData.isPlaying ? "󰐊 " : "") + (modelData.identity || "Player")
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                    color: parent.selected ? Theme.primary : Theme.muted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chosenId = modelData.uniqueId
                }
            }
        }
    }

    // ---- nothing playing -----------------------------------------------------

    ColumnLayout {
        visible: root.player === null
        Layout.fillWidth: true
        Layout.topMargin: 12
        Layout.bottomMargin: 12
        spacing: 6

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰝛"
            font.family: Theme.iconFont
            font.pixelSize: 34
            color: Theme.alpha(Theme.muted, 0.6)
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Nothing is playing"
            color: Theme.muted
            font.pixelSize: 12
        }
    }

    // ---- artwork and track ---------------------------------------------------

    RowLayout {
        visible: root.player !== null
        Layout.fillWidth: true
        spacing: 14

        ClippingRectangle {
            implicitWidth: 84
            implicitHeight: 84
            radius: 12
            color: Theme.alpha(Theme.primary, 0.14)

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "󰎆"
                font.family: Theme.iconFont
                font.pixelSize: 34
                color: Theme.primary
            }

            Image {
                id: art
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 168
                sourceSize.height: 168
                visible: status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                text: root.player ? (root.player.trackTitle || "Unknown track") : ""
                color: Theme.foreground
                font.pixelSize: 15
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: text !== ""
                text: root.player ? root.player.trackArtist : ""
                color: Theme.primary
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: text !== ""
                text: root.player ? root.player.trackAlbum : ""
                color: Theme.muted
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    // ---- progress ------------------------------------------------------------

    ColumnLayout {
        visible: root.player !== null
        Layout.fillWidth: true
        spacing: 4

        Slider {
            id: progress

            visible: root.hasLength
            Layout.fillWidth: true
            from: 0
            to: root.hasLength ? root.player.length : 1
            stepSize: 1
            value: root.player ? root.player.position : 0
            enabled: root.player !== null && root.player.canSeek
            onReleased: v => {
                if (root.player && root.player.canSeek)
                    root.player.position = v
                // Dragging replaced the binding; follow the player again.
                progress.value = Qt.binding(() => root.player ? root.player.position : 0)
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.hasLength ? root.time(progress.value) : "󰐹  Live"
                font.family: Theme.iconFont
                color: Theme.muted
                font.pixelSize: 11
                Layout.fillWidth: true
            }

            Text {
                visible: root.hasLength
                text: root.time(root.player ? root.player.length : 0)
                color: Theme.muted
                font.pixelSize: 11
            }
        }
    }

    // ---- transport -----------------------------------------------------------

    RowLayout {
        visible: root.player !== null
        Layout.fillWidth: true
        Layout.topMargin: -2
        spacing: 0

        component ControlButton: Rectangle {
            id: button

            property string icon: ""
            property int size: 36
            property bool active: false
            property bool primary: false
            signal clicked()

            implicitWidth: size
            implicitHeight: size
            radius: size / 2
            opacity: enabled ? 1 : 0.35
            color: primary ? Theme.primary
                 : buttonHover.hovered && enabled ? Theme.alpha(Theme.foreground, 0.1)
                 : "transparent"

            HoverHandler { id: buttonHover }

            Text {
                anchors.centerIn: parent
                text: button.icon
                font.family: Theme.iconFont
                font.pixelSize: button.primary ? 22 : 17
                color: button.primary ? Theme.primaryText
                     : button.active ? Theme.primary
                     : Theme.foreground
            }

            MouseArea {
                anchors.fill: parent
                enabled: button.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: button.clicked()
            }
        }

        Item { Layout.fillWidth: true }

        ControlButton {
            icon: "󰒟"
            active: root.player !== null && root.player.shuffle
            enabled: root.player !== null && root.player.shuffleSupported
            onClicked: root.player.shuffle = !root.player.shuffle
        }

        Item { Layout.preferredWidth: 10 }

        ControlButton {
            icon: "󰒮"
            enabled: root.player !== null && root.player.canGoPrevious
            onClicked: root.player.previous()
        }

        Item { Layout.preferredWidth: 10 }

        ControlButton {
            icon: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
            size: 48
            primary: true
            enabled: root.player !== null && root.player.canTogglePlaying
            onClicked: root.player.togglePlaying()
        }

        Item { Layout.preferredWidth: 10 }

        ControlButton {
            icon: "󰒭"
            enabled: root.player !== null && root.player.canGoNext
            onClicked: root.player.next()
        }

        Item { Layout.preferredWidth: 10 }

        ControlButton {
            icon: root.player && root.player.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
            active: root.player !== null && root.player.loopState !== MprisLoopState.None
            enabled: root.player !== null && root.player.loopSupported
            onClicked: {
                const p = root.player
                p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                            : p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                            : MprisLoopState.None
            }
        }

        Item { Layout.fillWidth: true }
    }

    FooterLink {
        visible: root.player !== null && root.player.canRaise
        text: "Open " + (root.player ? root.player.identity : "player")
        onClicked: {
            root.player.raise()
            root.closeRequested()
        }
    }
}
