import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';

import '../core/controller.dart';
import '../core/theme_defs.dart';

part 'widgets_chips.dart';
part 'widgets_forms.dart';
part 'widgets_inputs.dart';
part 'widgets_rows.dart';
part 'widgets_rgba.dart';

/// CSS curve ports.
const Curve kPop = Cubic(.34, 1.56, .64, 1);
const Curve kSpring = Cubic(.22, 1.28, .36, 1);
const Curve kRise = Cubic(.2, .8, .2, 1);

/// Provides the palette, direction and controller down the tree so every
/// widget can match the original CSS without plumbing parameters.
class LiquidScope extends InheritedNotifier<PanelController> {
  const LiquidScope({
    super.key,
    required PanelController controller,
    required this.palette,
    required this.dir,
    required super.child,
  }) : super(notifier: controller);

  final LiquidPalette palette;
  final int dir;

  static (LiquidPalette, PanelController, int) of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<LiquidScope>()!;
    return (s.palette, s.notifier!, s.dir);
  }

  static LiquidPalette paletteOf(BuildContext context) => of(context).$1;
  static PanelController panelOf(BuildContext context) => of(context).$2;

  /// Null when no shell is above (tests, embedders). Callers fall back to
  /// defaults instead of requiring the full liquid scope.
  static PanelController? maybePanelOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidScope>()?.notifier;
  static int dirOf(BuildContext context) => of(context).$3;
}

/// Base text styles, ported from the CSS body / h4 / small rules.
TextStyle _body(BuildContext context, {double size = 13, Color? color}) {
  final p = LiquidScope.paletteOf(context);
  return TextStyle(
    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    fontFamilyFallback: const ['Segoe UI', 'Segoe UI Emoji'],
    fontSize: size,
    color: color ?? p.ink,
    height: 1.25,
  );
}

/// `.field` — borderless rounded input.
