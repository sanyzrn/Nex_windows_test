// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Persisted shell settings for the Nex Windows desktop application.
/// Domain content is held only by nex_data; this is shell-only JSON preferences.
library;

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import 'models.dart';
import 'backup_shell.dart';

/// The persisted settings, JSON-compatible with the original app.
class Settings {
  Settings();

  String theme = 'midnight';
  String language = 'fa';
  String? installLanguageMarker;
  String preset = 'classic';
  String? accentSeed;
  double uiScale = 1;
  bool? solarCalendar;
  String hotkey = 'N';
  Color accent = Colors.black;
  bool startup = false;
  bool paste = true;
  bool magnify = true;
  bool panelPinned = false;
  double panelScale = 1;
  double edgeTriggerWidth = 2;
  double edgeTriggerHeight = 120;
  double edgeTriggerPosition = .5;

  /// 'window' = full desktop window (main mode); 'panel' = edge slide-out.
  String windowMode = 'window';

  /// Timeline card density: 'compact' | 'standard' | 'readable'. Feeds
  /// [NexCardDensityScope] around the library (IDEAS.md, density modes).
  String cardDensity = 'standard';

  /// Last normal (restored) frame of the desktop window, physical pixels,
  /// persisted so the window reopens where the user left it.
  Map<String, dynamic>? windowBounds;
  bool windowMaximized = false;

  /// False (default): the window opens as the compact card in the corner,
  /// always the same size. True: it reopens at the frame it was left in.
  bool windowRemember = false;

