# Nex desktop

Nex for Windows is a Flutter desktop application, version **0.11.0+7**. This standalone repository includes its four relative package dependencies. Shared changes are already applied; do not reapply `patches/` here. See the [root README](../../README.md), [integration guide](../../docs/INTEGRATION.md) and [validation report](../../docs/TEST_RESULTS.md).

## Interface modes

- **Window (default):** a resizable desktop window with Capture / Library / Tools / Settings navigation, keyboard shortcuts, note context menus and multi-selection. At widths of at least 900px, the library uses two panes with a persisted draggable divider. Window bounds and maximized state persist and are revalidated against available monitors. Losing focus leaves the window open.
- **Edge panel (optional):** the spring-animated slide-out shell with edge reveal, dock, flyouts, pinning, tray and global shortcuts. Interaction holds protect editing, reading, menus, recording and native pickers from automatic hiding.

Both modes share `PanelController`, `NexFeatures`, the SQLite isolate and preferences. Switching modes restyles the same native host. Background startup waits in the tray. The native smoke probe forces panel mode to validate physical edge placement.

## Architecture and data

`lib/core/` contains the controller, panel geometry, interaction holds, shell settings, utilities, springs and native bridge bindings. `lib/ui/` renders window/panel shells. `lib/nex/` contains capture, library, detail, link reading, commitments, reminders and settings views. The C++ runner separates clipboard, hotkeys, notifications, pickers, startup, tray and window management into `native_*.cpp` modules.

`DesktopStore` owns one database isolate and a FIFO command stream using `nex_core` and `nex_data`. Every edit submits a durable write without debounce. Notes, revisions, tombstones, FTS, tags and threads use shared Nex repositories. Search folds Arabic/Persian letter variants, digits and joiners using the shared `nexSearchFold` implementation. Cards, Markdown, themes, contrast and direction helpers come from `nex_ui`.

The application-support directory contains `nex.sqlite`, `media/` and temporary backup archives. Capture sessions survive view closure and pending work drains before exit. Failed imports preserve recoverable recordings. Shell preferences and utility state remain separate in `%APPDATA%\NexDesktopShell`.

Desktop text lives in the Persian/English ARBs under `lib/l10n/`. Persian is the default, with bundled Vazirmatn/Inter fonts. After changing ARBs, run:

```powershell
python tools/generate_utility_strings.py
flutter gen-l10n
dart format lib
```

The desktop has no imports of `nex_ai`; its optional dependency can be removed without changing app source. Assistant, Vault, cloud/LAN sync, OCR, local LLM and automatic updates are outside this desktop release.

## Reminders, backups and links

Reminder reconciliation schedules native WinRT toast notifications using `Nex.Desktop.App`. The installer sets the shortcut identity. Unit tests use a fake scheduler; they do not prove actual Windows notification delivery after exit or reboot. Test that path manually on an installed copy.

Settings exports and restores Nex `.nexbak` and `.nexfull` archives using checked staging and atomic replacement. Full-backup library/media entries are readable; private settings use authenticated WinZip AES-256 and a recovery key. Keep the key separately. There are no Vault or AI credentials to export.

Link metadata reading streams at most 256 KB and recognizes Open Graph metadata. Note opening allows `http`, `https`, `mailto` and `tel`; the web reader accepts HTTP(S).

## Build and verify

Use Windows x64, Flutter 3.35.0+ / Dart 3.9.0+ and Visual Studio with Desktop development with C++. From `apps/desktop`:

```powershell
# Hosts recorded in the validated lockfile.
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --release --no-pub
./tools/windows_smoke.ps1
```

Run Flutter commands sequentially within this app: concurrent builds/tests can race when regenerating Windows plugin symlinks. Distribute the entire `build/windows/x64/runner/Release` directory. See the [installer guide](installer/README.md) for Inno Setup packaging. Build outputs and caches are ignored by Git.

Run the shared suites from each package: `dart test` in `packages/core` and `packages/data`; `flutter test --no-pub` in `packages/ui` and `packages/ai`. Run analysis there as well.

Golden comparisons run in the Windows suite and are tagged `golden`; other hosts skip them because fonts/rendering differ. Ten baseline images cover settings, tools, both edges, capture and reading in both languages. `test/flutter_test_config.dart` loads bundled fonts and Segoe UI Emoji. Regenerate baselines only after reviewing intentional UI/SDK rendering changes, then compare again without `--update-goldens`.

`windows_smoke.ps1` validates runtime bundle members, tray creation, registered hotkey/capture delivery, edge reveal, startup restoration, display refresh, single-instance handling, a rendered GUI frame and graceful shutdown. Close other Nex instances first. It uses a temporary database and restores startup/cursor state. It does not validate live clipboard contents, actual toast delivery or interactive hardware behavior.

## Remaining manual checks

Review actual toast delivery after shutdown/reboot, live microphone/playback, clipboard image formats, Explorer drag/drop, picker shutdown races, tray recovery after Explorer restart, unavailable network shortcuts, mixed-DPI/hot-plug monitors and moving-shell visual parity. Automated widget snapshots, repository benchmarks and smoke probes do not establish these behaviors.

The original shell was supplied as `right_panel_flutter.zip`, with [raminturne/right-panel](https://github.com/raminturne/right-panel) at `90dcdbde8e33816f08b681c65cd341aa796f81e4` used as a read-only reference. Its notice and font/plugin notices remain in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Shared package provenance and historical validation are retained in the repository documentation.
