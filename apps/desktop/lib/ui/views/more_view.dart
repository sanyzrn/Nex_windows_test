import '../../l10n/utility_strings.dart';
import 'package:flutter/material.dart';

import '../../core/controller.dart';
import '../dock.dart';
import '../flyout.dart';
import '../widgets.dart';

/// The "More" tools grid. Tiles can be dragged onto the dock.
class MoreView extends StatelessWidget {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    final more = c.S.more!.where((id) => !c.S.hidden.contains(id)).toList();

    return Panel(
      children: [
        Head(
          title: utilityLabel(context, 'utility15'),
          trailing: Hint(utilityLabel(context, 'utility13')),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70, maxHeight: 400),
          child: more.isEmpty
              ? Empty(utilityLabel(context, 'utility14'))
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    key: c.zoneKeys['more'],
                    child: ValueListenableBuilder<DragInfo?>(
                      valueListenable: c.dragInfo,
                      builder: (context, drag, _) {
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tiles(c, more, drag),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _tiles(PanelController c, List<String> more, DragInfo? drag) {
    final tiles = <Widget>[];
    var idx = 0;
    for (final id in more) {
      if (drag?.zone == 'more' && drag!.insertIdx == idx) {
        tiles.add(const _TilePlaceholder());
      }
      tiles.add(
        SizedBox(
          key: c.toolKey(id),
          width: 84,
          child: _Tile(
            controller: c,
            id: id,
            on: id == 'awake' && c.awake,
            active: c.sub && c.panel == id,
          ),
        ),
      );
      idx++;
    }
    if (drag?.zone == 'more' && drag!.insertIdx == idx) {
      tiles.add(const _TilePlaceholder());
    }
    return tiles;
  }
}

class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder();

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: kPop,
      builder: (context, t, child) => Container(
        width: 84,
        constraints: const BoxConstraints(minHeight: 66),
        decoration: BoxDecoration(
          border: Border.all(width: 2, color: p.muted.withValues(alpha: t)),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.controller,
    required this.id,
    required this.on,
    required this.active,
  });

  final PanelController controller;
  final String id;
  final bool on;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ToolVisual(
      controller: controller,
      id: id,
      active: active,
      dimmed:
          controller.dragInfo.value?.id == id &&
          controller.dragInfo.value!.moved,
      tileStyle: true,
    );
  }
}
