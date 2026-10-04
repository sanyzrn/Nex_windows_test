// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/nex/store.dart';

void main() {
  test('10,000 notes benchmark: first page and Persian/English search latency', () async {
    final tempDir = await Directory.systemTemp.createTemp('nex-benchmark-10k-');
    final stopwatch = Stopwatch();

    try {
      final store = await DesktopStore.open(tempDir.path, 'bench-device');

      // 1. Generate 10,000 notes into temporary database
      stopwatch.start();
      const totalNotes = 10000;
      final batchWords = [
        'meeting notes for project launch',
        'یادداشت جلسه کاری و بررسی گزارش',
        'grocery list: apples, milk, bread',
        'کتاب جدید و نکات مطالعه هفتگی',
        'quick idea regarding desktop architecture',
        'برنامه‌ریزی ماه آینده و اهداف فصلی',
      ];

      // Insert notes via store capture
      for (var i = 0; i < totalNotes; i++) {
        final sample = batchWords[i % batchWords.length];
        await store.call('capture', {
          'text': '$sample #$i',
        });
      }
      stopwatch.stop();
      final insertMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('WP5 Benchmark: Inserted $totalNotes notes in ${insertMs}ms (${(insertMs / totalNotes).toStringAsFixed(2)}ms/note)');

      // 2. Measure first page of timeline
      stopwatch.reset();
      stopwatch.start();
      final firstPage = await store.call<List<Note>>('timeline', {'offset': 0});
      stopwatch.stop();
      final firstPageMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('WP5 Benchmark: First page of timeline (50 notes): ${firstPageMs}ms');
      expect(firstPage.length, 50);

      // 3. Measure search latency for common English word
      stopwatch.reset();
      stopwatch.start();
      final enSearch = await store.call<List<Note>>('search', {
        'filters': const SearchFilters(query: 'meeting'),
      });
      stopwatch.stop();
      final enSearchMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('WP5 Benchmark: English search ("meeting"): ${enSearchMs}ms, found ${enSearch.length} results');
      expect(enSearch.isNotEmpty, isTrue);

      // 4. Measure search latency for Persian word (with Persian folding)
      stopwatch.reset();
      stopwatch.start();
      final faSearch = await store.call<List<Note>>('search', {
        'filters': const SearchFilters(query: 'کتاب'),
      });
      stopwatch.stop();
      final faSearchMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('WP5 Benchmark: Persian search ("کتاب"): ${faSearchMs}ms, found ${faSearch.length} results');
      expect(faSearch.isNotEmpty, isTrue);

      // Verify Persian folded search finds notes with Arabic kaf 'كتاب'
      final foldedSearch = await store.call<List<Note>>('search', {
        'filters': const SearchFilters(query: 'كتاب'),
      });
      expect(foldedSearch.length, faSearch.length);

      await store.close();
    } finally {
      // 5. Clean up temporary database
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
