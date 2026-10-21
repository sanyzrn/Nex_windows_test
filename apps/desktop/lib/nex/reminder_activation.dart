import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';

class ReminderActivation {
  const ReminderActivation(
    this.noteId,
    this.action,
    this.revision,
    this.occurrence,
  );
  final String noteId, action;
  final int revision;
  final DateTime occurrence;

  static ReminderActivation? parse(String input) {
    try {
      final uri = Uri.tryParse(input);
      if (uri == null ||
          uri.scheme != 'nex-win' ||
          uri.host != 'reminder' ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort ||
          uri.fragment.isNotEmpty ||
          uri.pathSegments.length != 1 ||
          !RegExp(
            r'^[a-zA-Z0-9_-]{1,128}$',
          ).hasMatch(uri.pathSegments.single) ||
          uri.queryParametersAll.length != 3 ||
          uri.queryParametersAll.values.any((v) => v.length != 1)) {
        return null;
      }
      final action = uri.queryParameters['action'];
      final revision = int.tryParse(uri.queryParameters['rev'] ?? '');
      final epoch = int.tryParse(uri.queryParameters['at'] ?? '');
      if (!const ['snooze', 'done'].contains(action) ||
          revision == null ||
          revision < 0 ||
          epoch == null ||
          epoch < 1 ||
          epoch > 8640000000000000) {
        return null;
      }
      return ReminderActivation(
        uri.pathSegments.single,
        action!,
        revision,
        DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true),
      );
    } on FormatException {
      return null;
    }
  }
}

/// Runs synchronously on the store worker: duplicate or stale activations can
/// never consume a newly edited reminder or postpone it twice. Done removes the
/// reminder, not the note. Snooze retains daily/weekly cadence from the new time.
bool applyReminderActivation(
  SqliteNoteRepository repo,
  ReminderActivation action,
  DateTime now,
) {
  final note = repo.getById(action.noteId);
  if (note == null ||
      note.deletedAt != null ||
      note.dueAt == null ||
      note.rev != action.revision ||
      action.occurrence.isBefore(note.dueAt!) ||
      action.occurrence.isAfter(now.add(const Duration(minutes: 1)))) {
    return false;
  }
  repo.setDueAt(
    note.id,
    action.action == 'done'
        ? null
        : now.toUtc().add(const Duration(minutes: 10)),
    repeat: action.action == 'done' ? NoteRepeat.once : note.dueRepeat,
  );
  return true;
}
