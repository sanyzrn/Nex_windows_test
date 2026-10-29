import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';

void main() {
  testWidgets('capture modes keep one editor and convert the saved note', (
    tester,
  ) async {
    late Directory root;
    late NexFeatures features;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('nex-capture-modes-');
      features = NexFeatures(await DesktopStore.open(root.path, 'modes'));
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: nexLightTheme(),
        home: Scaffold(
          body: NexScope(
            features: features,
            child: const SizedBox(
              width: 720,
              child: NexCaptureView(compact: false, embedded: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('capture-field'));
    final original = tester.getRect(field);
    await tester.runAsync(() async {
      await tester.enterText(field, 'example.com/path');
      await features.session.flushed;
    });
    final id = features.session.id;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('capture-mode-link')));
      await features.session.flushed;
    });
    await tester.pump();
    final link = await tester.runAsync(
      () => features.store.call<Note?>('get', {'id': id}),
    );
    expect(link!.type, NoteType.link);
    expect(link.content, 'https://example.com/path');
    expect(tester.getRect(field), original);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('capture-mode-checklist')));
      await features.session.flushed;
    });
    await tester.pump();
    final checklist = await tester.runAsync(
      () => features.store.call<Note?>('get', {'id': id}),
    );
    expect(checklist!.type, NoteType.checklist);
    expect(checklist.checklistItems.single.text, 'example.com/path');
    expect(tester.getRect(field), original);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('capture-mode-text')));
      await features.session.flushed;
    });
    await tester.pump();
    final text = await tester.runAsync(
      () => features.store.call<Note?>('get', {'id': id}),
    );
    expect(text!.type, NoteType.text);
    expect(text.content, 'example.com/path');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await features.close();
      await root.delete(recursive: true);
    });
    expect(tester.takeException(), isNull);
  });

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
