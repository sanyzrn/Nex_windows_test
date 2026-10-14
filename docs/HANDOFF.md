# Agent Handoff: persistent clipboard and tool explanations — 2026-10-14

Owner requested durable last-50 clipboard history across Windows shutdown plus a one-line explanation of every tool before choosing removals. Implemented separate SQLite clipboard storage at `%APPDATA%/NexDesktopShell/clipboard.sqlite`, a dedicated isolate, atomic FULL WAL commits, cached immutable keys and incremental image-blob transmission. Retains 50 distinct recent text/image entries, MRU recopy, separate favorites, persisted delete/clear/pin/unpin, one-time legacy pin migration. Loads before native watching and drains before quit. Saving/error/retry are visible; unreadable databases are not silently overwritten. Clearing preserves pins. Old native image preview/downscaling remains unchanged.

Full suite **159 PASS**, ordinary unchanged goldens; final focused **8 PASS**; analysis/hygiene/host guard/whitespace PASS; Release and installer PASS. Actual isolated Release writer committed 60 entries, was forcibly terminated without close/checkpoint, and a fresh reader recovered 50 recent entries, exact image bytes/time and an evicted image favorite. This never touched the user's real clipboard/data/app. No actual OS reboot or installation was run. Root installer `Nex-Windows-Setup-0.12.0-Clipboard-x64.exe`, 13,877,393 bytes, SHA-256 `1454156b4fcfadbd1e904ac209022c918f4b57870423bcd5aea58bbe2d15c86e`. Source/build and tested/packaged EXE hashes match. Snapshot remains `C:\Users\zrn_s\AppData\Local\Temp\nex-product-build-20261014-081747`; logs under `apps/desktop/build/clipboard-*`.

No tools were removed. Await the owner's selection after the full tool descriptions. Pin window toggles previous-foreground always-on-top; Generate creates UUID/date/time/random/sample data; Text tools transforms copied text; Snippets saves reusable texts. All other registry definitions/handlers were inspected. The older product/reminder backlog remains below. See [CLIPBOARD_PERSISTENCE.md](CLIPBOARD_PERSISTENCE.md). No commit/push; preserve existing work.

---

# Agent Handoff: previous notebook workspace and reminder repair — 2026-10-14

Current owner request: improve both appearance and daily functionality, fully inspect reminders (09:00 changed on reopening), dock hover centering, and clipboard controls overlapping text. Implemented the notebook home with exact totals/pins/recent previews and quick Windows tools; wide library autoselection and retained off-page activation; independent clipboard action lane/two-line previews; actual dock center fix (full-width column plus removal of hover translation).

Reminders now use local display/calendar repeat calculations, explicit 24-hour input, validation, save/retry guards and a serial startup/mutation/30-second coordinator. Real Windows testing caught 16-char developer ID rejection and optional `ToastNotifier.Setting` ERROR_NOT_FOUND despite successful scheduling; both repaired. Native IDs are stable 15 chars for UUIDs. Installer registers note protocol activation; native forwarding and Dart routing support cold/existing app launches. Details and remaining delivery/recurrence limitations are in [PRODUCT_ITERATION.md](PRODUCT_ITERATION.md).

Validation: full suite **153 PASS**, ordinary goldens; analysis/hygiene/host guard/whitespace PASS; 40 visual screens; Release and installer PASS. Actual Release queue probe preserved local tomorrow 09:00, replaced with 10:00 (one entry) and cancelled. Actual mode/hover test passed 3 right/left/right cycles, no Flutter errors. Source hashes matched the build snapshot; packaged EXE hash matched tested Release.

Root installer `Nex-Windows-Setup-0.12.0-Product-x64.exe` (13,864,597 bytes), SHA-256 `e3dcc180de777e4dc25def6325ae4fdca09f457e01c3be6d7086b3126fb58748`. Build snapshot `C:\Users\zrn_s\AppData\Local\Temp\nex-product-build-20261014-081747`. Logs/probe JSON under `apps/desktop/build/product-*`. Existing installed user instance was not stopped or upgraded. No commit/push.

