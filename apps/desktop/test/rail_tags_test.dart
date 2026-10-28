import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart' show NoteType;
import 'package:nex_desktop/nex/features_state.dart';

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
  testWidgets('sidebar tags show counts and filter the Library', (t) async {
    const shot = ReviewShot(
      'rail_tags',
      mode: 'window',
      size: Size(1200, 800),
      target: 'capture',
      notes: 12,
    );
    final store = (await t.runAsync(
      () => openReviewStore(shot.name, count: shot.notes),
    ))!;
    final c = await bootReview(t, shot, store);
    await _settle(t);

    final rail = find.byKey(const ValueKey('workspace-sidebar'));
    final work = find.descendant(of: rail, matching: find.text('Work'));
    expect(work, findsOneWidget);
    // Twelve notes, four tags, three notes each.
    expect(find.descendant(of: rail, matching: find.text('3')), findsWidgets);

    await t.tap(work);
    await _settle(t);
    expect(c.windowSection.value, 'library');
    final features = NexScope.of(t.element(rail));
    expect(features.libraryTag, isNotNull);

    // Choosing the same tag again clears the filter.
    await t.tap(work);
    await _settle(t);
    expect(features.libraryTag, isNull);
    // Types: the fixture holds text, checklist and link notes.
    final checklist = find.byKey(const ValueKey('rail-type-checklist'));
    expect(checklist, findsOneWidget);
    await t.tap(checklist);
    await _settle(t);
    expect(features.libraryType, NoteType.checklist);
    await t.tap(checklist);
    await _settle(t);
    expect(features.libraryType, isNull);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox());
    c.dispose();
    await closeReviewStore(t, store);
  });
}
