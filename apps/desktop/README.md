# Nex desktop

This standalone test repository already contains the required Nex packages and applied shared changes. Build directly from `apps/desktop`; do not reapply the patches here. The clean-Nex-checkout patch instructions below describe the separate source handoff ZIP. See the repository root README for standalone build and downloads.

## Interface modes

Since 0.10.0 the product has two interface modes over one application:

- **Window (main):** `lib/ui/window_shell.dart` renders a full desktop surface — navigation rail (Capture / Library / Tools / Settings), section headers, adaptive content. The native host is restyled into a normal resizable `WS_OVERLAPPEDWINDOW` window (caption, min/max, taskbar, minimum size, no topmost, opaque composition). Its frame and maximized state persist in settings and are revalidated against current monitors at every launch; a frame that is no longer visible re-centers instead of opening off-screen.
- **Edge panel (optional):** the original liquid slide-out shell (`lib/ui/shell.dart`), unchanged in behaviour: same springs, dock, flyout, edge reveal, tray and shortcuts.

Both modes share the same `PanelController`, `NexFeatures`, database isolate and shell preferences; switching (`Settings → interface mode` or the rail button) swaps the home widget and restyles the host in place. In window mode `blur()`/edge-watch/auto-hide are dormant and `SetPassthrough` degrades to restore-and-focus, so the window survives focus loss and `--background` launches wait in the tray. The `--native-smoke` probe forces panel mode because it validates edge placement and reveal.

## Plan

Architecture: retain the extracted Flutter Right Panel shell and its spring model. Compose Nex core/data/ui through relative package dependencies. Run SQLite repositories in one owned isolate; persist captures on every content change. Shell preferences are separate from Nex domain data. No WebView, no second notes store. Optional AI has one removable integration point.

Nex main base: `4861feac41530c951cb9e637ff921c6472d7de58`; Android client version `1.92.1`.
Original reference: https://github.com/raminturne/right-panel (read-only).

| Right Panel feature | Mapping |
| --- | --- |
| Notes | Replace with Nex capture/timeline/detail |
| Search | Nex local search; retain web search in More |
| Emoji, clipboard, colours | Keep under More |
| Calculator, units, password, generators | Keep under More; owner decides later |
| Timer, stopwatch, world clock, text, snippets | Keep under More; owner decides later |
| Media, folders, app pins, screenshot, system helpers | Keep functional; owner decides later |
| Settings | Nex tokens/language plus shell edge/monitor/startup |
| Liquid dock, flyout, reorder, tray | Preserve shell |

Repair order: measured flyout bounds; physical-edge mirroring; responsive dock; clock offsets; owned native workers/cancelled shutdown; correct Release bundle documentation; regression and mandatory goldens. Then capture/media, timeline/detail, search/tags/threads, settings/backup, practical OS coverage. Shell fidelity takes priority over secondary feature count.

## Architecture and data

This app started from the extracted `right_panel_flutter.zip` supplied by the owner. The original Rust/WebView Right Panel was inspected read-only at commit `90dcdbde8e33816f08b681c65cd341aa796f81e4`; no changes were made to that repository. Its MIT notice is included here and in Settings → About / licences.

`lib/ui` and `lib/core/controller.dart` retain the Flutter shell, inline original SVG paths, spring integration, velocity squash, icon stagger, magnification falloff, press compression, active-pill travel/stretch, pouring flyout, radius morphing and content blur/stagger. Physical edge geometry uses `Settings.edge`, independently of Flutter's locale direction. The shell palette adapts the active Nex `ThemeData`; the competing original preset table/settings screen was removed after replacement with Nex settings. Shell shadows and liquid geometry remain panel effects.

`lib/nex/store.dart` owns one database isolate and one FIFO command stream. It opens `NexDatabase`, `SqliteNoteRepository`, `SqliteThreadRepository`, `CaptureService`, `TagService` and `LibraryMaintenance` from the relative Nex dependencies. Schema, migrations, UUIDv7, revisions, tombstones, FTS and change tracking remain Nex's implementations. The UI renders `nex_ui.NoteCard`, `NexTextSurface`, `NexMarkdown` and Nex content-direction/calendar helpers. The timeline loads 50 rows at a time through a lazy list. Filtered search uses Nex's query parser and repository, with thread membership intersected through the thread repository.

The application-support directory returned by `path_provider` contains `nex.sqlite`, `media/` and temporary backup archives. Every text change submits a write immediately, without debounce, Save, network or AI. The capture session/editor belongs to the app, survives flyout closure and drains before exit. Imports copy and stream-hash files in the database isolate using Nex's hashing/capture APIs. Large imports/backups share the FIFO and can delay subsequent write completion; separating media preparation from the short repository transaction is a performance follow-up. Clipboard capture reads the current image at full supported resolution; retained clipboard history uses the original thumbnail behavior. Failed writes stay visible and prevent shutdown from discarding a failed capture. Utility snippets, pinned clipboard previews and shell preferences remain separate original utility state in `%APPDATA%\NexDesktopShell`; no original JSON notes store or note model remains.

