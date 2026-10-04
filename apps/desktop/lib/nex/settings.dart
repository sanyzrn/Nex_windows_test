import '../l10n/utility_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:nex_ui/nex_ui.dart';
import '../core/panel_settings.dart';
import '../core/registry.dart';
import '../ui/widgets.dart';
import '../l10n/app_localizations.dart';
import 'features.dart';

class NexSettingsView extends StatefulWidget {
  const NexSettingsView({super.key, this.windowLayout = false});

  /// Wide presentation for the desktop window (no flyout-scroll container,
  /// edge/monitor pickers hidden while the window mode is active).
  final bool windowLayout;

  @override
  State<NexSettingsView> createState() => _NexSettingsViewState();
}

class _NexSettingsViewState extends State<NexSettingsView> {
  String? recoveryKey;

  @override
  Widget build(BuildContext context) {
    final c = LiquidScope.panelOf(context);
    final l = AppLocalizations.of(context)!;
    final f = NexScope.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

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
            if (!widget.windowLayout)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l.settings,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),

            // Card 1: Display & Interface
            _SettingsCard(
              icon: Icons.dashboard_customize_outlined,
              iconColor: scheme.primary,
              title: isFa ? 'نحوه اجرا و نمایش' : 'Display & Interface',
              children: [
                _SettingRow(
                  title: l.interfaceMode,
                  subtitle: l.modeDescription,
                  control: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'window',
                        icon: const Icon(Icons.web_asset_rounded, size: 18),
                        label: Text(l.windowMode),
                      ),
                      ButtonSegment(
                        value: 'panel',
                        icon: const Icon(Icons.view_sidebar_outlined, size: 18),
                        label: Text(l.panelMode),
                      ),
                    ],
                    selected: {c.S.windowMode},
                    onSelectionChanged: (v) => c.setWindowMode(v.first),
                  ),
                ),
                if (!c.isWindowMode || !widget.windowLayout) ...[
                  const Divider(height: 1),
                  _SettingRow(
                    title: l.edge,
                    subtitle: c.isWindowMode ? l.edgePanelOnly : null,
                    control: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'left', label: Text(l.left)),
                        ButtonSegment(value: 'right', label: Text(l.right)),
                      ],
                      selected: {c.S.edge},
                      onSelectionChanged: (v) async {
                        await c.applyPlacement(v.first, c.S.monitor);
                      },
                    ),
                  ),
                  if (c.screens.isNotEmpty && !c.isWindowMode) ...[
                    const Divider(height: 1),
                    _SettingRow(
                      title: l.monitor,
                      control: DropdownButton<int>(
                        value: c.S.monitor.clamp(0, c.screens.length - 1),
                        items: [
                          for (var i = 0; i < c.screens.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text('${l.monitor} ${i + 1}'),
                            ),
                        ],
                        onChanged: (v) async {
                          await c.applyPlacement(c.S.edge, v!);
                        },
                      ),
                    ),
                  ],
                ],
                const Divider(height: 1),
                _SettingRow(
                  title: l.startup,
                  control: Switch(
                    value: c.S.startup,
                    onChanged: (v) async {
                      await c.native.setStartup(v);
                      c.S.startup = await c.native.startupEnabled();
                      c.save();
                      c.refresh();
                    },
                  ),
                ),
              ],
            ),

            // Card 2: Appearance & Theme
            _SettingsCard(
              icon: Icons.palette_outlined,
              iconColor: scheme.tertiary,
              title: isFa
                  ? 'پوسته و ظاهر برنامه'
                  : 'Appearance & Personalization',
              children: [
                _SettingRow(
                  title: isFa ? 'حالت رنگی' : 'Color mode',
                  control: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'light',
                        icon: const Icon(Icons.light_mode_outlined, size: 16),
                        label: Text(l.light),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        icon: const Icon(Icons.dark_mode_outlined, size: 16),
                        label: Text(l.dark),
                      ),
                    ],
                    selected: {c.palette.isLight ? 'light' : 'dark'},
                    onSelectionChanged: (v) {
                      c.S.theme = v.first;
                      c.save();
                      c.refresh();
                    },
                  ),
                ),
                const Divider(height: 1),
                _SettingRow(
                  title: l.accent,
                  control: DropdownButton<String>(
                    value: c.S.preset,
                    underline: const SizedBox.shrink(),
                    items: nexThemePresets
                        .map(
                          (v) => DropdownMenuItem(
                            value: v.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: v.seed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(nexThemePresetLabel(context, v.id)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      c.S.preset = v!;
                      c.save();
                      c.refresh();
                    },
                  ),
                ),
                const Divider(height: 1),
                _SettingRow(
                  title: isFa ? 'زبان برنامه' : 'Application language',
                  control: DropdownButton<String>(
                    value: c.S.language,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 'fa', child: Text(l.persian)),
                      DropdownMenuItem(value: 'en', child: Text(l.english)),
                    ],
                    onChanged: (v) {
                      c.S.language = v!;
                      c.save();
                      c.refresh();
                    },
                  ),
                ),
              ],
            ),

            // Card 3: Shortcuts & Hotkeys
            _SettingsCard(
              icon: Icons.keyboard_command_key_rounded,
              iconColor: scheme.secondary,
              title: isFa ? 'کلیدهای میانبر و تعامل' : 'Shortcuts & Hotkeys',
              children: [
                _SettingRow(
                  title: l.hotkey,
                  subtitle: l.hotkeyInUse,
                  control: DropdownButton<String>(
                    value: c.S.hotkey,
                    underline: const SizedBox.shrink(),
                    items: ['N', 'Q', 'Space']
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: scheme.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Ctrl + Alt + $v',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      if (await c.native.configureHotkey(v!)) {
                        c.S.hotkey = v;
                        c.save();
                        c.refresh();
                      } else {
                        c.toast(l.hotkeyInUse);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                _SettingRow(
                  title: l.pasteOnClick,
                  control: Switch(
                    value: c.S.paste,
                    onChanged: (v) {
                      c.S.paste = v;
                      c.save();
                      c.refresh();
                    },
                  ),
                ),
                const Divider(height: 1),
                _SettingRow(
                  title: l.magnify,
                  control: Switch(
                    value: c.S.magnify,
                    onChanged: (v) {
                      c.S.magnify = v;
                      c.save();
                      c.refresh();
                    },
                  ),
                ),
              ],
            ),

            // Card 4: Backup & Data Safety
            _SettingsCard(
              icon: Icons.security_rounded,
              iconColor: const Color(0xFF10B981),
              title: isFa
                  ? 'پشتیبان‌گیری و امنیت داده‌ها'
                  : 'Data Safety & Backups',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: f == null
                              ? null
                              : () async {
                                  final path = await withPanelHold(
                                    context,
                                    () => getSaveLocation(
                                      suggestedName: 'nex-complete.nexfull',
                                    ),
                                  );
                                  if (path == null) return;
                                  await f.guard(() async {
                                    final recovery = await f.store.call<String>(
                                      'fullBackup',
                                      {
                                        'output': path.path,
                                        'settings': c.S.toMap(),
                                      },
                                    );
                                    if (mounted) {
                                      setState(() => recoveryKey = recovery);
                                    }
                                  });
                                },
                          icon: const Icon(
                            Icons.cloud_download_outlined,
                            size: 18,
                          ),
                          label: Text(l.backup),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: f == null
                              ? null
                              : () async {
                                  final file = await withPanelHold(
                                    context,
                                    () => openFile(
                                      acceptedTypeGroups: [
                                        const XTypeGroup(
                                          label: 'Nex Backup',
                                          extensions: [
                                            'nexbak',
                                            'sqlite',
                                            'nexfull',
                                            'fullbak',
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                  if (file == null || !context.mounted) return;

                                  String? enteredKey;
                                  if (file.path.endsWith('.nexfull') ||
                                      file.path.endsWith('.fullbak')) {
                                    final keyController =
                                        TextEditingController();
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(l.recoveryKey),
                                        content: TextField(
                                          controller: keyController,
                                          decoration: InputDecoration(
                                            hintText: l.recoveryKey,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(l.discard),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(l.restore),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    enteredKey = keyController.text.trim();
                                  }

                                  if (!context.mounted) return;
                                  final proceed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(l.restore),
                                      content: Text(
                                        isFa
                                            ? 'بازیابی نسخه پشتیبان تمام یادداشت‌ها، برچسب‌ها و رسانه‌های فعلی را جایگزین خواهد کرد. آیا مطمئن هستید؟'
                                            : 'Restoring will replace all current notes, tags, and media with this backup. Are you sure you want to proceed?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(l.discard),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(l.restore),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (proceed != true || !context.mounted) {
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await f.guard(() async {
                                    final restoredSettings = await f.store
                                        .call<Map<String, dynamic>?>(
                                          'restoreBackup',
                                          {
                                            'file': file.path,
                                            'key': enteredKey,
                                          },
                                        );
                                    if (restoredSettings != null) {
                                      c.S = Settings.fromMap(restoredSettings);
                                      c.save();
                                      c.refresh();
                                    }
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(l.restored)),
                                      );
                                    }
                                  });
                                },
                          icon: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 18,
                          ),
                          label: Text(l.restore),
                        ),
                      ),
                    ],
                  ),
                ),
                if (recoveryKey != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.key_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l.recoveryKey,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Copy key',
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: recoveryKey!),
                                );
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(l.copy)));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.backupInfo,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          recoveryKey!,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // Card 5: Tools & Dock
            _SettingsCard(
              icon: Icons.apps_rounded,
              iconColor: scheme.primary,
              title: isFa ? 'ابزارهای داک و برنامه‌ها' : 'Docked Tools & Apps',
              children: [
                for (final tool in kTools.values.where(
                  (t) => !t.fixed && t.id != 'more',
                ))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            utilityLabelForText(context, tool.name),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch(
                          value: c.S.dock!.contains(tool.id),
                          onChanged: (v) {
                            c.moveWidget(tool.id, v ? 'dock' : 'more', 0);
                          },
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => c.native.pickApp(),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(l.addApp),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => c.native.pickApp(folder: true),
                        icon: const Icon(
                          Icons.create_new_folder_outlined,
                          size: 16,
                        ),
                        label: Text(l.addFolder),
                      ),
                    ],
                  ),
                ),
                for (final app in c.S.apps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.name,
                            textDirection: nexDirectionOf(app.name),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        IconButton(
                          tooltip: l.remove,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => c.removeApp(app.id),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Card 6: Application info and Quit
            _SettingsCard(
              icon: Icons.info_outline_rounded,
              iconColor: scheme.outline,
              title: isFa ? 'درباره نکس' : 'About Nex',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nex Windows v0.11.0 (Build 7)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: 'Nex',
                        applicationVersion: '0.11.0+7',
                      ),
                      child: Text(l.about),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.errorContainer,
                        foregroundColor: scheme.onErrorContainer,
                      ),
                      onPressed: c.quit,
                      child: Text(l.quit),
                    ),
                  ],
                ),
              ],
            ),

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
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
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
