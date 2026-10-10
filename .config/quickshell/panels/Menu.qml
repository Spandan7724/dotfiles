import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "MenuModel.js" as Model

// The one menu surface for the desktop, replacing rofi. Three modes:
//
//   menu    the desktop menu from menu.json (Super+Escape); searching at the
//           top level looks through every submenu and installed app
//   select  a rofi -dmenu stand-in driven by hypr/scripts/menu-select
//   apps    the application launcher (Super+D)
PanelWindow {
    id: root

    property bool shown: false
    signal closeRequested()

    visible: shown
    screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)
            || Quickshell.screens[0]

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: "dotfiles-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property string home: Quickshell.env("HOME")

    property string mode: "menu"
    property int cursor: 0

    // Where the pointer was when the menu opened. A row under a pointer that
    // has not moved must not steal the selection from the keyboard.
    property point hoverOrigin: Qt.point(-1, -1)

    // ---- menu mode state ---------------------------------------------------------

    property var menu: ({ entries: {}, order: [], prelude: "" })
    property var guards: ({})
    property var stack: []
    readonly property string route: stack.length ? stack[stack.length - 1] : ""

    // ---- select mode state -------------------------------------------------------

    property var request: null
    property var lines: []
    // The open request's file, so menu-select can tell when its question has
    // gone away (another menu replaced it, or the shell reloaded).
    readonly property string requestPath: request ? requestFile.path.toString() : ""

    // ---- apps mode state ---------------------------------------------------------

    property var usage: ({})

    // ---- opening -----------------------------------------------------------------

    function openMenu(route) {
        finishRequest(null)
        mode = "menu"
        stack = route && menu.entries[route] ? routeStack(route) : []
        reset()
        guardProc.running = false
        guardProc.command = ["bash", "-c", Model.guardScript(menu)]
        guardProc.running = true
    }

    function openApps() {
        finishRequest(null)
        mode = "apps"
        stack = []
        reset()
    }

    // `path` is a JSON request written by menu-select.
    function openSelect(path) {
        finishRequest(null)
        requestFile.path = ""
        requestFile.path = path
    }

    function routeStack(route) {
        const out = []
        let id = route
        while (id) {
            out.unshift(id)
            id = menu.entries[id] ? menu.entries[id].parent : ""
        }
        return out
    }

    function reset() {
        search.text = request && request.filter ? request.filter : ""
        cursor = 0
        hoverOrigin = Qt.point(-1, -1)
        search.forceActiveFocus()
    }

    // Answer an open select request: the chosen value, or null for cancel.
    function finishRequest(value) {
        if (!request)
            return
        const done = request
        request = null
        lines = []
        // A small shell write rather than FileView: retargeting a FileView and
        // writing straight away could drop the write, leaving menu-select
        // without an answer.
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" > "$2" && printf "%s\\n" "$3" > "$4"', "sh",
                                 value === null ? "" : value, done.result,
                                 value === null ? "cancel" : "ok", done.done])
    }

    function close() {
        finishRequest(null)
        root.closeRequested()
    }

    onShownChanged: if (!shown) finishRequest(null)

    FileView {
        id: menuFile
        path: Quickshell.shellPath("menu.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.menu = Model.parseMenu(text()) } catch (e) { console.warn("menu.json:", e) }
        }
    }

    Process {
        id: guardProc
        stdout: StdioCollector {
            onStreamFinished: root.guards = Model.parseGuards(text)
        }
    }

    FileView {
        id: requestFile
        blockLoading: true
        onLoaded: {
            let data
            try { data = JSON.parse(text()) } catch (e) { return }
            root.mode = "select"
            root.stack = []
            root.request = data
            linesFile.path = ""
            linesFile.path = data.lines
            root.reset()
        }
    }

    FileView {
        id: linesFile
        blockLoading: true
        onLoaded: {
            const cols = root.request ? root.request.displayColumns : []
            const iconColumn = root.request ? root.request.iconColumn : 0
            root.lines = text().split("\n").filter(l => l.length).map(l => Model.parseLine(l, cols, iconColumn))
        }
    }


    FileView {
        id: usageFile
        path: root.home + "/.local/state/dotfiles-app-usage.json"
        printErrors: false
        onLoaded: {
            try { root.usage = JSON.parse(text()) } catch (e) {}
        }
    }

    // ---- rows --------------------------------------------------------------------

    readonly property var apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .slice()
        .sort((a, b) => (usage[b.id] || 0) - (usage[a.id] || 0) || a.name.localeCompare(b.name))

    function entryRow(e, withPath) {
        const g = guards[e.id] || {}
        return {
            kind: "entry",
            entry: e,
            icon: e.icon,
            label: e.label,
            detail: withPath && e.parent ? Model.breadcrumb(menu, e.parent) + "  ·  " + (e.description || "")
                                         : (e.description || ""),
            trailing: e.isSubmenu ? "submenu" : e.state ? (g.s ? "on" : "off") : "",
        }
    }

    function appRow(app) {
        return {
            kind: "app",
            app: app,
            icon: "",
            image: Quickshell.iconPath(app.icon, true),
            label: app.name,
            detail: app.genericName || app.comment || "",
            trailing: "",
        }
    }

    function appHits(query, limit) {
        const hits = []
        for (const app of apps) {
            const s = Model.score(query, app.name, (app.keywords || []).join(" ") + " " + (app.genericName || ""), app.comment)
            if (s > 0) hits.push({ app: app, score: s })
        }
        hits.sort((a, b) => b.score - a.score)
        return hits.slice(0, limit).map(h => appRow(h.app))
    }

    readonly property var rows: {
        const query = search.text.trim()
        if (mode === "select") {
            if (!query)
                return lines.map(l => ({ kind: "line", line: l, icon: l.icon, label: l.label, detail: l.detail, trailing: "" }))
            const hits = []
            for (const l of lines) {
                const s = Model.score(query, l.label, l.detail, l.value)
                if (s > 0) hits.push({ l: l, s: s })
            }
            hits.sort((a, b) => b.s - a.s)
            return hits.map(h => ({ kind: "line", line: h.l, icon: h.l.icon, label: h.l.label, detail: h.l.detail, trailing: "" }))
        }
        if (mode === "apps")
            return query ? appHits(query, 60) : apps.map(appRow)
        // Menu mode: the current submenu, or a search through everything.
        if (!query)
            return Model.children(menu, route, guards).map(e => entryRow(e, false))
        const found = Model.rankEntries(menu, query, guards).map(h => entryRow(h.entry, true))
        return route ? found : found.concat(appHits(query, 6))
    }

    onRowsChanged: cursor = Math.min(cursor, Math.max(0, rows.length - 1))

    // ---- actions -----------------------------------------------------------------

    function run(command) {
        Quickshell.execDetached(["bash", "-c", menu.prelude + "\n" + command])
    }

    function activate(row, custom) {
        if (mode === "select") {
            // Typed text is returned for input prompts, for Shift+Enter, and
            // when nothing matches, but only if the caller allows custom text.
            if (inputOnly)
                finishRequest(search.text)
            else if (custom && request && request.allowCustom && search.text !== "")
                finishRequest(search.text)
            else if (row && !custom)
                finishRequest(row.line.value)
            else
                return
            return root.closeRequested()
        }
        if (!row)
            return
        if (row.kind === "app") {
            const counts = Object.assign({}, usage)
            counts[row.app.id] = (counts[row.app.id] || 0) + 1
            usage = counts
            usageFile.setText(JSON.stringify(counts))
            row.app.execute()
            return root.closeRequested()
        }
        const e = row.entry
        if (e.isSubmenu) {
            stack = routeStack(e.id)
            search.text = ""
            cursor = 0
            return
        }
        root.closeRequested()
        run(e.action)
    }

    function back() {
        if (mode !== "menu" || !stack.length)
            return false
        const left = stack[stack.length - 1]
        stack = stack.slice(0, -1)
        search.text = ""
        const siblings = Model.children(menu, route, guards)
        cursor = Math.max(0, siblings.findIndex(e => e.id === left))
        return true
    }

    readonly property string title: {
        if (mode === "select")
            return request && request.prompt ? request.prompt : "Choose"
        if (mode === "apps")
            return "Apps"
        return route ? Model.breadcrumb(menu, route) : "Desktop"
    }

    readonly property string placeholder: {
        if (mode === "select" && request && request.placeholder)
            return request.placeholder
        if (mode === "select" && request && request.inputOnly)
            return "Type and press Enter"
        if (mode === "select")
            return "Search…"
        if (mode === "apps")
            return "Search applications…"
        return route ? "Filter " + (menu.entries[route] ? menu.entries[route].label : "") + "…"
                     : "Search the menu and apps…"
    }

    readonly property bool inputOnly: mode === "select" && request !== null && request.inputOnly === true

    // ---- window ------------------------------------------------------------------

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: card

        readonly property int wanted: root.mode === "select" && root.request && root.request.width ? root.request.width : 600

        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.16)
        width: Math.min(wanted, parent.width - 40)
        height: layout.implicitHeight + 32
        radius: 18
        color: Theme.background
        border.width: 1
        border.color: Theme.alpha(Theme.outline, 0.3)
        opacity: root.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: layout

            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12

            // ---- header -----------------------------------------------------------

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 8

                Rectangle {
                    visible: root.mode === "menu" && root.stack.length > 0
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 8
                    color: backHover.hovered ? Theme.alpha(Theme.foreground, 0.1) : "transparent"

                    HoverHandler { id: backHover }

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: Theme.iconFont
                        font.pixelSize: 15
                        color: Theme.muted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.back()
                    }
                }

                Text {
                    text: root.title
                    color: Theme.foreground
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    visible: !root.inputOnly
                    text: root.rows.length === 1 ? "1 item" : root.rows.length + " items"
                    color: Theme.alpha(Theme.muted, 0.8)
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 12
                color: Theme.alpha(Theme.foreground, 0.06)
                border.width: 1
                border.color: Theme.alpha(Theme.primary, 0.45)

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.inputOnly ? "󰞷" : "󰍉"
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    color: Theme.muted
                }

                TextInput {
                    id: search

                    anchors.left: searchIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.foreground
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.primaryText
                    font.pixelSize: 14
                    clip: true

                    onTextChanged: root.cursor = 0

                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier
                        const key = event.key
                        if (key === Qt.Key_Escape) {
                            if (text !== "" && !root.inputOnly) text = ""
                            else if (!root.back()) root.close()
                        } else if (key === Qt.Key_Down || key === Qt.Key_Tab || (ctrl && key === Qt.Key_J) || (ctrl && key === Qt.Key_N)) {
                            root.cursor = Math.min(root.rows.length - 1, root.cursor + 1)
                        } else if (key === Qt.Key_Up || key === Qt.Key_Backtab || (ctrl && key === Qt.Key_K) || (ctrl && key === Qt.Key_P)) {
                            root.cursor = Math.max(0, root.cursor - 1)
                        } else if (key === Qt.Key_PageDown) {
                            root.cursor = Math.min(root.rows.length - 1, root.cursor + 8)
                        } else if (key === Qt.Key_PageUp) {
                            root.cursor = Math.max(0, root.cursor - 8)
                        } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                            root.activate(root.rows[root.cursor], (event.modifiers & Qt.ShiftModifier) || root.rows.length === 0)
                        } else if (key === Qt.Key_Right && cursorPosition === text.length && root.rows[root.cursor]
                                   && root.rows[root.cursor].trailing === "submenu") {
                            root.activate(root.rows[root.cursor], false)
                        } else if ((key === Qt.Key_Left || key === Qt.Key_Backspace) && text === "") {
                            if (!root.back()) return
                        } else {
                            return
                        }
                        event.accepted = true
                    }

                    Text {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.placeholder
                        color: Theme.muted
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            Text {
                visible: root.mode === "select" && root.request !== null && !!root.request.message
                text: root.request && root.request.message ? root.request.message : ""
                color: Theme.muted
                font.pixelSize: 12
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.leftMargin: 4
            }

            // ---- rows -------------------------------------------------------------

            ListView {
                id: list

                visible: !root.inputOnly
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, root.mode === "select" && root.request && root.request.lines
                                                              ? (root.request.maxRows || 10) * 52 : 9 * 54)
                clip: true
                model: root.rows
                currentIndex: root.cursor
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                spacing: 2

                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.cursor

                    width: ListView.view.width
                    implicitHeight: modelData.detail ? 52 : 42
                    radius: 11
                    color: current ? Theme.alpha(Theme.primary, 0.16) : "transparent"
                    border.width: current ? 1 : 0
                    border.color: Theme.alpha(Theme.primary, 0.35)

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => {
                            const p = mapToItem(null, mouse.x, mouse.y)
                            if (root.hoverOrigin.x < 0) {
                                root.hoverOrigin = p
                                return
                            }
                            if (Math.abs(p.x - root.hoverOrigin.x) + Math.abs(p.y - root.hoverOrigin.y) > 4)
                                root.cursor = row.index
                        }
                        onClicked: root.activate(row.modelData, false)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Item {
                            visible: row.modelData.icon !== "" || row.modelData.image !== undefined
                            implicitWidth: 26
                            implicitHeight: 26

                            Text {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                text: row.modelData.icon || (row.modelData.kind === "app" ? "󰀻" : "")
                                font.family: Theme.iconFont
                                font.pixelSize: root.mode === "select" && root.request && root.request.iconColumn ? 21 : 18
                                color: row.current ? Theme.primary : Theme.foreground
                            }

                            IconImage {
                                id: appIcon
                                anchors.fill: parent
                                visible: !!row.modelData.image
                                source: row.modelData.image || ""
                                asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: row.modelData.label
                                color: Theme.foreground
                                font.pixelSize: 13
                                font.weight: row.current ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: text !== ""
                                text: row.modelData.detail || ""
                                color: Theme.muted
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            visible: row.modelData.trailing === "on" || row.modelData.trailing === "off"
                            implicitWidth: stateLabel.implicitWidth + 16
                            implicitHeight: 20
                            radius: 10
                            color: row.modelData.trailing === "on" ? Theme.alpha(Theme.primary, 0.22) : Theme.alpha(Theme.foreground, 0.07)

                            Text {
                                id: stateLabel
                                anchors.centerIn: parent
                                text: row.modelData.trailing === "on" ? "On" : "Off"
                                color: row.modelData.trailing === "on" ? Theme.primary : Theme.muted
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            visible: row.modelData.trailing === "submenu"
                            text: "󰅂"
                            font.family: Theme.iconFont
                            font.pixelSize: 15
                            color: Theme.muted
                        }
                    }
                }
            }

            Text {
                visible: !root.inputOnly && root.rows.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                horizontalAlignment: Text.AlignHCenter
                text: "Nothing matches"
                color: Theme.muted
                font.pixelSize: 12
            }

        }
    }
}
