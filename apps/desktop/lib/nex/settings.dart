import '../l10n/utility_strings.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:nex_ui/nex_ui.dart';
import '../core/registry.dart';
import '../ui/widgets.dart';
import '../l10n/app_localizations.dart';
import 'features.dart';

class NexSettingsView extends StatefulWidget {
  const NexSettingsView({super.key});
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.settings, style: Theme.of(context).textTheme.titleLarge),
          DropdownButton<String>(
            value: c.S.language,
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
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'light', label: Text(l.light)),
              ButtonSegment(value: 'dark', label: Text(l.dark)),
            ],
            selected: {c.palette.isLight ? 'light' : 'dark'},
            onSelectionChanged: (v) {
              c.S.theme = v.first;
              c.save();
              c.refresh();
            },
          ),
          DropdownButton<String>(
            value: c.S.preset,
            items: nexThemePresets
                .map(
                  (v) => DropdownMenuItem(
                    value: v.id,
                    child: Text(nexThemePresetLabel(context, v.id)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              c.S.preset = v!;
              c.save();
              c.refresh();
            },
          ),
          Text(l.edge),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'left', label: Text(l.left)),
              ButtonSegment(value: 'right', label: Text(l.right)),
            ],
            selected: {c.S.edge},
            onSelectionChanged: (v) async {
              await c.applyPlacement(v.first, c.S.monitor);
            },
          ),
          if (c.screens.isNotEmpty)
            DropdownButton<int>(
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.startup),
            value: c.S.startup,
            onChanged: (v) async {
              await c.native.setStartup(v);
              c.S.startup = await c.native.startupEnabled();
              c.save();
              c.refresh();
            },
          ),
          Text(l.hotkey),
          DropdownButton<String>(
            value: c.S.hotkey,
            items: ['N', 'Q', 'Space']
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(utilityLabelForText(context, v)),
                  ),
                )
                .toList(),
            onChanged: (v) async {
              if (await c.native.configureHotkey(v!)) {
                c.S.hotkey = v;
                c.save();
                c.refresh();
              }
            },
          ),
          TextButton(
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
                        {'output': path.path, 'settings': c.S.toMap()},
                      );
                      if (mounted) setState(() => recoveryKey = recovery);
                    });
                  },
            child: Text(l.backup),
          ),
          if (recoveryKey != null) ...[
            Text(l.backupInfo),
            Text(l.recoveryKey),
            SelectableText(recoveryKey!, textDirection: TextDirection.ltr),
          ],
          ExpansionTile(
            title: Text(l.tools),
            children: [
              for (final tool in kTools.values.where(
                (t) => !t.fixed && t.id != 'more',
              ))
                SwitchListTile(
                  title: Text(utilityLabelForText(context, tool.name)),
                  value: c.S.dock!.contains(tool.id),
                  onChanged: (v) {
                    c.moveWidget(tool.id, v ? 'dock' : 'more', 0);
                  },
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.pasteOnClick),
            value: c.S.paste,
            onChanged: (v) {
              c.S.paste = v;
              c.save();
              c.refresh();
            },
          ),
          ExpansionTile(
            title: Text(l.appsAndShortcuts),
            children: [
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => c.native.pickApp(),
                    child: Text(l.addApp),
                  ),
                  TextButton(
                    onPressed: () => c.native.pickApp(folder: true),
                    child: Text(l.addFolder),
                  ),
                ],
              ),
              for (final app in c.S.apps)
                ListTile(
                  dense: true,
                  title: Text(
                    app.name,
                    textDirection: nexDirectionOf(app.name),
                  ),
                  trailing: IconButton(
                    tooltip: l.remove,
                    icon: const Icon(Icons.close),
                    onPressed: () => c.removeApp(app.id),
                  ),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.magnify),
            value: c.S.magnify,
            onChanged: (v) {
              c.S.magnify = v;
              c.save();
              c.refresh();
            },
          ),
          Text(l.assistantStub),
          TextButton(onPressed: c.quit, child: Text(l.quit)),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Nex',
              applicationVersion: '0.9.0 (Windows preview)',
            ),
            child: Text(l.about),
          ),
          if (f?.error != null) Text('${l.failed}: ${f!.error}'),
        ],
      ),
    );
  }
}
