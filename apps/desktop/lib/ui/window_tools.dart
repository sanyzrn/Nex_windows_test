// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the window shell split (see window_shell.dart); do not import
// this file directly.
part of 'window_shell.dart';

class _ToolsDirectory extends StatelessWidget {
  const _ToolsDirectory();

  @override
  Widget build(BuildContext context) {
    final c = NexPanelScope.maybeOf(context) ?? LiquidScope.panelOf(context);
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    const reserved = {'more', 'settings', 'note', 'timeline'};
    final ids = [
      ...?c.S.dock,
      ...?c.S.more,
    ].where((id) => !reserved.contains(id)).toSet().toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Text(
          l.toolsHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final id in ids) _ToolTile(controller: c, id: id)],
        ),
      ],
    );
  }
}

class _ToolTile extends StatefulWidget {
  const _ToolTile({required this.controller, required this.id});

  final PanelController controller;
  final String id;

  @override
  State<_ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<_ToolTile> {
  bool _hover = false;

  void _open() {
    final info = ToolInfo.of(widget.id);
    if (info.kind == ToolKind.action) {
      widget.controller.runAction(info.action!);
      return;
    }
    if (info.kind == ToolKind.app) {
      widget.controller.onToolTap(widget.id);
      return;
    }
    widget.controller.openWindowTool(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = ToolInfo.of(widget.id);
    final onDot = widget.id == 'awake' && widget.controller.awake;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: kPop,
          width: 132,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _hover
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: _hover ? .1 : .05),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: .10),
                      offset: const Offset(0, 8),
                      blurRadius: 18,
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 30,
                child: Center(
                  child: _ToolIcon(
                    controller: widget.controller,
                    id: widget.id,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                utilityLabelForText(context, info.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onDot)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon resolution shared with the dock: core icons, emoji, app icons, SVGs.
class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.controller, required this.id});

  final PanelController controller;
  final String id;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = ToolInfo.of(id);
    final coreIcon = switch (id) {
      'more' => Icons.grid_view_rounded,
      'settings' => Icons.settings_outlined,
      _ => null,
    };
    if (coreIcon != null) {
      return Icon(coreIcon, size: 23, color: scheme.onSurfaceVariant);
    }
    if (info.emoji != null) {
      return Text(
        info.emoji!,
        style: const TextStyle(
          fontFamily: 'Segoe UI Emoji',
          fontFamilyFallback: ['Segoe UI Emoji'],
          fontSize: 21,
        ),
      );
    }
    if (info.kind == ToolKind.app && info.app?.icon != null) {
      return AppIconImage(dataUri: info.app!.icon!);
    }
    if (info.svg != null) {
      return SvgIcon(info.svg!, size: 20, color: scheme.onSurfaceVariant);
    }
    return const SizedBox.shrink();
  }
}

/// A utility tool opened from the directory: rendered inside a soft card
/// with a constrained width so the flyout-designed panels keep their shape.
class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.controller, required this.toolId});

  final PanelController controller;
  final String toolId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.onSurface.withValues(alpha: .07)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: .08),
                offset: const Offset(0, 10),
                blurRadius: 26,
                spreadRadius: -8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              child: buildPanelView(context, controller, toolId),
            ),
          ),
        ),
      ),
    );
  }
}

/// Toasts in the window surface, top-center, mirroring the panel's toast.
class _WindowToast extends StatelessWidget {
  const _WindowToast({required this.controller});

  final PanelController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String?>(
      valueListenable: controller.toastMsg,
      builder: (context, msg, _) {
        final text = msg?.split('\x00').first;
        final visible = text != null;
        return Positioned(
          top: 12,
          left: 24,
          right: 24,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: visible ? 1 : 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 320),
                curve: kPop,
                offset: visible ? Offset.zero : const Offset(0, -.4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.inverseSurface,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: .3),
                          offset: const Offset(0, 10),
                          blurRadius: 24,
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                    child: Text(
                      text ?? '',
                      style: TextStyle(
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.fontFamily,
                        fontFamilyFallback: const ['Segoe UI'],
                        fontSize: 12.5,
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Header-visible stop-recording control shared by every window section.
