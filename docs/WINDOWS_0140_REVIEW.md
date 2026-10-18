# Nex Windows 0.14.0+11 — review and release evidence

Baseline: `1ee95d8` (0.13.0+10). Review date: 2026-10-18.
Plan: [WINDOWS_0140_PLAN.md](WINDOWS_0140_PLAN.md).

## What changed

The notebook now has a bounded desktop workspace: a writing surface and pinned
notes share the main row, with recently updated notes in a grid below. Tools
have categories and a clearable search. Navigation has a New note action, less
visual clutter and a local-storage indicator. The library uses a distinct
reader surface and one active-card outline. Controls have larger desktop hit
areas; the sea-floor texture is quieter. English/Persian, dark/light, compact
panels and enlarged text remain supported without new runtime dependencies.

## Confirmed defects fixed

| Area | Failure | Correction |
| --- | --- | --- |
| Capture | Failed flush cleared the recovery copy on New note | Keep text/session on failure; show error and retry |
| Capture | Input arriving during session rotation could be cleared | Drain the latest write revision before replacing the session |
| Backup restore | Old capture ID survived replacement of the database | Flush first; reset capture only after successful restore |
| Reader | Editing an active capture left its composer stale | Reflect reader edits into the active composer |
| Caption | Refreshing the reader reassigned the controller while typing | Preserve the focused caption and reject older note revisions |
| Quick paste | Typing after a quick-pasted URL could overwrite the link | Save quick-pasted links independently of the composer |
| Empty library | Write/Tools used panel-only routing in window mode | Route to the matching desktop section |
| Filters | Null-valued All items were interpreted as menu dismissal | Use an explicit non-null menu choice and clear the filter |
| Keyboard | Parent library shortcuts could intercept editor keys | Text editing retains arrows, Delete, copy and undo |
| Tools | Hidden tools remained in the desktop directory | Apply the persisted visibility setting |
| Store | Calls submitted after close could wait forever | Reject calls once the terminal FIFO command is queued |
| Store | Worker errors/exits could leave pending futures unresolved | Observe isolate errors/exits and finish pending calls |
| Preferences | Interrupted direct writes could lose shell settings | Stage writes and keep a readable previous snapshot |
| Startup | Invalid typed settings could prevent the entire app opening | Fall back to usable shell defaults, retaining domain data |
| Timer | Countdown counted callbacks rather than elapsed time | Calculate against a deadline, including after Windows sleep |
| Restore cleanup | Failed decryption/unpack left temporary directories | Clean staging on authentication and extraction failures |
| Restored preferences | Widget mode could disagree with the native host | Apply the mode transition, hotkey, startup and panel placement |
| Home | Recent notes were ordered only by creation | Order by last edit with a stable ID tiebreaker |

Existing database schema, app identity, installation directory and notification
identity are preserved. No migration or new heavy UI/media package is required.

## Validation in the Linux workspace

SDK: Flutter 3.44.8, Dart 3.12.2, matching the existing Windows CI pin.
Dependencies resolved from committed lockfiles using the default pub.dev host.

- Desktop and shared UI static analysis: clean.
- Core and data static analysis: clean.
- Desktop behavior suite: 136 passing.
- Shared UI: 192 passing.
- Core: 198 passing.
- Data: 199 passing, 14 existing skips.
- Added focused regressions for capture rotation/failure/recovery, valid/invalid
  restore, reader-to-composer consistency, store closing, empty navigation,
  All-type filtering, hidden tools, preference recovery and missed timer ticks.
- Twelve actual-widget previews generated and inspected: home, tools, settings,
  command palette and reader, including Persian at 2× text scale and 700px width.
  Linux previews are not used to overwrite the Windows font baselines.
- Existing 10,000-note library benchmark exercises persistence and bilingual search.
- CI now also analyzes shared UI and analyzes/tests core and data.

## Windows release gate

Windows screenshot comparison, Release compilation and Inno Setup packaging
must pass on the exact release source. Changed UI requires intentionally
reviewed Windows baselines; comparison is not disabled or given a broad tolerance.

Status: pending Windows CI. A source review alone is not an installer validation.

## Remaining physical checks

Clean-machine install/upgrade, real mixed-DPI monitors/hot-plug, tray/global
shortcut interaction and installed notifications after reboot need physical
Windows validation. The installer remains unsigned. Cloud/LAN sync, automatic
updates and indefinite reminder recurrence while fully exited remain outside
this release's implemented feature set.
