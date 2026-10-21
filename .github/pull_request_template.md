## Problem and resulting behavior

Describe the concrete trigger, resulting behavior and relevant work-order items.

## Validation

Commands and results (explain unchecked/not-applicable items; do not imply a native
check passed from widget tests):

- [ ] Affected package analysis and focused regression tests
- [ ] Desktop suite/version consistency and required CI checks
- [ ] Localization parity: ARBs/placeholders and all three maps; generated l10n current
- [ ] UI hygiene and default package-host guards
- [ ] Shared UI/core/data analysis/tests when affected
- [ ] UI evidence: affected EN/FA, light/dark, window/panel, minimum/compact/wide sizes and text scales
- [ ] Intended golden/review diffs generated on Windows and reviewed without relaxed tolerances
- [ ] Windows release build and relevant `tools/windows_smoke.ps1` probes

For documentation-only edits, link/diff checks suffice locally; retain required CI.
Record unavailable manual DPI, Narrator, notification, installer and backup checks:

## Compatibility and delivery

- [ ] No note/clipboard/API-key data in logs, screenshots or commits; keys stay in secure storage
- [ ] Schema/archive compatibility preserved; no new network hosts without approval
- [ ] README/architecture/shortcuts/changelog updated when relevant
- [ ] If a version bump is authorized, all declarations and both release notes agree
- [ ] No unrelated generated files, SDK/build outputs or installer binaries committed

Agent work: commit/push each approved bundle and stop for the next approval.
Draft PRs mark track completion; merge, tag and release require owner authorization.
