import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/settings.dart';
import 'package:nex_desktop/nex/tool_organizer.dart';
import 'package:nex_desktop/ui/widgets.dart';
import 'package:nex_desktop/ui/window_caption.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Native extends NativeHost {
  final commands = <String>[];
  @override
  Future<void> windowCommand(String command) async => commands.add(command);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<PanelController> _boot(
  WidgetTester t, {
  String language = 'en',
  double width = 320,
  double scale = 1,
  bool caption = false,
}) async {
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = PanelController(nativeHost: _Native());
  await c.bootstrap(
    preset: Settings()
      ..language = language
      ..windowMode = 'panel',
    useNative: false,
  );
  await t.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1100),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: LiquidScope(
            controller: c,
            palette: c.palette,
            dir: 1,
            child: caption
                ? NexWindowCaption(controller: c)
                : const SingleChildScrollView(child: NexSettingsView()),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final language in ['en', 'fa']) {
    testWidgets(
      '$language settings directory opens bounded searchable tool placement at 200%',
      (t) async {
        final c = await _boot(t, language: language, scale: 2);
        final l = AppLocalizations.of(t.element(find.byType(NexSettingsView)))!;
        expect(find.byType(NexToolOrganizer), findsNothing);
        await t.ensureVisible(find.text(l.settingsTools).last);
        await t.tap(find.text(l.settingsTools).last);
        await t.pumpAndSettle();
        expect(find.byType(NexToolOrganizer), findsOneWidget);
        expect(find.byType(Switch), findsNothing);
        await t.enterText(find.byKey(const ValueKey('tool-search')), 'calc');
        await t.pump();
        final picker = find.byKey(const ValueKey('tool-placement-calc'));
        await t.ensureVisible(picker);
        await t.tap(picker);
        await t.pumpAndSettle();
        await t.tap(find.text(l.toolHidden).last);
        await t.pumpAndSettle();
        expect(c.S.hidden, contains('calc'));
        await t.tap(picker);
        await t.pumpAndSettle();
        await t.tap(find.text(l.toolDock).last);
        await t.pumpAndSettle();
        expect(c.S.hidden, isNot(contains('calc')));
        expect(c.S.dock, contains('calc'));
        expect(c.S.more, isNot(contains('calc')));
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'the complete caption height drags, including logo and empty corners',
    (t) async {
      final c = await _boot(t, width: 700, caption: true);
      final native = c.native as _Native;
      final rect = t.getRect(find.byType(NexWindowCaption));
      for (final point in [
        Offset(rect.left + 2, rect.top + 2),
        Offset(rect.left + 20, rect.top + 18),
        Offset(rect.right - 125, rect.bottom - 2),
        Offset(rect.center.dx, rect.bottom - 2),
      ]) {
        native.commands.clear();
        await t.dragFrom(
          point,
          const Offset(35, 0),
          kind: PointerDeviceKind.mouse,
        );
        await t.pump();
        expect(native.commands, ['drag'], reason: '$point');
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'caption controls stay on physical right in RTL and dispatch native commands',
    (t) async {
      final c = await _boot(t, language: 'fa', width: 700, caption: true);
      final l = AppLocalizations.of(t.element(find.byType(NexWindowCaption)))!;
      expect(
        t.getCenter(find.byTooltip(l.closeWindow)).dx,
        greaterThan(t.getCenter(find.byTooltip(l.minimizeWindow)).dx),
      );
      await t.tap(find.byTooltip(l.minimizeWindow));
      await t.tap(find.byTooltip(l.maximizeWindow));
      await t.tap(find.byTooltip(l.closeWindow));
      expect((c.native as _Native).commands, ['minimize', 'maximize', 'close']);
    },
  );
}
