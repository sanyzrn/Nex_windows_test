import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_ui/nex_ui.dart';

/// Every menu in the app is the card's hold menu: the same width, corners,
/// surface and padding, an icon on every action line, red for what destroys.
/// One place makes that so (`NexPopupMenuButton` and `nexMenuItem` in
/// packages/ui), and this keeps the next menu from being drawn some other way
/// — which is how the thread and tag menus came to be smaller, plainer and
/// without icons than the card's own.
void main() {
  testWidgets('a page menu looks like the card menu: icon, width, corners', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: nexLightTheme(),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              NexPopupMenuButton<String>(
                key: const ValueKey('menu'),
                itemBuilder: (_) => [
                  nexMenuItem(
                    value: 'edit',
                    icon: Icons.edit_outlined,
                    label: 'Rename',
                  ),
                  nexMenuItem(
                    value: 'delete',
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    destructive: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('menu')));
    await tester.pumpAndSettle();

    // An icon on every action line.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    // At least the shared width, however short the words.
    final rename = tester.getSize(
      find.ancestor(of: find.text('Rename'), matching: find.byType(InkWell)),
    );
    expect(rename.width, greaterThanOrEqualTo(180));
    expect(rename.height, greaterThanOrEqualTo(48));
    // The card menu's corners and raised surface: the menu's own Material.
    final surface = tester
        .widgetList<Material>(find.byType(Material))
        .firstWhere(
          (m) => m.shape is RoundedRectangleBorder && m.elevation == 3,
        );
    expect(
      (surface.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(NexRadius.lg),
    );
  });
  for (final dark in [false, true]) {
    for (final glass in [false, true]) {
      testWidgets('destructive menu contrast dark=$dark glass=$glass', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark
                ? nexDarkTheme(liquidGlass: glass)
                : nexLightTheme(liquidGlass: glass),
            home: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final ground = glass
                    ? context.nexVisualStyle.floatingContrastGround(
                        theme.brightness,
                      )
                    : theme.colorScheme.surfaceContainerHigh;
                expect(
                  nexContrast(nexMenuErrorColor(context), ground),
                  greaterThanOrEqualTo(4.5),
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      });
    }
  }
}
