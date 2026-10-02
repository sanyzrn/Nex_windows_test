import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';

import '../core/controller.dart';
import '../core/registry.dart';
import 'dock.dart';
import 'flyout.dart';
import 'svg_icon.dart';
import 'widgets.dart';

/// The window-sized root: hosts the dock and the flyout, runs the single
/// ticker that steps every spring (the port of the original's frame()),
/// and handles pointer/edge/escape interactions.
class PanelShell extends StatefulWidget {
  const PanelShell({super.key, required this.controller});

  final PanelController controller;

  @override
  State<PanelShell> createState() => _PanelShellState();
}

class _PanelShellState extends State<PanelShell>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _lastSec = 0;
  double _toolsTop = double.nan;
  bool _measurementPending = false;

  @override
  void initState() {
    super.initState();
    _lastSec = 0;
    _ticker = createTicker(_onTick);
    _ticker.start();
    final c = widget.controller;
    c.dockAnchorOf = _dockAnchor;
    c.moreAnchorOf = () => _dockAnchor('more') ?? 340;
    c.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    // Geometry hooks belong to this shell; a later window shell must not
    // call stale closures into a defunct element tree.
    final c = widget.controller;
    c.dockAnchorOf = null;
    c.moreAnchorOf = null;
    _ticker.dispose();
    super.dispose();
  }

  /// Scrolls the dock to keep the active tool reachable when the dock
  /// overflows its viewport.
  String? _lastActiveTool;
  void _onControllerChanged() {
    final active = widget.controller.activeToolId;
    if (active == _lastActiveTool) return;
    _lastActiveTool = active;
    if (active == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = widget.controller.toolKey(active).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 240),
          curve: kSpring,
          alignment: .5,
        );
      }
    });
  }

  double _viewportTop() {
    return _toolsTop;
  }

  void _measureAfterLayout() {
    if (_measurementPending) return;
    _measurementPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementPending = false;
      if (!mounted) return;
      _measureGeometry();
    });
  }

  void _measureGeometry() {
    final c = widget.controller;
    final ctx = c.toolsViewportKey.currentContext;
    final box = ctx?.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      _toolsTop = box.localToGlobal(Offset.zero).dy;
    } else {
      _toolsTop = double.nan;
    }
    final flyBox = c.flyBoxKey.currentContext?.findRenderObject();
    if (flyBox is RenderBox && flyBox.attached && flyBox.hasSize) {
      final height = flyBox.size.height;
      if (height.isFinite && (height - c.flyH).abs() > .5) c.flyH = height;
      c.flyRect = MatrixUtils.transformRect(
        flyBox.getTransformTo(null),
        Offset.zero & flyBox.size,
      );
    }
    final tabBox = c.tabBoxKey.currentContext?.findRenderObject();
    if (tabBox is RenderBox && tabBox.attached && tabBox.hasSize) {
      c.tabRect = tabBox.localToGlobal(Offset.zero) & tabBox.size;
    }
  }

  /// Window-space Y of a dock tool's center (live, includes scroll), the
  /// equivalent of anchorOf(el) in the original.
  double? _dockAnchor(String id) {
    final c = widget.controller;
    final S = c.S;
    final visible = S.dock!.where((x) => !S.hidden.contains(x)).toList();
    final i = visible.indexOf(id);
    final vpTop = _viewportTop();
    if (vpTop.isNaN) return null;
    final scroll = c.toolScroll.hasClients ? c.toolScroll.offset : 0.0;
    if (i >= 0) {
      return vpTop + 26 + 54.0 * i - scroll;
    }
    if (id == 'settings') {
      final viewportH = (54.0 * visible.length - 2).clamp(
        0.0,
        Dock.maxToolsHeight(MediaQuery.sizeOf(context).height),
      );
      return vpTop + viewportH + 47;
    }
    return null;
  }

  void _onTick(Duration elapsed) {
    final c = widget.controller;
    final nowSec = elapsed.inMicroseconds / 1e6;
    var dt = nowSec - _lastSec;
    _lastSec = nowSec;
    if (dt < 0) dt = 0;
    if (dt > 1 / 30) dt = 1 / 30;
    // Hidden windows stop vsync. Use the springs' clamped animation clock.
    c.clockSec += dt;

    final S = c.S;
    final visible = S.dock!.where((x) => !S.hidden.contains(x)).toList();
    final items = [...visible, 'settings'];
    final n = items.length;
    final sinceOpen = c.clockSec - c.openedAt;
    final sinceClose = c.clockSec - c.closedAt;
    double clamp01(double x) => x.clamp(0.0, 1.0);

    // ----- tab: slides in, melts back; peeks when the cursor nears the edge
    final peek = c.mx < 0 ? 0.0 : math.pow(clamp01(1 - c.mx / 150), 2) * .22;
    c.slide.t = c.isOpen ? 1 : (sinceClose < .07 ? 1 : peek.toDouble());
    c.slide.step(dt);

    // geometry needed for magnification + pill
    final vpTop = _viewportTop();
    final viewportH = (54.0 * visible.length - 2).clamp(
      0.0,
      Dock.maxToolsHeight(MediaQuery.sizeOf(context).height),
    );

    // ----- icons: staggered in/out + hover magnification -----
    for (var i = 0; i < n; i++) {
      final sp = c.springsFor(items[i]).sp;
      sp.t = c.isOpen
          ? (sinceOpen > .04 + i * .03 ? 1 : 0)
          : (sinceClose > (n - 1 - i) * .012 ? 0 : sp.t);
      var m = 0.0;
      if (S.magnify && c.hoverY != null && !c.dragging && !vpTop.isNaN) {
        final double centerY;
        if (i < visible.length) {
          centerY =
              vpTop +
              26 +
              54.0 * i -
              (c.toolScroll.hasClients ? c.toolScroll.offset : 0);
        } else {
          centerY = vpTop + viewportH + 47;
        }
        final d = (centerY - c.hoverY!).abs();
        m = math.pow(math.max(0, 1 - d / 80), 1.6).toDouble();
      }
      c.springsFor(items[i]).mg.t = m;
    }
    for (final id in items) {
      final s = c.springsFor(id);
      s.sp.step(dt);
      s.mg.step(dt);
      s.pr.step(dt);
    }

    // ----- liquid pill that slides to the active tool -----
    final activeId = c.activeToolId;
    if (activeId != null && items.contains(activeId)) {
      final i = items.indexOf(activeId);
      final double target;
      if (i < visible.length) {
        target =
            48 + 54.0 * i - (c.toolScroll.hasClients ? c.toolScroll.offset : 0);
      } else {
        target = 22 + viewportH + 47;
      }
      if (c.pillS.v < .05) {
        c.pillY.v = target;
        c.pillY.vel = 0;
      }
      c.pillY.t = target;
      c.pillS.t = 1;
    } else {
      c.pillS.t = 0;
    }
    c.pillY.step(dt);
    c.pillS.step(dt);

    // ----- flyout pours out next to the clicked button -----
    c.grow.t = c.panel != null ? 1 : 0;
    c.grow.step(dt);
    if (c.panel != null && c.flyH > 0) {
      final h = MediaQuery.of(context).size.height;
      final half = math.min(c.flyH / 2, math.max(0, (h - 20) / 2));
      c.fy.t = c.anchorY.clamp(half + 10, math.max(half + 10, h - half - 10));
    }
    c.fy.step(dt);

    // Ticker callbacks precede layout. Reading transforms here can throw on
    // the first frame and permanently stop the ticker in release builds.
    _measureAfterLayout();
    c.frame.value++;
  }

  void _pointerMove(PointerEvent e) {
    final c = widget.controller;
    // drag handling first (candidates were registered by tool listeners)
    c.handleDragPointer(e);

    if (!c.isOpen) return;
    final tab = c.tabRect;
    if (tab != null) {
      final overTab =
          e.position.dx >= tab.left &&
          e.position.dx <= tab.right &&
          e.position.dy > tab.top &&
          e.position.dy < tab.bottom;
      c.hoverY = overTab ? e.position.dy : null;
    } else {
      c.hoverY = null;
    }
    if (c.inside(e.position)) {
      c.cancelClose();
      c.sticky = false;
    } else {
      c.maybeClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => LiquidScope(
            controller: c,
            palette: c.palette,
            dir: c.S.edge == 'left' ? -1 : 1,
            child: Focus(
              autofocus: c.panel != 'note',
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  c.close();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Listener(
                onPointerHover: _pointerMove,
                onPointerMove: _pointerMove,
                onPointerUp: (e) => c.handleDragPointer(e),
                onPointerCancel: (e) => c.handleDragPointer(e),
                child: MouseRegion(
                  onExit: (_) {
                    c.hoverY = null;
                    c.maybeClose();
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // the flyout is underneath the dock in z-order terms
                      Flyout(controller: c),
                      Align(
                        alignment: c.dir < 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Dock(controller: c),
                      ),
                      _DragGhost(controller: c),
                      _ToastOverlay(controller: c),
                      _DropHintOverlay(controller: c),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating clone that follows the cursor during widget drags.
class _DragGhost extends StatelessWidget {
  const _DragGhost({required this.controller});

  final PanelController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DragInfo?>(
      valueListenable: controller.dragInfo,
      builder: (context, drag, _) {
        if (drag == null || !drag.moved || drag.pointer == null) {
          return const SizedBox.shrink();
        }
        final p = LiquidScope.paletteOf(context);
        final info = ToolInfo.of(drag.id);
        return Positioned(
          left: drag.pointer!.dx,
          top: drag.pointer!.dy,
          child: Transform.translate(
            offset: const Offset(-22, -22),
            child: Transform.scale(
              scale: 1.06,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.liquid,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x73000000),
                      offset: Offset(0, 10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Center(
                  child: info.emoji != null
                      ? Text(
                          info.emoji!,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI Emoji',
                            fontSize: 19,
                          ),
                        )
                      : info.kind == ToolKind.app && info.app?.icon != null
                      ? AppIconImage(dataUri: info.app!.icon!)
                      : (info.svg != null
                            ? SvgIcon(info.svg!, size: 20, color: p.ink)
                            : const SizedBox.shrink()),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DropHintOverlay extends StatelessWidget {
  const _DropHintOverlay({required this.controller});
  final PanelController controller;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: controller.dropHintOn,
    builder: (context, visible, _) {
      final left = controller.S.edge == 'left';
      final p = controller.palette;
      return Positioned(
        left: left ? 90 : null,
        right: left ? null : 90,
        top: 20,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              key: const ValueKey('capture-drop-hint'),
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.liquid,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line),
              ),
              child: Text(
                AppLocalizations.of(context)!.dropFiles,
                style: TextStyle(color: p.ink),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The toast that pops in at the bottom of the panel.
class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({required this.controller});

  final PanelController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: controller.toastMsg,
      builder: (context, msg, _) {
        final text = msg?.split('\x00').first;
        final visible = text != null;
        final c = controller;
        final left = c.S.edge == 'left';
        return Positioned(
          left: left ? 100 : null,
          right: left ? null : 100,
          bottom: 20,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: visible ? 1 : 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 550),
                curve: kPop,
                offset: visible ? Offset.zero : const Offset(0, 1),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 550),
                  curve: kPop,
                  scale: visible ? 1 : .8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.palette.liquid,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.palette.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000),
                          offset: Offset(0, 10),
                          blurRadius: 30,
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                    child: Text(
                      text ?? '',
                      style: TextStyle(
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.fontFamily,
                        fontFamilyFallback: const ['Segoe UI'],
                        fontSize: 12,
                        color: c.palette.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
