# Part 7 — final Windows bundle (B4–B7)

Base: `436bc6a`; branch `windows/0.23-agent`. Owner approved this bundle.

- B4: chose quiet writing over a translucent material: focus mode hides the rail,
  preserves the draft, shows localized word/save status and exits with Escape.
  Single-subtree section fades use NexMotion and honor reduced motion. Existing
  opaque palette surfaces remain compatible with Windows 10 and high contrast;
  no claim of Mica/Acrylic behind an opaque Flutter surface. Jump lists/taskbar
  overlays were optional design alternatives and are not implemented.
- B5: explicit connection tests automatically probe four capabilities with the
  shared Android engine and synthetic samples, displaying verdicts, HTTP status
  and refusal detail. No manual capability dropdowns or background probing.
  Modes/time/fingerprint and redacted verdict details persist with provider settings; the in-memory result
  cache includes the credential and fields, is bounded, and clears on consent
  withdrawal. Keys remain only in Windows secure storage. Provider models have a
  searchable picker with manual ID fallback; Gemini accepts custom `/v1beta`
  addresses. A standalone YouTube URL uses Gemini's native video request, without
  library context or action execution. No new indexing permission activates silently.
- B6: once-only, skippable setup offers language/theme/accent, compact versus
  remembered restoration, the existing real notification test, optional backup
  import through the existing confirmation/recovery flow and a shortcut tour.
  Background/probe launches bypass setup; completion stays Windows-local. Grouped
  settings search now indexes nested controls. Existing Android backup fixtures,
  unknown-table preservation and verified fake-update handoff are reused unchanged.
- B7: typing no longer rebuilds window chrome; small recording/status widgets
  retain independent updates. Regressions cover draft retention, welcome opt-out,
  credential-specific probe caching, model endpoints and native video routing.
  Actual desktop text, filled-button labels and navigation labels are checked at
  4.5:1 across 14 palettes in light/dark. Rail accents are strengthened over
  their tinted background; raw icon-only primary is not mistaken for a text fill.
  Existing 10k-note benchmark now enforces 500 ms first-page and EN/FA search
  ceilings; these are headless query budgets, not a physical scroll/FPS claim.

Verification: local translation parity, 18 checker tests, syntax formatting and
whitespace checks pass. Local Flutter execution remains unavailable after the
previous metadata-request automatic-review rejection; Windows CI supplies Flutter
analysis/tests/build/native/installer evidence. The first Windows analysis caught two brace hints and one unused import; corrected.
Windows refresh [39584740085](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39584740085) rendered successfully; all 31 changed/new images were reviewed.
Refresh [39585588218](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39585588218) passed; both corrected empty-writing receipts were reviewed.
Final source checks and final reviewed Windows renders will be recorded in the PR body and [checks](https://github.com/sanyzrn/Nex_windows_test/pull/9/checks), avoiding a documentation-only rerun.

Physical sign-off still needs the owner: installed notifications/DND and real
IME/DPI/multiple monitors/Narrator (see [B0](B0.md)); real Android ↔ Windows `.nexbak`
and `.nexfull` round trips with the owner's data/device; cold first-frame, 10k
scroll frame times and memory after 1000 captures on representative Windows
hardware. Automated fixture/codec tests do not substitute for those checks.
No immediate merge or new PR is required to implement this part. Keep PR #9 Draft
until physical sign-off; no schema/archive format/version change, merge or release.
Optional B8 remains deferred pending explicit selection.
