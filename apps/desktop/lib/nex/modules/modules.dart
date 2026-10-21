import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/app_localizations.dart';
import '../features_state.dart';
import 'module_controller.dart';
import 'private_gate.dart';
import 'pdf_reader.dart';
import 'vault_view.dart';
import 'portrait_view.dart';
import 'cycle_view.dart';

String desktopModuleTitle(AppLocalizations l, DesktopModule module) =>
    switch (module) {
      DesktopModule.pdf => l.modulePdf,
      DesktopModule.vault => l.moduleVault,
      DesktopModule.portrait => l.modulePortrait,
      DesktopModule.cycle => l.moduleCycle,
    };
String desktopModuleHint(AppLocalizations l, DesktopModule module) =>
    switch (module) {
      DesktopModule.pdf => l.modulePdfHint,
      DesktopModule.vault => l.moduleVaultHint,
      DesktopModule.portrait => l.modulePortraitHint,
      DesktopModule.cycle => l.moduleCycleHint,
    };
IconData desktopModuleIcon(DesktopModule module) => switch (module) {
  DesktopModule.pdf => Icons.picture_as_pdf_outlined,
  DesktopModule.vault => Icons.lock_outline_rounded,
  DesktopModule.portrait => Icons.auto_stories_outlined,
  DesktopModule.cycle => Icons.spa_outlined,
};

Future<void> openDesktopModuleMedia(BuildContext context, String path) async {
  final features = NexScope.of(context);
  final native = NexPanelScope.maybeOf(context)?.native;
  if (path.toLowerCase().endsWith('.pdf')) {
    await features.modules.initialize();
    if (!context.mounted) return;
    if (features.modules.enabled(DesktopModule.pdf)) {
      await showDesktopModule(context, DesktopModule.pdf, pdfPath: path);
      return;
    }
  }
  await native?.launch(path);
}

Future<void> showDesktopModule(
  BuildContext context,
  DesktopModule module, {
  String? pdfPath,
}) async {
  final features = NexScope.of(context);
  final modules = features.modules;
  final panel = NexPanelScope.maybeOf(context);
  await modules.initialize();
  if (!context.mounted || !modules.enabled(module)) return;
  await withPanelHold(
    context,
    () => showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(NexSpacing.md),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 860,
          height: MediaQuery.sizeOf(dialogContext).height * .9,
          child: ListenableBuilder(
            listenable: modules,
            builder: (context, _) {
              final l = AppLocalizations.of(context)!;
              Widget content = switch (module) {
                DesktopModule.pdf => DesktopPdfReader(
                  features: features,
                  initialPath: pdfPath,
                ),
                DesktopModule.vault => DesktopPrivateGate(
                  session: modules.privateSession,
                  builder: (_) => DesktopVaultView(modules: modules),
                ),
                DesktopModule.portrait => DesktopPortraitView(
                  features: features,
                ),
                DesktopModule.cycle => DesktopPrivateGate(
                  session: modules.privateSession,
                  builder: (_) => DesktopCycleView(features: features),
                ),
              };
              if (!modules.enabled(module)) {
                content = Center(child: Text(l.moduleDisabled));
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      NexSpacing.md,
                      NexSpacing.sm,
                      NexSpacing.sm,
                      0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          desktopModuleIcon(module),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: NexSpacing.sm),
                        Expanded(
                          child: Text(
                            desktopModuleTitle(l, module),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: l.close,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: NexSpacing.md),
                  Expanded(
                    child: NexScope(
                      features: features,
                      child: panel == null
                          ? content
                          : NexPanelScope(controller: panel, child: content),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class NexModulesSettings extends StatefulWidget {
  const NexModulesSettings({super.key});
  @override
  State<NexModulesSettings> createState() => _NexModulesSettingsState();
}

class _NexModulesSettingsState extends State<NexModulesSettings> {
  bool failed = false, started = false;
  DesktopModule? saving;
  @override
  Widget build(BuildContext context) {
    final features = NexScope.maybeOf(context);
    if (features == null) return const SizedBox.shrink();
    final modules = features.modules;
    if (!started) {
      started = true;
      unawaited(
        modules.initialize().catchError((Object _) {
          if (mounted) setState(() => failed = true);
        }),
      );
    }
    return ListenableBuilder(
      listenable: modules,
      builder: (context, _) {
        final l = AppLocalizations.of(context)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.modulesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: NexSpacing.sm),
            Text(l.modulesHint, style: Theme.of(context).textTheme.bodySmall),
            if (failed)
              Text(
                l.failed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final module in DesktopModule.values) ...[
              SwitchListTile.adaptive(
                key: ValueKey('module-switch-${module.name}'),
                contentPadding: EdgeInsets.zero,
                secondary: Icon(desktopModuleIcon(module)),
                title: Text(desktopModuleTitle(l, module)),
                subtitle: Text(desktopModuleHint(l, module)),
                value: modules.enabled(module),
                onChanged: !modules.ready || saving != null
                    ? null
                    : (value) async {
                        setState(() {
                          saving = module;
                          failed = false;
                        });
                        try {
                          await modules.setEnabled(module, value);
                        } catch (_) {
                          if (mounted) setState(() => failed = true);
                        } finally {
                          if (mounted) setState(() => saving = null);
                        }
                      },
              ),
              if (modules.enabled(module))
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => showDesktopModule(context, module),
                    icon: const Icon(Icons.arrow_outward_rounded),
                    label: Text(l.moduleOpen),
                  ),
                ),
            ],
            const SizedBox(height: NexSpacing.md),
          ],
        );
      },
    );
  }
}

class NexModuleShelf extends StatelessWidget {
  const NexModuleShelf({super.key, this.query = ''});
  final String query;
  @override
  Widget build(BuildContext context) {
    final f = NexScope.maybeOf(context);
    if (f == null) return const SizedBox.shrink();
    final modules = f.modules;
    unawaited(modules.initialize().catchError((Object _) {}));
    return ListenableBuilder(
      listenable: modules,
      builder: (context, _) {
        final l = AppLocalizations.of(context)!;
        final enabled = DesktopModule.values
            .where(
              (m) =>
                  modules.enabled(m) &&
                  desktopModuleTitle(
                    l,
                    m,
                  ).toLowerCase().contains(query.trim().toLowerCase()),
            )
            .toList();
        if (enabled.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: NexSpacing.lg),
          child: Wrap(
            spacing: NexSpacing.sm,
            runSpacing: NexSpacing.sm,
            children: [
              for (final m in enabled)
                ActionChip(
                  key: ValueKey('module-open-${m.name}'),
                  avatar: Icon(desktopModuleIcon(m), size: 18),
                  label: Text(desktopModuleTitle(l, m)),
                  onPressed: () => showDesktopModule(context, m),
                ),
            ],
          ),
        );
      },
    );
  }
}
