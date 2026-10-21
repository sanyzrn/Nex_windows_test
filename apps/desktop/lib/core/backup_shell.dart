/// Validate a desktop-only settings payload before its library is installed.
/// Kept free of Flutter so the storage worker can perform the preflight.
void validateBackupShell(Object? value) {
  if (value == null) return;
  if (value is! Map) throw const FormatException('Invalid desktop settings');
  const strings = {
    'theme',
    'language',
    'installLanguageMarker',
    'preset',
    'hotkey',
    'accentSeed',
    'windowMode',
    'cardDensity',
    'edge',
    'monitorName',
    'engine',
  };
  const booleans = {
    'startup',
    'paste',
    'magnify',
    'panelPinned',
    'windowMaximized',
    'windowRemember',
    'closeToTray',
    'updates',
    'solarCalendar',
  };
  const numbers = {'monitor', 'lastCheck', 'uiScale'};
  const lists = {
    'recentEmoji',
    'recentColors',
    'hidden',
    'apps',
    'snippets',
    'pins',
    'zones',
    'dock',
    'more',
  };
  bool color(Object? v) =>
      v is String &&
      RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(v);
  for (final entry in value.entries) {
    final v = entry.value;
    if (v == null) continue;
    if (strings.contains(entry.key) && v is! String ||
        booleans.contains(entry.key) && v is! bool ||
        numbers.contains(entry.key) && (v is! num || !v.isFinite) ||
        lists.contains(entry.key) && v is! List ||
        entry.key == 'accent' && !color(v) ||
        entry.key == 'accentSeed' && !color(v)) {
      throw const FormatException('Invalid desktop preference');
    }
    if (entry.key == 'recentColors' && (v as List).any((c) => !color(c))) {
      throw const FormatException('Invalid recent colors');
    }
    if (entry.key == 'apps' &&
        (v as List).any(
          (app) =>
              app is! Map ||
              const [
                'id',
                'name',
                'path',
                'icon',
              ].any((key) => app[key] != null && app[key] is! String),
        )) {
      throw const FormatException('Invalid desktop shortcuts');
    }
    if (entry.key == 'windowBounds') {
      final entries = v is Map
          ? v.values
          : v is List && v.length == 4
          ? v
          : null;
      if (entries == null || entries.any((n) => n is! num || !n.isFinite)) {
        throw const FormatException('Invalid window bounds');
      }
    }
  }
}
