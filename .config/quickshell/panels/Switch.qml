import QtQuick

// Small on/off switch in the panel palette.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 38
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.primary : Theme.alpha(Theme.foreground, 0.12)

    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.primaryText : Theme.muted

        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
