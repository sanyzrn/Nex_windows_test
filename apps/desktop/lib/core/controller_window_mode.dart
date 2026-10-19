part of 'controller.dart';

mixin PanelWindowTransitions on PanelStateBase {
  Future<void> _modeTail = Future.value();

  /// Switches between the desktop window (main) and edge panel (optional).
  /// Persists the desktop window's frame so nothing is lost between modes.
  @override
  Future<void> setWindowMode(String mode) {
    final task = _modeTail.then((_) => _changeWindowMode(mode));
    _modeTail = task.catchError((Object _) {});
    return task;
  }

  Future<void> _changeWindowMode(String mode) async {
    if (_disposed) return;
    if (mode != 'window' && mode != 'panel') return;
    if (mode == S.windowMode) return;
    final leavingWindow = S.windowMode == 'window';
    if (leavingWindow) {
      await _rememberWindowFrame();
    }
    windowModeChanging = true;
    cancelClose();
    // Delayed panel reveal/hide callbacks belong to the old surface.
    for (final timer in _delayed) {
      timer.cancel();
    }
    _delayed.clear();
    if (mode == 'panel') {
      // Return to the edge: borderless, topmost, hidden until revealed.
      _resetPanelSurface();
      try {
        await native.setWindowMode('panel');
        try {
          screens = await native.screens();
          S.monitor = displayIndex(screens, S.monitorName, S.monitor);
        } catch (_) {}
        final p = await native.applyPlacement(S.edge, S.monitor);
        if (p != null) placement = Placement.fromMap(p);
      } catch (_) {}
    } else {
      windowTool.value = null;
      windowSection.value = 'capture';
      try {
        await native.setWindowMode(
          'window',
          bounds: S.windowRemember ? S.windowBounds : null,
          maximized: S.windowRemember && S.windowMaximized,
          compact: !S.windowRemember,
          show: true,
        );
      } catch (_) {}
    }
    if (_disposed) return;
    S.windowMode = mode;
    windowModeChanging = false;
    save();
    notifyListeners();
    // A hidden Win32 host can suspend vsync. Build the new shell offscreen;
    // its post-frame acknowledgement then requests a real engine redraw.
    _later(Duration.zero, () => WidgetsBinding.instance.scheduleWarmUpFrame());
  }

  void _resetPanelSurface() {
    isOpen = sticky = sub = dragging = false;
    panel = lastPanel = null;
    hoverY = null;
    tabRect = flyRect = null;
    flyH = 0;
    mx = -1;
    _near = false;
    _held = 0;
    _lastX = _lastY = -2147483648;
    _dragCandidate = null;
    _dragMoved = false;
    _holdsTracker.resetFocus();
    dragInfo.value = null;
    dropHintOn.value = false;
    openedAt = closedAt = -1e9;
    for (final spring in [
      slide,
      grow,
      flyHs,
      pillS,
      for (final springs in toolSprings.values) ...[
        springs.sp,
        springs.mg,
        springs.pr,
      ],
    ]) {
      spring.v = spring.t = spring.vel = 0;
    }
  }

  @override
  Future<void> _rememberWindowFrame() async {
    try {
      final frame = await native.windowFrame();
      if (frame != null &&
          (frame['w'] as num?) != null &&
          (frame['h'] as num?) != null) {
        S.windowBounds = frame;
        S.windowMaximized = frame['maximized'] == true;
      }
    } catch (_) {}
  }
}
