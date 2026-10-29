import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/note_caption.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../../packages/data/test/fixtures/android_full_backup_codec.dart'
    as android;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture =
      jsonDecode(
            File(
              '../../packages/data/test/fixtures/android_214_backup.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  late Directory root;
  late NexFeatures features;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('nex-desktop-compat-');
    features = NexFeatures(
      await DesktopStore.open(root.path, 'windows-local-device'),
    );
  });
  tearDown(() async {
    await features.close();
    await root.delete(recursive: true);
  });

  Future<Map<String, dynamic>> restoreMobile() async {
    final source = File('${root.path}/from-android.BIN')
      ..writeAsBytesSync(base64Decode(fixture['fullWithModel'] as String));
    return (await features.restoreBackup(
      source.path,
      fixture['key'] as String,
    ))!;
  }

  test(
    'Android full backup applies common appearance while retaining Windows host choices',
    () async {
      final current = Settings()
        ..hotkey = 'Q'
        ..edge = 'left'
        ..windowMode = 'panel'
        ..startup = true;
      final restored = Settings.fromBackup(await restoreMobile(), current);
      expect(restored.preset, 'circuit');
      expect(restored.accentSeed, '#B61615');
      expect(restored.uiScale, 1.2);
      expect(restored.cardDensity, 'readable');
      expect(restored.solarCalendar, isTrue);
      expect(restored.hotkey, 'Q');
      expect(restored.edge, 'left');
      expect(restored.windowMode, 'panel');
      expect(restored.startup, isTrue);
      final note = await features.store.call<Note>('get', {
        'id': 'android-text',
      });
      expect(note.attachmentCount, 1);
      final attachments = await features.store.call<List<NoteAttachment>>(
        'attachments',
        {'id': note.id},
      );
      expect(File(attachments.single.mediaUri).existsSync(), isTrue);
      final addedFile = File('${root.path}/from-windows.txt')
        ..writeAsStringSync('new shared attachment');
      final workspaceBefore = await features.store.call<Map>('workspace');
      expect(workspaceBefore['media'], 4);
      final added = await features.store.call<NoteAttachment>('attachMedia', {
        'path': addedFile.path,
        'noteId': note.id,
      });
      expect(added.deviceId, 'windows-local-device');
      expect(
        (await features.store.call<Note>('get', {
          'id': note.id,
        })).attachmentCount,
        2,
      );
      expect((await features.store.call<Map>('workspace'))['media'], 5);
      await features.store.call<void>('removeAttachment', {'id': added.id});
      expect((await features.store.call<Map>('workspace'))['media'], 4);
      await features.store.call<bool>('restoreAttachment', {'id': added.id});
      expect((await features.store.call<Map>('workspace'))['media'], 5);
      await features.store.call<void>('delete', {'id': note.id});
      expect((await features.store.call<Map>('workspace'))['media'], 3);
      await features.store.call<void>('restore', {'id': note.id});
      expect((await features.store.call<Map>('workspace'))['media'], 5);

      final captured = await features.store.call<Note>('capture', {
        'text': 'from Windows',
      });
      expect(captured.deviceId, 'windows-local-device');

      final output = '${root.path}/return.nexfull';
      final key = await features.store.call<String>('fullBackup', {
        'output': output,
        'settings': restored.backupSettings(),
      });
      final androidSettings = android.FullBackup.unpack(
        output,
        '${root.path}/android-return',
        key,
        modelHash: '',
        modelBytes: 0,
      );
      PortablePreferences.validateScopedBackup(androidSettings);
      expect(androidSettings['preferences'], restored.sharedPreferences());
      expect(androidSettings['credentials'], isEmpty);
      expect(
        jsonEncode(androidSettings),
        isNot(contains('fixture-secret-never-install-on-windows')),
      );
    },
  );

  test(
    'incorrect mobile recovery key cannot replace a live Windows library',
    () async {
      await features.session.write('keep Windows draft');
      final source = File('${root.path}/bad-key.nexfull')
        ..writeAsBytesSync(base64Decode(fixture['fullWithModel'] as String));
      await expectLater(
        features.restoreBackup(source.path, FullBackup.newKey()),
        throwsA(isA<StateError>()),
      );
      final notes = await features.store.call<List<Note>>('timeline');
      expect(notes.single.content, 'keep Windows draft');
      expect(features.session.id, notes.single.id);
    },
  );

  test(
    'mobile export is additive and keeps the active Windows draft',
    () async {
      features.composer.text = 'my Windows draft';
      await features.session.write('my Windows draft');
      final captureId = features.session.id;
      final source = File('${root.path}/android-export.zip')
        ..writeAsBytesSync(base64Decode(fixture['export'] as String));
      expect(
        await features.store.call<NexBackupKind>('backupKind', {
          'file': source.path,
        }),
        NexBackupKind.export,
      );
      await features.restoreBackup(source.path, null);
      expect(features.session.id, captureId);
      expect(features.composer.text, 'my Windows draft');
      expect((await features.store.call<List<Note>>('timeline')).length, 7);
      final output = '${root.path}/portable.nexbak';
      await features.store.call<String>('portableBackup', {'output': output});
      expect(NexBackupKind.detect(output), NexBackupKind.library);
    },
  );

  test(
    'invalid desktop settings cannot install their backup library',
    () async {
      await features.session.write('still here');
      final library = File('${root.path}/library.nexbak')
        ..writeAsBytesSync(base64Decode(fixture['library'] as String));
      final full = '${root.path}/malformed.nexfull';
      final key = FullBackup.newKey();
      FullBackup.create(
        library: library.path,
        output: full,
        key: key,
        settings: {
          'version': PortablePreferences.settingsVersion,
          'scope': 'shared',
          'preferences': <String, dynamic>{},
          'credentials': <String, dynamic>{},
          'desktopShell': {'startup': 'invalid'},
        },
      );
      await expectLater(
        features.restoreBackup(full, key),
        throwsA(isA<StateError>()),
      );
      expect(
        (await features.store.call<List<Note>>('timeline')).single.content,
        'still here',
      );
      expect(
        root.listSync().whereType<Directory>().where(
          (d) => d.path.contains('.unpack-'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'unspecified mobile appearance uses mobile defaults, not old Windows choices',
    () {
      final current = Settings()
        ..preset = 'forest'
        ..theme = 'light'
        ..accentSeed = '#B61615'
        ..uiScale = 1.4;
      final restored = Settings.fromBackup({
        'version': 1,
        'preferences': <String, dynamic>{},
        'credentials': <String, dynamic>{},
      }, current);
      expect(restored.theme, 'system');
      expect(restored.language, 'system');
      expect(restored.preset, 'classic');
      expect(restored.accentSeed, isNull);
      expect(restored.uiScale, 1);
    },
  );

  testWidgets(
    'custom accent and system brightness invalidate the cached theme',
    (tester) async {
      final controller = PanelController();
      await controller.bootstrap(
        preset: Settings()..theme = 'system',
        useNative: false,
      );
      addTearDown(controller.dispose);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      expect(controller.appTheme.brightness, Brightness.light);
      final before = controller.appTheme;
      controller.S.accentSeed = '#B61615';
      expect(identical(controller.appTheme, before), isFalse);
      final light = controller.appTheme;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      expect(controller.appTheme.brightness, Brightness.dark);
      expect(identical(controller.appTheme, light), isFalse);
    },
  );

  testWidgets(
    'Android photo captions edit and round-trip with their independent fields intact',
    (t) async {
      await t.runAsync(restoreMobile);
      final photos = (await t.runAsync(
        () => features.store.call<List<Note>>('timeline'),
      ))!.where((note) => note.type == NoteType.photo).toList();
      expect(photos, isNotEmpty);
      final photo = photos.first;
      final original = photo.toJson();
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NexScope(
            features: features,
            child: Scaffold(
              body: NexNoteCaption(
                note: photo,
                onSave: (text) => features.store.call<void>('caption', {
                  'id': photo.id,
                  'text': text,
                }),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('note-caption-field')), findsNothing);
      if (photo.title?.isNotEmpty == true && photo.title != photo.caption) {
        expect(find.text(photo.title!), findsNothing);
      }
      await t.tap(find.byKey(const ValueKey('edit-note-caption')));
      await t.pumpAndSettle();
      final field = find.byKey(const ValueKey('note-caption-field'));
      expect(t.widget<TextField>(field).controller!.text, photo.caption ?? '');
      await t.enterText(field, 'شرح ویرایش‌شده در ویندوز\nخط دوم');
      await t.tap(find.byKey(const ValueKey('save-note-caption')));
      await t.runAsync(() async {
        final edited = await features.store.call<Note>('get', {'id': photo.id});
        for (final key in [
          'id',
          'type',
          'content',
          'title',
          'ocr_text',
          'transcript_text',
          'media_hash',
        ]) {
          expect(edited.toJson()[key], original[key], reason: key);
        }
        final output = '${root.path}/caption-return.nexfull';
        final key = await features.store.call<String>('fullBackup', {
          'output': output,
          'settings': Settings().backupSettings(),
        });
        final unpacked = '${root.path}/android-caption-return';
        android.FullBackup.unpack(
          output,
          unpacked,
          key,
          modelHash: '',
          modelBytes: 0,
        );
        final restoredDb = '${root.path}/return.sqlite';
        NexBackupArchive.restore(
          liveDbPath: restoredDb,
          mediaDir: '${root.path}/return-media',
          backupFile: '$unpacked/library.nexbak',
        );
        final db = NexDatabase.open(restoredDb);
        try {
          final returned = SqliteNoteRepository(db).getById(photo.id)!;
          for (final field in [
            'id',
            'type',
            'caption',
            'title',
            'ocr_text',
            'transcript_text',
            'content',
            'media_hash',
            'rev',
            'device_id',
            'sync_state',
          ]) {
            expect(
              returned.toJson()[field],
              edited.toJson()[field],
              reason: field,
            );
          }
        } finally {
          db.close();
        }
      });
      await t.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'restored Android attachments and legacy captions remain readable and editable',
    (tester) async {
      await tester.runAsync(restoreMobile);
      await tester.runAsync(
        () => features.store.call<void>('caption', {
          'id': 'android-text',
          'text': 'توضیح یادداشت قدیمی',
        }),
      );
      final note = (await tester.runAsync(
        () => features.store.call<Note>('get', {'id': 'android-text'}),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          theme: nexLightTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NexScope(
            features: features,
            child: Scaffold(
              body: NexNoteDetail(note: note, onClose: () {}),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      expect(find.text('invoice.txt'), findsOneWidget);
      expect(find.text('پیوست قابل جستجو'), findsOneWidget);
      expect(find.text('Attach files'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('edit-note-caption')));
      await tester.pumpAndSettle();
      final captionField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'توضیح یادداشت قدیمی',
      );
      expect(captionField, findsOneWidget);
      await tester.enterText(captionField, 'توضیح ویرایش‌شده در ویندوز');
      await tester.tap(find.byKey(const ValueKey('save-note-caption')));
      final edited = await tester.runAsync(
        () => features.store.call<Note>('get', {'id': note.id}),
      );
      expect(edited!.caption, 'توضیح ویرایش‌شده در ویندوز');
      expect(edited.content, note.content);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
