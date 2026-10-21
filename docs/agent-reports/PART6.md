# Part 6 — Windows reliability (B0–B3)

Base: `bb47bd9`; branch `windows/0.23-agent`. Owner approved this bundle.

## Plan
- Carry forward the 34 installed-device checks with explicit automation/manual status.
- Preserve Flutter editing/IME/undo semantics; mitigate active-paragraph direction without modifying text.
- Intercept close before plugins, add opt-in tray retention and restore compact placement only when hidden.
- Add version-checked reminder actions and harden overdue reconciliation; keep schema/archive formats unchanged.
- Extend native smoke coverage and run focused checks, then Windows CI; report physical-device limits.

Implementation and verification in progress. No merge, version bump, tag or release.
