# Nex Windows application

Current version: **0.12.1+9**. This repository includes the application's relative package dependencies. [Product overview](../../README.md) · [Release process](../../docs/RELEASING.md) · [0.12.1 validation](../../docs/WINDOWS_0121_REVIEW.md).

## Interface modes

- **Window:** custom caption with native drag, minimize, maximize/restore, close and system menu; Capture / Library / Tools / Settings navigation. The library uses two panes when its available width is at least 900 logical pixels. Normal bounds and maximize state persist, including when quitting while minimized. Maximized content fits the monitor work area.
- **Edge panel:** edge reveal, dock, hover navigation, flyouts, pinning, tray and global shortcut. Reader holds suppress automatic hiding but permit hover switching and explicit outside-click dismissal. Explicit pin, active drags, modal menus/dialogs and native pickers remain protected.

Both surfaces share the same controller, feature state, database worker and settings. Mode changes wait for the new Flutter frame before revealing the native window. Display labels use the actual Windows device number; a saved device name keeps selection stable when enumeration order changes.

## Architecture and persistence

`lib/core` owns shell state, geometry, holds, utilities and native bindings. `lib/ui` renders the two shells. `lib/nex` contains capture, library, detail, tag management, reminders, backups and settings. The C++ runner separates native window/caption, clipboard, hotkeys, tray, notifications, pickers and startup operations.

`DesktopStore` runs the shared Nex SQLite repositories in a dedicated isolate with FIFO commands. Notes, revisions, tags, threads, tombstones and FTS stay in the domain repositories. Saves are submitted without a view-owned debounce and pending work drains before exit. Shared UI includes an optional desktop checklist-preview callback; done-item sorting retains original source indexes.

The application-support directory contains `nex.sqlite` and `media/`. Shell preferences and clipboard storage live under `%APPDATA%\NexDesktopShell`. Clipboard persistence stores the most recent 50 distinct text/image entries and separate favorites, with atomic commits and save/retry reporting. Live clipboard preview capture may downscale images; the feature is not a promise to archive the original full-resolution source image.

## Localization and reminders

The UI supports English and Persian, bundled Inter/Vazirmatn fonts, Persian-aware search and RTL text. After changing ARBs, run `flutter gen-l10n` here; utility translations are generated with `python tools/generate_utility_strings.py` when that source changes.

Reminder times are stored in UTC and edited/displayed in local time using a 24-hour picker. A serial coordinator schedules/cancels Windows toast notifications with `Nex.Desktop.App`, refreshes on startup and mutations, and routes note activation. Native probe testing verified schedule/change/cancel; full installed delivery after exit/reboot remains a separate manual check. Indefinite repeat replenishment while the app is fully exited is not implemented.

Backups support Nex `.nexbak` / `.nexfull` archives, checked staging and atomic replacement. Full-backup private settings use authenticated encryption and a recovery key. Link reading is bounded and note opening permits only supported schemes. Cloud/LAN sync, OCR, assistant/Vault, local LLM and automatic updates are not included.

## Build and verify

Use **Flutter 3.44.8**, default `pub.dev`, and Visual Studio with Desktop development with C++. Run from this directory:

```powershell
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --release --no-pub
```

[Installer packaging](installer/README.md) requires Inno Setup **6.7.3**. Distribute the whole Release bundle or the installer. Build outputs and caches are ignored by Git.

Windows tests compare bundled-font snapshots and the review matrix. Non-emoji views are pixel exact. Four explicitly named emoji grids allow at most **0.05%** pixel drift for Windows 11/Server emoji rasterization; dimensions and larger differences still fail. CI uploads failure images and the reviewed matrix.

The explicit `--panel-smoke <report.json>` probe uses an isolated temporary database and separate instance identity. It tests repeated window/panel transitions, focused/held/pinned hover, native sizing, minimize/maximize/restore and saved bounds. Other probes and their limits are described in the dated validation reports.

Physical mixed-DPI/hot-plug monitors, live microphone/playback, external drag/drop and installed notification/upgrade paths need hardware or clean-machine checks. Automated snapshots and fake-host tests do not establish those behaviors.

## Attribution

The shared package base and historical transfer patches are documented in [INTEGRATION](../../docs/INTEGRATION.md). Original shell and font/plugin notices are retained in [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).
