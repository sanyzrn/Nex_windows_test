import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/models.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/capture_view.dart';
import 'package:nex_desktop/nex/command_palette.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/library_view.dart';
import 'package:nex_desktop/nex/note_detail_view.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Native extends NativeHost {
  ClipImage? image;
  Future<void> Function(bool)? awakeRequest;
  final awakeCalls = <bool>[];
  @override
  Future<void> keepAwake(bool on) async {
    awakeCalls.add(on);
    await awakeRequest?.call(on);
  }

  @override
  Future<ClipImage?> currentClipboardImage() async => image;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class _Fixture {
  _Fixture(this.root, this.features, this.controller, this.native);
  final Directory root;
  final NexFeatures features;
  final PanelController controller;
  final _Native native;
}

Future<_Fixture> _boot(WidgetTester t) async {
  late Directory root;
  late NexFeatures features;
  await t.runAsync(() async {
    root = await Directory.systemTemp.createTemp('nex-usability-');
    features = NexFeatures(await DesktopStore.open(root.path, 'regression'));
  });
  final native = _Native();
  final controller = PanelController(nativeHost: native);
  await controller.bootstrap(
    preset: Settings()..language = 'en',
    useNative: false,
  );
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    controller.dispose();
    await t.runAsync(() async {
      await features.close();
      await root.delete(recursive: true);
    });
  });
  return _Fixture(root, features, controller, native);
}

Future<void> _mount(WidgetTester t, _Fixture f, Widget body) async {
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: f.controller.appTheme,
      home: NexPanelScope(
        controller: f.controller,
        child: NexScope(
          features: f.features,
          child: Scaffold(body: body),
        ),
      ),
    ),
  );
  await t.pump();
  await _settleDatabase(t);
  await t.pumpAndSettle();
}

Future<void> _settleDatabase(WidgetTester t) async {
  // The widget starts each next isolate request after its preceding reply
  // reaches the fake UI zone. Give both zones time for the three round trips.
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump();
  }
}

Future<void> _paste(WidgetTester t) async {
  await t.runAsync(() async {
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyV);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });
  await t.pump();
}

