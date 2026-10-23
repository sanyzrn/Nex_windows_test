# Phase 6 — P4/P5: Cycle dialogs and Library copy notices

Owner approved this combined step on the existing unmerged `windows/0.28-tag-picker` branch. Base: `f4158b8048d258e9850ff49aab74f408992f01a9`. Version remains **0.28.0+22**.

Changed:
- `modules/cycle_view.dart`: replace only period-edit, period-delete and typical-length `AlertDialog` constructors with the existing `NexAlertDialog`. Their routes, validation, fields and results are preserved; the shared wrapper adds its optional glass shell.
- `library_actions.dart`, `library_keys.dart`, `library_list_pane.dart`: use existing `showNexNotice` for context-menu, Ctrl+C and selection-copy feedback. Copies replace queued notices, expire after four seconds and offer Close. Clipboard formatting, editing focus guards, deletion/attachment Undo and private clipboard code are unchanged.
- `test/cycle_dialogs_test.dart`: four English/Persian × light/dark cases, glass on/off across the cases, at 380×520 and 200% text. Exercise all three dialog shells and actual cancel/save outcomes using real storage and preferences.
- `test/library_copy_notice_test.dart`: four English/Persian × light/dark cases exercising all three copy paths, actual clipboard payloads, rapid repetition/replacement, automatic expiry and manual dismissal.
- Both unreleased changelogs and append-only SUMMARY updated. No schema, shared-package, settings-key, workflow, version or baseline changes.

Checks (Linux, Flutter 3.44.8 / Dart 3.12.2; scratch-only SQLite soname shim):
- `flutter test --no-pub test/cycle_dialogs_test.dart test/b8_modules_test.dart test/reported_bugs_test.dart test/note_copy_test.dart --reporter expanded`: **passed, 23 tests**. Includes existing cycle/private-session, note copy and deletion/Undo regressions.
- `flutter analyze --no-pub`: **passed, no issues** (2.4 s). `flutter test --no-pub test/library_copy_notice_test.dart --reporter expanded`: **passed, 4 tests**. Across both test commands, **27 distinct selected tests passed**; the full suite was not run.
- Root `python tools/check_l10n_parity.py`: **passed**. English/Persian release-history headings and bullet counts match. Handwritten Dart format, `git diff --check`, scope review and append-only SUMMARY checks: **passed**.

Initial new-test runs/analyzer failed on fixture setup/style: missing/unnecessary imports, a missing brace, looking for a lazy offscreen row, missing snapshot range arguments and leaving the test private-session timer open until teardown. Fixed the fixtures to use correct imports, scroll/wait, supply the existing command contract and lock the session before the widget test ends. No product workaround or existing test/tolerance relaxation.

Not run: Windows native/installed-app checks, full Windows CI, Windows visual review or installer build. Glass-enabled Cycle dialogs and the copy notice Close/timing are the visible changes to review on Windows; no golden regeneration was performed here. P1–P5 are now implemented (P1 released in 0.27; P2–P5 on this branch). Backup kit, performance measurements and 0.28 release preparation remain pending. No merge or release in this step.
