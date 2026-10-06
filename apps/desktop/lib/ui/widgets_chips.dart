// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the shared widget library split (see widgets.dart); do not import
// this file directly.
part of 'widgets.dart';

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
  const PanelBackButton({super.key, required this.onTap, this.size = 22});

  final VoidCallback onTap;

  /// Height of the button; the width and radius follow it. Views that place
  /// it beside a taller field pass a matching size (audit defect 10).
  final double size;

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
          width: widget.size + 10,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hover ? p.soft2 : p.soft,
            borderRadius: BorderRadius.circular(widget.size / 2.4),
          ),
          child: Center(
            child: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
              size: widget.size * .62,
              color: p.ink,
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