Desktop-owned interface labels live in `lib/l10n/app_fa.arb` and `app_en.arb`. Persian is the default; fonts are the existing Nex Vazirmatn/Inter assets. `utility_strings.dart` is generated from those ARBs to translate retained utility registry labels and messages. Shared preset names remain in Nex's existing bilingual catalog, avoiding a second preset catalog. System/plugin error diagnostics and generated/user content can retain their original language.

AI is explicitly a stub. There are zero desktop imports of `nex_ai`; its optional path dependency can be removed without changing desktop Dart code. No AI adapter, network capture path, credentials or bundled keys exist. Vault is absent: there is no desktop vault access, search indexing, clipboard capture from a vault UI, notification context or AI context. A future implementation must introduce explicit isolation before exposing vault data.

## Native lifetime

The bridge owns joinable workers. Finished workers are reaped when new work starts; the clipboard loop starts once and uses an atomic stop flag and interruptible waits. Shutdown first disables method callbacks, signals cancellation, closes worker dialogs, joins all workers, clears queued events and removes the tray. Modal initialization hooks also check cancellation, covering the race where a dialog appears during shutdown. Events return to Dart through the platform-thread queue and are dropped once stopping begins. The bridge is destroyed before Flutter's messenger/controller. No `.detach()` remains. Controller delayed actions, edge polling and utility timers are cancelled on disposal. Windows close requests drain Nex work before native destruction.

Third-party Windows shell/icon APIs can block while resolving an unavailable external path; this build cannot impose a hard cancellation deadline on every Windows API. Dialog-cancellation shutdown and inaccessible network shortcuts need the manual checks below before a shipping release.

## Run, test and build

Extract the handoff ZIP into a clean Nex checkout at the recorded SHA, then apply the two patches from the repository root:

```powershell
git apply --check patches/01-shared-backup.patch
git apply patches/01-shared-backup.patch
git apply --check patches/02-shared-theme-presets.patch
git apply patches/02-shared-theme-presets.patch
cd apps/desktop
flutter --version # minimum Flutter 3.35.0 / Dart 3.9.0; use installed SDK, no upper bound
flutter pub get
flutter run -d windows
```

Install the Flutter Windows build prerequisites, including Visual Studio's Desktop development with C++ workload. Keep all four relative package dependencies. The Dart package name `right_panel` is retained for the port's test imports; the product/window/executable are Nex / `nex_desktop.exe`, version `0.10.0+6`.

```powershell
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub test/golden_test.dart test/shell_regression_test.dart
flutter build windows --release --no-pub
./tools/windows_smoke.ps1
```

Goldens are enabled in the ordinary test suite. Ten committed images cover emoji, More, settings/light, both physical edges with Persian RTL, a differently sized calculator flyout, and capture/inline reading in English/light and Persian/dark. Capture/reader comparisons wait for the spring to settle; transient subpixel motion is not a visual baseline. The test font loader uses the supplied Nex fonts and the host's Windows Segoe UI Emoji font. Baselines were generated on Windows with Flutter 3.35.5; OS/font differences may require review — on Linux the same ten comparisons fail with small pixel diffs (1–6%) on the unmodified source as well, so a non-Windows run is not a visual verdict. Deliberate regeneration uses `flutter test --no-pub --update-goldens` (on Windows); generation alone is not a passing comparison. `test/window_shell_test.dart` covers the desktop window shell: section navigation, tool directory/back routing, durable capture, native mode-switch calls with frame persistence, settings round-trip of the new keys, and dormant auto-hide in window mode.

After editing ARBs, run `python tools/generate_utility_strings.py`, `flutter gen-l10n`, and `dart format lib`. Generated localization files are supplied. Dependency resolution during validation used `PUB_HOSTED_URL=https://pub.flutter-io.cn` and `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` because the default hosts were unavailable here. The lockfile records that mirror; use the same environment for the tested resolution.

`tools/windows_smoke.ps1` checks the full Release bundle and runs the built executable against a temporary Nex database. It sends the registered capture shortcut, moves the pointer to each edge and restores its location, temporarily toggles/restores startup, exercises placements/display-change refresh and verifies second-instance rejection and graceful exit. A separate normal GUI run checks its first Flutter frame, synthetic capture routing and WM_CLOSE exit. Close an existing Nex desktop instance first. The probe deliberately holds for two seconds for the mutex check. Its shutdown-wait figure includes that hold and is not a latency benchmark. It does not overwrite clipboard contents.

