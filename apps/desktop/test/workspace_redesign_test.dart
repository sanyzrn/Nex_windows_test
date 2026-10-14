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

  testWidgets('sidebar collapses while writing stays available', (t) async {
    await _boot(t, width: 700);
    // 64px icons-only rail: the compact width Windows nav panes use, down
    // from 76, leaving the section beside it more of a small window.
    expect(
      t.getSize(find.byKey(const ValueKey('workspace-sidebar'))).width,
      64,
    );
    expect(find.byKey(const ValueKey('capture-field')), findsOneWidget);
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

  testWidgets('settings categories reveal the existing controls in place', (
    t,
  ) async {
    await _boot(t, section: 'settings');
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    expect(find.text(l.interfaceMode), findsOneWidget);
    expect(find.text(l.colorMode), findsNothing);
    await t.tap(find.text(l.settingsAppearance));
    await t.pumpAndSettle();
    expect(find.text(l.colorMode), findsOneWidget);
    expect(find.text(l.interfaceMode), findsNothing);
    await t.tap(find.text(l.settingsBackup));
    await t.pumpAndSettle();
    expect(find.text(l.colorMode), findsNothing);
    expect(t.takeException(), isNull);
  });

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
