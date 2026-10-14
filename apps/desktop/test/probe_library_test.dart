import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/capture_view.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_desktop/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNative extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

String _clipboardText = '';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    const platform = MethodChannel('flutter/platform', JSONMethodCodec());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': _clipboardText};
          }
          return null;
        });
  });

  testWidgets('clipboard capture drains both link and text writes', (
    tester,
  ) async {
    late Directory root;
    late DesktopStore store;
    late NexFeatures features;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('nex-probe-cap-');
      store = await DesktopStore.open(root.path, 'dev-1');
      features = NexFeatures(store);
    });
    final c = PanelController(nativeHost: FakeNative());
    await tester.runAsync(() async {
      await c.bootstrap(
        preset: Settings()..windowMode = 'window',
        useNative: false,
      );
    });
    _clipboardText = 'https://example.com/articles/nex-12';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: LiquidScope(
          controller: c,
          palette: c.palette,
          dir: 1,
          child: NexScope(
            features: features,
            child: const Scaffold(body: NexCaptureView()),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await tester.tap(find.text('Paste text'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await features.session.flushed;
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    var notes = await tester.runAsync(
      () => store.call<List<dynamic>>('timeline', {'offset': 0}),
    );
    expect(notes, hasLength(1));
    expect(features.composer.text, isEmpty);
    _clipboardText = 'plain thoughts';

    await tester.runAsync(() async {
      await tester.tap(find.text('Paste text'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await features.session.flushed;
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    notes = await tester.runAsync(
      () => store.call<List<dynamic>>('timeline', {'offset': 0}),
    );
    expect(features.composer.text, 'plain thoughts');
    expect(notes, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.runAsync(() async {
      await features.close();
      await store.close();
      await root.delete(recursive: true);
    });
  });
}
