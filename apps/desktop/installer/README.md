# Nex Windows test installer

Inno Setup 6.7.3 produces `Nex-Windows-Setup-0.9.0-x64.exe` for Windows 10/11 x64. It installs for the current user into `%LOCALAPPDATA%\Programs\Nex` without administrator privileges, offers Persian/English installer UI, creates a Start menu shortcut and optionally a desktop shortcut, and registers its uninstaller in Windows Settings. The chosen installer language becomes the app/tray language on the next launch, once per installation. Automatic startup remains controlled by Nex settings. Close Nex before updating or uninstalling; the installer uses the same singleton mutex.

The complete Flutter Release bundle is included, with app-local x64 Microsoft C++ redistributable DLLs, assets, fonts, SQLite and all plugin DLLs. It needs no runtime download during installation. User notes/media/settings in application-support locations survive uninstall. The optional startup registry value is removed only when it points to this installation's executable.

Build after `flutter build windows --release`:

```powershell
./tools/build_installer.ps1 -ISCC 'C:/path/to/Inno Setup 6/ISCC.exe' -VCRuntime 'C:/path/to/Visual Studio/VC/Redist/MSVC/<version>/x64/Microsoft.VC143.CRT'
```

`-VCRuntime` may be omitted when the script can locate an installed Visual Studio redistributable directory. Use the licensed Visual Studio redistributable files; do not copy arbitrary DLLs from System32. Staging and the payload SHA-256 manifest are under `build/installer/`; the default output is `build/installer/output/`. `-Output` selects another output directory. The Inno compiler itself is a build tool, not bundled inside the Nex installer or source ZIP. The resulting Nex installer is unsigned; no signing certificate or update service was supplied.

Runtime packaging follows [Flutter's Windows distribution guidance](https://docs.flutter.dev/platform-integration/windows/building). Microsoft runtime files remain governed by [Microsoft's redistribution terms](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files). `Farsi.isl` is the user-contributed translation from the [Inno Setup 6.7.3 source](https://github.com/jrsoftware/issrc/blob/is-6_7_3/Files/Languages/Unofficial/Farsi.isl); its contributor attribution is retained.
