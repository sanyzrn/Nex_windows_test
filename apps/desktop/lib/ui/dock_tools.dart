// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the dock split (see dock.dart); do not import this file directly.
part of 'dock.dart';

class _ToolSlot extends StatelessWidget {
  const _ToolSlot({
    super.key,
    required this.controller,
    required this.id,
    required this.index,
    required this.active,
  });

  final PanelController controller;
  final String id;
  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.frame,
      builder: (context, _, __) {
        final sp = controller.springsFor(id).sp;
        final mg = controller.springsFor(id).mg;
        final pr = controller.springsFor(id).pr;
        final p = sp.v.clamp(0.0, 1.0);
        final M = mg.v.clamp(0.0, 1.0);
        final P = pr.v.clamp(0.0, 1.0);
        final dir = controller.dir;

        final tx = (1 - p) * 20 * dir;
        final scale = (.55 + .45 * p) * (1 + M * .16) * (1 - P * .14);

        Widget child = ToolVisual(
          controller: controller,
          id: id,
          active: active,
          dimmed:
              controller.dragInfo.value?.id == id &&
              controller.dragInfo.value!.moved,
        );

        child = Transform.translate(
          offset: Offset(tx, 0),
          child: Transform.scale(scale: scale, child: child),
        );
        if (p < .97) {
          final sigma = (1 - p) * 6;
          child = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          );
        }
        child = Opacity(opacity: p, child: child);
        return SizedBox(width: 44, height: 44, child: child);
      },
    );
  }
}

/// The pressable tool button (44x44, soft bg, hover radius change, dot).
class ToolVisual extends StatefulWidget {
  const ToolVisual({
    super.key,
    required this.controller,
    required this.id,
    required this.active,
    this.dimmed = false,
    this.tileStyle = false,
    this.smallIcon = false,
  });

  final PanelController controller;
  final String id;
  final bool active;
  final bool dimmed;

  /// Tiles (in the More panel) have the same look with column layout.
  final bool tileStyle;
  final bool smallIcon;

  @override
  State<ToolVisual> createState() => ToolVisualState();
}

class ToolVisualState extends State<ToolVisual> {
  bool _hover = false;
  bool _openedOnEnter = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    final info = ToolInfo.of(widget.id);
    final isApp = info.kind == ToolKind.app;
    final onDot = widget.id == 'awake' && widget.controller.awake;

    final iconColor = widget.active ? p.invInk : p.ink;

    Widget icon;
    final coreIcon = switch (widget.id) {
      'note' => Icons.edit_note_rounded,
      'timeline' => Icons.notes_rounded,
      'more' => Icons.grid_view_rounded,
      'settings' => Icons.settings_outlined,
      _ => null,
    };
    if (coreIcon != null) {
      icon = Icon(coreIcon, size: widget.smallIcon ? 18 : 23, color: iconColor);
    } else if (info.emoji != null) {
      icon = Text(
        info.emoji!,
        style: TextStyle(
          fontFamily: 'Segoe UI Emoji',
          fontFamilyFallback: const ['Segoe UI Emoji'],
          fontSize: widget.smallIcon ? 14 : 19,
        ),
      );
    } else if (isApp && info.app?.icon != null) {
      icon = AppIconImage(dataUri: info.app!.icon!);
    } else if (info.svg != null) {
      icon = SvgIcon(
        info.svg!,
        size: widget.smallIcon ? 17 : 20,
        color: iconColor,
      );
    } else {
      icon = const SizedBox.shrink();
    }

    if (widget.id == 'settings') {
      icon = NexUpdateDot(
        updates: NexScope.maybeOf(context)?.updates,
        child: icon,
      );
    }

    if (widget.tileStyle) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: _enter,
        onHover: _hoverMove,
        onExit: _exit,
        child: DesktopAction(
          behavior: HitTestBehavior.opaque,
          label: utilityLabelForText(context, info.name),
          selected: widget.active,
          excludeSemantics: true,
          onTap: _tap,
          onTapDown: _down,
          child: Listener(
            onPointerDown: _dragStart,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: kPop,
              transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
              decoration: BoxDecoration(
                color: widget.active ? p.inv : (_hover ? p.soft2 : p.soft),
                borderRadius: BorderRadius.circular(_hover ? 18 : 14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              child: Opacity(
                opacity: widget.dimmed ? .35 : 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 24, child: Center(child: icon)),
                    const SizedBox(height: 6),
                    Text(
                      utilityLabelForText(context, info.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.fontFamily,
                        fontFamilyFallback: const [
                          'Segoe UI',
                          'Segoe UI Emoji',
                        ],
                        fontSize: 11,
                        color: widget.active ? p.invInk : p.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _enter,
      onHover: _hoverMove,
      onExit: _exit,
      child: DesktopAction(
        behavior: HitTestBehavior.opaque,
        label: utilityLabelForText(context, info.name),
        selected: widget.active,
        excludeSemantics: true,
        onTap: _tap,
        onTapDown: _down,
        child: Listener(
          onPointerDown: _dragStart,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.active
                  ? Colors.transparent
                  : (isApp
                        ? (_hover ? p.soft2 : Colors.transparent)
                        : (_hover ? p.soft2 : p.soft)),
              borderRadius: BorderRadius.circular(_hover ? 18 : 14),
            ),
            child: Opacity(
              opacity: widget.dimmed ? .35 : 1,
              child: Stack(
                children: [
                  Center(child: icon),
                  if (onDot)
                    Positioned(
                      right: 3,
                      top: 3,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // One accent source in the dock: the active palette
                          // (preset-driven), not the raw theme primary.
                          color: LiquidScope.paletteOf(context).inv,
                          border: Border.all(
                            width: 2,
                            color: controllerPalette(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color controllerPalette(BuildContext context) =>
      LiquidScope.paletteOf(context).liquid;

  void _enter(PointerEnterEvent e) {
    setState(() => _hover = true);
    // port of the tab mouseover: switch panel when sweeping across tools
    _openOnHover();
  }

  void _hoverMove(PointerHoverEvent e) => _openOnHover();

  void _openOnHover() {
    final c = widget.controller;
    if (widget.tileStyle ||
        !c.isOpen ||
        c.windowModeChanging ||
        c.dragging ||
        c.modalOpen ||
        c.picking) {
      return;
    }
    final info = ToolInfo.of(widget.id);
    final id = widget.id;
    if (info.kind == ToolKind.panel &&
        (id != c.panel || c.sub) &&
        !(id == 'more' && c.sub)) {
      c.openWidget(id);
      _openedOnEnter = true;
    }
  }

  void _exit(PointerExitEvent e) {
    _openedOnEnter = false;
    setState(() => _hover = false);
  }

  void _down(TapDownDetails _) {
    final pr = widget.controller.springsFor(widget.id).pr;
    pr.v = 1;
    pr.vel = 0;
  }

  void _dragStart(PointerDownEvent e) {
    if (e.buttons == kPrimaryButton && widget.id != 'settings') {
      widget.controller.beginDragCandidate(widget.id, e.position);
    }
  }

  void _tap() {
    if (_openedOnEnter && widget.controller.panel == widget.id) {
      _openedOnEnter = false;
      return;
    }
    if (widget.tileStyle) {
      widget.controller.onTileTap(widget.id);
    } else {
      widget.controller.onToolTap(widget.id);
    }
  }
}

/// The liquid pill behind the active tool. Follows the active tool with a
/// spring, stretching like a drop while travelling.
