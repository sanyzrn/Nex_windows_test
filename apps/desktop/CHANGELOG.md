# Changelog

## 0.22.0 — 2026-10-19

- Shared packages (core, data, ui, ai) brought level with Android 2.1.9:
  automatic AI capability detection and model list, fused search ranking,
  link and recurring-item fixes. The desktop app now requires Flutter 3.44.
- New compact window: Nex opens as a tall portrait card in the bottom-right
  corner of the screen, always at the same size, and returns to that corner
  each time it is opened from the tray. It can still be resized or maximised;
  turn on Settings > Display > Remember window size and position to reopen at
  the last frame instead. The edge panel is unchanged.
- New window look: a surface tinted by the theme accent, a rounded content
  card, a caption without its own bar, and a slim navigation rail of icons over
  labels (Capture, Library, Intelligence, Tools, Settings) with a More menu for
  the edge panel switch, theme and shortcuts. Wide windows keep the labelled rail.

## 0.21.1 — 2026-10-19

- Close the desktop window to System Tray instead of stopping Nex, and
  restore with Open; exit cleanly only through Tray > Quit.
- Add live reminder delivery fallback for Windows while Nex stays resident;
  track one-off and daily/weekly notification receipts after actual attempts.
- Use a genuine Saturday-first Solar Hijri date picker for reminders whenever
  Solar Calendar is enabled; save the equivalent standard Gregorian date.
- Hide inoperative Grid/List controls in panel and narrow library layouts.

## 0.21.0 — 2026-10-19

- Add automatic update checks and background downloads from the latest stable
  GitHub release. Verify asset origins, sizes, GitHub digests and SHA256SUMS;
  offer Install & restart only after a complete, checked download.
- Save and close Nex before installing. A standalone native helper waits for
  the application to exit, locks and verifies the installer again, preserves
  the installation directory and language, then restarts Nex.
- Rebuild Intelligence around an overview, separate provider configuration,
  capability cards and progressively disclosed privacy and response controls.
- Bring Android's rounded tonal groups, icon badges, settings directory,
  visual appearance choices and colored utility cards to the Windows workspace.
- Move note intelligence below the writing, with compact circular actions and
  translation/rewrite options shown only when needed.

## 0.20.0 — 2026-10-18

- Bring Android 2.1.6 cloud adapters and action protocol to Windows: Anthropic,
  OpenAI, Gemini, OpenRouter and custom OpenAI-compatible endpoints. Keep
  separate model, image, audio and embedding settings for each provider.
- Add an Intelligence workspace with conversations, note context, image
  attachments, voice questions, source links, semantic search and a daily brief.
- Add note summaries, translation, six rewrite styles, tag suggestions, image
  OCR and audio transcription. Preview outputs before saving or replacing text.
- Keep AI off until explicitly enabled with cloud consent. Encrypt API keys in
  Windows secure storage; verify the exact configuration before activating it.
  Separate note-read, write-proposal and private-cycle permissions. Review all
  proposed changes before execution; database batches validate and commit together.
- Introduce a tag-colored card gallery with separate pinned and recent shelves,
  responsive list/reader modes, light/dark colors and large-text support. Color
  selection is stable and secondary text retains accessible contrast.
- Include an honest on-device-model placeholder for future runtime/model work.
  Local inference and live device synchronization are not enabled in this release.
- Expand CI with shared cloud-adapter and desktop AI regression tests. Continue
  automatic publication of the exact tested Windows installer and SHA256SUMS.

## 0.15.0 — 2026-10-18

- Align the portable note/attachment schema with Android 2.1.4, retaining tags,
  reminders, pins, scheduled notes and private module tables in database backups.
- Restore Android full backups even when renamed or carrying a mobile-only AI
  model; export an Android-valid shared-appearance envelope. Device IDs, OS
  permissions, clipboard integration and mobile credentials remain local.
- Match all 14 theme IDs, seeds, surfaces, base colors and motifs. Add shared
  custom accent, system theme/language, text scale and calendar preferences.
- Read and add attachments in the desktop note reader; include their text in
  search and protect their files from orphan cleanup and purge of shared media.
- Show and edit legacy text/checklist captions from Android. Include live extra
  attachments in the workspace file count, respecting removal, Undo and trash.
- Normalize Windows/POSIX paths when importing portable media. Reject newer
  schema versions and malformed shell settings before replacing the live library.
- Add Android-produced archive fixtures and independent Android-reader checks,
  plus a versioned portable contract for future iOS implementations.
- Live multi-device synchronization is not enabled by backup compatibility.
  See `docs/CROSS_PLATFORM_0150.md` for supported and unimplemented boundaries.
- New Windows versions publish their verified installer and checksum to GitHub
  Releases automatically after the complete main-branch CI succeeds.

## 0.14.0 — 2026-10-18

- Rebuilt the notebook workspace with a balanced writing/pinned layout, recently
  updated note grid, useful tool shortcuts and visible local-save feedback.
- Refined navigation, desktop-size capture controls, categorized searchable
  tools, a focused reader surface and one clear active-note outline.
- Preserve unsaved text after a failed flush; drain late input before rotating
  a capture. Restoring a backup resets the active capture only after success.
- Reader edits stay in sync with the active composer; caption updates preserve
  the caret. Quick-pasted links cannot be overwritten by the next thought.
