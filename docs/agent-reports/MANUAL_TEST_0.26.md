# Nex Windows 0.26 — installed acceptance checklist

Not executed in Linux. Windows agent: fill desktop checks. Owner: phone and
physical-device checks. Record Windows build, CPU/RAM, GPU, scaling and monitors:
`________________`. Use a disposable profile or export a backup first.
About 20 minutes hands-on, plus reminder waits, idle soak and phone transfer.
For every numbered item fill `PASS / FAIL / NOT TESTED — observation: ______`.
B0 IDs below cover all 34 historical items; they do not claim they passed.

## Lifecycle and navigation (B0 2–9, 11–12, 15, 33)
1. Install candidate, open Start → Nex and Windows Apps. Expect Nex shortcut,
   candidate version and compact bottom-right window above taskbar. Result: ____
2. Move/resize; click × and Alt+F4 separately. Expect process alive and tray
   available, no lost draft; tray click/Open and a second Start launch restore
   one window. Repeat with an upgraded profile that had close-to-tray OFF.
   Tray → Quit must flush and exit; launch again. Result: ____
3. Toggle Remember size/position; resize/maximize/restore, hide and reopen.
   Expect remembered placement when on and compact corner when off. Switch
   More → Panel → Window; Ctrl+N/L/K/F and F1 reach expected actions. Result: ____
4. Enable launch at login, sign out/in, confirm exactly one instance; turn off
   and verify disabled. Ensure launch does not destroy saved placement. Result: ____

## Notifications and civil dates (B0 22–30)
5. Enable Nex notifications, disable DND, run notification test: observe immediate
   and 15-second toast separately; an acceptance message alone is not delivery.
   Schedule a note 2 minutes ahead: repeat open, minimized, hidden by × and
   explicit Quit. Expect one notification for each reminder. Result: ____
6. Schedule before sleep, resume after due time; repeat across clock/timezone
   change. Expect one recovery, never duplicate note mutation. Record actual
   banners and Action Center entries. Result: ____
7. With app fully quit, click toast body, Snooze and Done in separate trials.
   Expect matching note, one reschedule or completed series; replay old actions
   after editing the reminder: no mutation. Delete a daily/weekly series and
   verify future queue removed. Next-day/week observation remains pending until
   it actually occurs. Result: ____
8. Open `nex-win://note/<existing-id>` with Win+R: expect correct note. Try
   `nex-win://note/` and `nex-win://reminder/bad?action=unknown`: no mutation/crash.
   Set a Persian-calendar reminder and compare Gregorian due time. Result: ____

## Persian editing and content (B0 16–21, 32)
9. In capture, reader, search, rename/tag fields type/paste three paragraphs:
   `English line.` / `سلام دنیا!` / `Test (۱۲۳) 😀 می‌نویسم.`. Use Persian IME,
   ZWNJ, Shift+arrows, Home/End, mouse selection, Ctrl+C/V/Z/Y and newlines.
   Save/reopen/export; expect exact text and stable composition/caret. Repeat
   10k characters. Active-paragraph direction is a mitigation, not independent
   native paragraph layout. Record defects/screenshots for editor verdict. Result: ____
10. Capture text/photo/file/audio, apply tag, search/filter/trash/restore, use
    reader copy/pin/reminder/delete. Expect usable pickers, unclipped action
    rows and file/reminder indicators. AI provider test must show real errors
    without exposing keys; capability test is not proof of account availability.
    Result: ____

## Visuals, tools and DPI (B0 10, 13–14, 19)
11. At 100/125/150% (also 200% if used), compact/full window and panel, fa/en,
    light/dark: open rail, library type/tag/thread menus and dropdowns. Expect
    shared rounded surface, legible contrast, correct RTL and no clipped text.
    Drag to second monitor, switch theme at runtime and change taskbar edge;
    compact corner stays in the working area. Capture screenshots. Result: ____
12. Enable all four tools. PDF: open real large/encrypted/Persian PDFs, search,
    select/copy, turn/jump/zoom/reopen; Ctrl+O/F/G work, no stale result/crash.
    Cycle: record/edit/delete a period, inspect ring with pointer/slider, select
    date, quick mood, full daily log, reopen; preserved fields and dates match.
    Vault: add/edit/reveal/copy all three categories, inspect category counts,
    lock, blur, sleep and cancel Hello; secrets disappear and later copies are
    not cleared accidentally. Portrait: metrics, refresh, optional AI consent,
    permission revocation and cancellation behave. No private content enters AI.
    Result: ____

## Update, install and trust (B0 1, 3–4)
13. On an older installed release with disposable notes and FA locale, check →
    download → install/restart. Expect same data, locale, path and new version;
    one relaunched instance. Offline check and modified cached installer must
    show failure and preserve old install. Unsigned SmartScreen is expected;
    never bypass a digest mismatch. Uninstall/reinstall preserves user data.
    Result: ____

## Android backup round trip (B0 31; owner's phone required)
14. Android release/1.80.0: create uniquely named FA/EN notes, checklist, image,
    attachment, tag and reminder. Export `android-before.nexbak` and, if offered,
    `android-before.nexfull`; copy unchanged to Windows. Import via Settings →
    Backup and compare text, media, dates, tags, checklist and Cycle data that
    the selected archive includes. Export `windows-roundtrip.nexbak` (and
    `.nexfull` only if Windows offers it); copy to phone, import into a disposable
    profile, compare again. Keep original archives; never rename one format to
    another. Vault secrets/device-only toggles must stay excluded. Record both
    app versions, exact files/format and missing fields. Windows agent prepares
    files and marks phone half NEEDS OWNER. Result: ____

## Performance (B0 34; Windows agent, measurements pending)
15. Record cold-start stopwatch method/time, RSS/private bytes and handles after
    startup and 30 minutes idle, then import a synthetic 5k-note library and
    repeat measurements plus scrolling frame evidence. Include machine/power
    mode and sample file; do not substitute Linux timings or adjectives.
    Start ____ ms; idle ____ MiB / ____ handles; 5k ____ MiB / ____ handles;
    scrolling ____; result: ____
