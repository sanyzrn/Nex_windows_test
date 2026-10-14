# Notebook and reminder repair — 2026-10-14

This iteration implements the owner's request to improve both the Windows interface and everyday behaviour. The attached quality document remains reference material; this report does not claim that its entire checklist is complete.

## What changed

- The desktop capture page is now a notebook workspace: exact SQLite totals, pinned and recent previews, a smaller writing surface, and direct clipboard/timer/keep-awake access. It responds to new captures and note mutations without loading the whole library. Narrow windows stack the shelves and editor; wide windows scroll each column independently.
- The wide library opens its first note immediately. A note opened through search or notification remains selected even when it is outside the first 50 rows; deleted selections are checked against SQLite.
- Clipboard text and image rows reserve an independent action lane. Favorite/delete controls use actual icon buttons and translated tooltips; text can occupy two lines without overlapping them. Clicking an action does not copy/paste its parent row.
- The dock's icon column now occupies the full dock width. Hover scaling preserves the icon's center; the active square and icon match on both screen edges.

## Reminder audit

The picker was reading stored UTC hours directly, while custom selection used local time. All reminder displays now convert to local time, including the picker, reader, cards and today strip. Custom time entry uses 24 hours. Saving does not silently move a past one-off time; it reports an error. Save requests cannot overlap, and delivery failures keep the selected time available for retry.

The previous reconciliation engine was not connected to normal startup or mutations. A serial coordinator now reconciles at startup, after reminder/delete/restore operations, and every 30 seconds while Nex runs. Unchanged schedules are cached; edits replace the existing entry; deletion and clearing cancel it. Overdue receipts persist across restarts and distinguish changes to the due time.

Actual Windows testing found two additional native defects:

1. The Windows queue rejected the 16-character developer ID with `WPN_E_DEV_ID_SIZE` (0x803E0120), despite the documented 16-character limit. Normal UUIDs are much longer. A stable 15-character hash is now used for long IDs and domain note IDs remain separate for opening the note.
2. `ToastNotifier.Setting()` returned `ERROR_NOT_FOUND` for this unpackaged desktop app even though `AddToSchedule` succeeded. That optional-property case now falls through to the scheduling operation; genuine notification blocks and scheduling errors still fail visibly.

Toast content uses protocol activation. The installer registers `nex-win://note/<id>`; cold launches and second-instance forwarding open the matching note. Nonfunctional foreground Done/Snooze buttons were removed; the OS dismiss button remains. XML escapes content and strips unsupported control characters.

Sources: [Windows developer ID contract](https://learn.microsoft.com/en-us/uwp/api/windows.ui.notifications.scheduledtoastnotification.id), [Microsoft's caveat for desktop notification settings](https://devblogs.microsoft.com/oldnewthing/20200810-00/?p=104058), [Windows scheduled notification delivery](https://learn.microsoft.com/en-us/windows/apps/develop/notifications/app-notifications/app-notifications-scheduled).

## Verification and scope

- Real Release queue probe: tomorrow 09:00 Iran Standard Time preserved exactly; edit to 10:00 retained one queue entry; cancel removed the owned test notification. No user notes, clipboard, preferences or existing reminders were altered by the probe.
- Automated coverage includes actual custom date/time input, UTC persistence/reopening, past-time rejection, retry, daily/weekly local calendar calculations, runtime mutation/caching/cancellation, persisted receipts, home totals/navigation/refresh, selection outside pagination, clipboard action geometry and dock center geometry.
- Visual matrix: 40 screenshots in English/Persian, both themes, panel/window, left/right edges and text scaling up to 2.0. Intentional layouts and seeded pinned fixtures have updated goldens, followed by ordinary comparisons.
- Release build and installer results are recorded in `TEST_RESULTS.md`. The existing installed Nex was not upgraded or stopped.

## Remaining work, in order

1. Durable recurring scheduling beyond a fully exited app: currently Windows owns the next queued occurrence, and the running coordinator or next startup queues later occurrences. Endless daily/weekly delivery while Nex remains completely exited is not implemented. Windows can drop a scheduled toast after the documented delivery window if the computer is off; a persisted queue acceptance is not proof that the user saw it.
2. Install/upgrade and actual toast-click activation verification with the new protocol registration; fresh-VM and DPI/monitor-change coverage. Unit tests verify URI routing and native forwarding compiles, but clicking a real toast through the installed new protocol has not been exercised.
3. Continue the product pass through reminder overview, editor/media actions, library organisation, and each Windows utility. This iteration repairs the reported defects and makes the home/library useful; it does not claim every remaining product problem is solved.
