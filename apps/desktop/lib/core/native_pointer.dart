part of 'native.dart';

base class _Point extends ffi.Struct {
  @ffi.Int32()
  external int x;
  @ffi.Int32()
  external int y;
}

mixin _NativePointer on NativeHost {
  (int, int)? get _probePos;
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
      if (ok == 0) return _probePos;
      if (p.ref.x == 0 && p.ref.y == 0 && _probePos != null) {
        return _probePos;
      }
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
