# Windows 0.21.0 — Android design and GitHub updates

## Design

Use the supplied Android references: rounded tonal groups, colored icon badges,
clear settings navigation, an Intelligence overview and capability grid, a
separate provider page and small circular note actions. Windows retains pointer,
keyboard, responsive gallery and edge-panel behavior. No mobile-only tool is
advertised as implemented. All 14 palettes and portable backups remain compatible.

## Updates

The application checks the latest stable public GitHub release after startup and
every six hours. It downloads newer x64 installers automatically; Install & restart
is explicit so ongoing work is not interrupted. Automatic checks/downloads can be
disabled, and manual checking remains available. No notes, AI credentials, GitHub
token or device ID are sent in update requests.

Exact repository asset URLs, stable version tags and filenames are validated.
Redirects are confined to GitHub release hosts. Sizes, GitHub SHA256 digests,
SHA256SUMS and Windows executable headers must match. Incomplete or changed files
cannot activate an update. Requests coalesce and cancellation prevents stale
activation; temporary network errors keep a previously verified download usable.

The standalone nex_update.exe is copied outside the installation before running.
It checks the parent executable identity, locks and hashes the installer, signals
a nonce handshake and waits for Nex to save and exit. It verifies the hash again,
installs into the same directory, preserves saved locale and preferences and
restarts Nex only after installation finishes. It never forces a system reboot.

## Validation

Gate release on hostile metadata/redirect/checksum/cancellation tests, shared
regressions and strict Windows screenshots. Windows CI also verifies the native
helper and performs a real Inno Setup installation into a temporary directory,
checks locale preservation and restart, then smoke-tests the installed bundle.

References: https://docs.github.com/en/rest/releases/releases#get-the-latest-release
and https://jrsoftware.org/ishelp/index.php?topic=setupcmdline
