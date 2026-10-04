import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/nex/store.dart';

void main() {
  test(
    'capture FIFO, reopen Nex schema, FTS, tags, threads and delete undo',
    () async {
      final root = await Directory.systemTemp.createTemp('nex-test-');
      final db = NexDatabase.open('${root.path}/nex.sqlite');
      final android = CaptureService(
        SqliteNoteRepository(db, localDeviceId: 'android'),
        deviceId: 'android',
      ).submitTextCapture('\u06cc\u0627\u062f\u062f\u0627\u0634\u062a \u0642\u062f\u06cc\u0645\u06cc');
      db.close();
      final store = await DesktopStore.open(root.path, 'windows');
      try {
        expect(
          (await store.call<List<Note>>('timeline')).single.id,
          android!.id,
        );
        final session = CaptureSession(store);
        await Future.wait([
          session.write('hello'),
          session.write('hello Persian \u06a9\u06cc\u06a9'),
        ]);
        final note = await store.call<Note>('get', {'id': session.id});
        expect(note.content, 'hello Persian \u06a9\u06cc\u06a9');
        expect(note.rev, 2);
        expect(note.syncState, SyncState.pending);
        expect(note.id.split('-')[2][0], '7');
        final results = await store.call<List<Note>>('search', {
          'filters': const SearchFilters(query: '\u06a9\u06cc\u06a9'),
        });
        expect(results.single.id, note.id);
        // Match the shipping Nex repository's normalization, including its limits.
        final reference = NexDatabase.open('${root.path}/nex.sqlite');
        final androidQuery = SqliteNoteRepository(
          reference,
        ).search(const SearchFilters(query: '\u0643\u064a\u0643'));
        final desktopQuery = await store.call<List<Note>>('search', {
          'filters': const SearchFilters(query: '\u0643\u064a\u0643'),
        });
        expect(desktopQuery.map((n) => n.id), androidQuery.map((n) => n.id));
        reference.close();
        await store.call<dynamic>('tag', {'id': note.id, 'name': '\u06a9\u0627\u0631'});
        expect(
          (await store.call<Note>('get', {'id': note.id})).tags.single.name,
          '\u06a9\u0627\u0631',
        );
        final thread = await store.call<NoteThread>('thread', {
          'id': note.id,
          'name': '\u067e\u0631\u0648\u0698\u0647',
        });
        expect(
          (await store.call<List<Note>>('threadNotes', {
            'thread': thread.id,
          })).single.id,
          note.id,
        );
        await store.call<void>('delete', {'id': note.id});
        expect((await store.call<List<Note>>('trash')).single.id, note.id);
        await store.call<void>('restore', {'id': note.id});
        expect(await store.call<Note?>('get', {'id': note.id}), isNotNull);
        await store.close();
        final reopened = NexDatabase.open('${root.path}/nex.sqlite');
        expect(
          SqliteNoteRepository(reopened).getById(note.id)!.content,
          note.content,
        );
        reopened.close();
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'photo/file content-addressed media and Nex full backup round trip',
    () async {
      final root = await Directory.systemTemp.createTemp('nex-media-');
      final store = await DesktopStore.open(root.path, 'windows');
      try {
        final photo = File('${root.path}/source.png');
        await photo.writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jC1kAAAAASUVORK5CYII=',
          ),
        );
        final note = await store.call<Note>('media', {'path': photo.path});
        final duplicate = await store.call<Note>('media', {'path': photo.path});
        expect(note.type, NoteType.photo);
        expect(duplicate.mediaUri, note.mediaUri);
        expect(note.mediaUri, contains(note.mediaHash!));
        await photo.delete();
        expect(await File(note.mediaUri!).exists(), true);
        final file = File('${root.path}/source.txt');
        await file.writeAsString('attachment');
        final attachment = await store.call<Note>('media', {'path': file.path});
        expect(attachment.type, NoteType.file);
        final output = '${root.path}/complete.nexfull';
        final key = await store.call<String>('fullBackup', {
          'output': output,
          'settings': {'language': 'fa'},
        });
        final restoredSettings = FullBackup.unpack(
          output,
          '${root.path}/extract',
          key,
          modelHash: '',
          modelBytes: 0,
        );
        expect((restoredSettings['desktopShell'] as Map)['language'], 'fa');
        expect(
          () => FullBackup.unpack(
            output,
            '${root.path}/wrong',
            FullBackup.newKey(),
            modelHash: '',
            modelBytes: 0,
          ),
          throwsA(anything),
        );
        NexBackupArchive.restore(
          liveDbPath: '${root.path}/restored/nex.sqlite',
          mediaDir: '${root.path}/restored/media',
          backupFile: '${root.path}/extract/library.nexbak',
        );
        final restored = NexDatabase.open('${root.path}/restored/nex.sqlite');
        final saved = SqliteNoteRepository(restored).getById(note.id)!;
        expect(saved.mediaHash, note.mediaHash);
        expect(File(saved.mediaUri!).existsSync(), true);
        restored.close();
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    '0.10.0 database upgrade with Persian search folding (Arabic/Persian kaf/yeh, ZWNJ)',
    () async {
      final root = await Directory.systemTemp.createTemp('nex-upgrade-');
      final dbPath = '${root.path}/nex.sqlite';
      final seedDb = NexDatabase.open(dbPath);
      final repo = SqliteNoteRepository(seedDb, localDeviceId: 'device-0.10.0');
      final cap = CaptureService(repo, deviceId: 'device-0.10.0');
      // n1 contains Arabic kaf and Arabic yeh: ك (\u0643) and ي (\u064A)
      final n1 = cap.submitTextCapture(
        '\u0643\u062a\u0627\u0628\u062e\u0627\u0646\u0647 \u0648 \u064a\u0627\u062f\u062f\u0627\u0634\u062a',
      )!;
      // n2 contains Persian kaf (\u06A9) and ZWNJ (\u200C)
      final n2 = cap.submitTextCapture(
        '\u06a9\u062a\u0627\u0628\u200c\u062e\u0627\u0646\u0647 \u0632\u06cc\u0628\u0627',
      )!;
      seedDb.db.execute("DELETE FROM nex_meta WHERE key = 'search_index_folded'");
      seedDb.db.execute(
        "UPDATE notes_fts SET content = '\u0643\u062a\u0627\u0628\u062e\u0627\u0646\u0647 \u0648 \u064a\u0627\u062f\u062f\u0627\u0634\u062a' WHERE note_id = '${n1.id}'",
      );
      seedDb.db.execute(
        "UPDATE notes_fts SET content = '\u06a9\u062a\u0627\u0628\u200c\u062e\u0627\u0646\u0647 \u0632\u06cc\u0628\u0627' WHERE note_id = '${n2.id}'",
      );
      seedDb.close();

      final store = await DesktopStore.open(root.path, 'windows');
      try {
        final resArabicKaf = await store.call<List<Note>>('search', {
          'filters': const SearchFilters(query: '\u0643\u062a\u0627\u0628'),
        });
        expect(resArabicKaf.map((n) => n.id).toSet(), {n1.id, n2.id});

        final resPersianKaf = await store.call<List<Note>>('search', {
          'filters': const SearchFilters(query: '\u06a9\u062a\u0627\u0628'),
        });
        expect(resPersianKaf.map((n) => n.id).toSet(), {n1.id, n2.id});

        final resNoZwnj = await store.call<List<Note>>('search', {
          'filters': const SearchFilters(query: '\u06a9\u062a\u0627\u0628\u062e\u0627\u0646\u0647'),
        });
        expect(resNoZwnj.map((n) => n.id).toSet(), {n1.id, n2.id});

        final resWithZwnj = await store.call<List<Note>>('search', {
          'filters': const SearchFilters(query: '\u06a9\u062a\u0627\u0628\u200c\u062e\u0627\u0646\u0647'),
        });
        expect(resWithZwnj.map((n) => n.id).toSet(), {n1.id, n2.id});

        final resYeh = await store.call<List<Note>>('search', {
          'filters': const SearchFilters(query: '\u06cc\u0627\u062f\u062f\u0627\u0634\u062a'),
        });
        expect(resYeh.single.id, n1.id);
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );
}
