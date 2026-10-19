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

Reviewed all 64 Windows screenshots from source
`8b72da824dbc429751703b0cfe98c8aa9ccb0199`, CI run `39210928992`.
Candidate ZIP SHA256:
`4a5925184ff7c1dc4c51465f88aa3bbbee5b7f6242b6d5eae1a130317db27bca`.
All 62 rendering tests passed. The comparison run had 203 passes and 39 expected
image differences; all failures were named screenshot comparisons. Baselines
were updated after review, with no changes to comparison tolerances.
Local validation: desktop analysis clean, 180 behavioral tests, 197 shared UI
tests and all 16 updater/security/large-text tests pass. Native compile and real
installer handoff remain gated on the final Windows CI run.
