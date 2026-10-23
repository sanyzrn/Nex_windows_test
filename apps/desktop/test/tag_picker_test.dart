import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_desktop/nex/tag_picker.dart';
import 'package:nex_ui/nex_ui.dart';

Future<void> _wait(WidgetTester t, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await t.pump(const Duration(milliseconds: 30));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (ready()) return;
  }
  fail('Tag operation did not finish');
}

void main() {
  test(
    'existing tag ids survive rename, are idempotent, and never resurrect deleted tags',
    () async {
      final root = await Directory.systemTemp.createTemp('nex-tag-command-');
      final store = await DesktopStore.open(root.path, 'test');
      try {
        final note = await store.call<Note>('capture', {
          'text': 'Keep my words',
        });
        final tag = await store.call<Tag>('tag', {
          'id': note.id,
          'name': 'Original',
        });
        await store.call<void>('renameTag', {'tag': tag.id, 'name': 'Renamed'});
        final second = await store.call<Note>('capture', {
          'text': 'Second note',
        });
        await store.call<Tag>('tag', {'id': second.id, 'tag': tag.id});
        final attached = await store.call<Note>('get', {'id': second.id});
        expect(attached.tags.single.id, tag.id);
        expect(attached.tags.single.name, 'Renamed');
        expect(attached.tags.single.color, tag.color);
        expect(attached.content, 'Second note');
        await store.call<Tag>('tag', {'id': second.id, 'tag': tag.id});
        final duplicate = await store.call<Note>('get', {'id': second.id});
        expect(duplicate.tags.length, 1);
        expect(duplicate.rev, attached.rev);
        await store.call<void>('deleteTag', {'tag': tag.id});
        await expectLater(
          store.call<Tag>('tag', {'id': second.id, 'tag': tag.id}),
          throwsStateError,
        );
        expect(
          (await store.call<List<Tag>>('tags')).map((item) => item.id),
          isNot(contains(tag.id)),
        );
        await store.call<Tag>('tag', {
          'id': second.id,
          'name': 'New typed tag',
        });
        expect(
          (await store.call<Note>('get', {'id': second.id})).tags.single.name,
          'New typed tag',
        );
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'picker retries a missing note and shows all-tags-attached state',
    (t) async {
      late Directory root;
      late DesktopStore store;
      late Note note;
      await t.runAsync(() async {
        root = await Directory.systemTemp.createTemp('nex-tag-retry-');
        store = await DesktopStore.open(root.path, 'retry');
        note = await store.call<Note>('capture', {
          'text': 'Every tag attached',
        });
        for (final tag in await store.call<List<Tag>>('tags')) {
          await store.call<Tag>('tag', {'id': note.id, 'tag': tag.id});
        }
        await store.call<void>('delete', {'id': note.id});
      });
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await store.close();
          await root.delete(recursive: true);
        });
      });
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DesktopTagPicker(store: store, noteId: note.id),
        ),
      );
      final l = AppLocalizations.of(t.element(find.byType(DesktopTagPicker)))!;
      await _wait(t, () => find.text(l.retry).evaluate().isNotEmpty);
      expect(find.text(l.failed), findsOneWidget);
      expect(find.textContaining('Bad state'), findsNothing);
      await t.runAsync(() => store.call<void>('restore', {'id': note.id}));
      await t.tap(find.text(l.retry));
      await _wait(t, () => find.text(l.noAvailableTags).evaluate().isNotEmpty);
      expect(find.byType(ListTile), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  for (final language in ['en', 'fa']) {
    for (final dark in [false, true]) {
      testWidgets('existing tag picker: $language/${dark ? 'dark' : 'light'}', (
        t,
      ) async {
        t.view.physicalSize = const Size(380, 520);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        late Directory root;
        late NexFeatures features;
        late Note target;
        late Tag used, work, travel;
        await t.runAsync(() async {
          root = await Directory.systemTemp.createTemp('nex-tag-picker-');
          final db = NexDatabase.open('${root.path}/nex.sqlite');
          try {
            final repo = SqliteNoteRepository(db);
            used = repo.upsertTag(name: 'Already attached');
            work = repo.upsertTag(name: 'کار', color: '#B61615');
            travel = repo.upsertTag(name: 'Travel');
          } finally {
            db.close();
          }
          features = NexFeatures(await DesktopStore.open(root.path, 'picker'));
          target = await features.store.call<Note>('capture', {
            'text': 'A note to tag',
          });
          await features.store.call<Tag>('tag', {
            'id': target.id,
            'tag': used.id,
          });
          target = await features.store.call<Note>('get', {'id': target.id});
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: NexScope(
              features: features,
              child: Scaffold(
                body: NexNoteDetail(note: target, onClose: () {}),
              ),
            ),
          ),
        );
        final context = t.element(find.byType(NexNoteDetail));
        final l = AppLocalizations.of(context)!;
        expect(
          Directionality.of(context),
          language == 'fa' ? TextDirection.rtl : TextDirection.ltr,
        );
        final group = find.text(l.tagsAndThreads);
        await t.ensureVisible(group);
        await t.tap(group);
        await t.pumpAndSettle();
        final open = find.byKey(const ValueKey('note-existing-tag'));
        await t.ensureVisible(open);
        await t.tap(open);
        await _wait(
          t,
          () =>
              find.byType(DesktopTagPicker).evaluate().isNotEmpty &&
              find
                  .descendant(
                    of: find.byType(DesktopTagPicker),
                    matching: find.byType(CircularProgressIndicator),
                  )
                  .evaluate()
                  .isEmpty,
        );
        final search = find.byKey(const ValueKey('existing-tag-search'));
        await t.enterText(search, used.name);
        await t.pump();
        expect(find.byKey(ValueKey('existing-tag-${used.id}')), findsNothing);
        expect(find.text(l.noMatchingTags), findsOneWidget);
        await t.enterText(search, 'كار');
        await t.pump();
        final dot = t.widget<Container>(
          find.byKey(ValueKey('existing-tag-color-${work.id}')),
        );
        expect(
          (dot.decoration! as BoxDecoration).color,
          const Color(0xFFB61615),
        );
        await t.enterText(search, 'No match');
        await t.pump();
        expect(find.text(l.noMatchingTags), findsOneWidget);
        await t.enterText(search, 'كار');
        await t.pump();
        expect(find.byKey(ValueKey('existing-tag-${travel.id}')), findsNothing);
        final choice = find.byKey(ValueKey('existing-tag-${work.id}'));
        await t.ensureVisible(choice);
        await t.tap(choice);
        late Note saved;
        await _wait(
          t,
          () =>
              find.byType(DesktopTagPicker).evaluate().isEmpty &&
              find.widgetWithText(InputChip, work.name).evaluate().isNotEmpty,
        );
        await t.runAsync(() async {
          saved = await features.store.call<Note>('get', {'id': target.id});
        });
        expect(
          saved.tags.map((tag) => tag.id),
          containsAll([used.id, work.id]),
        );
        expect(saved.tags.length, 2);
        expect(t.takeException(), isNull);
        await t.ensureVisible(open);
        await t.tap(open);
        await _wait(
          t,
          () =>
              find.byType(DesktopTagPicker).evaluate().isNotEmpty &&
              find
                  .descendant(
                    of: find.byType(DesktopTagPicker),
                    matching: find.byType(CircularProgressIndicator),
                  )
                  .evaluate()
                  .isEmpty,
        );
        await t.enterText(search, work.name);
        await t.pump();
        expect(find.byKey(ValueKey('existing-tag-${work.id}')), findsNothing);
        expect(find.text(l.noMatchingTags), findsOneWidget);
        await t.enterText(search, travel.name);
        await t.pump();
        expect(
          find.byKey(ValueKey('existing-tag-${travel.id}')),
          findsOneWidget,
        );
        await t.tap(find.widgetWithText(TextButton, l.close));
        await t.pumpAndSettle();
        final input = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == l.addTag,
        );
        await t.ensureVisible(input);
        await t.enterText(input, 'Fresh tag');
        await t.testTextInput.receiveAction(TextInputAction.done);
        await _wait(
          t,
          () =>
              find.widgetWithText(InputChip, 'Fresh tag').evaluate().isNotEmpty,
        );
        await t.runAsync(() async {
          saved = await features.store.call<Note>('get', {'id': target.id});
        });
        expect(saved.tags.map((tag) => tag.name), contains('Fresh tag'));
        expect(t.takeException(), isNull);
      });
    }
  }
}
