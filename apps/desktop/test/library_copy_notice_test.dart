import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _wait(WidgetTester t, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await t.pump(const Duration(milliseconds: 30));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (ready()) return;
  }
  fail('Library copy did not finish');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final language in ['en', 'fa']) {
    for (final dark in [false, true]) {
      testWidgets('Library copy paths replace, close and expire: $language/$dark', (
        t,
      ) async {
        t.view.physicalSize = const Size(1200, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var clipboard = '';
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboard = (call.arguments as Map)['text'] as String;
              }
              return null;
            });
        late Directory root;
        late NexFeatures features;
        await t.runAsync(() async {
          root = await Directory.systemTemp.createTemp('nex-copy-notice-');
          features = NexFeatures(await DesktopStore.open(root.path, 'copy'));
          await features.store.call<Note>('capture', {
            'text': 'First synthetic note',
          });
          await features.store.call<Note>('capture', {
            'text': 'Second synthetic note',
          });
        });
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.runAsync(() async {
            await features.close();
            await root.delete(recursive: true);
          });
        });
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: dark ? nexDarkTheme() : nexLightTheme(),
            home: NexScope(
              features: features,
              child: const Scaffold(body: NexLibraryView()),
            ),
          ),
        );
        await _wait(t, () => find.byType(NoteCard).evaluate().length == 2);
        final l = AppLocalizations.of(t.element(find.byType(NexLibraryView)))!;
        final card = find.byType(NoteCard).first;
        final expected = t.widget<NoteCard>(card).note.content!;
        // Context menu, then the library keyboard path while a note is selected.
        await t.tap(card, buttons: kSecondaryMouseButton);
        await t.pumpAndSettle();
        await t.tap(find.text(l.copy).last);
        await t.pumpAndSettle();
        expect(clipboard, expected);
        expect(t.widget<SnackBar>(find.byType(SnackBar)).showCloseIcon, isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pumpAndSettle();
        expect(find.byType(NexNoteDetail), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          clipboard = '';
          await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await t.sendKeyEvent(LogicalKeyboardKey.keyC);
          await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await t.pump(const Duration(milliseconds: 50));
          expect(clipboard, expected);
        }
        await t.pumpAndSettle();
        expect(find.byType(SnackBar), findsOneWidget);
        await t.pump(const Duration(seconds: 5));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(SnackBar), findsNothing);
        // Bulk selection must still copy both notes and allow manual dismissal.
        for (final text in ['First synthetic note', 'Second synthetic note']) {
          final target = find.byWidgetPredicate(
            (w) => w is NoteCard && w.note.content == text,
          );
          await t.ensureVisible(target);
          await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await t.tap(target);
          await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await t.pump();
        }
        await t.tap(find.byTooltip(l.copy).first);
        await t.pumpAndSettle();
        expect(clipboard, contains('First synthetic note'));
        expect(clipboard, contains('Second synthetic note'));
        expect(clipboard, contains('\n\n---\n\n'));
        final bar = find.byType(SnackBar);
        expect(bar, findsOneWidget);
        final close = find.descendant(
          of: bar,
          matching: find.byType(IconButton),
        );
        await t.tap(close);
        await t.pumpAndSettle();
        expect(bar, findsNothing);
        await t.pump(const Duration(seconds: 5));
        expect(bar, findsNothing);
        expect(t.takeException(), isNull);
      });
    }
  }
}
