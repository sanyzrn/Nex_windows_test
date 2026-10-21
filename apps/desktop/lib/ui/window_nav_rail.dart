part of 'window_shell.dart';

/// Labelled rail used only at or above kWindowWideAt; _SlimRail handles
/// narrower windows. Width grows for large localized text. Shortcut hints live in
/// tooltips, not beside every label — a badge on each row was noise the
/// Android app does not carry, and the F1 dialog lists them all anyway.
class _WindowNavRail extends StatelessWidget {
  const _WindowNavRail({required this.controller, required this.features});
  final PanelController controller;
  final NexFeatures? features;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    var railWidth = 206.0;
    final scaler = MediaQuery.textScalerOf(context);
    if (scaler.scale(1) > 1) {
      for (final label in [
        l.navCapture,
        l.library,
        AiStrings.of(context).t('ai'),
        l.navTools,
        l.settings,
        l.switchToPanel,
        l.newNote,
      ]) {
        for (final word in label.split(RegExp(r'\s+'))) {
          final painter = TextPainter(
            text: TextSpan(
              text: word,
              style: DefaultTextStyle.of(
                context,
              ).style.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            textScaler: scaler,
            textDirection: Directionality.of(context),
          )..layout();
          // Outer padding + button padding + icon/gap, with a rounding guard.
          final needed = painter.width.ceilToDouble() + 82;
          if (needed > railWidth) railWidth = needed;
          painter.dispose();
        }
      }
    }
    return ValueListenableBuilder<String>(
      valueListenable: controller.windowSection,
      builder: (context, section, _) => Container(
        key: const ValueKey('workspace-sidebar'),
        width: railWidth,
        margin: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            size: 19,
                            color: c.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l.workspaceBrand,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.5,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('workspace-new-note'),
                      onPressed: () {
                        controller.selectWindowSection('capture');
                        unawaited(features?.fresh());
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        minimumSize: const Size(40, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_rounded, size: 19),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l.newNote)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    NexWorkspaceDestination(
                      icon: Icons.edit_note_outlined,
                      label: l.navCapture,
                      selected: section == 'capture',
                      shortcut: ShortcutLabels.newNote,
                      onPressed: () =>
                          controller.selectWindowSection('capture'),
                    ),
                    const SizedBox(height: 4),
                    NexWorkspaceDestination(
                      icon: Icons.auto_stories_outlined,
                      label: l.library,
                      selected: section == 'library',
                      shortcut: ShortcutLabels.library,
                      onPressed: () =>
                          controller.selectWindowSection('library'),
                    ),
                    const SizedBox(height: 4),
                    NexWorkspaceDestination(
                      icon: Icons.auto_awesome_outlined,
                      label: AiStrings.of(context).t('ai'),
                      selected: section == 'assistant',
                      onPressed: () =>
                          controller.selectWindowSection('assistant'),
                    ),
                    const SizedBox(height: 4),
                    NexWorkspaceDestination(
                      icon: Icons.grid_view_outlined,
                      label: l.navTools,
                      selected: section == 'tools',
                      onPressed: () => controller.selectWindowSection('tools'),
                    ),
                  ],
                ),
              ),
            ),
            if (features != null)
              ListenableBuilder(
                listenable: features!,
                builder: (context, _) => features!.recordingAt == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RecordStopButton(controller: controller),
                      ),
              ),
            NexWorkspaceDestination(
              icon: Icons.settings_outlined,
              label: l.settings,
              selected: section == 'settings',
              onPressed: () => controller.selectWindowSection('settings'),
            ),
            const SizedBox(height: 4),
            NexWorkspaceDestination(
              icon: Icons.view_sidebar_outlined,
              label: l.switchToPanel,
              onPressed: () => controller.setWindowMode('panel'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: c.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      l.workspaceLocal,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: c.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: c.outlineVariant, height: 1),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _RailIcon(
                  tooltip: controller.palette.isLight ? l.dark : l.light,
                  icon: controller.palette.isLight
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  onPressed: () {
                    controller.S.theme = controller.palette.isLight
                        ? 'dark'
                        : 'light';
                    controller.save();
                    controller.refresh();
                  },
                ),
                const SizedBox(width: 2),
                _RailIcon(
                  tooltip: '${l.keyboardShortcuts} (${ShortcutLabels.help})',
                  icon: Icons.keyboard_outlined,
                  onPressed: () => showShortcutsDialog(context),
                ),
                const SizedBox(width: 2),
                _RailIcon(
                  tooltip:
                      '${l.workspaceSearch} (${ShortcutLabels.commandPalette})',
                  icon: Icons.search_outlined,
                  onPressed: () => showCommandPalette(
                    context,
                    controller: controller,
                    features: features,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A quiet 34px square icon button for the rail's footer row — the same
/// target Windows puts in its own nav panes, with the keyboard focus ring
/// every other control here keeps.
class _RailIcon extends StatelessWidget {
  const _RailIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: c.onSurfaceVariant,
        minimumSize: const Size(34, 34),
        maximumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 17),
    );
  }
}
