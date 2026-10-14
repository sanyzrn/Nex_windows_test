import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../l10n/app_localizations.dart';
import 'capture_view.dart';
import 'features_state.dart';

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
    final rail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NoteShelf(
          title: l.workspacePinned,
          empty: l.workspaceNoPinned,
          notes: pins,
          pinned: true,
        ),
        const SizedBox(height: 16),
        _NoteShelf(
          title: l.workspaceRecent,
          empty: l.workspaceNoRecent,
          notes: recent,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => c?.selectWindowSection('library'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 15),
            label: Text(l.workspaceViewAll),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
      ],
    );
    // The editor column is the page's work area. The quick-tool buttons that
    // used to sit above it (Clipboard, Timer, Keep awake) moved out: every one
    // of them lives in Tools one keystroke away, they were rarely the first
    // thing anyone wanted, and they pushed the composer below the fold.
    const editor = NexCaptureView(compact: false, embedded: true);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 780;
        final padding = box.maxWidth < 600 ? 16.0 : 24.0;
        // The title and the three counters share a line while there is room;
        // below that the counters move under the title rather than pushing
        // it off the edge (a Wrap inside a Row does not wrap — it overflows).
        final inlineStats = box.maxWidth >= 560;
        final title = Text(
          l.workspaceNotebook,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        );
        final stats = Wrap(
          spacing: 8,
          runSpacing: 4,
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
          ],
        );
        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (inlineStats)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  stats,
                ],
              )
            else ...[
              title,
              const SizedBox(height: 8),
              stats,
            ],
            if (NexScope.of(context).reminderDeliveryFailed)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  l.reminderDeliveryFailed,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
          ],
        );
        if (!wide) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, editor, const SizedBox(height: 24), rail],
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              header,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: editor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 270,
                      child: SingleChildScrollView(child: rail),
                    ),
                  ],
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteShelf extends StatelessWidget {
  const _NoteShelf({
    required this.title,
    required this.empty,
    required this.notes,
    this.pinned = false,
  });
  final String title, empty;
  final List<Note> notes;
  final bool pinned;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              pinned ? Icons.push_pin_outlined : Icons.history_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (notes.isEmpty)
          NexWorkspaceCard(
            padding: const EdgeInsets.all(12),
            child: Text(
              empty,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _NotePreview(note: note),
          ),
      ],
    );
  }
}

class _NotePreview extends StatelessWidget {
  const _NotePreview({required this.note});
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
        backgroundColor: scheme.surfaceContainerLowest,
        padding: const EdgeInsets.all(10),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: nexDirectionOf(label),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  nexDisplayDate(note.createdAt, solar: fa, persian: fa),
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
