# Contributing to Nex Windows

Bug reports, workflow feedback and pull requests are welcome in Persian or English. Use the [issue forms](https://github.com/sanyzrn/Nex_windows_test/issues/new/choose) and include the application version, Windows version, interface mode, language, display scaling and reproducible steps.

## Development environment

Use Windows x64, Flutter **3.44.8** and Visual Studio's Desktop development with C++ workload. `apps/desktop` depends on the four shared packages already included in this repository. Do not reapply the transfer patches in `patches/`.

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
