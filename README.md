# Questmarchy

An Omarchy shell plugin: a sword in the top bar that opens a searchable list
of your projects or quests, those whose windows you opened most recently
first. The projects are those with a `quests` directory in the places you
list, on this computer or on other hosts. Choosing a project opens the agent in the project root, and
choosing a quest opens the quest's agent, each in its own terminal window
attached to a [shpool](https://github.com/shell-pool/shpool) session, which
keeps the agent running when the window closes or the connection drops. If
its window is already open, it is focused instead.

## Requirements

- The Omarchy shell. Tested with Omarchy 4.0.0.alpha.
- On this computer: `jq`.
- A default agent, chosen on this computer with `omarchy default agent`.
- Where the projects live, this computer included when a place is here:
  shpool and the default agent on a login shell's `PATH`, and projects laid
  out as `<path>/<project>/quests/<slug>/QUEST.md`. shpool is in the AUR
  (`yay -S shpool`) and in Homebrew (`brew install shpool`), and starts its
  daemon itself.
- For each other host, `ssh <host>` without a prompt. SSH keeps host keys
  under the name you connect with, so accept the key once for each name you
  use in `places`, even for a host you already reach through an alias.

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
    { "host": "devbox", "path": "/home/me/Projects" },
    { "path": "~/Projects" }
  ]
}
```

When the places are on more than one computer, each entry names its computer.

## Use

Click the sword, or run `omarchy-shell shell toggle david.questmarchy`, for
example from a key binding.

- The Realms (projects) and Quests tabs switch lists. Tab switches them from
  the keyboard. The panel reopens on the last tab used.
- A flag marks each realm and a sword each quest, as on their tabs.
- Type to search both lists. While you search, the tabs give way to the
  matching realms, then the matching quests. Every word typed must appear
  in the name, and Tab does nothing.
- Each list starts with what you opened most recently: a quest when its
  window was last opened or focused, and a project when its own window or
  one of its quests' was. Those never opened follow, most recently active
  first, as `quest-window -l` lists them.
- Up and Down, or Ctrl+N and Ctrl+P, move the highlight.
- Enter or a click opens the highlighted project or quest.
- Escape clears the search, then closes the panel.

The lists refresh each time the panel opens. They are cached in
`~/.cache/questmarchy/quests.json`, so the last lists show while the new ones
load. A place that cannot be listed, such as one on a host that is off, keeps
its last lists, and the panel says it could not reach it.

## Windows and sessions

Each window attaches to a shpool session where the project lives, running
the agent in the project root or the quest directory. The project session is
where quests are created and archived. A quest session holds that quest's
work.

| Opens | shpool session | Window class |
| --- | --- | --- |
| A project | `questmarchy:<project>:<n>` | `TUI.questmarchy.<host>.<project>` |
| A quest | `questmarchy:<project>:<slug>:<n>` | `TUI.questmarchy.<host>.<project>.<slug>` |

`<host>` is the place's host, or this computer's name. Windows open in
Omarchy's default terminal (`omarchy default terminal`), through
`omarchy-launch-tui`. Omarchy tags `TUI.*` windows as terminals, so `Super+V`
pastes in them.

A window attaches to the first session for its project or quest that no
terminal is attached to, so closing a window and opening it again picks up
the same agent. When every one is attached, as when a terminal elsewhere
holds it, the window creates a session with the lowest free number `<n>`.

A new session starts the default agent on this computer (`omarchy default
agent`) as its own command where the project lives, such as `codex`, with no
options, from an interactive login shell; Omarchy's launcher is not used there.
When no default agent is chosen, or it is not installed where the project
lives, the session starts a shell instead, and a notification says why. When
the agent exits, the session ends and the window closes.

The window runs `bin/quest-session`, which attaches with `shpool attach`, over
`ssh -t <host>` for another host. When ssh loses the connection, the window
says so and reconnects every few seconds, forcing off the old client that the
host may still count as attached, until it gets through or a key is pressed.
Each window has an SSH connection of its own, not one shared through a
`ControlMaster`, so closing the window detaches its session at once. When the
session ends with an error, the window stays open until a key is pressed, so
the error can be read.

An agent that exits while no window is attached leaves its session listed as
detached. Attaching to it starts the agent again.

## quest-window

The widget does its work through `bin/quest-window`, which can also be run by
hand:

```sh
bin/quest-window [-n] [-p <place>] <project> [<slug>]
bin/quest-window -l [<place>...]
```

A place is `[<host>:]<path>`, such as `devbox:/home/me/Projects`. A
relative path starts at the home directory. The default place is
`~/Projects` on this computer. `-n` prints what would happen without opening
or focusing a window.

Each time it opens or focuses a window, `quest-window` records the time in
`~/.local/state/questmarchy/opened.json`, as `[{place, project, slug,
opened}]`, one entry for each project or quest, with no `slug` for a
project. `opened` is in seconds since the epoch. The place is recorded as
given, so the widget matches only the places it passed.

`-l` lists the places at once and prints, as JSON, `{projects: [{place, name,
updated}], quests: [{place, project, slug, updated}], failed: [<place>]}`, the
first two most recently active first. Archived quests are left out. `failed`
holds the places that could not be listed. `updated` is in seconds since the
epoch:

- For a quest, the newest change to its records (outside `.git`, `worktrees`,
  and `local-data`) or to a Claude Code transcript started in its directory.
- For a project, the newest change to a transcript started in its root, or
  the latest of its quests, whichever is later.

`QUEST.md` times and quest snapshot times alone were tried and rejected: bulk
edits and the first snapshot gave most quests the same time. Claude Code files
transcripts under a directory's physical path, so the listing resolves
symlinks such as `/home` to `/var/home`.

## Development

The shell keeps a plugin's compiled QML until it restarts, so run
`omarchy restart shell` after changing a QML file. Load errors appear only in
`journalctl --user -t omarchy-shell`.

To see the panel, wait a few seconds after a restart, open it with
`omarchy-shell shell summon david.questmarchy`, take a screenshot with `grim`,
and close it at once with `omarchy-shell shell hide david.questmarchy`. An
open panel takes the keyboard. Don't type into it with `wtype`: if the panel
did not open, the keys go to whichever window has focus.

Omarchy plugin details that are easy to miss:

- The manifest's `barWidget.defaults` are not passed to the widget, which
  gets only its entry in `shell.json`, so the code repeats its defaults.
- The settings form has no list type, so `places` is edited by hand.
- `omarchy plugin validate` rejects any symlink in the folder, including a
  linked plugin folder itself, so validate the clone, not the link.

`assets/sword.svg` and `assets/flag.svg` are the icons' source art.
`SwordIcon.qml` and `FlagIcon.qml` hold copies of their path data.

## License

MIT. See [LICENSE](LICENSE).
