// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Panel geometry, spring physics, and dock/flyout drag calculations.
/// Owns [ToolInfo], [ToolSprings], [DragInfo], [DragCandidate], and geometry models.
library;

import 'package:flutter/material.dart';
import 'models.dart';
import 'registry.dart';
import 'spring.dart';

/// Info about a dockable widget: a registry tool or a pinned app.
class ToolInfo {
  const ToolInfo({
    required this.id,
    required this.name,
    this.emoji,
    this.svg,
    required this.kind,
    this.dockOnly = false,
    this.fixed = false,
    this.action,
    this.app,
  });

  factory ToolInfo.of(String id) {
    if (id.startsWith('app-')) {
      final app = controllerApps.firstWhere(
        (a) => a.id == id,
        orElse: () => AppItem(id: id, name: 'App', path: ''),
      );
      return ToolInfo(
        id: id,
        name: app.name,
        emoji: app.icon == null ? '🚀' : null,
        kind: ToolKind.app,
        app: app,
      );
    }
    final w = kTools[id]!;
    return ToolInfo(
      id: id,
      name: w.name,
      emoji: w.emoji,
      svg: w.svg,
      kind: w.kind,
      dockOnly: w.dockOnly,
      fixed: w.fixed,
      action: w.action,
    );
  }

  static List<AppItem> controllerApps = [];

  final String id;
  final String name;
  final String? emoji;
  final String? svg;
  final ToolKind kind;
  final bool dockOnly;
  final bool fixed;
  final String? action;
  final AppItem? app;
}

/// Per-tool springs, preserved across re-renders (like el._s / el._m / el._p
/// on the DOM nodes) so tools never re-pop when the list is rebuilt.
class ToolSprings {
  ToolSprings()
    : sp = Spring(0, 380, 25),
      mg = Spring(0, 500, 30),
      pr = Spring(0, 700, 28);
  final Spring sp;
  final Spring mg;
  final Spring pr;
}

Color hexToColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.tryParse(h, radix: 16) ?? 0xFF000000);
}

String colorToHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// Live drag state for widget reordering (ghost, hovered zone, insert index).
class DragInfo {
  DragInfo({
    required this.id,
    required this.moved,
    this.zone,
    this.insertIdx = 0,
    this.pointer,
  });

  final String id;
  final bool moved;
  final String? zone; // dock | more | wdock | wmore
  final int insertIdx;
  final Offset? pointer;
}

class DragCandidate {
  DragCandidate(this.id, this.start);

  final String id;
  final Offset start;
}
