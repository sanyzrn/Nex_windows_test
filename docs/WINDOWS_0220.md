# Windows 0.22.0 — window redesign, phase 1

Phase 0 (foundation) synced the shared packages with Android 2.1.9 and
raised the declared SDK to Flutter 3.44 / Dart 3.12, which the code and CI
already required. Phase 1 gives the desktop window its own form.

## The compact window

- **Size and place.** The window opens as a portrait card of 460 x 760 dip,
  12 dip from the bottom-right corner of the work area of the monitor under the
  cursor, shrunk to fit small screens. `kCompactWindow*` in
  `windows/runner/native_window.h` holds the numbers; `CompactWindowFrame`
  computes the frame.
- **Always the same.** With the default setting (`windowRemember` off) the saved
  frame is ignored on start and when switching back from the edge panel. When the
  window comes back from the tray (hidden or minimised) it returns to the corner
  (`NativeBridge::FocusWindow`). A visible window that is only focused is never moved.
- **Remembering.** `Settings > Display > Remember window size and position`
  restores the last frame (and maximised state) as in 0.21. The saved frame is
  recorded either way, so turning it on later has something to restore.
- **Limits.** The window stays resizable; the minimum is 380 x 520 dip.

## Layout

- Below 960 logical px the rail is `_SlimRail`: a 76 px column of icon-over-label
  tiles sitting directly on the window surface. The selected tile gets the filled
  icon and an accent pill. Everything that was in the wide rail's footer (edge
  panel switch, theme, shortcut list) is behind the More tile; search is the
  button in the section header.
- From 960 px the labelled rail is kept.
- `nexWindowTint` washes the surface tone with the accent so each palette gets
  its own window colour; the content sits in a 28 px rounded card
  (`window-card`). The caption has no bar of its own.

## Verifying

Layout is checked at 440 px (compact) and 1100 px in English/Persian, light/dark
through `workspace_redesign_test.dart` and `window_shell_test.dart`. Placement and
re-anchoring are native code and need a manual check on Windows: first launch,
close to tray and Open, a second monitor, 125%/150% scaling.
