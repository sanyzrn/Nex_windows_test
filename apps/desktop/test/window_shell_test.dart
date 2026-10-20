import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';

import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_desktop/ui/dock.dart';
import 'package:nex_desktop/ui/shell.dart';
import 'package:nex_desktop/ui/window_shell.dart';

class _RecordingNative extends NativeHost {
  final List<String> modes = [];
  Map<String, dynamic>? lastBounds;
  bool? lastShow;
  bool? lastMaximized;
  bool? lastCompact;

  @override
  Future<void> setWindowMode(
    String mode, {
    Map<String, dynamic>? bounds,
    bool maximized = false,
    bool show = true,
    bool compact = false,
  }) async {
    modes.add(mode);
    lastBounds = bounds;
    lastShow = show;
    lastMaximized = maximized;
    lastCompact = compact;
  }

  @override
  Future<Map<String, dynamic>?> windowFrame() async => {
    'x': 40,
    'y': 60,
    'w': 1180,
    'h': 780,
    'maximized': false,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<(PanelController, NexFeatures, _RecordingNative)> _bootWindow(
  WidgetTester tester, {
  String language = 'en',
}) async {
  tester.view.physicalSize = const Size(2360, 1560);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  late Directory root;
  late NexFeatures features;
  await tester.runAsync(() async {
    root = await Directory.systemTemp.createTemp('nex-window-shell-');
    features = NexFeatures(await DesktopStore.open(root.path, 'window-device'));
  });
  final native = _RecordingNative();
  final controller = PanelController(nativeHost: native);
  await controller.bootstrap(
    preset: Settings()
      ..language = language
      ..windowMode = 'window',
    useNative: false,
  );
  await tester.pumpWidget(
    RightPanelApp(controller: controller, features: features),
  );
  await tester.pump(const Duration(milliseconds: 50));
  addTearDown(() async {
    await tester.runAsync(() async {
      await features.close();
      await root.delete(recursive: true);
    });
  });
  return (controller, features, native);
}

/// AnimatedSwitcher teardown needs successive frames, not one big jump.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('window shell renders sections and navigates', (tester) async {
    final (controller, _, _) = await _bootWindow(tester);

    expect(find.byType(NexWindowShell), findsOneWidget);
    expect(find.byType(PanelShell), findsNothing);
    expect(find.byKey(const ValueKey('capture-field')), findsOneWidget);

    // The rail exposes all four sections.
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Library shows the timeline (empty but rendered).
    await tester.tap(find.text('Library'));
    await _settle(tester);
    expect(find.byType(NexLibraryView), findsOneWidget);

    // Tools directory shows tiles; a panel tool opens its card.
    await tester.tap(find.text('Tools'));
    await _settle(tester);
    expect(find.byType(NexLibraryView), findsNothing);
    final emojiTile = find.text('Emoji');
    expect(emojiTile, findsOneWidget);
    await tester.ensureVisible(emojiTile);
    await tester.pumpAndSettle();
    await tester.tap(emojiTile);
    await _settle(tester);
    // The embedded tool's own back control is now labelled too; target the
    // window header explicitly rather than assuming one tooltip globally.
    expect(find.byKey(const ValueKey('window-back-to-tools')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('window-back-to-tools')));
    await _settle(tester);
    expect(emojiTile, findsOneWidget);

    // Settings shows the interface-mode selector, not the panel-only edge UI.
    await tester.tap(find.text('Settings'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('settings-open-0')));
    await _settle(tester);
    expect(find.text('Interface mode'), findsOneWidget);
    expect(find.text('Window'), findsOneWidget);
    expect(find.text('Edge panel'), findsOneWidget);

    // The window never auto-closes on blur, and the dock stays away.
    controller.blur();
    await tester.pump();
    expect(find.byType(NexWindowShell), findsOneWidget);
    expect(find.byType(Dock), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture typing in the window shell is durable', (tester) async {
    final (controller, features, _) = await _bootWindow(tester);

    await tester.runAsync(() async {
      await tester.enterText(
        find.byKey(const ValueKey('capture-field')),
        'window capture note',
      );
      await features.session.flushed;
      final rows = await features.store.call<List<Note>>('timeline');
      expect(rows.single.content, 'window capture note');
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching modes restyles natively and swaps shells', (
    tester,
  ) async {
    final (controller, _, native) = await _bootWindow(tester);

    // Settings -> Edge panel drives the same switch as the rail button.
    await tester.tap(find.text('Settings'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('settings-open-0')));
    await _settle(tester);
    await tester.tap(find.text('Edge panel'));
    await _settle(tester, 12);

    expect(native.modes, contains('panel'));
    expect(find.byType(PanelShell), findsOneWidget);
    expect(find.byType(NexWindowShell), findsNothing);

    // By default the window comes back as the fixed compact card, not at the
    // frame it was left in.
    await controller.setWindowMode('window');
    await _settle(tester, 12);
    expect(native.modes.last, 'window');
    expect(native.lastCompact, isTrue);
    expect(native.lastBounds, isNull);
    expect(native.lastMaximized, isFalse);
    expect(find.byType(NexWindowShell), findsOneWidget);

    // With "remember size and position" on, the saved frame returns.
    await controller.setWindowMode('panel');
    controller.S.windowRemember = true;
    await controller.setWindowMode('window');
    await _settle(tester, 12);
    expect(native.lastCompact, isFalse);
    expect(native.lastBounds?['w'], 1180);
    expect(native.lastBounds?['h'], 780);
    expect(find.byType(NexWindowShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('window mode and frame survive settings round-trip', (
    tester,
  ) async {
    final s = Settings()
      ..windowMode = 'panel'
      ..windowBounds = {'x': 10, 'y': 20, 'w': 900, 'h': 700}
      ..windowMaximized = true;
    final restored = Settings.fromMap(s.toMap());
    expect(restored.windowMode, 'panel');
    expect(restored.windowRemember, isFalse);
    expect(
      Settings.fromMap((s..windowRemember = true).toMap()).windowRemember,
      isTrue,
    );
    expect(restored.windowBounds?['w'], 900);
    expect(restored.windowMaximized, isTrue);

    // Legacy settings without the new keys default to the window mode.
    final legacy = Settings.fromMap(const <String, dynamic>{});
    expect(legacy.windowMode, 'window');
    expect(legacy.windowBounds, isNull);
  });

  testWidgets('edge watcher and hover close stay dormant in window mode', (
    tester,
  ) async {
    final (controller, _, _) = await _bootWindow(tester);
    // Pointer far outside any content: the window must keep rendering.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(const Offset(4, 600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NexWindowShell), findsOneWidget);
    expect(controller.isOpen, isFalse);
    expect(tester.takeException(), isNull);
  });
}
