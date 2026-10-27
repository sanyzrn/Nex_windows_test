import '../desktop_dropdown.dart';
import '../../l10n/desktop_format.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/utility_strings.dart';
import 'dart:async';
import '../../core/world_clock.dart';

import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/controller.dart';
import '../../core/data.dart';
import '../flyout.dart';
import '../widgets.dart';

// ================= Web search =================

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _go(PanelController c) {
    final q = _input.text.trim();
    if (q.isEmpty) return;
    final url =
        RegExp(r'^[\w-]+(\.[\w-]+)+(\/\S*)?$').hasMatch(q) && !q.contains(' ')
        ? 'https://$q'
        : q.startsWith(RegExp(r'https?://'))
        ? q
        : (kEngines[c.S.engine] ?? kEngines['Google']!).replaceAll(
            '%s',
            Uri.encodeComponent(q),
          );
    _input.clear();
    c.close();
    c.native.launch(url);
  }

  @override
  Widget build(BuildContext context) {
    final (_, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(title: utilityLabel(context, 'utility36'), onBack: () => _back(c)),
        Field(
          controller: _input,
          hint: utilityLabel(context, 'utility37'),
          autofocusDelayed: true,
          onSubmit: (_) => _go(c),
        ),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final name in kEngines.keys)
              PillChip(
                label: name,
                on: c.S.engine == name,
                onTap: () {
                  c.S.engine = name;
                  c.save();
                  c.refresh();
                },
              ),
          ],
        ),
      ],
    );
  }

  void _back(PanelController c) {
    c.backToTools();
  }
}

// ================= World clock =================

class ClockView extends StatefulWidget {
  const ClockView({super.key});

  @override
  State<ClockView> createState() => _ClockViewState();
}

class _ClockViewState extends State<ClockView> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  (String, String) _zoneParts(String zone) {
    final now = DateTime.now();
    tz.Location loc;
    try {
      loc = tz.getLocation(zone);
    } catch (_) {
      return ('--:--', zone);
    }
    final parts = worldClock(now, loc);
    final minutes = parts.offset.inMinutes;
    final dayStr = parts.day == 0
        ? 'Today'
        : parts.day > 0
        ? 'Tomorrow'
        : 'Yesterday';
    final diffStr = minutes == 0
        ? 'same time'
        : '${minutes > 0 ? '+' : '-'}${minutes.abs() ~/ 60}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';
    return (
      desktopDigits(context, parts.time),
      desktopDigits(
        context,
        '${utilityLabelForText(context, dayStr)}, ${utilityLabelForText(context, diffStr)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(title: utilityLabel(context, 'utility38'), onBack: () => _back(c)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: c.S.zones.isEmpty
              ? Empty(utilityLabel(context, 'utility29'))
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < c.S.zones.length; i++)
                        _ZoneRow(
                          zone: c.S.zones[i],
                          parts: _zoneParts(c.S.zones[i]),
                          onRemove: () {
                            c.S.zones.removeAt(i);
                            c.save();
                            c.refresh();
                          },
                        ),
                    ],
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: p.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _ZonePicker(
            current: c.S.zones,
            onAdd: (z) {
              c.S.zones.add(z);
              c.save();
              c.refresh();
            },
          ),
        ),
      ],
    );
  }

  void _back(PanelController c) {
    c.backToTools();
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.zone,
    required this.parts,
    required this.onRemove,
  });

  final String zone;
  final (String, String) parts;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    final city = zone.split('/').last.replaceAll('_', ' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: p.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                parts.$1,
                style: TextStyle(
                  fontFamily: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.fontFamily,
                  fontFamilyFallback: const ['Segoe UI'],
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: p.ink,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    utilityLabelForText(context, city),
                    style: TextStyle(
                      fontFamily: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.fontFamily,
                      fontFamilyFallback: const ['Segoe UI'],
                      fontSize: 13,
                      color: p.ink,
                    ),
                  ),
                  Text(
                    parts.$2,
                    style: TextStyle(
                      fontFamily: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.fontFamily,
                      fontFamilyFallback: const ['Segoe UI'],
                      fontSize: 10,
                      color: p.muted,
                    ),
                  ),
                ],
              ),
            ),
            _SmallX(onTap: onRemove),
          ],
        ),
      ),
    );
  }
}

class _SmallX extends StatefulWidget {
  const _SmallX({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SmallX> createState() => _SmallXState();
}

class _SmallXState extends State<_SmallX> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: DesktopAction(
        excludeSemantics: true,
        label: AppLocalizations.of(context)!.remove,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _hover ? p.soft2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '×',
              style: TextStyle(
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                fontFamilyFallback: const ['Segoe UI'],
                fontSize: 14,
                color: _hover ? p.ink : p.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZonePicker extends StatelessWidget {
  const _ZonePicker({required this.current, required this.onAdd});
  final List<String> current;
  final ValueChanged<String> onAdd;
  @override
  Widget build(BuildContext context) => DesktopDropdown<String>(
    hint: Text(
      utilityLabel(context, 'utility30'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    items: [
      for (final z in kZones.where((z) => !current.contains(z)))
        DropdownMenuItem(
          value: z,
          child: Text(
            utilityLabelForText(
              context,
              z.split('/').last.replaceAll('_', ' '),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (z) {
      if (z != null) onAdd(z);
    },
  );
}
