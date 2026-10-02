import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:right_panel/core/controller.dart';
import 'package:right_panel/core/world_clock.dart';
import 'package:right_panel/main.dart';
import 'package:right_panel/ui/dock.dart';
import 'package:right_panel/ui/flyout.dart';

Future<void> frames(WidgetTester t, [int count = 90]) async {
  for (var i = 0; i < count; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<PanelController> boot(
  WidgetTester t,
  String edge, {
  double height = 680,
}) async {
  t.view.physicalSize = Size(480, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = PanelController();
  await c.bootstrap(
    preset: Settings()
      ..edge = edge
      ..language = 'fa',
    useNative: false,
  );
  await t.pumpWidget(RightPanelApp(controller: c));
  c.open();
  await frames(t);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
  return c;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test(
    'clock positive, negative, half hour, DST and month/year boundaries',
    () {
      final utc = tz.getLocation('UTC');
      final summer = DateTime.utc(2026, 7, 1, 1);
      expect(
        worldClock(
          summer,
          tz.getLocation('America/New_York'),
          localZone: utc,
        ).offset.inHours,
        -4,
      );
      expect(
        worldClock(
          DateTime.utc(2026, 1, 1),
          tz.getLocation('America/New_York'),
          localZone: utc,
        ).offset.inHours,
        -5,
      );
      expect(
        worldClock(
          summer,
          tz.getLocation('Asia/Tehran'),
          localZone: utc,
        ).offset.inMinutes,
        210,
      );
      expect(
        worldClock(
          summer,
          tz.getLocation('Asia/Kolkata'),
          localZone: utc,
        ).offset.inMinutes,
        330,
      );
      expect(
        worldClock(
          DateTime.utc(2026, 1, 1, 1),
          tz.getLocation('America/New_York'),
          localZone: utc,
        ).day,
        -1,
      );
      expect(
        worldClock(
          DateTime.utc(2026, 12, 31, 22),
          tz.getLocation('Asia/Tehran'),
          localZone: utc,
        ).day,
        1,
      );
      expect(worldClock(summer, utc, localZone: utc).day, 0);
    },
  );
  for (final edge in ['right', 'left']) {
    testWidgets('$edge physical edge survives Persian RTL; flyout is inward', (
      t,
    ) async {
      final c = await boot(t, edge);
      c.setPanel('emoji');
      await frames(t);
      final dock = t.getRect(find.byType(Dock));
      final fly = c.flyRect!;
      if (edge == 'right') {
        expect(dock.right, closeTo(480, .1));
        expect(fly.right, lessThan(dock.left));
      } else {
        expect(dock.left, closeTo(0, .1));
        expect(fly.left, greaterThan(dock.right));
      }
      final transform = t
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(Flyout),
              matching: find.byType(Transform),
            ),
          )
          .firstWhere((e) => e.alignment != null);
      expect(
        transform.alignment,
        edge == 'left' ? Alignment.centerLeft : Alignment.centerRight,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/${edge}_shell.png'),
      );
      c.dropHintOn.value = true;
      await frames(t);
      final hint = t.getRect(find.byKey(const ValueKey('capture-drop-hint')));
      expect(hint.left, closeTo(edge == 'left' ? 90 : 170, .1));
      expect(hint.width, 220);
    });
  }
  testWidgets(
    'real flyout height anchors and clamps different content heights',
    (t) async {
      final c = await boot(t, 'right');
      c.anchorY = 660;
      c.setPanel('calc');
      await frames(t);
      final small = c.flyH;
      expect(small, greaterThan(30));
      expect(c.fy.t, closeTo(680 - small / 2 - 10, 1));
      c.setPanel('emoji');
      await frames(t);
      expect(c.flyH, isNot(closeTo(small, 1)));
      expect(c.fy.t, closeTo(680 - c.flyH / 2 - 10, 1));
      expect(c.flyRect!.bottom, lessThanOrEqualTo(680.5));
      c.setPanel('calc');
      await frames(t);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/calculator_height.png'),
      );
    },
  );
  testWidgets('short window dock scrolls without overflow', (t) async {
    final c = await boot(t, 'left', height: 260);
    expect(t.getSize(find.byType(Dock)).height, lessThan(260));
    expect(c.toolScroll.position.maxScrollExtent, greaterThan(0));
    c.setPanel('more');
    await frames(t);
    expect(c.flyH, lessThanOrEqualTo(240));
    expect(t.takeException(), isNull);
  });
}
