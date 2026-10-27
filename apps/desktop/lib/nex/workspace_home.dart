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
    final scheduled = _overview['scheduled'] as int? ?? 0;
    return LayoutBuilder(
      builder: (context, box) {
        final compactPage = box.maxWidth < 620;
        final small = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
        // One quiet line of heading: a label, how many, and what is next.
        Widget heading(String title, {String? number, Widget? trailing}) =>
            Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 10),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(title, style: small)),
                      if (number != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          number,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                  ?trailing,
                ],
              ),
            );
        Widget grid(List<Note> notes) => LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = ((constraints.maxWidth + 12) / (250 * scale + 12))
                .floor()
                .clamp(1, 5);
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final note in notes)
                  SizedBox(
                    width: width,
                    height: _NotePreview.heightFor(context),
                    child: _NotePreview(note: note),
                  ),
              ],
            );
          },
        );
        return SingleChildScrollView(
          key: const PageStorageKey('workspace-home-scroll'),
          padding: EdgeInsets.fromLTRB(
            box.maxWidth < 600 ? 16 : 28,
            box.maxWidth < 600 ? 12 : 14,
            box.maxWidth < 600 ? 16 : 28,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  SizedBox(height: compactPage ? 4 : 8),
                  const Align(
                    alignment: AlignmentDirectional.topStart,
                    child: NexCaptureView(compact: false, embedded: true),
                  ),
                  const SizedBox(height: 16),
                  const IntelligenceBrief(),
                  if (pins.isNotEmpty) ...[
                    heading(l.workspacePinned, number: count('pinned')),
                    grid(pins),
                  ],
                  heading(
                    l.workspaceRecent,
                    number: count('total'),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (scheduled > 0)
                          TextButton.icon(
                            onPressed: () => showScheduledNotes(context),
                            icon: const Icon(Icons.schedule_outlined, size: 15),
                            label: Text(
                              '${l.scheduledNotes} · ${count('scheduled')}',
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        TextButton(
                          onPressed: c == null
                              ? null
                              : () => c.selectWindowSection('library'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(l.workspaceViewAll),
                        ),
                      ],
                    ),
                  ),
                  if (_revision >= 0 && _overview.isEmpty && _error == null)
                    Text(
                      l.workspaceLoading,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    )
                  else if (recent.isEmpty)
                    Text(
                      l.workspaceNoRecent,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    )
                  else
                    grid(recent),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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

/// A note as a small card on the home page: a title, a few lines, and the
/// tag and the time at the foot — tinted by its tag's colour, otherwise paper.
class _NotePreview extends StatelessWidget {
  const _NotePreview({required this.note});
  final Note note;

  /// The height every card in the grid has; text size grows it.
  static double heightFor(BuildContext context) =>
      128 + 44 * (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = AppLocalizations.of(context)!;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final text = (note.displayText ?? '').trim();
    final lines = text.split('\n').where((s) => s.trim().isNotEmpty).toList();
    final first = lines.firstOrNull?.trim() ?? '';
    final rest = lines.skip(1).join('\n').trim();
    final named = note.title?.trim() ?? '';
    // A short first line over more text is a title. A single thought is the
    // card's text: a title would only cut it off.
    final String title, body;
    if (named.isNotEmpty) {
      title = named;
      body = text;
    } else if (rest.isNotEmpty && first.length <= 60) {
      title = first;
      body = rest;
    } else if (text.isEmpty) {
      title = '';
      body = noteTypeLabel(l, note.type);
    } else {
      title = '';
      body = text;
    }
    final photo = note.type == NoteType.photo && note.mediaUri != null;
    final tag = note.tags.firstOrNull;
    final tint = nexNoteCardColor(
      note,
      theme,
      highContrast: MediaQuery.highContrastOf(context),
    );
    final small = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Material(
      color: tint,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
      ),
      child: InkWell(
        key: ValueKey('workspace-note-${note.id}'),
        onTap: () {
          NexScope.of(context).requestNote(note);
          NexPanelScope.maybeOf(context)?.selectWindowSection('library');
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: nexDirectionOf(title),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Expanded(
                child: photo
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(note.mediaUri!),
                          fit: BoxFit.cover,
                          // A card never needs the full camera bitmap.
                          cacheWidth: 480,
                          errorBuilder: (_, error, stack) => Icon(
                            Icons.image_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Text(
                        body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textDirection: nexDirectionOf(body),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (note.pinnedAt != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: Icon(
                        Icons.push_pin,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (tag != null) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: nexParseTagColor(tag.color) ?? scheme.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        tag.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    nexDisplayDate(
                      note.updatedAt,
                      solar:
                          NexPanelScope.maybeOf(context)?.S.solarCalendar ?? fa,
                      persian: fa,
                    ),
                    style: small,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
