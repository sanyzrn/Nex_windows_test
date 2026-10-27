import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:nex_ai/cloud.dart';
import 'intelligence/worker.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:path/path.dart' as p;
import 'reminder_policy.dart';
import 'reminder_activation.dart';
import '../core/backup_shell.dart';

class DesktopRestoreResult {
  const DesktopRestoreResult({required this.replacesLibrary, this.settings});
  final bool replacesLibrary;
  final Map<String, dynamic>? settings;
}

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
  Future<void>? _closing;
  final _reminderChanges = StreamController<void>.broadcast();
  Stream<void> get reminderChanges => _reminderChanges.stream;
  final _libraryChanges = StreamController<void>.broadcast();
  Stream<void> get libraryChanges => _libraryChanges.stream;

  static Future<DesktopStore> open(String root, String deviceId) async {
    final replies = ReceivePort();
    final ready = Completer<SendPort>();
    DesktopStore? store;
    replies.listen((dynamic message) {
      // Isolate errors and exits must finish callers instead of leaving a
      // permanent spinner (including a worker that fails before its handshake).
      if (message == null || (message is List && message.length == 2)) {
        final error = StateError(
          message == null ? 'Storage worker stopped' : '${message[0]}',
        );
        if (!ready.isCompleted) ready.completeError(error);
        store?._failPending(error);
        return;
      }
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final parts = message as List;
      if (parts[0] == -2) {
        store?._libraryChanges.add(null);
        return;
      }
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
    final isolate = await Isolate.spawn(
      _worker,
      [replies.sendPort, root, deviceId],
      onError: replies.sendPort,
      onExit: replies.sendPort,
    );
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
    return result.future.then((value) {
      if (const {
        'remind',
        'reminderAction',
        'delete',
        'restore',
        'restoreBackup',
      }.contains(command)) {
        _reminderChanges.add(null);
      }
      return value as T;
    });
  }

  void _failPending(Object error) {
    _closed = true;
    for (final task in _pending.values) {
      task.completeError(error);
    }
    _pending.clear();
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    final drained = _closed ? Future<void>.value() : call<void>('close');
    // Reject new commands as soon as the FIFO's terminal command is queued.
    _closed = true;
    return _closing = drained.whenComplete(() async {
      await _reminderChanges.close();
      await _libraryChanges.close();
      _replies.close();
      _isolate.kill();
    });
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
            final scheduled = SqliteScheduledNoteRepository(db, notes);
            if (notes.releaseDueSetAside().isNotEmpty) {
              reply.send([-2, true, null]);
            }
            if (const {
              'timeline',
              'search',
              'workspace',
              'reminderCandidates',
            }.contains(cmd)) {
              if (scheduled.releaseDue(DateTime.now()).isNotEmpty) {
                reply.send([-2, true, null]);
              }
            }
            final dynamic result;
            switch (cmd) {
              case 'portraitNotes':
                final count =
                    db.db
                            .select(
                              'SELECT COUNT(*) AS n FROM notes WHERE deleted_at IS NULL',
                            )
                            .single['n']
                        as int;
                result = notes.listTimeline(limit: count);
              case 'cycleSnapshot':
                final cycle = SqliteCycleRepository(db);
                final day = a['day'] as DateTime;
                result = {
                  'periods': cycle.periods(),
                  'log': cycle.day(day),
                  'days': cycle.days(
                    a['from'] as DateTime,
                    a['to'] as DateTime,
                  ),
                };
              case 'cycleStart':
                result = SqliteCycleRepository(db).startPeriod(
                  a['day'] as DateTime,
                  closeAfter: a['typicalPeriod'] as int? ?? 5,
                );
              case 'cycleEnd':
                SqliteCycleRepository(
                  db,
                ).endPeriod(a['id'] as String, a['day'] as DateTime);
                result = null;
              case 'cycleUpdate':
                SqliteCycleRepository(db).updatePeriod(
                  a['id'] as String,
                  a['start'] as DateTime,
                  a['end'] as DateTime?,
                );
                result = null;
              case 'cycleDelete':
                SqliteCycleRepository(db).deletePeriod(a['id'] as String);
                result = null;
              case 'cycleDay':
                SqliteCycleRepository(db).saveDay(a['log'] as CycleDayLog);
                result = null;
              case 'aiActions':
                result = executeDesktopAiActions(
                  db,
                  device,
                  (a['actions'] as List).cast<AssistantAction>(),
                );
                reply.send([-2, true, null]);
              case 'aiEnrich':
                final noteId = a['id'] as String;
                if (notes.getById(noteId) == null) {
                  throw StateError('Note is unavailable');
                }
                switch (a['field']) {
                  case 'summary':
                    notes.setSummaryText(noteId, a['text'] as String);
                  case 'ocr':
                    notes.setOcrText(noteId, a['text'] as String);
                  case 'transcribe':
                    notes.setTranscriptText(noteId, a['text'] as String);
                  default:
                    throw ArgumentError('Unsupported enrichment');
                }
                result = null;
                reply.send([-2, true, null]);
              case 'aiEmbedding':
                notes.setEmbeddingSpace(a['space'] as String);
                notes.setEmbedding(
                  a['id'] as String,
                  (a['values'] as List).cast<double>(),
                );
                result = null;
              case 'aiNearest':
                notes.setEmbeddingSpace(a['space'] as String);
                result = notes
                    .nearestEmbeddings(
                      (a['values'] as List).cast<double>(),
                      minScore: .25,
                    )
                    .map((r) => notes.getById(r.noteId))
                    .whereType<Note>()
                    .toList();
              case 'aiCycleContext':
                result = jsonEncode({
                  'periods': db.db
                      .select(
                        'SELECT * FROM cycle_periods ORDER BY start_day DESC LIMIT 36',
                      )
                      .map((r) => Map<String, dynamic>.from(r))
                      .toList(),
                });
              case 'capture':
                final text = a['text'] as String;
                final oldId = a['id'] as String?;
                if (oldId != null) {
                  final current = notes.getById(oldId);
                  if (current == null || current.deletedAt != null) {
                    throw StateError('Capture note is no longer available');
                  }
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
                  limit: (a['limit'] as int? ?? 50).clamp(1, 200),
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
              case 'attachments':
                result = SqliteAttachmentRepository(
                  notes,
                  localDeviceId: device,
                ).forNote(a['id'] as String);
              case 'removeAttachment':
                SqliteAttachmentRepository(
                  notes,
                  localDeviceId: device,
                ).remove(a['id'] as String);
                result = null;
              case 'restoreAttachment':
                result = SqliteAttachmentRepository(
                  notes,
                  localDeviceId: device,
                ).restore(a['id'] as String);
              case 'scheduled':
                result = scheduled.pending();
              case 'releaseScheduled':
                result = scheduled.releaseNow(
                  a['id'] as String,
                  DateTime.now(),
                );
              case 'discardScheduled':
                scheduled.discard(a['id'] as String);
                result = null;
              case 'delete':
                notes.softDelete(a['id'] as String);
                result = null;
              case 'restore':
                notes.undelete(a['id'] as String);
                result = null;
              case 'trash':
                result = maintenance.deletedNotes();
              case 'setAside':
                result = notes.setAside(
                  a['id'] as String,
                  until: a['until'] as DateTime?,
                );
                reply.send([-2, true, null]);
              case 'bringBack':
                notes.bringBack(a['id'] as String);
                result = null;
                reply.send([-2, true, null]);
              case 'setAsideNotes':
                result = notes.listSetAside(
                  limit: (a['limit'] as int? ?? 500).clamp(1, 10000),
                );
              case 'libraryCounts':
                result = <String, int>{
                  'aside': notes.setAsideCount(),
                  'tags': notes.listTags().length,
                  'threads': threads.list().length,
                  'trash': maintenance.deletedNotes().length,
                };
              case 'pin':
                result = notes.pinNote(a['id'] as String);
              case 'unpin':
                notes.unpinNote(a['id'] as String);
                result = null;
              case 'tags':
                result = notes.listTags();
              case 'tagUsage':
                result = maintenance.tagUsage();
              case 'createTag':
                notes.upsertTag(name: a['name'] as String);
                result = null;
              case 'renameTag':
                final name = (a['name'] as String).trim();
                if (notes.listTags().any(
                  (t) =>
                      t.id != a['tag'] &&
                      t.name.toLowerCase() == name.toLowerCase(),
                )) {
                  throw ArgumentError('Tag name already exists');
                }
                maintenance.renameTag(a['tag'] as String, name);
                result = null;
              case 'deleteTag':
                maintenance.deleteTag(a['tag'] as String);
                result = null;
              case 'tag':
                final tagId = a['tag'] as String?;
                if (tagId == null) {
                  result = TagService(notes).addTag(
                    noteId: a['id'] as String,
                    name: a['name'] as String,
                  );
                } else {
                  final note = notes.getById(a['id'] as String);
                  final tag = notes
                      .listTags()
                      .where((t) => t.id == tagId)
                      .firstOrNull;
                  if (note == null || note.deletedAt != null || tag == null) {
                    throw StateError('Note or tag unavailable');
                  }
                  if (!note.tags.any((t) => t.id == tagId)) {
                    notes.attachTag(noteId: note.id, tagId: tagId);
                  }
                  result = tag;
                }
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
              case 'workspace':
                final totals = notes.db.select('''SELECT COUNT(*) AS total,
                  SUM(CASE WHEN pinned_at IS NOT NULL THEN 1 ELSE 0 END) AS pinned,
                  SUM(CASE WHEN media_uri IS NOT NULL THEN 1 ELSE 0 END) AS media
                  FROM notes WHERE deleted_at IS NULL''').single;
                List<Note> previews(
                  String order,
                  String filter,
                  int limit,
                ) => notes.db
                    .select(
                      'SELECT id FROM notes WHERE deleted_at IS NULL '
                      'AND (set_aside_at IS NULL OR (set_aside_until IS NOT NULL AND set_aside_until <= ?)) '
                      '$filter ORDER BY $order LIMIT ?',
                      [DateTime.now().toUtc().toIso8601String(), limit],
                    )
                    .map((row) => notes.getById(row['id'] as String))
                    .whereType<Note>()
                    .toList();
                result = {
                  'total': totals['total'] ?? 0,
                  'pinned': totals['pinned'] ?? 0,
                  'media':
                      (totals['media'] as int? ?? 0) +
                      (notes.db.select('''SELECT COUNT(*) AS count
                        FROM note_attachments a
                        JOIN notes n ON n.id = a.note_id
                        WHERE a.deleted_at IS NULL
                          AND n.deleted_at IS NULL''').single['count']
                          as int),
                  'scheduled': scheduled.pending().length,
                  'recent': previews('updated_at DESC, id DESC', '', 8),
                  'pins': previews(
                    'pinned_at DESC',
                    'AND pinned_at IS NOT NULL',
                    3,
                  ),
                };
              case 'reminderCandidates':
                result = reminderCandidates(
                  notes,
                  a['now'] as DateTime? ?? DateTime.now(),
                );
              case 'reminderAction':
                final action = ReminderActivation.parse(a['uri'] as String);
                result =
                    action != null &&
                    applyReminderActivation(notes, action, DateTime.now());
                if (result == true) reply.send([-2, true, null]);
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
              case 'attachMedia':
                if (cmd == 'attachMedia' &&
                    notes.getById(a['noteId'] as String) == null) {
                  throw StateError('Parent note is unavailable');
                }
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
                  if (cmd == 'attachMedia') {
                    final kind = NexFileKinds.of(path: target.path);
                    result =
                        SqliteAttachmentRepository(
                          notes,
                          localDeviceId: device,
                        ).add(
                          a['noteId'] as String,
                          kind: kind == NexFileKind.image
                              ? AttachmentKind.photo
                              : kind == NexFileKind.audio
                              ? AttachmentKind.voice
                              : AttachmentKind.file,
                          mediaUri: target.path,
                          mediaHash: hash,
                          name: p.basename(source.path),
                        );
                  } else if (a['duration'] != null ||
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
              case 'portableBackup':
                final library = NexBackupArchive.create(
                  database: db,
                  mediaDir: p.join(root, 'media'),
                  backupDir: p.join(root, 'backups'),
                );
                result = NexBackupArchive.portable(
                  library.path,
                  a['output'] as String,
                );
              case 'backupKind':
                result = NexBackupKind.detect(a['file'] as String);
              case 'fullBackup':
                final supplied = a['settings'] as Map<String, dynamic>;
                final settings = supplied.containsKey('version')
                    ? supplied
                    : <String, dynamic>{
                        'version': PortablePreferences.settingsVersion,
                        'scope': 'shared',
                        'preferences': <String, dynamic>{},
                        'credentials': <String, String>{},
                        'desktopShell': supplied,
                      };
                PortablePreferences.validateScopedBackup(settings);
                final library = NexBackupArchive.create(
                  database: db,
                  mediaDir: p.join(root, 'media'),
                  backupDir: p.join(root, 'backups'),
                );
                final key = FullBackup.newKey();
                FullBackup.create(
                  library: library.path,
                  output: a['output'] as String,
                  settings: settings,
                  key: key,
                );
                result = key;
              case 'restoreBackup':
                final backupPath = a['file'] as String;
                final key = a['key'] as String?;
                String libraryPath = backupPath;
                Map<String, dynamic>? restoredSettings;
                Directory? unpackStaging;
                try {
                  final kind = NexBackupKind.detect(backupPath);
                  if (kind == NexBackupKind.export) {
                    await notes.importArchive(
                      archiveFile: File(backupPath),
                      mediaRoot: p.join(root, 'media'),
                    );
                    result = const DesktopRestoreResult(replacesLibrary: false);
                    break;
                  }
                  if (kind == NexBackupKind.full) {
                    if (key == null || key.trim().isEmpty) {
                      throw ArgumentError('Recovery key required');
                    }
                    unpackStaging = Directory(
                      p.join(root, '.unpack-${newUuidV7()}'),
                    )..createSync(recursive: true);
                    final unpacked = FullBackup.unpack(
                      backupPath,
                      unpackStaging.path,
                      key.trim(),
                      modelHash: '',
                      modelBytes: 0,
                      includeModel: false,
                    );
                    libraryPath = p.join(unpackStaging.path, 'library.nexbak');
                    // Validate appearance before replacing any live library.
                    final prefs = unpacked['preferences'];
                    validateBackupShell(unpacked['desktopShell']);
                    if (prefs != null &&
                            unpacked['scope'] != 'shared' &&
                            unpacked['version'] != 1 ||
                        unpacked.containsKey('scope') &&
                            unpacked['scope'] != 'shared') {
                      throw const FormatException(
                        'Unsupported settings backup',
                      );
                    }
                    if (unpacked['scope'] == 'shared') {
                      PortablePreferences.validateScopedBackup(unpacked);
                    } else if (prefs is Map) {
                      PortablePreferences.validate({
                        for (final key in PortablePreferences.keys)
                          if (prefs.containsKey(key)) key: prefs[key],
                      });
                    }
                    restoredSettings = unpacked;
                  }
                  db.close();
                  try {
                    NexBackupArchive.restore(
                      liveDbPath: p.join(root, 'nex.sqlite'),
                      mediaDir: p.join(root, 'media'),
                      backupFile: libraryPath,
                    );
                  } finally {
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
                  result = DesktopRestoreResult(
                    replacesLibrary: true,
                    settings: restoredSettings,
                  );
                } finally {
                  if (unpackStaging?.existsSync() == true) {
                    try {
                      unpackStaging!.deleteSync(recursive: true);
                    } catch (_) {}
                  }
                }
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
  int revision = 0;
  Future<void> _tail = Future.value();
  Object? _error;
  Future<void> write(String text, {bool checklist = false}) {
    revision++;
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
