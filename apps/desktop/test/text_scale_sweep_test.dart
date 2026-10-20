import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/review_fixture.dart';
import 'support/text_scale_cases.dart';

void main() {
  for (final shot in textScaleShots) {
    final name = shot.name;
    final size = shot.size;
    final scale = shot.textScale;
    final locale = shot.locale;
    final theme = shot.theme;
    testWidgets('layout sweep: $name', (t) async {
      final store = (await t.runAsync(
        () => openReviewStore(name, count: shot.notes),
      ))!;
      final errors = <String>[];
      final previousError = FlutterError.onError!;
      FlutterError.onError = (details) {
        errors.add(details.toString());
        previousError(details);
      };
      final controller = await bootReview(t, shot, store);
      try {
        await goReview(t, controller, shot);
        const evidence = String.fromEnvironment('NEX_SWEEP_EVIDENCE');
        if (evidence.isNotEmpty &&
            scale == 2 &&
            ((size == const Size(380, 520) &&
                    locale == 'fa' &&
                    theme == 'dark') ||
                (size == const Size(1200, 800) &&
                    locale == 'en' &&
                    theme == 'light'))) {
          final surface = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('review-surface')),
          );
          await t.runAsync(() async {
            final image = await surface.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('$evidence/$name.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
        expect(
          t.takeException(),
          isNull,
          reason: '$name\n${errors.join('\n')}',
        );
      } finally {
        FlutterError.onError = previousError;
        await t.pumpWidget(const SizedBox());
        controller.dispose();
        await t.runAsync(() async {
          await store.features.close();
          await store.root.delete(recursive: true);
        });
      }
    });
  }
}
