import QtQuick
import QtQuick.Layouts

// One clickable row: icon, title with an optional subtitle, and an optional
// trailing action that appears on hover (Forget, Disconnect, ...).
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool busy: false
    property string trailingIcon: ""
    property string actionText: ""

    signal clicked()
    signal actionClicked()

    implicitHeight: 46
    radius: 10
    color: active ? Theme.alpha(Theme.primary, 0.16)
         : hover.hovered ? Theme.alpha(Theme.foreground, 0.07)
         : "transparent"

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 12

        Text {
            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: 18
            color: root.active ? Theme.primary : Theme.foreground
            Layout.preferredWidth: 22
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
                text: root.title
                color: Theme.foreground
                font.pixelSize: 13
                font.weight: root.active ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: text !== ""
                text: root.busy ? "Working…" : root.subtitle
                color: root.active ? Theme.primary : Theme.muted
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Rectangle {
            visible: root.actionText !== "" && hover.hovered
            implicitWidth: actionLabel.implicitWidth + 16
            implicitHeight: 24
            radius: 7
            color: actionHover.hovered ? Theme.alpha(Theme.error, 0.22) : Theme.alpha(Theme.foreground, 0.08)

            HoverHandler { id: actionHover }

            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: root.actionText
                color: actionHover.hovered ? Theme.error : Theme.muted
                font.pixelSize: 11
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionClicked()
            }
        }

        Text {
            visible: root.trailingIcon !== "" && !(root.actionText !== "" && hover.hovered)
            text: root.trailingIcon
            font.family: Theme.iconFont
            font.pixelSize: 13
            color: Theme.muted
        }
    }
}