Next work: durable later recurrences while the process remains fully exited, honest recovery after Windows drops a missed scheduled toast, installation/upgrade plus actual toast click with protocol registration, then the next product/utility pass. Reference brief is not blanket authority or a claim of completion. Preserve prior dirty changes. Native frame callback ownership/warm-up mode fixes remain required. Do not reuse the original stale Windows CMake cache; build the checked source snapshot. See [the current visual comparison](../design/product/README.md).

---

# Agent Handoff: previous panel transition and hover repair — 2026-10-14

Fixed native surface presentation across mode switches with hidden restyling, Flutter shell acknowledgement, a single pending generation-checked engine frame callback, and an offscreen warm-up frame. Mode changes serialize and reset stale panel state. Dock hover now opens its first panel and works while pinned/focused, while held reader/picker interactions remain protected. Auto-close and widget timer ownership were repaired.

Validation: full suite 140 PASS; analysis/hygiene/host guard/whitespace PASS; Release and installer PASS; actual isolated Release runner native mode/hover probe PASS (three right/left/right cycles, exit 0, no Flutter errors). Current root installer is `Nex-Windows-Setup-0.12.0-PanelFix-x64.exe`. See [PANEL_FIX.md](PANEL_FIX.md). Existing installed Nex PID 17792 remained running; installation was not performed. Normal launches retain their singleton identity; only the explicit panel diagnostic entry point uses a separate process and temporary data.

Next verification: installation/upgrade and additional DPI/monitor combinations. The previous reminder engine wiring remains unfinished. All previous source changes remain preserved; no commit or push was made.

---

# Agent Handoff: desktop usability phase — 2026-10-14

Implemented consistent keyboard paste, actual palette note opening and routes in both modes, new-note session reset, debounced library search, stale-response rejection, cached theme/palette, acknowledged Keep Awake state with error handling, and a clock-correct reminder reconciliation query. Installer filename detection and three CI defects were corrected. Shared packages and schema were not changed in this phase.

Validation: full desktop suite 135 PASS; final focused tests 14 PASS; desktop analysis, UI hygiene, whitespace and package-host guard fixtures PASS. The source tree remains dirty with the previous agent/redesign changes preserved. No commit, push, remote workflow run or installation was performed.

See [USABILITY_PHASE.md](USABILITY_PHASE.md) for current changes, measurements and limitations. Next native work: connect the reminder engine to startup/mutations through the store isolate and verify toast delivery; test installation/upgrade and hotkey/tray/clipboard/Keep Awake against the actual Windows runner. The installed Nex was left running. The previous appearance and historical notes follow.

---

# Agent Handoff: desktop appearance phase — 2026-10-09

The owner authorized a substantial redesign of both Windows modes. This phase is implemented; performance and the outstanding legacy quality/CI audit are the next work. The previous work in the checkout was preserved.

Version remains `0.12.0+8`. The root installer is `Nex-Windows-Setup-0.12.0-Redesign-x64.exe`, 13,829,419 bytes. SHA-256: `156a09e0447143b2e8ab7f123b1f66b708f663446cf1cf66b8bfc6418204aa0b`.

See [the redesign report](../design/redesign/README.md) for changes, screenshots, exact scope and validation. Desktop and UI analysis passed; UI hygiene passed; the full 120-test desktop suite passed with normal golden comparisons; Windows Release and Inno Setup compilation passed. Installer launch/upgrade, Narrator and native smoke were not run. The installed Nex process was already open and was left running.

Next: examine real Windows behaviour and performance, complete the old CI/documentation audit, and measure changes before claiming performance improvements. The material below is historical, including its old versions, base references and completion claims; it is not current verification.

---

# Historical handoff retained for reference

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
