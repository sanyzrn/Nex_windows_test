import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/review_fixture.dart';
import 'support/compact_review_cases.dart';

void main() {
  for (final shot in compactReviewShots) {
    testWidgets('compact layout: ${shot.name}', (t) async {
      final store = (await t.runAsync(() => openReviewStore(shot.name, count: shot.notes)))!;
      final controller = await bootReview(t, shot, store);
      try {
        await goReview(t, controller, shot);
        expect(t.takeException(), isNull);
        const evidence = String.fromEnvironment('NEX_COMPACT_EVIDENCE');
        if (evidence.isNotEmpty) {
          final surface = t.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('review-surface')));
          await t.runAsync(() async {
            final image = await surface.toImage();
            try {
              final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
              final file = File('$evidence/${shot.name}.png');
              await file.parent.create(recursive: true); await file.writeAsBytes(bytes!.buffer.asUint8List());
            } finally { image.dispose(); }
          });
        }
      } finally {
        await t.pumpWidget(const SizedBox()); controller.dispose();
        await t.runAsync(() async { await store.features.close(); await store.root.delete(recursive: true); });
      }
    });
  }
}
