# Cross-platform compatibility — Windows 0.15.0

Reference: Android `sanyzrn/DbsNex` main `34514226260dc8b1d3da35f91082dbfa9ce46b93`
(2.1.4). Rechecked against Android 2.1.5 main
`a4b27823b1d46cb016441a14eb3d06e194139d45`; the relevant persisted contracts
are unchanged. The compared schema, note model, archive, preferences and themes have
the same Git blob hashes as local reference commit `846f41e5`.

## Phased work

1. Audit both applications' persisted note fields, schema, portable archive,
   encrypted full backup, preference identities, palette IDs and sync protocol.
2. Align note/attachment storage, backup path remapping and reference-aware
   cleanup. Preserve Android-only tables through Windows backups. Reject newer
   unsupported layouts before replacing the current library.
3. Share the 14 palette identities and colors; translate common appearance
   preferences without copying desktop placement, clipboard history, device IDs,
   credentials or OS permissions between devices.
4. Exercise archives produced by the Android implementation in Windows, then
   restore Windows exports using the Android implementation. Verify corrupt,
   renamed and model-bearing backups, attachment retention and schema rejection.
5. Update the Android receiver for scoped desktop preferences, run regression
   suites and the native Windows release gate, and document actual boundaries.

## Confirmed gaps

| Contract | Before this revision | Required behavior |
| --- | --- | --- |
| Full backup settings | Windows only wrote `desktopShell`, rejected by Android | Android-valid version-1 envelope with shared preference scope |
| Appearance | Android preferences ignored by Windows | Read the shared theme, palette, seed, locale, density and recent colors |
| Model-bearing backup | Desktop passed an empty model digest and rejected it | Restore the portable library without installing a mobile model |
| Container recognition | File suffix determined full backup handling | Recognize container entries, including renamed downloads |
| Attachments | Windows did not know attachment references | Remap, search, display and retain every attached file |
| Cleanup | Android-only attachments could be treated as orphans | Count live references in both note and attachment tables |
| Palette identity | 10 old palettes; classic colors diverged | Same 14 IDs, seeds, surfaces and motifs as the Android reference |
| Schema | Windows did not check newer `user_version` | Fail before mutating or replacing an unsupported library |

## Scope

Backups carry the library database (including tags, pins, reminders, threads,
commitments, scheduled notes and module tables) and media. Shared appearance
settings use Android's existing `appearance.*` keys. Device-specific settings
stay on their own platform. A scoped desktop backup must not erase Android AI
keys, vault contents, permissions or preferences outside the shared scope.

This work establishes an executable compatibility contract. It does not turn
backup transfer into live sync. The existing sync transport covers a smaller
set than the database; attachments, module records and preferences must not be
advertised as live-synced until their server and client protocols support them.
iOS has no checkout in this review: its future implementation must run the same
fixtures and retain the same portable keys rather than inventing another format.

## Supported transfer matrix

| Content | Library backup `.nexbak` | Full backup `.nexfull` | Live sync in desktop |
| --- | --- | --- | --- |
| Note types, text, checklists, links and derived text | Yes | Yes | Not configured/enabled |
| Tags, tag colors, pins, reminder dates and recurrence | Yes | Yes | Not configured/enabled |
| Note media and extra attachments | Yes, path remapped | Yes, path remapped | Not implemented |
| Threads, commitments and scheduled notes | Yes | Yes | Not implemented |
| Android module/cycle tables | Preserved | Preserved | Not implemented |
| Shared appearance preferences | No | Yes | Not implemented |
| Windows placement, shortcuts and native tool settings | No | Windows section only | Device local |
| Android vault, credentials and mobile model | No | Remain mobile-only | Not implemented |

A desktop full backup has `version: 1`, `scope: shared`, the supported
`appearance.*` preferences, empty credentials, optional cleared preference keys
and a separate `desktopShell`. The companion Android receiver merges this scope
instead of clearing preferences absent from it. Existing Android 2.1.4/2.1.5
binaries lack that scope handling: use the updated receiver build for appearance
transfer, or use a library-only backup. The original mobile full backup remains
the recovery copy for mobile vault/model/credentials; Windows neither installs
nor retains those secrets in its own settings.

Local compact format-2 backups depend on sibling `.media` blobs. Share the
portable format-1 archive, not an isolated compact file. Windows full export
uses a self-contained library; Android already materializes compact backups.

The Windows settings page also offers a library-only portable backup for
existing mobile builds, and recognizes Android v3 export ZIPs as additive
imports. Import preserves the active desktop draft; a replacement restore
rotates the capture only after success.

## Validation

- Windows desktop behavior: 144 passing, including encrypted mobile restore,
  independent Android container decode, local device identity and reader access.
- Shared UI: 192 existing tests passing, plus a 14-palette/40-color contract gate.
- Core: 198 existing tests passing, with the shared wire-contract gate added.
- Data: 204 passing, 14 existing skips; Android-created library/full/export
  archives restore with attachment bytes, tags, reminders and private tables.
- Android: scoped-restore tests preserve device ID, credentials and private
  preferences, and reject hostile shared keys; full-backup regression tests pass.
- Both apps' static analysis is clean. Native Windows screenshots/build/installer
  gate and exact source commits are recorded after the final CI run.

Future iOS must use the same schema stamp, UTC instants, note type names, color
hex values and preference keys. Its sandbox paths must be rebuilt on restore,
not copied from the source device. The tests cover path semantics on POSIX;
no physical iOS app or device was available in this review.
