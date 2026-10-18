import 'dart:convert';
import 'dart:io';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import '../../../apps/client/lib/platform/full_backup.dart';

Future<void> main(List<String> args) async {
  final root = Directory.systemTemp.createTempSync('nex-android-fixture-');
  try {
    final media = Directory('${root.path}/media')..createSync();
    final photo = File('${media.path}/receipt.png')..writeAsBytesSync(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jC1kAAAAASUVORK5CYII='));
    final audio = File('${media.path}/memo.wav')..writeAsBytesSync(utf8.encode('RIFF fixture audio'));
    final document = File('${media.path}/invoice.txt')..writeAsStringSync('invoice فارسی');
    final db = NexDatabase.open('${root.path}/nex.sqlite');
    final repo = SqliteNoteRepository(db, localDeviceId: 'android-fixture-device');
    final at = DateTime.utc(2026, 10, 18, 9);
    for (final type in NoteType.values) {
      final file = switch(type) { NoteType.photo => photo, NoteType.voice => audio, NoteType.file => document, _ => null };
      repo.insert(Note(id: 'android-${type.name}', type: type,
        content: switch(type) { NoteType.text => 'متن مشترک **Nex**', NoteType.checklist => '- [x] انجام شد\n- [ ] باقی مانده', NoteType.link => 'https://example.com/nex', NoteType.file => 'invoice.txt', _ => null },
        mediaUri: file?.path, mediaHash: file == null ? null : sha256OfBytes(file.readAsBytesSync()),
        durationMs: type == NoteType.voice ? 1200 : null,
        caption: type == NoteType.link ? 'توضیح پیوند' : null,
        title: type == NoteType.link ? 'Nex page' : null,
        linkExcerpt: type == NoteType.link ? 'Original page description' : null,
        ocrText: type == NoteType.photo ? 'رسید خرید' : null,
        transcriptText: type == NoteType.voice ? 'سلام نکس' : null,
        summaryText: type == NoteType.text ? 'خلاصهٔ آزمایشی' : null,
        createdAt: at, updatedAt: at, deviceId: 'android-fixture-device', rev: 3, syncState: SyncState.pending));
    }
    repo.setSummaryText('android-text', 'خلاصهٔ آزمایشی');
    repo.setOcrText('android-photo', 'رسید خرید');
    repo.setTranscriptText('android-voice', 'سلام نکس');
    repo.pinNote('android-text');
    repo.setDueAt('android-text', DateTime.utc(2100, 1, 2, 8), repeat: NoteRepeat.weekly);
    final tag = repo.upsertTag(name: 'مشترک', color: '#B61615');
    repo.attachTag(noteId: 'android-text', tagId: tag.id);
    final attachments = SqliteAttachmentRepository(repo, localDeviceId: 'android-fixture-device');
    final attached = attachments.add('android-text', kind: AttachmentKind.file, mediaUri: document.path,
      mediaHash: sha256OfBytes(document.readAsBytesSync()), name: 'invoice.txt', caption: 'پیوست قابل جستجو', now: at)!;
    attachments.setOcrResult(attached.id, 'شماره فاکتور ۱۲۳');
    db.db.execute("INSERT INTO scheduled_notes VALUES (?, ?, ?, ?)", ['android-scheduled','در آینده نمایش بده',DateTime.utc(2100).toIso8601String(),at.toIso8601String()]);
    db.db.execute("INSERT INTO module_records VALUES (?, ?, ?, ?, ?)", ['habits','habit','android-habit','{"title":"پیاده‌روی"}',at.toIso8601String()]);
    db.db.execute('INSERT INTO cycle_periods VALUES (?, ?, ?)', ['android-cycle','2026-09-01','2026-09-05']);
    final library = NexBackupArchive.create(database: db, mediaDir: media.path, backupDir: '${root.path}/backups');
    final exported = await repo.exportArchive(outputPath: '${root.path}/export.zip', mediaRoot: media.path);
    const key = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=';
    final model = File('${root.path}/model.litertlm')..writeAsStringSync('mobile-only fixture model');
    final full = '${root.path}/mobile.nexfull';
    FullBackup.create(library: library.path, output: full, key: key, model: model.path,
      modelHash: sha256OfBytes(model.readAsBytesSync()), settings: {
        'version': 1,
        'preferences': {'appearance.theme': 'dark', 'appearance.theme_preset': 'circuit', 'appearance.accent_seed': '#B61615', 'appearance.locale': 'fa', 'appearance.ui_scale': 1.2, 'appearance.card_density': 'readable', 'appearance.solar_calendar': true, 'appearance.recent_colors': ['#B61615','#00838F'], 'profile.display_name': 'Android fixture'},
        'credentials': {'openai': 'fixture-secret-never-install-on-windows'},
      });
    final result = {'source': 'sanyzrn/DbsNex@34514226260dc8b1d3da35f91082dbfa9ce46b93 (2.1.4)', 'key': key,
      'library': base64Encode(library.readAsBytesSync()), 'export': base64Encode(exported.readAsBytesSync()), 'fullWithModel': base64Encode(File(full).readAsBytesSync())};
    File(args.single)..parent.createSync(recursive: true)..writeAsStringSync('${jsonEncode(result)}\n');
    db.close();
    stdout.writeln('Android-generated fixture: ${File(args.single).lengthSync()} bytes');
  } finally { root.deleteSync(recursive: true); }
}
