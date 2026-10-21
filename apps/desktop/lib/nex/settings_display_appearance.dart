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
          const Divider(height: 1),
          _SettingRow(
            title: l.windowCloseAction,
            subtitle: c.S.closeToTray
                ? l.windowCloseTrayHint
                : l.windowCloseQuitHint,
            control: Switch(
              key: const ValueKey('close-to-tray'),
              value: c.S.closeToTray,
              onChanged: (v) {
                c.S.closeToTray = v;
                c.save();
                c.refresh();
              },
            ),
          ),
          const Divider(height: 1),
          _SettingRow(
            title: l.windowRemember,
            subtitle: l.windowRememberHint,
            control: Switch(
              key: const ValueKey('window-remember'),
              value: c.S.windowRemember,
              onChanged: (v) async {
                c.S.windowRemember = v;
                c.save();
                c.refresh();
                await c.native.setCompactRestoration(!v);
              },
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
                          desktopDigits(
                            context,
                            '${l.monitor} ${displayNumber(c.screens[i], i)}',
                          ),
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
            title: l.testNotification,
            subtitle: l.testNotificationHint,
            control: DesktopFocusRing(
              child: Wrap(
                spacing: NexSpacing.sm,
                runSpacing: NexSpacing.sm,
                children: [
                  OutlinedButton(
                    key: const ValueKey('test-notification'),
                    onPressed: () => sendDesktopTestNotification(c, l),
                    child: Text(l.testNotificationRun),
                  ),
                  TextButton(
                    onPressed: () =>
                        c.native.launch('ms-settings:notifications'),
                    child: Text(l.notificationSettings),
                  ),
                ],
              ),
            ),
          ),
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
          Text(l.colorMode, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          NexResponsiveGrid(
            minWidth: 135,
            maxColumns: 3,
            children: [
              for (final mode in ['light', 'dark', 'system'])
                _AppearanceChoice(
                  label: mode == 'light'
                      ? l.light
                      : mode == 'dark'
                      ? l.dark
                      : l.followSystem,
                  selected:
                      (c.S.theme == 'system'
                          ? 'system'
                          : c.palette.isLight
                          ? 'light'
                          : 'dark') ==
                      mode,
                  icon: mode == 'light'
                      ? Icons.light_mode_outlined
                      : mode == 'dark'
                      ? Icons.dark_mode_outlined
                      : Icons.brightness_auto_outlined,
                  onTap: () {
                    c.S.theme = mode;
                    c.save();
                    c.refresh();
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          // Card density (IDEAS.md): compact / standard / readable, feeding
          // the NexCardDensityScope around the library.
          const SizedBox(height: 18),
          Text(
            l.settingsDensity,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          NexResponsiveGrid(
            minWidth: 145,
            maxColumns: 3,
            children: [
              for (final density in ['compact', 'standard', 'readable'])
                _AppearanceChoice(
                  label: density == 'compact'
                      ? l.densityCompact
                      : density == 'standard'
                      ? l.densityStandard
                      : l.densityReadable,
                  selected: c.S.cardDensity == density,
                  icon: density == 'compact'
                      ? Icons.view_headline_rounded
                      : density == 'standard'
                      ? Icons.view_agenda_outlined
                      : Icons.view_day_outlined,
                  onTap: () {
                    c.S.cardDensity = density;
                    c.save();
                    c.refresh();
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
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
                label: desktopDigits(
                  context,
                  '${(c.S.uiScale * 100).round()}%',
                ),
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
                  hintText: l.hexColorHint,
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

class _AppearanceChoice extends StatelessWidget {
  const _AppearanceChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: DesktopFocusRing(
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(18),
            backgroundColor: selected
                ? c.primary.withValues(alpha: .09)
                : c.surface,
            foregroundColor: selected ? c.primary : c.onSurface,
            side: BorderSide(
              color: selected ? c.primary : c.outline,
              width: selected ? 2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 14),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
