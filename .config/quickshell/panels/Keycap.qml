import QtQuick

// One key drawn as a keycap, for the cheatsheet and key hints.
Rectangle {
    id: root

    property string text: ""
    property int fontSize: 11

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 12)
    implicitHeight: fontSize + 11
    radius: 5
    color: Theme.alpha(Theme.foreground, 0.08)
    border.width: 1
    border.color: Theme.alpha(Theme.outline, 0.35)

    // A slightly heavier bottom edge reads as a physical key.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        height: 2
        radius: parent.radius
        color: Theme.alpha(Theme.outline, 0.3)
    }

    Text {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.text
        font.family: Theme.iconFont
        font.pixelSize: root.fontSize
        font.weight: Font.DemiBold
        color: Theme.foreground
    }
}