## Android ↔ Windows parity

“Done” describes implemented code with the validation scope in `TEST_RESULTS.md`; it does not imply every hardware scenario was manually tested.

| Feature | Windows status | Detail |
| --- | --- | --- |
| Full desktop window (main mode) | Done | Normal resizable window, nav rail sections, persisted frame, tray/hotkey routing, survives blur |
| Edge slide-out panel (optional mode) | Done | Original liquid shell preserved; switchable at runtime |
| Local notes/schema/change tracking | Done | Nex repositories/migrations; FIFO isolate; reopen tested |
| Immediate text/checklist capture | Done | Empty field, hotkey, per-change persistence; Esc keeps app-owned session |
| Photo/file capture | Done, OS validation partial | Separate image/audio/file choosers, clipboard button/Ctrl+V, drop and content-addressed copy; cancellation creates no note or success status |
| Timeline/pin/delete/undo/trash | Done | Nex cards, lazy 50-row pages, day headers, detail actions; undo refreshes library |
| Search | Done | Nex FTS/query parsing plus type/tag/thread filters; matches repository normalization |
| Tags/threads | Done | Create, attach/remove, browse, existing thread membership |
| Text/checklist/Markdown/detail | Done | Inline reader without a desktop-dimming modal, explicit edit mode with immediate edits, checklist toggles, photo preview, caption/copy rules and system attachment opening |
| Reminders | Missing OS feature | Nex `dueAt` command/model retained; no scheduling UI or Windows toast adapter; active reminder chips hidden |
| Voice | Partial | WAV record/play/pause and Nex media path implemented; actual Windows WAV playback completed; microphone and subjective output quality not exercised |
| Themes/language/shell settings | Done | Shared Nex presets/tokens, fa/en, chosen edge/monitor, N/Q/Space shortcuts, startup |
| Backup | Partial parity | Actual Nex full-backup export and codec round-trip; no desktop restore UI or vault/key payload |
| Assistant | Explicit stub | No adapter/actions/transcription; core works without AI |
| Vault | Missing by design | Existing client-only vault/auth/session UI needs a larger safe extraction |
| LAN/cloud sync, OCR, on-device AI | Out of scope | No alternate engine or protocol added |

Nex's shipping reminder adapter explicitly supports Android/iOS only. A Windows toast implementation requires a Windows notification identity, scheduling/reconciliation and activation path; it was left missing rather than treating an in-process timer as a durable reminder.

The prompt's blanket “encrypted backup” description conflicts with Nex's actual `FullBackup`: library/model entries are readable, while private settings use authenticated WinZip AES-256 with a generated recovery key. This app uses that exact format and states the distinction in the UI. It exports desktop shell settings, library and media; there are no vault, AI-key or model entries to export. Keep the recovery key separately. Persian search uses exactly the same Nex repository as Android, including its current limitation: Arabic `ي/ك` forms are not silently normalized into Persian `ی/ک` by a desktop-only rule.

## Shell parity and remaining validation

The mandatory conversion repairs are implemented: live flyout height/anchor clamping, full physical mirror, dynamic `height - 190` dock viewport, correct zone offsets/DST/day boundaries, owned native lifetimes and complete-bundle packaging. Drop hints mirror and held-drag edge reveal works even with a stationary pointer. Display/DPI messages defer reanchoring until Windows updates the geometry, keep the selected monitor by display name, and fall back to monitor zero after removal. App/folder pin controls remain in settings. Original spring constants remain: slide `320/38`, grow `340/24`, vertical flyout `380/30`, pill travel `420/26`, pill stretch `380/22`, icons `380/25`, hover `500/30`, press `700/28`. Tests assert edge geometry, mirrored origins, height changes, overflow safety and spring behavior. Reference-based code audit and committed goldens support parity; a side-by-side human assessment of moving shells has not been performed.

Known limits: live microphone/audio devices, live clipboard image formats, modal-picker exit races, mixed-DPI monitors/hot-plug, system utility actions and attachment launching need manual validation. Clipboard images support standard uncompressed 24/32-bit CF_DIB/CF_DIBV5; other formats are not implemented. Native registration reports hotkey collision as failure and retains the previous shortcut, but initial registration failures have no dedicated settings banner. Failed voice import keeps its temporary recording file; automatic retry/recovery UI is not complete. Warm usable-panel latency and 10,000-note frame smoothness are not measured. See the exact manual checklist and outcomes in the root test report.

