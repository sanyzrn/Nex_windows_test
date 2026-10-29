import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_core/nex_core.dart' show nexDisplayDate;
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/library_date_filter.dart';
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
  fail('Library date filter did not finish updating');
}

Set<String> _ids(WidgetTester t) =>
    t.widgetList<NoteCard>(find.byType(NoteCard)).map((w) => w.note.id).toSet();

Future<void> _choose(WidgetTester t, Finder menu, String label) async {
  await t.ensureVisible(menu);
  await t.tap(menu);
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pump(const Duration(milliseconds: 250));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'calendar bounds include whole local days across DST and year changes',
    () {
      for (final row in [
        (
          now: DateTime(2026, 3, 8, 15),
          week: DateTime(2026, 3, 2),
          month: DateTime(2026, 2, 7),
          next: DateTime(2026, 3, 9),
        ),
        (
          now: DateTime(2026, 11, 1, 15),
          week: DateTime(2026, 10, 26),
          month: DateTime(2026, 10, 3),
          next: DateTime(2026, 11, 2),
        ),
        (
          now: DateTime(2026, 1, 1, 15),
          week: DateTime(2025, 12, 26),
          month: DateTime(2025, 12, 3),
          next: DateTime(2026, 1, 2),
        ),
        (
          now: DateTime(2024, 3, 1, 15),
          week: DateTime(2024, 2, 24),
          month: DateTime(2024, 2, 1),
          next: DateTime(2024, 3, 2),
        ),
      ]) {
        final today = LibraryDatePreset.today.bounds(row.now.toUtc());
        final week = LibraryDatePreset.last7Days.bounds(row.now.toUtc());
        final month = LibraryDatePreset.last30Days.bounds(row.now.toUtc());
        expect(
          today.from,
          DateTime(row.now.year, row.now.month, row.now.day).toUtc(),
        );
        expect(week.from, row.week.toUtc());
        expect(month.from, row.month.toUtc());
        for (final range in [today, week, month]) {
          expect(range.from!.isUtc, isTrue);
          expect(range.to!.isUtc, isTrue);
          expect(
            range.to!.add(const Duration(microseconds: 1)),
            row.next.toUtc(),
          );
        }
      }
      if (Platform.isLinux &&
          Platform.environment['TZ'] == 'America/New_York') {
        final spring = LibraryDatePreset.today.bounds(DateTime(2026, 3, 8, 15));
        final autumn = LibraryDatePreset.today.bounds(
          DateTime(2026, 11, 1, 15),
        );
        expect(spring.from, DateTime.utc(2026, 3, 8, 5));
        expect(
          spring.to!.add(const Duration(microseconds: 1)),
          DateTime.utc(2026, 3, 9, 4),
        );
        expect(autumn.from, DateTime.utc(2026, 11, 1, 4));
        expect(
          autumn.to!.add(const Duration(microseconds: 1)),
          DateTime.utc(2026, 11, 2, 5),
        );
      }
      expect(LibraryDatePreset.any.bounds(DateTime.now()), (
        from: null,
        to: null,
      ));
    },
  );

  test(
    'date search includes boundary instants and excludes adjacent days',
    () async {
      final root = await Directory.systemTemp.createTemp('nex-date-bounds-');
      final db = NexDatabase.open('${root.path}/nex.sqlite');
      final repo = SqliteNoteRepository(db);
      final now = DateTime(2026, 3, 8, 15);
      final range = LibraryDatePreset.last7Days.bounds(now);
      final instants = {
        'before': range.from!.subtract(const Duration(microseconds: 1)),
        'start': range.from!,
        'end': range.to!,
        'after': range.to!.add(const Duration(microseconds: 1)),
      };
      for (final entry in instants.entries) {
        repo.insert(
          Note(
            id: entry.key,
            type: NoteType.text,
            content: 'Boundary ${entry.key}',
            createdAt: entry.value,
            updatedAt: entry.value,
            deviceId: 'test',
            rev: 1,
            syncState: SyncState.pending,
          ),
        );
      }
      db.close();
      final store = await DesktopStore.open(root.path, 'bounds');
      try {
        final results = await store.call<List<Note>>('search', {
          'filters': SearchFilters(
            createdFrom: range.from,
            createdTo: range.to,
          ),
        });
        expect(results.map((n) => n.id).toSet(), {'start', 'end'});
        final searched = await store.call<List<Note>>('search', {
          'filters': SearchFilters(
            query: 'Boundary',
            createdFrom: range.from,
            createdTo: range.to,
          ),
        });
        expect(searched.map((n) => n.id).toSet(), {'start', 'end'});
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );

  for (final language in ['en', 'fa']) {
    testWidgets(
      '$language: update dates and layout actions follow the actual pane',
      (t) async {
        t.view.physicalSize = const Size(700, 1100);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        late Directory root;
        late NexFeatures features;
        final updated = DateTime(2026, 10, 28, 12);
        await t.runAsync(() async {
          root = await Directory.systemTemp.createTemp('nex-library-updated-');
          final db = NexDatabase.open('${root.path}/nex.sqlite');
          final repo = SqliteNoteRepository(db);
          for (var i = 0; i < 2; i++) {
            repo.insert(
              Note(
                id: 'updated-$i',
                type: NoteType.text,
                content: 'Edited note $i',
                createdAt: DateTime(2020 + i, 1, 2),
                updatedAt: updated,
                deviceId: 'test',
                rev: 1,
                syncState: SyncState.pending,
              ),
            );
          }
          db.close();
          features = NexFeatures(await DesktopStore.open(root.path, 'test'));
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: nexLightTheme(),
            home: NexScope(
              features: features,
              child: const Scaffold(body: NexLibraryView()),
            ),
          ),
        );
        await _wait(t, () => _ids(t).length == 2);
        final list = find.byKey(const ValueKey('library-layout-list'));
        final board = find.byKey(const ValueKey('library-layout-board'));
        await t.tap(list);
        await t.pump();
        final shown = nexDisplayDate(
          updated,
          solar: language == 'fa',
          persian: language == 'fa',
        );
        expect(
          find.text(shown),
          findsOneWidget,
        ); // Two different creation dates, one updated day.
        await t.tap(board);
        await t.pump();
        expect(find.text(shown), findsNothing);
        t.view.physicalSize = const Size(639, 1100);
        await t.pump();
        expect(list, findsNothing);
        expect(board, findsNothing);
        expect(find.text(shown), findsOneWidget);
        t.view.physicalSize = const Size(640, 1100);
        await t.pump();
        expect(list, findsOneWidget);
        expect(t.widget<IconButton>(board).isSelected, isTrue);
        expect(find.text(shown), findsNothing);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'date presets combine, clear and fit narrow layouts: $language',
      (t) async {
        t.view.physicalSize = const Size(1200, 1800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        late Directory root;
        late NexFeatures features;
        await t.runAsync(() async {
          root = await Directory.systemTemp.createTemp('nex-date-ui-');
          final db = NexDatabase.open('${root.path}/nex.sqlite');
          try {
            final repo = SqliteNoteRepository(db);
            final threads = SqliteThreadRepository(db, repo);
            final tag = repo.upsertTag(name: 'Date work');
            final today = DateTime.now();
            final all = <String>[];
            for (final row in [
              (
                id: 'current',
                days: 0,
                type: NoteType.text,
                content: 'needle current',
                tagged: true,
                threaded: true,
              ),
              (
                id: 'week',
                days: 6,
                type: NoteType.text,
                content: 'needle week',
                tagged: true,
                threaded: true,
              ),
              (
                id: 'month',
                days: 29,
                type: NoteType.text,
                content: 'needle month',
                tagged: true,
                threaded: true,
              ),
              (
                id: 'archive',
                days: 30,
                type: NoteType.text,
                content: 'needle archive',
                tagged: true,
                threaded: true,
              ),
              (
                id: 'other-query',
                days: 0,
                type: NoteType.text,
                content: 'unrelated words',
                tagged: true,
                threaded: true,
              ),
              (
                id: 'other-type',
                days: 0,
                type: NoteType.link,
                content: 'https://needle.example.com',
                tagged: true,
                threaded: true,
              ),
              (
                id: 'other-tag',
                days: 0,
                type: NoteType.text,
                content: 'needle other tag',
                tagged: false,
                threaded: true,
              ),
              (
                id: 'other-thread',
                days: 0,
                type: NoteType.text,
                content: 'needle other thread',
                tagged: true,
                threaded: false,
              ),
            ]) {
              final at = DateTime(
                today.year,
                today.month,
                today.day - row.days,
                12,
              ).toUtc();
              repo.insert(
                Note(
                  id: row.id,
                  type: row.type,
                  content: row.content,
                  createdAt: at,
                  updatedAt: at,
                  deviceId: 'test',
                  rev: 1,
                  syncState: SyncState.pending,
                ),
              );
              if (row.tagged) repo.attachTag(noteId: row.id, tagId: tag.id);
              if (row.threaded) all.add(row.id);
            }
            threads.create('Date project', noteIds: all);
          } finally {
            db.close();
          }
          features = NexFeatures(await DesktopStore.open(root.path, 'dates'));
        });
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.runAsync(() async {
            await features.close();
            await root.delete(recursive: true);
          });
        });
        final scale = ValueNotifier(1.0);
        addTearDown(scale.dispose);
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: language == 'fa' ? nexDarkTheme() : nexLightTheme(),
            builder: (context, child) => ValueListenableBuilder<double>(
              valueListenable: scale,
              builder: (context, value, _) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(value)),
                child: child!,
              ),
            ),
            home: NexScope(
              features: features,
              child: const Scaffold(body: NexLibraryView()),
            ),
          ),
        );
        await _wait(t, () => _ids(t).length == 8);
        final l = AppLocalizations.of(t.element(find.byType(NexLibraryView)))!;
        final search = find.byKey(const ValueKey('library-search'));
        final dates = find.byKey(const ValueKey('library-date-filter'));
        await t.enterText(search, 'needle');
        await _wait(t, () => _ids(t).length == 7);
        await _choose(
          t,
          find.byKey(const ValueKey('library-type-filter')),
          l.text,
        );
        await _wait(t, () => _ids(t).length == 6);
        await _choose(
          t,
          find.byWidgetPredicate(
            (w) => w is NexPopupMenuButton<String> && w.tooltip == l.tags,
          ),
          'Date work',
        );
        await _wait(t, () => _ids(t).length == 5);
        await _choose(
          t,
          find.byWidgetPredicate(
            (w) => w is NexPopupMenuButton<String> && w.tooltip == l.threads,
          ),
          'Date project',
        );
        await _wait(t, () => _ids(t).length == 4);
        for (final row in [
          (label: l.todayTitle, ids: {'current'}),
          (label: l.filterLast7Days, ids: {'current', 'week'}),
          (label: l.filterLast30Days, ids: {'current', 'week', 'month'}),
        ]) {
          await _choose(t, dates, row.label);
          await _wait(t, () => _ids(t).length == row.ids.length);
          expect(_ids(t), row.ids);
        }
        // Clearing only the date must leave the query/type/tag/thread in place.
        final clearDate = find.descendant(
          of: dates,
          matching: find.byIcon(Icons.close),
        );
        await t.tap(clearDate);
        await _wait(t, () => _ids(t).length == 4);
        expect(t.widget<TextField>(search).controller!.text, 'needle');
        await _choose(t, dates, l.filterLast30Days);
        await _wait(t, () => _ids(t).length == 3);
        await t.ensureVisible(find.text(l.filterAll));
        await t.tap(find.text(l.filterAll));
        await _wait(t, () => _ids(t).length == 8);
        expect(t.widget<TextField>(search).controller!.text, isEmpty);
        expect(
          find.descendant(of: dates, matching: find.text(l.filterAnyTime)),
          findsOneWidget,
        );

        t.view.physicalSize = const Size(380, 520);
        scale.value = 2;
        await t.pumpAndSettle();
        expect(
          Directionality.of(t.element(find.byType(NexLibraryView))),
          language == 'fa' ? TextDirection.rtl : TextDirection.ltr,
        );
        await _choose(t, dates, l.todayTitle);
        await t.enterText(search, 'archive');
        await _wait(
          t,
          () => find.widgetWithText(TextButton, l.clear).evaluate().isNotEmpty,
        );
        expect(find.byType(NoteCard), findsNothing);
        final clearEmpty = find.widgetWithText(TextButton, l.clear);
        await t.ensureVisible(clearEmpty);
        await t.tap(clearEmpty);
        await _wait(t, () => _ids(t).isNotEmpty);
        expect(t.widget<TextField>(search).controller!.text, isEmpty);
        expect(
          find.descendant(of: dates, matching: find.text(l.filterAnyTime)),
          findsOneWidget,
        );
        await t.enterText(search, 'archive');
        await _wait(t, () => _ids(t).contains('archive'));
        expect(_ids(t), {'archive'});
        await _choose(t, dates, l.todayTitle);
        await _wait(
          t,
          () => find.widgetWithText(TextButton, l.clear).evaluate().isNotEmpty,
        );
        await t.runAsync(
          () => features.store.call<void>('delete', {'id': 'archive'}),
        );
        await t.ensureVisible(find.text(l.trash));
        await t.tap(find.text(l.trash));
        await _wait(t, () => _ids(t).contains('archive'));
        expect(dates, findsNothing);
        await t.ensureVisible(find.text(l.filterAll));
        await t.tap(find.text(l.filterAll));
        await _wait(
          t,
          () =>
              dates.evaluate().isNotEmpty &&
              _ids(t).isNotEmpty &&
              !_ids(t).contains('archive'),
        );
        expect(
          find.descendant(of: dates, matching: find.text(l.filterAnyTime)),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
