# Repository cleanup validation — 2026-10-04

Current checks ran locally on Windows with Flutter 3.44.8 / Dart 3.12.2. These results supersede the earlier reported validation below.

| Check | Current observed result |
| --- | --- |
| Desktop `flutter analyze --no-pub` | PASS, no issues |
| Desktop `flutter test --no-pub --reporter expanded` | PASS, 59 tests including 8 golden tests / 10 image comparisons |
| Core `dart analyze --fatal-infos`; `dart test` | PASS, no issues; 198 tests |
| Data `dart analyze --fatal-infos`; `dart test` | PASS, no issues; 198 tests passed, 14 skipped |
| UI `flutter analyze --no-pub --fatal-infos`; `flutter test --no-pub` | PASS, no issues after compatibility cleanup; 188 tests. The 20 affected tag/swipe tests were rerun and passed |
| AI `flutter analyze --no-pub --fatal-infos`; `flutter test --no-pub` | PASS, no issues; 74 tests |
| Desktop `flutter pub get --enforce-lockfile` with documented mirror | PASS; dependency versions retained |
| AI-removal CI commands, run locally | PASS; remove optional `nex_ai`, resolve, analyze with no issues, 51 non-golden tests. Original manifest/lockfile restored and resolution rechecked |
| Windows `flutter build windows --release --no-pub` | PASS; Release runner built in 94.4 seconds after regenerating local caches |
| `tools/windows_smoke.ps1` | PASS; tray/hotkey/capture, both edges, display refresh, startup restoration, single-instance, rendered GUI and exit code 0 |
| `tools/build_installer.ps1` | PASS; Inno Setup 6.7.3, 13,810,715-byte installer; current SHA-256 is in root `SHA256SUMS` |

Total: **717 tests passed**, with 14 data-suite skips. Skips are not passing coverage. The full desktop suite was compared normally after refreshing and reviewing the changed Windows baselines; `--update-goldens` alone is not counted as a comparison pass.

The first golden run failed six tests against older baselines. Review exposed a real settings defect: wide mode controls squeezed the narrow-panel label into almost one character per line. Settings rows now place controls below text on narrow surfaces, with an assertion for label height/control placement. Reader fixtures now seed a fixed local timestamp instead of using the wall clock. Eight changed baseline images were reviewed for settings, both physical edges, calculator, both capture languages and both readers. CI pins the validated Flutter version to reduce SDK rendering drift.

The initial build attempts failed because local generated plugin directories could not be recreated as symlinks. `flutter clean` and dependency resolution regenerated the ephemeral Windows files. Flutter commands are subsequently run sequentially within the app.

The final desktop benchmark inserted 10,000 notes in **15,737 ms** (1.57 ms/note), loaded 50 timeline rows in **2 ms**, and searched English/Persian in **12 ms / 9 ms**. An earlier run under concurrent package testing took 48,909 ms to insert the same count; these measurements are machine/load dependent and do not measure desktop frame time.

Cleanup moved active documentation to `docs/`, archived the old task, removed identical duplicate transfer patches and the redundant summary, fixed PowerShell quoting/error propagation in the AI-removal CI step, and retained generated/runtime output exclusions. Installer checksums are computed from the actual local artifact; installers are not Git payloads. Historical patch application and upstream-base metadata were not revalidated against DbsNex.

Reminder unit tests use `FakeReminderScheduler`. Actual WinRT toast delivery after exit/reboot, mixed-DPI displays, microphone/clipboard hardware paths and clean-machine installation remain manual checks. No GitHub CI, publishing or push is claimed.

---

# Earlier reported validation — 2026-10-04 (Release 0.11.0+7)

This section is retained as prior handoff history. Its installer hash did not match the local file during cleanup; the repository-root `SHA256SUMS` now records the actual artifact. The prior reminder test description overstates native coverage: those tests exercise Dart reconciliation with a fake scheduler.

## Environment
- OS: Windows 11 x64 (Build 26100)
- Flutter: 3.44.8 / Dart 3.12.2
- MSVC: Visual Studio 2022 C++ Compiler (v143)
- Inno Setup: 6.4.1

