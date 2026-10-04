// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Library timeline, search, tag/thread filters, and note card listing.
/// Owns [NexLibraryView], 2-pane responsive layout, shortcuts and multi-select.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'features_state.dart';
import 'note_copy.dart';
import 'note_detail_view.dart';
import 'reminder_picker.dart';
import 'shortcuts_dialog.dart';
import 'store.dart';

class NexLibraryView extends StatefulWidget {
  const NexLibraryView({super.key});
  @override
  State<NexLibraryView> createState() => _NexLibraryViewState();
}

class _NexLibraryViewState extends State<NexLibraryView> {
  final query = TextEditingController();
  final scroll = ScrollController();
  final _searchFocusNode = FocusNode();
  final _libraryFocusNode = FocusNode();

  List<Note> notes = [];
  List<Tag> tags = [];
  List<NoteThread> threads = [];
  final Set<String> _selectedIds = {};
  NoteType? type;
  String? tag;
  String? thread;
  String? failure;
  bool trash = false, loading = false, more = true;
  Note? selectedNote;
  VoidCallback? _detailRelease;
  int generation = 0;
  int _libraryRevision = -1;
  double _paneWidth = 380.0;
  String? _lastDeletedId;

  DesktopStore get store => NexScope.of(context).store;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 150 && more && !loading) {
        load(append: true);
      }
    });
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getDouble('nex_library_pane_width');
      if (saved != null && mounted) {
        setState(() => _paneWidth = saved);
      }
    }).catchError((_) {});
  }

  void _persistPaneWidth(double width) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble('nex_library_pane_width', width);
    }).catchError((_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = NexScope.of(context).libraryRevision;
    if (_libraryRevision != revision) {
      _libraryRevision = revision;
      load();
    }
  }

  Future<void> load({bool append = false}) async {
    final token = ++generation;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final rows = trash
          ? await store.call<List<Note>>('trash')
          : query.text.isNotEmpty ||
                type != null ||
                tag != null ||
                thread != null
          ? await store.call<List<Note>>('search', {
              'thread': thread,
              'filters': SearchFilters(
                query: query.text,
                types: type == null ? [] : [type!],
                tagIds: tag == null ? [] : [tag!],
              ),
            })
          : await store.call<List<Note>>('timeline', {
              'offset': append ? notes.length : 0,
            });
      final allTags = await store.call<List<Tag>>('tags');
      final allThreads = await store.call<List<NoteThread>>('threads');
      if (!mounted || token != generation) return;
      setState(() {
        notes = append ? [...notes, ...rows] : rows;
        tags = allTags;
        threads = allThreads;
        more =
            !trash &&
            thread == null &&
            query.text.isEmpty &&
            type == null &&
            tag == null &&
            rows.length == 50;
        loading = false;
        if (selectedNote != null) {
          final idx = notes.indexWhere((n) => n.id == selectedNote!.id);
          if (idx >= 0) {
            selectedNote = notes[idx];
          }
        }
      });
    } catch (e) {
      if (mounted && token == generation) {
        setState(() {
          loading = false;
          failure = e.toString();
        });
      }
    }
  }

  void _moveSelection(int delta) {
    if (notes.isEmpty) return;
    int currentIndex = selectedNote == null
        ? -1
        : notes.indexWhere((n) => n.id == selectedNote!.id);
    int nextIndex = (currentIndex + delta).clamp(0, notes.length - 1);
    setState(() {
      selectedNote = notes[nextIndex];
    });
  }

  Future<void> _deleteNote(Note note) async {
    final id = note.id;
    _lastDeletedId = id;
    await store.call('delete', {'id': id});
    setState(() {
      if (selectedNote?.id == id) selectedNote = null;
      _selectedIds.remove(id);
    });
    await load();
    if (mounted) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.deleted),
          action: SnackBarAction(
            label: l.undo,
            onPressed: _undoLastDelete,
          ),
        ),
      );
    }
  }

  Future<void> _undoLastDelete() async {
    if (_lastDeletedId == null) return;
    final id = _lastDeletedId!;
    _lastDeletedId = null;
    await store.call('restore', {'id': id});
    await load();
  }

  void _showCardContextMenu(
    Offset globalPosition,
    Note note,
  ) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              const Icon(Icons.open_in_new, size: 18),
              const SizedBox(width: 8),
              Text(l.readNote),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              const Icon(Icons.push_pin_outlined, size: 18),
              const SizedBox(width: 8),
              Text(note.pinnedAt == null ? l.pin : l.unpin),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy_rounded, size: 18),
              const SizedBox(width: 8),
              Text(l.copy),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'remind',
          child: Row(
            children: [
              const Icon(Icons.alarm_add_outlined, size: 18),
              const SizedBox(width: 8),
              Text(l.remind),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(l.delete, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );

    if (result == null || !mounted) return;
    switch (result) {
      case 'open':
        setState(() => selectedNote = note);
      case 'pin':
        await store.call(note.pinnedAt == null ? 'pin' : 'unpin', {'id': note.id});
        await load();
      case 'copy':
        Clipboard.setData(ClipboardData(text: noteCopyText(note)));
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l.copy)),
        );
      case 'remind':
        if (!mounted) return;
        await showReminderPicker(
          context,
          note: note,
          onSave: (dueAt, repeat) async {
            await store.call('remind', {
              'id': note.id,
              'at': dueAt,
              'repeat': repeat.wireName,
            });
            await load();
          },
        );
      case 'delete':
        await _deleteNote(note);
    }
  }

  @override
  void dispose() {
    _detailRelease?.call();
    generation++;
    query.dispose();
    scroll.dispose();
    _searchFocusNode.dispose();
    _libraryFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    if (event.logicalKey == LogicalKeyboardKey.f1 ||
        (isCtrl && event.logicalKey == LogicalKeyboardKey.slash)) {
      showShortcutsDialog(context);
      return KeyEventResult.handled;
    }

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      _searchFocusNode.requestFocus();
      query.selection =
          TextSelection(baseOffset: 0, extentOffset: query.text.length);
      return KeyEventResult.handled;
    }

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      _undoLastDelete();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (selectedNote != null) {
        _detailRelease?.call();
        _detailRelease = null;
        setState(() => selectedNote = null);
        return KeyEventResult.handled;
      }
      if (query.text.isNotEmpty) {
        query.clear();
        load();
        return KeyEventResult.handled;
      }
      if (_selectedIds.isNotEmpty) {
        setState(() => _selectedIds.clear());
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.delete && selectedNote != null) {
      _deleteNote(selectedNote!);
      return KeyEventResult.handled;
    }

    if (isCtrl &&
        event.logicalKey == LogicalKeyboardKey.keyP &&
        selectedNote != null) {
      store.call(
        selectedNote!.pinnedAt == null ? 'pin' : 'unpin',
        {'id': selectedNote!.id},
      ).then((_) => load());
      return KeyEventResult.handled;
    }

    if (isCtrl &&
        event.logicalKey == LogicalKeyboardKey.keyC &&
        selectedNote != null) {
      Clipboard.setData(ClipboardData(text: noteCopyText(selectedNote!)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.copy)),
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

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
                      await store.call(
                        n.pinnedAt == null ? 'pin' : 'unpin',
                        {'id': id},
                      );
                    }
                    setState(() => _selectedIds.clear());
                    await load();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: l.copy,
                  onPressed: () {
                    final sel =
                        notes.where((n) => _selectedIds.contains(n.id));
                    final text = sel.map(noteCopyText).join('\n\n---\n\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.copy)),
                    );
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
                action: (query.text.isNotEmpty ||
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
                        onSecondaryTapDown: (details) => _showCardContextMenu(
                          details.globalPosition,
                          note,
                        ),
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
                              NexRelativeUnit.minutes => l.minutesAgo(time.count),
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
                              final formattedTime =
                                  fa ? nexDigits(timeStr, persian: true) : timeStr;
                              final formattedDate =
                                  nexDisplayDate(due, solar: fa, persian: fa);
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
                              _detailRelease =
                                  NexPanelScope.maybeOf(context)?.holdOpen();
                              setState(() => selectedNote = note);
                            }
                          },
                        ),
                      ),
                    ),
                    if (trash)
                      TextButton(
                        onPressed: () async {
                          await store.call<void>('restore', {
                            'id': note.id,
                          });
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fa = Localizations.localeOf(context).languageCode == 'fa';

    return Focus(
      focusNode: _libraryFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTwoPane = constraints.maxWidth >= 900.0;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 530.0;

          if (!isTwoPane) {
            // Single-pane mode: if note selected, show detail view; otherwise list
            if (selectedNote != null) {
              return SizedBox(
                height: height,
                child: NexNoteDetail(
                  note: selectedNote!,
                  onClose: () {
                    _detailRelease?.call();
                    _detailRelease = null;
                    setState(() => selectedNote = null);
                    load();
                  },
                ),
              );
            }
            return SizedBox(
              height: height,
              child: _buildListPane(context, l, fa),
            );
          }

          // Two-pane mode: list pane on one side, detail pane on the other
          final clampedWidth = _paneWidth.clamp(
            280.0,
            constraints.maxWidth - 360.0,
          );

          return SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: clampedWidth,
                  child: _buildListPane(context, l, fa),
                ),
                // Draggable vertical divider
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      final isRtl =
                          Directionality.of(context) == TextDirection.rtl;
                      final delta =
                          isRtl ? -details.delta.dx : details.delta.dx;
                      final newWidth = (_paneWidth + delta).clamp(
                        280.0,
                        constraints.maxWidth - 360.0,
                      );
                      setState(() => _paneWidth = newWidth);
                      _persistPaneWidth(newWidth);
                    },
                    child: const _SplitterHandle(),
                  ),
                ),
                // Right pane: reader or editor
                Expanded(
                  child: selectedNote != null
                      ? NexNoteDetail(
                          key: ValueKey(selectedNote!.id),
                          note: selectedNote!,
                          onClose: () {
                            _detailRelease?.call();
                            _detailRelease = null;
                            setState(() => selectedNote = null);
                            load();
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.article_outlined,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l.noNoteSelected,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                fa
                                    ? 'برای پیمایش از کلیدهای جهت‌نما و برای یادداشت جدید از Ctrl+N استفاده کنید'
                                    : 'Use ↑ / ↓ to navigate notes, or Ctrl+N to create',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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
    required this.onShortcutsTap,
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
  final VoidCallback onShortcutsTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final hasActiveFilter =
        type != null || tag != null || thread != null || trash;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // "All" filter pill
          _FilterPill(
            label: fa ? 'همه' : 'All',
            icon: Icons.all_inbox_rounded,
            selected: !hasActiveFilter,
            onTap: onClearAll,
          ),
          const SizedBox(width: 6),
          // Type filter dropdown menu
          PopupMenuButton<NoteType?>(
            tooltip: l.type,
            initialValue: type,
            onSelected: onTypeChanged,
            itemBuilder: (context) => [
              PopupMenuItem<NoteType?>(
                value: null,
                child: Text(fa ? 'همه انواع' : 'All types'),
              ),
              ...NoteType.values.map(
                (v) => PopupMenuItem<NoteType?>(
                  value: v,
                  child: Row(
                    children: [
                      Icon(nexNoteTypeIcon(v.name), size: 18),
                      const SizedBox(width: 8),
                      Text(noteTypeLabel(l, v)),
                    ],
                  ),
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
            PopupMenuButton<String?>(
              tooltip: l.tags,
              initialValue: tag,
              onSelected: onTagChanged,
              itemBuilder: (context) => [
                PopupMenuItem<String?>(
                  value: null,
                  child: Text(fa ? 'همه برچسب‌ها' : 'All tags'),
                ),
                ...tags.map(
                  (t) => PopupMenuItem<String?>(
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
                        Text(t.name),
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
            PopupMenuButton<String?>(
              tooltip: l.threads,
              initialValue: thread,
              onSelected: onThreadChanged,
              itemBuilder: (context) => [
                PopupMenuItem<String?>(
                  value: null,
                  child: Text(fa ? 'همه رشته‌ها' : 'All threads'),
                ),
                ...threads.map(
                  (th) => PopupMenuItem<String?>(
                    value: th.id,
                    child: Text(th.name),
                  ),
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
          const SizedBox(width: 6),
          IconButton(
            tooltip: '${l.keyboardShortcuts} (F1)',
            icon: const Icon(Icons.keyboard_outlined, size: 18),
            onPressed: onShortcutsTap,
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              maximumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

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
      child: GestureDetector(
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
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
              if (widget.onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
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
