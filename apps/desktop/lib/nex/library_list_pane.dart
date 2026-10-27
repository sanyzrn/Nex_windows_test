// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the NexLibraryView split (see library_view.dart). Members below are
// spliced into the state class; do not import this file directly.
part of 'library_view.dart';

/// The list pane: selection banner, search field, filter bar, failure row,
/// the Today strip, empty states and the note card list with date dividers.
mixin _LibraryListPane on _LibraryStateBase, _LibraryWorkspace {
  @override
  Widget _buildListPane(BuildContext context, AppLocalizations l, bool fa) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chosen = notes.where((n) => _selectedIds.contains(n.id)).toList();
    final unpinChosen =
        chosen.isNotEmpty && chosen.every((n) => n.pinnedAt != null);

    return Column(
      children: [
        if (_selectedIds.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            // Compact 34px buttons and a flexible count: the pane can be
            // clamped to 280px, and full 48px IconButtons (four of them, plus
            // the count, plus the spacer) overflowed it.
            child: Row(
              children: [
                _BannerIcon(
                  icon: Icons.close_rounded,
                  tooltip: l.clearSelection,
                  color: scheme.onPrimaryContainer,
                  onPressed: () => setState(() => _selectedIds.clear()),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    desktopDigits(
                      context,
                      l.selectedCount(_selectedIds.length),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                _BannerIcon(
                  icon: Icons.push_pin_outlined,
                  tooltip: unpinChosen ? l.unpin : l.pin,
                  color: scheme.onPrimaryContainer,
                  onPressed: () async {
                    final features = NexScope.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    var limitReached = false;
                    await features.guard(() async {
                      for (final n in chosen) {
                        if (unpinChosen) {
                          await features.store.call<void>('unpin', {
                            'id': n.id,
                          });
                        } else if (n.pinnedAt == null) {
                          final pinned = await features.store.call<bool>(
                            'pin',
                            {'id': n.id},
                          );
                          if (!pinned) {
                            limitReached = true;
                            break;
                          }
                        }
                      }
                    });
                    if (!mounted) return;
                    setState(() => _selectedIds.clear());
                    await load();
                    if (mounted && limitReached) {
                      showNexNotice(messenger, l.pinLimitReached);
                    }
                  },
                ),
                _BannerIcon(
                  icon: Icons.copy_rounded,
                  tooltip: l.copy,
                  color: scheme.onPrimaryContainer,
                  onPressed: () {
                    final sel = notes.where((n) => _selectedIds.contains(n.id));
                    final text = sel.map(noteCopyText).join('\n\n---\n\n');
                    Clipboard.setData(ClipboardData(text: text));
                    showNexNotice(ScaffoldMessenger.of(context), l.copy);
                  },
                ),
                _BannerIcon(
                  icon: Icons.archive_outlined,
                  tooltip: l.setAside,
                  color: scheme.onPrimaryContainer,
                  onPressed: () async {
                    await setDesktopNotesAside(context, chosen);
                    if (!mounted) return;
                    setState(() => _selectedIds.clear());
                    await load();
                  },
                ),
                _BannerIcon(
                  icon: Icons.delete_outline_rounded,
                  tooltip: l.delete,
                  color: scheme.onPrimaryContainer,
                  onPressed: () async {
                    final features = NexScope.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final idsToDelete = Set<String>.from(_selectedIds);
                    await features.guard(() async {
                      for (final id in idsToDelete) {
                        await features.store.call('delete', {'id': id});
                      }
                      if (idsToDelete.contains(features.session.id)) {
                        await features.fresh();
                      }
                    });
                    if (!mounted) return;
                    setState(() {
                      _selectedIds.clear();
                      if (idsToDelete.contains(selectedNote?.id)) {
                        selectedNote = null;
                      }
                    });
                    await load();
                    if (context.mounted) {
                      showNexNotice(
                        messenger,
                        l.deleted,
                        action: SnackBarAction(
                          label: l.undo,
                          onPressed: () async {
                            await features.guard(() async {
                              for (final id in idsToDelete) {
                                await features.store.call('restore', {
                                  'id': id,
                                });
                              }
                            });
                            if (mounted) await load();
                          },
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 4),
          child: LayoutBuilder(
            builder: (context, box) {
              final scaledWidth =
                  box.maxWidth / MediaQuery.textScalerOf(context).scale(1);
              final stacked = scaledWidth < 320;
              // The Ctrl+F hint is a nicety: below ~480 px it squeezes the
              // field's own hint text, so it gives way first.
              final showHint = scaledWidth >= 480;
              final search = Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onFocusChange: (focused) {
                  final c = NexPanelScope.maybeOf(context);
                  if (focused) {
                    c?.focusGained();
                  } else {
                    c?.focusLost();
                  }
                },
                child: DesktopEditingDirection(
                  controller: query,
                  multiline: false,
                  builder: (context, direction) => TextField(
                    key: const ValueKey('library-search'),
                    controller: query,
                    focusNode: _searchFocusNode,
                    textDirection: direction,
                    decoration: InputDecoration(
                      hintText: l.search,
                      hintMaxLines: stacked ? 3 : 1,
                      isDense: true,
                      // A soft rounded field, not a capsule: it sits beside a
                      // row of small controls and should weigh no more than
                      // them.
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: scheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: scheme.primary,
                          width: nexFocusRingWidth,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: query.text.isNotEmpty
                          ? IconButton(
                              tooltip: l.clearSearch,
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                query.clear();
                                load();
                              },
                            )
                          : stacked || !showHint
                          ? null
                          : Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: 10,
                              ),
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
                                    ShortcutLabels.search,
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
                    onChanged: _queryChanged,
                  ),
                ),
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('library-locations'),
                    tooltip: l.libraryTitle,
                    onPressed: _openLibraryLocations,
                    icon: const Icon(Icons.folder_copy_outlined),
                  ),
                  if (NexPanelScope.maybeOf(context)?.isWindowMode ?? true) ...[
                    IconButton(
                      tooltip: AiStrings.of(context).t('board'),
                      isSelected: board,
                      onPressed: () => setState(() => board = true),
                      icon: const Icon(Icons.grid_view_outlined),
                    ),
                    IconButton(
                      tooltip: AiStrings.of(context).t('list'),
                      isSelected: !board,
                      onPressed: () => setState(() => board = false),
                      icon: const Icon(Icons.view_agenda_outlined),
                    ),
                  ],
                  IconButton.filledTonal(
                    key: const ValueKey('manage-tags'),
                    tooltip: l.manageTags,
                    icon: const Icon(Icons.sell_outlined, size: 18),
                    onPressed: () async {
                      await showTagManager(context, NexScope.of(context));
                      if (!mounted) return;
                      final all = await store.call<List<Tag>>('tags');
                      if (!mounted) return;
                      if (tag != null && !all.any((t) => t.id == tag)) {
                        tag = null;
                      }
                      await load();
                    },
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: NexSpacing.xs),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: actions,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 4),
                  actions,
                ],
              );
            },
          ),
        ),
        _FilterBar(
          type: type,
          tag: tag,
          thread: thread,
          datePreset: datePreset,
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
          onDateChanged: (v) {
            datePreset = v;
            load();
          },
          onTrashToggled: () {
            _detailRelease?.call();
            _detailRelease = null;
            setState(() {
              trash = !trash;
              datePreset = LibraryDatePreset.any;
              selectedNote = null;
              _selectedIds.clear();
            });
            load();
          },
          onClearAll: () {
            query.clear();
            type = null;
            tag = thread = null;
            datePreset = LibraryDatePreset.any;
            trash = false;
            load();
          },
        ),
        if (!trash && notes.any(_isDueToday)) _buildTodayStrip(context, l, fa),
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
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                primary: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(NexSpacing.sm),
                    child: _isFilteredEmpty
                        ? Center(
                            child: NexEmptyState(
                              icon: trash
                                  ? Icons.delete_outline_rounded
                                  : query.text.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : Icons.filter_list_off_rounded,
                              message: trash
                                  ? '${l.trash}: ${l.empty}'
                                  : query.text.isNotEmpty
                                  ? '${l.search}: ${l.empty}'
                                  : l.empty,
                              action: TextButton.icon(
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: Text(l.clear),
                                onPressed: () {
                                  query.clear();
                                  type = null;
                                  tag = thread = null;
                                  datePreset = LibraryDatePreset.any;
                                  trash = false;
                                  load();
                                },
                              ),
                            ),
                          )
                        // Designed first-run state (IDEAS.md): three concrete
                        // actions instead of a bare "empty" line.
                        : _buildFirstRunEmpty(context, l),
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final grid = board && !trash && box.maxWidth >= 640;
                Widget itemBuilder(BuildContext context, int index) {
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
                    solar:
                        NexPanelScope.maybeOf(context)?.S.solarCalendar ?? fa,
                    persian: fa,
                  );
                  final prior = index == 0
                      ? null
                      : nexDisplayDate(
                          notes[index - 1].createdAt,
                          solar:
                              NexPanelScope.maybeOf(context)?.S.solarCalendar ??
                              fa,
                          persian: fa,
                        );
                  final isCardSelected = _selectedIds.isNotEmpty
                      ? _selectedIds.contains(note.id)
                      : (selectedNote?.id == note.id);

                  return Column(
                    children: [
                      if (!grid && date != prior)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
                          child: Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(
                                    NexRadius.lg,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    date,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary,
                                    ),
                                  ),
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
                      Padding(
                        padding: EdgeInsets.zero,
                        child: GestureDetector(
                          onSecondaryTapDown: trash
                              ? null
                              : (details) => _showCardContextMenu(
                                  details.globalPosition,
                                  note,
                                ),
                          child: NoteCard(
                            board: grid,
                            active: isCardSelected && _selectedIds.isEmpty,
                            note: trash
                                ? note.copyWith(clearPinnedAt: true)
                                : note,
                            showDue:
                                !trash &&
                                NexScope.of(
                                  context,
                                ).reminderNeedsAttention(note),
                            onChecklistToggle: trash
                                ? null
                                : (itemIndex) async {
                                    await NexScope.of(context).guard(
                                      () => store.call<void>('check', {
                                        'id': note.id,
                                        'index': itemIndex,
                                      }),
                                    );
                                    if (mounted) await load();
                                  },
                            selected: _selectedIds.isNotEmpty
                                ? isCardSelected
                                : null,
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
                                NexRelativeUnit.minutes => desktopDigits(
                                  context,
                                  l.minutesAgo(time.count),
                                ),
                                NexRelativeUnit.hours => desktopDigits(
                                  context,
                                  l.hoursAgo(time.count),
                                ),
                                NexRelativeUnit.days => desktopDigits(
                                  context,
                                  l.daysAgo(time.count),
                                ),
                                NexRelativeUnit.weeks => desktopDigits(
                                  context,
                                  l.weeksAgo(time.count),
                                ),
                                NexRelativeUnit.months => desktopDigits(
                                  context,
                                  l.monthsAgo(time.count),
                                ),
                                NexRelativeUnit.years => desktopDigits(
                                  context,
                                  l.yearsAgo(time.count),
                                ),
                              },
                              dueLabel: (due, repeat) {
                                due = nextReminderOccurrence(
                                  due,
                                  repeat,
                                  DateTime.now(),
                                ).toLocal();
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
                                  solar:
                                      NexPanelScope.maybeOf(
                                        context,
                                      )?.S.solarCalendar ??
                                      fa,
                                  persian: fa,
                                );
                                return '$formattedDate $formattedTime$repeatText';
                              },
                            ),
                            onTap: trash
                                ? null
                                : () {
                                    final isCtrl = HardwareKeyboard
                                        .instance
                                        .isControlPressed;
                                    final isShift = HardwareKeyboard
                                        .instance
                                        .isShiftPressed;

                                    if (isCtrl ||
                                        isShift ||
                                        _selectedIds.isNotEmpty) {
                                      setState(() {
                                        if (_selectedIds.contains(note.id)) {
                                          _selectedIds.remove(note.id);
                                        } else {
                                          _selectedIds.add(note.id);
                                        }
                                      });
                                    } else {
                                      _detailRelease?.call();
                                      _detailRelease = NexPanelScope.maybeOf(
                                        context,
                                      )?.holdOpen(modal: false);
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
                            if (mounted) await load();
                          },
                          child: Text(l.restore),
                        ),
                    ],
                  );
                }

                if (grid) {
                  final pinned = [
                    for (var i = 0; i < notes.length; i++)
                      if (notes[i].pinnedAt != null) i,
                  ];
                  final rest = [
                    for (var i = 0; i < notes.length; i++)
                      if (notes[i].pinnedAt == null) i,
                  ];
                  final delegate = SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: (box.maxWidth / 270).floor().clamp(2, 5),
                    mainAxisExtent: nexBoardCardHeight(context),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  );
                  List<Widget> section(
                    String label,
                    List<int> indices,
                    IconData icon,
                  ) => indices.isEmpty
                      ? []
                      : [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: 12,
                                top: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    icon,
                                    size: 15,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    label,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Divider(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: 22),
                            sliver: SliverGrid.builder(
                              gridDelegate: delegate,
                              itemCount: indices.length,
                              itemBuilder: (context, i) =>
                                  itemBuilder(context, indices[i]),
                            ),
                          ),
                        ];
                  return CustomScrollView(
                    controller: scroll,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            ...section(
                              l.workspacePinned,
                              pinned,
                              Icons.push_pin_outlined,
                            ),
                            ...section(
                              AiStrings.of(context).t('gallery'),
                              rest,
                              Icons.palette_outlined,
                            ),
                            if (loading)
                              const SliverToBoxAdapter(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                  itemCount: notes.length + (loading ? 1 : 0),
                  itemBuilder: itemBuilder,
                );
              },
            ),
          ),
      ],
    );
  }
}

/// A compact 34px square action for the selection banner. The banner sits in
/// a pane the user can clamp to 280px, so its controls give up the 48px
/// touch default for a pointer-sized target with the same tooltip and
/// keyboard focus every other control keeps.
class _BannerIcon extends StatelessWidget {
  const _BannerIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 17),
      tooltip: tooltip,
      color: color,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(34, 34),
        maximumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    );
  }
}
