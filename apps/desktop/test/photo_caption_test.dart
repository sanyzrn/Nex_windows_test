import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/l10n/intelligence_strings.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/note_caption.dart';
import 'package:nex_desktop/nex/intelligence/controller.dart';
import 'package:nex_desktop/nex/intelligence/note_panel.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Secrets implements AiSecrets {
  @override
  Future<String?> read(String key) async =>
      key == 'ai.key.openai' ? 'test-key' : null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _Store implements DesktopStore {
  _Store(this.inner);
  final DesktopStore inner;
  bool failAppend = false;
  @override
  String get mediaDir => inner.mediaDir;
  @override
  Stream<void> get libraryChanges => inner.libraryChanges;
  @override
  Future<T> call<T>(String command, [Map<String, dynamic> args = const {}]) {
    if (command == 'appendCaption' && failAppend) {
      return Future<T>.error(StateError('Synthetic save failure'));
    }
    return inner.call<T>(command, args);
  }

  @override
  Future<void> close() => inner.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue);
}

void main() {
  test(
    'caption appends are atomic, idempotent and reject deleted notes',
    () async {
      final root = await Directory.systemTemp.createTemp('nex-append-caption-');
      final store = await DesktopStore.open(root.path, 'caption-test');
      try {
        final note = await store.call<Note>('capture', {'text': 'Test note'});
        await store.call<void>('caption', {
          'id': note.id,
          'text': 'Latest caption',
        });
        await Future.wait([
          store.call<void>('appendCaption', {
            'id': note.id,
            'text': 'Accepted result',
          }),
          store.call<void>('appendCaption', {
            'id': note.id,
            'text': 'Accepted result',
          }),
        ]);
        expect(
          (await store.call<Note>('get', {'id': note.id})).caption,
          'Latest caption\n\nAccepted result',
        );
        await store.call<void>('delete', {'id': note.id});
        await expectLater(
          store.call<void>('appendCaption', {
            'id': note.id,
            'text': 'Must not be saved',
          }),
          throwsStateError,
        );
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );

  const description = 'یک تصویر آزمایشی\nبا توضیح فارسی چندخطی';
  final field = find.byKey(const ValueKey('note-caption-field'));

  for (final locale in ['fa', 'en']) {
    testWidgets('$locale: image AI, caption edits and reopening stay in sync', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({
        'ai.enabled': true,
        'ai.cloud_opt_in': true,
        'ai.provider': 'openai',
      });
      t.view.physicalSize = const Size(900, 1500);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      late Directory root;
      late _Store store;
      late NexFeatures features;
      late Note note;
      Completer<void>? responseGate;
      await t.runAsync(() async {
        root = await Directory.systemTemp.createTemp('nex-photo-caption-');
        store = _Store(await DesktopStore.open(root.path, 'caption-test'));
        final image = File('${root.path}/test.png');
        final bytes = await rootBundle.load('assets/app-logo.png');
        await image.writeAsBytes(bytes.buffer.asUint8List());
        note = await store.call<Note>('media', {'path': image.path});
        await store.call<void>('caption', {
          'id': note.id,
          'text': 'توضیح اولیه',
        });
        note = await store.call<Note>('get', {'id': note.id});
        features = NexFeatures(
          store,
          intelligenceFactory: (store) => DesktopIntelligence(
            store,
            secrets: _Secrets(),
            clientFactory: () => MockClient((request) async {
              await responseGate?.future;
              return http.Response(
                jsonEncode({
                  'choices': [
                    {
                      'message': {'content': description},
                      'finish_reason': 'stop',
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        );
        await features.intelligence.initialize();
      });
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await features.close();
          await root.delete(recursive: true);
        });
      });
      Widget host(Note note) => MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: nexLightTheme(),
        home: NexScope(
          features: features,
          child: Scaffold(
            body: NexNoteDetail(
              key: ValueKey(note.id),
              note: note,
              onClose: () {},
            ),
          ),
        ),
      );
      await t.pumpWidget(host(note));
      await t.pumpAndSettle();
      String label(String key) =>
          AiStrings.of(t.element(find.byType(NoteIntelligencePanel))).t(key);
      Note shown() =>
          t.widget<NexNoteCaption>(find.byType(NexNoteCaption)).note;
      Future<void> edit(String text, {bool save = true}) async {
        final open = find.byKey(const ValueKey('edit-note-caption'));
        await t.ensureVisible(open);
        await t.tap(open);
        await _until(t, () => field.evaluate().isNotEmpty);
        await t.pump(const Duration(milliseconds: 250));
        expect(
          t.widget<TextField>(field).controller!.text,
          shown().caption ?? '',
        );
        await t.enterText(field, text);
        if (save) {
          await t.tap(find.byKey(const ValueKey('save-note-caption')));
        } else {
          await t.tap(find.widgetWithText(TextButton, label('cancel')));
        }
        await _until(t, () => field.evaluate().isEmpty);
      }

      final legacy = note.copyWith(title: 'عنوان قدیمی بکاپ اندروید');
      await t.pumpWidget(host(legacy));
      await t.pump();
      expect(find.text('عنوان قدیمی بکاپ اندروید'), findsNothing);
      expect(find.text('توضیح اولیه'), findsOneWidget);
      expect(field, findsNothing);
      await edit('این تغییر لغو می‌شود', save: false);
      expect(shown().caption, 'توضیح اولیه');

      // Android stores image analysis separately, even before caption acceptance.
      responseGate = Completer<void>();
      await t.tap(find.byTooltip(label('ocr')));
      await _until(t, () => features.intelligence.busy);
      await edit('آخرین ویرایش\nخط بعد');
      await t.runAsync(() async {
        responseGate!.complete();
      });
      await _until(
        t,
        () =>
            !features.intelligence.busy &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(shown().ocrText, description);
      expect(shown().caption, 'آخرین ویرایش\nخط بعد');
      final append = find.widgetWithText(TextButton, label('append'));
      await t.ensureVisible(append);
      final apply = t.widget<TextButton>(append).onPressed!;
      apply();
      apply();
      await _until(
        t,
        () => find
            .byKey(const ValueKey('append-caption-choice'))
            .evaluate()
            .isNotEmpty,
      );
      expect(
        find.byKey(const ValueKey('append-caption-choice')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('append-caption-choice')));
      const expected = 'آخرین ویرایش\nخط بعد\n\n$description';
      await _until(
        t,
        () =>
            shown().caption == expected &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(field, findsNothing);
      expect(find.text(expected), findsOneWidget);
      await edit('$expected\nویرایش دستی');
      expect(shown().caption, '$expected\nویرایش دستی');

      // A replacement must not overwrite a caption edited while the choice is open.
      responseGate = null;
      await t.ensureVisible(find.byTooltip(label('ocr')));
      await t.tap(find.byTooltip(label('ocr')));
      await _until(
        t,
        () =>
            append.evaluate().isNotEmpty &&
            t.widget<TextButton>(append).onPressed != null,
      );
      await t.ensureVisible(append);
      await t.tap(append);
      await _until(
        t,
        () => find
            .byKey(const ValueKey('replace-caption-choice'))
            .evaluate()
            .isNotEmpty,
      );
      await t.runAsync(
        () => store.call<void>('caption', {
          'id': note.id,
          'text': 'تغییر همزمان',
        }),
      );
      await t.tap(find.byKey(const ValueKey('replace-caption-choice')));
      await _until(
        t,
        () =>
            shown().caption == 'تغییر همزمان' &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await _until(
        t,
        () => find.text(label('captionChanged')).evaluate().isNotEmpty,
      );
      await t.ensureVisible(append);
      await t.tap(append);
      await _until(
        t,
        () => find
            .byKey(const ValueKey('replace-caption-choice'))
            .evaluate()
            .isNotEmpty,
      );
      await t.tap(find.byKey(const ValueKey('replace-caption-choice')));
      await _until(
        t,
        () =>
            shown().caption == description &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      await edit('');
      expect(shown().caption, isNull);
      expect(shown().ocrText, description);

      // Reopening with AI disabled still shows persisted image analysis.
      await t.runAsync(() async {
        note = await store.call<Note>('get', {'id': note.id});
        await features.intelligence.setValue('ai.enabled', false);
      });
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(note));
      await t.pumpAndSettle();
      expect(field, findsNothing);
      expect(find.byType(NoteIntelligencePanel), findsOneWidget);
      expect(find.widgetWithText(TextButton, label('append')), findsOneWidget);
      expect(shown().caption, isNull);
      store.failAppend = true;
      await t.ensureVisible(append);
      await t.tap(append);
      await _until(t, () => find.text(label('failed')).evaluate().isNotEmpty);
      expect(shown().caption, isNull);
      store.failAppend = false;
      await t.tap(append);
      await _until(t, () => shown().caption == description);
      expect(find.text(description), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
