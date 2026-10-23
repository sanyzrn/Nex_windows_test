// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the NexLibraryView split (see library_view.dart). Members below are
// spliced into the state class; do not import this file directly.
part of 'library_view.dart';

/// Library keyboard handling: shortcuts dialog, search focus, selection
/// movement, undo, delete, pin and copy (F1, Ctrl+F, Ctrl+Z, Ctrl+P, Ctrl+C).
mixin _LibraryKeys on _LibraryStateBase {
  void _moveSelection(int delta) {
    if (notes.isEmpty || trash) return;
    int currentIndex = selectedNote == null
        ? -1
        : notes.indexWhere((n) => n.id == selectedNote!.id);
    int nextIndex = (currentIndex + delta).clamp(0, notes.length - 1);
    setState(() {
      selectedNote = notes[nextIndex];
    });
  }

  @override
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
      query.selection = TextSelection(
        baseOffset: 0,
        extentOffset: query.text.length,
      );
      return KeyEventResult.handled;
    }

    // Text editing owns arrows, Delete, copy and undo. The library's parent
    // Focus must never turn an unhandled editor key into a note mutation.
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return KeyEventResult.ignored;
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
      final target = selectedNote!;
      store
          .call(target.pinnedAt == null ? 'pin' : 'unpin', {'id': target.id})
          .then((_) {
            // The store round-trip is async; the view can be closed while it
            // is in flight and load() would setState on a dead element.
            if (mounted) load();
          });
      return KeyEventResult.handled;
    }

    if (isCtrl &&
        event.logicalKey == LogicalKeyboardKey.keyC &&
        selectedNote != null) {
      Clipboard.setData(ClipboardData(text: noteCopyText(selectedNote!)));
      showNexNotice(
        ScaffoldMessenger.of(context),
        AppLocalizations.of(context)!.copy,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
