import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop stock-menu exceptions never grow', () {
    // A tag entry retains its colored dot. Material dropdowns preserve their
    // FormField validation and keyboard selection, using Nex surface tokens.
    const limits = {'nex/library_filter_widgets.dart': 1};
    final rule = RegExp(
      r'(?<![A-Za-z_.])(PopupMenuItem|PopupMenuButton|CheckedPopupMenuItem|showMenu)\s*[<(]',
    );
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final path = file.path
          .replaceAll('\\', '/')
          .replaceFirst(RegExp(r'^lib/'), '');
      expect(
        rule.allMatches(file.readAsStringSync()).length,
        lessThanOrEqualTo(limits[path] ?? 0),
        reason: path,
      );
    }
  });
}
