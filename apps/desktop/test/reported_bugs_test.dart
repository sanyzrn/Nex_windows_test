import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/display_identity.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/note_detail_view.dart';
import 'package:nex_desktop/nex/notices.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<void> _database(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<({NexFeatures f, PanelController c})> _fixture(
  WidgetTester t, {
  double width = 1200,
}) async {
  t.view.physicalSize = Size(width, 950);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  late Directory root;
  late NexFeatures f;
  await t.runAsync(() async {
    root = await Directory.systemTemp.createTemp('nex-reported-bugs-');
    final db = NexDatabase.open('${root.path}/nex.sqlite');
    final repo = SqliteNoteRepository(db);
    final now = DateTime.now().toUtc();
    repo.insert(
      Note(
        id: 'checklist',
        type: NoteType.checklist,
        content: '- [x] First done\n- [ ] Second item\n- [ ] Third item',
        createdAt: now,
        updatedAt: now,
        deviceId: 'test',
        rev: 1,
        syncState: SyncState.pending,
      ),
    );
    repo.insert(
      Note(
        id: 'deleted',
        type: NoteType.text,
        content: 'Deleted note content',
        createdAt: now,
        updatedAt: now,
        deviceId: 'test',
        rev: 1,
        syncState: SyncState.pending,
      ),
    );
    repo.pinNote('deleted');
    repo.setDueAt('deleted', now.add(const Duration(days: 1)));
    repo.softDelete('deleted');
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
  c.selectWindowSection('library');
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
  return (f: f, c: c);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'display numbers follow device names even with reversed enumeration',
    () {
      expect(displayNumber({'name': r'\\.\DISPLAY2'}, 0), '2');
      expect(displayNumber({'name': r'\\.\DISPLAY1'}, 1), '1');
      expect(displayNumber({'name': 'unknown'}, 0), '1');
    },
  );

  testWidgets(
    'Undo success notice expires and a new notice replaces its queue',
    (t) async {
      final messenger = GlobalKey<ScaffoldMessengerState>();
      await t.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messenger,
          home: const Scaffold(body: SizedBox()),
        ),
      );
      showNexNotice(
        messenger.currentState!,
        'Note deleted',
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Note deleted'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Note deleted'), findsNothing);
      showNexNotice(messenger.currentState!, 'Old notice');
      await t.pump();
      showNexNotice(messenger.currentState!, 'Newest notice');
      await t.pumpAndSettle();
      expect(find.text('Newest notice'), findsOneWidget);
      expect(find.text('Old notice'), findsNothing);
    },
  );

  testWidgets('trash has only restore and never opens editable reader', (
    t,
  ) async {
    final fixture = await _fixture(t);
    await t.tap(find.text('Recently deleted'));
    await _database(t);
    expect(find.byType(NexNoteDetail), findsNothing);
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(find.byIcon(Icons.alarm_add_outlined), findsNothing);
    final card = t.widget<NoteCard>(find.byType(NoteCard));
    expect(card.showDue, isFalse);
    expect(card.note.pinnedAt, isNull);
    expect(card.onTap, isNull);
    expect(card.onChecklistToggle, isNull);
    await t.tap(find.text('Restore'));
    await _database(t);
    final restored = await t.runAsync(
      () => fixture.f.store.call<Note?>('get', {'id': 'deleted'}),
    );
    expect(restored!.deletedAt, isNull);
    expect(
      restored.pinnedAt,
      isNotNull,
      reason: 'Restore preserves the original note metadata.',
    );
    expect(find.text('Deleted note content'), findsNothing);
  });

  testWidgets(
    'card checklist toggles source item without opening reader, detail refreshes',
    (t) async {
      final fixture = await _fixture(t, width: 700);
      final unchecked = find.descendant(
        of: find.byType(NoteCard),
        matching: find.byIcon(Icons.check_box_outline_blank),
      );
      await t.tap(unchecked.first);
      await _database(t);
      final checked = await t.runAsync(
        () => fixture.f.store.call<Note?>('get', {'id': 'checklist'}),
      );
      expect(checked!.checklistItems.map((i) => i.done), [true, true, false]);
      expect(find.byType(NexNoteDetail), findsNothing);
      await t.tap(find.byType(NoteCard));
      await _database(t);
      final tile = find.widgetWithText(CheckboxListTile, 'Third item');
      await t.tap(tile);
      await _database(t);
      expect(t.widget<CheckboxListTile>(tile).value, isTrue);
      final saved = await t.runAsync(
        () => fixture.f.store.call<Note?>('get', {'id': 'checklist'}),
      );
      expect(saved!.checklistItems.every((i) => i.done), isTrue);
      // An external update of the same note must update the retained reader state.
      await t.runAsync(
        () => fixture.f.guard(
          () => fixture.f.store.call<void>('check', {
            'id': 'checklist',
            'index': 0,
          }),
        ),
      );
      await _database(t);
      expect(
        t
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'First done'),
            )
            .value,
        isFalse,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'tag manager creates, renames and deletes without deleting notes',
    (t) async {
      final fixture = await _fixture(t);
      await t.tap(find.byKey(const ValueKey('manage-tags')));
      await _database(t);
      await t.enterText(find.byKey(const ValueKey('tag-name')), 'Release QA');
      await t.tap(find.byTooltip('Save'));
      await _database(t);
      expect(
        find.text('Release QA'),
        findsOneWidget,
        reason: t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
      await t.runAsync(
        () => fixture.f.store.call('tag', {
          'id': 'checklist',
          'name': 'Release QA',
        }),
      );
      await t.enterText(find.byKey(const ValueKey('tag-search')), 'Release');
      await t.pump();
      await t.tap(find.byTooltip('Edit'));
      await t.enterText(
        find.byKey(const ValueKey('tag-name')),
        'Release plans',
      );
      await t.tap(find.byTooltip('Save'));
      await _database(t);
      final renamed = await t.runAsync(
        () => fixture.f.store.call<Note?>('get', {'id': 'checklist'}),
      );
      expect(renamed!.tags.single.name, 'Release plans');
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byTooltip('Delete'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await _database(t);
      final after = await t.runAsync(
        () => fixture.f.store.call<Note?>('get', {'id': 'checklist'}),
      );
      expect(after!.tags, isEmpty);
      expect(after.deletedAt, isNull);
      expect(t.takeException(), isNull);
    },
  );
}
