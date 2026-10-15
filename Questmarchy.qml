import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A sword in the bar that opens a list of projects or quests, in two tabs,
// most recently active first. Searching lists the matches from both. The lists come from
// `quest-window -l`, through a cache file that the instance on every monitor
// watches. Choosing a project runs `quest-window <project>`, which opens the
// agent in the project root, and choosing a quest runs
// `quest-window <project> <slug>`; either focuses the window if it is open.
Panel {
  id: root
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string cachePath:
    (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/questmarchy/quests.json"

  // [{name, updated}] and [{project, slug, updated}], most recently active first.
  property var projects: []
  property var quests: []
  property bool refreshing: false
  property bool refreshFailed: false
  // "projects" or "quests". Kept between openings.
  property string tab: "quests"
  property string query: ""
  // Index into matches of the highlighted entry.
  property int cursorIndex: 0
  readonly property bool searching: query.trim() !== ""
  // Each entry has a title, an optional second line, its group ("projects"
  // or "quests"), and the quest-window arguments that open it.
  readonly property var projectEntries: projects.map(function(project) {
    return { title: project.name, subtitle: "", group: "projects", args: [project.name] }
  })
  readonly property var questEntries: quests.map(function(quest) {
    return { title: quest.slug, subtitle: quest.project, group: "quests", args: [quest.project, quest.slug] }
  })
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

  function load(text) {
    var data = null
    try { data = JSON.parse(text) } catch (e) {}
    var projects = data && Array.isArray(data.projects) ? data.projects : []
    var quests = data && Array.isArray(data.quests) ? data.quests : []
    root.projects = projects.filter(function(project) {
      return project && typeof project.name === "string"
    })
    root.quests = quests.filter(function(quest) {
      return quest && typeof quest.project === "string" && typeof quest.slug === "string"
    })
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
    Util.execArgv(["quest-window"].concat(entry.args))
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

  // Refreshes reload it too: a watch set up before the file existed misses
  // its creation.
  FileView {
    id: cache
    path: root.cachePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.load(text())
  }

  // Writes through a temporary file, so watchers never read a partial list
  // and a failed refresh keeps the last list.
  Process {
    id: refresher
    command: ["bash", "-lc",
      'mkdir -p "${1%/*}" && quest-window -l >"$1.$$" && mv "$1.$$" "$1" || { rm -f "$1.$$"; exit 1; }',
      "bash", root.cachePath]
    onExited: function(exitCode) {
      watchdog.stop()
      root.refreshing = false
      root.refreshFailed = exitCode !== 0
      if (exitCode === 0) cache.reload()
    }
  }

  // quest-window gives up on connecting after 10 seconds; this stops a
  // refresh that hangs after connecting.
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

        // The sword, then the search field in the rest of the row, like the
        // icon and title of a first-party panel's header.
        Item {
          width: parent.width
          implicitHeight: Math.max(sword.height, search.implicitHeight)

          SwordIcon {
            id: sword
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: root.foreground
          }

          TextField {
            id: search
            anchors.left: sword.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            foreground: root.foreground
            placeholderText: strings.t("search")
            onTextChanged: root.query = text
            Keys.onPressed: function(event) { root.handleKey(event, search) }
          }
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

      // The icons are drawn on a 24-unit grid with a margin around them, so
      // they get a box a little larger than the agents panel's glyphs.
      Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(Style.font.heading * 1.25)
        height: width

        Loader {
          anchors.centerIn: parent
          sourceComponent: tile.icon
          scale: parent.width / 24
        }
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

    Column {
      id: lines
      anchors.left: parent.left
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
