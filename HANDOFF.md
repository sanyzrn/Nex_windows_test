# Agent handoff: build the Windows home of Nex

## Product goal and current stage

This repository is the working project for **Nex for Windows**. The intended product is the Windows counterpart of the Nex Android application: the same local-first notes, capture, library, search, tags/threads and compatible data, presented through a fast desktop interface. It must become an everyday Windows Nex application. The interface is now **two modes over one app**: a full desktop window (the main mode since 0.10.0) and the original edge panel (optional). The panel is no longer the whole desktop interface by itself.

**Windows version: 0.10.0+6, public release v0.10.0.** Windows has its own pre-1.0 version sequence. Android's 1.92.1 identifies the upstream reference only; never reuse it as the Windows product version. Windows is still a preview and is not ready for a 1.0 claim. Preserve an independent Windows version until the owner explicitly approves readiness.

## Current SDK policy

The owner has Flutter **3.44.8 / Dart 3.12.2** installed on Windows. Use that system SDK; project requirements remain: minimum Flutter **3.35.0**, minimum Dart **3.9.0**, with no upper SDK bounds. The exact `.fvmrc` pin was removed. Do not download an older SDK or downgrade system Flutter to reproduce the historical toolchain. Existing 0.9.0 installer/test evidence below was produced with Flutter 3.35.5 / Dart 3.9.2; it does not certify a new build on the current SDK. Keep that history distinct from current validation. SDK-policy update check: `flutter pub get` succeeded and `flutter analyze --no-pub` reported no issues on the installed Flutter 3.44.8 / Dart 3.12.2. No new installer or runtime validation was produced by this configuration-only change.

## Where the implementation lives

- `apps/desktop`: the actual Windows Flutter application, native runner/bridge, translations, assets, tests and installer sources.
- `packages/core`, `data`, `ui`, `ai`: the required Nex packages included in this standalone repository. The shared backup/theme changes are already applied. Do not reapply `patches` here.
- Root `README.md`: clone/build/download instructions. `TEST_RESULTS.md`: actual validation and historical failures; historical PASS entries are not proof of current usability.
- GitHub Release: downloadable installer, source snapshot and SHA-256 checksums for the corresponding version and commit.

The original extracted Flutter Right Panel is the panel-mode shell implementation base. The original `raminturne/right-panel` repository is a read-only visual/behavioural reference for edge reveal, liquid motion, springs, hover magnification, active pill, flyout, tray and shortcuts. Nex owns domain behaviour and data. Do not replace Nex repositories/schema with a second note store or copy Android domain logic into a competing implementation. Preserve attribution and the established fonts/tokens. Do not push to either upstream repository.

## What the next agent should achieve

Continue towards a dependable Windows Nex app, prioritising the owner's actual usage reports over passing probes. The 0.9.0 repairs (invisible panel, dead clicks, unwanted auto-hide, confusing cancel/success, poor shadows) are preserved and covered by tests; prevent regressions. Since 0.10.0 the desktop window is the main mode; the edge panel is optional and switchable at runtime — both must keep sharing the same store, capture session and settings, and the window's frame must persist. Keep the persisted panel pin separate from a note's pin. Reading, typing, file selection, menus and recording must keep the panel usable. Notes must save immediately and survive closing/reopening and normal exit.

Before treating the app as 1.0-ready, re-run the full Windows validation of microphone recording, positive chooser/clipboard imports, repeated use and shutdown, multi-monitor/mixed-DPI/hot-plug (now including the window frame restore paths), usable-panel latency and a large library. Windows reminders/toasts, backup restore UI and other Android parity gaps remain explicit work; assistant/Vault and sync/OCR/on-device AI are not silently complete. Expand scope only when requested or necessary for the intended Windows Nex experience. Preserve the original liquid/spring shell (panel mode) while improving usability with Nex design tokens.

## Synchronisation and release discipline

The source on `main`, Windows version strings, About screen, executable version resources, installer version/name and latest GitHub Release must agree. Build the full Windows runtime from that source and keep the same installer AppId/data paths so updates retain existing notes/media/settings. Publish the built installer with the matching source snapshot/checksums and point the release tag at the source commit. Never rename an old installer and call it a new build. Never report unrun hardware checks as passed. Preserve the earlier test results as history.

## Existing implementation and evidence

# Nex Windows — 2026-10-02 (0.10.0 window mode)

