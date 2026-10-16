// Pure logic for Menu.qml: the menu tree from menu.json, search scoring, the
// batched shell guards, and parsing rofi-style select lines.

.pragma library

// ---- menu tree ----------------------------------------------------------------

// Entries are keyed by dotted id; "setup.audio" lives in the "setup" submenu
// and an id without a dot sits on the root. Anything without an action is a
// submenu.
function parseMenu(text) {
    var data = JSON.parse(text)
    var entries = {}
    var order = []
    var list = data.entries || []
    for (var i = 0; i < list.length; i++) {
        var e = list[i]
        var cut = e.id.lastIndexOf(".")
        e.parent = cut > 0 ? e.id.substring(0, cut) : ""
        e.isSubmenu = !e.action
        e.order = i
        entries[e.id] = e
        order.push(e.id)
    }
    return { entries: entries, order: order, prelude: data.prelude || "" }
}

function visible(entry, guards) {
    var g = guards[entry.id]
    return !entry.when || !g || g.w !== false
}

function children(menu, route, guards) {
    var out = []
    for (var i = 0; i < menu.order.length; i++) {
        var e = menu.entries[menu.order[i]]
        if (e.parent === route && visible(e, guards)) out.push(e)
    }
    return out
}

function breadcrumb(menu, id) {
    var parts = []
    var e = menu.entries[id]
    while (e) {
        parts.unshift(e.label)
        e = menu.entries[e.parent]
    }
    return parts.join(" › ")
}

// One bash script answers every `when` and `state` guard: "<id>:<w|s>:<0|1>".
function guardScript(menu) {
    var lines = [menu.prelude]
    for (var i = 0; i < menu.order.length; i++) {
        var e = menu.entries[menu.order[i]]
        if (e.when) lines.push("( " + e.when + " ) >/dev/null 2>&1 && echo '" + e.id + ":w:1' || echo '" + e.id + ":w:0'")
        if (e.state) lines.push("( " + e.state + " ) >/dev/null 2>&1 && echo '" + e.id + ":s:1' || echo '" + e.id + ":s:0'")
    }
    return lines.join("\n")
}

function parseGuards(text) {
    var guards = {}
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^(.*):([ws]):([01])$/)
        if (!m) continue
        if (!guards[m[1]]) guards[m[1]] = {}
        guards[m[1]][m[2]] = m[3] === "1"
    }
    return guards
}

// ---- search -------------------------------------------------------------------

// Every query word has to match somewhere. Label hits outrank keyword and
// description hits, and a match at the start of a word outranks one inside it.
function score(query, label, keywords, description) {
    var words = query.toLowerCase().split(/\s+/).filter(function (w) { return w.length })
    if (!words.length) return 1
    label = (label || "").toLowerCase()
    keywords = (keywords || "").toLowerCase()
    description = (description || "").toLowerCase()
    var total = 0
    for (var i = 0; i < words.length; i++) {
        var w = words[i]
        var s = 0
        if (label.indexOf(w) === 0) s = 100
        else if ((" " + label).indexOf(" " + w) !== -1) s = 80
        else if (label.indexOf(w) !== -1) s = 60
        else if ((" " + keywords).indexOf(" " + w) !== -1) s = 40
        else if (keywords.indexOf(w) !== -1) s = 30
        else if (description.indexOf(w) !== -1) s = 20
        else return 0
        total += s
    }
    return total
}

function rankEntries(menu, query, guards) {
    var hits = []
    for (var i = 0; i < menu.order.length; i++) {
        var e = menu.entries[menu.order[i]]
        if (!visible(e, guards)) continue
        var parent = menu.entries[e.parent]
        if (parent && !visible(parent, guards)) continue
        var s = score(query, e.label, e.keywords, e.description)
        if (s > 0) hits.push({ entry: e, score: s })
    }
    hits.sort(function (a, b) { return b.score - a.score || a.entry.order - b.entry.order })
    return hits
}

// ---- select mode (rofi -dmenu stand-in) -----------------------------------------

function isIconCodepoint(cp) {
    return (cp >= 0xE000 && cp <= 0xF8FF) || cp >= 0xF0000
}

// A line is shown as its display columns (tab-separated, 1-based like rofi's
// -display-columns); the whole line is what gets returned. The icon comes from
// iconColumn when given, else a leading Nerd Font glyph followed by spaces.
// One menu-select line as a row. `req` is the request: displayColumns,
// iconColumn, detailColumn, and sectionColumn pick tab-separated columns.
function parseLine(line, req) {
    req = req || {}
    var displayColumns = req.displayColumns || []
    var shown = line
    var cols = line.split("\t")
    var column = function (n) { return n ? (cols[n - 1] || "") : "" }
    if (displayColumns.length) {
        shown = displayColumns.map(column)
            .filter(function (c) { return c.length }).join("   ")
    }
    // Scripts mark the current choice with a leading "●"; it becomes a badge.
    var current = false
    var marker = shown.match(/^\s*●\s+/)
    if (marker) {
        current = true
        shown = shown.substring(marker[0].length)
    } else {
        shown = shown.replace(/^\s+/, "")
    }
    var icon = column(req.iconColumn)
    var cp = shown.codePointAt(0)
    if (!icon && cp !== undefined && isIconCodepoint(cp)) {
        var glyphLength = cp > 0xFFFF ? 2 : 1
        var rest = shown.substring(glyphLength)
        if (/^\s{1,}/.test(rest)) {
            icon = shown.substring(0, glyphLength)
            shown = rest.replace(/^\s+/, "")
        }
    }
    // Without a detail column, three or more spaces separate a label from
    // dimmer detail text.
    var detail = column(req.detailColumn)
    var split = req.detailColumn ? null : shown.match(/^(.*?\S)\s{3,}(\S.*)$/)
    if (split) {
        shown = split[1]
        detail = split[2]
    }
    // Hex colours in the swatch column become a row of dots (theme previews).
    var swatches = column(req.swatchColumn).split(/[\s,]+/)
        .filter(function (c) { return /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(c) })
    return { icon: icon, label: shown, detail: detail, value: line, current: current,
             section: column(req.sectionColumn), swatches: swatches }
}

// Rofi-style row list ("0,2,5-7") as a set of zero-based indexes.
function parseRowList(spec) {
    var out = {}
    String(spec || "").split(",").forEach(function (part) {
        var range = part.trim().match(/^(\d+)(?:-(\d+))?$/)
        if (!range) return
        var last = range[2] === undefined ? +range[1] : +range[2]
        for (var i = +range[1]; i <= last; i++) out[i] = true
    })
    return out
}

// Select rows grouped under a header row whenever the section changes.
function withSections(rows) {
    if (!rows.some(function (r) { return r.section })) return rows
    var out = []
    var last = null
    rows.forEach(function (r) {
        if (r.section !== last) {
            if (r.section) out.push({ kind: "header", label: r.section, icon: "", detail: "", trailing: "" })
            last = r.section
        }
        out.push(r)
    })
    return out
}
