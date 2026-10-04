import 'package:flutter/material.dart';

/// The resolved set of "CSS variables" the original UI is built from.
/// Every color the panel paints comes from here, so themes work the same.
class LiquidPalette {
  const LiquidPalette({
    required this.liquid,
    required this.ink,
    required this.inv,
    required this.invInk,
    required this.soft,
    required this.soft2,
    required this.muted,
    required this.line,
    required this.isLight,
  });

  /// --liquid: panel background
  final Color liquid;

  /// --ink: normal text / icon color
  final Color ink;

  /// --inv: the pill / primary accent
  final Color inv;

  /// --inv-ink: text on top of the pill
  final Color invInk;

  /// --soft: soft surfaces (buttons, items)
  final Color soft;

  /// --soft2: hovered soft surfaces
  final Color soft2;

  /// --muted: secondary text
  final Color muted;

  /// --line: hairlines
  final Color line;

  final bool isLight;

  Color rgba(double alpha) => isLight
      ? Color.fromRGBO(0, 0, 0, alpha)
      : Color.fromRGBO(255, 255, 255, alpha);
}

LiquidPalette paletteFromTheme(ThemeData theme) {
  final c = theme.colorScheme;
  return LiquidPalette(
    liquid: theme.cardTheme.color ?? c.surface,
    ink: c.onSurface,
    inv: c.primary,
    invInk: c.onPrimary,
    soft: c.surfaceContainerHigh,
    soft2: c.surfaceContainerHighest,
    muted: c.onSurfaceVariant,
    line: c.onSurface.withValues(alpha: .12),
    isLight: theme.brightness == Brightness.light,
  );
}
