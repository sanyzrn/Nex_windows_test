import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';
import '../l10n/app_localizations.dart';
import 'features_state.dart';
import 'commitments.dart';
import 'scheduled_notes.dart';
import 'set_aside.dart';
import 'modules/private_gate.dart';
import 'modules/vault_store.dart';
import 'modules/vault_view.dart';

/// Desktop host for the Android Tools/Library destinations. Scope and panel hold
/// survive opening the root navigator, including the private gate's navigator.
Future<T?> showDesktopCollection<T>(
  BuildContext context,
  String title,
  Widget child,
) {
  final features = NexScope.of(context);
  final panel = NexPanelScope.maybeOf(context);
  return withPanelHold(
    context,
    () => showDialog<T>(
      context: context,
      builder: (context) {
        Widget dialog = Dialog(
          insetPadding: const EdgeInsets.all(NexSpacing.md),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 900,
            height: MediaQuery.sizeOf(context).height * .9,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 20,
                    end: 8,
                    top: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: AppLocalizations.of(context)!.close,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(child: child),
              ],
            ),
          ),
        );
        if (panel != null) {
          dialog = NexPanelScope(controller: panel, child: dialog);
        }
        return NexScope(features: features, child: dialog);
      },
    ),
  );
}

class DesktopShelfTile extends StatelessWidget {
  const DesktopShelfTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentId,
    required this.onTap,
    this.locked = false,
  });
  final String title, subtitle, accentId;
  final IconData icon;
  final VoidCallback onTap;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = NexColors.toolAccent(accentId, scheme.primary);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(18),
        alignment: AlignmentDirectional.centerStart,
        foregroundColor: scheme.onSurface,
        backgroundColor: accent.withValues(alpha: .06),
        side: BorderSide(color: accent.withValues(alpha: .45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.onSurface),
              ),
              const Spacer(),
              if (locked)
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class NexToolsShelves extends StatelessWidget {
  const NexToolsShelves({super.key, this.query = ''});
  final String query;
  @override
  Widget build(BuildContext context) {
    final features = NexScope.maybeOf(context);
    if (features == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    bool matches(String title, String hint) =>
        '$title $hint'.toLowerCase().contains(query.trim().toLowerCase());
    final private = <Widget>[
      for (final (kind, title, hint, icon, accent) in [
        (
          VaultKind.password,
          l.vaultPasswords,
          l.vaultPasswordsHint,
          Icons.key_rounded,
          'pass',
        ),
        (
          VaultKind.card,
          l.vaultCards,
          l.vaultCardsHint,
          Icons.credit_card_rounded,
          'timer',
        ),
        (
          VaultKind.message,
          l.toolsMessages,
          l.toolsMessagesHint,
          Icons.chat_bubble_outline,
          'calc',
        ),
      ])
        if (matches(title, hint))
          DesktopShelfTile(
            key: ValueKey('private-${kind.name}'),
            title: title,
            subtitle: hint,
            icon: icon,
            accentId: accent,
            locked: true,
            onTap: () => unawaited(
              showDesktopCollection<void>(
                context,
                title,
                DesktopPrivateGate(
                  session: features.modules.privateSession,
                  builder: (_) => DesktopVaultView(
                    modules: features.modules,
                    initialKind: kind,
                  ),
                ),
              ),
            ),
          ),
    ];
    final everyday = <Widget>[
      if (matches(l.vaultGenerate, l.toolsGeneratorHint))
        DesktopShelfTile(
          key: const ValueKey('tools-password-generator'),
          title: l.vaultGenerate,
          subtitle: l.toolsGeneratorHint,
          icon: Icons.casino_outlined,
          accentId: 'clock',
          onTap: () {
            final panel = NexPanelScope.maybeOf(context);
            if (panel?.isWindowMode ?? false) {
              panel!.openWindowTool('pass');
            } else {
              panel?.openWidget('pass');
            }
          },
        ),
      if (matches(l.scheduledTitle, l.scheduledSubtitle))
        DesktopShelfTile(
          key: const ValueKey('tools-scheduled'),
          title: l.scheduledTitle,
          subtitle: l.scheduledSubtitle,
          icon: Icons.schedule_send_outlined,
          accentId: 'clip',
          onTap: () => unawaited(
            withPanelHold(context, () => showScheduledNotes(context)),
          ),
        ),
      if (matches(l.commitmentsTitle, l.commitmentTitleHint))
        DesktopShelfTile(
          key: const ValueKey('tools-recurring'),
          title: l.commitmentsTitle,
          subtitle: l.commitmentTitleHint,
          icon: Icons.event_repeat_rounded,
          accentId: 'timer',
          onTap: () => unawaited(
            showDesktopCollection<void>(
              context,
              l.commitmentsTitle,
              const NexCommitmentsView(),
            ),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (private.isNotEmpty) ...[
          Text(
            l.toolsSectionPrivate,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(l.toolsPrivateHint),
          const SizedBox(height: 12),
          NexResponsiveGrid(minWidth: 200, children: private),
          const SizedBox(height: 24),
        ],
        if (everyday.isNotEmpty) ...[
          Text(
            l.toolsSectionEveryday,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          NexResponsiveGrid(minWidth: 200, children: everyday),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class NexLibraryLocations extends StatefulWidget {
  const NexLibraryLocations({super.key});
  @override
  State<NexLibraryLocations> createState() => _NexLibraryLocationsState();
}

class _NexLibraryLocationsState extends State<NexLibraryLocations> {
  Map<String, int>? counts;
  bool started = false;
  Future<void> load() async {
    final result = await NexScope.of(
      context,
    ).store.call<Map<String, int>>('libraryCounts');
    if (mounted) setState(() => counts = result);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      unawaited(load().catchError((Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: NexResponsiveGrid(
        minWidth: 200,
        children: [
          DesktopShelfTile(
            key: const ValueKey('library-set-aside'),
            title: l.setAsideSection,
            subtitle: l.setAsideSectionHint,
            icon: Icons.archive_outlined,
            accentId: 'pass',
            onTap: () async {
              await showDesktopCollection<void>(
                context,
                l.setAsidePageTitle,
                const NexSetAsideView(),
              );
              if (mounted) await load();
            },
          ),
          DesktopShelfTile(
            key: const ValueKey('library-tags'),
            title: l.tags,
            subtitle: counts == null
                ? l.libraryTagsHint
                : l.libraryTagCount(counts!['tags']!),
            icon: Icons.label_outline,
            accentId: 'calc',
            onTap: () => Navigator.pop(context, 'tags'),
          ),
          DesktopShelfTile(
            key: const ValueKey('library-threads'),
            title: l.threads,
            subtitle: counts == null
                ? l.threadsSubtitle
                : l.libraryThreadCount(counts!['threads']!),
            icon: Icons.timeline_outlined,
            accentId: 'timer',
            onTap: () => Navigator.pop(context, 'threads'),
          ),
          DesktopShelfTile(
            key: const ValueKey('library-trash'),
            title: l.trash,
            subtitle: counts == null
                ? l.libraryTrashHint
                : l.libraryTrashCount(counts!['trash']!),
            icon: Icons.restore_from_trash_outlined,
            accentId: 'color',
            onTap: () => Navigator.pop(context, 'trash'),
          ),
        ],
      ),
    );
  }
}
