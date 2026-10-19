// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/nex/reminder_policy.dart';
import 'package:nex_desktop/nex/reminders.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late NexDatabase db;
  late SqliteNoteRepository repo;
  late FakeReminderScheduler scheduler;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nex_reminders_test_');
    db = NexDatabase.open(p.join(tmp.path, 'nex.sqlite'));
    repo = SqliteNoteRepository(db);
    scheduler = FakeReminderScheduler();
  });

  tearDown(() {
    db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Note createNote(String id, String content) {
    final now = DateTime.now().toUtc();
    return repo.insert(
      Note(
        id: id,
        type: NoteType.text,
        content: content,
        createdAt: now,
        updatedAt: now,
        deviceId: 'test-device',
        rev: 1,
        syncState: SyncState.pending,
      ),
    );
  }

  test('schedules future one-off reminder', () async {
    final note = createNote('n1', 'Call the dentist');
    final futureTime = DateTime.utc(2026, 10, 10, 14, 30);
    repo.setDueAt(note.id, futureTime, repeat: NoteRepeat.once);

    final now = DateTime.utc(2026, 10, 10, 10, 0);
    final summary = await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );

    expect(summary.scheduledCount, 1);
    expect(summary.cancelledCount, 0);
    expect(summary.overdueCount, 0);
    expect(scheduler.scheduled.containsKey('n1'), isTrue);
    expect(scheduler.scheduled['n1']!.fireAt, futureTime);
    expect(scheduler.scheduled['n1']!.body, 'Call the dentist');
  });

  test('past one-off reminder triggers overdue notification', () async {
    final note = createNote('n1', 'Pay utility bill');
    final pastTime = DateTime.utc(2026, 10, 10, 8, 0);
    repo.setDueAt(note.id, pastTime, repeat: NoteRepeat.once);

    final now = DateTime.utc(2026, 10, 10, 12, 0);
    final summary = await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );

    expect(summary.overdueCount, 1);
    expect(scheduler.overdueShown.length, 1);
    expect(scheduler.overdueShown.first.noteId, 'n1');
    // The fallback names the occurrence it stands in for, so a toast Windows
    // already delivered for that instant is not shown twice.
    expect(
      scheduler.overdueShown.first.fireAt,
      repo.getById('n1')!.dueAt!.toUtc(),
    );
    expect(scheduler.scheduled.isEmpty, isTrue);
  });

  test('daily repeat advances fireAt past current time', () async {
    final note = createNote('n_daily', 'Water the plants');
    final pastStart = DateTime.utc(2026, 10, 1, 9, 0);
    repo.setDueAt(note.id, pastStart, repeat: NoteRepeat.daily);

    final now = DateTime.utc(2026, 10, 10, 10, 0);
    final summary = await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );

    // The next occurrence plus the six after it: a week that keeps ringing
    // while Nex is closed.
    expect(summary.scheduledCount, 7);
    expect(
      scheduler.scheduled['n_daily']!.fireAt,
      DateTime.utc(2026, 10, 11, 9, 0),
    );
    final times = [
      for (var i = 0; i < 7; i++)
        scheduler.scheduled[reminderOccurrenceId('n_daily', i)]!.fireAt,
    ];
    for (var i = 1; i < times.length; i++) {
      expect(times[i].difference(times[i - 1]), const Duration(days: 1));
    }
    for (final id in scheduler.scheduled.keys) {
      expect(id.length, lessThan(16), reason: 'the queue rejects 16: $id');
    }
    expect(scheduler.scheduled.keys.toSet().length, 7);
  });

  test('queued occurrences that are no longer wanted are taken back', () async {
    final note = createNote('n_queue', 'Water the plants');
    repo.setDueAt(
      note.id,
      DateTime.utc(2026, 10, 1, 9),
      repeat: NoteRepeat.daily,
    );
    final now = DateTime.utc(2026, 10, 10, 10);
    await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );
    expect(scheduler.scheduled.length, 7);
    // The series becomes a one-off: only the one queue entry may remain.
    repo.setDueAt(note.id, DateTime.utc(2026, 10, 12, 9));
    await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );
    expect(scheduler.scheduled.keys, [reminderOccurrenceId('n_queue', 0)]);
  });

  test(
    'missed one-off reminder is shown once and old reminders are ignored',
    () async {
      final now = DateTime.utc(2026, 10, 10, 12);
      final recent = createNote('recent', 'Missed recently');
      final old = createNote('old', 'Expired reminder');
      repo.setDueAt(recent.id, now.subtract(const Duration(hours: 47)));
      repo.setDueAt(old.id, now.subtract(const Duration(hours: 49)));
      final notified = <String>{};
      final first = await ReminderReconciliationEngine.reconcile(
        repo: repo,
        scheduler: scheduler,
        nowOverride: now,
        notifiedOverdueIds: notified,
      );
      expect(first.overdueCount, 1);
      expect(scheduler.overdueShown.single.noteId, recent.id);
      final second = await ReminderReconciliationEngine.reconcile(
        repo: repo,
        scheduler: scheduler,
        nowOverride: now,
        notifiedOverdueIds: notified,
      );
      expect(second.overdueCount, 0);
      expect(scheduler.overdueShown.length, 1);
    },
  );

  test('weekly repeat advances fireAt past current time', () async {
    final note = createNote('n_weekly', 'Trash collection');
    final pastStart = DateTime.utc(2026, 10, 1, 8, 0); // Thursday
    repo.setDueAt(note.id, pastStart, repeat: NoteRepeat.weekly);

    final now = DateTime.utc(2026, 10, 10, 10, 0); // Saturday
    final summary = await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );

    expect(summary.scheduledCount, 8);
    expect(
      scheduler.scheduled['n_weekly']!.fireAt,
      DateTime.utc(2026, 10, 15, 8, 0),
    );
    expect(
      scheduler.scheduled[reminderOccurrenceId('n_weekly', 7)]!.fireAt,
      DateTime.utc(2026, 12, 3, 8, 0),
    );
  });

  test('daily reminders notify once for each occurrence', () async {
    final note = createNote('daily_once', 'Daily reminder');
    repo.setDueAt(note.id, DateTime.utc(2026, 10, 1, 9), repeat: NoteRepeat.daily);
    final seen = <String>{};
    final now = DateTime.utc(2026, 10, 10, 9, 1);
    final first = await ReminderReconciliationEngine.reconcile(
      repo: repo, scheduler: scheduler, nowOverride: now, notifiedOverdueIds: seen,
    );
    expect(first.overdueCount, 1);
    final second = await ReminderReconciliationEngine.reconcile(
      repo: repo, scheduler: scheduler,
      nowOverride: now.add(const Duration(minutes: 1)),
      notifiedOverdueIds: seen,
    );
    expect(second.overdueCount, 0);
    final tomorrow = await ReminderReconciliationEngine.reconcile(
      repo: repo, scheduler: scheduler,
      nowOverride: now.add(const Duration(days: 1)),
      notifiedOverdueIds: seen,
    );
    expect(tomorrow.overdueCount, 1);
    expect(scheduler.overdueShown.length, 2);
  });

  test('cancelling or clearing reminder removes it from schedule', () async {
    final note = createNote('n1', 'Team standup');
    final futureTime = DateTime.utc(2026, 10, 10, 14, 0);
    repo.setDueAt(note.id, futureTime);

    final now = DateTime.utc(2026, 10, 10, 9, 0);
    await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );
    expect(scheduler.scheduled.containsKey('n1'), isTrue);

    // Clear reminder
    repo.setDueAt(note.id, null);
    final summary = await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );

    expect(summary.cancelledCount, 1);
    expect(scheduler.scheduled.containsKey('n1'), isFalse);
    expect(scheduler.cancelled, contains('n1'));
  });

  test('soft-deleting note removes reminder from schedule', () async {
    final note = createNote('n1', 'Temporary reminder');
    repo.setDueAt(note.id, DateTime.utc(2026, 10, 10, 14, 0));

    final now = DateTime.utc(2026, 10, 10, 9, 0);
    await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );
    expect(scheduler.scheduled.containsKey('n1'), isTrue);

    repo.softDelete(note.id);
    final summary = await ReminderReconciliationEngine.reconcile(
      repo: repo,
      scheduler: scheduler,
      nowOverride: now,
    );

    expect(summary.cancelledCount, 1);
    expect(scheduler.scheduled.containsKey('n1'), isFalse);
  });
}
