import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    readonly property string configRoot:
        Quickshell.env("XDG_CONFIG_HOME") ||
        (Quickshell.env("HOME") + "/.config")

    readonly property color background: palette.background
    readonly property color surface: palette.surface
    readonly property color surfaceVariant: palette.surfaceVariant
    readonly property color foreground: palette.foreground
    readonly property color muted: palette.muted
    readonly property color primary: palette.primary
    readonly property color outline: palette.outline

    property FileView paletteFile: FileView {
        path: root.configRoot + "/quickshell/theme.json"
        watchChanges: true

        onFileChanged: reload()

        adapter: JsonAdapter {
            id: palette

            property string mode: "dark"
            property string background: "#111111"
            property string surface: "#e61c1c1c"
            property string surfaceVariant: "#3f3f3f"
            property string foreground: "#f5f5f5"
            property string muted: "#c7c7c7"
            property string primary: "#ffffff"
            property string outline: "#8e8e8e"
        }
    }
}
