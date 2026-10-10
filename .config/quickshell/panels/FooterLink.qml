import QtQuick
import QtQuick.Layouts

// Muted link at the bottom of a panel, e.g. "More settings".
Rectangle {
    id: root

    property string text: ""
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 32
    radius: 9
    color: hover.hovered ? Theme.alpha(Theme.foreground, 0.07) : "transparent"

    HoverHandler { id: hover }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        text: root.text
        color: hover.hovered ? Theme.foreground : Theme.muted
        font.pixelSize: 12
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        text: "󰁔"
        font.family: Theme.iconFont
        font.pixelSize: 13
        color: Theme.muted
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
