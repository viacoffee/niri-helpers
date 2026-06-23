# niri-helpers.sh

A bash library for [niri](https://github.com/niri-wm/niri) window management automation.

Abstracts the `niri msg --json | jq` pattern into named, composable functions with a snapshot-based caching model to minimize IPC round-trips.

## Requirements

- `bash`
- `jq`
- A running `niri` session
- `uwsm` (optional — used by `niri_focus_or_spawn` by default; configurable)

## Installation

It's a single self-contained file. Drop it somewhere on disk and source it:

```bash
curl -o ~/.local/lib/niri-helpers.sh \
  https://raw.githubusercontent.com/viacoffee/niri-helpers/main/niri-helpers.sh
```

Then source it from your scripts:

```bash
source ~/.local/lib/niri-helpers.sh
```

If you also want the example scripts, clone the whole repo instead:

```bash
git clone https://github.com/viacoffee/niri-helpers.git
source niri-helpers/niri-helpers.sh
```

## Configuration

Set `NIRI_APP_LAUNCHER` before sourcing to override the app launcher used by `niri_focus_or_spawn`:

```bash
NIRI_APP_LAUNCHER="my-launcher"
source niri-helpers.sh
```

Default: `uwsm-app`.

(Set it as its own statement, not as an inline prefix on `source` — an env-var
prefix on the `source` builtin is discarded when `source` returns, leaving the
override empty for later calls.)

## Caching model

All query functions use a lazy-cache: the first call fetches data from niri's IPC and stores it in `_NIRI_WINDOWS`, `_NIRI_WORKSPACES`, or `_NIRI_OUTPUTS`. Subsequent calls in the same process return the cached value.

Call `niri_init` once at the top of any script that uses multiple query functions to pre-warm all three caches upfront:

```bash
source niri-helpers.sh
niri_init
# all subsequent calls use cached data
```

**Subshell note:** The lazy-cache sets variables in the calling shell context. Subshells (pipes, `$(...)`) inherit the parent's variables but can't write back to them — so if you don't call `niri_init` first, each subshell that needs data will issue its own IPC request. `niri_init` sidesteps this by setting all variables in the main shell before any subshells run.

## Function reference

### Snapshot

| Function | Description |
|---|---|
| `niri_init` | Pre-fetch windows, workspaces, and outputs into `$_NIRI_WINDOWS`, `$_NIRI_WORKSPACES`, `$_NIRI_OUTPUTS` |

### Query primitives

| Function | Description |
|---|---|
| `niri_is_window_focused <id>` | Return true if the given window ID is currently focused |
| `niri_focused_window_id` | ID of the focused window |
| `niri_focused_workspace_id` | ID of the focused workspace |
| `niri_windows_on_workspace [ws_id]` | All windows on a workspace (default: focused workspace) |
| `niri_windows_matching <pattern>` | Windows whose `app_id` or `title` matches a case-insensitive regex |

### Window actions

| Function | Description |
|---|---|
| `niri_close_all_windows` | Close every open window |
| `niri_close_all_on_workspace [ws_id]` | Close all windows on a workspace (default: focused) |
| `niri_close_unfocused_on_workspace [ws_id]` | Close all windows on a workspace except the focused one |
| `niri_close_matching <pattern>` | Close all windows matching a pattern |
| `niri_focus_or_spawn <pattern> [command...]` | Focus an existing matching window, or spawn a new process |

### Named workspace navigation

| Function | Description |
|---|---|
| `niri_focused_workspace_name` | Name of the focused workspace (empty if unnamed) |
| `niri_workspace_by_name <name>` | Workspace JSON object(s) matching a name |

niri's IPC handles focus and move natively — no wrappers needed:

```bash
niri msg action focus-workspace <name|index>
niri msg action move-window-to-workspace [--window-id <id>] <name|index>
```

### Output-aware operations

| Function | Description |
|---|---|
| `niri_focused_output` | Name of the output the focused workspace is on |
| `niri_workspaces_on_output <output>` | All workspaces on a given output as streamed JSON |
| `niri_windows_on_output <output>` | All windows on a given output (joined through workspaces) |

Likewise, niri handles output focus and window movement natively:

```bash
niri msg action focus-monitor <output>
niri msg action move-window-to-monitor [--id <id>] <output>
```

## Examples

The `examples/` directory has reference scripts demonstrating the library. Read them before running, and adapt into your own `~/.local/bin` rather than running blind.

> [!WARNING]
> Some examples are destructive: `clear-workspace.sh` and `close-by-pattern.sh` close windows (you may lose unsaved work), and `graceful-shutdown.sh` reboots or powers off the machine.

| Script | Demonstrates |
|---|---|
| `focus-or-spawn.sh` | `niri_focus_or_spawn` — focus or launch any app by pattern |
| `window-switcher.sh` | `niri_init` + fuzzy picker with `fuzzel` (adaptable to rofi, wofi, dmenu) |
| `clear-workspace.sh` | `niri_close_all_on_workspace`, `niri_close_unfocused_on_workspace` |
| `close-by-pattern.sh` | `niri_windows_matching`, `niri_close_matching` |
| `graceful-shutdown.sh` | `niri_close_all_windows` before reboot or poweroff |
| `session-summary.sh` | `niri_focused_output`, `niri_focused_workspace_name`, `niri_workspaces_on_output`, `niri_windows_on_output` |
