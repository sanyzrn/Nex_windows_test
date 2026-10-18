# Android compatibility fixtures

`android_214_backup.json` contains base64 archives written by the **unmodified
Android 2.1.4** archive and full-backup implementations. All content, keys and
credentials are synthetic test values. No user data is included.

Reference: `sanyzrn/DbsNex` main
`34514226260dc8b1d3da35f91082dbfa9ce46b93`. Relevant files exactly match
`846f41e5efc8a14c7adfbcd2a8fbc8bd2956bf21`:

- full-backup codec blob `b04b70a251b0f9bd80ec3e288aa82a6e9e42e872`
- library archive blob `cf2ea6d92bd13220c7b174b78a943ea1d7be782c`
- note model blob `5e7d19fe8c92359bbbbab3bfd72dbaf43a14c654`

`android_full_backup_codec.dart` retains the Android reader verbatim for a
separate-implementation Windows-to-Android container check.

To regenerate, copy `tools/compat/generate_android_fixture.dart` into the pinned
Android checkout as `packages/data/tool/generate_cross_platform_fixture.dart`,
resolve its committed dependencies, then run it from `packages/data`, supplying
the destination fixture JSON path. The generator uses the Android libraries,
not the Windows writer. Native Android/iOS UI or installation is not simulated.
