import 'package:nex_ui/nex_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'desktop text clears 4.5 contrast in every light and dark palette',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = PanelController();
      await c.bootstrap(preset: Settings(), useNative: false);
      try {
        for (final preset in nexThemePresets) {
          for (final mode in ['light', 'dark']) {
            c.S.preset = preset.id;
            c.S.theme = mode;
            final colors = c.appTheme.colorScheme;
            for (final background in [
              colors.surface,
              colors.surfaceContainerLow,
            ]) {
              for (final foreground in [
                colors.onSurface,
                colors.onSurfaceVariant,
              ]) {
                expect(
                  nexContrast(foreground, background),
                  greaterThanOrEqualTo(4.5),
                  reason: '${preset.id} $mode',
                );
              }
            }
            expect(
              nexContrast(colors.onPrimary, colors.primary),
              greaterThanOrEqualTo(4.5),
              reason: '${preset.id} $mode primary',
            );
          }
        }
      } finally {
        c.dispose();
      }
    },
  );
  test('theme hot path reuses theme and palette allocations', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = PanelController();
    await controller.bootstrap(preset: Settings(), useNative: false);
    try {
      // Microbenchmark of getters, not an end-to-end frame measurement.
      const rebuilds = 1000;
      const cachedReads = 100000;
      final watch = Stopwatch()..start();
      for (var i = 0; i < rebuilds; i++) {
        controller.S.theme = i.isEven ? 'light' : 'midnight';
        controller.palette;
      }
      watch.stop();
      final rebuildUs = watch.elapsedMicroseconds / rebuilds;
      final theme = controller.appTheme;
      final palette = controller.palette;
      watch
        ..reset()
        ..start();
      var identicalReads = 0;
      for (var i = 0; i < cachedReads; i++) {
        if (identical(controller.appTheme, theme) &&
            identical(controller.palette, palette)) {
          identicalReads++;
        }
      }
      watch.stop();
      final cachedUs = watch.elapsedMicroseconds / cachedReads;
      expect(identicalReads, cachedReads);
      // ignore: avoid_print
      print(
        'Theme getter microbenchmark: forced rebuild ${rebuildUs.toStringAsFixed(2)} us/op ($rebuilds); cached theme+palette ${cachedUs.toStringAsFixed(2)} us/op ($cachedReads).',
      );
    } finally {
      controller.dispose();
    }
  });
}
