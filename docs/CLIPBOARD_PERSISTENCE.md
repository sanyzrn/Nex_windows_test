# Persistent clipboard — 2026-10-14

The clipboard now retains the most recent 50 distinct text/image entries in `%APPDATA%\NexDesktopShell\clipboard.sqlite`. Copying a duplicate moves it to the front with a fresh timestamp. Favorites are retained separately, so an old pin does not consume a recent-history slot or disappear on eviction. The existing 30-text-favorites limit is preserved.

Persistence includes captures, pin/unpin, deletion and clear-history. Clear preserves favorites. Existing text pins and pinned image previews migrate once, atomically; the migration marker prevents old files/settings from resurrecting deleted favorites. Text contents, whitespace, Unicode, capture times and the image bytes/dimensions already supplied by the native clipboard preview are stored exactly. This does not change the native image preview/downscaling behaviour.

SQLite work runs in one dedicated isolate. Mutations queue in order and commit as transactions with WAL and `synchronous=FULL`; a failed transaction rolls back. Image blobs are sent only for new entries, and immutable entry identities are cached, so repeated repainting and saving don't rehash every text or rewrite every image. Startup loads history before enabling native clipboard watching. Normal exit drains pending commits. Settings and note backups remain separate from this Windows clipboard database.

Saving/error status and retry are visible in the clipboard view. An unreadable database is not silently reset or overwritten. On retry, recoverable stored entries merge with in-memory changes. Automatic eviction removes unpinned entries from storage rather than retaining an unbounded archive.

## Verification

- Automated tests cover mixed 60-entry retention to 50, MRU deduplication, exact Unicode/whitespace/image bytes/times, old text/image favorites, recopy, clear, delete, one-time migration, rollback and an unreadable file remaining untouched. Controller tests verify startup restoration and draining before exit, including another shutdown callback failing.
- Full desktop suite: **159 PASS** with ordinary, unchanged golden comparisons. Analysis: no issues. UI hygiene, package-host and whitespace checks pass.
- Actual Windows Release test: a separate diagnostic process wrote 60 entries and acknowledged committed storage. It was forcibly terminated without database close/checkpoint. A fresh Release process recovered 50 recent entries, exact image bytes/time and the evicted old image pin. It never changed the user's OS clipboard, notes, preferences or app instance.
- Actual Windows reboot/power removal was not performed. The shutdown guarantee comes from committed disk storage and FULL synchronization; the crash/restart path was exercised directly.

Current installer and hashes are recorded in [TEST_RESULTS.md](TEST_RESULTS.md). Local evidence lives under `apps/desktop/build/clipboard-*`.

## Tools

The owner requested descriptions before choosing what to remove. Tool definitions and actual handlers/views were checked; no tools were removed. `Pin window` toggles always-on-top on the previous foreground window; `Generate` creates UUID/date/time/random/sample text; `Text tools` transforms copied text and counts it; `Snippets` stores reusable text for copying/pasting.
