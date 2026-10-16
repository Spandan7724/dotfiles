import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
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
        cursor = initialCursor()
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
            const req = root.request || {}
            const active = Model.parseRowList(req.active)
            // Long lists (file search) repeat a few icon names many times,
            // so each name is resolved once.
            const pictures = {}
            const picture = name => {
                if (!(name in pictures)) {
                    // A window class (zen, dev.zed.Zed) finds its app's icon too.
                    const entry = name.startsWith("/") ? null : DesktopEntries.heuristicLookup(name)
                    pictures[name] = name.startsWith("/") ? "file://" + name
                                   : Quickshell.iconPath(name, true) || (entry ? Quickshell.iconPath(entry.icon, true) : "")
                }
                return pictures[name]
            }
            root.lines = text().split("\n").filter(l => l.length).map((l, i) => {
                const line = Model.parseLine(l, req)
                if (active[i])
                    line.current = true
                // An icon theme name or an image path in the icon column is
                // shown as a picture, like the app launcher's icons.
                if (/^(\/|[A-Za-z0-9._+-]{2,}$)/.test(line.icon)) {
                    line.image = picture(line.icon) || undefined
                    line.icon = line.image ? "" : "\u{f003b}"
                }
                return line
            })
            root.cursor = root.initialCursor()
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

    // Desktop entries kept out of the launcher: one id per line in
    // hidden-apps.txt, e.g. "cmake-gui" (with or without ".desktop").
    property var hiddenApps: []

    FileView {
        path: Quickshell.shellPath("hidden-apps.txt")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.hiddenApps = text().split("\n")
            .map(l => l.replace(/#.*/, "").trim().replace(/\.desktop$/, ""))
            .filter(l => l.length)
    }

    // ---- rows --------------------------------------------------------------------

    readonly property var apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay && !hiddenApps.includes(a.id.replace(/\.desktop$/, "")))
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

    function lineRow(l) {
        return { kind: "line", line: l, icon: l.icon, image: l.image, label: l.label, detail: l.detail,
                 section: l.section, swatches: l.swatches, trailing: l.current ? "current" : "" }
    }

    readonly property var rows: {
        const query = search.text.trim()
        if (mode === "select") {
            // Section headers only make sense in the original order.
            if (!query)
                return Model.withSections(lines.map(lineRow))
            const hits = []
            for (const l of lines) {
                const s = Model.score(query, l.label, l.detail + " " + l.section, l.value)
                if (s > 0) hits.push({ l: l, s: s })
            }
            hits.sort((a, b) => b.s - a.s)
            return hits.map(h => lineRow(h.l))
        }
        if (mode === "apps")
            return query ? appHits(query, 60) : apps.map(appRow)
        // Menu mode: the current submenu, or a search through everything.
        if (!query)
            return Model.children(menu, route, guards).map(e => entryRow(e, false))
        const found = Model.rankEntries(menu, query, guards).map(h => entryRow(h.entry, true))
        return route ? found : found.concat(appHits(query, 6))
    }

    onRowsChanged: {
        cursor = Math.min(cursor, Math.max(0, rows.length - 1))
        settleCursor()
    }

    // Section headers are never selected: the cursor steps over them.
    function selectable(i) {
        return i >= 0 && i < rows.length && rows[i].kind !== "header"
    }

    function moveCursor(delta) {
        const step = delta > 0 ? 1 : -1
        let i = Math.max(0, Math.min(rows.length - 1, cursor + delta))
        while (i >= 0 && i < rows.length && !selectable(i))
            i += step
        if (!selectable(i))
            return
        cursor = i
    }

    // Moves the cursor off a header, forwards first.
    function settleCursor() {
        if (selectable(cursor) || !rows.length)
            return
        let i = cursor
        while (i < rows.length && !selectable(i)) i++
        if (!selectable(i)) {
            i = cursor
            while (i >= 0 && !selectable(i)) i--
        }
        if (selectable(i))
            cursor = i
    }

    onCursorChanged: settleCursor()

    // Where the cursor starts: menu-select's -selected-row, else the top.
    function initialCursor() {
        const sel = mode === "select" && request ? request.selectedRow : 0
        if (sel > 0 && lines[sel] && !search.text.trim())
            return Math.max(0, rows.findIndex(r => r.line === lines[sel]))
        return 0
    }

    readonly property int itemCount: rows.filter(r => r.kind !== "header").length

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
            // execute() ignores Terminal=true, so console apps (btop, htop...)
            // would start with no tty and exit; wrap them in the default terminal.
            if (row.app.runInTerminal)
                Quickshell.execDetached({
                    command: [Quickshell.env("HOME") + "/.config/hypr/scripts/default-launcher.sh",
                              "terminal", "-e"].concat(row.app.command),
                    workingDirectory: row.app.workingDirectory,
                })
            else
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

    // ---- presentation helpers ----------------------------------------------------

    function escapeMarkup(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    // The label as StyledText with the searched words picked out, the same
    // words Model.score matched on (word starts first, then anywhere).
    function markMatch(label) {
        label = label || ""
        const query = search.text.trim().toLowerCase()
        if (!query)
            return escapeMarkup(label)
        const lower = label.toLowerCase()
        const marked = new Array(label.length).fill(false)
        for (const w of query.split(/\s+/)) {
            if (!w)
                continue
            let at = (" " + lower).indexOf(" " + w)
            if (at < 0)
                at = lower.indexOf(w)
            for (let i = at; at >= 0 && i < at + w.length; i++)
                marked[i] = true
        }
        const strong = Theme.foreground.toString()
        let out = ""
        for (let i = 0; i < label.length;) {
            let j = i
            while (j < label.length && marked[j] === marked[i])
                j++
            const part = escapeMarkup(label.slice(i, j))
            out += marked[i] ? '<b><font color="' + strong + '">' + part + "</font></b>" : part
            i = j
        }
        return out
    }

    // Header path: "Desktop › Style › Wallpaper" in menu mode, each earlier
    // step clickable; otherwise just the title.
    readonly property var crumbs: mode !== "menu"
        ? [{ label: title, depth: -1 }]
        : [{ label: "Desktop", depth: 0 }].concat(
              stack.map((id, i) => ({ label: menu.entries[id] ? menu.entries[id].label : id, depth: i + 1 })))

    function jumpTo(depth) {
        if (depth < 0 || depth >= stack.length)
            return
        stack = stack.slice(0, depth)
        search.text = ""
        cursor = 0
    }

    // Slide the rows in from the side we are heading towards when entering
    // or leaving a submenu.
    property int shownDepth: 0
    onRouteChanged: {
        const depth = stack.length
        if (shown && mode === "menu" && depth !== shownDepth) {
            rowsSlide.from = depth > shownDepth ? 36 : -36
            rowsIn.restart()
        }
        shownDepth = depth
    }

    // ---- window ------------------------------------------------------------------

    // Dimmed backdrop. Its alpha stays under the Hyprland layer rule's
    // ignore_alpha (hypr/rules.lua), so only the card itself gets blurred.
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.32 : 0.18)
        opacity: root.shown ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 160 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        offset.y: 14
        blur: 44
        spread: -2
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.45 : 0.22)
        opacity: card.opacity
        scale: card.scale
        transformOrigin: card.transformOrigin
    }

    Rectangle {
        id: card

        readonly property int wanted: root.mode === "select" && root.request && root.request.width ? root.request.width : 600

        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.16)
        width: Math.min(wanted, parent.width - 40)
        height: layout.implicitHeight + 32
        radius: 18
        color: Theme.card
        border.width: 1
        border.color: Theme.alpha(Theme.foreground, Theme.dark ? 0.09 : 0.12)
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        transformOrigin: Item.Top

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

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
                        color: backHover.hovered ? Theme.foreground : Theme.dimText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.back()
                    }
                }

                // Breadcrumbs; the clip keeps a deep path from pushing the
                // item count off the card.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: crumbRow.implicitHeight
                    clip: true

                    Row {
                        id: crumbRow
                        spacing: 6

                        Repeater {
                            model: root.crumbs

                            Row {
                                id: crumb

                                required property var modelData
                                required property int index
                                readonly property bool last: index === root.crumbs.length - 1

                                spacing: 6

                                Text {
                                    visible: crumb.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "›"
                                    color: Theme.faintText
                                    font.pixelSize: 15
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: crumb.modelData.label
                                    color: crumb.last ? Theme.foreground
                                         : crumbHover.hovered ? Theme.foreground : Theme.dimText
                                    font.pixelSize: 15
                                    font.weight: crumb.last ? Font.DemiBold : Font.Normal

                                    HoverHandler {
                                        id: crumbHover
                                        enabled: !crumb.last && crumb.modelData.depth >= 0
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        enabled: crumbHover.enabled
                                        onTapped: root.jumpTo(crumb.modelData.depth)
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: !root.inputOnly
                    text: root.itemCount === 1 ? "1 item" : root.itemCount + " items"
                    color: Theme.faintText
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 12
                color: Theme.alpha(Theme.foreground, Theme.dark ? 0.06 : 0.05)
                border.width: 1
                border.color: Theme.alpha(Theme.foreground, Theme.dark ? 0.12 : 0.16)

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.inputOnly ? "󰞷" : "󰍉"
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    color: search.text !== "" ? Theme.foreground : Theme.dimText
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
                            root.moveCursor(1)
                        } else if (key === Qt.Key_Up || key === Qt.Key_Backtab || (ctrl && key === Qt.Key_K) || (ctrl && key === Qt.Key_P)) {
                            root.moveCursor(-1)
                        } else if (key === Qt.Key_PageDown) {
                            root.moveCursor(8)
                        } else if (key === Qt.Key_PageUp) {
                            root.moveCursor(-8)
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
                        color: Theme.faintText
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            Text {
                visible: root.mode === "select" && root.request !== null && !!root.request.message
                text: root.request && root.request.message ? root.request.message : ""
                color: Theme.dimText
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
                spacing: 2

                // The highlight is drawn once and slides between rows.
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 140
                highlightMoveVelocity: -1
                highlightResizeDuration: 140
                highlightResizeVelocity: -1

                highlight: Rectangle {
                    visible: list.count > 0
                    radius: 11
                    color: Theme.alpha(Theme.foreground, Theme.dark ? 0.07 : 0.06)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.alpha(Theme.primary, 0.18)
                        border.width: 1
                        border.color: Theme.alpha(Theme.primary, 0.4)
                    }

                    // Accent bar on the leading edge.
                    Rectangle {
                        x: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height - 20
                        radius: 2
                        color: Theme.primary
                    }
                }

                transform: Translate { id: rowsShift }

                ParallelAnimation {
                    id: rowsIn

                    NumberAnimation {
                        id: rowsSlide
                        target: rowsShift
                        property: "x"
                        to: 0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: list
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                // A section's first row also brings its header into view.
                onCurrentIndexChanged: {
                    positionViewAtIndex(currentIndex, ListView.Contain)
                    if (currentIndex > 0 && !root.selectable(currentIndex - 1))
                        positionViewAtIndex(currentIndex - 1, ListView.Contain)
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: index === root.cursor
                    readonly property bool isApp: !!modelData.image
                    readonly property bool header: modelData.kind === "header"

                    width: ListView.view.width
                    implicitHeight: header ? (index === 0 ? 24 : 34) : modelData.detail ? 54 : 44

                    // Section header: a small caps label with a hairline.
                    RowLayout {
                        visible: row.header
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 6
                        spacing: 10

                        Text {
                            text: row.header ? row.modelData.label.toUpperCase() : ""
                            color: Theme.faintText
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Theme.alpha(Theme.foreground, Theme.dark ? 0.08 : 0.1)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.header
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
                        visible: !row.header
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 12

                        Item {
                            visible: row.modelData.icon !== "" || row.modelData.image !== undefined
                            implicitWidth: 32
                            implicitHeight: 32

                            // Glyphs sit on a tinted tile, like PanelHeader's
                            // icon; app icons bring their own shape.
                            Rectangle {
                                anchors.fill: parent
                                visible: !row.isApp
                                radius: 9
                                color: row.current ? Theme.alpha(Theme.primary, 0.3)
                                                   : Theme.alpha(Theme.foreground, Theme.dark ? 0.06 : 0.07)

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !row.isApp
                                text: row.modelData.icon || (row.modelData.kind === "app" ? "󰀻" : "")
                                font.family: Theme.iconFont
                                font.pixelSize: root.mode === "select" && root.request && root.request.iconColumn ? 19 : 16
                                color: row.current ? Theme.foreground : Theme.alpha(Theme.foreground, 0.8)
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: row.modelData.kind === "app" ? 28 : 26
                                visible: row.isApp
                                source: row.modelData.image || ""
                                asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.markMatch(row.modelData.label)
                                textFormat: Text.StyledText
                                // While searching the unmatched letters step
                                // back so the matched ones stand out.
                                color: search.text.trim() !== "" ? Theme.alpha(Theme.foreground, 0.72)
                                     : row.current ? Theme.foreground
                                     : Theme.alpha(Theme.foreground, 0.9)
                                font.pixelSize: 13
                                font.weight: row.current ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: text !== ""
                                text: row.modelData.detail || ""
                                color: row.current ? Theme.alpha(Theme.foreground, 0.65) : Theme.dimText
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Colour previews (the theme picker's palettes). The
                        // ring keeps a dot that matches the card visible.
                        Row {
                            visible: !!row.modelData.swatches && row.modelData.swatches.length > 0
                            spacing: 5

                            Repeater {
                                model: row.modelData.swatches || []

                                Rectangle {
                                    required property string modelData
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: modelData
                                    border.width: 1
                                    border.color: Theme.alpha(Theme.foreground, 0.22)
                                }
                            }
                        }

                        Rectangle {
                            readonly property bool lit: row.modelData.trailing === "on" || row.modelData.trailing === "current"

                            visible: row.modelData.trailing === "on" || row.modelData.trailing === "off"
                                     || row.modelData.trailing === "current"
                            implicitWidth: stateLabel.implicitWidth + 16
                            implicitHeight: 20
                            radius: 10
                            color: lit ? Theme.alpha(Theme.primary, 0.3) : Theme.alpha(Theme.foreground, 0.07)

                            Text {
                                id: stateLabel
                                anchors.centerIn: parent
                                text: row.modelData.trailing === "current" ? "Current"
                                    : row.modelData.trailing === "on" ? "On" : "Off"
                                color: parent.lit ? Theme.foreground : Theme.dimText
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            visible: row.modelData.trailing === "submenu"
                            text: "󰅂"
                            font.family: Theme.iconFont
                            font.pixelSize: 15
                            color: row.current ? Theme.foreground : Theme.faintText
                        }
                    }
                }
            }

            ColumnLayout {
                visible: !root.inputOnly && root.itemCount === 0
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰈞"
                    font.family: Theme.iconFont
                    font.pixelSize: 26
                    color: Theme.faintText
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Nothing matches"
                    color: Theme.dimText
                    font.pixelSize: 12
                }
            }
        }
    }
}
