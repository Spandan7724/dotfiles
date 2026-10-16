// Virtual machine manager: a themed front end for libvirt (qemu:///system).
// All work happens in vmctl.sh; this file only renders its JSON and calls it.
//
// Launch: quickshell -n -c vm-manager   (Super + Shift + V)
//
// Keys, list page: Up/Down or j/k select a VM, Enter starts it (or opens the
// console if it is running), s shut down, r reboot, Shift+F force stop,
// e settings, Delete twice to delete, n new VM, m virt-manager, F5 refresh,
// Escape closes.
// New VM page: type to search, Up/Down + Enter pick an OS, Tab moves between
// fields, Ctrl+Enter creates, Escape goes back.

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel

FloatingWindow {
    id: root

    title: "Virtual machines"
    implicitWidth: 900
    implicitHeight: 640
    color: Theme.background

    readonly property string ctl: Quickshell.shellPath("vmctl.sh")
    readonly property string home: Quickshell.env("HOME")

    // ---- state from vmctl.sh ------------------------------------------------

    property var vms: []
    property var jobs: []
    property bool libvirtOk: true
    property bool loaded: false

    property var catalog: []
    property string catalogError: ""
    property bool catalogLoading: false
    property var poolIsos: []

    property int hostCpus: 4
    property int hostMemGiB: 8

    // ---- UI state -------------------------------------------------------------

    property string page: "list"          // list | new
    property string pendingDelete: ""     // VM awaiting a second click on Delete
    property string selVm: ""             // keyboard-selected VM; by name so refreshes keep it

    readonly property var curVm: vms.find(v => v.name === selVm) || vms[0] || null

    function run(args) {
        Quickshell.execDetached(["bash", ctl].concat(args))
        refreshSoon.restart()
    }

    function isRunning(vm) {
        return vm.state === "running" || vm.state === "paused" || vm.state === "in shutdown"
    }

    function moveSel(step) {
        const i = Math.max(0, Math.min(vms.length - 1, vms.indexOf(curVm) + step))
        selVm = vms[i].name
        const card = vmRepeater.itemAt(i)
        if (card) cardList.ensureVisible(card.y, card.height)
    }

    function askDelete(name) {
        if (pendingDelete === name) {
            pendingDelete = ""
            run(["delete", name])
        } else {
            pendingDelete = name
            deleteReset.restart()
        }
    }

    function listKey(event) {
        const k = event.key
        const vm = curVm
        event.accepted = true
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            event.accepted = false
        else if (k === Qt.Key_N) openNew()
        else if (k === Qt.Key_M) run(["manager"])
        else if (k === Qt.Key_F5) refresh()
        else if (!vm) event.accepted = false
        else if (k === Qt.Key_Down || k === Qt.Key_J) moveSel(1)
        else if (k === Qt.Key_Up || k === Qt.Key_K) moveSel(-1)
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) run([isRunning(vm) ? "console" : "start", vm.name])
        else if (k === Qt.Key_S && isRunning(vm)) run(["shutdown", vm.name])
        else if (k === Qt.Key_R && isRunning(vm)) run(["reboot", vm.name])
        // Shift, so one stray key cannot pull the plug on a running guest.
        else if (k === Qt.Key_F && (event.modifiers & Qt.ShiftModifier) && isRunning(vm)) run(["destroy", vm.name])
        else if (k === Qt.Key_E && !isRunning(vm)) run(["details", vm.name])
        else if (k === Qt.Key_Delete && !isRunning(vm)) askDelete(vm.name)
        else event.accepted = false
    }

    // Keyboard focus follows the page: the list takes keys, the new-VM page
    // starts in its search box.
    onPageChanged: {
        if (page === "list") listPage.forceActiveFocus()
        else if (creator.mode === "download") searchField.focusInput()
    }

    function refresh() {
        if (!lister.running)
            lister.running = true
    }

    function openNew() {
        page = "new"
        if (catalog.length === 0 && !catalogLoading) {
            catalogLoading = true
            catalogProc.running = true
        }
        isoProc.running = true
    }

    function fmtMem(mib) {
        const gib = mib / 1024
        return (gib < 10 && gib % 1 !== 0 ? gib.toFixed(1) : Math.round(gib)) + " GB"
    }

    Process {
        id: lister
        command: ["bash", root.ctl, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.vms = d.vms
                    root.jobs = d.jobs
                    root.libvirtOk = d.libvirt
                    root.loaded = true
                } catch (e) {}
            }
        }
    }

    Process {
        id: catalogProc
        command: ["bash", root.ctl, "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.catalog = d.items
                    root.catalogError = d.error
                } catch (e) {
                    root.catalogError = "Could not read the OS catalogue."
                }
                root.catalogLoading = false
            }
        }
    }

    Process {
        id: isoProc
        command: ["bash", root.ctl, "isos"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.poolIsos = JSON.parse(text) } catch (e) {}
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "nproc; awk '/MemTotal/ { print int($2 / 1048576) }' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split("\n")
                root.hostCpus = parseInt(v[0]) || 4
                root.hostMemGiB = parseInt(v[1]) || 8
            }
        }
    }

    // Refresh only while the window is on screen: listing VMs runs several
    // virsh and jq processes, and nobody needs it for a hidden window.
    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Closing the window from the compositor (Super+Q, the close button) has
    // to end the program too; only Escape used to, which left a hidden copy
    // running in the background.
    onVisibleChanged: if (!visible) Qt.quit()

    Connections {
        target: Quickshell
        function onLastWindowClosed() { Qt.quit() }
    }

    Timer {
        id: refreshSoon
        interval: 800
        onTriggered: root.refresh()
    }

    Timer {
        id: deleteReset
        interval: 3000
        onTriggered: root.pendingDelete = ""
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.page === "new" ? root.page = "list" : Qt.quit()
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: root.openNew()
    }

    Shortcut {
        sequences: ["Ctrl+Return", "Ctrl+Enter"]
        enabled: root.page === "new"
        onActivated: creator.create()
    }

    // ---- reusable pieces ------------------------------------------------------

    component Btn: Rectangle {
        id: btn

        property string text: ""
        property string icon: ""
        property bool primary: false
        property bool danger: false
        property bool active: true
        signal clicked

        implicitHeight: 34
        implicitWidth: btnRow.implicitWidth + 24
        radius: 9
        opacity: active ? 1 : 0.4
        color: primary ? Theme.primary
             : danger && hover.containsMouse ? Theme.alpha(Theme.error, 0.18)
             : hover.containsMouse ? Theme.surfaceVariant
             : Theme.alpha(Theme.surfaceVariant, 0.55)
        border.width: danger ? 1 : 0
        border.color: Theme.alpha(Theme.error, 0.6)

        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                visible: btn.icon !== ""
                text: btn.icon
                font.family: Theme.iconFont
                font.pixelSize: 15
                color: btn.primary ? Theme.primaryText : btn.danger ? Theme.error : Theme.foreground
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: btn.text !== ""
                text: btn.text
                font.pixelSize: 13
                font.weight: Font.Medium
                color: btn.primary ? Theme.primaryText : btn.danger ? Theme.error : Theme.foreground
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.active ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.active) btn.clicked()
        }
    }

    component Chip: Rectangle {
        id: chip

        property string text
        property bool selected: false
        signal clicked

        implicitHeight: 30
        implicitWidth: chipText.implicitWidth + 22
        radius: 15
        color: selected ? Theme.primary : chipHover.containsMouse ? Theme.surfaceVariant : "transparent"
        border.width: selected ? 0 : 1
        border.color: Theme.alpha(Theme.outline, 0.5)

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.text
            font.pixelSize: 12
            color: chip.selected ? Theme.primaryText : Theme.foreground
        }

        MouseArea {
            id: chipHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component Field: Rectangle {
        id: field

        property alias text: input.text
        property string placeholder: ""
        property string icon: ""
        signal upPressed
        signal downPressed
        signal accepted

        function focusInput() { input.forceActiveFocus() }

        implicitHeight: 36
        radius: 9
        color: Theme.alpha(Theme.surfaceVariant, 0.55)
        border.width: input.activeFocus ? 1 : 0
        border.color: Theme.primary

        Text {
            id: fieldIcon
            visible: field.icon !== ""
            text: field.icon
            font.family: Theme.iconFont
            font.pixelSize: 14
            color: Theme.muted
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: field.icon !== "" ? 34 : 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.foreground
            selectionColor: Theme.primary
            selectedTextColor: Theme.primaryText
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            activeFocusOnTab: true

            Keys.onUpPressed: field.upPressed()
            Keys.onDownPressed: field.downPressed()
            onAccepted: field.accepted()

            Text {
                visible: input.text === ""
                text: field.placeholder
                color: Theme.alpha(Theme.muted, 0.6)
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    component Stepper: RowLayout {
        id: stepper

        property string label
        property int value
        property int step: 1
        property int from: 1
        property int to: 64
        property string suffix: ""
        signal moved(int value)

        spacing: 10

        Text {
            text: stepper.label
            color: Theme.muted
            font.pixelSize: 13
            Layout.preferredWidth: 80
        }

        Btn {
            icon: "󰍴"
            implicitWidth: 34
            active: stepper.value > stepper.from
            onClicked: stepper.moved(Math.max(stepper.from, stepper.value - stepper.step))
        }

        Text {
            text: stepper.value + stepper.suffix
            color: Theme.foreground
            font.pixelSize: 14
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: 72
        }

        Btn {
            icon: "󰐕"
            implicitWidth: 34
            active: stepper.value < stepper.to
            onClicked: stepper.moved(Math.min(stepper.to, stepper.value + stepper.step))
        }
    }

    component IsoRow: Rectangle {
        id: isoRow

        property string title
        property bool selected: false
        signal clicked

        height: 38
        radius: 9
        color: selected ? Theme.alpha(Theme.primary, 0.18) : isoHover.containsMouse ? Theme.alpha(Theme.surfaceVariant, 0.6) : "transparent"

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰗮"
                font.family: Theme.iconFont
                font.pixelSize: 16
                color: isoRow.selected ? Theme.primary : Theme.muted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: isoRow.width - 50
                elide: Text.ElideMiddle
                text: isoRow.title
                color: isoRow.selected ? Theme.primary : Theme.foreground
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: isoHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: isoRow.clicked()
        }
    }

    component SectionLabel: Text {
        color: Theme.muted
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
    }

    // ---- layout -----------------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: root.page === "new" ? "󰐕" : "󰢹"
                font.family: Theme.iconFont
                font.pixelSize: 24
                color: Theme.primary
            }

            Text {
                text: root.page === "new" ? "New virtual machine" : "Virtual machines"
                color: Theme.foreground
                font.pixelSize: 20
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Btn {
                visible: root.page === "list"
                icon: "󰒓"
                text: "virt-manager"
                onClicked: root.run(["manager"])
            }

            Btn {
                visible: root.page === "list"
                primary: true
                icon: "󰐕"
                text: "New VM"
                onClicked: root.openNew()
            }

            Btn {
                visible: root.page === "new"
                icon: "󰁍"
                text: "Back"
                onClicked: root.page = "list"
            }
        }

        // ---- list page ----
        Item {
            id: listPage
            focus: true
            Keys.onPressed: event => root.listKey(event)
            visible: root.page === "list"
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                visible: root.loaded && (!root.libvirtOk || root.vms.length + root.jobs.length === 0)
                anchors.centerIn: parent
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.libvirtOk ? "󰢹" : "󰅙"
                    font.family: Theme.iconFont
                    font.pixelSize: 56
                    color: Theme.alpha(Theme.muted, 0.5)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.libvirtOk
                        ? "No virtual machines yet"
                        : "libvirt is not reachable.\nCheck that libvirtd is running and you are in the libvirt group."
                    color: Theme.muted
                    font.pixelSize: 14
                }

                Btn {
                    visible: root.libvirtOk
                    anchors.horizontalCenter: parent.horizontalCenter
                    primary: true
                    icon: "󰐕"
                    text: "Create your first VM"
                    onClicked: root.openNew()
                }
            }

            Flickable {
                id: cardList
                anchors.fill: parent
                contentHeight: cards.implicitHeight

                function ensureVisible(y, h) {
                    if (y < contentY) contentY = y
                    else if (y + h > contentY + height) contentY = y + h - height
                }
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: cards
                    width: parent.width
                    spacing: 10

                    // Creation jobs (downloading, importing, creating, or failed)
                    Repeater {
                        model: root.jobs

                        delegate: Rectangle {
                            id: jobCard
                            required property var modelData
                            readonly property bool failed: modelData.phase === "error"

                            width: cards.width
                            height: 84
                            radius: 14
                            color: Theme.surface
                            border.width: 1
                            border.color: failed ? Theme.alpha(Theme.error, 0.6) : Theme.alpha(Theme.outline, 0.25)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                Text {
                                    text: jobCard.failed ? "󰅚" : "󰇚"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 22
                                    color: jobCard.failed ? Theme.error : Theme.primary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Text {
                                        text: jobCard.modelData.name + "  ·  " + jobCard.modelData.label
                                        color: Theme.foreground
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: jobCard.failed ? jobCard.modelData.message
                                            : jobCard.modelData.phase === "downloading"
                                                ? "Downloading ISO  " + jobCard.modelData.percent + "%"
                                                : jobCard.modelData.message
                                        color: jobCard.failed ? Theme.error : Theme.muted
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        visible: !jobCard.failed
                                        Layout.fillWidth: true
                                        height: 4
                                        radius: 2
                                        color: Theme.alpha(Theme.surfaceVariant, 0.8)

                                        Rectangle {
                                            height: parent.height
                                            radius: 2
                                            color: Theme.primary
                                            width: jobCard.modelData.phase === "downloading"
                                                ? parent.width * jobCard.modelData.percent / 100
                                                : parent.width * 0.3
                                            // Indeterminate phases sweep instead of filling.
                                            x: jobCard.modelData.phase === "downloading" ? 0 : sweep.pos

                                            Behavior on width { NumberAnimation { duration: 400 } }
                                        }

                                        Item {
                                            id: sweep
                                            property real pos: 0
                                            NumberAnimation on pos {
                                                running: jobCard.modelData.phase !== "downloading"
                                                from: 0
                                                to: jobCard.width * 0.5
                                                duration: 1200
                                                loops: Animation.Infinite
                                                easing.type: Easing.InOutQuad
                                            }
                                        }
                                    }
                                }

                                Btn {
                                    text: jobCard.failed ? "Dismiss" : "Cancel"
                                    icon: "󰅖"
                                    onClicked: root.run([jobCard.failed ? "dismiss" : "cancel", jobCard.modelData.name])
                                }
                            }
                        }
                    }

                    // Virtual machines
                    Repeater {
                        id: vmRepeater
                        model: root.vms

                        delegate: Rectangle {
                            id: vmCard
                            required property var modelData
                            readonly property string vmState: modelData.state
                            readonly property bool running: vmState === "running" || vmState === "paused" || vmState === "in shutdown"
                            readonly property bool confirming: root.pendingDelete === modelData.name
                            readonly property bool keyed: root.curVm !== null && root.curVm.name === modelData.name

                            width: cards.width
                            height: 84
                            radius: 14
                            color: Theme.surface
                            border.width: keyed ? 2 : 1
                            border.color: keyed ? Theme.primary : Theme.alpha(Theme.outline, 0.25)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 14

                                Rectangle {
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: vmCard.vmState === "running" ? "#4ade80"
                                         : vmCard.running ? "#facc15"
                                         : Theme.alpha(Theme.muted, 0.4)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        text: vmCard.modelData.name
                                        color: Theme.foreground
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: [vmCard.modelData.label,
                                               vmCard.modelData.cpus + " vCPU",
                                               root.fmtMem(vmCard.modelData.memoryMiB),
                                               vmCard.vmState].filter(s => s).join("  ·  ")
                                        color: Theme.muted
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Row {
                                    spacing: 8

                                    Btn {
                                        visible: vmCard.running
                                        primary: true
                                        icon: "󰍹"
                                        text: "Console"
                                        onClicked: root.run(["console", vmCard.modelData.name])
                                    }
                                    Btn {
                                        visible: vmCard.running
                                        icon: "󰐥"
                                        text: "Shut down"
                                        onClicked: root.run(["shutdown", vmCard.modelData.name])
                                    }
                                    Btn {
                                        visible: vmCard.running
                                        icon: "󰜉"
                                        onClicked: root.run(["reboot", vmCard.modelData.name])
                                    }
                                    Btn {
                                        visible: vmCard.running
                                        danger: true
                                        icon: "󰚌"
                                        text: "Force stop"
                                        onClicked: root.run(["destroy", vmCard.modelData.name])
                                    }

                                    Btn {
                                        visible: !vmCard.running
                                        primary: true
                                        icon: "󰐊"
                                        text: "Start"
                                        onClicked: root.run(["start", vmCard.modelData.name])
                                    }
                                    Btn {
                                        visible: !vmCard.running
                                        icon: "󰒓"
                                        text: "Settings"
                                        onClicked: root.run(["details", vmCard.modelData.name])
                                    }
                                    Btn {
                                        visible: !vmCard.running
                                        danger: true
                                        icon: "󰩺"
                                        text: vmCard.confirming ? "Really delete?" : ""
                                        onClicked: root.askDelete(vmCard.modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- new VM page ----
        RowLayout {
            id: creator

            visible: root.page === "new"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            property string mode: "download"   // download | iso
            property string search: ""
            property int cursor: -1                // keyboard highlight in the OS list

            function moveCursor(step) {
                if (filteredOs.length === 0) return
                cursor = Math.max(0, Math.min(filteredOs.length - 1, cursor + step))
                osListView.positionViewAtIndex(cursor, ListView.Contain)
            }

            // Selection
            property string selOs: ""
            property string selName: ""
            property string selRelease: ""
            property string selEdition: ""
            property string selIsoSource: ""   // "iso" (a file) or "pool" (already imported)
            property string selIsoValue: ""

            property string vmName: ""
            property int cpus: 2
            property int memGiB: 4
            property int diskGiB: 30
            property string firmware: "uefi"
            property string graphics: "3d"       // 3d | basic

            readonly property var osList: {
                const seen = {}
                const out = []
                for (const it of root.catalog) {
                    if (seen[it.os]) continue
                    seen[it.os] = true
                    out.push({ os: it.os, name: it.name, icon: it.icon })
                }
                return out.sort((a, b) => a.name.localeCompare(b.name))
            }

            readonly property var filteredOs: {
                const q = search.toLowerCase()
                return q === "" ? osList
                    : osList.filter(o => o.name.toLowerCase().includes(q) || o.os.includes(q))
            }

            readonly property var releases: {
                const out = []
                for (const it of root.catalog)
                    if (it.os === selOs && !out.includes(it.release)) out.push(it.release)
                return out
            }

            readonly property var editions: {
                const out = []
                for (const it of root.catalog)
                    if (it.os === selOs && it.release === selRelease && it.edition !== "" && !out.includes(it.edition))
                        out.push(it.edition)
                return out
            }

            readonly property bool isWindows: selOs === "windows" || selOs === "windows-server"
                || /^win/i.test(selIsoValue)

            readonly property bool nameTaken: root.vms.some(v => v.name === vmName)
                || root.jobs.some(j => j.name === vmName)
            readonly property bool nameValid: /^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$/.test(vmName)

            readonly property bool ready: nameValid && !nameTaken && (mode === "download"
                ? selOs !== "" && selRelease !== "" && (editions.length === 0 || selEdition !== "")
                : selIsoValue !== "")

            function slug(s) {
                return s.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60)
            }

            // Newest stable-looking release: quickget lists releases oldest
            // first and puts dailies and betas alongside them.
            function defaultRelease(list) {
                if (list.includes("latest")) return "latest"
                const stable = list.filter(r => !/daily|dev|rawhide|beta|rc|testing|unstable|sid|nightly|insider|canary/i.test(r))
                return (stable.length ? stable : list)[(stable.length ? stable : list).length - 1] || ""
            }

            function defaultEdition(list) {
                const preferred = ["English International", "English (United States)", "desktop", "Workstation",
                                   "gnome", "GNOME", "kde", "KDE", "plasma", "standard", "cinnamon", "live"]
                for (const p of preferred)
                    if (list.includes(p)) return p
                return list[0] || ""
            }

            function applyDefaults(windows) {
                cpus = Math.min(windows ? 4 : 2, root.hostCpus)
                memGiB = Math.min(windows ? 8 : 4, Math.max(1, root.hostMemGiB - 2))
                diskGiB = windows ? 80 : 30
                // Windows has no virgl driver; everything else benefits from 3D.
                graphics = windows ? "basic" : "3d"
            }

            function pickOs(o) {
                selOs = o.os
                selName = o.name
                selRelease = defaultRelease(releases)
                selEdition = defaultEdition(editions)
                firmware = ["freedos", "kolibrios", "reactos", "tinycore"].includes(o.os) ? "bios" : "uefi"
                applyDefaults(isWindows)
                nameField.text = slug(o.os + "-" + selRelease)
            }

            function pickIso(source, value) {
                selIsoSource = source
                selIsoValue = value
                firmware = "uefi"
                applyDefaults(isWindows)
                nameField.text = slug(value.replace(/^.*\//, "").replace(/\.iso$/i, ""))
            }

            function create() {
                if (!ready) return
                const common = [vmName, String(cpus), String(memGiB * 1024), String(diskGiB), firmware,
                                isWindows ? "basic" : graphics]
                if (mode === "download") {
                    const label = [selName, selRelease, selEdition].filter(s => s).join(" ")
                    root.run(["create"].concat(common, [label, "quickget", selOs, selRelease], selEdition ? [selEdition] : []))
                } else {
                    const label = selIsoValue.replace(/^.*\//, "")
                    root.run(["create"].concat(common, [label, selIsoSource, selIsoValue]))
                }
                root.page = "list"
            }

            onEditionsChanged: if (!editions.includes(selEdition)) selEdition = defaultEdition(editions)

            // Left: what to install
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                radius: 14
                color: Theme.surface
                border.width: 1
                border.color: Theme.alpha(Theme.outline, 0.25)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Row {
                        spacing: 8
                        Chip {
                            text: "Download an OS"
                            selected: creator.mode === "download"
                            onClicked: creator.mode = "download"
                        }
                        Chip {
                            text: "Use an ISO"
                            selected: creator.mode === "iso"
                            onClicked: { creator.mode = "iso"; isoProc.running = true }
                        }
                    }

                    Field {
                        visible: creator.mode === "download"
                        Layout.fillWidth: true
                        icon: "󰍉"
                        id: searchField
                        placeholder: "Search " + creator.osList.length + " systems"
                        onTextChanged: {
                            creator.search = text
                            creator.cursor = text === "" ? -1 : 0
                        }
                        onUpPressed: creator.moveCursor(-1)
                        onDownPressed: creator.moveCursor(1)
                        onAccepted: if (creator.cursor >= 0 && creator.cursor < creator.filteredOs.length)
                                        creator.pickOs(creator.filteredOs[creator.cursor])
                    }

                    Text {
                        visible: creator.mode === "download" && (root.catalogLoading || root.catalogError !== "")
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: root.catalogLoading ? "Loading the OS catalogue (first time takes ~15 s)…" : root.catalogError
                        color: root.catalogError !== "" ? Theme.error : Theme.muted
                        font.pixelSize: 12
                    }

                    ListView {
                        id: osListView
                        visible: creator.mode === "download"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: creator.filteredOs
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: osRow
                            required property var modelData
                            required property int index
                            readonly property bool selected: creator.selOs === modelData.os

                            width: ListView.view.width
                            height: 42
                            radius: 9
                            color: selected ? Theme.alpha(Theme.primary, 0.18)
                                 : osHover.containsMouse || index === creator.cursor ? Theme.alpha(Theme.surfaceVariant, 0.6)
                                 : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                spacing: 12

                                Item {
                                    width: 26
                                    height: 26
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        id: osIcon
                                        anchors.fill: parent
                                        source: osRow.modelData.icon
                                        sourceSize: Qt.size(52, 52)
                                        asynchronous: true
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    Text {
                                        visible: osIcon.status !== Image.Ready
                                        anchors.centerIn: parent
                                        text: "󰍹"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 18
                                        color: Theme.muted
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: osRow.modelData.name
                                    color: osRow.selected ? Theme.primary : Theme.foreground
                                    font.pixelSize: 13
                                    font.weight: osRow.selected ? Font.DemiBold : Font.Normal
                                }
                            }

                            MouseArea {
                                id: osHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: creator.pickOs(osRow.modelData)
                            }
                        }
                    }

                    // ISO mode: ISOs already imported, then ~/Downloads
                    Flickable {
                        visible: creator.mode === "iso"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: isoColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: isoColumn
                            width: parent.width
                            spacing: 2

                            SectionLabel {
                                text: "Already downloaded"
                                visible: root.poolIsos.length > 0
                                topPadding: 4
                                bottomPadding: 6
                            }

                            Repeater {
                                model: root.poolIsos
                                delegate: IsoRow {
                                    required property string modelData
                                    width: isoColumn.width
                                    title: modelData
                                    selected: creator.selIsoValue === modelData
                                    onClicked: creator.pickIso("pool", modelData)
                                }
                            }

                            SectionLabel {
                                text: "In ~/Downloads"
                                topPadding: 12
                                bottomPadding: 6
                            }

                            Repeater {
                                model: FolderListModel {
                                    folder: "file://" + root.home + "/Downloads"
                                    nameFilters: ["*.iso", "*.ISO"]
                                    showDirs: false
                                    sortField: FolderListModel.Time
                                }
                                delegate: IsoRow {
                                    required property string filePath
                                    required property string fileName
                                    width: isoColumn.width
                                    title: fileName
                                    selected: creator.selIsoValue === filePath
                                    onClicked: creator.pickIso("iso", filePath)
                                }
                            }

                            SectionLabel {
                                text: "Or type a path"
                                topPadding: 12
                                bottomPadding: 6
                            }

                            Field {
                                width: parent.width
                                icon: "󰋊"
                                placeholder: "/path/to/installer.iso"
                                onTextChanged: if (text.toLowerCase().endsWith(".iso")) creator.pickIso("iso", text)
                            }
                        }
                    }
                }
            }

            // Right: how to set it up
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: details.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: details
                    width: parent.width
                    spacing: 14

                    Text {
                        visible: (creator.mode === "download" ? creator.selOs : creator.selIsoValue) === ""
                        Layout.fillWidth: true
                        Layout.topMargin: 40
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: creator.mode === "download"
                            ? "Pick a system on the left. Its installer ISO is downloaded for you and the VM boots straight into it."
                            : "Pick an ISO on the left, or type its path."
                        color: Theme.muted
                        font.pixelSize: 14
                    }

                    ColumnLayout {
                        visible: (creator.mode === "download" ? creator.selOs : creator.selIsoValue) !== ""
                        Layout.fillWidth: true
                        spacing: 14

                        Text {
                            text: creator.mode === "download" ? creator.selName : creator.selIsoValue.replace(/^.*\//, "")
                            color: Theme.foreground
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        SectionLabel { text: "Release"; visible: creator.mode === "download" }
                        Flow {
                            visible: creator.mode === "download"
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: creator.releases
                                Chip {
                                    required property string modelData
                                    text: modelData
                                    selected: creator.selRelease === modelData
                                    onClicked: {
                                        creator.selRelease = modelData
                                        nameField.text = creator.slug(creator.selOs + "-" + modelData)
                                    }
                                }
                            }
                        }

                        SectionLabel { text: creator.selOs === "windows" ? "Language" : "Edition"; visible: creator.mode === "download" && creator.editions.length > 0 }
                        Flow {
                            visible: creator.mode === "download" && creator.editions.length > 0
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: creator.editions
                                Chip {
                                    required property string modelData
                                    text: modelData
                                    selected: creator.selEdition === modelData
                                    onClicked: creator.selEdition = modelData
                                }
                            }
                        }

                        SectionLabel { text: "Name" }
                        Field {
                            id: nameField
                            Layout.fillWidth: true
                            Layout.maximumWidth: 360
                            onTextChanged: creator.vmName = text
                        }
                        Text {
                            visible: creator.vmName !== "" && (!creator.nameValid || creator.nameTaken)
                            text: creator.nameTaken ? "A VM with this name already exists."
                                : "Use letters, digits, dot, dash or underscore."
                            color: Theme.error
                            font.pixelSize: 12
                        }

                        SectionLabel { text: "Resources" }
                        Stepper {
                            label: "CPUs"
                            from: 1
                            to: root.hostCpus
                            value: creator.cpus
                            onMoved: v => creator.cpus = v
                        }
                        Stepper {
                            label: "Memory"
                            suffix: " GB"
                            from: 1
                            to: Math.max(1, root.hostMemGiB - 1)
                            value: creator.memGiB
                            onMoved: v => creator.memGiB = v
                        }
                        Stepper {
                            label: "Disk"
                            suffix: " GB"
                            step: 10
                            from: 10
                            to: 1000
                            value: creator.diskGiB
                            onMoved: v => creator.diskGiB = v
                        }

                        SectionLabel { text: "Firmware" }
                        Row {
                            spacing: 6
                            Chip {
                                text: creator.isWindows ? "UEFI + Secure Boot + TPM" : "UEFI"
                                selected: creator.firmware === "uefi"
                                onClicked: creator.firmware = "uefi"
                            }
                            Chip {
                                text: "Legacy BIOS"
                                selected: creator.firmware === "bios"
                                onClicked: creator.firmware = "bios"
                            }
                        }

                        SectionLabel { text: "Display" }
                        Row {
                            visible: !creator.isWindows
                            spacing: 6
                            Chip {
                                text: "3D acceleration"
                                selected: creator.graphics === "3d"
                                onClicked: creator.graphics = "3d"
                            }
                            Chip {
                                text: "Basic"
                                selected: creator.graphics === "basic"
                                onClicked: creator.graphics = "basic"
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: creator.isWindows
                                ? "Basic display: Windows has no driver for the virtual 3D GPU."
                                : creator.graphics === "3d"
                                    ? "Virtio GPU with OpenGL, rendered on the host GPU. Needed for smooth Wayland desktops such as Hyprland, GNOME or KDE."
                                    : "Simple 2D display. Most compatible, but desktops with animations will be slow."
                            color: Theme.muted
                            font.pixelSize: 12
                        }

                        Text {
                            visible: creator.isWindows && creator.mode === "download"
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: "Windows is downloaded directly from Microsoft (about 6 GB). Install it without a network if you want a local account."
                            color: Theme.muted
                            font.pixelSize: 12
                        }

                        Btn {
                            Layout.topMargin: 6
                            primary: true
                            active: creator.ready
                            icon: "󰐊"
                            text: creator.mode === "download" ? "Download and create" : "Create"
                            onClicked: creator.create()
                        }
                    }
                }
            }
        }
    }
}
