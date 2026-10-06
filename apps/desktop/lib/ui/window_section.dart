// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the window shell split (see window_shell.dart); do not import
// this file directly.
part of 'window_shell.dart';

class _WindowSection extends StatelessWidget {
  const _WindowSection({required this.controller});

  final PanelController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ValueListenableBuilder<String>(
      valueListenable: c.windowSection,
      builder: (context, section, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: c.windowTool,
          builder: (context, tool, _) {
            final body = switch (section) {
              'library' =>
                NexScope.maybeOf(context) == null
                    ? const _CenteredColumn(
                        maxWidth: 720,
                        child: _MissingStoreNotice(),
                      )
                    : const NexLibraryView(),
              'tools' =>
                tool == null
                    ? const _ToolsDirectory()
                    : _ToolCard(controller: c, toolId: tool),
              'settings' => const _CenteredColumn(
                maxWidth: 720,
                child: _SettingsSection(),
              ),
              _ => const _CaptureSection(),
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(controller: c, section: section, tool: tool),
                Expanded(
                  child: Stack(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, .015),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey('section-$section-${tool ?? ''}'),
                          child: body,
                        ),
                      ),
                      _WindowToast(controller: c),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
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
    final scheme = Theme.of(context).colorScheme;
    final f = NexScope.maybeOf(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final title = switch (section) {
      'library' => l.library,
      'tools' =>
        tool != null
            ? utilityLabelForText(context, ToolInfo.of(tool!).name)
            : l.navTools,
      'settings' => l.settings,
      _ => l.capture,
    };
    final subtitle = switch (section) {
      'library' =>
        isFa
            ? 'کتابخانه یادداشت‌ها و جستجوی لحظه‌ای'
            : 'Local library & instant search',
      'tools' =>
        isFa
            ? 'ابزارهای سریع و افزونه‌های متصل'
            : 'Quick utilities & connected tools',
      'settings' =>
        isFa
            ? 'تنظیمات، پوسته و امنیت داده‌ها'
            : 'Preferences, theme & data safety',
      _ =>
        isFa
            ? 'ثبت سریع افکار و چک‌لیست‌ها'
            : 'Fast capture & persistent scratchpad',
    };
    final recording = f?.recordingAt != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.onSurface.withValues(alpha: .07)),
        ),
      ),
      child: Row(
        children: [
          if (section == 'tools' && tool != null) ...[
            _HeaderIcon(
              icon: Icons.arrow_back_rounded,
              tooltip: l.backToTools,
              onTap: () {
                controller.windowTool.value = null;
                controller.refresh();
              },
            ),
            const SizedBox(width: 12),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (recording) ...[
            RecordStopButton(controller: controller),
            const SizedBox(width: 8),
          ],
          if (section == 'capture')
            _HeaderIcon(
              icon: Icons.add_rounded,
              tooltip: '${l.newNote} (Ctrl+N)',
              onTap: () => f?.fresh(),
            ),
          if (section == 'library')
            _HeaderIcon(
              icon: Icons.add_rounded,
              tooltip: '${l.newNote} (Ctrl+N)',
              onTap: () {
                controller.selectWindowSection('capture');
                f?.fresh();
              },
            ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
        style: IconButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(40, 40),
        ),
      ),
    );
  }
}

/// Capsule holding the capture editor. Gives the text field a bounded,
/// generous area and keeps every action from the flyout capture view.
