import 'package:flutter/material.dart';
import 'package:nex_data/schema/backup_kind.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:nex_ui/nex_ui.dart';
import 'command_palette.dart' show nexFoldText;
import '../core/app_meta.dart';
import '../core/display_identity.dart';
import '../core/panel_settings.dart';
import 'tool_organizer.dart';
import '../ui/widgets.dart';
import '../l10n/app_localizations.dart';
import 'features.dart';
import '../l10n/intelligence_strings.dart';
import 'intelligence/settings.dart';
import '../l10n/desktop_strings.dart';
import '../updates/widgets.dart';

part 'settings_display_appearance.dart';
part 'settings_shortcuts_backup.dart';
part 'settings_tools_about.dart';

class NexSettingsView extends StatefulWidget {
  const NexSettingsView({super.key, this.windowLayout = false});

  /// Wide presentation for the desktop window (no flyout-scroll container,
  /// edge/monitor pickers hidden while the window mode is active).
  final bool windowLayout;

  @override
  State<NexSettingsView> createState() => _NexSettingsViewState();
}

abstract class _SettingsStateBase extends State<NexSettingsView> {
  String? recoveryKey;
  int? category;
  final search = TextEditingController();
  String query = '';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  // Card builders implemented in the part files of this library; declared
  // here so the base build can compose them.
  List<Widget> _buildDisplayAppearance(BuildContext context);
  List<Widget> _buildShortcutsBackup(BuildContext context);
  List<Widget> _buildToolsAbout(BuildContext context);

  void _openCategory(int? value) {
    setState(() => category = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.maybeOf(context)?.position.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final f = NexScope.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final cards = [
      ..._buildDisplayAppearance(context),
      ..._buildShortcutsBackup(context),
      ..._buildToolsAbout(context),
      if (f != null) const DesktopIntelligenceSettings(),
    ];
    final names = [
      l.settingsDisplay,
      l.settingsAppearance,
      l.settingsShortcuts,
      l.settingsBackup,
      l.settingsTools,
      l.settingsAbout,
      if (f != null) AiStrings.of(context).t('ai'),
    ];

    final d = DesktopStrings.of(context);
    final icons = [
      Icons.web_asset_rounded,
      Icons.palette_outlined,
      Icons.keyboard_outlined,
      Icons.cloud_upload_outlined,
      Icons.grid_view_rounded,
      Icons.info_outline_rounded,
      Icons.auto_awesome_rounded,
    ];
    final hints = [
      'displayHint',
      'appearanceHint',
      'shortcutsHint',
      'backupHint',
      'toolsHint',
      'aboutHint',
      'aiHint',
    ];
    Widget group(List<int> indexes, String title) {
      final matching = indexes
          .where(
            (i) =>
                i < names.length &&
                nexFoldText(
                  '${names[i]} ${d.t(hints[i])}',
                ).contains(nexFoldText(query)),
          )
          .toList();
      if (matching.isEmpty) return const SizedBox.shrink();
      return NexSoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                d.t(title),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (var n = 0; n < matching.length; n++) ...[
              if (n != 0) const Divider(height: 1, indent: 56),
              NexSettingsLink(
                key: ValueKey('settings-open-${matching[n]}'),
                icon: icons[matching[n]],
                title: names[matching[n]],
                subtitle: d.t(hints[matching[n]]),
                onTap: () => _openCategory(matching[n]),
              ),
            ],
          ],
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.windowLayout ? 8 : 16,
          vertical: widget.windowLayout ? 0 : 16,
        ),
        child: Column(
          spacing: 18,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (category == null) ...[
              if (widget.windowLayout)
                NexSoftCard(
                  accent: scheme.primary,
                  child: Row(
                    children: [
                      const NexIconBadge(icon: Icons.tune_rounded, size: 54),
                      const SizedBox(width: 18),
                      Expanded(
                        child: NexWorkspaceIntro(
                          title: d.t('settingsIntro'),
                          description: d.t('settingsHint'),
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                key: const ValueKey('settings-search'),
                controller: search,
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: d.t('searchSettings'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              NexResponsiveGrid(
                minWidth: 300,
                children: [
                  group([0, 1, 2, 6], 'personal'),
                  group([3, 4, 5], 'data'),
                ],
              ),
            ] else ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('settings-back'),
                  onPressed: () => _openCategory(null),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(d.t('back')),
                ),
              ),
              cards[category!],
            ],
            if (f?.error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${l.failed}: ${f!.error}',
                  style: TextStyle(color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The composed settings state. Same library, so the mixins and this class
/// share every private member.
class _NexSettingsViewState = _SettingsStateBase
    with
        _SettingsDisplayAppearance,
        _SettingsShortcutsBackup,
        _SettingsToolsAbout;

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NexSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NexIconBadge(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    this.subtitle,
    required this.control,
  });

  final String title;
  final String? subtitle;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          );
          if (constraints.maxWidth < 450) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: control,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 14),
              control,
            ],
          );
        },
      ),
    );
  }
}
