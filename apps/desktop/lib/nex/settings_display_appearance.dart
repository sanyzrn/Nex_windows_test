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
                        child: Text(
                          '${l.monitor} ${displayNumber(c.screens[i], i)}',
                        ),
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
                  value: 'system',
                  icon: const Icon(Icons.brightness_auto_outlined, size: 16),
                  label: Text(l.followSystem),
                ),
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
              selected: {
                c.S.theme == 'system'
                    ? 'system'
                    : c.palette.isLight
                    ? 'light'
                    : 'dark',
              },
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
            title: l.themePalette,
            control: DropdownButton<String>(
              value: nexThemePresets.any((p) => p.id == c.S.preset)
                  ? c.S.preset
                  : 'classic',
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
            title: l.customAccent,
            control: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: Icon(Icons.color_lens_outlined, color: scheme.primary),
                  label: Text(c.S.accentSeed ?? l.followTheme),
                  onPressed: () async {
                    final picked = await withPanelHold(
                      context,
                      () => showDialog<Color>(
                        context: context,
                        builder: (_) => _AccentDialog(initial: scheme.primary),
                      ),
                    );
                    if (picked == null) return;
                    c.S.accentSeed =
                        '#${picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                    c.pushRecentColor(picked);
                    c.save();
                    c.refresh();
                  },
                ),
                if (c.S.accentSeed != null)
                  IconButton(
                    tooltip: l.followTheme,
                    icon: const Icon(Icons.restart_alt),
                    onPressed: () {
                      c.S.accentSeed = null;
                      c.save();
                      c.refresh();
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          _SettingRow(
            title: l.textScale,
            control: SizedBox(
              width: 180,
              child: Slider(
                min: 0.5,
                max: 3,
                divisions: 25,
                value: c.S.uiScale,
                label: '${(c.S.uiScale * 100).round()}%',
                onChanged: (v) {
                  c.S.uiScale = v;
                  c.refresh();
                },
                onChangeEnd: (_) => c.save(),
              ),
            ),
          ),
          const Divider(height: 1),
          _SettingRow(
            title: l.solarCalendar,
            control: Switch(
              value: c.S.solarCalendar ?? c.resolvedLanguage == 'fa',
              onChanged: (v) {
                c.S.solarCalendar = v;
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
                DropdownMenuItem(value: 'system', child: Text(l.followSystem)),
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

class _AccentDialog extends StatefulWidget {
  const _AccentDialog({required this.initial});
  final Color initial;
  @override
  State<_AccentDialog> createState() => _AccentDialogState();
}

class _AccentDialogState extends State<_AccentDialog> {
  late HSVColor color = HSVColor.fromColor(widget.initial);
  late final hex = TextEditingController(text: _hex(widget.initial));
  String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  void update(HSVColor value) {
    setState(() => color = value);
    hex.text = _hex(value.toColor());
  }

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.customAccent),
      content: SizedBox(
        width: 250,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NexColorWheel(
                hue: color.hue,
                saturation: color.saturation,
                value: color.value,
                semanticLabel: l.customAccent,
                onChanged: (h, s) => update(color.withHue(h).withSaturation(s)),
              ),
              Slider(
                value: color.value,
                onChanged: (v) => update(color.withValue(v)),
              ),
              TextField(
                controller: hex,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l.hexColor,
                  hintText: '#RRGGBB',
                ),
                maxLength: 7,
                onChanged: (v) {
                  if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v)) {
                    setState(
                      () => color = HSVColor.fromColor(
                        Color(int.parse('FF${v.substring(1)}', radix: 16)),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.discard),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, color.toColor()),
          child: Text(l.save),
        ),
      ],
    );
  }
}
