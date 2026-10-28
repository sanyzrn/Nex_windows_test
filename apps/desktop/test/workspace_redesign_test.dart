import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<PanelController> _boot(
  WidgetTester t, {
  String section = 'capture',
  String language = 'en',
  double width = 1200,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  late Directory root;
  late NexFeatures features;
  await t.runAsync(() async {
    root = await Directory.systemTemp.createTemp('nex-workspace-test-');
    features = NexFeatures(await DesktopStore.open(root.path, 'workspace'));
  });
  final c = PanelController(nativeHost: _Native());
  await c.bootstrap(
    preset: Settings()
      ..windowMode = 'window'
      ..language = language,
    useNative: false,
  );
  c.selectWindowSection(section);
  await t.pumpWidget(RightPanelApp(controller: c, features: features));
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
    await t.runAsync(() async {
      await features.close();
      await root.delete(recursive: true);
    });
  });
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('desktop destinations can be activated from the keyboard', (
    t,
  ) async {
    var selected = false;
    await t.pumpWidget(
      MaterialApp(
        theme: nexLightTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 228,
            child: NexWorkspaceDestination(
              icon: Icons.notes_outlined,
              label: 'Library',
              onPressed: () => selected = true,
            ),
          ),
        ),
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(selected, isTrue);
  });

  testWidgets('wide capture editor fills the same content column', (t) async {
    await _boot(t, width: 1600);
    final editor = t
        .getSize(find.byKey(const ValueKey('workspace-editor')))
        .width;
    expect(editor, greaterThan(1000));
    expect(t.takeException(), isNull);
  });

  testWidgets('scheduled notes are available in library locations', (t) async {
    final c = await _boot(t);
    c.selectWindowSection('library');
    for (var i = 0; i < 10; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.tap(find.byKey(const ValueKey('library-locations')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-scheduled')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('library-scheduled')));
    await t.pump(const Duration(milliseconds: 300));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('tools-scheduled')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('sidebar collapses while writing stays available', (t) async {
    await _boot(t, width: 700);
    // The compact rail is a slim 76px lane of icon-over-label tiles.
    expect(
      t.getSize(find.byKey(const ValueKey('workspace-sidebar'))).width,
      76,
    );
    expect(find.byKey(const ValueKey('capture-field')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('compact rail keeps every destination named and reachable', (
    t,
  ) async {
    final c = await _boot(t, width: 440);
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    // Labels sit under the icons — nothing is an unlabelled glyph.
    for (final label in [l.navCapture, l.library, l.navTools, l.settings]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byKey(const ValueKey('window-card')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('rail-library')));
    await t.pump();
    expect(c.windowSection.value, 'library');
    await t.tap(find.byKey(const ValueKey('rail-settings')));
    await t.pump();
    expect(c.windowSection.value, 'settings');
    expect(t.takeException(), isNull);
  });

  testWidgets('compact capture page puts the editor first, actions as tiles', (
    t,
  ) async {
    await _boot(t, width: 440);
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    // The hero line and counters give way to the editor.
    expect(find.text(l.workspaceNotebook), findsNothing);
    final field = find.byKey(const ValueKey('capture-field'));
    expect(t.getTopLeft(field).dy, lessThan(220));
    // All six capture actions stay reachable, three across.
    final paste = t.getTopLeft(find.text(l.pasteText));
    final image = t.getTopLeft(find.text(l.addImage));
    final attach = t.getTopLeft(find.text(l.attach));
    expect(image.dy, paste.dy);
    expect(attach.dy, paste.dy);
    expect(t.takeException(), isNull);
  });

  testWidgets('compact rail "More" holds the panel switch, theme, shortcuts', (
    t,
  ) async {
    final c = await _boot(t, width: 440);
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    await t.tap(find.byKey(const ValueKey('rail-more')));
    await t.pumpAndSettle();
    expect(find.text(l.switchToPanel), findsOneWidget);
    expect(find.text(l.keyboardShortcuts), findsOneWidget);
    final wasLight = c.palette.isLight;
    await t.tap(find.text(wasLight ? l.dark : l.light));
    await t.pumpAndSettle();
    expect(c.palette.isLight, !wasLight);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Persian tool search finds clipboard and preserves the tool action',
    (t) async {
      final c = await _boot(t, section: 'tools', language: 'fa');
      await t.enterText(
        find.byKey(const ValueKey('workspace-tools-search')),
        'کلیپ',
      );
      await t.pump();
      final clipboard = find.text('کلیپ‌بورد');
      expect(clipboard, findsOneWidget);
      await t.tap(clipboard);
      await t.pumpAndSettle();
      expect(c.windowTool.value, 'clip');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'settings directory opens existing controls and returns to categories',
    (t) async {
      await _boot(t, section: 'settings');
      final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
      await t.tap(find.byKey(const ValueKey('settings-open-0')));
      await t.pumpAndSettle();
      expect(find.text(l.interfaceMode), findsOneWidget);
      expect(find.text(l.colorMode), findsNothing);
      await t.tap(find.byKey(const ValueKey('settings-back')));
      await t.pumpAndSettle();
      await t.tap(find.text(l.settingsAppearance));
      await t.pumpAndSettle();
      expect(find.text(l.colorMode), findsOneWidget);
      expect(find.text(l.interfaceMode), findsNothing);
      await t.tap(find.byKey(const ValueKey('settings-back')));
      await t.pumpAndSettle();
      await t.tap(find.text(l.settingsBackup));
      await t.pumpAndSettle();
      expect(find.text(l.colorMode), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'a command query with no results remains usable and dismissible',
    (t) async {
      await _boot(t);
      await t.tap(find.byKey(const ValueKey('workspace-command')));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'zzzz-no-such-command',
      );
      await t.pump(const Duration(milliseconds: 200));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
      expect(t.takeException(), isNull);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
