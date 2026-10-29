import 'dart:io';
import 'dart:ui' show BoxWidthStyle, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features.dart';
import 'package:nex_desktop/nex/note_detail_parts.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_ui/nex_ui.dart';

void main() {
  const text =
      'هوش نکس برای هر آیتم اختصاصی نیست\n\n'
      'دکمه بازیابی آیتم حذف شده جاش اونجاست؟\n\n\n'
      'پیش نمایش آیتم اینتر را شناسایی نمیکنه';

  for (final mode in ['compact', 'wide', 'edit']) {
    testWidgets('$mode: Persian word highlight and copy agree', (t) async {
      String? copiedText;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      late Directory root;
      late NexFeatures features;
      Note? note;
      await t.runAsync(() async {
        root = await Directory.systemTemp.createTemp('nex-rtl-selection-');
        features = NexFeatures(await DesktopStore.open(root.path, 'selection'));
        if (mode == 'edit') {
          note = await features.store.call<Note>('capture', {'text': text});
        } else {
          features.composer.text = text;
        }
      });
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: nexLightTheme(fontFamily: nexPersianFont),
          home: NexScope(
            features: features,
            child: Scaffold(
              body: mode == 'edit'
                  ? NexNoteDetail(note: note!, onClose: () {})
                  : NexCaptureView(compact: mode == 'compact', embedded: true),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      if (mode == 'edit') {
        // Read mode keeps the same single and repeated Enters as the editor.
        expect(find.text(text), findsOneWidget);
        t
            .widget<NoteDetailHeader>(find.byType(NoteDetailHeader))
            .onToggleEdit!();
        await t.pumpAndSettle();
      }

      final editable = find.byType(EditableText).first;
      final state = t.state<EditableTextState>(editable);
      final controller = state.widget.controller;
      final render = state.renderEditable;
      for (final word in ['دکمه', 'بازیابی', 'اونجاست']) {
        final start = text.indexOf(word);
        final end = start + word.length;
        // Click the word itself using the editor's laid-out caret positions.
        final a = render.getLocalRectForCaret(TextPosition(offset: start));
        final b = render.getLocalRectForCaret(TextPosition(offset: end));
        final point = render.localToGlobal(
          Offset((a.center.dx + b.center.dx) / 2, a.center.dy),
        );
        await t.tapAt(point, kind: PointerDeviceKind.mouse);
        await t.pump(const Duration(milliseconds: 50));
        await t.tapAt(point, kind: PointerDeviceKind.mouse);
        await t.pump();
        expect(controller.selection.textInside(controller.text), word);

        final highlight = render.getRectForComposingRange(
          controller.selection,
        )!;
        final painter = TextPainter(
          text: render.text,
          textDirection: render.textDirection,
          textAlign: render.textAlign,
          textScaler: render.textScaler,
        )..layout(maxWidth: render.size.width);
        final wordBounds = painter
            .getBoxesForSelection(
              controller.selection,
              boxWidthStyle: BoxWidthStyle.tight,
            )
            .map((box) => box.toRect())
            .reduce((a, b) => a.expandToInclude(b));
        // A selected word must not paint into the empty space to the left.
        expect(highlight.width, closeTo(wordBounds.width, 0.1));
        painter.dispose();
        state.copySelection(SelectionChangedCause.toolbar);
        await t.pump();
        expect(copiedText, word);
        await t.pump(const Duration(milliseconds: 500));
      }
      expect(controller.text, text);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async {
        await features.close();
        await root.delete(recursive: true);
      });
      expect(t.takeException(), isNull);
    });
  }
}
