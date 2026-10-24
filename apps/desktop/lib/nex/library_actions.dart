// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the NexLibraryView split (see library_view.dart). Members below are
// spliced into the state class; do not import this file directly.
part of 'library_view.dart';

/// Note mutation actions: delete with undo, and the card context menu.
mixin _LibraryActions on _LibraryStateBase {
  @override
  Future<void> _openLibraryLocations() async {
    final l = AppLocalizations.of(context)!;
    final result = await showDesktopCollection<String>(
      context,
      l.libraryTitle,
      const NexLibraryLocations(),
    );
    if (!mounted) return;
    switch (result) {
      case 'tags':
        await showTagManager(context, NexScope.of(context));
      case 'threads':
        final picked = await showDialog<String>(
          context: context,
          builder: (ctx) => NexAlertDialog(
            title: Text(l.threads),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: threads.isEmpty
                      ? [Text(l.empty)]
                      : [
                          for (final item in threads)
                            ListTile(
                              title: Text(item.name),
                              onTap: () => Navigator.pop(ctx, item.id),
                            ),
                        ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.close),
              ),
            ],
          ),
        );
        if (!mounted || picked == null) return;
        setState(() {
          thread = picked;
          trash = false;
        });
      case 'trash':
        _detailRelease?.call();
        _detailRelease = null;
        setState(() {
          trash = true;
          thread = tag = null;
          datePreset = LibraryDatePreset.any;
          selectedNote = null;
          _selectedIds.clear();
        });
      default:
        break;
    }
    if (mounted) await load();
  }

  @override
  Future<void> _deleteNote(Note note) async {
    final id = note.id;
    _lastDeletedId = id;
    final features = NexScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context)!;
    try {
      await deleteNoteWithUndo(features, id, messenger, l);
    } catch (e) {
      showNexNotice(messenger, '${l.failed}: $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      if (selectedNote?.id == id) selectedNote = null;
      _selectedIds.remove(id);
    });
    await load();
  }

  @override
  Future<void> _undoLastDelete() async {
    if (_lastDeletedId == null) return;
    final id = _lastDeletedId!;
    _lastDeletedId = null;
    await NexScope.of(
      context,
    ).guard(() => store.call<void>('restore', {'id': id}));
    if (mounted) await load();
  }

  @override
  void _showCardContextMenu(Offset globalPosition, Note note) async {
    if (trash) return;
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await nexShowContextMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        nexMenuItem(value: 'open', icon: Icons.open_in_new, label: l.readNote),
        nexMenuItem(
          value: 'pin',
          icon: Icons.push_pin_outlined,
          label: note.pinnedAt == null ? l.pin : l.unpin,
        ),
        nexMenuItem(value: 'copy', icon: Icons.copy_rounded, label: l.copy),
        nexMenuItem(
          value: 'aside',
          icon: Icons.archive_outlined,
          label: l.setAside,
        ),
        nexMenuItem(
          value: 'remind',
          icon: Icons.alarm_add_outlined,
          label: l.remind,
        ),
        nexMenuItem(
          value: 'delete',
          icon: Icons.delete_outline,
          label: l.delete,
          destructive: true,
        ),
      ],
    );

    if (result == null || !mounted) return;
    switch (result) {
      case 'open':
        setState(() => selectedNote = note);
      case 'pin':
        await NexScope.of(context).guard(
          () => store.call<void>(note.pinnedAt == null ? 'pin' : 'unpin', {
            'id': note.id,
          }),
        );
        if (mounted) await load();
      case 'copy':
        Clipboard.setData(ClipboardData(text: noteCopyText(note)));
        if (!mounted) return;
        showNexNotice(messenger, l.copy);
      case 'remind':
        if (!mounted) return;
        // The scope is captured before the picker opens: the dialog outlives
        // this view on the root navigator, and looking the scope up from the
        // closure's captured context after the library has unmounted would
        // assert on a deactivated element.
        final features = NexScope.of(context);
        await showReminderPicker(
          context,
          note: note,
          onSave: (dueAt, repeat) async {
            await features.remind(note.id, dueAt, repeat);
            if (mounted) await load();
          },
        );
      case 'aside':
        await setDesktopNotesAside(context, [note]);
        if (mounted) {
          if (selectedNote?.id == note.id) {
            _detailRelease?.call();
            _detailRelease = null;
            setState(() => selectedNote = null);
          }
          await load();
        }
      case 'delete':
        await _deleteNote(note);
    }
  }
}
