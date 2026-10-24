# Windows 0.23 agent work — review summary

Working branch: `windows/0.23-agent`; base `2076ad4`. Release prepared as **0.23.0+17** after the owner authorized merge/publication for manual testing on 2026-10-21.
Implementation commits: `7173404`, `9cd6bdb`, `5c79990`, `d9e9211`, `9b0bd22`; Windows visual refreshes: `a4f487c`, `13d34a1`, `d0ea0d8`, `d8de9a3`.
A2 refresh run `39455265050` passed with no baseline changes.
A3 final refresh run `39498530568` passed; all 52 updated images were reviewed.

| Item | Status | Evidence / remaining work |
| --- | --- | --- |
| A1 translation audit | Implemented; local tests and Windows visual refresh passed | [Report](A1.md), 191 desktop tests, 16 checker tests, shared-package checks, 16 renders |
| A2 accessibility | Implemented; local tests and Windows visual refresh passed | [Report](A2.md), 205 desktop tests, 18 checker tests, shared-package checks, 16 focus renders; no Windows baseline changes |
| A3 minimum size/text scale | Implemented; local tests and Windows visual refresh passed | [Report](A3.md), 551 desktop tests including 336 layout cases and 10 scaled-control regressions; 52 Windows review additions; 44 before/after renders |
| A5, A7, A8, A10 | Completed in Part 4 | [Report](PART4.md); cleanup/docs/templates; 552 existing tests + 6 focused additions, analysis and guards passed |
| A4, A6, A9, A11, A12 | Completed in Part 5; Track A complete | [Report](PART5.md); offline history, digits/calendar, installer review, 76 compact Windows scenes, standalone formatting |
| B0–B3 | Implemented in Part 6; device limits remain | [Report](PART6.md), [34-item manual triage](B0.md), live Windows PR checks |
| B4–B7 | Implemented; full Windows CI passed; manual checks with owner | [Report](PART7.md), final PR checks and explicit device limits |
| B8 optional modules | Implemented; 0.24.0+18 release prepared | Four owner-selected modules; full Windows CI/native/installer/update checks passed; publication explicitly authorized; [report](B8.md) |

Source, tests, glossary, changelog and reports are committed together and pushed
after each completed part. The owner authorized merging Parts 1–7 and publishing 0.23.0 for manual testing; B8's four core modules were subsequently selected; see [B8](B8.md).
No private data, credentials, backup/schema changes or Android source changes.

Windows screenshots were reviewed. Parts 1–6 passed comparison/build/native
smoke/installer/update checks; the final Part 7 PR checks supply current automated
evidence. Real DPI/notification/Narrator, Android round trips and representative
hardware profiling remain open. Refresh success alone is not full sign-off.

Parts 1–6 have passed Windows CI. Part 7 was approved and implemented; its final checks and manual limitations are recorded in PART7.md. B8's four core modules were subsequently selected; see [B8](B8.md). Parts 1–7 are collected in [PR #9](https://github.com/sanyzrn/Nex_windows_test/pull/9);
Windows CI and manual limits are recorded in Part 5 and the PR checks.
Release automation publishes only after successful main-branch Windows CI for the exact release commit. Manual testing remains open and is owned by the user.

Final Part 7 source verification: [Windows run 39589605793](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39589605793), commit `4095fd9`: 856 desktop tests, shared UI 280, core 250, data 294 with 14 existing skips, AI 184, desktop without local inference 662; Release/native/installer/update checks passed.

Release preparation: version 0.23.0+17 declarations passed local consistency checks; Windows refresh [39608500545](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39608500545) passed and all eight changed About/history images were reviewed. Final main-branch CI and release URLs are recorded in PR #9.

## 0.26 candidate — 2026-10-22

Based on published main 91d3daa (0.25.0), preserving existing branches/history.
Caption close now hides with a real tray regardless of legacy false settings;
explicit Quit remains the drain/exit route. Shared Android menu helpers/theme
ported without desktop-density replacement; stock menus ratcheted. Four module
views improved; see UI_SYNC_0.26.md for exact scope and remaining Android gaps.
CI native lifecycle fixture deliberately uses the old false flag. Installed
protocol/AUMID assertions added to existing installer smoke rather than a second
redundant job. Windows-only manual/performance/phone work remains NOT TESTED and
assigned in MANUAL_TEST_0.26.md; no measurements invented. Signing/editor memo
makes recommendations only. No artifacts proven unnecessary were deleted.

