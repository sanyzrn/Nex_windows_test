import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/utility_strings.dart';
import '../core/controller.dart';
import '../core/registry.dart';
import '../nex/features.dart';
import '../nex/settings.dart';
import '../nex/shortcuts_dialog.dart';
import 'dock.dart' show AppIconImage;
import 'flyout.dart' show buildPanelView;
import 'svg_icon.dart';
import 'widgets.dart';

/// The full desktop window shell — the app's main mode. A navigation rail on
/// the leading edge switches between Capture, Library, Tools and Settings;
/// the edge slide-out panel remains available as an optional mode and both
/// surfaces drive the same [PanelController], [NexFeatures] and store.
///
/// The window itself is a normal resizable, minimize/maximize-able Win32
/// window (the bridge restyles the host when this shell is active), so this
/// widget paints an opaque background and stays put when focus is lost.
class NexWindowShell extends StatefulWidget {
  const NexWindowShell({super.key, required this.controller, this.features});

  final PanelController controller;
  final NexFeatures? features;

  @override
  State<NexWindowShell> createState() => _NexWindowShellState();
}

class _NexWindowShellState extends State<NexWindowShell> {
  @override
  void initState() {
    super.initState();
    // Stale geometry hooks from the panel shell must never be called while
    // the window shell owns the surface.
    final c = widget.controller;
    c.dockAnchorOf = null;
    c.moreAnchorOf = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    Widget buildSurface(BuildContext context, Widget? child) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WindowNavRail(controller: c, features: widget.features),
        Expanded(child: _WindowSection(controller: c)),
      ],
    );
    return Scaffold(
      // transparentScaffold is for the floating edge panel; the desktop
      // window must paint an opaque surface.
      backgroundColor: scheme.surface,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: LiquidScope(
          controller: c,
          palette: c.palette,
          dir: 1,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                final isCtrl = HardwareKeyboard.instance.isControlPressed;
                final isShift = HardwareKeyboard.instance.isShiftPressed;

                if (event.logicalKey == LogicalKeyboardKey.f1 ||
                    (isCtrl && event.logicalKey == LogicalKeyboardKey.slash)) {
                  showShortcutsDialog(context);
                  return KeyEventResult.handled;
                }

                if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyL) {
                  c.selectWindowSection('library');
                  return KeyEventResult.handled;
                }

                if (isCtrl && event.logicalKey == LogicalKeyboardKey.comma) {
                  c.selectWindowSection('settings');
                  return KeyEventResult.handled;
                }

                if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyN) {
                  c.selectWindowSection('capture');
                  if (widget.features != null) {
                    widget.features!.checklist = isShift;
                  }
                  return KeyEventResult.handled;
                }

                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  final tool = c.windowTool.value;
                  if (tool != null) {
                    c.windowTool.value = null;
                    c.refresh();
                    return KeyEventResult.handled;
                  }
                }
              }
              return KeyEventResult.ignored;
            },
            // Recording/import/error states live in NexFeatures; the shell
            // must repaint when they change (badge, stop button, progress).
            child: widget.features == null
                ? Builder(
                    builder: (context) => buildSurface(context, null),
                  )
                : ListenableBuilder(
                    listenable: widget.features!,
                    builder: buildSurface,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Navigation rail: logo, the four sections, then status and the mode
/// switcher pinned to the bottom.
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
              message: Localizations.localeOf(context).languageCode == 'fa'
                  ? 'دیتابیس محلی نکس: فعال و ایمن'
                  : 'Nex Local Engine: Active & secure',
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x6610B981),
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
        child: Icon(Icons.water_drop_rounded, color: scheme.onPrimary, size: 22),
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
                              : (_hover ? scheme.onSurface : scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected
                                ? scheme.onPrimary
                                : (_hover ? scheme.onSurface : scheme.onSurfaceVariant),
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
                            : (_hover ? scheme.onSurface : scheme.onSurfaceVariant),
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
                  isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
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
              'library' => NexScope.maybeOf(context) == null
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
      'library' => isFa ? 'کتابخانه یادداشت‌ها و جستجوی لحظه‌ای' : 'Local library & instant search',
      'tools' => isFa ? 'ابزارهای سریع و افزونه‌های متصل' : 'Quick utilities & connected tools',
      'settings' => isFa ? 'تنظیمات، پوسته و امنیت داده‌ها' : 'Preferences, theme & data safety',
      _ => isFa ? 'ثبت سریع افکار و چک‌لیست‌ها' : 'Fast capture & persistent scratchpad',
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
class _CaptureSection extends StatelessWidget {
  const _CaptureSection();

  @override
  Widget build(BuildContext context) {
    if (NexScope.maybeOf(context) == null) {
      // Tests boot the shell without a store; keep the surface renderable.
      return const Center(child: CircularProgressIndicator());
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: NexCaptureView(compact: false)),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      children: const [NexSettingsView(windowLayout: true)],
    );
  }
}

/// Placeholder for shells booted without a store (tests).
class _MissingStoreNotice extends StatelessWidget {
  const _MissingStoreNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text('No store', style: TextStyle(color: scheme.onSurfaceVariant)),
    );
  }
}

/// Centers the child and caps its width for readable line lengths.
class _CenteredColumn extends StatelessWidget {
  const _CenteredColumn({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// The tools directory: every dockable utility and pinned app as a large
/// tile. Panel tools open inside the window; actions run directly.
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
class RecordStopButton extends StatelessWidget {
  const RecordStopButton({super.key, required this.controller});

  final PanelController controller;

  @override
  Widget build(BuildContext context) {
    final f = NexScope.maybeOf(context);
    if (f == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: IconButton(
        tooltip: l.stop,
        onPressed: f.recordingBusy ? null : () => f.record(controller),
        icon: Icon(
          Icons.stop_circle_outlined,
          size: 20,
          color: scheme.onErrorContainer,
        ),
      ),
    );
  }
}
