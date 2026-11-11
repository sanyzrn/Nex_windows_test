import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_ui/nex_ui.dart';

/// The preset surface contract, stated as relationships rather than hexes.
///
/// `nexApplyThemePreset` forces each palette's page onto `ColorScheme.surface`
/// while the container tones used to come from whatever `fromSeed` guessed —
/// and a seed knows nothing about the forced page. On Circuit (dark) the card
/// landed at the same luma as the page (1.00:1, an invisible fill); on
/// Saffron (light) the card came out *darker* than the page, inverting the
/// layering. These assertions pin the fix: every palette's card sits a
/// visible step above its page, in both modes.
void main() {
  // The project's own presence floor — nex_tokens.dart: "1.08 of presence".
  const presenceFloor = 1.08;

  for (final brightness in Brightness.values) {
    for (final preset in nexThemePresets) {
      // The app builds the classic look with nexLightTheme/nexDarkTheme
      // alone — nexApplyThemePreset returns its base untouched for classic,
      // and a bare ThemeData() is nobody's theme. Every other palette goes
      // through the preset pipeline exactly as the app drives it.
      final theme = preset.id == 'classic'
          ? brightness == Brightness.light
                ? nexLightTheme()
                : nexDarkTheme()
          : nexApplyThemePreset(
              ThemeData(brightness: brightness),
              preset.id,
              null,
            );
      final scheme = theme.colorScheme;

      group('${preset.id} ${brightness.name}', () {
        test('the card fill is a visible step above the page', () {
          expect(
            nexContrastRatio(scheme.surfaceContainerLow, scheme.surface),
            greaterThanOrEqualTo(presenceFloor),
            reason:
                '${preset.id} (${brightness.name}): card '
                '${scheme.surfaceContainerLow} vs page ${scheme.surface}',
          );
        });

        test('container tones follow the Material tonal direction', () {
          // M3 ramps descend in light (a higher container rank is a deeper
          // fill) and ascend in dark. Equality is allowed — the classic
          // theme keeps container/high/highest on one tone — but the
          // direction must never reverse.
          double luma(Color c) {
            final r = c.r, g = c.g, b = c.b;
            return 0.2126 * r + 0.7152 * g + 0.0722 * b;
          }

          final steps = [
            scheme.surfaceContainerLowest,
            scheme.surfaceContainerLow,
            scheme.surfaceContainer,
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerHighest,
          ];
          for (var i = 0; i < steps.length - 1; i++) {
            final a = luma(steps[i]), b = luma(steps[i + 1]);
            expect(
              brightness == Brightness.dark ? b >= a : b <= a,
              isTrue,
              reason: '${preset.id} (${brightness.name}): container step $i '
                  'reverses the tonal direction — ${steps[i]} then '
                  '${steps[i + 1]}',
            );
          }
        });
      });
    }
  }
}
