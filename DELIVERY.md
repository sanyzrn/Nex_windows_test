# Nex Windows 0.14.0+11

Desktop workspace redesign and release-hardening update over 0.13.0+10.

- Phased plan: [docs/WINDOWS_0140_PLAN.md](docs/WINDOWS_0140_PLAN.md).
- Defects, validation and remaining physical checks:
  [docs/WINDOWS_0140_REVIEW.md](docs/WINDOWS_0140_REVIEW.md).
- Changes: [apps/desktop/CHANGELOG.md](apps/desktop/CHANGELOG.md).

Use the installer artifact produced by a successful Windows CI run for the
exact source commit. It includes the full runtime payload and SHA256SUMS.
Do not distribute a lone EXE from the application bundle. Before upgrading,
close the current app through its tray menu. App identity and user-data paths
are unchanged.

Public release publication is separate from source preparation. Release CI
refuses to publish without successful Windows CI for the tagged commit.
