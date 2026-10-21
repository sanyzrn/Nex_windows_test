# Windows agent roadmap

Source: the owner's supplied `WINDOWS_AGENT_PROMPT.md`. The owner explicitly
authorized adapting Windows-specific setup to this Linux environment, and asked
for a report, commit and push after each part, followed by approval before the
next part. No approval to merge, tag or publish a release is implied.

Base: `2076ad466aeb8b31e9fa7caf18a43156ae87b114` (`main`, 0.22.0+16).
Working branch: `windows/0.23-agent`. Android reference: separate read-only
`DbsNex` checkout. Existing checkouts and their uncommitted work are untouched.

## Compact plan — owner revision, 2026-10-21

The owner requested fewer parts, lower token use, related work together, short
reports and only necessary tests. This replaces the old 21-part schedule without
dropping required work-order items. Parts 1–6 are implemented and their Windows checks passed. The owner approved Part 7; its implementation and final verification are tracked below. Optional B8 remains a separate decision. The old part numbers
4–21 are superseded; A/B identifiers still refer to the original work order.

Each remaining row is one approval boundary. Finish related work in that row,
write a short report, commit and push, then wait for approval before the next row.
Do not split a row into more approval steps unless a concrete blocker requires
an owner decision. Internal commits may separate unrelated changes.

| Part | Work-order item | Scope | Status |
| --- | --- | --- | --- |
| 1 | A1 | Translation parity, visible strings, Persian glossary | Implemented; verification recorded in A1.md |
| 2 | A2 | Accessible labels, focus rings, LTR/RTL focus-order tests | Implemented; verification in A2.md |
| 3 | A3 | Minimum window and text-scale overflow sweep | Implemented; verification in A3.md |
| 4 | A5, A7, A8, A10 | Repository cleanup, architecture/README/shortcuts, contributor templates and focused pure-logic coverage | Completed; [report](PART4.md), focused checks recorded |
| 5 | A9, A11, A12, A4, A6 | Persian updater notes, digits/calendar consistency, installer polish; complete the screenshot matrix after these changes, then format | Completed; [report](PART5.md); closes Track A |
| 6 | B0, B1, B2, B3 | Triage remaining Windows checks; mixed-language editing, close/tray lifecycle, corner restoration, reminders and toast actions | Implemented; [report](PART6.md), CI result in PR checks; physical checks in [B0](B0.md) |
| 7 | B4, B5, B6, B7 | Windows appearance/integration, Android AI parity including models/YouTube, backup/onboarding/settings/update handoff, final accessibility/performance/localization checks | Implemented; [report](PART7.md), final Windows checks pending |
| Optional | B8 | Owner-selected modules and Windows extras | Deferred; selection and approval required before implementation |

A6 stays last in Track A and remains a standalone formatting commit inside Part 5.
A4 still covers all requested settings subpages, reader variants and states; batch
generation and concise contact-sheet review avoid repeating the same captures.
Part 7 includes the final B7 check after its feature changes. B0 records unresolved
native checks early, and later parts update that same checklist.

## Lean execution and verification

- Read only the files and original requirements needed for the current bundle.
  Reuse recorded findings and fixtures; avoid repeating completed audits.
- Run checks for the changed behavior and its affected callers. Add a regression
  only for a reproduced defect or material risk. For A10, use existing coverage
  to choose important uncovered pure logic; do not chase a coverage percentage.
- Skip redundant test runs, duplicate scenarios, cosmetic-only tests and tests
  that merely mirror implementation. Preserve existing useful regression tests;
  do not delete them just to reduce test counts or remove a failing check.
- For documentation-only changes, check links, scope mapping and diff hygiene;
  do not run Flutter tests. For source changes, analyze affected packages and run
  focused tests. Broaden only for shared-code impact, failures or unresolved risk.
- Consolidate broader regression checks at track completion when needed; do not
  repeat unchanged suites after every edit. Keep required repository/CI checks.
  Batch Windows visual refreshes after relevant UI changes stabilize.
- Use a short report per bundle: changes, verification actually run, remaining
  blockers and commit. Keep evidence where it helps review; no repeated long
  narratives, duplicate screenshots or extra report files for routine steps.
- Report unavailable Windows/manual checks honestly and carry them forward.
  Required native verification is not removed to save tokens.

The owner approved Part 7. B4–B7 implementation is recorded in PART7.md; final Windows CI and physical-device limits are tracked there. Stop before optional B8.

No data schema or backup format changes. No version bump until requested.
Draft PRs are due at the end of each track, as specified in the work order.
Manual Windows results, Narrator, installer tests and real Android backup
round-trips cannot be claimed from Linux. Where possible, existing Windows CI
can provide automated evidence; physical-device checks remain explicitly open.
