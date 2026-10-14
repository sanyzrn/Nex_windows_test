import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/models.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/ui/widgets.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

void main() {
  for (final language in ['en', 'fa']) {
    testWidgets('$language clipboard actions occupy a separate lane', (
      t,
    ) async {
      t.view.physicalSize = const Size(480, 680);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final native = _Native();
      var clipboardWrites = 0;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') clipboardWrites++;
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final c = PanelController(nativeHost: native);
      await c.bootstrap(
        preset: Settings()
          ..language = language
          ..windowMode = 'panel',
        useNative: false,
      );
      final text = language == 'fa'
          ? 'این متن بلند فارسی باید در کنار دکمه‌ها خوانا باقی بماند و با آنها تداخل نکند'
          : 'A long clipboard item stays readable beside separate favorite and delete buttons';
      c.clips = [
        ClipEntry.text(text, time: DateTime.now()),
        ClipEntry.image(
          ClipImage(
            id: 'test',
            w: 2,
            h: 2,
            rgba: Uint8List.fromList(List.filled(16, 255)),
          ),
          time: DateTime.now(),
        ),
      ];
      c.open();
      c.openWidget('clip');
      await t.pumpWidget(RightPanelApp(controller: c));
      for (var i = 0; i < 150; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      final label = t.getRect(find.text(text));
      final action = t.getRect(find.byIcon(Icons.star_outline_rounded).first);
      expect(label.overlaps(action), isFalse);
      expect(find.byType(ItemAction), findsNWidgets(4));
      await t.tap(find.byIcon(Icons.star_outline_rounded).first);
      await t.pump();
      expect(c.S.pins, contains(text));
      expect(clipboardWrites, 0);
      await t.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await t.pump();
      expect(c.clips.where((e) => e.text == text), isEmpty);
      expect(c.S.pins, isNot(contains(text)));
      expect(clipboardWrites, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
