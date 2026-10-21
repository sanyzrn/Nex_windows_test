# Nex Windows application

Declared version: **0.25.0+19**. [Product guide](../../README.md) ·
[Current progress](../../docs/agent-reports/SUMMARY.md) ·
[Shortcuts](../../docs/shortcuts.md) · [Release process](../../docs/RELEASING.md).

## Shells and state

- `lib/ui/window_shell.dart` composes the native caption, section header and content
  card. `kWindowWideAt` (960 logical px) chooses the labelled rail or slim rail.
  The default window is 460×760 dip with a 380×520 minimum; size/position memory
  is optional. Large text can widen rails and wrap/scroll content.
- The panel shell provides edge reveal, dock, hover navigation and flyouts. Holds
  protect recordings, native pickers, active drags and modal operations. Both modes
  share a controller, note feature state and storage; mode transitions reveal the
  native surface after the new Flutter frame. Closing quits by default; Settings → Display can retain Nex in the tray.
- `lib/core/controller.dart` composes `PanelLifecycle`, `PanelTimers`, `PanelWiring`,
  `PanelDismissal`, `PanelWindowTransitions`, `PanelActions` and `PanelClipboardOps`.
  Its `part` files belong to the same library; do not import them independently.
- `lib/nex/features.dart` exports feature modules. `NexFeatures` in
  `features_state.dart` coordinates capture, media, selection and note mutations;
  `NexScope`/`NexPanelScope` expose shared state and panel holds to the views.

## Native bridge and reminders

`lib/core/native.dart` defines the host interface and `WinNativeHost` method/event
channel bridge. `windows/runner` owns window placement/caption, tray, hotkeys,
clipboard, startup, pickers, updater handoff and WinRT toast scheduling.

Reminder edits store UTC, while pickers and repeat rules use local wall-clock
values. `reminder_coordinator.dart` serializes startup, mutation and timer refresh;
`reminders.dart` reconciles desired notifications with the native queue;
`reminder_policy.dart` derives stable IDs and future occurrences. Daily repeats
queue seven occurrences, weekly repeats eight. The runner uses AUMID
`Nex.Desktop.App`; protocol activation routes back to the selected note. A finite
queue does not replenish indefinitely while Nex is fully exited. See
[the 0.22 reminder contract](../../docs/WINDOWS_0220.md) and
[manual notification checks](../../docs/TEST_0220.md).

## Storage, backup and intelligence

`DesktopStore` (`lib/nex/store.dart`) runs SQLite repositories in a dedicated
isolate with FIFO commands. Notes, revisions, tags, threads, tombstones and FTS
remain in the shared domain repositories. Pending writes drain before exit.
The application-support directory holds `nex.sqlite` and `media/`; shell settings
and `clipboard.sqlite` live separately under `%APPDATA%\NexDesktopShell`.

`ClipboardStore` has one isolate writer, FULL WAL commits, 50 distinct recent
text/image entries and separately ordered favorites. It migrates legacy pins
once and reports save/retry errors. Live image capture may downscale previews.
Backups retain the existing `.nexbak`/`.nexfull` formats, checked staging and atomic
replacement; encrypted private settings use a recovery key. Do not alter schema
or archive formats as part of UI cleanup.

`lib/nex/intelligence` adds opt-in cloud providers, conversation history, note
context/actions, OCR, transcription and semantic search through `nex_ai`.
Provider keys use Windows secure storage. Local inference is a placeholder;
cloud/LAN sync is not enabled. Release history is bundled in English/Persian and opens offline from About Nex
or the update card. The reminder picker follows the chosen Solar/Gregorian
calendar, returning the same civil date for UTC persistence.

`lib/updates` checks stable GitHub
releases, validates downloads and hands a saved session to Install & restart.

## Optional modules (0.24.0)

`lib/nex/modules` holds four device-opt-in modules. `NexFeatures.modules` owns
switches and one `DesktopPrivateSession`; Settings and the window Tools shelf
share their launchers. A private local Navigator is removed on blur/lock so
nested dialogs cannot leave sensitive dates or text visible.

- `pdf_reader.dart` uses the Flutter-3.44-compatible pdfrx 2.4 line; PDFium is a
  bundled native build asset. Each keyed document owns its controller, and text
  search attaches only after document readiness. HTTP(S) links and internal PDF
  destinations are allowed; executable/custom link schemes are not launched.
- `vault_store.dart` reuses the Android validated v1 shape in a Windows-only
  secure-storage key; writes are serialized and read back. Neither note SQLite,
  FTS, AI nor the library/full-backup writers read it. `native_private.cpp` owns
  HWND-bound Windows Hello verification and excluded, sequence-checked copying.
- `portrait_view.dart` counts live library notes with `nexWritingStats` and asks
  for explicit disclosure consent before `DesktopIntelligence.writePortrait`.
- `cycle_view.dart` uses existing `SqliteCycleRepository` commands in the storage
  isolate and `CyclePredictor`, preserving advanced day fields and schema v1.
  Daily logs queue immediately; chosen calendars affect display, not civil dates.

The Release smoke probe renders/searches a synthetic PDF and tests secure
storage/private clipboard behavior. A real person's Windows Hello verification
and physical DPI/Narrator/backup checks remain manual. [B8 report](../../docs/agent-reports/B8.md).

## Localization and development

English/Persian use bundled Inter/Vazirmatn fonts and RTL-aware text. Keep both
ARBs and the desktop/intelligence/utility maps in parity. From this directory:

```powershell
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --release --no-pub
```

Use Flutter **3.44.8** / Dart **3.12.2**, default package hosts, and Visual Studio's
Desktop development with C++ workload for Windows builds. Run package commands
sequentially. [Contributor guidance](../../CONTRIBUTING.md) describes focused
local checks and CI gates. [Installer packaging](installer/README.md) pins Inno
Setup **6.7.3**. Distribute the whole Release bundle or installer.

Regenerate shortcut documentation with `dart run tool/generate_shortcuts.dart`.
Utility maps derive from ARBs with `python tools/generate_utility_strings.py`.
`../../tools/audit_unused_strings.py` lists cleanup candidates; inspect dynamic
lookups (AI enum keys and IANA city names) before deleting a translation.

Windows CI compares golden/review snapshots using the pinned SDK. Only explicitly
listed emoji grids have a small font-raster allowance; other comparisons remain
exact. Refresh intended changes on Windows and review all changed images.
Widget tests do not verify real DPI/monitor hot-plug, IME/Narrator, microphone,
installed toasts, uninstall/reinstall or clean-machine upgrades. Probe entry points
use isolated data; historical results are indexed in [verification](../../docs/TEST_RESULTS.md).

## Attribution

[Integration history](../../docs/INTEGRATION.md) and historical transfer patches
record the vendored package base; do not reapply patches. Existing shell/font/plugin
notices remain in [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).
