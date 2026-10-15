# Questmarchy

An Omarchy shell plugin: a sword in the top bar that opens a searchable list
of your projects or quests, most recently active first. Choosing a project
opens the agent in the project root, and choosing a quest opens the quest's
agent. If its window is already open, it is focused instead.

## Requirements

- The Omarchy shell. Tested with Omarchy 4.0.0.alpha.
- `quest-window` on `PATH`, from the `quest-window` package in the dot
  repository. The widget runs `quest-window -l` for the lists, and
  `quest-window <project>` or `quest-window <project> <slug>` for the chosen
  project or quest.

## Install

From a clone, link it into the plugins directory and enable it:

```sh
ln -s "$PWD" ~/.config/omarchy/plugins/david.questmarchy
omarchy-shell shell rescanPlugins
omarchy plugin enable david.questmarchy --section left --after omarchy.menu
```

## Use

Click the sword, or run `omarchy-shell shell toggle david.questmarchy`, for
example from a key binding.

- The Realms (projects) and Quests tabs switch lists. Tab switches them from
  the keyboard. The panel reopens on the last tab used.
- Type to search both lists. While you search, the tabs give way to the
  matching realms, then the matching quests. Every word typed must appear
  in the name, and Tab does nothing.
- Up and Down, or Ctrl+N and Ctrl+P, move the highlight.
- Enter or a click opens the highlighted project or quest.
- Escape clears the search, then closes the panel.

The lists refresh each time the panel opens. They are cached in
`~/.cache/questmarchy/quests.json`, so the last lists show while the new ones
load.

## Development

The shell keeps a plugin's compiled QML until it restarts, so run
`omarchy restart shell` after changing a QML file. Load errors appear only in
`journalctl --user -t omarchy-shell`.

`assets/sword.svg` is the icon's source art. `SwordIcon.qml` holds a copy of
its path data.
