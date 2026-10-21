import 'dart:convert';
import 'dart:typed_data';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';

/// Keep below the documented 16-character limit: the actual Windows queue
/// rejects a 16-character ID on supported Windows 11 (WPN_E_DEV_ID_SIZE).
String reminderScheduleId(String noteId) => noteId.length < 16
    ? noteId
    : 'nx${sha256OfBytes(Uint8List.fromList(utf8.encode(noteId))).substring(0, 13)}';

/// How many future occurrences of a repeating reminder are queued with
/// Windows at once. Scheduled toasts fire without Nex running, so a series
/// keeps ringing for this long after the app was last opened: a week of
/// daily reminders, two months of weekly ones.
int reminderLookahead(NoteRepeat repeat) => switch (repeat) {
  NoteRepeat.daily => 7,
  NoteRepeat.weekly => 8,
  NoteRepeat.once => 1,
};

/// The queue id of the [index]th upcoming occurrence (0 = the next one).
/// Index 0 keeps the id the note always had; the rest are "nx<hash>r<NN>",
/// 15 characters like every other id (the queue rejects 16).
String reminderOccurrenceId(String noteId, int index) {
  if (index == 0) return reminderScheduleId(noteId);
  final hash = sha256OfBytes(Uint8List.fromList(utf8.encode(noteId)));
  return 'nx${hash.substring(0, 10)}r${index.toString().padLeft(2, '0')}';
}

String reminderReceipt(Note note) =>
    '${note.id}:${note.dueAt!.millisecondsSinceEpoch}';

List<Note> reminderCandidates(SqliteNoteRepository repo, DateTime now) => repo
    .db
    .select(
      '''SELECT id FROM notes WHERE deleted_at IS NULL AND due_at IS NOT NULL
  AND (due_at >= ? OR (due_repeat IS NOT NULL AND due_repeat != 'once'))
  ORDER BY due_at ASC''',
      [now.toUtc().subtract(const Duration(hours: 48)).toIso8601String()],
    )
    .map((row) => repo.getById(row['id'] as String))
    .whereType<Note>()
    .toList();

/// Repeat by local calendar days, preserving the selected wall-clock hour.
DateTime nextReminderOccurrence(DateTime due, NoteRepeat repeat, DateTime now) {
  if (repeat == NoteRepeat.once) return due;
  final local = due.toLocal();
  final step = repeat == NoteRepeat.daily ? 1 : 7;
  var candidate = local;
  while (!candidate.isAfter(now)) {
    candidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day + step,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
    );
  }
  return candidate.toUtc();
}

/// Opaque revision of the reminder itself. setDueAt deliberately does not bump
/// the note's content revision, so that alone cannot reject edited reminders.
int reminderActionVersion(Note note) => int.parse(
  sha256OfBytes(
    Uint8List.fromList(
      utf8.encode(
        '${note.rev}:${note.dueAt?.toUtc().toIso8601String()}:${note.dueRepeat.wireName}',
      ),
    ),
  ).substring(0, 12),
  radix: 16,
);
