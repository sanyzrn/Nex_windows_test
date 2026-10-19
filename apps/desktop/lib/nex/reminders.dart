// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import '../core/native.dart';
import 'reminder_policy.dart';

/// Interface for scheduling durable Windows toast reminders.
abstract interface class ReminderScheduler {
  Future<bool> schedule({
    required String id,
    required String noteId,
    required String title,
    required String body,
    required DateTime fireAt,
  });

  Future<bool> cancel(String id);

  Future<bool> showOverdue({
    required String id,
    required String noteId,
    required String title,
    required String body,
    DateTime? occurrence,
  });

  Future<Set<String>> listScheduledIds();
}

/// Native Windows implementation delegating to C++/WinRT scheduled toast notifications.
class NativeReminderScheduler implements ReminderScheduler {
  NativeReminderScheduler(this._host);

  final NativeHost _host;

  @override
  Future<bool> schedule({
    required String id,
    required String noteId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) => _host.scheduleReminder(
    id: id,
    noteId: noteId,
    title: title,
    body: body,
    fireAt: fireAt,
  );

  @override
  Future<bool> cancel(String id) => _host.cancelReminder(id);

  @override
  Future<bool> showOverdue({
    required String id,
    required String noteId,
    required String title,
    required String body,
    DateTime? occurrence,
  }) => _host.showOverdueReminder(
    id: id,
    noteId: noteId,
    title: title,
    body: body,
    occurrence: occurrence,
  );

  @override
  Future<Set<String>> listScheduledIds() async {
    final list = await _host.listScheduledReminders();
    return list.toSet();
  }
}

/// In-memory scheduler for unit and widget testing.
class ScheduledReminderEntry {
  const ScheduledReminderEntry({
    required this.id,
    required this.noteId,
    required this.title,
    required this.body,
    required this.fireAt,
  });

  final String id;
  final String noteId;
  final String title;
  final String body;
  final DateTime fireAt;
}

class FakeReminderScheduler implements ReminderScheduler {
  final Map<String, ScheduledReminderEntry> scheduled = {};
  final List<String> cancelled = [];
  final List<ScheduledReminderEntry> overdueShown = [];

  @override
  Future<bool> schedule({
    required String id,
    required String noteId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    scheduled[id] = ScheduledReminderEntry(
      id: id,
      noteId: noteId,
      title: title,
      body: body,
      fireAt: fireAt,
    );
    return true;
  }

  @override
  Future<bool> cancel(String id) async {
    scheduled.remove(id);
    cancelled.add(id);
    return true;
  }

  @override
  Future<bool> showOverdue({
    required String id,
    required String noteId,
    required String title,
    required String body,
    DateTime? occurrence,
  }) async {
    overdueShown.add(
      ScheduledReminderEntry(
        id: id,
        noteId: noteId,
        title: title,
        body: body,
        fireAt: (occurrence ?? DateTime.now()).toUtc(),
      ),
    );
    return true;
  }

  @override
  Future<Set<String>> listScheduledIds() async => scheduled.keys.toSet();
}

class ReconciliationSummary {
  const ReconciliationSummary({
    required this.scheduledCount,
    required this.cancelledCount,
    required this.overdueCount,
    this.failedCount = 0,
  });

  final int scheduledCount;
  final int cancelledCount;
  final int overdueCount;
  final int failedCount;
}

/// Pure Dart engine that keeps the scheduled toast notifications in sync with SQLite.
class ReminderReconciliationEngine {
  /// Computes the next scheduled time for repeating series that started in the past.
  static DateTime computeNextOccurrence(
    DateTime dueAt,
    NoteRepeat repeat,
    DateTime now,
  ) {
    return nextReminderOccurrence(dueAt, repeat, now);
  }

