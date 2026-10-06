// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the NexLibraryView split (see library_view.dart). Members below are
// spliced into the state class; do not import this file directly.
part of 'library_view.dart';

/// The list pane: selection banner, search field, filter bar, failure row,
/// empty states and the note card list with date dividers.
mixin _LibraryListPane on _LibraryStateBase {
  @override
  Widget _buildListPane(BuildContext context, AppLocalizations l, bool fa) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        if (_selectedIds.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.1),
                  offset: const Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: l.clearSelection,
                  onPressed: () => setState(() => _selectedIds.clear()),
                ),
                Text(
                  l.selectedCount(_selectedIds.length),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.push_pin_outlined, size: 20),
                  tooltip: l.pin,
                  onPressed: () async {
                    for (final id in _selectedIds) {
                      final n = notes.firstWhere(
                        (x) => x.id == id,
                        orElse: () => notes.first,
                      );
                      await store.call(n.pinnedAt == null ? 'pin' : 'unpin', {
                        'id': id,
                      });
                    }
                    setState(() => _selectedIds.clear());
                    await load();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: l.copy,
                  onPressed: () {
                    final sel = notes.where((n) => _selectedIds.contains(n.id));
                    final text = sel.map(noteCopyText).join('\n\n---\n\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l.copy)));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: l.delete,
                  onPressed: () async {
                    final idsToDelete = Set<String>.from(_selectedIds);
                    for (final id in idsToDelete) {
                      await store.call('delete', {'id': id});
                    }
                    setState(() {
                      _selectedIds.clear();
                      if (idsToDelete.contains(selectedNote?.id)) {
                        selectedNote = null;
                      }
                    });
                    await load();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.deleted),
                          action: SnackBarAction(
                            label: l.undo,
                            onPressed: () async {
                              for (final id in idsToDelete) {
                                await store.call('restore', {'id': id});
                              }
                              await load();
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Focus(
            onFocusChange: (focused) {
              final c = NexPanelScope.maybeOf(context);
              if (focused) {
                c?.focusGained();
              } else {
                c?.focusLost();
              }
            },
            child: TextField(
              controller: query,
              focusNode: _searchFocusNode,
              textDirection: nexDirectionOf(query.text),
              decoration: InputDecoration(
                hintText: l.search,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: query.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          query.clear();
                          load();
                        },
                      )
                    : Padding(
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: Center(
                          widthFactor: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Text(
                              'Ctrl+F',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              onChanged: (_) => load(),
            ),
          ),
        ),
        _FilterBar(
          type: type,
          tag: tag,
          thread: thread,
          trash: trash,
          tags: tags,
          threads: threads,
          onTypeChanged: (v) {
            type = v;
            load();
          },
          onTagChanged: (v) {
            tag = v;
            load();
          },
          onThreadChanged: (v) {
            thread = v;
            load();
          },
          onTrashToggled: () {
            trash = !trash;
            load();
          },
          onClearAll: () {
            query.clear();
            type = null;
            tag = thread = null;
            trash = false;
            load();
          },
          onShortcutsTap: () => showShortcutsDialog(context),
        ),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '${l.failed}: $failure',
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
        if (notes.isEmpty && !loading)
          Expanded(
            child: Center(
              child: NexEmptyState(
                icon: trash
                    ? Icons.delete_outline_rounded
                    : query.text.isNotEmpty
                    ? Icons.search_off_rounded
                    : (type != null || tag != null || thread != null)
                    ? Icons.filter_list_off_rounded
                    : Icons.note_alt_outlined,
                message: trash
                    ? '${l.trash}: ${l.empty}'
                    : query.text.isNotEmpty
                    ? '${l.search}: ${l.empty}'
                    : l.empty,
                action:
                    (query.text.isNotEmpty ||
                        type != null ||
                        tag != null ||
                        thread != null ||
                        trash)
                    ? TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(l.clear),
                        onPressed: () {
                          query.clear();
                          type = null;
                          tag = thread = null;
                          trash = false;
                          load();
                        },
                      )
                    : null,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
              itemCount: notes.length + (loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == notes.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final note = notes[index];
                final date = nexDisplayDate(
                  note.createdAt,
                  solar: fa,
                  persian: fa,
                );
                final prior = index == 0
                    ? null
                    : nexDisplayDate(
                        notes[index - 1].createdAt,
                        solar: fa,
                        persian: fa,
                      );
                final isCardSelected = _selectedIds.isNotEmpty
                    ? _selectedIds.contains(note.id)
                    : (selectedNote?.id == note.id);

                return Column(
                  children: [
                    if (date != prior)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
                        child: Row(
                          children: [
                            Text(
                              date,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                height: 1,
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: isCardSelected && _selectedIds.isEmpty
                            ? scheme.primary.withValues(alpha: 0.07)
                            : Colors.transparent,
                        border: Border.all(
                          color: isCardSelected && _selectedIds.isEmpty
                              ? scheme.primary.withValues(alpha: 0.35)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: GestureDetector(
                        onSecondaryTapDown: (details) =>
                            _showCardContextMenu(details.globalPosition, note),
                        child: NoteCard(
                          note: note,
                          showDue: true,
                          selected: isCardSelected,
                          strings: NexCardStrings(
                            noteOfType: (t) =>
                                '${l.note}: ${noteTypeLabel(l, NoteType.values.firstWhere((x) => x.name == t, orElse: () => NoteType.text))}',
                            tagList: (tags) => '${l.tags}: $tags',
                            accentColor: l.accent,
                            durationLabel: (ms) => nexDigits(
                              '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}',
                              persian: fa,
                            ),
                            relativeTime: (time) => switch (time.unit) {
                              NexRelativeUnit.now => l.justNow,
                              NexRelativeUnit.minutes => l.minutesAgo(
                                time.count,
                              ),
                              NexRelativeUnit.hours => l.hoursAgo(time.count),
                              NexRelativeUnit.days => l.daysAgo(time.count),
                              NexRelativeUnit.weeks => l.weeksAgo(time.count),
                              NexRelativeUnit.months => l.monthsAgo(time.count),
                              NexRelativeUnit.years => l.yearsAgo(time.count),
                            },
                            dueLabel: (due, repeat) {
                              final now = DateTime.now();
                              final isOverdue = due.isBefore(now);
                              final repeatText = switch (repeat) {
                                NoteRepeat.daily => ' (${l.repeatDaily})',
                                NoteRepeat.weekly => ' (${l.repeatWeekly})',
                                _ => '',
                              };
                              if (isOverdue && repeat == NoteRepeat.once) {
                                return l.overdue;
                              }
                              final timeStr =
                                  '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
                              final formattedTime = fa
                                  ? nexDigits(timeStr, persian: true)
                                  : timeStr;
                              final formattedDate = nexDisplayDate(
                                due,
                                solar: fa,
                                persian: fa,
                              );
                              return '$formattedDate $formattedTime$repeatText';
                            },
                          ),
                          onTap: () {
                            final isCtrl =
                                HardwareKeyboard.instance.isControlPressed;
                            final isShift =
                                HardwareKeyboard.instance.isShiftPressed;

                            if (isCtrl || isShift || _selectedIds.isNotEmpty) {
                              setState(() {
                                if (_selectedIds.contains(note.id)) {
                                  _selectedIds.remove(note.id);
                                } else {
                                  _selectedIds.add(note.id);
                                }
                              });
                            } else {
                              _detailRelease = NexPanelScope.maybeOf(
                                context,
                              )?.holdOpen();
                              setState(() => selectedNote = note);
                            }
                          },
                        ),
                      ),
                    ),
                    if (trash)
                      TextButton(
                        onPressed: () async {
                          await store.call<void>('restore', {'id': note.id});
                          await load();
                        },
                        child: Text(l.restore),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
