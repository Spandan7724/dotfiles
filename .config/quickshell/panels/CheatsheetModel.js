// Turns `hyprctl binds -j` into cheatsheet categories. Plain JavaScript so the
// grouping logic stays out of the QML.
//
// Descriptions carry their category as a "Category: " prefix (see section() in
// hypr/keybinds.lua). Families of binds that differ only by number or direction
// (workspaces 1-10, focus left/right/up/down) collapse into one row.

.pragma library

var CATEGORY_ORDER = [
    "Apps", "Tools", "Windows", "Focus & move", "Layout", "Workspaces", "Monitors",
    "Clipboard", "Capture", "Desktop", "Appearance", "Notifications", "Session", "Hardware keys",
]

var CATEGORY_ICONS = {
    "Apps": "󰀻", "Tools": "󰦬", "Windows": "󰖯", "Focus & move": "󰆾", "Layout": "󰕴",
    "Workspaces": "󰍹", "Monitors": "󰍺", "Clipboard": "󰅌", "Capture": "󰄀", "Desktop": "󰧨",
    "Appearance": "󰏘", "Notifications": "󰂚", "Session": "󰐥", "Hardware keys": "󰌌",
}

var MODS = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]

var KEY_NAMES = {
    "mouse:272": "󰍽 Drag", "mouse:273": "󰍽 Right drag", "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑",
    "return": "Enter", "escape": "Esc", "space": "Space", "tab": "Tab", "grave": "`",
    "slash": "/", "backslash": "\\", "bracketleft": "[", "bracketright": "]", "semicolon": ";",
    "comma": ",", "period": ".", "equal": "=", "minus": "-", "print": "PrtSc",
    "page_up": "PgUp", "page_down": "PgDn", "left": "←", "right": "→", "up": "↑", "down": "↓",
    "xf86monbrightnessup": "󰃠 +", "xf86monbrightnessdown": "󰃞 −",
    "xf86audioraisevolume": "󰕾 +", "xf86audiolowervolume": "󰖀 −", "xf86audiomute": "󰖁 Mute",
    "xf86audiomicmute": "󰍭 Mic", "xf86audioplay": "󰐊 Play", "xf86audiopause": "󰏤 Pause",
    "xf86audionext": "󰒭 Next", "xf86audioprev": "󰒮 Prev",
}

// Direction families are listed left, down, up, right (h j k l order).
var DIRECTION_ORDER = { "left": 0, "down": 1, "up": 2, "right": 3 }
var RESIZE_WORDS = { "narrower": "left", "taller": "down", "shorter": "up", "wider": "right" }

function keyName(key) {
    var named = KEY_NAMES[String(key).toLowerCase()]
    if (named) return named
    return key.length === 1 ? key.toUpperCase() : key
}

function modNames(mask) {
    var names = []
    for (var i = 0; i < MODS.length; i++)
        if (mask & MODS[i][0]) names.push(MODS[i][1])
    return names
}

// "Switch to workspace 3" -> family "Switch to workspace", member 3.
// "Focus window left" -> family "Focus window", member "left".
function family(text) {
    var m = text.match(/^(.*\bworkspace) (\d+)$/)
    if (m) return { base: m[1], kind: "number", order: parseInt(m[2]) }
    m = text.match(/^Resize window (narrower|wider|shorter|taller)$/)
    if (m) return { base: "Resize window", kind: "direction", order: DIRECTION_ORDER[RESIZE_WORDS[m[1]]] }
    m = text.match(/^(.*) (left|right|up|down)$/)
    if (m) return { base: m[1], kind: "direction", order: DIRECTION_ORDER[m[2]] }
    return { base: text, kind: "single", order: 0 }
}

// Keys of a collapsed family as one keycap label.
function familyKey(members) {
    members.sort(function (a, b) { return a.order - b.order })
    var keys = members.map(function (m) { return keyName(m.key) })
    if (members[0].kind === "number" && keys.length >= 9) return "1 – 0"
    return keys.join(" ")
}

function build(binds) {
    // Pass 1: collapse number/direction families that share modifiers.
    var families = {}
    var familyOrder = []
    for (var i = 0; i < binds.length; i++) {
        var b = binds[i]
        if (!b.has_description || !b.description || b.submap) continue
        var desc = b.description
        var cut = desc.indexOf(": ")
        var category = cut > 0 ? desc.substring(0, cut) : "Other"
        var text = cut > 0 ? desc.substring(cut + 2) : desc
        var f = family(text)
        var id = category + "|" + b.modmask + "|" + f.base + "|" + (f.kind === "single" ? b.key : f.kind)
        if (!families[id]) {
            families[id] = { category: category, text: f.base, mods: modNames(b.modmask), members: [] }
            familyOrder.push(id)
        }
        families[id].members.push({ key: b.key, kind: f.kind, order: f.order })
    }

    // Pass 2: rows with the same description list every key combo that does it.
    var rows = {}
    var rowOrder = []
    for (var j = 0; j < familyOrder.length; j++) {
        var fam = families[familyOrder[j]]
        var rowId = fam.category + "|" + fam.text
        if (!rows[rowId]) {
            rows[rowId] = { category: fam.category, text: fam.text, combos: [] }
            rowOrder.push(rowId)
        }
        var combo = fam.mods.concat([familyKey(fam.members)])
        var comboText = combo.join("+")
        var seen = rows[rowId].combos.some(function (c) { return c.join("+") === comboText })
        if (!seen) rows[rowId].combos.push(combo)
    }

    // Group into categories in a fixed order; unknown ones go last.
    var byCategory = {}
    for (var k = 0; k < rowOrder.length; k++) {
        var row = rows[rowOrder[k]]
        row.search = (row.category + " " + row.text + " " + row.combos.map(function (c) { return c.join(" ") }).join(" ")).toLowerCase()
        if (!byCategory[row.category]) byCategory[row.category] = []
        byCategory[row.category].push(row)
    }
    var names = Object.keys(byCategory).sort(function (a, b) {
        var ia = CATEGORY_ORDER.indexOf(a), ib = CATEGORY_ORDER.indexOf(b)
        return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib)
    })
    return names.map(function (name) {
        return { name: name, icon: CATEGORY_ICONS[name] || "󰌌", rows: byCategory[name] }
    })
}

function filter(categories, query) {
    var q = query.trim().toLowerCase()
    if (!q) return categories
    var words = q.split(/\s+/)
    var out = []
    for (var i = 0; i < categories.length; i++) {
        var rows = categories[i].rows.filter(function (r) {
            return words.every(function (w) { return r.search.indexOf(w) !== -1 })
        })
        if (rows.length) out.push({ name: categories[i].name, icon: categories[i].icon, rows: rows })
    }
    return out
}

// Masonry: place each category in the currently shortest column.
// Rough height of one category, for balancing the columns: a header, then a
// row per shortcut. Rows with several key combos usually drop the keys to a
// second line.
function categoryHeight(category) {
    var h = 52
    for (var i = 0; i < category.rows.length; i++)
        h += category.rows[i].combos.length > 1 ? 56 : 32
    return h
}

function columns(categories, count) {
    var cols = [], heights = []
    for (var i = 0; i < count; i++) { cols.push([]); heights.push(0) }
    for (var j = 0; j < categories.length; j++) {
        var shortest = 0
        for (var c = 1; c < count; c++) if (heights[c] < heights[shortest]) shortest = c
        cols[shortest].push(categories[j])
        heights[shortest] += categoryHeight(categories[j])
    }
    return cols
}
