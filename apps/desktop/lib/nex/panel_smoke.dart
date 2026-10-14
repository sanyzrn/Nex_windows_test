import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../core/controller.dart';
import '../core/native.dart';
import '../main.dart' show RightPanelApp;
import 'features_state.dart';
import 'store.dart';

/// Explicit diagnostic entry point: temporary SQLite data, no saved settings,
/// no clipboard writes, no edge polling and no change to the user's instance.
Future<void> panelSmoke(String output) async {
  final root = await Directory.systemTemp.createTemp('nex-panel-probe-');
  final native = WinNativeHost();
  final initialCursor = native.cursorPos();
  final features = NexFeatures(
    await DesktopStore.open(root.path, 'panel-probe'),
  );
  final c = PanelController(nativeHost: native);
  final boundaryKey = GlobalKey();
  final result = <String, dynamic>{'cycles': <Map<String, dynamic>>[]};
  final errors = <String>[];
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  final report = File(output);
  await report.parent.create(recursive: true);
  Future<void> checkpoint(String stage) async {
    result['stage'] = stage;
    result['ui'] = {
      'frames': c.frame.value,
      'grow': c.grow.v,
      'focusAttached': features.focus.context != null,
      'focused': features.focus.hasFocus,
    };
    await report.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
    );
  }

  Future<void> waitFor(bool Function() condition) async {
    final limit = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(limit)) {
        throw StateError('UI condition timed out');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<Map<String, dynamic>> ready(bool window) async {
    var state = <String, dynamic>{};
    await waitFor(() {
      unawaited(
        native.diagnostics().then(
          (value) => state = value.cast<String, dynamic>(),
        ),
      );
      return state['surfaceReady'] == true && state['windowMode'] == window;
    });
    return state;
  }

  Future<void> hover(String id) async {
    final box = c.toolKey(id).currentContext!.findRenderObject() as RenderBox;
    final at = box.localToGlobal(box.size.center(Offset.zero));
    final pl = c.placement!;
    await native.probeCursor(
      (pl.x + at.dx * pl.scale).round(),
      (pl.y + at.dy * pl.scale).round(),
    );
    await waitFor(() => c.panel == id);
  }

  Future<void> screenshot(String name) async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${report.parent.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  try {
    await checkpoint('bootstrap');
    await c.bootstrap(
      preset: Settings()
        ..language = 'en'
        ..dock = ['note', 'timeline', 'clip', 'calc', 'more'],
      useNative: false,
    );
    await native.setWindowMode('window', show: false);
    runApp(
      RepaintBoundary(
        key: boundaryKey,
        child: RightPanelApp(controller: c, features: features),
      ),
    );
    await checkpoint('initial frame');
    await ready(true);
    for (var i = 0; i < 3; i++) {
      c.S.edge = i.isOdd ? 'left' : 'right';
      await checkpoint('panel $i');
      await c.setWindowMode('panel');
      final hidden = await ready(false);
      if (hidden['visible'] != false ||
          c.panel != null ||
          c.lastPanel != null) {
        throw StateError('Previous surface survived the mode switch');
      }
      if (hidden['clientWidth'] != hidden['viewWidth'] ||
          hidden['clientHeight'] != hidden['viewHeight']) {
        throw StateError('Flutter view does not match the panel host');
      }
      c.open();
      await waitFor(() => c.slide.v > .99);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await hover('note');
      await checkpoint('focused capture $i');
      // Hover does not activate another application's Win32 window. Activate
      // this isolated host before checking keyboard focus and moving on.
      await native.focusWindow();
      await waitFor(() => features.focus.context != null);
      features.focus.requestFocus();
      await waitFor(() => features.focus.hasFocus);
      await hover('timeline');
      c.S.panelPinned = true;
      await hover('clip');
      await hover('calc');
      await checkpoint('hover completed $i');
      final shown = await native.diagnostics();
      if (shown['visible'] != true) throw StateError('Panel did not reveal');
      await screenshot('panel-probe-${c.S.edge}-$i');
      c.S.panelPinned = false;
      // Closing queues a delayed native hide; returning to window must cancel it.
      c.close();
      await c.setWindowMode('window');
      await checkpoint('window $i');
      await ready(true);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      final window = await native.diagnostics();
      if (window['visible'] != true) {
        throw StateError('Old close timer hid the new window');
      }
      (result['cycles'] as List).add({
        'edge': c.S.edge,
        'hidden': hidden,
        'shown': shown,
        'window': window,
        'hoverWithFocus': true,
        'hoverPinned': true,
      });
    }
    await screenshot('panel-probe-window');
    result['pass'] = errors.isEmpty;
  } catch (error, stack) {
    result['pass'] = false;
    result['error'] = '$error';
    result['stack'] = '$stack';
  } finally {
    result['flutterErrors'] = errors;
    if (initialCursor != null) {
      await native.probeCursor(initialCursor.$1, initialCursor.$2);
    }
    runApp(const SizedBox());
    await WidgetsBinding.instance.endOfFrame;
    await features.close();
    await report.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
    );
    await root.delete(recursive: true);
    await native.quit();
  }
}
