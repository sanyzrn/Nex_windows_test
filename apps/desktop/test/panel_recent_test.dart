import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/nex/note_tile.dart';

import 'support/review_fixture.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the edge panel editor lists the last notes and opens one', (
    t,
  ) async {
    const shot = ReviewShot('panel_recent', target: 'note', notes: 12);
    final store = (await t.runAsync(
      () => openReviewStore(shot.name, count: shot.notes),
    ))!;
    final c = await bootReview(t, shot, store);
    await goReview(t, c, shot);
    await _settle(t);

    expect(find.text('Recently updated'), findsOneWidget);
    expect(find.byType(NexNoteTile), findsWidgets);
    // The strip scrolls sideways, so no more than six are ever built.
    expect(find.byType(NexNoteTile).evaluate().length, lessThanOrEqualTo(6));

    await t.tap(find.byType(NexNoteTile).first);
    await _settle(t);
    expect(c.panel, 'timeline');
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox());
    c.dispose();
    await closeReviewStore(t, store);
  });
}
