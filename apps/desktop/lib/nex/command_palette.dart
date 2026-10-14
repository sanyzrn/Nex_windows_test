// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Ctrl+K command palette (IDEAS.md).
///
/// One field that searches notes, jumps to any screen and runs the common
/// actions. Screens and actions match with Persian folding (ي→ی, ك→ک,
/// ZWNJ, Arabic digits), so "تنظیمات" finds the settings entry typed as
/// "tanẓimat" key neighbours and vice versa. Full-text note search is
/// delegated to the store's FTS index; results are re-ranked here with the
/// same fold so a folded needle still matches a stored title.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../core/controller.dart';
import '../l10n/app_localizations.dart';
import 'features_state.dart';

/// Normalises a string for palette matching: case-folded, Arabic/Persian
/// letter variants unified, zero-width joiners removed, digits mapped.
String nexFoldText(String s) {
  final buffer = StringBuffer();
  for (final ch in s.runes) {
    switch (ch) {
      case 0x0622 || 0x0623 || 0x0625: // آ أ إ -> ا
        buffer.writeCharCode(0x0627);
      case 0x0649 || 0x064A || 0x0626: // ى ي ئ -> ی
        buffer.writeCharCode(0x06CC);
      case 0x06A9 || 0x0643: // ك -> ک
        buffer.writeCharCode(0x06A9);
      case 0x0629: // ة -> ه
        buffer.writeCharCode(0x0647);
      case 0x0624: // ؤ -> و
        buffer.writeCharCode(0x0648);
      case 0x064B ||
          0x064C ||
          0x064D ||
          0x064E ||
          0x064F ||
          0x0650 ||
          0x0651 ||
          0x0652 ||
          0x200C ||
          0x200F ||
          0x200E:
        break; // diacritics, ZWNJ, marks: dropped
      case >= 0x0660 && <= 0x0669: // Arabic-Indic digits
        buffer.writeCharCode(0x30 + (ch - 0x0660));
      case >= 0x06F0 && <= 0x06F9: // Persian digits
        buffer.writeCharCode(0x30 + (ch - 0x06F0));
      default:
        buffer.writeCharCode(ch);
    }
  }
  return buffer.toString().toLowerCase().trim();
}

/// One row of the palette: a note, a screen to jump to, or an action.
class PaletteEntry {
  const PaletteEntry({
    required this.title,
    required this.icon,
    required this.run,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback run;
}

/// Opens the palette above the current surface.
Future<void> showCommandPalette(
  BuildContext context, {
  required PanelController controller,
  NexFeatures? features,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (context) =>
        _CommandPaletteDialog(controller: controller, features: features),
  );
}

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({required this.controller, this.features});

  final PanelController controller;
  final NexFeatures? features;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<Note> _noteHits = [];
  int _selected = 0;
  bool _searching = false;
  int _searchGeneration = 0;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchGeneration++;
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (_lastQuery == _query.text) return;
    _lastQuery = _query.text;
    _debounce?.cancel();
    final token = ++_searchGeneration;
    final q = _query.text.trim();
    setState(() {
      _selected = 0;
      _noteHits = [];
      _searching = q.isNotEmpty && widget.features != null;
    });
    if (!_searching) return;
    _debounce = Timer(
      const Duration(milliseconds: 150),
      () => _searchNotes(q, token),
    );
  }

  Future<void> _searchNotes(String q, int token) async {
    try {
      final hits = await widget.features!.store.call<List<Note>>('search', {
        'thread': null,
        'filters': SearchFilters(query: q),
      });
      if (!mounted || token != _searchGeneration) return;
      final folded = nexFoldText(q);
      hits.sort((a, b) {
        // Folded title matches first, then the store's own ranking order.
        final at = nexFoldText(a.displayText ?? '').contains(folded) ? 0 : 1;
        final bt = nexFoldText(b.displayText ?? '').contains(folded) ? 0 : 1;
        return at.compareTo(bt);
      });
      setState(() {
        _noteHits = hits.take(6).toList();
        _searching = false;
        _selected = 0;
      });
    } catch (_) {
      if (mounted && token == _searchGeneration) {
        setState(() => _searching = false);
      }
    }
  }

