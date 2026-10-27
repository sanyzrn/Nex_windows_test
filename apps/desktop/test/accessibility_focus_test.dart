import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/l10n/intelligence_strings.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/note_detail_parts.dart';
import 'package:nex_desktop/nex/settings.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_desktop/ui/desktop_accessibility.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<PanelController> boot(
  WidgetTester tester,
  String language, {
  double width = 1200,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final root = Directory.systemTemp.createTempSync('nex-a2-');
  late NexFeatures features;
  await tester.runAsync(() async {
    features = NexFeatures(
      await DesktopStore.open(root.path, 'accessibility-test'),
    );
  });
  final c = PanelController(nativeHost: _Native());
  await c.bootstrap(
    preset: Settings()
      ..language = language
      ..windowMode = 'window',
    useNative: false,
  );
  await tester.pumpWidget(RightPanelApp(controller: c, features: features));
  await settle(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.runAsync(() async {
      await features.close();
      await root.delete(recursive: true);
    });
  });
  return c;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 40)),
  );
  await tester.pump();
}

FocusNode nodeFor(WidgetTester tester, Finder target) {
  for (final element
      in find
          .descendant(
            of: target,
            matching: find.byWidgetPredicate((w) => w is Focus),
          )
          .evaluate()) {
    // Focus's State is private, but its public focusNode also covers internally
    // allocated Material/InkWell nodes; no production focus nodes are replaced.
    final node =
        (tester.state(find.byWidget(element.widget)) as dynamic).focusNode
            as FocusNode;
    if (node.canRequestFocus && !node.skipTraversal) return node;
  }
  throw StateError('No keyboard target under $target');
}

Future<void> walk(WidgetTester tester, List<Finder> targets) async {
  final first = nodeFor(tester, targets.first);
  first.requestFocus();
  await tester.pump();
  expect(FocusManager.instance.primaryFocus, first);
  for (final target in targets.skip(1)) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus,
      nodeFor(tester, target),
      reason: 'Tab must reach $target',
    );
  }
  for (final target in targets.reversed.skip(1)) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus,
      nodeFor(tester, target),
      reason: 'Shift+Tab must reach $target',
    );
  }
}

