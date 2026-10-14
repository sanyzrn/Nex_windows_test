part of 'window_shell.dart';

class _ToolsDirectory extends StatefulWidget {
  const _ToolsDirectory();
  @override
  State<_ToolsDirectory> createState() => _ToolsDirectoryState();
}

class _ToolsDirectoryState extends State<_ToolsDirectory> {
  String query = '';
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
    final filtered = ids
        .where(
          (id) => nexFoldText(
            utilityLabelForText(context, ToolInfo.of(id).name),
          ).contains(nexFoldText(query)),
        )
        .toList();
    const essentialIds = ['clip', 'awake', 'calc', 'timer', 'color'];
    final essentials = essentialIds.where(filtered.contains).toList();
    final others = filtered.where((id) => !essentialIds.contains(id)).toList();
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.all(constraints.maxWidth < 650 ? 24 : 40),
        children: [
          NexWorkspaceIntro(
            title: l.workspaceToolsTitle,
            description: l.workspaceToolsDescription,
            compact: constraints.maxWidth < 650,
          ),
          const SizedBox(height: 28),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 420,
              child: TextField(
                key: const ValueKey('workspace-tools-search'),
                decoration: InputDecoration(
                  hintText: l.workspaceToolsSearch,
                  prefixIcon: const Icon(Icons.search_outlined, size: 20),
                  fillColor: scheme.surfaceContainerLowest,
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (filtered.isEmpty)
            Padding(padding: const EdgeInsets.all(32), child: Text(l.empty)),
          if (essentials.isNotEmpty) ...[
            Text(
              l.workspaceEssentials,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _grid(essentials, c),
            const SizedBox(height: 32),
          ],
          if (others.isNotEmpty) ...[
            Text(
              l.workspaceAllTools,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _grid(others, c),
          ],
        ],
      ),
    );
  }

  Widget _grid(List<String> ids, PanelController controller) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 520
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final id in ids)
            SizedBox(
              width: width,
              child: _ToolTile(controller: controller, id: id),
            ),
        ],
      );
    },
  );
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.controller, required this.id});
  final PanelController controller;
  final String id;

  void _open() {
    final info = ToolInfo.of(id);
    if (info.kind == ToolKind.action) {
      controller.runAction(info.action!);
    } else if (info.kind == ToolKind.app) {
      controller.onToolTap(id);
    } else {
      controller.openWindowTool(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final active = id == 'awake' && controller.awake;
    final description = switch (id) {
      'clip' => l.workspaceClipboardHint,
      'awake' => l.workspaceAwakeHint,
      'timer' => l.workspaceTimerHint,
      'calc' => l.workspaceCalculatorHint,
      'color' => l.workspaceColorHint,
      _ => l.workspaceUtilityHint,
    };
    return TextButton(
      onPressed: id == 'awake' && controller.awakeBusy ? null : _open,
      style:
          TextButton.styleFrom(
            foregroundColor: c.onSurface,
            backgroundColor: active
                ? c.primary.withValues(alpha: .09)
                : c.surfaceContainerLowest,
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: AlignmentDirectional.centerStart,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused) || active
                    ? c.primary
                    : c.outlineVariant,
                width: states.contains(WidgetState.focused) ? 2 : 1,
              ),
            ),
          ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _ToolIcon(controller: controller, id: id),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  utilityLabelForText(context, ToolInfo.of(id).name),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (id == 'awake' && controller.awakeBusy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              active ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
              size: 16,
              color: active ? c.primary : c.onSurfaceVariant,
            ),
        ],
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
      'clip' => Icons.content_paste_outlined,
      'awake' => Icons.wb_sunny_outlined,
      'calc' => Icons.calculate_outlined,
      'timer' => Icons.timer_outlined,
      'stopwatch' => Icons.av_timer_outlined,
      'color' => Icons.palette_outlined,
      'clock' => Icons.public_outlined,
      'pass' => Icons.key_outlined,
      'unit' => Icons.straighten_outlined,
      'emoji' => Icons.sentiment_satisfied_outlined,
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
