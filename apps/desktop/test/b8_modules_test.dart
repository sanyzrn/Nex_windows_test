import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/modules/module_controller.dart';
import 'package:nex_desktop/nex/modules/private_session.dart';
import 'package:nex_desktop/nex/modules/private_gate.dart';
import 'package:nex_desktop/nex/modules/vault_store.dart';
import 'package:nex_desktop/nex/modules/pdf_reader.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'modules start off; switches persist independently and keep vault data',
    () async {
      final modules = DesktopModules();
      addTearDown(modules.dispose);
      await modules.initialize();
      expect(DesktopModule.values.any(modules.enabled), isFalse);
      await modules.setEnabled(DesktopModule.vault, true);
      final entry = VaultEntry(
        id: 'synthetic',
        kind: VaultKind.message,
        fields: {'title': 'Private fixture', 'message': 'Synthetic only'},
        updatedAt: DateTime(2026),
      );
      await modules.vault.save(entry);
      await modules.setEnabled(DesktopModule.vault, false);
      await modules.setEnabled(DesktopModule.pdf, true);
      final reopened = DesktopModules();
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.enabled(DesktopModule.pdf), isTrue);
      expect(reopened.enabled(DesktopModule.vault), isFalse);
      expect(reopened.enabled(DesktopModule.cycle), isFalse);
      expect((await reopened.vault.read()).entries.single.id, entry.id);
    },
  );
  test(
    'private tools share one unlock; expired activity cannot reopen it',
    () async {
      var now = DateTime(2026);
      var calls = 0;
      final session = DesktopPrivateSession(
        clock: () => now,
        authenticate: (_) async {
          calls++;
          return true;
        },
      );
      addTearDown(session.dispose);
      expect(await session.unlock('first tool'), isTrue);
      now = now.add(const Duration(seconds: 90));
      expect(await session.unlock('second tool'), isTrue);
      expect(calls, 1);
      now = now.add(const Duration(minutes: 2));
      session.touch();
      expect(session.isOpen, isFalse);
      expect(session.remaining, Duration.zero);
      expect(await session.unlock('again'), isTrue);
      expect(calls, 2);
    },
  );
  test(
    'cancelled authentication and a stale pending unlock fail closed',
    () async {
      final answer = Completer<bool>();
      var calls = 0;
      final session = DesktopPrivateSession(
        authenticate: (_) {
          calls++;
          return answer.future;
        },
      );
      addTearDown(session.dispose);
      final first = session.unlock('one');
      final second = session.unlock('two');
      expect(calls, 1);
      session.lock();
      answer.complete(true);
      expect(await first, isFalse);
      expect(await second, isFalse);
      expect(session.isOpen, isFalse);
      final cancelled = DesktopPrivateSession(authenticate: (_) async => false);
      addTearDown(cancelled.dispose);
      expect(await cancelled.unlock('cancelled'), isFalse);
    },
  );
  test(
    'vault serializes drafts and saves; corruption is never overwritten',
    () async {
      final store = VaultStore();
      VaultEntry entry(String id) => VaultEntry(
        id: id,
        kind: VaultKind.password,
        fields: {'title': id, 'password': 'synthetic-password'},
        updatedAt: DateTime(2026),
      );
      await Future.wait([
        store.save(entry('one')),
        store.save(entry('two')),
        store.saveDraft(entry('draft')),
      ]);
      expect((await store.read()).entries.length, 2);
      await store.save(entry('draft'));
      expect((await store.read()).draft, isNull);
      expect((await store.read()).entries.length, 3);
      const secure = FlutterSecureStorage();
      await secure.write(key: VaultStore.storageKey, value: 'corrupt fixture');
      await expectLater(store.read(), throwsA(isA<FormatException>()));
      await expectLater(
        store.save(entry('three')),
        throwsA(isA<FormatException>()),
      );
      expect(await secure.read(key: VaultStore.storageKey), 'corrupt fixture');
    },
  );
  test(
    'cycle commands preserve Android fields and stay outside note search/portrait',
    () async {
      final root = await Directory.systemTemp.createTemp('nex-b8-test-');
      final store = await DesktopStore.open(root.path, 'b8-test');
      try {
        final day = DateTime(2026, 10, 12);
        final period = await store.call<CyclePeriod>('cycleStart', {
          'day': day,
        });
        await store.call<void>('cycleEnd', {
          'id': period.id,
          'day': day.add(const Duration(days: 4)),
        });
        final log = CycleDayLog(
          day: CycleDate.of(day),
          symptoms: {CycleSymptom.cramps},
          note: 'synthetic-private-observation',
          temperature: 36.5,
          ovulationTest: CycleOvulationTest.negative,
        );
        await store.call<void>('cycleDay', {'log': log});
        await store.call<void>('cycleDay', {
          'log': log.copyWith(mood: () => CycleMood.calm),
        });
        final snapshot = await store.call<Map<String, dynamic>>(
          'cycleSnapshot',
          {'day': day, 'from': day, 'to': day},
        );
        expect((snapshot['log'] as CycleDayLog).temperature, 36.5);
        expect(
          (snapshot['log'] as CycleDayLog).ovulationTest,
          CycleOvulationTest.negative,
        );
        expect(
          (snapshot['periods'] as List<CyclePeriod>).single.end,
          CycleDate(2026, 10, 16),
        );
        expect(
          await store.call<List<Note>>('search', {
            'filters': const SearchFilters(
              query: 'synthetic-private-observation',
            ),
          }),
          isEmpty,
        );
        expect(await store.call<List<Note>>('portraitNotes'), isEmpty);
        await store.close();
        final db = NexDatabase.open('${root.path}/nex.sqlite');
        expect(db.db.select('PRAGMA user_version').single.values.single, 1);
        expect(SqliteCycleRepository(db).day(day)?.mood, CycleMood.calm);
        db.close();
      } finally {
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets('lock and blur remove private semantics and nested dialogs', (
    t,
  ) async {
    var now = DateTime(2026);
    final session = DesktopPrivateSession(
      clock: () => now,
      authenticate: (_) async => true,
    );
    await session.unlock('synthetic');
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DesktopPrivateGate(
            session: session,
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                useRootNavigator: false,
                builder: (_) =>
                    const AlertDialog(content: Text('synthetic-dialog-secret')),
              ),
              child: const Text('synthetic-private-value'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('synthetic-private-value'));
    await t.pumpAndSettle();
    expect(find.text('synthetic-dialog-secret'), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    expect(find.text('synthetic-dialog-secret'), findsNothing);
    expect(find.text('synthetic-private-value'), findsNothing);
    expect(session.isOpen, isTrue);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(find.text('synthetic-private-value'), findsOneWidget);
    now = now.add(const Duration(minutes: 2));
    await t.pump(const Duration(minutes: 2));
    expect(find.text('synthetic-private-value'), findsNothing);
    await t.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets('PDF page picker reaches a distant page without a slider', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: DesktopPdfPagePicker(count: 100, current: 80),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
    expect(find.text('80'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  test(
    'vault format rejects duplicates and keeps the Android v1 entry shape',
    () {
      final entry = VaultEntry(
        id: 'one',
        kind: VaultKind.card,
        fields: {'title': 'Synthetic card', 'number': '4111111111111111'},
        updatedAt: DateTime(2026),
      );
      final encoded =
          jsonDecode(jsonEncode(VaultSnapshot([entry], null).toJson()))
              as Map<String, dynamic>;
      expect(
        VaultSnapshot.fromJson(encoded).entries.single.value('number'),
        '4111111111111111',
      );
      expect(
        () => VaultSnapshot.fromJson({
          ...encoded,
          'entries': [entry.toJson(), entry.toJson()],
        }),
        throwsFormatException,
      );
      expect(validVaultCard('۴۱۱۱ ۱۱۱۱ ۱۱۱۱ ۱۱۱۱'), isTrue);
    },
  );
}
