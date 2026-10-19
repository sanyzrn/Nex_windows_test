import 'dart:async';
import 'dart:convert';
import 'package:nex_core/nex_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reminders.dart';
import 'reminder_policy.dart';
import 'store.dart';

class ReminderDeliveryFailure implements Exception {}

/// Serial reconciliation across startup, note mutations and repeat rollover.
class ReminderCoordinator {
  ReminderCoordinator(
    this.store,
    ReminderScheduler scheduler, {
    this.onFailureChanged,
  }) : _scheduler = _TrackedScheduler(scheduler);
  final DesktopStore store;
  final _TrackedScheduler _scheduler;
  final void Function(bool failed)? onFailureChanged;
  SharedPreferences? _prefs;
  StreamSubscription<void>? _changes;
  Timer? _timer;
  Future<void> _tail = Future.value();
  bool _closed = false;

  Future<void> start() async {
    _prefs = await SharedPreferences.getInstance();
    _scheduler.receipts.addAll(
      _prefs!.getStringList('nex_reminder_receipts') ?? [],
    );
    _changes = store.reminderChanges.listen((_) => unawaited(refresh()));
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(refresh()),
    );
    await refresh();
  }

  Future<ReconciliationSummary> refresh() {
    final task = _tail.then((_) async {
      if (_closed) {
        return const ReconciliationSummary(
          scheduledCount: 0,
          cancelledCount: 0,
          overdueCount: 0,
        );
      }
      try {
        final notes = await store.call<List<Note>>('reminderCandidates');
        final result = await ReminderReconciliationEngine.reconcileNotes(
          notes: notes,
          scheduler: _scheduler,
          notifiedOverdueIds: _scheduler.receipts,
        );
        await _prefs?.setStringList(
          'nex_reminder_receipts',
          _scheduler.receipts.toList().reversed.take(2048).toList(),
        );
        onFailureChanged?.call(result.failedCount > 0);
        return result;
      } catch (_) {
        onFailureChanged?.call(true);
        return const ReconciliationSummary(
          scheduledCount: 0,
          cancelledCount: 0,
          overdueCount: 0,
          failedCount: 1,
        );
      }
    });
    _tail = task.then<void>((_) {});
    return task;
  }

  Future<void> close() async {
    _closed = true;
    _timer?.cancel();
    await _changes?.cancel();
    await _tail;
  }
}

class _TrackedScheduler implements ReminderScheduler {
  _TrackedScheduler(this.delegate);
  final ReminderScheduler delegate;
  final receipts = <String>{};
  final _signatures = <String, String>{};
  Set<String> _scheduled = {};

  @override
  Future<Set<String>> listScheduledIds() async =>
      _scheduled = await delegate.listScheduledIds();

  @override
  Future<bool> schedule({
    required String id,
    required String noteId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    final signature = jsonEncode([fireAt.millisecondsSinceEpoch, title, body]);
    if (_scheduled.contains(id) && _signatures[id] == signature) return true;
    if (_scheduled.contains(id) && !await delegate.cancel(id)) return false;
    final success = await delegate.schedule(
      id: id,
      noteId: noteId,
      title: title,
      body: body,
      fireAt: fireAt,
    );
    if (success) {
      _signatures[id] = signature;
      _scheduled.add(id);
    }
    return success;
  }

  @override
  Future<bool> cancel(String id) async {
    final success = await delegate.cancel(id);
    if (success) {
      _scheduled.remove(id);
      _signatures.remove(id);
    }
    return success;
  }

  @override
  Future<bool> showOverdue({
    required String id,
    required String noteId,
    required String title,
    required String body,
    DateTime? occurrence,
  }) => delegate.showOverdue(
    id: id,
    noteId: noteId,
    title: title,
    body: body,
    occurrence: occurrence,
  );
}
