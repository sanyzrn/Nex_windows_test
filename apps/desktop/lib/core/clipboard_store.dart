import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:nex_core/nex_core.dart' show sha256OfBytes;
import 'package:sqlite3/sqlite3.dart';
import 'models.dart';

final _identities = Expando<String>('clipboard-identity');
String clipIdentity(ClipEntry entry) => _identities[entry] ??= entry.isImage
    ? 'image:${entry.image!.id}'
    : 'text:${sha256OfBytes(Uint8List.fromList(utf8.encode(entry.text!)))}';

class ClipboardSnapshot {
  ClipboardSnapshot(this.recent, this.favorites);
  final List<ClipEntry> recent, favorites;
}

/// One disk writer. FULL WAL commits sync before acknowledging a clipboard
/// update; images are stored once and are not retransmitted on every copy.
class ClipboardStore {
  ClipboardStore._(this._port, this._worker, this._replies);
  final SendPort _port;
  final Isolate _worker;
  final ReceivePort _replies;
  final _pending = <int, Completer<dynamic>>{};
  int _next = 0;
  bool _closed = false;

  static Future<ClipboardStore> open(String path) async {
    final replies = ReceivePort();
    final ready = Completer<SendPort>();
    ClipboardStore? store;
    replies.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final row = message as List;
      if (row[0] == -1) {
        ready.completeError(StateError(row[2]));
        return;
      }
      final completer = store?._pending.remove(row[0]);
      row[1] == true
          ? completer?.complete(row[2])
          : completer?.completeError(StateError(row[2]));
    });
    final worker = await Isolate.spawn(_run, [replies.sendPort, path]);
    try {
      store = ClipboardStore._(await ready.future, worker, replies);
      return store;
    } catch (_) {
      worker.kill();
      replies.close();
      rethrow;
    }
  }

  Future<dynamic> _call(
    String command, [
    Map<String, dynamic> args = const {},
  ]) {
    if (_closed) return Future.error(StateError('Clipboard store closed'));
    final id = ++_next;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _port.send([id, command, args]);
    return completer.future;
  }

  Future<ClipboardSnapshot> load(List<ClipEntry> legacy) async {
    final result = await _call('load', {'legacy': legacy});
    return result as ClipboardSnapshot;
  }

  Future<void> save(ClipboardSnapshot snapshot, Set<String> known) async {
    final entries = <String, ClipEntry>{};
    final recent = <String, int>{}, favorites = <String, int>{};
    for (var i = 0; i < snapshot.recent.length && i < 50; i++) {
      final e = snapshot.recent[i];
      final key = clipIdentity(e);
      entries[key] = e;
      recent[key] = i;
    }
    for (var i = 0; i < snapshot.favorites.length; i++) {
      final e = snapshot.favorites[i];
      final key = clipIdentity(e);
      entries.putIfAbsent(key, () => e);
      favorites[key] = i;
    }
    await _call('save', {
      'rows': [
        for (final item in entries.entries)
          {
            'key': item.key,
            'recent': recent[item.key],
            'favorite': favorites[item.key],
            'time': item.value.time.millisecondsSinceEpoch,
            if (!known.contains(item.key)) 'entry': item.value,
          },
      ],
    });
  }

  Future<void> close() async {
    if (_closed) return;
    await _call('close');
    _closed = true;
    _replies.close();
    _worker.kill();
  }

  static void _run(List<dynamic> configuration) {
    final reply = configuration[0] as SendPort;
    late Database db;
    var opened = false;
    try {
      db = sqlite3.open(configuration[1] as String);
      opened = true;
      db.execute('PRAGMA busy_timeout=5000');
      db.execute('PRAGMA journal_mode=WAL');
      db.execute('PRAGMA synchronous=FULL');
      db.execute('PRAGMA secure_delete=ON');
      db.execute(
        '''CREATE TABLE IF NOT EXISTS clipboard_entries (
        identity TEXT PRIMARY KEY, content TEXT, image_id TEXT,
        width INTEGER, height INTEGER, rgba BLOB,
        captured_at INTEGER NOT NULL, recent_rank INTEGER, favorite_rank INTEGER)''',
      );
      db.execute(
        'CREATE TABLE IF NOT EXISTS clipboard_meta (version INTEGER PRIMARY KEY)',
      );
    } catch (error) {
      if (opened) db.dispose();
      reply.send([-1, false, '$error']);
      return;
    }
    final commands = ReceivePort();
    reply.send(commands.sendPort);
    commands.listen((message) {
      final raw = message as List;
      final args = raw[2] as Map;
      try {
        dynamic result;
        switch (raw[1]) {
          case 'load':
            if (db.select('SELECT version FROM clipboard_meta').isEmpty) {
              final legacy = (args['legacy'] as List).cast<ClipEntry>();
              _commit(db, [
                for (var i = 0; i < legacy.length; i++)
                  {
                    'key': clipIdentity(legacy[i]),
                    'entry': legacy[i],
                    'time': legacy[i].time.millisecondsSinceEpoch,
                    'favorite': i,
                  },
              ]);
            }
            final recent = <ClipEntry>[], favorites = <ClipEntry>[];
            for (final row in db.select(
              'SELECT * FROM clipboard_entries ORDER BY recent_rank, favorite_rank',
            )) {
              final time = DateTime.fromMillisecondsSinceEpoch(
                row['captured_at'] as int,
              );
              final pinned = row['favorite_rank'] != null;
              final ClipEntry entry;
              if (row['image_id'] != null) {
                final w = row['width'] as int, h = row['height'] as int;
                final bytes = row['rgba'] as Uint8List;
                if (w <= 0 || h <= 0 || bytes.length != w * h * 4) {
                  throw StateError('Invalid stored clipboard image');
                }
                entry = ClipEntry.image(
                  ClipImage(
                    id: row['image_id'] as String,
                    w: w,
                    h: h,
                    rgba: bytes,
                  ),
                  time: time,
                  pinned: pinned,
                );
              } else {
                entry = ClipEntry.text(
                  row['content'] as String,
                  time: time,
                  pinned: pinned,
                );
              }
              if (row['recent_rank'] != null) recent.add(entry);
              if (pinned) favorites.add(entry);
            }
            // Favorites have their own order, independent of recent captures.
            final order = {
              for (final r in db.select(
                'SELECT identity, favorite_rank FROM clipboard_entries',
              ))
                r['identity'] as String: r['favorite_rank'] as int?,
            };
            favorites.sort(
              (a, b) =>
                  order[clipIdentity(a)]!.compareTo(order[clipIdentity(b)]!),
            );
            result = ClipboardSnapshot(recent, favorites);
          case 'save':
            _commit(db, (args['rows'] as List).cast<Map>());
          case 'close':
            db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
            db.dispose();
            commands.close();
        }
        reply.send([raw[0], true, result]);
      } catch (error) {
        reply.send([raw[0], false, '$error']);
      }
    });
  }

  static void _commit(Database db, List<Map> rows) {
    db.execute('BEGIN IMMEDIATE');
    try {
      db.execute(
        'UPDATE clipboard_entries SET recent_rank=NULL, favorite_rank=NULL',
      );
      for (final row in rows) {
        final entry = row['entry'] as ClipEntry?;
        if (entry != null) {
          final img = entry.image;
          db.execute(
            '''INSERT INTO clipboard_entries
            (identity, content, image_id, width, height, rgba, captured_at)
            VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(identity) DO NOTHING''',
            [
              row['key'],
              entry.text,
              img?.id,
              img?.w,
              img?.h,
              img?.rgba,
              row['time'],
            ],
          );
        }
        db.execute(
          '''UPDATE clipboard_entries SET captured_at=?,
          recent_rank=?, favorite_rank=? WHERE identity=?''',
          [row['time'], row['recent'], row['favorite'], row['key']],
        );
        if (db.updatedRows != 1) {
          throw StateError('Clipboard entry data missing');
        }
      }
      db.execute(
        'DELETE FROM clipboard_entries WHERE recent_rank IS NULL AND favorite_rank IS NULL',
      );
      db.execute('INSERT OR IGNORE INTO clipboard_meta VALUES (1)');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}
