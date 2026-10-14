part of 'window_shell.dart';

class _WindowNavRail extends StatelessWidget {
  const _WindowNavRail({required this.controller, required this.features});
  final PanelController controller;
  final NexFeatures? features;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return ValueListenableBuilder<String>(
      valueListenable: controller.windowSection,
      builder: (context, section, _) => Container(
        key: const ValueKey('workspace-sidebar'),
        width: wide ? 228 : 76,
        padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            c.onSurface.withValues(alpha: .025),
            c.surface,
          ),
          border: BorderDirectional(end: BorderSide(color: c.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: wide
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.onSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.sticky_note_2_outlined,
                            size: 23,
                            color: c.surface,
                          ),
                        ),
                        if (wide) ...[
                          const SizedBox(width: 12),
                          Text(
                            l.workspaceBrand,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (wide)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 14,
                          bottom: 12,
                        ),
                        child: Text(
                          l.workspaceLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: c.onSurfaceVariant),
                        ),
                      ),
                    NexWorkspaceDestination(
                      icon: Icons.edit_note_outlined,
                      label: l.navCapture,
                      selected: section == 'capture',
                      compact: !wide,
                      shortcut: wide ? 'Ctrl+N' : null,
                      onPressed: () =>
                          controller.selectWindowSection('capture'),
                    ),
                    const SizedBox(height: 6),
                    NexWorkspaceDestination(
                      icon: Icons.auto_stories_outlined,
                      label: l.library,
                      selected: section == 'library',
                      compact: !wide,
                      shortcut: wide ? 'Ctrl+L' : null,
                      onPressed: () =>
                          controller.selectWindowSection('library'),
                    ),
                    const SizedBox(height: 6),
                    NexWorkspaceDestination(
                      icon: Icons.grid_view_outlined,
                      label: l.navTools,
                      selected: section == 'tools',
                      compact: !wide,
                      onPressed: () => controller.selectWindowSection('tools'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (features?.recordingAt != null) ...[
              RecordStopButton(controller: controller),
              const SizedBox(height: 12),
            ],
            NexWorkspaceDestination(
              icon: Icons.settings_outlined,
              label: l.settings,
              selected: section == 'settings',
              compact: !wide,
              onPressed: () => controller.selectWindowSection('settings'),
            ),
            const SizedBox(height: 8),
            NexWorkspaceDestination(
              icon: Icons.view_sidebar_outlined,
              label: l.switchToPanel,
              compact: !wide,
              onPressed: () => controller.setWindowMode('panel'),
            ),
            const SizedBox(height: 16),
            Divider(color: c.outlineVariant, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: wide
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Expanded(
                  child: IconButton(
                    tooltip: controller.palette.isLight ? l.dark : l.light,
                    onPressed: () {
                      controller.S.theme = controller.palette.isLight
                          ? 'dark'
                          : 'light';
                      controller.save();
                      controller.refresh();
                    },
                    icon: Icon(
                      controller.palette.isLight
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      size: 20,
                    ),
                  ),
                ),
                if (wide) ...[
                  Expanded(
                    child: IconButton(
                      tooltip: '${l.keyboardShortcuts} (F1)',
                      onPressed: () => showShortcutsDialog(context),
                      icon: const Icon(Icons.keyboard_outlined, size: 20),
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      tooltip: '${l.workspaceSearch} (Ctrl+K)',
                      onPressed: () => showCommandPalette(
                        context,
                        controller: controller,
                        features: features,
                      ),
                      icon: const Icon(Icons.search_outlined, size: 20),
                    ),
                  ),
                ],
              ],
            ),
            if (wide)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 24),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 15,
                      color: c.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.workspaceLocal,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
