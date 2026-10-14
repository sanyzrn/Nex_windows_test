# Windows CI and releases

Current application: **0.13.0+10**, release tag **v0.13.0**. `main` contains
one current source tree at the repository root. Build caches and installer
EXEs are excluded from Git; installers belong in Releases.

## Reviewed visual baselines

The 0.13.0 redesign intentionally changes the palette and screen layout.
Windows baselines were generated locally with Flutter 3.44.8, reviewed and
committed. The full desktop suite then passed in comparison mode. CI compares
these images; it must not regenerate expected images before testing. Only
explicitly listed emoji-grid screenshots permit up to 0.05% Windows emoji-font
drift; dimensions and other screenshots remain exact.

## Build and publish

1. Update version declarations, changelog and current documentation.
2. Run analysis, affected checks and desktop/shared-package tests.
3. Commit and push main; wait for Desktop Windows CI on the exact commit.
4. Push an annotated version tag on that successful commit.
5. Run Publish tested Windows release with the tag.

CI uses pinned actions, Flutter 3.44.8 and SHA-verified Inno Setup 6.7.3.
It checks package hosts, versions and UI hygiene, runs desktop/shared UI
suites, builds and packages Windows, and checks optional AI removal.
The publisher validates tag/version/commit and the successful run's installer
checksum, and refuses to overwrite an existing release.

## Current artifact and synchronization

The initial 0.13.0 installer is the local Windows Release build from the
supplied redesign source. Promotion adds visual baselines, asynchronous test
synchronization and documentation corrections; application code is unchanged
from that installer. Root SHA256SUMS describes this exact published file.
Compiler/environment differences can change hashes for the same app source;
use the checksum shipped with the artifact you download.

Fetch before comparing HEAD with origin/main. Tracked changes must be absent
and ahead/behind counts must be 0 0. Historical commits and changelog entries
are retained. Obsolete installer copies, release assets and version tags are
removed only after the current release is verified.

[Latest release](https://github.com/sanyzrn/Nex_windows_test/releases/latest)
· [CI](https://github.com/sanyzrn/Nex_windows_test/actions/workflows/desktop.yml)
