# Agent Handoff: Nex for Windows (Version 0.11.0)

Repository cleanup on 2026-10-04 moved handoff, integration and validation notes into `docs/`, archived the original task under `docs/archive/`, and removed the duplicate `upstream-patches/` directory and redundant summary. `patches/` is the single retained transfer-patch location. See [TEST_RESULTS.md](TEST_RESULTS.md) for current checks; the work-package notes below describe the earlier implementation and are not independent proof of upstream alignment or hardware coverage.

## 1. Product Goal and Current Stage

**Nex for Windows** is the native Windows desktop client for Nex, sharing the local-first notes, capture, library, search, tags/threads, and SQLite data architecture of the Android application.
The interface operates in **two modes over one application**:
1. **Window Mode (Main Mode)**: A responsive, resizable full desktop application with navigation rail, 2-pane library view, keyboard shortcuts, context menus, and multi-selection.
2. **Panel Mode (Optional Mode)**: A lightweight, spring-animated edge slide-out panel living on the monitor perimeter with global hotkey invocation and edge mouse reveal.

**Current Version: `0.11.0+7`** (Windows resource version `0.11.0.7`). Synchronized across `pubspec.yaml`, About screen, `Runner.rc`, `nex.iss`, and `README.md`.

---

## 2. Base Commits & Repository Alignments

- **Upstream Monorepo (`DbsNex`)**: `3626d03d360098f99335e2193bba7d6e4b9b4a44` (release `v1.93.0`).
- **Windows Origin Base**: `82a7431c05022e2b70415c9c9c4a886497fedafb`.
- **Target SDK**: Flutter 3.44.8 / Dart 3.12.2 on Windows x64.

---

## 3. Architecture in Brief

- **Domain & Database**: Domain model is owned entirely by `packages/core` and `packages/data`. Database operations run across a dedicated serial SQLite isolate. Writes are durable and committed on change.
- **Liquid Physics Invariants**: All 8 liquid shell spring constants (`320/38`, `340/24`, `380/30`, `420/26`, `380/22`, `380/25`, `500/30`, `700/28`) are strictly preserved.
- **AI Layer Isolation**: `nex_ai` is isolated in `packages/ai` with **0 imports** inside `apps/desktop`.
- **Modular Native C++ Runner**: The native runner is partitioned into modular header/implementation pairs:
  - `native_common`: Strings, UTF conversions, process mutex.
  - `native_startup`: Registry run key management.
  - `native_hotkeys`: Windows global hotkey handling.
  - `native_tray`: System tray icon, context menu, Explorer restart recovery.
  - `native_window`: Window restyling, min/max track sizing, multi-monitor frame checks.
  - `native_clipboard`: Clipboard text/DIB/DIBv5/PNG read and set.
  - `native_pickers`: Win32 `IFileOpenDialog` wrappers with icon decor.
  - `native_notifications`: WinRT C++ Toast notification scheduling.

---

## 4. Work Package Completion Status

- **WP1 (Upstream Alignment 1.93.0)** — **COMPLETE**
  - Vendored upstream packages at recorded SHA.
  - Historical transfer patches `01-shared-backup.patch` and `02-shared-theme-presets.patch` retained; current upstream application has not been revalidated.
  - Persian search normalization (`nexSearchFold`) absorbed with full test suite.
- **WP2 (Codebase Reviewability)** — **COMPLETE**
  - Package renamed from `right_panel` to `nex_desktop`.
  - Added GitHub Actions workflow `.github/workflows/desktop.yml` with AI removal check.
  - Golden tests tagged `@Tags(['golden'])`.
  - Modular native runner with 8 focused domains.
  - Controller/features split into focused modules; some Dart files still exceed 500 lines.
- **WP3 (Desktop Parity Gaps)** — **COMPLETE**
  - Native WinRT durable toast notification scheduler + pure Dart reconciliation engine.
  - Backup restore UI and atomic SQLite staging for `.nexbak` and `.nexfull`.
  - 256 KB streaming link notes reader with Open Graph meta extraction.
  - Persian Saturday-first commitments calendar.
  - Safe link protocol whitelist and Android copy rule.
