# 0.28 release — Windows visual baseline correction

The owner merged the 0.28 feature branch, then reported failed CI. Main run
[39930646393](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39930646393)
passed **881 tests** and failed **41**, all pixel comparisons in
`review_screens_test.dart`. No other assertion, layout overflow or behavior
failure appears in that job. Analysis, version consistency and UI hygiene passed.
Installer/build and publication were consequently skipped.

Cause: the 0.28 Library date filter, version/build line and release notes changed
visible pixels while the reviewed Windows images still described 0.27. The source
merge contained the intended behavior changes; this correction does not remove or
weaken tests, change visual tolerances, or change app/shared-package/data code.

The release notes are now dated 2026-10-23 in both languages and the README labels
0.28.0+22 as the current source version. Version/resource/installer values are
unchanged. Requested regeneration on the existing Windows workflow:
[39933957571](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39933957571),
Flutter 3.44.8. No Linux golden regeneration.

## Completed visual verification

- Windows refresh run passed all **226** golden/review tests and committed
  `b59c02ff8eb8b442e132a853e0e15ff23acccd32`.
- Exactly the same **41** image paths that failed changed; no additional image
  changed, and every image retained its dimensions. All are review images:
  **33** Library filter-bar views, **4** About version/build views and **4**
  release-note views. Application/behavior tests and comparators are unchanged.
- Reviewed all 41 before/after difference crops in six contact sheets, plus full
  Persian/dark release notes and English/light minimum-size 200% text views.
  Differences match the added date pill, 0.28.0/build 22 and dated release notes.
  Release notes retain readable RTL text, scrolling content and visible Close.
  Compact filter rows retain their existing horizontal scrolling.
- Localization parity, EN/FA release-history headings/bullet counts, diff
  whitespace and bounded-file review passed. No local Flutter or Windows
  execution is claimed for this correction; generation happened on Windows CI.

The correction is ready for main's full Windows comparison/build/installer/update
pipeline. At this report commit, that exact main run and automatic publication
are still pending. Publication remains gated by successful full CI; no manual
bypass or prebuilt replacement asset is used. Physical Windows/phone acceptance
and performance measurements remain distinct from CI evidence.
