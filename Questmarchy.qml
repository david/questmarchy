import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A sword in the bar that opens a list of projects or quests, in two tabs,
// those whose windows were opened most recently first. Searching lists the
// matches from both. The projects are the quest command's realms, in the
// worlds it is configured with: directories on a host or on this computer.
// The lists come from `quest-window -l`, in this plugin's bin folder, through
// a cache file that the instance on every monitor watches. Choosing a project
// runs `quest-window -w <world> <project>`, which opens the agent in the
// project root, and choosing a quest runs `quest-window -w <world> <project>
// <slug>`; either focuses the window if it is open.
Panel {
  id: root
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string cachePath:
    (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/questmarchy/quests.json"
  readonly property string openedPath:
    (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/questmarchy/opened.json"
  readonly property string questWindow:
    decodeURIComponent(Qt.resolvedUrl("bin/quest-window").toString().replace(/^file:\/\//, ""))
  property string hostname: "localhost"

  // The quest command's worlds, [{world, host, path}] with a null host for
  // this computer, as the last lists gave them.
  property var worlds: []
  // Each world by name, as {label, failedLabel}: the name of its computer, and
  // how a failure to list it is reported.
  readonly property var worldsByName: {
    var byName = {}
    worlds.forEach(function(world) {
      byName[world.world] = { label: world.host || hostname, failedLabel: world.host || world.path }
    })
    return byName
  }
  // Whether the worlds are on more than one computer, so that entries name
  // theirs.
  readonly property bool showComputers: worlds.some(function(world) {
    return (world.host || hostname) !== (worlds[0].host || hostname)
  })

  // [{world, name}] and [{world, project, slug}], by name, and the worlds the
  // last refresh could not list.
  property var projects: []
  property var quests: []
  property var failedWorlds: []
  // When the windows were last opened, from quest-window's record, in
  // seconds since the epoch: each quest's by openedKey, and each project's,
  // its own window or any of its quests', whichever is later, by
  // openedKey(world, project).
  property var windowTimes: ({ projects: {}, quests: {} })
  property bool refreshing: false
  property bool refreshFailed: false
  // "projects" or "quests". Kept between openings.
  property string tab: "quests"
  property string query: ""
  // Index into matches of the highlighted entry.
  property int cursorIndex: 0
  readonly property bool searching: query.trim() !== ""
  // Each entry has a title, an optional second line, its group ("projects"
  // or "quests"), the quest-window arguments that open it, and when its
  // window was last opened.
  readonly property var projectEntries: byOpened(projects.filter(listed).map(function(project) {
    return {
      title: project.name,
      subtitle: showComputers ? worldsByName[project.world].label : "",
      group: "projects",
      args: ["-w", project.world, project.name],
      opened: windowTimes.projects[openedKey(project.world, project.name)] || 0
    }
  }))
  readonly property var questEntries: byOpened(quests.filter(listed).map(function(quest) {
    return {
      title: quest.slug,
      subtitle: quest.project + (showComputers ? " · " + worldsByName[quest.world].label : ""),
      group: "quests",
      args: ["-w", quest.world, quest.project, quest.slug],
      opened: windowTimes.quests[openedKey(quest.world, quest.project, quest.slug)] || 0
    }
  }))
  // The active tab's entries or, while searching, the projects and then the
  // quests that match.
  readonly property var matches: searching
    ? matching(projectEntries, query).concat(matching(questEntries, query))
    : (tab === "projects" ? projectEntries : questEntries)
  // The list's rows: {entry, index} for each match and, while searching,
  // {header} before each group.
  readonly property var rows: {
    var rows = []
    var group = ""
    for (var i = 0; i < matches.length; i++) {
      if (searching && matches[i].group !== group) {
        group = matches[i].group
        rows.push({ header: strings.t(group) })
      }
      rows.push({ entry: matches[i], index: i })
    }
    return rows
  }
  readonly property string status: {
    if (refreshFailed) return strings.t("refreshFailed")
    var failed = []
    failedWorlds.forEach(function(name) {
      var world = worldsByName[name]
      if (world && failed.indexOf(world.failedLabel) === -1) failed.push(world.failedLabel)
    })
    if (failed.length > 0) return strings.t("worldsFailed").replace("{worlds}", failed.join(", "))
    if (searching) return matches.length === 0 ? strings.t("noMatches") : ""
    if (matches.length === 0) {
      if (refreshing) return strings.t("loading")
      return strings.t(tab === "projects" ? "noProjects" : "noQuests")
    }
    return ""
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    if (panel.loadedContent) panel.loadedContent.search.clear()
    cursorIndex = 0
    openedFile.reload()
    refresh()
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }
  onQueryChanged: cursorIndex = 0
  onTabChanged: cursorIndex = 0
  onMatchesChanged: cursorIndex = Math.max(0, Math.min(cursorIndex, matches.length - 1))
  onCursorIndexChanged: scrollToCursor()

  // Keep the highlighted row in view, and the first group's header with the
  // first row.
  function scrollToCursor() {
    if (!panel.loadedContent) return
    var list = panel.loadedContent.list
    if (cursorIndex === 0) {
      list.positionViewAtBeginning()
      return
    }
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].entry && rows[i].index === cursorIndex) {
        list.positionViewAtIndex(i, ListView.Contain)
        return
      }
    }
  }

  // The entries whose titles contain every word of the query, in list order.
  function matching(list, text) {
    var words = text.toLowerCase().split(/\s+/).filter(function(word) { return word !== "" })
    if (words.length === 0) return list
    return list.filter(function(entry) {
      var title = entry.title.toLowerCase()
      return words.every(function(word) { return title.indexOf(word) !== -1 })
    })
  }

  // Whether a project or quest is in one of the worlds.
  function listed(entry) {
    return worldsByName.hasOwnProperty(entry.world)
  }

  function openedKey(world, project, slug) {
    return world + "\t" + project + "\t" + (slug || "")
  }

  // The entries whose windows were opened most recently first, then those
  // never opened, each in the lists' order: by name.
  function byOpened(entries) {
    return entries.map(function(entry, i) { return { entry: entry, i: i } })
      .sort(function(a, b) { return b.entry.opened - a.entry.opened || a.i - b.i })
      .map(function(item) { return item.entry })
  }

  // Reads quest-window's record of opened windows, [{place, project, slug,
  // opened}] with no slug for a project, where place is the world.
  function loadOpened(text) {
    var times = { projects: {}, quests: {} }
    var record = null
    try { record = JSON.parse(text) } catch (e) {}
    if (Array.isArray(record)) record.forEach(function(entry) {
      if (!entry || typeof entry.place !== "string" || typeof entry.project !== "string"
          || typeof entry.opened !== "number") return
      var project = openedKey(entry.place, entry.project)
      times.projects[project] = Math.max(times.projects[project] || 0, entry.opened)
      if (typeof entry.slug === "string" && entry.slug !== "")
        times.quests[openedKey(entry.place, entry.project, entry.slug)] = entry.opened
    })
    windowTimes = times
  }

  // By the given fields, in order.
  function byFields(fields) {
    return function(a, b) {
      for (var i = 0; i < fields.length; i++) {
        if (a[fields[i]] !== b[fields[i]]) return a[fields[i]] < b[fields[i]] ? -1 : 1
      }
      return 0
    }
  }

  // The lists in quest-window's JSON or the cache's, as {worlds, projects,
  // quests, failed}, without malformed entries; null when the text holds no
  // lists, as in a cache from before the quest command.
  function parseLists(text) {
    var data = null
    try { data = JSON.parse(text) } catch (e) {}
    if (!data || !Array.isArray(data.worlds) || !Array.isArray(data.projects)
        || !Array.isArray(data.quests)) return null
    var named = function(value) { return typeof value === "string" && value !== "" }
    return {
      worlds: data.worlds.filter(function(world) {
        return world && named(world.world) && named(world.path) && (world.host === null || named(world.host))
      }),
      projects: data.projects.filter(function(project) {
        return project && named(project.world) && named(project.name)
      }),
      quests: data.quests.filter(function(quest) {
        return quest && named(quest.world) && named(quest.project) && named(quest.slug)
      }),
      failed: Array.isArray(data.failed) ? data.failed.filter(named) : []
    }
  }

  function load(text) {
    var lists = parseLists(text) || { worlds: [], projects: [], quests: [], failed: [] }
    worlds = lists.worlds
    projects = lists.projects
    quests = lists.quests
    failedWorlds = lists.failed
  }

  // Takes the lists from a refresh, with the last lists of the worlds it
  // could not list, and writes them to the cache for the instances on the
  // other monitors.
  function finishRefresh(text) {
    var lists = parseLists(text)
    refreshFailed = !lists
    if (!lists) return
    var failed = function(entry) { return lists.failed.indexOf(entry.world) !== -1 }
    lists.projects = lists.projects.concat(projects.filter(failed)).sort(byFields(["name", "world"]))
    lists.quests = lists.quests.concat(quests.filter(failed)).sort(byFields(["project", "slug", "world"]))
    worlds = lists.worlds
    projects = lists.projects
    quests = lists.quests
    failedWorlds = lists.failed
    cache.setText(JSON.stringify(lists) + "\n")
  }

  function refresh() {
    if (refresher.running) return
    refreshing = true
    refresher.running = true
    watchdog.restart()
  }

  function moveCursor(delta) {
    if (matches.length === 0) return
    cursorIndex = Math.max(0, Math.min(matches.length - 1, cursorIndex + delta))
  }

  function activate(index) {
    var entry = matches[index]
    if (!entry) return
    Util.execArgv(["bash", questWindow].concat(entry.args))
    close()
  }

  function switchTab() {
    tab = tab === "projects" ? "quests" : "projects"
  }

  // Keys pressed in the search field. Escape clears the query, then closes;
  // Tab switches tabs unless a search hides them.
  function handleKey(event, field) {
    var key = event.key
    var ctrl = event.modifiers & Qt.ControlModifier
    if (key === Qt.Key_Escape) {
      if (field.text !== "") field.clear()
      else close()
    } else if (key === Qt.Key_Down || (ctrl && (key === Qt.Key_N || key === Qt.Key_J))) {
      moveCursor(1)
    } else if (key === Qt.Key_Up || (ctrl && (key === Qt.Key_P || key === Qt.Key_K))) {
      moveCursor(-1)
    } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
      activate(cursorIndex)
    } else if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
      if (!searching) switchTab()
    } else {
      return
    }
    event.accepted = true
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  // Written whole, so watchers never read a partial list, and only after a
  // refresh that listed something, so a failed one keeps the last lists.
  FileView {
    id: cache
    path: root.cachePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.load(text())
  }

  // Also reloaded each time the panel opens, in case the file appeared after
  // the watch began.
  FileView {
    id: openedFile
    path: root.openedPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadOpened(text())
  }

  FileView {
    path: "/etc/hostname"
    printErrors: false
    onLoaded: if (text().trim() !== "") root.hostname = text().trim()
  }

  // Makes the cache's directory for finishRefresh to write in.
  Process {
    id: refresher
    command: ["bash", "-lc", 'mkdir -p "${1%/*}" && exec bash "$2" -l', "bash", root.cachePath, root.questWindow]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishRefresh(text)
    }
    onExited: function(exitCode) {
      watchdog.stop()
      root.refreshing = false
      if (exitCode !== 0) root.refreshFailed = true
    }
  }

  // The quest command gives up on connecting to a host after 10 seconds; this
  // stops a refresh that hangs after connecting.
  Timer {
    id: watchdog
    interval: 30000
    onTriggered: {
      refresher.running = false
      root.refreshing = false
      root.refreshFailed = true
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: strings.t("tooltip")
    iconComponent: Component {
      SwordIcon { color: root.barForeground }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(560))

    content: FocusScope {
      property alias search: search
      property alias list: list
      implicitHeight: column.implicitHeight

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        // The sword and a title over the search field. The sword is fitted
        // to its outline, a little taller than the title's letters and
        // centered on them, with its left edge over the field's text.
        Item {
          width: parent.width
          implicitHeight: title.implicitHeight

          TextMetrics {
            id: titleMetrics
            font: title.font
            text: title.text
          }

          Item {
            id: sword
            x: search.leftPadding
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: title.baselineOffset + titleMetrics.tightBoundingRect.y
              + titleMetrics.tightBoundingRect.height / 2
            height: Math.round(title.font.pixelSize * 0.875)
            width: Math.round(swordShape.boundingRect.width * swordShape.scale)

            SwordIcon {
              id: swordShape
              color: root.foreground
              transformOrigin: Item.TopLeft
              scale: sword.height / boundingRect.height
              x: -boundingRect.x * scale
              y: -boundingRect.y * scale
            }
          }

          Text {
            id: title
            anchors.left: sword.right
            anchors.leftMargin: Style.space(12)
            textFormat: Text.PlainText
            text: strings.t("searchTitle")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
        }

        TextField {
          id: search
          width: parent.width
          focus: true
          foreground: root.foreground
          placeholderText: strings.t("search")
          onTextChanged: root.query = text
          Keys.onPressed: function(event) { root.handleKey(event, search) }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        // Two tabs that share the row's width.
        Row {
          id: tabs
          visible: !root.searching
          width: parent.width
          spacing: Style.space(10)
          // Keeps the list clear of the tabs, on top of the column spacing.
          bottomPadding: Style.space(8)

          TabTile {
            width: (tabs.width - tabs.spacing) / 2
            value: "projects"
            icon: Component { FlagIcon { color: Commons.Color.accent } }
          }

          TabTile {
            width: (tabs.width - tabs.spacing) / 2
            value: "quests"
            icon: Component { SwordIcon { color: Commons.Color.accent } }
          }
        }

        Text {
          visible: root.status !== ""
          width: parent.width
          leftPadding: Style.space(10)
          textFormat: Text.PlainText
          text: root.status
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        ListView {
          id: list
          visible: count > 0
          width: parent.width
          height: Math.min(contentHeight, Style.space(380))
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.rows
          delegate: Column {
            id: rowItem
            required property var modelData
            required property int index
            width: ListView.view.width

            PanelSectionHeader {
              visible: !!rowItem.modelData.header
              width: parent.width
              // Space the second group's header from the rows above it.
              topPadding: Math.ceil(fontSize * 0.15) + (rowItem.index > 0 ? Style.space(10) : 0)
              bottomPadding: Style.space(4)
              text: (rowItem.modelData.header || "").toUpperCase()
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            EntryRow {
              visible: !rowItem.modelData.header
              width: parent.width
              entry: rowItem.modelData.entry || null
              rowIndex: rowItem.modelData.header ? -1 : rowItem.modelData.index
            }
          }
        }
      }
    }
  }

  // A tab drawn like the agents panel's starter tiles: an accent icon and a
  // bold label on a faint fill, tinted with the accent while selected.
  component TabTile: Rectangle {
    id: tile
    property string value: ""
    property Component icon: null
    readonly property bool selected: root.tab === value

    implicitHeight: tileBody.implicitHeight + Style.space(20)
    radius: Style.cornerRadius
    color: selected ? Util.alpha(Commons.Color.accent, 0.14)
      : Util.alpha(root.foreground, tileMouse.containsMouse ? 0.09 : 0.05)

    Row {
      id: tileBody
      anchors.centerIn: parent
      spacing: Style.space(8)

      // A little larger than the agents panel's glyphs.
      GridIcon {
        anchors.verticalCenter: parent.verticalCenter
        size: Style.font.heading
        icon: tile.icon
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: strings.t(tile.value)
        color: tile.selected ? Commons.Color.accent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    MouseArea {
      id: tileMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.tab = tile.value
    }
  }

  Component {
    id: realmIcon
    FlagIcon { color: root.dim }
  }

  Component {
    id: questIcon
    SwordIcon { color: root.dim }
  }

  // An icon drawn on a 24-unit grid, scaled so that it looks about as large
  // as a glyph of the given font size: the grid leaves a margin around it.
  component GridIcon: Item {
    id: gridIcon
    property Component icon: null
    property real size: Style.font.body

    width: Math.round(size * 1.25)
    height: width

    Loader {
      anchors.centerIn: parent
      sourceComponent: gridIcon.icon
      scale: gridIcon.width / 24
    }
  }

  component EntryRow: CursorSurface {
    id: row
    property var entry: null
    property int rowIndex: 0

    hasCursor: root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: lines.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) root.cursorIndex = row.rowIndex
      onClicked: root.activate(row.rowIndex)
    }

    // A flag for a project and a sword for a quest, as on their tabs, sized
    // and colored like the network panel's signal icons.
    GridIcon {
      id: rowIcon
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      size: Style.font.title
      icon: row.entry && row.entry.group === "projects" ? realmIcon : questIcon
    }

    Column {
      id: lines
      anchors.left: rowIcon.right
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(1)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: row.entry ? row.entry.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        visible: text !== ""
        width: parent.width
        textFormat: Text.PlainText
        text: row.entry ? row.entry.subtitle : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }
}
