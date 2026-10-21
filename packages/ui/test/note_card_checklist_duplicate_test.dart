import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

/// The checklist preview used to resolve each visible line's toggle by value
/// equality (`items.indexOf(item)`). ChecklistItem has value equality, so two
/// identical lines — same words, same state — collapsed into one index: the
/// second line's checkbox toggled the first line's item and no number of
/// clicks could ever tick the second one.
void main() {
  testWidgets('two identical checklist lines toggle independently', (
    tester,
  ) async {
    final toggled = <int>[];
    final now = DateTime.utc(2026, 10, 15);
    final note = Note(
      id: 'dupes',
      type: NoteType.checklist,
      content: '- [ ] milk\n- [ ] milk',
      createdAt: now,
      updatedAt: now,
      deviceId: 'test',
      rev: 1,
      syncState: SyncState.pending,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: NoteCard(note: note, onChecklistToggle: toggled.add),
          ),
        ),
      ),
    );

    final boxes = find.byIcon(Icons.check_box_outline_blank);
    expect(boxes, findsNWidgets(2));

    // Tapping the second identical line must report the second index, not
    // fall back to the first because both lines compare equal.
    await tester.tap(boxes.at(1));
    expect(toggled, [1]);

    await tester.tap(boxes.at(0));
    expect(toggled, [1, 0]);
  });

  testWidgets('the +N overflow count rides the last visible line by position', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 15);
    final note = Note(
      id: 'long',
      type: NoteType.checklist,
      content: [
        for (var i = 0; i < 5; i++) '- [ ] item $i',
        // A duplicate of the last visible line: equality used to let an
        // earlier twin steal the trailing count.
        '- [ ] item 1',
      ].join('\n'),
      createdAt: now,
      updatedAt: now,
      deviceId: 'test',
      rev: 1,
      syncState: SyncState.pending,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, child: NoteCard(note: note)),
        ),
      ),
    );

    // Standard density shows two lines; six items leaves four behind, and the
    // count appears exactly once — on the row that is last on screen.
    expect(find.textContaining('+4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
