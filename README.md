# niri-helpers.sh

A small Bash library of helpers for [niri](https://github.com/niri-wm/niri)'s
IPC. It wraps `niri msg --json <request>` and `jq` in reusable queries and
window actions. Call `niri_init` to capture snapshot state when a script
needs several queries.

## Requirements

- Bash
- `jq`
- A running niri session
- `uwsm-app` only when using the default, configurable launcher in `niri_focus_or_spawn`

## Install

Download the versioned single-file release:

```bash
mkdir -p ~/.local/lib
curl --fail --location --output ~/.local/lib/niri-helpers.sh \
  https://raw.githubusercontent.com/viacoffee/niri-helpers/v1.1.0/niri-helpers.sh
```

Source it from a script:

```bash
source ~/.local/lib/niri-helpers.sh
```

## Quick start

```bash
source ~/.local/lib/niri-helpers.sh
niri_init # capture windows, workspaces, and outputs

focused_window="$(niri_focused_window_id)"
niri_windows_on_workspace | jq -r '"\(.app_id // "?"): \(.title // "?")"'
niri_focus_or_spawn 'firefox' firefox
```

`niri_focus_or_spawn` focuses the first matching window. If none matches, it
launches the supplied command. Provide `command...` unless a matching window
is guaranteed.

## Configuration

`niri_focus_or_spawn` launches commands through `NIRI_APP_LAUNCHER`, which
defaults to `uwsm-app`. The launcher receives `--` followed by the command and
its arguments. Set the variable before sourcing the library:

```bash
NIRI_APP_LAUNCHER="my-launcher"
source ~/.local/lib/niri-helpers.sh
```

Do not use an inline assignment such as `NIRI_APP_LAUNCHER=my-launcher source
...`: Bash discards that assignment when `source` returns.

## Snapshot state

Without `niri_init`, every data accessor fetches fresh state from niri. After
`niri_init`, data accessors and query functions read the snapshot values in
`_NIRI_WINDOWS`, `_NIRI_WORKSPACES`, and `_NIRI_OUTPUTS`; they make no further
JSON-query IPC requests.

Window actions still send `niri msg action` requests. Refresh the snapshot
after an action if later queries need current state:

```bash
niri_init
niri_close_matching 'firefox'
niri_init
```

The snapshot is assembled from three sequential IPC requests, not one atomic
niri snapshot. Treat it as a convenient view rather than one internally
consistent compositor state.

## Function reference

Functions that return windows or workspaces write one compact JSON object per
line. The `*_json` accessors write a JSON array. Match patterns are
case-insensitive `jq` regular expressions against a window's `app_id` or
`title`.

### State and data access

| Function | Result |
|---|---|
| `niri_init` | Refreshes the windows, workspaces, and outputs snapshot. |
| `niri_windows_json` | Windows as a JSON array. |
| `niri_workspaces_json` | Workspaces as a JSON array. |
| `niri_outputs_json` | Outputs as a JSON array. |

The accessors are intended for custom queries:

```bash
# Number of open windows per app
niri_windows_json | jq -r 'group_by(.app_id)[] | "\(length)\t\(.[0].app_id)"'
```

### Queries

| Function | Result |
|---|---|
| `niri_is_window_focused <id>` | Succeeds if the window is focused; otherwise exits nonzero. |
| `niri_focused_window_id` | Focused window ID. |
| `niri_focused_workspace_id` | Focused workspace ID, including on an empty workspace. |
| `niri_windows_on_workspace [ws_id]` | Windows on `ws_id`, or the focused workspace by default. |
| `niri_windows_matching <pattern>` | Matching windows. |
| `niri_focused_workspace_name` | Focused workspace name; empty when unnamed. |
| `niri_workspace_by_name <name>` | Workspaces with that name. |
| `niri_focused_output` | Output of the focused workspace. |
| `niri_workspaces_on_output <output>` | Workspaces on an output. |
| `niri_windows_on_output <output>` | Windows on an output. |

### Window actions

| Function | Effect |
|---|---|
| `niri_close_all_windows` | Closes every open window. |
| `niri_close_all_on_workspace [ws_id]` | Closes windows on `ws_id`, or the focused workspace. |
| `niri_close_unfocused_on_workspace [ws_id]` | Closes all but the focused window on a workspace. |
| `niri_close_matching <pattern>` | Closes all matching windows. |
| `niri_focus_or_spawn <pattern> [command...]` | Focuses a match, or launches `command`; required when no match exists. |

For workspace and output movement, use niri's native actions directly:

```bash
niri msg action focus-workspace <name|index>
niri msg action move-window-to-workspace [--window-id <id>] <name|index>
niri msg action focus-monitor <output>
niri msg action move-window-to-monitor [--id <id>] <output>
```

## Examples

The scripts in `examples/` are starting points, not commands to run without
review. They all use `realpath` to find the library. `window-switcher.sh` also
needs `fuzzel`; replace its picker command to use rofi, wofi, or dmenu.
`graceful-shutdown.sh` requires `systemctl` and can reboot or power off the
machine.

| Script | Demonstrates |
|---|---|
| `focus-or-spawn.sh` | Focus or launch an app by pattern. |
| `window-switcher.sh` | Snapshot queries and a fuzzy window picker. |
| `clear-workspace.sh` | Closing all, or all unfocused, workspace windows. |
| `close-by-pattern.sh` | Listing and closing matching windows. |
| `graceful-shutdown.sh` | Closing windows before reboot or poweroff. |
| `session-summary.sh` | Summarizing outputs, workspaces, and their windows. |

> [!WARNING]
> `clear-workspace.sh` and `close-by-pattern.sh` close windows and may discard
> unsaved work. `graceful-shutdown.sh` can reboot or power off the machine.

## License

[MIT](LICENSE)
