import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:path/path.dart' as p;

/// One persistent database isolate; every command uses Nex's repositories.
class DesktopStore {
  DesktopStore._(this._commands, this._isolate, this._replies, this.mediaDir);
  final SendPort _commands;
  final Isolate _isolate;
  final ReceivePort _replies;
  final String mediaDir;
  final Map<int, Completer<dynamic>> _pending = {};
  int _sequence = 0;
  bool _closed = false;

  static Future<DesktopStore> open(String root, String deviceId) async {
    final replies = ReceivePort();
    final ready = Completer<SendPort>();
    DesktopStore? store;
    replies.listen((dynamic message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final parts = message as List;
      if (parts[0] == -1) {
        ready.completeError(StateError(parts[2] as String));
        return;
      }
      final task = store?._pending.remove(parts[0]);
      if (parts[1] == true) {
        task?.complete(parts[2]);
      } else {
        task?.completeError(StateError(parts[2] as String));
      }
    });
    final isolate = await Isolate.spawn(_worker, [
      replies.sendPort,
      root,
      deviceId,
    ]);
    try {
      final commands = await ready.future;
      store = DesktopStore._(commands, isolate, replies, p.join(root, 'media'));
      return store;
    } catch (_) {
      isolate.kill();
      replies.close();
      rethrow;
    }
  }

  Future<T> call<T>(String command, [Map<String, dynamic> args = const {}]) {
    if (_closed) return Future.error(StateError('Store is closed'));
    final id = ++_sequence;
    final result = Completer<dynamic>();
    _pending[id] = result;
    _commands.send([id, command, args]);
    return result.future.then((value) => value as T);
  }

  Future<void> close() async {
    if (_closed) return;
    await call<void>('close'); // FIFO: commits all earlier captures first.
    _closed = true;
    _replies.close();
    _isolate.kill();
  }

