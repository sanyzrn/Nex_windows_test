/// EnumDisplayMonitors enumeration order is not the Windows display number.
String displayNumber(Map<String, dynamic> display, int fallbackIndex) =>
    RegExp(
      r'DISPLAY(\d+)$',
      caseSensitive: false,
    ).firstMatch(display['name']?.toString() ?? '')?.group(1) ??
    '${fallbackIndex + 1}';
