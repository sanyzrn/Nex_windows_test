// Quarantined: this GUI fixture can deadlock under concurrent Windows CI
// (run 40885950193). Domain pin tests remain blocking; run this file explicitly
// with --tags quarantined while investigating the fixture's async scheduling.
@Tags(['quarantined'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<void> _pumpUntil(WidgetTester t, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await t.pump(const Duration(milliseconds: 30));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (ready()) return;
  }
  fail('The library did not finish updating');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scenario in [
    (name: 'mixed', pins: 1, count: 2, language: 'en', theme: 'light'),
    (name: 'all pinned', pins: 2, count: 2, language: 'fa', theme: 'dark'),
    (name: 'none pinned', pins: 0, count: 2, language: 'fa', theme: 'light'),
    (name: 'pin limit', pins: 4, count: 6, language: 'en', theme: 'dark'),
  ]) {
    testWidgets(
      'bulk pin: ${scenario.name} (${scenario.language}/${scenario.theme})',
      (t) async {
        t.view.physicalSize = const Size(1000, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        late Directory root;
        late NexFeatures features;
        final originalPins = <String, DateTime?>{};
        await t.runAsync(() async {
          root = await Directory.systemTemp.createTemp('nex-bulk-pin-');
          final db = NexDatabase.open('${root.path}/nex.sqlite');
          try {
            final repo = SqliteNoteRepository(db);
            final now = DateTime.now().toUtc();
            for (var i = 0; i < scenario.count; i++) {
              final id = 'selection-$i';
              repo.insert(
                Note(
                  id: id,
                  type: NoteType.text,
                  content: 'Selection note $i',
                  createdAt: now.subtract(Duration(minutes: i)),
                  updatedAt: now,
                  deviceId: 'test',
                  rev: 1,
                  syncState: SyncState.pending,
                ),
              );
              if (i < scenario.pins) expect(repo.pinNote(id), isTrue);
              originalPins[id] = repo.getById(id)!.pinnedAt;
            }
          } finally {
            db.close();
          }
          features = NexFeatures(
            await DesktopStore.open(root.path, 'bulk-pin'),
          );
        });
        final controller = PanelController(nativeHost: _Native());
        await controller.bootstrap(
          preset: Settings()
            ..windowMode = 'window'
            ..language = scenario.language
            ..theme = scenario.theme,
          useNative: false,
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          controller.dispose();
          await t.runAsync(() async {
            await features.close();
            await root.delete(recursive: true);
          });
        });
        await t.pumpWidget(
          RightPanelApp(controller: controller, features: features),
        );
        controller.selectWindowSection('library');
        await _pumpUntil(
          t,
          () => find.byType(NoteCard).evaluate().length == scenario.count,
        );
        final context = t.element(find.byType(NexLibraryView));
        final l = AppLocalizations.of(context)!;
        expect(
          Directionality.of(context),
          scenario.language == 'fa' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          Theme.of(context).brightness,
          scenario.theme == 'dark' ? Brightness.dark : Brightness.light,
        );
        final chosen = scenario.count == 6 ? [0, 4, 5] : [0, 1];
        for (final i in chosen) {
          final card = find.byWidgetPredicate(
            (widget) => widget is NoteCard && widget.note.id == 'selection-$i',
          );
          await t.ensureVisible(card);
          await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await t.tap(card);
          await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await t.pump();
        }
        expect(
          find.byWidgetPredicate(
            (widget) => widget is NoteCard && widget.selected == true,
          ),
          findsNWidgets(chosen.length),
        );
        final unpin = scenario.name == 'all pinned';
        final action = find.byTooltip(unpin ? l.unpin : l.pin);
        expect(action, findsOneWidget);
        await t.ensureVisible(action);
        await t.tap(action);
        await _pumpUntil(
          t,
          () => find.byTooltip(l.clearSelection).evaluate().isEmpty,
        );
        late List<Note> saved;
        await t.runAsync(() async {
          saved = await features.store.call<List<Note>>('timeline');
        });
        final byId = {for (final note in saved) note.id: note};
        expect(saved.length, scenario.count);
        if (scenario.name == 'pin limit') {
          expect(saved.where((n) => n.pinnedAt != null).length, 5);
          expect(
            [4, 5].where((i) => byId['selection-$i']!.pinnedAt != null).length,
            1,
          );
          await _pumpUntil(
            t,
            () => find.text(l.pinLimitReached).evaluate().isNotEmpty,
          );
        } else {
          for (final i in chosen) {
            expect(byId['selection-$i']!.pinnedAt, unpin ? isNull : isNotNull);
          }
        }
        if (!unpin) {
          for (final entry in originalPins.entries.where(
            (e) => e.value != null,
          )) {
            expect(
              byId[entry.key]!.pinnedAt,
              entry.value,
              reason: 'Existing pins must be preserved',
            );
          }
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