Local localization parity and diff hygiene passed. Flutter validation locally
was blocked by automatic review over metadata-endpoint access; no bypass used.
Windows CI and visual review are pending at this commit. Release is not yet
claimed; append final actual evidence after the gates complete.

### 0.26 visual review and final validation handoff

[Windows visual refresh 39695846116](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39695846116)
passed 226 cases and generated `40ba6cb`. All 47 changed images reviewed;
[review and examples](REVIEW_0.26.md). No golden tolerance changes. Final module
layouts now include wide/compact Cycle dashboard, actionable PDF open state,
Vault category cards and Portrait metrics. Native smoke now reads actual process
AUMID and launches a real second normal instance to restore the original HWND;
installed protocol/shortcut identity are read after installation. Those new
native assertions still require the final Windows build/smoke result.

Earlier CI exposed a duplicate dropdownColor argument; fixed. Analysis on the
corrected and final layout sources passed. Local parity/tool checks passed (18
checks); local Flutter was not retried after the automatic-review block. The
obsolete root 0.13 checksum moved to docs/archive/SHA256SUMS_0.13.0, preserving
history while avoiding confusion with current release assets. No user data,
licenses, historical screenshots or existing work was removed.

Remaining owner/Windows-agent checks: physical IME, Hello, DPI/multiple monitors,
real notifications/sleep/clock cases, performance measurements and phone archive
round-trips, grouped in MANUAL_TEST_0.26.md. They remain unverified. Signing and
native-editor decisions remain with the owner. Final CI/publication evidence is
tracked in PR #12; a screenshot-refresh success alone never authorizes publication.

### 0.26 native activation correction

[Windows run 39697158980](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39697158980)
passed analysis, 900 desktop tests/golden comparisons, 285 shared UI tests,
250 core tests, 294 data tests (14 existing skips), and the Release build.
The actual second-normal-launch smoke failed to restore the hidden first HWND;
installer/remaining checks did not run, and no release was published.

Primary lookup now uses a stable window property instead of depending on the
Flutter/plugin-controlled caption; app-owned activation is routed before plugin
delegates. The real launcher regression deliberately renames the first caption
before hiding and launching again. PDF shortcut scope now receives focus on first
open, with Ctrl+F dispatched through real key events in the existing PDF test.
These corrections require the next Windows run; no native pass is inferred from
source inspection or from the earlier synthetic activation-message probe.

### 0.27.0 Phase 1 - baseline

Baseline on `main` at `c3139f2` (`0.27.0+21`; latest published tag `v0.26.0`,
no `v0.27.0`). On Windows 11 Home Single Language 10.0.26300 x64 with one
1920x1080 monitor at 125% scaling, all local CI checks passed: version
consistency (7 tests), localization parity plus 18 checker tests, UI hygiene,
analysis, 900 desktop tests, 285 shared UI tests, 250 core tests, 294 data
tests (14 existing skips), 184 AI tests, the Release build (106.7 s), the
installer build (19.1 s), and the native smoke (6.3 s) with an isolated
`APPDATA`. No files changed and no commit was made.

### 0.27.0 Phase 2 - remove temporary smoke tracing

Removed the 0.26.0 `SmokeTrace` helper and all four calls from
`native_bridge.cpp`, and `NEX_HIDE_DIAG` / `Get-NormalTrace` from
`tools/windows_smoke.ps1`. The normal-launch failure messages still distinguish
"first process exited" from "did not restore".

PowerShell syntax, Release build (16.7 s), analysis (24.6 s), version checks,
localization parity, UI hygiene, native private checks (5 s), and all 900
desktop tests (200.3 s) passed. The native smoke passed its probe,
single-instance, normal-window and second-launch stages, then failed the tray
compact-corner assertion (`left 40`, expected `1448`). The published 0.26.0
binary fails the same assertion, including with the unmodified HEAD smoke
script, so the failure predates this cleanup; no test or tolerance was changed.


### 0.27.0 Phase 5 - Android 2.1.15 parity audit (report only)