void main() {
  String clipboard = '';
  Completer<Map<String, dynamic>>? clipboardRead;
  setUp(() {
    clipboard = '';
    clipboardRead = null;
    SharedPreferences.setMockInitialValues({});
    const platform = MethodChannel('flutter/platform', JSONMethodCodec());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return clipboardRead?.future ?? {'text': clipboard};
          }
          return null;
        });
  });

  for (final compact in [true, false]) {
    final layout = compact ? 'panel' : 'window';
    testWidgets(
      '$layout Ctrl+V replaces a reversed selection in the same note',
      (t) async {
        final f = await _boot(t);
        await _mount(t, f, NexCaptureView(compact: compact));
        await t.runAsync(() async {
          await t.enterText(
            find.byKey(const ValueKey('capture-field')),
            'hello world',
          );
          await f.features.session.flushed;
        });
        final id = f.features.session.id;
        f.features.composer.selection = const TextSelection(
          baseOffset: 11,
          extentOffset: 6,
        );
        clipboard = 'فارسی';
        await _paste(t);
        expect(f.features.composer.text, 'hello فارسی');
        expect(f.features.composer.selection.baseOffset, 11);
        expect(f.features.session.id, id);
        await t.runAsync(() async {
          final rows = await f.features.store.call<List<Note>>('timeline');
          expect(rows.single.content, 'hello فارسی');
        });
        clipboard = 'https://example.com';
        f.features.composer.selection = const TextSelection.collapsed(
          offset: 6,
        );
        await _paste(t);
        expect(f.features.composer.text, 'hello https://example.comفارسی');
        expect(f.features.session.id, id);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      '$layout Ctrl+V imports an image while preserving the composer',
      (t) async {
        final f = await _boot(t);
        f.native.image = ClipImage(
          id: 'pixel',
          w: 1,
          h: 1,
          rgba: Uint8List.fromList([255, 0, 0, 255]),
        );
        await _mount(t, f, NexCaptureView(compact: compact));
        await t.tap(find.byKey(const ValueKey('capture-field')));
        await _paste(t);
        expect(f.features.composer.text, isEmpty);
        await t.runAsync(() async {
          final rows = await f.features.store.call<List<Note>>('timeline');
          expect(rows.single.type, NoteType.photo);
          expect(File(rows.single.mediaUri!).existsSync(), isTrue);
        });
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a delayed clipboard read cannot write into a newly started note',
    (t) async {
      final f = await _boot(t);
      await _mount(t, f, const NexCaptureView(compact: false));
      clipboardRead = Completer<Map<String, dynamic>>();
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyV);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.runAsync(() => f.features.fresh());
      clipboardRead!.complete({'text': 'obsolete paste'});
      await _settleDatabase(t);
      expect(f.features.composer.text, isEmpty);
      await t.runAsync(() async {
        expect(await f.features.store.call<List<Note>>('timeline'), isEmpty);
      });
    },
  );

  testWidgets(
    'palette search opens the selected note and clear rejects an old response',
    (t) async {
      t.view.physicalSize = const Size(1200, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final f = await _boot(t);
      late Note target;
      await t.runAsync(() async {
        target = await f.features.store.call<Note>('capture', {
          'text': 'unique needle',
        });
        await f.features.store.call<Note>('capture', {'text': 'another note'});
      });
      await t.pumpWidget(
        RightPanelApp(controller: f.controller, features: f.features),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('workspace-command')));
      await t.pumpAndSettle();
      final search = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await t.enterText(search, 'unique');
      await t.pump(const Duration(milliseconds: 151));
      await t.enterText(search, '');
      await _settleDatabase(t);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('unique needle')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await t.enterText(search, 'unique');
      await t.pump(const Duration(milliseconds: 151));
      await _settleDatabase(t);
      t.widget<TextField>(search).controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 6);
      await t.pump();
      final hit = find.descendant(of: find.byType(AlertDialog), matching: find.text('unique needle'));
      expect(hit, findsOneWidget);
      await t.tap(hit);
      await t.pump();
      await _settleDatabase(t);
      await t.pumpAndSettle();
      expect(f.controller.windowSection.value, 'library');
      expect(
        t.widget<NexNoteDetail>(find.byType(NexNoteDetail)).note.id,
        target.id,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('layout switch is hidden in panel and shown in wide window', (t) async {
    final f = await _boot(t);
    f.controller.S.windowMode = 'panel';
    await _mount(t, f, const NexLibraryView());
    expect(find.byIcon(Icons.grid_view_outlined), findsNothing);
    expect(find.byIcon(Icons.view_agenda_outlined), findsNothing);
    f.controller.S.windowMode = 'window';
    t.view.physicalSize = const Size(850, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pump();
    expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
    await t.tap(find.byIcon(Icons.view_agenda_outlined));
    await t.pump();
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'library searches the last query in a rapid burst and clear reloads',
    (t) async {
      final f = await _boot(t);
      await t.runAsync(() async {
        await f.features.store.call<Note>('capture', {'text': 'alpha sample'});
        await f.features.store.call<Note>('capture', {'text': 'beta sample'});
      });
      await _mount(t, f, const NexLibraryView());
      await _settleDatabase(t);
      final search = find.byKey(const ValueKey('library-search'));
      await t.enterText(search, 'alpha');
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(search, 'beta');
      await t.pump(const Duration(milliseconds: 151));
      await _settleDatabase(t);
      expect(find.text('beta sample'), findsOneWidget);
      expect(find.text('alpha sample'), findsNothing);
      await t.enterText(search, '');
      await t.pump(const Duration(milliseconds: 151));
      await _settleDatabase(t);
      expect(find.text('alpha sample'), findsOneWidget);
      expect(find.text('beta sample'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Ctrl+N drains the existing note before creating a new capture', (
    t,
  ) async {
    final f = await _boot(t);
    await t.pumpWidget(
      RightPanelApp(controller: f.controller, features: f.features),
    );
    await t.pumpAndSettle();
    await t.runAsync(() async {
      await t.enterText(
        find.byKey(const ValueKey('capture-field')),
        'first capture',
      );
      await f.features.session.flushed;
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyN);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pumpAndSettle();
    expect(f.features.composer.text, isEmpty);
    await t.runAsync(() async {
      await t.enterText(
        find.byKey(const ValueKey('capture-field')),
        'second capture',
      );
      await f.features.session.flushed;
      final rows = await f.features.store.call<List<Note>>('timeline');
      expect(
        rows.map((n) => n.content),
        containsAll(['first capture', 'second capture']),
      );
      expect(rows.length, 2);
    });
  });

  testWidgets(
    'theme cache responds to visual settings and survives unrelated settings',
    (t) async {
      final f = await _boot(t);
      final c = f.controller;
      final original = c.appTheme;
      final palette = c.palette;
      c.S.edge = 'left';
      c.S.cardDensity = 'compact';
      c.refresh();
      expect(identical(c.appTheme, original), isTrue);
      expect(identical(c.palette, palette), isTrue);
      c.S.theme = 'light';
      expect(c.appTheme.brightness, Brightness.light);
      expect(identical(c.appTheme, original), isFalse);
      final lightPalette = c.palette;
      c.S.preset = 'ocean';
      expect(identical(c.palette, lightPalette), isFalse);
      c.S.language = 'fa';
      expect(c.appTheme.textTheme.bodyLarge!.fontFamily, contains('Vazirmatn'));
    },
  );

  testWidgets(
    'keep awake waits for Windows and rejects repeated pending clicks',
    (t) async {
      final f = await _boot(t);
      final ack = Completer<void>();
      f.native.awakeRequest = (_) => ack.future;
      final pending = f.controller.toggleAwake();
      expect(f.controller.awakeBusy, isTrue);
      expect(f.controller.awake, isFalse);
      await f.controller.toggleAwake();
      expect(f.native.awakeCalls, [true]);
      ack.complete();
      await pending;
      expect(f.controller.awake, isTrue);
      expect(f.controller.awakeBusy, isFalse);
      f.native.awakeRequest = null;
      await f.controller.toggleAwake();
      expect(f.native.awakeCalls, [true, false]);
      expect(f.controller.awake, isFalse);
      await t.pump(const Duration(milliseconds: 1601));
    },
  );

  testWidgets(
    'a failed keep awake request preserves state and shows a Persian error',
    (t) async {
      final f = await _boot(t);
      f.controller.S.language = 'fa';
      f.native.awakeRequest = (_) async =>
          throw PlatformException(code: 'keep_awake_failed');
      await f.controller.toggleAwake();
      expect(f.controller.awake, isFalse);
      expect(f.controller.awakeBusy, isFalse);
      expect(
        f.controller.toastMsg.value,
        startsWith('تغییر وضعیت بیدار نگه‌داشتن انجام نشد'),
      );
      f.native.awakeRequest = null;
      await f.controller.toggleAwake();
      expect(f.controller.awake, isTrue);
      await t.pump(const Duration(milliseconds: 1601));
      f.native.awakeRequest = (_) async =>
          throw PlatformException(code: 'keep_awake_failed');
      await f.controller.toggleAwake();
      expect(f.controller.awake, isTrue);
      await t.pump(const Duration(milliseconds: 1601));
    },
  );

  for (final window in [true, false]) {
    testWidgets(
      'palette capture and tools routes respect ${window ? 'window' : 'panel'} mode',
      (t) async {
        final f = await _boot(t);
        f.controller.S.windowMode = window ? 'window' : 'panel';
        await _mount(t, f, const SizedBox(key: ValueKey('surface')));
        final surface = t.element(find.byKey(const ValueKey('surface')));
        final l = AppLocalizations.of(surface)!;
        for (final (label, section, panel) in [
          (l.capture, 'capture', 'note'),
          (l.tools, 'tools', 'more'),
        ]) {
          unawaited(showCommandPalette(surface, controller: f.controller));
          await t.pumpAndSettle();
          await t.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(label),
            ),
          );
          await t.pumpAndSettle();
          await t.pump(const Duration(milliseconds: 150));
          if (window) {
            expect(f.controller.windowSection.value, section);
          } else {
            expect(f.controller.panel, panel);
          }
        }
      },
    );
  }
}
