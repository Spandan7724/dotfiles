import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "CheatsheetModel.js" as Model

// Keyboard shortcut cheatsheet, modelled on end-4's: every described Hyprland
// bind, grouped by the category set with section() in hypr/keybinds.lua and
// laid out in masonry columns. Typing filters; Esc clears, then closes.
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

    property var categories: []
    readonly property var shownCategories: Model.filter(categories, search.text)
    readonly property int rowCount: shownCategories.reduce((n, c) => n + c.rows.length, 0)

    readonly property int columnWidth: 420
    readonly property int columnGap: 28
    readonly property int columnCount: Math.max(1, Math.floor((card.width - 56 + columnGap) / (columnWidth + columnGap)))

    onShownChanged: {
        if (!shown)
            return
        search.text = ""
        flick.contentY = 0
        bindsProc.running = true
        search.forceActiveFocus()
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.categories = Model.build(JSON.parse(text)) } catch (e) {}
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.background, 0.7)
        opacity: root.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 160 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1400)
        height: Math.min(parent.height - 80, 900)
        radius: 20
        color: Theme.background
        border.width: 1
        border.color: Theme.alpha(Theme.outline, 0.3)
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.98

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        // Swallow clicks so only the backdrop closes the sheet.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 20

            // ---- header -------------------------------------------------------

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 12
                    color: Theme.alpha(Theme.primary, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: "󰌌"
                        font.family: Theme.iconFont
                        font.pixelSize: 21
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    spacing: 1

                    Text {
                        text: "Keyboard shortcuts"
                        color: Theme.foreground
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.rowCount + " shortcuts in " + root.shownCategories.length + " groups"
                        color: Theme.muted
                        font.pixelSize: 12
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: 320
                    implicitHeight: 38
                    radius: 11
                    color: Theme.alpha(Theme.foreground, 0.06)
                    border.width: 1
                    border.color: search.activeFocus ? Theme.alpha(Theme.primary, 0.6) : Theme.alpha(Theme.outline, 0.3)

                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        font.family: Theme.iconFont
                        font.pixelSize: 15
                        color: Theme.muted
                    }

                    TextInput {
                        id: search

                        anchors.left: searchIcon.right
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.foreground
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.primaryText
                        font.pixelSize: 13
                        clip: true

                        onTextChanged: flick.contentY = 0

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                if (text !== "") text = ""
                                else root.closeRequested()
                            } else if (event.key === Qt.Key_Down) {
                                flick.scrollBy(60)
                            } else if (event.key === Qt.Key_Up) {
                                flick.scrollBy(-60)
                            } else if (event.key === Qt.Key_PageDown) {
                                flick.scrollBy(flick.height * 0.8)
                            } else if (event.key === Qt.Key_PageUp) {
                                flick.scrollBy(-flick.height * 0.8)
                            } else {
                                return
                            }
                            event.accepted = true
                        }

                        Text {
                            visible: search.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Filter by action or key…"
                            color: Theme.muted
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // ---- columns ------------------------------------------------------

            Flickable {
                id: flick

                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: masonry.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                function scrollBy(delta) {
                    contentY = Math.max(0, Math.min(contentHeight - height, contentY + delta))
                }

                Row {
                    id: masonry

                    spacing: root.columnGap
                    anchors.horizontalCenter: parent.horizontalCenter

                    Repeater {
                        model: Model.columns(root.shownCategories, root.columnCount)

                        Column {
                            required property var modelData

                            width: root.columnWidth
                            spacing: 22

                            Repeater {
                                model: parent.modelData

                                Column {
                                    id: category

                                    required property var modelData

                                    width: root.columnWidth
                                    spacing: 4

                                    RowLayout {
                                        width: parent.width
                                        spacing: 8

                                        Text {
                                            text: category.modelData.icon
                                            font.family: Theme.iconFont
                                            font.pixelSize: 15
                                            color: Theme.primary
                                        }

                                        Text {
                                            text: category.modelData.name
                                            color: Theme.foreground
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 6
                                            implicitHeight: 1
                                            color: Theme.alpha(Theme.outline, 0.25)
                                        }
                                    }

                                    Repeater {
                                        model: category.modelData.rows

                                        Rectangle {
                                            id: row

                                            required property var modelData

                                            width: root.columnWidth
                                            implicitHeight: 30
                                            radius: 7
                                            color: rowHover.hovered ? Theme.alpha(Theme.foreground, 0.05) : "transparent"

                                            HoverHandler { id: rowHover }

                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 6
                                                anchors.right: combos.left
                                                anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: row.modelData.text
                                                color: rowHover.hovered ? Theme.foreground : Theme.alpha(Theme.foreground, 0.85)
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                id: combos

                                                anchors.right: parent.right
                                                anchors.rightMargin: 6
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 8

                                                Repeater {
                                                    model: row.modelData.combos

                                                    Row {
                                                        required property var modelData
                                                        required property int index

                                                        spacing: 3

                                                        Text {
                                                            visible: parent.index > 0
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            rightPadding: 5
                                                            text: "or"
                                                            color: Theme.muted
                                                            font.pixelSize: 10
                                                        }

                                                        Repeater {
                                                            model: parent.modelData

                                                            Keycap {
                                                                required property string modelData
                                                                text: modelData
                                                                fontSize: 10
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
