// Isolated backup fixture/probe. Never opens the installed app's profile.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:path/path.dart' as p;

import 'package:nex_desktop/core/app_meta.dart';

const _tables = [
  'notes',
  'tags',
  'note_tags',
  'note_attachments',
  'threads',
  'note_threads',
  'cycle_periods',
  'cycle_days',
];
const _settings = <String, dynamic>{
  'version': 2,
  'scope': 'shared',
  'preferences': {
    'appearance.theme': 'dark',
    'appearance.locale': 'fa',
    'appearance.solar_calendar': true,
  },
  'credentials': <String, String>{},
  'desktopShell': {'theme': 'dark', 'language': 'fa'},
};

String _digest(List<int> bytes) => sha256.convert(bytes).toString();
void _writeJson(String file, Object value) => File(
  file,
).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');

Map<String, dynamic> _snapshot(String root) {
  final db = NexDatabase.open(p.join(root, 'nex.sqlite'));
  final mediaRoot = p.join(root, 'media');
  try {
    final tables = <String, dynamic>{};
    for (final table in _tables) {
      final rows = [
        for (final row in db.db.select('SELECT * FROM $table'))
          <String, dynamic>{
            for (final key in row.keys.toList()..sort())
              key: key == 'media_uri' && row[key] != null
                  ? p
                        .relative(row[key] as String, from: mediaRoot)
                        .replaceAll(r'\', '/')
                  : row[key],
          },
      ];
      rows.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
      tables[table] = rows;
    }
    final media = <String, String>{};
    final files = Directory(mediaRoot).existsSync()
        ? Directory(mediaRoot)
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .toList()
        : <File>[];
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      media[p.relative(file.path, from: mediaRoot).replaceAll(r'\', '/')] =
          _digest(file.readAsBytesSync());
    }
    final notes = tables['notes'] as List;
    return {
      'counts': {
        'notes': notes.length,
        'tags': (tables['tags'] as List).length,
        'tagLinks': (tables['note_tags'] as List).length,
        'reminders': notes.where((n) => n['due_at'] != null).length,
        'recurring': notes
            .where((n) => n['due_at'] != null && n['due_repeat'] != 'once')
            .length,
        'attachments': (tables['note_attachments'] as List).length,
        'mediaFiles': media.length,
        'threads': (tables['threads'] as List).length,
        'threadLinks': (tables['note_threads'] as List).length,
        'cyclePeriods': (tables['cycle_periods'] as List).length,
        'cycleDays': (tables['cycle_days'] as List).length,
      },
      'tables': tables,
      'mediaSha256': media,
    };
  } finally {
    db.close();
  }
}

void _seed(String root) {
  final media = Directory(p.join(root, 'media'))..createSync(recursive: true);
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGPcJibKQApgIkn1qIZRDUNKAwDkHQEBlfF2XwAAAABJRU5ErkJggg==',
  );
  for (final name in ['photo.png', 'attached.png']) {
    File(p.join(media.path, name)).writeAsBytesSync(png);
  }
  File(
    p.join(media.path, 'document.txt'),
  ).writeAsStringSync('Synthetic document / سند آزمایشی\n');
  File(
    p.join(media.path, 'attachment.txt'),
  ).writeAsStringSync('Synthetic attachment / پیوست آزمایشی\n');
  // Valid one-second silent 8 kHz, 16-bit mono WAV.
  final wav = ByteData(44 + 16000);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      wav.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  wav.setUint32(4, 36 + 16000, Endian.little);
  ascii(8, 'WAVEfmt ');
  wav.setUint32(16, 16, Endian.little);
  wav.setUint16(20, 1, Endian.little);
  wav.setUint16(22, 1, Endian.little);
  wav.setUint32(24, 8000, Endian.little);
  wav.setUint32(28, 16000, Endian.little);
  wav.setUint16(32, 2, Endian.little);
  wav.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  wav.setUint32(40, 16000, Endian.little);
  File(
    p.join(media.path, 'voice.wav'),
  ).writeAsBytesSync(wav.buffer.asUint8List());
  final db = NexDatabase.open(p.join(root, 'nex.sqlite'));
  try {
    final repo = SqliteNoteRepository(db, localDeviceId: 'synthetic-kit');
    final at = DateTime.utc(2026, 10, 1, 12);
    final contents = {
      NoteType.text:
          'ROUNDTRIP KIT — English\nمتن آزمایشی فارسی؛ بدون اطلاعات شخصی',
      NoteType.checklist:
          '- [x] Checked / انجام‌شده\n- [ ] Pending / انجام‌نشده',
      NoteType.link: 'https://example.com/nex-roundtrip',
      NoteType.photo: 'photo.png',
      NoteType.voice: 'voice.wav',
      NoteType.file: 'document.txt',
    };
    for (final entry in contents.entries) {
      final file =
          [NoteType.photo, NoteType.voice, NoteType.file].contains(entry.key)
          ? File(p.join(media.path, entry.value))
          : null;
      repo.insert(
        Note(
          id: 'kit-${entry.key.name}',
          type: entry.key,
          content: entry.value,
          mediaUri: file?.path,
          mediaHash: file == null ? null : _digest(file.readAsBytesSync()),
          durationMs: entry.key == NoteType.voice ? 1000 : null,
          createdAt: at,
          updatedAt: at,
          deviceId: 'synthetic-kit',
          rev: 1,
          syncState: SyncState.pending,
        ),
      );
    }
    final work = repo.upsertTag(name: 'KIT English', color: '#B61615');
    final fa = repo.upsertTag(name: 'کیت آزمایشی', color: '#008080');
    repo.attachTag(noteId: 'kit-text', tagId: work.id);
    repo.attachTag(noteId: 'kit-text', tagId: fa.id);
    repo.attachTag(noteId: 'kit-checklist', tagId: fa.id);
    repo.pinNote('kit-text');
    repo.setDueAt('kit-text', DateTime.utc(2030, 1, 15, 9));
    repo.setDueAt(
      'kit-checklist',
      DateTime.utc(2030, 1, 16, 9),
      repeat: NoteRepeat.daily,
    );
    repo.setDueAt(
      'kit-link',
      DateTime.utc(2030, 1, 17, 9),
      repeat: NoteRepeat.weekly,
    );
    final attachments = SqliteAttachmentRepository(
      repo,
      localDeviceId: 'synthetic-kit',
    );
    for (final name in ['attached.png', 'attachment.txt']) {
      final file = File(p.join(media.path, name));
      attachments.add(
        'kit-text',
        kind: name.endsWith('.png')
            ? AttachmentKind.photo
            : AttachmentKind.file,
        mediaUri: file.path,
        mediaHash: _digest(file.readAsBytesSync()),
        name: name,
        mimeType: name.endsWith('.png') ? 'image/png' : 'text/plain',
        now: at,
      );
    }
    SqliteThreadRepository(
      db,
      repo,
    ).create('KIT thread / رشتهٔ آزمایشی', noteIds: ['kit-text', 'kit-link']);
    final cycle = SqliteCycleRepository(db);
    final period = cycle.startPeriod(DateTime(2026, 10, 1));
    cycle.endPeriod(period.id, DateTime(2026, 10, 5));
    cycle.saveDay(
      const CycleDayLog(
        day: CycleDate(2026, 10, 6),
        mood: CycleMood.calm,
        note: 'SYNTHETIC ONLY',
      ),
    );
  } finally {
    db.close();
  }
}

Future<Map<String, dynamic>> _verify(
  String file,
  Map<String, dynamic> expected,
  String? key,
) async {
  final root = await Directory.systemTemp.createTemp('nex-roundtrip-verify-');
  try {
    var library = p.absolute(file);
    Map<String, dynamic>? settings;
    if (FullBackup.isFullBackup(file)) {
      if (key == null) throw ArgumentError('Full backup requires a key file');
      final staging = p.join(root.path, 'unpack');
      settings = FullBackup.unpack(
        file,
        staging,
        key.trim(),
        modelHash: '',
        modelBytes: 0,
        includeModel: false,
      );
      library = p.join(staging, 'library.nexbak');
    }
    final restored = p.join(root.path, 'restored');
    Directory(restored).createSync();
    NexBackupArchive.restore(
      liveDbPath: p.join(restored, 'nex.sqlite'),
      mediaDir: p.join(restored, 'media'),
      backupFile: library,
    );
    final actual = _snapshot(restored);
    final changes = [
      for (final table in _tables)
        if (jsonEncode(expected['tables'][table]) !=
            jsonEncode(actual['tables'][table]))
          table,
    ];
    final mediaOk =
        jsonEncode(expected['mediaSha256']) ==
        jsonEncode(actual['mediaSha256']);
    final wantedPrefs = expected['settings']['preferences'] as Map;
    final actualPrefs = settings?['preferences'];
    final bool? settingsOk = settings == null
        ? null
        : actualPrefs is Map &&
              wantedPrefs.entries.every(
                (entry) =>
                    jsonEncode(actualPrefs[entry.key]) ==
                    jsonEncode(entry.value),
              );
    return {
      'file': p.basename(file),
      'host': Platform.operatingSystem,
      'passed': changes.isEmpty && mediaOk && settingsOk != false,
      'counts': actual['counts'],
      'changedTables': changes,
      'mediaSha256Matches': mediaOk,
      'sharedAppearanceMatches': settingsOk,
    };
  } finally {
    await root.delete(recursive: true);
  }
}

Future<void> main(List<String> args) async {
  if (args.length == 2 && args.first == 'generate') {
    final output = Directory(p.absolute(args[1]));
    if (output.existsSync()) throw StateError('Output must be a new directory');
    output.createSync(recursive: true);
    final work = await Directory.systemTemp.createTemp('nex-roundtrip-source-');
    try {
      _seed(work.path);
      final expected = _snapshot(work.path)..['settings'] = _settings;
      final library = p.join(output.path, 'windows-sample.nexbak');
      final full = p.join(output.path, 'windows-sample.nexfull');
      final db = NexDatabase.open(p.join(work.path, 'nex.sqlite'));
      final key = FullBackup.newKey();
      try {
        final backup = NexBackupArchive.create(
          database: db,
          mediaDir: p.join(work.path, 'media'),
          backupDir: p.join(work.path, 'backups'),
        );
        NexBackupArchive.portable(backup.path, library);
        PortablePreferences.validateScopedBackup(_settings);
        FullBackup.create(
          library: library,
          output: full,
          settings: _settings,
          key: key,
        );
      } finally {
        db.close();
      }
      // Remove source files before restoration, proving independent portability.
      await work.delete(recursive: true);
      _writeJson(p.join(output.path, 'expected.json'), expected);
      File(
        p.join(output.path, 'SYNTHETIC-RECOVERY-KEY.txt'),
      ).writeAsStringSync('$key\n');
      final results = [
        await _verify(library, expected, null),
        await _verify(full, expected, key),
      ];
      final hashes = {
        for (final f in [File(library), File(full)])
          p.basename(f.path): _digest(f.readAsBytesSync()),
      };
      _writeJson(p.join(output.path, 'results.json'), {
        'appVersion': kAppVersionString,
        'host': Platform.operatingSystem,
        'results': results,
        'archiveSha256': hashes,
      });
      stdout.writeln(
        jsonEncode({
          'counts': expected['counts'],
          'results': results,
          'archiveSha256': hashes,
        }),
      );
      if (results.any((r) => r['passed'] != true)) exitCode = 1;
    } finally {
      if (work.existsSync()) await work.delete(recursive: true);
    }
  } else if (args.length == 4 || args.length == 5) {
    if (args.first != 'verify') throw ArgumentError('Unknown mode');
    final report = File(args[3]);
    if (report.existsSync()) throw StateError('Report file already exists');
    final expected =
        jsonDecode(File(args[2]).readAsStringSync()) as Map<String, dynamic>;
    final result = await _verify(
      args[1],
      expected,
      args.length == 5 ? File(args[4]).readAsStringSync() : null,
    );
    _writeJson(report.path, result);
    stdout.writeln(jsonEncode(result));
    if (result['passed'] != true) exitCode = 1;
  } else {
    stderr.writeln(
      'Usage: dart run tools/backup_roundtrip.dart generate NEW_OUTPUT_DIRECTORY\n'
      '   or: dart run tools/backup_roundtrip.dart verify BACKUP EXPECTED_JSON NEW_REPORT_JSON [RECOVERY_KEY_FILE]',
    );
    exitCode = 64;
  }
}
