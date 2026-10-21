import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_shortcuts.dart';

void main() {
  test('shortcut documentation matches the dialog rows and both locales', () {
    final actual = File(
      '../../docs/shortcuts.md',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    expect(actual, generateShortcuts(Directory('../..')));
  });
}
