// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
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

    expect(summary.scheduledCount, 1);
    expect(scheduler.scheduled['n_daily']!.fireAt, DateTime.utc(2026, 10, 11, 9, 0));
  });

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

    expect(summary.scheduledCount, 1);
    expect(scheduler.scheduled['n_weekly']!.fireAt, DateTime.utc(2026, 10, 15, 8, 0));
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
