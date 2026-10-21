@Tags(['review'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/core/panel_settings.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/modules/module_controller.dart';
import 'package:nex_desktop/nex/modules/pdf_reader.dart';
import 'package:nex_desktop/nex/modules/vault_view.dart';
import 'package:nex_desktop/nex/modules/vault_store.dart';
import 'package:nex_desktop/nex/modules/portrait_view.dart';
import 'package:nex_desktop/nex/modules/cycle_view.dart';
import 'support/review_fixture.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

final _now = DateTime(2026, 10, 21, 12);

void main() {
  for (final module in DesktopModule.values) {
    for (final locale in ['en', 'fa']) {
      for (final dark in [false, true]) {
        for (final wide in [false, true]) {
          final name =
              'b8_${module.name}_${wide ? 'wide' : 'compact'}_${locale}_${dark ? 'dark' : 'light'}';
          testWidgets(name, (t) async {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = Size(wide ? 1000 : 460, 760);
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            FlutterSecureStorage.setMockInitialValues({});
            final store = (await t.runAsync(
              () => openReviewStore(name, count: 40),
            ))!;
            final c = PanelController(nativeHost: _Native());
            final modules = DesktopModules();
            await t.runAsync(() async {
              await c.bootstrap(
                preset: Settings()
                  ..language = locale
                  ..theme = dark ? 'dark' : 'light',
                useNative: false,
              );
              await modules.initialize();
              await modules.vault.save(
                VaultEntry(
                  id: 'private-review-fixture',
                  kind: VaultKind.password,
                  fields: {
                    'title': locale == 'fa' ? 'حساب آزمایشی' : 'Review account',
                    'password': 'synthetic-only',
                  },
                  updatedAt: _now,
                ),
              );
              final db = NexDatabase.open('${store.root.path}/nex.sqlite');
              final cycle = SqliteCycleRepository(db);
              final p = cycle.startPeriod(DateTime(2026, 10, 12));
              cycle.endPeriod(p.id, DateTime(2026, 10, 16));
              cycle.saveDay(
                const CycleDayLog(
                  day: CycleDate(2026, 10, 14),
                  mood: CycleMood.calm,
                ),
              );
              db.close();
              await store.features.intelligence.initialize();
            });
            final body = switch (module) {
              DesktopModule.pdf => DesktopPdfReader(features: store.features),
              DesktopModule.vault => DesktopVaultView(modules: modules),
              DesktopModule.portrait => DesktopPortraitView(
                features: store.features,
                statsAt: _now,
              ),
              DesktopModule.cycle => DesktopCycleView(
                features: store.features,
                clock: () => _now,
              ),
            };
            try {
              await t.pumpWidget(
                RepaintBoundary(
                  key: const ValueKey('b8-review'),
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: c.appTheme,
                    locale: Locale(locale),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: NexPanelScope(
                      controller: c,
                      child: NexScope(
                        features: store.features,
                        child: Scaffold(backgroundColor: c.appTheme.colorScheme.surface, body: body),
                      ),
                    ),
                  ),
                ),
              );
              // Let the real database isolate deliver the first snapshot.
              for (var i = 0; i < 4; i++) {
                await t.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 75)),
                );
                await t.pump();
              }
              await t.pump(const Duration(milliseconds: 300));
              expect(t.takeException(), isNull);

              await expectLater(
                find.byKey(const ValueKey('b8-review')),
                matchesGoldenFile(
                  '${const String.fromEnvironment('NEX_REVIEW_DIRECTORY', defaultValue: 'review_goldens')}/$name.png',
                ),
              );
              // The same surfaces at the minimum window and 2x text, without
              // another redundant image matrix. Layout exceptions still fail.
              t.view.physicalSize = const Size(380, 520);
              await t.pumpWidget(
                RepaintBoundary(
                  key: const ValueKey('b8-review'),
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: c.appTheme,
                    locale: Locale(locale),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(2)),
                      child: child!,
                    ),
                    home: NexPanelScope(
                      controller: c,
                      child: NexScope(
                        features: store.features,
                        child: Scaffold(backgroundColor: c.appTheme.colorScheme.surface, body: body),
                      ),
                    ),
                  ),
                ),
              );
              await t.pump();
              expect(t.takeException(), isNull);
            } finally {
              await t.pumpWidget(const SizedBox());
              modules.dispose();
              c.dispose();
              await closeReviewStore(t, store);
            }
          });
        }
      }
    }
  }
}
