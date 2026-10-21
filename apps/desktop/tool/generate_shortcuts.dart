import 'dart:convert';
import 'dart:io';

/// Derive the table from the dialog's actual rows and localization sources.
/// Reject unrecognized rows rather than silently omitting a new shortcut.
String generateShortcuts(Directory repository) {
  String read(String path) =>
      File('${repository.path}/$path').readAsStringSync();
  const desktop = 'apps/desktop/lib';
  final dialog = read('$desktop/nex/shortcuts_dialog.dart');
  final body = RegExp(
    r'final shortcuts = \[([\s\S]*?)\];',
  ).firstMatch(dialog)!.group(1)!;
  final row = RegExp(
    r'\(\s*(?:ShortcutLabels\.spaced\(ShortcutLabels\.(\w+)\)|ShortcutLabels\.(\w+))\s*,\s*l\.(\w+)\s*,?\s*\)',
  );
  if (body.replaceAll(row, '').replaceAll(RegExp(r'[\s,]'), '').isNotEmpty) {
    throw StateError('Unsupported shortcut row; update the generator.');
  }
  final keys = {
    for (final match in RegExp(
      r"static const (\w+) = '([^']*)';",
    ).allMatches(read('$desktop/l10n/shortcut_labels.dart')))
      match[1]!: match[2]!,
  };
  final en = jsonDecode(read('$desktop/l10n/app_en.arb')) as Map;
  final fa = jsonDecode(read('$desktop/l10n/app_fa.arb')) as Map;
  String cell(Object value) => value.toString().replaceAll('|', r'\|');
  final output = StringBuffer('''# Keyboard shortcuts / میان‌برهای صفحه‌کلید

Generated from `shortcuts_dialog.dart`, `shortcut_labels.dart` and both ARBs.
From `apps/desktop`, run `dart run tool/generate_shortcuts.dart` after editing them.

These are the actions listed by the in-app help dialog. Library selection actions
apply while the library owns focus; an active text editor keeps its editing keys.

| Shortcut | English | فارسی |
| --- | --- | --- |
''');
  final matches = row.allMatches(body).toList();
  if (matches.isEmpty) throw StateError('No shortcut rows found.');
  for (final match in matches) {
    final key = keys[match[1] ?? match[2]]!;
    final action = match[3]!;
    output.writeln(
      '| `${cell(key)}` | ${cell(en[action]!)} | ${cell(fa[action]!)} |',
    );
  }
  output.writeln();
  output.write('''
Additional bindings: `Ctrl+K` opens the command palette; `F1` opens help
(`Ctrl+/` also opens help in the library); `Ctrl+Z` undoes library deletion when
an editor does not own focus. The global capture shortcut defaults to
`Ctrl+Alt+N` and is configurable in Settings → Shortcuts & input.

The generated table describes the help dialog; context-specific bindings above
are documented separately. [Product guide](../README.md).
''');
  return output.toString();
}

void main() {
  final root = File.fromUri(Platform.script).parent.parent.parent.parent;
  File(
    '${root.path}/docs/shortcuts.md',
  ).writeAsStringSync(generateShortcuts(root));
}
