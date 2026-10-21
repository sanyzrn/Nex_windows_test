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
import '../l10n/desktop_format.dart';
import 'features_state.dart';
import '../ui/desktop_accessibility.dart';

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
    final back = IconButton(
      tooltip: l.backToLibrary,
      onPressed: onClose,
      icon: const BackButtonIcon(),
    );
    final edit = canEdit && onToggleEdit != null
        ? IconButton(
            tooltip: editing ? l.readNote : l.editNote,
            onPressed: onToggleEdit,
            icon: Icon(editing ? Icons.done_rounded : Icons.edit_outlined),
          )
        : null;
    final pin = note.pinnedAt != null
        ? Icon(Icons.push_pin, size: 16, color: scheme.primary)
        : null;
    final badge = Container(
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
          Flexible(
            child: Text(
              noteTypeLabel(l, note.type),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final scaledWidth =
            box.maxWidth / MediaQuery.textScalerOf(context).scale(1);
        if (scaledWidth < 180) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  back,
                  const Spacer(),
                  if (pin != null) pin,
                  if (edit != null) edit,
                ],
              ),
              badge,
            ],
          );
        }
        return Row(
          children: [
            back,
            Expanded(
              child: Row(
                children: [
                  Flexible(child: badge),
                  if (pin != null) ...[const SizedBox(width: 8), pin],
                ],
              ),
            ),
            if (edit != null) edit,
          ],
        );
      },
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
            nexDisplayDate(
              note.createdAt,
              solar: NexPanelScope.maybeOf(context)?.S.solarCalendar ?? fa,
              persian: fa,
            ),
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
          desktopDigits(
            context,
            l.wordCount(note.content!.trim().split(RegExp(r'\s+')).length),
          ),
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
    // Preserve the compact tonal row at normal text size; larger text gets
    // two columns and wrapping labels instead of a shrunken font.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(NexRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = scale >= 1.5
                ? (box.maxWidth / scale < 120 ? 1 : 2)
                : cells.length;
            return Wrap(
              children: [
                for (final cell in cells)
                  SizedBox(width: box.maxWidth / columns, child: cell),
              ],
            );
          },
        ),
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
    final disabled = onPressed == null;
    final color = disabled ? scheme.onSurface.withValues(alpha: .38) : tone;
    return DesktopAction(
      label: label,
      excludeSemantics: true,
      material: true,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
