import 'dart:convert';
import 'dart:io';
import 'package:nex_core/nex_core.dart';
import '../core/native.dart';
import 'reminder_policy.dart';

/// Checks the real Windows queue with an owned future notification, then removes
/// it. No user database, preferences or existing reminders are changed.
Future<void> reminderSmoke(String output) async {
  final native = WinNativeHost();
  final noteId = newUuidV7();
  final id = reminderScheduleId(noteId);
  final now = DateTime.now();
  final result = <String, dynamic>{'id': id, 'timezone': now.timeZoneName};
  try {
    for (final hour in [9, 10]) {
      final local = DateTime(now.year, now.month, now.day + 1, hour);
      final ok = await native.scheduleReminder(
        id: id,
        noteId: noteId,
        title: 'Nex diagnostic',
        body: 'Temporary schedule verification',
        fireAt: local.toUtc(),
      );
      final matches = (await native.scheduledReminderDetails())
          .where((entry) => entry['id'] == id)
          .toList();
      final actual = matches.length == 1
          ? matches.single['fireAt'] as int
          : null;
      result['hour$hour'] = {
        'nativeError': await native.reminderDiagnosticError(),
        'scheduled': ok,
        'expectedEpoch': local.millisecondsSinceEpoch,
        'actualEpoch': actual,
        'queueEntries': matches.length,
        'localTime': actual == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(actual).toIso8601String(),
      };
      if (!ok || actual != local.millisecondsSinceEpoch) {
        throw StateError('Windows schedule did not preserve local $hour:00');
      }
    }
    result['cancelled'] = await native.cancelReminder(id);
    result['absentAfterCancel'] = !(await native.listScheduledReminders())
        .contains(id);
    result['passed'] =
        result['cancelled'] == true && result['absentAfterCancel'] == true;
  } catch (error) {
    result['passed'] = false;
    result['error'] = '$error';
  } finally {
    await native.cancelReminder(id);
    final file = File(output);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
    );
    await native.quit();
  }
}