Remaining shell duplication is intentional: the port's spring, SVG, layout and original non-Nex utilities. There is no copied Nex schema/search/merge/theme engine. Utility snippets and clipboard history remain utility state; the owner should decide whether to integrate or retire them later. Two small package moves expose existing backup/theme modules while preserving Android import shims. No root Makefile/CI changes are needed for this standalone desktop handoff; existing root checks do not automatically discover this app. Maintainers should add the documented desktop commands to CI once Windows/font baselines are owned.

Next: implement durable Windows reminder notifications; complete backup restore/secure settings payload; measure hotkey and large-library performance; validate mixed-DPI/hot-plug and picker shutdown; test voice and clipboard formats; decide utilities/installer ownership; extract vault only with isolation tests; add a single removable AI adapter using Nex's existing action/confirmation protocol when requested.

## Windows distribution

### Runtime repair after the first installer

The first installer was not usable: a ticker read a render transform before layout and stopped the animation on its first frame. Geometry is now measured after layout, and full-shell startup tests include the actual Nex editor/database and focus. Hover-switching followed by a click keeps the selected tool open; a second click closes it. The spring parameters are unchanged.

Closed hosts are hidden rather than making the Flutter DirectComposition parent layered. Manual launch, tray opening and a second launch restore an interactive host; Windows startup uses `--background`. The visible host has a real taskbar/Alt-Tab icon. This visibility/taskbar behavior is an intentional Windows usability adjustment to the reference shell. Keyboard focus on the native host is forwarded to the Flutter child. Opening again cancels an outstanding hide timer.

The installer writes its selected language plus an installation marker. The app applies that language once per installation, while later in-app language choices survive ordinary restarts. The Nex resource icon is used in the runner, installer and tray. App/folder selection uses Windows `IFileOpenDialog`, holds off blur/auto-close during the modal, and emits an added-app event only after a successful nonempty selection. Cancel adds nothing and shows no success toast; invalid empty shortcuts from the old version are removed from shell preferences.

For local troubleshooting only, an adjacent `diagnostics.flag` enables a geometry/frame-state report and Flutter error log in the shell preferences folder; it records no note content. That marker is not packaged. Runtime validation and its limits are in the updated test report; the earlier first-frame/native-state probes did not prove usability.

Distribute the **entire** `build/windows/x64/runner/Release/` directory together: `nex_desktop.exe`, Flutter runtime, every plugin/runtime DLL, native assets, `data/app.so`, `data/icudtl.dat` and all `data/flutter_assets/`. Keep their relative paths. The raw executable alone is not a portable distribution.

At the owner's follow-up request, `installer/nex.iss` and `tools/build_installer.ps1` package the full bundle and app-local Microsoft C++ runtimes as `Nex-Windows-Setup-0.9.0-x64.exe`. The installer is supplied separately from the source ZIP, installs per user, supports Persian/English and preserves note/media/settings data on uninstall. See `installer/README.md` for reproducible build commands and signing status. This handoff ZIP remains source-only, with no compiled bundle, installer binary or toolchain/cache files.

## Usability repair — 0.9.0+5

The header pin keeps the panel open, persists across launches, and is independent of a note's library pin. Explicit Close/Escape still closes it. Typing, reading a note, menus, file selection and recording hold the host open. Hovering another dock tool cannot replace a held editor/reader. Detail is inline, with a reader first and an explicit Edit action; tags/threads are collapsed. The desktop theme uses Nex colours/fonts with lighter input fills, consistent rounded controls, compact native icons and softer shadows. The active liquid pill paints below its glyph.

The unresponsive lower capture controls were a real hit-test defect: bounded Opacity preceded a vertical Transform, so controls painted outside the unshifted bounds could not receive pointer input. Transforms now precede Opacity, without changing spring constants or animation math. Mouse regression tests place the flyout near the bottom on both physical edges and click the translated Add image and checklist controls. Picker cancellation, picker errors, overlapping holds and durable photo/audio copying have separate coverage. Error propagation through nested media operations is explicit.

Add image opens a Windows image chooser; Add audio opens an audio chooser; Attach files accepts generic files. Clipboard image paste remains a separate action. Import/permission errors are visible, empty cancellation does not show success, and ongoing imports drain on exit. Recording uses WAV, prevents overlapping start/stop calls, and holds the panel until stopped. Playback follows actual player state. Unsupported mobile audio-session activation is disabled on this Windows player; native fixture playback was verified through a completed event at the full file duration.

For an isolated native media/codecs check, close other Nex instances and run the full Release executable with `--media-smoke <image-path> <audio-path> <result-json-path>`. This opt-in check imports into its own temporary Nex database, decodes the copied image, plays the copied audio to completion and exits. It does not establish microphone, file-dialog pointer or hardware-wide coverage. See TEST_RESULTS.md for observed results.
