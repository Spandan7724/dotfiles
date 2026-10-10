import QtQuick

// Horizontal slider. `value` follows the handle while dragging; `moved` fires
// on every change and `released` once the drag ends, so callers can choose
// between live updates (brightness) and apply-on-release (text size).
Item {
    id: root

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    readonly property bool pressed: mouse.pressed

    signal moved(real value)
    signal released(real value)

    implicitHeight: 22

    readonly property real position: (value - from) / (to - from)

    function valueAt(x) {
        const ratio = Math.max(0, Math.min(1, x / width))
        const raw = from + ratio * (to - from)
        return Math.round(raw / stepSize) * stepSize
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.alpha(Theme.foreground, 0.12)

        Rectangle {
            width: Math.max(parent.height, root.position * parent.width)
            height: parent.height
            radius: parent.radius
            color: Theme.primary
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.position * (root.width - width)
        width: 16
        height: 16
        radius: 8
        color: Theme.primary
        border.width: 3
        border.color: Theme.surface
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function update(x) {
            const next = root.valueAt(x)
            if (next !== root.value) {
                root.value = next
                root.moved(next)
            }
        }

        onPressed: event => update(event.x)
        onPositionChanged: event => { if (pressed) update(event.x) }
        onReleased: root.released(root.value)
    }
}
