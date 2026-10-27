import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/commitments.dart';

class _CalculatorHost extends NativeHost {
  final launched = <String>[];
  @override
  Future<void> launch(String target) async => launched.add(target);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  test('dock, More, quick tool and window use the system calculator', () async {
    final native = _CalculatorHost();
    final c = PanelController(nativeHost: native);
    await c.bootstrap(preset: Settings(), useNative: false);
    c.onToolTap('calc');
    c.onTileTap('calc');
    c.openWidget('calc');
    c.openWindowTool('calc');
    expect(native.launched, List.filled(4, 'calc.exe'));
    expect(c.panel, isNot('calc'));
    expect(c.windowTool.value, isNot('calc'));
    c.dispose();
  });

  testWidgets(
    'editing recurring items retains imported history and timing details',
    (t) async {
      final now = DateTime(2026, 10, 24);
      final original = NexCommitment(
        id: 'synthetic-recurring',
        title: 'Old title',
        cadence: NexCadence.weeks,
        every: 2,
        dueAt: now.add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
        lead: const Duration(hours: 3),
        windowStart: 480,
        windowEnd: 1200,
        lastMetAt: now,
        metToday: 2,
        metTodayOn: '2026-10-24',
        paused: true,
        rev: 7,
        details: const {
          'weekdays': [1, 6],
          'amountMinor': 12500,
          'currency': 'IRR',
          'history': [
            {'action': 'met', 'at': '2026-10-23T00:00:00Z'},
          ],
          'noteIds': ['linked-note'],
        },
      );
      NexCommitment? saved;
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => saved = await showDialog<NexCommitment>(
                  context: context,
                  builder: (_) => NexCommitmentEditorDialog(existing: original),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'New title');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(saved!.title, 'New title');
      expect(saved!.details, original.details);
      expect(saved!.lead, original.lead);
      expect(saved!.windowStart, original.windowStart);
      expect(saved!.windowEnd, original.windowEnd);
      expect(saved!.lastMetAt, original.lastMetAt);
      expect(saved!.metToday, 2);
      expect(saved!.paused, isTrue);
      expect(saved!.rev, 8);
      expect(t.takeException(), isNull);
    },
  );
}
