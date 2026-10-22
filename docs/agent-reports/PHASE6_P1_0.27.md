# Phase 6 — P1: consistent bulk Pin / Unpin

The owner delegated the next-item choice after reviewing phase 5. P1 was chosen as the smallest confirmed behavioral discrepancy. P2–P5, performance tooling and module ports have not been started.

## Changed

- `apps/desktop/lib/nex/library_list_pane.dart`: derive one intent for the current selection. Pin only unpinned notes in a mixed/unpinned selection; unpin only when every selected note is pinned. The tooltip reflects that intent. Existing pinned timestamps remain intact. Stop when the repository refuses another pin and show localized capacity feedback; the existing five-note limit remains unchanged.
- `apps/desktop/lib/l10n/app_en.arb`, `app_fa.arb`: add `pinLimitReached` in English and Persian.
- `apps/desktop/lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_fa.dart`: include the generated getter. Existing formatting outside this addition was preserved; lexical comparison against generated output confirmed unchanged code apart from formatting/trailing commas.
- `apps/desktop/test/bulk_pin_test.dart`: four UI/database regressions, using an isolated sample library and the real storage worker. Cover mixed selection, all pinned, none pinned and capacity exhaustion; assert selected membership, actual saved state, preserved existing timestamps, correct tooltip, direction/theme and capacity feedback. The four cases collectively cover English/Persian, light/dark and LTR/RTL.
- `docs/agent-reports/PHASE6_P1_0.27.md`: this report.
- `docs/agent-reports/SUMMARY.md`: append-only phase summary.

## Checks

Environment: Linux. Reused the available Flutter **3.44.8** SDK / Dart **3.12.2** after preparing its missing caches. No SDK or host workaround was added to repository files.

Commands below run from `apps/desktop` unless stated otherwise; `flutter`/`dart` refer to that SDK.

- `flutter pub get --enforce-lockfile` → **run here and passed**; tracked lockfiles unchanged. Initial SDK cache extraction failed on archive ownership; retrying with `TAR_OPTIONS=--no-same-owner` succeeded.
- `flutter analyze --no-pub` → **run here and passed**, no issues (final run: 5.7 s). An initial unnecessary test import was removed before the successful reruns.
- `LD_LIBRARY_PATH=/workspace/scratch/8157d047247b/test-libs flutter test --no-pub test/bulk_pin_test.dart test/redesign_regression_test.dart test/version_consistency_test.dart test/menu_rule_test.dart --reporter expanded` → **run here and passed, 15 tests**. Four are new bulk-pin scenarios; eleven are existing regression/version/menu tests.
- Initial test run → **run here and failed** because Linux exposed `libsqlite3.so.0` but not the unversioned `libsqlite3.so` name. A scratch-only symlink to the installed system library supplied that name; no app, package or test loader was changed. A subsequent new capacity assertion assumed an unspecified row order; it was corrected to require exactly one additional selected pin and five total, while checking selection membership and all pre-existing timestamps. Final tests passed. No existing assertion, tolerance or baseline was loosened.
- From repository root, `python tools/check_l10n_parity.py` → **run here and passed**.
- From repository root, `python -m unittest discover -s tools -p test_check_l10n_parity.py` → **run here and passed, 18 tests**.
- `dart format` on the changed application/test Dart files → **run here and passed**, final run changed no files.
- `git diff --check`, new-file whitespace and bounded-scope checks → **run here and passed**. Final summary integrity is recorded in SUMMARY.
- Exact PowerShell UI-hygiene gate, Windows build/native smoke, installer and Windows golden comparisons → **not run**: Windows/PowerShell are unavailable. The full test suite was not run for this bounded sub-step. No golden images were regenerated.

## Not tested on this machine

Physical Windows input and accessibility, native toast/tray behavior, DPI/monitors and live Windows rendering. UI/database behavior was tested with the Linux Flutter widget runner, not a Windows application build. The capacity case exercised the English message; translation parity checked both languages, and Persian widget cases exercised localized Pin/Unpin behavior.

## Risks / visible changes

The selection tooltip now says Unpin when appropriate. At capacity, a notice explains that up to five notes can be pinned; available slots are filled before stopping. No persistent layout, data/schema, settings keys, shared packages, identity or update logic changed. Windows visual review is still needed for the changed tooltip/conditional notice; existing golden images remain untouched.

## Handoff

Phase 5's two documentation files are committed locally as `4b931e6` (`Document Android parity gaps and prioritize desktop follow-up work`) on `windows/0.27-parity-audit`. After reviewing P1, the owner explicitly authorized committing/pushing the completed work and releasing version 0.27.0 with an installer. This later instruction supersedes the original owner-only push/release restriction. Remaining parity candidates are deferred to a later version. Windows CI and verified installer publication must complete before claiming the release is available.
