// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the settings view split (see settings.dart); do not import this
// file directly.
part of 'settings.dart';

mixin _SettingsToolsAbout on _SettingsStateBase {
  @override
  List<Widget> _buildToolsAbout(BuildContext context) {
    final c = LiquidScope.panelOf(context);
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return [
      // Card 5: Tools & Dock
      _SettingsCard(
        icon: Icons.apps_rounded,
        iconColor: scheme.primary,
        title: l.settingsTools,
        children: [
          NexToolOrganizer(controller: c),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => c.native.pickApp(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l.addApp),
                ),
                OutlinedButton.icon(
                  onPressed: () => c.native.pickApp(folder: true),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                  label: Text(l.addFolder),
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
        title: l.settingsAbout,
        children: [
          if (NexScope.maybeOf(context)?.updates case final updates?) ...[
            NexUpdateCard(updates: updates),
            const SizedBox(height: 18),
          ] else
            const ReleaseNotesButton(),
          Row(
            children: [
              Expanded(
                child: Text(
                  desktopDigits(context, 'Nex Windows v$kAppShortVersion (Build $kAppBuild)'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Nex',
                  applicationVersion: kAppVersionString,
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
    ];
  }
}
