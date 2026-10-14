// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the shared widget library split (see widgets.dart); do not import
// this file directly.
part of 'widgets.dart';

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
    final p = LiquidScope.paletteOf(context);
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
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
              ),
              if (widget.trailing != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10),
                  child: widget.trailing!,
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
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: widget.onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      iconSize: 17,
      icon: widget.child,
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
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.29),
                  offset: const Offset(0, 1),
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
