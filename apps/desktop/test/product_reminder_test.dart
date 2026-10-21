import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/reminder_coordinator.dart';
import 'package:nex_desktop/nex/reminder_picker.dart';
import 'package:nex_desktop/nex/reminder_policy.dart';
import 'package:nex_desktop/nex/reminders.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/note_activation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Scheduler extends FakeReminderScheduler {
  int calls = 0;
  bool fail = false;
  @override
  Future<bool> schedule({
    required String id,
    required String noteId,
    required String title,
    required String body,
    required DateTime fireAt,
    int? revision,
  }) async {
    calls++;
    if (fail) return false;
    return super.schedule(
      id: id,
      noteId: noteId,
      title: title,
      body: body,
      fireAt: fireAt,
      revision: revision,
    );
  }
}

Note _note(DateTime due) => Note(
  id: 'test-reminder',
  type: NoteType.text,
  content: 'A reminder',
  dueAt: due,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  deviceId: 'test',
  rev: 1,
  syncState: SyncState.pending,
);

Future<void> _dialog(
  WidgetTester t,
  Note note,
  Future<void> Function(DateTime?, NoteRepeat) save,
) async {
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showReminderPicker(context, note: note, onSave: save),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    '09:00 survives UTC persistence, reopening and saving unchanged',
    (t) async {
      final now = DateTime.now();
      final local = DateTime(now.year, now.month, now.day + 1, 9);
      DateTime? saved;
      await _dialog(t, _note(local.toUtc()), (at, repeat) async => saved = at);
      final text = t
          .widget<Text>(find.byKey(const ValueKey('reminder-selected-time')))
          .data!;
      expect(text, contains('09:00'));
      final l = AppLocalizations.of(t.element(find.byType(AlertDialog)))!;
      await t.tap(find.text(l.reminderSet));
      await t.pumpAndSettle();
      expect(saved!.toUtc(), local.toUtc());
      expect(saved!.hour, 9);
      await _dialog(t, _note(saved!.toUtc()), (at, repeat) async {});
      expect(
        t
            .widget<Text>(find.byKey(const ValueKey('reminder-selected-time')))
            .data,
        contains('09:00'),
      );
    },
  );

  testWidgets(
    'Windows delivery failures leave a saved time visible and permit retry',
    (t) async {
      final now = DateTime.now();
      var fail = true;
      await _dialog(t, _note(now.add(const Duration(days: 1)).toUtc()), (
        at,
        repeat,
      ) async {
        if (fail) throw ReminderDeliveryFailure();
      });
      final l = AppLocalizations.of(t.element(find.byType(AlertDialog)))!;
      await t.tap(find.text(l.reminderSet));
      await t.pumpAndSettle();
      expect(find.text(l.reminderDeliveryFailed), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      fail = false;
      await t.tap(find.text(l.reminderSet));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('custom date and 24-hour input preserve 09:00', (t) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 18);
    DateTime? saved;
    await _dialog(t, _note(tomorrow.toUtc()), (at, repeat) async => saved = at);
    final l = AppLocalizations.of(t.element(find.byType(AlertDialog)))!;
    await t.tap(find.text(l.customDateTime));
    await t.pumpAndSettle();
    final date = find.byType(DatePickerDialog);
    final material = MaterialLocalizations.of(t.element(date));
    await t.tap(
      find.descendant(of: date, matching: find.text(material.okButtonLabel)),
    );
    await t.pumpAndSettle();
    final time = find.byType(TimePickerDialog);
    await t.tap(find.byTooltip(material.inputTimeModeButtonLabel));
    await t.pumpAndSettle();
    final inputs = find.descendant(of: time, matching: find.byType(TextField));
    await t.enterText(inputs.at(0), '09');
    await t.enterText(inputs.at(1), '00');
    await t.tap(
      find.descendant(of: time, matching: find.text(material.okButtonLabel)),
    );
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const ValueKey('reminder-selected-time'))).data,
      contains('09:00'),
    );
    await t.tap(find.text(l.reminderSet));
    await t.pumpAndSettle();
    expect(saved!.hour, 9);
    expect(saved!.minute, 0);
    expect(saved!.day, tomorrow.day);
  });

  testWidgets(
    'past one-off times are rejected instead of being silently changed',
    (t) async {
      var saves = 0;
      await _dialog(
        t,
        _note(DateTime.now().subtract(const Duration(hours: 1))),
        (at, repeat) async {
          saves++;
        },
      );
      final l = AppLocalizations.of(t.element(find.byType(AlertDialog)))!;
      await t.tap(find.text(l.reminderSet));
      await t.pump();
      expect(saves, 0);
      expect(find.text(l.reminderFutureRequired), findsOneWidget);
    },
  );

  test('native IDs are stable and fit the Windows 16-character limit', () {
    const id = '01991414-1122-7333-8444-001122334455';
    expect(reminderScheduleId(id).length, 15);
    expect(reminderScheduleId('0123456789abcdef').length, 15);
    expect(reminderScheduleId(id), reminderScheduleId(id));
    expect(reminderScheduleId(id), isNot(reminderScheduleId('$id-x')));
    expect(reminderScheduleId('short'), 'short');
    expect(noteIdFromActivation('nex-win://note/$id'), id);
    expect(noteIdFromActivation('https://example.org/$id'), isNull);
    expect(noteIdFromActivation('nex-win://note/%2Fetc'), isNull);
  });

  test(
    'daily and weekly repeats keep local 09:00 after multiple missed days',
    () {
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day - 20, 9).toUtc();
      for (final repeat in [NoteRepeat.daily, NoteRepeat.weekly]) {
        final next = nextReminderOccurrence(due, repeat, now);
        expect(next.isAfter(now), isTrue);
        expect(next.toLocal().hour, 9);
        expect(next.toLocal().minute, 0);
      }
    },
  );

  test(
    'runtime connects mutations, caches unchanged schedules and cancels deleted notes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'nex-reminder-runtime-',
      );
      final store = await DesktopStore.open(root.path, 'runtime');
      final scheduler = _Scheduler();
      final runtime = ReminderCoordinator(store, scheduler);
      try {
        final note = await store.call<Note>('capture', {
          'text': 'Reminder runtime',
        });
        final now = DateTime.now();
        final due = DateTime(now.year, now.month, now.day + 1, 9).toUtc();
        await store.call('remind', {
          'id': note.id,
          'at': due,
          'repeat': 'once',
        });
        await runtime.start();
        expect(scheduler.scheduled.keys.single.length, 15);
        expect(scheduler.scheduled.values.single.fireAt.toLocal().hour, 9);
        final calls = scheduler.calls;
        await runtime.refresh();
        expect(scheduler.calls, calls);
        await store.call('remind', {
          'id': note.id,
          'at': due.add(const Duration(hours: 1)),
          'repeat': 'once',
        });
        await runtime.refresh();
        expect(scheduler.scheduled.values.single.fireAt.toLocal().hour, 10);
        await store.call('delete', {'id': note.id});
        await runtime.refresh();
        expect(scheduler.scheduled, isEmpty);
      } finally {
        await runtime.close();
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'delivery acknowledgement survives restarts and a changed due time gets its own receipt',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'nex-reminder-receipts-',
      );
      final store = await DesktopStore.open(root.path, 'receipts');
      final scheduler = _Scheduler();
      final features = NexFeatures(store);
      var runtime = ReminderCoordinator(
        store,
        scheduler,
        onDeliveredChanged: features.setDeliveredReminders,
      );
      try {
        final note = await store.call<Note>('capture', {
          'text': 'Missed reminder',
        });
        await store.call('remind', {
          'id': note.id,
          'at': DateTime.now().subtract(const Duration(hours: 2)),
        });
        await runtime.start();
        expect(scheduler.overdueShown.length, 1);
        final current = (await store.call<Note?>('get', {'id': note.id}))!;
        expect(
          current.dueAt,
          isNotNull,
        ); // Snooze/Done keep the original occurrence.
        expect(features.reminderNeedsAttention(current), isFalse);
        expect(
          features.reminderNeedsAttention(
            current.copyWith(
              dueAt: current.dueAt!.add(const Duration(days: 1)),
            ),
          ),
          isTrue,
        );
        await runtime.close();
        runtime = ReminderCoordinator(
          store,
          scheduler,
          onDeliveredChanged: features.setDeliveredReminders,
        );
        await runtime.start();
        expect(scheduler.overdueShown.length, 1);
        await store.call('remind', {
          'id': note.id,
          'at': DateTime.now().subtract(const Duration(hours: 1)),
        });
        await runtime.refresh();
        expect(scheduler.overdueShown.length, 2);
      } finally {
        await runtime.close();
        await features.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'queue acceptance is not a delivery receipt; missed delivery recovers once',
    () async {
      final root = await Directory.systemTemp.createTemp('nex-missed-');
      final store = await DesktopStore.open(root.path, 'missed');
      final scheduler = _Scheduler();
      final runtime = ReminderCoordinator(store, scheduler);
      try {
        final note = await store.call<Note>('capture', {
          'text': 'Missed while asleep',
        });
        await store.call('remind', {
          'id': note.id,
          'at': DateTime.now().add(const Duration(days: 1)),
        });
        await runtime.start();
        expect(
          SharedPreferences.getInstance().then(
            (p) => p.getStringList('nex_reminder_delivered_v2'),
          ),
          completion(isEmpty),
        );
        await store.call('remind', {
          'id': note.id,
          'at': DateTime.now().subtract(const Duration(minutes: 1)),
        });
        await runtime.refresh();
        await runtime.refresh();
        expect(scheduler.overdueShown.length, 1);
      } finally {
        await runtime.close();
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );
}