## Summary of Test Results
- **`apps/desktop`**: 51/51 unit & integration tests PASS.
- **`packages/core`**: 198/198 tests PASS.
- **`packages/data`**: 198/198 tests PASS (14 sync tests skipped pending live Phase 2 backend).
- **`packages/ui`**: 188/188 tests PASS.
- **`packages/ai`**: 74/74 tests PASS.
- **Total Test Suite**: **709 tests PASS** across the repository.
- **Static Analysis**: `flutter analyze` reports 0 issues across all packages.
- **Windows Smoke Test (`windows_smoke.ps1`)**: PASS with exit code 0.
- **Installer Build (`build_installer.ps1`)**: PASS (`Nex-Windows-Setup-0.11.0-x64.exe`, SHA256 `3c1b6095543a3f2b5b965ab22911edb833bf5c09972b1050b7fadfc28450b8cb`).

## WP5 Measured Benchmark Performance
Run via `apps/desktop/test/large_library_benchmark_test.dart` over 10,000 notes inserted into a clean SQLite instance:
- **10,000 note insert time**: 14,984 ms total (1.50 ms per note).
- **First page of timeline (50 notes)**: **2 ms**.
- **English full-text search ("meeting")**: **14 ms** (200 matching notes returned).
- **Persian normalized search ("کتاب" with Arabic Kaf folding)**: **10 ms** (200 matching notes returned).

## WP3 & WP4 Desktop Feature Validations
1. **Durable Reminders**: `test/reminders_test.dart` (6/6 pass). Validates WinRT native toast scheduling and Dart state reconciliation across app restarts.
2. **Backup & Restore**: `test/backup_restore_test.dart` (2/2 pass). Validates atomic database replacement for `.nexbak` and password/key-derived `.nexfull`.
3. **Link Notes Reader**: `test/link_reader_test.dart` (5/5 pass). Validates 256 KB streaming cap, Open Graph meta extraction, HTML unescaping, and protocol whitelisting.
4. **Window Mode & 2-Pane**: `test/window_mode_wp4_test.dart` (3/3 pass). Validates responsive 2-pane view at >= 900px, divider width persistence, and single-pane fallback.
5. **Note Copy Rules**: `test/note_copy_test.dart` (4/4 pass). Validates Android text copy semantics and metadata preservation.

## Native Smoke Probe Output (`windows_smoke.ps1`)
```json
{
    "hotkey": true,
    "monitors": 1,
    "tray": true,
    "workers": 1,
    "hotkeyDelivered": true,
    "captureOpened": true,
    "startupToggle": true,
    "placements": [
        { "monitor": 0, "edge": "left", "edgeX": 0, "h": 680, "onLeft": true, "scale": 1.0, "w": 480, "x": 0, "y": 200, "edgeReveal": true },
        { "monitor": 0, "edge": "right", "edgeX": 1920, "h": 680, "onLeft": false, "scale": 1.0, "w": 480, "x": 1440, "y": 200, "edgeReveal": true }
    ],
    "displayChangeRefresh": true,
    "startupRestored": true,
    "singleInstance": true,
    "exitCode": 0,
    "shutdownWaitMs": 1939,
    "fullBundle": true,
    "normalGuiFirstFrame": true,
    "normalGuiAliveAfterCapture": true,
    "normalGuiExitCode": 0
}
```

---

# Historical Validation (Earlier Passes)

## Window mode, fixes and audit — 0.10.0+6 (Linux validation)

This pass was developed and checked on Linux x64 with Flutter 3.35.5 / Dart 3.9.2 (the historical 0.9.0 toolchain). No Windows build, installer or native run was produced here; those steps are the owner's to re-run on Windows.

| Check | Observed result |
| --- | --- |
| `dart format lib test` | PASS |
| `flutter gen-l10n` after ARB edits | PASS; both locales regenerated |
| `python tools/generate_utility_strings.py` | PASS; content identical to committed file |
| `flutter analyze --no-pub` | PASS; No issues found |
| `flutter test --no-pub` | **29 passed, 8 failed** — all 8 failures are golden image comparisons (`right_shell`, `left_shell`, `calculator_height`, `emoji_panel`, `more_panel`, `settings_light`, `capture_en`, `reader_fa`) |
| Golden failures vs unmodified source on the same machine | **Identical set of failures** on the pristine 00abf70 checkout (verified via `git stash`); diffs are 0.59–6.00% pixel-level font rasterization differences between Windows and Linux, which the README already documents as requiring Windows review. This is an environment limitation, not a regression. |
| New `test/window_shell_test.dart` | PASS; 5 tests: window shell navigation + tool directory/back, durable capture through the wide editor, mode switching with recorded native `setWindowMode`/`windowFrame` calls and frame persistence, settings round-trip of `windowMode`/`windowBounds`/`windowMaximized` (legacy JSON defaults to window mode), blur/edge-watch dormant in window mode |

