import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

Note _checklistNote(int items) {
  final now = DateTime.utc(2026, 7, 28);
  return Note(
    id: 'n1',
    type: NoteType.checklist,
    content: [
      for (var i = 1; i <= items; i++) '- [ ] item $i',
    ].join('\n'),
    createdAt: now,
    updatedAt: now,
    deviceId: 'test',
    rev: 1,
    syncState: SyncState.pending,
  );
}

Widget _host(Widget Function(BuildContext) build) => MaterialApp(
  theme: nexLightTheme(),
  home: Scaffold(body: SizedBox(width: 400, child: Builder(builder: build))),
);

// A subtree override rather than a MaterialApp locale: the test bundle has
// no Material delegate for fa, and only `Localizations.localeOf` matters
// for the digit conversion under test.
Widget Function(BuildContext) _fa(Widget child) => (context) =>
    Localizations.override(locale: const Locale('fa'), context: context, child: child);

void main() {
  testWidgets('the checklist overflow count pins LTR and localises digits', (
    tester,
  ) async {
    // Standard density shows two of the seven; five stay behind the count.
    await tester.pumpWidget(_host((_) => NoteCard(note: _checklistNote(7))));
    await tester.pumpAndSettle();

    final count = tester.widget<Text>(find.text('+5'));
    expect(count.textDirection, TextDirection.ltr);

    await tester.pumpWidget(
      _host(_fa(NoteCard(note: _checklistNote(7)))),
    );
    await tester.pumpAndSettle();

    // Persian digits, and still pinned LTR: in an RTL paragraph the
    // neutral '+' drifts to the other side of the number and the overflow
    // reads "۵+".
    final faCount = tester.widget<Text>(find.text('+۵'));
    expect(faCount.textDirection, TextDirection.ltr);
  });

  testWidgets('the tag overflow count localises the same way', (tester) async {
    final now = DateTime.utc(2026, 7, 28);
    Note tagged(int n) => Note(
      id: 'n2',
      type: NoteType.text,
      content: 'body',
      createdAt: now,
      updatedAt: now,
      deviceId: 'test',
      rev: 1,
      syncState: SyncState.pending,
      tags: [
        for (var i = 0; i < n; i++)
          Tag(createdAt: now, id: 't$i', name: 'tag$i', color: '#8ECFB8'),
      ],
    );

    // The tag row belongs to the board body (the list card carries tags in
    // its footnote strip), so the card renders as a board tile.
    await tester.pumpWidget(
      _host((_) => NoteCard(note: tagged(4), board: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('+2'), findsOneWidget);

    await tester.pumpWidget(
      _host(_fa(NoteCard(note: tagged(4), board: true))),
    );
    await tester.pumpAndSettle();
    expect(find.text('+۲'), findsOneWidget);
  });
}
