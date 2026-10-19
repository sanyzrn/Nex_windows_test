import 'scheduled_notes.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../l10n/app_localizations.dart';
import 'capture_view.dart';
import 'features_state.dart';
import 'intelligence/brief.dart';

class NexWorkspaceHome extends StatefulWidget {
  const NexWorkspaceHome({super.key});
  @override
  State<NexWorkspaceHome> createState() => _NexWorkspaceHomeState();
}

class _NexWorkspaceHomeState extends State<NexWorkspaceHome> {
  Timer? _reload;
  int _revision = -1, _generation = 0;
  Map<String, dynamic> _overview = {};
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final f = NexScope.of(context);
    if (_revision == f.libraryRevision) return;
    final initial = _revision == -1;
    _revision = f.libraryRevision;
    _reload?.cancel();
    if (initial) {
      unawaited(_load());
    } else {
      _reload = Timer(const Duration(milliseconds: 250), _load);
    }
  }

  Future<void> _load() async {
    final token = ++_generation;
    final store = NexScope.of(context).store;
    try {
      final overview = await store.call<Map<String, dynamic>>('workspace');
      if (mounted && token == _generation) {
        setState(() {
          _overview = overview;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && token == _generation) {
        setState(() => _error = AppLocalizations.of(context)!.failed);
      }
    }
  }

  @override
  void dispose() {
    _reload?.cancel();
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Nullable on purpose: the workspace also renders in tests and previews
    // that have no panel controller in scope, and a missing scope must not
    // take the page down with it.
    final c = NexPanelScope.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    String count(String key) =>
        nexDigits('${_overview[key] ?? 0}', persian: fa);
    final recent = (_overview['recent'] as List?)?.cast<Note>() ?? [];
    final pins = (_overview['pins'] as List?)?.cast<Note>() ?? [];
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 860 && scale < 1.5;
        // The compact window: writing comes first. The hero line and the
        // counters (both also in the library) would push the editor below the
        // fold of a 460 px card.
        final compactPage = box.maxWidth < 620;
        final columns = box.maxWidth >= 1000 && scale < 1.3
            ? 3
            : box.maxWidth >= 620 && scale < 1.6
            ? 2
            : 1;
        final stats = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryCount(
              icon: Icons.notes_rounded,
              count: count('total'),
              label: l.workspaceTotal,
            ),
            _SummaryCount(
              icon: Icons.push_pin_outlined,
              count: count('pinned'),
              label: l.workspacePinned,
            ),
            _SummaryCount(
              icon: Icons.attach_file_rounded,
              count: count('media'),
              label: l.workspaceMedia,
            ),
            if ((_overview['scheduled'] as int? ?? 0) > 0)
              ActionChip(
                avatar: const Icon(Icons.schedule_outlined, size: 16),
                label: Text('${l.scheduledNotes} · ${count('scheduled')}'),
                onPressed: () => showScheduledNotes(context),
              ),
          ],
        );
        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.workspaceNotebook,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.workspaceStartHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        );
        final quickTools = <(String, IconData, String)>[
          ('clip', Icons.content_paste_rounded, l.clipboard),
          ('timer', Icons.timer_outlined, l.workspaceFocus),
          ('calc', Icons.calculate_outlined, l.workspaceCalculate),
        ].where((entry) => !(c?.S.hidden.contains(entry.$1) ?? false)).toList();
        final shelf = NexWorkspaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ShelfHeading(
                icon: Icons.push_pin_outlined,
                title: l.workspacePinned,
              ),
              const SizedBox(height: 12),
              if (pins.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    l.workspaceNoPinned,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              for (final note in pins)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _NotePreview(note: note, quiet: true),
                ),
              if (quickTools.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 16),
                _ShelfHeading(
                  icon: Icons.bolt_outlined,
                  title: l.workspaceEssentials,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in quickTools)
                      ActionChip(
                        avatar: Icon(entry.$2, size: 16),
                        label: Text(entry.$3),
                        onPressed: c == null
                            ? null
                            : () => c.openWindowTool(entry.$1),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        backgroundColor: scheme.primary.withValues(alpha: .07),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
        return SingleChildScrollView(
          key: const PageStorageKey('workspace-home-scroll'),
          padding: EdgeInsets.all(box.maxWidth < 600 ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: intro),
                        const SizedBox(width: 20),
                        stats,
                      ],
                    )
                  else if (!compactPage) ...[
                    intro,
                    const SizedBox(height: 16),
                    stats,
                  ],
                  if (NexScope.of(context).reminderDeliveryFailed)
                    _HomeMessage(
                      l.reminderDeliveryFailed,
                      actionLabel: c == null ? null : l.notificationSettings,
                      onAction: c == null
                          ? null
                          : () => unawaited(
                              c.native
                                  .launch('ms-settings:notifications')
                                  .catchError((_) {}),
                            ),
                    ),
                  if (_error != null) _HomeMessage(_error!, onRetry: _load),
                  SizedBox(height: compactPage ? 4 : 24),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          flex: 7,
                          child: NexCaptureView(compact: false, embedded: true),
                        ),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: shelf),
                      ],
                    )
                  else ...[
                    const NexCaptureView(compact: false, embedded: true),
                    const SizedBox(height: 20),
                    shelf,
                  ],
                  const SizedBox(height: 20),
                  const IntelligenceBrief(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _ShelfHeading(
                          icon: Icons.history_rounded,
                          title: l.workspaceRecent,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: c == null
                            ? null
                            : () => c.selectWindowSection('library'),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text(l.workspaceViewAll),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_revision >= 0 && _overview.isEmpty && _error == null)
                    NexWorkspaceCard(
                      child: Text(
                        l.workspaceLoading,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else if (recent.isEmpty)
                    NexWorkspaceCard(
                      child: Text(
                        l.workspaceNoRecent,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width =
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final note in recent)
                              SizedBox(
                                width: width,
                                child: _NotePreview(note: note),
                              ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCount extends StatelessWidget {
  const _SummaryCount({
    required this.icon,
    required this.count,
    required this.label,
  });
  final IconData icon;
  final String count, label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            count,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ShelfHeading extends StatelessWidget {
  const _ShelfHeading({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage(
    this.message, {
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        if (onAction != null && actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        if (onRetry != null)
          IconButton(
            tooltip: AppLocalizations.of(context)!.retry,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
  );
}

class _NotePreview extends StatelessWidget {
  const _NotePreview({required this.note, this.quiet = false});
  final bool quiet;
  final Note note;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final caption = note.displayText?.trim();
    final label = caption?.isNotEmpty == true
        ? caption!
        : noteTypeLabel(l, note.type);
    final photo = note.type == NoteType.photo && note.mediaUri != null;
    return TextButton(
      key: ValueKey('workspace-note-${note.id}'),
      onPressed: () {
        NexScope.of(context).requestNote(note);
        NexPanelScope.maybeOf(context)?.selectWindowSection('library');
      },
      style: TextButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        foregroundColor: scheme.onSurface,
        backgroundColor: nexNoteCardColor(
          note,
          Theme.of(context),
          highContrast: MediaQuery.highContrastOf(context),
        ),
        padding: EdgeInsets.all(quiet ? 10 : 16),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: photo
                ? Image.file(
                    File(note.mediaUri!),
                    fit: BoxFit.cover,
                    // A 32px thumbnail never needs the full bitmap; decoding
                    // whole camera photos for the shelf was jank and memory
                    // for nothing.
                    cacheWidth: 96,
                    errorBuilder: (_, error, stack) => Icon(
                      Icons.image_outlined,
                      size: 16,
                      color: scheme.primary,
                    ),
                  )
                : Icon(
                    nexNoteTypeIcon(note.type.wireName),
                    size: 16,
                    color: scheme.primary,
                  ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: quiet ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  textDirection: nexDirectionOf(label),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  nexDisplayDate(
                    note.updatedAt,
                    solar:
                        NexPanelScope.maybeOf(context)?.S.solarCalendar ?? fa,
                    persian: fa,
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
