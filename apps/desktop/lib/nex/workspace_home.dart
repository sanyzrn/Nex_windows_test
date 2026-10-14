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
    final c = NexPanelScope.maybeOf(context)!;
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
        const SizedBox(height: 22),
        _NoteShelf(
          title: l.workspaceRecent,
          empty: l.workspaceNoRecent,
          notes: recent,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => c.selectWindowSection('library'),
          icon: const Icon(Icons.arrow_forward_rounded, size: 17),
          label: Text(l.workspaceViewAll),
        ),
      ],
    );
    final editor = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.edit_note_rounded, size: 21, color: scheme.primary),
            const SizedBox(width: 8),
            Text(l.capture, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => c.openWindowTool('clip'),
              icon: const Icon(Icons.content_paste_outlined, size: 17),
              label: Text(l.utility1),
            ),
            OutlinedButton.icon(
              onPressed: () => c.openWindowTool('timer'),
              icon: const Icon(Icons.timer_outlined, size: 17),
              label: Text(l.utility21),
            ),
            OutlinedButton.icon(
              onPressed: c.awakeBusy ? null : () => c.runAction('awake'),
              icon: Icon(
                c.awake ? Icons.check_circle_outline : Icons.wb_sunny_outlined,
                size: 17,
              ),
              label: Text(l.utility48),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const NexCaptureView(compact: false, embedded: true),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 850;
        final padding = box.maxWidth < 600 ? 20.0 : 28.0;
        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.workspaceNotebook,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.workspaceStartHint,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
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
              ],
            ),
            if (NexScope.of(context).reminderDeliveryFailed)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  l.reminderDeliveryFailed,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 28),
          ],
        );
        if (!wide) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, editor, const SizedBox(height: 28), rail],
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
                    Expanded(child: SingleChildScrollView(child: editor)),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 290,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            count,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
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
              size: 17,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          NexWorkspaceCard(
            padding: const EdgeInsets.all(18),
            child: Text(
              empty,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
        NexPanelScope.maybeOf(context)!.selectWindowSection('library');
      },
      style: TextButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        foregroundColor: scheme.onSurface,
        backgroundColor: scheme.surfaceContainerLowest,
        padding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: photo
                ? Image.file(
                    File(note.mediaUri!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) => Icon(
                      Icons.image_outlined,
                      size: 19,
                      color: scheme.primary,
                    ),
                  )
                : Icon(
                    nexNoteTypeIcon(note.type.wireName),
                    size: 19,
                    color: scheme.primary,
                  ),
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 6),
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
