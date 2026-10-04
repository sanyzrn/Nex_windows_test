// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shell utility data, clipboard preview models, and launcher helpers.
/// Owns stopwatch formatting, snippet storage, search engine presets, and recent tool histories.
library;

class UtilityStateHelper {
  /// Format milliseconds into mm:ss.cc for the stopwatch display.
  static String formatStopwatch(int ms) =>
      '${(ms ~/ 60000).toString().padLeft(2, '0')}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${((ms ~/ 10) % 100).toString().padLeft(2, '0')}';

  /// Standard search engine URLs for quick lookup.
  static const Map<String, String> searchEngines = {
    'Google': 'https://www.google.com/search?q=',
    'DuckDuckGo': 'https://duckduckgo.com/?q=',
    'Bing': 'https://www.bing.com/search?q=',
  };
}
