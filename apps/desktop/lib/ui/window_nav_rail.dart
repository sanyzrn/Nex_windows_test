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
    var railWidth = 192.0;
    final scaler = MediaQuery.textScalerOf(context);
    if (scaler.scale(1) > 1) {
      for (final label in [
        l.navCapture,
        l.library,
        AiStrings.of(context).t('ai'),
        l.navTools,
        l.settings,
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
          final needed = painter.width.ceilToDouble() + 74;
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
        margin: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: c.primary,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              Icons.edit_note_rounded,
                              size: 15,
                              color: c.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.workspaceBrand,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.2,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      key: const ValueKey('workspace-new-note'),
                      onPressed: () {
                        controller.selectWindowSection('capture');
                        unawaited(features?.fresh());
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        minimumSize: const Size(40, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_rounded, size: 17),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l.newNote)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    NexWorkspaceDestination(
                      dense: true,
                      icon: Icons.edit_note_outlined,
                      label: l.navCapture,
                      selected: section == 'capture',
                      shortcut: ShortcutLabels.newNote,
                      onPressed: () =>
                          controller.selectWindowSection('capture'),
                    ),
                    const SizedBox(height: 2),
                    NexWorkspaceDestination(
                      dense: true,
                      icon: Icons.auto_stories_outlined,
                      label: l.library,
                      selected: section == 'library',
                      shortcut: ShortcutLabels.library,
                      onPressed: () =>
                          controller.selectWindowSection('library'),
                    ),
                    const SizedBox(height: 2),
                    NexWorkspaceDestination(
                      dense: true,
                      icon: Icons.auto_awesome_outlined,
                      label: AiStrings.of(context).t('ai'),
                      selected: section == 'assistant',
                      onPressed: () =>
                          controller.selectWindowSection('assistant'),
                    ),
                    const SizedBox(height: 2),
                    NexWorkspaceDestination(
                      dense: true,
                      icon: Icons.grid_view_outlined,
                      label: l.navTools,
                      selected: section == 'tools',
                      onPressed: () => controller.selectWindowSection('tools'),
                    ),
                    if (features != null)
                      NexRailTags(
                        features: features!,
                        controller: controller,
                        section: section,
                      ),
                    if (features != null)
                      NexRailTypes(
                        features: features!,
                        controller: controller,
                        section: section,
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
              dense: true,
              icon: Icons.settings_outlined,
              iconWidget: NexUpdateDot(
                updates: features?.updates,
                child: const Icon(Icons.settings_outlined, size: 18),
              ),
              label: l.settings,
              selected: section == 'settings',
              onPressed: () => controller.selectWindowSection('settings'),
            ),
            const SizedBox(height: 6),
            // The panel switch, the theme, the shortcuts and the search are
            // one row of small icons: what used to be a labelled row and a
            // privacy paragraph under the destinations was noise on every
            // screen. The privacy line stays, as the shield's tooltip.
            Row(
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
                _RailIcon(
                  tooltip: '${l.keyboardShortcuts} (${ShortcutLabels.help})',
                  icon: Icons.keyboard_outlined,
                  onPressed: () => showShortcutsDialog(context),
                ),
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
                _RailIcon(
                  key: const ValueKey('workspace-switch-panel'),
                  tooltip: l.switchToPanel,
                  icon: Icons.view_sidebar_outlined,
                  onPressed: () => controller.setWindowMode('panel'),
                ),
                const Spacer(),
                Tooltip(
                  message: l.workspaceLocal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 15,
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// A quiet 32px square icon button for the rail's footer row — the same
/// target Windows puts in its own nav panes, with the keyboard focus ring
/// every other control here keeps.
class _RailIcon extends StatelessWidget {
  const _RailIcon({
    super.key,
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
        minimumSize: const Size(32, 32),
        maximumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 17),
    );
  }
}