  /// Opt-in: the default close action remains a clean quit.
  bool closeToTray = true;
  List<String> recentEmoji = [];
  List<Color> recentColors = [];
  String edge = 'right';
  int monitor = 0;
  String? monitorName;
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
    return Colors.black;
  }

  Map<String, dynamic> toMap() => {
    'theme': theme,
    'language': language,
    'installLanguageMarker': installLanguageMarker,
    'preset': preset,
    'accentSeed': accentSeed,
    'uiScale': uiScale,
    'solarCalendar': solarCalendar,
    'hotkey': hotkey,
    'accent': _hex(accent),
    'startup': startup,
    'paste': paste,
    'magnify': magnify,
    'panelPinned': panelPinned,
    'panelScale': panelScale,
    'edgeTriggerWidth': edgeTriggerWidth,
    'edgeTriggerHeight': edgeTriggerHeight,
    'edgeTriggerPosition': edgeTriggerPosition,
    'windowMode': windowMode,
    'cardDensity': cardDensity,
    'windowBounds': windowBounds,
    'windowMaximized': windowMaximized,
    'windowRemember': windowRemember,
    'closeToTray': closeToTray,
    'recentEmoji': recentEmoji,
    'recentColors': recentColors.map(_hex).toList(),
    'edge': edge,
    'monitor': monitor,
    'monitorName': monitorName,
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
    s.accentSeed = PortablePreferences.isColor(j['accentSeed'])
        ? j['accentSeed'] as String
        : null;
    final scale = j['uiScale'];
    if (scale is num && scale.isFinite) {
      s.uiScale = scale.clamp(0.5, 3).toDouble();
    }
    s.solarCalendar = j['solarCalendar'] as bool?;
    s.hotkey = j['hotkey'] as String? ?? 'N';
    s.accent = _col(j['accent']);
    s.startup = j['startup'] as bool? ?? false;
    s.paste = j['paste'] as bool? ?? true;
    s.magnify = j['magnify'] as bool? ?? true;
    s.panelPinned = j['panelPinned'] as bool? ?? false;
    double bounded(String key, double fallback, double min, double max) {
      final value = j[key];
      return value is num && value.isFinite
          ? value.clamp(min, max).toDouble()
          : fallback;
    }

    s.panelScale = bounded('panelScale', 1, .75, 1.25);
    s.edgeTriggerWidth = bounded('edgeTriggerWidth', 2, 1, 12);
    s.edgeTriggerHeight = bounded('edgeTriggerHeight', 120, 24, 400);
    s.edgeTriggerPosition = bounded('edgeTriggerPosition', .5, 0, 1);
    s.windowMode = (j['windowMode'] as String?) == 'panel' ? 'panel' : 'window';
    s.cardDensity = NexCardDensity.fromWire(j['cardDensity'] as String?).name;
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
    s.windowRemember = j['windowRemember'] as bool? ?? false;
    s.closeToTray = true; // Migrate the former opt-in close behavior.
    s.recentEmoji = ((j['recentEmoji'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    s.recentColors = ((j['recentColors'] as List?) ?? [])
        .map((e) => _col(e))
        .toList();
    s.edge = j['edge'] as String? ?? 'right';
    s.monitor = (j['monitor'] as num?)?.toInt() ?? 0;
    s.monitorName = j['monitorName'] as String?;
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

  Map<String, dynamic> sharedPreferences() => {
    'appearance.theme': switch (theme) {
      'system' => 'system',
      'light' || 'sky' => 'light',
      _ => 'dark',
    },
    'appearance.theme_preset': preset,
    if (accentSeed != null) 'appearance.accent_seed': accentSeed,
    'appearance.recent_colors': recentColors.take(32).map(_hex).toList(),
    'appearance.locale': language,
    'appearance.card_density': cardDensity,
    'appearance.ui_scale': uiScale,
    if (solarCalendar != null) 'appearance.solar_calendar': solarCalendar,
  };

  Map<String, dynamic> backupSettings() => {
    'version': PortablePreferences.settingsVersion,
    'scope': 'shared',
    'preferences': sharedPreferences(),
    'credentials': <String, String>{},
    'clearedPreferences': [
      if (accentSeed == null) 'appearance.accent_seed',
      if (solarCalendar == null) 'appearance.solar_calendar',
    ],
    'desktopShell': toMap(),
  };

  /// A foreign backup can change common appearance, never the Windows host.
  static Settings fromBackup(Map<String, dynamic> backup, Settings current) {
    final shell = backup['desktopShell'];
    validateBackupShell(shell);
    final restored = fromMap(
      shell is Map
          ? {...current.toMap(), ...Map<String, dynamic>.from(shell)}
          : current.toMap(),
    );
    if (backup['scope'] == 'shared') {
      PortablePreferences.validateScopedBackup(backup);
    }
    final raw = backup['preferences'];
    if (raw is! Map) return restored; // Original Windows full backups.
    final prefs = <String, dynamic>{
      if (backup['scope'] != 'shared') ...PortablePreferences.defaults,
      for (final key in PortablePreferences.keys)
        if (raw.containsKey(key)) key: raw[key],
    };
    PortablePreferences.validate(prefs);
    if (prefs['appearance.theme'] case final String v) restored.theme = v;
    if (prefs['appearance.theme_preset'] case final String v) {
      // Retain a future ID in storage; the theme renderer falls back safely.
      restored.preset = v;
    }
    if (prefs['appearance.accent_seed'] case final String v) {
      restored.accentSeed = v;
    }
    if (prefs['appearance.locale'] case final String v) restored.language = v;
    if (prefs['appearance.card_density'] case final String v) {
      restored.cardDensity = v;
    }
    if (prefs['appearance.ui_scale'] case final num v) {
      restored.uiScale = v.toDouble();
    }
    if (prefs['appearance.solar_calendar'] case final bool v) {
      restored.solarCalendar = v;
    }
    if (prefs['appearance.recent_colors'] case final List v) {
      restored.recentColors = v.map(_col).toList();
    }
    final cleared = backup['clearedPreferences'] as List? ?? const [];
    if (cleared.contains('appearance.accent_seed') ||
        backup['scope'] != 'shared' &&
            !prefs.containsKey('appearance.accent_seed')) {
      restored.accentSeed = null;
    }
    if (cleared.contains('appearance.solar_calendar') ||
        backup['scope'] != 'shared' &&
            !prefs.containsKey('appearance.solar_calendar')) {
      restored.solarCalendar = null;
    }
    return restored;
  }
}
