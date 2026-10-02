import 'dart:io';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:right_panel/core/controller.dart';
import 'package:right_panel/core/native.dart';
import 'package:right_panel/core/spring.dart';
import 'package:right_panel/main.dart';
import 'package:right_panel/nex/features.dart';
import 'package:right_panel/nex/store.dart';
import 'package:right_panel/ui/dock.dart';

class _FakeNative extends NativeHost {
  bool passthrough = true;
  @override
  Future<void> setPassthrough(bool on) async {
    passthrough = on;
  }

  @override
  Future<void> rememberForeground() async {}
  @override
  Future<void> pasteIntoPrevious(String text) async {}
  @override
  Future<void> pressKey(String name) async {}
  @override
  Future<String> pinWindow() async => 'No window to pin';
  @override
  Future<void> lock() async {}
  @override
  Future<void> screenOff() async {}
  @override
  Future<void> beep() async {}
  @override
  Future<void> keepAwake(bool on) async {}
  @override
  Future<void> screenshot() async {}
  @override
  Future<void> launch(String target) async {}
  @override
  Future<void> pickColor() async {}
  @override
  Future<void> pickCustomColor(String currentHex) async {}
  @override
  Future<void> pickApp({bool folder = false}) async {}
  @override
  Future<void> appIcon(String id, String path) async {}
  @override
  Future<bool> startupEnabled() async => false;
  @override
  Future<void> setStartup(bool on) async {}
  @override
  Future<void> quit() async {}
  @override
  Future<void> setClipboardImage(int w, int h, Uint8List rgba) async {}
  @override
  Future<Map<String, dynamic>?> applyPlacement(
    String edge,
    int monitor,
  ) async => {
    'x': 1400,
    'y': 220,
    'w': 480,
    'h': 680,
    'edgeX': 1880,
    'scale': 1.0,
    'onLeft': false,
  };
  @override
  Future<List<Map<String, dynamic>>> screens() async => [
    {'name': 'Primary', 'w': 1880, 'h': 1080},
  ];
  @override
  Future<void> ready() async {}
  @override
  bool get ffiAvailable => false;
  @override
  (int, int)? cursorPos() => null;
  @override
  bool leftDown() => false;
}

