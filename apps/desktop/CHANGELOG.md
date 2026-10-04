# Changelog

## 0.11.0 (2026-10-04)

### Upstream Alignment & Architecture (WP1, WP2)
- Vendored upstream `DbsNex` 1.93.0 packages at recorded SHA (`packages/core`, `packages/data`, `packages/ui`, `packages/ai`).
- Validated shared patches 01 and 02 with clean `git apply --check`.
- Renamed desktop package from `right_panel` to `nex_desktop`.
- Modularized native runner into focused translation units (`native_common`, `native_startup`, `native_hotkeys`, `native_tray`, `native_window`, `native_clipboard`, `native_pickers`, `native_notifications`).
- Modularized Flutter state and views under 500 lines per file (`features_state`, `capture_view`, `library_view`, `note_detail_view`, `panel_settings`, `panel_geometry`, etc.).
- Tagged golden tests and created GitHub Actions CI workflow with AI-removal verification.

### Desktop Parity Gaps (WP3)
- **Durable Reminders & Notifications:** Integrated WinRT `ScheduleToastNotification` / `CancelScheduledToastNotification` with AppUserModelID `Nex.Desktop.App`. Implemented pure Dart reconciliation engine. Reminders fire even when the app is closed.
- **Backup Restore Flow:** Full support for restoring `.nexbak` and encrypted `.nexfull` backups with recovery key, atomic SQLite staging, and safe settings reload.
- **Link Notes:** Added streaming link reader with 256 KB memory cap, 8-second timeout, Open Graph `<meta>` title/description priority over HTML title, and safe entity unescaping.
- **Commitments:** Added recurring obligations viewer and dialog with Persian Saturday-first weekday calendar.
- **Android Parity:** Enforced safe link scheme whitelist (`http`, `https`, `mailto`, `tel`) and Android copy precedence rule (caption > transcript/OCR > text content up to 50k chars > display text).

### Window Mode Desktop Experience (WP4)
- **Responsive 2-Pane Layout:** Automatically shows dual pane (timeline list + detail editor) on displays >= 900px with draggable divider and persisted width.
- **Keyboard Shortcuts:** Global and focused shortcuts: `Ctrl+N` (New note), `Ctrl+Shift+N` (New checklist), `Ctrl+F` (Search), `Ctrl+L` (Library), `Ctrl+,` (Settings), `↑`/`↓` (List navigation), `Enter` (Open note), `Esc` (Close reader/clear search), `Delete` (Delete with Undo), `Ctrl+Z` (Undo deletion), `Ctrl+P` (Pin/unpin), `Ctrl+C` (Copy).
- **Shortcuts Dialog:** Built localized shortcuts reference dialog (`F1` or `Ctrl+?`).
- **Context Menu & Multi-Select:** Right-click context menu on note cards (read, pin, copy, remind, delete) and multi-select with bulk action bar.
- **Reminder UI:** Quick reminder picker (later today, tomorrow morning, custom date/time, repeat options) and reminder badges on note cards.

### Premium Desktop UI/UX Redesign
- **Window Shell & Navigation Rail:** Elevated branding with glowing gradient logo pill, Windows 11 Fluent 2 / Linear style navigation pills with keyboard shortcut badges (`Ctrl+N`, `Ctrl+L`, `Ctrl+,`), live theme switcher, F1 shortcut launcher, and panel mode quick-switch.
- **Unified Command Bar & Filter Bar:** Integrated search pill with shortcut badge and horizontal filter capsules (All Notes, Type dropdown with icons, Tag pills with color indicators, Thread selector, Trash toggle with danger styling, and filter reset).
- **Desktop Hero Capture Card:** Elevated desktop card with emerald local persistence indicator, keyboard shortcut badges, checklist switcher, and clean outlined action triggers.
- **Document Detail & Reader:** Fluent document header with back navigation, type badge, pin toggle, and modern outlined action buttons (Copy, Open, Remind, Pin, Delete).
- **Design System Polish:** Refined keycap shortcut badges, rounded dialogs (`16px`), smooth splitter hover micro-interactions, floating bulk action toolbar, and full RTL/LTR Persian & English parity.
