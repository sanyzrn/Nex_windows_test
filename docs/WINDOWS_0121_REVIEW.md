# Windows 0.12.1+9 validation — 2026-10-14

The reported panel, library and settings paths were inspected through their Flutter widgets, interaction controller, database worker and native Windows host. This report records tested behavior rather than claiming every possible bug has been eliminated.

## Changes

- Outside click dismisses a sticky or focused reader; explicit panel pin and modal/file pickers remain protected. Global mouse button release is tracked while closed so reopening cannot lose the next click.
- Hover switches dock tools while a reader is open; true modal routes and active drags still block it.
- Display labels come from the Windows `DISPLAYn` device name. The selected device name is saved and resolved again when enumeration order changes.
- The library exposes tag creation, search, rename and deletion. Deletion removes associations and keeps notes.
- Success/Undo notices expire after four seconds and replace older notices. Undo holds the data service, so it works after leaving the originating reader.
- Recently deleted cards hide pin/reminder badges, cannot open an editor/context menu, and offer restore. Restore retains original note metadata.
- Checklist preview ticks change their original source index even when done items are sorted below. The reader refreshes when its note changes externally.
- Panel and desktop settings show one category at a time. Tool placement uses search, short pages, and Dock/More/Hidden controls; custom app/folder launchers are included.
- The custom caption supports native drag, double-click maximize, right-click system menu, minimize, restore and close. Maximize fits the monitor work area, and minimizing preserves the normal saved frame.
- The installer has a dark title bar, geometric Nex artwork, and mirrored Persian/English pages.

The host retains native frame styles and handles client sizing/hit testing before Flutter, using the [Microsoft custom frame guidance](https://learn.microsoft.com/en-us/windows/win32/dwm/customframe). Setup uses the supported [Inno WizardStyle](https://jrsoftware.org/ishelp/topic_setup_wizardstyle.htm) dark/title-bar modifiers.

## Evidence

- Desktop: **174 tests passed**, including the 44-image review matrix, Persian/English, large text, mode transitions, reminders, clipboard persistence, search and backup/restore.
- Shared UI: **190 tests passed**.
- Flutter analyze and UI hygiene: passed; no issues.
- Release native probe: three window/panel cycles, left/right hover, focused capture, non-modal reader hold, pinned panel, native minimize/maximize/restore, matching Flutter/native sizes; no Flutter errors.
- Maximized native client and Flutter view both measured **1920 × 1032**, equal to the available monitor work area. The minimized saved frame retained **1180 × 780** and normal coordinates.
- The installer compiled successfully with Inno Setup 6.7.3. Its Persian and English welcome pages were inspected in Windows and cancelled before installation.
- Packaged executable hash matches the tested Release executable. Production sources match the build snapshot, normalizing generated localization line endings.

[Native probe report](../design/product/0.12.1/panel-report.json) · [Release window](../design/product/0.12.1/window-release.png) · [Panel tool settings](../apps/desktop/test/review_goldens/settings_tools_panel_dark_fa.png)

## Artifact

`Nex-Windows-Setup-0.12.1-x64.exe` is in the workspace root (14,111,807 bytes).

SHA-256: `e61f5e4e487780b0ed738dda7236e5e51c553b1d57ecd197e544f42abf42cd87`

Installers are generated artifacts and excluded from Git; their source, assets, regression tests and validation report are committed. The tested installer is published in [release v0.12.1](https://github.com/sanyzrn/Nex_windows_test/releases/tag/v0.12.1) with its exact checksum.

## Limits

This machine currently has one physical monitor. Reversed enumeration and saved device identity were tested with simulated two-display inputs; physical dual-monitor hot-plug and mixed-DPI switching remain hardware checks. The setup was previewed, not installed over the user's application. The previous reminder limit for generating future repeating occurrences while the app is fully exited remains outside this repair.
