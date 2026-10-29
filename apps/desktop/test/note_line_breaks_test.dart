import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/note_tile.dart';
import 'package:nex_desktop/nex/store.dart';

void main() {
  for (final formatted in [false, true]) {
    testWidgets('reader retains Enters (formatted: $formatted)', (t) async {
      const words = 'خط اول\nخط دوم\n\nخط سوم\n\n\nخط چهارم';
      final text = formatted ? '**خط اول**${words.substring(6)}' : words;
      late Directory root;
      late NexFeatures features;
      late Note note;
      await t.runAsync(() async {
        root = await Directory.systemTemp.createTemp('nex-line-breaks-');
        features = NexFeatures(await DesktopStore.open(root.path, 'lines'));
        note = await features.store.call<Note>('capture', {'text': text});
      });
      Widget host(Widget child) => MaterialApp(
        locale: const Locale('fa'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NexScope(
          features: features,
          child: Scaffold(body: child),
        ),
      );
      await t.pumpWidget(host(NexNoteDetail(note: note, onClose: () {})));
      await t.pumpAndSettle();
      final paragraphs = t
          .widgetList<RichText>(find.byType(RichText))
          .map((widget) => widget.text.toPlainText())
          .join('\n');
      expect(paragraphs, contains('خط اول\nخط دوم'));
      if (!formatted) {
        expect(paragraphs, contains(words));
        await t.pumpWidget(
          host(
            SizedBox(
              width: 400,
              height: 200,
              child: NexNoteTile(note: note, onOpen: () {}),
            ),
          ),
        );
        expect(find.text('خط دوم\n\nخط سوم\n\n\nخط چهارم'), findsOneWidget);
      }
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        await features.close();
        await root.delete(recursive: true);
      });
      expect(t.takeException(), isNull);
    });
  }
}