- **WP4 (Window Mode Polish)** — **COMPLETE**
  - Responsive 2-pane library view at $\ge 900$px with draggable divider and persisted width.
  - Comprehensive keyboard shortcuts (`Ctrl+N`, `Ctrl+Shift+N`, `Ctrl+F`, `Ctrl+L`, `Ctrl+,`, `↑`/`↓`, `Enter`, `Esc`, `Delete` with Undo snackbar & `Ctrl+Z`, `Ctrl+P`, `Ctrl+C`).
  - Shortcuts help dialog (`F1` or `Ctrl+?`).
  - Note card desktop context menu and bulk actions bar.
  - Reminder picker dialog with card badges.
- **WP5 (Measurement & Hardening)** — **COMPLETE**
  - 10,000 note benchmark: 1.22–1.50 ms/note insert rate, 2 ms timeline latency, 14 ms English search, 10 ms Persian search.
  - Media hashing outside database transactions.
  - Clean shutdown on `WM_CLOSE` across active recording, capture, or workers.
- **WP6 (Installer & Release Hygiene)** — **COMPLETE**
  - Version `0.11.0+7` (resource `0.11.0.7`) synchronized across all 5 required files.
  - Clean Inno Setup installer: `Nex-Windows-Setup-0.11.0-x64.exe` (13,810,715 bytes).
  - SHA256 checksum recorded in the repository-root `SHA256SUMS`; compiled installers remain ignored local artifacts.
  - User-facing `apps/desktop/CHANGELOG.md` created.

---

## 5. Duplication to Resolve (when merging into DbsNex)

- Merge `apps/desktop` into `DbsNex` monorepo as detailed in `INTEGRATION.md`.
- Retire the redundant standalone copy of `packages/core`, `data`, `ui`, `ai` and `spec/`.
- Consolidate common utility tokens with `nex_ui`.

---

## 6. Owner Decisions (Section 7)

Leave these decisions to the owner:
1. **Utility Tools Retention**: Right Panel utilities (calculator, units, colors, emoji, timers, media keys). Recommendation: Keep them in the "Tools" rail tab, as they provide useful desktop utilities without encroaching on note domain code.
2. **Edge Panel Mode After 1.0**: Whether to retain the edge panel mode permanently or transition solely to Window Mode. Recommendation: Keep both, as users love the edge slide-out for quick capture.
3. **AUMID & Notification Display Name**: Configured as `Nex.Desktop.App` and "Nex". Confirm before submission to Microsoft Store or enterprise catalogs.
4. **Uninstall Behavior**: Inno Setup currently retains user database and media in `%APPDATA%\NexDesktopShell` and `%APPDATA%\ir.dbsnex\nex_desktop`.
5. **In-App Updates**: Recommend GitHub Releases or Microsoft Store MSIX packaging.
6. **Package Naming**: Renamed to `nex_desktop` in `pubspec.yaml`.

---

## 7. Next Steps

1. Test the built installer `build/installer/output/Nex-Windows-Setup-0.11.0-x64.exe` on a fresh clean Windows environment.
2. Review visual layout on multi-monitor and high-DPI displays.
3. Follow `INTEGRATION.md` when ready to merge into `DbsNex` monorepo.

---

# History

The historical handoff documentation from previous versions (0.9.0 and 0.10.0) is preserved below:

### Historical Pass: 0.10.0 (2026-10-02)
- Added initial Window Mode shell with navigation rail.
- Persisted `windowMode`, `windowBounds`, and `windowMaximized`.
- Added native bridge `setWindowMode` and `windowFrame`.

### Historical Pass: 0.9.0 (2026-10-02)
- Fixed unclickable controls due to Opacity transform ordering.
- Added panel pin, interaction holds for pickers and recording.
- Replaced note dialogs with inline reader/edit flows.
- Disabled mobile audio session activation on Windows for audio player.
