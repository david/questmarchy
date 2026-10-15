# Questmarchy

An Omarchy shell plugin: a sword in the top bar that opens a searchable list
of your projects or quests, most recently active first. The projects are
those with a `quests` directory in the places you list, on this computer or
on other hosts. Choosing a project opens the agent in the project root, and
choosing a quest opens the quest's agent. If its window is already open, it
is focused instead.

## Requirements

- The Omarchy shell. Tested with Omarchy 4.0.0.alpha.
- `quest-window` on `PATH`, from the `quest-window` package in the dot
  repository. The widget runs `quest-window -l <place>...` for the lists, and
  `quest-window -p <place> <project>` or `quest-window -p <place> <project>
  <slug>` for the chosen project or quest.

## Install

From a clone, link it into the plugins directory and enable it:

```sh
ln -s "$PWD" ~/.config/omarchy/plugins/david.questmarchy
omarchy-shell shell rescanPlugins
omarchy plugin enable david.questmarchy --section left --after omarchy.menu
```

## Configure

List the places to look for projects in the widget's entry in
`~/.config/omarchy/shell.json`. Each place is a directory of projects, with
the host it is on. Leave out the host, or give this computer's name, for a
place on this computer. Without `places`, the widget lists `~/Projects` here.

```json
{
  "id": "david.questmarchy",
  "places": [
    { "host": "timbuktu", "path": "/home/david/Projects" },
    { "host": "madagascar", "path": "/home/david/Projects" }
  ]
}
```

Each other host must accept `ssh <host>` without a prompt. When the places are
on more than one computer, each entry names its computer.

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
load. A place that cannot be listed, such as one on a host that is off, keeps
its last lists, and the panel says it could not reach it.

## Development

The shell keeps a plugin's compiled QML until it restarts, so run
`omarchy restart shell` after changing a QML file. Load errors appear only in
`journalctl --user -t omarchy-shell`.

`assets/sword.svg` and `assets/flag.svg` are the icons' source art.
`SwordIcon.qml` and `FlagIcon.qml` hold copies of their path data.

## License

MIT. See [LICENSE](LICENSE).
