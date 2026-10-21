// WP2.2 review harness — renders the full screen matrix that backs the
// design audit (design/UI_AUDIT.md). Every shot lands in
// test/review_goldens/<name>.png; copy the folder to design/before (rendered
// at the baseline commit) or design/after (rendered after the work).
//
//   flutter test --tags review
//
// The same harness compiles against the baseline snapshot, so the before and
// after matrices use identical file names and identical viewports.
@Tags(['review'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/review_fixture.dart';
import 'support/text_scale_cases.dart';
import 'support/compact_review_cases.dart';

const _matrix = <ReviewShot>[
  ReviewShot(
    'intelligence_configured_1200_light_en',
    mode: 'window',
    size: Size(1200, 1100),
    target: 'aiSettings',
  ),
  ReviewShot(
    'intelligence_configured_1200_dark_fa',
    mode: 'window',
    size: Size(1200, 1100),
    target: 'aiSettings',
    theme: 'dark',
    locale: 'fa',
  ),
  ReviewShot(
    'provider_1200_light_en',
    mode: 'window',
    size: Size(1200, 1000),
    target: 'providerSettings',
  ),
  ReviewShot(
    'provider_1200_dark_fa',
    mode: 'window',
    size: Size(1200, 1000),
    theme: 'dark',
    locale: 'fa',
    target: 'providerSettings',
  ),
  ReviewShot(
    'appearance_700_light_fa_scale2',
    mode: 'window',
    size: Size(700, 1100),
    locale: 'fa',
    textScale: 2,
    target: 'appearance',
  ),
  ReviewShot(
    'intelligence_1200_light_en',
    mode: 'window',
    target: 'assistant',
    size: Size(1200, 900),
  ),
  ReviewShot(
    'intelligence_1200_dark_fa',
    mode: 'window',
    target: 'assistant',
    theme: 'dark',
    locale: 'fa',
    size: Size(1200, 900),
  ),
  ReviewShot(
    'intelligence_settings_1200_light_en',
    mode: 'window',
    target: 'aiSettings',
    size: Size(1200, 1000),
  ),
  ReviewShot(
    'intelligence_settings_700_dark_fa_scale2',
    mode: 'window',
    target: 'aiSettings',
    theme: 'dark',
    locale: 'fa',
    textScale: 2,
    size: Size(700, 1000),
  ),
  ReviewShot(
    'chromatic_gallery_1200_light_en_scale2',
    mode: 'window',
    target: 'timeline',
    notes: 30,
    textScale: 2,
    size: Size(1200, 1000),
  ),
  ReviewShot(
    'settings_tools_panel_dark_fa',
    locale: 'fa',
    theme: 'dark',
    target: 'toolsSettings',
  ),
  ReviewShot('settings_tools_panel_light_en', target: 'toolsSettings'),
  ReviewShot(
    'settings_tools_window_dark_fa',
    locale: 'fa',
    theme: 'dark',
    target: 'toolsSettings',
    mode: 'window',
    size: Size(1200, 800),
  ),
  ReviewShot(
    'settings_tools_window_fa_scale2',
    locale: 'fa',
    theme: 'dark',
    target: 'toolsSettings',
    mode: 'window',
    size: Size(700, 900),
    textScale: 2,
  ),
  ReviewShot(
    'product_clipboard_dark_fa',
    locale: 'fa',
    theme: 'dark',
    target: 'clip',
  ),
  ReviewShot('product_clipboard_light_en', target: 'clip'),
  // Desktop redesign: full-size writing, RTL, large type and secondary flows.
  ReviewShot(
    'redesign_window_capture_1200_light_en',
    mode: 'window',
    size: Size(1200, 800),
  ),
  ReviewShot(
    'redesign_window_capture_1600_dark_en',
    mode: 'window',
    size: Size(1600, 1000),
    theme: 'dark',
  ),
  ReviewShot(
    'redesign_window_capture_700_light_fa_scale2',
    mode: 'window',
    size: Size(700, 900),
    locale: 'fa',
    textScale: 2,
  ),
  ReviewShot(
    'redesign_window_tools_1200_dark_fa',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    theme: 'dark',
    target: 'more',
  ),
  ReviewShot(
    'redesign_window_tools_700_light_fa_scale2',
    mode: 'window',
    size: Size(700, 900),
    locale: 'fa',
    textScale: 2,
    target: 'more',
  ),
  ReviewShot(
    'redesign_window_settings_1200_light_en_appearance',
    mode: 'window',
    size: Size(1200, 800),
    target: 'appearance',
  ),
  ReviewShot(
    'redesign_window_settings_1200_dark_fa_backup',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    theme: 'dark',
    target: 'backup',
  ),
  ReviewShot(
    'redesign_window_settings_700_dark_fa_scale2',
    mode: 'window',
    size: Size(700, 900),
    locale: 'fa',
    theme: 'dark',
    textScale: 2,
    target: 'settings',
  ),
  ReviewShot(
    'redesign_window_palette_1200_dark_fa',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    theme: 'dark',
    target: 'palette',
  ),
  ReviewShot(
    'redesign_capture_panel_left_dark_fa_scale2',
    locale: 'fa',
    theme: 'dark',
    edge: 'left',
    textScale: 2,
  ),
  // Panel, right edge, both languages, both themes — the primary audit grid.
  ReviewShot('capture_panel_right_light_en'),
  ReviewShot('capture_panel_right_dark_en', theme: 'dark'),
  ReviewShot('capture_panel_right_light_fa', locale: 'fa'),
  ReviewShot('capture_panel_right_dark_fa', locale: 'fa', theme: 'dark'),
  ReviewShot('timeline_panel_right_light_en', target: 'timeline'),
  ReviewShot(
    'timeline_panel_right_dark_fa',
    target: 'timeline',
    locale: 'fa',
    theme: 'dark',
  ),
  ReviewShot('reader_panel_right_light_en', target: 'reader'),
  ReviewShot(
    'reader_panel_right_dark_fa',
    target: 'reader',
    locale: 'fa',
    theme: 'dark',
  ),
  ReviewShot('settings_panel_right_light_en', target: 'settings'),
  ReviewShot(
    'settings_panel_right_dark_fa',
    target: 'settings',
    locale: 'fa',
    theme: 'dark',
  ),
  ReviewShot('emoji_panel_right_dark_en', target: 'emoji', theme: 'dark'),
  ReviewShot('more_panel_right_light_fa', target: 'more', locale: 'fa'),
  ReviewShot('color_panel_right_dark_en', target: 'color', theme: 'dark'),
  // Left edge and large text: the two regression-prone frame conditions.
  ReviewShot('capture_panel_left_light_en', edge: 'left'),
  ReviewShot('capture_panel_right_light_en_scale15', textScale: 1.5),
  // Desktop window at the three widths called out by the task.
  ReviewShot(
    'window_capture_1200_dark_fa',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    theme: 'dark',
  ),
  ReviewShot(
    'window_library_700_light_en',
    mode: 'window',
    size: Size(700, 900),
    target: 'timeline',
  ),
  ReviewShot(
    'window_library_1200_dark_en',
    mode: 'window',
    size: Size(1200, 800),
    theme: 'dark',
    target: 'timeline',
  ),
  ReviewShot(
    'window_library_1600_light_fa',
    mode: 'window',
    size: Size(1600, 1000),
    locale: 'fa',
    target: 'timeline',
  ),
  ReviewShot(
    'window_reader_1200_dark_en',
    mode: 'window',
    size: Size(1200, 800),
    theme: 'dark',
    target: 'reader',
  ),
  ReviewShot(
    'window_settings_700_light_fa',
    mode: 'window',
    size: Size(700, 900),
    locale: 'fa',
    target: 'settings',
  ),
  ReviewShot(
    'window_tools_1200_light_en',
    mode: 'window',
    size: Size(1200, 800),
    target: 'more',
  ),
  ReviewShot(
    'window_library500_1200_light_en',
    mode: 'window',
    size: Size(1200, 800),
    target: 'timeline',
    notes: 500,
  ),
  ReviewShot(
    'window_library_1200_light_fa_scale15',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    target: 'timeline',
    textScale: 1.5,
  ),
  // At least four panel presets, dark, English.
  ReviewShot('preset_classic_panel_dark_en', theme: 'dark'),
  ReviewShot('preset_autumn_panel_dark_en', theme: 'dark', preset: 'autumn'),
  ReviewShot(
    'preset_midnight_panel_dark_en',
    theme: 'dark',
    preset: 'midnight',
  ),
  ReviewShot('preset_ocean_panel_dark_en', theme: 'dark', preset: 'ocean'),
];

void main() {
  for (final spec in [..._matrix, ...textScaleReviewShots, ...compactReviewShots]) {
    testWidgets('review: ${spec.name}', (t) async {
      final store = (await t.runAsync(
        () => openReviewStore(spec.name, count: spec.notes),
      ))!;
      final c = await bootReview(t, spec, store);
      await goReview(t, c, spec);
      // Audit defect 14: with the default debug flag tests draw shadows as
      // solid slabs. The review matrix must show the shadows that ship. The
      // flag is restored inside the body so the framework's debug invariant
      // (checked before tearDown) still holds.
      debugDisableShadows = false;
      try {
        await expectLater(
          find.byKey(const ValueKey('review-surface')),
          matchesGoldenFile(
            '${const String.fromEnvironment('NEX_REVIEW_DIRECTORY', defaultValue: 'review_goldens')}/${spec.name}.png',
          ),
        );
      } finally {
        debugDisableShadows = true;
      }
      await t.pumpWidget(const SizedBox());
      c.dispose();
      await t.runAsync(() async {
        await store.features.close();
        await store.root.delete(recursive: true);
      });
      expect(t.takeException(), isNull);
    });
  }
}
