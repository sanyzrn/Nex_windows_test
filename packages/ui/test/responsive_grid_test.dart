import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_ui/nex_ui.dart';

void main() {
  testWidgets('cards in one row are one height; a short last row keeps its '
      'column width', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            child: NexResponsiveGrid(
              minWidth: 200,
              maxColumns: 3,
              spacing: 10,
              equalHeights: true,
              children: [
                for (final (i, h) in [40.0, 120.0, 80.0, 30.0].indexed)
                  Container(
                    key: ValueKey('card-$i'),
                    height: h,
                    color: Colors.blue,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    Size size(int i) => t.getSize(find.byKey(ValueKey('card-$i')));
    // First row: the tallest (120) sets all three.
    expect(size(0).height, 120);
    expect(size(1).height, 120);
    expect(size(2).height, 120);
    // The lone card in the second row is as wide as the others, not full width.
    expect(size(3).width, size(0).width);
    expect(size(0).width, closeTo((640 - 20) / 3, .01));
  });
}
