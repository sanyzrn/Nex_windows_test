// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Persisted shell settings for the Nex Windows desktop application.
/// Domain content is held only by nex_data; this is shell-only JSON preferences.
library;

import 'package:flutter/material.dart';
import 'models.dart';

/// The persisted settings, JSON-compatible with the original app.
class Settings {
  Settings();

  String theme = 'midnight';
  String language = 'fa';
  String? installLanguageMarker;
  String preset = 'classic';
  String hotkey = 'N';
  Color accent = const Color(0xFF000000);
  bool startup = false;
  bool paste = true;
  bool magnify = true;
  bool panelPinned = false;

  /// 'window' = full desktop window (main mode); 'panel' = edge slide-out.
  String windowMode = 'window';

  /// Last normal (restored) frame of the desktop window, physical pixels,
  /// persisted so the window reopens where the user left it.
  Map<String, dynamic>? windowBounds;
  bool windowMaximized = false;
  List<String> recentEmoji = [];
  List<Color> recentColors = [];
  String edge = 'right';
  int monitor = 0;
  bool updates = true;
  int lastCheck = 0;
  List<String> hidden = [];
  List<AppItem> apps = [];
  List<String> snippets = [];
  List<String> pins = [];
  String engine = 'Google';
  List<String> zones = [
    'UTC',
    'Europe/London',
    'America/New_York',
    'Asia/Tokyo',
  ];
  List<String>? dock;
  List<String>? more;

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  static Color _col(dynamic v) {
    var s = (v ?? '#000000').toString();
    if (s.length == 7 && s.startsWith('#')) {
      return Color(int.parse('FF${s.substring(1)}', radix: 16));
    }
    if (s.length == 9 && s.startsWith('#')) {
      return Color(int.parse(s.substring(1), radix: 16));
    }
    return const Color(0xFF000000);
  }

  Map<String, dynamic> toMap() => {
    'theme': theme,
    'language': language,
    'installLanguageMarker': installLanguageMarker,
    'preset': preset,
    'hotkey': hotkey,
    'accent': _hex(accent),
    'startup': startup,
    'paste': paste,
    'magnify': magnify,
    'panelPinned': panelPinned,
    'windowMode': windowMode,
    'windowBounds': windowBounds,
    'windowMaximized': windowMaximized,
    'recentEmoji': recentEmoji,
    'recentColors': recentColors.map(_hex).toList(),
    'edge': edge,
    'monitor': monitor,
    'updates': updates,
    'lastCheck': lastCheck,
    'hidden': hidden,
    'apps': apps.map((a) => a.toJson()).toList(),
    'snippets': snippets,
    'pins': pins,
    'engine': engine,
    'zones': zones,
    'dock': dock,
    'more': more,
  };

  static Settings fromMap(Map<String, dynamic> j) {
    final s = Settings();
    s.theme = j['theme'] as String? ?? 'midnight';
    s.language = j['language'] as String? ?? 'fa';
    s.installLanguageMarker = j['installLanguageMarker'] as String?;
    s.preset = j['preset'] as String? ?? 'classic';
    s.hotkey = j['hotkey'] as String? ?? 'N';
    s.accent = _col(j['accent']);
    s.startup = j['startup'] as bool? ?? false;
    s.paste = j['paste'] as bool? ?? true;
    s.magnify = j['magnify'] as bool? ?? true;
    s.panelPinned = j['panelPinned'] as bool? ?? false;
    s.windowMode = (j['windowMode'] as String?) == 'panel' ? 'panel' : 'window';
    final bounds = j['windowBounds'];
    if (bounds is Map) {
      s.windowBounds = bounds.cast<String, dynamic>();
    } else if (bounds is List && bounds.length == 4) {
      // Tolerate a plain [x, y, w, h] list from older JSON exports.
      s.windowBounds = {
        'x': (bounds[0] as num).toInt(),
        'y': (bounds[1] as num).toInt(),
        'w': (bounds[2] as num).toInt(),
        'h': (bounds[3] as num).toInt(),
      };
    }
    s.windowMaximized = j['windowMaximized'] as bool? ?? false;
    s.recentEmoji = ((j['recentEmoji'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    s.recentColors = ((j['recentColors'] as List?) ?? [])
        .map((e) => _col(e))
        .toList();
    s.edge = j['edge'] as String? ?? 'right';
    s.monitor = (j['monitor'] as num?)?.toInt() ?? 0;
    s.updates = j['updates'] as bool? ?? true;
    s.lastCheck = (j['lastCheck'] as num?)?.toInt() ?? 0;
    s.hidden = ((j['hidden'] as List?) ?? []).map((e) => e.toString()).toList();
    s.apps = ((j['apps'] as List?) ?? [])
        .whereType<Map>()
        .map((m) => AppItem.fromJson(m.cast<String, dynamic>()))
        .toList();
    s.snippets = ((j['snippets'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    s.pins = ((j['pins'] as List?) ?? []).map((e) => e.toString()).toList();
    s.engine = j['engine'] as String? ?? 'Google';
    s.zones = ((j['zones'] as List?) ?? []).map((e) => e.toString()).toList();
    s.dock = (j['dock'] as List?)?.map((e) => e.toString()).toList();
    s.more = (j['more'] as List?)?.map((e) => e.toString()).toList();
    return s;
  }
}
