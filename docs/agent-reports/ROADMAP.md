# Windows agent roadmap

Source: the owner's supplied `WINDOWS_AGENT_PROMPT.md`. The owner explicitly
authorized adapting Windows-specific setup to this Linux environment, and asked
for a report, commit and push after each part, followed by approval before the
next part. No approval to merge, tag or publish a release is implied.

Base: `2076ad466aeb8b31e9fa7caf18a43156ae87b114` (`main`, 0.22.0+16).
Working branch: `windows/0.23-agent`. Android reference: separate read-only
`DbsNex` checkout. Existing checkouts and their uncommitted work are untouched.

Each row is a review boundary. A large row can be divided into smaller parts,
with the same approval boundary. A6 is intentionally last in Track A: its own
instruction requires formatting only after the other A work is complete.

| Part | Work-order item | Scope | Status |
| --- | --- | --- | --- |
| 1 | A1 | Translation parity, visible strings, Persian glossary | Implemented; verification recorded in A1.md |
| 2 | A2 | Accessible labels, focus rings, LTR/RTL focus-order tests | Awaiting owner approval |
| 3 | A3 | Minimum window and text-scale overflow sweep | Not started |
| 4 | A4 | Compact review screenshot matrix | Not started |
| 5 | A5 | Proven dead code, unused strings, stale documentation | Not started |
| 6 | A7 | Current architecture, README and shortcut documentation | Not started |
| 7 | A8 | Issue forms and PR/contributor checklists | Not started |
| 8 | A9 | Persian release notes in the updater | Not started |
| 9 | A10 | Coverage-driven tests for existing pure logic | Not started |
| 10 | A11 | Persian digits and calendar consistency | Not started |
| 11 | A12 | Installer review and safe polish | Not started |
| 12 | A6 | Standalone formatting commit | Not started |
| 13 | B0 | Windows verification checklist and triage | Not started; native checks need Windows |
| 14 | B1 | Mixed Persian/English editing and selection | Not started |
| 15 | B2 | Close preference, tray lifecycle and corner restoration | Not started |
| 16 | B3 | Reliable reminder delivery and toast actions | Not started |
| 17 | B4 | Distinctive Windows appearance and integration | Not started |
| 18 | B5 | Android AI parity: capabilities, models, YouTube | Not started |
| 19 | B6 | Backup, onboarding, settings and update handoff | Not started |
| 20 | B7 | Keyboard/Narrator, performance and localization completeness | Not started |
| 21 | B8 | Optional modules and Windows extras | Not started; module selection required first |

No data schema or backup format changes. No version bump until requested.
Draft PRs are due at the end of each track, as specified in the work order.
Manual Windows results, Narrator, installer tests and real Android backup
round-trips cannot be claimed from Linux. Where possible, existing Windows CI
can provide automated evidence; physical-device checks remain explicitly open.
