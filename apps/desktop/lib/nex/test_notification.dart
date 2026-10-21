import '../core/controller.dart';
import '../l10n/app_localizations.dart';

/// One toast now, one queued with Windows for 15 seconds later — the two
/// ways reminders reach the screen — and Windows' own reason if it refuses.
Future<void> sendDesktopTestNotification(
  PanelController c,
  AppLocalizations l,
) async {
  final native = c.native;
  var shown = false, queued = false;
  try {
    shown = await native.showOverdueReminder(
      id: 'nextest',
      noteId: '',
      title: l.applicationName,
      body: l.testNotificationBody,
    );
    queued = await native.scheduleReminder(
      id: 'nextest2',
      noteId: '',
      title: l.applicationName,
      body: l.testNotificationLater,
      fireAt: DateTime.now().add(const Duration(seconds: 15)),
    );
  } catch (_) {}
  if (shown && queued) {
    c.toast(l.testNotificationSent);
    return;
  }
  String? why;
  try {
    why = await native.reminderDiagnosticError();
  } catch (_) {}
  c.toast(
    l.testNotificationFailed(why == null || why.isEmpty ? '' : ' ($why)'),
  );
}
