# Windows checks before pushing

Run from the repository root with Windows x64, Flutter 3.44.8, Python and Visual
Studio C++ build tools. Inno Setup 6.7.3 is needed for the installer stage.

```powershell
powershell -NoProfile -File .\tools\verify_windows.ps1 -Offline
```

This runs source/localization/release checks, desktop and all shared-package
analysis/tests, the Release build and installer packaging. It uses the same
verification script as GitHub, retains per-step logs and writes
`apps/desktop/build/local-ci/PrePush-report.json`. Independent checks continue
after a failure, so one run can reveal more than the first error. `-Offline`
uses cached dependencies with the committed lockfiles; omit it for a first setup.

To recheck a smaller area, pass `-Stage Desktop`, `Ui`, `CoreData`, `Ai`,
`Validate`, `Build` or `Package`. `-NoRestore` uses already-resolved dependencies.
An explicit `-ISCC C:\path\ISCC.exe` overrides compiler discovery.

Tests have a two-minute default deadline and two concurrent workers, matching
CI. The existing 10,000-note benchmark retains its explicit five-minute limit.
Pixel baselines remain temporarily excluded while the UI is being revised.
The four GUI bulk-pin scenarios are separately tagged `quarantined`: they pass
locally but deadlocked CI run 40885950193 until the whole job timed out. Pin
repository/domain tests remain enabled. Use `-IncludeQuarantined` to diagnose
those scenarios; existing test sources and visual baselines are retained.

`-Stage Runtime` copies current saved source to an isolated ignored directory,
removes only that copy's optional AI runtime, and re-runs analysis/tests. It
does not mutate the working source or lockfiles. Run this before changes to
optional AI dependencies; CI also runs it.

`-Stage Native` and `-Stage Update` are separate checks for a disposable Windows
account or VM. They exercise the OS clipboard, live app window and real installer
registration/restart; they are deliberately absent from the default command on
the user's everyday desktop. GitHub runs them on its clean Windows worker.

Local checks cannot promise identical Windows Server fonts, OS permissions or
GitHub release permissions. A successful local report reduces CI surprises;
publication still requires the clean GitHub build and installer checks.
