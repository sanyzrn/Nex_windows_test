# Windows 0.23 agent work — review summary

Working branch: `windows/0.23-agent`; base `2076ad4`. Release prepared as **0.23.0+17** after the owner authorized merge/publication for manual testing on 2026-10-21.
Implementation commits: `7173404`, `9cd6bdb`, `5c79990`, `d9e9211`, `9b0bd22`; Windows visual refreshes: `a4f487c`, `13d34a1`, `d0ea0d8`, `d8de9a3`.
A2 refresh run `39455265050` passed with no baseline changes.
A3 final refresh run `39498530568` passed; all 52 updated images were reviewed.

| Item | Status | Evidence / remaining work |
| --- | --- | --- |
| A1 translation audit | Implemented; local tests and Windows visual refresh passed | [Report](A1.md), 191 desktop tests, 16 checker tests, shared-package checks, 16 renders |
| A2 accessibility | Implemented; local tests and Windows visual refresh passed | [Report](A2.md), 205 desktop tests, 18 checker tests, shared-package checks, 16 focus renders; no Windows baseline changes |
| A3 minimum size/text scale | Implemented; local tests and Windows visual refresh passed | [Report](A3.md), 551 desktop tests including 336 layout cases and 10 scaled-control regressions; 52 Windows review additions; 44 before/after renders |
| A5, A7, A8, A10 | Completed in Part 4 | [Report](PART4.md); cleanup/docs/templates; 552 existing tests + 6 focused additions, analysis and guards passed |
| A4, A6, A9, A11, A12 | Completed in Part 5; Track A complete | [Report](PART5.md); offline history, digits/calendar, installer review, 76 compact Windows scenes, standalone formatting |
| B0–B3 | Implemented in Part 6; device limits remain | [Report](PART6.md), [34-item manual triage](B0.md), live Windows PR checks |
| B4–B7 | Implemented; full Windows CI passed; manual checks with owner | [Report](PART7.md), final PR checks and explicit device limits |
| B8 optional modules | Deferred by owner | No implementation in 0.23.0 |

Source, tests, glossary, changelog and reports are committed together and pushed
after each completed part. The owner authorized merging Parts 1–7 and publishing 0.23.0 for manual testing; B8's four core modules were subsequently selected; see [B8](B8.md).
No private data, credentials, backup/schema changes or Android source changes.

Windows screenshots were reviewed. Parts 1–6 passed comparison/build/native
smoke/installer/update checks; the final Part 7 PR checks supply current automated
evidence. Real DPI/notification/Narrator, Android round trips and representative
hardware profiling remain open. Refresh success alone is not full sign-off.

Parts 1–6 have passed Windows CI. Part 7 was approved and implemented; its final checks and manual limitations are recorded in PART7.md. Optional B8's four core modules were subsequently selected; see [B8](B8.md). Parts 1–7 are collected in [PR #9](https://github.com/sanyzrn/Nex_windows_test/pull/9);
Windows CI and manual limits are recorded in Part 5 and the PR checks.
Release automation publishes only after successful main-branch Windows CI for the exact release commit. Manual testing remains open and is owned by the user.

Final Part 7 source verification: [Windows run 39589605793](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39589605793), commit `4095fd9`: 856 desktop tests, shared UI 280, core 250, data 294 with 14 existing skips, AI 184, desktop without local inference 662; Release/native/installer/update checks passed.

Release preparation: version 0.23.0+17 declarations passed local consistency checks; Windows refresh [39608500545](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39608500545) passed and all eight changed About/history images were reviewed. Final main-branch CI and release URLs are recorded in PR #9.
