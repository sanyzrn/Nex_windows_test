import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/main.dart';

class _Native extends NativeHost {
  _Native({this.accept = true});
  final bool accept;
  final shown = <String>[];
  final queued = <String>[];
  @override
  Future<bool> showOverdueReminder({
    required String id,
    required String noteId,
    required String title,
    required String body,
    DateTime? occurrence,
  }) async {
    shown.add(body);
    return accept;
  }

  @override
  Future<bool> scheduleReminder({
    required String id,
    required String noteId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    queued.add(body);
    return accept;
  }

  @override
  Future<String?> reminderDiagnosticError() async => 'setting: blocked';
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<(PanelController, _Native)> _boot(
  WidgetTester t, {
  bool accept = true,
}) async {
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final native = _Native(accept: accept);
  final c = PanelController(nativeHost: native);
  await c.bootstrap(
    preset: Settings()..windowMode = 'window',
    useNative: false,
  );
  c.open();
  await t.pumpWidget(RightPanelApp(controller: c));
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
  c.selectWindowSection('settings');
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('settings-open-0')));
  await t.pumpAndSettle();
  return (c, native);
}

void main() {
  testWidgets('test notification sends one now and one queued', (t) async {
    final (c, native) = await _boot(t);
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    final button = find.byKey(const ValueKey('test-notification'));
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pump();
    expect(native.shown, [l.testNotificationBody]);
    expect(native.queued, [l.testNotificationLater]);
    expect(c.toastMsg.value?.split('\x00').first, l.testNotificationSent);
    await t.pumpAndSettle(const Duration(seconds: 4));
    expect(t.takeException(), isNull);
  });

  testWidgets('a refused test shows Windows\' own reason', (t) async {
    final (c, _) = await _boot(t, accept: false);
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    final button = find.byKey(const ValueKey('test-notification'));
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pump();
    expect(
      c.toastMsg.value?.split('\x00').first,
      l.testNotificationFailed(' (setting: blocked)'),
    );
    await t.pumpAndSettle(const Duration(seconds: 4));
    expect(t.takeException(), isNull);
  });
}
