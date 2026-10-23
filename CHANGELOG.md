# Changelog

## Unreleased

Fixed

- Query and close helpers propagate IPC and JSON-query failures without relying
  on the caller's shell options. Close helpers finish selecting targets before
  sending any actions, so a failed selection cannot close a partial result.
- `clear-workspace.sh` rejects unknown or extra arguments before making IPC
  requests, so a mistyped `--keep` cannot close the focused window.
- JSON accessors now preserve IPC failures, and `niri_init` only updates its
  snapshot after all IPC requests succeed.
- `niri_focus_or_spawn` returns query errors instead of treating them as a
  missing window and launching an application.
- The window switcher sanitizes control characters in labels and validates the
  selected window ID against its snapshot.

## v1.2.0 — 2026-09-02

Added

- `niri_tiled_windows_on_workspace_sorted` returns tiled windows in scrolling-layout order.

## v1.1.0 — 2026-08-09

Added

- `niri_windows_json`, `niri_workspaces_json`, and `niri_outputs_json` are now
  public. They were `_`-prefixed and undocumented; they are the intended
  extension point for writing queries this library doesn't cover, so pipe them
  into your own `jq`. The old underscore names are gone rather than aliased,
  since nothing outside the repo should have been calling them.

Changed

- Snapshot accessors no longer try to write the fetched value back to
  `_NIRI_*`. The assignment happened inside the subshell, so it was discarded
  before any caller could see it; `niri_init` was always the only thing that
  filled the snapshot.
- `niri_focus_or_spawn` calls `niri_windows_matching` instead of carrying a
  second copy of the app_id/title regex.
- The example scripts use the public accessors instead of reading `_NIRI_*`
  directly.

Removed

- `_niri_extract_ids`, inlined as `jq -r '.id'` at its two call sites.

No public `niri_*` function changed its signature or behavior.

## v1.0.0

Initial release.
