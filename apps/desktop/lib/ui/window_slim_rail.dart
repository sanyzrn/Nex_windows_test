// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the window shell split (see window_shell.dart); do not import
// this file directly.
part of 'window_shell.dart';

/// The compact window's rail: a slim column of icon-over-label tiles with no
/// panel of its own — it sits straight on the tinted window surface, the way
/// a Windows 11 flyout or the Bing Wallpaper app does. The selected tile
/// swaps its icon for the filled one and wears a soft accent pill.
class _SlimRail extends StatelessWidget {
  const _SlimRail({required this.controller, required this.features});
  final PanelController controller;
  final NexFeatures? features;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String>(
      valueListenable: controller.windowSection,
      builder: (context, section, _) {
        Widget tile(
          String id,
          IconData icon,
          IconData selectedIcon,
          String label,
        ) => _RailTile(
          key: ValueKey('rail-$id'),
          icon: icon,
          selectedIcon: selectedIcon,
          label: label,
          selected: section == id,
          onPressed: () => controller.selectWindowSection(id),
        );
        return SizedBox(
          key: const ValueKey('workspace-sidebar'),
          width: _SlimRail.width,
          child: Column(
            children: [
              const SizedBox(height: NexSpacing.sm),
              Tooltip(
                message: l.newNote,
                child: Material(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(NexRadius.md + 4),
                  child: InkWell(
                    key: const ValueKey('workspace-new-note'),
                    borderRadius: BorderRadius.circular(NexRadius.md + 4),
                    onTap: () {
                      controller.selectWindowSection('capture');
                      unawaited(features?.fresh());
                    },
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.add_rounded,
                        size: 26,
                        color: c.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NexSpacing.contentGap),
              tile(
                'capture',
                Icons.edit_note_outlined,
                Icons.edit_note_rounded,
                l.navCapture,
              ),
              tile(
                'library',
                Icons.auto_stories_outlined,
                Icons.auto_stories_rounded,
                l.library,
              ),
              tile(
                'assistant',
                Icons.auto_awesome_outlined,
                Icons.auto_awesome_rounded,
                AiStrings.of(context).t('ai'),
              ),
              tile(
                'tools',
                Icons.grid_view_outlined,
                Icons.grid_view_rounded,
                l.navTools,
              ),
              const Spacer(),
              if (features?.recordingAt != null) ...[
                RecordStopButton(controller: controller),
                const SizedBox(height: NexSpacing.sm),
              ],
              tile(
                'settings',
                Icons.settings_outlined,
                Icons.settings_rounded,
                l.settings,
              ),
              _SlimMoreMenu(controller: controller, features: features),
              const SizedBox(height: NexSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  static const width = 76.0;
}

/// What the wide rail keeps in its footer — the edge panel switch, the theme
/// toggle and the shortcut list — gathered behind one tile.
class _SlimMoreMenu extends StatelessWidget {
  const _SlimMoreMenu({required this.controller, required this.features});
  final PanelController controller;
  final NexFeatures? features;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final light = controller.palette.isLight;
    return PopupMenuButton<String>(
      key: const ValueKey('rail-more'),
      tooltip: l.toolMore,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NexRadius.lg),
      ),
      onSelected: (value) {
        switch (value) {
          case 'panel':
            unawaited(controller.setWindowMode('panel'));
          case 'theme':
            controller.S.theme = light ? 'dark' : 'light';
            controller.save();
            controller.refresh();
          case 'keys':
            showShortcutsDialog(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'panel',
          child: _MenuRow(Icons.view_sidebar_outlined, l.switchToPanel),
        ),
        PopupMenuItem(
          value: 'theme',
          child: _MenuRow(
            light ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            light ? l.dark : l.light,
          ),
        ),
        PopupMenuItem(
          value: 'keys',
          child: _MenuRow(Icons.keyboard_outlined, l.keyboardShortcuts),
        ),
      ],
      child: IgnorePointer(
        child: _RailTile(
          icon: Icons.more_horiz_rounded,
          selectedIcon: Icons.more_horiz_rounded,
          label: l.toolMore,
          selected: false,
          onPressed: () {},
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 19),
      const SizedBox(width: NexSpacing.md - 4),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    ],
  );
}

/// One slim-rail destination: an icon in a pill over a one-line label. The
/// whole 76×62 tile is the target; keyboard focus draws a ring around it.
class _RailTile extends StatefulWidget {
  const _RailTile({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final color = selected ? c.primary : c.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        child: InkWell(
          onTap: widget.onPressed,
          onFocusChange: (value) => setState(() => _focused = value),
          borderRadius: BorderRadius.circular(NexRadius.lg),
          child: Container(
            width: _SlimRail.width - 8,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NexRadius.lg),
              border: Border.all(
                color: _focused ? c.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: NexMotion.fast,
                  curve: NexMotion.curve,
                  width: 52,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected
                        ? c.primary.withValues(alpha: .16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    selected ? widget.selectedIcon : widget.icon,
                    size: 22,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: color,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