Compared Windows main `8dbaf4c5dbd1161f13636f6a82ce8d105bd61754` with
DbsNex `release/1.80.0` at `9590194f2425ed7eb3fa46ec61c1719cb98872a4`
(Android version 2.1.15). Added `PARITY_0.27.md` with area-by-area source
findings, desktop-fit/scope/risk assessments, all twelve absent optional
modules, and five candidates for owner selection: consistent batch pinning,
an existing-tag chooser for one note, Library date presets, three Cycle
Nex dialog shells, and consistent ordinary Library copy notices.

Scanned 138 desktop Dart files: 0 stock popup buttons, 1 intentional stock
popup item, 18 Nex-styled Material dropdowns, 13 SnackBar construction sites,
7 raw Cards, and 23 AlertDialogs. Reviewed two existing Windows module
baseline images, without regenerating images or claiming live visual parity.
Localization parity and its 18 checker tests passed here. All 50 report source
links and 182 inventory locations validated; final whitespace, append-only
summary integrity, and documentation-only scope checks passed here.

Flutter/Dart/PowerShell tests, analysis, live app comparison, native smoke,
build/installer, Hello, OS notifications and phone backup round-trips were
not run: this environment is Linux without Flutter, Dart or PowerShell.
The existing phase-2 tray-smoke finding remains as recorded above; this audit
does not resolve or reclassify it. No app, vendored package, format, version,
identity, test or golden baseline changed. No commit/push/PR/tag/release was
made. Owner selection is needed before implementing phase-6 candidates.


### 0.27.0 Phase 6 - P1 consistent bulk Pin / Unpin (review pending)

After the owner delegated the next-item choice, implemented P1 only. Mixed
selections now pin their unpinned notes without removing existing pins;
all-pinned selections unpin together, and the tooltip reflects the intent.
The existing five-note limit is preserved, with Persian/English feedback
when capacity is reached. Added four real UI/database regressions covering
mixed/all/none-pinned selections and the limit, across both languages,
themes and reading directions. Details: `PHASE6_P1_0.27.md`.

Using Flutter 3.44.8 / Dart 3.12.2 on Linux, dependency installation, analysis
(no issues), 15 targeted tests, localization parity and 18 checker tests
passed. New/generated localization changes were kept minimal. The Linux
SQLite loader needed a scratch-only link to the installed system library;
no repository workaround was introduced. Diff whitespace, documentation-only
summary append and bounded P1 scope checks passed. No existing test or golden
tolerance was changed, and no baseline was regenerated.

Windows UI hygiene (PowerShell), native/build/installer checks and Windows
visual review were not run. No shared package, data format, settings key,
identity or version change. Phase 5 is locally committed as `4b931e6`;
P1 remains uncommitted for review. Nothing was pushed/merged/published, in
accordance with the work order assigning push to the owner.


### 0.27.0 release preparation - owner authorized publication

The owner explicitly authorized pushing and publishing the completed work as
0.27.0, with the installer in repository Releases; all other planned changes
are deferred. This supersedes the original owner-only push/release workflow.
P1 is committed as `95288bb`; phase-5 audit documentation is `4b931e6`.

Bumped all declared versions to 0.27.0+21 / resource 0.27.0.21, updated both
changelogs and the README selection guide, and increased the release-history
assertion to 14 sections. The 19 selected version/localization/bulk-pin/menu
tests, localization parity, 18 checker tests and diff whitespace check passed
locally. The latest existing main CI (`39781563512`, commit `8dbaf4c`) passed
all Windows gates; the earlier physical-machine tray finding remains historical.

Requested Windows-runner baseline refresh for About/version/release-history
pixels. No local golden regeneration or tolerance changes. Publication remains
pending refreshed-image review and successful full Windows CI for the exact
release source, including native smoke, installer build and verified update
handoff. No physical-phone round-trip or manual Windows acceptance is claimed.


### 0.27.0 Windows visual review - release source

[Refresh run 39829751363](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39829751363)
passed all 226 golden/review cases on Windows with Flutter 3.44.8 and committed
`09bb1ab`. Reviewed all eight changed images: About in English/Persian and
light/dark changed only its version/build line; the four release-history
images show the new 0.27.0 notes with readable text and accessible Close.
No dimensions or tolerances changed; no other baseline files changed.

