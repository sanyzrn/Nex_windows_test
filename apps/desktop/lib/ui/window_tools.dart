part of 'window_shell.dart';

class _ToolsDirectory extends StatefulWidget {
  const _ToolsDirectory();
  @override
  State<_ToolsDirectory> createState() => _ToolsDirectoryState();
}

class _ToolsDirectoryState extends State<_ToolsDirectory> {
  final search = TextEditingController();
  String query = '';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = NexPanelScope.maybeOf(context) ?? LiquidScope.panelOf(context);
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    const reserved = {'more', 'settings', 'note', 'timeline'};
    final ids = [...?c.S.dock, ...?c.S.more]
        .where((id) => !reserved.contains(id) && !c.S.hidden.contains(id))
        .toSet()
        .toList();
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
    final groups = <(String, Set<String>)>[
      (
        l.workspaceToolsWork,
        {'text', 'snippets', 'gen', 'pass', 'emoji', 'color'},
      ),
      (l.workspaceToolsTime, {'timer', 'stopwatch', 'clock', 'awake'}),
      (l.workspaceToolsSystem, {}),
    ];
    final grouped = <String>{};
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.all(constraints.maxWidth < 650 ? 16 : 24),
        children: [
          NexWorkspaceIntro(
            title: l.workspaceToolsTitle,
            description: l.workspaceToolsDescription,
            compact: constraints.maxWidth < 650,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 320,
              child: TextField(
                key: const ValueKey('workspace-tools-search'),
                controller: search,
                decoration: InputDecoration(
                  hintText: l.workspaceToolsSearch,
                  prefixIcon: const Icon(Icons.search_outlined, size: 17),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.clearSelection,
                          icon: const Icon(Icons.close_rounded, size: 17),
                          onPressed: () {
                            search.clear();
                            setState(() => query = '');
                          },
                        ),
                  fillColor: scheme.surfaceContainerLowest,
                  // The Android app's search field is a capsule.
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(
                      color: scheme.primary,
                      width: nexFocusRingWidth,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(l.empty)),
          if (essentials.isNotEmpty) ...[
            _sectionLabel(l.workspaceEssentials),
            const SizedBox(height: 10),
            _grid(essentials, c),
            const SizedBox(height: 20),
          ],
          for (final group in groups)
            if (others.any(
              (id) => group.$2.isEmpty
                  ? !grouped.contains(id)
                  : group.$2.contains(id),
            )) ...[
              _sectionLabel(group.$1),
              const SizedBox(height: 10),
              _grid(
                others.where((id) {
                  final included = group.$2.isEmpty
                      ? !grouped.contains(id)
                      : group.$2.contains(id);
                  if (included) grouped.add(id);
                  return included;
                }).toList(),
                c,
              ),
              const SizedBox(height: 20),
            ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  Widget _grid(List<String> ids, PanelController controller) => LayoutBuilder(
    builder: (context, constraints) {
      final scaledWidth =
          constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1);
      final columns = scaledWidth >= 860
          ? 3
          : scaledWidth >= 520
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
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
    // Every tile carries the Android grid's coloured icon chip: a per-tool
    // hue at a low tint behind a same-hue icon, so the directory scans by
    // category the way the phone's quick-access grid does.
    final accent = NexColors.toolAccent(id, c.onSurfaceVariant);
    return TextButton(
      onPressed: id == 'awake' && controller.awakeBusy ? null : _open,
      style:
          TextButton.styleFrom(
            foregroundColor: c.onSurface,
            backgroundColor: active
                ? c.primary.withValues(alpha: .09)
                : c.surfaceContainerLowest,
            padding: const EdgeInsets.all(18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: _ToolIcon(controller: controller, id: id, color: accent),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  utilityLabelForText(context, ToolInfo.of(id).name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (id == 'awake' && controller.awakeBusy)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              active ? Icons.check_circle_outline : Icons.chevron_right_rounded,
              size: 16,
              color: active ? c.primary : c.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

/// Icon resolution shared with the dock: core icons, emoji, app icons, SVGs.
///
/// [color] tints the directory tile's icon with its per-tool hue; the dock
/// passes the theme's own icon colour.
class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.controller, required this.id, this.color});

  final PanelController controller;
  final String id;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = ToolInfo.of(id);
    final tint = color ?? scheme.onSurfaceVariant;
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
      return Icon(coreIcon, size: 19, color: tint);
    }
    if (info.emoji != null) {
      return Text(
        info.emoji!,
        style: const TextStyle(
          fontFamily: 'Segoe UI Emoji',
          fontFamilyFallback: ['Segoe UI Emoji'],
          fontSize: 18,
        ),
      );
    }
    if (info.kind == ToolKind.app && info.app?.icon != null) {
      return AppIconImage(dataUri: info.app!.icon!);
    }
    if (info.svg != null) {
      return SvgIcon(info.svg!, size: 18, color: tint);
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
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
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
