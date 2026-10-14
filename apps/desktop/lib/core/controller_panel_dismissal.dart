part of 'controller.dart';

mixin PanelDismissal on PanelStateBase {
  bool _pointerDown = false;

  @override
  void dismissPanel({Offset? at}) {
    if (isWindowMode ||
        !isOpen ||
        S.panelPinned ||
        picking ||
        dragging ||
        _holdsTracker.modal) {
      return;
    }
    if (at != null &&
        ((tabRect?.contains(at) ?? false) ||
            (panel != null && (flyRect?.contains(at) ?? false)))) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _holdsTracker.resetFocus();
    close();
  }

  /// A non-activated edge window never receives WM_ACTIVATE when a different
  /// app is clicked. Observe the real pointer button even outside our HWND.
  @override
  void pollPanelPointer() {
    final down = native.leftDown();
    if (!isOpen) {
      _pointerDown = down;
      return;
    }
    final position = native.cursorPos();
    final frame = placement;
    if (position != null && frame != null) {
      final at = Offset(
        (position.$1 - frame.x) / frame.scale,
        (position.$2 - frame.y) / frame.scale,
      );
      if (down && !_pointerDown) dismissPanel(at: at);
      if (!inside(at) && !sticky) maybeClose();
      if (inside(at)) cancelClose();
    }
    _pointerDown = down;
  }
}
