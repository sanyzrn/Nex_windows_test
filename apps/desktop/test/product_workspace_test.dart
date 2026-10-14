import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/note_activation.dart';
import 'package:nex_desktop/nex/note_detail_view.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<void> _database(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'home loads exact counts, opens pinned notes and refreshes saves',
    (t) async {
      t.view.physicalSize = const Size(1200, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      late Directory root;
      late NexFeatures f;
      late Note old;
      await t.runAsync(() async {
        root = await Directory.systemTemp.createTemp('nex-product-home-');
        final db = NexDatabase.open('${root.path}/nex.sqlite');
        final repo = SqliteNoteRepository(db);
        for (var i = 0; i < 60; i++) {
          final at = DateTime.utc(2026, 10, 14).subtract(Duration(minutes: i));
          repo.insert(
            Note(
              id: 'home-$i',
              type: NoteType.text,
              content: 'Home note $i',
              createdAt: at,
              updatedAt: at,
              deviceId: 'test',
              rev: 1,
              syncState: SyncState.pending,
            ),
          );
        }
        repo.pinNote('home-5');
        old = repo.getById('home-59')!;
        db.close();
        f = NexFeatures(await DesktopStore.open(root.path, 'test'));
      });
      final c = PanelController(nativeHost: _Native());
      await c.bootstrap(
        preset: Settings()
          ..windowMode = 'window'
          ..language = 'en',
        useNative: false,
      );
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        c.dispose();
        await t.runAsync(() async {
          await f.close();
          await root.delete(recursive: true);
        });
      });
      await t.pumpWidget(RightPanelApp(controller: c, features: f));
      await _database(t);
      expect(find.text('60'), findsOneWidget);
      final preview = find.byKey(const ValueKey('workspace-note-home-5'));
      expect(preview, findsWidgets);
      await t.tap(preview.first);
      await _database(t);
      expect(
        t.widget<NexNoteDetail>(find.byType(NexNoteDetail)).note.id,
        'home-5',
      );

      // Notification/search activation must retain a note beyond the first page.
      await t.runAsync(() => activateNote('nex-win://note/${old.id}', c, f));
      await _database(t);
      f.libraryRevision++;
      f.notify();
      await _database(t);
      expect(
        t.widget<NexNoteDetail>(find.byType(NexNoteDetail)).note.id,
        old.id,
      );

      c.selectWindowSection('capture');
      await t.pump();
      await _database(t);
      await t.runAsync(() async {
        f.write('A newly captured note');
        await f.session.flushed;
      });
      await t.pump(const Duration(milliseconds: 251));
      await _database(t);
      await t.pump(const Duration(milliseconds: 251));
      await _database(t);
      expect(find.text('61'), findsOneWidget);
      expect(find.text('A newly captured note'), findsWidgets);
      expect(t.takeException(), isNull);
    },
  );
}
