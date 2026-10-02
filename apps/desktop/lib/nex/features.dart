import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import '../core/models.dart' show ClipImage;
import '../core/controller.dart';
import '../l10n/app_localizations.dart';
import 'store.dart';

class NexFeatures extends ChangeNotifier {
  NexFeatures(this.store, {this.pickFiles}) : session = CaptureSession(store);
  final DesktopStore store;
  final Future<List<XFile>> Function(List<XTypeGroup>)? pickFiles;
  CaptureSession session;
  final composer = TextEditingController();
  final focus = FocusNode();
  bool checklist = false;
  String? error;
  int libraryRevision = 0;
  int importedCount = 0;
  bool importing = false, recordingBusy = false;
  VoidCallback? _recordingRelease;
  AudioRecorder? _recorder;
  AudioRecorder get recorder => _recorder ??= AudioRecorder();
  DateTime? recordingAt;
  String? _recordingPath;
  final _pending = <Future<void>>{};

  void notify() => notifyListeners();
  Future<void> guard(
    Future<void> Function() action, {
    bool rethrowError = false,
  }) {
    late final Future<void> task;
    task = _guard(
      action,
      rethrowError,
    ).whenComplete(() => _pending.remove(task));
    _pending.add(task);
    return task;
  }

  Future<void> _guard(Future<void> Function() action, bool rethrowError) async {
    try {
      await action();
      error = null;
      libraryRevision++;
    } catch (e) {
      error = e.toString();
      if (rethrowError) rethrow;
    } finally {
      notifyListeners();
    }
  }

  void write(String text) {
    // No debounce. Session owns the FIFO, so disposing a panel loses nothing.
    unawaited(guard(() => session.write(text, checklist: checklist)));
  }

  Future<void> fresh() async {
    await session.flushed;
    session = CaptureSession(store);
    composer.clear();
    notifyListeners();
    // The hotkey can arrive before the capture field's first layout. Opening
    // its input connection sooner reads an unlaid-out RenderEditable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focus.context != null) focus.requestFocus();
    });
  }

  Future<void> importPaths(
    List<String> paths, {
    bool rethrowError = false,
  }) async {
    if (paths.isEmpty || importing) return;
    importing = true;
    importedCount = 0;
    notify();
    try {
      await guard(() async {
        for (final path in paths) {
          if (!await File(path).exists()) {
            throw FileSystemException('File unavailable', path);
          }
          await store.call<Note>('media', {'path': path});
          importedCount++;
        }
      }, rethrowError: rethrowError);
    } finally {
      importing = false;
      notify();
    }
  }

  Future<void> pasteImage(ClipImage image, {bool rethrowError = false}) =>
      guard(() async {
        final completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          image.rgba,
          image.w,
          image.h,
          ui.PixelFormat.rgba8888,
          completer.complete,
        );
        final decoded = await completer.future;
        final bytes = await decoded.toByteData(format: ui.ImageByteFormat.png);
        decoded.dispose();
        if (bytes == null) throw StateError('PNG encoding failed');
        final temp = await Directory.systemTemp.createTemp('nex-clipboard-');
        try {
          final file = File(p.join(temp.path, 'clipboard.png'));
          await file.writeAsBytes(bytes.buffer.asUint8List());
          await store.call<Note>('media', {'path': file.path});
          importedCount = 1;
        } finally {
          await temp.delete(recursive: true);
        }
      }, rethrowError: rethrowError);
  Future<void> record([PanelController? panel]) async {
    if (recordingBusy) return;
    recordingBusy = true;
    notify();
    try {
      await guard(() async {
        if (recordingAt == null) {
          if (!await recorder.hasPermission()) {
            throw StateError('Microphone permission denied');
          }
          _recordingPath = p.join(
            Directory.systemTemp.path,
            'nex-${newUuidV7()}.wav',
          );
          await recorder.start(
            const RecordConfig(encoder: AudioEncoder.wav),
            path: _recordingPath!,
          );
          recordingAt = DateTime.now();
          _recordingRelease = panel?.holdOpen();
        } else {
          final path = await recorder.stop() ?? _recordingPath;
          final duration = DateTime.now()
              .difference(recordingAt!)
              .inMilliseconds;
          if (path != null) {
            await store.call<Note>('media', {
              'path': path,
              'duration': duration,
            });
            importedCount = 1;
            await File(path).delete();
          }
          recordingAt = null;
          _recordingRelease?.call();
          _recordingRelease = null;
        }
      });
    } finally {
      recordingBusy = false;
      notify();
    }
  }

  Future<void> close() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
    if (recordingAt != null) await record();
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
    // A failed attachment/permission request must not prevent graceful exit.
    await session.flushed;
    await store.close();
    await _recorder?.dispose();
    composer.dispose();
    focus.dispose();
  }
}

