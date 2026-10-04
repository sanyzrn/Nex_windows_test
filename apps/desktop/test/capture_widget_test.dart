import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';

void main() {
  testWidgets(
    'Persian typing is durable after capture widget closes and app drains',
    (tester) async {
      late Directory root;
      late NexFeatures features;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('nex-capture-widget-');
        features = NexFeatures(
          await DesktopStore.open(root.path, 'widget-device'),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: nexLightTheme(),
          home: Scaffold(
            body: NexScope(
              features: features,
              child: const SizedBox(width: 300, child: NexCaptureView()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        // SQLite isolate messages need real async time, including the write callback.
        await tester.enterText(
          find.byKey(const ValueKey('capture-field')),
          'ثبت فوری فارسی',
        );
        await features.session.flushed;
        final rows = await features.store.call<List<Note>>('timeline');
        expect(rows.single.content, 'ثبت فوری فارسی');
      });
      // Closing the flyout removes its editor, not its app-owned capture session.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await features.close();
        final db = NexDatabase.open('${root.path}/nex.sqlite');
        expect(
          SqliteNoteRepository(db).listTimeline().single.content,
          'ثبت فوری فارسی',
        );
        db.close();
        await root.delete(recursive: true);
      });
      expect(tester.takeException(), isNull);
    },
  );
}
