import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/l10n/desktop_format.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/modules/cycle_view.dart';
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
  fail('Cycle dialog operation did not finish');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('rp/native'),
          (call) async => call.method == 'privateVerify' ? true : null,
        );
  });
  for (final language in ['en', 'fa']) {
    for (final dark in [false, true]) {
      testWidgets('Cycle dialogs preserve cancel/save: $language/$dark', (
        t,
      ) async {
        t.view.physicalSize = const Size(380, 520);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        late Directory root;
        late NexFeatures features;
        await t.runAsync(() async {
          root = await Directory.systemTemp.createTemp('nex-cycle-dialogs-');
          features = NexFeatures(await DesktopStore.open(root.path, 'dialogs'));
          await features.modules.initialize();
          await features.modules.privateSession.unlock('Synthetic test');
          final period = await features.store.call<CyclePeriod>('cycleStart', {
            'day': DateTime(2026, 10, 12),
          });
          await features.store.call<void>('cycleEnd', {
            'id': period.id,
            'day': DateTime(2026, 10, 16),
          });
        });
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.runAsync(() async {
            await features.close();
            await root.delete(recursive: true);
          });
        });
        final glass = language == 'fa' ? !dark : dark;
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: dark
                ? nexDarkTheme(liquidGlass: glass)
                : nexLightTheme(liquidGlass: glass),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: NexScope(
              features: features,
              child: Scaffold(
                body: DesktopCycleView(
                  features: features,
                  clock: () => DateTime(2026, 10, 21),
                ),
              ),
            ),
          ),
        );
        final context = t.element(find.byType(DesktopCycleView));
        final l = AppLocalizations.of(context)!;
        expect(
          Directionality.of(context),
          language == 'fa' ? TextDirection.rtl : TextDirection.ltr,
        );
        await _wait(t, () => find.text(l.cyclePrivacy).evaluate().isNotEmpty);
        final remove = find.byTooltip(l.delete);
        await t.scrollUntilVisible(
          remove,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        final history = find.ancestor(
          of: remove,
          matching: find.byType(ListTile),
        );
        Future<void> openEdit() async {
          await t.ensureVisible(history);
          await t.tap(history);
          await t.pumpAndSettle();
          expect(find.byType(NexAlertDialog), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(NexAlertDialog),
              matching: find.byType(NexGlassSurface),
            ),
            glass ? findsOneWidget : findsNothing,
          );
        }

        await openEdit();
        await t.tap(find.byType(Switch));
        await t.pumpAndSettle();
        await t.tap(find.text(l.moduleCancel));
        await t.pumpAndSettle();
        Future<List<CyclePeriod>> periods() async {
          final data = await features.store
              .call<Map<String, dynamic>>('cycleSnapshot', {
                'day': DateTime(2026, 10, 21),
                'from': DateTime(2026, 10, 1),
                'to': DateTime(2026, 11, 1),
              });
          return (data['periods'] as List).cast<CyclePeriod>();
        }

        expect(
          (await t.runAsync(periods))!.single.end,
          const CycleDate(2026, 10, 16),
        );
        await openEdit();
        await t.tap(find.byType(Switch));
        await t.pump();
        await t.tap(find.text(l.save));
        await _wait(t, () => find.text(l.cycleEnd).evaluate().isNotEmpty);
        expect((await t.runAsync(periods))!.single.end, isNull);
        final typical = find.text(l.cycleTypical);
        await t.ensureVisible(typical);
        await t.tap(typical);
        await t.pumpAndSettle();
        expect(find.byType(NexAlertDialog), findsOneWidget);
        await t.tap(find.byType(DropdownButtonFormField<int>).first);
        await t.pumpAndSettle();
        await t.tap(find.text(desktopDigits(context, 29)).last);
        await t.pumpAndSettle();
        await t.tap(find.text(l.moduleCancel));
        await t.pumpAndSettle();
        expect(features.modules.typicalCycle, 28);
        await t.tap(typical);
        await t.pumpAndSettle();
        await t.tap(find.byType(DropdownButtonFormField<int>).first);
        await t.pumpAndSettle();
        await t.tap(find.text(desktopDigits(context, 29)).last);
        await t.pumpAndSettle();
        await t.tap(find.text(l.save));
        await _wait(t, () => features.modules.typicalCycle == 29);
        expect(features.modules.typicalPeriod, 5);
        await t.ensureVisible(remove);
        await t.tap(remove);
        await t.pumpAndSettle();
        expect(find.byType(NexAlertDialog), findsOneWidget);
        await t.tap(find.text(l.moduleCancel));
        await t.pumpAndSettle();
        expect((await t.runAsync(periods))!.length, 1);
        await t.tap(remove);
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilledButton, l.delete));
        await _wait(t, () => remove.evaluate().isEmpty);
        expect(await t.runAsync(periods), isEmpty);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        features.modules.privateSession.lock();
      });
    }
  }
}
