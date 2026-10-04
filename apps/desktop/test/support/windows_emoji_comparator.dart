import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps ordinary goldens exact, allowing only tiny Windows emoji raster drift.
class WindowsEmojiComparator extends LocalFileComparator {
  WindowsEmojiComparator(super.testFile);

  // Windows Server 2025 differed by 125-129 of 326,400 pixels from Windows 11
  // with the same Flutter SDK. Limit this allowance to the three emoji grids.
  static const _emojiGoldens = {
    'goldens/emoji_panel.png',
    'goldens/right_shell.png',
    'goldens/left_shell.png',
  };
  static const _maxDiffFraction = 0.0005; // 0.05%, not 5%.

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    if (!_emojiGoldens.contains(golden.path)) {
      return super.compare(imageBytes, golden);
    }
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    try {
      if (result.passed || result.diffPercent <= _maxDiffFraction) {
        return true;
      }
      throw FlutterError(await generateFailureOutput(result, golden, basedir));
    } finally {
      result.dispose();
    }
  }
}
