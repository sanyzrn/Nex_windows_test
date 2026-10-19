# Nex Windows 0.21.0+14

Android-compatible cloud intelligence and a new tag-colored note gallery.
[Scope, architecture, phased implementation and validation](docs/WINDOWS_0200.md).
[Changelog](apps/desktop/CHANGELOG.md) · [Shared backup contract](docs/CROSS_PLATFORM_0150.md).

Use the installer and SHA256SUMS from the same successful GitHub release.
The complete main-branch Windows CI must pass before the automatic publisher
creates v0.21.0. It publishes the exact tested installer, without rebuilding it.
Published versions are never silently replaced.

AI is disabled until configured and explicitly enabled. Five cloud providers
match Android 2.1.6. API keys stay in Windows secure storage, outside portable
backups. Local model selection/runtime is a future capability; live sync is
not implemented. Existing note, attachment and appearance backups remain
compatible under the versioned cross-platform contract.

Close the current app through its tray menu before upgrading. App identity
and user-data paths remain unchanged. Install the complete setup payload;
a lone application EXE is not a distributable package.
