part of 'library_view.dart';

mixin _LibraryWorkspace on _LibraryStateBase {
  /// True while any filter (search, type, tag, thread, trash) is active —
  /// decides between the filtered-empty state and the first-run design.
  bool get _isFilteredEmpty =>
      query.text.isNotEmpty ||
      type != null ||
      tag != null ||
      thread != null ||
      trash;

  /// Whether [n]'s reminder still needs attention today (due later today,
  /// already overdue, or a recurring item whose turn has come round).
  ///
  /// [now] and [endOfToday] are passed in: the strip asks this once per note
  /// per build, and calling DateTime.now() inside meant a fresh clock read
  /// per note on a list that grows with every scrolled page.
  bool _dueToday(Note n, DateTime now, DateTime endOfToday) {
    final due = n.dueAt == null ? null : _effectiveDue(n);
    if (due == null) return false;
    return due.isBefore(endOfToday);
  }

  /// A tear-off of [_dueToday] for `notes.any` at build time: one clock read,
  /// one end-of-day bound, then the same predicate over every note.
  bool _isDueToday(Note n) {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _dueToday(n, now, endOfToday);
  }

  DateTime _effectiveDue(Note n) =>
      nextReminderOccurrence(n.dueAt!, n.dueRepeat, DateTime.now()).toLocal();

  /// Today strip (IDEAS.md): due and overdue reminders at the top of the
  /// timeline, matching Android's overdue language. Tapping a chip opens
  /// the note.
  Widget _buildTodayStrip(BuildContext context, AppLocalizations l, bool fa) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final due = notes.where((n) => _dueToday(n, now, endOfToday)).toList()
      ..sort((a, b) => _effectiveDue(a).compareTo(_effectiveDue(b)));
    final overdue = due.where((n) => _effectiveDue(n).isBefore(now)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today_rounded, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                l.todayTitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                overdue > 0 ? l.overdueCount(overdue) : l.dueCount(due.length),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: overdue > 0 ? scheme.error : scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: due.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final n = due[index];
                final isOverdue = _effectiveDue(n).isBefore(now);
                return ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isOverdue
                      ? scheme.errorContainer.withValues(alpha: 0.55)
                      : scheme.secondaryContainer.withValues(alpha: 0.55),
                  side: BorderSide(
                    color: isOverdue
                        ? scheme.error.withValues(alpha: 0.4)
                        : scheme.outlineVariant,
                  ),
                  avatar: Icon(
                    isOverdue ? Icons.alarm_rounded : Icons.schedule_rounded,
                    size: 14,
                    color: isOverdue ? scheme.error : scheme.primary,
                  ),
                  label: Text(
                    _todayChipLabel(n, fa),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? scheme.onErrorContainer
                          : scheme.onSecondaryContainer,
                    ),
                  ),
                  onPressed: () => setState(() => selectedNote = n),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _todayChipLabel(Note n, bool fa) {
    final text = (n.title?.isNotEmpty == true ? n.title : n.displayText) ?? '';
    final compact = text.replaceAll('\n', ' ').trim();
    final due = _effectiveDue(n);
    final time =
        '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
    final stamped = fa ? nexDigits(time, persian: true) : time;
    final body = compact.isEmpty ? stamped : '$stamped · $compact';
    return body.length <= 42 ? body : '${body.substring(0, 42)}…';
  }

  /// The designed empty library (IDEAS.md): a calm first run with three
  /// concrete next steps, both languages.
  Widget _buildFirstRunEmpty(BuildContext context, AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    final c = LiquidScope.maybePanelOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.note_alt_outlined,
              size: 48,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.emptyLibraryTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            l.emptyLibraryHint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: c == null
                ? null
                : () => c.isWindowMode
                      ? c.selectWindowSection('capture')
                      : c.show('note'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l.emptyLibraryWrite),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: c == null
                ? null
                : () => c.isWindowMode
                      ? c.selectWindowSection('tools')
                      : c.show('more'),
            icon: const Icon(Icons.widgets_outlined, size: 18),
            label: Text(l.emptyLibraryTools),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => showShortcutsDialog(context),
            icon: const Icon(Icons.keyboard_outlined, size: 18),
            label: Text(l.emptyLibraryShortcuts),
          ),
        ],
      ),
    );
  }
}

class _LibraryReaderEmpty extends StatelessWidget {
  const _LibraryReaderEmpty();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerLowest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 28),
            Text(
              l.workspaceReaderTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(l.noNoteSelected, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              l.workspaceReaderHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
