# Nex Windows 0.13.0+10

The supplied redesign was validated on Windows before promotion into the
current application tree. Sources live at apps/desktop; the workspace root
has one current installer. Generated installers are published in Releases.

## Windows validation — 2026-10-14

- Flutter 3.44.8 / Dart 3.12.2; desktop and shared UI analysis pass.
- Desktop: 178 tests pass, including reviewed Windows visual baselines.
- Shared UI: 192 pass; core: 198 pass; data: 199 pass, 14 skipped.
- Package-host and UI-hygiene checks pass.
- Windows Release build and Inno Setup 6.7.3 packaging succeed.
- App and installer report 0.13.0+10.
- Tag-management tests use bounded waits for asynchronous UI/database
  completion. No application-code changes were needed during promotion.

The redesign adds a navy palette, compact chrome, a wave backdrop and
colored tool chips. It fixes duplicate checklist toggles, stale tool IDs,
disposed-view callbacks and narrow-layout overflows. See the changelog and
[validation report](docs/WINDOWS_0130_REVIEW.md).

## Install

Download Nex-Windows-Setup-0.13.0-x64.exe and SHA256SUMS from
[Releases](https://github.com/sanyzrn/Nex_windows_test/releases/latest).
Close Nex via its tray menu before upgrading. User notes, media and settings
are outside the program directory and retained.

This is suitable to replace 0.12.1 based on the observed checks. Physical
mixed-DPI multi-monitor/hot-plug behavior, installed notification delivery
after reboot and clean-machine upgrades remain manual checks. Indefinite
repeating reminders while fully exited, cloud/LAN sync and auto-updates
are not implemented. This is not a claim of universal bug-free operation.

CI compares committed visual baselines without refreshing them. See
[release instructions](docs/RELEASING.md).
