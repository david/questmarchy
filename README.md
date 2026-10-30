# Questmarchy

An Omarchy shell plugin: a sword in the top bar that opens a searchable list
of your projects or quests, those whose windows you opened most recently
first. The projects are the realms that the
[`quest` command](https://github.com/david/quest) finds in your worlds, on
this computer or on other hosts. Choosing a project opens the agent in the project root, and
choosing a quest opens the quest's agent, each in its own terminal window
attached to a [shpool](https://github.com/shell-pool/shpool) session, which
keeps the agent running when the window closes or the connection drops. If
its window is already open, it is focused instead.

## Requirements

- The Omarchy shell. Tested with Omarchy 4.0.0.alpha.
- On this computer: `jq`, and the `quest` command from the
  [quest skill](https://github.com/david/quest): on `PATH`, or with the skill
  installed in `~/.claude/skills/quest` or `~/.agents/skills/quest`.
- A default agent, chosen on this computer with `omarchy default agent`.
- Where the projects live, this computer included when a world is here:
  shpool and the default agent on a login shell's `PATH`, and `python3`,
  which runs `quest` there to list them, and Questmarchy's
  [`sessionctl`](#sessionctl). shpool is in the AUR
  (`yay -S shpool`) and in Homebrew (`brew install shpool`), and starts its
  daemon itself.
- For each other host, `ssh <host>` without a prompt. SSH keeps host keys
  under the name you connect with, so accept the key once for each name you
  use in your worlds, even for a host you already reach through an alias.
- To resume Claude Code's conversations after shpool loses their sessions,
  and to show what its agents are doing, Questmarchy's plugin for Claude Code
  where the projects live. See [Resuming
  conversations](#resuming-conversations) and [Agent status](#agent-status).

## Install

From a clone, link it into the plugins directory and enable it:

```sh
ln -s "$PWD" ~/.config/omarchy/plugins/david.questmarchy
omarchy-shell shell rescanPlugins
omarchy plugin enable david.questmarchy --section left --after omarchy.menu
```

## Configure

The widget lists the worlds that the `quest` command is configured with, in
`~/.config/quest/worlds.json`. Each world is a directory of realms, with the
host it is on. Leave out the host, or give this computer's name, for a world
on this computer. Without the file, `quest` lists `~/Projects` here.

```json
[
  { "host": "devbox", "path": "/home/me/Projects" },
  { "path": "~/Projects" }
]
```

When the worlds are on more than one computer, each entry names its computer.
`quest world list` prints the worlds as `quest` reads them.

## Use

Click the sword, or run `omarchy-shell shell toggle david.questmarchy`, for
example from a key binding.

- The Realms (projects) and Quests tabs switch lists. Tab switches them from
  the keyboard. The panel reopens on the last tab used.
- A flag marks each realm and a sword each quest, as on their tabs. Its
  color says what its windows and agents are doing; see [Agent
  status](#agent-status).
- Type to search both lists. While you search, the tabs give way to the
  matching realms, then the matching quests. Every word typed must appear
  in the name, and Tab does nothing.
- Each list starts with what you opened most recently: a quest when its
  window was last opened or focused, and a project when its own window or
  one of its quests' was. Those never opened follow by name.
- Up and Down, or Ctrl+N and Ctrl+P, move the highlight.
- Enter or a click opens the highlighted project or quest.
- Escape clears the search, then closes the panel.

The lists refresh each time the panel opens. They are cached in
`~/.cache/questmarchy/quests.json`, so the last lists show while the new ones
load. A world that cannot be listed, such as one on a host that is off, keeps
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

`<host>` is the world's host, or this computer's name. Windows open in
Omarchy's default terminal (`omarchy default terminal`), through
`omarchy-launch-tui`. Omarchy tags `TUI.*` windows as terminals, so `Super+V`
pastes in them.

Opening a project or quest opens a window for each of its sessions at once, so
closing its windows and opening it again picks up the same agents. It also
opens one for each session that shpool lost, as in a reboot, and that is linked
to a conversation, and recreates the session resuming that conversation; see
[Resuming conversations](#resuming-conversations). When there is neither, one
window creates session 1.

These windows open only when this computer has none for the project or quest,
so each takes over its session from any terminal attached to it. After a crash
here, a host can still count the lost terminals as attached, and can't tell
them from live ones, so opening the quest brings its sessions back. A window
open on another computer loses its session, and closes.

A new session starts the default agent on this computer (`omarchy default
agent`) as its own command where the project lives, such as `codex`, with no
options, from an interactive login shell; Omarchy's launcher is not used there.
When no default agent is chosen, or it is not installed where the project
lives, the session starts a shell instead, and a notification says why. When
the agent exits, the session ends and the window closes.

The window runs `bin/quest-session`, which attaches with `shpool attach`
through [`sessionctl`](#sessionctl) where the project lives, over
`ssh -t <host>` for another host. When ssh loses the connection, the window
says so and reconnects every few seconds, until it gets through or a key is
pressed.
Each window has an SSH connection of its own, not one shared through a
`ControlMaster`, so closing the window detaches its session at once. When the
session ends with an error, the window stays open until a key is pressed, so
the error can be read.

An agent that exits while no window is attached leaves its session listed as
detached. Attaching to it starts the agent again.

## Resuming conversations

Questmarchy's plugin for Claude Code links each session to the conversation
running in it, so that a session shpool loses, as in a reboot, comes back
with its conversation. Install it on each host where projects live, this
computer included when a world is here:

```sh
claude plugin install questmarchy --marketplace david/questmarchy
```

`claude plugin update questmarchy@questmarchy` brings it up to date. Without
it, a new Claude session's notification says that its conversation will not
come back.

The plugin's hooks, in `claude-plugin/`, run where the session lives. Each
time a conversation starts, including after `/clear` or `/resume`, they save
Claude's input for the hook as the session's link, in
`~/.local/state/questmarchy/sessions/shpool/<session>.json`. When you quit
Claude, with `/exit` or `/logout`, they delete it, so the session does not
come back. They do nothing in a Claude that Questmarchy did not start: the
session's agent runs with `QUESTMARCHY_SESSION=shpool/<session>` in its
environment, and the hooks need it. A Claude started inside the session, as
by the agent itself, inherits it and replaces the link with its own
conversation.

`sessionctl attach` reads the link each time `quest-session` attaches, again
on each reconnection, since the host may have lost the session meanwhile. When
it creates a linked session, it starts `claude --resume` with the linked
conversation, whatever the default agent. A conversation with nothing in it
has no transcript to resume, so Claude starts fresh instead.

## Agent status

The flag or sword at the right of each row shows, first match wins:

| Color | When |
| --- | --- |
| Red | An agent stopped in the middle of a turn, as when its computer restarted. It stays red until it is given a new prompt. |
| Yellow | An agent is working, or background work it started still runs. |
| Green | An agent's turn ended, or it asks for a permission or an answer, after its window last had the focus. |
| Bright | A window is open. |
| Dim | No window is open. |

Each row counts its own sessions: a project's, `questmarchy:<project>:<n>`,
or a quest's, `questmarchy:<project>:<slug>:<n>`. An agent keeps its status
with no window open, since its session keeps it running, and through a restart
of either computer. Red, yellow, and green are the theme's.

Only Claude Code reports a status, through Questmarchy's plugin; install it
as [Resuming conversations](#resuming-conversations) says. Its hooks, in
`claude-plugin/hooks/agent-status`, keep each session's status where the
session lives, in `~/.local/state/questmarchy/status/shpool/<session>.json`,
as `{state, since, transcript}`. `state` is `running` from a prompt on, and
again after a tool runs; `waiting` while a permission or `AskUserQuestion`
waits on the user; `done` when the turn ends, unless background work it
started still runs; and `interrupted` when Claude starts again over a turn
that was `running` or `waiting`, as on a resume after a reboot. `since` is
when the state began, by that computer's clock. Quitting with `/exit` or
`/logout` deletes the file, as it does the session's link.

[`sessionctl status`](#sessionctl) prints the statuses. A turn `running` or
`waiting` in a session that shpool lost is `interrupted`. No hook runs when
you interrupt a turn with Escape, so a `running` turn whose transcript ends
with Claude's "[Request interrupted by user]" after `since` is left out.

While the panel is open, the widget runs `quest-window -s` every 3 seconds
and caches the statuses in `~/.cache/questmarchy/status.json`. It sees open
windows and the focus through the compositor, and records when each window
last lost the focus in `~/.local/state/questmarchy/seen.json`. A turn is
green when its `since` is later than that, and its window does not have the
focus.

## quest-window

The widget does its work through `bin/quest-window`, which can also be run by
hand:

```sh
bin/quest-window [-w <world>] <project> [<slug>]
bin/quest-window -l
bin/quest-window -s
```

A world is one of those that `quest world list` prints, such as
`devbox:/home/me/Projects`. `quest-window` takes its host from that list, so
focusing an open window reaches no host. Without `-w`, the project is looked
for in every world, and `quest-window` stops when more than one has it. To
open a new session, `quest-window` asks `quest show`, or `quest realm show`
for a project, for its directory. It chooses the sessions to open with
[`sessionctl prepare`](#sessionctl) where the project lives.

Each time it opens or focuses a window, `quest-window` records the time in
`~/.local/state/questmarchy/opened.json`, as `[{place, project, slug,
opened}]`, one entry for each project or quest, with no `slug` for a
project. `place` is the world, under the name worlds had before the `quest`
command, so that earlier records still count. `opened` is in seconds since the
epoch.

`-l` runs `quest world list`, `quest realm list`, and `quest list` at once and
prints, as JSON, `{worlds: [{world, host, path}], projects: [{world, name}],
quests: [{world, project, slug}], failed: [<world>]}`. Archived quests are
left out. `failed` holds the worlds that could not be listed. A realm whose
quests could not be listed, as when its `quests` directory cannot be read,
shows none; `quest list` says why.

`-s` runs `sessionctl status` on every computer that has worlds at once and
prints `{hosts: [{host, sessions: [{session, state, since}]}], failed:
[<host>]}`, each computer by the name in its windows' classes. `failed` holds
the computers that could not be reached.

## sessionctl

`bin/sessionctl` does the part of opening a window that runs where the
project lives, so that `quest-window` and each window's `quest-session` reach
a host with one ssh call each. It is written in Python, since a host has
`python3` for `quest` but need not have `jq`.

```sh
bin/sessionctl prepare <prefix> <dir> [<agent>]
bin/sessionctl attach [-f] <session> <dir> [<agent>]
bin/sessionctl status
```

`prepare` checks the directory, shpool, the agent, and Questmarchy's plugin
for Claude Code, reads the links, lists shpool's sessions, and chooses the
sessions named `<prefix><number>` to open windows for, as
[Windows and sessions](#windows-and-sessions) describes. It prints `{dir,
agent, sessions, notices}` as JSON: the directory's full path, the agent to
start, empty when there is none, the sessions' names, and the notifications
to show. It changes nothing, so it can be run by hand to see what opening a
project or quest would do.

`attach` attaches to the session, with `-f` forcing off the terminal attached
to it, or creates it in `<dir>`, resuming its linked conversation or running
`<agent>`. It becomes `shpool attach`, so that the window gets the session's
status.

`status` prints `{sessions: [{session, state, since}]}` as JSON: the status
of the agent in each Questmarchy session that has one, as [Agent
status](#agent-status) describes, with `since` null for a session shpool
lost. It changes nothing.

On this computer, they run the plugin's own `sessionctl`. On another host,
they run the copy in `~/.local/share/questmarchy/bin/sessionctl`: each time
`quest-window` runs it there, it sends the plugin's copy along in the same
ssh call, and the host replaces its own when it is missing or differs. A
plugin update thus reaches a host the next time the panel opens. Removing Questmarchy leaves the copy behind; delete
`~/.local/share/questmarchy` on each host to remove it too.

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
  gets only its entry in `shell.json`, so code must repeat any default.
- `omarchy plugin validate` rejects any symlink in the folder, including a
  linked plugin folder itself, so validate the clone, not the link.

The repository is also a marketplace for Claude Code plugins, through
`.claude-plugin/marketplace.json`, with Questmarchy's plugin in
`claude-plugin/`. It keeps the plugin out of the root so that Claude Code
does not put `bin/` on its Bash tool's `PATH`. Check it with `claude plugin
validate .`, and try a change with `claude --plugin-dir claude-plugin` and
`QUESTMARCHY_SESSION` set.

`assets/sword.svg`, `assets/flag.svg`, and `assets/globe.svg` are the icons'
source art. `SwordIcon.qml`, `FlagIcon.qml`, and `GlobeIcon.qml` hold copies
of their path data.

## License

MIT. See [LICENSE](LICENSE).
