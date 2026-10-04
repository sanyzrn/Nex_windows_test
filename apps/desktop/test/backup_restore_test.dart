// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late NexDatabase db;
  late SqliteNoteRepository repo;
  late String mediaDir;
  late String backupDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nex_backup_restore_test_');
    mediaDir = p.join(tmp.path, 'media');
    backupDir = p.join(tmp.path, 'backups');
    Directory(mediaDir).createSync(recursive: true);
    Directory(backupDir).createSync(recursive: true);

    db = NexDatabase.open(p.join(tmp.path, 'nex.sqlite'));
    repo = SqliteNoteRepository(db);
  });

  tearDown(() {
    db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('NexBackupArchive create and restore round-trip preserves notes, due dates and repeats', () {
    final now = DateTime.now().toUtc();
    final note1 = repo.insert(
      Note(
        id: 'n1',
        type: NoteType.text,
        content: 'Note 1 content',
        createdAt: now,
        updatedAt: now,
        deviceId: 'device-a',
        rev: 1,
        syncState: SyncState.pending,
      ),
    );
    final due = now.add(const Duration(days: 3));
    repo.setDueAt(note1.id, due, repeat: NoteRepeat.daily);

    // Create backup archive (.nexbak)
    final archiveFile = NexBackupArchive.create(
      database: db,
      mediaDir: mediaDir,
      backupDir: backupDir,
    );
    expect(archiveFile.existsSync(), isTrue);

    // Close db and clear active database
    db.close();
    File(p.join(tmp.path, 'nex.sqlite')).deleteSync();

    // Restore into live database
    NexBackupArchive.restore(
      liveDbPath: p.join(tmp.path, 'nex.sqlite'),
      mediaDir: mediaDir,
      backupFile: archiveFile.path,
    );

    // Reopen and verify
    final restoredDb = NexDatabase.open(p.join(tmp.path, 'nex.sqlite'));
    final restoredRepo = SqliteNoteRepository(restoredDb);

    final restoredNote = restoredRepo.getById('n1');
    expect(restoredNote, isNotNull);
    expect(restoredNote!.content, 'Note 1 content');
    expect(restoredNote.dueRepeat, NoteRepeat.daily);
    expect(
      restoredNote.dueAt!.millisecondsSinceEpoch,
      closeTo(due.millisecondsSinceEpoch, 1000),
    );

    restoredDb.close();
  });

  test('FullBackup create and unpack round-trip with encrypted settings', () {
    final now = DateTime.now().toUtc();
    repo.insert(
      Note(
        id: 'n_full',
        type: NoteType.text,
        content: 'Confidential Note',
        createdAt: now,
        updatedAt: now,
        deviceId: 'device-w',
        rev: 1,
        syncState: SyncState.pending,
      ),
    );

    final libraryArchive = NexBackupArchive.create(
      database: db,
      mediaDir: mediaDir,
      backupDir: backupDir,
    );

    final key = FullBackup.newKey();
    final fullBackupPath = p.join(backupDir, 'backup.nexfull');
    final shellSettings = {'theme': 'dark', 'windowMode': 'window'};

    FullBackup.create(
      library: libraryArchive.path,
      output: fullBackupPath,
      settings: {'desktopShell': shellSettings},
      key: key,
    );

    expect(File(fullBackupPath).existsSync(), isTrue);

    // Unpack into staging
    final unpackStaging = p.join(tmp.path, 'unpack_stage');
    final unpacked = FullBackup.unpack(
      fullBackupPath,
      unpackStaging,
      key,
      modelHash: '',
      modelBytes: 0,
    );

    expect(unpacked['desktopShell'], equals(shellSettings));
    final stagedLibrary = File(p.join(unpackStaging, 'library.nexbak'));
    expect(stagedLibrary.existsSync(), isTrue);

    // Restore staged library
    db.close();
    File(p.join(tmp.path, 'nex.sqlite')).deleteSync();

    NexBackupArchive.restore(
      liveDbPath: p.join(tmp.path, 'nex.sqlite'),
      mediaDir: mediaDir,
      backupFile: stagedLibrary.path,
    );

    final restoredDb = NexDatabase.open(p.join(tmp.path, 'nex.sqlite'));
    final restoredRepo = SqliteNoteRepository(restoredDb);
    expect(restoredRepo.getById('n_full')?.content, 'Confidential Note');
    restoredDb.close();
  });
}