/// Pumps at 60fps for [seconds] so the springs integrate like real frames.
Future<void> pumpSeconds(WidgetTester tester, double seconds) async {
  final frames = (seconds * 60).round();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  test(
    'modal app picker cancels pending close and suppresses blur/auto-close',
    () async {
      final native = _FakeNative();
      final controller = PanelController(nativeHost: native);
      await controller.bootstrap(preset: Settings(), useNative: false);
      controller.open();
      controller.sticky = false;
      expect(controller.maybeClose(), true);
      controller.setPickerActive(true);
      controller.blur();
      expect(controller.maybeClose(), false);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(controller.isOpen, true);
      expect(native.passthrough, false);
      controller.setPickerActive(false);
      expect(controller.S.apps, isEmpty);
      expect(controller.toastMsg.value, isNull);
      expect(controller.sticky, true);
      controller.dispose();
    },
  );
  testWidgets(
    'hover switch followed by first click keeps the selected panel open',
    (tester) async {
      final controller = PanelController(nativeHost: _FakeNative());
      await controller.bootstrap(preset: Settings(), useNative: false);
      controller.open();
      controller.openWidget('note');
      await tester.pumpWidget(RightPanelApp(controller: controller));
      await pumpSeconds(tester, 1);
      final settings = find.byWidgetPredicate(
        (w) => w is ToolVisual && w.id == 'settings',
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(settings));
      await tester.pump();
      expect(controller.panel, 'settings');
      await tester.tap(settings);
      await pumpSeconds(tester, .2);
      expect(controller.panel, 'settings');
      await tester.tap(settings);
      await tester.pump();
      expect(controller.panel, isNull);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
  testWidgets(
    'real capture startup focuses only after layout and accepts typing',
    (tester) async {
      late Directory root;
      late NexFeatures features;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('nex-shell-capture-');
        features = NexFeatures(
          await DesktopStore.open(root.path, 'startup-test'),
        );
      });
      final controller = PanelController(nativeHost: _FakeNative());
      await controller.bootstrap(preset: Settings(), useNative: false);
      controller.onCapture = () {
        features.fresh();
      };
      controller.onTray('capture');
      await tester.pumpWidget(
        RightPanelApp(controller: controller, features: features),
      );
      await pumpSeconds(tester, 1);
      expect(tester.takeException(), isNull);
      expect(features.focus.hasFocus, true);
      await tester.runAsync(() async {
        await tester.enterText(
          find.byKey(const ValueKey('capture-field')),
          'startup تایپ',
        );
        await features.session.flushed;
        expect(
          (await features.store.call<List<dynamic>>('timeline')).single.content,
          'startup تایپ',
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.runAsync(() async {
        await features.close();
        await root.delete(recursive: true);
      });
    },
  );
  testWidgets('manual startup before first layout keeps animation running', (
    tester,
  ) async {
    final controller = PanelController(nativeHost: _FakeNative());
    await controller.bootstrap(preset: Settings(), useNative: false);
    controller.onTray('capture');
    await tester.pumpWidget(RightPanelApp(controller: controller));
    await pumpSeconds(tester, 1);
    expect(tester.takeException(), isNull);
    expect(controller.frame.value, greaterThan(30));
    expect(controller.slide.v, greaterThan(.99));
    expect(controller.grow.v, greaterThan(.99));
    expect(controller.flyH, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
  test(
    'tray opening makes the real window interactive; closing restores passthrough',
    () async {
      final native = _FakeNative();
      final controller = PanelController(nativeHost: native);
      await controller.bootstrap(preset: Settings(), useNative: false);
      controller.onTray('open');
      expect(native.passthrough, false);
      expect(controller.isOpen, true);
      controller.close();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(native.passthrough, true);
      controller.dispose();
    },
  );
  test('cancelled app selection adds nothing and shows no success', () async {
    final controller = PanelController(nativeHost: _FakeNative());
    await controller.bootstrap(preset: Settings(), useNative: false);
    final before = controller.S.dock!.toList();
    controller.appAdded(path: '');
    controller.appAdded(path: '  ');
    expect(controller.S.apps, isEmpty);
    expect(controller.S.dock, before);
    expect(controller.toastMsg.value, isNull);
    controller.dispose();
  });
  test(
    'installer language applies once and later in-app choice survives restart',
    () async {
      final settings = Settings();
      final first = PanelController(nativeHost: _FakeNative());
      await first.bootstrap(
        preset: settings,
        useNative: false,
        installerLanguageMarker: 'en|install-2',
      );
      expect(first.S.language, 'en');
      first.S.language = 'fa';
      final saved = Settings.fromMap(first.S.toMap());
      first.dispose();
      final restarted = PanelController(nativeHost: _FakeNative());
      await restarted.bootstrap(
        preset: saved,
        useNative: false,
        installerLanguageMarker: 'en|install-2',
      );
      expect(restarted.S.language, 'fa');
      restarted.dispose();
    },
  );
  testWidgets(
    'global capture selects immediately; delayed work stops on disposal',
    (tester) async {
      final controller = PanelController(nativeHost: _FakeNative());
      await controller.bootstrap(preset: Settings(), useNative: false);
      var captured = false;
      controller.onCapture = () => captured = true;
      controller.onTray('capture');
      expect(controller.panel, 'note');
      expect(controller.isOpen, true);
      expect(captured, true);
      controller.show('settings');
      controller.dispose();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Spring settles without overshoot when critically damped (tab slide)',
    () {
      final s = Spring(0, 320, 38);
      var dt = 1 / 60.0;
      s.t = 1;
      var max = 0.0;
      for (var i = 0; i < 240; i++) {
        final v = s.step(dt);
        if (v > max) max = v;
      }
      expect(
        max,
        lessThan(1.0),
        reason: 'slide must not overshoot past the edge',
      );
      expect(s.v, closeTo(1.0, 0.001));
    },
  );

  test('Spring bounces when underdamped (flyout pour)', () {
    final s = Spring(0, 340, 24);
    s.t = 1;
    var max = 0.0;
    for (var i = 0; i < 240; i++) {
      final v = s.step(1 / 60.0);
      if (v > max) max = v;
    }
    expect(max, greaterThan(1.0), reason: 'the pour should overshoot a little');
  });

  test('Settings round-trips through the original JSON shape', () {
    final s = Settings()
      ..theme = 'ocean'
      ..edge = 'left'
      ..monitor = 1
      ..recentEmoji = ['😀', '🔥']
      ..snippets = ['hello'];
    final m = s.toMap();
    expect(m['theme'], 'ocean');
    expect(m['edge'], 'left');
    expect(m['recentEmoji'], ['😀', '🔥']);
    expect(m['snippets'], ['hello']);
    final back = Settings.fromMap(Map<String, dynamic>.from(m));
    expect(back.theme, 'ocean');
    expect(back.recentEmoji, s.recentEmoji);
  });

  testWidgets('app boots, opens, and the dock renders its tools', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(960, 1360);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final controller = PanelController(nativeHost: _FakeNative());
    await controller.bootstrap(
      preset: Settings()..language = 'en',
      useNative: false,
    );

    await tester.pumpWidget(RightPanelApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Scaffold), findsOneWidget);

    controller.open();
    // the default dock opens its tools with the staggered entrance
    await pumpSeconds(tester, 1.2);
    expect(controller.slide.v, closeTo(1.0, 0.01));

    // opening a tool pours out the flyout
    controller.setPanel('emoji');
    await pumpSeconds(tester, 1.2);
    expect(controller.grow.v, closeTo(1.0, 0.02));
    expect(find.text('Search emoji…'), findsOneWidget);

    // emoji search filters (watermelon is not a category icon, so exactly 1)
    await tester.enterText(find.byType(TextField).first, 'watermelon');
    await tester.pump();
    expect(find.text('🍉'), findsOneWidget);

    controller.setPanel('clip');
    await pumpSeconds(tester, 1.2);
    expect(find.text('CLIPBOARD'), findsWidgets);

    controller.close();
    await pumpSeconds(tester, 1.2);
    expect(controller.isOpen, false);
    expect(controller.slide.v, closeTo(0.0, 0.05));
  });
}
