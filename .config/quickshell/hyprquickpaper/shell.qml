import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main

    Theme {
        id: theme
    }

    // ---- Settings ----
    property int moveDuration: 180
    property real zoomScale: 0.8
    property real edgeScale: 0.3
    property real skewFactor: 0
    property int baseSpacing: 10
    property int startPosition: 20

    // Resolved once, used to expand relative paths from config.json
    readonly property string homeDir: Quickshell.env("HOME")

    implicitHeight: 500
    implicitWidth: Screen.width
    color: "transparent"
    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted:
        Quickshell.execDetached([
            "bash",
            Quickshell.shellPath("cache.sh"),
            Quickshell.shellDir
        ])

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs

            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
        }
    }

    FolderListModel {
        id: folderModel

        folder: "file://" + main.homeDir + "/" + configs.wallpaper_path
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        sortField: FolderListModel.Name
    }

    // A PathView rather than a ListView so the strip loops: stepping past
    // the last wallpaper continues straight into the first.
    PathView {
        id: list

        anchors.fill: parent
        focus: true
        model: folderModel
        clip: true
        // All pointer input goes through pointerArea below, so the view only
        // ever moves to center the selection.
        interactive: false

        readonly property real tileWidth: width / configs.number_of_pictures - 10
        readonly property real step: tileWidth + main.baseSpacing
        readonly property real viewportCenterX: width / 2

        // Tile the pointer last moved onto, or -1 when the keyboard or wheel
        // drives the selection. Hovering highlights without recentering, so
        // the strip never slides out from under the cursor.
        property int hoverIndex: -1
        readonly property int selectedIndex: hoverIndex >= 0 ? hoverIndex : currentIndex
        property bool ready: false

        // Two extra slots keep the edges filled while the strip animates.
        pathItemCount: Math.min(count, configs.number_of_pictures + 2)
        cacheItemCount: 4
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: ready ? main.moveDuration : 0
        snapMode: PathView.SnapToItem

        path: Path {
            startX: list.viewportCenterX - list.pathItemCount * list.step / 2
            startY: list.height / 2

            PathLine {
                x: list.viewportCenterX + list.pathItemCount * list.step / 2
                y: list.height / 2
            }
        }

        onCountChanged: {
            if (!ready && count > 0) {
                currentIndex = Math.max(0, Math.min(main.startPosition, count - 1))
                ready = true
            }
        }

        function wrapIndex(i) {
            return ((i % count) + count) % count
        }

        function activateCurrent() {
            activateIndex(selectedIndex)
        }

        function activateIndex(i) {
            if (i < 0 || i >= count)
                return

            Quickshell.execDetached([
                "bash",
                Quickshell.shellPath("commands.sh"),
                folderModel.get(i, "filePath")
            ])

            Qt.quit()
        }

        // Step from whatever is highlighted, so scrolling or pressing an
        // arrow after hovering continues from the hovered tile.
        function moveSelection(delta) {
            if (count === 0)
                return
            const target = wrapIndex(selectedIndex + delta)
            hoverIndex = -1
            currentIndex = target
        }

        delegate: Item {
            id: delegateItem

            height: 500
            width: list.tileWidth
            property bool active: index === list.selectedIndex

            // Dock-style magnification based on on-screen position.
            property real scaleFactor: {
                const centerX = x + width / 2
                const frac = Math.min(
                    1,
                    Math.abs(centerX - list.viewportCenterX) / list.viewportCenterX
                )

                const t = 1 - frac * frac * (3 - 2 * frac)

                return main.edgeScale +
                       (main.zoomScale - main.edgeScale) * t
            }

            Item {
                id: content

                anchors.centerIn: parent
                width: delegateItem.width * delegateItem.scaleFactor
                height: delegateItem.height *
                        Math.min(1, delegateItem.scaleFactor)

                Text {
                    id: alt

                    text: ""
                    color: theme.muted
                    anchors.centerIn: parent
                    font.pixelSize: 16

                    transform: Shear {
                        xFactor: main.skewFactor
                    }
                }

                Image {
                    id: img

                    anchors.fill: parent
                    opacity: 0.8
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true

                    source: "file://" +
                            main.homeDir + "/" +
                            configs.cache_path +
                            fileName

                    // Decode once at max zoomed size.
                    sourceSize.width:
                        delegateItem.width * main.zoomScale

                    sourceSize.height:
                        delegateItem.height

                    transform: Shear {
                        xFactor: main.skewFactor
                    }

                    Timer {
                        id: retryTimer

                        interval: 1000
                        repeat: false

                        onTriggered: {
                            const s = img.source
                            img.source = ""
                            img.source = s
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Error) {
                            alt.text = "Caching"
                            retryTimer.start()
                        }
                    }
                }

                Rectangle {
                    z: 10
                    anchors.fill: parent
                    visible: delegateItem.active
                    color: "transparent"
                    border.width: 2
                    border.color: theme.primary

                    transform: Shear {
                        xFactor: main.skewFactor
                    }
                }
            }
        }

        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_Up:
                moveSelection(-1)
                break
            case Qt.Key_Right:
            case Qt.Key_Down:
                moveSelection(1)
                break
            case Qt.Key_PageUp:
                moveSelection(-configs.number_of_pictures)
                break
            case Qt.Key_PageDown:
                moveSelection(configs.number_of_pictures)
                break
            case Qt.Key_Home:
                hoverIndex = -1
                currentIndex = 0
                break
            case Qt.Key_End:
                hoverIndex = -1
                currentIndex = count - 1
                break
            case Qt.Key_Space:
            case Qt.Key_Return:
            case Qt.Key_Enter:
                activateCurrent()
                break
            case Qt.Key_W:
            case Qt.Key_Escape:
                Qt.quit()
                break
            default:
                return
            }
            event.accepted = true
        }
    }

    // One handler for all pointer input. It sits outside the PathView so its
    // coordinates stay fixed while the tiles slide underneath, which lets
    // hover tell real pointer motion from tiles moving under a still cursor.
    MouseArea {
        id: pointerArea

        anchors.fill: list
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton |
                         Qt.BackButton | Qt.ForwardButton

        // Wheel notches report 120 per step; touchpads report small pixel
        // deltas, so both are accumulated until a full step is reached.
        readonly property int angleStep: 120
        readonly property int pixelStep: 60
        property real wheelAccum: 0
        property real lastX: NaN
        property real lastY: NaN

        onPositionChanged: function(mouse) {
            const moved = !isNaN(lastX) &&
                          (mouse.x !== lastX || mouse.y !== lastY)
            lastX = mouse.x
            lastY = mouse.y
            if (!moved)
                return

            const i = list.indexAt(mouse.x, mouse.y)
            if (i >= 0)
                list.hoverIndex = i
        }

        onExited: list.hoverIndex = -1

        onClicked: function(mouse) {
            switch (mouse.button) {
            case Qt.LeftButton:
            case Qt.MiddleButton:
                list.activateIndex(list.indexAt(mouse.x, mouse.y))
                break
            case Qt.RightButton:
                Qt.quit()
                break
            case Qt.BackButton:
                list.moveSelection(-1)
                break
            case Qt.ForwardButton:
                list.moveSelection(1)
                break
            }
        }

        onWheel: function(wheel) {
            wheel.accepted = true

            const usePixels = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0
            const d = usePixels ? wheel.pixelDelta : wheel.angleDelta
            const threshold = usePixels ? pixelStep : angleStep

            // Use whichever axis dominates, so vertical wheels and horizontal
            // touchpad swipes both scroll the strip.
            const delta = -(Math.abs(d.x) > Math.abs(d.y) ? d.x : d.y)
            if (delta === 0)
                return

            if (Math.sign(delta) !== Math.sign(wheelAccum))
                wheelAccum = 0
            wheelAccum += delta

            const steps = Math.trunc(wheelAccum / threshold)
            if (steps !== 0) {
                wheelAccum -= steps * threshold
                list.moveSelection(steps)
            }
        }
    }
}
