# Phase 6 — P2: existing-tag picker (0.28 development)

The owner authorized starting P2 and assigned subsequent work to 0.28.0 while testing the published 0.27.0 installer. Work is isolated on `windows/0.28-tag-picker`, based on main `6c949b2f55660f9aa19b55a49eff914d103a11c6`. No release is requested for this intermediate step.

## Behavior

Note detail → Tags & threads → Choose an existing tag opens a searchable, localized dialog. It displays tag colors and excludes tags already attached to the latest saved note. Search uses the existing Persian/Arabic letter and diacritic folding. Loading, no matches, all tags attached, failure and retry states are localized. The dialog keeps an edge panel open while choosing/saving; cancellation leaves the note alone. The original new-tag field remains available.

The existing `tag` storage command accepts an existing tag ID as an alternative to a new name. Selecting after a rename attaches the same tag with its current name; repeating attachment leaves the note revision unchanged. A deleted note or tag rejects the operation without recreating tags. A note-detail identity check prevents a delayed selection from being applied to a different note. No schema, shared-package, settings-key, application-identity or update-protocol change.

Version declarations, Windows resources and installer metadata now agree on **0.28.0+22 / 0.28.0.22**. Both changelogs label 0.28.0 unreleased. The README describes the development version and chooser; latest-release links still resolve to the public release.

## Validation

Linux, Flutter **3.44.8**, Dart **3.12.2**. Commands below are from `apps/desktop` unless stated otherwise.

- `flutter analyze --no-pub`: passed, no issues (final run 3.4 s).
- `flutter test --no-pub test/tag_picker_test.dart test/version_consistency_test.dart test/part5_localization_test.dart test/redesign_regression_test.dart test/menu_rule_test.dart --reporter expanded`: passed, 23 tests at that point (five new, eighteen existing).
- After adding the error/retry/empty-state case and fixing the analyzer brace warning, `flutter test --no-pub test/tag_picker_test.dart --reporter expanded`: passed, all six final new tests. Four cases cover real note-detail selection and persistence in English/Persian and light/dark, at 380×520 with 200% text. They also check tag color, attached-tag exclusion, Persian/Arabic search, cancellation and the original typed-tag flow. The other cases check ID attachment after rename, idempotency, deletion and retry/empty behavior.
- Tests use isolated temporary databases and the real storage worker. `LD_LIBRARY_PATH` supplied the existing scratch-only SQLite soname shim; no host workaround is tracked.
- Root `python tools/check_l10n_parity.py`: passed. `python -m unittest discover -s tools -p test_check_l10n_parity.py`: passed, 18 tests.
- Generated localization getters match `flutter gen-l10n` lexically; unrelated generated formatting was preserved. Changed handwritten Dart files were formatted.
- `git diff --check` and scope review: passed. Lockfiles, shared packages, schema, baseline images and workflow files are unchanged. SUMMARY was appended without rewriting previous entries.

Initial new-test failures were test-fixture issues: a nonexistent theme helper, an assumption that a fresh database had no seeded tags, and a lazy-list row expectation before searching. These were corrected to use actual shared themes and seeded data behavior. No existing assertion, baseline or tolerance was loosened.

## Remaining release checks

Full Windows CI, native panel interaction, physical keyboard/accessibility, visual review, installer and installed-app checks were not run here. About/version and release-history baselines must be refreshed and reviewed on the Windows runner before releasing 0.28.0; no Linux golden regeneration was performed. The published 0.27.0 installer remains the version under owner testing. P3 date filters and subsequent parity work remain pending.
