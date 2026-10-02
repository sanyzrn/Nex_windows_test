import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'dart:io';

import 'package:flutter/services.dart';

import 'models.dart';

/// Everything the Dart side needs from the native Windows runner.
/// Implemented with a MethodChannel plus a couple of tiny user32 FFI calls
/// (cursor position + left-button state) used by the edge watcher.
abstract class NativeHost {
  Future<void> setPassthrough(bool on);
  Future<void> rememberForeground();
  Future<void> pasteIntoPrevious(String text);
  Future<void> pressKey(String name);
  Future<String> pinWindow();
  Future<void> lock();
  Future<void> screenOff();
  Future<void> beep();
  Future<void> keepAwake(bool on);
  Future<void> screenshot();
  Future<void> launch(String target);
  Future<void> pickColor();
  Future<void> pickCustomColor(String currentHex);
  Future<void> pickApp({bool folder = false});
  Future<void> appIcon(String id, String path);
  Future<bool> startupEnabled();
  Future<void> setStartup(bool on);
  Future<void> quit();
  Future<void> setClipboardImage(int w, int h, Uint8List rgba);
  Future<Map<String, dynamic>?> applyPlacement(String edge, int monitor);
  Future<List<Map<String, dynamic>>> screens();
  Future<void> ready();

  /// Restyles the host between the full desktop window and the edge panel.
  /// [bounds] is the saved frame (x/y/w/h, physical px) to restore, if any.
  /// No-op off Windows so tests and stubs work unchanged.
  Future<void> setWindowMode(
    String mode, {
    Map<String, dynamic>? bounds,
    bool maximized = false,
    bool show = true,
  }) async {}

  /// Current desktop-window frame {x, y, w, h, maximized} for persistence.
  Future<Map<String, dynamic>?> windowFrame() async => null;

  /// Restores (if minimized) and brings the window to the foreground.
  Future<void> focusWindow() async {}
  Future<bool> configureHotkey(String key) async => false;
  Future<ClipImage?> currentClipboardImage() async => null;
  Future<void> setLabels(Map<String, String> labels) async {}

  /// FFI helpers (no-ops off Windows so tests run everywhere).
  bool get ffiAvailable;
  (int, int)? cursorPos();
  bool leftDown();
}

/// Where the panel lives, in physical screen pixels.
class Placement {
  Placement({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.edgeX,
    required this.scale,
    required this.onLeft,
  });

  final int x, y, w, h, edgeX;
  final double scale;
  final bool onLeft;

  static Placement fromMap(Map<dynamic, dynamic> m) => Placement(
    x: ((m['x'] as num?) ?? 0).toInt(),
    y: ((m['y'] as num?) ?? 0).toInt(),
    w: ((m['w'] as num?) ?? 0).toInt(),
    h: ((m['h'] as num?) ?? 0).toInt(),
    edgeX: ((m['edgeX'] as num?) ?? 0).toInt(),
    scale: ((m['scale'] as num?) ?? 1.0).toDouble(),
    onLeft: (m['onLeft'] as bool?) ?? false,
  );
}

/// Events pushed from C++ to Dart.
class NativeEvents {
  NativeEvents({
    required this.onClipText,
    required this.onClipImage,
    required this.onTray,
    required this.onBlur,
    required this.onFilesDropped,
    required this.onPickedColor,
    required this.onPickedCustomColor,
    required this.onPickedApp,
    required this.onAppIcon,
    this.onPlacement,
    this.onPickerState,
  });

  final void Function(String text) onClipText;
  final void Function(ClipImage img) onClipImage;
  final void Function(String id) onTray;
  final void Function() onBlur;
  final void Function(List<String> paths) onFilesDropped;
  final void Function(String? hex) onPickedColor;
  final void Function(String? hex) onPickedCustomColor;
  final void Function(String path) onPickedApp;
  final void Function(String id, String icon) onAppIcon;
  final void Function(Map<String, dynamic> placement)? onPlacement;
  final void Function(bool active)? onPickerState;
}

base class _Point extends ffi.Struct {
  @ffi.Int32()
  external int x;
  @ffi.Int32()
  external int y;
}

