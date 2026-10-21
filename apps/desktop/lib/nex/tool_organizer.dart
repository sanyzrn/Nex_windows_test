import '../l10n/desktop_format.dart';
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/registry.dart';
import '../l10n/app_localizations.dart';
import '../l10n/utility_strings.dart';

/// A bounded, searchable tool list shared by both settings surfaces.
class NexToolOrganizer extends StatefulWidget {
  const NexToolOrganizer({super.key, required this.controller});
  final PanelController controller;
  @override
  State<NexToolOrganizer> createState() => _NexToolOrganizerState();
}

class _NexToolOrganizerState extends State<NexToolOrganizer> {
  final search = TextEditingController();
  String query = '', filter = 'dock';
  int page = 0;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String placement(String id) => widget.controller.S.hidden.contains(id)
      ? 'hidden'
      : widget.controller.S.dock!.contains(id)
      ? 'dock'
      : 'more';

  void move(String id, String destination) {
    final c = widget.controller;
    if (destination == 'hidden') {
      if (!c.S.hidden.contains(id)) c.S.hidden.add(id);
      c.save();
      c.refresh();
    } else {
      c.moveWidget(
        id,
        destination,
        destination == 'dock' ? c.S.dock!.length : c.S.more!.length,
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final l = AppLocalizations.of(context)!;
    final labels = {
      'dock': l.toolDock,
      'more': l.toolMore,
      'hidden': l.toolHidden,
    };
    final tools = <({String id, String name, bool dockOnly, bool app})>[
      for (final t in kTools.values.where((t) => !t.fixed && t.id != 'more'))
        (
          id: t.id,
          name: utilityLabelForText(context, t.name),
          dockOnly: t.dockOnly,
          app: false,
        ),
      for (final a in c.S.apps)
        (id: a.id, name: a.name, dockOnly: false, app: true),
    ];
    final matching = tools
        .where(
          (t) => query.isNotEmpty
              ? t.name.toLowerCase().contains(query.toLowerCase()) ||
                    t.id.contains(query.toLowerCase())
              : placement(t.id) == filter,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('tool-search'),
          controller: search,
          decoration: InputDecoration(
            hintText: l.toolSearch,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (v) => setState(() {
            query = v.trim();
            page = 0;
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in labels.entries)
              ChoiceChip(
                label: Text(
                  desktopDigits(
                    context,
                    '${entry.value} · ${tools.where((t) => placement(t.id) == entry.key).length}',
                  ),
                ),
                selected: filter == entry.key,
                onSelected: (_) => setState(() {
                  filter = entry.key;
                  search.clear();
                  query = '';
                  page = 0;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620 ? 2 : 1;
            final size = columns * 4;
            final pages = (matching.length / size).ceil().clamp(1, 1000);
            final current = page.clamp(0, pages - 1);
            final visible = matching.skip(current * size).take(size);
            return Column(
              children: [
                if (matching.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(l.empty),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final t in visible)
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t.name,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  key: ValueKey('tool-placement-${t.id}'),
                                  value: placement(t.id),
                                  underline: const SizedBox(),
                                  items: [
                                    for (final entry in labels.entries)
                                      if (!t.dockOnly || entry.key != 'more')
                                        DropdownMenuItem(
                                          value: entry.key,
                                          child: Text(
                                            entry.value,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) move(t.id, v);
                                  },
                                ),
                                if (t.app)
                                  IconButton(
                                    tooltip: l.remove,
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      c.removeApp(t.id);
                                      setState(() {});
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (pages > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: l.previousPage,
                        onPressed: current == 0
                            ? null
                            : () => setState(() => page = current - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(desktopDigits(context, '${current + 1} / $pages')),
                      IconButton(
                        tooltip: l.nextPage,
                        onPressed: current + 1 == pages
                            ? null
                            : () => setState(() => page = current + 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
