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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../ui/widgets.dart';
import 'features_state.dart';
import 'note_copy.dart';
import 'notices.dart';
import 'note_detail_view.dart';
import 'reminder_picker.dart';
import 'reminder_policy.dart';
import 'shortcuts_dialog.dart';
import 'store.dart';
import 'tag_manager.dart';

part 'library_actions.dart';
part 'library_filter_widgets.dart';
part 'library_keys.dart';
part 'library_list_pane.dart';
part 'library_workspace.dart';

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
  Timer? _searchDebounce;
  int _libraryRevision = -1;
  double _paneWidth = 380.0;
  double _layoutWidth = 0;
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
    final features = NexScope.of(context);
    final requested = features.takeRequestedNote();
    if (requested != null) {
      _detailRelease?.call();
      _detailRelease = NexPanelScope.maybeOf(context)?.holdOpen(modal: false);
      selectedNote = requested;
      _selectedIds.clear();
    }
    final revision = features.libraryRevision;
    if (_libraryRevision != revision) {
      _libraryRevision = revision;
      load();
    }
  }

  void _queryChanged(String value) {
    _searchDebounce?.cancel();
    // Invalidate a request immediately, even while the next query waits.
    generation++;
    setState(() {
      loading = true;
      failure = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 150), () => load());
  }

  Future<void> load({bool append = false}) async {
    _searchDebounce?.cancel();
    final database = store;
    final token = ++generation;
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final rows = trash
          ? await database.call<List<Note>>('trash')
          : query.text.isNotEmpty ||
                type != null ||
                tag != null ||
                thread != null
          ? await database.call<List<Note>>('search', {
              'thread': thread,
              'filters': SearchFilters(
                query: query.text,
                types: type == null ? [] : [type!],
                tagIds: tag == null ? [] : [tag!],
              ),
            })
          : await database.call<List<Note>>('timeline', {
              'offset': append ? notes.length : 0,
            });
      if (!mounted || token != generation) return;
      final allTags = await database.call<List<Tag>>('tags');
      if (!mounted || token != generation) return;
      final allThreads = await database.call<List<NoteThread>>('threads');
      if (!mounted || token != generation) return;
      final outside = selectedNote;
      if (!append && outside != null && !rows.any((n) => n.id == outside.id)) {
        final current = await database.call<Note?>('get', {'id': outside.id});
        if (!mounted || token != generation) return;
        if (selectedNote?.id == outside.id) {
          selectedNote = current?.deletedAt == null ? current : null;
          if (selectedNote == null) {
            _detailRelease?.call();
            _detailRelease = null;
          }
        }
      }
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
          } else if (!append &&
              (query.text.isNotEmpty ||
                  type != null ||
                  tag != null ||
                  thread != null ||
                  trash)) {
            _detailRelease?.call();
            _detailRelease = null;
            selectedNote = null;
          }
        }
        if (!trash &&
            selectedNote == null &&
            _layoutWidth >= 900 &&
            notes.isNotEmpty) {
          selectedNote = notes.first;
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
    _searchDebounce?.cancel();
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

    // Card density (IDEAS.md): the user's compact/standard/readable choice
    // from Settings feeds every NoteCard below through the nex_ui scope.
    // No scope above (tests, embeds) keeps the standard density.
    final c = LiquidScope.maybePanelOf(context);
    return NexCardDensityScope(
      density: NexCardDensity.fromWire(c?.S.cardDensity),
      child: Focus(
        focusNode: _libraryFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _layoutWidth = constraints.maxWidth;
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
                    key: ValueKey(selectedNote!.id),
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
                        : const _LibraryReaderEmpty(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The composed state the library renders. Same library, so the mixins and
/// this class share every private member.
class _NexLibraryViewState = _LibraryStateBase
    with _LibraryActions, _LibraryKeys, _LibraryWorkspace, _LibraryListPane;
