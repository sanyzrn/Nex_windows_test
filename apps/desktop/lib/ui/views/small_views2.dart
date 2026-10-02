import '../../l10n/utility_strings.dart';
import 'dart:async';
import '../../core/world_clock.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/controller.dart';
import '../../core/data.dart';
import '../../core/registry.dart';
import '../flyout.dart';
import '../svg_icon.dart';
import '../widgets.dart';

// ================= Media =================

class MediaView extends StatelessWidget {
  const MediaView({super.key});

  @override
  Widget build(BuildContext context) {
    final (_, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(title: utilityLabel(context, 'utility31'), onBack: () => _back(c)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MediaButton(
              icon: kMediaIcons['prev']!,
              onTap: () => c.native.pressKey('prev'),
            ),
            const SizedBox(width: 12),
            _MediaButton(
              icon: kMediaIcons['play']!,
              big: true,
              filled: true,
              onTap: () => c.native.pressKey('play'),
            ),
            const SizedBox(width: 12),
            _MediaButton(
              icon: kMediaIcons['next']!,
              onTap: () => c.native.pressKey('next'),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MediaButton(
              icon: kMediaIcons['voldown']!,
              onTap: () => c.native.pressKey('voldown'),
            ),
            const SizedBox(width: 12),
            _MediaButton(
              icon: kMediaIcons['mute']!,
              onTap: () => c.native.pressKey('mute'),
            ),
            const SizedBox(width: 12),
            _MediaButton(
              icon: kMediaIcons['volup']!,
              onTap: () => c.native.pressKey('volup'),
            ),
          ],
        ),
      ],
    );
  }

  void _back(PanelController c) {
    c.anchorY = c.fy.v;
    c.setPanel('more', fromMore: true);
  }
}

class _MediaButton extends StatefulWidget {
  const _MediaButton({
    required this.icon,
    required this.onTap,
    this.big = false,
    this.filled = false,
  });

  final String icon;
  final VoidCallback onTap;
  final bool big;
  final bool filled;

  @override
  State<_MediaButton> createState() => _MediaButtonState();
}

