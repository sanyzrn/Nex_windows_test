# Phase 6 — P3: Library date presets (0.28 development)

The owner requested adding the next step to the unmerged P2 branch. P3 is on the same `windows/0.28-tag-picker` branch, based on P2 commit `72889e58e427cead702bdbc6127ca15c0f630d1b`. Development version remains **0.28.0+22**. Main/release publication is deferred.

## Behavior

- Library's calendar pill offers Any time, Today, Last 7 days and Last 30 days. Seven/thirty days include today and the preceding six/twenty-nine calendar days. These filter creation dates, independent of the displayed Persian/Gregorian calendar.
- Dates combine with text, type, tag and thread filters using existing `SearchFilters.createdFrom/createdTo` and the existing worker/SQL path. No worker, repository, schema, settings or shared-package changes.
- Boundaries are local midnight through the final microsecond before the following midnight, converted to UTC. Constructing calendar dates rather than subtracting 24-hour durations handles DST and month/year boundaries. Bounds are recalculated on each library load.
- The pill's clear action resets only dates; All/Clear filters and the filtered-empty action reset dates along with existing filters. Date-only empty results use the filtered-empty design. Active dates also disable unfiltered timeline pagination and close a selected detail when it no longer matches.
- Recently deleted remains its separate existing view: entering it clears the date preset and hides the date control. Returning uses Any time. No hidden date restriction applies to trash.
- Added four paired English/Persian strings and generated getters, plus README and unreleased changelog guidance. The existing Today translation is reused. P2 remains intact.

## Validation

Linux, Flutter **3.44.8**, Dart **3.12.2**. Commands from `apps/desktop` unless stated otherwise. SQLite tests use the existing scratch-only `LD_LIBRARY_PATH` shim, with no repository workaround.

- `TZ=Asia/Tehran flutter test --no-pub test/library_date_filter_test.dart --reporter expanded`: **4 passed**. Calendar bounds cover DST dates, year rollover and leap February. Real-worker searches include exact lower/upper instants and exclude adjacent instants, both with and without text. UI cases cover English/light and Persian/dark, combined query/type/tag/thread, all three narrowed presets, date-only clearing, All, empty-state reset and trash. Both resize from a wide view to 380×520 with 200% text.
- `TZ=America/New_York flutter test --no-pub test/library_date_filter_test.dart --name 'calendar bounds|date search' --reporter expanded`: **2 passed**. Explicit UTC assertions verify both the 23-hour spring day and 25-hour autumn day; real SQL boundaries also pass in this timezone.
- `flutter analyze --no-pub`: **passed, no issues**, final run 5.2 s.
- `TZ=Asia/Tehran flutter test --no-pub test/tag_picker_test.dart test/bulk_pin_test.dart test/part5_localization_test.dart test/version_consistency_test.dart test/menu_rule_test.dart test/redesign_regression_test.dart --reporter expanded`: **28 passed**. Together with the four P3 tests, 32 distinct selected tests passed; this is not a full-suite claim.
- Root `python tools/check_l10n_parity.py`: **passed**. `python -m unittest discover -s tools -p test_check_l10n_parity.py`: **18 passed**. New localization getters were lexically compared with generated output, preserving unrelated formatting.
- Changed handwritten Dart format checks, `git diff --check`, scope review and append-only SUMMARY check: **passed**. No baseline, workflow, lockfile or version-metadata changes in P3.

Initial new UI tests waited for animation settlement while real storage I/O was pending, then matched duplicate tag/thread tooltips. Test helpers now wait on actual result state with I/O yields and target the specific menu widgets. A concurrent Flutter SDK startup hit a cache-stamp race; the final SDK checks were run sequentially. No product workaround, existing test relaxation or golden change was made.

Full Windows CI, native/installed-app validation, Windows golden refresh/review and a 0.28 installer remain pending. Merge to main triggers the release workflow after successful Windows CI, so this intermediate branch was not merged. P4/P5 remain separate follow-up items.
