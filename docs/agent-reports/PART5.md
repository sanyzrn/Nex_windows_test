# Part 5 — Track A completion

Base: `689ac2a`; branch `windows/0.23-agent`. Covers A9, A11, A12, A4 and A6.

## Changes

- Bundled complete offline EN/FA release history in About/update controls: all
  10 sections and 107 bullets translated; locale changes and loading errors handled.
- Localized application counters, attachment badges, time tools, update progress
  and AI-action dates. Reminder dialogs retain the selected calendar across routes;
  Solar selection validates bounds and leap-month days. Stored UTC values, user
  text, credentials, IDs and copied/generated wire values remain unchanged.
- Added 76 compact Windows scenes (19 flows × EN/FA × light/dark), covering every
  settings category, provider setup, four reader types, tagged/reminder/file data,
  local release history and Solar picker. Reviewed images exposed narrow Solar
  year and About version fields; both now preserve whole words/numbers.
- Installer static review confirmed per-user install, stable AppId, AUMID on both
  shortcuts, quoted protocol forwarding and retained user data. Persian language
  selection now uses its native name. No installer behavior/identity change.
- A6: 424 non-generated tracked Dart files formatted; 54 changed. Their normalized
  ASTs match the source before formatting. Formatting is a standalone commit.
- Corrected an existing About build-label drift (15) to match the unchanged
  release 0.22.0+16; seven version-consistency checks now cover display components.

## Verification

- Flutter 3.44.8 / Dart 3.12.2; tracked lockfiles unchanged. Desktop regression:
  **640 passed, 7 existing Windows-only skips**. After the final fixture/shared
  badge refinement, affected checks: **83 passed** (76 compact + 7 behavior).
  Shared UI: **280 passed**, analysis clean. Four focused About checks also passed.
- Solar year readability at 200% and four affected scenes passed. Final desktop
  analysis, localization parity, 18 checker tests and diff hygiene passed.
  Unchanged full suites were not repeated for isolated layout/fixture refinements.
- Windows refresh [39552041554](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39552041554)
  passed: 76 new and 15 affected PNGs (`2a0b494`), all visually reviewed. A shared
  immutable photo fixture avoids Windows mapped-file deletion during temporary
  store cleanup; assertions and comparison tolerances remain intact.
- About layout refresh [39553244365](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39553244365)
  passed; eight affected About/history images reviewed (`2587ef6`). Final build-label
  refresh [39553886246](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39553886246)
  passed; all four changed About images reviewed (`0136023`).
- Standalone formatting commit: `8720413`. Full Windows comparison/build/native
  CI is pending the Track A draft PR below.

Manual installed-app install/uninstall/reinstall with retained notes, Run-dialog
protocol activation, physical DPI/IME/Narrator and real Android round-trips remain
open. Automated refresh success alone does not establish these behaviors.
No version, data schema/archive format, native runner or workflow logic changes;
no merge, tag or release. Stop before Part 6 pending owner approval.