The C++ runner changes (`SetWindowMode`, `WindowFrame`, `FocusWindow`, `WM_GETMINMAXINFO`, window-mode gating of `SetPassthrough`/`WM_APP_PLACEMENT`, first-frame show gating) compile-validated by review only — **no MSVC build was run in this environment**. Windows re-validation must cover: Release build, installer build, window resize/min/max/restore, frame persistence across restarts, monitor unplug (frame re-validation), tray/hotkey/second-instance routing in window mode, `--background` startup, and the `--native-smoke` probe with forced panel mode.

Fixed in this pass (with automated coverage where testable): clipboard Clear wipes pinned entries (now preserved; pinned text restored into the boot list), failed voice import keeps its recoverable WAV while success deletes it, `fresh()` no longer throws unhandled after a failed prior session write, hotkey collision surfaces a localized message, emoji/units empty states localized, dock auto-scrolls to the active tool, panel-shell geometry hooks cleared on dispose to prevent stale-closure calls after a mode switch.

## Standalone repository publication

For `sanyzrn/Nex_windows_test`, the final desktop source was copied from the validated handoff ZIP and accompanied by the four required Nex packages at the recorded base, including the two already-applied shared changes. The original upstream repositories are unchanged. The standalone checkout passed `flutter pub get`, `flutter analyze --no-pub` (no issues), and `flutter test --no-pub --reporter expanded` (**32 passed**, including 10 golden comparisons), using Flutter 3.35.5 / Dart 3.9.2 and the lockfile's documented mirror hosts. The source ZIP is in `releases/1.92.1.4`; `SHA256SUMS` records the original validated hashes of the ZIP and the separately distributed installer. Generated files, caches, toolchains and runtime user data are excluded from Git.

## Usability and media replacement — 1.92.1.4

The owner confirmed that Add image did nothing in the preview. This was an application defect, not a passing interaction or an automation-only failure. The translated flyout painted lower controls outside an ancestor Opacity's untransformed hit-test bounds. A mouse regression failed before the fix; with transforms above Opacity, translated Add image and checklist controls pass on both physical edges. Original spring constants and velocity effects remain unchanged.

Other repairs: persisted panel pin; owned interaction holds for editors/readers/pickers/menus/recording; no hover switching of held content; inline reader with explicit edit and collapsed metadata; softer desktop/dock shadows; active-pill paint order beneath icons; compact glyphs and consistent controls; separate image/audio/file pickers; cancellation without notes or success; visible media errors and pending-operation drain; WAV recording with a busy guard; actual playback state/replay handling. Windows playback also had a session-activation issue: a real imported WAV remained at position 0 with activation enabled. Disabling unsupported mobile session activation for the Windows player produced a real completed playback event at 2,000 ms.

Final automated validation with Flutter 3.35.5 / Dart 3.9.2:

| Check | Observed result |
| --- | --- |
| Formatting and `flutter analyze --no-pub` | PASS; no issues |
| `flutter test --no-pub --reporter expanded` | PASS; **32 tests, 0 skipped**, including **10 normal golden comparisons** |
| `flutter build windows --release --no-pub` | PASS; full x64 Release bundle |
| Isolated `--media-smoke` on that real Release executable | PASS; 2 imported notes, copied image decoded at **480×680**, valid WAV duration **2,000 ms**, actual processing state **completed**, position **2,000 ms** |
| Final Inno Setup build | PASS; `Nex-Windows-Setup-1.92.1.4-x64.exe`, **12,772,489 bytes** |
| Update of the existing per-user installation | PASS; English installation, exit **0**, all **37 payload SHA-256 hashes match** the final manifest |
| Final source ZIP | PASS; **91 files**, CRC validation, required layout, 10 golden images, 2 shared patches and compiled/cache exclusions |

Native media validation used supplied QA fixtures and its own temporary Nex database/media directory, which was removed after normal exit. It does not prove microphone recording, subjective audible output, every codec or native picker pointer input. Automated media-import classification uses a separate deliberately minimal WAV header and is not counted as playback validation.

