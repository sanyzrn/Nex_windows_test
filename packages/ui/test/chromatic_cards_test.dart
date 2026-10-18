import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

void main() {
  Note note(List<Tag> tags) => Note(
    id: 'n',
    type: NoteType.text,
    content: 'A colorful idea\nA readable preview.',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    deviceId: 'test',
    rev: 1,
    syncState: SyncState.pending,
    tags: tags,
  );
  test('tag fills retain readable secondary text in all shared palettes', () {
    for (final brightness in Brightness.values) {
      for (final preset in nexThemePresets) {
        final theme = nexApplyThemePreset(
          ThemeData(brightness: brightness),
          preset.id,
          null,
        );
        for (final seed in [
          '#000000',
          '#FFFFFF',
          '#0000FF',
          '#FF0000',
          '#00FF00',
          '#F2C572',
          '#8ECFB8',
          '#B4A1DC',
          '#8FC5EC',
        ]) {
          final n = note([Tag(createdAt: DateTime(2026), id: 't', name: 'Ideas', color: seed)]);
          final background = nexNoteCardColor(n, theme);
          expect(
            nexContrastRatio(theme.colorScheme.onSurfaceVariant, background),
            greaterThanOrEqualTo(4.45),
            reason: '${preset.id} $brightness $seed',
          );
          expect(
            nexContrastRatio(theme.colorScheme.onSurface, background),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    }
  });
  test('primary card color is stable across tag ordering and renames', () {
    final theme = ThemeData();
    final a = Tag(createdAt: DateTime(2026), id: 'oldest', name: 'Work', color: '#8ECFB8'),
        b = Tag(createdAt: DateTime(2026), id: 'recent', name: 'Ideas', color: '#F2C572');
    expect(
      nexNoteCardColor(note([a, b]), theme),
      nexNoteCardColor(note([b, a]), theme),
    );
    expect(
      nexNoteCardColor(note([a]), theme, highContrast: true),
      theme.colorScheme.surfaceContainerLowest,
    );
  });
  testWidgets('gallery cards retain readable content at 200 percent in RTL', (
    t,
  ) async {
    final n = note([Tag(createdAt: DateTime(2026), id: 'a', name: 'ایده‌های من', color: '#F2C572')]);
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: NoteCard(note: n, board: true, onTap: () {}),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('ایده‌های من'), findsOneWidget);
  });
}
