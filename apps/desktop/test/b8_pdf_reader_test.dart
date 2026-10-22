import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/modules/module_probe.dart';
import 'package:nex_desktop/nex/modules/pdf_reader.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:pdfrx/pdfrx.dart';
import 'support/review_fixture.dart';

void main() {
  testWidgets(
    'real local PDF turns pages, searches, and closes without a stale searcher',
    (t) async {
      final root = (await t.runAsync(
        () => Directory.systemTemp.createTemp('nex-b8-pdf-widget-'),
      ))!;
      final file = File('${root.path}/two-pages.pdf');
      final features = (await t.runAsync(
        () async => NexFeatures(
          await DesktopStore.open(root.path, 'pdf-widget'),
          pickFiles: (_) async => [XFile(file.path)],
        ),
      ))!;
      final fixture = ReviewStore(features, root);
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
        // Shortcuts work on first open, before clicking any focusable control.
        await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await t.sendKeyEvent(LogicalKeyboardKey.keyF);
        await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await t.pump();
        expect(
          t
              .widget<TextField>(find.byKey(const ValueKey('pdf-search')))
              .focusNode!
              .hasFocus,
          isTrue,
        );
        await t.tap(find.byKey(const ValueKey('pdf-next')));
        await t.pump(const Duration(milliseconds: 400));
        await until(() => find.text('Page 2 of 2').evaluate().isNotEmpty);
        await t.enterText(
          find.byKey(const ValueKey('pdf-search')),
          'probe page two',
        );
        await t.pump(const Duration(milliseconds: 600));
        await until(() => find.text('Match 1 of 1').evaluate().isNotEmpty);
        // Reopening retires the old keyed viewer without detaching the new one.
        await t.tap(find.text('Choose a PDF'));
        await t.pump();
        await until(() => find.text('Page 1 of 2').evaluate().isNotEmpty);
        await t.tap(find.byKey(const ValueKey('pdf-next')));
        await t.pump(const Duration(milliseconds: 400));
        await until(() => find.text('Page 2 of 2').evaluate().isNotEmpty);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await closeReviewStore(t, fixture);
        expect(t.takeException(), isNull);
      }
    },
  );
}
