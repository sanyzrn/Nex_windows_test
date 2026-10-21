# Part 4 — cleanup, documentation and focused logic coverage

Base: `e9a1a83`; branch `windows/0.23-agent`. Covers A5, A7, A8, A10.

Plan: remove only proven leftovers, update current guides/templates, generate the
shortcut reference from the dialog, collect coverage once and add focused tests
for important gaps. Run affected checks, commit/push, stop before Part 5.

## Changes

- Removed seven one-off split scripts: `git grep` found no callers outside those
  obsolete helpers. Simplified the labelled rail after confirming its only caller
  selects it at `kWindowWideAt` (960); slim navigation still handles smaller widths.
- Removed 19 unused ARB keys and six unused map entries in both languages. The
  repeatable audit scans desktop/shared runtime and tests; preserves AI enum wire
  names and city labels derived from IANA identifiers. Candidates still require
  dynamic-lookup review; no automated deletion is provided.
- Refreshed root/app READMEs, current 0.22 notes, contributor guidance and handoff.
  Kept old handoff/test evidence in `docs/archive/` and current-path indexes.
  Reused reviewed Windows compact screenshots with their actual text scale stated.
- Generated the bilingual keyboard table from the real help rows and ARBs; added
  a drift check. Issue forms now explicitly require version, Windows, scale,
  language, interface mode and reproduction/workflow; PR checklist mirrors gates.

- Coverage identified backup preflight at 25%; three focused tests now cover its
  validation branches (100%). Three calendar tests cover both conversions,
  Nowruz/month ends, leap Esfand, invalid dates and localized time formatting
  (shared calendar helper: 98.4% in this focused run). Existing reminder policy
  (100%) and clipboard store (99.3%) did not need duplicate tests.

## Verification

- Flutter 3.44.8 / Dart 3.12.2, unchanged locked dependencies. Restored missing
  packages from default pub.dev archives with lockfile SHA-256 verification, then
  `flutter pub get --offline --enforce-lockfile`; `flutter gen-l10n` completed.
- One desktop `flutter test --no-pub --coverage` run: **552 passed, 7 existing
  Windows-only visual skips** (includes the new shortcut-documentation check).
  Only the six added pure-logic tests ran afterwards: **6 passed**. No second
  full-suite run. [Coverage snapshot](part4-coverage.json) lists all 42 measured
  non-generated desktop files below 60% plus four unmeasured files, which are not
  asserted to have 0% coverage. No coverage-percentage target was imposed on UI.
- Desktop analysis and focused analysis of the added test: no issues.
  `dart fix --dry-run`: nothing to fix. Localization parity and 18 guard tests
  passed; utility maps exactly match the remaining ARB generation inputs.
  Issue YAML/required fields, updated guide links and `git diff --check` passed.
- No intended visual change: no golden regeneration, tolerance edits or baseline
  deletions. Existing minimum/scaled-window regressions passed after rail cleanup.
  No shared source changed, so shared suites were not repeated.
- Windows executable/manual behavior, PowerShell hygiene/native smoke, installed
  app checks and Windows visual comparison were not run in this Linux session.
  No schema/archive format, version, native runner or workflow changes; no merge,
  release or tag. Part 5 remains unstarted and requires owner approval.
