import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<void> _settleDatabase(WidgetTester t) async {
  // Bound the wait by rendered loading state rather than SQLite timing on
  // a particular host. The first frame mounts the destination and starts I/O.
  await t.pump();
  for (var i = 0; i < 60; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty && i >= 2) {
      return;
    }
  }
  fail('The library did not finish loading within the bounded wait.');
}

void main() {
  late Directory root;
  late NexFeatures f;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('nex-0140-');
    f = NexFeatures(await DesktopStore.open(root.path, 'release-test'));
  });
  tearDown(() async {
    await f.close();
    await root.delete(recursive: true);
  });

  test(
    'new-note rotation drains input arriving during its first flush',
    () async {
      f.composer.text = 'first';
      f.write('first');
      final rotate = f.fresh();
      f.composer.text = 'the final text';
      // Ctrl+V also writes directly through the session's FIFO.
      final latePaste = f.session.write('the final text');
      await latePaste;
      expect(await rotate, isTrue);
      expect(f.composer.text, isEmpty);
      final rows = await f.store.call<List<Note>>('timeline');
      expect(rows.single.content, 'the final text');
    },
  );

  test('a failed flush retains recoverable text and can be retried', () async {
    f.write('original');
    await f.session.flushed;
    final id = f.session.id!;
    await f.store.call<void>('delete', {'id': id});
    f.composer.text = 'unsaved recovery copy';
    f.write(f.composer.text);
    await expectLater(f.session.flushed, throwsStateError);
    expect(await f.fresh(), isFalse);
    expect(f.composer.text, 'unsaved recovery copy');
    expect(f.session.id, id);
    await f.store.call<void>('restore', {'id': id});
    f.write(f.composer.text);
    await f.session.flushed;
    expect(await f.fresh(), isTrue);
    expect(
      (await f.store.call<Note>('get', {'id': id})).content,
      'unsaved recovery copy',
    );
  });

  test(
    'restore resets the active capture and subsequent input persists',
    () async {
      await f.store.call<Note>('capture', {'text': 'backed up'});
      final archive = await f.store.call<String>('backup', {
        'directory': '${root.path}/backups',
      });
      f.composer.text = 'not in backup';
      f.write(f.composer.text);
      await f.session.flushed;
      final oldId = f.session.id;
      await f.restoreBackup(archive, null);
      expect(f.session.id, isNull);
      expect(f.composer.text, isEmpty);
      f.write('after restore');
      await f.session.flushed;
      expect(f.session.id, isNot(oldId));
      expect(
        (await f.store.call<List<Note>>('timeline')).map((n) => n.content),
        containsAll(['backed up', 'after restore']),
      );
    },
  );

  test('an invalid restore retains the active capture', () async {
    f.composer.text = 'keep this';
    f.write(f.composer.text);
    await f.session.flushed;
    final session = f.session;
    await expectLater(
      f.restoreBackup('${root.path}/missing.nexbak', null),
      throwsA(anything),
    );
    expect(f.session, same(session));
    expect(f.composer.text, 'keep this');
  });

  test('reader edits update the active composer and recent ordering', () async {
    f.write('first note');
    await f.session.flushed;
    final id = f.session.id!;
    await f.store.call<Note>('capture', {'text': 'newer note'});
    await f.store.call<Note>('capture', {'id': id, 'text': 'edited in reader'});
    final note = await f.store.call<Note>('get', {'id': id});
    f.reflectReaderEdit(note);
    expect(f.composer.text, 'edited in reader');
    final overview = await f.store.call<Map<String, dynamic>>('workspace');
    expect((overview['recent'] as List<Note>).first.id, id);
  });

  test('closing rejects commands queued after the terminal command', () async {
    final closing = f.store.close();
    await expectLater(f.store.call<void>('timeline'), throwsStateError);
    await Future.wait([closing, f.store.close()]);
  });

  testWidgets('empty library routes to capture and tools in window mode', (
    t,
  ) async {
    t.view.physicalSize = const Size(850, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = PanelController(nativeHost: _Native());
    await c.bootstrap(
      preset: Settings()
        ..windowMode = 'window'
        ..language = 'en',
      useNative: false,
    );
    await t.pumpWidget(RightPanelApp(controller: c, features: f));
    c.selectWindowSection('library');
    await _settleDatabase(t);
    await t.tap(find.text('Write the first note'));
    await t.pump();
    expect(c.windowSection.value, 'capture');
    c.selectWindowSection('library');
    await _settleDatabase(t);
    await t.tap(find.text('Browse the tools'));
    await t.pump();
    expect(c.windowSection.value, 'tools');
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'type filter All clears its selection and hidden tools stay hidden',
    (t) async {
      t.view.physicalSize = const Size(1200, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.runAsync(() async {
        await f.store.call<Note>('capture', {'text': 'ordinary note'});
        await f.store.call<Note>('capture', {
          'text': 'one task',
          'checklist': true,
        });
      });
      final c = PanelController(nativeHost: _Native());
      await c.bootstrap(
        preset: Settings()
          ..windowMode = 'window'
          ..language = 'en'
          ..hidden = ['calc'],
        useNative: false,
      );
      await t.pumpWidget(RightPanelApp(controller: c, features: f));
      c.selectWindowSection('library');
      await _settleDatabase(t);
      expect(find.byType(NoteCard), findsNWidgets(2));
      await t.tap(find.byKey(const ValueKey('library-type-filter')));
      await t.pumpAndSettle();
      await t.tap(find.text('Checklist').last);
      await _settleDatabase(t);
      expect(find.byType(NoteCard), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('library-type-filter')));
      await t.pumpAndSettle();
      await t.tap(find.text('All types'));
      await _settleDatabase(t);
      expect(find.byType(NoteCard), findsNWidgets(2));
      c.selectWindowSection('tools');
      await t.pumpAndSettle();
      expect(find.text('Calculator'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
