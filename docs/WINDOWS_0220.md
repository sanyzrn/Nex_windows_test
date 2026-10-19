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
  frame is ignored on start and when switching back from the edge panel.
  (Re-anchoring on a return from the tray was dropped together with the
  tray-close behaviour, see "Reverted" below.)
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

## Phase 2 — library and cards

- `NoteCard` (packages/ui) puts the reminder chip and the "+N" files mark in a
  footnote row below the preview. Marked cards are exactly one footnote row taller
  (`nexCardHeightFor(withFootnote: true)`), whatever the marks hold.
- The library list pane has one search row (search, grid/list switch where a grid
  fits, tag manager). Date dividers are accent capsules. `_FilterBar` is full width
  so its pills align to the leading edge.
- `NoteActionBar` is a single tonal dock; each action takes an equal share.

## Phase 3 — capture

- `NexWorkspaceHome` hides the hero line and the counters below 620 px
  (`compactPage`), so the editor starts under the section header.
- `_CaptureAction` renders as an icon-over-label tile below 520 px, three
  across; wider layouts keep the outlined buttons.
- Not changed: Ctrl+V is still handled by the composer (it protects a note that
  was started while the clipboard was being read, see
  `usability_regression_test`). Whether mixed Persian/English text in
  Flutter's single-direction text field (ADR-037 in the Android repo) is the
  typing problem seen on Windows is not established; it needs the symptom.

## Phase 4 — reminders and notifications

- `reminderLookahead` / `reminderOccurrenceId` (reminder_policy.dart): a repeating
  reminder queues 7 (daily) or 8 (weekly) occurrences. Ids are `nx<10 hex>r<NN>`
  (15 characters; the queue rejects 16). The coordinator's 30-second pass
  reconciles them like any other id, so dropped, paused or edited series are
  taken back.
- Scheduled toasts carry the Tag `<id>@<epoch seconds>`. The fallback toast
  (`showOverdueReminder(occurrence:)`) checks the Action Center history for that
  tag and does nothing if Windows already delivered it.
- Settings > Display > Test notifications; native errors come from
  `reminderDiagnosticError`.
- Needs a Windows check: scheduled toasts with the installed shortcut
  (AUMID `Nex.Desktop.App`), the history check, click-through to the note,
  recurring toasts after the app was exited. See `docs/TEST_0220.md`.

## Visual baselines

Window-mode screenshots change with the look. `refresh-visual-baselines.yml`
regenerates them on a Windows runner when
`.github/refresh-baselines-request.txt` is changed on a `windows/**` branch,
and commits them to that branch (a bot commit does not start CI by itself; push
any ordinary commit after it). Review the changed images in the PR before
merging. The comparison gate in `desktop.yml` is unchanged.

## Reverted

Everything committed to `main` after the 0.21.0 release (PR #6, 10:55 Tehran) and
before this work started — sixteen commits between 16:26 and 18:58 Tehran on
2026-10-19: close-to-tray, the reminder recovery/fallback, the Solar Hijri
reminder picker, the layout-toggle visibility change, their golden updates, the
0.21.1 bump and the one-off golden workflow — was removed again on this branch
(`git revert`, history kept; no force push). The tree is 0.21.0 plus the phases
above. Closing the window quits Nex, as in 0.21.0.
