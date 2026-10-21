import 'dart:async';
import 'package:nex_core/nex_core.dart';
import '../core/controller.dart';
import 'features_state.dart';
import 'reminder_activation.dart';
import 'reminder_policy.dart';

String? noteIdFromActivation(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'nex-win' ||
      uri.host != 'note' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.pathSegments.length != 1) {
    return null;
  }
  final id = uri.pathSegments.single;
  return RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(id) ? id : null;
}

Future<void> activateNote(String uri, PanelController c, NexFeatures f) async {
  final action = ReminderActivation.parse(uri);
  if (action != null) {
    final changed = await f.store.call<bool>('reminderAction', {'uri': uri});
    if (changed) {
      for (var i = 0; i < 8; i++) {
        await c.native.cancelReminder(
          reminderOccurrenceId(action.noteId, i),
          clearDelivered: true,
        );
      }
    }
    await f.synchronizeReminders?.call();
    return;
  }
  final id = noteIdFromActivation(uri);
  if (id == null) return;
  final note = await f.store.call<Note?>('get', {'id': id});
  if (note == null) return;
  f.requestNote(note);
  if (c.isWindowMode) {
    c.selectWindowSection('library');
    await c.native.focusWindow();
  } else {
    c.open();
    c.openWidget('timeline');
    await c.native.focusWindow();
  }
}
