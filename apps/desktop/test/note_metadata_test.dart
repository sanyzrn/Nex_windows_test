import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/note_detail_parts.dart';

void main() {
  for (final language in ['en', 'fa']) {
    for (final edited in [false, true]) {
      testWidgets(
        '$language: details distinguish created and updated ($edited)',
        (t) async {
          final created = DateTime(2026, 10, 28, 12, 1, 7);
          final updated = edited
              ? created.add(const Duration(seconds: 10))
              : created;
          final note = Note(
            id: 'dates',
            type: NoteType.text,
            content: 'Test note',
            createdAt: created,
            updatedAt: updated,
            deviceId: 'test',
            rev: 1,
            syncState: SyncState.pending,
          );
          await t.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: NoteMetadataLine(note: note)),
            ),
          );
          final l = AppLocalizations.of(
            t.element(find.byType(NoteMetadataLine)),
          )!;
          await t.tap(find.byKey(const ValueKey('note-details-open')));
          await t.pumpAndSettle();
          expect(find.text(l.created), findsOneWidget);
          final date = nexDisplayDate(
            created,
            solar: language == 'fa',
            persian: language == 'fa',
          );
          expect(
            t.widget<Text>(find.byKey(const ValueKey('note-created-at'))).data,
            '$date · ${nexDigits('12:01:07', persian: language == 'fa')}',
          );
          if (edited) {
            expect(find.text(l.detailsEdited), findsOneWidget);
            expect(
              t
                  .widget<Text>(find.byKey(const ValueKey('note-updated-at')))
                  .data,
              '$date · ${nexDigits('12:01:17', persian: language == 'fa')}',
            );
          } else {
            expect(find.text(l.detailsNotEdited), findsOneWidget);
            expect(find.byKey(const ValueKey('note-updated-at')), findsNothing);
          }
          await t.tap(find.text(l.close));
          await t.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
