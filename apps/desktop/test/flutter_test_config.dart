import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/windows_emoji_comparator.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  if (Platform.isWindows) {
    final emoji = File(
      '${Platform.environment['WINDIR']}\\Fonts\\seguiemj.ttf',
    );
    if (emoji.existsSync()) {
      await (FontLoader(
        'Segoe UI Emoji',
      )..addFont(emoji.readAsBytes().then(ByteData.sublistView))).load();
    }
  }
  for (final entry in {
    'Inter': 'Inter-subset.ttf',
    'Vazirmatn': 'VazirmatnVariable.ttf',
  }.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(rootBundle.load('assets/fonts/${entry.value}'));
    await loader.load();
  }
  final previousComparator = goldenFileComparator;
  if (Platform.isWindows && previousComparator is LocalFileComparator) {
    goldenFileComparator = WindowsEmojiComparator(
      previousComparator.basedir.resolve('flutter_test_config.dart'),
    );
  }
  try {
    await testMain();
  } finally {
    goldenFileComparator = previousComparator;
  }
}
