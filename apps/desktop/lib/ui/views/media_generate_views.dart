import '../../l10n/app_localizations.dart';
import '../../l10n/utility_strings.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/controller.dart';
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
              label: AppLocalizations.of(context)!.mediaPrevious,
              onTap: () => c.native.pressKey('prev'),
            ),
            const SizedBox(width: 12),
            _MediaButton(
              icon: kMediaIcons['play']!,
              label: AppLocalizations.of(context)!.mediaPlayPause,
              big: true,
              filled: true,
              onTap: () => c.native.pressKey('play'),
            ),
            const SizedBox(width: 12),
            _MediaButton(
              icon: kMediaIcons['next']!,
              label: AppLocalizations.of(context)!.mediaNext,
              onTap: () => c.native.pressKey('next'),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MediaButton(
              icon: kMediaIcons['voldown']!,
              label: AppLocalizations.of(context)!.volumeDown,
              onTap: () => c.native.pressKey('voldown'),
            ),
            const SizedBox(width: 12),
            _MediaButton(
              icon: kMediaIcons['mute']!,
              label: AppLocalizations.of(context)!.volumeMute,
              onTap: () => c.native.pressKey('mute'),
            ),
            const SizedBox(width: 12),
            _MediaButton(
              icon: kMediaIcons['volup']!,
              label: AppLocalizations.of(context)!.volumeUp,
              onTap: () => c.native.pressKey('volup'),
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

class _MediaButton extends StatefulWidget {
  const _MediaButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.big = false,
    this.filled = false,
  });

  final String icon;
  final String label;
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
      child: DesktopAction(
        label: widget.label,
        excludeSemantics: true,
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
    c.backToTools();
  }
}
