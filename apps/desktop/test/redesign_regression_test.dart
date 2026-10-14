import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/core/registry.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

/// Regressions found and fixed in the 0.13.0 Android-parity redesign review.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a stale persisted tool id resolves to a ghost instead of crashing', () {
    // Dock/more lists are stored verbatim. A tool renamed or removed across
    // versions used to leave an id that `ToolInfo.of` null-checked
    // (`kTools[id]!`), taking the whole Tools section down with it.
    final info = ToolInfo.of('no-such-tool-anymore');
    expect(info.id, 'no-such-tool-anymore');
    expect(info.name, isNotEmpty);
    expect(info.kind, ToolKind.panel);
    // Real tools still resolve as before.
    final real = ToolInfo.of('clip');
    expect(real.kind, ToolKind.panel);
    expect(real.name, isNotEmpty);
  });

  testWidgets('the window shell paints its wave backdrop behind the page', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = PanelController(nativeHost: _Native());
    await c.bootstrap(
      preset: Settings()
        ..windowMode = 'window'
        ..language = 'en',
      useNative: false,
    );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
    await t.pumpWidget(RightPanelApp(controller: c));
    await t.pump();
    expect(find.byType(NexTextureBackdrop), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the compact selection banner fits a flyout-width window', (
    t,
  ) async {
    // Four banner actions plus a count used to be full-size IconButtons with
    // a Spacer between; in the edge flyout's width, or with large text, that
    // row overflowed. The compact banner must survive a 360px window.
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late Directory root;
    late NexFeatures features;
    await t.runAsync(() async {
      root = await Directory.systemTemp.createTemp('nex-banner-test-');
      final db = NexDatabase.open('${root.path}/nex.sqlite');
      final repo = SqliteNoteRepository(db);
      final now = DateTime.now().toUtc();
      for (var i = 0; i < 3; i++) {
        repo.insert(
          Note(
            id: 'banner-$i',
            type: NoteType.text,
            content: 'Banner note $i',
            createdAt: now,
            updatedAt: now,
            deviceId: 'test',
            rev: 1,
            syncState: SyncState.pending,
          ),
        );
      }
      db.close();
      features = NexFeatures(await DesktopStore.open(root.path, 'banner'));
    });
    final c = PanelController(nativeHost: _Native());
    await c.bootstrap(
      preset: Settings()
        ..windowMode = 'window'
        ..language = 'en',
      useNative: false,
    );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      c.dispose();
      await t.runAsync(() async {
        await features.close();
        await root.delete(recursive: true);
      });
    });
    await t.pumpWidget(RightPanelApp(controller: c, features: features));
    c.selectWindowSection('library');
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 50));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    await t.pump(const Duration(milliseconds: 300));
    // Enter selection mode with a control-click on the first card. The
    // banner appears in place of the ordinary header row; any overflow in it
    // surfaces as a RenderFlex exception on this 360px-wide surface.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.tap(find.byType(NoteCard).first);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 50));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    expect(t.takeException(), isNull);
    expect(find.byIcon(Icons.push_pin_outlined), findsWidgets);
  });
}
