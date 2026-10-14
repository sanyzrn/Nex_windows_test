# Windows 0.13.0 review — the Android-parity redesign

Windows promotion validation: **2026-10-14**, Flutter 3.44.8 / Dart 3.12.2.
The supplied source report described a Linux review; the Windows validation
below was independently run before replacing 0.12.1.

## What this release is

The owner asked for a full review of the Windows app: fix every bug found,
improve stability and polish, and redesign the interface to be minimal,
compact and professional — as consistent as possible with the Android app
(DbsNex), whose screenshots were supplied as the visual reference.

The Android reference was analysed first (ten screenshots): deep-sea navy
page (`#0B1622`), cards a clear step above it (`#1C2733`), a sky-blue accent
(`#7CB9FF`), a faint wave motif behind the content, capsule search fields,
coloured per-tool icon chips in the tools grid, and noticeably tighter
spacing everywhere than the Windows app had.

## Design changes

- **The classic dark ramp is the Android navy.** Page `#0C141F`, card
  `#182230`, elevated `#2A394C`, secondary text `#93A1B3`, border `#5D7290`,
  accent `#7CB9FF` (the old accent was one unit of green away). The light
  ramp became the matching cool off-white (`#F2F4F7` page). Every
  relationship the token contract tests hold — border ≥ 3:1 on card,
  text/secondary ≥ 4.5:1 on card and page, elevated ≥ 1.3 over card,
  accent ≥ 3:1 on every ground — was recomputed for the new ramp before it
  was written; the glass wash's dark anchor moved to a navy-tinted value
  because the old neutral grey left a glass panel at 1.077:1 against the new
  page, under its own 1.08 presence floor.
- **The wave motif** (the shared package's `NexThemeTexture.waves`) paints
  behind the window's content at a low alpha over the lower ~60% of the
  page, skipped in high-contrast mode.
- **Compact chrome**: 36px title bar (was 44), 204/64px navigation rail
  (was 228/76), 40px rail rows with 4px gaps, no permanent shortcut badges
  (tooltips carry them), no "YOUR SPACE" section label, no footer text — the
  rail bottom is three small icon buttons (theme, keyboard help, search).
  The section header is one 32px-tall line with a capsule Ctrl+K button.
- **Capture is one clean card**: the status row, its two dividers and the
  leading "New note" button are gone; the composer is 16px type (was 20)
  with an 18px inset (was 28); the footer is one row (checklist, count,
  new-note) and the six capture actions are 36px buttons (was 52).
- **The home page header is one line** (title + three small counters that
  stack below it under 560px), and the quick-tool buttons above the editor
  were removed — every one of them is in Tools, one keystroke away.
- **Tools**: Android-style per-tool coloured icon chips (a token map, so no
  colour literal enters app code), a 320px capsule search field, 36px icon
  boxes, 12px tile padding, tighter grid.
- **Library**: capsule search field, compact 34px selection-banner actions
  with a flexible count, and note cards at a 76px body (was 80) with a 6px
  vertical gutter (was 8) — the standard-density pitch is 88px, down from
  96.
- **Settings**: 14px-radius cards with 14/18px padding, one line less
  vertical chrome per row, and the page is capped at 760px wide so a row's
  label and control keep reading as one thing.
- **Global**: inputs are 12/10px padded, outlined buttons 36px with 10px
  radii — which also tightens the edge-panel mode everywhere.

## Bugs fixed (each with a regression test or an existing one)

1. **Stale tool ids crashed the Tools section.** `ToolInfo.of` used
   `kTools[id]!`; a tool renamed or removed across versions left a persisted
   dock/more entry that null-checked and took the whole section down. Stale
   ids now resolve to a ghost entry the tool organizer can remove. (Tested.)
2. **Identical checklist lines could not be ticked separately.** The
   preview resolved each line's toggle by value equality, so two lines with
   the same words and state both toggled the first; the "+N" overflow count
   could also land on the wrong line. Lines are now paired with their
   original index. (Tested.)
3. **Ctrl+P setState-after-dispose** in the library: the pin store call is
   async and the view can close while it is in flight. Mounted-guarded.
4. **Reminder picker used a deactivated element** after the library
   unmounted while the picker was open: the scope is captured before the
   picker shows. Mounted-guarded after the save.
5. **Two RenderFlex overflows at narrow widths** (below ~420px): the home
   stats row pushed its title off the edge (a `Wrap` inside a `Row` does not
   wrap), and the composer footer overflowed by 6px. Both found by the new
   narrow-window regression test, both fixed (stats stack under the title;
   the count flexes and the new-note button drops its label below 420px).
6. **Selection banner overflow risk**: four full-size IconButtons plus a
   count and a Spacer in a pane that can be narrow. Now 34px actions with an
   ellipsising count. (Tested at a 360px window.)
7. **Full-resolution photo decode for 32px thumbnails** on the home shelf;
   now decodes at thumbnail size.
8. **A SharedPreferences write on every drag frame** of the library pane
   splitter; the preference is written once, on drag end.
9. **`DateTime.now()` per note per build** in the Today strip's filter; the
   clock is read once per build now.
10. **Selection ring radius mismatch** (16 vs the card's 20) — a selected
    card's outline cut across its own corners.
11. **Null-asserts on a missing panel scope** in the workspace home (build
    and note-tap paths); both are tolerant now.
12. **The dead height branch** in the wide capture layout (`maxHeight` is
    infinite when embedded) was removed; the footer's adaptive threshold is
    width-only.

## Independently verified on Windows

- Desktop and shared UI analysis: clean.
- Desktop: 178 tests pass, including golden and review screenshot comparisons.
- Shared UI: 192 pass; core: 198 pass; data: 199 pass, 14 skipped.
- Version consistency, package-host and UI-hygiene checks pass.
- Release Windows build and Inno Setup 6.7.3 packaging succeed.
- Installer and app versions both report 0.13.0+10.
- Visual baselines were intentionally refreshed for the redesign, inspected
  and then tested in comparison mode. CI now compares committed baselines.
- The tag-management test's fixed delay raced SQLite isolate completion on
  Windows under parallel tests. Bounded waits for the actual UI state fix
  the test without altering the application's tag behavior.

## Remaining manual validation

No installed-app upgrade, tray/hotkey, physical mixed-DPI multi-monitor or
post-reboot notification test was performed during promotion. Existing user
Nex was running and was not interrupted. Native runner code is unchanged
from 0.12.1. Clean-machine installs, indefinite repeating reminders while
fully exited and other documented limits are not claimed as completed.
