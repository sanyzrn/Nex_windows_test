part of 'window_shell.dart';

class _WindowSection extends StatelessWidget {
  const _WindowSection({required this.controller});
  final PanelController controller;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: controller.windowSection,
      builder: (context, section, _) => ValueListenableBuilder<String?>(
        valueListenable: controller.windowTool,
        builder: (context, tool, _) {
          final body = switch (section) {
            'assistant' => const DesktopAssistant(),
            'library' =>
              NexScope.maybeOf(context) == null
                  ? const Center(child: _MissingStoreNotice())
                  : const NexLibraryView(),
            'tools' =>
              tool == null
                  ? const _ToolsDirectory()
                  : _ToolCard(controller: controller, toolId: tool),
            'settings' => const _SettingsSection(),
            _ => const _CaptureSection(),
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(
                controller: controller,
                section: section,
                tool: tool,
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // A capture focus/controller must have only one live subtree.
                    KeyedSubtree(
                      key: ValueKey('section-$section-${tool ?? ''}'),
                      child: body,
                    ),
                    _WindowToast(controller: controller),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.controller,
    required this.section,
    required this.tool,
  });
  final PanelController controller;
  final String section;
  final String? tool;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final title = switch (section) {
      'assistant' => AiStrings.of(context).t('ai'),
      'library' => l.library,
      'tools' =>
        tool == null
            ? l.navTools
            : utilityLabelForText(context, ToolInfo.of(tool!).name),
      'settings' => l.settings,
      _ => l.capture,
    };
    final small = MediaQuery.sizeOf(context).width < 760;
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
    );
    void search() => showCommandPalette(
      context,
      controller: controller,
      features: NexScope.maybeOf(context),
    );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        small ? 18 : 22,
        small ? 10 : 12,
        small ? 10 : 16,
        6,
      ),
      child: Row(
        children: [
          if (section == 'tools' && tool != null) ...[
            IconButton(
              tooltip: l.backToTools,
              icon: const BackButtonIcon(),
              onPressed: () {
                controller.windowTool.value = null;
                controller.refresh();
              },
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (NexScope.maybeOf(context)?.recordingAt != null)
            RecordStopButton(controller: controller),
          const SizedBox(width: 8),
          if (small)
            IconButton.filledTonal(
              key: const ValueKey('workspace-command'),
              tooltip: '${l.workspaceSearch} (Ctrl+K)',
              onPressed: search,
              icon: const Icon(Icons.search_rounded, size: 20),
            )
          else
            OutlinedButton.icon(
              key: const ValueKey('workspace-command'),
              onPressed: search,
              icon: const Icon(Icons.search_outlined, size: 15),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.workspaceSearch),
                  const SizedBox(width: 10),
                  const NexShortcutHint('Ctrl+K'),
                ],
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: c.surfaceContainerLowest,
                foregroundColor: c.onSurfaceVariant,
                side: BorderSide(color: c.outlineVariant),
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
        ],
      ),
    );
  }
}
