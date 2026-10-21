// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the NexLibraryView split (see library_view.dart). The widgets below
// are private to the library; do not import this file directly.
part of 'library_view.dart';

/// Horizontal row of filter pills (all / type / tag / thread / trash) shown
/// above the note list.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.type,
    required this.tag,
    required this.thread,
    required this.trash,
    required this.tags,
    required this.threads,
    required this.onTypeChanged,
    required this.onTagChanged,
    required this.onThreadChanged,
    required this.onTrashToggled,
    required this.onClearAll,
  });

  final NoteType? type;
  final String? tag;
  final String? thread;
  final bool trash;
  final List<Tag> tags;
  final List<NoteThread> threads;
  final ValueChanged<NoteType?> onTypeChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String?> onThreadChanged;
  final VoidCallback onTrashToggled;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hasActiveFilter =
        type != null || tag != null || thread != null || trash;

    // Full width: in a Column a bare scroll view shrinks to its chips and is
    // centred, which put the pills mid-pane in a wide window.
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            // "All" filter pill
            _FilterPill(
              label: l.filterAll,
              icon: Icons.all_inbox_rounded,
              selected: !hasActiveFilter,
              onTap: onClearAll,
            ),
            const SizedBox(width: 6),
            // Type filter dropdown menu
            NexPopupMenuButton<String>(
              key: const ValueKey('library-type-filter'),
              tooltip: l.type,
              initialValue: type?.name ?? '__all__',
              onSelected: (value) => onTypeChanged(
                value == '__all__' ? null : NoteType.values.byName(value),
              ),
              itemBuilder: (context) => [
                nexMenuItem<String>(value: '__all__', label: l.filterAllTypes),
                ...NoteType.values.map(
                  (v) => nexMenuItem<String>(
                    value: v.name,
                    icon: nexNoteTypeIcon(v.name),
                    label: noteTypeLabel(l, v),
                  ),
                ),
              ],
              child: _FilterPill(
                label: type == null ? l.type : noteTypeLabel(l, type!),
                icon: type == null
                    ? Icons.filter_list_rounded
                    : nexNoteTypeIcon(type!.name),
                selected: type != null,
                onClear: type != null ? () => onTypeChanged(null) : null,
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(width: 6),
              NexPopupMenuButton<String>(
                tooltip: l.tags,
                initialValue: tag ?? '__all__',
                onSelected: (value) =>
                    onTagChanged(value == '__all__' ? null : value),
                itemBuilder: (context) => [
                  nexMenuItem<String>(value: '__all__', label: l.filterAllTags),
                  ...tags.map(
                    (t) => PopupMenuItem<String>(
                      value: t.id,
                      child: Row(
                        children: [
                          if (t.color != null)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsetsDirectional.only(end: 8),
                              decoration: BoxDecoration(
                                color: nexParseTagColor(t.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              t.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                child: _FilterPill(
                  label: tag == null
                      ? l.tags
                      : (tags.where((t) => t.id == tag).firstOrNull?.name ??
                            l.tags),
                  icon: Icons.tag_rounded,
                  selected: tag != null,
                  onClear: tag != null ? () => onTagChanged(null) : null,
                ),
              ),
            ],
            if (threads.isNotEmpty) ...[
              const SizedBox(width: 6),
              NexPopupMenuButton<String>(
                tooltip: l.threads,
                initialValue: thread ?? '__all__',
                onSelected: (value) =>
                    onThreadChanged(value == '__all__' ? null : value),
                itemBuilder: (context) => [
                  nexMenuItem<String>(
                    value: '__all__',
                    label: l.filterAllThreads,
                  ),
                  ...threads.map(
                    (th) => nexMenuItem<String>(value: th.id, label: th.name),
                  ),
                ],
                child: _FilterPill(
                  label: thread == null
                      ? l.threads
                      : (threads
                                .where((th) => th.id == thread)
                                .firstOrNull
                                ?.name ??
                            l.threads),
                  icon: Icons.forum_outlined,
                  selected: thread != null,
                  onClear: thread != null ? () => onThreadChanged(null) : null,
                ),
              ),
            ],
            const SizedBox(width: 6),
            // Trash toggle
            _FilterPill(
              label: l.trash,
              icon: trash
                  ? Icons.restore_from_trash_outlined
                  : Icons.delete_outline_rounded,
              selected: trash,
              danger: trash,
              onTap: onTrashToggled,
            ),
            if (hasActiveFilter) ...[
              const SizedBox(width: 6),
              _FilterPill(
                label: l.clear,
                icon: Icons.filter_alt_off_rounded,
                selected: false,
                onTap: onClearAll,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single rounded filter pill with optional clear button.
class _FilterPill extends StatefulWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
    this.onClear,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool danger;

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = widget.selected;
    final danger = widget.danger;

    final bg = danger && selected
        ? scheme.errorContainer
        : selected
        ? scheme.primaryContainer
        : _hover
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLow;

    final fg = danger && selected
        ? scheme.onErrorContainer
        : selected
        ? scheme.onPrimaryContainer
        : _hover
        ? scheme.onSurface
        : scheme.onSurfaceVariant;

    final border = danger && selected
        ? Border.all(color: scheme.error.withValues(alpha: 0.5))
        : selected
        ? Border.all(color: scheme.primary.withValues(alpha: 0.5))
        : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: DesktopAction(
        label: widget.label,
        selected: widget.selected,
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 5),
              ExcludeSemantics(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              if (widget.onClear != null) ...[
                const SizedBox(width: 4),
                DesktopAction(
                  label: AppLocalizations.of(context)!.clearSelection,
                  excludeSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClear,
                  child: Icon(Icons.close, size: 13, color: fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Draggable two-pane divider with hover affordance.
class _SplitterHandle extends StatefulWidget {
  const _SplitterHandle();

  @override
  State<_SplitterHandle> createState() => _SplitterHandleState();
}

class _SplitterHandleState extends State<_SplitterHandle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 8,
        color: _hover
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.outlineVariant.withValues(alpha: 0.15),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _hover ? 3 : 2,
            height: 48,
            decoration: BoxDecoration(
              color: _hover ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
