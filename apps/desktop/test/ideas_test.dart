// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Tests for the implemented improvements in design/IDEAS.md:
// command palette (Ctrl+K), Persian folding, the Today strip, the designed
// empty library, density modes and paste-to-link intelligence.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/command_palette.dart';
import 'package:nex_desktop/nex/capture_view.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/library_view.dart';
import 'package:nex_desktop/nex/note_detail_view.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_desktop/ui/widgets.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNative extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<(Directory, DesktopStore, NexFeatures)> _bootStore(String tag) async {
  final root = await Directory.systemTemp.createTemp('nex-ideas-$tag-');
  final store = await DesktopStore.open(root.path, 'dev-1');
  return (root, store, NexFeatures(store));
}

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required NexFeatures features,
  required PanelController controller,
  Size size = const Size(1200, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: LiquidScope(
        controller: controller,
        palette: controller.palette,
        dir: 1,
        child: NexScope(
          features: features,
          child: const Scaffold(body: NexLibraryView()),
        ),
      ),
    ),
  );
  // The view loads from the store isolate on mount. Grant real time for the
  // round trips, then let the fake zone rebuild with whatever landed.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }
}

/// What the mocked platform clipboard returns for reads.
String _clipboardText = '';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Clipboard.getData/setData must not hit the test host's platform channel:
    // on this machine that call never returns, hanging the whole test process.
    // flutter/platform uses the JSON codec, so the mock channel must carry
    // the same codec — a StandardMethodCodec mock fails to decode.
    const platform = MethodChannel('flutter/platform', JSONMethodCodec());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': _clipboardText};
          }
          return null;
        });
  });

  test('nexFoldText unifies Persian/Arabic variants and digits', () {
    // Arabic yeh/kaf vs Persian forms, hamza carriers, ZWNJ, diacritics.
    expect(nexFoldText('تنظيمات'), nexFoldText('تنظیمات'));
    expect(nexFoldText('كتاب'), nexFoldText('کتاب'));
    expect(nexFoldText('مرأة'), 'مراه');
    expect(nexFoldText('زمی\u200Cن'), 'زمین');
    expect(nexFoldText('۱۲۳'), '123');
    expect(nexFoldText('٤٥'), '45');
    // Case folding for Latin queries.
    expect(nexFoldText('Library'), 'library');
  });

  testWidgets('Ctrl+K opens the palette and a screen jump runs', (
    tester,
  ) async {
    final c = PanelController(nativeHost: FakeNative());
    await c.bootstrap(
      preset: Settings()..windowMode = 'window',
      useNative: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: LiquidScope(
          controller: c,
          palette: c.palette,
          dir: 1,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('surface'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Open the palette the same way the shell does.
    final context = tester.element(find.text('surface'));
    unawaited(showCommandPalette(context, controller: c, features: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Search notes, screens and actions…'), findsOneWidget);
    // Screens are offered without a query.
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Filter: "sett" narrows to the settings screen entry.
    await tester.enterText(find.byType(TextField), 'sett');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Library'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);

    // Tap the entry: the palette closes and the action ran.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(c.windowSection.value, 'settings');
    c.dispose();
  });

  testWidgets('palette folding finds entries typed in Arabic script', (
    tester,
  ) async {
    final c = PanelController(nativeHost: FakeNative());
    await c.bootstrap(
      preset: Settings()..windowMode = 'window',
      useNative: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fa'),
        home: LiquidScope(
          controller: c,
          palette: c.palette,
          dir: 0,
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    unawaited(showCommandPalette(context, controller: c, features: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The fa title of the settings screen is "تنظیمات". Typing it with the
    // Arabic yeh/kaf still matches after folding.
    await tester.enterText(find.byType(TextField), 'تنظيمات');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('تنظیمات'), findsWidgets);
    c.dispose();
  });

  testWidgets('Today strip lists due and overdue reminders', (tester) async {
    late Directory root;
    late DesktopStore store;
    late NexFeatures features;
    await tester.runAsync(() async {
      (root, store, features) = await _bootStore('today');
      features.write('Feed the cat');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final notes = await store.call<List<Note>>('timeline', {'offset': 0});
      final id = notes.first.id;
      final now = DateTime.now();
      await store.call('remind', {
        'id': id,
        'at': now.subtract(const Duration(days: 1)),
        'repeat': 'once',
      });
    });

    final c = PanelController(nativeHost: FakeNative());
    await tester.runAsync(() async {
      await c.bootstrap(
        preset: Settings()..windowMode = 'window',
        useNative: false,
      );
    });
    await _pumpLibrary(tester, features: features, controller: c);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('1 overdue'), findsOneWidget);
    // The chip carries the due time and the note text.
    expect(find.textContaining('Feed the cat'), findsWidgets);

    // Tapping the chip opens the note in the reader pane (two-pane width).
    await tester.tap(find.byType(ActionChip).first);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(NexNoteDetail), findsOneWidget);
    c.dispose();
    await tester.runAsync(() async {
      await store.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
  });

  testWidgets('designed empty library shows three concrete actions', (
    tester,
  ) async {
    late Directory root;
    late DesktopStore store;
    late NexFeatures features;
    await tester.runAsync(() async {
      (root, store, features) = await _bootStore('empty');
    });

    final c = PanelController(nativeHost: FakeNative());
    await tester.runAsync(() async {
      await c.bootstrap(
        preset: Settings()..windowMode = 'window',
        useNative: false,
      );
    });
    await _pumpLibrary(tester, features: features, controller: c);

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Write the first note'), findsOneWidget);
    expect(find.text('Browse the tools'), findsOneWidget);
    expect(find.text('Learn the shortcuts'), findsOneWidget);

    // "Write the first note" routes to the capture surface.
    await tester.tap(find.text('Write the first note'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.windowSection.value, 'capture');
    c.dispose();
    await tester.runAsync(() async {
      await store.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
  });

  testWidgets('density modes change the timeline card height', (tester) async {
    Future<double> cardHeight(String density) async {
      late Directory root;
      late DesktopStore store;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp(
          'nex-ideas-density-$density-',
        );
        store = await DesktopStore.open(root.path, 'dev-1');
      });
      final features = NexFeatures(store);
      await tester.runAsync(() async {
        features.write('A note long enough to preview across two lines. ' * 3);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      final c = PanelController(nativeHost: FakeNative());
      await tester.runAsync(() async {
        await c.bootstrap(
          preset: Settings()
            ..windowMode = 'window'
            ..cardDensity = density,
          useNative: false,
        );
      });
      await _pumpLibrary(tester, features: features, controller: c);
      final size = tester.getSize(find.byType(NoteCard).first);
      c.dispose();
      await tester.runAsync(() async {
        await store.close();
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      await tester.pumpWidget(const SizedBox());
      return size.height;
    }

    final standard = await cardHeight('standard');
    final compact = await cardHeight('compact');
    final readable = await cardHeight('readable');
    expect(compact, lessThan(standard));
    expect(readable, greaterThan(standard));
  });

  testWidgets('pasting a bare URL creates a link note immediately', (
    tester,
  ) async {
    late Directory root;
    late DesktopStore store;
    late NexFeatures features;
    await tester.runAsync(() async {
      (root, store, features) = await _bootStore('paste-link');
    });

    final c = PanelController(nativeHost: FakeNative());
    await tester.runAsync(() async {
      await c.bootstrap(
        preset: Settings()..windowMode = 'window',
        useNative: false,
      );
    });

    // Put a bare URL on the clipboard and press the capture view's
    // "Paste text" action. (The platform clipboard is mocked in setUp.)
    _clipboardText = 'https://example.com/articles/nex-12';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: LiquidScope(
          controller: c,
          palette: c.palette,
          dir: 1,
          child: NexScope(
            features: features,
            child: const Scaffold(body: NexCaptureView()),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async {
      await tester.tap(find.text('Paste text'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await features.session.flushed;
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    // The URL became a link note and the composer stayed clean.
    final List<dynamic> notes0 =
        await tester.runAsync(
          () => store.call<List<dynamic>>('timeline', {'offset': 0}),
        ) ??
        <dynamic>[];
    final notes = <Note>[...notes0.cast<Note>()];
    expect(notes, isNotEmpty, reason: 'a note must exist after paste');
    expect(notes.first.type, NoteType.link);
    expect(notes.first.linkUrl, 'https://example.com/articles/nex-12');
    expect(features.composer.text, isEmpty);

    // Non-URL text still lands in the composer for editing.
    _clipboardText = 'plain thoughts';
    await tester.runAsync(() async {
      await features.fresh();
    });
    await tester.runAsync(() async {
      await tester.tap(find.text('Paste text'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await features.session.flushed;
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    expect(features.composer.text, 'plain thoughts');

    await tester.runAsync(() async {
      await features.close();
    });
    c.dispose();
    await tester.runAsync(() async {
      await store.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
  });
}
