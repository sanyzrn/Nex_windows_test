import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../l10n/app_localizations.dart';
import 'features_state.dart';

/// A note as a small card — on the window's home page and in the edge panel: a title, a few lines, and the
/// tag and the time at the foot — tinted by its tag's colour, otherwise paper.
class NexNoteTile extends StatelessWidget {
  const NexNoteTile({
    super.key,
    required this.note,
    required this.onOpen,
    this.showDate = true,
  });
  final Note note;

  /// A narrow card gives its footer to the tag instead of the date.
  final bool showDate;

  /// What tapping the card does: the window goes to its Library, the edge
  /// panel opens its own.
  final VoidCallback onOpen;

  /// The height every card in the grid has; text size grows it.
  static double heightFor(BuildContext context) =>
      128 + 44 * (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = AppLocalizations.of(context)!;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final text = note.displayText ?? '';
    final lines = text.split('\n');
    final first = lines.firstOrNull?.trim() ?? '';
    final rest = lines.skip(1).join('\n');
    final named = note.title?.trim() ?? '';
    // A short first line over more text is a title. A single thought is the
    // card's text: a title would only cut it off.
    final String title, body;
    if (named.isNotEmpty) {
      title = named;
      body = text;
    } else if (rest.trim().isNotEmpty && first.length <= 60) {
      title = first;
      body = rest;
    } else if (text.trim().isEmpty) {
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
        onTap: onOpen,
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
                  if (showDate) ...[
                    const Spacer(),
                    Text(
                      nexDisplayDate(
                        note.updatedAt,
                        solar:
                            NexPanelScope.maybeOf(context)?.S.solarCalendar ??
                            fa,
                        persian: fa,
                      ),
                      style: small,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