The 0.10.0 pass added the desktop window as the main interface while keeping the edge panel as an optional mode. `windowMode`/`windowBounds`/`windowMaximized` persist in the shell settings JSON with legacy-safe defaults. `lib/ui/window_shell.dart` renders the navigation rail and sections; the views were made adaptive (flyout keeps its historical heights, the window fills). The native bridge gained `setWindowMode`/`windowFrame`/`focusWindow`: `WS_OVERLAPPEDWINDOW` restyle, opaque composition, minimum track size, saved-frame validation against current monitors, `WM_GETMINMAXINFO` sizing, and display-change re-anchoring gated to panel mode. `--native-smoke` forces panel mode because it validates edge behaviour. Repairs beyond the mode work: clipboard Clear keeps pinned entries and pinned text is restored at boot; failed voice import keeps the recoverable WAV and success deletes it; `fresh()` no longer crashes on a previously failed session write; hotkey collision shows a localized message; emoji/units empty-state strings are localized; the dock auto-scrolls to the active tool; panel-shell geometry hooks are cleared on dispose. Validation this pass ran on Linux (Flutter 3.35.5): analyzer clean, 29 tests passing including five new window-shell tests; the ten golden comparisons fail with small pixel diffs on Linux even on the unmodified source (Windows font rasterization) and must be re-verified on Windows together with the Release build, installer and native behaviours. Details in `TEST_RESULTS.md`.

# Nex Windows — 2026-10-02

Nex base: **4861feac41530c951cb9e637ff921c6472d7de58**, Android **1.92.1**. Historical 0.9.0 build toolchain: Flutter **3.35.5 / Dart 3.9.2**, Windows x64. The owner confirmed this workspace is the extracted `right_panel_flutter.zip`; it is the implementation base. Canonical Right Panel was inspected read-only at **90dcdbde8e33816f08b681c65cd341aa796f81e4** and remains unmodified. MIT attribution is included.

The latest desktop is **0.9.0+5**, with separate unsigned installer **Nex-Windows-Setup-0.9.0-x64.exe**. It adds a persisted panel pin, protects typing/reading/pickers/menus/recording from auto-hide, replaces note dialogs with an inline reader/edit flow, and improves glyphs, spacing, fills and shadows. The active pill paints beneath its icon. Separate image/audio/file choosers show errors and report cancellation honestly. Unclickable lower controls were caused by Opacity bounds preceding the flyout translation; transformed hit testing now works on both physical edges. Windows audio session activation is disabled for the desktop player; a copied WAV actually played to completion.

Nex owns notes, schema/migrations, UUIDv7, revisions/tombstones/FTS, capture, tags/threads and the backup codec. One serial database isolate handles operations; text saves on every change and drains before exit. The app includes text/checklist/image/file/audio capture, lazy timeline, search/filtering, pin/delete/undo/trash, inline detail/edit, tags/threads, Persian RTL/fonts/calendar, shared themes and full-backup export. AI is a removable stub with zero desktop `nex_ai` imports. Vault is absent. Retained utility snippets, clipboard previews and shell preferences are separate from Nex notes.

The mandatory shell repairs preserve original spring constants: measured/clamped flyout height, physical-edge mirroring independent of RTL, viewport-responsive dock, correct clock offsets, owned/cancellable native workers and dialogs, platform-thread events, safe bridge/messenger destruction and cancelled Dart delays. Release packaging includes every Flutter/plugin/runtime asset.

Build this standalone repository directly: its four required Nex packages and shared changes are already included. The two files in `patches` are historical integration patches for a separate clean upstream Nex checkout at the recorded base; do not apply them to this repository. Those patches were previously checked in a fresh detached upstream checkout. Run/build instructions are in `apps/desktop/README.md`.

Final validation: analyzer clean; **32 tests, 10 normal golden comparisons**, full Release and installer built; real Windows codec/import check decoded a 480×680 image and played a 2,000 ms WAV to completion; installed update exit 0 and all 37 payload hashes match. A live click opened the image chooser. Source ZIP has CRC/layout/cache/binary exclusion checks. Exact outcomes and historical failed probes are in `TEST_RESULTS.md`.

Limits: microphone hardware, positive UI file selection/clipboard flows, mixed DPI/hot-plug, picker shutdown races, moving side-by-side parity and performance targets still need manual checks. Windows reminders/toasts, backup restore UI, assistant/Vault and sync/OCR/on-device AI are absent or out of scope. Nex's readable full-backup library with encrypted private settings, and its Persian normalization limitations, are preserved and documented.
