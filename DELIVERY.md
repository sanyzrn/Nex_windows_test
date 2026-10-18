# Nex Windows 0.15.0+12

Notes, attachment storage, backup interchange and all 14 palettes are aligned
with Android 2.1.4. [Compatibility contract, evidence and limitations](docs/CROSS_PLATFORM_0150.md).
The Android companion change adds scoped appearance restore without resetting
mobile credentials or private preferences. Use a build containing that change
for complete Windows-to-Android appearance transfer; library-only `.nexbak`
restore remains compatible with the referenced Android release.

Cross-platform compatibility update over Windows 0.14.0+11.

- Phased plan: [docs/WINDOWS_0140_PLAN.md](docs/WINDOWS_0140_PLAN.md).
- Defects, validation and remaining physical checks:
  [docs/WINDOWS_0140_REVIEW.md](docs/WINDOWS_0140_REVIEW.md).
- Changes: [apps/desktop/CHANGELOG.md](apps/desktop/CHANGELOG.md).

Use the installer artifact produced by a successful Windows CI run for the
exact source commit. It includes the full runtime payload and SHA256SUMS.
Do not distribute a lone EXE from the application bundle. Before upgrading,
close the current app through its tray menu. App identity and user-data paths
are unchanged.

Every new source version publishes automatically to GitHub Releases after the
complete main-branch Windows CI succeeds. The publisher verifies that exact
commit's installer and SHA256SUMS, creates its version tag, and attaches both
files. Failed/stale CI cannot publish. Published versions are never overwritten;
increase the source version for the next update. Manual dispatch remains a retry
path for an existing version tag. See [release guidance](docs/RELEASING.md).