Widget localized(String language, Widget child) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'keyboard focus owns a nonmodal panel hold and releases it on pointer mode or disposal',
    (tester) async {
      final previous = FocusManager.instance.highlightStrategy;
      final c = PanelController(nativeHost: _Native());
      await c.bootstrap(
        preset: Settings()..windowMode = 'panel',
        useNative: false,
      );
      try {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        await tester.pumpWidget(
          NexPanelScope(
            controller: c,
            child: localized(
              'en',
              DesktopAction(
                label: 'Action',
                onTap: () {},
                child: const Icon(Icons.add),
              ),
            ),
          ),
        );
        nodeFor(tester, find.byType(DesktopAction)).requestFocus();
        await tester.pump();
        expect(c.interacting, isTrue);
        expect(c.modalOpen, isFalse);
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        await tester.pump();
        expect(c.interacting, isFalse);
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        await tester.pump();
        expect(c.interacting, isTrue);
        await tester.pumpWidget(const SizedBox());
        expect(c.interacting, isFalse);
      } finally {
        FocusManager.instance.highlightStrategy = previous;
        c.dispose();
      }
    },
  );
  testWidgets('focus indicators survive a theme change from the More menu', (
    tester,
  ) async {
    final c = await boot(tester, 'en', width: 460);
    await tester.tap(find.byKey(const ValueKey('rail-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.palette.isLight ? 'Dark' : 'Light'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'custom action keeps focus, outlines it, and activates once per key or click',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final old = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = old);
        var count = 0;
        await tester.pumpWidget(
          localized(
            'en',
            Center(
              child: DesktopAction(
                label: 'Test action',
                excludeSemantics: true,
                onTap: () => count++,
                child: const SizedBox(
                  width: 80,
                  height: 40,
                  child: Icon(Icons.add),
                ),
              ),
            ),
          ),
        );
        final action = find.byType(DesktopAction);
        final node = nodeFor(tester, action);
        node.requestFocus();
        await tester.pump();
        final box = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('desktop-focus-ring')),
        );
        expect((box.decoration as BoxDecoration).border, isNotNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.tap(action);
        expect(count, 3);
        expect(FocusManager.instance.primaryFocus, node);
        await tester.pump();
        expect(find.bySemanticsLabel('Test action'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Test action'))
              .getSemanticsData()
              .label,
          'Test action',
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('disabled custom actions are skipped and cannot activate', (
    tester,
  ) async {
    var count = 0;
    await tester.pumpWidget(
      localized(
        'en',
        Column(
          children: [
            DesktopAction(
              key: const ValueKey('first'),
              label: 'First',
              onTap: () => count++,
              child: const Icon(Icons.add),
            ),
            const DesktopAction(
              label: 'Unavailable',
              child: Icon(Icons.remove),
            ),
            TextButton(
              key: const ValueKey('last'),
              onPressed: () {},
              child: const Text('Last'),
            ),
          ],
        ),
      ),
    );
    await walk(tester, [
      find.byKey(const ValueKey('first')),
      find.byKey(const ValueKey('last')),
    ]);
    expect(count, 0);
  });

  for (final language in ['en', 'fa']) {
    testWidgets(
      '$language compact rail has one ordered keyboard target per destination',
      (tester) async {
        await boot(tester, language, width: 460);
        await walk(tester, [
          find.byKey(const ValueKey('workspace-new-note')),
          for (final id in [
            'capture',
            'library',
            'assistant',
            'tools',
            'settings',
            'more',
          ])
            find.byKey(ValueKey('rail-$id')),
        ]);
        // The More menu's presentation tile must not create a second Tab stop.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('rail-more')),
            matching: find.byType(ExcludeFocus),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language capture editor, toggle and six actions follow source order',
      (tester) async {
        await boot(tester, language, width: 460);
        final scope = find.byType(NexCaptureView);
        final l = AppLocalizations.of(tester.element(scope))!;
        Finder within(Finder f) => find.descendant(of: scope, matching: f);
        await walk(tester, [
          within(find.byKey(const ValueKey('capture-field'))),
          within(find.byType(Switch)),
          within(find.byTooltip(l.newNote)),
          for (final label in [
            l.pasteText,
            l.addImage,
            l.attach,
            l.addAudio,
            l.record,
            l.pastePhoto,
          ])
            within(find.byTooltip(label)),
        ]);
        expect(
          tester
              .getSemantics(within(find.byType(Switch)))
              .getSemanticsData()
              .label,
          contains(l.checklist),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language library header search, layouts and tags follow keyboard order',
      (tester) async {
        final c = await boot(tester, language);
        c.selectWindowSection('library');
        await settle(tester);
        final context = tester.element(
          find.byKey(const ValueKey('library-search')),
        );
        final s = AiStrings.of(context);
        await walk(tester, [
          find.byKey(const ValueKey('library-search')),
          find.byKey(const ValueKey('library-locations')),
          find.byTooltip(s.t('board')),
          find.byTooltip(s.t('list')),
          find.byKey(const ValueKey('manage-tags')),
        ]);
        for (final widget in tester.widgetList<IconButton>(
          find.byType(IconButton),
        )) {
          expect(widget.tooltip, isNotNull);
          expect(widget.tooltip!.trim(), isNotEmpty);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language reader dock has named actions in both Tab directions',
      (tester) async {
        final at = DateTime.utc(2026, 10, 20);
        final note = Note(
          id: 'a2-note',
          type: NoteType.text,
          content: 'Example',
          createdAt: at,
          updatedAt: at,
          deviceId: 'test',
          rev: 1,
          syncState: SyncState.pending,
        );
        await tester.pumpWidget(
          localized(
            language,
            Center(
              child: SizedBox(
                width: 440,
                child: NoteActionBar(
                  note: note,
                  onCopy: () {},
                  onPin: () {},
                  onRemind: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(NoteActionBar)),
        )!;
        await walk(tester, [
          for (final label in [l.copy, l.pin, l.remind, l.delete])
            find.byTooltip(label),
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language settings search and seven category links are keyboard reachable',
      (tester) async {
        final c = await boot(tester, language);
        c.selectWindowSection('settings');
        await settle(tester);
        final scope = find.byType(NexSettingsView);
        final field = find.descendant(
          of: scope,
          matching: find.byType(TextField),
        );
        await walk(tester, [
          field,
          for (final i in [0, 1, 2, 6, 3, 4, 5])
            find.byKey(ValueKey('settings-open-$i')),
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
