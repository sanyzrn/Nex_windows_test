# Part 6 — Windows reliability (B0–B3)

Base: `bb47bd9`; branch `windows/0.23-agent`. Owner approved this bundle.

## Changes

- B0: all 34 installed-device checks are triaged in [B0.md](B0.md), with the
  exact physical checks still open and a mixed-language editing script.
- B1: capture, reader/caption, search and tag/thread fields own their text direction.
  Multiline editing follows the active paragraph, freezes direction during IME/range
  selection, and never changes controller text, offsets, undo or paste handling.
  Other edited paragraphs still share Flutter's base direction: mitigation only;
  read mode retains per-paragraph rendering. Physical IME/selection remains open.
- B2: opt-in close-to-tray (default quit); WM_CLOSE is handled before plugins.
  No real tray icon means a clean quit. Open/left-click/single-instance activation
  restore a hidden compact window to the cursor monitor's work-area corner;
  visible focus and remembered windows retain placement. The remember setting
  updates restoration immediately. Tray includes New note and clean draining Quit.
- B3: localized Snooze 10 min / Done protocol actions, logo and timestamp, grouped
  occurrence tags. Store-worker reminder fingerprints (time/repeat/content revision) reject stale/replayed actions;
  Done removes the reminder/series, never the note. Snooze retains repetition
  anchored to the new time. Cold actions run without showing the application.
  Queue acceptance is no longer a delivery receipt; fallback acknowledgements are
  bounded/persisted separately. Queue errors propagate; test success says accepted
  and links to Windows notification settings. OS history deduplication is best
  effort: exactly-once delivery after every dismissal/sleep/crash is not proven.

## Verification

- Local parity guard, 18 checker tests, syntax formatting and diff hygiene passed.
  Local Flutter bootstrap was blocked by automatic review of an instance-metadata
  request; local Flutter analysis/tests/build were not run. Windows CI is used.
- Windows refresh [39569264574](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39569264574)
  passed; all 11 changed images reviewed (`d1c7d81`). No tolerance changes.
- The first full Windows run stopped on two test-only const hints; fixed in
  `2e5e1d4`. Its follow-up passed analysis and entered the desktop suite.
- The next run exposed three reminder-action fixture failures. The repository
  inserts base note fields separately from due-time fields and does not bump the
  content revision for a reminder edit. Fixtures now set reminders through the
  actual API; action fingerprints include time/repeat as well as content revision.
- Final source checks: [PR checks](https://github.com/sanyzrn/Nex_windows_test/pull/9/checks).
  CI compares Windows images, runs the regression suites, builds Release and the
  installer, and exercises the real runner. The new native probe asserts close
  hides/process survives, menu/click/activation restore the corner, visible focus
  preserves the frame, and Quit drains/exits 0; it parses synthetic toast action
  XML through WinRT. The PR body records the final result without rerunning
  unchanged suites merely to update this document.

Physical installed toasts, DND, real IME, DPI/multiple monitors and uninstall/data
retention remain explicitly open in B0. No version/schema/archive-format changes,
merge, tag or release. Stop before Part 7 pending owner approval.