Future<T> withPanelHold<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final release = NexPanelScope.maybeOf(context)?.holdOpen();
  try {
    return await action();
  } finally {
    release?.call();
  }
}

class NexScope extends InheritedNotifier<NexFeatures> {
  const NexScope({
    super.key,
    required NexFeatures features,
    required super.child,
  }) : super(notifier: features);
  static NexFeatures of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexScope>()!.notifier!;
  static NexFeatures? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexScope>()?.notifier;
}

class NexCaptureView extends StatelessWidget {
  const NexCaptureView({super.key, this.pickFiles});
  final Future<List<XFile>> Function(List<XTypeGroup>)? pickFiles;
  Future<void> _choose(
    BuildContext context,
    NexFeatures features, [
    List<XTypeGroup> groups = const [],
  ]) {
    features.importedCount = 0;
    features.notify();
    return withPanelHold(
      context,
      () => features.guard(() async {
        final picker = pickFiles ?? features.pickFiles;
        final files =
            await (picker?.call(groups) ??
                openFiles(acceptedTypeGroups: groups));
        await features.importPaths(
          files.map((e) => e.path).toList(),
          rethrowError: true,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = NexScope.of(context);
    final l = AppLocalizations.of(context)!;
    final c = context
        .dependOnInheritedWidgetOfExactType<NexPanelScope>()
        ?.controller;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.savedLocally,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: l.newNote,
                onPressed: () => f.fresh(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyV,
                control: true,
              ): () async {
                final text = await Clipboard.getData(Clipboard.kTextPlain);
                if (text?.text?.isNotEmpty == true) {
                  final selection = f.composer.selection;
                  final value = f.composer.text;
                  final start = selection.isValid
                      ? selection.start
                      : value.length;
                  final end = selection.isValid ? selection.end : value.length;
                  f.composer.value = TextEditingValue(
                    text: value.replaceRange(start, end, text!.text!),
                    selection: TextSelection.collapsed(
                      offset: start + text.text!.length,
                    ),
                  );
                  f.write(f.composer.text);
                } else if (c != null) {
                  await f.guard(() async {
                    final image = await c.native.currentClipboardImage();
                    if (image != null) {
                      await f.pasteImage(image, rethrowError: true);
                    }
                  });
                }
              },
            },
            child: Focus(
              onFocusChange: (focused) =>
                  focused ? c?.focusGained() : c?.focusLost(),
              child: TextField(
                key: const ValueKey('capture-field'),
                controller: f.composer,
                focusNode: f.focus,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                textDirection: nexDirectionOf(f.composer.text),
                decoration: InputDecoration(
                  hintText: l.captureHint,
                  filled: true,
                ),
                onChanged: f.write,
              ),
            ),
          ),
          Row(
            children: [
              Checkbox(
                value: f.checklist,
                onChanged: f.session.id == null
                    ? (v) {
                        f.checklist = v!;
                        f.notify();
                      }
                    : null,
              ),
              Text(l.checklist),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CaptureAction(
                label: l.pasteText,
                onPressed: () async {
                  final clip = await Clipboard.getData(Clipboard.kTextPlain);
                  if (clip?.text?.isNotEmpty == true) {
                    await f.fresh();
                    f.composer.text = clip!.text!;
                    f.write(clip.text!);
                  }
                },
                icon: Icons.content_paste_rounded,
              ),
              _CaptureAction(
                label: l.addImage,
                onPressed: f.importing
                    ? null
                    : () => _choose(context, f, [
                        XTypeGroup(
                          label: l.photo,
                          extensions: const [
                            'png',
                            'jpg',
                            'jpeg',
                            'webp',
                            'gif',
                            'bmp',
                          ],
                        ),
                      ]),
                icon: Icons.add_photo_alternate_outlined,
              ),
              _CaptureAction(
                label: l.attach,
                onPressed: f.importing ? null : () => _choose(context, f),
                icon: Icons.attach_file_rounded,
              ),
              _CaptureAction(
                label: l.addAudio,
                onPressed: f.importing
                    ? null
                    : () => _choose(context, f, [
                        XTypeGroup(
                          label: l.voice,
                          extensions: const [
                            'wav',
                            'mp3',
                            'm4a',
                            'aac',
                            'ogg',
                            'opus',
                            'flac',
                            'wma',
                          ],
                        ),
                      ]),
                icon: Icons.audio_file_outlined,
              ),
              _CaptureAction(
                label: f.recordingAt == null ? l.record : l.stop,
                onPressed: f.recordingBusy ? null : () => f.record(c),
                icon: f.recordingAt == null
                    ? Icons.mic_none_rounded
                    : Icons.stop_circle_outlined,
              ),
              if (c != null)
                _CaptureAction(
                  label: l.pastePhoto,
                  onPressed: () => f.guard(() async {
                    final image = await c.native.currentClipboardImage();
                    if (image == null) throw StateError(l.noClipboardImage);
                    await f.pasteImage(image, rethrowError: true);
                  }),
                  icon: Icons.content_paste_go_rounded,
                ),
            ],
          ),
          if (f.importing || f.recordingBusy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (f.recordingAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l.recording,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (f.importedCount > 0 && !f.importing)
            TextButton.icon(
              onPressed: c == null ? null : () => c.openWidget('timeline'),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(l.mediaAdded(f.importedCount)),
            ),
          if (f.error != null)
            Text(
              '${l.failed}: ${f.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _CaptureAction extends StatelessWidget {
  const _CaptureAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 152,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 2, textAlign: TextAlign.start),
      style: OutlinedButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    ),
  );
}

class NexPanelScope extends InheritedWidget {
  const NexPanelScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final PanelController controller;
  static PanelController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexPanelScope>()?.controller;
  @override
  bool updateShouldNotify(NexPanelScope oldWidget) =>
      oldWidget.controller != controller;
}

class NexLibraryView extends StatefulWidget {
  const NexLibraryView({super.key});
  @override
  State<NexLibraryView> createState() => _NexLibraryViewState();
}

class _NexLibraryViewState extends State<NexLibraryView> {
  final query = TextEditingController();
  final scroll = ScrollController();
  List<Note> notes = [];
  List<Tag> tags = [];
  List<NoteThread> threads = [];
  NoteType? type;
  String? tag;
  String? thread;
  String? failure;
  bool trash = false, loading = false, more = true;
  Note? selectedNote;
  VoidCallback? _detailRelease;
  int generation = 0;
  int _libraryRevision = -1;
  DesktopStore get store => NexScope.of(context).store;
  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 150 && more && !loading) {
        load(append: true);
      }
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (selectedNote != null) {
      return NexNoteDetail(
        note: selectedNote!,
        onClose: () {
          _detailRelease?.call();
          _detailRelease = null;
          setState(() => selectedNote = null);
          load();
        },
      );
    }
    return SizedBox(
      height: 530,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
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
                textDirection: nexDirectionOf(query.text),
                decoration: InputDecoration(
                  hintText: l.search,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) => load(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              children: [
                DropdownButton<NoteType>(
                  hint: Text(l.type),
                  value: type,
                  items: NoteType.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(noteTypeLabel(l, v)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    type = v;
                    load();
                  },
                ),
                DropdownButton<String>(
                  hint: Text(l.tags),
                  value: tag,
                  items: tags
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v.id, child: Text(v.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    tag = v;
                    load();
                  },
                ),
                DropdownButton<String>(
                  hint: Text(l.threads),
                  value: thread,
                  items: threads
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v.id, child: Text(v.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    thread = v;
                    load();
                  },
                ),
                IconButton(
                  tooltip: l.clear,
                  onPressed: () {
                    query.clear();
                    type = null;
                    tag = thread = null;
                    load();
                  },
                  icon: const Icon(Icons.filter_alt_off),
                ),
                IconButton(
                  tooltip: l.trash,
                  onPressed: () {
                    trash = !trash;
                    load();
                  },
                  icon: Icon(trash ? Icons.history : Icons.delete_outline),
                ),
              ],
            ),
          ),
          if (failure != null) Text('${l.failed}: $failure'),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              itemCount: notes.length + (loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == notes.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final note = notes[index];
                final fa = Localizations.localeOf(context).languageCode == 'fa';
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
                return Column(
                  children: [
                    if (date != prior)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(date),
                      ),
                    NoteCard(
                      note: note,
                      showDue: false,
                      strings: NexCardStrings(
                        noteOfType: (type) =>
                            '${l.note}: ${noteTypeLabel(l, NoteType.values.firstWhere((t) => t.name == type, orElse: () => NoteType.text))}',
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
                      ),
                      onTap: () {
                        _detailRelease = NexPanelScope.maybeOf(
                          context,
                        )?.holdOpen();
                        setState(() => selectedNote = note);
                      },
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
          if (notes.isEmpty && !loading) Text(l.empty),
        ],
      ),
    );
  }
}

String noteTypeLabel(AppLocalizations l, NoteType type) => switch (type) {
  NoteType.text => l.text,
  NoteType.voice => l.voice,
  NoteType.photo => l.photo,
  NoteType.file => l.file,
  NoteType.checklist => l.checklist,
  NoteType.link => l.link,
};

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
    return SizedBox(
      width: double.infinity,
      height: 530,
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
                  Expanded(
                    child: Text(
                      noteTypeLabel(l, note.type),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (note.type == NoteType.text ||
                      note.type == NoteType.checklist)
                    IconButton(
                      tooltip: editing ? l.readNote : l.editNote,
                      onPressed: () => setState(() => editing = !editing),
                      icon: Icon(
                        editing ? Icons.done_rounded : Icons.edit_outlined,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
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
                          if (mounted) setState(() => failure = e.toString());
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
                children: [
                  TextButton(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: note.copyText ?? ''),
                    ),
                    child: Text(l.copy),
                  ),
                  if (note.mediaUri != null)
                    TextButton(
                      onPressed: c == null
                          ? null
                          : () => c.native.launch(note.mediaUri!),
                      child: Text(l.open),
                    ),
                  TextButton(
                    onPressed: () =>
                        run(note.pinnedAt == null ? 'pin' : 'unpin', {}),
                    child: Text(note.pinnedAt == null ? l.pin : l.unpin),
                  ),
                  TextButton(
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
                    child: Text(l.delete),
                  ),
                ],
              ),
              Wrap(
                children: note.tags
                    .map(
                      (t) => InputChip(
                        label: Text(t.name),
                        onDeleted: () => run('untag', {'tag': t.id}),
                      ),
                    )
                    .toList(),
              ),
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
    );
  }
}
