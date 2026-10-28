import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';

/// The desktop window's buttons: the shared theme draws capsules 44 px tall,
/// sized for a thumb. Every card in the window has 12–16 px corners, so its
/// buttons do too, and a pointer needs 34 px, not 44.
ThemeData nexDesktopTheme(ThemeData base) {
  final shape = WidgetStatePropertyAll<OutlinedBorder>(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(NexRadius.md)),
  );
  const minimum = WidgetStatePropertyAll<Size>(Size(40, 34));
  const padding = WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: 14),
  );
  ButtonStyle? tuned(ButtonStyle? style) => (style ?? const ButtonStyle())
      .copyWith(shape: shape, minimumSize: minimum, padding: padding);
  return base.copyWith(
    // A text field is as tall as the buttons beside it. Its icons keep the
    // 48 px target by default, which is what made every field 48 tall.
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 34),
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 34),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: tuned(base.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: tuned(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: tuned(base.textButtonTheme.style),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: (base.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: const WidgetStatePropertyAll<Size>(Size.square(34)),
        shape: shape,
      ),
    ),
  );
}
