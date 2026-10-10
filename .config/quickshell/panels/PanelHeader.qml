import QtQuick
import QtQuick.Layouts

// Panel title row: large icon, title and status line, optional switch.
RowLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string status: ""
    property bool showSwitch: true
    property bool checked: false
    signal toggled()

    spacing: 12

    Rectangle {
        implicitWidth: 38
        implicitHeight: 38
        radius: 11
        color: root.checked || !root.showSwitch ? Theme.alpha(Theme.primary, 0.18) : Theme.alpha(Theme.foreground, 0.08)

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: 19
            color: root.checked || !root.showSwitch ? Theme.foreground : Theme.dimText
        }
    }

    ColumnLayout {
        spacing: 1
        Layout.fillWidth: true

        Text {
            text: root.title
            color: Theme.foreground
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            text: root.status
            color: Theme.dimText
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    Switch {
        visible: root.showSwitch
        checked: root.checked
        onToggled: root.toggled()
    }
}
