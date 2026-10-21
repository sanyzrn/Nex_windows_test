// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the settings view split (see settings.dart); do not import this
// file directly.
part of 'settings.dart';

mixin _SettingsShortcutsBackup on _SettingsStateBase {
  @override
  List<Widget> _buildShortcutsBackup(BuildContext context) {
    final c = LiquidScope.panelOf(context);
    final l = AppLocalizations.of(context)!;
    final f = NexScope.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;

    return [
      // Card 3: Shortcuts & Hotkeys
      _SettingsCard(
        icon: Icons.keyboard_command_key_rounded,
        iconColor: scheme.secondary,
        title: l.settingsShortcuts,
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
        iconColor: scheme.primary,
        title: l.settingsBackup,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l.backupCompatibility,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
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
                              await f.session.flushed;
                              final recovery = await f.store
                                  .call<String>('fullBackup', {
                                    'output': path.path,
                                    'settings': c.S.backupSettings(),
                                  });
                              if (mounted) {
                                setState(() => recoveryKey = recovery);
                              }
                            });
                          },
                    icon: const Icon(Icons.cloud_download_outlined, size: 18),
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
                                  XTypeGroup(
                                    label: l.backupFileType,
                                    extensions: const [
                                      'nexbak',
                                      'sqlite',
                                      'nexfull',
                                      'fullbak',
                                      'zip',
                                      'bin',
                                    ],
                                  ),
                                ],
                              ),
                            );
                            if (file == null || !context.mounted) return;

                            String? enteredKey;
                            NexBackupKind? kind;
                            await f.guard(() async {
                              kind = await f.store.call<NexBackupKind>(
                                'backupKind',
                                {'file': file.path},
                              );
                            });
                            if (kind == null) return;
                            if (!context.mounted) return;
                            if (kind == NexBackupKind.full) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(l.recoveryKey),
                                  content: TextField(
                                    textDirection: TextDirection.ltr,
                                    autocorrect: false,
                                    onChanged: (v) => enteredKey = v.trim(),
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
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(l.restore),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                            }

                            if (!context.mounted) return;
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(l.restore),
                                content: Text(
                                  kind == NexBackupKind.export
                                      ? l.importBackupConfirm
                                      : l.restoreConfirmBody,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(l.discard),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(
                                      kind == NexBackupKind.export
                                          ? l.importNotes
                                          : l.restore,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (proceed != true || !context.mounted) {
                              return;
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            await f.guard(() async {
                              final restoredSettings = await f.restoreBackup(
                                file.path,
                                enteredKey,
                              );
                              if (restoredSettings != null) {
                                final restored = Settings.fromBackup(
                                  restoredSettings,
                                  c.S,
                                );
                                final mode = restored.windowMode;
                                final oldHotkey = c.S.hotkey;
                                restored.windowMode = c.S.windowMode;
                                if (!await c.native.configureHotkey(
                                  restored.hotkey,
                                )) {
                                  restored.hotkey = oldHotkey;
                                  c.toast(l.hotkeyInUse);
                                }
                                await c.native.setStartup(restored.startup);
                                restored.startup = await c.native
                                    .startupEnabled();
                                c.S = restored;
                                c.normalize();
                                c.save();
                                c.refresh();
                                await c.setWindowMode(mode);
                                if (!c.isWindowMode) {
                                  await c.applyPlacement(c.S.edge, c.S.monitor);
                                }
                              }
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      kind == NexBackupKind.export
                                          ? l.importNotesDone
                                          : l.restored,
                                    ),
                                  ),
                                );
                              }
                            });
                          },
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text(l.restore),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.devices_outlined, size: 18),
              label: Text(l.portableLibraryBackup),
              onPressed: f == null
                  ? null
                  : () async {
                      final output = await withPanelHold(
                        context,
                        () => getSaveLocation(
                          suggestedName: 'nex-library.nexbak',
                        ),
                      );
                      if (output == null) return;
                      await f.guard(() async {
                        await f.session.flushed;
                        await f.store.call<String>('portableBackup', {
                          'output': output.path,
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.backupSaved)),
                          );
                        }
                      });
                    },
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
                      Icon(Icons.key_rounded, size: 18, color: scheme.primary),
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
                        tooltip: l.copyKey,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: recoveryKey!));
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
    ];
  }
}
