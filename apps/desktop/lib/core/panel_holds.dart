// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Holds, auto-hide suppression, and modal route tracking.
/// Owns [PanelRouteObserver], interacting lease management, and auto-hide suppression.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

abstract interface class PanelHoldable {
  VoidCallback holdOpen();
}

/// Popup menus and secondary routes can extend beyond the measured flyout.
/// Keep their host alive until Navigator dismisses them.
class PanelRouteObserver extends NavigatorObserver {
  PanelRouteObserver(this.controller);
  final PanelHoldable controller;
  final _holds = <Route<dynamic>, VoidCallback>{};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _holds[route] = controller.holdOpen();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _release(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _release(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final held = _holds.containsKey(oldRoute);
    if (oldRoute != null) _release(oldRoute);
    if (held && newRoute != null) _holds[newRoute] = controller.holdOpen();
  }

  void _release(Route<dynamic> route) => _holds.remove(route)?.call();
}

/// Tracks interactive leases, text focus, and keep-open rules.
class PanelHoldsTracker {
  int _textFocusCount = 0;
  int _interactionCount = 0;

  void focusGained() => _textFocusCount++;
  void focusLost() => _textFocusCount = math.max(0, _textFocusCount - 1);
  bool get typing => _textFocusCount > 0;

  bool get interacting => _interactionCount > 0;

  VoidCallback acquireHold(VoidCallback onFirstHold, VoidCallback onLastRelease) {
    _interactionCount++;
    if (_interactionCount == 1) {
      onFirstHold();
    }
    var released = false;
    return () {
      if (released) return;
      released = true;
      _interactionCount--;
      if (_interactionCount == 0) {
        onLastRelease();
      }
    };
  }
}
