import '../l10n/utility_strings.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/registry.dart';
import 'svg_icon.dart';
import 'widgets.dart';

double clamp01(double x) => x.clamp(0.0, 1.0);

/// The liquid tab: 78px wide, glued to the screen edge, with concave
/// "flap" curves above and below that let it melt into the edge.
/// All movement comes from the controller's springs, stepped once per
/// frame by the shell; this widget just reads them out.
class Dock extends StatelessWidget {
  const Dock({super.key, required this.controller});

  final PanelController controller;

  static const double tabWidth = 78;
  static const double toolSize = 44;
  static const double toolStep = 54; // 44 + 10 gap
  static double maxToolsHeight(double height) => math.max(0, height - 190);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.frame,
      builder: (context, _, __) {
        final S = controller.S;
        final visibleDock = S.dock!
            .where((id) => !S.hidden.contains(id))
            .toList();
        final n = visibleDock.length;
        final toolsContentH = 54.0 * n - 2; // 44*n + 10*(n-1) + 4 + 4
        final viewportH = toolsContentH.clamp(
          0.0,
          maxToolsHeight(MediaQuery.sizeOf(context).height),
        );
        final bodyH = 22 + viewportH + 25 + 44 + 22;

        // ---- tab transform (slide + squash), port of the frame() math ----
        final sl = controller.slide.v;
        final v = controller.slide.vel;
        final dir = controller.dir;
        final sx = 1 + (v.abs() * .05).clamp(0.0, .22);
        final sy = 1 - (v.abs() * .03).clamp(0.0, .12);
        final dx = (1 - clamp01(sl)) * 1.2 * tabWidth * dir;
        final r = 26 + (v.abs() * 6).clamp(0.0, 18.0);
        final f = (26 * clamp01(sl) + (v.abs() * 4).clamp(0.0, 14.0)).clamp(
          0.0,
          44.0,
        );

        return SizedBox(
          key: controller.tabBoxKey,
          width: tabWidth,
          height: bodyH,
          child: Transform(
            alignment: controller.dir < 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            transform: (Matrix4.identity()..translateByDouble(dx, 0, 0, 1))
              ..scaleByDouble(sx, sy, 1, 1),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TabShapePainter(
                      radius: r,
                      flap: f,
                      dir: dir,
                      color: controller.palette.liquid,
                      shadow: Theme.of(
                        context,
                      ).colorScheme.shadow.withValues(alpha: .14),
                    ),
                  ),
                ),
                _Pill(
                  controller: controller,
                  viewportH: viewportH,
                  bodyH: bodyH,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Column(
                    children: [
                      _ToolsViewport(
                        controller: controller,
                        visibleDock: visibleDock,
                        viewportH: viewportH,
                        bodyH: bodyH,
                      ),
                      Container(
                        width: 30,
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        color: controller.palette.line,
                      ),
                      _ToolSlot(
                        controller: controller,
                        id: 'settings',
                        index: n,
                        active: controller.activeToolId == 'settings',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Scrollable column of dock tools (+ drag placeholder).
class _ToolsViewport extends StatelessWidget {
  const _ToolsViewport({
    required this.controller,
    required this.visibleDock,
    required this.viewportH,
    required this.bodyH,
  });

  final PanelController controller;
  final List<String> visibleDock;
  final double viewportH;
  final double bodyH;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: controller.zoneKeys['dock'],
      constraints: BoxConstraints(maxHeight: viewportH),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          key: controller.toolsViewportKey,
          controller: controller.toolScroll,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ValueListenableBuilder<DragInfo?>(
            valueListenable: controller.dragInfo,
            builder: (context, drag, _) {
              final tools = <Widget>[];
              var idx = 0;
              for (final id in visibleDock) {
                if (drag?.zone == 'dock' && drag!.insertIdx == idx) {
                  tools.add(const _DockPlaceholder());
                }
                tools.add(
                  _ToolSlot(
                    key: controller.toolKey(id),
                    controller: controller,
                    id: id,
                    index: idx,
                    active: controller.activeToolId == id,
                  ),
                );
                idx++;
              }
              if (drag?.zone == 'dock' && drag!.insertIdx == idx) {
                tools.add(const _DockPlaceholder());
              }
              return Column(
                children: [
                  for (var i = 0; i < tools.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    tools[i],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DockPlaceholder extends StatelessWidget {
  const _DockPlaceholder();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: kPop,
      builder: (context, t, child) => Container(
        width: 34,
        height: 6,
        margin: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: LiquidScope.paletteOf(context).inv,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: Opacity(
            opacity: t,
            child: Container(
              width: 34,
              height: 6,
              decoration: BoxDecoration(
                color: LiquidScope.paletteOf(context).inv,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One dock tool: stagger/blur/press/magnify transforms are read from the
/// per-tool springs every frame; hover styling stays in state.
class _ToolSlot extends StatelessWidget {
  const _ToolSlot({
    super.key,
    required this.controller,
    required this.id,
    required this.index,
    required this.active,
  });

  final PanelController controller;
  final String id;
  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.frame,
      builder: (context, _, __) {
        final sp = controller.springsFor(id).sp;
        final mg = controller.springsFor(id).mg;
        final pr = controller.springsFor(id).pr;
        final p = sp.v.clamp(0.0, 1.0);
        final M = mg.v.clamp(0.0, 1.0);
        final P = pr.v.clamp(0.0, 1.0);
        final dir = controller.dir;

        final tx = ((1 - p) * 20 - M * 5) * dir;
        final scale = (.55 + .45 * p) * (1 + M * .16) * (1 - P * .14);

        Widget child = ToolVisual(
          controller: controller,
          id: id,
          active: active,
          dimmed:
              controller.dragInfo.value?.id == id &&
              controller.dragInfo.value!.moved,
        );

        child = Transform.translate(
          offset: Offset(tx, 0),
          child: Transform.scale(scale: scale, child: child),
        );
        if (p < .97) {
          final sigma = (1 - p) * 6;
          child = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          );
        }
        child = Opacity(opacity: p, child: child);
        return SizedBox(width: 44, height: 44, child: child);
      },
    );
  }
}

/// The pressable tool button (44x44, soft bg, hover radius change, dot).
class ToolVisual extends StatefulWidget {
  const ToolVisual({
    super.key,
    required this.controller,
    required this.id,
    required this.active,
    this.dimmed = false,
    this.tileStyle = false,
    this.smallIcon = false,
  });

  final PanelController controller;
  final String id;
  final bool active;
  final bool dimmed;

  /// Tiles (in the More panel) have the same look with column layout.
  final bool tileStyle;
  final bool smallIcon;

  @override
  State<ToolVisual> createState() => ToolVisualState();
}

class ToolVisualState extends State<ToolVisual> {
  bool _hover = false;
  bool _openedOnEnter = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    final info = ToolInfo.of(widget.id);
    final isApp = info.kind == ToolKind.app;
    final onDot = widget.id == 'awake' && widget.controller.awake;

    final iconColor = widget.active ? p.invInk : p.ink;

    Widget icon;
    final coreIcon = switch (widget.id) {
      'note' => Icons.edit_note_rounded,
      'timeline' => Icons.notes_rounded,
      'more' => Icons.grid_view_rounded,
      'settings' => Icons.settings_outlined,
      _ => null,
    };
    if (coreIcon != null) {
      icon = Icon(coreIcon, size: widget.smallIcon ? 18 : 23, color: iconColor);
    } else if (info.emoji != null) {
      icon = Text(
        info.emoji!,
        style: TextStyle(
          fontFamily: 'Segoe UI Emoji',
          fontFamilyFallback: const ['Segoe UI Emoji'],
          fontSize: widget.smallIcon ? 14 : 19,
        ),
      );
    } else if (isApp && info.app?.icon != null) {
      icon = AppIconImage(dataUri: info.app!.icon!);
    } else if (info.svg != null) {
      icon = SvgIcon(
        info.svg!,
        size: widget.smallIcon ? 17 : 20,
        color: iconColor,
      );
    } else {
      icon = const SizedBox.shrink();
    }

    if (widget.tileStyle) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: _enter,
        onExit: _exit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          onTapDown: _down,
          child: Listener(
            onPointerDown: _dragStart,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: kPop,
              transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
              decoration: BoxDecoration(
                color: widget.active ? p.inv : (_hover ? p.soft2 : p.soft),
                borderRadius: BorderRadius.circular(_hover ? 18 : 14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              child: Opacity(
                opacity: widget.dimmed ? .35 : 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 24, child: Center(child: icon)),
                    const SizedBox(height: 6),
                    Text(
                      utilityLabelForText(context, info.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.fontFamily,
                        fontFamilyFallback: const [
                          'Segoe UI',
                          'Segoe UI Emoji',
                        ],
                        fontSize: 11,
                        color: widget.active ? p.invInk : p.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _enter,
      onExit: _exit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        onTapDown: _down,
        child: Listener(
          onPointerDown: _dragStart,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.active
                  ? Colors.transparent
                  : (isApp
                        ? (_hover ? p.soft2 : Colors.transparent)
                        : (_hover ? p.soft2 : p.soft)),
              borderRadius: BorderRadius.circular(_hover ? 18 : 14),
            ),
            child: Opacity(
              opacity: widget.dimmed ? .35 : 1,
              child: Stack(
                children: [
                  Center(child: icon),
                  if (onDot)
                    Positioned(
                      right: 3,
                      top: 3,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                          border: Border.all(
                            width: 2,
                            color: controllerPalette(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color controllerPalette(BuildContext context) =>
      LiquidScope.paletteOf(context).liquid;

  void _enter(PointerEnterEvent e) {
    setState(() => _hover = true);
    // port of the tab mouseover: switch panel when sweeping across tools
    final c = widget.controller;
    if (c.panel == null || c.dragging || c.keepOpen) return;
    final info = ToolInfo.of(widget.id);
    final id = widget.id;
    if (info.kind == ToolKind.panel &&
        (id != c.panel || c.sub) &&
        !(id == 'more' && c.sub)) {
      c.anchorY = c.dockAnchorOf?.call(id) ?? c.anchorY;
      c.setPanel(id);
      _openedOnEnter = true;
    }
  }

  void _exit(PointerExitEvent e) {
    _openedOnEnter = false;
    setState(() => _hover = false);
  }

  void _down(TapDownDetails _) {
    final pr = widget.controller.springsFor(widget.id).pr;
    pr.v = 1;
    pr.vel = 0;
  }

  void _dragStart(PointerDownEvent e) {
    if (e.buttons == kPrimaryButton && widget.id != 'settings') {
      widget.controller.beginDragCandidate(widget.id, e.position);
    }
  }

  void _tap() {
    if (_openedOnEnter && widget.controller.panel == widget.id) {
      _openedOnEnter = false;
      return;
    }
    if (widget.tileStyle) {
      widget.controller.onTileTap(widget.id);
    } else {
      widget.controller.onToolTap(widget.id);
    }
  }
}

/// The liquid pill behind the active tool. Follows the active tool with a
/// spring, stretching like a drop while travelling.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.controller,
    required this.viewportH,
    required this.bodyH,
  });

  final PanelController controller;
  final double viewportH;
  final double bodyH;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.frame,
      builder: (context, _, __) {
        final py = controller.pillY.v;
        var ps = controller.pillS.v;
        if (ps < 0) ps = 0;
        if (ps < .001) return const SizedBox.shrink();
        final stretch = (controller.pillY.vel.abs() / 900).clamp(0.0, .45);
        final activeId = controller.activeToolId;
        final am = activeId != null
            ? 1 + controller.springsFor(activeId).mg.v * .16
            : 1.0;

        final sxP = ps * am * (1 - stretch * .35);
        final syP = ps * am * (1 + stretch);

        return Positioned(
          left: 17,
          top: -22,
          width: 44,
          height: 44,
          child: IgnorePointer(
            child: Transform.translate(
              offset: Offset(0, py),
              child: Transform.scale(
                scaleX: sxP,
                scaleY: syP,
                child: Container(
                  decoration: BoxDecoration(
                    color: controller.palette.inv,
                    borderRadius: BorderRadius.circular(22),
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

/// The tab silhouette: body with rounded left corners + concave quarter
/// circle flaps (size [flap]) at the edge side, drawn with a soft shadow —
/// exactly the shape produced by the CSS border-radius + radial-gradient
/// pseudo elements.
class _TabShapePainter extends CustomPainter {
  _TabShapePainter({
    required this.radius,
    required this.flap,
    required this.dir,
    required this.color,
    required this.shadow,
  });

  final double radius;
  final double flap;
  final double dir;
  final Color color;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _silhouette(size, radius, flap.clamp(0.0, 44.0));

    // shadow: blurred silhouette offset away from the screen edge
    // (CSS: -18px 0 40px -20px rgba(0,0,0,.35))
    final shadowDir = dir > 0 ? -4.0 : 4.0;
    canvas.save();
    canvas.translate(shadowDir, 0);
    if (dir < 0) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.restore();

    canvas.save();
    if (dir < 0) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  /// Outline of the tab for the right-edge case, built clockwise:
  /// rounded left corners, square edge-side corners, concave quarter-circle
  /// flaps above and below the edge side — the "liquid melt" shape.
  static Path _silhouette(Size size, double rr, double f) {
    final w = size.width;
    final h = size.height;
    final p = Path();
    // top-left rounded corner: (0, rr) -> (rr, 0)
    p.moveTo(0, rr);
    p.arcTo(
      Rect.fromCircle(center: Offset(rr, rr), radius: rr),
      math.pi,
      math.pi / 2,
      false,
    );
    // top edge to the flap tangent point
    p.lineTo(w - f, 0);
    // concave flap above the tab: (w - f, 0) -> (w, -f)
    if (f > 0) {
      p.arcTo(
        Rect.fromCircle(center: Offset(w - f, -f), radius: f),
        math.pi / 2,
        -math.pi / 2,
        false,
      );
    }
    // down the screen edge
    p.lineTo(w, h + f);
    // concave flap below the tab: (w, h + f) -> (w - f, h)
    if (f > 0) {
      p.arcTo(
        Rect.fromCircle(center: Offset(w - f, h + f), radius: f),
        0,
        -math.pi / 2,
        false,
      );
    }
    // bottom edge
    p.lineTo(rr, h);
    // bottom-left rounded corner: (rr, h) -> (0, h - rr)
    p.arcTo(
      Rect.fromCircle(center: Offset(rr, h - rr), radius: rr),
      math.pi / 2,
      math.pi / 2,
      false,
    );
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(_TabShapePainter old) =>
      old.radius != radius ||
      old.flap != flap ||
      old.color != color ||
      old.dir != dir ||
      old.shadow != shadow;
}

/// Decodes a data:image/png;base64 URI to an image widget (app icons).
class AppIconImage extends StatelessWidget {
  const AppIconImage({super.key, required this.dataUri});

  final String dataUri;
  static final Map<String, Uint8List> _cache = {};

  Uint8List? get bytes {
    final c = _cache[dataUri];
    if (c != null) return c;
    final comma = dataUri.indexOf(',');
    if (!dataUri.startsWith('data:') || comma < 0) return null;
    try {
      final b = _base64Decode(dataUri.substring(comma + 1));
      _cache[dataUri] = b;
      return b;
    } catch (_) {
      return null;
    }
  }

  static Uint8List _base64Decode(String s) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final clean = s.replaceAll(RegExp(r'\s'), '');
    final out = BytesBuilder();
    var bitBuf = 0, bits = 0;
    for (final ch in clean.codeUnits) {
      if (ch == 0x3D) break; // '='
      final v = chars.indexOf(String.fromCharCode(ch));
      if (v < 0) continue;
      bitBuf = (bitBuf << 6) | v;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        out.addByte((bitBuf >> bits) & 0xFF);
      }
    }
    return out.toBytes();
  }

  @override
  Widget build(BuildContext context) {
    final b = bytes;
    if (b == null) {
      return const Text(
        '🚀',
        style: TextStyle(fontFamily: 'Segoe UI Emoji', fontSize: 19),
      );
    }
    return Image.memory(
      b,
      width: 26,
      height: 26,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