  /// Reconciles the scheduled set against active non-deleted notes in the database.
  static Future<ReconciliationSummary> reconcile({
    required SqliteNoteRepository repo,
    required ReminderScheduler scheduler,
    DateTime? nowOverride,
    Set<String>? notifiedOverdueIds,
  }) async {
    final now = (nowOverride ?? DateTime.now()).toUtc();
    return reconcileNotes(
      notes: reminderCandidates(repo, now),
      scheduler: scheduler,
      nowOverride: now,
      notifiedOverdueIds: notifiedOverdueIds,
    );
  }

  static Future<ReconciliationSummary> reconcileNotes({
    required Iterable<Note> notes,
    required ReminderScheduler scheduler,
    DateTime? nowOverride,
    Set<String>? notifiedOverdueIds,
    String fallbackTitle = 'Nex',
  }) async {
    final now = (nowOverride ?? DateTime.now()).toUtc();

    final targetMap =
        <String, ({DateTime fireAt, String title, String body})>{};
    final noteIds = <String, String>{
      for (final note in notes)
        for (var i = 0; i < reminderLookahead(note.dueRepeat); i++)
          reminderOccurrenceId(note.id, i): note.id,
    };
    int overdueCount = 0;
    int failedCount = 0;

    for (final note in notes) {
      if (note.deletedAt != null || note.dueAt == null) continue;
      final due = note.dueAt!.toUtc();
      final String bodyText;
      final dt = note.displayText?.trim();
      if (dt != null && dt.isNotEmpty) {
        bodyText = String.fromCharCodes(dt.runes.take(240));
      } else {
        final c = note.content?.trim();
        bodyText = (c != null && c.isNotEmpty) ? c : fallbackTitle;
      }
      final titleText = note.title?.trim().isNotEmpty == true
          ? note.title!
          : fallbackTitle;
      final id = reminderScheduleId(note.id);
      final receipt = reminderReceipt(note);

      if (note.dueRepeat == NoteRepeat.once) {
        if (!due.isAfter(now)) {
          if (now.difference(due).inHours < 48) {
            final shouldShow =
                notifiedOverdueIds == null ||
                !notifiedOverdueIds.contains(receipt);
            if (shouldShow) {
              final shown = await scheduler.showOverdue(
                id: id,
                noteId: note.id,
                title: titleText,
                body: bodyText,
                occurrence: due,
              );
              if (shown) {
                notifiedOverdueIds?.add(receipt);
                overdueCount++;
              } else {
                failedCount++;
              }
            }
          }
        } else {
          targetMap[id] = (fireAt: due, title: titleText, body: bodyText);
        }
      } else {
        final nextFire = computeNextOccurrence(due, note.dueRepeat, now);
        // The next few occurrences are queued too, so the series keeps
        // ringing while Nex is closed.
        var fireAt = nextFire;
        for (var i = 0; i < reminderLookahead(note.dueRepeat); i++) {
          targetMap[reminderOccurrenceId(note.id, i)] = (
            fireAt: fireAt,
            title: titleText,
            body: bodyText,
          );
          fireAt = computeNextOccurrence(due, note.dueRepeat, fireAt);
        }
      }
    }

    final currentlyScheduled = await scheduler.listScheduledIds();
    int cancelledCount = 0;
    int scheduledCount = 0;

    for (final id in currentlyScheduled) {
      if (!targetMap.containsKey(id)) {
        if (await scheduler.cancel(id)) {
          cancelledCount++;
        } else {
          failedCount++;
        }
      }
    }

    for (final entry in targetMap.entries) {
      final scheduled = await scheduler.schedule(
        id: entry.key,
        noteId: noteIds[entry.key]!,
        title: entry.value.title,
        body: entry.value.body,
        fireAt: entry.value.fireAt,
      );
      if (scheduled) {
        scheduledCount++;
      } else {
        failedCount++;
      }
    }

    return ReconciliationSummary(
      scheduledCount: scheduledCount,
      cancelledCount: cancelledCount,
      overdueCount: overdueCount,
      failedCount: failedCount,
    );
  }
}
