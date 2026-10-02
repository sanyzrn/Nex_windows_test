import '../../l10n/utility_strings.dart';
import 'package:flutter/material.dart';

import '../../core/controller.dart';
import '../../core/data.dart';
import '../flyout.dart';
import '../svg_icon.dart';
import '../widgets.dart';

/// Color: eyedropper, HEX/RGB/HSL, palette, recents.
class ColorView extends StatefulWidget {
  const ColorView({super.key});

  @override
  State<ColorView> createState() => _ColorViewState();
}

class _ColorViewState extends State<ColorView> {
  Color color = const Color(0xFF3B82F6);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    color = hexToColor(LiquidScope.panelOf(context).pickedColorHex);
  }

  (int, int, int) get _rgb => (
    (color.r * 255).round(),
    (color.g * 255).round(),
    (color.b * 255).round(),
  );

  List<int> get _hsl {
    var r = (color.r * 255).round() / 255,
        g = (color.g * 255).round() / 255,
        b = (color.b * 255).round() / 255;
    final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
    var h = 0.0, s = 0.0;
    final l = (mx + mn) / 2;
    if (mx != mn) {
      final d = mx - mn;
      s = l > .5 ? d / (2 - mx - mn) : d / (mx + mn);
      if (mx == r) {
        h = (g - b) / d + (g < b ? 6 : 0);
      } else if (mx == g) {
        h = (b - r) / d + 2;
      } else {
        h = (r - g) / d + 4;
      }
      h *= 60;
    }
    return [h.round(), (s * 100).round(), (l * 100).round()];
  }

  String get _hexStr =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  String get _rgbStr {
    final (r, g, b) = _rgb;
    return 'rgb($r, $g, $b)';
  }

  String get _hslStr {
    final h = _hsl;
    return 'hsl(${h[0]}, ${h[1]}%, ${h[2]}%)';
  }

  void _setColor(Color c) => setState(() => color = c);

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(
          title: utilityLabel(context, 'utility5'),
          onBack: () => _backToMore(c),
          trailing: LinkButton(
            label: utilityLabel(context, 'utility6'),
            onTap: () {
              c.picking = true;
              c.close();
              c.native.pickColor();
            },
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => c.pickCustomColorFor('color'),
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.line),
                ),
                child: Center(
                  child: SvgIcon(
                    '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
                    size: 22,
                    color: useWhiteText(color) ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FmtRow(
                    label: utilityLabel(context, 'utility7'),
                    value: _hexStr,
                    onTap: () {
                      c.copy(_hexStr);
                      c.pushRecentColor(color);
                    },
                  ),
                  const SizedBox(height: 4),
                  _FmtRow(
                    label: utilityLabel(context, 'utility8'),
                    value: _rgbStr,
                    onTap: () {
                      c.copy(_rgbStr);
                      c.pushRecentColor(color);
                    },
                  ),
                  const SizedBox(height: 4),
                  _FmtRow(
                    label: utilityLabel(context, 'utility9'),
                    value: _hslStr,
                    onTap: () {
                      c.copy(_hslStr);
                      c.pushRecentColor(color);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        Head(title: utilityLabel(context, 'utility10')),
        _Swatches(
          colors: [for (final v in kPalette) Color(v)],
          onTap: (col) {
            _setColor(col);
            c.copy(_hexStr);
          },
        ),
        Head(title: utilityLabel(context, 'utility11')),
        c.S.recentColors.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Empty(utilityLabel(context, 'utility4')),
              )
            : _Swatches(
                colors: c.S.recentColors,
                onTap: (col) {
                  _setColor(col);
                  c.copy(_hexStr);
                },
              ),
      ],
    );
  }

  void _backToMore(PanelController c) {
    c.anchorY = c.fy.v;
    c.setPanel('more', fromMore: true);
  }
}

bool useWhiteText(Color c) =>
    .2126 * (c.r * 255).round() / 255 +
        .7152 * (c.g * 255).round() / 255 +
        .0722 * (c.b * 255).round() / 255 <
    .55;

class _FmtRow extends StatefulWidget {
  const _FmtRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  State<_FmtRow> createState() => _FmtRowState();
}

class _FmtRowState extends State<_FmtRow> {
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
          duration: const Duration(milliseconds: 120),
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: _hover ? p.soft2 : p.soft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.value,
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: p.ink,
                  ),
                ),
              ),
              Text(
                widget.label,
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
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors, required this.onTap});

  final List<Color> colors;
  final ValueChanged<Color> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [for (final col in colors) _Swatch(color: col, onTap: onTap)],
    );
  }
}

class _Swatch extends StatefulWidget {
  const _Swatch({required this.color, required this.onTap});

  final Color color;
  final ValueChanged<Color> onTap;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.color),
        child: AnimatedScale(
          scale: _hover ? 1.25 : 1,
          duration: const Duration(milliseconds: 350),
          curve: kPop,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(color: p.line),
            ),
          ),
        ),
      ),
    );
  }
}
