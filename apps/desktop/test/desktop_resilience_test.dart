import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/core/storage.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

void main() {
  test(
    'preferences recover the last valid snapshot after truncation',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'nex-settings-recovery-',
      );
      try {
        final storage = Storage(directory: root);
        storage.saveSettings({'language': 'fa', 'theme': 'dark'});
        storage.saveSettings({'language': 'en', 'theme': 'light'});
        File('${root.path}/settings.json').writeAsStringSync('{broken');
        expect(storage.loadSettings()['language'], 'fa');
        storage.saveSettings({'language': 'en'});
        expect(storage.loadSettings()['language'], 'en');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  testWidgets('focus timer catches up after missed ticks and preserves pause', (
    t,
  ) async {
    final c = PanelController(nativeHost: _Native());
    await c.bootstrap(preset: Settings(), useNative: false);
    var now = DateTime.utc(2026, 10, 18);
    c.timerNow = () => now;
    c.timerPreset(10);
    c.timerToggle();
    now = now.add(const Duration(minutes: 9));
    await t.pump(const Duration(seconds: 1));
    expect(c.tLeft, 60);
    c.timerToggle();
    now = now.add(const Duration(hours: 1));
    c.timerToggle();
    now = now.add(const Duration(seconds: 30));
    await t.pump(const Duration(seconds: 1));
    expect(c.tLeft, 30);
    c.timerReset();
    c.dispose();
  });
}
