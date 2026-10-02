import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:right_panel/core/controller.dart';
import 'package:right_panel/core/native.dart';
import 'package:right_panel/main.dart';
import 'package:right_panel/ui/shell.dart';

class _FakeNative extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<void> _boot(WidgetTester tester, {String theme = 'midnight'}) async {
  tester.view.physicalSize = const Size(960, 1360);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final controller = PanelController(nativeHost: _FakeNative());
  final settings = Settings()
    ..theme = theme
    ..language = 'en';
  await controller.bootstrap(preset: settings, useNative: false);
  await tester.pumpWidget(RightPanelApp(controller: controller));
  await tester.pump(const Duration(milliseconds: 50));
  controller.open();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _pumpSecs(WidgetTester tester, double seconds) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

// Comparisons run in the normal suite. Deliberately refresh reviewed baselines
// with flutter test --update-goldens; test/flutter_test_config.dart loads fonts.

void main() {
  testWidgets('golden: dock open with pill', (tester) async {
    await _boot(tester);
    await _pumpSecs(tester, 1.0);
    controllerOf(tester).setPanel('emoji');
    await _pumpSecs(tester, 1.0);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/emoji_panel.png'),
    );
  });

  testWidgets('golden: more tools grid', (tester) async {
    await _boot(tester);
    await _pumpSecs(tester, 1.0);
    controllerOf(tester).setPanel('more');
    await _pumpSecs(tester, 1.0);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/more_panel.png'),
    );
  });

  testWidgets('golden: light theme + settings', (tester) async {
    await _boot(tester, theme: 'sky');
    await _pumpSecs(tester, 1.0);
    controllerOf(tester).setPanel('settings');
    await _pumpSecs(tester, 1.0);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/settings_light.png'),
    );
  });
}

PanelController controllerOf(WidgetTester tester) {
  final shell = tester.widget<PanelShell>(find.byType(PanelShell));
  return shell.controller;
}
