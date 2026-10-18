// Part of the PanelController split (see controller.dart). Members
// below are spliced into the class body; do not import this file directly.
part of 'controller.dart';

/// Drag & drop plumbing, tile/tab taps, flyout panel switching and actions.

/// The mixin contract... fields belong to [PanelBase]; see controller.dart.
mixin PanelActions on PanelStateBase {
  @override
  void beginDragCandidate(String id, Offset position) {
    _dragCandidate = DragCandidate(id, position);
  }

  /// Handles a pointer that might be dragging a widget. Returns true while a
  /// drag is in progress (the shell calls this from its root listener).
  @override
  bool handleDragPointer(PointerEvent e) {
    final cand = _dragCandidate;
    if (cand == null) return dragInfo.value != null;
    if (e is PointerUpEvent || e.buttons == 0) {
      {
        _endDrag(e.position);
      }
      return false;
    }
    if (!_dragMoved) {
      if ((e.position - cand.start).distance < 5) return false;
      _dragMoved = true;
      dragging = true;
      cancelClose();
    }
    _updateDrag(cand.id, e.position);
    return true;
  }

  void _updateDrag(String id, Offset p) {
    final zone = _zoneAt(p);
    if (zone == null || (zone == 'more' && (kTools[id]?.dockOnly ?? false))) {
      if (dragInfo.value?.id == id) {
        dragInfo.value = DragInfo(id: id, moved: true, zone: null, pointer: p);
      }
      return;
    }
    final idx = _insertIndex(zone, p, id);
    dragInfo.value = DragInfo(
      id: id,
      moved: true,
      zone: zone,
      insertIdx: idx,
      pointer: p,
    );
  }

  String? _zoneAt(Offset p) {
    for (final entry in zoneKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is RenderBox && box.attached) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect.inflate(4).contains(p)) return entry.key;
      }
    }
    return null;
  }

  int _insertIndex(String zone, Offset p, String draggingId) {
    final list = zone == 'dock'
        ? S.dock!
        : zone == 'more'
        ? S.more!
        : zone == 'wdock'
        ? S.dock!
        : S.more!;
    final withHidden = zone.startsWith('w');
    final kids = list
        .where((x) => x != draggingId && (withHidden || !S.hidden.contains(x)))
        .toList();
    final isGrid = zone == 'more';
    for (var i = 0; i < kids.length; i++) {
      final key = toolKeys[kids[i]];
      final ctx = key?.currentContext;
      final box = ctx?.findRenderObject();
      if (box is RenderBox && box.attached) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final hit = isGrid
            ? (p.dy < rect.bottom &&
                      (resolvedLanguage == 'fa'
                          ? p.dx > rect.center.dx
                          : p.dx < rect.center.dx)) ||
                  p.dy < rect.top
            : p.dy < rect.top + rect.height / 2;
        if (hit) return i;
      }
    }
    return kids.length;
  }

  void _endDrag(Offset p) {
    final cand = _dragCandidate;
    final info = dragInfo.value;
    _dragCandidate = null;
    dragging = false;
    dragInfo.value = null;
    if (cand != null && _dragMoved && info?.zone != null) {
      final zone = info!.zone!;
      final list = zone == 'dock' ? 'dock' : 'more';
      moveWidget(
        cand.id,
        list,
        info.insertIdx,
        withHidden: zone.startsWith('w'),
      );
    }
    if (_dragMoved) {
      // clicks that happen right after a drag are swallowed
      _later(const Duration(milliseconds: 60), () {
        _dragMoved = false;
      });
    }
    notifyListeners();
  }

  /// Guard used by tool taps (the original's dragMoved check).
  bool get dragMoved => _dragMoved;

  /// Port of the tiles click handler (opens as a sub-panel of More).
  @override
  void onTileTap(String id) {
    if (_dragMoved) return;
    final w = ToolInfo.of(id);
    if (w.kind == ToolKind.panel) {
      anchorY = fy.v;
      setPanel(id, fromMore: true);
    } else {
      openWidget(id);
    }
  }

  /// Port of the tab click handler.
  @override
  void onToolTap(String id) {
    if (_dragMoved) return;
    final w = ToolInfo.of(id);
    if (w.kind == ToolKind.app) {
      _later(const Duration(milliseconds: 160), () {
        close();
        unawaited(native.launch(w.app!.path).catchError((_) {}));
      });
      return;
    }
    if (w.kind == ToolKind.action) {
      runAction(w.action!);
      return;
    }
    anchorY = dockAnchorOf?.call(id) ?? anchorY;
    setPanel(panel == id && !sub ? null : id);
  }

  // ---- flyout panel switching (setPanel) ----
  @override
  void setPanel(String? name, {bool fromMore = false}) {
    if (name != null && panel == null) {
      fy.v = anchorY;
      fy.vel = 0;
      grow.v = 0;
      grow.vel = 0;
    } else if (name != null && panel != null && name != panel) {
      grow.vel -= 3; // little squish when switching
    }
    if (name != null) {
      if (name != panel) panelSerial++;
      lastPanel = name;
    }
    panel = name;
    sub = name != null && fromMore;
    notifyListeners();
  }

  @override
  void openWidget(String id) {
    final w = ToolInfo.of(id);
    if (w.kind == ToolKind.app) {
      _later(const Duration(milliseconds: 160), () {
        close();
        unawaited(native.launch(w.app!.path).catchError((_) {}));
      });
      return;
    }
    if (w.kind == ToolKind.action) {
      runAction(w.action!);
      return;
    }
    final opening = panel == null;
    final dockAnchor = dockAnchorOf?.call(id);
    if (S.dock!.contains(id) || (dockAnchor != null && dockAnchor.isFinite)) {
      // Audit defect 6: the card keeps one anchor while it is open. Re-anchoring
      // to the next tool's dock slot made the card leap between views.
      if (opening) anchorY = dockAnchor ?? anchorY;
      setPanel(id);
    } else {
      if (opening) anchorY = moreAnchorOf?.call() ?? 340;
      setPanel(id, fromMore: true);
    }
  }

  @override
  void runAction(String action) {
    switch (action) {
      case 'shot':
        close();
        unawaited(native.screenshot().catchError((_) {}));
        break;
      case 'awake':
        unawaited(toggleAwake());
        break;
      case 'pinwin':
        native
            .pinWindow()
            .then((result) {
              final parts = result.split('\n');
              toast(
                parts.length == 2
                    ? message(
                        parts.first == 'pinned'
                            ? 'Pinned {value}'
                            : 'Unpinned {value}',
                        {'value': parts.last},
                      )
                    : result,
              );
            })
            .catchError((_) {});
        break;
      case 'desktop':
        close();
        unawaited(native.pressKey('desktop').catchError((_) {}));
        break;
      case 'screenoff':
        close();
        unawaited(native.screenOff().catchError((_) {}));
        break;
      case 'lock':
        close();
        unawaited(native.lock().catchError((_) {}));
        break;
      case 'taskmgr':
        close();
        unawaited(native.launch('taskmgr').catchError((_) {}));
        break;
      case 'winset':
        close();
        unawaited(native.launch('ms-settings:').catchError((_) {}));
        break;
    }
  }

  Future<void> toggleAwake() async {
    if (awakeBusy || _disposed) return;
    awakeBusy = true;
    notifyListeners();
    final next = !awake;
    try {
      await native.keepAwake(next);
      if (_disposed) return;
      awake = next;
      toast(awake ? '☀ PC stays awake' : 'Sleep allowed again');
    } catch (_) {
      if (!_disposed) toast('Could not change keep awake');
    } finally {
      awakeBusy = false;
      if (!_disposed) notifyListeners();
    }
  }
}
