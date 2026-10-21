import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/nex/reminder_activation.dart';
import 'package:nex_desktop/nex/reminder_policy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21, 12);
  String uri(int rev, String action) =>
      'nex-win://reminder/n1?action=$action&rev=$rev&at=${now.millisecondsSinceEpoch}';
  test('only exact action protocols are accepted', () {
    expect(ReminderActivation.parse(uri(2, 'done'))!.action, 'done');
    for (final bad in [
      uri(2, 'erase'),
      '${uri(2, 'done')}&action=done',
      uri(-1, 'done'),
      uri(2, 'done').replaceAll('n1', '%2Fbad'),
      '${uri(2, 'done')}#x',
      uri(2, 'done').replaceAll('nex-win:', 'https:'),
    ]) {
      expect(ReminderActivation.parse(bad), isNull, reason: bad);
    }
  });
  for (final repeat in NoteRepeat.values) {
    test(
      'snooze/done preserve notes and reject replays/stale revisions for $repeat',
      () {
        final root = Directory.systemTemp.createTempSync('nex-action-');
        final db = NexDatabase.open('${root.path}/nex.sqlite');
        final repo = SqliteNoteRepository(db);
        try {
          repo.insert(
            Note(
              id: 'n1',
              type: NoteType.text,
              content: 'Keep this note',
              dueAt: now,
              dueRepeat: repeat,
              createdAt: now,
              updatedAt: now,
              deviceId: 'test',
              rev: 1,
              syncState: SyncState.pending,
            ),
          );
          repo.setDueAt('n1', now, repeat: repeat);
          final rev = reminderActionVersion(repo.getById('n1')!);
          final snooze = ReminderActivation.parse(uri(rev, 'snooze'))!;
          expect(applyReminderActivation(repo, snooze, now), isTrue);
          final note = repo.getById('n1')!;
          expect(note.dueAt, now.add(const Duration(minutes: 10)));
          expect(note.dueRepeat, repeat);
          expect(applyReminderActivation(repo, snooze, now), isFalse);
          expect(note.rev, 1);
          expect(reminderActionVersion(note), isNot(rev));
          expect(
            applyReminderActivation(
              repo,
              ReminderActivation.parse(uri(rev, 'done'))!,
              now,
            ),
            isFalse,
          );
          final done = ReminderActivation(
            'n1',
            'done',
            reminderActionVersion(note),
            note.dueAt!,
          );
          expect(applyReminderActivation(repo, done, note.dueAt!), isTrue);
          expect(repo.getById('n1')!.dueAt, isNull);
          expect(repo.getById('n1')!.content, 'Keep this note');
          expect(applyReminderActivation(repo, done, note.dueAt!), isFalse);
        } finally {
          db.close();
          root.deleteSync(recursive: true);
        }
      },
    );
  }
}