class _MediaButtonState extends State<_MediaButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    final size = widget.big ? 64.0 : 52.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? .9 : (_hover ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 200),
          curve: kPop,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.big ? p.inv : (_hover ? p.soft2 : p.soft),
            ),
            child: Center(
              child: SvgIcon(
                widget.icon,
                size: 22,
                filled: widget.filled,
                color: widget.big ? p.invInk : p.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= Generate =================

String _lorem =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.';

class GenerateView extends StatefulWidget {
  const GenerateView({super.key});

  static String uuidV4() {
    final rnd = math.Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static String p2(int n) => n.toString().padLeft(2, '0');

  static final Map<String, String Function()> gens = {
    'UUID': uuidV4,
    'Date': () {
      final d = DateTime.now();
      return '${d.year}-${p2(d.month)}-${p2(d.day)}';
    },
    'Time': () {
      final d = DateTime.now();
      return '${p2(d.hour)}:${p2(d.minute)}';
    },
    'ISO timestamp': () => DateTime.now().toUtc().toIso8601String(),
    'Unix time': () =>
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
    'Random 1-100': () => (1 + math.Random.secure().nextInt(100)).toString(),
    'Coin flip': () => math.Random.secure().nextBool() ? 'Heads' : 'Tails',
    'Lorem sentence': () => '${_lorem.split('. ')[0]}.',
    'Lorem paragraph': () => _lorem,
  };

  @override
  State<GenerateView> createState() => _GenerateViewState();
}

class _GenerateViewState extends State<GenerateView> {
  /// Fresh values each time the panel opens (like renderGen()).
  late final Map<String, String> values = {
    for (final e in GenerateView.gens.entries) e.key: e.value(),
  };

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(title: utilityLabel(context, 'utility32'), onBack: () => _back(c)),
        Column(
          children: [
            for (final e in GenerateView.gens.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ItemRow(
                  plain: true,
                  onTap: () => c.deliver(GenerateView.gens[e.key]!()),
                  trailing: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      _clip(values[e.key] ?? '', 24),
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                        color: p.muted,
                      ),
                    ),
                  ),
                  child: Text(utilityLabelForText(context, e.key)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';

  void _back(PanelController c) {
    c.anchorY = c.fy.v;
    c.setPanel('more', fromMore: true);
  }
}

// ================= Folders =================

class FoldersView extends StatelessWidget {
  const FoldersView({super.key});

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(title: utilityLabel(context, 'utility33'), onBack: () => _back(c)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in kFolders)
              SizedBox(
                width: 84,
                child: _FolderTile(
                  name: f[0],
                  target: f[1],
                  onTap: () {
                    c.close();
                    c.native.launch(f[1]);
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _back(PanelController c) {
    c.anchorY = c.fy.v;
    c.setPanel('more', fromMore: true);
  }
}

class _FolderTile extends StatefulWidget {
  const _FolderTile({
    required this.name,
    required this.target,
    required this.onTap,
  });

  final String name;
  final String target;
  final VoidCallback onTap;

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: kPop,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _hover ? p.soft2 : p.soft,
            borderRadius: BorderRadius.circular(_hover ? 18 : 14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: Center(
                  child: SvgIcon(
                    kTools['folders']!.svg!,
                    size: 22,
                    strokeWidth: 1.7,
                    color: p.ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                utilityLabelForText(context, widget.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.fontFamily,
                  fontFamilyFallback: const ['Segoe UI'],
                  fontSize: 11,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= Snippets =================

class SnippetsView extends StatefulWidget {
  const SnippetsView({super.key});

  @override
  State<SnippetsView> createState() => _SnippetsViewState();
}

class _SnippetsViewState extends State<SnippetsView> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (_, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(
          title: utilityLabel(context, 'utility34'),
          onBack: () => _back(c),
          trailing: Hint(utilityLabel(context, 'utility27')),
        ),
        Field(
          controller: _input,
          hint: utilityLabel(context, 'utility35'),
          autofocusDelayed: true,
          onSubmit: (v) {
            if (v.trim().isNotEmpty) {
              c.S.snippets.insert(0, v.trim());
              _input.clear();
              c.save();
              c.refresh();
            }
          },
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: c.S.snippets.isEmpty
              ? Empty(utilityLabel(context, 'utility28'))
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < c.S.snippets.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ItemRow(
                            onTap: () => c.deliver(c.S.snippets[i]),
                            trailing: ItemAction(
                              child: const Text('×'),
                              onTap: () {
                                c.S.snippets.removeAt(i);
                                c.save();
                                c.refresh();
                              },
                            ),
                            child: Text(
                              c.S.snippets[i]
                                          .replaceAll(RegExp(r'\s+'), ' ')
                                          .length >
                                      100
                                  ? c.S.snippets[i]
                                        .replaceAll(RegExp(r'\s+'), ' ')
                                        .substring(0, 100)
                                  : c.S.snippets[i].replaceAll(
                                      RegExp(r'\s+'),
                                      ' ',
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _back(PanelController c) {
    c.anchorY = c.fy.v;
    c.setPanel('more', fromMore: true);
  }
}

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
    c.anchorY = c.fy.v;
    c.setPanel('more', fromMore: true);
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
      parts.time,
      '${utilityLabelForText(context, dayStr)}, ${utilityLabelForText(context, diffStr)}',
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
    c.anchorY = c.fy.v;
    c.setPanel('more', fromMore: true);
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
      child: GestureDetector(
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
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    final remaining = kZones.where((z) => !current.contains(z)).toList();
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        dropdownColor: p.liquid,
        hint: Text(
          utilityLabel(context, 'utility30'),
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            fontFamilyFallback: const ['Segoe UI'],
            fontSize: 13,
            color: p.ink,
          ),
        ),
        style: TextStyle(
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          fontFamilyFallback: const ['Segoe UI'],
          fontSize: 13,
          color: p.ink,
        ),
        icon: const SizedBox.shrink(),
        items: [
          for (final z in remaining)
            DropdownMenuItem(
              value: z,
              child: Text(
                utilityLabelForText(
                  context,
                  z.split('/').last.replaceAll('_', ' '),
                ),
              ),
            ),
        ],
        onChanged: (z) {
          if (z != null) onAdd(z);
        },
      ),
    );
  }
}
