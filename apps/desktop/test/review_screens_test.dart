// WP2.2 review harness — renders the full screen matrix that backs the
// design audit (design/UI_AUDIT.md). Every shot lands in
// test/review_goldens/<name>.png; copy the folder to design/before (rendered
// at the baseline commit) or design/after (rendered after the work).
//
//   flutter test --tags review
//
// The same harness compiles against the baseline snapshot, so the before and
// after matrices use identical file names and identical viewports.
@Tags(['review'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/models.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_ui/nex_ui.dart';

class _FakeNative extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Future<void> _frames(WidgetTester t, [int count = 180]) async {
  for (var i = 0; i < count; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

final _day = DateTime(2026, 10, 4, 10, 4);

Note _note(int i) {
  const kinds = [NoteType.text, NoteType.checklist, NoteType.link];
  final kind = kinds[i % kinds.length];
  final body = switch (kind) {
    NoteType.checklist => '[ ] Standup at 10:0$i\n[x] Review pull request',
    NoteType.link => 'https://example.com/article-$i',
    _ => 'Review note $i — team meeting moved to 10:0$i',
  };
  final at = _day.subtract(Duration(minutes: i * 7));
  return Note(
    id: 'review-$i',
    type: kind,
    content: body,
    createdAt: at,
    updatedAt: at,
    deviceId: 'review-device',
    rev: 1,
    syncState: SyncState.pending,
    pinnedAt: i % 7 == 0 ? at : null,
  );
}

class _Store with _StoreCleanup {
  final NexFeatures features;
  final Directory root;
  _Store(this.features, this.root);
}

mixin _StoreCleanup {}

Future<_Store> _openStore(String name, {int count = 0}) async {
  final root = await Directory.systemTemp.createTemp('nex-review-$name-');
  final db = NexDatabase.open('${root.path}/nex.sqlite');
  final repo = SqliteNoteRepository(db);
  for (var i = 0; i < count; i++) {
    repo.insert(_note(i));
    if (i % 7 == 0) repo.pinNote('review-$i');
  }
  db.close();
  final features = NexFeatures(await DesktopStore.open(root.path, name));
  return _Store(features, root);
}

class _Shot {
  final String name;
  final String locale;
  final String theme;
  final String preset;
  final String mode;
  final Size size;
  final String target;
  final int notes;
  final double textScale;
  final String edge;
  const _Shot(
    this.name, {
    this.locale = 'en',
    this.theme = 'light',
    this.preset = 'classic',
    this.mode = 'panel',
    this.size = const Size(480, 680),
    this.target = 'note',
    this.notes = 12,
    this.textScale = 1.0,
    this.edge = 'right',
  });
}

const _matrix = <_Shot>[
  _Shot(
    'settings_tools_panel_dark_fa',
    locale: 'fa',
    theme: 'dark',
    target: 'toolsSettings',
  ),
  _Shot('settings_tools_panel_light_en', target: 'toolsSettings'),
  _Shot(
    'settings_tools_window_dark_fa',
    locale: 'fa',
    theme: 'dark',
    target: 'toolsSettings',
    mode: 'window',
    size: Size(1200, 800),
  ),
  _Shot(
    'settings_tools_window_fa_scale2',
    locale: 'fa',
    theme: 'dark',
    target: 'toolsSettings',
    mode: 'window',
    size: Size(700, 900),
    textScale: 2,
  ),
  _Shot(
    'product_clipboard_dark_fa',
    locale: 'fa',
    theme: 'dark',
    target: 'clip',
  ),
  _Shot('product_clipboard_light_en', target: 'clip'),
  // Desktop redesign: full-size writing, RTL, large type and secondary flows.
  _Shot(
    'redesign_window_capture_1200_light_en',
    mode: 'window',
    size: Size(1200, 800),
  ),
  _Shot(
    'redesign_window_capture_1600_dark_en',
    mode: 'window',
    size: Size(1600, 1000),
    theme: 'dark',
  ),
  _Shot(
    'redesign_window_capture_700_light_fa_scale2',
    mode: 'window',
    size: Size(700, 900),
    locale: 'fa',
    textScale: 2,
  ),
  _Shot(
    'redesign_window_tools_1200_dark_fa',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    theme: 'dark',
    target: 'more',
  ),
  _Shot(
    'redesign_window_tools_700_light_fa_scale2',
    mode: 'window',
    size: Size(700, 900),
    locale: 'fa',
    textScale: 2,
    target: 'more',
  ),
  _Shot(
    'redesign_window_settings_1200_light_en_appearance',
    mode: 'window',
    size: Size(1200, 800),
    target: 'appearance',
  ),
  _Shot(
    'redesign_window_settings_1200_dark_fa_backup',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    theme: 'dark',
    target: 'backup',
  ),
  _Shot(
    'redesign_window_settings_700_dark_fa_scale2',
    mode: 'window',
    size: Size(700, 900),
    locale: 'fa',
    theme: 'dark',
    textScale: 2,
    target: 'settings',
  ),
  _Shot(
    'redesign_window_palette_1200_dark_fa',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    theme: 'dark',
    target: 'palette',
  ),
  _Shot(
    'redesign_capture_panel_left_dark_fa_scale2',
    locale: 'fa',
    theme: 'dark',
    edge: 'left',
    textScale: 2,
  ),
  // Panel, right edge, both languages, both themes — the primary audit grid.
  _Shot('capture_panel_right_light_en'),
  _Shot('capture_panel_right_dark_en', theme: 'dark'),
  _Shot('capture_panel_right_light_fa', locale: 'fa'),
  _Shot('capture_panel_right_dark_fa', locale: 'fa', theme: 'dark'),
  _Shot('timeline_panel_right_light_en', target: 'timeline'),
  _Shot(
    'timeline_panel_right_dark_fa',
    target: 'timeline',
    locale: 'fa',
    theme: 'dark',
  ),
  _Shot('reader_panel_right_light_en', target: 'reader'),
  _Shot(
    'reader_panel_right_dark_fa',
    target: 'reader',
    locale: 'fa',
    theme: 'dark',
  ),
  _Shot('settings_panel_right_light_en', target: 'settings'),
  _Shot(
    'settings_panel_right_dark_fa',
    target: 'settings',
    locale: 'fa',
    theme: 'dark',
  ),
  _Shot('emoji_panel_right_dark_en', target: 'emoji', theme: 'dark'),
  _Shot('more_panel_right_light_fa', target: 'more', locale: 'fa'),
  _Shot('color_panel_right_dark_en', target: 'color', theme: 'dark'),
  // Left edge and large text: the two regression-prone frame conditions.
  _Shot('capture_panel_left_light_en', edge: 'left'),
  _Shot('capture_panel_right_light_en_scale15', textScale: 1.5),
  // Desktop window at the three widths called out by the task.
  _Shot(
    'window_capture_1200_dark_fa',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    theme: 'dark',
  ),
  _Shot(
    'window_library_700_light_en',
    mode: 'window',
    size: Size(700, 900),
    target: 'timeline',
  ),
  _Shot(
    'window_library_1200_dark_en',
    mode: 'window',
    size: Size(1200, 800),
    theme: 'dark',
    target: 'timeline',
  ),
  _Shot(
    'window_library_1600_light_fa',
    mode: 'window',
    size: Size(1600, 1000),
    locale: 'fa',
    target: 'timeline',
  ),
  _Shot(
    'window_reader_1200_dark_en',
    mode: 'window',
    size: Size(1200, 800),
    theme: 'dark',
    target: 'reader',
  ),
  _Shot(
    'window_settings_700_light_fa',
    mode: 'window',
    size: Size(700, 900),
    locale: 'fa',
    target: 'settings',
  ),
  _Shot(
    'window_tools_1200_light_en',
    mode: 'window',
    size: Size(1200, 800),
    target: 'more',
  ),
  _Shot(
    'window_library500_1200_light_en',
    mode: 'window',
    size: Size(1200, 800),
    target: 'timeline',
    notes: 500,
  ),
  _Shot(
    'window_library_1200_light_fa_scale15',
    mode: 'window',
    size: Size(1200, 800),
    locale: 'fa',
    target: 'timeline',
    textScale: 1.5,
  ),
  // At least four panel presets, dark, English.
  _Shot('preset_classic_panel_dark_en', theme: 'dark'),
  _Shot('preset_autumn_panel_dark_en', theme: 'dark', preset: 'autumn'),
  _Shot('preset_midnight_panel_dark_en', theme: 'dark', preset: 'midnight'),
  _Shot('preset_ocean_panel_dark_en', theme: 'dark', preset: 'ocean'),
];

Future<PanelController> _boot(WidgetTester t, _Shot spec, _Store store) async {
  t.view.physicalSize = spec.size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.textScaleFactorTestValue = spec.textScale;
  addTearDown(() {
    t.platformDispatcher.textScaleFactorTestValue = 1.0;
  });
  final c = PanelController(nativeHost: _FakeNative());
  await c.bootstrap(
    preset: Settings()
      ..windowMode = spec.mode
      ..language = spec.locale
      ..theme = spec.theme
      ..preset = spec.preset
      ..edge = spec.edge,
    useNative: false,
  );
  c.open();
  if (spec.target == 'clip') {
    c.clips = [
      ClipEntry.text(
        spec.locale == 'fa'
            ? 'متن بلند فارسی برای بررسی فاصلهٔ دکمه‌های علاقه‌مندی و حذف در کلیپ‌بورد'
            : 'A long clipboard item with favorite and delete controls beside the text',
        time: DateTime.now(),
      ),
      ClipEntry.text('https://example.com/notes/windows', time: DateTime.now()),
    ];
  }
  await t.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('review-surface'),
      child: RightPanelApp(controller: c, features: store.features),
    ),
  );
  await _frames(t);
  return c;
}

/// Navigates to [spec.target] in whichever mode is active and settles springs.
Future<void> _go(WidgetTester t, PanelController c, _Shot spec) async {
  final window = spec.mode == 'window';
  switch (spec.target) {
    case 'timeline' || 'reader':
      window ? c.selectWindowSection('library') : c.openWidget('timeline');
    case 'settings' || 'appearance' || 'backup' || 'toolsSettings':
      window ? c.selectWindowSection('settings') : c.openWidget('settings');
    case 'more':
      window ? c.selectWindowSection('tools') : c.openWidget('more');
    case 'emoji' || 'color' || 'note' || 'palette' || 'clip':
      c.openWidget(spec.target == 'palette' ? 'note' : spec.target);
  }
  await _frames(t, 90);
  if (spec.target == 'toolsSettings') {
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    if (!window) {
      await t.tap(find.byKey(const ValueKey('settings-category')));
      await _frames(t, 45);
    }
    await t.tap(find.text(l.settingsTools).last);
    await _frames(t, 90);
  }
  if (spec.target == 'appearance' || spec.target == 'backup') {
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    await t.tap(
      find.text(
        spec.target == 'appearance' ? l.settingsAppearance : l.settingsBackup,
      ),
    );
    await t.pumpAndSettle();
  }
  if (spec.target == 'palette') {
    await t.tap(find.byKey(const ValueKey('workspace-command')));
    await t.pumpAndSettle();
  }
  if (window || spec.target == 'timeline' || spec.target == 'reader') {
    // The library view loads its first page from the store isolate.
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 75));
      });
      await t.pump();
    }
    await _frames(t);
  }
  if (spec.target == 'reader') {
    await t.tap(find.byType(NoteCard).first);
    await _frames(t);
    expect(find.byType(NexNoteDetail), findsOneWidget);
  }
}

void main() {
  for (final spec in _matrix) {
    testWidgets('review: ${spec.name}', (t) async {
      final store = (await t.runAsync(
        () => _openStore(spec.name, count: spec.notes),
      ))!;
      final c = await _boot(t, spec, store);
      await _go(t, c, spec);
      // Audit defect 14: with the default debug flag tests draw shadows as
      // solid slabs. The review matrix must show the shadows that ship. The
      // flag is restored inside the body so the framework's debug invariant
      // (checked before tearDown) still holds.
      debugDisableShadows = false;
      try {
        await expectLater(
          find.byKey(const ValueKey('review-surface')),
          matchesGoldenFile('review_goldens/${spec.name}.png'),
        );
      } finally {
        debugDisableShadows = true;
      }
      await t.pumpWidget(const SizedBox());
      c.dispose();
      await t.runAsync(() async {
        await store.features.close();
        await store.root.delete(recursive: true);
      });
      expect(t.takeException(), isNull);
    });
  }
}