/// The real Windows implementation. Channel calls are cheap; the FFI cursor
/// lookups happen ~80x/second which keeps the edge trigger as tight as the
/// original's native watcher thread.
class WinNativeHost extends NativeHost {
  Future<void> probeDisplayChange() =>
      _channel.invokeMethod('probeDisplayChange');
  Future<void> probeCursor(int x, int y) =>
      _channel.invokeMethod('probeCursor', {'x': x, 'y': y});
  Future<bool> probeHotkey() async =>
      await _channel.invokeMethod<bool>('probeHotkey') ?? false;
  @override
  Future<bool> configureHotkey(String key) async =>
      await _channel.invokeMethod<bool>('hotkey', {'key': key}) ?? false;
  Future<Map<dynamic, dynamic>> diagnostics() async =>
      await _channel.invokeMethod<Map>('diagnostics') ?? {};
  WinNativeHost() : _channel = const MethodChannel('rp/native') {
    _channel.setMethodCallHandler(_handleCall);
  }

  final MethodChannel _channel;
  int _clipboardRequest = 0;
  final _clipboardReads = <int, Completer<ClipImage?>>{};
  @override
  Future<void> setLabels(Map<String, String> labels) =>
      _channel.invokeMethod('labels', labels);
  @override
  Future<ClipImage?> currentClipboardImage() async {
    final id = ++_clipboardRequest;
    final result = Completer<ClipImage?>();
    _clipboardReads[id] = result;
    try {
      await _channel.invokeMethod('readClipboardImage', {'request': id});
      return await result.future.timeout(const Duration(seconds: 10));
    } finally {
      _clipboardReads.remove(id);
    }
  }

  NativeEvents? events;
  void dispose() {
    events = null;
    _channel.setMethodCallHandler(null);
  }

  // ---- events from C++ ----
  Future<dynamic> _handleCall(MethodCall call) async {
    final args = call.arguments;
    final map = args is Map
        ? args.cast<String, dynamic>()
        : <String, dynamic>{};
    switch (call.method) {
      case 'placement':
        events?.onPlacement?.call(map);
        break;
      case 'clipboardRead':
        final rgba = map['rgba'] as Uint8List?;
        _clipboardReads[(map['request'] as num).toInt()]?.complete(
          rgba == null
              ? null
              : ClipImage(
                  id: map['id'].toString(),
                  w: (map['w'] as num).toInt(),
                  h: (map['h'] as num).toInt(),
                  rgba: rgba,
                ),
        );
        break;
      case 'clipText':
        events?.onClipText(map['text'] as String? ?? '');
        break;
      case 'clipImage':
        final rgba = map['rgba'] as Uint8List?;
        if (rgba != null) {
          events?.onClipImage(
            ClipImage(
              id: map['id']?.toString() ?? '',
              w: (map['w'] as num?)?.toInt() ?? 0,
              h: (map['h'] as num?)?.toInt() ?? 0,
              rgba: rgba,
            ),
          );
        }
        break;
      case 'tray':
        events?.onTray(map['id'] as String? ?? '');
        break;
      case 'blur':
        events?.onBlur();
        break;
      case 'files':
        final l = map['paths'];
        if (l is List) events?.onFilesDropped(l.cast<String>());
        break;
      case 'pickedColor':
        events?.onPickedColor(map['hex'] as String?);
        break;
      case 'pickedCustomColor':
        events?.onPickedCustomColor(map['hex'] as String?);
        break;
      case 'pickedApp':
        final path = map['path'] as String? ?? '';
        if (path.trim().isNotEmpty) events?.onPickedApp(path);
        break;
      case 'pickerState':
        events?.onPickerState?.call(map['active'] == true);
        break;
      case 'appIcon':
        events?.onAppIcon(
          map['id'] as String? ?? '',
          map['icon'] as String? ?? '',
        );
        break;
    }
    return null;
  }

  // ---- calls to C++ ----
  @override
  Future<void> setPassthrough(bool on) =>
      _channel.invokeMethod('setPassthrough', {'on': on});

  @override
  Future<void> rememberForeground() =>
      _channel.invokeMethod('rememberForeground');

  @override
  Future<void> pasteIntoPrevious(String text) =>
      _channel.invokeMethod('pasteIntoPrevious', {'text': text});

