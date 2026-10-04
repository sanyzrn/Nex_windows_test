# Integration Guide: Merging Nex Windows Desktop into DbsNex Monorepo

This document describes the exact steps to migrate `apps/desktop` into the primary `DbsNex` upstream monorepo.

---

## 1. Repository Base SHAs

- **Upstream Monorepo (`DbsNex`)**:
  - Base Commit: `3626d03d360098f99335e2193bba7d6e4b9b4a44` (tag `v1.93.0`)
  - Target branch: `main`
- **Windows Desktop Standalone Repo (`wiiin` / `Nex_windows_test`)**:
  - Origin Base Commit: `82a7431c05022e2b70415c9c9c4a886497fedafb` (0.10.0+6)
  - Release Version: **`0.11.0+7`** (Windows Resource Version: `0.11.0.7`)

---

## 2. Upstream Patches to Apply in `DbsNex`

Before copying `apps/desktop`, apply the two shared library patches to `DbsNex`:

```bash
cd /path/to/DbsNex

# Verify clean application
git apply --check /path/to/Nex_windows_test/patches/01-shared-backup.patch
git apply /path/to/Nex_windows_test/patches/01-shared-backup.patch

git apply --check /path/to/Nex_windows_test/patches/02-shared-theme-presets.patch
git apply /path/to/Nex_windows_test/patches/02-shared-theme-presets.patch
```

### Patch Summary:
1. **`01-shared-backup.patch`**: Extends `packages/data` with full backup/restore routines (`.nexbak` and `.nexfull`), streaming decompression, checksum validation, and atomic staging.
2. **`02-shared-theme-presets.patch`**: Transfers shared theme presets and their supporting UI changes.

These are historical transfer patches, not a complete diff of the current vendored packages. Search folding and later repository/AI changes must be reconciled separately against the chosen upstream checkout. The recorded base SHAs are prior handoff metadata; patch application against current upstream has not been revalidated during repository cleanup. Do not apply these patches to this standalone repository, where their changes already exist.

---

## 3. Copying `apps/desktop` into `DbsNex`

In `DbsNex`, the monorepo has an `apps/` directory or root packages structure. Copy `apps/desktop` directly:

```bash
# From this standalone repository root, export committed sources only.
# This excludes local build outputs, SDK caches and ephemeral plugin links.
git archive --format=tar --output=/tmp/nex-desktop.tar HEAD apps/desktop .github/workflows/desktop.yml
tar -xf /tmp/nex-desktop.tar -C /path/to/DbsNex
```

Relative path dependencies in `apps/desktop/pubspec.yaml` remain identical:
- `nex_core: path: ../../packages/core`
- `nex_data: path: ../../packages/data`
- `nex_ui: path: ../../packages/ui`
- `nex_ai: path: ../../packages/ai`

---

## 4. Verification in `DbsNex`

Run the following commands from `DbsNex` root to ensure Android and mobile packages remain completely unaffected:

```bash
# 1. Run upstream validation (proves Android / core packages remain 100% green)
make check   # or flutter test in packages/core, packages/data, packages/ui, packages/ai

# 2. Verify desktop application
cd apps/desktop
flutter pub get
flutter analyze --no-pub
flutter test --exclude-tags golden

# 3. Build Windows Release runner and smoke tests (on Windows x64 machine)
flutter build windows --release --no-pub
powershell -ExecutionPolicy Bypass -File tools/windows_smoke.ps1
powershell -ExecutionPolicy Bypass -File tools/build_installer.ps1
```

---

## 5. Cleanup from Standalone Layout After Move

Once `apps/desktop` is merged into `DbsNex`:
- The vendored standalone `packages/` directory is retired (use `DbsNex` canonical packages).
- The standalone root `spec/` folder is retired (canonical `DbsNex/spec` is used).
- Standalone repo transition patches in `patches/` can be archived.
