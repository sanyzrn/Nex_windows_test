import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';

/// Regression tests for the reader's checklist rows.
///
/// `CheckboxListTile` defaults to `ListTileControlAffinity.platform`, which
/// parks the box in the *trailing* slot on every platform — in the Persian
/// reader that put the box at the visual left edge, away from the text it
/// belongs to, while every other checklist in the app (card previews, the
/// intelligence settings) draws it leading. And the row's `Text` took the
/// ambient RTL base, so a mixed-language item scrambled its neutrals.
void main() {
  testWidgets('reader checklist rows lead with their box and own their '
      'direction', (t) async {
    // The capture command adds its own `- [ ]` prefixes for a checklist.
    const content = 'خرید شیر\nBuy milk @ 5pm';
    late Directory root;
    late NexFeatures features;
    late Note note;
    await t.runAsync(() async {
      root = await Directory.systemTemp.createTemp('nex-checklist-rows-');
      features = NexFeatures(await DesktopStore.open(root.path, 'rows'));
      note = await features.store.call<Note>('capture', {
        'text': content,
        'type': 'checklist',
      });
    });
    Widget host(Widget child) => MaterialApp(
      locale: const Locale('fa'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NexScope(features: features, child: Scaffold(body: child)),
    );
    await t.pumpWidget(host(NexNoteDetail(note: note, onClose: () {})));
    await t.pumpAndSettle();

    final tiles = t
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(tiles, hasLength(2));
    for (final tile in tiles) {
      expect(
        tile.controlAffinity,
        ListTileControlAffinity.leading,
        reason: 'the reader box belongs beside the text, not at the trailing '
            'edge the platform default picks',
      );
    }

    // Each row decides its own direction first-strong: the Persian item is
    // laid out RTL, the English item LTR — instead of both taking the
    // interface's RTL base and scrambling the English one's neutrals.
    final faRow = t.widget<Text>(find.text('خرید شیر'));
    expect(faRow.textDirection, TextDirection.rtl);
    final enRow = t.widget<Text>(find.text('Buy milk @ 5pm'));
    expect(enRow.textDirection, TextDirection.ltr);

    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async {
      await features.close();
      await root.delete(recursive: true);
    });
    expect(t.takeException(), isNull);
  });
}
