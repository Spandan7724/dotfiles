pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Matugen/theme palette shared by every panel. A singleton rather than a
// per-file instance because separate components cannot see each other's ids.
Singleton {
    id: root

    readonly property string configRoot:
        Quickshell.env("XDG_CONFIG_HOME") ||
        (Quickshell.env("HOME") + "/.config")

    readonly property string iconFont: "Symbols Nerd Font"

    readonly property color background: palette.background
    readonly property color surface: palette.surface
    readonly property color surfaceVariant: palette.surfaceVariant
    readonly property color foreground: palette.foreground
    readonly property color muted: palette.muted
    readonly property color primary: palette.primary
    readonly property color outline: palette.outline
    // Read by hand: JsonAdapter cannot declare these keys, because "error" is
    // a signal name and "onPrimary" parses as a signal handler.
    property color primaryText: "#111111"
    property color error: "#ff6b6b"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    FileView {
        path: root.configRoot + "/quickshell/theme.json"
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                const json = JSON.parse(text())
                if (json.onPrimary) root.primaryText = json.onPrimary
                if (json.error) root.error = json.error
            } catch (err) {}
        }

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
