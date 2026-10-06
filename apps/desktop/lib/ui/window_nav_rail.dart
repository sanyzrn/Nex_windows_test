// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the window shell split (see window_shell.dart); do not import
// this file directly.
part of 'window_shell.dart';

class _WindowNavRail extends StatelessWidget {
  const _WindowNavRail({required this.controller, required this.features});

  final PanelController controller;
  final NexFeatures? features;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 780;
    final recording = features?.recordingAt != null;

    return ValueListenableBuilder<String>(
      valueListenable: controller.windowSection,
      builder: (context, section, _) => Container(
        width: wide ? 88 : 64,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: BorderDirectional(
            end: BorderSide(color: scheme.onSurface.withValues(alpha: .08)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const _Logo(),
            const SizedBox(height: 18),
            _NavItem(
              controller: controller,
              id: 'capture',
              icon: Icons.edit_note_rounded,
              label: l.navCapture,
              selected: section == 'capture',
              wide: wide,
              shortcut: 'Ctrl+N',
            ),
            _NavItem(
              controller: controller,
              id: 'library',
              icon: Icons.notes_rounded,
              label: l.library,
              selected: section == 'library',
              wide: wide,
              shortcut: 'Ctrl+L',
            ),
            _NavItem(
              controller: controller,
              id: 'tools',
              icon: Icons.apps_rounded,
              label: l.navTools,
              selected: section == 'tools',
              wide: wide,
            ),
            _NavItem(
              controller: controller,
              id: 'settings',
              icon: Icons.settings_outlined,
              label: l.settings,
              selected: section == 'settings',
              wide: wide,
              shortcut: 'Ctrl+,',
            ),
            const Spacer(),
            if (recording) ...[
              _RecordingBadge(features: features),
              const SizedBox(height: 10),
            ],
            _ThemeToggleButton(controller: controller),
            const _ShortcutsHelpButton(),
            _ModeSwitchButton(controller: controller),
            const SizedBox(height: 8),
            Tooltip(
              message: l.localEngineActive,
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              Color.alphaBlend(
                scheme.tertiary.withValues(alpha: 0.3),
                scheme.primary,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: .30),
              offset: const Offset(0, 4),
              blurRadius: 14,
            ),
          ],
        ),
        child: Icon(
          Icons.water_drop_rounded,
          color: scheme.onPrimary,
          size: 22,
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.controller,
    required this.id,
    required this.icon,
    required this.label,
    required this.selected,
    required this.wide,
    this.shortcut,
  });

  final PanelController controller;
  final String id;
  final IconData icon;
  final String label;
  final bool selected;
  final bool wide;
  final String? shortcut;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final tooltipText = widget.shortcut != null
        ? '${widget.label} (${widget.shortcut})'
        : widget.label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: tooltipText,
        waitDuration: const Duration(milliseconds: 500),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.controller.selectWindowSection(widget.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 56,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary
                    : (_hover ? scheme.surfaceContainerHigh : null),
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.25),
                          offset: const Offset(0, 3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: widget.wide
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.icon,
                          size: 22,
                          color: selected
                              ? scheme.onPrimary
                              : (_hover
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? scheme.onPrimary
                                : (_hover
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Icon(
                        widget.icon,
                        size: 24,
                        color: selected
                            ? scheme.onPrimary
                            : (_hover
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingBadge extends StatefulWidget {
  const _RecordingBadge({required this.features});

  final NexFeatures? features;

  @override
  State<_RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<_RecordingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Tooltip(
      message: l.recording,
      child: FadeTransition(
        opacity: Tween(
          begin: .35,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.error,
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatefulWidget {
  const _ThemeToggleButton({required this.controller});
  final PanelController controller;

  @override
  State<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<_ThemeToggleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = widget.controller.palette.isLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: isLight ? 'Dark theme' : 'Light theme',
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.controller.S.theme = isLight ? 'dark' : 'light';
              widget.controller.save();
              widget.controller.refresh();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 38,
              decoration: BoxDecoration(
                color: _hover
                    ? scheme.surfaceContainerHigh
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  isLight
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  size: 20,
                  color: _hover ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutsHelpButton extends StatefulWidget {
  const _ShortcutsHelpButton();

  @override
  State<_ShortcutsHelpButton> createState() => _ShortcutsHelpButtonState();
}

class _ShortcutsHelpButtonState extends State<_ShortcutsHelpButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: '${l.keyboardShortcuts} (F1)',
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showShortcutsDialog(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 38,
              decoration: BoxDecoration(
                color: _hover
                    ? scheme.surfaceContainerHigh
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.keyboard_outlined,
                  size: 20,
                  color: _hover ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSwitchButton extends StatefulWidget {
  const _ModeSwitchButton({required this.controller});

  final PanelController controller;

  @override
  State<_ModeSwitchButton> createState() => _ModeSwitchButtonState();
}

class _ModeSwitchButtonState extends State<_ModeSwitchButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: l.switchToPanel,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.controller.setWindowMode('panel'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 38,
              decoration: BoxDecoration(
                color: _hover
                    ? scheme.surfaceContainerHigh
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  Icons.view_sidebar_outlined,
                  size: 20,
                  color: _hover ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The content surface: header with the section title and contextual
/// actions, then the section body with a soft animated transition.
