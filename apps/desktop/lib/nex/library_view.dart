// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Library timeline, search, tag/thread filters, and note card listing.
/// Owns [NexLibraryView], 2-pane responsive layout, shortcuts and multi-select.
///
/// Split across part files of this library (same private members):
/// library_actions.dart, library_keys.dart, library_list_pane.dart and
/// library_filter_widgets.dart.
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

part 'library_actions.dart';
part 'library_filter_widgets.dart';
part 'library_keys.dart';
part 'library_list_pane.dart';

class NexLibraryView extends StatefulWidget {
  const NexLibraryView({super.key});
  @override
  State<NexLibraryView> createState() => _NexLibraryViewState();
}

abstract class _LibraryStateBase extends State<NexLibraryView> {
  // Cross-mixin members, implemented in the part files of this library;
  // declared here so the base build and sibling mixins can call them.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event);
  Widget _buildListPane(BuildContext context, AppLocalizations l, bool fa);
  Future<void> _deleteNote(Note note);
  Future<void> _undoLastDelete();
  void _showCardContextMenu(Offset globalPosition, Note note);

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
    SharedPreferences.getInstance()
        .then((prefs) {
          final saved = prefs.getDouble('nex_library_pane_width');
          if (saved != null && mounted) {
            setState(() => _paneWidth = saved);
          }
        })
        .catchError((_) {});
  }

  void _persistPaneWidth(double width) {
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setDouble('nex_library_pane_width', width);
        })
        .catchError((_) {});
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
                      final delta = isRtl
                          ? -details.delta.dx
                          : details.delta.dx;
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l.noNoteSelected,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l.noNoteSelectedHint,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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

/// The composed state the library renders. Same library, so the mixins and
/// this class share every private member.
class _NexLibraryViewState = _LibraryStateBase
    with _LibraryActions, _LibraryKeys, _LibraryListPane;
