import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  await testMain();
}
