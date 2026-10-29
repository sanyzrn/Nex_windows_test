import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/nex/desktop_editing_direction.dart';

void main() {
  for (final width in [180.0, 360.0]) {
    testWidgets(
      'clicking and typing at Persian line ends ($width px)',
      (t) async {
        await t.runAsync(() async {
          final loader = FontLoader('Vazirmatn')
            ..addFont(rootBundle.load('assets/fonts/VazirmatnVariable.ttf'));
          await loader.load();
        });
        const text =
            'هوش نکس برای هر آیتم اختصاصی نیست\n'
            'برای تصویر کپشن داغون هست\n\n'
            'دکمه بازیابی آیتم حذف شده جاش اونجاست؟\n'
            'پیش نمایش آیتم اینتر را شناسایی نمیکنه';
        final controller = TextEditingController(text: text);
        addTearDown(controller.dispose);
        await t.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SizedBox(
                  width: width,
                  child: DesktopEditingDirection(
                    controller: controller,
                    builder: (context, direction) => TextField(
                      controller: controller,
                      textDirection: direction,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 15,
                        height: 1.6,
                      ),
                      maxLines: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final render = t
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
        final firstLine = render.getLineAtOffset(const TextPosition(offset: 0));
        if (firstLine.end < text.indexOf('\n')) {
          final caret = render.getLocalRectForCaret(
            TextPosition(
              offset: firstLine.end,
              affinity: TextAffinity.upstream,
            ),
          );
          await t.tapAt(
            render.localToGlobal(Offset(caret.left - 5, caret.center.dy)),
            kind: PointerDeviceKind.mouse,
          );
          await t.pump();
          final clicked = render.getLocalRectForCaret(
            controller.selection.extent,
          );
          expect(clicked.center.dy, closeTo(caret.center.dy, 1));
          await t.pump(const Duration(milliseconds: 500));
        }
        for (final ending in ['نیست', 'هست', 'اونجاست؟', 'نمیکنه']) {
          final end = text.indexOf(ending) + ending.length;
          final caret = render.getLocalRectForCaret(TextPosition(offset: end));
          final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.down(
            render.localToGlobal(Offset(caret.left - 5, caret.center.dy)),
          );
          await t.pump(const Duration(milliseconds: 16));
          expect(
            controller.selection.extentOffset,
            end,
            reason: 'first painted frame: $ending',
          );
          await t.pump(const Duration(milliseconds: 200));
          expect(
            controller.selection.extentOffset,
            end,
            reason: 'held mouse: $ending',
          );
          await mouse.up();
          await t.pump();
          expect(controller.selection.extentOffset, end, reason: ending);
          const inserted = ' تازه';
          t.testTextInput.updateEditingValue(
            controller.value.replaced(
              TextRange.collapsed(controller.selection.extentOffset),
              inserted,
            ),
          );
          await t.pump();
          expect(controller.text, text.replaceRange(end, end, inserted));
          controller.text = text;
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
        }
        await t.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
