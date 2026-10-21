# Current Windows handoff

Declared app version: **0.22.0+16**. Active agent branch: `windows/0.23-agent`.
[Progress and verification](agent-reports/SUMMARY.md) and the [compact roadmap](agent-reports/ROADMAP.md)
are the current work record; this does not assert that the branch has merged or released.

- Window mode opens at 460×760 dip, minimum 380×520. Below 960 logical px use
  the slim rail; at larger text sizes it grows to fit complete localized labels.
- Capture, library, tools, intelligence and settings share the panel/window state.
  Closing the window currently quits; changing close/tray policy belongs to Part 6.
- Cloud intelligence and the GitHub updater exist. Local inference remains a
  placeholder. Do not reapply the historical integration patches.
- Data/backup formats and version declarations stay unchanged unless requested.
- Finish one approved bundle, report briefly, commit/push, then wait for approval.
  No merge, release or tag is authorized by the agent work order.

[Architecture](../apps/desktop/README.md) · [Shortcuts](shortcuts.md) ·
[Manual Windows checklist](TEST_0220.md) · [Verification index](TEST_RESULTS.md) ·
[Release process](RELEASING.md)

Earlier handoffs, timings, binaries and test totals are preserved in
[the historical handoff](archive/HANDOFF.md); they are not current validation.
