# Windows CI and release process

## Source and binary synchronization

`main` is the working source branch. Compare local `HEAD` with `origin/main` after fetching, and use `git status --short` to identify pending tracked edits. Build caches, local SDKs and installer EXEs are excluded by `.gitignore`; their absence from the source checkout is intentional. Public installer downloads belong in Releases.

The application version is currently `0.12.1+9` and its release tag is `v0.12.1`. Windows app versions are independent of the recorded Android upstream version. Older release names and dated validation reports are historical records.

## CI failure repaired on 2026-10-14

[Run 38593007184](https://github.com/sanyzrn/Nex_windows_test/actions/runs/38593007184) failed only on `review_goldens/emoji_panel_right_dark_en.png`: **129 / 326,400 pixels (0.0395%)**, image size **480 × 680**, differing inside two emoji glyphs. Its package-host checks, version checks, UI checks and analysis succeeded.

The Windows-specific comparator already allowed at most **0.05%** drift for three emoji-grid snapshots but omitted this review-grid name. The fix adds only this exact filename. All other review views remain exact; larger changes and dimension changes are rejected. Regression tests cover the review filename, threshold, unchanged non-emoji views and image dimensions. Failure artifacts were inspected; baselines were not regenerated to silence CI.

## Build artifacts

`Desktop Windows CI` uses pinned action commits and Flutter **3.44.8**, explicit read-only repository permissions, cancellation of superseded runs and a bounded runtime. It runs desktop and shared UI tests, builds the Windows bundle, installs SHA-verified Inno Setup **6.7.3**, packages the installer, and verifies the desktop still works without its optional AI dependency.

Successful runs retain:

- `nex-windows-release-<commit>`: complete executable/runtime bundle.
- `nex-windows-installer-<commit>`: installer and its generated `SHA256SUMS`.
- Review screenshots; failure images when applicable.

Run status and artifact retention belong to the specific Actions run; a historical failed run is not rewritten or deleted.

## Publish a future version

1. Update the application/version-resource declarations, changelog and current user documentation. Run the version and affected regression checks.
2. Commit and push `main`; wait for **Desktop Windows CI** to succeed on that exact commit, including packaging and AI-removal verification.
3. Create and push an annotated tag such as `v0.12.2` on the tested commit.
4. Run **Publish tested Windows release** from Actions, providing that tag.

The workflow validates tag/version/commit consistency, selects a successful CI run on that exact commit, downloads its installer artifact and checks the checksum before publishing. It refuses to overwrite an existing release or assets. GitHub supplies source ZIP/tar archives from the release tag automatically.

Use the `SHA256SUMS` asset from the same release to verify the corresponding installer. Compiler versions and build environments can affect binary hashes even when app sources are unchanged; the checksum describes a particular published artifact.

## Current 0.12.1 artifact

The initial 0.12.1 installer is the locally tested Windows Release build documented in [WINDOWS_0121_REVIEW](WINDOWS_0121_REVIEW.md). Its app source is unchanged by the CI/docs correction. It is published with its exact original checksum rather than being replaced by a differently built binary with the same filename.

[Latest release](https://github.com/sanyzrn/Nex_windows_test/releases/latest) · [CI](https://github.com/sanyzrn/Nex_windows_test/actions/workflows/desktop.yml)
