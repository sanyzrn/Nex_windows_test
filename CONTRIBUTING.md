# Contributing to Nex Windows

Bug reports, workflow feedback and pull requests are welcome in Persian or English. Use the [issue forms](https://github.com/sanyzrn/Nex_windows_test/issues/new/choose) and include the application version, Windows version, interface mode, language, display scaling and reproducible steps.

## Development environment

Use Windows x64, Flutter **3.44.8** and Visual Studio's Desktop development with C++ workload. `apps/desktop` depends on the four shared packages already included in this repository. Do not reapply the transfer patches in `patches/`.

For the complete local pre-push check, run `powershell -NoProfile -File
.\tools\verify_windows.ps1 -Offline` from the repository root. See
[local verification](docs/LOCAL_VERIFICATION.md) for stage selection, logs and
the temporarily quarantined visual/GUI fixtures.

```powershell
cd apps/desktop
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

Run Flutter commands sequentially within the same package to avoid generated-plugin races. Use default package hosts and keep lockfiles committed. See [the application architecture](apps/desktop/README.md).

## Changes and validation

- Explain the concrete user problem and the resulting behavior in a PR.
- Keep strings in the ARB files and colors in the theme/design tokens. Generate localizations from `apps/desktop` with `flutter gen-l10n`.
- Add a regression test for a reproduced bug, including persistence or native behavior where relevant.
- For UI work, review both English/Persian, window/panel, light/dark, and the affected text scales. Use the existing review screenshot matrix.
- Do not broadly relax golden tolerances or regenerate every baseline to hide a failure. Only named emoji grids have the narrow Windows font-raster allowance; other images remain exact.
- Run shared-package tests when changing shared behavior. In `packages/ui`, use `flutter pub get --enforce-lockfile` then `flutter test --no-pub`.
- Never commit private notes, clipboard content, credentials, local build folders or installer binaries.

For an application version bump, update `pubspec.yaml`, `core/app_meta.dart`, Windows resources, Inno Setup, README and the changelog together; the version-consistency tests check these declarations. Put downloads and checksums in the corresponding GitHub Release.

[Release instructions](docs/RELEASING.md) · [MIT license](LICENSE)

## Efficient local verification

Read the affected feature and reuse existing fixtures. Documentation-only changes
need link/diff checks, not a Flutter suite. For code changes, analyze the affected
package and run focused tests for changed behavior and affected callers. Add tests
for reproduced defects or meaningful uncovered logic, not implementation mirrors
or cosmetic edits. Broaden for shared-code impact, failures or unresolved risk;
do not repeatedly run unchanged suites after every edit. Keep existing useful
regressions and all required CI gates. Windows-only claims require Windows evidence.

The full Windows gates remain analysis, desktop tests/goldens, version consistency,
localization/UI/package-host checks, affected shared-package checks, Release build
and relevant native smoke probes. The [PR checklist](.github/pull_request_template.md)
records results or explicit limitations. [Manual Windows checks](docs/TEST_0220.md)
cover installed behaviors that widget tests cannot establish.

Generate [the keyboard reference](docs/shortcuts.md) from the actual help dialog:
`cd apps/desktop` then `dart run tool/generate_shortcuts.dart`. Its regression test
fails when the rows, shortcut labels or translated descriptions drift. Run
`python tools/audit_unused_strings.py` from the repository root to list unused-copy
candidates; it cannot prove the absence of arbitrary dynamic lookups. Review AI
wire names, utility English-text lookups and IANA-derived city labels first.

Reports can be brief: changes, checks actually run, blockers and commit. Preserve
historical findings under `docs/archive/`; link current instructions to current
source. Never claim a version was released just because its source was committed.