The owner authorized release of this completed scope as 0.27.0+21. Remaining
P2-P5 items and performance/phone work are deferred. Full main-branch Windows
CI, native/installer/update checks and automatic verified publication are
still pending at this documentation commit; no release success is claimed.


### 0.28 development — phase 6 P2 existing-tag picker

The owner authorized P2 while testing the published 0.27.0 release and assigned
new work to 0.28.0. On `windows/0.28-tag-picker`, note detail now offers a
searchable existing-tag dialog with colors, Persian/Arabic text folding,
already-attached exclusion, localized empty/error/retry states and panel hold.
The original typed-tag field remains available. Existing-tag attachment uses
IDs through the existing command, survives rename, is idempotent and rejects
deleted notes/tags. No schema, shared-package or settings-key changes.

Bumped development metadata to 0.28.0+22, with matching Windows resource and
installer declarations, paired unreleased changelogs and README guidance.
The combined selected suite passed 23 tests; after the final error/empty-state
case, all six new tests passed, covering English/Persian, light/dark and
380×520 at 200% text. Analyzer, localization parity, 18 checker tests, formatting
and diff checks passed. See [P2 validation](PHASE6_P2_0.28.md) for commands,
fixture corrections and limitations.

Windows CI/native checks, visual baseline refresh and installer publication
remain pending for the 0.28 release. No baseline was regenerated. Main and
published 0.27.0 remain unchanged; P3 date filters are the next planned item.


### 0.28 development — phase 6 P3 Library date presets

At the owner's request, added P3 to the same unmerged `windows/0.28-tag-picker`
branch after P2. Version remains 0.28.0+22. Library now offers Any time / Today /
Last 7 days / Last 30 days for creation dates, with local calendar-day bounds
converted to UTC. Date restrictions combine with query/type/tag/thread and
participate in empty-state handling, clear actions and pagination gating.
Entering Recently deleted clears dates and hides that control. No persistence,
worker, shared-package, settings-key or schema changes.

Four new tests passed in Asia/Tehran, including real SQLite boundary checks
and English/light + Persian/dark UI combinations, clearing and 380×520 at
200% text. Two boundary tests also passed under America/New_York, with explicit
UTC assertions for 23-hour and 25-hour days. The selected tag-picker, bulk-pin,
localization, version, menu and redesign regressions passed all 28 tests.
Thus 32 distinct selected tests passed, plus 18 localization checker tests.
Analyzer, localization parity, formatting, diff and append-only summary checks
passed. [P3 report](PHASE6_P3_0.28.md) records commands and test-helper corrections.

Both features remain on the development branch; main/0.27 release were not
changed. Windows CI, visual baseline refresh/review and 0.28 installer checks
are pending before release. No golden or tolerance was modified here.


### 0.28 development — phase 6 P4/P5 complete

Owner approved combining the two remaining small parity candidates on the
existing unmerged `windows/0.28-tag-picker` branch. Cycle period edit/delete
and typical-length settings now use `NexAlertDialog`, retaining existing
navigation, validation and results. Ordinary Library copy feedback from the
context menu, Ctrl+C and selection toolbar now uses `showNexNotice`: replacement,
four-second expiry and Close. Clipboard payloads, private clipboard and Undo
code are unchanged. Updated both unreleased changelogs; version stays 0.28.0+22.

Four Cycle dialog regressions passed at 380×520/200% text, covering both
languages/themes and glass on/off across cases, with real cancel/save outcomes.
Four copy regressions passed for both languages/themes and all three paths,
including real clipboard payloads, rapid repeats, expiry and dismissal. Existing
module, reported-bug/Undo and note-copy regressions also passed: 27 distinct
selected tests in total. Analyzer, localization parity, paired release-history
sections/bullets, formatting, diff/scope and append-only checks passed.
[P4/P5 report](PHASE6_P4_P5_0.28.md) records exact commands and fixture corrections.

P1–P5 are implemented: P1 in released 0.27, P2–P5 on this development branch.
Windows native/visual/installer validation and full Windows CI remain pending;
no baseline was regenerated. Backup round-trip kit, performance measurements
and final 0.28 release preparation remain. No merge or publication in this step.


