@Tags(['review'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/ui/desktop_dropdown.dart';
import 'support/review_fixture.dart';

void main() {
  for (final locale in ['en', 'fa']) {
    for (final target in ['monitor', 'locations']) {
      final name = 'controls_030_${target}_$locale';
      testWidgets(name, (t) async {
        final spec = ReviewShot(
          name,
          locale: locale,
          theme: locale == 'fa' ? 'dark' : 'light',
          size: const Size(480, 760),
          textScale: locale == 'fa' ? 2 : 1,
          target: target == 'monitor' ? 'displaySettings' : 'timeline',
        );
        final store = (await t.runAsync(
          () => openReviewStore(name, count: 8),
        ))!;
        final c = await bootReview(t, spec, store);
        try {
          c.screens = [
            {
              'name': r'\\.\DISPLAY1',
              'left': 0,
              'top': 0,
              'right': 1920,
              'bottom': 1080,
            },
            {
              'name': r'\\.\DISPLAY2',
              'left': 1920,
              'top': 0,
              'right': 3840,
              'bottom': 1080,
            },
          ];
          c.refresh();
          await goReview(t, c, spec);
          final entry = find.byKey(
            ValueKey(
              target == 'monitor' ? 'monitor-selection' : 'library-locations',
            ),
          );
          await t.ensureVisible(entry);
          for (var frame = 0; frame < 45; frame++) {
            await t.pump(const Duration(milliseconds: 16));
          }
          await t.tap(entry);
          for (var i = 0; i < 4; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 75)),
            );
            await t.pump();
          }
          for (var frame = 0; frame < 45; frame++) {
            await t.pump(const Duration(milliseconds: 16));
          }
          expect(t.takeException(), isNull);
          if (target == 'monitor') {
            expect(find.byType(DesktopDropdown<int>), findsOneWidget);
          }
          await expectLater(
            find.byKey(const ValueKey('review-surface')),
            matchesGoldenFile(
              '${const String.fromEnvironment('NEX_REVIEW_DIRECTORY', defaultValue: 'review_goldens')}/$name.png',
            ),
          );
        } finally {
          await t.pumpWidget(const SizedBox());
          c.dispose();
          await closeReviewStore(t, store);
        }
      });
    }
  }
}
