import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';

import '../core/controller.dart';
import '../core/theme_defs.dart';

/// CSS curve ports.
const Curve kPop = Cubic(.34, 1.56, .64, 1);
const Curve kSpring = Cubic(.22, 1.28, .36, 1);
const Curve kRise = Cubic(.2, .8, .2, 1);

/// Provides the palette, direction and controller down the tree so every
/// widget can match the original CSS without plumbing parameters.
class LiquidScope extends InheritedNotifier<PanelController> {
  const LiquidScope({
    super.key,
    required PanelController controller,
    required this.palette,
    required this.dir,
    required super.child,
  }) : super(notifier: controller);

  final LiquidPalette palette;
  final int dir;

  static (LiquidPalette, PanelController, int) of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<LiquidScope>()!;
    return (s.palette, s.notifier!, s.dir);
  }

  static LiquidPalette paletteOf(BuildContext context) => of(context).$1;
  static PanelController panelOf(BuildContext context) => of(context).$2;
  static int dirOf(BuildContext context) => of(context).$3;
}

/// Base text styles, ported from the CSS body / h4 / small rules.
TextStyle _body(BuildContext context, {double size = 13, Color? color}) {
  final p = LiquidScope.paletteOf(context);
  return TextStyle(
    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    fontFamilyFallback: const ['Segoe UI', 'Segoe UI Emoji'],
    fontSize: size,
    color: color ?? p.ink,
    height: 1.25,
  );
}

/// `.field` — borderless rounded input.
class Field extends StatefulWidget {
  const Field({
    super.key,
    this.controller,
    this.hint,
    this.focusNode,
    this.onChanged,
    this.onSubmit,
    this.onEnter,
    this.maxLines = 1,
    this.minLines,
    this.multiline = false,
    this.autofocusDelayed = false,
    this.style,
    this.keyboardType,
  });

  final TextEditingController? controller;
  final String? hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmit;
  final ValueChanged<String>? onEnter;
  final int maxLines;
  final int? minLines;
  final bool multiline;
  final bool autofocusDelayed;
  final TextStyle? style;
  final TextInputType? keyboardType;

  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  late final FocusNode _ownNode;
  bool _hadFocus = false;
  PanelController? _trackedPanel;

  @override
  void initState() {
    super.initState();
    _ownNode = widget.focusNode ?? FocusNode();
    _ownNode.addListener(_focusChanged);
    if (widget.autofocusDelayed) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) _ownNode.requestFocus();
      });
    }
  }

  void _focusChanged() {
    final has = _ownNode.hasFocus;
    final panel = _trackedPanel ??= LiquidScope.panelOf(context);
    if (has && !_hadFocus) panel.focusGained();
    if (!has && _hadFocus) panel.focusLost();
    _hadFocus = has;
  }

  @override
  void dispose() {
    // If disposed while focused, release the typing guard so the panel can
    // still auto-close.
    if (_hadFocus) _trackedPanel?.focusLost();
    _ownNode.removeListener(_focusChanged);
    if (widget.focusNode == null) _ownNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return TextField(
      controller: widget.controller,
      focusNode: _ownNode,
      textDirection: nexDirectionOf(widget.controller?.text),
      style:
          widget.style ??
          _body(context).copyWith(
            fontFamilyFallback: [
              'Segoe UI Variable Text',
              'Segoe UI',
              'Consolas',
              'Segoe UI Emoji',
            ],
          ),
      keyboardType: widget.keyboardType,
      maxLines: widget.multiline ? null : widget.maxLines,
      minLines: widget.multiline ? null : widget.minLines,
      expands: widget.multiline,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: _body(context, color: p.muted),
        filled: true,
        fillColor: p.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      cursorColor: p.inv,
      textAlignVertical: TextAlignVertical.top,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmit,
    );
  }
}

/// `.btn`.
class Btn extends StatefulWidget {
  const Btn({
    super.key,
    required this.child,
    this.onPressed,
    this.primary = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  State<Btn> createState() => _BtnState();
}

class _BtnState extends State<Btn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.primary ? p.inv : (_hover ? p.soft2 : p.soft),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: DefaultTextStyle(
            style: _body(context).copyWith(
              color: widget.primary ? p.invInk : p.ink,
              fontWeight: widget.primary ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// `.chip`.
class PillChip extends StatefulWidget {
  const PillChip({super.key, required this.label, this.on = false, this.onTap});

  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  State<PillChip> createState() => _ChipState();
}

class _ChipState extends State<PillChip> {
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
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.on ? p.inv : (_hover ? p.soft2 : p.soft),
            borderRadius: BorderRadius.circular(99),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Text(
            widget.label,
            style: _body(
              context,
              size: 12,
            ).copyWith(color: widget.on ? p.invInk : p.ink),
          ),
        ),
      ),
    );
  }
}

/// `.head` with an optional `.back` button, title and trailing link.
class Head extends StatelessWidget {
  const Head({super.key, this.title, this.onBack, this.trailing});

  final String? title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          if (onBack != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: PanelBackButton(onTap: onBack!),
            ),
          if (title != null)
            Flexible(
              child: Text(
                title!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(
                  context,
                  size: 11,
                  color: p.muted,
                ).copyWith(fontWeight: FontWeight.w600, letterSpacing: .9),
              ),
            )
          else
            const Spacer(),
          if (trailing != null) const SizedBox(width: 8),
          if (trailing != null)
            Flexible(
              child: DefaultTextStyle(
                style: _body(context, size: 11, color: p.muted),
                child: trailing!,
              ),
            ),
        ],
      ),
    );
  }
}

