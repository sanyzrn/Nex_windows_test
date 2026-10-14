// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the settings view split (see settings.dart); do not import this
// file directly.
part of 'settings.dart';

mixin _SettingsDisplayAppearance on _SettingsStateBase {
  @override
  List<Widget> _buildDisplayAppearance(BuildContext context) {
    final c = LiquidScope.panelOf(context);
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return [
      // Card 1: Display & Interface
      _SettingsCard(
        icon: Icons.dashboard_customize_outlined,
        iconColor: scheme.primary,
        title: l.settingsDisplay,
        children: [
          _SettingRow(
            title: l.interfaceMode,
            subtitle: l.modeDescription,
            control: SegmentedButton<String>(
              direction: MediaQuery.textScalerOf(context).scale(1) > 1.4
                  ? Axis.vertical
                  : Axis.horizontal,
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
                direction: MediaQuery.textScalerOf(context).scale(1) > 1.4
                    ? Axis.vertical
                    : Axis.horizontal,
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
        title: l.settingsAppearance,
        children: [
          _SettingRow(
            title: l.colorMode,
            control: SegmentedButton<String>(
              direction: MediaQuery.textScalerOf(context).scale(1) > 1.4
                  ? Axis.vertical
                  : Axis.horizontal,
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
          // Card density (IDEAS.md): compact / standard / readable, feeding
          // the NexCardDensityScope around the library.
          _SettingRow(
            title: l.settingsDensity,
            control: SegmentedButton<String>(
              direction: MediaQuery.textScalerOf(context).scale(1) > 1.4
                  ? Axis.vertical
                  : Axis.horizontal,
              segments: [
                ButtonSegment(value: 'compact', label: Text(l.densityCompact)),
                ButtonSegment(
                  value: 'standard',
                  label: Text(l.densityStandard),
                ),
                ButtonSegment(
                  value: 'readable',
                  label: Text(l.densityReadable),
                ),
              ],
              selected: {c.S.cardDensity},
              onSelectionChanged: (v) {
                c.S.cardDensity = v.first;
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
            title: l.appLanguage,
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
    ];
  }
}
