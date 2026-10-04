// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Detailed view, editor, media playback, tags, and threads for a note.
/// Owns [NexNoteDetail] and its inline editing state.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../l10n/app_localizations.dart';
import 'features_state.dart';
import 'note_copy.dart';
import 'reminder_picker.dart';

class NexNoteDetail extends StatefulWidget {
  const NexNoteDetail({super.key, required this.note, required this.onClose});
  final Note note;
  final VoidCallback onClose;
  @override
  State<NexNoteDetail> createState() => _NexNoteDetailState();
}

class _NexNoteDetailState extends State<NexNoteDetail> {
  late Note note = widget.note;
  late final editor = TextEditingController(text: note.content ?? '');
  final tag = TextEditingController(), thread = TextEditingController();
  late final caption = TextEditingController(text: note.caption ?? '');
  List<NoteThread> memberships = [], availableThreads = [];
  AudioPlayer? _player;
  // Windows has no mobile audio-session activation; let its media backend own
  // playback without interleaving an unsupported session configuration call.
  AudioPlayer get player =>
      _player ??= AudioPlayer(handleAudioSessionActivation: false);
  String? failure;
  bool editing = false;
  int editRevision = 0;
  bool _threadsLoaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_threadsLoaded) {
      _threadsLoaded = true;
      loadThreads();
    }
  }

  Future<void> loadThreads() async {
    final store = NexScope.of(context).store;
    try {
      final all = await store.call<List<NoteThread>>('threads');
      final member = await store.call<List<NoteThread>>('noteThreads', {
        'id': note.id,
      });
      if (mounted) {
        setState(() {
          availableThreads = all;
          memberships = member;
        });
      }
    } catch (e) {
      if (mounted) setState(() => failure = e.toString());
    }
  }

  Future<void> run(String command, Map<String, dynamic> args) async {
    final revision = ++editRevision;
    try {
      final store = NexScope.of(context).store;
      await NexScope.of(context).guard(() async {
        await store.call<dynamic>(command, {'id': note.id, ...args});
      }, rethrowError: true);
      if (!mounted) return;
      if (['thread', 'joinThread', 'leaveThread'].contains(command)) {
        await loadThreads();
      }
      final refreshed = await store.call<Note?>('get', {'id': note.id});
      if (mounted && refreshed != null && revision == editRevision) {
        setState(() {
          note = refreshed;
          failure = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => failure = e.toString());
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    editor.dispose();
    tag.dispose();
    thread.dispose();
    caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final c = NexPanelScope.maybeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 530.0;
        return SizedBox(
          width: double.infinity,
          height: height,
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: l.backToLibrary,
                          onPressed: widget.onClose,
                          icon: const BackButtonIcon(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                nexNoteTypeIcon(note.type.wireName),
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                noteTypeLabel(l, note.type),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (note.pinnedAt != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.push_pin,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                        const Spacer(),
                        if (note.type == NoteType.text ||
                            note.type == NoteType.checklist)
                          IconButton(
                            tooltip: editing ? l.readNote : l.editNote,
                            onPressed: () => setState(() => editing = !editing),
                            icon: Icon(
                              editing
                                  ? Icons.done_rounded
                                  : Icons.edit_outlined,
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            nexDisplayDate(
                              note.createdAt,
                              solar:
                                  Localizations.localeOf(context).languageCode ==
                                  'fa',
                              persian:
                                  Localizations.localeOf(context).languageCode ==
                                  'fa',
                              time: true,
                            ),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                          ),
                          if (note.content?.isNotEmpty == true) ...[
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outlineVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Localizations.localeOf(context).languageCode == 'fa'
                                  ? nexDigits(
                                      '${note.content!.trim().split(RegExp(r'\s+')).length} کلمه',
                                      persian: true,
                                    )
                                  : '${note.content!.trim().split(RegExp(r'\s+')).length} words',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (editing &&
                        (note.type == NoteType.text ||
                            note.type == NoteType.checklist))
                      TextField(
                        controller: editor,
                        minLines: 3,
                        maxLines: 10,
                        textDirection: nexDirectionOf(editor.text),
                        onChanged: (text) => run('capture', {'text': text}),
                      ),
                    if (note.type != NoteType.text &&
                        note.type != NoteType.checklist) ...[
                      if (note.type == NoteType.photo && note.mediaUri != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(note.mediaUri!),
                            height: 220,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(l.mediaUnavailable),
                            ),
                          ),
                        )
                      else if (note.type == NoteType.file)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: NexTextSurface(note.originalFilename ?? ''),
                        ),
                      NexTextSurface(note.displayText ?? ''),
                      const SizedBox(height: 12),
                      TextField(
                        controller: caption,
                        textDirection: nexDirectionOf(caption.text),
                        decoration: InputDecoration(hintText: l.caption),
                        onChanged: (text) => run('caption', {'text': text}),
                      ),
                    ],
                    if (!editing && note.type == NoteType.text)
                      NexMarkdown(note.content ?? ''),
                    if (!editing && note.type == NoteType.checklist) ...[
                      for (
                        var i = 0;
                        i < parseChecklist(note.content ?? '').length;
                        i++
                      )
                        CheckboxListTile(
                          value: parseChecklist(note.content ?? '')[i].done,
                          title: Text(parseChecklist(note.content ?? '')[i].text),
                          onChanged: (_) => run('check', {'index': i}),
                        ),
                    ],
                    if (note.type == NoteType.voice && note.mediaUri != null)
                      StreamBuilder<PlayerState>(
                        stream: player.playerStateStream,
                        builder: (context, state) {
                          final playing =
                              player.playing &&
                              player.processingState != ProcessingState.completed;
                          return TextButton.icon(
                            onPressed: () async {
                              try {
                                if (playing) {
                                  await player.pause();
                                } else {
                                  if (player.audioSource == null) {
                                    await player.setFilePath(note.mediaUri!);
                                  }
                                  if (player.processingState ==
                                      ProcessingState.completed) {
                                    await player.seek(Duration.zero);
                                  }
                                  unawaited(
                                    player.play().catchError((Object e) {
                                      if (mounted) {
                                        setState(() => failure = e.toString());
                                      }
                                    }),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => failure = e.toString());
                                }
                              }
                            },
                            icon: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(playing ? l.pause : l.play),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: noteCopyText(note)),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l.copy)),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(l.copy),
                        ),
                        if (note.mediaUri != null)
                          OutlinedButton.icon(
                            onPressed: c == null
                                ? null
                                : () => c.native.launch(note.mediaUri!),
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: Text(l.open),
                          ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              run(note.pinnedAt == null ? 'pin' : 'unpin', {}),
                          icon: Icon(
                            note.pinnedAt == null
                                ? Icons.push_pin_outlined
                                : Icons.push_pin,
                            size: 16,
                            color: note.pinnedAt != null
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          label: Text(note.pinnedAt == null ? l.pin : l.unpin),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => showReminderPicker(
                            context,
                            note: note,
                            onSave: (dueAt, repeat) => run('remind', {
                              'at': dueAt,
                              'repeat': repeat.wireName,
                            }),
                          ),
                          icon: const Icon(Icons.alarm_add_outlined, size: 16),
                          label: Text(l.remind),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await run('delete', {});
                            if (context.mounted && failure == null) {
                              final features = NexScope.of(context);
                              if (features.session.id == note.id) {
                                await features.fresh();
                              }
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.deleted),
                                  action: SnackBarAction(
                                    label: l.undo,
                                    onPressed: () => features.guard(
                                      () => features.store.call<void>('restore', {
                                        'id': note.id,
                                      }),
                                    ),
                                  ),
                                ),
                              );
                              widget.onClose();
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                          label: Text(l.delete, style: const TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.red.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (note.dueAt != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: InputChip(
                          avatar: const Icon(Icons.alarm, size: 16),
                          label: Text(
                            '${nexDisplayDate(note.dueAt!, solar: Localizations.localeOf(context).languageCode == 'fa', persian: Localizations.localeOf(context).languageCode == 'fa')} ${Localizations.localeOf(context).languageCode == 'fa' ? nexDigits('${note.dueAt!.hour.toString().padLeft(2, '0')}:${note.dueAt!.minute.toString().padLeft(2, '0')}', persian: true) : '${note.dueAt!.hour.toString().padLeft(2, '0')}:${note.dueAt!.minute.toString().padLeft(2, '0')}'}${note.dueRepeat != NoteRepeat.once ? ' (${note.dueRepeat == NoteRepeat.daily ? l.repeatDaily : l.repeatWeekly})' : ''}',
                          ),
                          onPressed: () => showReminderPicker(
                            context,
                            note: note,
                            onSave: (dueAt, repeat) => run('remind', {
                              'at': dueAt,
                              'repeat': repeat.wireName,
                            }),
                          ),
                          onDeleted: () => run('remind', {'at': null, 'repeat': 'once'}),
                        ),
                      ),
                    ],
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: note.tags
                            .map(
                              (t) => InputChip(
                                avatar: t.color != null
                                    ? Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: nexParseTagColor(t.color),
                                        ),
                                      )
                                    : null,
                                label: Text(t.name),
                                onDeleted: () => run('untag', {'tag': t.id}),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: Text(l.tagsAndThreads),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        TextField(
                          controller: tag,
                          textDirection: nexDirectionOf(tag.text),
                          decoration: InputDecoration(hintText: l.addTag),
                          onSubmitted: (name) async {
                            await run('tag', {'name': name});
                            tag.clear();
                          },
                        ),
                        TextField(
                          controller: thread,
                          textDirection: nexDirectionOf(thread.text),
                          decoration: InputDecoration(hintText: l.addThread),
                          onSubmitted: (name) async {
                            await run('thread', {'name': name});
                            thread.clear();
                          },
                        ),
                        Wrap(
                          children: memberships
                              .map(
                                (t) => InputChip(
                                  label: Text(t.name),
                                  onDeleted: () =>
                                      run('leaveThread', {'thread': t.id}),
                                ),
                              )
                              .toList(),
                        ),
                        DropdownButton<String>(
                          hint: Text(l.joinThread),
                          isExpanded: true,
                          items: availableThreads
                              .where((t) => !memberships.any((m) => m.id == t.id))
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            if (id != null) run('joinThread', {'thread': id});
                          },
                        ),
                      ],
                    ),
                    if (failure != null) Text('${l.failed}: $failure'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
