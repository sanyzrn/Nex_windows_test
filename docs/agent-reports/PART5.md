# Part 5 — Track A completion

Base: `689ac2a`; branch `windows/0.23-agent`. Scope: A9, A11, A12, A4, then A6.

Plan: bundle both release histories and test language selection; fix owned numeric
labels and calendar selection without changing stored values; extend compact
review data across all requested flows; inspect installer identity/data retention;
run focused checks and one track regression, review Windows images, then format
non-generated Dart in a standalone commit. Open a draft PR; stop before Part 6.

## Changes

- Offline EN/FA release history in About/update controls: all 10 sections and 107
  bullets translated. Asset/error/locale-switch behavior covered by focused tests.
- Application counters, time tools, updater progress, monitor/scale and AI-action
  dates honor locale/calendar. User text, credentials, IDs, copied calculator
  values and ISO/Unix generator payloads retain their original values.
- Reminder dialogs carry the caller's calendar preference across routes. Solar
  date selection uses existing conversions with valid days/bounds and leap-month
  clamping; Gregorian selection keeps Material's date picker. UTC storage is unchanged.
- Added 76 compact scenes: 19 flows × EN/FA × light/dark, including all seven
  settings categories, provider configuration, four reader types, tagged library
  with reminder/file, local release history and Solar picker. Existing matrix names
  and tolerances remain; new sample media and metadata are deterministic.
- Installer static review: per-user install, stable AppId, AUMID on both shortcuts,
  quoted protocol forwarding, and no user-data deletion. Persian now appears by
  its native name in language selection. No installer behavior/identity changes.

## Verification

- Flutter 3.44.8 / Dart 3.12.2; enforced lockfiles unchanged. Final completed
  Linux suite: **640 passed, 7 existing Windows-only skips**. Six new behavior
  tests cover local-history parity/loading/error/locale changes, calendar route
  preference/leap selection and actual reader digits without altering content.
- All 76 compact scenes passed. Visual inspection then found a wrapped Solar
  year; field widths now reserve the full number at 100–200%. The strengthened
  200% leap test and four affected scenes passed afterwards. Unchanged suites
  were not repeated for this isolated width adjustment.
- Analysis clean; localization parity and all 18 guard tests passed. Updated
  documentation links and diff hygiene passed. Installer strings/registration
  were reviewed statically. Windows visual refresh and standalone formatting
  follow; their final evidence will be recorded below.

Real Windows installation/uninstall/reinstall with notes, Run-dialog protocol
activation, DPI/IME/Narrator and native delivery cannot be verified here.
No version, schema/archive format, native runner or workflow changes; no merge,
tag or release. Part 6 requires a new owner approval.
