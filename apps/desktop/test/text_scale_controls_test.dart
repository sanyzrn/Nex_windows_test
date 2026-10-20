import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'support/review_fixture.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_desktop/nex/note_detail_parts.dart';
import 'package:nex_desktop/l10n/intelligence_strings.dart';

void expectFullSizeLabel(WidgetTester t, Finder label) {
  final paragraph = t.renderObject<RenderParagraph>(label);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: 'An action label must wrap instead of truncating.',
  );
  expect(
    paragraph.getMinIntrinsicWidth(double.infinity),
    lessThanOrEqualTo(paragraph.size.width + .01),
    reason: 'Words must fit without being broken into fragments.',
  );
  expect(
    math.sqrt(
      math.pow(paragraph.getTransformTo(null).entry(0, 0), 2) +
          math.pow(paragraph.getTransformTo(null).entry(1, 0), 2),
    ),
    closeTo(1, .001),
    reason:
        'The requested text size must not be cancelled by shrinking the label.',
  );
}

void main() {
  for (final locale in ['en', 'fa']) {
    testWidgets('minimum library search and actions remain visible: $locale', (
      t,
    ) async {
      final shot = ReviewShot(
        'library_controls',
        mode: 'window',
        target: 'timeline',
        locale: locale,
        size: const Size(380, 520),
        textScale: 2,
        notes: 0,
      );
      final store = (await t.runAsync(
        () => openReviewStore('library_controls'),
      ))!;
      final c = await bootReview(t, shot, store);
      try {
        await goReview(t, c, shot);
        final context = t.element(find.byType(Scaffold));
        final l = AppLocalizations.of(context)!;
        final ai = AiStrings.of(context);
        final hint = t.renderObject<RenderParagraph>(find.text(l.search));
        expect(hint.didExceedMaxLines, isFalse);
        expect(
          hint.getMinIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(hint.size.width + .01),
        );
        for (final tooltip in [ai.t('board'), ai.t('list'), l.manageTags]) {
          final action = find.byTooltip(tooltip);
          expect(action, findsOneWidget);
          expect(t.getRect(action).right, lessThanOrEqualTo(380));
        }
        for (final label in [
          l.emptyLibraryWrite,
          l.emptyLibraryTools,
          l.emptyLibraryShortcuts,
        ]) {
          final text = find.text(label);
          expectFullSizeLabel(t, text);
          await t.ensureVisible(text);
          await t.pumpAndSettle();
          expect(t.getRect(text).bottom, lessThanOrEqualTo(520));
        }
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        c.dispose();
        await t.runAsync(() async {
          await store.features.close();
          await store.root.delete(recursive: true);
        });
      }
    });
  }
  for (final locale in ['en', 'fa']) {
    testWidgets('reader labels retain requested text size: $locale', (t) async {
      final shot = ReviewShot(
        'reader_controls',
        mode: 'window',
        target: 'reader',
        locale: locale,
        size: const Size(380, 520),
        textScale: 2,
        notes: 8,
      );
      final store = (await t.runAsync(
        () => openReviewStore('reader_controls', count: 8),
      ))!;
      final c = await bootReview(t, shot, store);
      try {
        await goReview(t, c, shot);
        final bar = find.byType(NoteActionBar);
        for (final element
            in find
                .descendant(of: bar, matching: find.byType(Text))
                .evaluate()) {
          final text = find.byWidget(element.widget);
          expectFullSizeLabel(t, text);
          await t.ensureVisible(text);
          await t.pumpAndSettle();
          expect(t.getRect(text).bottom, lessThanOrEqualTo(520));
        }
        expectFullSizeLabel(
          t,
          find
              .descendant(
                of: find.byType(NoteDetailHeader),
                matching: find.byType(Text),
              )
              .first,
        );
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        c.dispose();
        await t.runAsync(() async {
          await store.features.close();
          await store.root.delete(recursive: true);
        });
      }
    });
  }
  for (final locale in ['en', 'fa']) {
    for (final size in [
      const Size(380, 520),
      const Size(460, 760),
      const Size(1200, 800),
    ]) {
      testWidgets(
        'large text controls remain readable and reachable: $locale $size',
        (t) async {
          final shot = ReviewShot(
            'controls',
            mode: 'window',
            locale: locale,
            size: size,
            textScale: 2,
            notes: 0,
          );
          final store = (await t.runAsync(() => openReviewStore('controls')))!;
          final c = await bootReview(t, shot, store);
          try {
            final l = AppLocalizations.of(t.element(find.byType(Scaffold)))!;
            for (final section in [
              'assistant',
              'library',
              'tools',
              'settings',
              'capture',
            ]) {
              c.selectWindowSection(section);
              await t.pump();
              expectFullSizeLabel(
                t,
                find.byKey(const ValueKey('window-section-title')),
              );
            }
            expectFullSizeLabel(
              t,
              find.byKey(const ValueKey('window-section-title')),
            );
            if (size.width < 960) {
              for (final id in [
                'capture',
                'library',
                'assistant',
                'tools',
                'settings',
                'more',
              ]) {
                final tile = find.byKey(ValueKey('rail-$id'));
                final text = find
                    .descendant(of: tile, matching: find.byType(Text))
                    .first;
                expectFullSizeLabel(t, text);
                final paragraph = t.renderObject<RenderParagraph>(text);
                expect(
                  paragraph.getMaxIntrinsicWidth(double.infinity),
                  lessThanOrEqualTo(paragraph.size.width + .01),
                  reason:
                      'A compact destination must fit as a whole label at the requested size.',
                );
                await t.ensureVisible(tile);
                await t.pumpAndSettle();
                final rect = t.getRect(tile);
                expect(rect.top, greaterThanOrEqualTo(36));
                expect(rect.bottom, lessThanOrEqualTo(size.height));
              }
            }
            if (size.width >= 960) {
              for (final element
                  in find.byType(NexWorkspaceDestination).evaluate()) {
                final tile = find.byWidget(element.widget);
                final text = find
                    .descendant(of: tile, matching: find.byType(Text))
                    .first;
                expectFullSizeLabel(t, text);
                await t.ensureVisible(tile);
                await t.pumpAndSettle();
              }
              expectFullSizeLabel(
                t,
                find
                    .descendant(
                      of: find.byKey(const ValueKey('workspace-new-note')),
                      matching: find.byType(Text),
                    )
                    .first,
              );
            }
            for (final label in [
              l.pasteText,
              l.addImage,
              l.attach,
              l.addAudio,
              l.record,
              l.pastePhoto,
            ]) {
              final text = find.text(label);
              expectFullSizeLabel(t, text);
              await t.ensureVisible(text);
              await t.pumpAndSettle();
              expect(t.getRect(text).bottom, lessThanOrEqualTo(size.height));
            }
            expect(t.takeException(), isNull);
          } finally {
            await t.pumpWidget(const SizedBox());
            c.dispose();
            await t.runAsync(() async {
              await store.features.close();
              await store.root.delete(recursive: true);
            });
          }
        },
      );
    }
  }
}
