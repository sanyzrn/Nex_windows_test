# Desktop usability phase — 2026-10-14

This phase continues the completed window/panel redesign. Version remains `0.12.0+8`; the app's database schema and shared Android packages were not changed in this phase.

## Changes

- Ctrl+V inserts at the caret or replaces the selected range in the current capture, in both layouts. It no longer starts a new window-mode note. Persian text, reversed selections and image-only clipboards are covered. A clipboard read that finishes after starting another note is discarded. Clipboard failures appear through the existing error state. The separate Paste text action still creates a fresh capture and recognises bare URLs.
- Ctrl+N drains the previous capture and starts a new one. Ctrl+Shift+N selects checklist capture.
- Ctrl+K note results open the selected note. Capture, library, tools and settings routes respect the active window/panel mode. The New note action starts a fresh capture. Search responses carry a generation token: clearing or replacing a query rejects older responses. Selecting text inside the query does not discard its results.
- Library typing waits 150 ms before searching, with immediate invalidation of older requests. Superseded searches stop before additional tag/thread queries, and store access no longer depends on a disposed widget context after an await. Capturing text remains immediate.
- ThemeData and LiquidPalette are cached together and rebuilt when theme, preset or language changes. Layout, clipboard and other controller notifications reuse them.
- Keep Awake changes its displayed state only after Windows acknowledges the request. Repeated pending clicks are ignored, the window tool shows progress, and failures preserve the prior state with a translated message. The native bridge checks the return value specified in [Microsoft's SetThreadExecutionState documentation](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate).
- Reminder reconciliation now queries with its own clock and includes missed one-off reminders from the preceding 48 hours. Previously the shared future-only query excluded all overdue one-offs and ignored the test clock. Daily/weekly schedules, delete/clear and overdue deduplication are tested. **The reconciliation engine is still not connected to application startup or note mutations; this phase does not claim working end-to-end Windows reminder notifications.**
- Installer packaging obtains its output filename from `nex.iss`, fixing the stale hardcoded `0.11.0` filename. CI installs dependencies before its no-pub version test. Its package-host guard runs in a separate script so it does not match its own inline pattern. Screenshot artifacts now point to the 38 baselines compared by the suite, rather than an old design folder. The SDK comment now accurately distinguishes the desktop SDK from upstream Android.

## Validation

- Full desktop suite: **135 tests passed**, including ordinary golden comparisons and the 10,000-note benchmark (`apps/desktop/build/usability-tests-final.log`). No golden baselines were changed for this phase.
- After the final query-selection refinement, the 14 focused regression/benchmark tests passed again (`usability-regression-final.log`).
- Desktop analysis: no issues (`usability-analysis-final.log`).
- UI hygiene and whitespace checks passed. Non-generated desktop Dart files remain at or below 500 lines.
- Package-host guard passed on the real repository and clean temporary fixtures; injected workflow host overrides, pubspec mirrors and README host assignments were correctly rejected. GitHub Actions itself was not run remotely.

The 10,000-note fixture measured a 3 ms first page, 27 ms English search and 18 ms Persian search; insertion took 67,599 ms. These are single debug-test observations while the suite was running concurrently, not p95 measurements or a claim that storage is faster than the previous phase.

The final focused getter microbenchmark measured 199.15 microseconds per forced theme rebuild over 1,000 alternating light/dark iterations and 0.21 microseconds per cached theme+palette read over 100,000 iterations. Identity assertions confirm reuse. This measures the getter path only, not application frame time or native GPU performance.

## Installer

- Root file: `Nex-Windows-Setup-0.12.0-Usability-x64.exe`.
- Version: `0.12.0+8`; x64; **13,830,579 bytes**.
- SHA-256: `a9e36b90ed5295c2c1a01e7e724112401870a366f3a5af4e42fcebda93286d6f`.
- Fresh snapshot dependency resolution with `--enforce-lockfile`, Windows Release compilation and the repaired `tools/build_installer.ps1` all passed. Final app/native/installer source hashes matched the compiled source snapshot, and the root executable matched the compiler output.
- Build tools: Flutter 3.44.8 / Dart 3.12.2, Visual Studio 18, Inno Setup 6.7.3, bundled x64 VC145 CRT. MSBuild emitted MSB8029 warnings about the temporary build path; the build completed successfully.
- Logs: `apps/desktop/build/usability-release-final.log`, `usability-pub-get.log`, `usability-installer.log`; payload contents and hashes are recorded in `build/installer/payload-manifest.json` under the desktop app.

Close the running Nex instance before installing. The old audit/redesign executables remain in the root for reference; the Usability executable above is the current result.

## Remaining verification

The owner's installed Nex process was left running. Installer launch/upgrade, native hotkey/tray smoke, actual clipboard integration, actual Keep Awake behaviour, Narrator and clean-VM installation were not run. Native Keep Awake success/failure handling was checked through controlled host responses and compiled into the Windows runner. Windows Release was built from an isolated source snapshot because the existing local CMake cache references a different checkout.
