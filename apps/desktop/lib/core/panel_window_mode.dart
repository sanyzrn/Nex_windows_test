// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Window mode state and geometry management for the desktop window shell.
/// Owns window frame validation, coordinate clamping across monitors, and bounds formatting.
library;

class WindowFrameHelper {
  /// Validates and ensures the stored window bounds fall within at least one active screen.
  /// If the bounds are off-screen or empty, returns null to trigger default centering.
  static Map<String, dynamic>? validateBounds({
    required Map<String, dynamic>? bounds,
    required List<Map<String, dynamic>> screens,
    int minWidth = 400,
    int minHeight = 300,
  }) {
    if (bounds == null) return null;
    final x = (bounds['x'] as num?)?.toInt();
    final y = (bounds['y'] as num?)?.toInt();
    final w = (bounds['w'] as num?)?.toInt();
    final h = (bounds['h'] as num?)?.toInt();
    if (x == null || y == null || w == null || h == null) return null;
    if (w < minWidth || h < minHeight) return null;

    if (screens.isEmpty) return bounds;

    // Check if the center of the window intersects any screen
    final cx = x + w / 2;
    final cy = y + h / 2;
    final onAnyScreen = screens.any((s) {
      final sx = (s['x'] as num?)?.toDouble() ?? 0;
      final sy = (s['y'] as num?)?.toDouble() ?? 0;
      final sw = (s['w'] as num?)?.toDouble() ?? 0;
      final sh = (s['h'] as num?)?.toDouble() ?? 0;
      return cx >= sx && cx <= sx + sw && cy >= sy && cy <= sy + sh;
    });

    return onAnyScreen ? bounds : null;
  }
}