class PanelBackButton extends StatefulWidget {
  const PanelBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<PanelBackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<PanelBackButton> {
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
          duration: const Duration(milliseconds: 150),
          width: 24,
          height: 22,
          decoration: BoxDecoration(
            color: _hover ? p.soft2 : p.soft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              Directionality.of(context) == TextDirection.rtl ? '→' : '←',
              style: _body(context, size: 13),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.link`.
class LinkButton extends StatefulWidget {
  const LinkButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<LinkButton> {
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
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hover ? p.soft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _body(context, size: 12, color: _hover ? p.ink : p.muted),
          ),
        ),
      ),
    );
  }
}

/// `.item` list row used by clipboard, snippets, laps, units…
class ItemRow extends StatefulWidget {
  const ItemRow({
    super.key,
    required this.child,
    this.sub,
    this.pinned = false,
    this.plain = false,
    this.trailing,
    this.onTap,
    this.springy = true,
  });

  final Widget child;

  /// The <small> line.
  final Widget? sub;
  final bool pinned;
  final bool plain;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool springy;

  @override
  State<ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<ItemRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final (p, _, dir) = LiquidScope.of(context);
    final shift = _hover ? -4.0 * dir : 0.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: widget.springy ? 350 : 0),
          curve: kPop,
          transform: Matrix4.translationValues(shift, 0, 0),
          decoration: BoxDecoration(
            color: _hover ? p.soft2 : p.soft,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                width: 3,
                color: widget.pinned ? p.inv : Colors.transparent,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            left: widget.pinned ? 9 : 12,
            right: widget.plain ? 12 : 54,
            top: 9,
            bottom: 9,
          ),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: _body(
                      context,
                    ).copyWith(overflow: TextOverflow.ellipsis),
                    maxLines: 1,
                    child: widget.child,
                  ),
                  if (widget.sub != null)
                    DefaultTextStyle(
                      style: _body(context, size: 10, color: p.muted),
                      maxLines: 1,
                      child: widget.sub!,
                    ),
                ],
              ),
              if (widget.trailing != null)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _hover || widget.pinned ? 1 : 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [widget.trailing!],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tiny 22x22 action square inside `.item .acts`.
class ItemAction extends StatefulWidget {
  const ItemAction({super.key, required this.child, this.onTap, this.tooltip});

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<ItemAction> createState() => _ItemActionState();
}

class _ItemActionState extends State<ItemAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _hover ? p.soft2 : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: DefaultTextStyle(
              style: _body(context, size: 12, color: _hover ? p.ink : p.muted),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.empty`.
class Empty extends StatelessWidget {
  const Empty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(text, style: _body(context, size: 12, color: p.muted)),
      ),
    );
  }
}

/// `.hint`.
class Hint extends StatelessWidget {
  const Hint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: _body(context, size: 11, color: p.muted),
    );
  }
}

/// iOS-style `.toggle` switch.
class Toggle extends StatefulWidget {
  const Toggle({super.key, required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  State<Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<Toggle> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: widget.on
              ? Theme.of(context).colorScheme.primary
              : LiquidScope.paletteOf(context).soft2,
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 400),
          curve: kPop,
          alignment: widget.on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x49000000),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.set` row (label + control).
class SetRow extends StatelessWidget {
  const SetRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: SizedBox(
        height: 28,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Expanded(child: child)],
        ),
      ),
    );
  }
}

/// `.tabs` segmented control.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.current,
    this.onSwitch,
  });

  final List<String> tabs;
  final String current;
  final ValueChanged<String>? onSwitch;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: _SegTab(
                label: t,
                on: t == current,
                onTap: () => onSwitch?.call(t),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegTab extends StatefulWidget {
  const _SegTab({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_SegTab> createState() => _SegTabState();
}

class _SegTabState extends State<_SegTab> {
  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 26,
          decoration: BoxDecoration(
            color: widget.on ? p.inv : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: _body(context, size: 12).copyWith(
                color: widget.on ? p.invInk : p.muted,
                fontWeight: widget.on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders raw RGBA bytes (clipboard images) scaled to fit [maxExtent].
class RgbaImage extends StatefulWidget {
  const RgbaImage({
    super.key,
    required this.rgba,
    required this.w,
    required this.h,
    this.maxExtent = 240,
  });

  final Uint8List rgba;
  final int w;
  final int h;
  final double maxExtent;

  @override
  State<RgbaImage> createState() => _RgbaImageState();
}

class _RgbaImageState extends State<RgbaImage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(RgbaImage old) {
    super.didUpdateWidget(old);
    if (!identical(old.rgba, widget.rgba)) _decode();
  }

  Future<void> _decode() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(widget.rgba);
      final desc = ui.ImageDescriptor.raw(
        buffer,
        width: widget.w,
        height: widget.h,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await desc.instantiateCodec();
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _image = frame.image);
    } catch (_) {}
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return SizedBox(
        width: widget.maxExtent / 3,
        height: widget.maxExtent / 3,
      );
    }
    final s = widget.maxExtent / math.max(img.width, img.height);
    final size = Size(img.width * s, img.height * s);
    return CustomPaint(size: size, painter: _RgbaPainter(img, size));
  }
}

class _RgbaPainter extends CustomPainter {
  _RgbaPainter(this.image, this.size);

  final ui.Image image;
  final Size size;

  @override
  void paint(Canvas canvas, Size _) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(image, src, Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_RgbaPainter old) => old.image != image;
}
