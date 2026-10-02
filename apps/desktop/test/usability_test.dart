import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:right_panel/core/controller.dart';
import 'package:right_panel/core/native.dart';
import 'package:right_panel/l10n/app_localizations.dart';
import 'package:right_panel/main.dart';
import 'package:right_panel/nex/features.dart';
import 'package:right_panel/nex/store.dart';
import 'package:right_panel/ui/dock.dart';

class FakeNative extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<void> frames(WidgetTester tester, [int count = 75]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('popup routes cancel pending auto-hide until dismissed', (
    t,
  ) async {
    final c = PanelController(nativeHost: FakeNative());
    await c.bootstrap(preset: Settings(), useNative: false);
    c.open();
    await t.pumpWidget(
      MaterialApp(
        navigatorObservers: [c.routeObserver],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMenu<int>(
                context: context,
                position: const RelativeRect.fromLTRB(10, 10, 100, 100),
                items: const [
                  PopupMenuItem(value: 1, child: Text('Test choice')),
                ],
              ),
              child: const Text('Open test menu'),
            ),
          ),
        ),
      ),
    );
    c.maybeClose();
    await t.tap(find.text('Open test menu'));
    await t.pumpAndSettle();
    c.sticky = false;
    c.blur();
    await t.pump(const Duration(seconds: 1));
    expect(c.isOpen, true);
    expect(c.interacting, true);
    await t.tap(find.text('Test choice'));
    await t.pumpAndSettle();
    expect(c.interacting, false);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    'panel pin cancels a queued hide and blocks blur; explicit close works',
    (t) async {
      final c = PanelController(nativeHost: FakeNative());
      await c.bootstrap(preset: Settings(), useNative: false);
      c.open();
      expect(c.maybeClose(), true);
      c.togglePanelPin();
      c.blur();
      await t.pump(const Duration(seconds: 1));
      expect(c.isOpen, true);
      expect(c.maybeClose(), false);
      expect(Settings.fromMap(c.S.toMap()).panelPinned, true);
      c.close();
      expect(c.isOpen, false);
      c.dispose();
    },
  );

  testWidgets(
    'overlapping interaction leases and focus cannot prematurely unlock',
    (t) async {
      final c = PanelController(nativeHost: FakeNative());
      await c.bootstrap(preset: Settings(), useNative: false);
      c.open();
      final a = c.holdOpen(), b = c.holdOpen();
      a();
      a();
      c.sticky = false;
      c.blur();
      expect(c.isOpen, true);
      expect(c.interacting, true);
      b();
      expect(c.interacting, false);
      c.sticky = false;
      c.focusGained();
      c.blur();
      expect(c.isOpen, true);
      c.focusLost();
      c.focusLost();
      expect(c.typing, false);
      expect(c.maybeClose(), true);
      await t.pump(const Duration(milliseconds: 601));
      expect(c.isOpen, false);
      c.dispose();
    },
  );

  testWidgets(
    'image picker holds owner visible; cancel creates no note or success',
    (t) async {
      late Directory root;
      late NexFeatures f;
      await t.runAsync(() async {
        root = await Directory.systemTemp.createTemp('nex-picker-test-');
        f = NexFeatures(await DesktopStore.open(root.path, 'picker-test'));
      });
      final c = PanelController(nativeHost: FakeNative());
      await c.bootstrap(preset: Settings()..language = 'en', useNative: false);
      c.open();
      final selection = Completer<List<XFile>>();
      await t.pumpWidget(
        MaterialApp(
          theme: c.appTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NexPanelScope(
              controller: c,
              child: NexScope(
                features: f,
                child: SizedBox(
                  width: 360,
                  child: NexCaptureView(
                    pickFiles: (groups) {
                      expect(groups.single.extensions, contains('png'));
                      return selection.future;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Add image'));
      await t.pump();
      c.sticky = false;
      c.blur();
      expect(c.interacting, true);
      expect(c.isOpen, true);
      selection.complete([]);
      await t.pumpAndSettle();
      expect(c.interacting, false);
      expect(f.importedCount, 0);
      expect(f.error, isNull);
      await t.runAsync(() async {
        expect(await f.store.call<List<Note>>('timeline'), isEmpty);
      });
      await t.pumpWidget(const SizedBox());
      c.dispose();
      await t.runAsync(() async {
        await f.close();
        await root.delete(recursive: true);
      });
    },
  );

  for (final edge in ['right', 'left']) {
    testWidgets(
      '$edge mouse clicks in a translated flyout activate media controls',
      (t) async {
        t.view.physicalSize = const Size(480, 680);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        late Directory root;
        late NexFeatures f;
        final selection = Completer<List<XFile>>();
        await t.runAsync(() async {
          root = await Directory.systemTemp.createTemp('nex-mouse-picker-');
          f = NexFeatures(
            await DesktopStore.open(root.path, 'mouse-picker'),
            pickFiles: (groups) => selection.future,
          );
        });
        final c = PanelController(nativeHost: FakeNative());
        await c.bootstrap(
          preset: Settings()
            ..language = 'en'
            ..edge = edge,
          useNative: false,
        );
        c.onTray('capture');
        await t.pumpWidget(RightPanelApp(controller: c, features: f));
        c.anchorY = 660;
        await frames(t);
        expect(t.getCenter(find.text('Add image')).dy, greaterThan(c.flyH));
        await t.tap(find.text('Add image'), kind: PointerDeviceKind.mouse);
        await t.pump();
        expect(c.interacting, true);
        c.blur();
        expect(c.isOpen, true);
        if (edge == 'left') {
          selection.completeError(StateError('File chooser unavailable'));
        } else {
          selection.complete([]);
        }
        await frames(t);
        if (edge == 'left') {
          expect(
            find.textContaining('File chooser unavailable'),
            findsOneWidget,
          );
          expect(f.importedCount, 0);
        }
        expect(c.interacting, false);
        await t.tap(find.byType(Checkbox), kind: PointerDeviceKind.mouse);
        await t.pump();
        expect(f.checklist, true);
        await t.pumpWidget(const SizedBox());
        c.dispose();
        await t.runAsync(() async {
          await f.close();
          await root.delete(recursive: true);
        });
      },
    );
  }

  test(
    'photo/audio import is durable; cancellation and missing files report honestly; error does not block exit',
    () async {
      final root = await Directory.systemTemp.createTemp('nex-import-test-');
      final f = NexFeatures(await DesktopStore.open(root.path, 'import-test'));
      final png = File('${root.path}/photo.png');
      await png.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jC1kAAAAASUVORK5CYII=',
        ),
      );
      final audio = File('${root.path}/voice.wav');
      // File classification is independent of playback; runtime codec checks use
      // a valid WAV during the actual Windows smoke test.
      await audio.writeAsBytes([82, 73, 70, 70]);
      await f.importPaths([png.path, audio.path]);
      expect(f.importedCount, 2);
      expect(f.error, isNull);
      final notes = await f.store.call<List<Note>>('timeline');
      expect(notes.map((n) => n.type).toSet(), {
        NoteType.photo,
        NoteType.voice,
      });
      await png.delete();
      await audio.delete();
      for (final n in notes) {
        expect(File(n.mediaUri!).existsSync(), true);
      }
      await f.importPaths([]);
      expect((await f.store.call<List<Note>>('timeline')).length, 2);
      await f.importPaths(['${root.path}/missing.png']);
      expect(f.error, isNotNull);
      expect(f.importedCount, 0);
      expect(f.importing, false);
      await f.close();
      final reopened = await DesktopStore.open(root.path, 'reopened');
      expect((await reopened.call<List<Note>>('timeline')).length, 2);
      await reopened.close();
      await root.delete(recursive: true);
    },
  );

  for (final locale in ['en', 'fa']) {
    testWidgets(
      '$locale capture and inline reader have no scrim, duplicated editor or accidental hover switch',
      (t) async {
        t.view.physicalSize = const Size(480, 680);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        late Directory root;
        late NexFeatures f;
        await t.runAsync(() async {
          root = await Directory.systemTemp.createTemp('nex-reader-test-');
          f = NexFeatures(await DesktopStore.open(root.path, 'reader-test'));
          await f.session.write(
            locale == 'fa'
                ? 'یادداشت آزمایشی برای مطالعه'
                : 'A note to read comfortably',
          );
        });
        final c = PanelController(nativeHost: FakeNative());
        await c.bootstrap(
          preset: Settings()
            ..language = locale
            ..theme = locale == 'en' ? 'light' : 'dark',
          useNative: false,
        );
        c.open();
        c.openWidget('note');
        await t.pumpWidget(RightPanelApp(controller: c, features: f));
        // Compare settled surfaces, rather than residual subpixel spring motion.
        await frames(t, 180);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/capture_$locale.png'),
        );
        c.openWidget('timeline');
        await frames(t);
        for (var i = 0; i < 4; i++) {
          await t.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 75));
          });
          await t.pump();
        }
        await frames(t);
        await t.tap(find.byType(NoteCard).first);
        await frames(t);
        expect(find.byType(NexNoteDetail), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) => w is ModalBarrier && (w.color?.a ?? 0) > 0,
          ),
          findsNothing,
        );
        expect(find.byType(TextField), findsNothing);
        expect(c.interacting, true);
        c.sticky = false;
        c.blur();
        expect(c.isOpen, true);
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          t.getCenter(
            find.byWidgetPredicate(
              (w) => w is ToolVisual && w.id == 'settings',
            ),
          ),
        );
        await frames(t);
        expect(c.panel, 'timeline');
        await mouse.removePointer();
        await frames(t, 180);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/reader_$locale.png'),
        );
        await t.tap(
          find.byTooltip(locale == 'en' ? 'Edit note' : 'ویرایش یادداشت'),
        );
        await t.pump();
        expect(find.byType(TextField), findsOneWidget);
        await t.runAsync(() async {
          await t.enterText(find.byType(TextField), 'Edited immediately');
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(
            (await f.store.call<List<Note>>('timeline')).single.content,
            'Edited immediately',
          );
        });
        await t.pumpWidget(const SizedBox());
        expect(c.interacting, false);
        c.dispose();
        await t.runAsync(() async {
          await f.close();
          await root.delete(recursive: true);
        });
        expect(t.takeException(), isNull);
      },
    );
  }
}
