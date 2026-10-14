/// EnumDisplayMonitors enumeration order is not the Windows display number.
String displayNumber(Map<String, dynamic> display, int fallbackIndex) =>
    RegExp(
      r'DISPLAY(\d+)$',
      caseSensitive: false,
    ).firstMatch(display['name']?.toString() ?? '')?.group(1) ??
    '${fallbackIndex + 1}';

int displayIndex(
  List<Map<String, dynamic>> displays,
  String? name,
  int fallback,
) {
  final index = name == null
      ? -1
      : displays.indexWhere((d) => d['name'] == name);
  return index >= 0
      ? index
      : displays.isEmpty
      ? 0
      : fallback.clamp(0, displays.length - 1);
}
