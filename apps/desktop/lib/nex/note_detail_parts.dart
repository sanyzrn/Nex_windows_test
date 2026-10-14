// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Reader header, metadata line and action toolbar for a note detail.
/// Owns [NoteDetailHeader], [NoteMetadataLine] and [NoteActionBar].
library;

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../l10n/app_localizations.dart';
import 'features_state.dart';

/// Header row: back, type badge, pin, and the edit toggle riding with the
/// actions so text-note headers do not show one lone pencil at the far end.
class NoteDetailHeader extends StatelessWidget {
  const NoteDetailHeader({
    super.key,
    required this.note,
    required this.onClose,
    this.editing = false,
    this.onToggleEdit,
  });

  final Note note;
  final VoidCallback onClose;
  final bool editing;
  final VoidCallback? onToggleEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final canEdit =
        note.type == NoteType.text || note.type == NoteType.checklist;
    return Row(
      children: [
        IconButton(
          tooltip: l.backToLibrary,
          onPressed: onClose,
          icon: const BackButtonIcon(),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                nexNoteTypeIcon(note.type.wireName),
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                noteTypeLabel(l, note.type),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (note.pinnedAt != null) ...[
          const SizedBox(width: 8),
          Icon(Icons.push_pin, size: 16, color: scheme.primary),
        ],
        const Spacer(),
        if (canEdit && onToggleEdit != null)
          IconButton(
            tooltip: editing ? l.readNote : l.editNote,
            onPressed: onToggleEdit,
            icon: Icon(editing ? Icons.done_rounded : Icons.edit_outlined),
          ),
      ],
    );
  }
}

/// One row: clock icon, date, time and word count. Each numeric fragment is
/// wrapped in LTR directionality so the Persian line reads in one order and
/// the dot separators stay between the fragments.
class NoteMetadataLine extends StatelessWidget {
  const NoteMetadataLine({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 11.5,
    );
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final time =
        '${note.createdAt.toLocal().hour.toString().padLeft(2, '0')}:${note.createdAt.toLocal().minute.toString().padLeft(2, '0')}';
    final dot = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('•', style: TextStyle(color: muted, height: 1)),
    );
    final fragments = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: muted),
          const SizedBox(width: 4),
          Text(
            nexDisplayDate(note.createdAt, solar: fa, persian: fa),
            style: style,
          ),
        ],
      ),
      dot,
      Directionality(
        textDirection: TextDirection.ltr,
        child: Text(fa ? nexDigits(time, persian: true) : time, style: style),
      ),
      if (note.content?.trim().isNotEmpty == true) ...[
        dot,
        Text(
          l.wordCount(note.content!.trim().split(RegExp(r'\s+')).length),
          style: style,
        ),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 2,
        children: fragments,
      ),
    );
  }
}

/// The reader's actions in one toolbar. Every action is an equal-width
/// expanded button in a 2-per-row grid, so rows never come out 2+2 with
/// different widths and no action is stranded alone.
class NoteActionBar extends StatelessWidget {
  const NoteActionBar({
    super.key,
    required this.note,
    required this.onPin,
    required this.onRemind,
    required this.onDelete,
    this.onCopy,
    this.onOpenMedia,
  });

  final Note note;
  final VoidCallback onPin;
  final VoidCallback onRemind;
  final VoidCallback onDelete;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenMedia;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final pinned = note.pinnedAt != null;
    final cells = <Widget>[
      _ToolAction(label: l.copy, icon: Icons.copy_rounded, onPressed: onCopy),
      _ToolAction(
        label: pinned ? l.unpin : l.pin,
        icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
        onPressed: onPin,
        accent: pinned ? scheme.primary : null,
      ),
      _ToolAction(
        label: l.remind,
        icon: Icons.alarm_add_outlined,
        onPressed: onRemind,
      ),
      _ToolAction(
        label: l.delete,
        icon: Icons.delete_outline_rounded,
        onPressed: onDelete,
        danger: true,
      ),
      if (onOpenMedia != null)
        _ToolAction(
          label: l.open,
          icon: Icons.open_in_new_rounded,
          onPressed: onOpenMedia,
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            cells[i],
          ],
        ],
      ),
    );
  }
}

class _ToolAction extends StatelessWidget {
  const _ToolAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
    this.accent,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = danger ? scheme.error : (accent ?? scheme.onSurfaceVariant);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: onPressed == null ? null : tone),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: onPressed == null
            ? scheme.onSurface.withValues(alpha: .38)
            : (danger ? scheme.error : scheme.onSurface),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        side: BorderSide(
          color: danger
              ? scheme.error.withValues(alpha: .45)
              : (accent ?? scheme.outlineVariant),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
