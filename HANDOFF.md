# Agent handoff: build the Windows home of Nex

## Product goal and current stage

This repository is the working project for **Nex for Windows**. The intended product is the Windows counterpart of the Nex Android application: the same local-first notes, capture, library, search, tags/threads and compatible data, presented through a fast desktop edge panel. It must become an everyday Windows Nex application. The panel is its desktop interface, not the final product by itself.

**Windows version: 0.9.0+5, public release v0.9.0.** Windows has its own pre-1.0 version sequence. Android's 1.92.1 identifies the upstream reference only; never reuse it as the Windows product version. Windows is still a preview and is not ready for a 1.0 claim. Preserve an independent Windows version until the owner explicitly approves readiness.

## Where the implementation lives

- `apps/desktop`: the actual Windows Flutter application, native runner/bridge, translations, assets, tests and installer sources.
- `packages/core`, `data`, `ui`, `ai`: the required Nex packages included in this standalone repository. The shared backup/theme changes are already applied. Do not reapply `patches` here.
- Root `README.md`: clone/build/download instructions. `TEST_RESULTS.md`: actual validation and historical failures; historical PASS entries are not proof of current usability.
- GitHub Release: downloadable installer, source snapshot and SHA-256 checksums for the corresponding version and commit.

The original extracted Flutter Right Panel is the shell implementation base. The original `raminturne/right-panel` repository is a read-only visual/behavioural reference for edge reveal, liquid motion, springs, hover magnification, active pill, flyout, tray and shortcuts. Nex owns domain behaviour and data. Do not replace Nex repositories/schema with a second note store or copy Android domain logic into a competing implementation. Preserve attribution and the established fonts/tokens. Do not push to either upstream repository.

## What the next agent should achieve

Continue towards a dependable Windows Nex app, prioritising the owner's actual usage reports over passing probes. The owner already encountered an invisible panel, controls that painted but did not receive clicks, unwanted auto-hide while reading, confusing cancel/success messages and poor shadows/spacing. Those repairs are implemented; prevent regressions. Keep the persisted panel pin separate from a note's pin. Reading, typing, file selection, menus and recording must keep the panel usable. Notes must save immediately and survive closing/reopening and normal exit.

Before treating the app as 1.0-ready, complete real Windows validation of microphone recording, positive chooser/clipboard imports, repeated use and shutdown, multi-monitor/mixed-DPI/hot-plug, usable-panel latency and a large library. Windows reminders/toasts, backup restore UI and other Android parity gaps remain explicit work; assistant/Vault and sync/OCR/on-device AI are not silently complete. Expand scope only when requested or necessary for the intended Windows Nex experience. Preserve the original liquid/spring shell while improving usability with Nex design tokens.

## Synchronisation and release discipline

The source on `main`, Windows version strings, About screen, executable version resources, installer version/name and latest GitHub Release must agree. Build the full Windows runtime from that source and keep the same installer AppId/data paths so updates retain existing notes/media/settings. Publish the built installer with the matching source snapshot/checksums and point the release tag at the source commit. Never rename an old installer and call it a new build. Never report unrun hardware checks as passed. Preserve the earlier test results as history.

## Existing implementation and evidence

# Nex Windows — 2026-10-02

Nex base: **4861feac41530c951cb9e637ff921c6472d7de58**, Android **1.92.1**. Toolchain: Flutter **3.35.5 / Dart 3.9.2**, Windows x64. The owner confirmed this workspace is the extracted `right_panel_flutter.zip`; it is the implementation base. Canonical Right Panel was inspected read-only at **90dcdbde8e33816f08b681c65cd341aa796f81e4** and remains unmodified. MIT attribution is included.

The latest desktop is **0.9.0+5**, with separate unsigned installer **Nex-Windows-Setup-0.9.0-x64.exe**. It adds a persisted panel pin, protects typing/reading/pickers/menus/recording from auto-hide, replaces note dialogs with an inline reader/edit flow, and improves glyphs, spacing, fills and shadows. The active pill paints beneath its icon. Separate image/audio/file choosers show errors and report cancellation honestly. Unclickable lower controls were caused by Opacity bounds preceding the flyout translation; transformed hit testing now works on both physical edges. Windows audio session activation is disabled for the desktop player; a copied WAV actually played to completion.

Nex owns notes, schema/migrations, UUIDv7, revisions/tombstones/FTS, capture, tags/threads and the backup codec. One serial database isolate handles operations; text saves on every change and drains before exit. The app includes text/checklist/image/file/audio capture, lazy timeline, search/filtering, pin/delete/undo/trash, inline detail/edit, tags/threads, Persian RTL/fonts/calendar, shared themes and full-backup export. AI is a removable stub with zero desktop `nex_ai` imports. Vault is absent. Retained utility snippets, clipboard previews and shell preferences are separate from Nex notes.

The mandatory shell repairs preserve original spring constants: measured/clamped flyout height, physical-edge mirroring independent of RTL, viewport-responsive dock, correct clock offsets, owned/cancellable native workers and dialogs, platform-thread events, safe bridge/messenger destruction and cancelled Dart delays. Release packaging includes every Flutter/plugin/runtime asset.

Build this standalone repository directly: its four required Nex packages and shared changes are already included. The two files in `patches` are historical integration patches for a separate clean upstream Nex checkout at the recorded base; do not apply them to this repository. Those patches were previously checked in a fresh detached upstream checkout. Run/build instructions are in `apps/desktop/README.md`.

Final validation: analyzer clean; **32 tests, 10 normal golden comparisons**, full Release and installer built; real Windows codec/import check decoded a 480×680 image and played a 2,000 ms WAV to completion; installed update exit 0 and all 37 payload hashes match. A live click opened the image chooser. Source ZIP has CRC/layout/cache/binary exclusion checks. Exact outcomes and historical failed probes are in `TEST_RESULTS.md`.

Limits: microphone hardware, positive UI file selection/clipboard flows, mixed DPI/hot-plug, picker shutdown races, moving side-by-side parity and performance targets still need manual checks. Windows reminders/toasts, backup restore UI, assistant/Vault and sync/OCR/on-device AI are absent or out of scope. Nex's readable full-backup library with encrypted private settings, and its Persian normalization limitations, are preserved and documented.
