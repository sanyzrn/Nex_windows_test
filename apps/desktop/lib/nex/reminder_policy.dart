import 'dart:convert';
import 'dart:typed_data';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';

/// Keep below the documented 16-character limit: the actual Windows queue
/// rejects a 16-character ID on supported Windows 11 (WPN_E_DEV_ID_SIZE).
String reminderScheduleId(String noteId) => noteId.length < 16
    ? noteId
    : 'nx${sha256OfBytes(Uint8List.fromList(utf8.encode(noteId))).substring(0, 13)}';

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