### 0.28 development — phase 4 backup round-trip kit prepared

Owner authorized the next step. Added `apps/desktop/tools/backup_roundtrip.dart`,
Persian [round-trip instructions](BACKUP_ROUNDTRIP.md) and the small synthetic
[fixture kit](fixtures/backup-roundtrip-0.28.zip) on the same development branch.
No production backup/app/shared-package code, formats, dependencies, lockfiles,
settings keys, CI or version metadata changed. Version remains 0.28.0+22.

On Linux/Dart 3.12.2, generation through the production shared backup APIs and
restoration after deleting the source passed for both portable library and full
backup. Separate CLI verification also passed for both files. All eight tables
matched exactly after media-path normalization; all five media hashes matched.
Preserved: 6 notes, 7 tags/3 links, 3 reminders/2 recurring, 2 extra attachments,
1 thread/2 members and 1 synthetic Cycle period/day. Full-backup shared dark/fa/
solar appearance matched. Key and all data in the fixture are explicitly synthetic.
The ZIP includes expected rows/counts, results, recovery key, guide and checksums.
Kit SHA-256: bd0c9a059ea86ac3aae9ef6e1f58291c35561eb5452aad48f2880aa5235445e5.

Targeted Dart analyzer and format checks passed; archive format/PNG CRC/WAV,
ZIP integrity and every packaged checksum passed. Diff/scope and append-only
summary checks passed. The old SDK/cache had been removed. Standard dependency
fetch was rejected by automatic review because it tried a cloud metadata endpoint;
only explicitly named public pub.dev archives were fetched directly and matched
the lockfile SHA-256. No rejected metadata request was retried. The initial worker
CLI hit a Flutter-only dependency, so the final probe deliberately tests the actual
shared data APIs without the Flutter worker. An invalid initial synthetic PNG was
replaced and the final kit regenerated and validated; no product code was altered.

Not run: Windows worker/UI/native restore, actual Android import/export or phone
round-trip. The prepared kit completes the environment-independent portion of
phase 4; physical confirmation and Android return files remain with the owner.
Performance measurement and 0.28 Windows release validation remain pending.
No merge or release in this step.


### 0.28 release — reviewed Windows baseline correction

After the owner merged 0.28, main CI 39930646393 passed 881 tests and failed
41 review-image comparisons only. Analysis/version/UI hygiene passed; build and
release were skipped. The 0.27 baselines had not yet incorporated the 0.28 pixels.

Finalized dated EN/FA release notes and current-version README text; requested
Windows-only refresh on `windows/0.28-visual-baselines`. Refresh 39933957571
passed all 226 visual cases and committed b59c02f. Reviewed all 41 changed paths:
33 Library filter-bar views, four About and four release-history images. All
paths exactly match the failures; dimensions and tolerances are unchanged.
Six before/after contact sheets and two full screenshots confirmed expected
changes only, with readable Persian release notes and accessible Close.

Localization/release-history parity, diff and bounded-scope checks passed.
No app/shared-package/data code or behavior test was changed, skipped or loosened.
[CI report](CI_0.28.md) records the failed/refresh runs and review evidence.
The main comparison/build/native/installer/update gates and automatic publication
are pending at this report commit. No Windows/phone physical acceptance is claimed.


### Local draft — Tools/Library follow-up, 2026-10-24

Owner requested pausing modules, system Calculator, and Android Tools/Library
destinations; explicitly no push yet. See [local draft](DRAFT_TOOLS.md).
PDF/Cycle/Portrait and legacy module controls remain paused; three private Tools
entries reuse protected Windows storage/authentication. Added discoverable
Scheduled, password generator, Recurring and Library locations. Ported Android
Set aside with documented additive shared-package sync and bounded Chrome CSV
import. Recurring editing preserves existing metadata and offers date/time.

Standalone Dart analysis passed for desktop/affected tests, core and data;
36 data/migration/backup/commitment tests passed; localization and diff checks
passed. Flutter startup was auto-review blocked on cloud metadata access and
was not retried. Flutter/widget/Windows/visual/native/install checks not run.
No dependency/lockfile, identity, updater, baseline or version changes.
No commit/push/merge/CI dispatch/release. Remaining owner edits stay on this draft.