  @override
  Future<void> pressKey(String name) =>
      _channel.invokeMethod('pressKey', {'name': name});

  @override
  Future<String> pinWindow() async =>
      await _channel.invokeMethod('pinWindow') as String? ?? '';

  @override
  Future<void> lock() => _channel.invokeMethod('lock');

  @override
  Future<void> screenOff() => _channel.invokeMethod('screenOff');

  @override
  Future<void> beep() => _channel.invokeMethod('beep');

  @override
  Future<void> keepAwake(bool on) =>
      _channel.invokeMethod('keepAwake', {'on': on});

  @override
  Future<void> screenshot() => _channel.invokeMethod('screenshot');

  @override
  Future<void> launch(String target) =>
      _channel.invokeMethod('launch', {'target': target});

  @override
  Future<void> pickColor() => _channel.invokeMethod('pickColor');

  @override
  Future<void> pickCustomColor(String currentHex) =>
      _channel.invokeMethod('pickCustomColor', {'current': currentHex});

  @override
  Future<void> pickApp({bool folder = false}) =>
      _channel.invokeMethod('pickApp', {'folder': folder});

  @override
  Future<void> appIcon(String id, String path) =>
      _channel.invokeMethod('appIcon', {'id': id, 'path': path});

  @override
  Future<bool> startupEnabled() async =>
      await _channel.invokeMethod('startupEnabled') as bool? ?? false;

  @override
  Future<void> setStartup(bool on) =>
      _channel.invokeMethod('setStartup', {'on': on});

  @override
  Future<void> quit() => _channel.invokeMethod('quit');

  @override
  Future<void> setClipboardImage(int w, int h, Uint8List rgba) => _channel
      .invokeMethod('setClipboardImage', {'w': w, 'h': h, 'rgba': rgba});

  @override
  Future<Map<String, dynamic>?> applyPlacement(String edge, int monitor) async {
    final v = await _channel.invokeMethod('applyPlacement', {
      'edge': edge,
      'monitor': monitor,
    });
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> screens() async {
    final v = await _channel.invokeMethod('screens');
    if (v is List) {
      return v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    }
    return [];
  }

  @override
  Future<void> ready() => _channel.invokeMethod('ready');

  @override
  Future<void> setWindowMode(
    String mode, {
    Map<String, dynamic>? bounds,
    bool maximized = false,
    bool show = true,
  }) => _channel.invokeMethod('setWindowMode', {
    'mode': mode,
    if (bounds != null) ...bounds,
    'maximized': maximized,
    'show': show,
  });

  @override
  Future<Map<String, dynamic>?> windowFrame() async {
    final v = await _channel.invokeMethod('windowFrame');
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  @override
  Future<void> focusWindow() => _channel.invokeMethod('focusWindow');

  // ---- FFI: cursor + left button ----
  ffi.DynamicLibrary? _user32;
  int Function(ffi.Pointer<_Point>)? _getCursorPos;
  int Function(int)? _getAsyncKeyState;

  @override
  bool get ffiAvailable => Platform.isWindows;

  void _initFfi() {
    if (_user32 != null) return;
    if (!Platform.isWindows) {
      _user32 = ffi.DynamicLibrary.process(); // placeholder, never used
      return;
    }
    _user32 = ffi.DynamicLibrary.open('user32.dll');
    _getCursorPos = _user32!
        .lookupFunction<
          ffi.Int32 Function(ffi.Pointer<_Point>),
          int Function(ffi.Pointer<_Point>)
        >('GetCursorPos');
    _getAsyncKeyState = _user32!
        .lookupFunction<ffi.Int16 Function(ffi.Int32), int Function(int)>(
          'GetAsyncKeyState',
        );
  }

  @override
  (int, int)? cursorPos() {
    if (!ffiAvailable) return null;
    _initFfi();
    final p = calloc<_Point>();
    try {
      final ok = _getCursorPos!(p);
      if (ok == 0) return null;
      return (p.ref.x, p.ref.y);
    } finally {
      calloc.free(p);
    }
  }

  @override
  bool leftDown() {
    if (!ffiAvailable) return false;
    _initFfi();
    return (_getAsyncKeyState!(0x01)) < 0; // VK_LBUTTON
  }
}
