import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';

class _Native extends NativeHost {
  bool available = true;
  int hides = 0, exits = 0;
  @override
  Future<bool> hideToTray() async {
    hides++;
    return available;
  }

  @override
  Future<void> quit() async {
    exits++;
  }

  @override
  Future<Map<String, dynamic>?> windowFrame() async => {
    'x': 10,
    'y': 20,
    'w': 460,
    'h': 760,
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  test('caption close migrates legacy profiles to tray retention', () {
    expect(Settings.fromMap({}).closeToTray, isTrue);
    expect(Settings.fromMap({'closeToTray': false}).closeToTray, isTrue);
    expect(
      Settings.fromMap((Settings()..closeToTray = true).toMap()).closeToTray,
      isTrue,
    );
  });
  for (final keep in [false, true]) {
    for (final tray in [false, true]) {
      test(
        'close keep=$keep tray=$tray ignores legacy flag and hides only with a real tray, explicit quit drains',
        () async {
          final native = _Native()..available = tray;
          final c = PanelController(nativeHost: native);
          await c.bootstrap(
            preset: Settings()..closeToTray = keep,
            useNative: false,
          );
          var drained = 0;
          c.beforeShutdown = () async {
            drained++;
          };
          c.onTray('shutdown');
          await Future<void>.delayed(Duration.zero);
          expect(native.hides, 1);
          expect(native.exits, tray ? 0 : 1);
          if (tray) {
            expect(drained, 0);
            await c.quit();
          }
          expect(drained, 1);
          expect(native.exits, 1);
          c.dispose();
        },
      );
    }
  }
}
