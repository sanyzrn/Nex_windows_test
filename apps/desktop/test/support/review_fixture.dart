import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nex_desktop/nex/intelligence/controller.dart';

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

class ReviewStore with ReviewStoreCleanup {
  final NexFeatures features;
  final Directory root;
  ReviewStore(this.features, this.root);
}

mixin ReviewStoreCleanup {}

class _PreviewSecrets implements AiSecrets {
  @override
  Future<String?> read(String key) async =>
      key.endsWith('.custom') ? 'preview-only' : null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

Future<ReviewStore> openReviewStore(String name, {int count = 0}) async {
  SharedPreferences.setMockInitialValues({
    if (name.startsWith('intelligence_configured')) ...{
      'ai.enabled': true,
      'ai.cloud_opt_in': true,
      'ai.provider': 'custom',
      'ai.baseUrl.custom': 'https://example.test/v1/chat/completions',
      'ai.model.custom': 'gemini-3.5-flash-lite',
      'ai.images.custom': 'enabled',
      'ai.audio.custom': 'enabled',
      'ai.embeddings.custom': 'enabled',
    },
  });
  final root = await Directory.systemTemp.createTemp('nex-review-$name-');
  final db = NexDatabase.open('${root.path}/nex.sqlite');
  final repo = SqliteNoteRepository(db);
  for (var i = 0; i < count; i++) {
    repo.insert(_note(i));
    if (i % 7 == 0 && repo.pinNote('review-$i')) {
      // Windows clock ticks can tie between inserts and change pin ordering.
      // Keep the fixture order independent of runner speed and wall time.
      db.db.execute('UPDATE notes SET pinned_at = ? WHERE id = ?', [
        _day.add(Duration(minutes: i)).toUtc().toIso8601String(),
        'review-$i',
      ]);
    }
    final tag = repo.upsertTag(
      name: ['Ideas', 'Work', 'Personal', 'Study'][i % 4],
    );
    repo.setTagColor(
      tagId: tag.id,
      color: ['#F2C572', '#8ECFB8', '#B4A1DC', '#8FC5EC'][i % 4],
    );
    repo.attachTag(noteId: 'review-$i', tagId: tag.id);
  }
  db.close();
  final features = NexFeatures(
    await DesktopStore.open(root.path, name),
    intelligenceFactory: (store) => DesktopIntelligence(
      store,
      secrets: _PreviewSecrets(),
      clientFactory: () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'A clear plan'},
                'finish_reason': 'stop',
              },
            ],
          }),
          200,
        ),
      ),
    ),
  );
  return ReviewStore(features, root);
}

class ReviewShot {
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
  const ReviewShot(
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

Future<PanelController> bootReview(
  WidgetTester t,
  ReviewShot spec,
  ReviewStore store,
) async {
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
      child: NexCardTimeScope(
        now: DateTime(2026, 10, 18, 12),
        child: RightPanelApp(controller: c, features: store.features),
      ),
    ),
  );
  await _frames(t);
  return c;
}

/// Navigates to [spec.target] in whichever mode is active and settles springs.
Future<void> goReview(
  WidgetTester t,
  PanelController c,
  ReviewShot spec,
) async {
  final window = spec.mode == 'window';
  switch (spec.target) {
    case 'assistant':
      c.selectWindowSection('assistant');
    case 'aiSettings' || 'providerSettings':
      c.selectWindowSection('settings');
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
  if (spec.target == 'aiSettings' || spec.target == 'providerSettings') {
    final open = find.byKey(const ValueKey('settings-open-6'));
    await t.ensureVisible(open);
    await t.tap(open);
    await _frames(t, 60);
    if (spec.target == 'providerSettings') {
      final provider = find.byKey(const ValueKey('ai-provider-open'));
      await t.ensureVisible(provider);
      await t.tap(provider);
      await _frames(t, 60);
      final custom = find.byKey(const ValueKey('provider-choice-custom'));
      await t.ensureVisible(custom);
      await t.tap(custom);
      await _frames(t, 60);
    }
  }
  if (spec.target == 'settings' && !window) {
    await t.tap(find.byKey(const ValueKey('settings-open-0')));
    await _frames(t, 60);
  }
  if (spec.target == 'toolsSettings') {
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    await t.ensureVisible(find.text(l.settingsTools).last);
    await t.tap(find.text(l.settingsTools).last);
    await _frames(t, 90);
  }
  if (spec.target == 'appearance' || spec.target == 'backup') {
    final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
    final target = find.text(
      spec.target == 'appearance' ? l.settingsAppearance : l.settingsBackup,
    );
    await t.ensureVisible(target);
    await t.tap(target);
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