  List<PaletteEntry> _entries(AppLocalizations l) {
    final c = widget.controller;
    final q = nexFoldText(_query.text);
    bool match(String title) => q.isEmpty || nexFoldText(title).contains(q);

    final screens = <PaletteEntry>[
      if (match(l.capture))
        PaletteEntry(
          title: l.capture,
          icon: Icons.edit_note_rounded,
          run: () => c.isWindowMode
              ? c.selectWindowSection('capture')
              : c.show('note'),
        ),
      if (match(l.library))
        PaletteEntry(
          title: l.library,
          icon: Icons.auto_stories_outlined,
          run: () => c.isWindowMode
              ? c.selectWindowSection('library')
              : c.show('timeline'),
        ),
      if (match(l.tools))
        PaletteEntry(
          title: l.tools,
          icon: Icons.widgets_outlined,
          run: () =>
              c.isWindowMode ? c.selectWindowSection('tools') : c.show('more'),
        ),
      if (match(l.settings))
        PaletteEntry(
          title: l.settings,
          icon: Icons.settings_outlined,
          run: () => c.isWindowMode
              ? c.selectWindowSection('settings')
              : c.show('settings'),
        ),
    ];

    final actions = <PaletteEntry>[
      if (match(l.newNote))
        PaletteEntry(
          title: l.newNote,
          icon: Icons.add_rounded,
          run: () {
            unawaited(widget.features?.fresh());
            if (c.isWindowMode) {
              c.selectWindowSection('capture');
            } else {
              c.show('note');
            }
          },
        ),
      if (match(l.paletteActionToggleTheme))
        PaletteEntry(
          title: l.paletteActionToggleTheme,
          icon: Icons.brightness_6_outlined,
          run: () {
            c.S.theme = c.palette.isLight ? 'midnight' : 'light';
            c.save();
            c.refresh();
          },
        ),
      if (match(l.paletteOpen))
        PaletteEntry(
          title: l.paletteOpen,
          icon: Icons.keyboard_command_key_rounded,
          run: () {}, // already here; keeps the shortcut discoverable
        ),
    ];

    final notes = <PaletteEntry>[
      for (final n in _noteHits)
        PaletteEntry(
          title: n.displayText ?? '',
          subtitle: _noteKindLabel(l, n),
          icon: Icons.description_outlined,
          run: () {
            widget.features?.requestNote(n);
            if (c.isWindowMode) {
              c.selectWindowSection('library');
            } else {
              c.show('timeline');
            }
          },
        ),
    ];

    return [...screens, ...notes, ...actions];
  }

  String _noteKindLabel(AppLocalizations l, Note n) => switch (n.type) {
    NoteType.checklist => l.checklist,
    NoteType.link => l.link,
    _ => l.note,
  };

  void _runAt(List<PaletteEntry> entries, int index) {
    if (index < 0 || index >= entries.length) return;
    final entry = entries[index];
    Navigator.of(context).pop();
    entry.run();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final entries = _entries(l);
    final clamped = _selected.clamp(
      0,
      (entries.isEmpty ? 0 : entries.length - 1),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => setState(
          () => _selected = (_selected + 1).clamp(
            0,
            (entries.isEmpty ? 0 : entries.length - 1),
          ),
        ),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => setState(
          () => _selected = (_selected - 1).clamp(
            0,
            (entries.isEmpty ? 0 : entries.length - 1),
          ),
        ),
        const SingleActivator(LogicalKeyboardKey.enter): () =>
            _runAt(entries, clamped),
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          title: TextField(
            controller: _query,
            focusNode: _focus,
            autofocus: true,
            textDirection: nexDirectionOf(_query.text),
            decoration: InputDecoration(
              hintText: l.paletteSearchHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_query.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _query.clear();
                              _focus.requestFocus();
                            },
                          )
                        : Padding(
                            padding: const EdgeInsetsDirectional.only(end: 10),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                'Ctrl+K',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
          content: SizedBox(
            width: 460,
            height: 320,
            child: entries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        l.paletteNoResults,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      final isSel = index == clamped;
                      return ListTile(
                        leading: Icon(
                          e.icon,
                          size: 20,
                          color: isSel
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        title: Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSel
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: e.subtitle == null
                            ? null
                            : Text(
                                e.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        tileColor: isSel
                            ? scheme.primary.withValues(alpha: 0.08)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onTap: () => _runAt(entries, index),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
