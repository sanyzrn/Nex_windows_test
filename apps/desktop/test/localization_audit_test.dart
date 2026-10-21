import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/l10n/shortcut_labels.dart';
import 'package:nex_desktop/nex/commitments.dart';
import 'package:nex_desktop/nex/shortcuts_dialog.dart';

Widget localized(String language, WidgetBuilder builder) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: Builder(builder: builder)),
);

void main() {
  test(
    'weekday labels preserve stored weekday numbers and locale ordering',
    () {
      final en = commitmentWeekdays(false);
      final fa = commitmentWeekdays(true);
      expect(en.map((day) => day.day), [1, 2, 3, 4, 5, 6, 7]);
      expect(fa.map((day) => day.day), [6, 7, 1, 2, 3, 4, 5]);
      expect(en.first.name, 'Monday');
      expect(fa.first.name, 'شنبه');
      expect(fa.first.shortName, 'ش');
      for (final day in fa) {
        expect(day.name, isNotEmpty);
        expect(day.shortName, isNotEmpty);
      }
    },
  );

  for (final language in ['en', 'fa']) {
    testWidgets('cadence messages and counts are localized in $language', (
      tester,
    ) async {
      final expected = language == 'fa'
          ? ['هر ساعت', 'روزانه', 'هفتگی', 'ماهانه', 'سالانه']
          : ['Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly'];
      await tester.pumpWidget(
        localized(language, (context) {
          return Column(
            children: [
              for (final cadence in NexCadence.values)
                Text(commitmentCadenceLabel(context, cadence, 1)),
              Text(commitmentCadenceLabel(context, NexCadence.days, 12)),
              Text(commitmentCadenceLabel(context, NexCadence.hours, 2)),
            ],
          );
        }),
      );
      await tester.pumpAndSettle();
      for (final message in expected) {
        expect(find.text(message), findsOneWidget);
      }
      expect(
        find.text(language == 'fa' ? 'هر ۱۲ روز' : 'Every 12 days'),
        findsOneWidget,
      );
      expect(
        find.text(language == 'fa' ? 'هر ۲ ساعت' : 'Every 2 hours'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'shortcut key names stay LTR inside the $language help dialog',
      (tester) async {
        await tester.pumpWidget(
          localized(language, (context) {
            return TextButton(
              onPressed: () => showShortcutsDialog(context),
              child: Text(AppLocalizations.of(context)!.keyboardShortcuts),
            );
          }),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        final label = ShortcutLabels.spaced(ShortcutLabels.newNote);
        expect(find.text(label), findsOneWidget);
        expect(
          tester.widget<Text>(find.text(label)).textDirection,
          TextDirection.ltr,
        );
        expect(
          find.text(language == 'fa' ? 'یادداشت جدید' : 'New note'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
