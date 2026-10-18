# Nex Windows 0.14.0 — audit and implementation plan

Baseline: `1ee95d8`, 0.13.0+10. Started 2026-10-18.

## Phase 1 — data integrity and desktop behavior (P0/P1)

- Trace capture, editing, deletion/undo, import, backup/restore and shutdown.
- Prevent a failed capture flush from clearing the only editable copy.
- Keep active capture sessions consistent with edits made in the reader.
- Make session rotation safe while previous writes are in flight.
- Check stale async callbacks, store lifecycle and isolate failures.
- Verify empty-state navigation, keyboard ownership and tool visibility.
- Add focused regressions for observed failures; retain existing coverage.

Exit: focused storage and interaction tests pass, failures remain visible and
recoverable, no changes to the installed application/data identity.

## Phase 2 — a coherent desktop workspace (P1)

- Replace the scattered composer and excessive horizontal gaps with a bounded,
  intentional workspace: a useful header, writing surface, attachment actions,
  pinned notes and a recent-note grid.
- Restore explicit saving/failure feedback beside the composer.
- Refine navigation and page hierarchy, typography, spacing and focus states.
- Give tools useful categories, consistent cards and an immediate search/reset.
- Make empty, loading and error states actionable.
- Use theme colors, subtle hover transitions, no raster decoration or new heavy
  runtime dependencies. Respect reduced motion and high contrast.

Exit: capture/library/tools/settings reviewed in dark/light, English/Persian,
compact/wide and enlarged text; overflow tests pass.

## Phase 3 — release hardening (P1/P2)

- Review Windows bridge, installer, dependencies, version consistency and CI.
- Run desktop/shared-package analysis and behavior tests supported here.
- Separate portable visual regression tests from Windows font baselines so CI
  cannot silently approve old screenshots for a changed interface.
- Record exact checks, outcomes and any Windows-only validation still pending.
- Update changelog, release documentation and all version declarations together.

Exit: a reproducible 0.14.0+11 source tree and honest release readiness record.

## Phase 4 — delivery

- Commit and push the reviewed change set to a dedicated branch.
- Use Windows CI to validate the actual Release build and installer if available.
- Never describe an unbuilt installer or an untested native interaction as tested.
- Final handoff links to source changes, plan, evidence and installation artifact
  when produced. Public release publication is not required by this request.

## Initial confirmed findings

1. `NexFeatures.fresh()` catches a failed session flush and still clears the
   composer; unsaved text can disappear from the only recovery surface.
2. Rotating a session waits before assigning the replacement; typing during
   that interval can join the old session then disappear from the composer.
3. The library's first-run buttons call panel-only `show()` in window mode.
4. Desktop capture removes the compact panel's saved/saving indicator.
5. The 1600px home view leaves a large gap between a capped editor and a narrow
   note shelf, with little recent content in the central work area.

Further findings and validation are recorded in `WINDOWS_0140_REVIEW.md`.
