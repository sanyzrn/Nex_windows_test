import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/desktop_date_picker.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/note_detail_parts.dart';
import 'package:nex_desktop/nex/reminder_picker.dart';
import 'package:nex_desktop/updates/release_notes.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_core/nex_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/review_fixture.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle({this.fail = false});
  final bool fail;
  final loaded = <String>[];
  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    if (fail) throw StateError('test missing asset');
    return ByteData.sublistView(
      Uint8List.fromList(
        utf8.encode(
          key.endsWith('.fa.md') ? '# بهبود نکس' : '# Nex improvements',
        ),
      ),
    );
  }
}

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

Widget _app(
  Widget home, {
  Locale locale = const Locale('fa'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: home),
);

void main() {
  test(
    'Persian release history retains every version and bullet in each section',
    () {
      final en = File('CHANGELOG.md').readAsStringSync();
      final fa = File(
        'assets/CHANGELOG.fa.md',
      ).readAsStringSync().replaceAll('منتشرنشده', 'Unreleased');
      List<(String, int)> sections(String source) {
        final blocks = source.split(RegExp(r'^## ', multiLine: true)).skip(1);
        return [
          for (final b in blocks)
            (
              b.split('\n').first.trim(),
              RegExp(r'^- ', multiLine: true).allMatches(b).length,
            ),
        ];
      }

      expect(sections(fa), sections(en));
      expect(
        sections(fa).length,
        15,
      ); // Includes the 0.28.0 development section.
    },
  );

  testWidgets('release notes reload the local asset when language changes', (
    t,
  ) async {
    final bundle = _Bundle();
    final locale = ValueNotifier(const Locale('en'));
    addTearDown(locale.dispose);
    await t.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: ValueListenableBuilder(
          valueListenable: locale,
          builder: (_, value, __) =>
              _app(const ReleaseNotesButton(), locale: value),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('release-notes-open')));
    await t.pumpAndSettle();
    expect(
      t.widget<NexMarkdown>(find.byType(NexMarkdown)).text,
      '# Nex improvements',
    );
    locale.value = const Locale('fa');
    await t.pumpAndSettle();
    expect(t.widget<NexMarkdown>(find.byType(NexMarkdown)).text, '# بهبود نکس');
    expect(
      bundle.loaded,
      containsAll(['CHANGELOG.md', 'assets/CHANGELOG.fa.md']),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('missing release notes have a localized failure state', (
    t,
  ) async {
    await t.pumpWidget(
      DefaultAssetBundle(
        bundle: _Bundle(fail: true),
        child: _app(const ReleaseNotesButton()),
      ),
    );
    await t.tap(find.byKey(const ValueKey('release-notes-open')));
    await t.pumpAndSettle();
    expect(find.text('یادداشت‌های انتشار بارگذاری نشد.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Solar date selection clamps leap Esfand when changing year', (
    t,
  ) async {
    DateTime? result;
    await t.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDesktopDatePicker(
                context,
                initialDate: DateTime(2025, 3, 20),
                firstDate: DateTime(2024),
                lastDate: DateTime(2027, 12, 31),
                solar: true,
              );
            },
            child: const Text('open'),
          ),
        ),
        textScale: 2,
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('۱۴۰۳/۱۲/۳۰'), findsOneWidget);
    final yearText = t.renderObject<RenderParagraph>(find.text('۱۴۰۳'));
    expect(
      yearText.getMinIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(yearText.size.width + .5),
    );
    await t.tap(find.byKey(const ValueKey('solar-year-1403')));
    await t.pumpAndSettle();
    await t.tap(find.text('۱۴۰۴').last);
    await t.pumpAndSettle();
    expect(find.text('۱۴۰۴/۱۲/۲۹'), findsOneWidget);
    final material = MaterialLocalizations.of(
      t.element(find.byKey(const ValueKey('solar-date-picker'))),
    );
    await t.tap(find.widgetWithText(FilledButton, material.okButtonLabel));
    await t.pumpAndSettle();
    expect(result, DateTime(2026, 3, 20));
  });

  testWidgets(
    'reminder route preserves the explicit calendar preference in Persian',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      for (final solar in [false, true]) {
        final c = PanelController(nativeHost: _Native());
        await c.bootstrap(
          preset: Settings()
            ..language = 'fa'
            ..solarCalendar = solar,
          useNative: false,
        );
        final at = DateTime.now().add(const Duration(days: 2));
        final note = Note(
          id: 'calendar',
          type: NoteType.text,
          content: 'fixture',
          createdAt: at,
          updatedAt: at,
          deviceId: 'test',
          rev: 1,
          syncState: SyncState.pending,
        );
        await t.pumpWidget(
          _app(
            NexPanelScope(
              controller: c,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showReminderPicker(
                    context,
                    note: note,
                    onSave: (_, __) async {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        final l = AppLocalizations.of(t.element(find.byType(AlertDialog)))!;
        await t.tap(find.text(l.customDateTime));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('solar-date-picker')),
          solar ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(CalendarDatePicker),
          solar ? findsNothing : findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
        c.dispose();
      }
    },
  );

  testWidgets(
    'Persian attachment badges localize counts in both card layouts',
    (t) async {
      final at = DateTime(2026, 10, 4);
      final note = Note(
        id: 'count',
        type: NoteType.text,
        content: 'Original 123',
        createdAt: at,
        updatedAt: at,
        deviceId: 'test',
        rev: 1,
        syncState: SyncState.pending,
        attachmentCount: 2,
      );
      for (final board in [false, true]) {
        await t.pumpWidget(
          _app(
            SizedBox(
              width: 360,
              height: 220,
              child: NoteCard(note: note, board: board),
            ),
          ),
        );
        expect(find.text(board ? '۲' : '+۲'), findsOneWidget);
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Persian reader localizes its word count without editing note content',
    (t) async {
      const spec = ReviewShot(
        'compact_digit_regression',
        mode: 'window',
        locale: 'fa',
        size: Size(460, 760),
        target: 'readerText',
      );
      final store = (await t.runAsync(
        () => openReviewStore(spec.name, count: 12),
      ))!;
      final c = await bootReview(t, spec, store);
      try {
        await goReview(t, c, spec);
        final texts = t.widgetList<Text>(
          find.descendant(
            of: find.byType(NoteMetadataLine),
            matching: find.byType(Text),
          ),
        );
        final words = texts
            .map((w) => w.data ?? '')
            .singleWhere((v) => v.contains('واژه'));
        expect(RegExp('[0-9]').hasMatch(words), isFalse);
        expect(RegExp('[۰-۹]').hasMatch(words), isTrue);
        final note = await t.runAsync(
          () => store.features.store.call<Note>('get', {'id': 'review-0'}),
        );
        expect(note!.content, contains('10:00'));
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        c.dispose();
        await closeReviewStore(t, store);
      }
    },
  );
}
