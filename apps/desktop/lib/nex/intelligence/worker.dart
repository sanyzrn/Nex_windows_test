import 'package:nex_ai/cloud.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';

/// Confirmation has happened in the UI. Validate every target before a single
/// write, then commit the whole database portion together with its FTS changes.
List<String> executeDesktopAiActions(
  NexDatabase database,
  String device,
  List<AssistantAction> actions,
) {
  final notes = SqliteNoteRepository(database, localDeviceId: device);
  final threads = SqliteThreadRepository(
    database,
    notes,
    localDeviceId: device,
  );
  final commitments = SqliteCommitmentRepository(
    database,
    localDeviceId: device,
  );
  final capture = CaptureService(notes, deviceId: device);
  final created = <String>[];
  Tag? tagNamed(String? name) => notes
      .listTags()
      .where((t) => t.name.toLowerCase() == name?.toLowerCase())
      .firstOrNull;
  NexCommitment? commitmentNamed(String? name) => commitments
      .list()
      .where((c) => c.title.toLowerCase() == name?.toLowerCase())
      .firstOrNull;
  for (final a in actions) {
    if (a.isRead || a.kind == AssistantActionKind.setting) {
      throw ArgumentError('Not a database write');
    }
    final targets = {if (a.noteId != null) a.noteId!, ...a.noteIds};
    for (final id in targets) {
      final rows = notes.db.select(
        'SELECT deleted_at FROM notes WHERE id = ?',
        [id],
      );
      if (rows.isEmpty ||
          (a.kind != AssistantActionKind.restore &&
              rows.single['deleted_at'] != null)) {
        throw StateError('Action target is unavailable');
      }
    }
    if ((a.kind == AssistantActionKind.create ||
            a.kind == AssistantActionKind.remind) &&
        a.at != null &&
        a.repeat == NoteRepeat.once &&
        !a.at!.isAfter(DateTime.now())) {
      throw StateError('Reminder time has passed');
    }
    if ((a.kind == AssistantActionKind.tagColor ||
            a.kind == AssistantActionKind.renameTag) &&
        tagNamed(a.tagName) == null) {
      throw StateError('Tag is unavailable');
    }
    if ((a.kind == AssistantActionKind.commitmentMet ||
            a.kind == AssistantActionKind.commitmentDelete) &&
        commitmentNamed(a.commitmentName) == null) {
      throw StateError('Commitment is unavailable');
    }
    if (a.kind == AssistantActionKind.check) {
      final n = notes.getById(a.noteId!);
      if (n == null ||
          n.type != NoteType.checklist ||
          a.index == null ||
          a.index! < 0 ||
          a.index! >= n.checklistItems.length) {
        throw StateError('Checklist item is unavailable');
      }
    }
  }
  return notes.db.together(() {
    for (final a in actions) {
      switch (a.kind) {
        case AssistantActionKind.create:
          final n = a.items.isNotEmpty
              ? capture.submitChecklistCapture(
                  a.items
                      .map((t) => ChecklistItem(text: t, done: false))
                      .toList(),
                )
              : capture.submitTextCapture(a.text!);
          if (n == null) throw StateError('Capture was empty');
          created.add(n.id);
          if (a.at != null) notes.setDueAt(n.id, a.at, repeat: a.repeat);
        case AssistantActionKind.edit:
          notes.updateContent(a.noteId!, a.text!);
        case AssistantActionKind.delete:
          notes.softDelete(a.noteId!);
        case AssistantActionKind.restore:
          notes.undelete(a.noteId!);
        case AssistantActionKind.pin:
          if (a.flag ?? true) {
            if (!notes.pinNote(a.noteId!)) {
              throw StateError('Pin limit reached');
            }
          } else {
            notes.unpinNote(a.noteId!);
          }
        case AssistantActionKind.remind:
          notes.setDueAt(a.noteId!, a.at, repeat: a.repeat);
        case AssistantActionKind.title:
          notes.setTitle(a.noteId!, a.text);
        case AssistantActionKind.tag:
          for (final name in a.addTags) {
            final tag = notes.upsertTag(name: name);
            notes.attachTag(noteId: a.noteId!, tagId: tag.id);
          }
          for (final name in a.removeTags) {
            final tag = tagNamed(name);
            if (tag != null) notes.detachTag(noteId: a.noteId!, tagId: tag.id);
          }
        case AssistantActionKind.merge:
          notes.updateContent(a.noteIds.first, a.text!);
          for (final id in a.noteIds.skip(1)) {
            notes.softDelete(id);
          }
        case AssistantActionKind.toChecklist:
          final n = notes.getById(a.noteId!)!;
          final items = (n.content ?? '')
              .split('\n')
              .where((s) => s.trim().isNotEmpty)
              .map(
                (s) => ChecklistItem(
                  text: s.replaceFirst(RegExp(r'^\s*[-*]\s*'), ''),
                  done: false,
                ),
              )
              .toList();
          notes.db.execute('UPDATE notes SET type = ? WHERE id = ?', [
            NoteType.checklist.wireName,
            n.id,
          ]);
          notes.updateContent(n.id, formatChecklist(items));
        case AssistantActionKind.check:
          final n = notes.getById(a.noteId!)!;
          if (a.flag == null || n.checklistItems[a.index!].done != a.flag) {
            notes.toggleChecklistItem(n.id, a.index!);
          }
        case AssistantActionKind.renameTag:
          LibraryMaintenance(notes).renameTag(tagNamed(a.tagName)!.id, a.text!);
        case AssistantActionKind.tagColor:
          notes.setTagColor(tagId: tagNamed(a.tagName)!.id, color: a.text);
        case AssistantActionKind.thread:
          var thread = threads
              .list()
              .where((t) => t.name.toLowerCase() == a.threadName!.toLowerCase())
              .firstOrNull;
          if (thread == null) {
            final now = DateTime.now().toUtc().toIso8601String();
            final id = newUuidV7();
            notes.db.execute(
              'INSERT INTO threads (id,name,created_at,updated_at,device_id) VALUES (?,?,?,?,?)',
              [id, a.threadName, now, now, device],
            );
            thread = threads.getById(id)!;
          }
          for (final id in a.noteIds) {
            threads.add(thread.id, id);
          }
        case AssistantActionKind.commitment:
          final existing = commitmentNamed(a.commitmentName);
          final now = DateTime.now();
          commitments.save(
            NexCommitment(
              id: existing?.id ?? newUuidV7(),
              title: a.commitmentName!,
              cadence: a.cadence!,
              every: a.every!,
              dueAt: a.at ?? existing?.dueAt ?? now,
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
              rev: (existing?.rev ?? 0) + 1,
              details: existing?.details ?? {},
            ),
          );
        case AssistantActionKind.commitmentMet:
          commitments.markMet(commitmentNamed(a.commitmentName)!.id);
        case AssistantActionKind.commitmentDelete:
          commitments.delete(commitmentNamed(a.commitmentName)!.id);
        default:
          throw ArgumentError('Unsupported action');
      }
    }
    return created;
  });
}
