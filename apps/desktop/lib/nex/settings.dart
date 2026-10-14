import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:nex_ui/nex_ui.dart';
import '../core/app_meta.dart';
import '../core/display_identity.dart';
import '../core/panel_settings.dart';
import 'tool_organizer.dart';
import '../ui/widgets.dart';
import '../l10n/app_localizations.dart';
import 'features.dart';

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
  int category = 0;

  // Card builders implemented in the part files of this library; declared
  // here so the base build can compose them.
  List<Widget> _buildDisplayAppearance(BuildContext context);
  List<Widget> _buildShortcutsBackup(BuildContext context);
  List<Widget> _buildToolsAbout(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final f = NexScope.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final cards = [
      ..._buildDisplayAppearance(context),
      ..._buildShortcutsBackup(context),
      ..._buildToolsAbout(context),
    ];
    final names = [
      l.settingsDisplay,
      l.settingsAppearance,
      l.settingsShortcuts,
      l.settingsBackup,
      l.settingsTools,
      l.settingsAbout,
    ];

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.windowLayout ? 8 : 16,
          vertical: widget.windowLayout ? 16 : 16,
        ),
        child: Column(
          spacing: 16,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No page title here: the flyout's panel header already names the
            // view (audit defect 5 - "Settings" used to appear twice).
            if (widget.windowLayout) ...[
              NexWorkspaceIntro(
                title: l.workspaceSettingsDescription,
                description: l.modeDescription,
                compact: true,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < names.length; i++)
                    ChoiceChip(
                      label: Text(names[i]),
                      selected: category == i,
                      onSelected: (_) => setState(() => category = i),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              cards[category],
            ] else ...[
              DropdownButtonFormField<int>(
                key: const ValueKey('settings-category'),
                initialValue: category,
                isExpanded: true,
                items: [
                  for (var i = 0; i < names.length; i++)
                    DropdownMenuItem(value: i, child: Text(names[i])),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => category = v);
                },
              ),
              cards[category],
            ],

            if (f?.error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
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
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 900 ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
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
                const SizedBox(height: 12),
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
              const SizedBox(width: 16),
              control,
            ],
          );
        },
      ),
    );
  }
}
