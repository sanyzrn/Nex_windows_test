import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/data.dart';

void main() {
  test('emoji picker includes the full categorized set and keeps aliases', () {
    expect(kAllEmoji.length, greaterThan(3900));
    expect(
      kAllEmoji.where((e) => e.category == '🏳️').length,
      greaterThan(200),
    );
    expect(
      kAllEmoji.any((e) => e.emoji == '😂' && e.keywords.contains('laugh')),
      isTrue,
    );
    expect(kAllEmoji.map((e) => e.emoji).toSet().length, kAllEmoji.length);
  });
}
