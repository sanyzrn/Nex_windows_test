import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/windows_emoji_comparator.dart';

Future<Uint8List> png({int width = 100, int changedPixels = 0}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, changedPixels.toDouble(), 1),
    ui.Paint()
      ..color = const ui.Color(0xff000000)
      ..isAntiAlias = false,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, 20);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  late Directory root;
  late WindowsEmojiComparator comparator;
  late Uint8List baseline;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('nex-golden-comparator-');
    comparator = WindowsEmojiComparator(root.uri.resolve('fixture_test.dart'));
    baseline = await png();
    for (final name in [
      'emoji_panel',
      'right_shell',
      'left_shell',
      'settings_light',
    ]) {
      await comparator.update(Uri.parse('goldens/$name.png'), baseline);
    }
  });

  tearDown(() async => root.delete(recursive: true));

  test(
    'accepts up to 0.05% changed pixels only in the three emoji grids',
    () async {
      final drift = await png(changedPixels: 1); // 1 / 2000 = 0.05%.
      for (final name in ['emoji_panel', 'right_shell', 'left_shell']) {
        expect(
          await comparator.compare(drift, Uri.parse('goldens/$name.png')),
          isTrue,
        );
      }
    },
  );

  test(
    'rejects emoji changes above the limit and writes failure images',
    () async {
      await expectLater(
        comparator.compare(
          await png(changedPixels: 2),
          Uri.parse('goldens/emoji_panel.png'),
        ),
        throwsA(isA<FlutterError>()),
      );
      expect(
        File('${root.path}/failures/emoji_panel_isolatedDiff.png').existsSync(),
        isTrue,
      );
    },
  );

  test('keeps all other images pixel exact', () async {
    final golden = Uri.parse('goldens/settings_light.png');
    expect(await comparator.compare(baseline, golden), isTrue);
    await expectLater(
      comparator.compare(await png(changedPixels: 1), golden),
      throwsA(isA<FlutterError>()),
    );
  });

  test('rejects image dimension changes', () async {
    await expectLater(
      comparator.compare(
        await png(width: 101),
        Uri.parse('goldens/emoji_panel.png'),
      ),
      throwsA(isA<FlutterError>()),
    );
  });
}