- Fixed first-run navigation, All filter menu choices, hidden-tool visibility,
  editor keyboard ownership, pending calls during store shutdown and worker exits.
- Countdown timers catch up after Windows sleep; shell preferences keep a
  recoverable last-valid snapshot. Failed full-backup unpacking cleans staging.
- Link previews have a total read deadline, canceling continuously streaming
  responses instead of allowing each chunk to restart an idle timeout.
- Added focused data-loss, restore, navigation, filter and timer regressions.
- Release evidence and remaining native checks: `docs/WINDOWS_0140_REVIEW.md`.

## 0.13.0 (2026-10-14)

The Android-parity release: the whole interface was reworked to match the
phone app's design language, and a review pass fixed every defect found
along the way.

### Design
- The dark theme is the Android app's deep-sea navy (page `#0C141F`, cards
  `#182230`, sky-blue accent `#7CB9FF`); the light theme is the matching cool
  off-white. Every contrast floor the token tests hold still holds on the new
  ramp.
- The window paints the Android app's quiet wave motif behind its content,
  skipped in high-contrast mode.
- The capture page lost its kitchen sink: the status row, its dividers and
  the leading "New note" button are gone. One clean card, the composer, a
  compact footer, and 36px action buttons instead of 52.
- The home header is one line — title and three small counters — and the
  quick-tool buttons moved out (they all live in Tools).
- Tools tiles carry the Android grid's per-tool coloured icon chips (sky,
  amber, violet, teal, rose…), a capsule search field and tighter spacing.
- Library search is a capsule; the selection banner uses compact 34px
  actions and a flexible count so it never overflows a narrow pane.
- Everything is smaller and closer together: 36px title bar, 204/64px
  navigation rail, 40px rail rows, 76px note cards (was 80 + wider gutters),
  36px outlined buttons and lighter inputs — with every keyboard focus ring
  and contrast floor kept.

### Fixed
- A tool removed or renamed across versions crashed the whole Tools section
  at startup; stale persisted ids now resolve to removable ghost entries.
- Two identical checklist lines (same words, same state) could not be ticked
  separately — the second checkbox always toggled the first item.
- Ctrl+P could call `setState` after the library closed; the reminder picker
  could use a deactivated element after the view unmounted.
- The home's stats row and the composer footer overflowed at window widths
  below ~420px.
- Note thumbnails on the home shelf decoded full-resolution camera photos;
  they decode at thumbnail size now.
- The library pane width preference was written on every drag frame; it is
  written once, when the drag ends.
- The selected card's outline no longer cuts across the card's own corners.

### Verified
- On Windows: 178 desktop tests (including visual baselines), 192 shared-UI
  tests, 198 core tests and 199 data tests pass; 14 data tests are skipped.
  Analysis and the UI hygiene gate pass on Flutter 3.44.8.
- New regression tests cover the stale-tool fallback, the duplicate-checklist
  toggle, the wave backdrop and the narrow-window overflow fixes.
- Reviewed Windows visual baselines are committed; CI compares against them
  without regenerating expected results. Tag-management tests wait for
  asynchronous database/UI completion rather than relying on a fixed delay.

## 0.12.1 (2026-10-14)

- Reliable outside-click panel dismissal and hover between readers and tools.
- Windows display labels use the actual display device number.
- Create, rename, search and delete tags from the library.
- Deleted notes offer only restore; Undo notices expire.
- Interactive checklist previews and refreshed reader state.
- Categorized compact settings with tool search and placement controls.
- Custom desktop title bar and a minimal dark installer.

## 0.12.0 (2026-10-04)

### Upstream truth and CI
- Vendored packages replaced with DbsNex at `b00fcddf50ddee90231f6753b4fed7d8b3a9e250` (Android 1.93.3); the two shared patches were regenerated against that SHA and apply cleanly.
- Copy from the reader keeps line breaks (`NexSelectableLines`), and new tags pick the least-used of twelve accent colours, matching Android 1.93.2.
- CI no longer downloads packages from a mirror; Flutter is pinned to the same stable DbsNex uses, and new steps fail on version drift, `Color(0x…)` literals and hard-coded UI strings.
- Documentation reconciled: one upstream base recorded everywhere, a claims audit in the hand-off, and every check labelled with the toolchain it was observed on.

### Interface quality (the visible round)
- Settings no longer shows its title twice; long pages scroll with a visible fade and affordance instead of cutting off.
- The panel card no longer leaps between views: one fixed anchor with a smooth height spring for every view.
- The reader was rebuilt: metadata with a visible separator that reads correctly in Persian, one uniform action toolbar instead of unequal wrapped buttons, and a real empty state instead of blank space.
- Capture action tiles use the same theme-aware component in light and dark with WCAG-AA contrast; the local-save indicator uses the theme instead of a hard-coded green.
- Emoji panel: aligned search controls, larger category targets with hover/focus states, and an edge fade instead of a half-cut last row.
- The dock keeps one shape language and one accent rule in both themes; window-mode rail items show visible focus rings.
- Every icon-only control has a tooltip, and every colour and string now comes from nex_ui tokens and the ARB files.

### Code health
- Files over 500 lines split into cohesive units; the "under 500 lines" claim is now true and tested.
- Version `0.12.0+8` lives in one place and a test fails when any file drifts.
- Window-mode goldens (1200 px, en/fa, light/dark) added; goldens render with real shadows.

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
