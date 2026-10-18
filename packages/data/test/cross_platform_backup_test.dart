import 'dart:convert';
import 'dart:io';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'fixtures/android_full_backup_codec.dart' as android;

void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/android_214_backup.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  late Directory root;
  setUp(
    () => root = Directory.systemTemp.createTempSync('nex-cross-platform-'),
  );
  tearDown(() => root.deleteSync(recursive: true));
  File source(String field, String name) =>
      File('${root.path}/$name')
        ..writeAsBytesSync(base64Decode(fixture[field] as String));

  void verifyLibrary(NexDatabase db, String media) {
    final notes = SqliteNoteRepository(db, localDeviceId: 'windows-receiver');
    expect(notes.listTimeline(), hasLength(6));
    final note = notes.getById('android-text')!;
    expect(note.content, 'متن مشترک **Nex**');
    expect(note.summaryText, 'خلاصهٔ آزمایشی');
    expect(note.pinnedAt, isNotNull);
    expect(note.dueRepeat, NoteRepeat.weekly);
    expect(note.dueAt, DateTime.utc(2100, 1, 2, 8));
    expect(note.tags.single.name, 'مشترک');
    expect(note.tags.single.color, '#B61615');
    expect(note.deviceId, 'android-fixture-device');
    expect(note.attachmentCount, 1);
    final attachments = SqliteAttachmentRepository(
      notes,
      localDeviceId: 'windows-receiver',
    ).forNote(note.id);
    expect(attachments.single.name, 'invoice.txt');
    expect(
      File(attachments.single.mediaUri).readAsStringSync(),
      'invoice فارسی',
    );
    expect(attachments.single.mediaUri, startsWith(media));
    expect(
      notes.search(const SearchFilters(query: 'فاکتور')).map((n) => n.id),
      contains(note.id),
    );
    for (final note in notes.listTimeline()) {
      if (note.mediaUri case final uri?) {
        expect(uri, startsWith(media));
        expect(File(uri).existsSync(), isTrue);
      }
    }
    expect(
      db.db.select('SELECT id FROM scheduled_notes').single['id'],
      'android-scheduled',
    );
    expect(
      db.db.select('SELECT body FROM module_records').single['body'],
      contains('پیاده‌روی'),
    );
    expect(
      db.db.select('SELECT id FROM cycle_periods').single['id'],
      'android-cycle',
    );
  }

  test(
    'Android library survives Windows restore, cleanup and return backup',
    () {
      final library = source('library', 'android.nexbak');
      final dbPath = '${root.path}/windows/nex.sqlite';
      final media = '${root.path}/windows/media';
      Directory('${root.path}/windows').createSync();
      NexBackupArchive.restore(
        liveDbPath: dbPath,
        mediaDir: media,
        backupFile: library.path,
      );
      final db = NexDatabase.open(dbPath);
      verifyLibrary(db, media);
      final notes = SqliteNoteRepository(db, localDeviceId: 'windows-receiver');
      final attachment = SqliteAttachmentRepository(
        notes,
        localDeviceId: 'windows-receiver',
      ).forNote('android-text').single;
      File(attachment.mediaUri).setLastModifiedSync(DateTime.utc(2000));
      LibraryMaintenance(notes, mediaRoot: media).sweepOrphanMedia();
      expect(File(attachment.mediaUri).existsSync(), isTrue);
      final returned = NexBackupArchive.create(
        database: db,
        mediaDir: media,
        backupDir: '${root.path}/returned',
      );
      db.close();
      final receiver = '${root.path}/ios-sandbox';
      Directory(receiver).createSync();
      NexBackupArchive.restore(
        liveDbPath: '$receiver/nex.sqlite',
        mediaDir: '$receiver/media',
        backupFile: returned.path,
      );
      final restored = NexDatabase.open('$receiver/nex.sqlite');
      try {
        verifyLibrary(restored, '$receiver/media');
      } finally {
        restored.close();
      }
    },
  );

  test(
    'mobile model is optional on desktop; Windows full container opens in Android codec',
    () {
      final renamed = source('fullWithModel', 'download.BIN');
      expect(FullBackup.isFullBackup(renamed.path), isTrue);
      final settings = FullBackup.unpack(
        renamed.path,
        '${root.path}/unpack',
        fixture['key'] as String,
        modelHash: '',
        modelBytes: 0,
        includeModel: false,
      );
      expect(File('${root.path}/unpack/model.litertlm').existsSync(), isFalse);
      expect(
        (settings['preferences'] as Map)['appearance.theme_preset'],
        'circuit',
      );
      const shared = <String, dynamic>{
        'version': PortablePreferences.settingsVersion,
        'scope': 'shared',
        'preferences': {'appearance.theme_preset': 'circuit'},
        'credentials': <String, String>{},
      };
      final out = '${root.path}/windows.nexfull';
      FullBackup.create(
        library: '${root.path}/unpack/library.nexbak',
        output: out,
        settings: shared,
        key: fixture['key'] as String,
      );
      final decoded = android.FullBackup.unpack(
        out,
        '${root.path}/android-return',
        fixture['key'] as String,
        modelHash: '',
        modelBytes: 0,
      );
      PortablePreferences.validateScopedBackup(decoded);
      expect(decoded, shared);
      expect(
        File('${root.path}/android-return/library.nexbak').readAsBytesSync(),
        File('${root.path}/unpack/library.nexbak').readAsBytesSync(),
      );
    },
  );

  test(
    'Android v3 export imports attachments and scheduled notes additively',
    () async {
      final exported = source('export', 'android-export.zip');
      final db = NexDatabase.open('${root.path}/import.sqlite');
      try {
        final repo = SqliteNoteRepository(db, localDeviceId: 'windows-import');
        final imported = await repo.importArchive(
          archiveFile: exported,
          mediaRoot: '${root.path}/import-media',
        );
        expect(imported.imported, 6);
        expect(repo.getById('android-text')!.attachmentCount, 1);
        expect(
          SqliteScheduledNoteRepository(db, repo).pending().single.id,
          'android-scheduled',
        );
        final again = await repo.importArchive(
          archiveFile: exported,
          mediaRoot: '${root.path}/import-media',
        );
        expect(again.imported, 0);
        expect(
          SqliteAttachmentRepository(
            repo,
            localDeviceId: 'windows-import',
          ).forNote('android-text'),
          hasLength(1),
        );
      } finally {
        db.close();
      }
    },
  );

  test('newer schema is rejected before replacing the current database', () {
    final live = NexDatabase.open('${root.path}/live.sqlite');
    final capture = CaptureService(
      SqliteNoteRepository(live),
      deviceId: 'local',
    );
    final id = capture.submitTextCapture('keep me')!.id;
    live.close();
    final future = sqlite3.open('${root.path}/future.sqlite');
    future.execute('CREATE TABLE notes (id TEXT)');
    future.execute('PRAGMA user_version = 999');
    future.dispose();
    expect(
      () => NexBackupArchive.restore(
        liveDbPath: '${root.path}/live.sqlite',
        mediaDir: '${root.path}/media',
        backupFile: '${root.path}/future.sqlite',
      ),
      throwsStateError,
    );
    final reopened = NexDatabase.open('${root.path}/live.sqlite');
    try {
      expect(SqliteNoteRepository(reopened).getById(id)!.content, 'keep me');
    } finally {
      reopened.close();
    }
  });
}
