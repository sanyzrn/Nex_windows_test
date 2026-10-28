import 'package:flutter/material.dart';
import '../l10n/desktop_format.dart';
import 'release_notes.dart';
import 'package:nex_ui/nex_ui.dart';
import '../l10n/desktop_strings.dart';
import 'controller.dart';

class NexUpdateCard extends StatelessWidget {
  const NexUpdateCard({super.key, required this.updates, this.compact = false});
  final DesktopUpdates updates;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final s = DesktopStrings.of(context), c = Theme.of(context).colorScheme;
      final u = updates;
      final label = switch (u.phase) {
        UpdatePhase.checking => 'checking',
        UpdatePhase.downloading => 'downloading',
        UpdatePhase.ready => 'ready',
        UpdatePhase.available => 'available',
        UpdatePhase.installing => 'installing',
        UpdatePhase.idle =>
          u.lastChecked == null || u.error != null ? 'updates' : 'upToDate',
      };
      final action = u.ready
          ? 'install'
          : u.release != null
          ? 'download'
          : 'check';
      final button = FilledButton.icon(
        onPressed: u.busy
            ? null
            : u.ready
            ? u.installReady
            : u.release != null
            ? u.download
            : u.check,
        icon: Icon(
          u.ready ? Icons.restart_alt_rounded : Icons.system_update_alt_rounded,
          size: 18,
        ),
        label: Text(s.t(action)),
      );
      return NexSoftCard(
        accent: u.release == null ? null : c.primary,
        padding: EdgeInsets.all(compact ? 16 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const NexIconBadge(icon: Icons.system_update_alt_rounded),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.t(label),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            u.release == null
                                ? '${s.t('installed')} ${desktopDigits(context, u.currentVersion)}'
                                : 'Nex ${desktopDigits(context, u.release!.version)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                button,
              ],
            ),
            if (u.phase == UpdatePhase.downloading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: u.progress),
              const SizedBox(height: 6),
              Text(desktopDigits(context, '${(u.progress * 100).floor()}%')),
            ],
            if (u.error != null) ...[
              const SizedBox(height: 12),
              Text(
                s.t(switch (u.error) {
                  'download' => 'updateDownloadError',
                  'install' => 'updateInstallError',
                  _ => 'updateCheckError',
                }),
                style: TextStyle(color: c.error),
              ),
              TextButton(
                onPressed: u.busy
                    ? null
                    : u.ready
                    ? u.installReady
                    : u.release != null
                    ? u.download
                    : u.check,
                child: Text(s.t('retry')),
              ),
            ],
            if (!compact) ...[
              const ReleaseNotesButton(),
              const SizedBox(height: 18),
              NexSwitchTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.t('automatic')),
                subtitle: Text(s.t('automaticHint')),
                value: u.automatic,
                onChanged: u.phase == UpdatePhase.installing
                    ? null
                    : u.setAutomatic,
              ),
              const SizedBox(height: 12),
              Text(
                s.t('updatePrivacy'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class NexUpdateBanner extends StatefulWidget {
  const NexUpdateBanner({super.key, required this.updates});
  final DesktopUpdates? updates;
  @override
  State<NexUpdateBanner> createState() => _BannerState();
}

class _BannerState extends State<NexUpdateBanner> {
  String? dismissed;
  @override
  Widget build(BuildContext context) {
    final u = widget.updates;
    if (u == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) {
        if (!u.ready || u.release?.version == dismissed) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 34),
                child: NexUpdateCard(updates: u, compact: true),
              ),
              Positioned.directional(
                textDirection: Directionality.of(context),
                end: 0,
                top: 0,
                child: IconButton(
                  tooltip: DesktopStrings.of(context).t('later'),
                  onPressed: () =>
                      setState(() => dismissed = u.release?.version),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A live update marker; it never starts a network request.
class NexUpdateDot extends StatelessWidget {
  const NexUpdateDot({super.key, required this.updates, required this.child});
  final DesktopUpdates? updates;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final service = updates;
    if (service == null) return child;
    return ListenableBuilder(
      listenable: service,
      child: child,
      builder: (context, icon) => Badge(
        isLabelVisible: service.release != null,
        smallSize: 8,
        backgroundColor: Theme.of(context).colorScheme.error,
        child: icon!,
      ),
    );
  }
}
