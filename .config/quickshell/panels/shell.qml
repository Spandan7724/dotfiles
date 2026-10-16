//@ pragma IconTheme Papirus-Dark
// Wi-Fi, Bluetooth, Display, and Media pop-ups for the top bar, plus the
// full-screen session screen and keyboard cheatsheet, modelled on Omarchy's and end-4's shells. One
// daemon serves them all; hypr/scripts/panel.sh starts it on demand and
// toggles one:
//
//   qs -c panels ipc call panels toggle wifi|bluetooth|display|media|session|cheatsheet
//
// Icons come from Papirus, the theme the rest of the desktop uses (themes/
// apply.sh), so menus can show file-type icons and not just app icons. Pragmas
// are read at launch: restart the daemon after changing it.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    id: shell

    property string current: ""

    // Names shown in the small pop-up card; anything else is a full-screen overlay.
    readonly property var popups: ["wifi", "bluetooth", "display", "media"]

    IpcHandler {
        target: "panels"

        function toggle(name: string): void {
            shell.current = shell.current === name ? "" : name
        }

        function open(name: string): void {
            shell.current = name
        }

        function close(): void {
            shell.current = ""
        }

        // The desktop menu, optionally opened at a submenu ("setup", "style.wallpaper").
        function menu(route: string): void {
            if (shell.current === "menu" && menuWindow.mode === "menu" && route === "") {
                shell.current = ""
                return
            }
            menuWindow.openMenu(route)
            shell.current = "menu"
        }

        function apps(): void {
            if (shell.current === "menu" && menuWindow.mode === "apps") {
                shell.current = ""
                return
            }
            menuWindow.openApps()
            shell.current = "menu"
        }

        // A rofi -dmenu style request written by hypr/scripts/menu-select.
        function select(requestPath: string): void {
            menuWindow.openSelect(requestPath)
            shell.current = "menu"
        }

        // The request file currently being answered, or "" if none.
        function activeRequest(): string {
            return shell.current === "menu" ? menuWindow.requestPath.replace(/^file:\/\//, "") : ""
        }
    }

    PanelWindow {
        id: panel

        visible: shell.popups.includes(shell.current)
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
                || Quickshell.screens[0]

        anchors {
            top: true
            right: true
        }

        // Layer-shell placement already sits below Waybar's exclusive zone.
        margins {
            top: 6
            right: 8
        }

        implicitWidth: 340
        implicitHeight: card.height
        color: "transparent"

        WlrLayershell.namespace: "dotfiles-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // Clicking anywhere outside closes the panel.
        HyprlandFocusGrab {
            active: panel.visible
            windows: [panel]
            onCleared: shell.current = ""
        }

        Rectangle {
            id: card

            width: parent.width
            height: content.implicitHeight + 32
            radius: 16
            // Translucent so the dotfiles-panel blur rule shows through.
            color: Theme.card
            border.width: 1
            border.color: Theme.alpha(Theme.foreground, Theme.dark ? 0.09 : 0.12)

            Item {
                id: content

                x: 16
                y: 16
                width: parent.width - 32
                implicitHeight: views.children[views.index].implicitHeight
                focus: true

                Keys.onEscapePressed: shell.current = ""

                QtObject {
                    id: views
                    readonly property var children: [wifi, bluetooth, display, media]
                    readonly property int index: shell.current === "bluetooth" ? 1
                                               : shell.current === "display" ? 2
                                               : shell.current === "media" ? 3
                                               : 0
                }

                WifiView {
                    id: wifi
                    width: parent.width
                    visible: shell.current === "wifi"
                    opened: visible
                    onCloseRequested: shell.current = ""
                }

                BluetoothView {
                    id: bluetooth
                    width: parent.width
                    visible: shell.current === "bluetooth"
                    opened: visible
                    onCloseRequested: shell.current = ""
                }

                DisplayView {
                    id: display
                    width: parent.width
                    visible: shell.current === "display"
                    opened: visible
                    onCloseRequested: shell.current = ""
                }

                MediaView {
                    id: media
                    width: parent.width
                    visible: shell.current === "media"
                    opened: visible
                    onCloseRequested: shell.current = ""
                }
            }
        }
    }

    SessionScreen {
        shown: shell.current === "session"
        onCloseRequested: shell.current = ""
    }

    Menu {
        id: menuWindow
        shown: shell.current === "menu"
        onCloseRequested: shell.current = ""
    }

    Cheatsheet {
        shown: shell.current === "cheatsheet"
        onCloseRequested: shell.current = ""
    }
}
