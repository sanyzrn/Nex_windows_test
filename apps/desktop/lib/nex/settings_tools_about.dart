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
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
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
        title: l.settingsAbout,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nex Windows v$kAppShortVersion (Build $kAppBuild)',
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
