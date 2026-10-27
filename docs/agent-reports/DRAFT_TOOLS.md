# Local tools and Library draft — 2026-10-24

Owner requested these edits together with pausing the optional modules, and
explicitly said **do not push yet**. Local branch: `windows/pause-modules`,
base `accbcad`. No version bump, commit, push, merge, CI dispatch or release.

- PDF, Cycle and Writing portrait remain unavailable. The old optional module
  switches/shelf remain hidden. Saved module flags and data are preserved.
- The owner's subsequent screenshot request exposes private passwords, bank
  cards and saved messages as three regular Tools destinations. These use the
  existing Windows encrypted store, Hello gate, session locking and excluded
  private clipboard. They do not enable the old optional-module switch.
- Windows Calculator is a native action (`calc.exe`) from dock, More, quick
  tools and the window directory. The panel QA fixture sweeps over Timer instead
  of an external calculator; its focus/visibility assertions are unchanged.
- Tools now exposes Scheduled, password generation and Recurring. These already
  had implementations. Recurring now loads after inherited scope initialization,
  offers a first due date/time and preserves imported history, cost, attachments,
  pause state and timing metadata when editing.
- Private password CSV import uses Android's parser, existing secure bulk import,
  deduplication/capacity handling and generic results without secret exception text.
  File size is bounded; authentication is checked after the native picker.
- Library has four destinations matching the supplied screenshot: Set aside,
  Tags, Threads and Trash. Existing tag/thread/trash features are reused.
  Set aside works from a note's context menu or a selection, has Undo and timed
  return choices (18:00 evening, 08:00 tomorrow/next week, custom date or manual).
  Aside notes stay searchable and retain reminders. Home previews exclude them.

## Android sync scope

Read-only reference: `sanyzrn/DbsNex` main **6a653a3620c18e68af37fdf3bcce3c7d78ae052a**
(app 2.2.2). The user explicitly requested the Android functionality.

- `packages/core/lib/models/note.dart` and
  `packages/data/lib/repositories/note_repository.dart` are exact copies of that
  reference; their entire source diff is the Set aside feature.
- `packages/data/lib/schema/database.dart` syncs only the two additive, local-only
  `set_aside_at`/`set_aside_until` columns, including table rebuild preservation.
  Android's unrelated removal of the newer-library guard was deliberately excluded.
- Copied Android's existing seven Set aside repository tests and password CSV
  parser. No dependency, identity, protocol or updater changes. Backup formats
  and version stamps are unchanged; the new columns follow Android's local-only
  policy. This is a documented partial shared-package sync, not a package sweep.
- Tools/Library arrangement, labels and return-time semantics follow Android;
  desktop hosts use existing responsive UI, root-dialog scopes and panel holds.

## Verification actually performed

- Standalone Dart 3.12.2 analysis of all desktop `lib` and the affected test files:
  **passed, no issues**. Dart format and localization parity: passed.
- Existing backup archive, migration and commitment repository tests plus Android
  Set aside tests: **36 passed**. Initial test loading failed because this Linux
  host lacked `libsqlite3.so`; a scratch-only symlink to its installed `.so.0`
  supplied the loader name. No repository runtime workaround.
- Added targeted Flutter regressions for all Calculator launch paths and preserving
  Recurring metadata. Those and the updated module-pause regression were analyzed,
  **not executed**. Other Flutter/widget/golden tests also **not executed**.
- Flutter tool startup was rejected by automatic approval review for attempting
  cloud instance metadata access. It was not retried. Standalone Dart analysis
  and pure data tests used explicit public pub.dev archives, validated against
  lockfile SHA-256, and local package maps; no dependency or lockfile changes.
- Windows Calculator launch, Hello/clipboard/native file picker behavior, UI layout,
  visual comparison, Windows CI, build and installer: **not run** in this Linux
  environment. Existing Recurring notification transport was not extended or
  certified as Android parity in this UI/accessibility change.

Before publication: combine the owner's remaining edits, run required Windows
checks and refresh/review changed Tools, Settings and Library baselines on the
Windows runner. Do not regenerate baselines locally or change tolerances.


## 0.30.0 release follow-up — owner authorization

The owner subsequently authorized UI polish, push and publication as 0.30.0.
The earlier no-push instruction is superseded. Version is 0.30.0+23.
Desktop buttons share 12px corners/44px minimums while keeping theme contrast
colors. The monitor selector now has a filled bordered field and monitor icon;
palette, language, hotkey, tool-placement, thread and clock selectors use the
same controlled field with keyboard navigation, focus treatment and bounded menu.
Updated paired release history, section count, README and Windows metadata.
Four Windows review captures cover the monitor menu and Library locations in
English/light and Persian/dark at 200% text. Baselines must come from Windows.
Standalone Dart analysis and localization parity pass; final Windows visual,
behavior, native, installer and release evidence will be appended after execution.

### Windows visual review and main validation handoff

Windows refresh [40114222891](https://github.com/sanyzrn/Nex_windows_test/actions/runs/40114222891)
passed 230 visual tests and produced `5df0fcb`: 147 PNG changes, including four
new monitor/Library captures. Reviewed all 147 via nineteen before/after contact
sheets, plus the new full-size captures and English/light + Persian/dark Tools.
All existing image dimensions stayed unchanged. Expected changes: common button
corners/heights, framed dropdowns, release metadata, hidden legacy modules,
private/everyday Tools cards, CSV import entry and Library location affordance.

The review refined the odd last Tools card to fill its row like Android.
Final refresh [40115042065](https://github.com/sanyzrn/Nex_windows_test/actions/runs/40115042065)
passed 230 tests, producing `aba1cc7`; only the two wide Tools PNGs changed, and
both were reviewed at full size. All four new captures and final images retain
readable EN/FA labels and controls; small/200% views scroll rather than overflow.
No comparator/test tolerance changes and no local baseline regeneration.

The existing window navigation regression now finds Emoji via the visible Tools
search before opening/after returning, since new shelves move utility groups
below the initial lazy viewport. Navigation and presence assertions remain.
Standalone analysis of this test passed; its execution is left to main CI.

The exact final main commit must pass full behavior/golden comparison, shared
packages, Windows Release/native smoke, installer and verified-update checks.
Automatic publication is pending those gates at this documentation commit.
Physical monitor placement, Hello and owner-device acceptance remain unverified.

### Full-suite navigation fixture correction

Main run 40115733045 passed 925 desktop tests and failed three navigation
expectations, with no golden differences. The EN/FA keyboard walks now include
the added Library locations button between search and layout controls. The Emoji
navigation assertion targets its TextButton, excluding the identical text in
the active search editor. All original navigation and bidirectional focus
assertions remain. Standalone analysis passed; full CI is rerun before release.
