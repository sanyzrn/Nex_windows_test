// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import '../core/native.dart';

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
  }) =>
      _host.scheduleReminder(
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
  }) =>
      _host.showOverdueReminder(
        id: id,
        noteId: noteId,
        title: title,
        body: body,
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
  }) async {
    overdueShown.add(
      ScheduledReminderEntry(
        id: id,
        noteId: noteId,
        title: title,
        body: body,
        fireAt: DateTime.now().toUtc(),
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
  });

  final int scheduledCount;
  final int cancelledCount;
  final int overdueCount;
}

/// Pure Dart engine that keeps the scheduled toast notifications in sync with SQLite.
class ReminderReconciliationEngine {
  /// Computes the next scheduled time for repeating series that started in the past.
  static DateTime computeNextOccurrence(
    DateTime dueAt,
    NoteRepeat repeat,
    DateTime now,
  ) {
    if (repeat == NoteRepeat.once) {
      return dueAt;
    }
    DateTime candidate = dueAt;
    if (repeat == NoteRepeat.daily) {
      while (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }
    if (repeat == NoteRepeat.weekly) {
      while (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 7));
      }
      return candidate;
    }
    return candidate;
  }

  /// Reconciles the scheduled set against active non-deleted notes in the database.
  static Future<ReconciliationSummary> reconcile({
    required SqliteNoteRepository repo,
    required ReminderScheduler scheduler,
    DateTime? nowOverride,
    Set<String>? notifiedOverdueIds,
  }) async {
    final now = (nowOverride ?? DateTime.now()).toUtc();
    final upcomingNotes = repo.listUpcomingReminders();

    final targetMap =
        <String, ({DateTime fireAt, String title, String body})>{};
    int overdueCount = 0;

    for (final note in upcomingNotes) {
      if (note.deletedAt != null || note.dueAt == null) continue;
      final due = note.dueAt!.toUtc();
      final String bodyText;
      final dt = note.displayText?.trim();
      if (dt != null && dt.isNotEmpty) {
        bodyText = dt;
      } else {
        final c = note.content?.trim();
        bodyText = (c != null && c.isNotEmpty) ? c : 'Nex Note';
      }
      final titleText = note.title?.trim().isNotEmpty == true
          ? note.title!
          : 'Nex Reminder';

      if (note.dueRepeat == NoteRepeat.once) {
        if (due.isBefore(now)) {
          if (now.difference(due).inHours < 48) {
            final shouldShow =
                notifiedOverdueIds == null ||
                !notifiedOverdueIds.contains(note.id);
            if (shouldShow) {
              await scheduler.showOverdue(
                id: note.id,
                noteId: note.id,
                title: titleText,
                body: bodyText,
              );
              notifiedOverdueIds?.add(note.id);
              overdueCount++;
            }
          }
        } else {
          targetMap[note.id] = (
            fireAt: due,
            title: titleText,
            body: bodyText,
          );
        }
      } else {
        final nextFire = computeNextOccurrence(due, note.dueRepeat, now);
        targetMap[note.id] = (
          fireAt: nextFire,
          title: titleText,
          body: bodyText,
        );
      }
    }

    final currentlyScheduled = await scheduler.listScheduledIds();
    int cancelledCount = 0;
    int scheduledCount = 0;

    for (final id in currentlyScheduled) {
      if (!targetMap.containsKey(id)) {
        await scheduler.cancel(id);
        cancelledCount++;
      }
    }

    for (final entry in targetMap.entries) {
      await scheduler.schedule(
        id: entry.key,
        noteId: entry.key,
        title: entry.value.title,
        body: entry.value.body,
        fireAt: entry.value.fireAt,
      );
      scheduledCount++;
    }

    return ReconciliationSummary(
      scheduledCount: scheduledCount,
      cancelledCount: cancelledCount,
      overdueCount: overdueCount,
    );
  }
}
