import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/nex/desktop_editing_direction.dart';

void main() {
  test(
    'paragraph selection uses UTF-16 offsets and preserves neutral prefixes',
    () {
      const text = 'Hello!\n😀 ۱۲۳ سلام!\nWorld.';
      expect(
        desktopEditingDirection(
          const TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: 3),
          ),
        ),
        TextDirection.ltr,
      );
      expect(
        desktopEditingDirection(
          const TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: 18),
          ),
        ),
        TextDirection.rtl,
      );
      expect(
        desktopEditingDirection(
          const TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        ),
        TextDirection.ltr,
      );
      expect(
        desktopEditingDirection(
          const TextEditingValue(
            text: text,
            selection: TextSelection(baseOffset: 0, extentOffset: 15),
          ),
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'direction changes preserve field, focus, composition, range and raw text',
    (t) async {
      final c = TextEditingController(text: 'English.\nسلام دنیا!');
      final focus = FocusNode();
      addTearDown(c.dispose);
      addTearDown(focus.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopEditingDirection(
              controller: c,
              builder: (context, direction) => TextField(
                controller: c,
                focusNode: focus,
                textDirection: direction,
                maxLines: 5,
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await t.pump();
      final state = t.state(find.byType(EditableText));
      final original = c.text;
      c.selection = TextSelection.collapsed(offset: c.text.length);
      await t.pump();
      expect(
        t.widget<EditableText>(find.byType(EditableText)).textDirection,
        TextDirection.rtl,
      );
      expect(identical(t.state(find.byType(EditableText)), state), isTrue);
      expect(focus.hasFocus, isTrue);
      c.value = TextEditingValue(
        text: original,
        selection: const TextSelection.collapsed(offset: 2),
        composing: const TextRange(start: 0, end: 4),
      );
      await t.pump();
      expect(
        t.widget<EditableText>(find.byType(EditableText)).textDirection,
        TextDirection.rtl,
      );
      expect(c.value.composing, const TextRange(start: 0, end: 4));
      c.value = TextEditingValue(
        text: original,
        selection: TextSelection(baseOffset: 2, extentOffset: original.length),
      );
      await t.pump();
      expect(
        t.widget<EditableText>(find.byType(EditableText)).textDirection,
        TextDirection.rtl,
      );
      expect(c.text, original);
      c.selection = const TextSelection.collapsed(offset: 2);
      await t.pump();
      expect(
        t.widget<EditableText>(find.byType(EditableText)).textDirection,
        TextDirection.ltr,
      );
      expect(c.text, original);
      await t.pumpWidget(const SizedBox());
    },
  );

  test('10k text, emoji and ZWNJ remain byte-for-byte untouched', () {
    final text = '${'a' * 10000}\n😀 می\u200cنویسم!';
    final value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    expect(desktopEditingDirection(value), TextDirection.rtl);
    expect(value.text, text);
  });
}
