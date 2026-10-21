part of 'window_shell.dart';

class _WindowSection extends StatelessWidget {
  const _WindowSection({
    required this.controller,
    required this.writing,
    required this.toggleWriting,
  });
  final PanelController controller;
  final bool writing;
  final VoidCallback toggleWriting;
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
                writing: writing,
                toggleWriting: toggleWriting,
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // A capture focus/controller must have only one live subtree.
                    KeyedSubtree(
                      key: ValueKey('section-$section-${tool ?? ''}'),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: NexMotion.of(context, NexMotion.standard),
                        curve: NexMotion.curve,
                        child: body,
                        builder: (context, value, child) =>
                            Opacity(opacity: value, child: child),
                      ),
                    ),
                    _WindowToast(controller: controller),
                  ],
                ),
              ),
              if (writing && section == 'capture') const _WritingStatus(),
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
    required this.writing,
    required this.toggleWriting,
  });
  final PanelController controller;
  final String section;
  final String? tool;
  final bool writing;
  final VoidCallback toggleWriting;
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
      child: LayoutBuilder(
        builder: (context, box) {
          final stacked =
              small &&
              box.maxWidth / MediaQuery.textScalerOf(context).scale(1) < 180;
          final heading = Text(
            title,
            key: const ValueKey('window-section-title'),
            style: style,
          );
          final leading = <Widget>[
            if (section == 'tools' && tool != null) ...[
              IconButton(
                key: const ValueKey('window-back-to-tools'),
                tooltip: l.backToTools,
                icon: const BackButtonIcon(),
                onPressed: () {
                  controller.windowTool.value = null;
                  controller.refresh();
                },
              ),
              const SizedBox(width: 8),
            ],
          ];
          final actions = <Widget>[
            if (section == 'capture' || writing)
              IconButton(
                key: const ValueKey('writing-mode'),
                tooltip: DesktopStrings.of(
                  context,
                ).t(writing ? 'leaveWriting' : 'writingMode'),
                onPressed: toggleWriting,
                icon: Icon(
                  writing
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                ),
              ),
            if (NexScope.maybeOf(context)?.recordingAt != null)
              RecordStopButton(controller: controller),
            const SizedBox(width: 8),
            if (small)
              IconButton.filledTonal(
                key: const ValueKey('workspace-command'),
                tooltip:
                    '${l.workspaceSearch} (${ShortcutLabels.commandPalette})',
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
                    const NexShortcutHint(ShortcutLabels.commandPalette),
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
          ];
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ...leading,
                    Expanded(child: heading),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                ),
              ],
            );
          }
          return Row(
            children: [
              ...leading,
              Expanded(child: heading),
              ...actions,
            ],
          );
        },
      ),
    );
  }
}

/// Subscribes only at the small writing receipt, never at the window shell.
class _WritingStatus extends StatelessWidget {
  const _WritingStatus();
  @override
  Widget build(BuildContext context) {
    final f = NexScope.maybeOf(context);
    if (f == null) return const SizedBox.shrink();
    final s = DesktopStrings.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: f.composer,
      builder: (context, value, _) {
        final count = RegExp(r'\S+').allMatches(value.text).length;
        final status = f.error != null
            ? 'writingFailed'
            : f.saving
            ? 'writingSaving'
            : value.text.trim().isEmpty
            ? 'writingReady'
            : 'writingSaved';
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${s.t('wordCount')}: ${desktopDigits(context, count)} · ${s.t(status)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        );
      },
    );
  }
}
