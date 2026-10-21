import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/modules/module_probe.dart';
import 'package:nex_desktop/nex/modules/pdf_reader.dart';
import 'package:pdfrx/pdfrx.dart';
import 'support/review_fixture.dart';

void main() {
  testWidgets(
    'real local PDF turns pages, searches, and closes without a stale searcher',
    (t) async {
      final fixture = (await t.runAsync(
        () => openReviewStore('b8-pdf-widget'),
      ))!;
      final file = File('${fixture.root.path}/two-pages.pdf');
      await t.runAsync(() async {
        await file.writeAsBytes(desktopPdfProbeBytes());
        // No platform directory method or network is involved in this test.
        Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
        await pdfrxFlutterInitialize();
      });
      try {
        await t.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DesktopPdfReader(
                features: fixture.features,
                initialPath: file.path,
              ),
            ),
          ),
        );
        Future<void> until(bool Function() ready) async {
          for (var i = 0; i < 100 && !ready(); i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await t.pump(const Duration(milliseconds: 20));
          }
          expect(ready(), isTrue);
        }

        await until(() => find.text('Page 1 of 2').evaluate().isNotEmpty);
        await t.tap(find.byKey(const ValueKey('pdf-next')));
        await t.pump(const Duration(milliseconds: 400));
        await until(() => find.text('Page 2 of 2').evaluate().isNotEmpty);
        await t.enterText(
          find.byKey(const ValueKey('pdf-search')),
          'probe page two',
        );
        await t.pump(const Duration(milliseconds: 600));
        await until(() => find.text('Match 1 of 1').evaluate().isNotEmpty);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await closeReviewStore(t, fixture);
        expect(t.takeException(), isNull);
      }
    },
  );
}