The first capture golden comparison in this follow-up detected only 9/21 single-level antialias pixels during residual spring motion. Capture/reader goldens now wait 180 frames for the spring to settle. Baselines were visually reviewed and followed by normal comparisons; tolerances were not relaxed. Temporary pointer diagnostics were removed from source, and the installed diagnostics flag was removed. Existing notes/media/settings remain intact.

Windows UI observation of the installed final version: English capture controls rendered clearly; a genuine mouse click on the previously dead Add image button opened the native Windows Open dialog with the image extension filter and Nex title-bar icon. The visible host remained behind the chooser. Further automated chooser input was interrupted by detected user input and stale accessibility indexes; those steps are not reported as a successful UI file selection. Durable photo/audio import and playback passed independently in the actual native executable. Panel pin, cancel-without-success, typing/reading holds, menus and inline editor persistence have automated shell/database coverage. Live microphone recording, subjective sound quality, positive clipboard image/paste, mixed-DPI monitors and performance targets remain manual checks.

## Runtime correction — replacement installer 1.92.1.2

The first installer failed the owner's actual use. The earlier native-state and first-rendered-frame PASS entries below are historical probe results; they did **not** establish a visible, interactive panel. A release ticker threw `RenderBox was not laid out` while computing an ancestor transform before layout and stopped advancing. A separate early editor-focus error, hover-then-click toggle, native visibility/focus, icon creation, installer-language propagation and modal auto-hide defects were also repaired. Geometry is sampled post-frame, while the original spring constants remain unchanged.

Final replacement-source validation with the pinned SDK:

| Command | Result |
| --- | --- |
| `dart format` on changed Dart files | PASS |
| `flutter test --no-pub --reporter expanded` | PASS: **23 tests, 0 skipped**, including all **6 golden comparisons** |
| `flutter analyze --no-pub` | PASS: **No issues found** |
| `flutter build windows --release --no-pub` | PASS: full x64 Release bundle |
| `tools/build_installer.ps1` with Inno 6.7.3 and licensed VS x64 CRT files | PASS: replacement `Nex-Windows-Setup-1.92.1.2-x64.exe` |

New regression cases exercise startup before first layout, the real capture editor/database in the full shell, focus and typing, English installer locale applied once with later manual locale preserved, cancel/empty app selection, interactive tray opening/delayed hide, hover-switch followed by first/second click, and modal suppression of an already pending close/blur.

Actual installed-app UI observations used the Windows Computer Use skill: visible capture field and dock after spring opening; English settings after English installation; working first click on Settings; the modern Windows `IFileOpenDialog` with English title/filter and the Nex icon; Escape cancellation returned to the same settings panel with no added shortcut or success toast; saved shell state retained zero apps and `note,timeline,more`; Ctrl+Alt+N visibly selected the capture editor. Ordinary key input produced Persian text under the user's Persian keyboard layout. Literal-text injection and stale accessibility element indexes were unreliable in the automation helper, including in Notepad++; they are not counted as passing full-text automation. Persian/English editor persistence has full-shell/widget/database coverage; positive live image clipboard, long-text paste, mixed-DPI monitors and moving side-by-side parity still need manual review.

The obsolete modal-auto-hide build's hidden test process required forced cleanup; that is not reported as graceful picker shutdown coverage. Cancellation of the repaired picker was observed normally. Uninstall/clean-VM and shutdown while a dialog is opening were not rerun on the replacement. Original reference repository remained clean. Opt-in diagnostics markers and compiled output are excluded from the source ZIP; user notes/media/preferences are retained by the updater.

Additional live replacement checks: Escape hid the host, second launch restored capture, and the library showed the Persian character entered by the test after reopening. Two short character test notes remain in the library. Settings moved the host to x=0; reopening showed the dock on the left and the flyout inward. The setting was restored to the right, x=1440, on the same 1920×1080/100% monitor. This verifies physical placement/mirroring; it is not a new mouse-only edge-reveal or mixed-DPI test. The Nex icon was visibly present on the file dialog title bar.

The repaired process then exited normally through Alt+F4 after picker cancellation. The final replacement installer updated the existing per-user installation with `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LANG=english`; exit code **0**, a fresh `en|<installation timestamp>` marker, and **all 37 installed payload SHA-256 hashes matched** the build manifest. Installer size: **12,762,704 bytes**. No forced shutdown was required for this final update. The source ZIP was regenerated with CRC, required-layout and compiled/cache exclusion checks.

## Earlier source/installer validation (historical)

