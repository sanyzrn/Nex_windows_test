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
