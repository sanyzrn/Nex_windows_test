# Panel transition and hover repair — 2026-10-14

## Behaviour

The native host hides before changing its style or bounds. After Flutter lays out the new shell, the bridge requests a new engine frame and reveals only the acknowledged surface generation. Startup and transitions share one pending frame callback. A stale callback cannot reveal another mode. An offscreen warm-up frame handles transitions while the hidden Windows host has suspended vsync.

Mode requests execute in order. Returning to the panel clears the previous flyout, geometry, drag state, hover state and springs. Delayed reveal/hide work belonging to the old surface is cancelled. Panel reveal retains the tool-window style rather than creating a taskbar window.

Hover opens the first dock panel without a preliminary click. Pinning the panel or focusing a text field no longer disables switching tools. Moving within a tool retries a previously blocked hover after an interaction ends. Readers, pickers and other held interactions still protect their view, and action/launcher tiles require a click. The first click after a hover switch keeps the newly opened panel visible.

The auto-close deadline no longer restarts on every movement outside the panel. Delayed focus, flyout entrance and drag-release timers are cancelled when their owners disappear.

## Verification

- Full desktop suite: **140 tests passed**, including unchanged golden comparisons (`apps/desktop/build/panel-fix-tests-final.log`).
- Desktop analysis: no issues (`panel-fix-analysis-final.log`). UI hygiene, package-host and whitespace checks passed. Non-generated desktop Dart files remain at or below 500 lines; transition logic and shell overlays were extracted into cohesive part files.
- Windows Release and Inno Setup compilation passed. Final app and native source hashes matched the compiled snapshot.
- **Actual Release runner test passed**, exit code 0, three complete window → panel → window cycles: right, left, right. It moved the Windows cursor across capture, library, clipboard and calculator; tested focus and pinning; checked that the old delayed close did not hide the returning window. No Flutter errors were recorded.
- After each switch, the panel was hidden until requested, the acknowledged frame was ready, and both the host client and Flutter child measured **480×680**. Revealing the panel changed native visibility to true. Returning window client/child dimensions also matched.

The native report is `apps/desktop/build/panel-native-probe/result.json`. The diagnostic `--panel-smoke <report-path>` uses a separate process and temporary database, avoids saved settings and edge polling, restores the cursor, and exits. The existing installed Nex process (PID 17792) remained running. Its hotkey was already registered; hotkey delivery was not a claim of this probe.

Actual testing used one monitor at the machine's current scale. Additional DPI/monitor combinations and installation/upgrade remain untested. This probe verifies mode and mouse behaviour; it is not an exhaustive OS integration test. The reminder wiring limitation recorded in the previous usability report remains.

## Installer

Current root installer: `Nex-Windows-Setup-0.12.0-PanelFix-x64.exe`, version `0.12.0+8`, **13,838,185 bytes**.

SHA-256: `da8c4ecd47ac51fe4ac3bf6081e534a6cd3af87a1f55c1be75221ffa2b2fccb7`.

Close the installed Nex through Exit in its tray menu before running this installer. Previous root executables are retained; use the PanelFix build for these repairs.
