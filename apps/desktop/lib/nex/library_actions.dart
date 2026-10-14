// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the NexLibraryView split (see library_view.dart). Members below are
// spliced into the state class; do not import this file directly.
part of 'library_view.dart';

/// Note mutation actions: delete with undo, and the card context menu.
mixin _LibraryActions on _LibraryStateBase {
  @override
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
          action: SnackBarAction(label: l.undo, onPressed: _undoLastDelete),
        ),
      );
    }
  }

  @override
  Future<void> _undoLastDelete() async {
    if (_lastDeletedId == null) return;
    final id = _lastDeletedId!;
    _lastDeletedId = null;
    await store.call('restore', {'id': id});
    await load();
  }

  @override
  void _showCardContextMenu(Offset globalPosition, Note note) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final dangerColor = Theme.of(context).colorScheme.error;
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
              Icon(Icons.delete_outline, size: 18, color: dangerColor),
              const SizedBox(width: 8),
              Text(l.delete, style: TextStyle(color: dangerColor)),
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
        await store.call(note.pinnedAt == null ? 'pin' : 'unpin', {
          'id': note.id,
        });
        await load();
      case 'copy':
        Clipboard.setData(ClipboardData(text: noteCopyText(note)));
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(l.copy)));
      case 'remind':
        if (!mounted) return;
        await showReminderPicker(
          context,
          note: note,
          onSave: (dueAt, repeat) async {
            await NexScope.of(context).remind(note.id, dueAt, repeat);
            await load();
          },
        );
      case 'delete':
        await _deleteNote(note);
    }
  }
}
