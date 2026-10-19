# Nex Windows installer

Inno Setup **6.7.3** builds `Nex-Windows-Setup-0.21.1-x64.exe` for app **0.21.1+15** on Windows 10/11 x64. Setup uses a dark title bar, Nex artwork and English/Persian pages. It installs per user into `%LOCALAPPDATA%\Programs\Nex`, adds a Start menu shortcut and optionally a desktop shortcut, and registers its uninstaller. The selected installer language becomes the app/tray language once per installation.

Close Nex before upgrading or uninstalling; setup uses the application's singleton mutex. User notes, media and settings are stored outside the program directory and retained. Startup is controlled in Nex settings; uninstall removes its startup entry only when it points to this installation.

The complete Flutter Release bundle is packaged with app-local x64 Microsoft C++ runtime files, SQLite, plugin DLLs, fonts and assets. Runtime downloads are not needed during installation. The installer is currently **unsigned**.

## Local packaging

After `flutter build windows --release --no-pub`, run from `apps/desktop`:

```powershell
./tools/build_installer.ps1 -ISCC 'C:/path/to/Inno Setup 6/ISCC.exe' -VCRuntime 'C:/path/to/Visual Studio/VC/Redist/MSVC/<version>/x64/Microsoft.VC143.CRT'
```

The script can discover an installed Visual Studio CRT directory when `-VCRuntime` is omitted. It stages the full bundle, checks required runtime members and writes a payload SHA-256 manifest under `build/installer/`. The default installer output is `build/installer/output/`; `-Output` can override it. Use licensed Visual Studio redistributable files rather than arbitrary System32 DLLs.

## CI and releases

Desktop Windows CI installs the compiler from the official **6.7.3** release after checking its published SHA-256. It builds setup and attaches the installer plus `SHA256SUMS` as an artifact of the tested source commit. Successful main-branch CI triggers automatic publication: the release workflow verifies the same artifact, creates the source version's tag and publishes both files. Existing releases are not overwritten; each new public update needs a new source version. Manual dispatch remains available for retries.

The current download is in [GitHub Releases](https://github.com/sanyzrn/Nex_windows_test/releases/latest); generated EXEs are intentionally excluded from Git. See [release instructions](../../../docs/RELEASING.md).

Brand PNGs are committed assets; `artwork/generate_brand.py` records their deterministic drawing recipe. They are not regenerated on CI. `Farsi.isl` is the attributed translation from the [Inno Setup 6.7.3 source](https://github.com/jrsoftware/issrc/blob/is-6_7_3/Files/Languages/Unofficial/Farsi.isl).

Packaging follows [Flutter's Windows distribution guidance](https://docs.flutter.dev/platform-integration/windows/building); runtime redistribution follows [Microsoft's terms](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files).