Nex base `4861feac41530c951cb9e637ff921c6472d7de58`; client `1.92.1`; Windows x64, one 1920×1080 monitor at 100% scaling. Flutter **3.35.5**, Dart **3.9.2**, isolated toolchain commit `ac4e799d237041cf905519190471f657b657155a`. Visual Studio/MSVC Windows Release build was available. No Android APK/device validation was performed.

The actual desktop command prefix was `C:\Users\zrn_s\OneDrive\Desktop\nex_windows\toolchain\flutter\bin\flutter.bat`; `dart` below was that SDK's `bin/cache/dart-sdk/bin/dart.exe`. Desktop working directory was `nex/apps/desktop`. Resolution used:

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
```

Default storage/pub hosts were unavailable in this environment; transient mirror DNS/file-lock download failures were retried. The delivered lockfile records the tested resolution.

## Final command outcomes

| Directory | Exact command after selecting the pinned SDK | Observed result |
| --- | --- | --- |
| `apps/desktop` | `flutter gen-l10n` | PASS; both locales generated |
| `apps/desktop` | `dart format lib test` | PASS; applied to final Dart source |
| `apps/desktop` | `flutter analyze --no-pub` | PASS; **No issues found** |
| `apps/desktop` | `flutter test --no-pub` | PASS; **16 tests, 0 skipped** |
| `apps/desktop` | `flutter test --no-pub test/golden_test.dart test/shell_regression_test.dart` | PASS; **8 tests, 0 skipped**, including 6 actual golden comparisons |
| `apps/desktop` | `flutter build windows --release --no-pub` | PASS; `build/windows/x64/runner/Release/nex_desktop.exe` built |
| `apps/desktop` | `./tools/windows_smoke.ps1 -Output C:/Users/zrn_s/OneDrive/Desktop/nex_windows/windows-smoke-final.json` | PASS; full-bundle native probe, second-instance check and normal GUI launch/capture/exit, exit code 0 |
| `packages/data` | `dart pub get`; `dart test` | PASS; **183 passed, 14 skipped by Nex's existing suite**; skipped cases are not coverage |
| `packages/data` | `dart analyze --fatal-infos` | PASS; No issues found; shared codec remains pure Dart |
| `packages/ui` | `flutter test` | PASS; **183 tests**, no skip count reported |
| `packages/ui` | `flutter analyze --no-pub --fatal-infos` | PASS; No issues found |
| Nex root | `make check` | **NOT RUN**: attempted before integration and again with patches; GNU `make` is not installed/on PATH. Package checks above are not claimed as the full root check. |
| Fresh detached validation clone at base SHA | `git apply --check` then `git apply`, separately for `01-shared-backup.patch`, then `02-shared-theme-presets.patch` | PASS; both commands in each step returned 0 |

Only required shared-module changes were patched. Package pub-get mirror/lock changes were restored and are not included. No remote pushes, branches for feature work, PRs, issues or comments were created. The canonical Right Panel clone's final status is clean.

## Original source ZIP verification (before installer follow-up)

The original archive was extracted into `C:/Users/zrn_s/OneDrive/Desktop/nex_windows/patch-validation`, a fresh detached clone of the exact base with the two patches applied in order. From its `apps/desktop`, the same pinned SDK and mirror environment ran `flutter pub get` (PASS), `flutter analyze --no-pub` (PASS, no issues), `flutter test --no-pub` (PASS, 16 tests, zero skips), and `flutter build windows --release --no-pub` (PASS, Release built in 80.8 seconds). All extracted desktop source bytes and the lockfile matched that archive after dependency resolution; all six patched package/client files matched the integration checkout. The ZIP CRC, required layout, two patches, six goldens and cache/compiled-output exclusions were checked successfully. The installer follow-up below adds packaging sources/documentation only; application code, lockfile and shared patches are unchanged. No Nex packages or SDK are vendored.

## Installer follow-up — requested after source delivery

`Nex-Windows-Setup-1.92.1-x64.exe` was compiled with Inno Setup **6.7.3**, using its official compiler download with a valid Pyrsys B.V. Authenticode signature. The Nex test installer itself is **unsigned**. The 12,739,765-byte executable includes all Release files and the x64 Microsoft.VC143.CRT redistributable DLLs from licensed Visual Studio directory `C:/Program Files/Microsoft Visual Studio/18/Community/VC/Redist/MSVC/14.44.35112/x64/Microsoft.VC143.CRT`. No Flutter, compiler or runtime download is required on the test machine.

Actual packaging command, from `apps/desktop`:

```powershell
./tools/build_installer.ps1 -ISCC 'C:/Users/zrn_s/OneDrive/Desktop/nex_windows/installer-toolchain/inno/ISCC.exe' -VCRuntime 'C:/Program Files/Microsoft Visual Studio/18/Community/VC/Redist/MSVC/14.44.35112/x64/Microsoft.VC143.CRT' -Output 'C:/Users/zrn_s/OneDrive/Desktop/nex_windows'
```

Observed: **PASS**, successful compiler exit, no compiler warnings. Persian/English messages compiled; the graphical installer pages were not visually inspected. Silent installation used `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER /LANG=farsi /TASKS="" /DIR="C:/Users/zrn_s/OneDrive/Desktop/nex_windows/installer-smoke/نکس آزمایشی"` with a log file. The initial test assumed a configurable shortcut folder, then used an ANSI-only COM shortcut reader; those assertions were corrected to the fixed Nex Start menu folder and actual shortcut execution. These were test-harness failures, not claimed passes.

Final observed results: installation exit **0**; all **37 installed payload files** match their SHA-256 staging manifest; Windows uninstall entry exists; Start menu shortcut launches the installed GUI from the Persian/space-containing path, renders a frame and exits through WM_CLOSE with **0**. `tools/windows_smoke.ps1 -Release <that installed path> -Output <workspace>/installer-smoke/installed-app-smoke.json` passed tray, actual hotkey/capture, both edges, display refresh, startup restoration, single instance and normal GUI launch/capture/exit. Uninstall launcher exit **0**; asynchronous child cleanup was awaited and all payload files, uninstall registration and shortcut disappeared. An untracked user file inside the install directory survived. User data outside the install directory is never targeted by the installer/uninstaller.

Only the workspace test installation was removed. Default per-user install location and optional desktop-shortcut UI are configured but were not separately installed/clicked; the tested destination was the isolated Persian path. No clean VM, other Windows version, graphical wizard review or certificate signing was performed. The executable is delivered separately at the owner's explicit request; the updated source ZIP includes reproducible installer sources and still excludes compiled output.

## What desktop tests cover

The shell tests cover under/critically damped spring behavior, settings serialization, boot/open/close, immediate hotkey capture selection and cancellation of delayed controller work; real nonzero flyout measurement with different heights and bounded anchor targets; right/left positions and transform origins under Persian RTL; short-window scrolling without overflow; deterministic UTC/New York/Tehran/Kolkata offsets, DST and previous/today/next-day boundaries.

Nex tests cover actual Persian typing through the capture widget into SQLite, closing the widget/draining/reopening the DB, ordered updates/revisions/UUIDv7/pending sync state, opening a DB made with Nex migrations/repositories, FTS parity with the same repository including Arabic/Persian letter limitations, tags/thread membership, tombstone/delete/undo, copied/deduplicated photo/file media, actual full-backup private-settings decryption, wrong-key rejection, restored library/media and matching hashes. The backup library is deliberately readable because this is Nex's format; this is not a claim that the whole archive is encrypted.

Six committed goldens: `right_shell.png`, `left_shell.png`, `emoji_panel.png`, `more_panel.png`, `settings_light.png`, `calculator_height.png`. Baselines were deliberately regenerated with `flutter test --no-pub --update-goldens`, then compared successfully without that option. Goldens run normally; no opt-in define or skipped visual tests. The actual Nex fonts and host Segoe UI Emoji were loaded. Settings/More/left-edge images were also visually inspected. Static snapshots and a code audit do not establish human-perceived motion equivalence by themselves.

Earlier validation failures were repaired and rerun: original Windows transform/libraries/duplicate UTF helper linkage defects; a WORD narrowing error in the smoke probe; new-test theme API naming and fake-async/isolate timing; analyzer infos. No failed or interrupted run is counted as a final pass.

## Windows smoke scope and results

`tools/windows_smoke.ps1` launches the built executable with `--native-smoke`, using a temporary library, actual native bridge, clipboard watcher, registry startup API, monitor placement and named mutex. It restores startup and cursor position and does not change clipboard contents. The emitted report is summarized below; booleans were observed, not inferred from source:

| Probe | Outcome |
| --- | --- |
| Complete runtime/plugin/data bundle members | PASS |
| Native tray icon created | PASS (`tray=true`) |
| Global shortcut registered; synthesized real shortcut received by Dart | PASS (`hotkey=true`, `hotkeyDelivered=true`) |
| Capture selected/opened by that delivery | PASS (`captureOpened=true`); usable rendered-field latency not measured |
| Left physical placement and FFI edge reveal | PASS: x=0, y=200, w=480, h=680, edgeX=0, scale=1.0 |
| Right physical placement and FFI edge reveal | PASS: x=1440, y=200, w=480, h=680, edgeX=1920, scale=1.0 |
| Posted display-change event reanchors and updates Dart placement | PASS (`displayChangeRefresh=true`); actual mixed-DPI/hot-plug hardware not exercised |
| Startup toggle and restoration | PASS (`startupToggle=true`, `startupRestored=true`) |
| Second instance returns without running its probe; primary remains alive | PASS (`singleInstance=true`) |
| Clipboard watcher active at diagnostics | PASS (one owned worker); positive clipboard content flow not exercised |
| Graceful exit with worker active | PASS: process exit 0; no timeout/crash observed |
| Normal GUI renders its first Flutter frame | PASS (`normalGuiFirstFrame=true`), visible app HWND detected |
| Normal GUI remains alive after capture and exits through WM_CLOSE | PASS (`normalGuiAliveAfterCapture=true`, `normalGuiExitCode=0`); capture routed by synthetic WM_HOTKEY |

The final probe's shutdown wait was 2025 ms, **including the intentional two-second hold for mutex testing**. That is not a measured teardown budget or usable-panel latency. The separate normal GUI launch checks a rendered frame, capture routing and clean close; actual registered key-combination delivery is checked in the native probe. Neither is a full interactive user session or human visual assessment.

The Release directory contained Flutter runtime, file selector/record/just-audio/SQLite plugin DLLs, `sqlite3.dll`, native-assets metadata and `data/` with `app.so`, `icudtl.dat`, all Flutter assets/fonts/notices. Compiled files are excluded from the source ZIP.

## Manual checklist — remaining checks are NOT RUN

These are reviewer instructions, not claimed results:

1. **NOT RUN — live interactive capture/clipboard:** open with the global hotkey, type both languages, Esc and reopen; copy text → one-click capture; copy an image → Ctrl+V/button; verify fresh clipboard state, full photo resolution, pins, timestamps and history. File/photo store and typing/closure have automated coverage, but this OS path needs a positive live check.
2. **NOT RUN — file drop and attachment launching:** drag a file/image from Explorer, verify Nex-owned copy survives source removal, then open in the system app. Automated file/media storage tests do not assert Explorer drop delivery or shell launching.
3. **NOT RUN — several monitors/mixed DPI/hot-plug:** switch monitor and both edges at 125/150/200%, disconnect the selected monitor, and check anchors/hit tolerance/flyout clamping after scaling changes. Only one physical monitor was available; short-window widget coverage passed.
4. **NOT RUN — picker and utility behavior:** open colour/app/folder picker, quit while each is opening/open, check no hang or late callback; test screenshot, media keys, timer alert, keep-awake, pinning, password/text/units utilities and app shortcuts, especially inaccessible network paths.
5. **NOT RUN — microphone/audio hardware:** record, stop, play/pause, switch output devices, deny microphone access and verify failed-import recovery. Native recording/playback DLL presence and compilation were checked; hardware behavior was not.
6. **NOT RUN — tray/Explorer restart and UI shortcut changes:** verify localized tray menu/checkmark, Explorer icon recreation, changing N/Q/Space, collision reporting and restoring normal focus. Tray creation and N delivery passed the native probe.
7. **NOT RUN — moving side-by-side shell comparison:** compare original Right Panel liquid silhouette, active pill, velocity squash, stagger, hover/press and drag feedback on both edges. Source parameters/goldens were reviewed, but no human motion judgment is claimed.

## Performance

- Warm global hotkey → usable rendered field under 150 ms: **not measured**. Native delivery/open selection was verified; its polling time is not a usability measurement.
- Smooth desktop timeline with 10,000 notes: **not measured**. Paging/lazy rendering is implemented. Existing Nex data-suite performance assertions passed, which does not prove desktop frame-time performance.

Reminders/toasts, assistant actions, vault, desktop backup restore UI, sync and Windows OCR were not implemented and therefore have no passing feature claims.
