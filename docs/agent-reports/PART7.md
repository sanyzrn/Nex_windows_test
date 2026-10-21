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
  Existing 10k-note benchmark now enforces 500 ms first-page/EN/FA search
  ceilings and 128 MiB process RSS growth after its first 1000 captures; these
  headless store budgets do not claim physical scroll/FPS or GPU-memory results.

Verification: local translation parity, 18 checker tests, syntax formatting and
whitespace checks pass. Local Flutter execution remains unavailable after the
previous metadata-request automatic-review rejection; Windows CI supplies Flutter
analysis/tests/build/native/installer evidence. The first Windows analysis caught two brace hints and one unused import; corrected.
Windows refresh [39584740085](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39584740085) rendered successfully; all 31 changed/new images were reviewed.
Refresh [39585588218](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39585588218) passed; both corrected empty-writing receipts were reviewed.
Refresh [39586615755](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39586615755) passed; all 81 navigation-contrast image changes were reviewed, with unchanged dimensions and no layout regressions.
The cancellation fixtures now return valid synthetic transcription/embedding responses; automatic detection correctly stopped accepting the previous text-only mock as audio. Existing timeout/expectation strictness stays intact.
Final source checks will be recorded in the PR body and [checks](https://github.com/sanyzrn/Nex_windows_test/pull/9/checks), avoiding a documentation-only rerun.

Physical sign-off still needs the owner: installed notifications/DND and real
IME/DPI/multiple monitors/Narrator (see [B0](B0.md)); real Android ↔ Windows `.nexbak`
and `.nexfull` round trips with the owner's data/device; cold first-frame, 10k
scroll frame times and memory after 1000 captures on representative Windows
hardware. Automated fixture/codec tests do not substitute for those checks.
No immediate merge or new PR is required to implement this part. Keep PR #9 Draft
until physical sign-off; no schema/archive format/version change, merge or release.
Optional B8 remains deferred pending explicit selection.

## Visual comparison

Writing is Nex's central action, so the chosen treatment gives its editor the
rail's space while keeping the current draft and a quiet local-save receipt.
A single live editor and short reduced-motion-aware fades keep this treatment
usable with keyboard, large text and the existing Windows 10/11 surfaces.

Before (normal workspace, Part 6):

![Before](https://raw.githubusercontent.com/sanyzrn/Nex_windows_test/436bc6aac7ad8cbaf480241d5dc1f938c6059a6d/apps/desktop/test/review_goldens/redesign_window_capture_1200_light_en.png)

After (writing mode, same 1200 px light-English viewport):

![After](https://raw.githubusercontent.com/sanyzrn/Nex_windows_test/d1d8584dfec091d2b6a487221185595f4cffc85c/apps/desktop/test/review_goldens/writing_1200_light_en.png)
