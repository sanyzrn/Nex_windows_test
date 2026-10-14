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

part 'dock_tools.dart';
part 'dock_pill.dart';

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
                Positioned(
                  left: 0,
                  right: 0,
                  top: 22,
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