  static void _worker(List<dynamic> config) {
    final reply = config[0] as SendPort;
    NexDatabase db;
    final root = config[1] as String;
    final device = config[2] as String;
    try {
      db = NexDatabase.open(p.join(root, 'nex.sqlite'));
    } catch (e) {
      reply.send([-1, false, e.toString()]);
      return;
    }
    var notes = SqliteNoteRepository(db, localDeviceId: device);
    var capture = CaptureService(notes, deviceId: device);
    var threads = SqliteThreadRepository(db, notes, localDeviceId: device);
    var commitments = SqliteCommitmentRepository(db, localDeviceId: device);
    var maintenance = LibraryMaintenance(
      notes,
      mediaRoot: p.join(root, 'media'),
    );
    final commands = ReceivePort();
    reply.send(commands.sendPort);
    commands
        .asyncMap((dynamic raw) async {
          final id = raw[0] as int;
          final cmd = raw[1] as String;
          final a = (raw[2] as Map).cast<String, dynamic>();
          try {
            // Only synchronous repository calls here: one message is one commit.
            final dynamic result;
            switch (cmd) {
              case 'capture':
                final text = a['text'] as String;
                final oldId = a['id'] as String?;
                if (oldId != null) {
                  notes.updateContent(
                    oldId,
                    a['checklist'] == true
                        ? formatChecklist(
                            text
                                .split('\n')
                                .where((line) => line.isNotEmpty)
                                .map(
                                  (line) =>
                                      ChecklistItem(text: line, done: false),
                                )
                                .toList(),
                          )
                        : text,
                  );
                  result = notes.getById(oldId);
                } else if (a['checklist'] == true) {
                  result = capture.submitChecklistCapture(
                    text
                        .split('\n')
                        .where((line) => line.isNotEmpty)
                        .map((line) => ChecklistItem(text: line, done: false))
                        .toList(),
                  );
                } else {
                  final trimmed = text.trim();
                  final normalisedUrl = normaliseUrl(trimmed);
                  if (normalisedUrl != null) {
                    result = capture.submitLinkCapture(trimmed);
                  } else {
                    result = capture.submitTextCapture(text);
                  }
                }
              case 'timeline':
                result = notes.listTimeline(
                  limit: 50,
                  offset: a['offset'] as int? ?? 0,
                );
              case 'search':
                final filters = a['filters'] as SearchFilters;
                final parsed = parseSearchQuery(filters.query);
                final tags = notes.listTags();
                final tagIds = [...filters.tagIds];
                for (final name in parsed.tagNames) {
                  tagIds.add(
                    tags
                            .where(
                              (t) => t.name.toLowerCase() == name.toLowerCase(),
                            )
                            .firstOrNull
                            ?.id ??
                        'unmatched-tag',
                  );
                }
                final matches = notes.search(
                  SearchFilters(
                    query: parsed.text,
                    tagIds: tagIds,
                    types: [...filters.types, ...parsed.types],
                    createdFrom: filters.createdFrom,
                    createdTo: filters.createdTo,
                  ),
                );
                final threadId = a['thread'] as String?;
                final members = threadId == null
                    ? null
                    : threads.notes(threadId).map((n) => n.id).toSet();
                result = members == null
                    ? matches
                    : matches.where((n) => members.contains(n.id)).toList();
              case 'get':
                result = notes.getById(a['id'] as String);
              case 'delete':
                notes.softDelete(a['id'] as String);
                result = null;
              case 'restore':
                notes.undelete(a['id'] as String);
                result = null;
              case 'trash':
                result = maintenance.deletedNotes();
              case 'pin':
                result = notes.pinNote(a['id'] as String);
              case 'unpin':
                notes.unpinNote(a['id'] as String);
                result = null;
              case 'tags':
                result = notes.listTags();
              case 'tag':
                result = TagService(
                  notes,
                ).addTag(noteId: a['id'] as String, name: a['name'] as String);
              case 'untag':
                notes.detachTag(
                  noteId: a['id'] as String,
                  tagId: a['tag'] as String,
                );
                result = null;
              case 'threads':
                result = threads.list();
              case 'threadNotes':
                result = threads.notes(a['thread'] as String);
              case 'noteThreads':
                result = threads.forNote(a['id'] as String);
              case 'thread':
                result = threads.create(
                  a['name'] as String,
                  noteIds: [a['id'] as String],
                );
              case 'joinThread':
                threads.add(a['thread'] as String, a['id'] as String);
                result = null;
              case 'leaveThread':
                threads.remove(a['thread'] as String, a['id'] as String);
                result = null;
              case 'check':
                notes.toggleChecklistItem(a['id'] as String, a['index'] as int);
                result = null;
              case 'caption':
                notes.setCaption(a['id'] as String, a['text'] as String);
                result = null;
              case 'remind':
                final repeatStr = a['repeat'] as String?;
                final repeat = repeatStr != null
                    ? NoteRepeat.fromWire(repeatStr)
                    : NoteRepeat.once;
                notes.setDueAt(
                  a['id'] as String,
                  a['at'] as DateTime?,
                  repeat: repeat,
                );
                result = null;
              case 'linkMeta':
                notes.setLinkMetadata(
                  a['id'] as String,
                  title: a['title'] as String?,
                  excerpt: a['excerpt'] as String?,
                );
                result = null;
              case 'commitments':
                result = commitments.list();
              case 'commitmentSave':
                result = commitments.save(a['commitment'] as NexCommitment);
              case 'commitmentMet':
                result = commitments.markMet(a['id'] as String);
              case 'commitmentDelete':
                commitments.delete(a['id'] as String);
                result = null;
              case 'media':
                // Stream-copy and hash inside this isolate. Never load arbitrary files into UI memory.
                final source = File(a['path'] as String);
                final media = Directory(p.join(root, 'media'))
                  ..createSync(recursive: true);
                final staging = File(
                  p.join(media.path, '.incoming-${newUuidV7()}'),
                );
                try {
                  await source.copy(staging.path);
                  final hash = await sha256OfFile(staging.path);
                  if (hash == null) {
                    await staging.delete();
                    throw StateError('Media hashing failed');
                  }
                  final extension = p.extension(source.path).toLowerCase();
                  final target = File(p.join(media.path, '$hash$extension'));
                  if (!target.existsSync()) {
                    await staging.rename(target.path);
                  } else {
                    await staging.delete();
                  }
                  if (a['duration'] != null ||
                      [
                        '.wav',
                        '.mp3',
                        '.m4a',
                        '.aac',
                        '.ogg',
                        '.opus',
                        '.flac',
                        '.wma',
                      ].contains(extension)) {
                    result = capture.submitVoiceCapture(
                      mediaUri: target.path,
                      mediaHash: hash,
                      durationMs: a['duration'] as int? ?? 0,
                    );
                  } else if ([
                    '.png',
                    '.jpg',
                    '.jpeg',
                    '.webp',
                    '.gif',
                    '.bmp',
                  ].contains(extension)) {
                    result = capture.submitPhotoCapture(
                      mediaUri: target.path,
                      mediaHash: hash,
                    );
                  } else {
                    result = capture.submitFileCapture(
                      mediaUri: target.path,
                      mediaHash: hash,
                      originalFilename: p.basename(source.path),
                    );
                  }
                } finally {
                  if (await staging.exists()) await staging.delete();
                }
              case 'backup':
                result = NexBackupArchive.create(
                  database: db,
                  mediaDir: p.join(root, 'media'),
                  backupDir: a['directory'] as String,
                ).path;
              case 'fullBackup':
                final library = NexBackupArchive.create(
                  database: db,
                  mediaDir: p.join(root, 'media'),
                  backupDir: p.join(root, 'backups'),
                );
                final key = FullBackup.newKey();
                FullBackup.create(
                  library: library.path,
                  output: a['output'] as String,
                  settings: {'desktopShell': a['settings']},
                  key: key,
                );
                result = key;
              case 'restoreBackup':
                final backupPath = a['file'] as String;
                final key = a['key'] as String?;
                String libraryPath = backupPath;
                Map<String, dynamic>? restoredSettings;
                Directory? unpackStaging;
                if (backupPath.endsWith('.nexfull') ||
                    backupPath.endsWith('.fullbak')) {
                  if (key == null || key.trim().isEmpty) {
                    throw ArgumentError('Recovery key required');
                  }
                  unpackStaging = Directory(p.join(root, '.unpack-${newUuidV7()}'))
                    ..createSync(recursive: true);
                  final unpacked = FullBackup.unpack(
                    backupPath,
                    unpackStaging.path,
                    key.trim(),
                    modelHash: '',
                    modelBytes: 0,
                  );
                  libraryPath = p.join(unpackStaging.path, 'library.nexbak');
                  restoredSettings =
                      unpacked['desktopShell'] as Map<String, dynamic>?;
                }
                db.close();
                try {
                  NexBackupArchive.restore(
                    liveDbPath: p.join(root, 'nex.sqlite'),
                    mediaDir: p.join(root, 'media'),
                    backupFile: libraryPath,
                  );
                } finally {
                  if (unpackStaging?.existsSync() == true) {
                    try {
                      unpackStaging!.deleteSync(recursive: true);
                    } catch (_) {}
                  }
                  db = NexDatabase.open(p.join(root, 'nex.sqlite'));
                  notes = SqliteNoteRepository(db, localDeviceId: device);
                  capture = CaptureService(notes, deviceId: device);
                  threads = SqliteThreadRepository(
                    db,
                    notes,
                    localDeviceId: device,
                  );
                  commitments = SqliteCommitmentRepository(
                    db,
                    localDeviceId: device,
                  );
                  maintenance = LibraryMaintenance(
                    notes,
                    mediaRoot: p.join(root, 'media'),
                  );
                }
                result = restoredSettings;
              case 'close':
                db.close();
                commands.close();
                result = null;
              default:
                throw ArgumentError('Unknown command $cmd');
            }
            reply.send([id, true, result]);
          } catch (e) {
            reply.send([id, false, e.toString()]);
          }
        })
        .listen((_) {});
  }
}

/// Capture lifetime belongs to the app, never to a flyout widget.
class CaptureSession {
  CaptureSession(this.store);
  final DesktopStore store;
  String? id;
  Future<void> _tail = Future.value();
  Object? _error;
  Future<void> write(String text, {bool checklist = false}) {
    final task = _tail.then((_) async {
      final note = await store.call<Note?>('capture', {
        'id': id,
        'text': text,
        'checklist': checklist,
      });
      id = note?.id ?? id;
      _error = null;
    });
    _tail = task.catchError((Object e) {
      _error = e;
    });
    return task;
  }

  Future<void> get flushed => _tail.then((_) {
    if (_error != null) throw _error!;
  });
}
