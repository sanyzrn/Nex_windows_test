# Desktop workspace redesign — 2026-10-09

This is the appearance phase requested by the owner, implemented in the
existing Flutter Windows application. The two modes and Windows utilities
remain available. This report does not declare the older quality brief done.

## What changed

- A 228px labelled sidebar at desktop widths, a 76px compact rail below
  1000px, and a permanent command/search entry. Navigation now uses actual
  keyboard-accessible buttons with visible focus borders.
- Capture is a bounded writing surface with a clear local-save receipt,
  a checklist/count strip, shared media actions and a scrollable layout.
  Counts use Persian digits in the Persian interface.
- Tools have an adaptive directory, a small essentials section, consistent
  line icons and a working Persian-aware filter. Clipboard, keep awake,
  calculator, timer, colour and the remaining configured tools keep their
  existing actions. Dock configuration still determines the available tools.
- Window settings expose the six existing categories individually. Large
  text changes segmented controls to vertical groups. Panel settings keep
  their scrolling overview.
- The library keeps the list/reader splitter. A reader selection no longer
  activates the multi-selection ring on every card. Empty reading space
  has a coherent state. Reader actions share one horizontal band, inherit
  the bundled font and retain readable widths; wide documents are bounded.
- Panel headers, writing surface and capture actions follow the window's
  typography and surfaces. The liquid dock and spring values remain intact.
- The panel's forced 1.0 text-scale cap and the window's 1.25 cap were removed.
  Large text now gets real layout coverage rather than silently shrinking.
- Shared workspace components live in `packages/ui/lib/widgets/nex_workspace.dart`.
  Colours come from the active Nex theme. No illustrative bitmap or decorative
  gradient was needed.

## Evidence

`before/` contains 28 fresh screenshots taken before this redesign, with the
then-current working changes included. `after/` contains 38 screenshots of the
redesigned app. The original 28 names allow direct comparisons; the additional
10 cover more window sizes, Persian text at 2.0, category pages and the palette.
Screenshots use bundled fonts and real shadows. They are Flutter renderings,
not screenshots of a native Windows title bar or Windows High Contrast.

| Screen | Before | After |
| --- | --- | --- |
| Persian dark capture | [Before](before/window_capture_1200_dark_fa.png) | [After](after/window_capture_1200_dark_fa.png) |
| Tools directory | [Before](before/window_tools_1200_light_en.png) | [After](after/window_tools_1200_light_en.png) |
| Dark library | [Before](before/window_library_1200_dark_en.png) | [After](after/window_library_1200_dark_en.png) |
| Narrow Persian settings | [Before](before/window_settings_700_light_fa.png) | [After](after/window_settings_700_light_fa.png) |
| Side panel capture | [Before](before/capture_panel_right_light_en.png) | [After](after/capture_panel_right_light_en.png) |

## Validation

Flutter 3.44.8 / Dart 3.12.2 on the owner's Windows machine.

- Desktop analysis and UI-package analysis: passed.
- UI colour/string hygiene gate: passed.
- Full desktop suite: 120 tests passed with ordinary golden comparisons.
- After the last reader-font/list selection changes, 47 affected review and
  usability tests were regenerated; ordinary comparisons were run again.
- Windows Release compilation: passed from an isolated temporary checkout;
  existing native build caches referenced another checkout and were not reused.
- The two inherited asynchronous clipboard tests were repaired to run SQLite
  work in real async time; the command-palette test now waits for route dismissal.
  Regression assertions remain. The palette also handles zero matches safely.
- Old screenshot baselines were deliberately updated for the redesign and
  then compared normally. Updating baselines alone is not counted as proof.

Installer output: `Nex-Windows-Setup-0.12.0-Redesign-x64.exe`, 13,829,419 bytes.
SHA-256: `156a09e0447143b2e8ab7f123b1f66b708f663446cf1cf66b8bfc6418204aa0b`.
Installer compilation passed; installation and upgrade were not run.

## Deliberately outside this phase

No schema/store migration, upstream package upgrade, AI implementation, updater,
new performance claim or new Windows title-bar/backdrop implementation. The
legacy handoff/CI issues found in the earlier audit are still separate work.
The matrix is a useful sample, not the exhaustive state Cartesian product in
the old brief. Screen-reader testing and an installer upgrade on a clean VM
have not been performed. The running installed Nex instance was left alone.

## Try first

1. Install the redesign installer in the repository root after closing the
   currently running Nex. Open Capture in window mode and type a Persian note.
2. Open Tools, filter for clipboard, then use keep awake and a panel utility.
3. Switch to the edge panel. Compare both physical edges and the light/dark
   themes; return to window mode through Settings. Ctrl+K opens quick commands.
