import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/ui/dock.dart';
import 'package:nex_desktop/ui/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Native extends NativeHost {
  bool button = false;
  (int, int)? position;
  @override
  bool leftDown() => button;
  @override
  (int, int)? cursorPos() => position;
  final calls = <String>[];
  Completer<void>? gate;
  @override
  Future<void> setWindowMode(
    String mode, {
    Map<String, dynamic>? bounds,
    bool maximized = false,
    bool show = true,
    bool compact = false,
  }) async {
    calls.add('mode:$mode');
    await gate?.future;
  }

  @override
  Future<void> surfaceReady(String mode) async => calls.add('frame:$mode');
  @override
  Future<void> setPassthrough(bool on) async => calls.add('hidden:$on');
  @override
  Future<Map<String, dynamic>?> applyPlacement(String edge, int monitor) async {
    calls.add('placement:$edge');
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<void> _frames(WidgetTester t, [int count = 60]) async {
  for (var i = 0; i < count; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Finder _tool(String id) =>
    find.byWidgetPredicate((w) => w is ToolVisual && w.id == id);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'mode switch clears old flyout and acknowledges only a painted panel',
    (t) async {
      final native = _Native();
      final c = PanelController(nativeHost: native);
      await c.bootstrap(
        preset: Settings()..windowMode = 'window',
        useNative: false,
      );
      await t.pumpWidget(RightPanelApp(controller: c));
      native.calls.clear();
      c.panel = c.lastPanel = 'note';
      c.grow.v = c.slide.v = 1;
      c.flyH = 600;
      c.mx = 0;
      c.close(); // stale delayed hide must not affect a later window
      await c.setWindowMode('panel');
      expect(native.calls, ['mode:panel', 'placement:right']);
      expect(c.panel, isNull);
      expect(c.lastPanel, isNull);
      expect(c.grow.v, 0);
      expect(c.slide.v, 0);
      expect(c.mx, -1);
      await t.pump();
      expect(find.byType(PanelShell), findsOneWidget);
      expect(native.calls.last, 'frame:panel');
      c.open();
      c.close();
      await c.setWindowMode('window');
      await _frames(t, 45);
      expect(native.calls.last, 'frame:window');
      expect(native.calls.where((s) => s == 'hidden:true'), isEmpty);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'rapid mode requests execute in order without publishing an unfinished host',
    (t) async {
      final native = _Native();
      final c = PanelController(nativeHost: native);
      await c.bootstrap(
        preset: Settings()..windowMode = 'window',
        useNative: false,
      );
      native.gate = Completer<void>();
      final first = c.setWindowMode('panel');
      final second = c.setWindowMode('window');
      await t.pump();
      expect(c.windowModeChanging, isTrue);
      expect(c.isWindowMode, isTrue);
      expect(native.calls, ['mode:panel']);
      native.gate!.complete();
      await Future.wait([first, second]);
      expect(native.calls, ['mode:panel', 'placement:right', 'mode:window']);
      expect(c.isWindowMode, isTrue);
      expect(c.windowModeChanging, isFalse);
      c.dispose();
    },
  );

  for (final edge in ['left', 'right']) {
    testWidgets(
      '$edge hover opens the first item and still switches while pinned or focused',
      (t) async {
        t.view.physicalSize = const Size(480, 680);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final c = PanelController(nativeHost: _Native());
        await c.bootstrap(
          preset: Settings()
            ..windowMode = 'panel'
            ..dock = ['note', 'clip', 'more']
            ..edge = edge,
          useNative: false,
        );
        c.open();
        await t.pumpWidget(RightPanelApp(controller: c));
        await _frames(t);
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(240, 10));
        await mouse.moveTo(t.getCenter(_tool('note')));
        await t.pump();
        expect(c.panel, 'note');
        await _frames(t);
        final iconCenter = t.getCenter(_tool('note'));
        final pillCenter = t.getCenter(
          find.byKey(const ValueKey('dock-active-pill')),
        );
        expect(
          (pillCenter - iconCenter).distance,
          lessThan(0.5),
          reason: 'Hover center: icon=$iconCenter pill=$pillCenter',
        );
        c.S.panelPinned = true;
        c.focusGained();
        await mouse.moveTo(t.getCenter(_tool('clip')));
        await t.pump();
        expect(c.panel, 'clip');
        final readerRelease = c.holdOpen(modal: false);
        await mouse.moveTo(t.getCenter(_tool('note')));
        await t.pump();
        expect(c.panel, 'note');
        readerRelease();
        await mouse.moveTo(t.getCenter(_tool('clip')));
        await t.pump();
        final release = c.holdOpen();
        await mouse.moveTo(t.getCenter(_tool('settings')));
        await t.pump();
        expect(c.panel, 'clip');
        release();
        // Retry on movement inside the same item, without requiring re-entry.
        await mouse.moveTo(t.getCenter(_tool('settings')) + const Offset(1, 1));
        await t.pump();
        expect(c.panel, 'settings');
        c.focusLost();
        await mouse.removePointer();
        await t.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }

  testWidgets(
    'global outside clicks still dismiss after release while closed',
    (t) async {
      final native = _Native()..position = (1000, 1000);
      final c = PanelController(nativeHost: native);
      await c.bootstrap(
        preset: Settings()..windowMode = 'panel',
        useNative: false,
      );
      c.placement = Placement.fromMap({
        'x': 0,
        'y': 0,
        'w': 480,
        'h': 680,
        'scale': 1,
        'edgeX': 480,
        'onLeft': false,
      });
      for (var i = 0; i < 3; i++) {
        c.open();
        c.sticky = true;
        native.button = true;
        c.pollPanelPointer();
        expect(c.isOpen, isFalse);
        native.button = false;
        c.pollPanelPointer();
        await t.pump(const Duration(seconds: 1));
      }
      c.dispose();
    },
  );

  testWidgets('outside pointer movement does not keep extending auto-close', (
    t,
  ) async {
    final c = PanelController(nativeHost: _Native());
    await c.bootstrap(
      preset: Settings()..windowMode = 'panel',
      useNative: false,
    );
    c.open();
    c.maybeClose();
    await t.pump(const Duration(milliseconds: 400));
    c.maybeClose();
    await t.pump(const Duration(milliseconds: 201));
    expect(c.isOpen, isFalse);
    c.dispose();
  });

  testWidgets(
    'outside click dismisses a focused sticky reader but protects modal and pin',
    (t) async {
      final c = PanelController(nativeHost: _Native());
      await c.bootstrap(
        preset: Settings()..windowMode = 'panel',
        useNative: false,
      );
      c.open();
      c.sticky = true;
      c.focusGained();
      final reader = c.holdOpen(modal: false);
      final modal = c.holdOpen();
      c.dismissPanel();
      expect(c.isOpen, isTrue);
      modal();
      c.S.panelPinned = true;
      c.dismissPanel();
      expect(c.isOpen, isTrue);
      c.S.panelPinned = false;
      c.dismissPanel();
      expect(c.isOpen, isFalse);
      expect(c.typing, isFalse);
      reader();
      reader();
      expect(c.interacting, isFalse);
      await t.pump(const Duration(seconds: 1));
      c.dispose();
    },
  );
}
